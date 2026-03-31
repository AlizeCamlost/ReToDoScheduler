CREATE TABLE IF NOT EXISTS task_pool_organization_documents (
  id TEXT PRIMARY KEY,
  payload_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_task_pool_organization_documents_updated_at
  ON task_pool_organization_documents(updated_at);
