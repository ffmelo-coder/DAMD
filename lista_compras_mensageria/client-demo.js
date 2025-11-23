const fetch = require("node-fetch");

const GATEWAY = process.env.GATEWAY_URL || "http://localhost:3000";

async function run() {
  console.log("Client demo starting...");
  // 1. register
  const email = `demo+${Date.now()}@example.com`;
  const registerResp = await fetch(`${GATEWAY}/api/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, username: "demouser", password: "secret" }),
  });
  const reg = await registerResp.json();
  console.log("registered", reg.user);

  // 2. login
  const loginResp = await fetch(`${GATEWAY}/api/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: "secret" }),
  });
  const login = await loginResp.json();
  const token = login.token;
  console.log("logged in, token length", token && token.length);

  // 3. search items
  const search = await (await fetch(`${GATEWAY}/api/search?q=arroz`)).json();
  console.log("search results (items):", (search.items || []).slice(0, 3));

  // 4. create list
  const listResp = await fetch(`${GATEWAY}/api/lists`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer " + token,
    },
    body: JSON.stringify({ name: "Compras semanais" }),
  });
  const list = await listResp.json();
  console.log("created list", list.id);

  // 5. add item to list (use first item from search if present)
  if (search.items && search.items.length > 0) {
    const itemId = search.items[0].id;
    const addResp = await fetch(`${GATEWAY}/api/lists/${list.id}/items`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: "Bearer " + token,
      },
      body: JSON.stringify({ itemId, quantity: 2 }),
    });
    const added = await addResp.json();
    console.log("added item", added);
  }

  // 6. dashboard
  const dash = await (
    await fetch(`${GATEWAY}/api/dashboard`, {
      headers: { authorization: "Bearer " + token },
    })
  ).json();
  console.log("dashboard", dash);

  // 7. checkout the list to trigger async processing (messaging)
  try {
    console.log('Triggering checkout for list', list.id);
    const checkoutResp = await fetch(`${GATEWAY}/api/lists/${list.id}/checkout`, {
      method: 'POST',
      headers: { authorization: 'Bearer ' + token },
    });
    const checkoutRes = await checkoutResp.json().catch(() => ({}));
    console.log('Checkout response', checkoutResp.status, checkoutRes);

    // wait a few seconds to allow workers to process and show logs
    console.log('Waiting 5 seconds for consumers to process...');
    await new Promise(r => setTimeout(r, 5000));
    console.log('Done waiting — if workers are running you should see their logs now.');
  } catch (e) {
    console.error('Checkout failed', e.message || e);
  }
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
