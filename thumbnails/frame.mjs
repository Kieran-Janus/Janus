// Fits any artwork (e.g. an AI-generated render) into Roblox's exact frames.
//
// Usage:
//   node thumbnails/frame.mjs <image> [--name my-game] [--icon-focus 0.7,0.4]
//
// Writes output/<name>/thumbnail-1920x1080.png (16:9) and icon-512x512.png (1:1).
// The thumbnail is centre-cropped to 16:9. The icon is a square crop centred on
// --icon-focus (x,y as 0–1 fractions of the image), default the centre.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { basename, dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch {
  ({ chromium } = require("/opt/node22/lib/node_modules/playwright"));
}

const args = process.argv.slice(2);
const opt = (k) => { const i = args.indexOf(k); return i >= 0 ? args.splice(i, 2)[1] : undefined; };
const name = opt("--name");
const focus = (opt("--icon-focus") || "0.5,0.5").split(",").map(Number);
const src = args[0];
if (!src) {
  console.error("usage: node thumbnails/frame.mjs <image> [--name my-game] [--icon-focus x,y]");
  process.exit(1);
}

const ext = extname(src).slice(1).toLowerCase().replace("jpg", "jpeg");
const dataUrl = `data:image/${ext};base64,${readFileSync(resolve(src)).toString("base64")}`;
const dir = join(dirname(fileURLToPath(import.meta.url)), "output", name || basename(src, extname(src)));
mkdirSync(dir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage();
const results = await page.evaluate(async ({ dataUrl, focus }) => {
  const img = new Image();
  img.src = dataUrl;
  await img.decode();
  const W = img.naturalWidth, H = img.naturalHeight;
  // Crop a w×h box of the given aspect, centred on (fx,fy), clamped inside the image.
  const crop = (aspect, fx, fy) => {
    let w = W, h = W / aspect;
    if (h > H) { h = H; w = H * aspect; }
    const x = Math.min(Math.max(fx * W - w / 2, 0), W - w);
    const y = Math.min(Math.max(fy * H - h / 2, 0), H - h);
    return { x, y, w, h };
  };
  // Downscale in halving steps for clean, sharp results.
  const render = ({ x, y, w, h }, ow, oh) => {
    let c = document.createElement("canvas");
    c.width = w; c.height = h;
    c.getContext("2d").drawImage(img, x, y, w, h, 0, 0, w, h);
    while (c.width / 2 >= ow) {
      const n = document.createElement("canvas");
      n.width = Math.round(c.width / 2); n.height = Math.round(c.height / 2);
      const ctx = n.getContext("2d");
      ctx.imageSmoothingQuality = "high";
      ctx.drawImage(c, 0, 0, n.width, n.height);
      c = n;
    }
    const out = document.createElement("canvas");
    out.width = ow; out.height = oh;
    const ctx = out.getContext("2d");
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(c, 0, 0, ow, oh);
    return out.toDataURL("image/png").split(",")[1];
  };
  return {
    W, H,
    thumb: render(crop(16 / 9, 0.5, 0.5), 1920, 1080),
    icon: render(crop(1, focus[0], focus[1]), 512, 512),
  };
}, { dataUrl, focus });
await browser.close();

writeFileSync(join(dir, "thumbnail-1920x1080.png"), Buffer.from(results.thumb, "base64"));
writeFileSync(join(dir, "icon-512x512.png"), Buffer.from(results.icon, "base64"));
console.log(`source ${results.W}x${results.H} -> ${dir}`);
if (results.W < 1920 || results.H < 1080) console.warn("warning: source is smaller than 1920x1080, so the thumbnail is upscaled and may look soft");
