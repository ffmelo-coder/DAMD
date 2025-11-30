const { spawn } = require("child_process");
const path = require("path");

const services = [
  { name: "user", script: "services/user/index.js" },
  { name: "item", script: "services/item/index.js" },
  { name: "list", script: "services/list/index.js" },
  { name: "gateway", script: "gateway/index.js" },
];

function startService(svc) {
  const p = spawn("node", [svc.script], {
    cwd: path.resolve(__dirname),
    env: Object.assign({}, process.env),
    stdio: ["ignore", "pipe", "pipe"],
  });

  p.stdout.on("data", (d) => {
    process.stdout.write(`[${svc.name}] ${d.toString()}`);
  });
  p.stderr.on("data", (d) => {
    process.stderr.write(`[${svc.name}][ERR] ${d.toString()}`);
  });
  p.on("exit", (code, sig) => {
    console.log(`[${svc.name}] exited code=${code} sig=${sig}`);
  });
  return p;
}

console.log("Starting all services...");
const procs = services.map(startService);

function shutdown() {
  console.log("Shutting down services...");
  procs.forEach((p) => {
    try {
      p.kill("SIGINT");
    } catch (e) {}
  });
  process.exit(0);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

// keep process alive
setInterval(() => {}, 1000);
