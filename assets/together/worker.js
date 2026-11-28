// Kyndrel Watch Together relay (task 9.11): a Cloudflare Worker with one
// Durable Object per room. It speaks the same messages as Kyndrel's own
// room server (lib/core/net/together_server.dart), and the room protocol of
// Harbor's relay (HarborCommunity/Harbor, MIT): hello/joined,
// participant-joined/left, host, state, cmd, chat, ping/pong. It relays
// nothing else and keeps no data once a room empties.
const VERSION = 1;
const ROOM_PATH = /^\/r\/([A-Z0-9]{4,8})$/;

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === "/" || url.pathname === "/health") {
      return new Response(JSON.stringify({ ok: true, kyndrel: true, version: VERSION }), {
        headers: { "content-type": "application/json" },
      });
    }
    const m = url.pathname.match(ROOM_PATH);
    if (!m) return new Response("not found", { status: 404 });
    if (req.headers.get("upgrade") !== "websocket") {
      return new Response("expected websocket", { status: 426 });
    }
    return env.ROOM.get(env.ROOM.idFromName(m[1])).fetch(req);
  },
};

export class Room {
  constructor(state) {
    this.state = state;
    this.peers = new Map();
    this.syncState = null;
    this.host = null;
    for (const ws of state.getWebSockets()) {
      const p = ws.deserializeAttachment();
      if (p && p.id) this.peers.set(ws, p);
    }
  }

  async fetch() {
    const pair = new WebSocketPair();
    this.state.acceptWebSocket(pair[1]);
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  webSocketMessage(ws, data) {
    let msg;
    try {
      msg = JSON.parse(typeof data === "string" ? data : new TextDecoder().decode(data));
    } catch {
      return;
    }
    this.onMessage(ws, msg);
  }

  webSocketClose(ws) {
    this.leave(ws);
  }

  webSocketError(ws) {
    this.leave(ws);
  }

  send(ws, msg) {
    try {
      ws.send(JSON.stringify(msg));
    } catch {}
  }

  broadcast(msg, except) {
    const text = JSON.stringify(msg);
    for (const ws of this.peers.keys()) {
      if (ws === except) continue;
      try {
        ws.send(text);
      } catch {}
    }
  }

  onMessage(ws, msg) {
    const now = Date.now();
    const peer = this.peers.get(ws);
    switch (msg.t) {
      case "hello": {
        if (typeof msg.clientId !== "string" || !msg.clientId) return;
        const p = { id: msg.clientId, name: String(msg.name || "Guest").slice(0, 32), joinedAt: now };
        for (const [s, q] of this.peers) {
          if (q.id === p.id && s !== ws) {
            this.peers.delete(s);
            try {
              s.close(1000, "replaced");
            } catch {}
          }
        }
        this.peers.set(ws, p);
        ws.serializeAttachment(p);
        const becameHost = !this.host;
        if (becameHost) this.host = p.id;
        this.send(ws, {
          t: "joined",
          participants: [...this.peers.values()],
          state: this.syncState,
          hostClientId: this.host,
          srvAt: now,
        });
        this.broadcast({ t: "participant-joined", participant: p }, ws);
        if (becameHost) this.broadcast({ t: "host", hostClientId: this.host });
        return;
      }
      case "state": {
        const s = msg.state;
        if (!peer || peer.id !== this.host || !s) return;
        if (typeof s.positionSeconds !== "number" || s.positionSeconds < 0) return;
        if (typeof s.playing !== "boolean") return;
        this.syncState = { ...s, srvAt: now };
        this.broadcast({ t: "state", state: this.syncState, from: peer.id }, ws);
        return;
      }
      case "cmd": {
        const c = msg.command;
        if (!peer || !c || !this.host || peer.id === this.host) return;
        if (!["play", "pause", "seek"].includes(c.action)) return;
        if (c.action === "seek" && typeof c.positionSeconds !== "number") return;
        for (const [s, q] of this.peers) {
          if (q.id === this.host) this.send(s, { t: "cmd", from: peer.id, command: c });
        }
        return;
      }
      case "chat": {
        if (!peer || typeof msg.text !== "string" || !msg.text.trim()) return;
        this.broadcast({ t: "chat", from: peer.id, name: peer.name, text: msg.text.slice(0, 500), at: now });
        return;
      }
      case "ping":
        this.send(ws, { t: "pong", srvAt: now });
        return;
    }
  }

  leave(ws) {
    const p = this.peers.get(ws);
    if (!p) return;
    this.peers.delete(ws);
    this.broadcast({ t: "participant-left", id: p.id });
    if (p.id === this.host) {
      const next = [...this.peers.values()].sort((a, b) => a.joinedAt - b.joinedAt)[0];
      this.host = next ? next.id : null;
      this.broadcast({ t: "host", hostClientId: this.host });
    }
    if (this.peers.size === 0) this.syncState = null;
  }
}
