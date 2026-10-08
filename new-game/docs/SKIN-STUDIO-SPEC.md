# Skin Studio, animated skins, walk styles and catalog items: build spec

Written 8 October 2026 on branch `claude/clever-clarke-3zqgma` (base `1765a6d`) from Kieran's request: *"can you give me a way of changing and animating the skins in the game"*. Revised the same day after a review: section 16 lists what changed and what was not taken. This is the contract two builders follow so their work fits together. Builder A makes the animation system and catalog items. Builder B makes the Skin Studio editor and saving. An integration step (section 8.4) joins them. The plain-English version for Kieran goes in `docs/CUSTOMIZE.md` (section 13).

## 0. In plain English (for Kieran)
- **Skins can move.** Wings flap, tails wag, capes sway, head pieces spin, bob or float. Colours fade, glows flicker and sparkles burst. You write this in a skin's `Style` (`Animate = { ... }`) or pick it in Skin Studio. Everyone in the server sees it.
- **CRAZY effects stay as they are.** `Crazy = { Rainbow = true, Pulse = true, Orbit = ... }` still does the rainbow, the pulsing glow and the orbiting pieces. `Animate` adds *other* movement and can't touch what CRAZY already drives (section 3.2a).
- **Walk styles.** A skin can make you walk like a zombie, float like a ghost, march like a robot or flap like a bat (`Motion = "Zombie"`). You can also use your own uploaded walk, run and idle animations.
- **Your own animated models.** Build a model in Studio and put it in `ReplicatedStorage > Custom > Cosmetics`, named after the skin. Give any part the attribute `Animate = "Spin"` and that part spins. Spin, Bob, Wobble and the other effects work the same way.
- **Real Roblox catalog items.** A skin can add catalog hats, hair, back items and classic shirts or pants. Only items made by Roblox, by you or by your group are allowed, and only ids you have approved (because crates are sold for Robux). This is off until you've tried it in Studio (section 5).
- **Skin Studio.** Start a Studio playtest and open Menu > Skin Studio (or F8 > Skin Studio). Pick any skin or make a new one, then change everything with colour pickers, sliders and dropdowns. You see it on your own character straight away, animations included. Press Save, then type `/save-skins` in Claude Code **before you press Stop**. Claude Code writes your skins into the game files and runs the tests. Closing the panel by accident loses nothing. The "Copy code" button always works as a backup.

## 1. Scope
**In scope:**
- `Style.Animate`: a list of effects on skin pieces, the glow, the aura and body colours.
- Animated parts inside custom models.
- `Style.Motion`: walk styles, made in code or from uploaded animation ids.
- `Style.Catalog`: rigid catalog accessories, classic clothes and a classic face, from approved creators only.
- Skin Studio: an editor for admins in Studio, with saving to the repo.
- Tests, docs and Config for all of the above.

**Not in scope:**
- Players designing their own skins in live games. Player data is unchanged: no new saved fields, no `Config.Data.Template` change.
- Bundles, body parts, body scales, layered clothing and catalog animation packs inside skins (section 5.1 says why).
- Editing hats, pets or trails in Skin Studio. This could come later, and the schema module is written so it can grow.
- Changing `DataService` or `LeaderboardService` (a Studio-only store name is a recommended follow-up: section 15, question 5).

