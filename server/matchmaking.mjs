const LOBBY_TTL_MS = 5 * 60 * 1000;
const SIGNAL_TTL_MS = 30 * 1000;

const state = globalThis.__floorballMatchmaking ??= {
  games: new Map(),
  signals: new Map(),
};

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

function lobby(request, response) {
  cleanup();
  if (request.method === "GET") {
    const games = [...state.games.values()].sort((a, b) => b.createdAt - a.createdAt);
    send(response, 200, games);
    return;
  }
  const body = request.body ?? {};
  if (request.method !== "POST" || !body.action || !body.roomId) {
    send(response, 400, { error: "missing action or roomId" });
    return;
  }
  if (body.action === "register") {
    state.games.set(String(body.roomId), {
      roomId: String(body.roomId).slice(0, 12),
      hostName: String(body.hostName || "Game").trim().slice(0, 35),
      createdAt: Date.now(),
    });
  } else if (body.action === "join") {
    state.games.delete(String(body.roomId));
  } else {
    send(response, 400, { error: "unknown action" });
    return;
  }
  send(response, 200, { ok: true });
}

function signal(request, response) {
  cleanup();
  if (request.method === "GET") {
    const room = query(request.url, "room");
    const role = query(request.url, "role");
    if (!room || !role) {
      send(response, 400, { error: "missing room or role" });
      return;
    }
    const key = `${room}:${role}`;
    const messages = (state.signals.get(key) ?? []).map((entry) => entry.message);
    state.signals.delete(key);
    send(response, 200, messages);
    return;
  }
  const body = request.body ?? {};
  if (request.method !== "POST" || !body.room || !body.role || !body.msg) {
    send(response, 400, { error: "missing room, role, or msg" });
    return;
  }
  const recipient = body.role === "host" ? "client" : "host";
  const key = `${body.room}:${recipient}`;
  const queue = state.signals.get(key) ?? [];
  queue.push({ message: body.msg, createdAt: Date.now() });
  state.signals.set(key, queue.slice(-64));
  send(response, 200, { ok: true });
}

export default function handler(request, response) {
  const endpoint = query(request.url, "endpoint");
  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }
  if (endpoint === "lobby") lobby(request, response);
  else if (endpoint === "signal") signal(request, response);
  else send(response, 404, { error: "unknown matchmaking endpoint" });
}

export function resetForTests() {
  state.games.clear();
  state.signals.clear();
}
