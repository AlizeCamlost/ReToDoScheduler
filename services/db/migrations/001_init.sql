CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  raw_input TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL,
  estimated_minutes INTEGER NOT NULL,
  min_chunk_minutes INTEGER NOT NULL,
  due_at TIMESTAMPTZ,
  importance SMALLINT NOT NULL,
  value_score SMALLINT NOT NULL,
  difficulty SMALLINT NOT NULL,
  postponability SMALLINT NOT NULL,
  task_traits_json JSONB NOT NULL,
  tags_json JSONB NOT NULL,
  ext_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS task_parts (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  estimated_minutes INTEGER NOT NULL,
  status TEXT NOT NULL,
  dependency_ids_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS time_windows (
  id TEXT PRIMARY KEY,
  weekday SMALLINT NOT NULL,
  start_minute SMALLINT NOT NULL,
  end_minute SMALLINT NOT NULL,
  slot_traits_json JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS schedule_blocks (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  task_part_id TEXT,
  start_at TIMESTAMPTZ NOT NULL,
  end_at TIMESTAMPTZ NOT NULL,
  is_parallel BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS learning_events (
  id TEXT PRIMARY KEY,
  higher_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  lower_task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  source TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_ops (
  id BIGSERIAL PRIMARY KEY,
  device_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op_type TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_ops_created_at ON sync_ops(created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at);
