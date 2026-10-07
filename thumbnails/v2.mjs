// Pumpkin Panic store art, v2: Roblox thumbnails (1920x1080) and the icon (512x512) made from
// renders of the REAL game (the lobby, the round maps and the skins, built by the game's own
// code in the new-game test harness), with titles composited in headless Chromium.
//
// Usage (from the repo root):
//   node thumbnails/v2.mjs                     scenes -> renders -> images (about 4 minutes)
//   node thumbnails/v2.mjs --only 02,icon      just these images (ids or file-name prefixes)
//   node thumbnails/v2.mjs --reuse             reuse scenes/renders already in the work folder
//   node thumbnails/v2.mjs --compose           only redo titles and layout (implies --reuse)
//
// Needs (cloud tooling, not in this repo): Lune (LUNE, default /tmp/claude-0/tools/lune, else
// `lune` on PATH) and the offline scene previewer (ROBLOX_PREVIEW_RENDERER, default
// /tmp/claude-0/render/render.mjs; its export.luau sits next to it). Playwright + Chromium for
// the compositing. Work files (scene JSONs, raw renders, small previews) go to V2_WORK
// (default new-game/tests/out/thumbnails-v2, git-ignored).
//
// Pipeline per image:
//   1. thumbnails/v2-scene.luau builds the scene: HubBuilder (lobby) or MapService (round map)
//      plus posed mannequins wearing real skins (Cosmetics.Wear), the candy gun, ScareMaze actors.
//   2. The previewer renders it from a cinematic camera, plus flat "mask" passes (parts painted
//      white or black, no lights): where the sky is (for the dusk sky, stars and the moon), a
//      cut-out subject (the icon), and which parts of a sign are in view.
//   3. HTML/CSS lays the art over it: titles, the in-game sign texts (SurfaceGuis, which the
//      previewer doesn't draw) projected onto their parts, effects. Chromium screenshots at 2x.
// Every claim in the text comes from Config (facts.json: skin count, one-in-a-million skins).
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync, statSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch {
  ({ chromium } = require("/opt/node22/lib/node_modules/playwright"));
}

const HERE = dirname(fileURLToPath(import.meta.url)); // thumbnails/
const REPO = join(HERE, "..");
const OUT = join(HERE, "output", "pumpkin-panic-v2");
const WORK = process.env.V2_WORK || join(REPO, "new-game", "tests", "out", "thumbnails-v2");
const LUNE = process.env.LUNE || (existsSync("/tmp/claude-0/tools/lune") ? "/tmp/claude-0/tools/lune" : "lune");
const RENDERER = process.env.ROBLOX_PREVIEW_RENDERER || "/tmp/claude-0/render/render.mjs";
const EXPORTER = join(dirname(RENDERER), "export.luau");

const argv = process.argv.slice(2);
const flag = (k) => argv.includes(k);
const opt = (k) => { const i = argv.indexOf(k); return i >= 0 ? argv[i + 1] : undefined; };
const COMPOSE_ONLY = flag("--compose");
const REUSE = COMPOSE_ONLY || flag("--reuse") || flag("--try");
const ONLY = (opt("--only") || "").split(",").filter(Boolean);

for (const d of [OUT, WORK, join(WORK, "scenes"), join(WORK, "renders"), join(WORK, "preview")]) mkdirSync(d, { recursive: true });

const log = (...a) => console.log("[v2]", ...a);
const rel = (p) => relative(REPO, p) || ".";

// ------------------------------------------------------------------ helpers
const readJSON = (p) => JSON.parse(readFileSync(p, "utf8"));
const writeJSON = (p, v) => writeFileSync(p, JSON.stringify(v));
const dataUrl = (p) => `data:image/png;base64,${readFileSync(p).toString("base64")}`;
const font = (name) => `data:font/woff2;base64,${readFileSync(join(HERE, "fonts", `${name}.woff2`)).toString("base64")}`;
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function lune(spec, name) {
  const specPath = join(WORK, "scenes", `${name}.spec.json`);
  writeJSON(specPath, { exporter: EXPORTER, ...spec });
  execFileSync(LUNE, ["run", "thumbnails/v2-scene", "--", specPath], { cwd: REPO, stdio: ["ignore", "inherit", "inherit"] });
}

