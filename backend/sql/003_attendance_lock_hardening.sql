
BEGIN;

-- Check every insert and update, regardless of which column changes.
-- Lock the parent session row to prevent concurrent close/edit races.
CREATE OR REPLACE FUNCTION validate_attendance_record_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
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
      AND institution_id = NEW.institution_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Attendance session not found';
    END IF;

    IF current_status <> 'open' THEN
        RAISE EXCEPTION 'Attendance session is closed; changes are not allowed';
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
        RAISE EXCEPTION 'Student is not enrolled for this attendance session';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_attendance_record_enrollment
ON attendance_records;

CREATE TRIGGER trg_validate_attendance_record_enrollment
BEFORE INSERT OR UPDATE ON attendance_records
FOR EACH ROW
EXECUTE FUNCTION validate_attendance_record_enrollment();


-- Lock the session while checking deletion permissions too.
CREATE OR REPLACE FUNCTION prevent_attendance_record_delete_when_closed()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_status TEXT;
BEGIN
    SELECT session_status
    INTO current_status
    FROM attendance_sessions
    WHERE id = OLD.attendance_session_id
      AND institution_id = OLD.institution_id
    FOR UPDATE;

    IF NOT FOUND OR current_status <> 'open' THEN
        RAISE EXCEPTION 'Cannot delete attendance from a closed session';
    END IF;

    RETURN OLD;
END;
$$;

COMMIT;
