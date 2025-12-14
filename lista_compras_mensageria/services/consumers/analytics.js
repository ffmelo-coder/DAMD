const amqp = require("amqplib");

const AMQP_URL =
  process.env.AMQP_URL ||
  process.env.CLOUDAMQP_URL ||
  "amqp://guest:guest@localhost:5672/";
const EXCHANGE = "shopping_events";
const QUEUE = "analytics_worker";

async function run() {
  const conn = await amqp.connect(AMQP_URL);
  const ch = await conn.createChannel();
  await ch.assertExchange(EXCHANGE, "topic", { durable: true });
  await ch.assertQueue(QUEUE, { durable: true });
  await ch.bindQueue(QUEUE, EXCHANGE, "list.checkout.#");
  console.log("Analytics worker waiting for messages...");
  ch.consume(
    QUEUE,
    (msg) => {
      if (!msg) return;
      try {
        const body = JSON.parse(msg.content.toString());
        const listId = body.listId;
        const total = (body.items || []).reduce(
          (s, it) => s + Number(it.estimatedPrice || 0),
          0
        );
        console.log(
          `Analytics: lista [${listId}] total estimado R$ ${total.toFixed(2)}`
        );
        ch.ack(msg);
      } catch (e) {
        console.error("Analytics failed to process message", e);
        ch.nack(msg, false, false);
      }
    },
    { noAck: false }
  );
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
