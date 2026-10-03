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
  ${glow("bloom", 12)}${glow("bloomBig", 28)}${glow("glowU", 0.09)}
  <radialGradient id="pumpkinG" cx="0.45" cy="0.4" r="0.7"><stop offset="0" stop-color="#ffb347"/><stop offset="0.6" stop-color="#f07214"/><stop offset="1" stop-color="#b8480a"/></radialGradient>`;

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

// World position of a front avatar's right hand (handles flip).
function handWorld(x, y, s, rot, flip, armR) {
  const a = rad(armR), [px, py] = [1.5, 0.35];
  const lx = (px + (1.52 - px) * Math.cos(a) - (2.0 - py) * Math.sin(a)) * s * flip;
  const ly = (py + (1.52 - px) * Math.sin(a) + (2.0 - py) * Math.cos(a)) * s;
  const r = rad(rot);
  return [x + lx * Math.cos(r) - ly * Math.sin(r), y + lx * Math.sin(r) + ly * Math.cos(r)];
}
// Weapon drawn in world space from a hand, pointing at a target.
function aimed(weapon, hand, target, s) {
  const ang = (Math.atan2(target[0] - hand[0], -(target[1] - hand[1])) * 180) / Math.PI;
  return `<g transform="translate(${hand[0]} ${hand[1]}) rotate(${ang}) scale(${s})">${weapon}</g>`;
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
    angry: `<path d="M-0.38 -0.25 L-0.07 -0.12 M0.38 -0.25 L0.07 -0.12" stroke="${INK}" stroke-width="0.065" stroke-linecap="round"/>
            <ellipse cx="-0.2" cy="-0.02" rx="0.1" ry="0.075" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
            <ellipse cx="0.2" cy="-0.02" rx="0.1" ry="0.075" fill="#fff" stroke="${INK}" stroke-width="0.025"/>
            <circle cx="-0.16" cy="-0.01" r="0.045" fill="${INK}"/><circle cx="0.24" cy="-0.01" r="0.045" fill="${INK}"/>
            <path d="M-0.2 0.15 L0.2 0.15 L0.15 0.37 Q0 0.42 -0.15 0.37Z" fill="#3a0d12" stroke="${INK}" stroke-width="0.025"/>
            <path d="M-0.19 0.15 L0.19 0.15 L0.18 0.2 L-0.18 0.2Z" fill="#fff"/>`,
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

// Avatar facing the camera (fighting poses). flip=-1 mirrors it to face left.
// itemR / itemL are drawn in hand space: origin at the hand, arm pointing +y.
function avatarFront(x, y, s, o = {}) {
  const { skin = "#f2c48d", shirt = "#2a2f4a", pants = "#16182a", hair = "#3a2010", expr = "angry", pose = {}, rot = 0, flip = 1, itemR = "", itemL = "", rimId, sash, shadow = true } = o;
  const { armL = 0, armR = 0, legL = 0, legR = 0 } = pose;
  const sleeve = (x0) => `<rect x="${x0}" y="0" width="1" height="1.1" rx="0.14" fill="${shirt}" stroke="${INK}" stroke-width="0.07"/>`;
  const hand = (hx, item) => (item ? `<g transform="translate(${hx} 2.0)">${item}</g>` : "");
  return `<g ${rimId ? `filter="url(#${rimId})"` : ""}><g transform="translate(${x} ${y}) rotate(${rot}) scale(${s * flip} ${s})">
    ${shadow ? `<ellipse cx="0" cy="4.1" rx="1.9" ry="0.35" fill="#000" opacity="0.45"/>` : ""}
    ${limb(-1, 1.95, 1, 2.05, pants, legL, -0.5, 2, "left")}
    ${limb(0, 1.95, 1, 2.05, pants, legR, 0.5, 2, "left")}
    ${limb(-2.02, 0, 1, 2, skin, armL, -1.5, 0.35, "left", sleeve(-2.02) + hand(-1.52, itemL))}
    <rect x="-1" y="0" width="2" height="2.02" rx="0.1" fill="${shirt}" stroke="${INK}" stroke-width="0.07"/>
    ${sash ? `<path d="M-1 0.2 L-0.6 0 L1 1.6 L1 2 Z" fill="${sash}" filter="url(#glowU)"/>` : ""}
    <path d="M-0.35 0 L0 0.3 L0.35 0" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="0.07"/>
    <rect x="-1" y="0" width="2" height="2.02" rx="0.1" fill="url(#shadeR)"/>
    <g transform="translate(0 -0.78) scale(1.36)">${face(expr, { skin, hair })}</g>
    ${limb(1.02, 0, 1, 2, skin, armR, 1.5, 0.35, "left", sleeve(1.02) + hand(1.52, itemR))}
  </g></g>`;
}

// ---------- weapons (stud units, handle at origin, pointing -y) ----------
const neonSword = (c) => `<g>
  <rect x="-0.11" y="-0.15" width="0.22" height="0.75" rx="0.05" fill="#1a1a24" stroke="${INK}" stroke-width="0.05"/>
  <rect x="-0.45" y="-0.32" width="0.9" height="0.18" rx="0.06" fill="#2b2b38" stroke="${c}" stroke-width="0.06"/>
  <g filter="url(#glowU)"><path d="M-0.2 -0.32 L-0.2 -3.3 L0 -3.75 L0.2 -3.3 L0.2 -0.32Z" fill="${c}"/></g>
  <path d="M-0.08 -0.4 L-0.08 -3.3 L0 -3.55 L0.08 -3.3 L0.08 -0.4Z" fill="#fff" opacity="0.9"/></g>`;

function pumpkin(cx, cy, rx, ry, { sw = 0.05, face: f = "angry", glowId = "glowU", stem = true } = {}) {
  const P = (u, v) => `${cx + u * rx},${cy + v * ry}`;
  const seg = [[-0.5, 0.5, "#c94f06"], [0.5, 0.5, "#c94f06"], [-0.26, 0.56, "#e8650f"], [0.26, 0.56, "#e8650f"], [0, 0.56, "url(#pumpkinG)"]]
    .map(([u, w, fill]) => `<ellipse cx="${cx + u * rx}" cy="${cy}" rx="${w * rx}" ry="${ry}" fill="${fill}" stroke="#4a1a00" stroke-width="${sw}"/>`).join("");
  const poly = (pts) => `<polygon points="${pts.map(([u, v]) => P(u, v)).join(" ")}"/>`;
  const faceSvg = f ? `<g fill="#ffe066" filter="url(#${glowId})">
      ${poly([[-0.55, -0.32], [-0.1, -0.12], [-0.42, 0.06]])}${poly([[0.55, -0.32], [0.1, -0.12], [0.42, 0.06]])}
      ${poly([[0, 0], [0.09, 0.14], [-0.09, 0.14]])}
      ${poly([[-0.62, 0.2], [-0.42, 0.32], [-0.3, 0.22], [-0.15, 0.36], [0, 0.26], [0.15, 0.36], [0.3, 0.22], [0.42, 0.32], [0.62, 0.2], [0.46, 0.58], [0.22, 0.5], [0.1, 0.66], [-0.1, 0.66], [-0.22, 0.5], [-0.46, 0.58]])}</g>` : "";
  const stemSvg = stem ? `<path d="M${P(-0.08, -0.9)} Q${P(-0.05, -1.25)} ${P(0.16, -1.3)} L${P(0.18, -1.15)} Q${P(0.06, -1.1)} ${P(0.1, -0.9)}Z" fill="#3c7a1e" stroke="#1a3a0a" stroke-width="${sw}"/>` : "";
  return `${stemSvg}${seg}${faceSvg}`;
}

const pumpkinHammer = `<g>
  <rect x="-0.1" y="-2.7" width="0.2" height="3.2" rx="0.06" fill="#3a2414" stroke="${INK}" stroke-width="0.05"/>
  <g filter="url(#glowU)"><path d="M-0.1 -0.2 L0.1 -0.5 M-0.1 -0.7 L0.1 -1.0 M-0.1 -1.2 L0.1 -1.5" stroke="#b44dff" stroke-width="0.09"/></g>
  <path d="M-0.5 -3.0 Q-0.9 -4.6 -0.1 -5.0 Q-0.4 -4.3 0 -4.1 Q0.2 -4.8 0.6 -4.9 Q0.9 -4.0 0.5 -3.0Z" fill="#b44dff" opacity="0.75" filter="url(#glowU)"/>
  ${pumpkin(0, -3.3, 0.95, 0.78, { sw: 0.05 })}</g>`;

const neonBlaster = (c) => `<g transform="rotate(90)">
  <rect x="-0.18" y="-0.1" width="0.36" height="0.7" rx="0.06" fill="#20222e" stroke="${INK}" stroke-width="0.05" transform="rotate(-12)"/>
  <rect x="-0.32" y="-0.35" width="1.9" height="0.5" rx="0.1" fill="#2b2e3e" stroke="${INK}" stroke-width="0.05"/>
  <rect x="1.5" y="-0.26" width="0.45" height="0.3" fill="#3a3e52" stroke="${INK}" stroke-width="0.05"/>
  <g filter="url(#glowU)"><rect x="-0.2" y="-0.22" width="1.6" height="0.09" fill="${c}"/><circle cx="2.05" cy="-0.11" r="0.2" fill="${c}"/></g>
  <g filter="url(#glowU)"><rect x="2.6" y="-0.19" width="1.4" height="0.16" rx="0.08" fill="${c}"/><rect x="4.6" y="-0.19" width="1.1" height="0.16" rx="0.08" fill="${c}"/></g>
  <rect x="2.6" y="-0.15" width="1.4" height="0.07" rx="0.04" fill="#fff"/><rect x="4.6" y="-0.15" width="1.1" height="0.07" rx="0.04" fill="#fff"/></g>`;

const coinW = (x, y, k, tilt = 1) => `<g transform="translate(${x} ${y}) scale(${k * tilt} ${k})"><circle r="40" fill="#c98a00" stroke="${INK}" stroke-width="5"/><circle r="30" fill="#ffd23f" stroke="#e6a400" stroke-width="4"/><text y="13" text-anchor="middle" font-family="Luckiest" font-size="38" fill="#e6a400">$</text></g>`;
const burst = (x, y, k, col = "#fff6b0") => `<g transform="translate(${x} ${y}) scale(${k})">
  <circle r="70" fill="#fff" filter="url(#bloomBig)"/>
  <g filter="url(#bloom)">${Array.from({ length: 14 }, (_, i) => { const a = (i / 14) * 6.283, L = i % 2 ? 110 : 180; return `<path d="M${Math.cos(a + 0.06) * 20} ${Math.sin(a + 0.06) * 20} L${Math.cos(a) * L} ${Math.sin(a) * L} L${Math.cos(a - 0.06) * 20} ${Math.sin(a - 0.06) * 20}Z" fill="${col}"/>`; }).join("")}</g>
  <circle r="34" fill="#fff"/></g>`;
const bat = (x, y, k) => `<path transform="translate(${x} ${y}) scale(${k})" d="M0 4 C-8 -6 -22 -10 -40 -4 C-32 0 -30 6 -32 10 C-24 6 -16 8 -12 14 C-8 8 -4 8 0 10 C4 8 8 8 12 14 C16 8 24 6 32 10 C30 6 32 0 40 -4 C22 -10 8 -6 0 4Z M-5 -2 L-4 -9 L-1 -4 L1 -4 L4 -9 L5 -2Z" fill="#07030c"/>`;

// ---------- scenes (1920x1080 canvas) ----------

function swordTycoon() {
  const r = rng(21);
  const VP = [960, 640];
  const floorLines = (col, x0, x1) => Array.from({ length: 13 }, (_, i) => {
    const bx = x0 + ((x1 - x0) * i) / 12;
    return `<line x1="${VP[0] + (bx - VP[0]) * 0.08}" y1="${VP[1]}" x2="${bx}" y2="1080" stroke="${col}"/>`;
  }).join("");
  const hl = Array.from({ length: 8 }, (_, i) => { const y = VP[1] + (1080 - VP[1]) * Math.pow(i / 7, 2); return `<line x1="0" y1="${y}" x2="1920" y2="${y}"/>`; }).join("");
  const base = (x, col, flip) => `<g transform="translate(${x} 0) scale(${flip} 1)">
      <rect x="0" y="330" width="300" height="320" fill="#120c22" stroke="${col}" stroke-width="5" filter="url(#bloom)"/>
      <rect x="40" y="210" width="140" height="130" fill="#120c22" stroke="${col}" stroke-width="5"/>
      <path d="M30 210 L110 150 L190 210Z" fill="#120c22" stroke="${col}" stroke-width="5"/>
      <rect x="108" y="60" width="6" height="95" fill="#ccc"/><path d="M114 62 L190 82 L114 104Z" fill="${col}" filter="url(#bloom)"/>
      ${[0, 1, 2].map((i) => `<rect x="${40 + i * 85}" y="400" width="50" height="60" fill="${col}" opacity="0.5"/><rect x="${40 + i * 85}" y="520" width="50" height="60" fill="${col}" opacity="0.35"/>`).join("")}
      <path d="M300 520 L520 520 L520 545 L300 545Z" fill="#2a2440" stroke="${col}" stroke-width="3"/>
      ${[0, 1, 2, 3].map((i) => coinW(330 + i * 50, 505, 0.35)).join("")}</g>`;
  const lights = [[200, "#ff2d55", 18], [700, "#ff7a1a", 8], [1220, "#00c8ff", -8], [1720, "#3d7bff", -18]].map(([x, c, a]) =>
    `<path d="M${x - 30} -20 L${x + 30} -20 L${x + 260} 1000 L${x - 260} 1000Z" fill="${c}" opacity="0.18" transform="rotate(${a} ${x} 0)" style="mix-blend-mode:screen" filter="url(#dof)"/>`).join("");
  const coinsFloat = Array.from({ length: 10 }, () => coinW(300 + r() * 1320, 120 + r() * 300, 0.4 + r() * 0.4, 0.3 + r() * 0.7)).join("");
  const sparks = Array.from({ length: 26 }, () => { const a = r() * 6.28, d = 60 + r() * 260; return `<circle cx="${980 + Math.cos(a) * d}" cy="${420 + Math.sin(a) * d * 0.7}" r="${2 + r() * 5}" fill="${r() > 0.5 ? "#fff3a0" : "#ffffff"}" filter="url(#bloom)"/>`; }).join("");
  const jacks = [[130, 1010, 60], [1800, 1020, 64], [560, 1050, 40]].map(([x, y, k]) => `<g>${pumpkin(x, y, k, k * 0.8, { sw: 4, glowId: "bloom" })}</g>`).join("");
  return {
    defs: `${rimFilter("rimRed", "#ff3b3b", 7, 3, 16)}${rimFilter("rimBlue", "#21d4ff", -7, 3, 16)}
      <linearGradient id="asky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05030f"/><stop offset="0.7" stop-color="#1e0b3a"/><stop offset="1" stop-color="#3a1048"/></linearGradient>
      <linearGradient id="afloor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#140a26"/><stop offset="1" stop-color="#05030c"/></linearGradient>
      <linearGradient id="teamSplit" x1="0" x2="1"><stop offset="0" stop-color="#ff2d55" stop-opacity="0.35"/><stop offset="0.5" stop-color="#ff2d55" stop-opacity="0"/><stop offset="0.5" stop-color="#00c8ff" stop-opacity="0"/><stop offset="1" stop-color="#00c8ff" stop-opacity="0.35"/></linearGradient>`,
    body: `<rect width="1920" height="1080" fill="url(#asky)"/>
      <circle cx="960" cy="190" r="120" fill="#fff4dc" opacity="0.9" filter="url(#bloomBig)"/>
      ${bat(820, 150, 1.2)}${bat(1120, 110, 0.9)}${bat(1010, 240, 0.7)}
      <g filter="url(#dof)">${base(40, "#ff2d55", 1)}${base(1880, "#00c8ff", -1)}</g>
      ${lights}
      <rect y="${VP[1]}" width="1920" height="${1080 - VP[1]}" fill="url(#afloor)"/>
      <g stroke-width="2.5" opacity="0.6" filter="url(#bloom)">${floorLines("#ff2d55", -1400, 960)}${floorLines("#00c8ff", 960, 3320)}<g stroke="#a04dff">${hl}</g></g>
      <rect y="${VP[1]}" width="1920" height="${1080 - VP[1]}" fill="url(#teamSplit)" style="mix-blend-mode:screen"/>
      <line x1="960" y1="${VP[1]}" x2="960" y2="1080" stroke="#fff" stroke-width="4" opacity="0.6" filter="url(#bloom)"/>
      ${coinsFloat}
      ${avatarFront(230, 620, 70, { shirt: "#3a0d16", pants: "#1a0a10", hair: "#5a2410", sash: "#ff2d55", rot: -8, expr: "angry", pose: { armL: 30, armR: -165, legL: 22, legR: -10 }, itemR: `<g transform="rotate(170)">${pumpkinHammer}</g>`, rimId: "rimRed" })}
      ${avatarFront(1730, 620, 70, { shirt: "#0d1f3a", pants: "#0a1020", hair: "#e8c45a", skin: "#e0ac7a", sash: "#00c8ff", flip: -1, rot: 6, expr: "angry", pose: { armL: 20, armR: -95, legL: 18, legR: -12 }, itemR: neonBlaster("#00e5ff"), rimId: "rimBlue" })}
      ${avatarFront(560, 590, 92, { shirt: "#5a0f1e", pants: "#1a0a10", hair: "#1a1010", sash: "#ff2d55", rot: 8, expr: "angry", pose: { armL: 35, armR: -70, legL: 30, legR: -24 }, rimId: "rimRed" })}
      ${avatarFront(1390, 590, 92, { shirt: "#102a5a", pants: "#0a1020", hair: "#7a3e1a", sash: "#00c8ff", flip: -1, rot: -8, expr: "angry", pose: { armL: 35, armR: -70, legL: 30, legR: -24 }, rimId: "rimBlue" })}
      ${(() => {
        const hb = handWorld(560, 590, 92, 8, 1, -70), hc = handWorld(1390, 590, 92, -8, -1, -70);
        const db = [0.75, -1], dc = [-0.75, -1];
        // intersection of the two blade lines = clash point
        const t = ((hc[0] - hb[0]) * dc[1] - (hc[1] - hb[1]) * dc[0]) / (db[0] * dc[1] - db[1] * dc[0]);
        const X = [hb[0] + db[0] * t, hb[1] + db[1] * t];
        return `<g filter="url(#rimRed)">${aimed(neonSword("#ff2d3d"), hb, [hb[0] + db[0], hb[1] + db[1]], 98)}</g>
          <g filter="url(#rimBlue)">${aimed(neonSword("#21d4ff"), hc, [hc[0] + dc[0], hc[1] + dc[1]], 98)}</g>
          ${burst(X[0], X[1], 1.0)}`; })()}
      ${sparks}
      ${jacks}
      <rect width="1920" height="1080" fill="url(#vig)" opacity="0.8"/>
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [475, 150, 930],
  };
}

function surviveHalloween() {
  const r = rng(31);
  const trees = [[90, 640, 1], [1180, 660, 0.8], [520, 600, 0.7]].map(([x, y, k]) => `<g transform="translate(${x} ${y}) scale(${k})" stroke="#0b0614" stroke-linecap="round" fill="none">
      <path d="M0 0 L0 -260" stroke-width="30"/><path d="M0 -140 L-90 -230 L-130 -240 M-90 -230 L-100 -290" stroke-width="16"/><path d="M0 -200 L80 -280 L140 -285 M80 -280 L90 -340" stroke-width="14"/><path d="M0 -255 L-30 -330" stroke-width="10"/></g>`).join("");
  const graves = [[300, 690], [420, 700], [980, 690], [1100, 700]].map(([x, y]) => `<path d="M${x - 30} ${y} L${x - 30} ${y - 60} Q${x} ${y - 95} ${x + 30} ${y - 60} L${x + 30} ${y}Z" fill="#1a1428"/>`).join("");
  const bats = [[1000, 120, 1.3], [1120, 200, 0.9], [760, 90, 0.8], [1880, 470, 1], [1250, 330, 0.7], [640, 240, 0.6]].map((b) => bat(...b)).join("");
  // obby platforms with level signs, rising from bottom-left toward the centre
  const plat = (x, y, w, top, side, lvl) => `<g>
      <path d="M${x} ${y} L${x + 30} ${y - 18} L${x + w + 30} ${y - 18} L${x + w} ${y}Z" fill="${top}" stroke="${INK}" stroke-width="4"/>
      <path d="M${x + w} ${y} L${x + w + 30} ${y - 18} L${x + w + 30} ${y + 22} L${x + w} ${y + 40}Z" fill="${side}" stroke="${INK}" stroke-width="4"/>
      <rect x="${x}" y="${y}" width="${w}" height="40" fill="${side}" stroke="${INK}" stroke-width="4"/>
      ${lvl ? `<g transform="translate(${x + w / 2} ${y - 20})"><rect x="-4" y="-90" width="8" height="90" fill="#555"/>
        <rect x="-62" y="-140" width="124" height="56" rx="10" fill="#140a22" stroke="${lvl[1]}" stroke-width="5" filter="url(#bloom)"/>
        <text y="-100" text-anchor="middle" font-family="Luckiest" font-size="38" fill="#fff">LVL ${lvl[0]}</text></g>` : ""}</g>`;
  const obby = [
    plat(40, 930, 230, "#78ebbe", "#ff7ab8", [1, "#7dff5c"]),
    plat(360, 840, 170, "#ff9a2e", "#c25a0a", [50, "#ffb03d"]),
    plat(610, 760, 140, "#78ebbe", "#ff7ab8", [99, "#ff3df5"]),
  ].join("");
  const spinner = `<g transform="translate(480 900) rotate(-12)" filter="url(#bloom)"><rect x="-150" y="-10" width="300" height="20" rx="10" fill="#ff2d3d"/></g><circle cx="480" cy="900" r="16" fill="#333" stroke="${INK}" stroke-width="4"/>`;
  const goo = `<path d="M0 1000 Q120 975 240 1000 T480 1000 T720 1000 T960 1000 T1200 1000 L1200 1080 L0 1080Z" fill="#6dff3a" filter="url(#bloom)"/>
      <path d="M0 1015 Q120 995 240 1015 T480 1015 T720 1015 T960 1015 T1200 1015 L1200 1080 L0 1080Z" fill="#2fa80e"/>
      ${Array.from({ length: 9 }, () => `<circle cx="${r() * 1150}" cy="${1010 + r() * 50}" r="${6 + r() * 12}" fill="#b6ff8a" opacity="0.8"/>`).join("")}`;
  const fog = Array.from({ length: 7 }, (_, i) => `<ellipse cx="${i * 320}" cy="${700 + (i % 2) * 30}" rx="320" ry="60" fill="#c9b6ff" opacity="0.12" filter="url(#soft)"/>`).join("");
  // Pumpkin King boss
  const boss = `<g>
      <ellipse cx="1600" cy="560" rx="420" ry="520" fill="#7a2aff" opacity="0.35" filter="url(#soft)"/>
      <path d="M1380 560 Q1600 480 1830 560 L1980 1080 L1240 1080Z" fill="#1c0c2e" stroke="#0a0412" stroke-width="6"/>
      <path d="M1240 1080 L1290 1020 L1330 1080 L1380 1010 L1420 1080Z M1700 1080 L1760 1000 L1800 1080 L1860 1010 L1920 1080Z" fill="#05020a"/>
      <rect x="1330" y="800" width="560" height="70" rx="12" fill="#ffc933" stroke="#7a4a00" stroke-width="6"/>
      <rect x="1330" y="800" width="560" height="20" rx="8" fill="#fff2a8" opacity="0.6"/>
      <path d="M1600 790 L1650 835 L1600 880 L1550 835Z" fill="#ff2d6e" stroke="#7a0020" stroke-width="5" filter="url(#bloom)"/>
      <path d="M1585 815 L1600 800 L1615 815Z" fill="#fff" opacity="0.8"/>
      <ellipse cx="1405" cy="560" rx="105" ry="55" fill="#ffc933" stroke="#7a4a00" stroke-width="6"/><ellipse cx="1395" cy="545" rx="60" ry="18" fill="#fff2a8" opacity="0.6"/>
      <ellipse cx="1800" cy="560" rx="105" ry="55" fill="#ffc933" stroke="#7a4a00" stroke-width="6"/><ellipse cx="1790" cy="545" rx="60" ry="18" fill="#fff2a8" opacity="0.6"/>
      <g transform="rotate(-24 1380 600)"><rect x="1300" y="580" width="110" height="330" rx="18" fill="#2a1240" stroke="#0a0412" stroke-width="6"/>
        <path d="M1300 900 L1290 960 L1320 930 L1335 975 L1355 930 L1375 970 L1390 925 L1415 950 L1410 900Z" fill="#e9dcc8" stroke="#0a0412" stroke-width="4"/></g>
      <g transform="rotate(-18 1250 700)"><rect x="1236" y="120" width="26" height="900" rx="10" fill="#2a1a10" stroke="#0a0412" stroke-width="5"/>
        <path d="M1262 150 Q1120 90 990 220 Q1110 150 1250 210Z" fill="#c6ff9a" stroke="#7dff5c" stroke-width="6" filter="url(#bloom)"/></g>
      <g filter="url(#rimGreen)">${pumpkin(1600, 360, 230, 190, { sw: 8, glowId: "bloomBig" })}</g>
      <path d="M1450 190 L1470 120 L1520 165 L1600 95 L1680 165 L1730 120 L1750 190Z" fill="#ffcc33" stroke="#7a4a00" stroke-width="6"/>
      <circle cx="1600" cy="140" r="14" fill="#ff2d55"/></g>`;
  const slash = `<path d="M1180 180 Q1420 330 1300 640 Q1350 360 1180 180Z" fill="#c9f6ff" filter="url(#bloom)" opacity="0.95"/>
      <path d="M1150 160 Q1460 340 1290 700" fill="none" stroke="#7de8ff" stroke-width="10" opacity="0.6" filter="url(#bloom)"/>`;
  return {
    defs: `${rimFilter("rimMoon", "#c8e6ff", -6, 5, 16)}${rimFilter("rimGreen", "#7dff5c", 6, 4, 22)}${rimFilter("rimOrange2", "#ff9a3d", -6, 3, 12)}
      <linearGradient id="hsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#07041a"/><stop offset="0.6" stop-color="#2a0f4a"/><stop offset="1" stop-color="#ff6a1a"/></linearGradient>
      <radialGradient id="moonG" cx="0.4" cy="0.4" r="0.6"><stop offset="0" stop-color="#fffbe8"/><stop offset="1" stop-color="#ffd9a0"/></radialGradient>`,
    body: `<rect width="1920" height="1080" fill="url(#hsky)"/>
      ${Array.from({ length: 60 }, () => `<circle cx="${r() * 1920}" cy="${r() * 450}" r="${r() * 2 + 0.4}" fill="#fff" opacity="${0.3 + r() * 0.6}"/>`).join("")}
      <circle cx="1600" cy="330" r="330" fill="#ffb347" opacity="0.35" filter="url(#bloomBig)"/>
      <circle cx="1600" cy="330" r="280" fill="url(#moonG)"/>
      <g filter="url(#dof)"><path d="M0 700 Q300 640 600 690 T1200 680 T1920 700 L1920 1080 L0 1080Z" fill="#120a20"/>${trees}${graves}</g>
      ${fog}${bats}
      ${boss}
      ${goo}${obby}${spinner}
      ${avatarFront(250, 560, 40, { shirt: "#ff8a1a", pants: "#2a1a40", hair: "#1a1010", expr: "shocked", rot: 18, shadow: false, pose: { armL: 150, armR: -150, legL: 35, legR: -40 }, rimId: "rimOrange2" })}
      ${slash}
      ${avatarFront(950, 470, 84, { shirt: "#2a1a4a", pants: "#120c22", hair: "#d8d8e8", sash: "#7de8ff", expr: "angry", rot: 22, shadow: false, pose: { armL: 60, armR: -165, legL: 40, legR: -30 }, itemR: `<g transform="rotate(195)">${neonSword("#7de8ff")}</g>`, rimId: "rimMoon" })}
      ${burst(1300, 470, 0.7, "#c9f6ff")}
      <rect width="1920" height="1080" fill="url(#vig)" opacity="0.8"/>
      <rect width="1920" height="1080" filter="url(#grain)"/>`,
    icon: [1080, 60, 820],
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
  pink: ["#ffe1fb", "#ff3df5"], sky: ["#ffffff", "#8fd8ff"], purple: ["#f1dcff", "#9a3dff"],
};

const GAMES = [
  {
    slug: "2v2-sword-tycoon",
    scene: swordTycoon,
    thumb: title([
      { parts: [{ t: "2", grad: G.red }, { t: "V", grad: G.white }, { t: "2 ", grad: G.cyan }, { t: "SWORD TYCOON", grad: G.gold }], size: 138 },
    ], { x: 0, y: 46, font: "Luckiest", stroke: 24, glow: "0 0 40px rgba(255,80,120,.55),0 0 60px rgba(0,200,255,.4)", align: "center", rot: -2 })
      + `<div style="position:absolute;left:36px;bottom:40px;transform:rotate(-3deg);background:linear-gradient(180deg,#ff9a1a,#d84a00);border:8px solid #000;border-radius:22px;padding:12px 30px 4px;box-shadow:0 0 40px rgba(255,140,0,.6)">
          <span style="font:64px/1 Luckiest;color:#fff;-webkit-text-stroke:8px #000;paint-order:stroke fill">NEW HALLOWEEN WEAPONS!</span></div>`,
    icon: title([{ parts: [{ t: "2", grad: G.red }, { t: "V", grad: G.white }, { t: "2", grad: G.cyan }], size: 190 }],
      { x: 0, y: 330, font: "Luckiest", stroke: 24, glow: "0 0 30px rgba(255,255,255,.4)", align: "center", rot: -4 }),
  },
  {
    slug: "survive-halloween",
    scene: surviveHalloween,
    thumb: title([
      { parts: [{ t: "SURVIVE", grad: G.orange }], size: 190 },
      { parts: [{ t: "HALLOWEEN", grad: G.purple }], size: 165, mt: -16 },
      { parts: [{ t: "BOSS ", grad: G.red }, { t: "+ ", grad: G.white }, { t: "OBBY", grad: G.green }], size: 96, mt: 6 },
    ], { x: 50, y: 30, font: "Creepster", stroke: 24, glow: "0 0 40px rgba(255,120,0,.6)" })
      + `<div style="position:absolute;left:520px;top:345px;transform:rotate(-5deg);background:linear-gradient(180deg,#b44dff,#5a12b0);border:8px solid #000;border-radius:20px;padding:10px 26px 2px;box-shadow:0 0 36px rgba(180,77,255,.7)">
          <span style="font:54px/1 Luckiest;color:#fff;-webkit-text-stroke:8px #000;paint-order:stroke fill">100 LEVELS!</span></div>`
      + `<div style="position:absolute;right:40px;top:36px;width:620px;text-align:right">
          <div style="font:46px/1 Luckiest;color:#fff;-webkit-text-stroke:8px #000;paint-order:stroke fill;letter-spacing:2px">👑 PUMPKIN KING</div>
          <div style="margin-top:10px;height:40px;border:6px solid #000;border-radius:12px;background:#2a0a10;overflow:hidden;box-shadow:0 0 24px rgba(255,40,60,.6)">
            <div style="width:62%;height:100%;margin-left:auto;background:linear-gradient(180deg,#ff6a7a,#d0102a)"></div></div></div>`,
    icon: title([{ parts: [{ t: "SURVIVE", grad: G.orange }], size: 100 }, { parts: [{ t: "HALLOWEEN", grad: G.purple }], size: 84, mt: -10 }],
      { x: 0, y: 320, font: "Creepster", stroke: 16, glow: "0 0 26px rgba(255,120,0,.7)", align: "center", rot: -3 }),
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
