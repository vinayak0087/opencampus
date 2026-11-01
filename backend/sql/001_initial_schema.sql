BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE institutions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    programme_type TEXT NOT NULL DEFAULT 'unspecified',
    UNIQUE (institution_id, code),
    UNIQUE (id, institution_id)
);

CREATE TABLE academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    label TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CHECK (end_date >= start_date),
    UNIQUE (institution_id, label),
    UNIQUE (id, institution_id)
);

CREATE TABLE class_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    department_id UUID NOT NULL,
    academic_year_id UUID NOT NULL,
    programme_name TEXT NOT NULL,
    study_year SMALLINT NOT NULL CHECK (study_year > 0),
    section_name TEXT NOT NULL DEFAULT 'A',
    FOREIGN KEY (department_id, institution_id)
        REFERENCES departments(id, institution_id),
    FOREIGN KEY (academic_year_id, institution_id)
        REFERENCES academic_years(id, institution_id),
    UNIQUE (id, institution_id)
);

CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    department_id UUID NOT NULL,
    admission_number TEXT NOT NULL,
    full_name TEXT NOT NULL,
    institutional_email TEXT,
    student_status TEXT NOT NULL DEFAULT 'active'
        CHECK (student_status IN ('active', 'inactive', 'graduated', 'withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (department_id, institution_id)
        REFERENCES departments(id, institution_id),
    UNIQUE (institution_id, admission_number),
    UNIQUE (id, institution_id)
);

CREATE TABLE faculty (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    department_id UUID NOT NULL,
    staff_code TEXT NOT NULL,
    full_name TEXT NOT NULL,
    institutional_email TEXT,
    FOREIGN KEY (department_id, institution_id)
        REFERENCES departments(id, institution_id),
    UNIQUE (institution_id, staff_code),
    UNIQUE (id, institution_id)
);

CREATE TABLE subjects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL REFERENCES institutions(id),
    department_id UUID NOT NULL,
    subject_code TEXT NOT NULL,
    subject_name TEXT NOT NULL,
    FOREIGN KEY (department_id, institution_id)
        REFERENCES departments(id, institution_id),
    UNIQUE (institution_id, subject_code),
    UNIQUE (id, institution_id)
);

CREATE TABLE student_enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL,
    student_id UUID NOT NULL,
    class_section_id UUID NOT NULL,
    subject_id UUID,
    enrolled_from DATE NOT NULL DEFAULT CURRENT_DATE,
    enrolled_until DATE,
    FOREIGN KEY (student_id, institution_id)
        REFERENCES students(id, institution_id),
    FOREIGN KEY (class_section_id, institution_id)
        REFERENCES class_sections(id, institution_id),
    FOREIGN KEY (subject_id, institution_id)
        REFERENCES subjects(id, institution_id),
    CHECK (enrolled_until IS NULL OR enrolled_until >= enrolled_from)
);

CREATE TABLE attendance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL,
    class_section_id UUID NOT NULL,
    subject_id UUID NOT NULL,
    faculty_id UUID NOT NULL,
    attendance_date DATE NOT NULL,
    period_number SMALLINT NOT NULL CHECK (period_number > 0),
    session_status TEXT NOT NULL DEFAULT 'open'
        CHECK (session_status IN ('open', 'submitted', 'locked', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (class_section_id, institution_id)
        REFERENCES class_sections(id, institution_id),
    FOREIGN KEY (subject_id, institution_id)
        REFERENCES subjects(id, institution_id),
    FOREIGN KEY (faculty_id, institution_id)
        REFERENCES faculty(id, institution_id),
    UNIQUE (class_section_id, subject_id, attendance_date, period_number),
    UNIQUE (id, institution_id)
);

CREATE TABLE attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    institution_id UUID NOT NULL,
    attendance_session_id UUID NOT NULL,
    student_id UUID NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('present', 'absent', 'on_duty', 'excused')),
    remarks TEXT,
    marked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (attendance_session_id, institution_id)
        REFERENCES attendance_sessions(id, institution_id),
    FOREIGN KEY (student_id, institution_id)
        REFERENCES students(id, institution_id),
    UNIQUE (attendance_session_id, student_id)
);

CREATE INDEX idx_students_department
ON students(institution_id, department_id, student_status);

CREATE INDEX idx_attendance_date
ON attendance_sessions(class_section_id, attendance_date);

CREATE INDEX idx_attendance_student
ON attendance_records(student_id, attendance_session_id);

CREATE INDEX idx_absentees
ON attendance_records(attendance_session_id)
WHERE status = 'absent';

COMMIT;