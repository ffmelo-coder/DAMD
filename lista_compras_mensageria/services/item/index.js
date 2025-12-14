const express = require("express");
const bodyParser = require("body-parser");
const path = require("path");
const { readJson, writeJson, ensureFile } = require("../../shared/jsonDb");
const registry = require("../../shared/serviceRegistry");
const jwt = require("jsonwebtoken");

const app = express();
app.use(bodyParser.json());

app.use((req, res, next) => {
  try {
    const safeBody = Object.assign({}, req.body || {});
    if (safeBody.password) safeBody.password = "****";
    console.log(
      `[item] ${req.method} ${req.originalUrl} body=${JSON.stringify(safeBody)}`
    );
  } catch (e) {
    console.log("[item] request logger error", e.message || e);
  }
  next();
});

const PORT = process.env.PORT || 3003;
const DATA_FILE = path.join(__dirname, "..", "..", "data", "items.json");
ensureFile(DATA_FILE, []);
const JWT_SECRET = process.env.JWT_SECRET || "verysecret";

function authOptional(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return next();
  const parts = auth.split(" ");
  if (parts.length !== 2) return next();
  const token = parts[1];
  try {
    req.user = jwt.verify(token, JWT_SECRET);
  } catch (e) {}
  next();
}

app.get("/health", (req, res) => res.json({ status: "ok", service: "item" }));

app.get("/items", authOptional, (req, res) => {
  const { category, name } = req.query;
  let items = readJson(DATA_FILE, []);
  if (category)
    items = items.filter(
      (i) => i.category.toLowerCase() === category.toLowerCase()
    );
  if (name)
    items = items.filter((i) =>
      i.name.toLowerCase().includes(name.toLowerCase())
    );
  res.json(items);
});

app.get("/items/:id", (req, res) => {
  const items = readJson(DATA_FILE, []);
  const it = items.find((i) => i.id === req.params.id);
  if (!it) return res.status(404).json({ error: "not found" });
  res.json(it);
});

app.post("/items", (req, res) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: "missing token" });
  const parts = auth.split(" ");
  if (parts.length !== 2)
    return res.status(401).json({ error: "bad auth header" });
  const token = parts[1];
  try {
    jwt.verify(token, JWT_SECRET);
  } catch (e) {
    return res.status(401).json({ error: "invalid token" });
  }

  const body = req.body;
  const items = readJson(DATA_FILE, []);
  const id = (items.length + 1).toString();
  const now = Date.now();
  const item = Object.assign({ id, createdAt: now, active: true }, body);
  items.push(item);
  writeJson(DATA_FILE, items);
  res.json(item);
});

app.put("/items/:id", (req, res) => {
  const items = readJson(DATA_FILE, []);
  const idx = items.findIndex((i) => i.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  items[idx] = Object.assign(items[idx], req.body);
  writeJson(DATA_FILE, items);
  res.json(items[idx]);
});

app.get("/categories", (req, res) => {
  const items = readJson(DATA_FILE, []);
  const cats = [...new Set(items.map((i) => i.category))];
  res.json(cats);
});

app.get("/search", (req, res) => {
  const q = (req.query.q || "").toLowerCase();
  const items = readJson(DATA_FILE, []);
  const found = items.filter(
    (i) =>
      i.name.toLowerCase().includes(q) ||
      (i.description || "").toLowerCase().includes(q)
  );
  res.json(found);
});

const serviceUrl = `http://localhost:${PORT}`;
registry.registerService("item-service", {
  url: serviceUrl,
  port: PORT,
  healthPath: "/health",
});

app.listen(PORT, () => console.log(`Item Service running on ${PORT}`));
