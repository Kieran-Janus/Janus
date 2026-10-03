// Cloudflare Worker: tiny proxy between Roblox and the Anthropic API.
// Why: keeps your Anthropic key off Roblox, lets you rate-limit/cap cost, and swap models in one place.
//
// Deploy:
//   cd tools/ai-proxy && npx wrangler deploy
//   npx wrangler secret put ANTHROPIC_API_KEY
//   npx wrangler secret put PROXY_KEY        # same value you store in Roblox Secrets as AI_PROXY_KEY
// Then put the worker URL (…/chat) into src/shared/Config.luau -> AI.ProxyUrl.

const MODEL = "claude-haiku-4-5-20251001"; // fast + cheap for NPC chat; change to a bigger model for smarter NPCs
const MAX_TOKENS_CAP = 300;

export default {
	async fetch(request, env) {
		if (request.method !== "POST") return new Response("POST only", { status: 405 });
		if (request.headers.get("x-proxy-key") !== env.PROXY_KEY) {
			return new Response("unauthorized", { status: 401 });
		}

		let body;
		try {
			body = await request.json();
		} catch {
			return new Response("bad json", { status: 400 });
		}

		const upstream = await fetch("https://api.anthropic.com/v1/messages", {
			method: "POST",
			headers: {
				"content-type": "application/json",
				"x-api-key": env.ANTHROPIC_API_KEY,
				"anthropic-version": "2023-06-01",
			},
			body: JSON.stringify({
				model: env.MODEL || MODEL,
				max_tokens: Math.min(body.max_tokens || 150, MAX_TOKENS_CAP),
				system: String(body.system || "").slice(0, 2000),
				messages: (body.messages || []).slice(-10),
			}),
		});

		if (!upstream.ok) return new Response("upstream error", { status: 502 });
		const data = await upstream.json();
		const reply = (data.content || []).map((b) => b.text || "").join("");
		return Response.json({ reply });
	},
};
