const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");

// Use a single SQLite file under the repo data directory
const DB_FILE = path.join(__dirname, "..", "data", "app.db");

function ensureDataDir() {
  const dir = path.dirname(DB_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function initDb() {
  ensureDataDir();
  // Open with a busy timeout so concurrent processes wait for locks
  // instead of immediately throwing SQLITE_BUSY.
  const db = new Database(DB_FILE, { timeout: 5000 });

  // Apply a reasonable busy timeout at runtime as well.
  try {
    db.pragma("busy_timeout = 5000");
  } catch (e) {
    // ignore
  }

  // Try to set WAL journal mode; if it's busy, continue — WAL is an optimization.
  try {
    db.pragma("journal_mode = WAL");
  } catch (e) {
    // ignore journal_mode failures when DB is locked by another process
  }

  db.exec(
    `CREATE TABLE IF NOT EXISTS kv (
      key TEXT PRIMARY KEY,
      json TEXT NOT NULL
    )`
  );
  return db;
}

const db = initDb();

function keyFor(filePath) {
  // Use the basename of the JSON file as key to preserve previous semantics
  return path.basename(filePath);
}

function ensureFile(filePath, initial) {
  const key = keyFor(filePath);
  const row = db.prepare("SELECT json FROM kv WHERE key = ?").get(key);
  if (!row) {
    const json = JSON.stringify(initial, null, 2);
    db.prepare("INSERT INTO kv (key, json) VALUES (?, ?)").run(key, json);
  }
}

function readJson(filePath, initial = []) {
  ensureFile(filePath, initial);
  const key = keyFor(filePath);
  const row = db.prepare("SELECT json FROM kv WHERE key = ?").get(key);
  if (!row || !row.json) return initial;
  try {
    return JSON.parse(row.json);
  } catch (e) {
    return initial;
  }
}

function writeJson(filePath, data) {
  const key = keyFor(filePath);
  const json = JSON.stringify(data, null, 2);
  const exists = db.prepare("SELECT 1 FROM kv WHERE key = ?").get(key);
  if (exists) {
    db.prepare("UPDATE kv SET json = ? WHERE key = ?").run(json, key);
  } else {
    db.prepare("INSERT INTO kv (key, json) VALUES (?, ?)").run(key, json);
  }
}

process.on("exit", () => {
  try {
    db.close();
  } catch (e) {}
});

module.exports = { readJson, writeJson, ensureFile };
