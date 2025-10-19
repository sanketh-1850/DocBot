-- ===== Extensions / Types =====
CREATE EXTENSION IF NOT EXISTS citext;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('ADMIN','CURATOR','ENDUSER');
  END IF;
END$$;

-- ===== USERS (from ERD: userId, name, email/Username, password_hash, role, timestamp[EndUser only]) =====
CREATE TABLE IF NOT EXISTS users (
  user_id          BIGSERIAL PRIMARY KEY,
  name             TEXT        NOT NULL,
  email            CITEXT      UNIQUE,
  username         CITEXT      UNIQUE NOT NULL,
  password_hash    TEXT        NOT NULL,
  role             user_role   NOT NULL,
  -- ERD note: “timestamp (null for admin and curator)”
  last_activity_at TIMESTAMPTZ,               -- for ENDUSER only
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (role = 'ENDUSER' OR last_activity_at IS NULL)
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ===== DOCUMENTS (docId, title, type, source, timestamp; added_by → User) =====
-- Project requires a processed flag for Vector Pipeline.
CREATE TABLE IF NOT EXISTS documents (
  doc_id     BIGSERIAL PRIMARY KEY,
  title      TEXT        NOT NULL,
  doc_type   TEXT,                      -- ERD: type
  source     TEXT,
  added_by   BIGINT      NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),   -- ERD: timestamp
  processed  BOOLEAN     NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_documents_added_by ON documents(added_by);
CREATE INDEX IF NOT EXISTS idx_documents_processed ON documents(processed);

-- Optional: prevent changing ownership later
CREATE OR REPLACE FUNCTION prevent_added_by_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.added_by <> OLD.added_by THEN
    RAISE EXCEPTION 'added_by is immutable once set';
  END IF;
  RETURN NEW;
END$$;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='trg_documents_lock_owner') THEN
    CREATE TRIGGER trg_documents_lock_owner
    BEFORE UPDATE OF added_by ON documents
    FOR EACH ROW EXECUTE FUNCTION prevent_added_by_update();
  END IF;
END$$;

-- ===== QUERY LOGS (queryId, queryText, timestamp; query_issued_by → User) =====
CREATE TABLE IF NOT EXISTS query_logs (
  log_id     BIGSERIAL PRIMARY KEY,           -- ERD: queryId
  user_id    BIGINT REFERENCES users(user_id) ON DELETE SET NULL, -- ERD: query_issued_by
  query_text TEXT        NOT NULL,            -- ERD: queryText
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()  -- ERD: timestamp
);
CREATE INDEX IF NOT EXISTS idx_query_logs_user ON query_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_query_logs_created_at ON query_logs(created_at);

-- ===== QUERY ↔ DOCUMENT (ERD: queried_by is M–N) =====
CREATE TABLE IF NOT EXISTS query_log_results (
  log_id  BIGINT NOT NULL REFERENCES query_logs(log_id) ON DELETE CASCADE,
  doc_id  BIGINT NOT NULL REFERENCES documents(doc_id)  ON DELETE CASCADE,
  rank    INT,
  score   DOUBLE PRECISION,
  PRIMARY KEY (log_id, doc_id)
);
CREATE INDEX IF NOT EXISTS idx_qlr_rank  ON query_log_results(rank);
CREATE INDEX IF NOT EXISTS idx_qlr_score ON query_log_results(score);