## 2. Key decisions
| # | Decision | Why |
| --- | --- | --- |
| D1 | **Replicate state, not motion.** The server only puts the skin on and sets tags or attributes once. Every client animates every visible character itself. | This is the pattern Dances and SkinFx already use. It adds no network traffic per frame, and `Motor6D.Transform` doesn't replicate anyway. |
| D2 | **Moving pieces hang on Motor6D "pivots" that the server builds.** A moving group (head piece, each wing, tail, cape, a named or custom part) is welded to one invisible `AnimPivot` part. That part is joined to the body by a `Motor6D` named `SkinMotor`. Clients write `SkinMotor.Transform` in `PreSimulation`. | Transform writes are batched by Roblox and are the cheapest way to move welded parts. One write moves a whole group. Pieces follow dances and walk animations for free. |
| D3 | **Effects never write `Transparency` or `Enabled`.** They only change `Color`, light `Brightness`/`Color` and `Transform`, and call `ParticleEmitter:Emit()`, and only on an emitter that is `Enabled`. | The Hide & Seek disguise (Transparency 1, emitters and lights off) and ghost transparency can never be undone by an effect, so no hider is ever revealed. |
| D4 | **Last-written guard.** When an effect stops, it restores a property only if the property still holds the value the effect last wrote. | If the server changed the property meanwhile (TakeOff restored colours, or a new skin was put on), the effect must not paint the old colour back. |
| D5 | **Shared clock.** Effects use `Workspace:GetServerTimeNow()` as `t`. | Every screen shows the same wing beat at the same moment. Flicker uses a hash of the time step, not `math.random`. |
| D6 | **Walk styles:** code presets are an attribute that every client poses (like Dances). Uploaded animation ids play as tracks on the wearer's own client, which Roblox replicates. | No editing of the Animate script. Restoring is just "stop the tracks". The approach works on R15 and R6 (code presets) and can be tested offline. |
| D7 | **Catalog items:** only rigid accessories, classic Shirt/Pants/T-shirt and a classic face, only from allowed creators and approved ids. The server applies them as a HumanoidDescription *diff*, so body parts never change. The feature is off by default. Previews use thumbnails. | `ApplyDescriptionAsync` is server-only, yields, can fail, and fights Part-built cosmetics if body parts change. Crates are sold for Robux, so other creators' items stay out (5.6). |
| D8 | **Skin Studio saves drafts on the server**, in memory and in a `ServerStorage` mirror. A DataStore copy is optional and **off by default** (7 says why). Three ways reach the repo: Studio MCP plus `/save-skins` (main, during the playtest), "Print for Claude" plus the console (older MCP), and "Copy code" (always works). | Playtest changes vanish on Stop, and game scripts can't edit `Source`. The MCP can read the Server DataModel during play. |
| D9 | **A draft is worn under a reserved id**, `StudioDraft_<DraftId>`, with `ModelId = <real Id>`. | Effects must come from the draft, not the old catalogue entry with the same Id. A custom model still has to be found under its real Id. |
| D10 | **One schema module (`SkinSchema`) drives everything in the editor:** its controls, server validation, JSON encoding, the Luau export **and the catalogue rules that `skins.spec` checks** (rarity looks, look keys). | A new Style key then shows up in the editor, gets validated and exports correctly in one place, and the editor's warnings can't drift from the tests. |
| D11 | **One owner per property.** What `Style.Crazy` drives (rainbow accent colours, the glow's brightness when `Crazy.Pulse` is on, the Highlight, orbit pieces), `Animate` may not touch. `Normalize` refuses such effects, and the client skips `Rainbow` parts anyway. | Two systems writing the same property every frame flicker, and SkinFx's restore would break D4. |
| D12 | **Targets are found by attributes set at build time** (`SkinPart`, `SkinIndex`), never by part names or welds. | Head-piece part names (`Wing`, `Tail`, `Spot`, `Stitch`...) collide with accent pattern names, previews have no welds, and build order is the only order every screen agrees on. |
| D13 | **Joint transforms are written every frame** while a character is animated, even when the maths runs at half rate. | Roblox's Animator usually overwrites `Motor6D.Transform` every frame; skipping a write snaps the piece back to rest for that frame. |

---

## 3. Part 1: Skin animations (`Style.Animate`)

### 3.1 Schema
`Style.Animate` is a list of up to `Config.SkinAnimate.MaxEffects` effect tables. Every key is optional except `Effect`.
```lua
Animate = {
	{ Effect = "Flap", Target = "Wings", Speed = 1.5 },
	{ Effect = "Bob", Target = "Head", Amount = 0.6, Delay = 0.3 },
	{ Effect = "ColorCycle", Target = "Accents", Colors = { rgb(255, 120, 0), rgb(150, 60, 200) } },
	{ Effect = "Pulse", Target = "Glow" },
	{ Effect = "SparkleBurst", Target = "Aura", Every = 4, Count = 25 },
},
```
| Key | Type | Range / default | Meaning |
| --- | --- | --- | --- |
| `Effect` | string | a preset name (3.2) | which animation |
| `Target` | string | preset's `DefaultTarget` | what moves or changes (3.3) |
| `Speed` | number | 0.1–5, default 1 | 2 = twice as fast |
| `Amount` | number | 0–3, default 1 | how strong: degrees, studs or colour strength, scaled |
| `Delay` | number | 0–10 s, default 0 | starts the cycle later (so two effects don't move together) |
| `Axis` | string | `"X"`, `"Y"`, `"Z"` | the axis to turn round (Spin, Wobble, Flap, Wag, Breathe) |
| `Reverse` | boolean | default false | Spin the other way |
| `Colors` | {Color3} | 2–6 colours | ColorCycle only (required there) |
| `Every` | number | 0.05–30 s | SparkleBurst (≥ 0.5) and Flicker |
| `Count` | number (integer) | 1–50 | SparkleBurst only: particles per burst |

- A key that isn't listed for that effect is an **error**, as are a wrong type and an out-of-range number. That keeps typos out of the catalogue and the remote.
- **Every number must be finite**: `x == x` and `-math.huge < x < math.huge`. NaN and ±inf slip through `x < min or x > max` and make broken CFrames, so `Normalize` and `DecodeLive` check this first (`SkinAnimate.IsFinite(x)`).
- Lists (`Animate`, `Colors`) must be proper sequences: keys `1..n` with no holes and no other keys.

### 3.2 Presets
The numbers live in `Config.SkinAnimate.Presets[<Effect>]`. The code (`src/shared/SkinAnimate.luau`) holds each preset's kind, targets, labels and maths. `p` below is the preset's Config block; `w = 2π · (t + Delay) · Speed / p.Seconds`.

| Effect | Kind | Default target | Allowed targets | What it does (formula) | Config numbers |
| --- | --- | --- | --- | --- | --- |
| `Spin` | Motion | Head | Head, moving patterns, Part | turns round `Axis` (default Y): angle = `w` (× -1 if Reverse); Amount is not used | `Seconds = 4` |
| `Bob` | Motion | Head | Head, moving patterns, Part | up and down: Y = `p.Height · Amount · sin w` | `Seconds = 1.2, Height = 0.15` |
| `Float` | Motion | Head | Head, moving patterns, Part | rises and sways gently: Y = `p.Height · Amount · (0.5 + 0.5 sin w)`, roll = `p.Sway · Amount · sin(w/2)` | `Seconds = 3, Height = 0.35, Sway = 6` |
| `Wobble` | Motion | Head | Head, moving patterns, Part | tilts about `Axis` (default Z): `p.Degrees · Amount · sin w` | `Seconds = 1, Degrees = 8` |
| `Flap` | Motion | Wings | Wings, Part | wings beat back and open, mirrored: angle about `Axis` (default Y) = `side · p.Degrees · Amount · (0.5 + 0.5 sin w)` | `Seconds = 0.6, Degrees = 35` |
| `Wag` | Motion | Tail | Tail, Part | side to side about `Axis` (default Y): `p.Degrees · Amount · sin w` | `Seconds = 0.5, Degrees = 25` |
| `Breathe` | Motion | Cape | Head, moving patterns, Part | slow tiny lift and tilt: Y = `p.Height · Amount · sin w`, about `Axis` (default X) `p.Degrees · Amount · sin w` | `Seconds = 3.5, Height = 0.05, Degrees = 3` |
| `Pulse` | Light / Colour | Glow | Glow, Head, Accents, a pattern, Body, Part, All | light: Brightness = `base · lerp(p.Low, 1, wave)`. Parts: colour = `base:Lerp(black, (1 - wave) · (1 - p.Low) · min(Amount, 1))`. `wave = 0.5 + 0.5 sin w` | `Seconds = 1.6, Low = 0.45` |
| `ColorCycle` | Colour | Accents | Glow, Head, Accents, a pattern, Body, Part, All | fades through `Colors` in order, `p.SecondsPerColor / Speed` each, lerping smoothly; part `index` starts `index · p.Spread` colours later, so the colour ripples across the pieces | `SecondsPerColor = 1, Spread = 0.15` |
| `Flicker` | Light / Colour | Glow | same as Pulse | candle flicker: in each step of `Every / Speed` s, `hash(step, seed) < p.Chance` dims to `p.Low` (light) or lerps toward black by `(1 - p.Low) · min(Amount, 1)` (parts) | `Every = 0.08, Low = 0.3, Chance = 0.35` |
| `Shimmer` | Colour | Accents | Head, Accents, a pattern, Body, Part, All | a bright band sweeps upward: part at height fraction `h`, band at `b = frac(t · Speed / p.Seconds)`, strength = `max(0, 1 - abs(h - b) / p.Width) · p.Strength · min(Amount, 1)` → `base:Lerp(white, strength)` | `Seconds = 2, Width = 0.25, Strength = 0.6` |
| `SparkleBurst` | Particles | Aura | Aura | every `Every / Speed` s: `emitter:Emit(round(Count · Amount · scale))` (`scale` = `PhoneBurstScale` on phones, else 1), only if `emitter.Enabled` | `Every = 3, Count = 20, MaxCount = 50` |

- `seed` is the wearer's `UserId`, or 0 for previews.
- `side` is the pivot's `AnimSide` attribute (-1 for the left wing, 1 for the right).
- For parts, `index` is the part's rank by its `SkinIndex` attribute (build order, unique within a skin, 3.4), so every screen agrees. Body parts use the fixed order of `Cosmetics.BodyParts`.
- There is **no** `Rainbow` or `Orbit` in `Animate`: those belong to `Crazy` (section 16 says why).

### 3.2a Who owns what (D11)
Every CRAZY skin has `Crazy = { Rainbow = true, Pulse = true, ... }`, and `SkinFx` drives those properties every frame. So:

| When the skin has | SkinFx owns | `Normalize` **error** for | The client also |
| --- | --- | --- | --- |
| `Crazy.Rainbow = true` | the colour of every part with the `Rainbow` attribute (the accent pieces), and the `SkinFxTint` Highlight | a colour effect (Pulse, ColorCycle, Flicker, Shimmer) with Target `Accents`, `All` or any pattern name | skips parts with the `Rainbow` attribute in every colour effect (for example a `Part:` target) |
| `Crazy.Pulse = true` | `SkinGlow.Brightness` | `Pulse` or `Flicker` with Target `Glow` | — (ColorCycle on `Glow` changes the light's `Color`, which SkinFx never writes, so it's allowed) |
| `Crazy.Orbit` | the orbit pieces | — (Animate has no Orbit) | — |

The error text says what to do instead, in plain English: *"CRAZY Rainbow already colours the accents. Use Target Head or Body, or turn Crazy.Rainbow off."* Skin Studio greys these targets out with the same reason (6.3).

### 3.3 Targets
Targets are found from the attributes `SkinPart` and `SkinIndex` that Cosmetics sets on every piece when it builds the skin (3.4). Names of parts are only used inside the head piece, by `Part:`.

| Target | Means | Motion? | Colour? |
| --- | --- | --- | --- |
| `"Head"` | every piece with `SkinPart = "Head"`: the Part-built head piece or the custom model | yes (one pivot at the head centre) | yes |
| `"Wings"`, `"Tail"`, `"Cape"` | pieces with `SkinPart` = that pattern name (`Cosmetics.MovingPatterns`) | yes (Wings = two mirrored pivots) | yes |
| any other pattern name (`"Belt"`, `"Stripes"`...) | pieces with `SkinPart` = that name | no | yes |
| `"Accents"` | every piece whose `SkinPart` is a pattern name (not `"Head"`, not `"Aura"`) | no | yes |
| `"All"` | Head + Accents | no | yes |
| `"Body"` | the avatar's body parts (`Cosmetics.BodyParts(character)`, never HumanoidRootPart); in a preview, the stand-in's body parts | no | yes |
| `"Glow"` | the `SkinGlow` light | no | Pulse, Flicker, ColorCycle (light Brightness/Color) |
| `"Aura"` | the `SkinAura` emitter | no | SparkleBurst only |
| `"Part:<Name>"` | inside the head piece or custom model only (`SkinPart = "Head"`): every BasePart named `<Name>`, or one Model named `<Name>`. Accent pieces are never matched, so `Part:Wing` means the head piece's wing, not the Wings pattern | yes (one pivot for the group) | yes |

- A target that the skin doesn't have is a **warning**, not an error. For example, `Wings` on a skin with no Wings pattern, or `Glow` with no `Style.Glow`. The effect just does nothing.
- `SkinAnimate.TargetsIn(style, partNames?)` lists the targets a style really has, for the editor's dropdown. It leaves out the targets 3.2a forbids for that style.

### 3.4 Server build (changes in `src/shared/Cosmetics.luau`, builder A)
1. **Feature switch.** When `Config.Features.SkinAnimations` is false, nothing in steps 3–5 happens: skins get exactly today's parts and joints. Step 2b (the `SkinPart`/`SkinIndex` attributes) always happens, because they are plain data with no behaviour and `skins.spec` relies on them.
2. **Normalize.** `wearSkin` calls `SkinAnimate.Normalize(style.Animate, style)`. Bad entries are dropped **silently**, because Wear must never warn (`noWarnings`). Catalogue skins are checked by tests, and Studio drafts by `SkinStudioService`.
   - **2b. Part attributes.** Every BasePart (and every Model) the skin builds gets:
     - `SkinPart`: `"Head"` for everything `Cosmetics.Build` makes for a Skin item (Part-built head piece or custom model); the pattern's name (`"Wings"`, `"Stripes"`, ...) for accent pieces, set in `add()` from `ctx.Pattern` (the pattern being built); `"Aura"` for the glow and aura holder.
     - `SkinIndex`: a counter per skin model, in build order (head piece first, then accents in pattern order, then the aura holder). In previews the same code runs on the client, so the order matches the wearing build for Part-built skins; for custom models it is only consistent within one build, which is all a preview needs.
3. **Groups.** Pivots are built only for groups that a motion effect targets, or that a custom-model part marks with a motion `Animate` attribute (3.5). A skin with no motion effect builds the **same parts and joints as today**.
   - **Pivot part:** `Name = "AnimPivot"`, `Size = 0.2³`, `Transparency = 1`, `Massless`, `CanCollide`/`CanTouch`/`CanQuery = false`, `CastShadow = false`, unanchored. It is a child of the `Cosmetic_Skin` model and carries:
     - attribute `AnimGroup` (`"Head"`, `"WingL"`, `"WingR"`, `"Tail"`, `"Cape"`, `"Part:<Name>"`, `"Custom:<n>"`)
     - attribute `AnimSide` (-1 or 1, wings only)
     - a child `Motor6D` named `SkinMotor`, with `Part0` = what the pieces would otherwise weld to (or the parent group's pivot, see the table), `Part1` = the pivot, `C0` = the pivot's offset in `Part0` space and `C1 = identity`
   - **Members:** each member piece gets a `WeldConstraint` with `Part0 = pivot` instead of the body part. A piece belongs to one group only: custom marks (3.5) claim their parts first, then `Part:` groups, then `Head` takes the rest of the head piece.
   - **Where each pivot goes:**

     | Group | `Part0` | `C0` (offset in `Part0` space) |
     | --- | --- | --- |
     | Head | `Head` | identity |
     | WingL / WingR | chest (`UpperTorso` or `Torso`) | `CFrame.new(side·0.3, top.Size.Y·0.3, top.Size.Z/2 + 0.12) · Angles(0, rad(side·-20), 0)` (the same wing root `patterns.Wings` uses) |
     | Tail | `LowerTorso` or `Torso` | `CFrame.new(0, -base.Size.Y/2 + 0.15, base.Size.Z/2 + 0.12)` |
     | Cape | chest | `CFrame.new(0, top.Size.Y/2 - 0.05, top.Size.Z/2 + 0.06)` |
     | `Part:<Name>`, `Custom:<n>` | the Head pivot when the skin has one, else `Head` (so they move with a moving head piece) | centre of the named parts' bounding box, or the Model's `GetPivot()` |

     Implementation hint: give `Dress` a `Group(name, on, offset)` helper that the Wings, Tail and Cape patterns call before adding their pieces. `add()` then welds to `ctx.CurrentGroup` when there is one.
   - **Limit:** at most `Config.SkinAnimate.MaxPivots` pivots. Extra groups stay welded and don't move.
4. **Tag.** If the normalized list isn't empty, or custom animated parts exist, tag the model `Tags.SkinAnim` (`"SkinAnim"`, new in `Tags.luau`). `hasExtras` also returns true when `style.Animate` is set. `Motion` needs no model, because it lives in character attributes.
5. **LiveStyle.** When `Items.Get(item.Id) == nil` (a Studio draft), set the attribute `LiveStyle = SkinAnimate.EncodeLive(style)` on the `Cosmetic_Skin` model. It is JSON holding `Crazy` and `Animate`, with colours as `"#RRGGBB"`, at most `Config.SkinAnimate.MaxLiveChars` (4,000) characters. Clients read styles with `SkinAnimate.StyleOf(model)`: the catalogue first, then `LiveStyle`.
6. **Order: attributes, then tags, then parent.** Every attribute on the skin model and its pieces (`ItemId`, `LiveStyle`, `SkinPart`, `SkinIndex`, `AnimGroup`, `AnimSide`, the copied custom attributes) is set **before** any tag is added, and every tag (`SkinFx`, `SkinAnim`) is added **before** `m.Parent = character`. `SkinFx.onTagged` reads `ItemId` and the style once, when the tag appears; a late attribute would mean a draft's CRAZY effects never start. (Today `wearSkin` parents first and tags after; A moves the tag line above the parent line.)
7. **ModelId.** `Cosmetics.Build`, `wearSkin` and `skinPreview` look custom models up by `item.ModelId or item.Id`.
8. **Walk styles** (section 4) are set here too, as character attributes, and cleared in `restoreSkin`.
9. **Hats on moving head pieces.**
   - `Cosmetics.Wear` for the Hat slot welds the hat to the Head pivot (the `AnimPivot` with `AnimGroup = "Head"` inside `Cosmetic_Skin`) when there is one, else to `Head` as today. `HatLift` is unchanged. Then Float, Bob and Spin carry the hat with the head piece.
   - `TakeOff(character, "Skin")` first re-welds any `WeldConstraint` outside the skin model whose `Part0` is an `AnimPivot` inside it (the hat) to `Head`, and only then destroys the skin. A hat never loses its weld and falls. (`ShopService.Dress` wears Skin before Hat, so a re-dress rebuilds the hat on the new pivot anyway.)
10. **Catalog hooks** (section 5):
    - `headAccessories` skips accessories with the attribute `SkinCatalog = true`.
    - `Cosmetics.OnSkinChanged(fn) -> disconnect` is a server-only listener list, fired with `(character, item?)`. Each listener runs in `pcall`. It fires once:
      - at the end of `Wear` for the Skin slot, with the item
      - at the end of a `TakeOff(character, "Skin")` **called directly**, with nil (not the TakeOff that `Wear` runs first)
    - **No duplicates on restore:** when `restoreSkin` moves the `SkinStash` back, a stashed `BodyColors`, `Shirt`, `Pants` or `ShirtGraphic` whose class the character already has is destroyed instead of moved back. (A catalog apply can create a new BodyColors while the old one is stashed; the newer one wins.)
11. **New public helpers:**
    - `Cosmetics.MovingPatterns = { "Wings", "Tail", "Cape" }`
    - `Cosmetics.BodyParts(character) -> { BasePart }` (a fixed name order, so `index` agrees everywhere)
12. **Previews** (`skinPreview`, `Weld = false`):
    - Each group becomes a sub-Model named `AnimGroup` (attributes `AnimGroup`/`AnimSide`, `PrimaryPart` = an anchored `AnimPivot`). Nested groups (`Part:`, `Custom:` inside the head piece) are sub-Models of the Head group.
    - The preview model's own `PrimaryPart` (or `WorldPivot`) is never inside an `AnimGroup`, so moving a group never moves the model's pivot.
    - The preview model gets `ItemId = item.Id`, plus `LiveStyle` for a draft, set before anything is parented (rule 6).
13. **TakeOff** keeps working otherwise unchanged: pivots and motors live in `Cosmetic_Skin` and are destroyed with it.

### 3.5 Animated parts in custom models (Kieran's Studio workflow)
A part, or a Model grouping several parts, anywhere inside `ReplicatedStorage.Custom.Cosmetics.<SkinId>` can carry these attributes. They are set in Studio: Properties > Attributes > +.

| Attribute | Type | Same as |
| --- | --- | --- |
| `Animate` | string | `Effect` (Spin, Bob, Float, Wobble, Flap, Wag, Breathe, Pulse, ColorCycle, Flicker, Shimmer) |
| `Speed`, `Amount`, `Delay`, `Every` | number | the same keys as 3.1 |
| `Axis` | string | `Axis` |
| `Reverse` | boolean | `Reverse` |
| `Color2` | Color3 | ColorCycle between the part's own colour and `Color2` (an attribute can't hold a list) |

- **Grouping and pivots:**
  - A Model with a motion `Animate` moves as one group and turns round its pivot. Kieran sets the pivot with Studio's Pivot tool.
  - A Part with a motion `Animate` turns round its own centre.
  - The server builds one pivot per marked Part or Model with a **motion** effect. It copies the attributes onto the `AnimPivot` (`AnimGroup = "Custom:<n>"`, `n` in `SkinIndex` order) so clients read them there. The pivot chains to the Head pivot when the head piece moves (3.4).
  - A **colour** mark needs no pivot: the client reads it from the marked part itself (it has `SkinPart = "Head"`).
  - The rest of the model is welded to the head as today.
- **Validation:** values go through `SkinAnimate.Normalize`. Bad values are ignored, and only Skin Studio (6.9) shows a warning.
- **Limits:**
  - These effects don't count toward rarity limits (it's Kieran's own model).
  - They do count toward `MaxPivots` and the 120-part budget.
  - Scripts are still stripped, so attributes are the only way to animate a custom model.

### 3.6 Client runtime: `src/client/SkinAnim.luau` (builder A)
```
SkinAnim.Mount(gui)                    -- starts watching Tags.SkinAnim (nothing when Features.SkinAnimations is off)
SkinAnim.AnimatePreview(model) -> stop -- ViewportFrame previews; SkinFx.AnimatePreview calls it first
SkinAnim.PreviewVisible(viewport) -> boolean -- shown AND inside every scrolling ancestor's visible area
SkinAnim.Active() -> number            -- characters animating right now (tests, perf)
SkinAnim.ColorWrites() -> number       -- colour writes in the last frame (tests, perf)
```
It follows `SkinFx`'s pattern: entry per tagged model, `pick()` every `CheckSeconds`, activate/step/deactivate, and no frame connection while there are no entries and no previews.

1. **Entry.** On a tagged model:
   - Resolve the effects: `SkinAnimate.StyleOf(model).Animate`, normalized, plus the `AnimPivot`s and parts carrying custom attributes.
   - Resolve the targets from attributes only (3.3): pivots by `AnimGroup`; pieces by `SkinPart`, ordered by `SkinIndex`; `Body` = `Cosmetics.BodyParts(character)`.
   - Anything missing because of streaming is skipped and looked up again at the next `pick()`.
2. **Pick (budget):**
   - Candidates are in Workspace, not a hider, have a root, and are within `MaxDistance` of the camera.
   - Sort them by distance. **Your own character always comes first.**
   - The first `MaxCharacters` are active, or `PhoneMaxCharacters` when `Layout.IsPhone()`. The rest are deactivated.
3. **Hide & Seek.**
   - While an entry exists, connect its player's `HideSeekRole` attribute-changed signal and **deactivate at once** when it becomes `"Hider"`.
   - `pick()` also skips hiders.
   - SparkleBurst checks `emitter.Enabled` every time it fires.
4. **Activate:**
   - Find each target's motors, parts, light and emitter.
   - **Leave out every part with the `Rainbow` attribute** from colour effects (3.2a).
   - Store base colours, base brightness, and each part's height fraction (for Shimmer).
   - Cap each colour effect at `MaxColorParts` parts.
5. **Step** (`RunService.PreSimulation`, the same event as Dances, after the Animator has written):
   - `t = Workspace:GetServerTimeNow()`.
   - **Motion:** `offset = SkinAnimate.Offset(effect, t, side)`; several motion effects on one pivot multiply in list order. **Write `motor.Transform` every frame** for every active motor (D13). Beyond `HalfRateDistance`, the offset is *computed* every second frame and the cached value is *written* every frame.
   - **Colour:** runs at `ColorHz` (30 times a second), not every frame. `part.Color = SkinAnimate.Tint(...)`; several colour effects on one part: the last in the list wins. A write is skipped when the new colour equals the last one written. All colour and light writes share one budget per frame across every character and preview: `MaxColorWrites` (PC) or `PhoneMaxColorWrites`, spent closest character first (yours first); parts the budget doesn't reach keep their colour until the next colour tick.
   - **Light:** `light.Brightness = SkinAnimate.Brightness(...)`, at `ColorHz`, counted in the same budget.
   - **Burst:** `if SkinAnimate.BurstDue(effect, last, t) and emitter.Enabled then emitter:Emit(n) end`, with `n` scaled by `PhoneBurstScale` on phones.
   - Remember every value written (`written[instance][property]`).
   - Characters off screen (`Camera:WorldToViewportPoint` of the root, with `OffScreenMargin`), except your own, get no writes at all. Their pieces may rest while you can't see them.
6. **Deactivate:**
   - `motor.Transform = identity` if the motor still exists.
   - Colours and brightness are restored **only where the current value equals `written`** (D4).
7. **Never** write `Transparency`, `LocalTransparencyModifier` or `Enabled`, and never create Highlights or lights.

### 3.7 Previews (shop, crates, Skin Studio)
- **`SkinFx.AnimatePreview(model)` is restructured** (A, `SkinFx.luau`):
  1. It calls `SkinAnim.AnimatePreview(model)` **first**, whatever `Features.SkinEffects` is (SkinAnim checks `Features.SkinAnimations` itself).
  2. Then it does its own rainbow work, only if `Features.SkinEffects` is on and the model has rainbow parts.
  3. It returns **one** stop function that stops both. (Today it returns early when SkinEffects is off or there are no rainbow parts; most animated skins would never reach SkinAnim.)
- **Visibility:** a preview animates (motion **and** colour) only while `SkinAnim.PreviewVisible(viewport)` is true: the existing `guiShown` check, plus the ViewportFrame lies inside the visible area of every `ScrollingFrame` above it. That is the same maths as CrateUI's local `inView` (`CrateUI.luau` ~241); A copies the ~10 lines into SkinAnim rather than editing CrateUI. Preview colour writes count toward `MaxColorWrites`.
- **Motion is relative to the preview model's current pivot and scale.** CrateUI spins previews with `model:PivotTo(base * yaw)` every frame and the reveal stage calls `ScaleTo` and `PivotTo` every frame, so a rest pose captured once in world space would snap pieces back. For each group, in parent-first order:
  - at start: `s0 = model:GetScale()`, `rel = parentPivot:ToObjectSpace(group:GetPivot())` where `parentPivot` is `model:GetPivot()` (or the parent group's pivot for a nested group); keep `relRot = rel.Rotation` and `relPos = rel.Position / s0`.
  - each frame: `s = model:GetScale()`, `o = SkinAnimate.Offset(effect, t, side)`, `oS = CFrame.new(o.Position * s) * o.Rotation`, then `group:PivotTo(parentPivot * CFrame.new(relPos * s) * relRot * oS)`, with `parentPivot` read **this frame**.
  - Motion runs on at most `MaxPreviewMotion` previews at once, and never on phones (`PreviewMotionOnPhones = false`).
- Pulse/Flicker on a preview's `GlowHalo` may change its Transparency, because a preview is never a character.
- **ShopUI hook (A):** call `SkinFx.AnimatePreview(model)` for every skin card, not only CRAZY ones. It is a no-op for still skins. CrateUI already calls it for every preview.
- Phones keep the existing rule: no spinning shop previews.

### 3.8 Rarity rules (Config-driven)
`Config.SkinAnimate.Rarity`:
```lua
Rarity = {
	Common = { Effects = 0, Motion = false },
	Uncommon = { Effects = 1, Motion = false },
	Rare = { Effects = 3, Motion = true },
	Crazy = { Effects = 6, Motion = true },
},
```
`SkinAnimate.RarityProblems(item)` checks them. It is the only copy of these rules: `skinanimate.spec`, `SkinSchema.Check` and (through `SkinSchema.RarityProblems`) `skins.spec` all call it. Catalog items aren't limited by rarity (open question 2).

### 3.9 `Config.SkinAnimate` (`src/shared/Config/SkinAnimate.luau`, builder A)
```lua
return {
	MaxCharacters = 8, -- characters whose skin pieces animate at once (the closest; you first)
	PhoneMaxCharacters = 4,
	MaxDistance = 120, -- studs from the camera
	HalfRateDistance = 60, -- further than this: maths every second frame (still written every frame)
	OffScreenMargin = 0.2, -- how far past the screen edge (fraction of the screen) still counts as on screen
	CheckSeconds = 0.5, -- how often the closest ones are picked again
	ColorHz = 30, -- colour and light effects update this many times a second
	MaxColorWrites = 400, -- colour/light writes per frame, all characters and previews together (PC)
	PhoneMaxColorWrites = 120,
	PhoneBurstScale = 0.5, -- SparkleBurst particles on phones (0.5 = half)
	MaxEffects = 6, -- effects in one skin's Animate list (rarity limits below are lower)
	MaxPivots = 6, -- moving groups in one skin
	MaxColorParts = 40, -- parts one colour effect changes
	MaxLiveChars = 4000, -- a draft's LiveStyle attribute
	MaxPreviewMotion = 4, -- shop/crate/studio previews whose pieces move at once
	PreviewMotionOnPhones = false,
	Rarity = { ... }, -- 3.8
	Presets = { Spin = { Seconds = 4 }, Bob = { ... }, ... }, -- 3.2, every preset listed
}
```
It is required in `Config/init.luau` as `SkinAnimate = require(script.SkinAnimate)`. It starts with a plain-English header like every Config file.

### 3.10 Shared module `src/shared/SkinAnimate.luau` (builder A; pure, client + server)
```
export type Effect = { Effect: string, Target: string, Speed: number, Amount: number, Delay: number,
	Axis: string?, Reverse: boolean?, Colors: { Color3 }?, Every: number?, Count: number? }
export type ParamInfo = { Key: string, Label: string, Help: string,
	Type: "number" | "boolean" | "Axis" | "Colors",
	Min: number?, Max: number?, Step: number?, Default: any }
export type EffectInfo = { Name: string, Label: string, Help: string,
	Kind: "Motion" | "Colour" | "Light" | "Particles",
	Targets: { string }, DefaultTarget: string, Params: { ParamInfo } }

SkinAnimate.Effects: { EffectInfo }                 -- ordered, for the editor (labels + help in plain English)
SkinAnimate.Has(name) -> boolean
SkinAnimate.IsFinite(x: any) -> boolean             -- a number that isn't NaN or ±inf
SkinAnimate.Normalize(list: any, style: any?) -> ({ Effect }?, { string } errors, { string } warnings)
                                                    -- includes the 3.2a ownership errors (needs style.Crazy)
SkinAnimate.TargetsIn(style, partNames: { string }?) -> { string }   -- leaves out targets 3.2a forbids
SkinAnimate.PartNames(model: Model) -> { string }   -- unique names of parts/Models with SkinPart = "Head" (editor)
SkinAnimate.Offset(effect, t, side: number?) -> CFrame
SkinAnimate.Tint(effect, base: Color3, t, index: number, height: number, seed: number) -> Color3
SkinAnimate.Brightness(effect, base: number, t, seed: number) -> number
SkinAnimate.BurstDue(effect, lastT: number, t: number) -> boolean
SkinAnimate.EncodeLive(style) -> (string?, string? problem)  -- { Crazy, Animate } as JSON; nil if neither;
                                                    -- problem = "too long" past MaxLiveChars
SkinAnimate.DecodeLive(text: any) -> { Crazy: any?, Animate: { Effect }? }   -- checks finiteness too
SkinAnimate.StyleOf(model: Instance) -> any?        -- catalogue item's Style by ItemId, else DecodeLive(LiveStyle)
SkinAnimate.RarityProblems(item) -> { string }      -- 3.8 rules
```

### 3.11 SkinFx changes (builder A)
- `onTagged`: when `Items.Get(ItemId)` is nil, use `SkinAnimate.StyleOf(model).Crazy`. Drafts' CRAZY effects then work in Skin Studio (this needs rule 6 of 3.4).
- `AnimatePreview` is restructured (3.7).
- Nothing else changes: CRAZY budget, Highlight tint and SkinEffects stay as they are.

---

## 4. Walk styles (`Style.Motion`)

### 4.1 Schema
```lua
Motion = "Zombie"                                   -- a code preset (works on R15 and R6)
Motion = { Walk = "rbxassetid://123", Run = "rbxassetid://456", Idle = "rbxassetid://789" }
Motion = { Preset = "Ghost", Idle = "rbxassetid://789" } -- both: preset poses + your idle
```
- **Ids:** each is `"rbxassetid://<1–20 digits>"`, or the digits alone as a number or string; they are stored in that canonical form.
- **Uploaded ids** play on R15 rigs only. R6 characters get just the `Preset`, if there is one.
- **Who can play an uploaded animation:**
  - It must be owned by the game's owner (Kieran, or his group if the game is group-owned) or be one of Roblox's own animations. If not, Roblox doesn't play it.
  - The editor and the docs say this, and the client warns in Studio when a track doesn't load (4.3).
- **Presets** (`SkinMotion.Names`):

  | Preset | What it does |
  | --- | --- |
  | `Zombie` | arms held forward, head tilted, slight lean, shuffle |
  | `Mummy` | stiff arms forward a little lower, short steps |
  | `Ghost` | floats above the ground and bobs, legs dangle, arms limp |
  | `Robot` | straight elbows and knees, head turns in ticks |
  | `Bat` | arms out flapping, faster when moving, small hover |
  | `Sneaky` | crouched tiptoe, arms close |
  | `Bouncy` | an extra hop in every step |
  | `Proud` | chest out, chin up |

### 4.2 Server (in `Cosmetics.wearSkin` / `restoreSkin`, builder A)
- **Feature switch.** Only when `Config.Features.WalkStyles` is on.
- **Wear:** `SkinMotion.Normalize(style.Motion)` (bad values are dropped silently), then:
  - `character:SetAttribute("SkinMotion", preset)` when a preset is set
  - `character:SetAttribute("SkinMotionIds", SkinMotion.IdsText(motion))` (e.g. `"Walk=123;Run=456;Idle=789"`) when ids are set
- **Take off:** `restoreSkin` sets both to nil. The skins.spec snapshot gains both attributes, so TakeOff must leave them nil.
- **Hide & Seek:** a hider is never dressed, so these attributes are absent or stale. Clients skip hiders anyway (4.3).

### 4.3 Client: `src/client/SkinWalk.luau` (builder A)
```
SkinWalk.Mount(gui)       -- nothing when Features.WalkStyles is off
SkinWalk.Active() -> number
```
- **Watching.** It watches every player's character for `SkinMotion` / `SkinMotionIds` (like `Dances.watchCharacter`). `PreSimulation` is connected only while someone has a walk style.
- **Code presets** (every client, every visible character, within budget):
  - **Budget:**
    - `MaxCharacters` (`PhoneMaxCharacters` on phones), the closest first and your own always included, within `MaxDistance`.
    - Skip a character that is: off screen; dancing (`Dance` attribute set: the dance wins); a hider; dead; or `Humanoid.Sit`.
    - **Other players' characters:** don't use `Humanoid:GetState()` (it isn't reliable for characters this client doesn't simulate). Fade out when the root's vertical speed is above `AirSpeed` (jumping, falling, climbing).
    - **Your own character** may also use `GetState()` to skip swimming and climbing.
  - **Pose:** `move = clamp(horizontal root velocity / Humanoid.WalkSpeed, 0, 1)` (velocity replicates; `MoveDirection` doesn't for other players). Then `pose = SkinMotion.Pose(name, t, move)`, faded in and out over `FadeSeconds`.
  - **Pose type:** `{ [jointName]: { Mode: "Set" | "Add", Turn: CFrame } }`, using DanceMoves joint names and body directions. `Root` may also shift.
  - **Root shift on your own character** is capped at `OwnRootShiftMax` studs. Your head and torso collide, so a full Ghost float (0.8), Bat hover or Bouncy hop could bump ceilings in tight places (the Tower, ScareMaze). Other screens show the full shift, because there it is only visual.
  - **Set mode** writes the converted turn (the same conversion as `DanceMoves.Apply`: `c0Rot:Inverse() * turn * c0Rot`). It replaces the walk animation for that joint, e.g. Zombie arms.
  - **Add mode** layers on top of Roblox's walk animation, using **base tracking**:
    1. Read `cur = joint.Transform`.
    2. Read the character's `Animator.EvaluationThrottled` through `pcall` (it isn't in the harness's API list, and the result is cached as "not supported" after the first failure).
       - `false`: the Animator wrote a fresh pose this frame, so `base = cur`.
       - `true`: the Animator reused an old pose, so `base = lastBase[joint]`.
       - not readable: fall back to the guess `base = if cur == written[joint] then lastBase[joint] else cur`.
    3. Write `base * add` and remember `written` and `lastBase`. **Write every frame** (D13), also at half rate.

    This never builds up across frames and needs no second event. (The harness has no `PreAnimation`.)
  - **Stopping** (attribute cleared, a dance starts, the character goes out of budget): Set-mode joints are put back to identity (`DanceMoves.Clear`) and Add-mode joints to `lastBase`.
  - **Shared code:** `DanceMoves.Joints` finds the joints (R15, R6, AnimationConstraint). If A needs the conversion, A exports a tiny helper from `DanceMoves` (`DanceMoves.Local(joint, turn) -> CFrame`), changing no existing behaviour.
- **Uploaded ids (your own character only):**
  - **Loading:** load Walk/Run/Idle as tracks on your own `Animator` (`pcall(animator.LoadAnimation)`), `Priority = Movement`, looped.
  - **Which one plays, each frame:**

    | You are | Plays |
    | --- | --- |
    | on the ground, speed > `RunSpeed` | Run, if set (else Walk) |
    | on the ground, speed > `WalkThreshold` | Walk, `AdjustSpeed(speed / Humanoid.WalkSpeed)` |
    | on the ground, otherwise | Idle |
    | in the air, climbing, swimming or seated | none of ours (Roblox's jump/fall/climb show) |

  - **Replication:** Roblox replicates your Animator's tracks to everyone.
  - **Stopping:** stop and destroy all of them when the attribute clears, the character changes, you start a dance, or **your `HideSeekRole` becomes `"Hider"`** (watch the attribute; never start them while you are a hider).
  - **Load check:** after `LoadCheckSeconds`, a track with `Length == 0` counts as not loaded. It is skipped, and in Studio there is one `warn`: `[SkinWalk] animation 123 didn't load: is it owned by the game's owner?`.

### 4.4 `Config.SkinMotion` (`src/shared/Config/SkinMotion.luau`, builder A)
```lua
return {
	MaxCharacters = 12, PhoneMaxCharacters = 6, MaxDistance = 100, CheckSeconds = 0.5,
	HalfRateDistance = 50, -- further than this: maths every second frame (still written every frame)
	FadeSeconds = 0.25, -- blend in and out
	AllowUploaded = true, -- false = only the code presets (uploaded ids are ignored)
	WalkThreshold = 0.5, RunSpeed = 20, -- studs/s
	AirSpeed = 10, -- studs/s up or down: other players' walk style fades out (jumping, falling, climbing)
	OwnRootShiftMax = 0.2, -- studs: your own character never floats or hops higher than this (ceilings)
	LoadCheckSeconds = 3,
	Presets = { Zombie = { ArmsForward = 85, Lean = 8, HeadTilt = 12, Seconds = 1.1 }, Ghost = { Height = 0.8, Bob = 0.25, Seconds = 2.4 }, ... },
}
```

### 4.5 Shared module `src/shared/SkinMotion.luau` (builder A; pure)
```
export type Motion = { Preset: string?, Walk: string?, Run: string?, Idle: string? }
export type JointPose = { Mode: "Set" | "Add", Turn: CFrame }
SkinMotion.Names: { string }
SkinMotion.Info: { { Name: string, Label: string, Help: string } }
SkinMotion.Has(name) -> boolean
SkinMotion.Normalize(value: any) -> (Motion?, { string } errors)
SkinMotion.Pose(name: string, t: number, move: number) -> { [string]: JointPose }
SkinMotion.IdsText(motion: Motion) -> string?
SkinMotion.ParseIds(text: any) -> { Walk: string?, Run: string?, Idle: string? }
```

---

## 5. Part 2: Catalog items in skins (`Style.Catalog`)

### 5.1 Verdict
The platform research says the server *can* put any published catalog item on a player without ownership checks:
- `Humanoid:ApplyDescriptionAsync(desc, Enum.AssetTypeVerification.Always)`, server-only, replicated to everyone.

But it comes with problems:
- It yields and does web loads.
- It can fail ("DataModel was not available", missing or moderated assets), and moderated assets may break later applies.
- Roblox documents that it assumes nothing else edits the character (our Part skin does: 5.3 deals with it).
- Body-part ids replace the body MeshParts, which **breaks every Part-skin weld**. Scales leave weld offsets wrong.

**So we take the safe subset:**
| Allowed | Excluded, and why |
| --- | --- |
| Rigid accessories: Hat, Hair, FaceAccessory, Neck, Shoulder, Front, Back, Waist | **Bundles and body parts**: replace body MeshParts and heads, which breaks welds and head pieces; R15 only |
| Classic `Shirt`, `Pants`, `TShirt` (graphic) | **Scales / proportions**: weld offsets go wrong; no effect on R6 |
| `ClassicFace` (a classic face decal; only on a skin without a head piece) | **Layered clothing**: R15 only, clips through Part skins, ignores HideClothes |
|  | **Animation packs**: use `Style.Motion` instead (custom ids don't apply through descriptions anyway) |
|  | **Items by other creators** (5.6) |

- **How it's applied:** as a *diff* on the player's own applied description. Body parts, colours and scales stay identical, so the Part skin keeps its welds.
- **Fallback:** the Part-built skin is always there. If loading fails, players simply see the skin without the catalog bits.
- **Default:** `Config.Features.SkinCatalog = false` until Kieran tests it in Studio and approves ids (5.6).

### 5.2 Schema
```lua
Catalog = {
	Accessories = { { Id = 1234567890, Type = "Hat" }, { Id = 2345678901, Type = "Back" } }, -- up to MaxAccessories
	Shirt = 3456789012, Pants = 4567890123, TShirt = 5678901234, -- classic clothes (the skin needs HideClothes = false)
	ClassicFace = 6789012345, -- classic face decal (only when the skin has no Head piece)
}
```
- Ids are positive integers below 2^53.
- `Type` is one of `SkinCatalog.Types`. `"FaceAccessory"` is a 3D accessory worn on the face (glasses, masks); `ClassicFace` is the flat face decal. The two names are different on purpose.
- Skin Studio fills `Type` in by looking the id up in Studio (6.6, `LookupAsset`), so live servers never make that web call.
- **Errors:** too many accessories, a duplicate id, an unknown `Type`, layered types, a non-finite or non-integer id.
- **Warnings:**
  - Shirt/Pants/TShirt while `HideClothes ~= false`: the skin would hide them.
  - `ClassicFace` with a `Head`.
  - Head-slot accessories (Hat, Hair, FaceAccessory) with a `Head` piece: the head piece hides head accessories, except ours. Catalog accessories are marked `SkinCatalog` and are **not** hidden, so a catalog hat sits on the head itself (Studio test item).
  - An id that isn't in `Config.SkinCatalog.ApprovedIds` (it is an **error** in `skins.spec` and `save-skins`, 5.6).

### 5.3 Server: `src/server/Services/SkinCatalogService.luau` (builder A)
```
SkinCatalogService.Start()                 -- returns early when Features.SkinCatalog is off
SkinCatalogService.Status(character) -> string?   -- "Loading", "On", "Failed: <reason>", nil
```
Flow (at most one worker per character; the newest skin wins):
0. **Start.** Connect `Cosmetics.OnSkinChanged` first. Then, for every player already in the game with a character (Studio Play Solo dresses you before this service starts), call `ShopService.Dress(player)` once inside `task.defer`, so the listener sees their skin. Start never yields.
1. **Trigger.** `Cosmetics.OnSkinChanged(character, item?)` records `wanted[character] = SkinCatalog.Key(item and item.Style.Catalog)` (a stable string, `""` = none) and the matching catalog table. If no worker is running for that character, it starts one with `task.defer`. A burst of changes (`Dress` putting several slots on) collapses into one apply.
2. **Worker loop.** The worker loops while `wanted[character] ~= applied[character]`. It reads `wanted` again after every yield and stops when they match.
   - **Wait for the avatar.** `OnSkinChanged` first fires from the CharacterAdded `Dress`, before the avatar has loaded. If `not player:HasAppearanceLoaded()`, wait for `player.CharacterAppearanceLoaded` with an `AppearanceWaitSeconds` timeout, then go on either way.
   - It waits until `SecondsBetweenApplies` have passed since the last apply for this player.
   - Abort if the player is a Hide & Seek hider, the character isn't `player.Character`, or the humanoid is dead.
3. **Snapshot.** Take a snapshot once per character, after the appearance has loaded and before our first apply: `base[character] = humanoid:GetAppliedDescription()`. This is the player's own avatar with Avatar Settings applied, and needs no web call.
4. **Build the description.** `desc = base:Clone()`, then:
   - `own = base:GetAccessories(true)` (rigid included).
   - `ours` = one entry per catalog accessory not already in `own`: `{ AssetId = id, AccessoryType = Enum.AccessoryType[ENUM[Type]], IsLayered = false }`, where `ENUM = { Hat = "Hat", Hair = "Hair", FaceAccessory = "Face", Neck = "Neck", Shoulder = "Shoulder", Front = "Front", Back = "Back", Waist = "Waist" }` (look the item up by name, never by number).
   - `desc:SetAccessories(own ∪ ours, true)`.
   - set `Shirt`, `Pants`, `GraphicTShirt` and `Face` (from `ClassicFace`) where given.

   Removing catalog items means applying `base` itself.
5. **Apply.** Remember the accessories present, then call `pcall(humanoid.ApplyDescriptionAsync, humanoid, desc, Enum.AssetTypeVerification.Always)`. The Part skin stays on during the apply (taking it off would show the bare avatar for the whole web load; section 16).
6. **After the yield:**
   - If the character is gone, stop.
   - If the player became a hider, re-apply `base` (pcall) and stop.
   - If `wanted` changed meanwhile, loop and apply the newer one.
7. **Finish:**
   - Mark new accessories `SkinCatalog = true`.
   - Set `applied[character]` to the key just applied.
   - Set the character attribute `SkinCatalogStatus` (`"On"`, or `"Failed: <short reason>"`).
   - Then **re-dress** with `ShopService.Dress(player)`. Dress fires `OnSkinChanged` again with the same key, so nothing new happens. This puts the Part skin back over anything the apply reset (BodyColors, clothes). `restoreSkin`'s no-duplicates rule (3.4, step 10) stops a second BodyColors appearing.
   - After a failure, `applied` is set too, so a broken id isn't retried until the skin changes.
8. **Failure.** The status says why. One `warn` per asset id per server, only in Studio, and never during `Wear`. The Part skin stays.
9. **Cleanup** on `CharacterRemoving` and `PlayerRemoving`. A respawned character loads the player's own avatar, and `Dress` → `OnSkinChanged` applies again with a new snapshot.

This service starts after `ShopService` in `Main.server.luau` and creates no remotes.

### 5.4 Previews: `src/client/CatalogBadge.luau` (builder A)
```
CatalogBadge.Add(parent: GuiObject, item) -> Frame?   -- nil when the skin has no catalog items or the feature is off
```
- **What it shows:** a row of up to 4 `ImageLabel`s with `rbxthumb://type=Asset&id=<id>&w=150&h=150` across the bottom of the card. These are 2D thumbnails: a ViewportFrame stand-in can't load catalog meshes.
- **Hover:** on PC, hovering shows "Roblox catalog item".
- **Buy button:** when `ShowBuyButtons`, a small "Buy" button calls `MarketplaceService:PromptPurchase(LocalPlayer, id)` (client-side, no remote). The default is **false**, to stay kid-friendly.
- **Hooks (A):**
  - `ShopUI` `makeCard`: one line after `rarityTag`.
  - `CrateUI` reveal card: one line.
  - Skin Studio calls it too (B).

### 5.5 `Config.SkinCatalog` (`src/shared/Config/SkinCatalog.luau`, builder A) and switch
```lua
return {
	MaxAccessories = 4,
	Types = { "Hat", "Hair", "FaceAccessory", "Neck", "Shoulder", "Front", "Back", "Waist" },
	-- Who may make the items. Crates are sold for Robux, so only Roblox, you and your group.
	AllowedCreators = {
		Roblox = true,
		UserIds = { --[[ Kieran's UserId (open question 4) ]] },
		GroupIds = { --[[ the game's group, if it has one ]] },
	},
	-- Every catalog id a skin in the game files uses must be listed here, after Kieran has checked it.
	-- [id] = "item name, creator, checked on <date>"
	ApprovedIds = {},
	SecondsBetweenApplies = 2, -- per player; the newest skin always wins
	AppearanceWaitSeconds = 10, -- wait this long for the avatar to load before the first apply
	ShowThumbnails = true, ShowBuyButtons = false, ThumbnailSize = 150,
}
```
`Config.Features.SkinCatalog = false`.

### 5.6 Rules for whose items (enforced, not just a note)
Robux crates are live (commit `1765a6d`, all 34 crates on sale). Putting other creators' catalog items inside crate skins would mean selling access to marketplace items Kieran doesn't own, inside paid random boxes, in a kids' game. So:
- **`LookupAsset`** (6.6) returns the creator and `Allowed` (Roblox, a user in `AllowedCreators.UserIds`, or a group in `GroupIds`). Skin Studio refuses to add an id that isn't `Allowed`, and says why.
- **`skins.spec`** (A) fails when any skin in the game files uses a catalog id that isn't a key of `Config.SkinCatalog.ApprovedIds`. Every theme skin is in a crate, so this covers every Robux-reachable skin.
- **`tests/save-skins.luau`** (B) refuses a draft with an id that isn't in `ApprovedIds`, and prints the creator the server recorded in the draft's `Lookups` (6.4). The offline tool can't ask Roblox who made an item, so the allow-list in Config is the gate.
- **Adding to `ApprovedIds`:** Claude adds an id only when Kieran says yes **and** the recorded creator is Roblox, Kieran or his group, with a comment naming the item, the creator and the date.
- The feature stays **off** by default. `ShowBuyButtons` stays **false**.

### 5.7 Shared module `src/shared/SkinCatalog.luau` (builder A; pure)
```
SkinCatalog.Types: { string }
SkinCatalog.Normalize(value: any, style: any?) -> (Catalog?, { string } errors, { string } warnings)
SkinCatalog.Key(catalog: any) -> string             -- "" for none; sorted, stable
SkinCatalog.Ids(catalog: any) -> { number }         -- every id in it (accessories, clothes, face)
SkinCatalog.TypeFromAssetType(assetTypeName: string) -> string?  -- "Hat"->"Hat", "HairAccessory"->"Hair",
                                                    -- "FaceAccessory"->"FaceAccessory", "Shirt"->"Shirt", "Face"->"ClassicFace"...
SkinCatalog.CreatorAllowed(creatorType: string, creatorId: number) -> boolean   -- AllowedCreators
SkinCatalog.Approved(id: number) -> boolean         -- in ApprovedIds
```
Map through `Enum.AssetType` item names, never hard-coded numbers: find the item whose `.Value == AssetTypeId`.

---

## 6. Part 3: Skin Studio (builder B)

### 6.1 Who and where
**Allowed** means all of:
- `Config.Features.SkinStudio`
- the player attribute `Admin == true` (set by AdminService)
- `RunService:IsStudio()` or `Config.SkinStudio.AllowInLiveServers`

`SkinStudioService.Allowed(player)` checks this on the server for **every** action, **before** anything is decoded. The client checks the same things, but only to decide whether to show the tile.

**Entry points:**
- **Menu tile:**
  - a `Config.Menu.Tiles` line `{ Id = "SkinStudio", Text = "Skin Studio", Icon = "🎨", Color = Color3.fromRGB(90, 60, 150), Feature = "SkinStudio" }`
  - `MenuUI.AddTile({ Id = "SkinStudio", Label = "Skin Studio", Order = 95, Visible = allowed, OnClick = SkinStudioUI.Open })`
- **F8 button:** `AdminService.Register("SkinStudio", "Skin Studio", fn)`. The server checks `Allowed`, then sets the player attribute `SkinStudioOpenAt = Workspace:GetServerTimeNow()` and returns `"Skin Studio opened."` (or why not). `SkinStudioUI.Mount` (feature on) watches that attribute on the local player and opens the panel when it changes. No remote is needed, so the first F8 press always works. (There is no `SkinStudioOpen` RemoteEvent.)

### 6.2 Screen layout
The panel **docks to the right edge** so your real character stays visible on the left (it is not centred).
- `Theme.panel(gui)`, named `SkinStudio`, `PanelManager.Register(panel)`.
- On a PC it is `Config.SkinStudio.Panel.Width` (440) wide and full height minus the top bar, and uses `Layout.Fit(panel)`.

```
┌───────────── Skin Studio ─────────────[✕]┐
│ [ preview viewport (turns) ]  Name  ★Rare │  header: small turntable preview + badges
│ Wearing: Moon Moth (draft)  [Wear on me ✓] │
├─[Skins]─[Look]─[Animate]─[Catalog]─[Save]──┤  tabs
│ (tab content, scrolls)                     │
├────────────────────────────────────────────┤
│ [↶ Undo] [↷ Redo] [Reset] [🎥 Turntable]   │  footer, always visible
│ status line (green ok / yellow warning)    │
│ ⚠ 3 drafts not in the game files yet:      │
│   run /save-skins before you press Stop    │
└────────────────────────────────────────────┘
```
- **Phone** (`Layout.IsPhone()`, checked in Studio's device emulator):
  - a bottom sheet, full width and `PhoneHeightScale` (0.55) of the screen high
  - it does **not** call `Layout.Fit` (which can shrink a panel to 0.3 scale and break the 44 px rule); it is sized from the screen instead
  - the same tabs; the header preview is hidden (your real character is above the sheet)
  - every control at least 44 px tall on screen; slider buttons step by ±1 and ±10
- **Tabs:**

  | Tab | Contents |
  | --- | --- |
  | Skins | search box; Theme dropdown (All, 30 themes, Classic, Tower); rarity chips; "Drafts" and "Animated" toggles; a paged list (`ListPageSize`, `PhoneListPageSize`); buttons **New**, **Duplicate** |
  | Look | Basics (Name, Id, Theme, Rarity, Crate, Price, CrateOnly, with the economy lock 6.4); Body; Head; Accent; Glow & particles; CRAZY |
  | Animate | the effect list editor (6.3) and Walk style |
  | Catalog | ids with Look up, thumbnails, and a notice when the feature is off |
  | Save | drafts list, Save, Delete, Copy code, Print for Claude, saving instructions and status |

  - **List rows:** a rarity dot, Name, Id (small), theme, and icons: 🎞 Animate, 🚶 Motion, 🛍 Catalog, ✎ draft, ✓ "in game files". Rows are text only; only the selected skin gets a 3D preview.
- **Opening and closing (nothing is lost):**
  - PanelManager closes the panel on Escape, the Roblox menu, M, B and any other panel opening. So everything lives in the module, not the panel: the current `SkinStudioState` (with its Undo history), the selected skin, tab and list page survive closing and reopening.
  - Opening the panel never changes what you wear until you edit something, or tick **Wear on me** (default on in Studio).
  - **Keep wearing after closing** is **on** by default (`KeepWearingDefault`). Untick it to go back to your own skin when you close.
  - The footer, and a toast on close, say *"N drafts are not in the game files yet: run /save-skins in Claude Code before you press Stop"* (N = saved drafts whose encoding differs from the catalogue entry), and *"You have unsaved changes"* when the working draft is dirty.

### 6.3 Controls (`src/client/SkinStudioControls.luau`)
Each control is built from `SkinSchema.Fields` metadata (6.9), so a new Style key gets a control without UI work.

| Control | Used for | Behaviour |
| --- | --- | --- |
| Colour | every Color3 key | swatch → popover with the `Config.SkinStudio.Palette` grid (24 swatches), R/G/B sliders 0–255 with number boxes, a hex box, **Clear** (unset an optional key) |
| Material | Material keys | dropdown of `Config.SkinStudio.Materials` (a friendly list; the server accepts any `Enum.Material`) |
| Choice | Head, Face, Aura.Kind, Crazy.Orbit, Crazy.Effect, Theme, Rarity, Effect, Target, Axis, Motion, Catalog Type | dropdown. Head shows CRAZY heads with ⭐ and warns when another skin already uses one. Target lists only `SkinAnimate.TargetsIn`; targets that 3.2a forbids are shown greyed with the reason |
| Patterns | Accent.Pattern | chips; tap to add or remove, in order |
| Toggle | HideClothes, Crazy.Rainbow, Crazy.Pulse, CrateOnly, Reverse | on/off pill |
| Number | Transparency (0–0.9), Glow.Brightness (0–10), Glow.Range (0–60), Crazy.Count (1–8), Price, effect numbers | slider + box with min/max/step from metadata; dragging is one Undo step; typed text that isn't a finite number is ignored |
| Text | Name (1–40), Id (new skins only), Note | TextBox; Id auto-fills `<Theme>_<NameWithoutSpaces>` until edited by hand; newlines and control characters are stripped as you type |
| Effect list | `Animate` | rows: Effect, Target, Speed, Amount, then the effect's `Params`; ✕ ▲ ▼ per row; **+ Add animation** (greyed at the rarity/`MaxEffects` limit with the reason) |
| Walk style | `Motion` | dropdown None + `SkinMotion.Info`; "Use my own animations" expander with Walk, Run and Idle id boxes and the ownership note |
| Catalog list | `Catalog` | id box + **Look up** (fills Type, shows name, creator, Roblox-made tick and thumbnail via `CatalogBadge`; refuses ids whose creator isn't allowed, 5.6); Shirt, Pants, TShirt and ClassicFace boxes |
| Economy lock | Rarity, Crate, Price, CrateOnly of an existing skin | locked (greyed) with a padlock; **Unlock** asks *"Players already own this skin. Changing its rarity or crate changes what they own and the Robux crate odds. Unlock?"* |

**Help text.** Every control has a `?` that shows its plain-English `Help` from the metadata, e.g. *"Glow: a light around you. Rare and up."* A warning line under a section shows that section's `SkinSchema.Check` warnings.

### 6.4 Drafts, live wearing and the turntable
```
type DraftRecord = {
	DraftId: string,          -- made by the server: HttpService:GenerateGUID(false)
	Source: string?,          -- the catalogue Id this draft edits (nil = a new skin)
	Item: EncodedItem,        -- { Id, Name, Rarity, Theme?, Crate?, Price?, CrateOnly?, OneInAMillion?, Odds?,
	                          --   Slot?, VipOnly?, Exclusive?, Style }
	UnlockEconomy: boolean?,  -- true = Rarity/Crate/Price/CrateOnly of an existing skin may change (warned)
	Lookups: { [string]: AssetInfo }?, -- filled by the SERVER from its LookupAsset results, keyed by id text
	Updated: number,          -- DateTime.now().UnixTimestampMillis, set by the server
	Author: number,           -- UserId
	Note: string?,            -- up to 120 characters
	Deleted: boolean?,        -- tombstone: kept (with Updated) so a merge can't bring the draft back
}
type DraftSummary = { DraftId: string, SkinId: string, Name: string, Theme: string?, Rarity: string,
	Source: string?, Updated: number }
```
- **Selecting a catalogue skin** makes an unsaved working draft (`Source = Id`):
  - Its **Id and Theme are locked**, because Ids never change.
  - **Rarity, Crate, Price and CrateOnly are locked** (6.3, economy lock) unless Kieran unlocks them, which sets `UnlockEconomy = true`. Players already own these skins, and Robux crate odds depend on them.
  - `OneInAMillion`/`Odds`, `Slot`, `VipOnly` and `Exclusive` are carried over read-only.
  - Classic (no Theme) and Tower (`Exclusive`) skins can be previewed and duplicated, but `/save-skins` won't write them (edit by hand, or use Copy code).
- **New** starts a blank Common draft in the selected theme (`SkinSchema.NewItem(theme)`).
- **Duplicate** copies the selected item with Id `<Id>Copy` and Name `"<Name> Copy"`, unlocked.
- **Live wearing** (`SkinStudioState`, 6.5):
  - Every committed change (and the first tick of Wear on me) schedules **one** `Wear` call after `WearDelay` seconds of no changes; the newest draft wins.
  - The server wears it under `StudioDraft_<DraftId or "U"..UserId>` with `ModelId = Item.Id` (D9), so SkinFx, SkinAnim and SkinWalk animate it like a real skin (`LiveStyle`, `SkinMotion`).
  - A "Slow down" reply retries after the delay.
  - Your save never changes.
- **Header preview:**
  - `Cosmetics.Preview(wearItem)` in a ViewportFrame with a turning camera (`PreviewSpinSeconds`) and `SkinFx.AnimatePreview(model)`.
  - It is rebuilt `PreviewDelay` seconds after a change; the old model is destroyed and its animation stopped.
- **Turntable** toggle:
  - The camera becomes `Scriptable` and circles your character via `BindToRenderStep("SkinStudioTurntable", Camera + 1)`, with `Turntable.Seconds`, `Distance` and `Height`.
  - It stops on toggle, close, death or respawn, and puts `CameraType = Custom` and `CameraSubject = humanoid` back.
  - This is the real character, so real particles, lights and walk styles show.

### 6.5 Undo/Reset: `src/client/SkinStudioState.luau` (pure, testable)
```
State.new(item, source: string?) -> State
state:Get() -> item                   -- deep copy
state:Set(path: { string | number }, value: any)   -- one Undo step (value nil = clear the key)
state:Begin() / state:Commit()        -- group a slider drag into one step
state:Undo() / state:Redo() / state:CanUndo() / state:CanRedo()
state:Reset()                         -- back to how it was when opened (catalogue version or blank)
state:Dirty() -> boolean
state.Changed: signal (BindableEvent wrapper)
```
History is capped at `UndoSteps`. Undo, Redo and Reset each schedule a Wear like any change. `SkinStudioUI` keeps the State object in a module-level variable, so closing the panel keeps it (6.2).

### 6.6 Server: `src/server/Services/SkinStudioService.luau`
**`Start()` never yields** (`Main.server.luau` starts services one after another; a yield here would hold up every later service down to GameService). It:
1. creates `Remotes.Function("SkinStudio")` **first**, before any feature check
2. registers the F8 command
3. returns when the feature is off
4. if `UseDataStore` **and** (`RunService:IsStudio()` or `AllowInLiveServers`): starts the DataStore load and the flush loop in `task.spawn`. Otherwise it never touches `DataStoreService` (live servers never read it on boot).
5. in Studio with `PrintOnStop`: `game:BindToClose` prints the drafts saved this session (`SkinExport.Print`, below), as a last-chance copy in Output.

Every handler wraps its work in `pcall` and returns a `Reply`; it never errors back to the client.

`SkinStudio:InvokeServer(action: string, payload: any) -> { Ok: boolean, Message: string, Data: any? }`

**Check order for every call:** `action` is a string → `Allowed(player)` → the action's cooldown, **stamping the time right away, before anything can yield** (so two parallel calls can't both pass) → the payload's type → for Wear/Save: the payload is a **string** with `#payload <= MaxDraftBytes` (instant) → `pcall(HttpService.JSONDecode)` → `SkinSchema.Decode` → `SkinSchema.Validate`.

| Action | Payload | Data | Checks (besides the order above) |
| --- | --- | --- | --- |
| `"Hello"` | — | `{ DataStore = "Loading" \| "On" \| "Off" \| "Failed", Drafts = { DraftSummary }, Wearing = string? }` | — |
| `"Get"` | `DraftId: string` | the `DraftRecord` | exists, not deleted |
| `"Wear"` | JSON string of `{ DraftId: string?, Item: EncodedItem }` | `{ WornId: string }` | `WearCooldown`; Validate (errors refuse, warnings allowed); character alive; not a hider |
| `"StopWearing"` | — | — | — |
| `"Save"` | JSON string of `{ DraftId: string?, Source: string?, Item: EncodedItem, Note: string?, UnlockEconomy: boolean? }` (`DraftId` nil = new) | the stored `DraftRecord` | `SaveCooldown`; Validate (errors refuse); at most `MaxDrafts`; `Source` must be a real catalogue Id and the draft may not change its Id or Theme; Rarity/Crate/Price/CrateOnly unchanged unless `UnlockEconomy`; the Id isn't used by another live draft or by a catalogue skin other than `Source` (`IdOk` with the taken set); the escaped record fits one export page (6.8); the whole store stays under `MaxStoreChars` |
| `"Delete"` | `DraftId: string` | — | exists |
| `"LookupAsset"` | `id: number` | `AssetInfo = { Name, Type: string?, AssetType: string, Creator: string, CreatorType: string, CreatorId: number, RobloxMade: boolean, Allowed: boolean, Problem: string? }` | `LookupCooldown`; a finite integer in range; `pcall(MarketplaceService.GetProductInfoAsync)` (falls back to `GetProductInfo`); `Allowed` from `SkinCatalog.CreatorAllowed`; result cached per id for this server (only a lookup that **succeeded** is cached) |
| `"PrintDrafts"` | — | `{ Pages: number }` | `PrintCooldown`; calls `SkinExport.Print()` (for the older MCP, 6.8) |

- **Wearing:**
  - `ShopService.SetSkinOverride(player, wearItem)` then `ShopService.Dress(player)`.
  - `StopWearing` sets the override to nil and dresses again.
  - The override is dropped on `PlayerRemoving`.
- **Respawn:** `Dress` on `CharacterAdded` uses the override, so the draft comes back by itself.
- **Save fills server-side fields:** `DraftId` (new GUID), `Updated`, `Author`, and `Lookups` (the server's cached `LookupAsset` results for every id in `SkinCatalog.Ids(Item.Style.Catalog)`). The client can't set them.
- **Drafts are stored:**
  1. in memory (`drafts[DraftId]`), straight away
  2. in the **mirror** `ServerStorage.SkinStudioDrafts` (a Folder made at runtime, the first time a draft is saved): one `StringValue` per draft, `Name = DraftId`, `Value = JSON(DraftRecord)`, attributes `SkinId`, `Theme`, `Updated`, straight away. Deleting removes the StringValue.
  3. in the **DataStore**, only when `UseDataStore` (default **off**, see 6.8 and 13): `DataStoreService:GetDataStore(DraftStore)`, key `DraftKey`, value `{ Version = 2, Drafts = { [DraftId] = DraftRecord } }`.
- **DataStore rules** (one key allows about one write every 6 seconds):
  - Save and Delete only mark the store **dirty**. A flush loop writes with `UpdateAsync` at most once every `FlushSeconds` (7), only when dirty, plus a final flush in `BindToClose` (pcall, best effort).
  - **Merge:** inside `UpdateAsync`, per `DraftId` the record with the larger `Updated` wins. Delete stores a **tombstone** (`{ DraftId, Deleted = true, Updated = now }`), so a merge never brings a deleted draft back. Tombstones older than `TombstoneDays` are dropped during the merge.
  - **Size:** before writing, `#HttpService:JSONEncode(value) < MaxStoreChars` (under the 4 MB limit). If it's too big, the write is skipped and the status says *"Too many drafts to keep after Stop: delete some"*. Save also refuses a draft that would push the in-memory total over `MaxStoreChars`.
  - **Loading** happens once, in its own thread after `Start`. Until it finishes, `Hello` reports `"Loading"`. On failure the status is `"Failed"` or `"Off"` (no published place, or Studio API access off) and the UI explains (6.8).
  - A failure never blocks memory or mirror saves.
- **Names:** draft names are seen only by admins in their own panel and are never shown to other players, so they need no TextService filtering. If that ever changes, filter them (CLAUDE.md rule 7).

### 6.7 ShopService hook (builder B; the only ShopService change)
```lua
-- Skin Studio: wear `item` in the Skin slot instead of the equipped skin (no ownership check:
-- SkinStudioService only calls this for admins; the save never changes). nil = back to normal.
function ShopService.SetSkinOverride(player: Player, item: any?)
function ShopService.SkinOverride(player: Player): any?
```
- In `Dress`: for slot `"Skin"`, if there is an override, `Cosmetics.Wear(character, override)` and skip the saved skin.
- `PlayerRemoving` clears it.
- The hider early-return stays first.

### 6.8 Saving to the game files
**The main path is Studio MCP + `/save-skins`, during the playtest, before Stop:**
1. In Skin Studio, press **Save** on each draft (Save tab). The status line says where it is kept:
   - *"Saved for this playtest. Run /save-skins in Claude Code before you press Stop."* (the default), or
   - *"Saved. Also kept after Stop (DataStore on)."*
2. In Claude Code type `/save-skins` (`.claude/commands/save-skins.md`, B). It runs these steps:
   1. **Which MCP is connected?**
      - **Built-in Studio MCP** (tools `list_roblox_studios`, `get_studio_state`, `execute_luau`, `get_console_output`). Every call needs a `studio_id`: call `list_roblox_studios` first and pick the instance with this place (ask Kieran if there are several).
      - **Older open-source MCP** (tools `run_code`, `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode`). It can't read the play-server DataModel, and `run_script_in_play_mode` starts a **fresh** playtest that has no drafts, so never use it here. Go to step 2b.
   2. **Read the drafts.**
      - **a. Built-in MCP:** `get_studio_state`. If a playtest is running, `execute_luau` with `datamodel_type = "Server"`: `return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).Count()`, then the same with `.Json(<page>)` for each page. If stopped: the same calls with `datamodel_type = "Edit"` (they read the DataStore, which only has drafts if `UseDataStore` was on and API access is enabled). If there's nothing there, ask Kieran to press Play, open Skin Studio and Save again, or to look in Output for the Stop print-out (step 2b).
      - **b. Older MCP, or as a fallback:** ask Kieran to press **Print for Claude** in the Save tab (or check that Output still shows the print-out made when he pressed Stop), then call `get_console_output` and take every page between `Config.SkinStudio.ExportMarkers`.
   3. Write each page, exactly as received, to `tests/out/skin-drafts/page-<n>.json` (git-ignored).
   4. Run `lune run tests/save-skins -- tests/out/skin-drafts --dry-run` and show Kieran the plan: which file, added or replaced, warnings, economy changes, unapproved catalog ids, and the new rarity counts.
   5. Run it again without `--dry-run`, then `stylua src`, `selene src` and `lune run tests/run`.
   6. If a new skin changed a theme's rarity counts, update `tests/specs/skins.spec.luau` and `crates.spec.luau` the way `/add-skin` step 6 describes. Explain the new crate odds (`/add-skin` step 5).
   7. Fix test failures caused by the drafts, or tell Kieran which draft breaks which rule. Never weaken an unrelated test.
   8. Commit `Skin Studio: <n> skins` (only if Kieran agrees), and tell him which skins went in.

**The Lune tool `tests/save-skins.luau` (B):**
- **Usage:** `lune run tests/save-skins -- <page.json | folder of pages> [--dry-run] [--only <Id>,<Id>]`.
- **Checks every draft's checksum first:** each page holds `{ Sum, Text }` per draft (below). The tool computes `SkinExport.Sum(Text)` and refuses the whole run if any differs ("page 3, draft 2 was damaged in copying: read it again").
- **Generates its own text:** it builds the harness `Runtime` and `rt:require`s `SkinSchema` and `SkinExport`. For each draft it decodes `Text`, runs `Decode` and `Validate`, and **regenerates** the Luau with `SkinSchema.ToLuau`. It never pastes text from the JSON, so a stale or edited file can't inject code.
- **Refuses:**
  - drafts with errors
  - Classic or Tower skins
  - a `Source` whose Id changed
  - an Id that already exists in another theme file, or **two drafts with the same Id in one batch**
  - a catalog id not in `Config.SkinCatalog.ApprovedIds` (it prints the creator from the draft's `Lookups`)
  - a theme file without `local rgb = Color3.fromRGB` / `local M = Enum.Material`
- **Warns loudly** (but writes, after Kieran's yes in `/save-skins`) when `UnlockEconomy` changed Rarity, Crate, Price or CrateOnly of an existing skin.
- **Edits:** it uses pure helpers in `tests/tools/SkinFile.luau`:
  - **replace** the entry block containing `\t\tId = "<Id>",`: from the nearest `\t{` line above to the next `\t},` line
  - or **insert** a new entry after the last entry of the same `Rarity`, or before the closing `} :: { any }`
  - every other byte stays identical
  - the header count line (`(20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY`) is updated when it matches that pattern
- **Output:** per theme, the rarity counts before and after, then the warnings. Exit code 1 if anything was refused.

**Copy code (always works, no setup):**
- The Save tab's **Copy code** opens a modal `TextBox` (MultiLine, `ClearTextOnFocus = false`). It holds `SkinSchema.ToLuau(item)`, computed on the client because the module is shared, plus a one-line hint: *"Ctrl+A, Ctrl+C, then paste it into Claude Code and say which theme file"*. If you type in it, the text resets when the box loses focus.
- **Print for Claude** asks the server to print every saved draft to Output (`PrintDrafts`), page by page between `Config.SkinStudio.ExportMarkers`. MCP `get_console_output` can read it.

**Edit-mode-safe helper `src/server/Tools/SkinExport.luau` (B):**
```
SkinExport.Count() -> string            -- JSON {"From":"Playtest"|"DataStore"|"None","Drafts":n,"Pages":n,"Problem":string?}
SkinExport.Json(page: number) -> string -- JSON {"Version":2,"From":...,"Page":p,"Pages":n,"Drafts":[{"Sum":n,"Text":"<record JSON>"}]}
SkinExport.Print()                      -- every page, each between the export markers
SkinExport.Sum(text: string) -> number  -- FNV-1a 32-bit over the bytes of `text`
```
- In a playtest it reads the `ServerStorage.SkinStudioDrafts` mirror. Otherwise it reads the DataStore (`pcall`, only when `UseDataStore`). Tombstones are never exported.
- **Pages:** whole drafts, at most `ExportPageChars` (20,000) characters per page. A single draft always fits: `Save` refuses a record whose text, escaped as a JSON string (`#HttpService:JSONEncode(text)`), is longer than `ExportPageChars - 500` (room for the page envelope). With `MaxDraftBytes = 10,000` that only happens with very unusual text.
- **Checksum:** `Sum` is computed on the exact `Text` string stored in the mirror, never on re-encoded JSON (Roblox and Lune order JSON keys differently, so re-encoding would never match).
- **Safe to require in edit mode, from MCP or the command bar:** it is stateless, creates **no instances**, and requires only `Config` (and Roblox services). It must never require `Remotes` (a server-side require creates `ReplicatedStorage.Remotes` in the Edit DataModel; saved into the place, clients would then wait forever on that stale folder), `Cosmetics`, `SkinSchema` or any service.

**After saving:** Rojo syncs the changed theme files into Studio. On the next playtest, the Skins list marks a draft **✓ in game files** when `SkinSchema.Encode(draft.Item)` equals the catalogue entry's encoding, and offers **Delete draft**.

### 6.9 Shared module `src/shared/SkinSchema.luau` (builder B; pure, client + server)
```
export type Field = { Key: string, Path: { string }, Label: string, Help: string, Section: string,
	Control: "Color" | "Material" | "Choice" | "Patterns" | "Toggle" | "Number" | "Text"
		| "Effects" | "Motion" | "Catalog",
	Choices: (() -> { string })?, Min: number?, Max: number?, Step: number?,
	Optional: boolean, From: string?, Economy: boolean? }  -- From = lowest rarity it suits; Economy = locked for existing skins
SkinSchema.Fields: { Field }          -- item fields + every Style key, in export order
SkinSchema.ItemKeys: { string }       -- editable: Id, Name, Rarity, Crate, Price, CrateOnly, Style
SkinSchema.ReadOnlyKeys: { string }   -- carried unchanged: Slot, Theme, OneInAMillion, Odds, VipOnly, Exclusive
SkinSchema.EconomyKeys: { string }    -- Rarity, Crate, Price, CrateOnly
SkinSchema.Encode(item) -> EncodedItem          -- JSON-safe: Color3 "#RRGGBB", Enum.Material name
SkinSchema.Decode(encoded: any) -> (item?, { string } errors)
SkinSchema.Validate(item) -> (boolean, { string } errors, { string } warnings)
SkinSchema.Check(item, catalogue: { any }) -> { string } warnings   -- RarityProblems, duplicate look (LookKey),
	-- CRAZY head already used, duplicate Name, test expectations (crate skin with own Crate/Price/HideClothes false)
SkinSchema.RarityProblems(item) -> { string }   -- the rarity look rules skins.spec checks (Commons are colours,
	-- Uncommons add a head piece, ...) + SkinAnimate.RarityProblems. The only copy of these rules.
SkinSchema.CrazyHeadProblems(catalogue: { any }) -> { string }   -- a CRAZY head used by another skin
SkinSchema.LookKey(style) -> string   -- the look key; skins.spec calls it (the only copy)
SkinSchema.IdOk(id, theme, taken: { [string]: boolean }?) -> (boolean, string?)
	-- ^(%u%a+)_(%u%w+)$, prefix = theme, not "StudioDraft_", not in `taken`
SkinSchema.NewItem(theme: string) -> item
SkinSchema.Duplicate(item) -> item
SkinSchema.WearItem(record) -> item   -- { Id = "StudioDraft_...", ModelId = Item.Id, Slot = "Skin", Name, Rarity, Style + Kind/HideClothes defaults }
SkinSchema.ToLuau(item, theme: string?) -> string   -- one entry, one tab indented, in the theme files' style
```
**Validation errors** (the server refuses):
- not a table; unknown keys at any level; wrong types; nesting deeper than **6** levels (the item is level 1; `Item.Style.Animate[i].Colors` and `Style.Catalog.Accessories[i]` are 5)
- a number that isn't finite (NaN, ±inf), anywhere
- a list that isn't a proper sequence (`1..n`, no holes, no other keys), anywhere
- **any string with a control character** (byte < 32 or 127, so also newlines and tabs), anywhere, so `ToLuau` can't write a broken theme file
- `Style.Kind` other than `"Skin"` (nil is filled in as `"Skin"`)
- a colour that isn't `#RRGGBB`; a material that isn't an `Enum.Material` name
- `Head` not `HeadPieces.Has`; `Face` not in `HeadPieces.Faces`
- an unknown pattern (`Cosmetics.HasPattern`); `Aura.Kind` not in `Config.Skins.Auras`
- `Crazy.Orbit` not in `OrbitKinds`; `Crazy.Count` not an integer 1–8; `Crazy.Effect` not a key of `Config.Skins.Effects.Special` (the server can't require the client's SkinEffects)
- Animate, Motion or Catalog errors from A's `Normalize` functions (including the 3.2a ownership errors)
- `SkinAnimate.EncodeLive(style)` reports "too long" (every valid draft must be wearable)
- out-of-range numbers: `Transparency` 0–0.9, `Glow.Brightness` 0–10, `Glow.Range` 0–60, `Price` an integer 0–10,000,000
- `Name` not 1–40 characters; `Note` over 120; any other string over 60 characters
- `Rarity` not in `Config.Rarity.Order`; `Theme` not in `Config.Skins.Themes`; `Crate` not in `Config.Crates.List`
- a bad Id (`IdOk`); encoded size over `MaxDraftBytes`

**Warnings** (allowed in drafts, listed in the UI and by `/save-skins`): everything `Check` returns.

**ToLuau rules:**
- Uses the theme file's locals `rgb(...)` and `M.Name`.
- Leaves out what `Skins/init.luau` fills in: `Slot`, `Theme`, `Style.Kind`, `HideClothes = true`, and `Crate` when it equals the theme's crate.
- Key order follows `Fields`. Numbers are written shortest-exact (`1.5`, `0.35`). Strings are double-quoted with `\` and `"` escaped (control characters can't occur).
- `OneInAMillion`/`Odds` get the same comments the theme files use.

### 6.10 `Config.SkinStudio` (`src/shared/Config/SkinStudio.luau`, builder B)
```lua
return {
	AllowInLiveServers = false, -- true = admins can use it in live games too (Config.Admin decides who)
	-- false = drafts are kept only during the playtest: run /save-skins before Stop (the safe default).
	-- true needs "Enable Studio Access to API Services", which ALSO makes Studio use your real
	-- player save and the public leaderboard. Read docs/CUSTOMIZE.md > Skin Studio first.
	UseDataStore = false,
	DraftStore = "SkinStudioDrafts_v1", DraftKey = "Drafts",
	FlushSeconds = 7, -- DataStore writes at most this often (Roblox allows about 1 per 6 s per key)
	TombstoneDays = 30, -- deleted drafts are remembered this long so a merge can't bring them back
	MaxStoreChars = 3900000, -- under the DataStore's 4 MB per key
	MaxDrafts = 200, MaxDraftBytes = 10000,
	ExportPageChars = 20000, -- SkinExport page size (MCP output is cut off past roughly this)
	PrintOnStop = true, -- in Studio, print this session's drafts to Output when the playtest stops
	KeepWearingDefault = true, -- keep wearing the draft after closing the panel
	WearDelay = 0.35, PreviewDelay = 0.15, -- seconds after your last change
	WearCooldown = 0.25, SaveCooldown = 1, LookupCooldown = 1, PrintCooldown = 5, -- per admin, on the server
	UndoSteps = 50,
	ListPageSize = 30, PhoneListPageSize = 15,
	Panel = { Width = 440, PhoneHeightScale = 0.55 },
	PreviewSpinSeconds = 6,
	Turntable = { Seconds = 8, Distance = 9, Height = 2 },
	Palette = { --[[ 24 Color3s: pumpkin oranges, candy pinks, ghost whites, night purples, slime greens, bone, black ]] },
	Materials = { "SmoothPlastic", "Plastic", "Neon", "Foil", "Glass", "ForceField", "Metal", "DiamondPlate",
		"Fabric", "Wood", "WoodPlanks", "Marble", "Granite", "Slate", "Cobblestone", "Brick", "Concrete",
		"Ice", "Snow", "Sand", "Grass", "CrackedLava", "Pebble", "CorrodedMetal" },
	ExportMarkers = { Begin = "--[[ SKIN STUDIO BEGIN ]]", End = "--[[ SKIN STUDIO END ]]" },
	Text = { --[[ every message the panel shows, in plain English ]] },
}
```
`Config.Features.SkinStudio = true` (it only ever shows for admins in Studio).

---

## 7. Contracts at a glance

**New Style keys** (all optional; added to `STYLE_KEYS` and to the options comment at the top of `Skins/Pumpkin.luau`):
| Key | Type | Section |
| --- | --- | --- |
| `Animate` | table (list) | 3 |
| `Motion` | string or table | 4 |
| `Catalog` | table | 5 |

**Item field:** `ModelId` (string, optional). It is never written to theme files; only `SkinSchema.WearItem` sets it.

**Tags:** `Tags.SkinAnim = "SkinAnim"` (on a `Cosmetic_Skin` model with animations).

**Attributes:**
| On | Name | Type | Set by |
| --- | --- | --- | --- |
| `Cosmetic_Skin` / preview model | `LiveStyle` | string (JSON) | Cosmetics (drafts only), before parenting |
| every skin piece (BasePart or Model) | `SkinPart` (`"Head"`, a pattern name, `"Aura"`), `SkinIndex` (build order) | string, number | Cosmetics, always |
| `AnimPivot` part | `AnimGroup`, `AnimSide`, and the copied custom `Animate`/`Speed`/`Amount`/`Axis`/`Delay`/`Every`/`Reverse`/`Color2` | various | Cosmetics |
| custom-model part or Model | `Animate`, `Speed`, `Amount`, `Axis`, `Delay`, `Every`, `Reverse`, `Color2` | various | Kieran in Studio |
| character | `SkinMotion` | string | Cosmetics |
| character | `SkinMotionIds` | string | Cosmetics |
| character | `SkinCatalogStatus` | string | SkinCatalogService |
| catalog Accessory | `SkinCatalog` | boolean | SkinCatalogService |
| Player | `SkinStudioOpenAt` | number | SkinStudioService (F8) |

**Joints and instances:**
- `Motor6D` named `SkinMotor`, inside each `AnimPivot`.
- `ServerStorage.SkinStudioDrafts` (Folder of StringValues, runtime only).
- `Workspace.LocalSkinFx` (existing, client-only).

**Remotes** (B only; A adds none):
| Name | Kind | Direction |
| --- | --- | --- |
| `SkinStudio` | RemoteFunction | client → server |

**Feature switches** (`Config.Features`): `SkinAnimations = true`, `WalkStyles = true`, `SkinCatalog = false` (A); `SkinStudio = true` (B).

**Config sections:** `Config.SkinAnimate`, `Config.SkinMotion`, `Config.SkinCatalog` (A); `Config.SkinStudio` (B).

**Saved data:** none added.

---

## 8. File ownership and how the builders share the branch

### 8.1 Working copies
- **Each builder works in its own git worktree on its own branch**, made from the commit that holds this spec, for example:
  - A: `git -C /home/user/Janus worktree add /home/user/Janus/.claude/worktrees/skin-a -b skin-studio-a claude/clever-clarke-3zqgma`
  - B: the same with `skin-b` / `skin-studio-b`

  (If the orchestrator already gives each builder a worktree, use that.) The checker takes the worktree's folder: `/tmp/claude-0/check/check.sh <worktree>/new-game`.
- Run `stylua src`, `lune run tests/run` and every other tool **only inside your own worktree**. Never in the main checkout, and never in the other builder's.
- **Commit only paths you own**, by name: `git add <path> <path>`. Never `git add -A`, `git add .` or `git commit -a`.
- Nobody pushes. The other Claude Code session on Kieran's PC also commits to `claude/clever-clarke-3zqgma`; only the integration step (8.4) touches that branch.

### 8.2 Builder A: animation system + catalog items
| File | New / change |
| --- | --- |
| `src/shared/SkinAnimate.luau`, `src/shared/SkinMotion.luau`, `src/shared/SkinCatalog.luau` | new |
| `src/shared/Config/SkinAnimate.luau`, `Config/SkinMotion.luau`, `Config/SkinCatalog.luau` | new |
| `src/client/SkinAnim.luau`, `src/client/SkinWalk.luau`, `src/client/CatalogBadge.luau` | new |
| `src/server/Services/SkinCatalogService.luau` | new |
| `src/shared/Cosmetics.luau` | change (3.4, 4.2, 5.3 hooks, hat welds, restore without duplicates) |
| `src/client/SkinFx.luau` | change (3.11) |
| `src/shared/DanceMoves.luau` | optional tiny export (4.3) |
| `src/shared/Tags.luau` | one line |
| `src/client/ShopUI.luau` | two hooks (3.7, 5.4) |
| `src/client/CrateUI.luau` | one hook (5.4) |
| `src/shared/Config/Skins/*.luau` | showcase animations on existing skins (section 9, step A6), and the Pumpkin.luau options comment |
| `tests/specs/skins.spec.luau` | change, **except the two blocks B owns** (8.3): the `STYLE_KEYS` table and its test; a **new** `it` inserted right after "only uses known Style keys of the right type" (Normalize on every skin, `ApprovedIds`); the `HideClothes` rule in "fills Slot, Crate, Kind and HideClothes"; `snapshot`; and in "Wearing skins" the weld chain rule and the accent count (section 10) |
| `tests/specs/skinanimate.spec.luau`, `skinmotion.spec.luau`, `skincatalog.spec.luau` | new (each includes its own feature-off/on Mount and Start tests) |
| `.claude/commands/add-skin.md` | mention Animate, Motion and Catalog |
| `.claude/commands/animate-skin.md` | new: `/animate-skin <skin> <what should move>` |
| `docs/CUSTOMIZE.md` | sections "Animated skins", "Walk styles", "Catalog items in skins", inserted after "### Crate skins: add or change a skin" (before "### Trails"); 2 rows in "Turn animations off or down"; the `/animate-skin` row in "Claude Code commands" **right after the `/add-skin` row** |

### 8.3 Builder B: Skin Studio + saving
| File | New / change |
| --- | --- |
| `src/shared/SkinSchema.luau` | new |
| `src/shared/Config/SkinStudio.luau` | new |
| `src/server/Services/SkinStudioService.luau`, `src/server/Tools/SkinExport.luau` | new |
| `src/client/SkinStudioUI.luau`, `src/client/SkinStudioControls.luau`, `src/client/SkinStudioState.luau` | new |
| `src/server/Services/ShopService.luau` | change (6.7 only) |
| `src/shared/Config/Menu.luau` | the tile line, after the `EasterEggs` tile |
| `tests/specs/skins.spec.luau` | **only** the bodies of two `it` blocks, in B4: "makes every skin look clearly different (no two share a look)" (calls `SkinSchema.LookKey`) and "makes each rarity look better than the one below" (calls `SkinSchema.RarityProblems` and `CrazyHeadProblems`). Same test names, same failure messages. |
| `tests/save-skins.luau`, `tests/tools/SkinFile.luau` | new |
| `tests/specs/skinstudio.spec.luau` | new (includes the feature-off/on Mount and Start tests for B's modules) |
| `.claude/commands/save-skins.md` | new |
| `CLAUDE.md` | the slash-command list line: add `/save-skins` and `/animate-skin` (B adds both, so only one builder edits that line) |
| `docs/CUSTOMIZE.md` | a new `## Skin Studio` section inserted right before `## Crates`; the `/save-skins` row in "Claude Code commands" **after the last row (`/polish-hub`)** |

**Shared hook points** (both builders edit; exact places, at least 5 untouched lines apart, so git merges them cleanly)
| File | A adds | B adds |
| --- | --- | --- |
| `src/shared/Config/Features.luau` | 3 lines right after `SkinEffects = true, ...` | 1 line right after `Menu = true, ...` |
| `src/shared/Config/init.luau` | `SkinAnimate = require(script.SkinAnimate),` `SkinMotion = ...,` `SkinCatalog = ...,` right after `Skins = require(script.Skins.Settings),` | `SkinStudio = require(script.SkinStudio),` right after `ScreenMotion = require(script.ScreenMotion),` |
| `src/client/Main.client.luau` ORDER | `"SkinAnim", -- ...` and `"SkinWalk", -- ...` right after `"Dances"` | `"SkinStudioUI", -- ...` right after `"AdminUI"` |
| `src/server/Main.server.luau` ORDER | `"SkinCatalogService", -- ...` right after `"ShopService"` | `"SkinStudioService", -- ...` right after `"AdminService"` |
| `tests/specs/skins.spec.luau` | everything listed in 8.2 | the two blocks listed in 8.3 |
| `docs/CUSTOMIZE.md` | the places listed in 8.2 | the places listed in 8.3 |

- **`tests/specs/Startup.spec.luau` is not edited by anyone.** Each builder puts the "mounts / starts with the feature off and on, and never waits on a missing remote" tests for its own modules in its own spec (A: SkinAnim, SkinWalk, SkinCatalogService; B: SkinStudioUI, SkinStudioService).
- **Test harness:** if A needs Humanoid description stubs, A defines them inside its own spec with `Dom.define("Humanoid", {...})` (as `serverguard.spec` does), not in `tests/harness/`. B doesn't touch the harness.

### 8.4 Integration (the orchestrating session, after both builders)
The integrator owns: merging, `docs/V2-CHANGES.md`, `docs/PROGRESS.md`, `ROADMAP.md` (if it lists the feature), and the final checks. Neither builder edits those three files.
1. On `claude/clever-clarke-3zqgma` (merge in anything the branch gained meanwhile first; never force anything): merge `skin-studio-a`, then `skin-studio-b`.
2. `stylua src`, `/tmp/claude-0/check/check.sh <new-game>` with no new type errors, `lune run tests/run` all green, catwalk renders of the showcase skins.
3. Update `V2-CHANGES.md` (what's new, switches, undo, the API-access warning) and `PROGRESS.md`.
4. Commit `Skin Studio: integrate animated skins and the editor` with the two attribution lines. No push.
5. Hand over the Studio test list (section 14).

---

## 9. Build order and sync points
- **A1 (first, small, ~1 h):**
  - all three Config files and the switches
  - `SkinAnimate`, `SkinMotion` and `SkinCatalog` shared modules with metadata, `Normalize` (including finiteness and the 3.2a ownership rule), encode/decode and the pure maths
  - `Tags.SkinAnim` and the hook lines
  - their unit tests

  Commit as `Skin animations: shared contract`.
- **A2:** Cosmetics (`SkinPart`/`SkinIndex`, pivots, attribute/tag/parent order, LiveStyle, ModelId, Motion attributes, hat welds, OnSkinChanged, catalog skip, restore without duplicates) + A's skins.spec changes.
- **A3:** SkinAnim + SkinFx changes + preview hooks.
- **A4:** SkinWalk.
- **A5:** SkinCatalogService + CatalogBadge.
- **A6 (last, its own commit):** showcase skins, then docs and the slash command. Suggested showcase (Rare at most 3 effects, Motion Rare and up; CRAZY skins never colour their rainbow accents or pulse their glow, 3.2a):
  - `Candy_BubblegumBat`: Flap
  - `Moonlight_MoonMoth`: slow Flap + Glow Pulse
  - `Candy_CottonCandyCat`: Wag
  - `WitchsBrew_BrewMistress`: Wag + Cape Breathe
  - `Pumpkin_SirGourdington`: Cape Breathe + Head Wobble
  - `ZombieTown_ZombieOverlord`: Flap + `Motion = "Zombie"`
  - `Pumpkin_MegaGourdSupreme`: Head Float + Head Shimmer + Aura SparkleBurst + `Motion = "Bouncy"` (the head piece isn't rainbow, so Shimmer there is allowed)
  - `VampireCastle_NightLordSupreme`: Cape Wobble + `Motion = "Bat"`
  - `Moonlight_LunarLegend`: slow Head Spin + `Motion = "Ghost"`
- **B1:** Config.SkinStudio, SkinSchema (core keys: Encode/Decode/Validate/ToLuau/LookKey, read-only keys, finiteness, depth, control characters, sequences) + tests.
- **B2:** SkinStudioService (non-yielding Start, check order, cooldown stamps, Get/Hello summaries), the ShopService hook, the remote, drafts (memory, mirror, DataStore with flush/tombstones/size), SkinExport (Count/Json/Print/Sum), F8 attribute + tests.
- **B3:** SkinStudioState, SkinStudioControls, SkinStudioUI (PC and phone, kept state, economy lock, banners) + tests.
- **B4 (after A1):** Animate, Walk style and Catalog editors; SkinSchema delegates to A's `Normalize` functions and `SkinAnimate.RarityProblems`; the two skins.spec blocks call SkinSchema.
- **B5:** `tests/save-skins.luau` + `SkinFile` + `/save-skins` + docs.

**Sync points** (B merges A's branch into its own: `git merge skin-studio-a`):
| # | When | What |
| --- | --- | --- |
| S1 | A1 committed | B merges before starting B4 (A's `Normalize` functions and `RarityProblems`). |
| S2 | A2 committed | B merges before writing B2's Wear tests that need A's Cosmetics changes (custom models through `ModelId`, `LiveStyle`, `SkinPart`). B can write the rest of B2 first. |
| S3 | A6 committed | A6 adds `Animate` and `Motion` to theme files, which B's "knows every Style key" and round-trip tests must handle (B4). B's last step is merging A's finished branch and running the whole suite. If B finishes before A, the integrator re-runs `skinstudio.spec` and `skins.spec` after merging A6 and fixes or bounces any failure. |

**Each builder, before handing over:**
- `stylua`, then `/tmp/claude-0/check/check.sh <worktree>/new-game` with no new type errors
- `lune run tests/run` all green in its own worktree
- catwalk renders of the showcase skins (A)
- commits of owned paths only, ending with the two attribution lines; no push

---

## 10. Tests
**Changes to existing specs (A, `skins.spec`):**
- "Skin styles":
  - `STYLE_KEYS` adds `Animate = "table"`, `Catalog = "table"` and `Motion` (accepts `"string"` or `"table"`; change the check to allow a set of types).
  - A **new** `it`, right after "only uses known Style keys of the right type": runs `SkinAnimate.Normalize`, `SkinMotion.Normalize` and `SkinCatalog.Normalize` on every catalogue skin, with no errors and no warnings, and checks every catalog id is in `Config.SkinCatalog.ApprovedIds` (5.6).
  - (The rarity rules, including `SkinAnimate.RarityProblems`, come through B's rewrite of "makes each rarity look better", S3. A's own `skinanimate.spec` also runs `RarityProblems` on every skin, so A's branch is covered on its own.)
- "fills ... HideClothes": allow `HideClothes = false` when `Style.Catalog` has Shirt, Pants or TShirt.
- "Wearing skins":
  - **The joint check becomes a chain rule.** Every BasePart in `Cosmetic_Skin` is unanchored and `CanCollide = false`, and is either:
    - (a) joined by a `WeldConstraint` to a body part, or
    - (b) joined by a `WeldConstraint` to an `AnimPivot` in the model, or
    - (c) an `AnimPivot` whose `SkinMotor.Part0` is a body part or another `AnimPivot`

    Following the chain always ends at a body part outside the model.
  - **The accent count uses `SkinPart`**, not `FindFirstChildOfClass("WeldConstraint").Part0.Name` (which crashes on an `AnimPivot`, which has no WeldConstraint, and counts head-piece parts welded to a Head pivot as accents): count BaseParts whose `SkinPart` is a pattern name.
  - The snapshot also covers the character attributes `SkinMotion` and `SkinMotionIds`.

**New: `skinanimate.spec` (A):**
- every effect has metadata and Config numbers, and the other way round; there is no `Rainbow` or `Orbit` effect
- `Normalize` fills defaults; a table of ~30 bad inputs is each refused with a message, including **NaN, +inf and -inf** in every number key, a list with holes, and the 3.2a cases (colour effect on Accents/All/a pattern with `Crazy.Rainbow`; Pulse or Flicker on Glow with `Crazy.Pulse`); ColorCycle on Glow with `Crazy.Pulse` is allowed
- `DecodeLive` refuses NaN and ±inf as well; `EncodeLive` reports "too long" past `MaxLiveChars`
- Offset, Tint and Brightness are finite and continuous (a small `dt` gives a small change), and deterministic for the same `t`
- `EncodeLive`/`DecodeLive` round trip; `StyleOf` prefers the catalogue
- `RarityProblems` is empty for every catalogue skin
- **build attributes:** every skin piece has `SkinPart` and a unique `SkinIndex`; on a skin whose head piece has parts named `Wing`, `Tail`, `Spot`, `Stripe`, `Collar`, `Wrap`, `Stitch`, `Patch` or `Buckle` *and* the matching accent patterns, `Wings`/`Stripes`/... targets get only accent pieces and `Part:Wing` gets only head-piece parts
- pivots are built only for moving targets; a skin without Animate builds the **same instances** (attributes aside) as with the feature off
- **attributes before parenting:** a `ChildAdded` listener on the character sees `ItemId`, `LiveStyle` and the tags already set on the new `Cosmetic_Skin`
- **hats:** with a moving head piece the hat welds to the Head pivot; taking the skin off on its own leaves the hat welded to `Head` (it doesn't fall)
- animated skins go on and come off R15 and R6 leaving the avatar exactly as it was
- custom-model `Animate` attributes become groups (a test model made in the runtime under `Custom.Cosmetics`); a `Custom:` group inside a moving head piece chains to the Head pivot
- nothing is built or tagged with `SkinAnimations` off; `SkinAnim.Mount` with the feature off does nothing and never waits
- **client:**
  - budget (PC 8, phone 4, own character first, distance cull)
  - hider deactivates straight away on the attribute change
  - last-written guard (the server recolours mid-effect, then deactivate leaves it)
  - **SkinFx + SkinAnim on a CRAZY draft with Animate:** over 3 virtual seconds, no part's `Color` and no light's `Brightness` is written by both modules (count writers per property)
  - **every frame at half rate:** a character beyond `HalfRateDistance` gets a `SkinMotor.Transform` write on every frame (the test resets `Transform` to identity between frames, like the Animator, and checks it is written again each frame)
  - colour effects run at `ColorHz` and skip unchanged colours
  - SparkleBurst never emits on a disabled emitter; phones emit `PhoneBurstScale` as many
  - over 5 virtual seconds with every effect running, no `Transparency`, `Enabled` or `LocalTransparencyModifier` change event fires
  - no frame connection when idle (perf pattern)
  - **perf, 32 characters:** 32 characters wearing a test draft with 6 colour effects on `All` (40 parts), PC then phone: over 3 s the colour/light writes per frame (`SkinAnim.ColorWrites`, cross-checked by counting `Color` change events) never exceed `MaxColorWrites` / `PhoneMaxColorWrites`, and motion goes to at most `MaxCharacters` / `PhoneMaxCharacters`
- **previews:**
  - `SkinFx.AnimatePreview` starts SkinAnim with `Features.SkinEffects` off, and on a skin with no rainbow parts; the one stop function stops both
  - animate only while shown **and** inside the scroll view (`PreviewVisible`: a card scrolled out of a ScrollingFrame gets no writes)
  - **motion under CrateUI's spin and scale:** the test spins the model with `PivotTo(base * yaw)` and calls `ScaleTo` every frame; each group stays at `model:GetPivot() * rest(scaled) * offset(scaled)` (within 1e-3), never at the unspun or unscaled place
  - motion on at most `MaxPreviewMotion`, none on phones

**New: `skinmotion.spec` (A):**
- every preset poses R15 and R6 with finite turns
- `Normalize` accepts presets and ids and refuses others (including NaN and inf ids)
- the server sets and clears the attributes
- Add mode doesn't build up when the "animator" doesn't write (the test sets `Transform` by hand between frames); with `Animator.EvaluationThrottled` stubbed `true`, base comes from `lastBase`; with the property missing, the fallback guess is used; a write happens every frame either way
- Set mode overrides; skips dancers, hiders, the seated and characters out of budget; clears joints on stop
- other players' characters are never checked with `GetState` (a stubbed `GetState` that errors for them doesn't matter); a fast vertical velocity fades them out
- your own character's root shift never exceeds `OwnRootShiftMax`
- own-client uploaded tracks load, switch Walk/Run/Idle by speed, stop on clear, **stop when your `HideSeekRole` becomes `"Hider"`** (`rt:calls("Animator", "LoadAnimation")` or a stub)
- `SkinWalk.Mount` with the feature off does nothing

**New: `skincatalog.spec` (A):**
- `Normalize`, `Key`, `Ids`; the names `FaceAccessory` / `ClassicFace`
- `CreatorAllowed` and `Approved` follow Config
- with `Dom.define("Humanoid", { GetAppliedDescription, ApplyDescriptionAsync })` stubs (yields, failures):
  - **waits for the appearance:** with `HasAppearanceLoaded` false, nothing is applied until `CharacterAppearanceLoaded` fires (or the timeout passes)
  - **players dressed before Start:** a player already in the game with a catalog skin gets it applied after `Start`
  - the description's accessories are `{ AssetId, AccessoryType = Enum.AccessoryType.X, IsLayered = false }` entries
  - applies once; newest wins; never for hiders (including one who becomes a hider during the yield)
  - restores `base` when the skin comes off
  - **no duplicate BodyColors** after apply → re-dress → take off
  - failure keeps the Part skin and sets the status
  - respawn applies again; feature off does nothing
- CatalogBadge shows thumbnails only for catalog skins

**New: `skinstudio.spec` (B):**
- **Schema:**
  - knows every Style key the catalogue uses
  - `Decode(Encode(item))` deep-equals the item for **all ~634 skins**, including `Slot`, `Theme`, `VipOnly` (KingSkin) and `Exclusive` (the Tower skin)
  - evaluating `ToLuau(item)` with `@lune/luau` `load` (env `rgb`, `M`) and re-applying the `Skins/init.luau` defaults deep-equals the item, for all skins
  - `LookKey` is unique across the catalogue; `RarityProblems` is empty for every skin
  - `Validate` refuses ~40 bad drafts: types, ranges, unknown keys, huge strings, **NaN/±inf in every number field**, **nesting 7 deep** (while 5-deep `Animate[i].Colors` and `Catalog.Accessories[i]` pass), **a newline, a tab or a NUL in any string**, a list with holes, `Style.Kind = "Hat"`, a style whose `EncodeLive` is too long, a bad Id, the `StudioDraft_` prefix, an Id taken by another draft
  - `Check` warns for each rarity rule, a duplicate look and a used CRAZY head
- **Server:**
  - only admins, only in Studio unless `AllowInLiveServers`; the feature off answers "not allowed" and never errors
  - **`Allowed` runs before any decode** (a non-admin's huge or malformed payload is refused without decoding)
  - malformed or oversize payloads, a table instead of a JSON string, and non-string actions get Ok = false
  - cooldowns, including **two parallel calls** (the second, started while the first yields in `LookupAsset`, is refused)
  - **`Start` doesn't yield:** run inside a coroutine it finishes at once, even with a slow DataStore; services after it start without waiting; `Hello` says `"Loading"` until the load ends
  - **no DataStore outside Studio:** with `studio = false` and `AllowInLiveServers = false`, `DataStoreService` is never called; with `UseDataStore = false` (default) never either
  - Wear wears `StudioDraft_...` with `ModelId`, leaves the save untouched, survives respawn, `StopWearing` puts the equipped skin back, refused for a hider
  - Save/Get/Delete in memory and mirror; `Hello` returns summaries only
  - **DataStore (UseDataStore on):** 10 saves within 3 s cause one write; the next write waits `FlushSeconds`; a deleted draft stays deleted after a merge with an older stored copy (tombstone); tombstones older than `TombstoneDays` disappear; `DraftId`s are unique GUIDs; an over-`MaxStoreChars` store isn't written and the status says so; failure (`dataStores = false`, `rt.dataStoreFailures`) still saves to memory and mirror with the right status; `BindToClose` flushes
  - `MaxDrafts`; `Source` id and theme locked; economy fields refused without `UnlockEconomy`, accepted with it
  - `LookupAsset` marks other creators not `Allowed`; `Save` records `Lookups` from the server's cache, ignoring anything the client sends
  - **F8 opens the panel on the first press:** the command sets `SkinStudioOpenAt` only for allowed players, and a mounted client opens the panel on the first change
- **SkinExport:**
  - `Count` and `Json(page)` from the mirror and from the DataStore; pages hold whole drafts and stay under `ExportPageChars`; tombstones aren't exported
  - `Sum(Text)` matches; a page with one changed character fails `save-skins`' checksum check
  - **edit mode:** requiring SkinExport in a fresh runtime with no services started creates no instances (descendant count unchanged; `ReplicatedStorage.Remotes` doesn't appear)
- **Client** (client runtime, `OnServerInvoke` stub):
  - shows nothing when off or not admin and never waits on a missing remote (remotes are looked up with `WaitForChild(name, 10)` inside Open, not in Mount; the F8 path needs no remote)
  - the Menu tile is visible only for admins
  - search and filter
  - one Wear after the debounce for a burst of edits
  - Undo, Redo and Reset
  - **closing keeps the work:** edit, close with Escape (`PanelManager.CloseTop`), reopen: the same draft, Undo history and tab; the character still wears the draft (Keep wearing on by default); the "not in the game files yet" banner counts right
  - economy fields are locked for an existing skin until unlocked
  - Copy code text equals `ToLuau`
  - phone layout is a bottom sheet with tabs, 44 px controls, and no `FitScale` shrink
  - open/close 20 times keeps instance and connection counts flat (like `perf.spec`)
  - turntable restores the camera
- **Tool:** `SkinFile` replaces an entry, inserts after its rarity group and keeps every other byte identical. `save-skins` refuses a renamed Id, an Id from another theme, **two drafts with one Id**, an unapproved catalog id, and a bad checksum. Counts are right.

**Existing guards that must stay green:** `Startup.spec` (ORDER modules mount), `Menu.spec` (a tile with `Feature` is a boolean switch), `perf.spec` (idle work), `modules.spec`, and the catalogue counts. Showcase skins don't add skins, so counts don't change.

---

## 11. Performance budgets
| What | PC | Phone | Where |
| --- | --- | --- | --- |
| Characters with animated pieces | 8 | 4 | `SkinAnimate.MaxCharacters` / `PhoneMaxCharacters` |
| Characters with walk styles | 12 | 6 | `SkinMotion.MaxCharacters` / `PhoneMaxCharacters` |
| CRAZY effects (existing) | 6 | 6 | `Skins.Effects.MaxAnimated` (unchanged) |
| Animation range | 120 studs (maths at half rate past 60, still written every frame) | same | `MaxDistance`, `HalfRateDistance` |
| Colour and light writes per frame, everything together | 400 | 120 | `MaxColorWrites` / `PhoneMaxColorWrites` |
| Colour effect update rate | 30 Hz, unchanged colours skipped | 30 Hz | `ColorHz` |
| Effects per skin | 6 (by rarity: 0/1/3/6) | — | validated |
| Moving groups per skin | 6 pivots | — | `MaxPivots` |
| Parts recoloured per effect | 40 | — | `MaxColorParts` |
| Parts in a `Cosmetic_Skin` | ≤ 120 including pivots | — | existing skins.spec test |
| Particles | SparkleBurst ≤ 50 per burst, at least 0.5 s apart; no new emitters | half (`PhoneBurstScale`) | validated |
| Lights / Highlights | none added | — | rule D3 |
| Previews with moving pieces | 4 | 0 | `MaxPreviewMotion` |
| Previews animating at all | only cards inside the scroll view | same | `SkinAnim.PreviewVisible` |
| Idle cost | no frame connection when nothing animates | — | perf.spec pattern |
| Network | nothing per frame; attributes once per wear; Studio Wear ≤ 4/s per admin | — | D1, `WearCooldown` |
| Catalog applies | ≤ 1 per player per 2 s, one in flight per character | — | `SecondsBetweenApplies` |
| DataStore (only if on) | ≤ 1 write per 7 s; nothing at all on live servers | — | `FlushSeconds`, 6.6 |

The worst case without the colour budget would be about 6 effects × 40 parts × 8 characters ≈ 1,900 colour writes a frame (960 on phones) on top of SkinFx. Off-screen characters (except you) get no writes. All per-frame work is plain Lua property writes, with no instance creation per frame.

## 12. Security checklist
- **Remotes:** B adds one (`SkinStudio`); A adds none. The F8 open path uses a player attribute set by the server. `SkinStudio` checks in this order: the action is a string, `Allowed`, the cooldown (stamped before anything yields), the payload type, the JSON string's length, then `pcall(JSONDecode)`, `SkinSchema.Decode` and `Validate` (strict whitelist, ranges, finite numbers, sequences, depth 6, no control characters). Errors become Replies, never script errors.
- **Hide & Seek:** a client never trusts its own guess. Hiders are skipped by every effect and walk style, and your own uploaded walk tracks stop when you become a hider. Effects can't un-hide anything (D3), and Catalog re-checks the role after the yield.
- **Ownership:** the Studio override is the only way to wear an unowned skin. It is set only by `SkinStudioService` after `Allowed`, and the save never changes. Players get nothing new through Skin Studio.
- **Economy:** Rarity, Crate, Price and CrateOnly of skins players already own are locked unless Kieran unlocks them, and `/save-skins` warns loudly about any such change.
- **Asset loads:** `AssetTypeVerification.Always` on every apply. Ids are integers, types are whitelisted and layered types refused. Only allowed creators and Kieran-approved ids reach the game files (5.6).
- **Export:** the save-skins tool checks every draft's checksum and regenerates code from validated data (it never pastes JSON text). Theme Ids never change. SkinExport creates nothing when required in edit mode.
- **DataStore:** off by default. When on, only the server writes, at most every 7 s, only in Studio (or with `AllowInLiveServers`), to a separate store name (`SkinStudioDrafts_v1`), never touching player data.

## 13. Docs to write
- **`docs/CUSTOMIZE.md` (A):**
  - **Animated skins**: what each effect does; copy-paste examples; targets; **"CRAZY already owns the rainbow and the glow pulse"** (3.2a) with what to use instead; rarity limits; turning effects down.
  - **Animate parts of your own model**: the attribute table and the Pivot tool, then Save to File into `assets/Cosmetics/<SkinId>.rbxm` to keep it in git.
  - **Walk styles**: presets; your own animations; the ownership rule; R6 note; "your own float is smaller so you don't hit ceilings".
  - **Catalog items in skins**: what's allowed and why; **only Roblox, you or your group, and each id approved in `ApprovedIds`**; how to switch it on; Studio test steps.
  - Two rows in "Turn animations off or down": `SkinAnimations`/`MaxCharacters` and `WalkStyles`/`MaxCharacters`.
  - The `/animate-skin` row in "Claude Code commands".
- **`docs/CUSTOMIZE.md` (B), "## Skin Studio":**
  - how to open it
  - a tour of each tab
  - wearing and the turntable; closing the panel keeps everything
  - saving (the three ways, with exact steps), and **"run /save-skins before you press Stop"** in bold
  - **a big warning box about Studio API access:** *"Turning on Game Settings > Security > Enable Studio Access to API Services makes Studio use your REAL player save and the PUBLIC leaderboard. Then F8 '+ Coins', 'Unlock all' and 'Reset my save' change your real save, and Studio test rounds post to the leaderboard everyone sees. Skin Studio doesn't need it: leave it off and use /save-skins during the playtest."* Only then: how to turn on `UseDataStore` if he still wants drafts kept after Stop.
  - troubleshooting: *"Saved for this playtest only"*, *"Not allowed"*, *"Slow down"*, *"Animation didn't load"*, *"Not an allowed creator"*, *"This skin's rarity is locked"*
  - The `/save-skins` row in "Claude Code commands".
- **The Pumpkin.luau STYLE OPTIONS comment (A):** `Animate`, `Motion` and `Catalog` with one-line examples.
- **Slash commands:**
  - `/save-skins` (B, steps in 6.8, both MCP versions)
  - `/animate-skin` (A: read the skin, pick effects within its rarity limit and 3.2a, edit the theme file, run tests, render with catwalk)
  - `/add-skin` gains a line on Animate, Motion and Catalog (A)
- **Integration (8.4):** `V2-CHANGES.md` (what's new, switches, undo, the API-access warning) and `PROGRESS.md`.
- Every new Config file opens with a plain-English header; every new module opens with a doc comment listing its API (like `SkinFx.luau`).

## 14. Needs testing in Studio (after integration)
1. **Effects on R15, R6 and AnimationConstraint rigs:** Flap, Wag, Spin and Breathe pieces move smoothly while walking, jumping and dancing (pieces follow the dance), and on the next respawn. No flicker back to rest (the every-frame rule).
2. **Other players' view:** a 2-player test. Same phase on both screens. Your own character always animates. Others stop beyond 120 studs. **Far-away characters under animation throttling:** pieces and walk styles stay smooth (no snapping), and walk-style Add mode doesn't jitter.
3. **Phones:** the device emulator plus a real phone with 6+ animated and CRAZY skins in view. Frame rate is fine and the phone limits hold.
4. **CRAZY + Animate:** `Pumpkin_MegaGourdSupreme` and a CRAZY draft with Animate: rainbow accents and the glow pulse look exactly as before, with no flicker.
5. **Hide & Seek:** become a hider while wearing an animated, walk-style (uploaded ids too) or catalog skin. Nothing shows, nothing sparkles, nothing moves, your own walk tracks stop. Undisguise brings everything back.
6. **Ghosts:** caught players stay see-through with effects running.
7. **Walk styles:**
   - every preset on R15 and R6
   - blending with Roblox's walk, with no build-up or jitter (checks `EvaluationThrottled` and the fallback)
   - dances still win
   - **Ghost, Bat and Bouncy inside the Tormented Tower and ScareMaze corridors:** your own character doesn't bump ceilings or get pushed around
   - uploaded ids play for everyone; a non-owned id shows the Studio warning and falls back to the normal walk
8. **Hats:** a hat on Float, Bob and Spin head pieces moves with the piece; swapping or taking off the skin never drops the hat.
9. **Catalog** (switch on, with approved ids):
   - a hat and a back item on a Part skin, with welds intact and the head piece correct
   - **`SkinMotor` pivots and pieces after `ApplyDescriptionAsync` and the re-dress** (still moving, still welded)
   - a classic shirt with `HideClothes = false`
   - taking it off restores your own avatar exactly; no duplicate BodyColors
   - respawn; a bad id; a moderated id; a slow-loading avatar (applies after it loads)
   - with `AvatarUnificationMode` / `EnableSLIMAvatars` as set in this place
10. **Skin Studio:**
    - open from Menu and from F8 (**the first F8 press opens it**); edit every control; live wear updates within half a second; respawn keeps the draft
    - **close it by accident** (Escape, the Roblox menu, M, opening the shop) and reopen: nothing lost, still wearing the draft
    - Undo/Reset; turntable; phone sheet (44 px controls, no shrinking)
    - economy lock on an existing skin
    - **`/save-skins` with the built-in Studio MCP** (playtest; `studio_id` picked from `list_roblox_studios`; several pages) and **with the older open-source MCP** (Print for Claude + `get_console_output`); Copy code reaches the clipboard; the Stop print-out appears in Output
    - if Kieran ever turns API access on: **check what it does to his live save and the leaderboard first** (13), then Save with the DataStore on and off
11. **Previews:** shop cards and crate reveals of animated skins move (PC only) **while the crate cards spin and the reveal scales them**, nothing animates once scrolled out of view, catalog thumbnails show, and closing the shop frees them.

## 15. Open questions for Kieran (sensible defaults are already in Config)
1. Should Common skins ever animate? (default: no; Uncommon 1 effect, Rare 3, CRAZY 6)
2. Catalog items: only items made by Roblox, you or your group, each id approved by you in `ApprovedIds`. OK? (default: switched off; buy buttons off)
3. Walk styles only on Rare and CRAZY skins? (default: yes)
4. Is the game owned by you or by a group? This decides who must own uploaded animations. What are your UserId and group id (for `AllowedCreators`)?
5. Keeping drafts after Stop needs Studio API access, which also makes Studio use your real save and the public leaderboard. Default: off; use `/save-skins` before Stop. Would you like a separate small change later that gives Studio its own player-data and leaderboard store, so API access becomes safe?
6. Happy with the 9 showcase skins in section 9, or pick your own?

## 16. Review decisions (8 October 2026)
The review's 25 points were all taken. In these the fix differs from what the review proposed, or one of its options was picked:

| Point | Decision | Why |
| --- | --- | --- |
| 1, 23 (two systems, duplicate names) | **Removed `Rainbow` and `Orbit` from `Animate`** instead of renaming them; kept `Pulse` with the 3.2a ownership rule. | Every CRAZY skin has `Crazy.Rainbow`, and Animate's Rainbow was CRAZY-only, so it could only ever have touched the head or body. `ColorCycle` covers colour fades for every rarity, and `Crazy.Orbit` already exists. One name per thing is easier for Kieran. |
| 7 (Studio API access) | Picked option 1: **`UseDataStore = false` by default** and `/save-skins` before Stop as the main path, plus the warning. `DataService` and `LeaderboardService` are **not** changed in this build. | Player-data code is the riskiest code in the game, it belongs to neither builder, and the other session may be editing it. A Studio-only store name is offered as a follow-up (15, question 5). |
| 8 (catalog creators) | The gate in tests and `save-skins` is the **`ApprovedIds` allow-list** in Config; the creator check happens at `LookupAsset` and is recorded server-side in the draft's `Lookups`. | The offline Lune tool can't ask Roblox who made an item, so a reviewed list in git is the only check that works there. |
| 9 (apply flow, BodyColors) | Chose **"remove duplicates"** (`restoreSkin` drops a stashed BodyColors/clothes whose class the character already has) plus the existing re-dress, not "take the skin off before applying". | Taking the Part skin off for the apply would show the bare avatar for the whole web load, which can take seconds. |
| 10 (checksums) | The checksum is over the exact stored record text, carried as `{ Sum, Text }`. | Roblox and Lune encode JSON keys in different orders, so a checksum of re-encoded JSON would never match. |
| 12 (F8 path) | Chose the player attribute `SkinStudioOpenAt` and **dropped the `SkinStudioOpen` RemoteEvent**. | Mount then needs no remote at all, and there is one remote fewer to secure. |
| 15 (previews in view) | `inView`'s maths is **copied** into `SkinAnim.PreviewVisible`, not shared out of CrateUI. | CrateUI's `inView` is a local function in a 2,860-line file; a ~10-line copy keeps A's CrateUI change to one hook line. |
| 17, 18 (sharing the branch, one source of truth) | Separate worktrees and branches; the orchestrating session integrates. `skins.spec` stays A's file except two named `it` blocks that B rewrites in B4 to call `SkinSchema`. | Keeps one copy of the rules without both builders editing the same lines. |
| 20 (economy fields) | **Price and CrateOnly are locked too**, not only Rarity and Crate. | They change what players paid for and what crates contain in the same way. |
| 4 (throttling) | `Animator.EvaluationThrottled` is used when readable; the CFrame-equality guess stays only as the fallback. | The harness's API list (and possibly older clients) don't have the property. |
| 6 (DraftId) | `HttpService:GenerateGUID(false)`; `Updated` is in milliseconds. | Avoids collisions between Team Create servers and ties within one second. |
| 6 (page size) | `MaxDraftBytes` lowered from 16,000 to 10,000, and `Save` checks that the escaped record fits one export page. | So one draft always fits in one 20,000-character export page, and 200 drafts stay far under 4 MB. |
