import { redisCommands } from "./redis_client.mjs";

const LOBBY_TTL_MS = 5 * 60 * 1000;
const SIGNAL_TTL_MS = 30 * 1000;

const state = globalThis.__floorballMatchmaking ??= {
  games: new Map(),
  signals: new Map(),
};

export function backendForEnvironment(environment) {
  return environment.REDIS_URL ? "redis" : "memory";
}

const usesRedis = () => backendForEnvironment(process.env) === "redis";

function cleanup(now = Date.now()) {
  for (const [roomId, entry] of state.games) {
    if (now - entry.createdAt > LOBBY_TTL_MS) state.games.delete(roomId);
  }
  for (const [key, queue] of state.signals) {
    const live = queue.filter((entry) => now - entry.createdAt <= SIGNAL_TTL_MS);
    if (live.length) state.signals.set(key, live);
    else state.signals.delete(key);
  }
}

function query(url, key) {
  return new URL(url, "https://floorball.invalid").searchParams.get(key);
}

function send(response, status, body) {
  response.setHeader("Content-Type", "application/json");
  response.setHeader("Cache-Control", "no-store");
  response.writeHead(status);
  response.end(JSON.stringify(body));
}

async function bodyOf(request) {
  if (request.body && typeof request.body === "object") return request.body;
  let raw = "";
  for await (const chunk of request) raw += chunk.toString();
  if (!raw) return {};
  try { return JSON.parse(raw); }
  catch { return {}; }
}

async function lobby(request, response) {
  cleanup();
  if (request.method === "GET") {
    let games;
    if (usesRedis()) {
      const cutoff = Date.now() - LOBBY_TTL_MS;
      const [, roomIds] = await redisCommands([
        ["ZREMRANGEBYSCORE", "floorball:lobby:index", "-inf", cutoff],
        ["ZREVRANGE", "floorball:lobby:index", 0, -1],
      ]);
      if (roomIds.length) {
        const [entries] = await redisCommands([["MGET", ...roomIds.map((roomId) => `floorball:lobby:game:${roomId}`)]]);
        games = entries.filter(Boolean).map((entry) => JSON.parse(entry));
      } else games = [];
    } else {
      games = [...state.games.values()].sort((a, b) => b.createdAt - a.createdAt);
    }
    send(response, 200, games);
    return;
  }
  const body = await bodyOf(request);
  if (request.method !== "POST" || !body.action || !body.roomId) {
    send(response, 400, { error: "missing action or roomId" });
    return;
  }
  if (body.action === "register") {
    const entry = {
      roomId: String(body.roomId).slice(0, 12),
      hostName: String(body.hostName || "Game").trim().slice(0, 35),
      createdAt: Date.now(),
    };
    if (usesRedis()) {
      await redisCommands([
        ["ZADD", "floorball:lobby:index", entry.createdAt, entry.roomId],
        ["SET", `floorball:lobby:game:${entry.roomId}`, JSON.stringify(entry), "PX", LOBBY_TTL_MS],
      ]);
    } else state.games.set(entry.roomId, entry);
  } else if (body.action === "join") {
    const roomId = String(body.roomId);
    if (usesRedis()) await redisCommands([
      ["ZREM", "floorball:lobby:index", roomId],
      ["DEL", `floorball:lobby:game:${roomId}`],
    ]);
    else state.games.delete(roomId);
  } else {
    send(response, 400, { error: "unknown action" });
    return;
  }
  send(response, 200, { ok: true });
}

async function signal(request, response) {
  cleanup();
  if (request.method === "GET") {
    const room = query(request.url, "room");
    const role = query(request.url, "role");
    if (!room || !role) {
      send(response, 400, { error: "missing room or role" });
      return;
    }
    const key = `${room}:${role}`;
    let messages;
    if (usesRedis()) {
      const script = "local v=redis.call('LRANGE',KEYS[1],0,-1); redis.call('DEL',KEYS[1]); return v";
      const [values] = await redisCommands([["EVAL", script, 1, `floorball:signal:${key}`]]);
      messages = values.map((value) => JSON.parse(value));
    } else {
      messages = (state.signals.get(key) ?? []).map((entry) => entry.message);
      state.signals.delete(key);
    }
    send(response, 200, messages);
    return;
  }
  const body = await bodyOf(request);
  if (request.method !== "POST" || !body.room || !body.role || !body.msg) {
    send(response, 400, { error: "missing room, role, or msg" });
    return;
  }
  const recipient = body.role === "host" ? "client" : "host";
  const key = `${body.room}:${recipient}`;
  if (usesRedis()) {
    const redisKey = `floorball:signal:${key}`;
    await redisCommands([
      ["RPUSH", redisKey, JSON.stringify(body.msg)],
      ["LTRIM", redisKey, -64, -1],
      ["PEXPIRE", redisKey, SIGNAL_TTL_MS],
    ]);
  } else {
    const queue = state.signals.get(key) ?? [];
    queue.push({ message: body.msg, createdAt: Date.now() });
    state.signals.set(key, queue.slice(-64));
  }
  send(response, 200, { ok: true });
}

export default async function handler(request, response) {
  const endpoint = query(request.url, "endpoint");
  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }
  if (endpoint === "lobby") await lobby(request, response);
  else if (endpoint === "signal") await signal(request, response);
  else send(response, 404, { error: "unknown matchmaking endpoint" });
}

export function resetForTests() {
  state.games.clear();
  state.signals.clear();
}
