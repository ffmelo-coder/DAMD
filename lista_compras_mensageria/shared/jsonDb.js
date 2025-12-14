const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");

const DB_FILE = path.join(__dirname, "..", "data", "app.db");

function ensureDataDir() {
  const dir = path.dirname(DB_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

function initDb() {
  ensureDataDir();
  const db = new Database(DB_FILE, { timeout: 5000 });

  try {
    db.pragma("busy_timeout = 5000");
  } catch (e) {}

  try {
    db.pragma("journal_mode = WAL");
  } catch (e) {}

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
