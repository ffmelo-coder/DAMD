const amqp = require("amqplib");

const url =
  process.env.AMQP_URL ||
  process.env.CLOUDAMQP_URL ||
  "amqp://guest:guest@localhost:5672/";

(async () => {
  console.log("Testing AMQP URL:", url);
  try {
    const conn = await amqp.connect(url);
    console.log("Connected to broker");
    try {
      const ch = await conn.createChannel();
      console.log("Channel created");
      await ch.close();
    } catch (e) {
      console.error("Channel error:", e);
    }
    await conn.close();
    process.exit(0);
  } catch (err) {
    console.error("Connection error:");
    console.error(err);
    process.exit(2);
  }
})();
