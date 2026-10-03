// Renders Roblox game thumbnails (1920x1080) and icons (512x512) to PNG.
// Usage: node thumbnails/render.mjs
// Edit GAMES (bottom of file) to change titles, taglines and badges.
//
// Style: cinematic "YouTube-style" Roblox thumbnails — hero seen from behind
// walking toward a lit focal point, warm/cool lighting with rim light and
// bloom, dripping/gradient outlined titles, and a jagged reaction-face inset.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require("playwright"));
} catch {
  ({ chromium } = require("/opt/node22/lib/node_modules/playwright"));
}

const ROOT = dirname(fileURLToPath(import.meta.url));
const OUT = join(ROOT, "output");

// ---------- helpers ----------
const font = (name) =>
  `data:font/woff2;base64,${readFileSync(join(ROOT, "fonts", `${name}.woff2`)).toString("base64")}`;

const FONT_CSS = `
@font-face{font-family:Luckiest;src:url(${font("luckiest-guy")})}
@font-face{font-family:Creepster;src:url(${font("creepster")})}
@font-face{font-family:Orbitron;src:url(${font("orbitron")});font-weight:900}
@font-face{font-family:Lilita;src:url(${font("lilita-one")})}
@font-face{font-family:Bangers;src:url(${font("bangers")})}
`;

