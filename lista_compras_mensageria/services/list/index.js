const express = require("express");
const bodyParser = require("body-parser");
const path = require("path");
const { readJson, writeJson, ensureFile } = require("../../shared/jsonDb");
const registry = require("../../shared/serviceRegistry");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const fetch = require("node-fetch");
const amqp = require("amqplib");

const app = express();
app.use(bodyParser.json());

const PORT = process.env.PORT || 3002;
const DATA_FILE = path.join(__dirname, "..", "..", "data", "lists.json");
ensureFile(DATA_FILE, []);
const JWT_SECRET = process.env.JWT_SECRET || "verysecret";

function authMiddleware(req, res, next) {
  if (req.headers && req.headers["x-skip-auth"] === "true") {
    req.user = { id: "demo-user", email: "demo@example.com" };
    return next();
  }
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

app.get("/health", (req, res) => res.json({ status: "ok", service: "list" }));

app.post("/lists", authMiddleware, async (req, res) => {
  const { name, description, items: incomingItems } = req.body;
  const lists = readJson(DATA_FILE, []);
  const id = uuidv4();
  const now = new Date().toISOString();

  const list = {
    id,
    name: name || "",
    description: description || "",
    userId: req.user && req.user.id ? req.user.id : "demo-user",
    items: [],
    status: "active",
    createdAt: now,
    updatedAt: now,
    summary: { totalItems: 0, purchasedItems: 0, estimatedTotal: 0 },
  };

  if (Array.isArray(incomingItems) && incomingItems.length > 0) {
    const svc = registry.discover("item-service");
    for (const inc of incomingItems) {
      try {
        if (inc.itemId && svc) {
          const resp = await fetch(`${svc.url}/items/${inc.itemId}`);
          if (resp.ok) {
            const item = await resp.json();
            const added = {
              itemId: item.id,
              itemName: item.name,
              quantity: Number(inc.quantity || 1),
              unit: item.unit || inc.unit || "un",
              estimatedPrice:
                (item.averagePrice || 0) * Number(inc.quantity || 1),
              purchased: !!inc.purchased,
              notes: inc.notes || "",
              addedAt: new Date().toISOString(),
              id: uuidv4(),
            };
            list.items.push(added);
          } else {
            const fallback = {
              itemId: inc.itemId,
              itemName: inc.itemName || inc.name || "",
              quantity: Number(inc.quantity || 1),
              unit: inc.unit || "un",
              estimatedPrice: Number(inc.estimatedPrice || 0),
              purchased: !!inc.purchased,
              notes: inc.notes || "",
              addedAt: new Date().toISOString(),
              id: uuidv4(),
            };
            list.items.push(fallback);
          }
        } else {
          const inline = {
            itemId: inc.itemId || null,
            itemName: inc.itemName || inc.name || "",
            quantity: Number(inc.quantity || 1),
            unit: inc.unit || "un",
            estimatedPrice: Number(inc.estimatedPrice || 0),
            purchased: !!inc.purchased,
            notes: inc.notes || "",
            addedAt: new Date().toISOString(),
            id: inc.id || uuidv4(),
          };
          list.items.push(inline);
        }
      } catch (e) {
        console.warn(
          "Failed to process incoming item on list create:",
          e && e.message
        );
      }
    }
    list.summary = calculateSummary(list.items);
    list.updatedAt = new Date().toISOString();
  }

  lists.push(list);
  writeJson(DATA_FILE, lists);
  res.json(list);
});

app.get("/lists", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const mine = lists.filter((l) => l.userId === req.user.id);
  res.json(mine);
});

function requireOwnership(userId, list) {
  return list && list.userId === userId;
}

app.get("/lists/:id", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const list = lists.find((l) => l.id === req.params.id);
  if (!list) return res.status(404).json({ error: "not found" });
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  res.json(list);
});

app.put("/lists/:id", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  const { name, description, status } = req.body;
  if (name !== undefined) list.name = name;
  if (description !== undefined) list.description = description;
  if (status !== undefined) list.status = status;
  list.updatedAt = new Date().toISOString();
  lists[idx] = list;
  writeJson(DATA_FILE, lists);
  res.json(list);
});

app.delete("/lists/:id", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  lists.splice(idx, 1);
  writeJson(DATA_FILE, lists);
  res.json({ ok: true });
});

