const { spawn } = require("child_process");
const path = require("path");

const services = [
  { name: "user", script: "services/user/index.js" },
  { name: "item", script: "services/item/index.js" },
  { name: "list", script: "services/list/index.js" },
  { name: "media", script: "services/media/index.js" },
  { name: "gateway", script: "gateway/index.js" },
];

function startService(svc) {
  const env = Object.assign({}, process.env);

  if (svc.name === "media") {
    env.GATEWAY_URL = "https://SEU-NGROK-AQUI";
  }

  const p = spawn("node", [svc.script], {
    cwd: path.resolve(__dirname),
    env: env,
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

setInterval(() => {}, 1000);
