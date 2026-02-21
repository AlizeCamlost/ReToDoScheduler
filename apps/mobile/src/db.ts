import * as SQLite from "expo-sqlite";

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

export const getDb = async (): Promise<SQLite.SQLiteDatabase> => {
  if (!dbPromise) {
    dbPromise = SQLite.openDatabaseAsync("retodo.db");
  }
  return dbPromise;
};

export const initializeDb = async (): Promise<void> => {
  const db = await getDb();
  await db.execAsync(`
    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      raw_input TEXT NOT NULL,
      status TEXT NOT NULL,
      estimated_minutes INTEGER NOT NULL,
      min_chunk_minutes INTEGER NOT NULL,
      due_at TEXT,
      importance INTEGER NOT NULL,
      value_score INTEGER NOT NULL,
      difficulty INTEGER NOT NULL,
      postponability INTEGER NOT NULL,
      task_traits_json TEXT NOT NULL,
      tags_json TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      ext_json TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
  `);
};
