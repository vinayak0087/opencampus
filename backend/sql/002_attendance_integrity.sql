
BEGIN;

-- Validate that the class and subject belong to the same department.
CREATE OR REPLACE FUNCTION validate_attendance_session_department()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    class_dept UUID;
    subject_dept UUID;
BEGIN
    SELECT department_id INTO class_dept
    FROM class_sections
    WHERE id = NEW.class_section_id
      AND institution_id = NEW.institution_id;

    SELECT department_id INTO subject_dept
    FROM subjects
    WHERE id = NEW.subject_id
      AND institution_id = NEW.institution_id;

    IF class_dept IS NULL OR subject_dept IS NULL THEN
        RAISE EXCEPTION 'Invalid class section or subject';
    END IF;

    IF class_dept <> subject_dept THEN
        RAISE EXCEPTION 'Subject must belong to the class department';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_attendance_session_department
BEFORE INSERT OR UPDATE OF class_section_id, subject_id, institution_id
ON attendance_sessions
FOR EACH ROW
EXECUTE FUNCTION validate_attendance_session_department();


-- Validate that student enrolment matches the class and subject.
CREATE OR REPLACE FUNCTION validate_student_enrollment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    student_dept UUID;
    class_dept UUID;
    subject_dept UUID;
BEGIN
    SELECT department_id INTO student_dept
    FROM students
    WHERE id = NEW.student_id
      AND institution_id = NEW.institution_id;

    SELECT department_id INTO class_dept
    FROM class_sections
    WHERE id = NEW.class_section_id
      AND institution_id = NEW.institution_id;

    IF student_dept IS NULL OR class_dept IS NULL THEN
        RAISE EXCEPTION 'Student or class does not belong to this institution';
    END IF;

    IF student_dept <> class_dept THEN
        RAISE EXCEPTION 'Student and class must belong to the same department';
    END IF;

    IF NEW.subject_id IS NOT NULL THEN
        SELECT department_id INTO subject_dept
        FROM subjects
        WHERE id = NEW.subject_id
          AND institution_id = NEW.institution_id;

        IF subject_dept IS NULL OR subject_dept <> class_dept THEN
            RAISE EXCEPTION 'Enrolment subject must belong to the class department';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_student_enrollment
BEFORE INSERT OR UPDATE OF student_id, class_section_id, subject_id, institution_id
ON student_enrollments
FOR EACH ROW
EXECUTE FUNCTION validate_student_enrollment();


-- Attendance can only be recorded for an enrolled student.
-- A NULL subject_id in student_enrollments means class-wide enrolment.
CREATE OR REPLACE FUNCTION validate_attendance_record_enrollment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    session_date DATE;
    session_subject UUID;
    session_class UUID;
    current_status TEXT;
BEGIN
    SELECT attendance_date, subject_id, class_section_id, session_status
    INTO session_date, session_subject, session_class, current_status
    FROM attendance_sessions
    WHERE id = NEW.attendance_session_id
      AND institution_id = NEW.institution_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attendance session not found';
    END IF;

    IF current_status <> 'open' THEN
        RAISE EXCEPTION 'Only open attendance sessions can be changed';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM student_enrollments e
        WHERE e.institution_id = NEW.institution_id
          AND e.student_id = NEW.student_id
          AND e.class_section_id = session_class
          AND (e.subject_id IS NULL OR e.subject_id = session_subject)
          AND e.enrolled_from <= session_date
          AND (e.enrolled_until IS NULL OR e.enrolled_until >= session_date)
    ) THEN
        RAISE EXCEPTION 'Student is not enrolled in this class and subject on this date';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_attendance_record_enrollment
BEFORE INSERT OR UPDATE OF attendance_session_id, student_id, institution_id, status
ON attendance_records
FOR EACH ROW
EXECUTE FUNCTION validate_attendance_record_enrollment();


-- Prevent deleting records after a session is closed.
CREATE OR REPLACE FUNCTION prevent_attendance_record_delete_when_closed()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    current_status TEXT;
BEGIN
    SELECT session_status INTO current_status
    FROM attendance_sessions
    WHERE id = OLD.attendance_session_id
      AND institution_id = OLD.institution_id;

    IF current_status IS DISTINCT FROM 'open' THEN
        RAISE EXCEPTION 'Cannot delete attendance from a closed session';
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_prevent_attendance_record_delete_when_closed
BEFORE DELETE ON attendance_records
FOR EACH ROW
EXECUTE FUNCTION prevent_attendance_record_delete_when_closed();


-- Automatically update the modification timestamp.
CREATE OR REPLACE FUNCTION set_attendance_record_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_set_attendance_record_updated_at
BEFORE UPDATE ON attendance_records
FOR EACH ROW
EXECUTE FUNCTION set_attendance_record_updated_at();


-- Audit log: retain changes even if an attendance record is deleted.
CREATE TABLE attendance_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL,
    attendance_session_id UUID NOT NULL,
    attendance_record_id UUID NOT NULL,
    student_id UUID NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by TEXT NOT NULL DEFAULT CURRENT_USER
);

CREATE INDEX idx_attendance_audit_session
ON attendance_audit_logs(institution_id, attendance_session_id, changed_at DESC);

CREATE INDEX idx_attendance_audit_student
ON attendance_audit_logs(institution_id, student_id, changed_at DESC);


CREATE OR REPLACE FUNCTION write_attendance_audit_log()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO attendance_audit_logs (
            institution_id, attendance_session_id, attendance_record_id,
            student_id, action, new_data
        )
        VALUES (
            NEW.institution_id, NEW.attendance_session_id, NEW.id,
            NEW.student_id, TG_OP, TO_JSONB(NEW)
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO attendance_audit_logs (
            institution_id, attendance_session_id, attendance_record_id,
            student_id, action, old_data, new_data
        )
        VALUES (
            NEW.institution_id, NEW.attendance_session_id, NEW.id,
            NEW.student_id, TG_OP, TO_JSONB(OLD), TO_JSONB(NEW)
        );
        RETURN NEW;

    ELSE
        INSERT INTO attendance_audit_logs (
            institution_id, attendance_session_id, attendance_record_id,
            student_id, action, old_data
        )
        VALUES (
            OLD.institution_id, OLD.attendance_session_id, OLD.id,
            OLD.student_id, TG_OP, TO_JSONB(OLD)
        );
        RETURN OLD;
    END IF;
END;
$$;

CREATE TRIGGER trg_write_attendance_audit_log
AFTER INSERT OR UPDATE OR DELETE ON attendance_records
FOR EACH ROW
EXECUTE FUNCTION write_attendance_audit_log();


-- Improve enrolment lookup performance.
CREATE INDEX idx_student_enrollments_attendance_lookup
ON student_enrollments(
    institution_id, student_id, class_section_id,
    enrolled_from, enrolled_until
);

COMMIT;
