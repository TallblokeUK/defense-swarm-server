// Defense Swarm master server: a tiny registry for the in-game server
// browser. Dedicated servers POST /announce every 60s; the game GETs
// /list on the title screen. Entries auto-expire after 3 silent minutes.
export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    const headers = {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/json",
    };
    if (url.pathname === "/announce" && req.method === "POST") {
      let b;
      try {
        b = await req.json();
      } catch {
        return new Response('{"ok":false}', { status: 400, headers });
      }
      // Prefer the server's self-reported IPv4: a v6-preferring VPS
      // announces over IPv6, and listing that address strands every
      // v4-only player. Fall back to the request source IP.
      const ip4 = String(b.ip4 || "");
      const ip =
        /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(ip4)
          ? ip4
          : req.headers.get("CF-Connecting-IP") || "0.0.0.0";
      const port = Math.min(Math.max(parseInt(b.port) || 7777, 1), 65535);
      const meta = {
        ip,
        port,
        name: String(b.name || "Unnamed Swarm Server").slice(0, 40),
        players: Math.min(Math.max(parseInt(b.players) || 0, 0), 99),
        max: Math.min(Math.max(parseInt(b.max) || 5, 1), 99),
        wave: Math.min(Math.max(parseInt(b.wave) || 0, 0), 9999),
        pw: !!b.pw,
        v: String(b.v || "?").slice(0, 16),
        t: Date.now(),
      };
      await env.SERVERS.put(`srv:${ip}:${port}`, "1", {
        expirationTtl: 180,
        metadata: meta,
      });
      return new Response('{"ok":true}', { headers });
    }
    if (url.pathname === "/list") {
      const l = await env.SERVERS.list({ prefix: "srv:", limit: 100 });
      const servers = l.keys.map((k) => k.metadata).filter(Boolean);
      return new Response(JSON.stringify({ servers }), { headers });
    }
    return new Response('{"ok":false,"hint":"POST /announce or GET /list"}', {
      status: 404,
      headers,
    });
  },
};
