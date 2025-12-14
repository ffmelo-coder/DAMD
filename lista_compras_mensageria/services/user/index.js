const express = require("express");
const bodyParser = require("body-parser");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const { readJson, writeJson, ensureFile } = require("../../shared/jsonDb");
const registry = require("../../shared/serviceRegistry");

const app = express();
app.use(bodyParser.json());

app.use((req, res, next) => {
  try {
    const safeBody = Object.assign({}, req.body || {});
    if (safeBody.password) safeBody.password = "****";
    console.log(
      `[user] ${req.method} ${req.originalUrl} body=${JSON.stringify(safeBody)}`
    );
  } catch (e) {
    console.log("[user] request logger error", e.message || e);
  }
  next();
});

const PORT = process.env.PORT || 3001;
const DATA_FILE = path.join(__dirname, "..", "..", "data", "users.json");
ensureFile(DATA_FILE, []);
const JWT_SECRET = process.env.JWT_SECRET || "verysecret";

function authMiddleware(req, res, next) {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: "missing token" });
  const parts = auth.split(" ");
  if (parts.length !== 2)
    return res.status(401).json({ error: "bad auth header" });
  const token = parts[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: "invalid token" });
  }
}

app.get("/health", (req, res) => res.json({ status: "ok", service: "user" }));

app.post("/auth/register", (req, res) => {
  const { email, username, password, firstName, lastName, preferences } =
    req.body;
  if (!email || !password || !username)
    return res
      .status(400)
      .json({ error: "email, username and password required" });
  const users = readJson(DATA_FILE, []);
  if (users.find((u) => u.email === email))
    return res.status(400).json({ error: "email already exists" });
  const id = uuidv4();
  const hash = bcrypt.hashSync(password, 10);
  const now = Date.now();
  const user = {
    id,
    email,
    username,
    password: hash,
    firstName: firstName || "",
    lastName: lastName || "",
    preferences: preferences || {},
    createdAt: now,
    updatedAt: now,
  };
  users.push(user);
  writeJson(DATA_FILE, users);
  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, {
    expiresIn: "7d",
  });
  res.json({
    user: { id: user.id, email: user.email, username: user.username },
    token,
  });
});

app.post("/auth/login", (req, res) => {
  const { email, password } = req.body;
  if (!email || !password)
    return res.status(400).json({ error: "email and password required" });
  const users = readJson(DATA_FILE, []);
  const user = users.find((u) => u.email === email);
  if (!user) return res.status(401).json({ error: "invalid credentials" });
  if (!bcrypt.compareSync(password, user.password))
    return res.status(401).json({ error: "invalid credentials" });
  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, {
    expiresIn: "7d",
  });
  res.json({
    token,
    user: { id: user.id, email: user.email, username: user.username },
  });
});

app.get("/users/:id", authMiddleware, (req, res) => {
  const { id } = req.params;
  if (req.user.id !== id) return res.status(403).json({ error: "forbidden" });
  const users = readJson(DATA_FILE, []);
  const user = users.find((u) => u.id === id);
  if (!user) return res.status(404).json({ error: "not found" });
  const safe = Object.assign({}, user);
  delete safe.password;
  res.json(safe);
});

app.put("/users/:id", authMiddleware, (req, res) => {
  const { id } = req.params;
  if (req.user.id !== id) return res.status(403).json({ error: "forbidden" });
  const users = readJson(DATA_FILE, []);
  const idx = users.findIndex((u) => u.id === id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const toUpdate = users[idx];
  const { firstName, lastName, preferences } = req.body;
  if (firstName !== undefined) toUpdate.firstName = firstName;
  if (lastName !== undefined) toUpdate.lastName = lastName;
  if (preferences !== undefined) toUpdate.preferences = preferences;
  toUpdate.updatedAt = Date.now();
  users[idx] = toUpdate;
  writeJson(DATA_FILE, users);
  const safe = Object.assign({}, toUpdate);
  delete safe.password;
  res.json(safe);
});

const serviceUrl = `http://localhost:${PORT}`;
registry.registerService("user-service", {
  url: serviceUrl,
  port: PORT,
  healthPath: "/health",
});

app.listen(PORT, () => console.log(`User Service running on ${PORT}`));
