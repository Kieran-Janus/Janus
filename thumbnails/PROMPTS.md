# AI image prompts: cinematic Roblox thumbnail style

These prompts match the "Nightmare Trick or Treat" reference: a glossy 3D render, Roblox
characters, dramatic warm-vs-cool lighting, a big dripping title and a reaction-face inset.
Paste one into an image generator (ChatGPT, Gemini, Midjourney, Ideogram…) and ask for
**16:9 landscape, highest resolution available**.

Then fit the result to Roblox's exact frames:

```sh
node thumbnails/frame.mjs path/to/generated.png --name survive-halloween --icon-focus 0.7,0.45
```

This writes `output/<name>/thumbnail-1920x1080.png` and `icon-512x512.png`. `--icon-focus`
sets where the square icon crop is centred (x,y from 0 to 1). Point it at the boss or the
main character.

---

## Survive Halloween

```
Cinematic 3D Roblox game thumbnail, 16:9, ultra-detailed glossy Roblox render style with
blocky Roblox avatar characters (R15 proportions, smooth plastic shading, expressive faces).

Scene: a Halloween night arena on a haunted hill under a huge full moon. On the right, the
giant boss "Pumpkin King" towers over everything: a huge glowing jack-o'-lantern head with
angry carved eyes and jagged grin, a golden crown, gold shoulder pads, a gold belt with a
big pink gem, and a dark purple tattered cloak, swinging a glowing green scythe. A red boss
health bar labelled "PUMPKIN KING" floats above him.

In the centre, a Roblox hero leaps at the boss mid-air, swinging a glowing cyan neon sword
with a bright slash trail and sparks on impact. On the left, another Roblox player jumps
across a floating obby course of candy-mint green platforms with pink trim, over bubbling
glowing green goo. Neon signs on poles above the platforms read "LVL 1", "LVL 50", "LVL 99".
Bats, floating fireflies, purple fog, jack-o'-lanterns on the ground.

Lighting: strong orange glow from the boss's face vs cool blue-purple moonlight, rim light
on every character, bloom, depth of field, high contrast, vibrant saturated colours.

Text: top-left big dripping horror title "SURVIVE HALLOWEEN", with "SURVIVE" in fiery orange
and "HALLOWEEN" in glowing purple, thick black outline. Below it, a smaller line "BOSS + OBBY".
A purple badge "100 LEVELS!".

Bottom-left corner: a close-up inset of a Roblox character's terrified face (wide eyes, open
mouth, hands on cheeks) inside a jagged frame with a glowing red border, plus white shock lines.
```

## 2v2 Sword Tycoon

```
Cinematic 3D Roblox game thumbnail, 16:9, ultra-detailed glossy Roblox render style with
blocky Roblox avatar characters (R15 proportions, smooth plastic shading, expressive
determined faces).

Scene: an epic 2v2 battle in a neon tycoon arena at night. Red team (two players with red
glowing outfits) on the left vs blue team (two players with blue/cyan glowing outfits) on
the right. Behind each team stands their tycoon base, a multi-floor tower with neon red or
neon blue trim, gold coins pouring from generators.

Centre: two fighters clash, a glowing red neon sword crossing a glowing cyan neon sword in an
X, with a huge burst of sparks and light at the impact point. Far left: a red player swings a
Halloween weapon, a giant glowing jack-o'-lantern hammer with purple flames. Far right: a blue
player fires a neon laser blaster, cyan laser bolts flying. Gold coins and sparkles in the air,
a neon ring on the arena floor, a full moon with bats, a few jack-o'-lanterns at the arena edge.

Lighting: red light on the left half, cyan light on the right half, rim light on every
character, bloom, depth of field, dramatic high contrast, vibrant saturated colours.

Text: top centre, huge bold title "2V2 SWORD TYCOON", with "2" in red, "V" in white, "2" in
blue, and "SWORD TYCOON" in shiny gold, thick black outline. Bottom-left: orange badge
"NEW HALLOWEEN WEAPONS!".

Bottom-right corner (optional): a close-up inset of a Roblox character's hyped face inside a
jagged frame with a glowing gold border.
```

### Tips
- Image generators sometimes misspell text. If they do, generate again, or ask for the same
  image with **no text** and say so. The coded titles from `render.mjs` can then be overlaid.
- Roblox moderates thumbnails: keep it spooky but not gory, and avoid real brands or logos.
- Name the game's real weapons ("Phoenix Sword", "Reaper Scythe", "Thunder Hammer", "Ray Gun")
  in the prompt to show off what's actually in the game.
