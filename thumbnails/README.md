# Roblox game thumbnails

Ready-to-upload PNGs live in `output/<game>/`:

| File | Size | Where it goes on Roblox |
| --- | --- | --- |
| `thumbnail-1920x1080.png` | 1920×1080 (16:9) | Experience → Places → Thumbnails |
| `icon-512x512.png` | 512×512 (1:1) | Experience → Basic Info → Icon |

Games: `2v2-sword-tycoon`, `survive-halloween`.

## Regenerate / edit

```sh
node thumbnails/render.mjs
```

Titles and taglines are in the `GAMES` list at the bottom of `render.mjs`. Each scene
(neon team arena, Pumpkin King boss + obby) is a function above it. Images render at 2×
and are downscaled for clean edges. Fonts are from Google Fonts (SIL OFL, see `fonts/*.LICENSE`).