function rng(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ------------------------------------------------------------------ 3D maths (Roblox = three.js world)
const sub = (a, b) => a.map((v, i) => v - b[i]);
const add = (a, b) => a.map((v, i) => v + b[i]);
const mul = (a, k) => a.map((v) => v * k);
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = (a) => { const l = Math.hypot(...a); return a.map((v) => v / l); };

// Where a world point lands in a render: the previewer's camera looks at the target with +Y up
// and a vertical field of view (three.js PerspectiveCamera). Returns [x, y, depth].
function projector(r) {
  const [C, T] = r.camera.split("->").map((s) => s.split(",").map(Number));
  const [W, H] = r.size;
  const f = norm(sub(T, C)), right = norm(cross(f, [0, 1, 0])), up = cross(right, f);
  const k = H / 2 / Math.tan(((r.fov || 70) * Math.PI) / 360);
  return (P) => {
    const d = sub(P, C), z = dot(d, f);
    return [W / 2 + (dot(d, right) / z) * k, H / 2 - (dot(d, up) / z) * k, z];
  };
}

// A part's CFrame (cframe = [x, y, z, R00..R22], row-major): world position of a local point.
const partPoint = (p, l) => {
  const c = p.cframe;
  return [c[0] + c[3] * l[0] + c[4] * l[1] + c[5] * l[2], c[1] + c[6] * l[0] + c[7] * l[1] + c[8] * l[2], c[2] + c[9] * l[0] + c[10] * l[1] + c[11] * l[2]];
};

// SurfaceGui faces: outward normal, and the text's right (u) and up (v) directions, in part space.
// Top: words run along the part's depth (Z), as src/server/Hub/FloorSigns.luau relies on.
const FACES = {
  Front: { n: [0, 0, -1], u: [-1, 0, 0], v: [0, 1, 0] },
  Back: { n: [0, 0, 1], u: [1, 0, 0], v: [0, 1, 0] },
  Right: { n: [1, 0, 0], u: [0, 0, -1], v: [0, 1, 0] },
  Left: { n: [-1, 0, 0], u: [0, 0, 1], v: [0, 1, 0] },
  Top: { n: [0, 1, 0], u: [0, 0, -1], v: [-1, 0, 0] },
  Bottom: { n: [0, -1, 0], u: [0, 0, 1], v: [-1, 0, 0] },
};
const sizeAlong = (s, a) => Math.abs(a[0]) * s.x + Math.abs(a[1]) * s.y + Math.abs(a[2]) * s.z;

// The four corners (top-left, top-right, bottom-right, bottom-left) of a label's face, in world space.
function labelQuad(scene, label) {
  const holder = label.path.split(".").slice(0, -2).join(".");
  const F = FACES[label.face || "Front"];
  if (!F) return null;
  const L = label.position;
  let best = null, bestD = Infinity;
  for (const p of scene.parts) {
    if (p.path !== holder) continue;
    const c = partPoint(p, mul(F.n, sizeAlong(p.size, F.n) / 2));
    const d = Math.hypot(c[0] - L.x, c[1] - L.y, c[2] - L.z);
    if (d < bestD) { bestD = d; best = p; }
  }
  if (!best || bestD > 1) return null;
  const su = sizeAlong(best.size, F.u) / 2, sv = sizeAlong(best.size, F.v) / 2, sn = sizeAlong(best.size, F.n) / 2;
  const corner = (a, b) => partPoint(best, add(add(mul(F.n, sn + 0.02), mul(F.u, a * su)), mul(F.v, b * sv)));
  return { part: best, corners: [corner(-1, 1), corner(1, 1), corner(1, -1), corner(-1, -1)], aspect: su / sv };
}

// CSS matrix3d that maps a w x h box onto the screen quad q (Heckbert's square-to-quad).
function quadMatrix(w, h, q) {
  const [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] = q;
  const sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3;
  const dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
  const det = dx1 * dy2 - dx2 * dy1;
  const g = (sx * dy2 - dx2 * sy) / det, hh = (dx1 * sy - sx * dy1) / det;
  const a = x1 - x0 + g * x1, b = x3 - x0 + hh * x3, c = x0;
  const d = y1 - y0 + g * y1, e = y3 - y0 + hh * y3, f = y0;
  return `matrix3d(${[a / w, d / w, 0, g / w, b / h, e / h, 0, hh / h, 0, 0, 1, 0, c, f, 0, 1].map((v) => +v.toFixed(8)).join(",")})`;
}

// ------------------------------------------------------------------ facts (from Config)
// (always counted again, except with --compose: a second, and a Config change shows straight away)
function facts() {
  const p = join(WORK, "facts.json");
  if (!(COMPOSE_ONLY && existsSync(p))) lune({ facts: p }, "facts");
  return readJSON(p);
}

// ------------------------------------------------------------------ scenes
// Mannequin poses: armL/armR = [swing forward, lift sideways] degrees, legL/legR = swing forward.
const CHEER = { armL: [0, 150], armR: [0, 150] };
const WAVE = { armL: [0, 12], armR: [0, 160] };
const WAVE_L = { armL: [0, 160], armR: [0, 12] };
const RUN = { armL: [60, 8], armR: [-50, 8], legL: -35, legR: 40 };
const RUN2 = { armL: [-50, 8], armR: [60, 8], legL: 40, legR: -35 };
const JUMP = { armL: [20, 140], armR: [20, 140], legL: 35, legR: -10 };
const near = (p, x0, x1, z0, z1) => p.cframe[0] > x0 && p.cframe[0] < x1 && p.cframe[2] > z0 && p.cframe[2] < z1;

const SCENES = {
  // The lobby from the spawn: the Ready circle under its pumpkin arch, the clock tower behind.
  hero: {
    base: "hub",
    characters: [
      { skin: "Pumpkin_MegaGourdSupreme", at: [0.5, 1.7, 47.5], yaw: 182, pose: CHEER },
      { skin: "Candy_CottonCandyCat", at: [-4.6, 1.7, 45.6], yaw: 165, pose: WAVE },
      { skin: "Graveyard_SkellySuperstar", at: [5.2, 1.7, 45.2], yaw: 200, pose: WAVE_L },
      // two players by the spawn stone, close to the camera
      { skin: "CandyFactory_FrostingFiend", at: [-8.2, 1, 66.5], face: [-3, 86], pose: JUMP },
      { skin: "WitchsBrew_GrandWitch", at: [7.6, 1, 65.8], face: [-3, 86], pose: WAVE },
    ],
  },
  // The Tormented Tower (inside the clock tower): two players at its doorway, looking up.
  towerOut: {
    base: "hub",
    characters: [
      { skin: "Candy_BubblegumBat", at: [-1.6, 1.8, -34], face: [0, -60], pose: { armL: [0, 12], armR: [160, 0] } },
      { skin: "AutumnLeaves_HarvestSpirit", at: [2.3, 1.8, -34], face: [-2, -60], pose: { armL: [0, 25], armR: [0, 25] } },
    ],
    // a path lamp, a bench and the middle signpost between the camera and the door
    drop: (p) => /Decor\.(PathLamps|Benches|Signposts)/.test(p.path) && near(p, -16, 24, -30, -6),
  },
  // Pumpkin Farm (Hide & Seek): one of these pumpkins is a player. The seeker has the candy gun.
  farm: {
    base: "map:PumpkinFarm",
    characters: [
      // in the gap between two rows of decoys, looking the wrong way
      { skin: "CandyFactory_CandyTycoon", at: [25, 0.75, 1061.4], face: [64, 1056], pose: { armL: [10, 8], armR: [88, 0] }, tool: "CandyGun" },
    ],
  },
  // ScareMaze at night: two Survivors run, a ghost and bats jump out of the corn.
  maze: {
    base: "map:ScareMaze",
    characters: [
      { skin: "Candy_CottonCandyCat", at: [-89.4, 0.5, 1050], face: [-90, 1064], lean: 12, pose: RUN },
      { skin: "CursedToys_ToyBoxTerror", at: [-93.2, 0.5, 1041], face: [-91, 1064], lean: 12, pose: RUN2 },
    ],
    props: [
      { kind: "Ghost", at: [-96.2, 1.8, 1055], yaw: 215 },
      { kind: "Bat", at: [-87.4, 5.4, 1057], yaw: 200 },
      { kind: "Bat", at: [-86.4, 7.6, 1055.5], yaw: 160 },
      { kind: "Bat", at: [-93.6, 7.6, 1050], yaw: 150 },
    ],
  },
  // The crate CRAZY skins and the three ONE IN A MILLION skins (middle) at the crate stand.
  skins: {
    base: "hub",
    characters: [
      { skin: "VampireCastle_NightLordSupreme", at: [31, 1, 1.4], face: [6, 6], pose: { armL: [0, 20], armR: [0, 150] } },
      { skin: "MonsterDisco_DiscoDemon", at: [31.6, 1, 6.2], face: [6, 6], pose: CHEER },
      { skin: "AlienAbduction_StarVoyager", at: [31, 1, 11], face: [6, 6], pose: { armL: [0, 150], armR: [0, 20] } },
      { skin: "Candy_SugarRushSupreme", at: [29.8, 1, -3.5], face: [6, 6], pose: WAVE },
      { skin: "Monster_GloopGalaxy", at: [29.8, 1, 15.9], face: [6, 6], pose: WAVE_L },
      { skin: "Pumpkin_MegaGourdSupreme", at: [28, 1, -8.3], face: [6, 6], pose: CHEER },
      { skin: "Graveyard_SkellySuperstar", at: [28, 1, 20.7], face: [6, 6], pose: CHEER },
    ],
    // a path lamp, a bench and bunting between the camera and the line-up
    drop: (p) => /Decor\.(PathLamps|Benches|Bunting)/.test(p.path) && near(p, 8, 25, -12, 24),
    // the previewer gives the smooth floor-sign pad a white moon glint at this grazing angle
    tweak: (p) => (/FloorSigns\.CratesFloorSign$/.test(p.path) ? { ...p, material: "Plastic" } : null),
  },
  // The lobby minigames: parkour (behind the clock tower), Candy Rush and Web Scour.
  games: {
    base: "hub",
    characters: [
      // parkour: on the first pumpkins, one mid-jump, and two up on the Candy Sky platforms
      // (heights: the pumpkin and candy tops, e.g. Step 29's candy disc is at y = 50.55)
      { skin: "Pumpkin_SirGourdington", at: [10, 6.35, -70.1], face: [40, -46], pose: WAVE },
      { skin: "Monster_Sparky", at: [14.4, 9.2, -71.8], face: [18.5, -73.3], pose: JUMP },
      { skin: "Spooky_PotionMaster", at: [12.3, 50.55, -72.4], face: [30, -60], pose: CHEER },
      { skin: "Candy_BubblegumBat", at: [17.2, 53.4, -74.4], face: [21.8, -77], lean: 10, pose: JUMP },
      // Candy Rush: three racers on the join pads (lanes 2-4), reaching for their candies
      { skin: "Candy_CottonCandyCat", at: [-58, 1.7, 3], yaw: 90, pose: { armL: [0, 10], armR: [115, 0] } },
      { skin: "MonsterDisco_DanceKing", at: [-58, 1.7, -3], yaw: 90, pose: { armL: [115, 0], armR: [0, 10] } },
      { skin: "Graveyard_GlowBones", at: [-58, 1.7, -9], yaw: 90, pose: { armL: [0, 10], armR: [115, 0] } },
      // Web Scour: hunting critters in the Spider Grove
      { skin: "SwampCreatures_FrogKing", at: [-31.5, 1, -26], face: [-42, -34], yaw: 55, pose: { armL: [0, 10], armR: [100, 30] } },
    ],
    props: [
      // the racers' candies on the board (each lane is 6 studs wide, the board's front is x = -68.2)
      { kind: "Candy", candy: "Lollipop", color: 1, at: [-67, 12.4, 2.2], yaw: 270 },
      { kind: "Candy", candy: "Wrapped", color: 5, at: [-67, 8, -3.6], yaw: 270, roll: 18 },
      { kind: "Candy", candy: "CandyCorn", at: [-67, 13.6, -8.4], yaw: 270 },
    ],
  },
  hub: { base: "hub" },
};

// Cache: with --reuse, a scene or render is only redone when what it was made from changed.
const keyOf = (v) => JSON.stringify(v, (k, x) => (x instanceof RegExp || typeof x === "function" ? String(x) : x));
function cached(path, key) {
  if (!existsSync(path)) return false;
  if (COMPOSE_ONLY) return true;
  const keyPath = `${path}.key`;
  return REUSE && existsSync(keyPath) && readFileSync(keyPath, "utf8") === key;
}
const markDone = (path, key) => writeFileSync(`${path}.key`, key);

const builtScenes = new Set();
function buildScene(name) {
  const path = join(WORK, "scenes", `${name}.json`);
  const def = SCENES[name];
  const key = keyOf(def);
  if (builtScenes.has(name) || cached(path, key)) return path;
  builtScenes.add(name);
  lune({ out: path, base: def.base, characters: def.characters || [], props: def.props || [] }, name);
  if (def.drop || def.tweak) {
    const s = readJSON(path);
    if (def.drop) s.parts = s.parts.filter((p) => !def.drop(p));
    if (def.tweak) s.parts = s.parts.map((p) => def.tweak(p) || p);
    writeJSON(path, s);
  }
  markDone(path, key);
  return path;
}

// ------------------------------------------------------------------ renders
// One render = one camera on one scene.
//   flags     extra previewer options
//   soften    0-1: mix in a pass without bloom, so glowing skins keep their details
//   sky       also render where the sky is (for the dusk sky, stars and the moon)
//   only/cut  render only these parts (RegExp on the path) and cut them out (the icon)
//   signs     in-game texts to draw on their parts: [{ text: RegExp, font, stroke, glow }]
//   points    named spots to find: { name: { nearest: RegExp on part paths, to: [x, y, z] } }
const RENDERS = {
  hero: {
    scene: "hero", camera: "-3,6.2,86->1,25,-40", fov: 52, size: [1920, 1080], sky: true,
    signs: [{ text: /^PLAY!$/, font: "Lilita", stroke: 0.3 }, { text: /READY\? STEP IN/, font: "Lilita", stroke: 0.4, glow: true }],
  },
  towerOut: {
    scene: "towerOut", camera: "5,2.2,-13->-1,34,-47", fov: 74, size: [1920, 1080], sky: true,
    signs: [{ text: /TORMENTED TOWER/, font: "Lilita", stroke: 0.4, glow: true }],
  },
  farm: {
    scene: "farm", camera: "-6,9.5,1076->30,0,1044", fov: 50, size: [1920, 1080], sky: true,
    points: { hider: { nearest: /PumpkinFields\.Field1\.Pumpkin\.Body$/, to: [13.1, 2, 1064.6] } },
    // the hider's glow (Config.HideSeek.Effects.GlowOutline), as in the last seconds of a round
    highlight: { point: "hider", path: /PumpkinFields/, radius: 2.8, color: "#ffe6a0" },
  },
  maze: { scene: "maze", camera: "-90.6,4.4,1066->-91,7.2,1030", fov: 64, size: [1920, 1080], sky: true, flags: ["--exposure", "1.3", "--min-ambient", "0.32"] },
  skins: {
    scene: "skins", camera: "3,10.5,6.5->44,6.8,6.5", fov: 46, size: [1920, 1080], sky: true, soften: 0.55,
    flags: ["--light-scale", "0.35", "--min-ambient", "0.45"],
    signs: [{ text: /^MYSTERY CRATES$/, path: /SignBoard/, font: "Creepster", glow: true }],
  },
  parkour: { scene: "games", camera: "28,47,-58->15,52,-74", fov: 62, size: [820, 1080], sky: true },
  candy: {
    scene: "games", camera: "-38,7.5,-2->-66,13,-1", fov: 60, size: [820, 1080], sky: true,
    signs: [
      { text: /^CANDY RUSH$/, path: /SignBoard/, font: "Lilita", region: [0.02, 0.04, 0.96, 0.62] },
      { text: /first to grab/, font: "Lilita", region: [0.06, 0.66, 0.88, 0.28] },
      { text: /^CANDY RUSH$/, path: /FloorSign/, font: "Lilita", stroke: 0.4, glow: true },
    ],
  },
  web: {
    scene: "games", camera: "-18,6,-14->-38,12,-34", fov: 62, size: [820, 1080], sky: true,
    signs: [{ text: /^WEB SCOUR$/, font: "Lilita", stroke: 0.4, glow: true }, { text: /critters/, font: "Lilita" }],
  },
  // the icon: the Pumpkin King statue by the clock tower (Config.Hub.Polish.KingStatue), face on,
  // and the clock tower on its own, both cut out
  iconKing: { scene: "hub", camera: "20.6,12,-35->26,15.6,-44", fov: 44, size: [1024, 1024], only: /KingStatue/, cut: true },
  iconTower: { scene: "hub", camera: "0,30,60->2,40,-47", fov: 38, size: [1024, 1024], only: /ClockTower|TowerParkour/, cut: true },
};

// Flat passes: every part white (sky: scenery vs sky; cut: the subject), or only some white and
// the rest black (signs: which bits of a sign are in view).
function flatScene(s, white) {
  const m = { ...s, lights: [], effects: [], labels: [] };
  m.parts = s.parts.map((p) => ({ ...p, color: white(p) ? [1, 1, 1] : [0, 0, 0], material: "Neon", transparency: 0, reflectance: 0 }));
  const allWhite = white === ALL;
  m.terrain = (Array.isArray(s.terrain) ? s.terrain : []).map((t) => ({ ...t, color: allWhite ? [1, 1, 1] : [0, 0, 0] }));
  m.lighting = { ClockTime: 0, Brightness: 0, Ambient: [1, 1, 1], OutdoorAmbient: [1, 1, 1] };
  return m;
}
const ALL = () => true;

function sceneFor(name) {
  const r = RENDERS[name];
  let s = readJSON(buildScene(r.scene));
  if (r.only) {
    s = { ...s, parts: s.parts.filter((p) => r.only.test(p.path)), terrain: [] };
  }
  return s;
}

const renderCache = {};
function renderOne(name) {
  if (renderCache[name]) return renderCache[name];
  const r = RENDERS[name];
  const dir = join(WORK, "renders", name);
  mkdirSync(dir, { recursive: true });
  const scene = sceneFor(name);
  const scenePath = join(dir, "scene.json");
  const project = projector(r);

  // the signs this camera sees
  const signs = [];
  for (const sel of r.signs || []) {
    for (const l of Array.isArray(scene.labels) ? scene.labels : []) {
      if (!sel.text.test(l.text) || (sel.path && !sel.path.test(l.path))) continue;
      const q = labelQuad(scene, l);
      if (!q) continue;
      const pts = q.corners.map(project);
      const facing = dot(sub(q.corners[0], r.camera.split("->")[0].split(",").map(Number)), cross(sub(q.corners[1], q.corners[0]), sub(q.corners[3], q.corners[0]))) > 0;
      if (pts.some((p) => p[2] < 0.5) || !facing) continue;
      signs.push({ ...sel, text: l.text, color: l.color, part: q.part, quad: pts.map((p) => [p[0], p[1]]), aspect: q.aspect });
    }
  }
  // named spots
  const points = {};
  for (const [k, def] of Object.entries(r.points || {})) {
    let best = null, bestD = Infinity;
    for (const p of scene.parts) {
      if (!def.nearest.test(p.path)) continue;
      const d = Math.hypot(...sub(p.cframe.slice(0, 3), def.to));
      if (d < bestD) { bestD = d; best = p; }
    }
    if (best) points[k] = { world: best.cframe.slice(0, 3), size: best.size, screen: project(best.cframe.slice(0, 3)), top: project(add(best.cframe.slice(0, 3), [0, best.size.y / 2, 0])) };
  }

  const out = { r, signs, points, png: {} };
  const passes = [["main", null, r.flags || []]];
  if (r.soften) passes.push(["soft", null, [...(r.flags || []), "--no-bloom"]]);
  if (r.sky) passes.push(["sky", ALL, null]);
  if (r.cut) passes.push(["cut", ALL, null]);
  if (signs.length) {
    const ids = new Set(signs.map((s) => s.part));
    passes.push(["signs", (p) => ids.has(p), null]);
  }
  // highlight: the parts of one thing (near a named point) for a glow drawn round it
  if (r.highlight && points[r.highlight.point]) {
    const P = points[r.highlight.point].world, hl = r.highlight;
    passes.push(["hl", (p) => hl.path.test(p.path) && Math.hypot(...sub(p.cframe.slice(0, 3), P)) < hl.radius, null]);
  }
  const common = ["--views", "custom", "--camera", r.camera, "--fov", String(r.fov), "--size", r.size.join("x"), "--no-caption", "--no-compass", "--quiet"];
  const flatFlags = ["--no-bloom", "--no-fog", "--no-shadows", "--no-effects", "--no-patterns", "--min-ambient", "1"];
  const sceneKey = existsSync(`${join(WORK, "scenes", `${r.scene}.json`)}.key`) ? readFileSync(`${join(WORK, "scenes", `${r.scene}.json`)}.key`, "utf8") : "";
  let wroteScene = false;
  for (const [pass, white, flags] of passes) {
    const png = join(dir, pass, "custom.png");
    out.png[pass] = png;
    const key = keyOf({ r, pass, sceneKey, signs: pass === "signs" ? signs.map((s) => s.part.cframe) : null });
    if (!builtScenes.has(r.scene) && cached(png, key)) continue;
    if (!wroteScene) { writeJSON(scenePath, scene); wroteScene = true; log(`render ${name} (${r.camera}, fov ${r.fov})`); }
    let src = scenePath;
    if (white) {
      src = join(dir, `${pass}.json`);
      writeJSON(src, flatScene(scene, white));
    }
    execFileSync("node", [RENDERER, src, join(dir, pass), ...common, ...(white ? flatFlags : flags)], { stdio: "inherit" });
    markDone(png, key);
  }
  renderCache[name] = out;
  return out;
}

// ------------------------------------------------------------------ design system (HTML/CSS)
const INK = "#1b0a2a"; // outlines: a very dark purple instead of black
const GRAD = {
  pumpkin: ["#ffe45c", "#ff7a00"], panic: ["#f6e2ff", "#a64dff"], white: ["#ffffff", "#ffe9a8"],
  gold: ["#fff6a8", "#ffb800"], green: ["#e4ff9a", "#3de04a"], red: ["#ffd2c2", "#ff3b3b"],
  pink: ["#ffe0f6", "#ff4fc3"], teal: ["#e6fffb", "#25e0c8"], orange: ["#fff0b0", "#ff8a1a"],
};

const CSS = `
@font-face{font-family:Luckiest;src:url(${font("luckiest-guy")})}
@font-face{font-family:Creepster;src:url(${font("creepster")})}
@font-face{font-family:Lilita;src:url(${font("lilita-one")})}
@font-face{font-family:Bangers;src:url(${font("bangers")})}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#000}
.frame{position:relative;overflow:hidden;background:#140a26}
.abs{position:absolute}
.fill{position:absolute;inset:0;width:100%;height:100%}
.box{position:absolute;overflow:hidden}
.box>img{position:absolute;left:0;top:0;width:100%;height:100%}
.t{position:absolute;display:grid;white-space:nowrap;line-height:.92}
.t>span{grid-area:1/1;display:block}
.t>.f{-webkit-background-clip:text;background-clip:text;color:transparent}
.badge{position:absolute;white-space:nowrap;display:flex;align-items:center;justify-content:center}
.badge>span{font-family:Luckiest;color:#fff;paint-order:stroke fill;line-height:1;padding-top:.09em}
.sign{position:absolute;left:0;top:0;transform-origin:0 0}
.slot{position:absolute;display:flex;align-items:center;justify-content:center;text-align:center}
.slot>span{display:block;line-height:1.02;paint-order:stroke fill;white-space:pre-line}
`;

// Big chunky text: a dark outline layer with a 3D extrude, a gradient fill and a shine on top.
function txt(text, o) {
  const { x, y, size, font: f = "Luckiest", fill = GRAD.white, stroke = 0.17, depth = 0.1, depthColor = "#4a1470", rot = 0, align = "left", glow = "", spacing = 0, shine = true } = o;
  const sw = Math.round(size * stroke), d = Math.max(2, Math.round(size * depth));
  const shadows = [];
  for (let i = 1; i <= d; i += 2) shadows.push(`0 ${i}px 0 ${depthColor}`);
  shadows.push(`0 ${d + 4}px 0 ${INK}`, `0 ${d + 10}px 24px rgba(0,0,0,.55)`);
  const base = `font-family:${f};font-size:${size}px;letter-spacing:${spacing}em;`;
  const tx = align === "center" ? "translateX(-50%) " : align === "right" ? "translateX(-100%) " : "";
  const fillBg = `${shine ? "linear-gradient(180deg,rgba(255,255,255,.5) 0%,rgba(255,255,255,0) 38%)," : ""}linear-gradient(180deg,${fill[0]} 18%,${fill[1]} 88%)`;
  return `<div class="t" style="left:${x}px;top:${y}px;transform:${tx}rotate(${rot}deg);transform-origin:${align === "center" ? "50%" : align === "right" ? "100%" : "0"} 50%;${glow ? `filter:drop-shadow(0 0 ${glow[1] || 30}px ${glow[0]});` : ""}">
    <span style="${base}color:${INK};-webkit-text-stroke:${sw}px ${INK};text-shadow:${shadows.join(",")}">${text}</span>
    <span class="f" style="${base}background-image:${fillBg}">${text}</span></div>`;
}

// A sticker: rounded label with a thick dark border.
function badge(text, o) {
  const { x, y, size = 56, bg = ["#c15bff", "#6413c2"], rot = -3, align = "left", color = "#fff", glow = "rgba(180,77,255,.7)", pad = [0.32, 0.55] } = o;
  const tx = align === "center" ? "translateX(-50%) " : align === "right" ? "translateX(-100%) " : "";
  return `<div class="badge" style="left:${x}px;top:${y}px;transform:${tx}rotate(${rot}deg);padding:${pad[0] * size}px ${pad[1] * size}px;
      background:linear-gradient(180deg,${bg[0]},${bg[1]});border:${Math.round(size * 0.13)}px solid ${INK};border-radius:${Math.round(size * 0.42)}px;
      box-shadow:0 ${Math.round(size * 0.14)}px 0 ${INK},0 0 ${Math.round(size * 0.7)}px ${glow},inset 0 ${Math.round(size * 0.12)}px 0 rgba(255,255,255,.35)">
    <span style="font-size:${size}px;color:${color};-webkit-text-stroke:${Math.round(size * 0.16)}px ${INK}">${text}</span></div>`;
}

// The game's logo: PUMPKIN (orange) over PANIC (purple), as in v1, chunkier.
function logo({ x, y, size = 190, rot = -4, align = "left", gap = -0.2 }) {
  const lh = size * (1 + gap);
  return txt("PUMPKIN", { x, y, size, font: "Creepster", fill: GRAD.pumpkin, rot, align, stroke: 0.15, depth: 0.08, depthColor: "#7a2a00", glow: ["rgba(255,120,0,.55)", 34], spacing: 0.02 })
    + txt("PANIC", { x: x + (align === "left" ? size * 0.42 : 0), y: y + lh, size: size * 1.04, font: "Creepster", fill: GRAD.panic, rot, align, stroke: 0.15, depth: 0.08, depthColor: "#2e0b52", glow: ["rgba(170,70,255,.55)", 34], spacing: 0.03 });
}

// The lobby's dusk sky (Config.Hub.Lighting: ClockTime 19.4, a purple sky with an orange glow):
// a gradient, drifting purple clouds (Lighting.Clouds), stars and the big moon (MoonAngularSize).
const DUSK = [[0, "#120828"], [0.34, "#2e1260"], [0.6, "#6a2a8c"], [0.78, "#c4508c"], [0.92, "#ff9a55"]];
function skyFx({ w, h, seed = 7, stars = 160, moon, starTop = 0, starBottom = 0.6, grad, horizon = 1, clouds = 0 }) {
  const r = rng(seed);
  let s = "";
  if (grad) s += `<div class="fill" style="background:linear-gradient(180deg,${grad.map(([p, c]) => `${c} ${(p * horizon * 100).toFixed(1)}%`).join(",")})"></div>`;
  for (let i = 0; i < clouds; i++) {
    const cx = r() * w, cy = (0.08 + r() * 0.4) * h * horizon, cw = (0.18 + r() * 0.22) * w, ch = cw * (0.12 + r() * 0.08);
    s += `<div class="abs" style="left:${cx - cw / 2}px;top:${cy - ch / 2}px;width:${cw}px;height:${ch}px;border-radius:50%;background:radial-gradient(ellipse closest-side,rgba(186,150,224,.34),rgba(186,150,224,0));filter:blur(${ch * 0.18}px)"></div>`;
  }
  for (let i = 0; i < stars; i++) {
    const sx = r() * w, sy = (starTop + r() * (starBottom - starTop)) * h, z = r();
    const sz = z > 0.93 ? 4.2 : z > 0.7 ? 2.8 : 1.8;
    s += `<div class="abs" style="left:${sx}px;top:${sy}px;width:${sz}px;height:${sz}px;border-radius:50%;background:#fff;opacity:${0.45 + r() * 0.55};box-shadow:0 0 ${sz * 3}px rgba(255,255,255,.9)"></div>`;
  }
  if (moon) s += moonDisc(...moon);
  return s;
}

function moonDisc(mx, my, mr) {
  const crater = (u, v, k, a) => `<div class="abs" style="left:${mr + u * mr - k * mr / 2}px;top:${mr + v * mr - k * mr / 2}px;width:${k * mr}px;height:${k * mr}px;border-radius:50%;background:radial-gradient(circle closest-side,rgba(226,182,120,${a}) 60%,rgba(226,182,120,0) 100%)"></div>`;
  return `<div class="abs" style="left:${mx - mr * 3}px;top:${my - mr * 3}px;width:${mr * 6}px;height:${mr * 6}px;background:radial-gradient(circle closest-side,rgba(255,214,140,.5) 0%,rgba(255,170,90,.2) 38%,rgba(255,150,80,.07) 62%,rgba(255,150,80,0) 100%)"></div>
    <div class="abs" style="left:${mx - mr}px;top:${my - mr}px;width:${mr * 2}px;height:${mr * 2}px;border-radius:50%;overflow:hidden;
      background:radial-gradient(circle at 36% 32%,#fffef6 0%,#fff3cc 48%,#ffd98e 100%)">
      ${crater(-0.35, -0.2, 0.34, 0.45)}${crater(0.3, 0.32, 0.26, 0.4)}${crater(0.42, -0.38, 0.14, 0.45)}${crater(-0.12, 0.52, 0.16, 0.35)}${crater(-0.6, 0.25, 0.12, 0.35)}</div>`;
}

// Sparkle puff: Hide & Seek's "giggle" (Config.HideSeek.Effects.SparkleColor) that gives a hider away.
function sparkle(x, y, k = 1, color = "#ffe68c") {
  let s = `<div class="abs" style="left:${x - 110 * k}px;top:${y - 110 * k}px;width:${220 * k}px;height:${220 * k}px;border-radius:50%;background:radial-gradient(circle closest-side,${color}aa 0%,${color}33 45%,${color}00 100%)"></div>`;
  const star = (sx, sy, sz, rot) => `<svg class="abs" style="left:${sx - sz / 2}px;top:${sy - sz / 2}px;transform:rotate(${rot}deg);filter:drop-shadow(0 0 ${sz / 5}px ${color})" width="${sz}" height="${sz}" viewBox="-10 -10 20 20"><path d="M0 -10 L2.2 -2.2 L10 0 L2.2 2.2 L0 10 L-2.2 2.2 L-10 0 L-2.2 -2.2Z" fill="#fffbe6"/></svg>`;
  s += star(x, y, 74 * k, 0) + star(x - 78 * k, y + 24 * k, 36 * k, 20) + star(x + 70 * k, y - 38 * k, 44 * k, -10) + star(x + 46 * k, y + 56 * k, 28 * k, 8) + star(x - 40 * k, y - 66 * k, 26 * k, 30) + star(x + 96 * k, y + 16 * k, 20 * k, 0) + star(x - 100 * k, y - 20 * k, 18 * k, 15);
  return s;
}

// A render with its layers, in the render's own pixel space, placed at (x, y).
//   sky: skyFx options (or null); grade: CSS filter; signs drawn and masked to where they show.
function renderBox(key, R, { x = 0, y = 0, grade = "saturate(1.25) contrast(1.08) brightness(1.06)", sky = null, soften } = {}) {
  const [w, h] = R.r.size;
  const mix = soften ?? R.r.soften ?? 0;
  let s = `<div class="box" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px">
    <img data-img="${key}:main" style="filter:${grade}">`;
  if (mix && R.png.soft) s += `<img data-img="${key}:soft" style="filter:${grade};opacity:${mix}">`;
  if (R.png.hl) {
    // like the game's Highlight (FillTransparency 0.7, OutlineTransparency 0.25): a light fill
    // and a glowing outline round the shape
    const c = R.r.highlight.color;
    s += `<div class="fill" data-mask="${key}:hl" data-soften="1" style="background:${c};opacity:.3;mix-blend-mode:screen"></div>
      <div class="fill" data-mask="${key}:hl" data-ring="7" data-soften="1" style="background:${c};opacity:.95"></div>
      <div class="fill" data-mask="${key}:hl" data-ring="22" data-soften="6" style="background:${c};opacity:.55;mix-blend-mode:screen"></div>`;
  }
  if (sky && R.png.sky) s += `<div class="fill" data-mask="${key}:sky" data-invert="1" data-soften="1.4">${skyFx({ w, h, ...sky })}</div>`;
  if (R.signs.length) {
    s += `<div class="fill" data-mask="${key}:signs" data-soften="0.6">`;
    for (const sg of R.signs) {
      const W0 = 1000, H0 = Math.round(W0 / sg.aspect);
      const c = `rgb(${(sg.color || [1, 1, 1]).map((v) => Math.round(v * 255)).join(",")})`;
      // TextStrokeTransparency t: a dark outline (Roblox draws it outside the letters)
      const stroke = sg.stroke != null ? `-webkit-text-stroke:.07em rgba(0,0,0,${(1 - sg.stroke).toFixed(2)});` : "";
      const glow = sg.glow ? `text-shadow:0 0 .1em ${c},0 0 .3em ${c};` : "";
      const [rx, ry, rw, rh] = sg.region || [0.03, 0.07, 0.94, 0.86];
      s += `<div class="sign" style="width:${W0}px;height:${H0}px;transform:${quadMatrix(W0, H0, sg.quad)}">
        <div class="slot" style="left:${rx * W0}px;top:${ry * H0}px;width:${rw * W0}px;height:${rh * H0}px">
        <span data-fit style="font-family:${sg.font || "Creepster"};color:${sg.textColor || c};${stroke}${glow}">${esc(sg.text)}</span></div></div>`;
    }
    s += `</div>`;
  }
  return s + `</div>`;
}

// ------------------------------------------------------------------ page + screenshots
let pageCount = 0;
function page({ w, h, body, renders }) {
  const imgs = {};
  for (const [k, R] of Object.entries(renders)) {
    for (const pass of Object.keys(R.png || {})) if (R.png?.[pass] && existsSync(R.png[pass])) imgs[`${k}:${pass}`] = dataUrl(R.png[pass]);
  }
  // setContent reuses the window object, so each page waits for its own token
  const token = `page${++pageCount}`;
  return { token, html: `<!doctype html><html><head><meta charset="utf-8"><style>${CSS}</style></head><body>
  <div class="frame" style="width:${w}px;height:${h}px">${body}</div>
  <script>(() => { // a function scope: the window (and its globals) outlives setContent
    window.READY = "";
    const IMGS = ${JSON.stringify(imgs)};
    const load = (src) => new Promise((ok, no) => { const i = new Image(); i.onload = () => ok(i); i.onerror = no; i.src = src; });
    // a flat pass -> alpha mask (white parts = 1; invert = the dark sky instead;
    // ring = a glowing band of that width round the shape, like Roblox's Highlight outline)
    async function alpha(key, invert, soften, ring) {
      const m = await load(IMGS[key]);
      const c = document.createElement("canvas"); c.width = m.width; c.height = m.height;
      const g = c.getContext("2d"); g.drawImage(m, 0, 0);
      const d = g.getImageData(0, 0, c.width, c.height), p = d.data;
      for (let i = 0; i < p.length; i += 4) {
        const l = (p[i] * 0.3 + p[i + 1] * 0.59 + p[i + 2] * 0.11) / 255;
        let a = Math.min(1, Math.max(0, (l - 0.25) / 0.45));
        if (invert) a = 1 - a;
        p[i] = p[i + 1] = p[i + 2] = 255; p[i + 3] = Math.round(a * 255);
      }
      g.putImageData(d, 0, 0);
      if (ring) {
        const c3 = document.createElement("canvas"); c3.width = c.width; c3.height = c.height;
        const g3 = c3.getContext("2d"); g3.filter = "blur(" + ring + "px)"; g3.drawImage(c, 0, 0);
        const d3 = g3.getImageData(0, 0, c.width, c.height), q = d3.data;
        for (let i = 0; i < q.length; i += 4) q[i + 3] = Math.round(Math.min(1, (q[i + 3] / 255) * 2.6) * (1 - p[i + 3] / 255) * 255);
        g.putImageData(d3, 0, 0);
      }
      if (!soften) return c.toDataURL();
      const c2 = document.createElement("canvas"); c2.width = c.width; c2.height = c.height;
      const g2 = c2.getContext("2d"); g2.filter = "blur(" + soften + "px)"; g2.drawImage(c, 0, 0);
      return c2.toDataURL();
    }
    async function prepare() {
      for (const el of document.querySelectorAll("[data-img]")) el.src = IMGS[el.dataset.img] || "";
      for (const el of document.querySelectorAll("[data-mask]")) {
        if (!IMGS[el.dataset.mask]) { el.remove(); continue; }
        const url = await alpha(el.dataset.mask, el.dataset.invert === "1", Number(el.dataset.soften || 0), Number(el.dataset.ring || 0));
        el.style.webkitMaskImage = el.style.maskImage = "url(" + url + ")";
        el.style.webkitMaskSize = el.style.maskSize = "100% 100%";
      }
      await Promise.all([...document.images].map((i) => i.decode().catch(() => {})));
      await document.fonts.ready;
      // TextScaled: the biggest size that fits the sign (words may wrap, like TextWrapped)
      for (const el of document.querySelectorAll("[data-fit]")) {
        const box = el.parentElement, bw = box.clientWidth, bh = box.clientHeight;
        let lo = 4, hi = bh;
        for (let i = 0; i < 18; i++) {
          const mid = (lo + hi) / 2; el.style.fontSize = mid + "px";
          if (el.scrollWidth <= bw && el.offsetHeight <= bh) lo = mid; else hi = mid;
        }
        el.style.fontSize = lo + "px";
      }
      await new Promise((ok) => requestAnimationFrame(() => requestAnimationFrame(ok)));
      window.READY = "${token}";
    }
    prepare();
  })();</script></body></html>` };
}

// ------------------------------------------------------------------ the images
const W = 1920, H = 1080;
const vignette = (strength = 0.55, cx = "50%", cy = "45%") => `<div class="fill" style="background:radial-gradient(ellipse at ${cx} ${cy},rgba(0,0,0,0) 45%,rgba(10,2,20,${strength}) 100%)"></div>`;
const topShade = (h = 420, a = 0.55) => `<div class="abs" style="left:0;top:0;width:100%;height:${h}px;background:linear-gradient(180deg,rgba(20,6,38,${a}),rgba(20,6,38,0))"></div>`;
const bottomShade = (h = 300, a = 0.6) => `<div class="abs" style="left:0;bottom:0;width:100%;height:${h}px;background:linear-gradient(0deg,rgba(20,6,38,${a}),rgba(20,6,38,0))"></div>`;
// a small logo so every image carries the brand
const cornerLogo = (x = 44, y = 26, size = 82, align = "left") => logo({ x, y, size, rot: -4, align });

// Icon layout (512 px canvas): [left, top, size] of each cut-out render, the moon [x, y, r] and
// the glow behind the King [x, y, r]. Keep the face big and centred: Roblox rounds the corners.
const ICON = { tower: [58, -52, 580], king: [46, 116, 420], moon: [96, 98, 54], glow: [256, 330, 230], bats: [[176, 64, 0.7, -12], [62, 176, 0.5, 10]] };

// A bat silhouette (the lobby's clock tower has real bats flapping round its roof).
const bat = (x, y, k, rot = 0) => `<svg class="abs" style="left:${x - 40 * k}px;top:${y - 14 * k}px;transform:rotate(${rot}deg)" width="${80 * k}" height="${28 * k}" viewBox="-40 -10 80 28"><path d="M0 4 C-8 -6 -22 -10 -40 -4 C-32 0 -30 6 -32 10 C-24 6 -16 8 -12 14 C-8 8 -4 8 0 10 C4 8 8 8 12 14 C16 8 24 6 32 10 C30 6 32 0 40 -4 C22 -10 8 -6 0 4Z M-5 -2 L-4 -9 L-1 -4 L1 -4 L4 -9 L5 -2Z" fill="#12061f"/></svg>`;

const SHOTS = [
  {
    id: "01", file: "01-main.png", renders: ["hero"],
    compose: (F, R) => `
      ${renderBox("hero", R.hero, { grade: "saturate(1.3) contrast(1.08) brightness(1.08)", sky: { seed: 11, stars: 150, moon: [1530, 215, 108], starBottom: 0.5, grad: DUSK, horizon: 0.72, clouds: 7 } })}
      ${topShade(430, 0.38)}${vignette(0.45)}${bottomShade(240, 0.5)}
      ${logo({ x: 70, y: 22, size: 205, rot: -5 })}
      ${badge("SURVIVE THE PUMPKIN KING!", { x: W / 2, y: 908, size: 68, rot: -2, align: "center", bg: ["#ff9a2e", "#e04e00"], glow: "rgba(255,140,40,.75)" })}`,
  },
  {
    id: "02", file: "02-tormented-tower.png", renders: ["towerOut"],
    compose: (F, R) => `
      ${renderBox("towerOut", R.towerOut, { grade: "saturate(1.25) contrast(1.1) brightness(1.06)", sky: { seed: 21, stars: 170, moon: [1450, 250, 96], starBottom: 0.75, grad: DUSK, horizon: 1.25, clouds: 6 } })}
      ${vignette(0.5, "50%", "40%")}${topShade(380, 0.4)}${bottomShade(240, 0.45)}
      ${txt("CAN YOU", { x: 60, y: 70, size: 150, fill: GRAD.white, rot: -6, depthColor: "#7a0f1c" })}
      ${txt("CLIMB IT?", { x: 60, y: 225, size: 178, fill: GRAD.red, rot: -6, depthColor: "#5a0a14", glow: ["rgba(255,60,60,.5)", 30] })}
      ${badge("TORMENTED TOWER", { x: 1880, y: 942, size: 54, rot: 3, align: "right", bg: ["#ff4b4b", "#a3001c"], glow: "rgba(255,60,70,.7)" })}
      ${cornerLogo(1880, 26, 74, "right")}`,
  },
  {
    id: "03", file: "03-hide-and-seek.png", renders: ["farm"],
    compose: (F, R) => {
      const h = R.farm.points.hider;
      return `
      ${renderBox("farm", R.farm, { grade: "saturate(1.22) contrast(1.06) brightness(1.05)", sky: { seed: 31, stars: 30, starBottom: 0.25, clouds: 5, horizon: 0.6 } })}
      ${topShade(400, 0.45)}${vignette(0.4)}
      ${h ? sparkle(h.top[0], h.top[1] - 20, 1.1) : ""}
      ${txt("HIDE AS A", { x: W / 2, y: 40, size: 120, align: "center", fill: GRAD.white, rot: -3, depthColor: "#7a3300" })}
      ${txt("PUMPKIN!", { x: W / 2, y: 160, size: 200, align: "center", fill: GRAD.pumpkin, rot: -3, depthColor: "#7a2a00", glow: ["rgba(255,140,0,.45)", 30] })}
      ${cornerLogo(1880, 940, 70, "right")}`;
    },
  },
  {
    id: "04", file: "04-scaremaze.png", renders: ["maze"],
    compose: (F, R) => `
      ${renderBox("maze", R.maze, { grade: "saturate(1.3) contrast(1.1) brightness(1.1)", sky: { seed: 41, stars: 170, moon: [1590, 165, 88], starBottom: 0.5, grad: [[0, "#0d0820"], [0.5, "#24124a"], [0.9, "#4a2a6e"]], horizon: 0.55, clouds: 4 } })}
      ${vignette(0.6)}${topShade(360, 0.45)}
      ${txt("DON'T STOP", { x: W / 2, y: 36, size: 150, align: "center", fill: GRAD.white, rot: -3, depthColor: "#0d4a2a" })}
      ${txt("MOVING!", { x: W / 2, y: 186, size: 190, align: "center", fill: GRAD.green, rot: -3, depthColor: "#0b3a1a", glow: ["rgba(90,255,120,.45)", 30] })}
      ${badge("SCAREMAZE", { x: 60, y: 950, size: 56, rot: -3, bg: ["#5fe36a", "#127a2a"], glow: "rgba(90,255,120,.6)" })}
      ${cornerLogo(1880, 940, 70, "right")}`,
  },
  {
    id: "05", file: "05-skins.png", renders: ["skins"],
    compose: (F, R) => {
      const n = F.skins % 10 === 0 ? `${F.skins}` : `${Math.floor(F.skins / 10) * 10}+`;
      return `
      ${renderBox("skins", R.skins, { grade: "saturate(1.25) contrast(1.08) brightness(1.08)", sky: { seed: 51, stars: 110, starBottom: 0.4, grad: DUSK, horizon: 0.55, clouds: 5 } })}
      ${topShade(330, 0.45)}${vignette(0.45)}
      ${txt(`${n} SKINS!`, { x: W / 2, y: 26, size: 180, align: "center", fill: GRAD.gold, rot: -3, depthColor: "#7a3d00", glow: ["rgba(255,200,40,.45)", 34] })}
      ${badge("1 IN A MILLION", { x: W / 2, y: 912, size: 64, rot: -2, align: "center", bg: ["#ff5fd2", "#9b12c9"], glow: "rgba(255,80,220,.8)" })}
      ${cornerLogo(44, 948, 62, "left")}`;
    },
  },
  {
    id: "06", file: "06-minigames.png", renders: ["parkour", "candy", "web"],
    compose: (F, R) => {
      // three slanted panels; each render is centred on its panel
      const cut = 90;
      const clips = [
        `polygon(0 0,${640 + cut}px 0,640px ${H}px,0 ${H}px)`,
        `polygon(${640 + cut}px 0,${1280 + cut}px 0,1280px ${H}px,640px ${H}px)`,
        `polygon(${1280 + cut}px 0,${W}px 0,${W}px ${H}px,1280px ${H}px)`,
      ];
      const boxes = [-68, 550, 1190];
      const panel = (i, key, seed) => `
        <div class="fill" style="clip-path:${clips[i]}">
          ${renderBox(key, R[key], { x: boxes[i], grade: "saturate(1.3) contrast(1.08) brightness(1.08)", sky: { seed, stars: 90, starBottom: 0.45, grad: DUSK, horizon: 0.6, clouds: 3 } })}
          <div class="fill" style="background:linear-gradient(0deg,rgba(18,6,34,.85) 0%,rgba(18,6,34,0) 32%)"></div>
        </div>`;
      const seam = (x0, x1) => `<svg class="abs" style="left:0;top:0" width="${W}" height="${H}"><line x1="${x0}" y1="0" x2="${x1}" y2="${H}" stroke="${INK}" stroke-width="22"/><line x1="${x0}" y1="0" x2="${x1}" y2="${H}" stroke="#ff9a2e" stroke-width="7"/></svg>`;
      return `
        ${panel(0, "parkour", 61)}${panel(1, "candy", 62)}${panel(2, "web", 63)}
        ${seam(640 + cut, 640)}${seam(1280 + cut, 1280)}
        ${txt("PARKOUR", { x: 330, y: 930, size: 96, align: "center", fill: GRAD.gold, rot: -3, depthColor: "#6a3a00" })}
        ${txt("CANDY RUSH", { x: 960, y: 930, size: 92, align: "center", fill: GRAD.pink, rot: -3, depthColor: "#6a0a4a" })}
        ${txt("WEB SCOUR", { x: 1610, y: 930, size: 92, align: "center", fill: GRAD.green, rot: -3, depthColor: "#0d4a1a" })}
        ${cornerLogo(W / 2, 22, 72, "center")}`;
    },
  },
  {
    id: "icon", file: "icon-512.png", size: [512, 512], renders: ["iconKing", "iconTower"],
    // the King's glowing face in front of his crooked clock tower, under a big moon
    compose: (F, R, o = ICON) => `
      <div class="fill" style="background:radial-gradient(circle at 50% 38%,#8a3fd6 0%,#45177e 42%,#1a0736 100%)"></div>
      ${skyFx({ w: 512, h: 512, seed: 5, stars: 46, starBottom: 0.75, moon: o.moon })}
      ${o.bats.map((b) => bat(...b)).join("")}
      <div class="box" style="left:${o.tower[0]}px;top:${o.tower[1]}px;width:${o.tower[2]}px;height:${o.tower[2]}px;filter:drop-shadow(0 0 2px #12061f) drop-shadow(0 0 12px rgba(255,150,60,.45))">
        <div class="fill" data-mask="iconTower:cut" data-soften="0.6"><img class="fill" data-img="iconTower:main" style="filter:brightness(.62) contrast(1.15) saturate(1.3)"></div></div>
      <div class="abs" style="left:${o.glow[0] - o.glow[2]}px;top:${o.glow[1] - o.glow[2]}px;width:${o.glow[2] * 2}px;height:${o.glow[2] * 2}px;border-radius:50%;background:radial-gradient(circle closest-side,rgba(255,170,60,.7) 0%,rgba(255,110,20,.25) 50%,rgba(255,110,20,0) 100%)"></div>
      <div class="box" style="left:${o.king[0]}px;top:${o.king[1]}px;width:${o.king[2]}px;height:${o.king[2]}px;filter:drop-shadow(0 0 3px #2a0d08) drop-shadow(0 0 18px rgba(255,140,30,.9))">
        <div class="fill" data-mask="iconKing:cut" data-soften="0.6"><img class="fill" data-img="iconKing:main" style="filter:saturate(1.3) contrast(1.08) brightness(1.1)"></div></div>
      <div class="fill" style="background:radial-gradient(circle at 50% 46%,rgba(0,0,0,0) 60%,rgba(12,2,24,.5) 100%)"></div>`,
  },
];

// ------------------------------------------------------------------ run
// --try <render> --camera "x,y,z->x,y,z" [--camera ...] [--fov n]: quick half-size test renders of
// other cameras for one render (into <work>/try/<render>/), to find a better shot.
if (opt("--try")) {
  const name = opt("--try"), r = RENDERS[name];
  const cams = argv.flatMap((a, i) => (a === "--camera" ? [argv[i + 1]] : []));
  const scenePath = join(WORK, "renders", name, "scene.json");
  mkdirSync(dirname(scenePath), { recursive: true });
  writeJSON(scenePath, sceneFor(name));
  const dir = join(WORK, "try", name);
  execFileSync("node", [RENDERER, scenePath, dir, "--views", "custom", ...cams.flatMap((c) => ["--camera", c]), "--fov", opt("--fov") || String(r.fov),
    "--size", r.size.map((v) => Math.round(v / 2)).join("x"), "--no-caption", "--no-compass", "--quiet", ...(r.flags || [])], { stdio: "inherit" });
  log(`try renders in ${rel(dir)}`);
  process.exit(0);
}

const selected = SHOTS.filter((s) => !ONLY.length || ONLY.some((o) => s.id === o || s.file.startsWith(o)));
const F = facts();
log(`facts: ${F.skins} skins (${F.themedSkins} in crate themes), ${F.crazy.length} CRAZY, ${F.oneInAMillion.length} one in a million`);

const R = {};
for (const s of selected) for (const r of s.renders) R[r] ||= renderOne(r);

const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
const SS = 2;
const pg = await (await browser.newContext({ deviceScaleFactor: SS })).newPage();
const scaler = await (await browser.newContext({ deviceScaleFactor: 1 })).newPage();
async function shoot(w, h, body, renders) {
  const { token, html } = page({ w, h, body, renders });
  await pg.setViewportSize({ width: w, height: h });
  await pg.setContent(html, { waitUntil: "load" });
  await pg.waitForFunction((t) => window.READY === t, token, { timeout: 120000 });
  return pg.locator(".frame").screenshot();
}
async function downscale(buf, w, h) {
  const b64 = await scaler.evaluate(async ({ src, w, h }) => {
    const img = new Image();
    img.src = src;
    await img.decode();
    let c = document.createElement("canvas");
    c.width = img.width; c.height = img.height;
    c.getContext("2d").drawImage(img, 0, 0);
    while (c.width / 2 >= w) {
      const n = document.createElement("canvas");
      n.width = Math.round(c.width / 2); n.height = Math.round(c.height / 2);
      const g = n.getContext("2d"); g.imageSmoothingQuality = "high"; g.drawImage(c, 0, 0, n.width, n.height);
      c = n;
    }
    const o = document.createElement("canvas");
    o.width = w; o.height = h;
    const g = o.getContext("2d"); g.imageSmoothingQuality = "high"; g.drawImage(c, 0, 0, w, h);
    return o.toDataURL("image/png").split(",")[1];
  }, { src: `data:image/png;base64,${buf.toString("base64")}`, w, h });
  return Buffer.from(b64, "base64");
}

for (const s of selected) {
  const [w, h] = s.size || [W, H];
  const renders = Object.fromEntries(s.renders.map((r) => [r, R[r]]));
  const png = await downscale(await shoot(w, h, s.compose(F, renders), renders), w, h);
  const out = join(OUT, s.file);
  writeFileSync(out, png);
  // readability check: how it looks small (a 480x270 thumbnail, a 150 px icon)
  const [pw, ph] = s.size ? [150, 150] : [480, 270];
  writeFileSync(join(WORK, "preview", s.file.replace(".png", `-${pw}.png`)), await downscale(png, pw, ph));
  log(`wrote ${rel(out)} (${(statSync(out).size / 1e6).toFixed(2)} MB)`);
}

// contact sheet: everything small in one picture
if (!ONLY.length || flag("--sheet")) {
  const files = SHOTS.map((s) => ({ s, path: join(OUT, s.file) })).filter((f) => existsSync(f.path));
  const cell = 600, gap = 36, cols = 3, th = (cell * 9) / 16, label = 60;
  const thumbs = files.filter((f) => !f.s.size), icons = files.filter((f) => f.s.size);
  const rows = Math.ceil(thumbs.length / cols);
  const sw = cols * cell + (cols + 1) * gap;
  const sh = 110 + rows * (th + label + gap) + (icons.length ? 256 + label + gap : 0);
  const item = (f, x, y, w, h) => `<div class="abs" style="left:${x}px;top:${y}px">
      <img src="${dataUrl(f.path)}" style="display:block;width:${w}px;height:${h}px;border-radius:${f.s.size ? w * 0.2 : 14}px;box-shadow:0 8px 30px rgba(0,0,0,.6)">
      <div style="font:28px Lilita;color:#f2e6ff;margin-top:10px">${f.s.file}</div></div>`;
  let body = `<div class="fill" style="background:linear-gradient(180deg,#24103f,#100620)"></div>
    <div class="abs" style="left:${gap}px;top:26px;font:52px Luckiest;color:#ffb347;-webkit-text-stroke:8px ${INK};paint-order:stroke fill">PUMPKIN PANIC <span style="color:#c99bff">STORE ART V2</span></div>`;
  thumbs.forEach((f, i) => { body += item(f, gap + (i % cols) * (cell + gap), 110 + Math.floor(i / cols) * (th + label + gap), cell, th); });
  icons.forEach((f, i) => { body += item(f, gap + i * (300 + gap), 110 + rows * (th + label + gap), 256, 256); });
  const out = join(OUT, "contact-sheet.png");
  writeFileSync(out, await downscale(await shoot(sw, sh, body, {}), sw, sh));
  log(`wrote ${rel(out)}`);
}
await browser.close();
log(`small previews in ${rel(join(WORK, "preview"))}`);
