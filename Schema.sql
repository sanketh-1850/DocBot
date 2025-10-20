-- ===== Extensions / Types =====
CREATE EXTENSION citext;

CREATE TYPE user_role AS ENUM ('ADMIN', 'CURATOR', 'ENDUSER');

-- ===== USERS =====
CREATE TABLE users (
  user_id       BIGSERIAL PRIMARY KEY,
  name          TEXT        NOT NULL,
  email         CITEXT      UNIQUE,
  username      CITEXT      UNIQUE NOT NULL,
  password_hash TEXT        NOT NULL,
  role          user_role   NOT NULL,
  created_at    TIMESTAMPTZ,
  CHECK (
    (role = 'ENDUSER' AND created_at IS NOT NULL) OR
    (role IN ('ADMIN', 'CURATOR') AND created_at IS NULL)
  )
);

-- ===== DOCUMENTS =====
CREATE TABLE documents (
  doc_id     BIGSERIAL PRIMARY KEY,
  title      TEXT        NOT NULL,
  doc_type   TEXT,
  source     TEXT,
  added_by   BIGINT      NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== QUERY LOGS =====
CREATE TABLE query_logs (
  log_id     BIGSERIAL PRIMARY KEY,
  user_id    BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
  doc_id     BIGINT REFERENCES documents(doc_id) ON DELETE SET NULL,
  query_text TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
