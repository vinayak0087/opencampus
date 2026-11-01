BEGIN;

-- Global user identity.
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    is_platform_admin BOOLEAN NOT NULL DEFAULT FALSE,
    account_status TEXT NOT NULL DEFAULT 'active'
        CHECK (account_status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Email addresses are unique regardless of letter case.
CREATE UNIQUE INDEX uq_users_email_lower
ON users (LOWER(email));

-- Institution-specific access and roles.
CREATE TABLE institution_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    institution_id UUID NOT NULL REFERENCES institutions(id) ON DELETE RESTRICT,
    department_id UUID,
    role TEXT NOT NULL CHECK (
        role IN (
            'institution_admin',
            'hod',
            'faculty',
            'class_representative',
            'student'
        )
    ),
    membership_status TEXT NOT NULL DEFAULT 'active'
        CHECK (membership_status IN ('active', 'inactive', 'suspended')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    FOREIGN KEY (department_id, institution_id)
        REFERENCES departments(id, institution_id),

    UNIQUE (user_id, institution_id, role)
);

CREATE INDEX idx_memberships_user
ON institution_memberships(user_id, membership_status);

CREATE INDEX idx_memberships_institution
ON institution_memberships(institution_id, role, membership_status);

COMMIT;