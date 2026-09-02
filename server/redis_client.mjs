import net from "node:net";
import tls from "node:tls";

export function encodeCommand(parts) {
  return `*${parts.length}\r\n${parts.map((part) => {
    const value = String(part);
    return `$${Buffer.byteLength(value)}\r\n${value}\r\n`;
  }).join("")}`;
}

export function parseResponse(source, offset = 0) {
  const lineEnd = source.indexOf("\r\n", offset);
  if (lineEnd < 0) throw new Error("Incomplete Redis response");
  const prefix = source[offset];
  const line = source.slice(offset + 1, lineEnd);
  let cursor = lineEnd + 2;
  if (prefix === "+") return { value: line, offset: cursor };
  if (prefix === "-") throw new Error(`Redis error: ${line}`);
  if (prefix === ":") return { value: Number(line), offset: cursor };
  if (prefix === "$") {
    const length = Number(line);
    if (length < 0) return { value: null, offset: cursor };
    if (source.length < cursor + length + 2) throw new Error("Incomplete Redis bulk response");
    return { value: source.slice(cursor, cursor + length), offset: cursor + length + 2 };
  }
  if (prefix === "*") {
    const values = [];
    for (let index = 0; index < Number(line); index++) {
      const parsed = parseResponse(source, cursor);
      values.push(parsed.value);
      cursor = parsed.offset;
    }
    return { value: values, offset: cursor };
  }
  throw new Error(`Unknown Redis response prefix: ${prefix}`);
}

export function redisCommands(commands, connectionUrl = process.env.REDIS_URL) {
  if (!connectionUrl) throw new Error("REDIS_URL is not configured");
  const url = new URL(connectionUrl);
  const auth = url.password
    ? [["AUTH", decodeURIComponent(url.username || "default"), decodeURIComponent(url.password)]]
    : [];
  const allCommands = [...auth, ...commands];
  const payload = allCommands.map(encodeCommand).join("");
  return new Promise((resolve, reject) => {
    const options = { host: url.hostname, port: Number(url.port || (url.protocol === "rediss:" ? 6380 : 6379)), servername: url.hostname };
    const socket = url.protocol === "rediss:" ? tls.connect(options) : net.connect(options);
    let response = "";
    const finishIfComplete = () => {
      try {
        const values = [];
        let offset = 0;
        for (let index = 0; index < allCommands.length; index++) {
          const parsed = parseResponse(response, offset);
          values.push(parsed.value);
          offset = parsed.offset;
        }
        socket.end();
        resolve(values.slice(auth.length));
      } catch (error) {
        if (!String(error.message).startsWith("Incomplete")) {
          socket.destroy();
          reject(error);
        }
      }
    };
    socket.setTimeout(5000, () => socket.destroy(new Error("Redis connection timed out")));
    socket.on("connect", () => socket.write(payload));
    socket.on("data", (chunk) => { response += chunk.toString("utf8"); finishIfComplete(); });
    socket.on("error", reject);
  });
}
