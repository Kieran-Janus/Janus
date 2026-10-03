// Generates a cinematic thumbnail with OpenAI's image API, then fits it to Roblox frames.
//
// Needs: OPENAI_API_KEY in the environment, and network access to api.openai.com.
// Usage:  node thumbnails/generate.mjs survive-halloween [--icon-focus 0.7,0.45]
//         node thumbnails/generate.mjs 2v2-sword-tycoon
// Prompts come from the ``` blocks in PROMPTS.md (matched by the "## <Title>" heading).
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

const ROOT = dirname(fileURLToPath(import.meta.url));
const [slug, ...rest] = process.argv.slice(2);
const HEADINGS = { "survive-halloween": "Survive Halloween", "2v2-sword-tycoon": "2v2 Sword Tycoon" };
if (!HEADINGS[slug]) {
  console.error(`usage: node thumbnails/generate.mjs <${Object.keys(HEADINGS).join("|")}> [--icon-focus x,y]`);
  process.exit(1);
}
if (!process.env.OPENAI_API_KEY) {
  console.error("OPENAI_API_KEY is not set in this environment.");
  process.exit(1);
}

const md = readFileSync(join(ROOT, "PROMPTS.md"), "utf8");
const section = md.split(/^## /m).find((s) => s.startsWith(HEADINGS[slug]));
const prompt = section.match(/```\n([\s\S]*?)```/)[1].trim();

const res = await fetch("https://api.openai.com/v1/images/generations", {
  method: "POST",
  headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
  body: JSON.stringify({
    model: process.env.OPENAI_IMAGE_MODEL || "gpt-image-1",
    prompt,
    size: "1536x1024", // largest landscape size; frame.mjs crops it to 16:9
    quality: "high",
    n: 1,
  }),
});
if (!res.ok) {
  console.error(`OpenAI API error ${res.status}: ${await res.text()}`);
  process.exit(1);
}
const { data } = await res.json();
const rawDir = join(ROOT, "source");
mkdirSync(rawDir, { recursive: true });
const raw = join(rawDir, `${slug}-${Date.now()}.png`);
writeFileSync(raw, Buffer.from(data[0].b64_json, "base64"));
console.log("generated", raw);

execFileSync("node", [join(ROOT, "frame.mjs"), raw, "--name", slug, ...rest], { stdio: "inherit" });
