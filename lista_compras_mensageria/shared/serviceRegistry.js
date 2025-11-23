const fs = require("fs");
const path = require("path");
const fetch = require("node-fetch");

const REGISTRY_FILE = path.join(
  __dirname,
  "..",
  "data",
  "service-registry.json"
);
function ensureRegistry() {
  const dir = path.dirname(REGISTRY_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  if (!fs.existsSync(REGISTRY_FILE))
    fs.writeFileSync(REGISTRY_FILE, JSON.stringify({}, null, 2));
}

function load() {
  ensureRegistry();
  return JSON.parse(fs.readFileSync(REGISTRY_FILE, "utf8") || "{}");
}

function save(reg) {
  fs.writeFileSync(REGISTRY_FILE, JSON.stringify(reg, null, 2));
}

function registerService(name, info) {
  const reg = load();
  reg[name] = reg[name] || [];
  // avoid duplicates by url
  if (!reg[name].find((s) => s.url === info.url)) {
    reg[name].push(
      Object.assign({ registeredAt: Date.now(), healthy: true }, info)
    );
    save(reg);
  }
}

function unregisterService(name, url) {
  const reg = load();
  if (!reg[name]) return;
  reg[name] = reg[name].filter((s) => s.url !== url);
  if (reg[name].length === 0) delete reg[name];
  save(reg);
}

function discover(serviceName) {
  const reg = load();
  if (!reg[serviceName] || reg[serviceName].length === 0) return null;
  // return first healthy
  const healthy = reg[serviceName].filter((s) => s.healthy);
  return healthy[0] || reg[serviceName][0] || null;
}

function list() {
  return load();
}

async function healthCheckAll() {
  const reg = load();
  const names = Object.keys(reg);
  for (const name of names) {
    for (const inst of reg[name]) {
      try {
        const url = new URL(inst.url);
        const healthUrl = inst.healthPath
          ? new URL(inst.healthPath, inst.url).toString()
          : new URL("/health", inst.url).toString();
        const res = await fetch(healthUrl, { timeout: 5000 });
        inst.healthy = res.ok;
      } catch (e) {
        inst.healthy = false;
      }
    }
  }
  save(reg);
}

// start periodic health checks
setInterval(() => {
  healthCheckAll().catch(() => {});
}, 30 * 1000);

process.on("exit", () => {
  // no-op cleanup: in real environment we'd unregister
});

module.exports = {
  registerService,
  unregisterService,
  discover,
  list,
  healthCheckAll,
};