function rng(seed) {
  return () => {
    seed |= 0;
    seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const INK = "#0b0b16";
const rad = (d) => (d * Math.PI) / 180;

// Shared SVG defs: shading gradients, rim-light filters, vignette, grain, blur.
const rimFilter = (id, color, dx, dy, halo = 14) => `
  <filter id="${id}" x="-30%" y="-30%" width="160%" height="160%">
    <feOffset in="SourceAlpha" dx="${dx}" dy="${dy}" result="o"/>
    <feComposite in="SourceAlpha" in2="o" operator="out" result="edge"/>
    <feFlood flood-color="${color}"/><feComposite in2="edge" operator="in" result="rim"/>
    <feGaussianBlur in="rim" stdDeviation="2.2" result="rimb"/>
    <feGaussianBlur in="SourceAlpha" stdDeviation="${halo}" result="h"/>
    <feFlood flood-color="${color}" flood-opacity="0.55"/><feComposite in2="h" operator="in" result="halo"/>
    <feMerge><feMergeNode in="halo"/><feMergeNode in="SourceGraphic"/><feMergeNode in="rimb"/><feMergeNode in="rim"/></feMerge>
  </filter>`;
const glow = (id, std, color) => `
  <filter id="${id}" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="${std}" result="b"/>
    ${color ? `<feFlood flood-color="${color}"/><feComposite in2="b" operator="in" result="b"/>` : ""}
    <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>`;
const SHARED_DEFS = `
  <linearGradient id="shadeR" x1="0" x2="1"><stop offset="0.35" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.5"/></linearGradient>
  <linearGradient id="shadeL" x1="1" x2="0"><stop offset="0.35" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.5"/></linearGradient>
  <linearGradient id="shadeB" x1="0" y1="0" x2="0" y2="1"><stop offset="0.3" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.55"/></linearGradient>
  <radialGradient id="vig" cx="0.55" cy="0.48" r="0.78"><stop offset="0.5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.85"/></radialGradient>
  <filter id="dof"><feGaussianBlur stdDeviation="2.4"/></filter>
  <filter id="dof2"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="soft"><feGaussianBlur stdDeviation="30"/></filter>
  <filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" stitchTiles="stitch"/>
    <feColorMatrix values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 0.07 0"/></filter>
  ${glow("bloom", 12)}${glow("bloomBig", 28)}`;

// ---------- characters ----------

// Blocky limb with shading. Lit side controls which side gets the dark gradient.
function limb(x, y, w, h, fill, ang, px, py, lit, extra = "") {
  return `<g transform="rotate(${ang} ${px} ${py})">
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="0.14" fill="${fill}" stroke="${INK}" stroke-width="0.07"/>
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="0.14" fill="url(#${lit === "right" ? "shadeL" : "shadeR"})"/>
    ${extra}</g>`;
}

const HAIR_BACK = (c) => `<path d="M-0.76 -1.5 L-0.5 -1.7 L-0.25 -1.6 L0 -1.74 L0.28 -1.62 L0.52 -1.72 L0.78 -1.46 L0.76 -0.3 L0.56 -0.12 L0.34 -0.2 L0.14 -0.06 L-0.08 -0.18 L-0.3 -0.06 L-0.52 -0.16 L-0.76 -0.28Z" fill="${c}" stroke="${INK}" stroke-width="0.07" stroke-linejoin="round"/>
  <path d="M-0.5 -1.45 L-0.42 -0.35 M-0.15 -1.5 L-0.1 -0.3 M0.2 -1.5 L0.16 -0.3 M0.5 -1.4 L0.44 -0.35" stroke="#000" stroke-opacity="0.3" stroke-width="0.06"/>
  <path d="M-0.76 -1.5 L-0.5 -1.7 L-0.25 -1.6 L0 -1.74 L0.28 -1.62 L0.52 -1.72 L0.78 -1.46 L0.76 -0.3 L0.56 -0.12 L0.34 -0.2 L0.14 -0.06 L-0.08 -0.18 L-0.3 -0.06 L-0.52 -0.16 L-0.76 -0.28Z" fill="url(#shadeR)"/>`;

const CHEF_HAT = `<g><rect x="-0.66" y="-1.95" width="1.32" height="0.42" fill="#f4f4f4" stroke="${INK}" stroke-width="0.07"/>
  <circle cx="-0.45" cy="-2.3" r="0.45" fill="#fff" stroke="${INK}" stroke-width="0.07"/><circle cx="0.45" cy="-2.3" r="0.45" fill="#fff" stroke="${INK}" stroke-width="0.07"/>
  <circle cx="0" cy="-2.55" r="0.55" fill="#fff" stroke="${INK}" stroke-width="0.07"/><rect x="-0.6" y="-2.2" width="1.2" height="0.3" fill="#fff"/>
  <rect x="-0.66" y="-2.9" width="1.32" height="1.37" fill="url(#shadeR)"/></g>`;

// Avatar seen from behind. Origin = top-centre of torso; 1 unit = 1 stud; s = px/unit.
// itemR is SVG drawn in the right hand's local space (hand centre ≈ 1.52, 2.0).
function avatarBack(x, y, s, o = {}) {
  const { skin = "#f2c48d", shirt = "#1f2233", pants = "#141522", hair = "#5a2e1a", hat = "", pose = {}, rot = 0, lit = "right", itemR = "", rimId, shadow = true } = o;
  const { armL = 0, armR = 0, legL = 0, legR = 0 } = pose;
  const sleeve = (x0) => `<rect x="${x0}" y="0" width="1" height="1.1" rx="0.14" fill="${shirt}" stroke="${INK}" stroke-width="0.07"/>`;
  return `<g ${rimId ? `filter="url(#${rimId})"` : ""}><g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})">
    ${shadow ? `<ellipse cx="0" cy="4.1" rx="1.9" ry="0.35" fill="#000" opacity="0.45"/>` : ""}
    ${limb(-1, 1.95, 1, 2.05, pants, legL, -0.5, 2, lit)}
    ${limb(0, 1.95, 1, 2.05, pants, legR, 0.5, 2, lit)}
    ${limb(-2.02, 0, 1, 2, skin, armL, -1.5, 0.35, lit, sleeve(-2.02))}
    ${limb(1.02, 0, 1, 2, skin, armR, 1.5, 0.35, lit, sleeve(1.02) + itemR)}
    <rect x="-1" y="0" width="2" height="2.02" rx="0.1" fill="${shirt}" stroke="${INK}" stroke-width="0.07"/>
    <path d="M-0.35 0 L0 0.25 L0.35 0" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="0.07"/>
    <rect x="-1" y="0" width="2" height="2.02" rx="0.1" fill="url(#${lit === "right" ? "shadeL" : "shadeR"})"/>
    <rect x="-0.4" y="-0.18" width="0.8" height="0.25" fill="${skin}" stroke="${INK}" stroke-width="0.06"/>
    <rect x="-0.68" y="-1.45" width="1.36" height="1.36" rx="0.3" fill="${skin}" stroke="${INK}" stroke-width="0.07"/>
    ${HAIR_BACK(hair)}${hat}
  </g></g>`;
}

// World position of the right hand of an avatar (for beams etc).
function handR(x, y, s, rot, armR) {
  const [px, py] = [1.5, 0.35];
  const a = rad(armR);
  const lx = px + (1.52 - px) * Math.cos(a) - (2.0 - py) * Math.sin(a);
  const ly = py + (1.52 - px) * Math.sin(a) + (2.0 - py) * Math.cos(a);
  const r = rad(rot);
  return [x + s * (lx * Math.cos(r) - ly * Math.sin(r)), y + s * (lx * Math.sin(r) + ly * Math.cos(r))];
}

// Close-up reaction face for the corner inset. Head is 1x1 units centred at origin.
function face(expr, { skin = "#f2c48d", hair = "#6b3a1f" } = {}) {
  const eyes = {
    scared: `<ellipse cx="-0.2" cy="-0.02" rx="0.115" ry="0.15" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
             <ellipse cx="0.2" cy="-0.02" rx="0.115" ry="0.15" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
             <circle cx="-0.19" cy="0" r="0.045" fill="${INK}"/><circle cx="0.21" cy="0" r="0.045" fill="${INK}"/>
             <path d="M-0.36 -0.15 L-0.08 -0.27 M0.36 -0.15 L0.08 -0.27" stroke="${INK}" stroke-width="0.045" fill="none" stroke-linecap="round"/>
             <path d="M-0.24 0.34 Q-0.22 0.14 0 0.13 Q0.22 0.14 0.24 0.34 Q0.12 0.28 0 0.3 Q-0.12 0.28 -0.24 0.34Z" fill="#3a0d12" stroke="${INK}" stroke-width="0.025"/>
             <path d="M-0.15 0.17 Q0 0.13 0.15 0.17 L0.13 0.2 Q0 0.17 -0.13 0.2Z" fill="#fff"/>
             <path d="M-0.32 0.07 q-0.04 0.07 0 0.1 q0.04 -0.03 0 -0.1Z" fill="#9fe3ff" stroke="#fff" stroke-width="0.01"/>`,
    shocked: `<circle cx="-0.2" cy="-0.04" r="0.14" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
              <circle cx="0.2" cy="-0.04" r="0.14" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
              <circle cx="-0.2" cy="-0.04" r="0.035" fill="${INK}"/><circle cx="0.2" cy="-0.04" r="0.035" fill="${INK}"/>
              <path d="M-0.34 -0.26 Q-0.2 -0.34 -0.08 -0.27 M0.34 -0.26 Q0.2 -0.34 0.08 -0.27" stroke="${INK}" stroke-width="0.04" fill="none" stroke-linecap="round"/>
              <ellipse cx="0" cy="0.26" rx="0.12" ry="0.15" fill="#3a0d12" stroke="${INK}" stroke-width="0.025"/>
              <ellipse cx="0" cy="0.34" rx="0.07" ry="0.05" fill="#e0475e"/>`,
    money: `<text x="-0.2" y="0.07" text-anchor="middle" font-family="Luckiest" font-size="0.3" fill="#2bd94a" stroke="${INK}" stroke-width="0.02">$</text>
            <text x="0.2" y="0.07" text-anchor="middle" font-family="Luckiest" font-size="0.3" fill="#2bd94a" stroke="${INK}" stroke-width="0.02">$</text>
            <path d="M-0.34 -0.24 Q-0.2 -0.32 -0.08 -0.25 M0.34 -0.24 Q0.2 -0.32 0.08 -0.25" stroke="${INK}" stroke-width="0.04" fill="none" stroke-linecap="round"/>
            <path d="M-0.26 0.14 L0.26 0.14 Q0.24 0.4 0 0.41 Q-0.24 0.4 -0.26 0.14Z" fill="#3a0d12" stroke="${INK}" stroke-width="0.025"/>
            <path d="M-0.24 0.14 L0.24 0.14 L0.23 0.2 L-0.23 0.2Z" fill="#fff"/><path d="M-0.12 0.34 Q0 0.27 0.12 0.34 Q0 0.4 -0.12 0.34Z" fill="#e0475e"/>`,
    determined: `<path d="M-0.36 -0.2 L-0.08 -0.12 M0.36 -0.2 L0.08 -0.12" stroke="${INK}" stroke-width="0.055" stroke-linecap="round"/>
                 <ellipse cx="-0.2" cy="-0.01" rx="0.1" ry="0.07" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
                 <ellipse cx="0.2" cy="-0.01" rx="0.1" ry="0.07" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
                 <circle cx="-0.18" cy="0" r="0.045" fill="#00e1ff"/><circle cx="0.22" cy="0" r="0.045" fill="#00e1ff"/>
                 <rect x="-0.2" y="0.18" width="0.4" height="0.13" rx="0.03" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
                 <path d="M-0.1 0.18 V0.31 M0 0.18 V0.31 M0.1 0.18 V0.31 M-0.2 0.245 H0.2" stroke="${INK}" stroke-width="0.015"/>`,
  }[expr];
  return `<rect x="-0.5" y="-0.5" width="1" height="1" rx="0.2" fill="${skin}" stroke="${INK}" stroke-width="0.035"/>
    <rect x="-0.5" y="-0.5" width="1" height="1" rx="0.2" fill="url(#shadeR)" opacity="0.7"/>
    <ellipse cx="-0.24" cy="-0.28" rx="0.16" ry="0.08" fill="#fff" opacity="0.25"/>
    <circle cx="-0.32" cy="0.15" r="0.07" fill="#ff7a7a" opacity="0.35"/><circle cx="0.32" cy="0.15" r="0.07" fill="#ff7a7a" opacity="0.35"/>
    ${eyes}
    <path d="M-0.56 -0.12 L-0.58 -0.44 L-0.42 -0.62 L-0.2 -0.66 L-0.02 -0.74 L0.2 -0.66 L0.42 -0.7 L0.6 -0.5 L0.56 -0.1 L0.46 -0.3 L0.34 -0.36 L0.26 -0.28 L0.14 -0.4 L0.02 -0.3 L-0.12 -0.4 L-0.24 -0.3 L-0.36 -0.38 L-0.46 -0.26Z" fill="${hair}" stroke="${INK}" stroke-width="0.035" stroke-linejoin="round"/>
    <path d="M-0.4 -0.5 L-0.3 -0.38 M-0.05 -0.6 L0.02 -0.4 M0.3 -0.56 L0.28 -0.38" stroke="#fff" stroke-opacity="0.18" stroke-width="0.03"/>`;
}

// Jagged corner inset (bottom-left) with a reaction face.
function reactionInset({ expr, border = "#ff1f1f", bg = ["#3a1020", "#0d0410"], shirt = "#2a5bd7", skin, hair, hands = false, marks = "#fff" }) {
  const W = 600, H = 470, X = 0, Y = 1080 - H;
  const pts = [[-30, 0], [300, -18], [380, 40], [430, 30], [480, 140], [455, 175], [540, 260], [520, 300], [600, 420], [585, 520], [-30, 520]]
    .map(([a, b]) => `${X + a},${Y + b}`).join(" ");
  const cx = X + 230, cy = Y + 290, S = 300;
  const hand = (hx, r) => `<g transform="translate(${hx} 0.62) rotate(${r})"><rect x="-0.17" y="-0.24" width="0.34" height="0.48" rx="0.08" fill="${skin || "#f2c48d"}" stroke="${INK}" stroke-width="0.03"/><rect x="-0.17" y="-0.24" width="0.34" height="0.48" rx="0.08" fill="url(#shadeR)"/></g>`;
  const shock = [[-35, 0], [-15, 1], [5, 2]].map(([a, i]) => {
    const r1 = 210, r2 = 260 + i * 10, ang = rad(a);
    return `<line x1="${cx + 150 + r1 * Math.cos(ang) * 0.6}" y1="${cy - 60 + r1 * Math.sin(ang) * 0.6}" x2="${cx + 150 + r2 * Math.cos(ang) * 0.6}" y2="${cy - 60 + r2 * Math.sin(ang) * 0.6}" stroke="${marks}" stroke-width="12" stroke-linecap="round"/>`;
  }).join("");
  return `<defs><clipPath id="insetClip"><polygon points="${pts}"/></clipPath>
      <radialGradient id="insetBg" cx="0.35" cy="0.5" r="0.7"><stop offset="0" stop-color="${bg[0]}"/><stop offset="1" stop-color="${bg[1]}"/></radialGradient></defs>
    <polygon points="${pts}" fill="none" stroke="#000" stroke-width="34" stroke-linejoin="round"/>
    <polygon points="${pts}" fill="none" stroke="${border}" stroke-width="16" stroke-linejoin="round" filter="url(#bloom)"/>
    <g clip-path="url(#insetClip)">
      <rect x="${X - 40}" y="${Y - 40}" width="${W + 80}" height="${H + 80}" fill="url(#insetBg)"/>
      <g transform="translate(${cx} ${cy}) rotate(-6) scale(${S})">
        <rect x="-0.85" y="0.5" width="1.7" height="0.9" rx="0.08" fill="${shirt}" stroke="${INK}" stroke-width="0.03"/>
        <rect x="-0.85" y="0.5" width="1.7" height="0.9" rx="0.08" fill="url(#shadeR)"/>
        ${face(expr, { skin, hair })}
        ${hands ? hand(-0.42, 12) + hand(0.42, -12) : ""}
      </g>
    </g>
    <polygon points="${pts}" fill="none" stroke="${border}" stroke-width="10" stroke-linejoin="round"/>
    ${shock}`;
}

// ---------- scenes (1920x1080 canvas) ----------

function nightShift() {
  const [x0, x1, y0, y1] = [1150, 1390, 410, 610]; // back wall
  const wall = (k, side) => [side < 0 ? x0 - x0 * k : x1 + (1920 - x1) * k, y0 - y0 * k, y1 + (1080 - y1) * k];
  const sideDoor = (k0, k1, side, col, lit = false) => {
    const [a, at, ab] = wall(k0, side), [b, bt, bb] = wall(k1, side);
    const h = (t, bot) => bot - (bot - t) * 0.74;
    return `<path d="M${a} ${ab} L${a} ${h(at, ab)} L${b} ${h(bt, bb)} L${b} ${bb} Z" fill="${col}" stroke="#000" stroke-width="4"/>
      ${lit ? `<path d="M${a} ${ab} L${a} ${h(at, ab)} L${a + (b - a) * 0.12} ${h(at, ab) + (h(bt, bb) - h(at, ab)) * 0.12} L${a + (b - a) * 0.12} ${ab + (bb - ab) * 0.12}Z" fill="#ff8a2a" filter="url(#bloom)"/>` : ""}`;
  };
  const floor = Array.from({ length: 13 }, (_, i) => {
    const bx = -700 + i * 260, t = Math.min(1, Math.max(0, bx / 1920));
    return `<line x1="${x0 + (x1 - x0) * t}" y1="${y1}" x2="${bx}" y2="1080"/>`;
  }).join("") + [0.06, 0.16, 0.32, 0.56, 0.9].map((k) => `<line x1="${x0 - x0 * k}" y1="${y1 + (1080 - y1) * k}" x2="${x1 + (1920 - x1) * k}" y2="${y1 + (1080 - y1) * k}"/>`).join("");
  const lamp = (k, on) => {
    const y = y0 - y0 * k + 14, cx = 1270 + (960 - 1270) * k * 0.15, w = 70 + 300 * k;
    return `<rect x="${cx - w / 2}" y="${y}" width="${w}" height="${8 + 20 * k}" fill="${on ? "#cfe6ff" : "#20262c"}" ${on ? 'filter="url(#bloom)"' : ""}/>
      ${on ? `<path d="M${cx - w / 2} ${y} L${cx + w / 2} ${y} L${cx + w * 1.5} ${y + 250 + 650 * k} L${cx - w * 1.5} ${y + 250 + 650 * k}Z" fill="url(#coneBlue)" style="mix-blend-mode:screen"/>` : ""}`;
  };
  const creature = `<g transform="translate(1272 610)">
    <path d="M-70 0 L-58 -230 Q-62 -300 0 -310 Q62 -300 58 -230 L70 0Z" fill="#070304"/>
    <path d="M-58 -230 L-96 -40 L-80 -36 L-50 -180Z M58 -230 L96 -40 L80 -36 L50 -180Z" fill="#070304"/>
    <rect x="-84" y="-44" width="22" height="26" fill="#d9c6b0"/>
    <path d="M-44 -300 Q0 -350 44 -300 L48 -250 Q0 -232 -48 -250Z" fill="#050203"/>
    <rect x="-34" y="-300" width="68" height="62" rx="12" fill="#e9dcc8"/>
    <rect x="-34" y="-300" width="68" height="62" rx="12" fill="url(#shadeR)"/>
    <g filter="url(#redEye)"><path d="M-24 -282 L-8 -276 L-24 -270Z M24 -282 L8 -276 L24 -270Z" fill="#ff1a1a"/></g>
    <path d="M-24 -258 Q0 -244 24 -258" fill="none" stroke="#1a0505" stroke-width="5"/>
    <path d="M-20 -256 l4 6 l4 -6 l4 7 l4 -7 l4 7 l4 -7 l4 6 l4 -6" fill="none" stroke="#1a0505" stroke-width="2.5"/></g>`;
  const X = 870, Y = 690, S = 118, ROT = -3, ARM = -55;
  const torch = `<g transform="translate(1.52 2.0)"><rect x="-0.17" y="-0.1" width="0.34" height="0.75" rx="0.06" fill="#2a2a2a" stroke="${INK}" stroke-width="0.05"/><rect x="-0.24" y="0.55" width="0.48" height="0.25" rx="0.05" fill="#444" stroke="${INK}" stroke-width="0.05"/><rect x="-0.2" y="0.78" width="0.4" height="0.07" fill="#fffbe0"/></g>`;
  const [hx, hy] = handR(X, Y, S, ROT, ARM);
  const beam = `<path d="M${hx} ${hy} L1140 400 L1420 520 Z" fill="url(#beam)" style="mix-blend-mode:screen"/>
    <circle cx="${hx}" cy="${hy}" r="26" fill="#fff6d0" filter="url(#bloomBig)"/>`;
  return {
    defs: `${rimFilter("rimOrange", "#ff7a1a", -7, 3, 18)}${glow("redEye", 5, "#ff0000")}
      <linearGradient id="wl" x1="0" x2="1"><stop offset="0" stop-color="#16314f"/><stop offset="1" stop-color="#050a16"/></linearGradient>
      <linearGradient id="wr" x1="1" x2="0"><stop offset="0" stop-color="#1b2f48"/><stop offset="1" stop-color="#070b16"/></linearGradient>
      <linearGradient id="fl" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#12182a"/><stop offset="1" stop-color="#05060c"/></linearGradient>
      <linearGradient id="cl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0f1626"/><stop offset="1" stop-color="#03050a"/></linearGradient>
      <linearGradient id="coneBlue" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fc4ff" stop-opacity="0.35"/><stop offset="1" stop-color="#8fc4ff" stop-opacity="0"/></linearGradient>
      <linearGradient id="beam" x1="0" y1="1" x2="1" y2="0"><stop offset="0" stop-color="#fff6d0" stop-opacity="0.75"/><stop offset="1" stop-color="#fff6d0" stop-opacity="0.05"/></linearGradient>
      <radialGradient id="doorGlow" cx="0.5" cy="0.6" r="0.6"><stop offset="0" stop-color="#ffb347"/><stop offset="0.5" stop-color="#ff5a14"/><stop offset="1" stop-color="#7a1400"/></radialGradient>
      <radialGradient id="spill" cx="0.5" cy="0" r="0.8"><stop offset="0" stop-color="#ff6a1a" stop-opacity="0.75"/><stop offset="1" stop-color="#ff6a1a" stop-opacity="0"/></radialGradient>
      <radialGradient id="warmKey" cx="0.66" cy="0.48" r="0.45"><stop offset="0" stop-color="#ff7a1a" stop-opacity="0.45"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/></radialGradient>`,
    body: `<rect width="1920" height="1080" fill="#000"/>
      <g filter="url(#dof)">
        <path d="M0 0 L1920 0 L${x1} ${y0} L${x0} ${y0}Z" fill="url(#cl)"/>
        <path d="M0 0 L${x0} ${y0} L${x0} ${y1} L0 1080Z" fill="url(#wl)"/>
        <path d="M1920 0 L${x1} ${y0} L${x1} ${y1} L1920 1080Z" fill="url(#wr)"/>
        <path d="M0 1080 L${x0} ${y1} L${x1} ${y1} L1920 1080Z" fill="url(#fl)"/>
        <g stroke="#000" stroke-width="3" opacity="0.55">${floor}</g>
        <rect x="${x0}" y="${y0}" width="${x1 - x0}" height="${y1 - y0}" fill="#0a0d16"/>
        <rect x="1200" y="430" width="145" height="180" fill="url(#doorGlow)" filter="url(#bloom)"/>
        <path d="M1200 430 L1150 414 L1150 626 L1200 610Z" fill="#3a1408" stroke="#000" stroke-width="3"/>
        ${creature}
        
        ${sideDoor(0.2, 0.36, -1, "#1c1310")}${sideDoor(0.55, 0.82, -1, "#22160f", true)}${sideDoor(0.26, 0.44, 1, "#1c1310")}${sideDoor(0.62, 0.95, 1, "#1a1210")}
        ${lamp(0.08, false)}${lamp(0.45, true)}${lamp(0.8, false)}
      </g>
      <path d="M1100 610 L1450 610 L1700 1080 L700 1080Z" fill="url(#spill)" style="mix-blend-mode:screen"/>
      <rect x="1235" y="640" width="70" height="420" fill="#ff7a2a" opacity="0.35" filter="url(#dof2)"/>
      ${beam}
      ${avatarBack(X, Y, S, { shirt: "#1d2030", pants: "#11121c", hair: "#5a2a14", rot: ROT, pose: { armL: 8, armR: ARM, legL: 3, legR: -3 }, itemR: torch, rimId: "rimOrange" })}
      <rect width="1920" height="1080" fill="url(#warmKey)" style="mix-blend-mode:screen"/>
      <rect width="1920" height="1080" fill="url(#vig)"/>
      ${reactionInset({ expr: "scared", border: "#ff1f1f", bg: ["#2a1a40", "#07040e"], shirt: "#2a5bd7", hands: true })}
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [1015, 230, 520],
  };
}

function skyObby() {
  const r = rng(7);
  const cloud = (cx, cy, k, top = "#ffd2e6", bot = "#5b4fa8") => `<g transform="translate(${cx} ${cy}) scale(${k})">
      <g fill="${bot}"><circle cx="-90" cy="20" r="70"/><circle cx="0" cy="-20" r="100"/><circle cx="110" cy="10" r="80"/><circle cx="190" cy="40" r="55"/><rect x="-160" y="20" width="400" height="80" rx="40"/></g>
      <g fill="${top}"><circle cx="-90" cy="8" r="62"/><circle cx="0" cy="-30" r="90"/><circle cx="110" cy="0" r="70"/><circle cx="185" cy="30" r="45"/></g></g>`;
  const cloudsFar = [[200, 820, 1.6], [760, 900, 2], [1350, 860, 1.7], [1800, 900, 1.5], [1000, 980, 2.4]].map((c) => cloud(...c)).join("");
  const plat = (x, y, w, d, top, side, glowc) => `<g>
      <path d="M${x} ${y} L${x + d} ${y - d * 0.55} L${x + w + d} ${y - d * 0.55} L${x + w} ${y}Z" fill="${top}" stroke="${INK}" stroke-width="4"/>
      <path d="M${x + w} ${y} L${x + w + d} ${y - d * 0.55} L${x + w + d} ${y + w * 0.12 - d * 0.55} L${x + w} ${y + w * 0.12}Z" fill="${side}" stroke="${INK}" stroke-width="4"/>
      <rect x="${x}" y="${y}" width="${w}" height="${w * 0.12}" fill="${side}" stroke="${INK}" stroke-width="4"/>
      <rect x="${x}" y="${y}" width="${w}" height="${w * 0.12}" fill="url(#shadeB)"/>
      ${glowc ? `<path d="M${x + 6} ${y - 2} L${x + w - 6} ${y - 2}" stroke="${glowc}" stroke-width="5" filter="url(#bloom)"/>` : ""}</g>`;
  const plats = [
    [1450, 390, 110, 34, "#ff7ac0", "#a8306c"],
    [1250, 470, 150, 44, "#ffe066", "#a8820d"],
    [1500, 560, 190, 56, "#5df08f", "#1f7a43"],
    [1180, 690, 260, 72, "#b98aff", "#5b2fab", "#e6d6ff"],
  ].map((p) => plat(...p)).join("");
  const beacon = `<g><rect x="1462" y="0" width="90" height="390" fill="url(#beamUp)" style="mix-blend-mode:screen"/>
      <rect x="1490" y="300" width="10" height="90" fill="#eee" stroke="${INK}" stroke-width="3"/>
      <path d="M1500 300 L1570 320 L1500 340Z" fill="#5df08f" stroke="${INK}" stroke-width="3" filter="url(#bloom)"/></g>`;
  const spinner = `<g transform="translate(1340 655) rotate(-14)" filter="url(#redGlow)"><rect x="-230" y="-14" width="460" height="28" rx="12" fill="#ff2d3d"/>
      <rect x="-220" y="-10" width="440" height="8" rx="4" fill="#fff" opacity="0.6"/></g>
      <circle cx="1340" cy="655" r="22" fill="#333" stroke="${INK}" stroke-width="5"/>`;
  const near = `<g>${plat(200, 980, 760, 150, "#3dc7ff", "#13619a")}</g>`;
  const sparkles = Array.from({ length: 22 }, () => {
    const x = 900 + r() * 1000, y = 60 + r() * 600, k = 0.4 + r() * 0.8;
    return `<path transform="translate(${x} ${y}) scale(${k})" d="M0 -18 L5 -5 L18 0 L5 5 L0 18 L-5 5 L-18 0 L-5 -5Z" fill="#fff6d6" opacity="${0.4 + r() * 0.6}"/>`;
  }).join("");
  const speed = [0, 1, 2, 3, 4].map((i) => `<path d="M${880 - i * 20} ${660 + i * 40} l-${220 - i * 30} ${80 + i * 10}" stroke="#fff" stroke-width="${10 - i}" stroke-linecap="round" opacity="0.65"/>`).join("");
  return {
    defs: `${rimFilter("rimSun", "#ffb347", -7, 6, 18)}${glow("redGlow", 8, "#ff2d3d")}
      <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b1f6b"/><stop offset="0.45" stop-color="#7b3fa0"/><stop offset="0.75" stop-color="#ff7a59"/><stop offset="1" stop-color="#ffc26b"/></linearGradient>
      <radialGradient id="sun" cx="0.78" cy="0.42" r="0.4"><stop offset="0" stop-color="#fff6d6"/><stop offset="0.12" stop-color="#ffd27a"/><stop offset="0.5" stop-color="#ff8a4d" stop-opacity="0.5"/><stop offset="1" stop-color="#ff8a4d" stop-opacity="0"/></radialGradient>
      <linearGradient id="beamUp" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#7dffb0" stop-opacity="0.8"/><stop offset="1" stop-color="#7dffb0" stop-opacity="0"/></linearGradient>
      <radialGradient id="coolL" cx="0" cy="0.3" r="0.8"><stop offset="0" stop-color="#0b0f40" stop-opacity="0.65"/><stop offset="1" stop-color="#0b0f40" stop-opacity="0"/></radialGradient>`,
    body: `<rect width="1920" height="1080" fill="url(#sky)"/>
      <rect width="1920" height="1080" fill="url(#sun)"/>
      <circle cx="1500" cy="450" r="90" fill="#fff3c9" filter="url(#bloomBig)"/>
      <g filter="url(#dof)">${cloudsFar}${plats}${beacon}</g>
      ${spinner}${sparkles}${near}${speed}
      ${avatarBack(1020, 470, 92, { shirt: "#e8334a", pants: "#1f2050", hair: "#2a1a10", rot: 18, pose: { armL: 150, armR: -150, legL: 30, legR: -42 }, rimId: "rimSun", shadow: false })}
      <rect width="1920" height="1080" fill="url(#coolL)"/>
      <rect width="1920" height="1080" fill="url(#vig)" opacity="0.7"/>
      ${reactionInset({ expr: "shocked", border: "#ffcc1f", bg: ["#3b4fd6", "#120f3f"], shirt: "#e8334a", hair: "#2a1a10" })}
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [770, 220, 800],
  };
}

function pizzaTycoon() {
  const r = rng(42);
  const city = Array.from({ length: 22 }, (_, i) => {
    const w = 60 + r() * 90, h = 120 + r() * 300, x = i * 92 - 40;
    const wins = Array.from({ length: 10 }, () => `<rect x="${x + 10 + r() * (w - 25)}" y="${680 - h + 20 + r() * (h - 40)}" width="9" height="12" fill="#ffd27a" opacity="${0.3 + r() * 0.6}"/>`).join("");
    return `<rect x="${x}" y="${680 - h}" width="${w}" height="${h}" fill="#1a1440"/>${wins}`;
  }).join("");
  const [bx0, bx1, by0, by1] = [960, 1760, 150, 820];
  const awning = Array.from({ length: 10 }, (_, i) => {
    const w = (bx1 - bx0 - 40) / 10, x = bx0 + 20 + i * w;
    return `<path d="M${x} 520 L${x + w} 520 L${x + w + 6} 600 Q${x + w / 2} 630 ${x - 6} 600Z" fill="${i % 2 ? "#fff3e0" : "#e0262c"}" stroke="${INK}" stroke-width="3"/>`;
  }).join("");
  const slice = `<g transform="translate(1600 420) scale(0.6)" filter="url(#neonOrange)">
      <path d="M-120 -80 L120 -80 L0 150Z" fill="none" stroke="#ffb020" stroke-width="12" stroke-linejoin="round"/>
      <path d="M-120 -80 Q0 -120 120 -80" fill="none" stroke="#ff6a1a" stroke-width="12"/>
      <circle cx="-35" cy="-30" r="20" fill="none" stroke="#ff3b3b" stroke-width="8"/><circle cx="35" cy="-20" r="18" fill="none" stroke="#ff3b3b" stroke-width="8"/><circle cx="0" cy="40" r="16" fill="none" stroke="#ff3b3b" stroke-width="8"/></g>`;
  const coin = (x, y, k, tilt = 1) => `<g transform="translate(${x} ${y}) scale(${k * tilt} ${k})"><circle r="40" fill="#c98a00" stroke="${INK}" stroke-width="5"/><circle r="30" fill="#ffd23f" stroke="#e6a400" stroke-width="4"/><text y="13" text-anchor="middle" font-family="Luckiest" font-size="38" fill="#e6a400">$</text></g>`;
  const pile = (cx, cy, w, h, n, seed) => {
    const rr = rng(seed);
    let s = `<ellipse cx="${cx}" cy="${cy}" rx="${w * 0.55}" ry="${h * 0.2}" fill="#7a4a00" opacity="0.6"/>`;
    const cs = [];
    for (let i = 0; i < n; i++) {
      const t = rr(), u = rr() * 2 - 1;
      const y = cy - t * h, half = w * 0.5 * (1 - t) * (0.6 + 0.4 * Math.sqrt(1 - u * u));
      cs.push([cx + u * half, y, 0.6 + rr() * 0.5, 0.5 + rr() * 0.5]);
    }
    cs.sort((a, b) => a[1] - b[1]);
    return s + cs.map((c) => coin(...c)).join("");
  };
  const rain = Array.from({ length: 12 }, (_, i) => coin(i % 2 ? 860 + r() * 220 : 1650 + r() * 250, 40 + r() * 520, 0.5 + r() * 0.6, 0.3 + r() * 0.7)).join("");
  const bill = (x, y, rot) => `<g transform="translate(${x} ${y}) rotate(${rot})"><rect x="-70" y="-34" width="140" height="68" rx="6" fill="#4fcf62" stroke="${INK}" stroke-width="5"/><rect x="-58" y="-24" width="116" height="48" rx="5" fill="none" stroke="#1e7a30" stroke-width="3"/><circle r="16" fill="#1e7a30"/></g>`;
  const X = 1340, Y = 650, S = 98, ARM = -150;
  const fan = `<g transform="translate(1.52 2.2) rotate(180)">${[-30, -10, 10, 30].map((a) => `<g transform="rotate(${a})"><rect x="-0.3" y="-1.3" width="0.6" height="1.2" rx="0.05" fill="#4fcf62" stroke="${INK}" stroke-width="0.04"/><circle cy="-0.75" r="0.14" fill="#1e7a30"/></g>`).join("")}</g>`;
  return {
    defs: `${rimFilter("rimGold", "#ffcc4d", -6, 5, 18)}${glow("neonOrange", 8, "#ff8a1a")}
      <linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#120a35"/><stop offset="0.6" stop-color="#4a1f6e"/><stop offset="1" stop-color="#ff7a3d"/></linearGradient>
      <pattern id="brick" width="80" height="40" patternUnits="userSpaceOnUse"><rect width="80" height="40" fill="#7a2a1c"/><path d="M0 0 H80 M0 20 H80 M40 0 V20 M0 20 V40 M80 20 V40" stroke="#4a160d" stroke-width="4"/></pattern>
      <linearGradient id="bShade" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#1a0a30" stop-opacity="0.7"/><stop offset="0.6" stop-color="#1a0a30" stop-opacity="0.2"/><stop offset="1" stop-color="#1a0a30" stop-opacity="0.6"/></linearGradient>
      <radialGradient id="shopGlow" cx="0.5" cy="0.5" r="0.6"><stop offset="0" stop-color="#ffe9a8"/><stop offset="0.6" stop-color="#ffb347"/><stop offset="1" stop-color="#ff7a1a"/></radialGradient>
      <radialGradient id="streetGlow" cx="0.55" cy="0" r="0.7"><stop offset="0" stop-color="#ffb347" stop-opacity="0.8"/><stop offset="1" stop-color="#ffb347" stop-opacity="0"/></radialGradient>
      <radialGradient id="coolL2" cx="0" cy="0.4" r="0.8"><stop offset="0" stop-color="#0a0526" stop-opacity="0.8"/><stop offset="1" stop-color="#0a0526" stop-opacity="0"/></radialGradient>`,
    body: `<rect width="1920" height="1080" fill="url(#dusk)"/>
      <g filter="url(#dof2)">${city}</g>
      <rect y="680" width="1920" height="400" fill="#140c22"/>
      <g filter="url(#dof)">
        <rect x="${bx0}" y="${by0}" width="${bx1 - bx0}" height="${by1 - by0}" fill="url(#brick)" stroke="${INK}" stroke-width="6"/>
        <rect x="${bx0}" y="${by0}" width="${bx1 - bx0}" height="${by1 - by0}" fill="url(#bShade)"/>
        <rect x="${bx0 - 20}" y="${by0 - 30}" width="${bx1 - bx0 + 40}" height="40" fill="#3a1410" stroke="${INK}" stroke-width="5"/>
        <rect x="1040" y="610" width="640" height="210" fill="url(#shopGlow)" filter="url(#bloom)"/>
        <path d="M1360 610 V820 M1040 700 H1680" stroke="#5a2a10" stroke-width="10"/>
        ${awning}${slice}
        <text x="1360" y="275" text-anchor="middle" font-family="Bangers" font-size="120" letter-spacing="8" fill="#fff4d6" stroke="#ff8a1a" stroke-width="4" filter="url(#neonOrange)">PIZZA EMPIRE</text>
      </g>
      <path d="M960 820 L1760 820 L1920 1080 L700 1080Z" fill="url(#streetGlow)" style="mix-blend-mode:screen"/>
      ${rain}
      ${pile(1780, 1060, 420, 260, 70, 3)}${pile(820, 1080, 300, 150, 40, 9)}
      ${bill(1050, 900, -20)}${bill(1620, 880, 25)}
      ${avatarBack(X, Y, S, { shirt: "#f4f4f4", pants: "#c81e28", hair: "#3a2010", hat: CHEF_HAT, rot: 0, pose: { armL: 150, armR: ARM, legL: 6, legR: -6 }, itemR: fan, rimId: "rimGold" })}
      <rect width="1920" height="1080" fill="url(#coolL2)"/>
      <rect width="1920" height="1080" fill="url(#vig)" opacity="0.75"/>
      ${reactionInset({ expr: "money", border: "#2bd94a", bg: ["#ffb347", "#a8320f"], shirt: "#f4f4f4", hair: "#3a2010", marks: "#fff4c2" })}
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [990, 120, 760],
  };
}

function neonDefense() {
  const H = 640, VP = [1260, H];
  const r = rng(99);
  const stars = Array.from({ length: 90 }, () => `<circle cx="${r() * 1920}" cy="${r() * 560}" r="${r() * 2.2 + 0.4}" fill="#fff" opacity="${0.3 + r() * 0.7}"/>`).join("");
  const sunStripes = [0, 1, 2, 3, 4, 5].map((i) => `<rect x="900" y="${470 + i * 28 + i * i * 2}" width="760" height="${4 + i * 2.8}" fill="#000"/>`).join("");
  const vLines = Array.from({ length: 41 }, (_, i) => {
    const bx = -2600 + i * 190;
    return `<line x1="${VP[0] + (bx - VP[0]) * 0.02}" y1="${H}" x2="${bx}" y2="1080"/>`;
  }).join("");
  const hLines = Array.from({ length: 12 }, (_, i) => `<line x1="0" y1="${H + (1080 - H) * Math.pow(i / 11, 2.2)}" x2="1920" y2="${H + (1080 - H) * Math.pow(i / 11, 2.2)}"/>`).join("");
  // giant boss silhouette in front of the sun
  const boss = `<g transform="translate(1260 640)">
      <rect x="-60" y="-120" width="50" height="120" fill="#0a0418"/><rect x="10" y="-120" width="50" height="120" fill="#0a0418"/>
      <rect x="-150" y="-380" width="300" height="270" rx="10" fill="#0a0418"/>
      <rect x="-250" y="-380" width="90" height="250" rx="10" fill="#0a0418" transform="rotate(14 -205 -380)"/>
      <rect x="160" y="-380" width="90" height="250" rx="10" fill="#0a0418" transform="rotate(-14 205 -380)"/>
      <rect x="-100" y="-540" width="200" height="170" rx="16" fill="#0a0418"/>
      <path d="M-150 -380 H150 M-100 -540 H100" stroke="#ff3df5" stroke-width="4" filter="url(#neon)"/>
      <g filter="url(#neonRed)"><path d="M-70 -480 L-20 -462 L-70 -444Z M70 -480 L20 -462 L70 -444Z" fill="#ff1f5a"/>
      <rect x="-50" y="-415" width="100" height="10" fill="#ff1f5a"/></g>
      <circle cx="0" cy="-250" r="40" fill="none" stroke="#ff1f5a" stroke-width="8" filter="url(#neonRed)"/></g>`;
  const tower = (x, y, k, col) => `<g transform="translate(${x} ${y}) scale(${k})" filter="url(#neon)">
    <path d="M-60 0 L-40 -30 L40 -30 L60 0 L40 20 L-40 20Z" fill="#12052b" stroke="${col}" stroke-width="5"/>
    <rect x="-28" y="-150" width="56" height="122" fill="#12052b" stroke="${col}" stroke-width="5"/>
    <path d="M-44 -150 L0 -200 L44 -150Z" fill="#12052b" stroke="${col}" stroke-width="5"/>
    <circle cx="0" cy="-160" r="12" fill="${col}"/></g>`;
  const minion = (x, y, k, col) => `<g transform="translate(${x} ${y}) scale(${k})" filter="url(#neon)">
    <path d="M0 -60 L40 -40 L40 10 L0 30 L-40 10 L-40 -40Z" fill="#12052b" stroke="${col}" stroke-width="5"/>
    <path d="M-40 -40 L0 -20 L40 -40 M0 -20 L0 30" stroke="${col}" stroke-width="4" fill="none"/></g>`;
  const laser = (a, b, col) => `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${col}" stroke-width="9" filter="url(#neon)" stroke-linecap="round"/><line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="#fff" stroke-width="3"/>`;
  const burst = (x, y, k = 1) => `<g transform="translate(${x} ${y}) scale(${k})" filter="url(#neon)">${Array.from({ length: 10 }, (_, i) => `<line x1="0" y1="0" x2="${Math.cos(i * 0.628) * 46}" y2="${Math.sin(i * 0.628) * 46}" stroke="#fff35c" stroke-width="5" stroke-linecap="round"/>`).join("")}</g>`;
  const T = [[880, 860, 1.0, "#ff3df5"], [1640, 840, 1.0, "#7dff5c"], [1060, 720, 0.6, "#ffb03d"], [1500, 710, 0.6, "#00f0ff"]];
  const top = ([x, y, k]) => [x, y - 160 * k];
  return {
    defs: `${rimFilter("rimCyan", "#00e5ff", -6, 4, 16)}${glow("neon", 7)}${glow("neonRed", 9, "#ff1f5a")}
      <linearGradient id="nsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05000f"/><stop offset="0.55" stop-color="#2d0b5a"/><stop offset="1" stop-color="#8a1a8a"/></linearGradient>
      <linearGradient id="nsun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff35c"/><stop offset="0.5" stop-color="#ff7a3d"/><stop offset="1" stop-color="#ff2fa8"/></linearGradient>
      <linearGradient id="nfloor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2b0047"/><stop offset="1" stop-color="#07000f"/></linearGradient>
      <mask id="sunMask"><rect width="1920" height="1080" fill="#fff"/>${sunStripes}</mask>
      <radialGradient id="nshade" cx="0" cy="0.5" r="0.8"><stop offset="0" stop-color="#07000f" stop-opacity="0.8"/><stop offset="1" stop-color="#07000f" stop-opacity="0"/></radialGradient>`,
    body: `<rect width="1920" height="1080" fill="url(#nsky)"/>${stars}
      <circle cx="1260" cy="430" r="330" fill="#ff2fa8" opacity="0.4" filter="url(#bloomBig)"/>
      <circle cx="1260" cy="430" r="280" fill="url(#nsun)" mask="url(#sunMask)"/>
      <path d="M0 ${H} L140 540 L280 610 L440 500 L600 ${H}Z M1540 ${H} L1660 520 L1780 590 L1920 500 L1920 ${H}Z" fill="#2b0f4d" stroke="#ff3df5" stroke-width="3" opacity="0.9"/>
      <g filter="url(#dof)">${boss}</g>
      <rect y="${H}" width="1920" height="${1080 - H}" fill="url(#nfloor)"/>
      <g stroke="#ff3df5" stroke-width="2.5" opacity="0.7" filter="url(#neon)">${vLines}${hLines}</g>
      <line x1="0" y1="${H}" x2="1920" y2="${H}" stroke="#ff9cf9" stroke-width="4" filter="url(#neon)"/>
      ${minion(1180, 700, 0.5, "#ff3d6e")}${minion(1380, 740, 0.6, "#ff3d6e")}${minion(1300, 680, 0.4, "#ffe23d")}
      ${T.map((t) => tower(...t)).join("")}
      ${laser(top(T[0]), [1210, 290], "#ff3df5")}${laser(top(T[1]), [1310, 300], "#7dff5c")}
      ${laser(top(T[2]), [1180, 690], "#ffb03d")}${laser(top(T[3]), [1380, 720], "#00f0ff")}
      ${burst(1210, 290, 1.4)}${burst(1310, 300, 1.2)}${burst(1380, 720)}
      ${avatarBack(1260, 790, 84, { shirt: "#141a3a", pants: "#0b0f24", hair: "#1a1030", rot: 0, pose: { armL: 6, armR: -150, legL: 10, legR: -10 }, rimId: "rimCyan" })}
      <rect width="1920" height="1080" fill="url(#nshade)"/>
      <rect width="1920" height="1080" fill="url(#vig)" opacity="0.7"/>
      ${reactionInset({ expr: "determined", border: "#00e5ff", bg: ["#5a1a8a", "#0a0218"], shirt: "#141a3a", hair: "#1a1030" })}
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [900, 110, 720],
  };
}

// ---------- titles (HTML overlay) ----------
// A line = [{ t, grad:[top,bottom] }...]; drawn twice: thick outline layer + gradient fill layer.
function title(lines, { x, y, rot = -4, font: f, stroke = 22, outline = "#000", glow: g = "", align = "left" }) {
  const row = (parts, size, mt) => {
    const base = `font-family:${f};font-size:${size}px;line-height:0.95;grid-area:1/1;white-space:nowrap;${f === "Orbitron" ? "font-weight:900;" : ""}`;
    const under = `<div style="${base}color:${outline};-webkit-text-stroke:${stroke}px ${outline};text-shadow:0 ${stroke * 0.6}px 0 ${outline}${g ? "," + g : ""}">${parts.map((p) => p.t).join("")}</div>`;
    const over = `<div style="${base}">${parts.map((p) => `<span style="background:linear-gradient(180deg,${p.grad[0]} 15%,${p.grad[1]} 90%);-webkit-background-clip:text;background-clip:text;color:transparent">${p.t}</span>`).join("")}</div>`;
    return `<div style="display:grid;margin-top:${mt}px;justify-items:${align === "center" ? "center" : "start"}">${under}${over}</div>`;
  };
  return `<div style="position:absolute;left:${x}px;top:${y}px;transform:rotate(${rot}deg);transform-origin:left top;${align === "center" ? "width:100%;left:0;" : ""}">
    ${lines.map((l) => row(l.parts, l.size, l.mt || 0)).join("")}</div>`;
}

const G = {
  red: ["#ff5a3c", "#c40000"], orange: ["#ffd23f", "#ff6a00"], white: ["#ffffff", "#c9d3e6"],
  gold: ["#fff4a8", "#ffae00"], green: ["#b8ff9a", "#18c23a"], cyan: ["#e8ffff", "#00c8ff"],
  pink: ["#ffe1fb", "#ff3df5"], sky: ["#ffffff", "#8fd8ff"],
};

const GAMES = [
  {
    slug: "the-night-shift",
    scene: nightShift,
    thumb: title([
      { parts: [{ t: "THE NIGHT", grad: G.red }], size: 190 },
      { parts: [{ t: "SHIFT", grad: G.red }], size: 230, mt: -18 },
      { parts: [{ t: "SURVIVE ", grad: G.orange }, { t: "TILL ", grad: G.white }, { t: "6AM", grad: G.orange }], size: 104, mt: 4 },
    ], { x: 60, y: 40, font: "Creepster", stroke: 26, glow: "0 0 40px rgba(255,30,0,.75)" }),
    icon: title([{ parts: [{ t: "NIGHT", grad: G.red }], size: 132 }, { parts: [{ t: "SHIFT", grad: G.orange }], size: 132, mt: -22 }],
      { x: 0, y: 270, font: "Creepster", stroke: 18, glow: "0 0 28px rgba(255,30,0,.8)", align: "center", rot: -3 }),
  },
  {
    slug: "sky-high-obby",
    scene: skyObby,
    thumb: title([
      { parts: [{ t: "SKY HIGH", grad: G.orange }], size: 190 },
      { parts: [{ t: "OBBY", grad: G.sky }], size: 270, mt: -4 },
      { parts: [{ t: "100+ ", grad: G.gold }, { t: "STAGES!", grad: G.white }], size: 92, mt: 14 },
    ], { x: 60, y: 46, font: "Luckiest", stroke: 26, glow: "0 0 40px rgba(255,170,60,.6)" }),
    icon: title([{ parts: [{ t: "OBBY", grad: G.orange }], size: 150 }],
      { x: 0, y: 340, font: "Luckiest", stroke: 20, glow: "0 0 30px rgba(255,170,60,.7)", align: "center", rot: -5 }),
  },
  {
    slug: "pizza-empire-tycoon",
    scene: pizzaTycoon,
    thumb: title([
      { parts: [{ t: "PIZZA", grad: G.gold }], size: 220 },
      { parts: [{ t: "TYCOON", grad: G.white }], size: 170, mt: -6 },
      { parts: [{ t: "+$1,000,000", grad: G.green }], size: 104, mt: 14 },
    ], { x: 60, y: 40, font: "Luckiest", stroke: 26, glow: "0 0 40px rgba(255,190,60,.6)" }),
    icon: title([{ parts: [{ t: "TYCOON", grad: G.gold }], size: 112 }],
      { x: 0, y: 370, font: "Luckiest", stroke: 18, glow: "0 0 30px rgba(255,190,60,.7)", align: "center", rot: -4 }),
  },
  {
    slug: "neon-defense",
    scene: neonDefense,
    thumb: title([
      { parts: [{ t: "NEON", grad: G.cyan }], size: 180 },
      { parts: [{ t: "DEFENSE", grad: G.pink }], size: 128, mt: 0 },
      { parts: [{ t: "BOSS ", grad: G.orange }, { t: "WAVE", grad: G.white }], size: 90, mt: 18 },
    ], { x: 60, y: 60, font: "Orbitron", stroke: 22, glow: "0 0 30px #00e5ff,0 0 60px rgba(255,61,245,.6)", rot: -3 }),
    icon: title([{ parts: [{ t: "NEON TD", grad: G.cyan }], size: 84 }],
      { x: 0, y: 400, font: "Orbitron", stroke: 16, glow: "0 0 24px #00e5ff", align: "center", rot: -3 }),
  },
];

// ---------- render ----------
function page(scene, overlay, w, h, viewBox, withInset) {
  // The reaction inset is only for the 16:9 thumbnail; icons crop it out anyway.
  return `<!doctype html><html><head><meta charset="utf-8"><style>${FONT_CSS}
    html,body{margin:0;padding:0;background:#000}
    .f{position:relative;width:${w}px;height:${h}px;overflow:hidden}
    .f svg{position:absolute;inset:0}</style></head><body><div class="f">
    <svg width="${w}" height="${h}" viewBox="${viewBox}" preserveAspectRatio="xMidYMid slice" xmlns="http://www.w3.org/2000/svg">
      <defs>${SHARED_DEFS}${scene.defs}</defs>${withInset ? scene.body : scene.body.replace(/<defs><clipPath id="insetClip">[\s\S]*$/, "")}</svg>${overlay}</div></body></html>`;
}

const SS = 2; // supersample factor: render at 2x, downscale for clean edges
const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const p = await (await browser.newContext({ deviceScaleFactor: SS })).newPage();
const scaler = await (await browser.newContext({ deviceScaleFactor: 1 })).newPage();
async function downscale(buf, w, h) {
  const b64 = await scaler.evaluate(async ({ src, w, h }) => {
    const img = new Image();
    img.src = src;
    await img.decode();
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    const ctx = c.getContext("2d");
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = "high";
    ctx.drawImage(img, 0, 0, w, h);
    return c.toDataURL("image/png").split(",")[1];
  }, { src: `data:image/png;base64,${buf.toString("base64")}`, w, h });
  return Buffer.from(b64, "base64");
}
for (const g of GAMES) {
  const scene = g.scene();
  const dir = join(OUT, g.slug);
  mkdirSync(dir, { recursive: true });
  const [ix, iy, is] = scene.icon;
  const jobs = [
    ["thumbnail-1920x1080.png", 1920, 1080, "0 0 1920 1080", g.thumb, true],
    ["icon-512x512.png", 512, 512, `${ix} ${iy} ${is} ${is}`, g.icon, false],
  ];
  for (const [file, w, h, vb, overlay, inset] of jobs) {
    await p.setViewportSize({ width: w, height: h });
    await p.setContent(page(scene, overlay, w, h, vb, inset), { waitUntil: "load" });
    await p.evaluate(() => document.fonts.ready);
    const big = await p.locator(".f").screenshot();
    writeFileSync(join(dir, file), await downscale(big, w, h));
    console.log("wrote", join(g.slug, file));
  }
}
await browser.close();
