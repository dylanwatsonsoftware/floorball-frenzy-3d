import assert from "node:assert/strict";
import { encodeCommand, parseResponse } from "../server/redis_client.mjs";

assert.equal(
  encodeCommand(["SET", "room:ABC", "hello"]),
  "*3\r\n$3\r\nSET\r\n$8\r\nroom:ABC\r\n$5\r\nhello\r\n",
);
assert.deepEqual(parseResponse("*2\r\n$5\r\noffer\r\n$6\r\nanswer\r\n").value, ["offer", "answer"]);
assert.equal(parseResponse("$-1\r\n").value, null);
assert.equal(parseResponse(":3\r\n").value, 3);

console.log("Redis RESP commands and responses are encoded safely.");
