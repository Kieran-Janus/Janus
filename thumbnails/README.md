# Roblox game thumbnails

Ready-to-upload PNGs live in `output/<game>/`:

| File | Size | Where it goes on Roblox |
| --- | --- | --- |
| `thumbnail-1920x1080.png` | 1920×1080 (16:9) | Experience → Places → Thumbnails |
| `icon-512x512.png` | 512×512 (1:1) | Experience → Basic Info → Icon |

Games: `2v2-sword-tycoon`, `survive-halloween`, `pumpkin-panic` (v1, drawn) and
`pumpkin-panic-v2` (made from renders of the real game, below).

## Regenerate / edit

```sh
node thumbnails/render.mjs
```

Titles and taglines are in the `GAMES` list at the bottom of `render.mjs`. Each scene
(neon team arena, Pumpkin King boss + obby) is a function above it. Images render at 2×
and are downscaled for clean edges. Fonts are from Google Fonts (SIL OFL, see `fonts/*.LICENSE`).

## Pumpkin Panic v2 (`output/pumpkin-panic-v2/`)

Seven images made from renders of the **real game**: the lobby, the round maps, the skins and
the props are built by the game's own code (`new-game/src`) in the offline test harness, then
rendered and given titles. Nothing in them is painted in by hand.

| File | Size | What it shows | Where it goes on Creator Hub |
| --- | --- | --- | --- |
| `01-main.png` | 1920×1080 | PUMPKIN PANIC + "Survive the Pumpkin King!": the lobby at dusk, the Ready circle under its pumpkin arch, the crooked clock tower | Places → Thumbnails (put it **first**) |
| `02-tormented-tower.png` | 1920×1080 | "Can you climb it?": the Tormented Tower (clock tower) from its doorway | Places → Thumbnails |
| `03-hide-and-seek.png` | 1920×1080 | "Hide as a pumpkin!": Pumpkin Farm, one glowing pumpkin is a hider, a seeker with the candy gun | Places → Thumbnails |
| `04-scaremaze.png` | 1920×1080 | "Don't stop moving!": ScareMaze at night, a ghost and bats jump out | Places → Thumbnails |
| `05-skins.png` | 1920×1080 | "630+ skins!" + "1 in a million": the CRAZY skins at the Mystery Crates stand | Places → Thumbnails |
| `06-minigames.png` | 1920×1080 | Parkour, Candy Rush and Web Scour | Places → Thumbnails |
| `icon-512.png` | 512×512 | The Pumpkin King's glowing face in front of his clock tower (no text) | Basic Info → Icon |
| `contact-sheet.png` | – | All seven, small (for reviewing, not for upload) | – |

Creator Hub: Creations → Pumpkin Panic → **Places** → the start place → **Thumbnails** (upload
01 to 06, drag 01 to the front; up to 10 are allowed) and **Basic Info** → **Icon** (upload
`icon-512.png`; Roblox rounds its corners). Thumbnails and icons are moderated before they show.

### Regenerate after the game changes

From the repo root, in the cloud environment (it needs the offline preview tooling in
`/tmp/claude-0`: Lune and the scene previewer, see `new-game/tests/README.md` > Preview images):

```sh
node thumbnails/v2.mjs                 # everything: scenes, renders, images (~4 minutes)
node thumbnails/v2.mjs --only 03,icon  # just some images (ids or file-name prefixes)
node thumbnails/v2.mjs --reuse         # keep scenes/renders whose settings didn't change
node thumbnails/v2.mjs --compose       # only redo titles and layout from the last renders
node thumbnails/v2.mjs --try farm --camera "x,y,z->x,y,z" [--camera ...]   # test cameras
```

Run it **without** `--reuse` after the game changed (a new lobby, map or skin), so the scenes
are built again from `new-game/src`. Work files (scene JSONs, raw renders, the 480×270 and
150 px previews used to check the text reads small) go to `new-game/tests/out/thumbnails-v2/`
(git-ignored). Override the tools with `LUNE`, `ROBLOX_PREVIEW_RENDERER` and `V2_WORK`.

How it works:

- `thumbnails/v2-scene.luau` (Lune) builds a scene in the test harness: `HubBuilder.Build()`
  for the lobby or `MapService.Load(id)` for a map, plus posed mannequins wearing real skins
  (`Cosmetics.Wear`, with one frame of the CRAZY orbit pieces), the seekers' candy gun, Hide &
  Seek pumpkins, ScareMaze actors (ghost, bats...) and Candy Rush candies, and exports it for the
  previewer. With `{ "facts": ... }` it counts what the text may claim from Config.
- `thumbnails/v2.mjs` holds the shots: `SCENES` (who stands where, in which skin), `RENDERS`
  (cameras) and `SHOTS` (titles and layout, HTML/CSS composited in headless Chromium at 2×).
  Flat silhouette renders tell sky from scenery (the dusk sky, stars and moon are drawn only in
  the sky), cut out the icon's subjects, and show where in-game sign text (SurfaceGuis, which
  the previewer doesn't draw) is visible, so "PLAY!", "MYSTERY CRATES", "CANDY RUSH" appear
  on their real signs.
- The text stays true: the skin count comes from `Config.Shop.Items` (634 skins today, shown as
  "630+"; it updates itself), "1 in a million" from the skins with `OneInAMillion = true`
  (Night Lord Supreme, Disco Demon, Star Voyager), and every mode and minigame shown is
  switched on in `Config.Features`. No Robux claims, Roblox logos or game UI.
