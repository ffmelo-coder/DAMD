const fs = require("fs");
const path = require("path");

function ensureFile(filePath, initial) {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(filePath))
    fs.writeFileSync(filePath, JSON.stringify(initial, null, 2));
}

function readJson(filePath, initial = []) {
  ensureFile(filePath, initial);
  const raw = fs.readFileSync(filePath, "utf8");
  try {
    return JSON.parse(raw || "[]");
  } catch (e) {
    return initial;
  }
}

function writeJson(filePath, data) {
  ensureFile(filePath, data instanceof Array ? [] : {});
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

module.exports = { readJson, writeJson, ensureFile };
