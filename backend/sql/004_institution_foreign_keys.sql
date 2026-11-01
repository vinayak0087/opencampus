BEGIN;

-- Ensure every enrollment belongs to a valid institution.
ALTER TABLE student_enrollments
ADD CONSTRAINT fk_enrollments_institution
FOREIGN KEY (institution_id)
REFERENCES institutions(id)
ON DELETE RESTRICT;

-- Ensure every attendance session belongs to a valid institution.
ALTER TABLE attendance_sessions
ADD CONSTRAINT fk_attendance_sessions_institution
FOREIGN KEY (institution_id)
REFERENCES institutions(id)
ON DELETE RESTRICT;

-- Ensure every attendance record belongs to a valid institution.
ALTER TABLE attendance_records
ADD CONSTRAINT fk_attendance_records_institution
FOREIGN KEY (institution_id)
REFERENCES institutions(id)
ON DELETE RESTRICT;

COMMIT;