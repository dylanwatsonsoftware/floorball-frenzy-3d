import assert from "node:assert/strict";
import handler, { resetForTests } from "../server/matchmaking.mjs";

function request(method, url, body = undefined) {
  return new Promise((resolve) => {
    const response = {
      statusCode: 200,
      headers: {},
      setHeader(name, value) { this.headers[name.toLowerCase()] = value; },
      writeHead(code, headers = {}) { this.statusCode = code; Object.assign(this.headers, headers); },
      end(payload = "") { resolve({ status: this.statusCode, headers: this.headers, body: payload ? JSON.parse(payload) : null }); },
    };
    handler({ method, url, body }, response);
  });
}

resetForTests();
let result = await request("POST", "/api/matchmaking?endpoint=lobby", { action: "register", roomId: "ABC234", hostName: "[G2] Test" });
assert.equal(result.status, 200);
result = await request("GET", "/api/matchmaking?endpoint=lobby");
assert.equal(result.body.length, 1);
assert.equal(result.body[0].roomId, "ABC234");

await request("POST", "/api/matchmaking?endpoint=signal", { room: "ABC234", role: "host", msg: { type: "offer", sdp: "test" } });
result = await request("GET", "/api/matchmaking?endpoint=signal&room=ABC234&role=client");
assert.deepEqual(result.body, [{ type: "offer", sdp: "test" }]);
result = await request("GET", "/api/matchmaking?endpoint=signal&room=ABC234&role=client");
assert.deepEqual(result.body, []);

result = await request("POST", "/api/matchmaking?endpoint=lobby", { action: "join", roomId: "ABC234" });
assert.equal(result.status, 200);
result = await request("GET", "/api/matchmaking?endpoint=lobby");
assert.deepEqual(result.body, []);

console.log("Same-origin matchmaking lobby and signaling relay messages correctly.");