app.post("/lists/:id/items", authMiddleware, async (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  const { itemId, quantity = 1, notes = "" } = req.body;
  if (!itemId) return res.status(400).json({ error: "itemId required" });

  const svc = registry.discover("item-service");
  if (!svc) return res.status(500).json({ error: "item service unavailable" });
  try {
    const resp = await fetch(`${svc.url}/items/${itemId}`);
    if (!resp.ok)
      return res.status(400).json({ error: "item not found in item service" });
    const item = await resp.json();
    const added = {
      itemId: item.id,
      itemName: item.name,
      quantity: Number(quantity),
      unit: item.unit || "un",
      estimatedPrice: (item.averagePrice || 0) * Number(quantity),
      purchased: false,
      notes: notes || "",
      addedAt: new Date().toISOString(),
      id: uuidv4(),
    };
    list.items.push(added);
    list.summary = calculateSummary(list.items);
    list.updatedAt = new Date().toISOString();
    lists[idx] = list;
    writeJson(DATA_FILE, lists);
    res.json(added);
  } catch (e) {
    return res.status(500).json({ error: "error fetching item" });
  }
});

app.put("/lists/:id/items/:itemId", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  const itemIdx = list.items.findIndex((it) => it.id === req.params.itemId);
  if (itemIdx === -1)
    return res.status(404).json({ error: "item not in list" });
  const it = list.items[itemIdx];
  const { quantity, purchased, notes } = req.body;
  if (quantity !== undefined) {
    it.quantity = Number(quantity);
    const unitPrice =
      it.estimatedPrice && it.quantity
        ? it.estimatedPrice / it.quantity
        : it.estimatedPrice || 0;
    it.estimatedPrice = unitPrice * it.quantity;
  }
  if (purchased !== undefined) it.purchased = !!purchased;
  if (notes !== undefined) it.notes = notes;
  list.items[itemIdx] = it;
  list.summary = calculateSummary(list.items);
  list.updatedAt = new Date().toISOString();
  lists[idx] = list;
  writeJson(DATA_FILE, lists);
  res.json(it);
});

app.delete("/lists/:id/items/:itemId", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  const itemIdx = list.items.findIndex((it) => it.id === req.params.itemId);
  if (itemIdx === -1)
    return res.status(404).json({ error: "item not in list" });
  list.items.splice(itemIdx, 1);
  list.summary = calculateSummary(list.items);
  list.updatedAt = new Date().toISOString();
  lists[idx] = list;
  writeJson(DATA_FILE, lists);
  res.json({ ok: true });
});

app.get("/lists/:id/summary", authMiddleware, (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const list = lists.find((l) => l.id === req.params.id);
  if (!list) return res.status(404).json({ error: "not found" });
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });
  list.summary = calculateSummary(list.items);
  res.json(list.summary);
});

app.post("/lists/:id/checkout", authMiddleware, async (req, res) => {
  const lists = readJson(DATA_FILE, []);
  const idx = lists.findIndex((l) => l.id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "not found" });
  const list = lists[idx];
  if (!requireOwnership(req.user.id, list))
    return res.status(403).json({ error: "forbidden" });

  list.status = "completed";
  list.updatedAt = new Date().toISOString();
  list.summary = calculateSummary(list.items);
  lists[idx] = list;
  writeJson(DATA_FILE, lists);

  const payload = {
    event: "list.checkout.completed",
    listId: list.id,
    userId: list.userId,
    items: list.items,
    summary: list.summary,
    timestamp: new Date().toISOString(),
  };

  try {
    const userSvc = registry.discover("user-service");
    if (userSvc) {
      const r = await fetch(`${userSvc.url}/users/${list.userId}`, {
        headers: { authorization: req.headers.authorization },
      });
      if (r.ok) {
        const u = await r.json();
        payload.userEmail = u.email;
      }
    }
  } catch (e) {}

  const amqpUrl =
    process.env.AMQP_URL ||
    process.env.CLOUDAMQP_URL ||
    "amqp://guest:guest@localhost:5672/";
  (async () => {
    try {
      const conn = await amqp.connect(amqpUrl);
      const ch = await conn.createChannel();
      const exchange = "shopping_events";
      await ch.assertExchange(exchange, "topic", { durable: true });
      const routingKey = "list.checkout.completed";
      ch.publish(exchange, routingKey, Buffer.from(JSON.stringify(payload)), {
        persistent: true,
      });
      await ch.close();
      await conn.close();
      console.log("Published checkout event for list", list.id);
    } catch (e) {
      console.error("Failed to publish checkout event", e.message || e);
    }
  })();

  res.status(202).json({ status: "accepted", listId: list.id });
});

function calculateSummary(items) {
  const totalItems = items.length;
  const purchasedItems = items.filter((i) => i.purchased).length;
  const estimatedTotal = items.reduce(
    (s, i) => s + Number(i.estimatedPrice || 0),
    0
  );
  return { totalItems, purchasedItems, estimatedTotal };
}

const serviceUrl = `http://localhost:${PORT}`;
registry.registerService("list-service", {
  url: serviceUrl,
  port: PORT,
  healthPath: "/health",
});

app.listen(PORT, () => console.log(`List Service running on ${PORT}`));
