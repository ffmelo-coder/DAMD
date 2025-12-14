const express = require("express");
const bodyParser = require("body-parser");
const registry = require("../shared/serviceRegistry");
const fetch = require("node-fetch");

const app = express();
app.use(bodyParser.json({ limit: "50mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "50mb" }));

const PORT = process.env.PORT || 3000;

const cb = {};
function recordFailure(name) {
  cb[name] = cb[name] || { failures: 0, openUntil: 0 };
  cb[name].failures++;
  if (cb[name].failures >= 3) cb[name].openUntil = Date.now() + 30 * 1000;
}
function recordSuccess(name) {
  cb[name] = { failures: 0, openUntil: 0 };
}
function isOpen(name) {
  cb[name] = cb[name] || { failures: 0, openUntil: 0 };
  if (Date.now() < cb[name].openUntil) return true;
  return false;
}

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
  next();
});

async function proxyToService(serviceName, reqPath, req, res) {
  const svc = registry.discover(serviceName);
  if (!svc)
    return res.status(503).json({ error: `${serviceName} not available` });
  if (isOpen(serviceName))
    return res.status(503).json({ error: `${serviceName} circuit open` });
  const url = svc.url + reqPath;
  try {
    const options = {
      method: req.method,
      headers: Object.assign({}, req.headers),
    };
    delete options.headers.host;
    if (req.method !== "GET" && req.method !== "HEAD")
      options.body = JSON.stringify(req.body);
    const r = await fetch(url, options);
    const text = await r.text();
    res.status(r.status);
    try {
      res.json(JSON.parse(text));
    } catch (e) {
      res.send(text);
    }
    recordSuccess(serviceName);
  } catch (e) {
    recordFailure(serviceName);
    res.status(502).json({ error: "bad gateway", details: e.message });
  }
}

app.use("/api/auth", (req, res) => {
  const path = req.originalUrl.replace(/^\/api\/auth/, "/auth");
  proxyToService("user-service", path, req, res);
});

app.use("/api/users", (req, res) => {
  const path = req.originalUrl.replace(/^\/api\/users/, "/users");
  proxyToService("user-service", path, req, res);
});

app.use("/api/items", (req, res) => {
  const path = req.originalUrl.replace(/^\/api\/items/, "/items");
  proxyToService("item-service", path, req, res);
});

app.use("/api/lists", (req, res) => {
  const path = req.originalUrl.replace(/^\/api\/lists/, "/lists");
  proxyToService("list-service", path, req, res);
});

app.get("/api/media/images/:key", async (req, res) => {
  try {
    const { key } = req.params;
    console.log(`[gateway] Buscando imagem: ${key}`);

    const service = registry.discover("media-service");

    if (!service) {
      console.error("[gateway] media-service não disponível");
      return res.status(503).json({ error: "media-service unavailable" });
    }

    const url = `${service.url}/media/image/${key}`;
    console.log(`[gateway] Proxy para: ${url}`);

    const response = await fetch(url);
    console.log(`[gateway] Response status: ${response.status}`);

    if (!response.ok) {
      const errorText = await response.text();
      console.error(
        `[gateway] Erro ao buscar imagem: ${response.status} - ${errorText}`
      );
      return res
        .status(response.status)
        .json({ error: "image not found", details: errorText });
    }

    const contentType = response.headers.get("content-type");
    console.log(`[gateway] Content-Type: ${contentType}`);
    if (contentType) {
      res.setHeader("content-type", contentType);
    }

    const buffer = await response.buffer();
    console.log(`[gateway] Imagem enviada: ${buffer.length} bytes`);
    res.send(buffer);
  } catch (e) {
    console.error("[gateway] Erro no proxy de imagem:", e.message, e.stack);
    res
      .status(500)
      .json({ error: "failed to fetch image", details: e.message });
  }
});

app.use("/api/media", (req, res) => {
  const path = req.originalUrl.replace(/^\/api\/media/, "/media");
  proxyToService("media-service", path, req, res);
});

app.use("/tasks", (req, res) => {
  req.headers["x-skip-auth"] = "true";
  const path = req.originalUrl.replace(/^\/tasks/, "/lists");
  proxyToService("list-service", path, req, res);
});

app.get("/api/dashboard", async (req, res) => {
  const auth = req.headers.authorization;
  const listSvc = registry.discover("list-service");
  if (!listSvc)
    return res.status(503).json({ error: "list service unavailable" });
  try {
    const r = await fetch(listSvc.url + "/lists", {
      headers: { authorization: auth },
    });
    const lists = await r.json();
    const totalLists = lists.length;
    const totalItems = lists.reduce(
      (s, l) => s + (l.items ? l.items.length : 0),
      0
    );
    const estimatedTotal = lists.reduce(
      (s, l) => s + ((l.summary && l.summary.estimatedTotal) || 0),
      0
    );
    res.json({ totalLists, totalItems, estimatedTotal, lists });
  } catch (e) {
    res.status(500).json({ error: "failed to build dashboard" });
  }
});

app.get("/api/search", async (req, res) => {
  const q = req.query.q || "";
  const itemSvc = registry.discover("item-service");
  const listSvc = registry.discover("list-service");
  const results = { items: [], lists: [] };
  try {
    if (itemSvc) {
      const r = await fetch(itemSvc.url + `/search?q=${encodeURIComponent(q)}`);
      if (r.ok) results.items = await r.json();
    }
    if (listSvc) {
      const r2 = await fetch(listSvc.url + "/lists");
      if (r2.ok) {
        const all = await r2.json();
        results.lists = all.filter((l) =>
          (l.name || "").toLowerCase().includes(q.toLowerCase())
        );
      }
    }
    res.json(results);
  } catch (e) {
    res.status(500).json({ error: "search failed" });
  }
});

app.get("/health", async (req, res) => {
  await registry.healthCheckAll().catch(() => {});
  const reg = registry.list();
  res.json({ gateway: "ok", registry: reg });
});

app.get("/registry", (req, res) => {
  res.json(registry.list());
});

app.listen(PORT, () => console.log(`API Gateway running on ${PORT}`));
