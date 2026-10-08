# Skin Studio, animated skins, walk styles and catalog items: build spec

Written 8 October 2026 on branch `claude/clever-clarke-3zqgma` (base `1765a6d`) from Kieran's request: *"can you give me a way of changing and animating the skins in the game"*. This is the contract two builders follow so their work fits together. Builder A makes the animation system and catalog items. Builder B makes the Skin Studio editor and saving. The plain-English version for Kieran goes in `docs/CUSTOMIZE.md` (section 13).

## 0. In plain English (for Kieran)
- **Skins can move.** Wings flap, tails wag, capes sway, head pieces spin, bob or float. Colours cycle, glows flicker and sparkles burst. You write this in a skin's `Style` (`Animate = { ... }`) or pick it in Skin Studio. Everyone in the server sees it.
- **Walk styles.** A skin can make you walk like a zombie, float like a ghost, march like a robot or flap like a bat (`Motion = "Zombie"`). You can also use your own uploaded walk, run and idle animations.
- **Your own animated models.** Build a model in Studio and put it in `ReplicatedStorage > Custom > Cosmetics`, named after the skin. Give any part the attribute `Animate = "Spin"` and that part spins. Spin, Bob, Wobble and the other effects work the same way.
- **Real Roblox catalog items.** A skin can add catalog hats, hair, back items and classic shirts or pants. This is off until you've tried it in Studio, because Roblox loads these items from the web and they can fail (section 5).
- **Skin Studio.** Start a Studio playtest and open Menu > Skin Studio (or F8 > Skin Studio). Pick any skin or make a new one, then change everything with colour pickers, sliders and dropdowns. You see it on your own character straight away, animations included. Press Save, then type `/save-skins` in Claude Code. Claude Code writes your skins into the game files and runs the tests. The "Copy code" button always works as a backup.

## 1. Scope
**In scope:**
- `Style.Animate`: a list of effects on skin pieces, the glow, the aura and body colours.
- Animated parts inside custom models.
- `Style.Motion`: walk styles, made in code or from uploaded animation ids.
- `Style.Catalog`: rigid catalog accessories, classic clothes and a classic face.
- Skin Studio: an editor for admins in Studio, with saving to the repo.
- Tests, docs and Config for all of the above.

**Not in scope:**
- Players designing their own skins in live games. Player data is unchanged: no new saved fields, no `Config.Data.Template` change.
- Bundles, body parts, body scales, layered clothing and catalog animation packs inside skins (section 5.1 says why).
- Editing hats, pets or trails in Skin Studio. This could come later, and the schema module is written so it can grow.

## 2. Key decisions
| # | Decision | Why |
| --- | --- | --- |
| D1 | **Replicate state, not motion.** The server only puts the skin on and sets tags or attributes once. Every client animates every visible character itself. | This is the pattern Dances and SkinFx already use. It adds no network traffic per frame, and `Motor6D.Transform` doesn't replicate anyway. |
| D2 | **Moving pieces hang on Motor6D "pivots" that the server builds.** A moving group (head piece, each wing, tail, cape, a named or custom part) is welded to one invisible `AnimPivot` part. That part is joined to the body by a `Motor6D` named `SkinMotor`. Clients write `SkinMotor.Transform` in `PreSimulation`. | Transform writes are batched by Roblox and are the cheapest way to move welded parts. One write moves a whole group. Pieces follow dances and walk animations for free. |
| D3 | **Effects never write `Transparency` or `Enabled`.** They only change `Color`, light `Brightness`/`Color` and `Transform`, and call `ParticleEmitter:Emit()`, and only on an emitter that is `Enabled`. | The Hide & Seek disguise (Transparency 1, emitters and lights off) and ghost transparency can never be undone by an effect, so no hider is ever revealed. |
| D4 | **Last-written guard.** When an effect stops, it restores a property only if the property still holds the value the effect last wrote. | If the server changed the property meanwhile (TakeOff restored colours, or a new skin was put on), the effect must not paint the old colour back. |
| D5 | **Shared clock.** Effects use `Workspace:GetServerTimeNow()` as `t`. | Every screen shows the same wing beat at the same moment. Flicker uses a hash of the time step, not `math.random`. |
| D6 | **Walk styles:** code presets are an attribute that every client poses (like Dances). Uploaded animation ids play as tracks on the wearer's own client, which Roblox replicates. | No editing of the Animate script. Restoring is just "stop the tracks". The approach works on R15 and R6 (code presets) and can be tested offline. |
| D7 | **Catalog items:** only rigid accessories, classic Shirt/Pants/T-shirt and a classic Face. The server applies them as a HumanoidDescription *diff*, so body parts never change. The feature is off by default. Previews use thumbnails. | `ApplyDescriptionAsync` is server-only, yields, can fail, and fights Part-built cosmetics if body parts change. The Part skin stays the fallback (section 5). |
| D8 | **Skin Studio saves drafts on the server.** Drafts live in memory, in a `ServerStorage` mirror, and in an optional DataStore. Three ways reach the repo: Studio MCP plus `/save-skins` (main), a Lune tool that edits theme files, and "Copy code" (always works). | Playtest changes vanish on Stop, and game scripts can't edit `Source`. The MCP can read the Server DataModel during play. |
| D9 | **A draft is worn under a reserved id**, `StudioDraft_<DraftId>`, with `ModelId = <real Id>`. | Effects must come from the draft, not the old catalogue entry with the same Id. A custom model still has to be found under its real Id. |
| D10 | **One schema module (`SkinSchema`) drives everything in the editor:** its controls, server validation, JSON encoding and the Luau export. | A new Style key then shows up in the editor, gets validated and exports correctly in one place. |

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
| `Count` | number (integer) | SparkleBurst 1–50, Orbit 1–8 | particles per burst / orbiting pieces |
| `Kind` | string | `HeadPieces.OrbitKinds` | Orbit only (Pumpkins, Candies, Ghosts, Bones, Eyes, Stars, Bats) |
| `OrbitColor` | Color3 | optional | Orbit only: tints the pieces |

A key that isn't listed for that effect is an **error**, as are a wrong type and an out-of-range number. That keeps typos out of the catalogue and the remote.

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
| `Rainbow` | Colour | Accents | Glow, Head, Accents, a pattern, Body, Part, All | hue = `(t · Speed / p.Seconds + index · p.Spread) % 1`. Colour = `base:Lerp(fromHSV(hue, 0.7, 1), min(Amount, 1))` | `Seconds = 3, Spread = 0.11` |
| `ColorCycle` | Colour | Accents | same as Rainbow | fades through `Colors` in order, `p.SecondsPerColor / Speed` each, lerping smoothly | `SecondsPerColor = 1` |
| `Flicker` | Light / Colour | Glow | same as Pulse | candle flicker: in each step of `Every / Speed` s, `hash(step, seed) < p.Chance` dims to `p.Low` (light) or lerps toward black by `(1 - p.Low) · min(Amount, 1)` (parts) | `Every = 0.08, Low = 0.3, Chance = 0.35` |
| `Shimmer` | Colour | Accents | Head, Accents, a pattern, Body, Part, All | a bright band sweeps upward: part at height fraction `h`, band at `b = frac(t · Speed / p.Seconds)`, strength = `max(0, 1 - abs(h - b) / p.Width) · p.Strength · min(Amount, 1)` → `base:Lerp(white, strength)` | `Seconds = 2, Width = 0.25, Strength = 0.6` |
| `SparkleBurst` | Particles | Aura | Aura | every `Every / Speed` s: `emitter:Emit(round(Count · Amount))`, only if `emitter.Enabled` | `Every = 3, Count = 20, MaxCount = 50` |
| `Orbit` | Pieces | (Body) | none (Target is set to `"Body"`) | `Count` pieces of `Kind` circle you, exactly like `Crazy.Orbit` (`HeadPieces.Orbit`, client-only copies in `Workspace.LocalSkinFx`). Lap time = `Skins.Effects.OrbitSeconds / Speed` | `Count = 3, MaxCount = 8` (radius, height, bob and scale come from `Config.Skins.Effects`) |

- `seed` is the wearer's `UserId`, or 0 for previews.
- `side` is the pivot's `AnimSide` attribute (-1 for the left wing, 1 for the right).
- For parts, `index` is the part's position in the target list, sorted by name and then height so every screen agrees.

### 3.3 Targets
| Target | Means | Motion? | Colour? |
| --- | --- | --- | --- |
| `"Head"` | the head piece, Part-built or the custom model | yes (one pivot at the head centre) | yes |
| `"Wings"`, `"Tail"`, `"Cape"` | that accent pattern's pieces (`Cosmetics.MovingPatterns`) | yes (Wings = two mirrored pivots) | yes |
| any other pattern name (`"Belt"`, `"Stripes"`...) | that pattern's pieces (`Cosmetics.PatternParts[name]`) | no | yes |
| `"Accents"` | every accent piece | no | yes |
| `"All"` | head piece + every accent piece | no | yes |
| `"Body"` | the avatar's body parts (`Cosmetics.BodyParts(character)`, never HumanoidRootPart) | no | yes |
| `"Glow"` | the `SkinGlow` light | no | Pulse, Flicker, Rainbow, ColorCycle (light Brightness/Color) |
| `"Aura"` | the `SkinAura` emitter | no | SparkleBurst only |
| `"Part:<Name>"` | every BasePart named `<Name>`, or one Model named `<Name>`, inside the skin's model: head-piece bits (`"Part:Eye"`, `"Part:Flame"`) or custom-model parts | yes (one pivot for the group) | yes |

- A target that the skin doesn't have is a **warning**, not an error. For example, `Wings` on a skin with no Wings pattern, or `Glow` with no `Style.Glow`. The effect just does nothing.
- `SkinAnimate.TargetsIn(style, partNames?)` lists the targets a style really has, for the editor's dropdown.

### 3.4 Server build (changes in `src/shared/Cosmetics.luau`, builder A)
1. **Feature switch.** When `Config.Features.SkinAnimations` is false, nothing below happens: skins are built exactly as today.
2. **Normalize.** `wearSkin` calls `SkinAnimate.Normalize(style.Animate, style)`. Bad entries are dropped **silently**, because Wear must never warn (`noWarnings`). Catalogue skins are checked by tests, and Studio drafts by `SkinStudioService`.
3. **Groups.** Pivots are built only for groups that a motion effect targets, or that a custom-model part marks with an `Animate` attribute (3.5). A skin with no motion effect builds the **same parts and joints as today**.
   - **Pivot part:** `Name = "AnimPivot"`, `Size = 0.2³`, `Transparency = 1`, `Massless`, `CanCollide`/`CanTouch`/`CanQuery = false`, `CastShadow = false`, unanchored. It is a child of the `Cosmetic_Skin` model and carries:
     - attribute `AnimGroup` (`"Head"`, `"WingL"`, `"WingR"`, `"Tail"`, `"Cape"`, `"Part:<Name>"`)
     - attribute `AnimSide` (-1 or 1, wings only)
     - a child `Motor6D` named `SkinMotor`, with `Part0` = the body part the pieces would otherwise weld to (or the parent group's pivot, for a `Part:` group inside the head piece), `Part1` = the pivot, `C0` = the pivot's offset in `Part0` space and `C1 = identity`
   - **Members:** each member piece gets a `WeldConstraint` with `Part0 = pivot` instead of the body part.
   - **Where each pivot goes:**

     | Group | `Part0` | `C0` (offset in `Part0` space) |
     | --- | --- | --- |
     | Head | `Head` | identity |
     | WingL / WingR | chest (`UpperTorso` or `Torso`) | `CFrame.new(side·0.3, top.Size.Y·0.3, top.Size.Z/2 + 0.12) · Angles(0, rad(side·-20), 0)` (the same wing root `patterns.Wings` uses) |
     | Tail | `LowerTorso` or `Torso` | `CFrame.new(0, -base.Size.Y/2 + 0.15, base.Size.Z/2 + 0.12)` |
     | Cape | chest | `CFrame.new(0, top.Size.Y/2 - 0.05, top.Size.Z/2 + 0.06)` |
     | `Part:<Name>` | what the parts would weld to | centre of the named parts' bounding box, or the Model's `GetPivot()` |

     Implementation hint: give `Dress` a `Group(name, on, offset)` helper that the Wings, Tail and Cape patterns call before adding their pieces. `add()` then welds to `ctx.CurrentGroup` when there is one.
   - **Limit:** at most `Config.SkinAnimate.MaxPivots` pivots. Extra groups stay welded and don't move.
4. **Tag.** If the normalized list isn't empty, or custom animated parts exist, tag the model `Tags.SkinAnim` (`"SkinAnim"`, new in `Tags.luau`). `hasExtras` also returns true when `style.Animate` is set. `Motion` needs no model, because it lives in character attributes.
5. **LiveStyle.** When `Items.Get(item.Id) == nil` (a Studio draft), set the attribute `LiveStyle = SkinAnimate.EncodeLive(style)` on the `Cosmetic_Skin` model. It is JSON holding `Crazy` and `Animate`, with colours as `"#RRGGBB"`, at most 4,000 characters. Clients read styles with `SkinAnimate.StyleOf(model)`: the catalogue first, then `LiveStyle`.
6. **ModelId.** `Cosmetics.Build`, `wearSkin` and `skinPreview` look custom models up by `item.ModelId or item.Id`.
7. **Walk styles** (section 4) are set here too, as character attributes, and cleared in `restoreSkin`.
8. **Catalog hooks** (section 5):
   - `headAccessories` skips accessories with the attribute `SkinCatalog = true`.
   - `Cosmetics.OnSkinChanged(fn) -> disconnect` is a server-only listener list, fired with `(character, item?)`. Each listener runs in `pcall`. It fires once:
     - at the end of `Wear` for the Skin slot, with the item
     - at the end of a `TakeOff(character, "Skin")` **called directly**, with nil (not the TakeOff that `Wear` runs first)
9. **New public helpers:**
   - `Cosmetics.MovingPatterns = { "Wings", "Tail", "Cape" }`
   - `Cosmetics.PatternParts: { [pattern]: { partName } }`
   - `Cosmetics.BodyParts(character) -> { BasePart }`
10. **Previews** (`skinPreview`, `Weld = false`):
    - Each group becomes a sub-Model named `AnimGroup` (attributes `AnimGroup`/`AnimSide`, `PrimaryPart` = an anchored `AnimPivot`).
    - The preview model gets `ItemId = item.Id`, plus `LiveStyle` for a draft.
11. **TakeOff** keeps working unchanged: pivots and motors live in `Cosmetic_Skin` and are destroyed with it.

### 3.5 Animated parts in custom models (Kieran's Studio workflow)
A part, or a Model grouping several parts, anywhere inside `ReplicatedStorage.Custom.Cosmetics.<SkinId>` can carry these attributes. They are set in Studio: Properties > Attributes > +.

| Attribute | Type | Same as |
| --- | --- | --- |
| `Animate` | string | `Effect` (Spin, Bob, Float, Wobble, Flap, Wag, Breathe, Pulse, Rainbow, ColorCycle, Flicker, Shimmer) |
| `Speed`, `Amount`, `Delay`, `Every` | number | the same keys as 3.1 |
| `Axis` | string | `Axis` |
| `Reverse` | boolean | `Reverse` |
| `Color2` | Color3 | ColorCycle between the part's own colour and `Color2` (an attribute can't hold a list) |

- **Grouping and pivots:**
  - A Model with `Animate` moves as one group and turns round its pivot. Kieran sets the pivot with Studio's Pivot tool.
  - A Part with `Animate` turns round its own centre.
  - The server builds one pivot per marked Part or Model. It copies the attributes onto the `AnimPivot` (`AnimGroup = "Custom:<n>"`) so clients read them there.
  - The rest of the model is welded to the head as today.
- **Validation:** values go through `SkinAnimate.Normalize`. Bad values are ignored, and only Skin Studio (6.9) shows a warning.
- **Limits:**
  - These effects don't count toward rarity limits (it's Kieran's own model).
  - They do count toward `MaxPivots` and the 120-part budget.
  - Scripts are still stripped, so attributes are the only way to animate a custom model.

### 3.6 Client runtime: `src/client/SkinAnim.luau` (builder A)
```
SkinAnim.Mount(gui)                    -- starts watching Tags.SkinAnim (nothing when Features.SkinAnimations is off)
SkinAnim.AnimatePreview(model) -> stop -- ViewportFrame previews; SkinFx.AnimatePreview calls it
SkinAnim.Active() -> number            -- characters animating right now (tests, perf)
```
It follows `SkinFx`'s pattern: entry per tagged model, `pick()` every `CheckSeconds`, activate/step/deactivate, and no frame connection while there are no entries and no previews.

1. **Entry.** On a tagged model:
   - Resolve the effects: `SkinAnimate.StyleOf(model).Animate`, normalized, plus the `AnimPivot`s carrying custom attributes.
   - Resolve the targets: pivots by `AnimGroup`; parts by name (`PatternParts`); the head piece = parts welded to `Head` or to the `Head` pivot (plus `Part:` groups nested in it); `Body` = `Cosmetics.BodyParts(character)`.
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
   - Store base colours, base brightness, and each part's height fraction (for Shimmer).
   - Build Orbit pieces into `Workspace.LocalSkinFx`.
   - Cap each colour effect at `MaxColorParts` parts.
5. **Step** (`RunService.PreSimulation`, the same event as Dances):
   - `t = Workspace:GetServerTimeNow()`.
   - Motion: `motor.Transform = SkinAnimate.Offset(effect, t, side)`. Several motion effects on one pivot multiply in list order.
   - Colour: `part.Color = SkinAnimate.Tint(...)`. Several colour effects on one part: the last in the list wins.
   - Light: `light.Brightness = SkinAnimate.Brightness(...)`.
   - Burst: `if SkinAnimate.BurstDue(effect, last, t) and emitter.Enabled then emitter:Emit(n) end`.
   - Remember every value written (`written[instance][property]`).
   - Characters off screen (`Camera:WorldToViewportPoint`), except your own, get no motion or colour writes. Characters beyond `HalfRateDistance` update every second frame.
6. **Deactivate:**
   - `motor.Transform = identity` if the motor still exists.
   - Colours and brightness are restored **only where the current value equals `written`** (D4).
   - Destroy the orbit pieces.
7. **Never** write `Transparency`, `LocalTransparencyModifier` or `Enabled`, and never create Highlights or lights.

### 3.7 Previews (shop, crates, Skin Studio)
- `SkinFx.AnimatePreview(model)` also calls `SkinAnim.AnimatePreview(model)` and returns one stop function that stops both. This change is in `SkinFx.luau` (A).
- The preview animates only while its ViewportFrame is shown (the existing `guiShown`).
  - Colour effects run on preview parts.
  - Motion runs as `AnimGroup:PivotTo(rest · offset)`, on at most `MaxPreviewMotion` previews at once, and never on phones (`PreviewMotionOnPhones = false`).
  - Pulse/Flicker on a preview's `GlowHalo` may change its Transparency, because a preview is never a character.
- **ShopUI hook (A):** call `SkinFx.AnimatePreview(model)` for every skin card, not only CRAZY ones. It is a no-op for still skins. CrateUI already calls it for every preview.
- Phones keep the existing rule: no spinning shop previews.

### 3.8 Rarity rules (Config-driven, enforced by `skins.spec`)
`Config.SkinAnimate.Rarity`:
```lua
Rarity = {
	Common = { Effects = 0, Motion = false },
	Uncommon = { Effects = 1, Motion = false },
	Rare = { Effects = 3, Motion = true },
	Crazy = { Effects = 6, Motion = true },
},
CrazyOnly = { "Orbit", "Rainbow" }, -- the CRAZY hallmarks stay CRAZY
```
Catalog items aren't limited by rarity (open question 2).

### 3.9 `Config.SkinAnimate` (`src/shared/Config/SkinAnimate.luau`, builder A)
```lua
return {
	MaxCharacters = 8, -- characters whose skin pieces animate at once (the closest; you first)
	PhoneMaxCharacters = 4,
	MaxDistance = 120, -- studs from the camera
	HalfRateDistance = 60, -- further than this: updated every second frame
	CheckSeconds = 0.5, -- how often the closest ones are picked again
	MaxEffects = 6, -- effects in one skin's Animate list (rarity limits below are lower)
	MaxPivots = 6, -- moving groups in one skin
	MaxColorParts = 40, -- parts one colour effect changes
	MaxPreviewMotion = 4, -- shop/crate/studio previews whose pieces move at once
	PreviewMotionOnPhones = false,
	Rarity = { ... }, CrazyOnly = { ... }, -- 3.8
	Presets = { Spin = { Seconds = 4 }, Bob = { ... }, ... }, -- 3.2, every preset listed
}
```
It is required in `Config/init.luau` as `SkinAnimate = require(script.SkinAnimate)`. It starts with a plain-English header like every Config file.

### 3.10 Shared module `src/shared/SkinAnimate.luau` (builder A; pure, client + server)
```
export type Effect = { Effect: string, Target: string, Speed: number, Amount: number, Delay: number,
	Axis: string?, Reverse: boolean?, Colors: { Color3 }?, Every: number?, Count: number?,
	Kind: string?, OrbitColor: Color3? }
export type ParamInfo = { Key: string, Label: string, Help: string,
	Type: "number" | "boolean" | "Axis" | "Colors" | "OrbitKind" | "Color",
	Min: number?, Max: number?, Step: number?, Default: any }
export type EffectInfo = { Name: string, Label: string, Help: string,
	Kind: "Motion" | "Colour" | "Light" | "Particles" | "Pieces",
	Targets: { string }, DefaultTarget: string, Params: { ParamInfo } }

SkinAnimate.Effects: { EffectInfo }                 -- ordered, for the editor (labels + help in plain English)
SkinAnimate.Has(name) -> boolean
SkinAnimate.Normalize(list: any, style: any?) -> ({ Effect }?, { string } errors, { string } warnings)
SkinAnimate.TargetsIn(style, partNames: { string }?) -> { string }
SkinAnimate.PartNames(model: Model) -> { string }   -- unique BasePart/Model names in a built skin (editor)
SkinAnimate.Offset(effect, t, side: number?) -> CFrame
SkinAnimate.Tint(effect, base: Color3, t, index: number, height: number, seed: number) -> Color3
SkinAnimate.Brightness(effect, base: number, t, seed: number) -> number
SkinAnimate.BurstDue(effect, lastT: number, t: number) -> boolean
SkinAnimate.EncodeLive(style) -> string?            -- { Crazy, Animate } as JSON, nil if neither
SkinAnimate.DecodeLive(text: any) -> { Crazy: any?, Animate: { Effect }? }
SkinAnimate.StyleOf(model: Instance) -> any?        -- catalogue item's Style by ItemId, else DecodeLive(LiveStyle)
SkinAnimate.RarityProblems(item) -> { string }      -- 3.8 rules, used by skins.spec and Skin Studio
```

### 3.11 SkinFx changes (builder A)
- `onTagged`: when `Items.Get(ItemId)` is nil, use `SkinAnimate.StyleOf(model).Crazy`. Drafts' CRAZY effects then work in Skin Studio.
- `AnimatePreview` also calls `SkinAnim.AnimatePreview` (3.7).
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
  - The editor and the docs say this, and the client warns in Studio when a track doesn't load (4.4).
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
    - Skip a character that is: off screen; dancing (`Dance` attribute set: the dance wins); a hider; dead; `Humanoid.Sit`; or swimming or climbing (`Humanoid:GetState()`).
  - **Pose:** `move = clamp(horizontal root velocity / Humanoid.WalkSpeed, 0, 1)` (velocity replicates; `MoveDirection` doesn't for other players). Then `pose = SkinMotion.Pose(name, t, move)`, faded in and out over `FadeSeconds`.
  - **Pose type:** `{ [jointName]: { Mode: "Set" | "Add", Turn: CFrame } }`, using DanceMoves joint names and body directions. `Root` may also shift.
  - **Set mode** writes the converted turn (the same conversion as `DanceMoves.Apply`: `c0Rot:Inverse() * turn * c0Rot`). It replaces the walk animation for that joint, e.g. Zombie arms.
  - **Add mode** layers on top of Roblox's walk animation, using **base tracking**:
    1. Read `cur = joint.Transform`.
    2. If `cur == written[joint]` (the Animator didn't write this frame), then `base = lastBase[joint]`; otherwise `base = cur`.
    3. Write `base * add` and remember `written` and `lastBase`.

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
  - **Stopping:** stop and destroy all of them when the attribute clears, the character changes, or you start a dance.
  - **Load check:** after `LoadCheckSeconds`, a track with `Length == 0` counts as not loaded. It is skipped, and in Studio there is one `warn`: `[SkinWalk] animation 123 didn't load: is it owned by the game's owner?`.

### 4.4 `Config.SkinMotion` (`src/shared/Config/SkinMotion.luau`, builder A)
```lua
return {
	MaxCharacters = 12, PhoneMaxCharacters = 6, MaxDistance = 100, CheckSeconds = 0.5,
	FadeSeconds = 0.25, -- blend in and out
	AllowUploaded = true, -- false = only the code presets (uploaded ids are ignored)
	WalkThreshold = 0.5, RunSpeed = 20, -- studs/s
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
- It assumes nothing else edits the character.
- Body-part ids replace the body MeshParts, which **breaks every Part-skin weld**. Scales leave weld offsets wrong.

**So we take the safe subset:**
| Allowed | Excluded, and why |
| --- | --- |
| Rigid accessories: Hat, Hair, Face, Neck, Shoulder, Front, Back, Waist (`Enum.AccessoryType`) | **Bundles and body parts**: replace body MeshParts and heads, which breaks welds and head pieces; R15 only |
| Classic `Shirt`, `Pants`, `TShirt` (graphic) | **Scales / proportions**: weld offsets go wrong; no effect on R6 |
| Classic `Face` (only on a skin without a head piece) | **Layered clothing**: R15 only, clips through Part skins, ignores HideClothes |
|  | **Animation packs**: use `Style.Motion` instead (custom ids don't apply through descriptions anyway) |

- **How it's applied:** as a *diff* on the player's own applied description. Body parts, colours and scales stay identical, so the Part skin keeps its welds.
- **Fallback:** the Part-built skin is always there. If loading fails, players simply see the skin without the catalog bits.
- **Default:** `Config.Features.SkinCatalog = false` until Kieran tests it in Studio and decides on policy (5.6).

### 5.2 Schema
```lua
Catalog = {
	Accessories = { { Id = 1234567890, Type = "Hat" }, { Id = 2345678901, Type = "Back" } }, -- up to MaxAccessories
	Shirt = 3456789012, Pants = 4567890123, TShirt = 5678901234, -- classic clothes (the skin needs HideClothes = false)
	Face = 6789012345, -- classic face (only when the skin has no Head piece)
}
```
- Ids are positive integers below 2^53.
- `Type` is one of `SkinCatalog.Types`.
- Skin Studio fills `Type` in by looking the id up in Studio (6.6, `LookupAsset`), so live servers never make that web call.
- **Errors:** too many accessories, a duplicate id, an unknown `Type`, layered types.
- **Warnings:**
  - Shirt/Pants/TShirt while `HideClothes ~= false`: the skin would hide them.
  - `Face` with a `Head`.
  - Head-slot accessories (Hat, Hair, Face) with a `Head` piece: the head piece hides head accessories, except ours. Catalog accessories are marked `SkinCatalog` and are **not** hidden, so a catalog hat sits on the head itself (Studio test item).

### 5.3 Server: `src/server/Services/SkinCatalogService.luau` (builder A)
```
SkinCatalogService.Start()                 -- returns early when Features.SkinCatalog is off
SkinCatalogService.Status(character) -> string?   -- "Loading", "On", "Failed: <reason>", nil
```
Flow (at most one worker per character; the newest skin wins):
1. **Trigger.** `Cosmetics.OnSkinChanged(character, item?)` records `wanted[character] = SkinCatalog.Key(item and item.Style.Catalog)` (a stable string, `""` = none) and the matching catalog table. If no worker is running for that character, it starts one with `task.defer`. A burst of changes (`Dress` putting several slots on) collapses into one apply.
2. **Worker loop.** The worker loops while `wanted[character] ~= applied[character]`. It reads `wanted` again after every yield and stops when they match.
   - It waits until `SecondsBetweenApplies` have passed since the last apply for this player.
   - Abort if the player is a Hide & Seek hider, the character isn't `player.Character`, or the humanoid is dead.
3. **Snapshot.** Take a snapshot once per character, before our first apply: `base[character] = humanoid:GetAppliedDescription()`. This is the player's own avatar with Avatar Settings applied, and needs no web call.
4. **Build the description.** `desc = base:Clone()`, then:
   - `desc:SetAccessories(own ∪ ours, true)`, where `own = base:GetAccessories(true)`, skipping ids already there
   - set `Shirt`, `Pants`, `GraphicTShirt` and `Face` where given

   Removing catalog items means applying `base` itself.
5. **Apply.** Remember the accessories present, then call `pcall(humanoid.ApplyDescriptionAsync, humanoid, desc, Enum.AssetTypeVerification.Always)`.
6. **After the yield:**
   - If the character is gone, stop.
   - If the player became a hider, re-apply `base` (pcall) and stop.
   - If `wanted` changed meanwhile, loop and apply the newer one.
7. **Finish:**
   - Mark new accessories `SkinCatalog = true`.
   - Set `applied[character]` to the key just applied.
   - Set the character attribute `SkinCatalogStatus` (`"On"`, or `"Failed: <short reason>"`).
   - Then **re-dress** with `ShopService.Dress(player)`. Dress fires `OnSkinChanged` again with the same key, so nothing new happens. This puts the Part skin back over anything the apply reset (BodyColors, clothing stash).
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
	Types = { "Hat", "Hair", "Face", "Neck", "Shoulder", "Front", "Back", "Waist" },
	SecondsBetweenApplies = 2, -- per player; the newest skin always wins
	ShowThumbnails = true, ShowBuyButtons = false, ThumbnailSize = 150,
}
```
`Config.Features.SkinCatalog = false`.

### 5.6 Policy note (goes in the docs)
- Giving away other creators' catalog items inside crate skins may conflict with Roblox's Marketplace rules. A 2023 "visible buy option" policy was paused; its status is unverified [L].
- **Safest:** Roblox-made items or Kieran's own. Skin Studio shows the creator and a "Roblox-made" tick when it looks an id up.
- `ShowBuyButtons = true` gives players a way to buy the real item, and earns Kieran a commission.

### 5.7 Shared module `src/shared/SkinCatalog.luau` (builder A; pure)
```
SkinCatalog.Types: { string }
SkinCatalog.Normalize(value: any, style: any?) -> (Catalog?, { string } errors, { string } warnings)
SkinCatalog.Key(catalog: any) -> string             -- "" for none; sorted, stable
SkinCatalog.TypeFromAssetType(assetTypeName: string) -> string?  -- "Hat"->"Hat", "HairAccessory"->"Hair", "Shirt"->"Shirt", "Face"->"ClassicFace"...
```
Map through `Enum.AssetType` item names, never hard-coded numbers: find the item whose `.Value == AssetTypeId`.

---

## 6. Part 3: Skin Studio (builder B)

### 6.1 Who and where
**Allowed** means all of:
- `Config.Features.SkinStudio`
- the player attribute `Admin == true` (set by AdminService)
- `RunService:IsStudio()` or `Config.SkinStudio.AllowInLiveServers`

`SkinStudioService.Allowed(player)` checks this on the server for **every** action. The client checks the same things, but only to decide whether to show the tile.

**Entry points:**
- **Menu tile:**
  - a `Config.Menu.Tiles` line `{ Id = "SkinStudio", Text = "Skin Studio", Icon = "🎨", Color = Color3.fromRGB(90, 60, 150), Feature = "SkinStudio" }`
  - `MenuUI.AddTile({ Id = "SkinStudio", Label = "Skin Studio", Order = 95, Visible = allowed, OnClick = SkinStudioUI.Open })`
- **F8 button:** `AdminService.Register("SkinStudio", "Skin Studio", fn)`. The server checks `Allowed` and fires the `SkinStudioOpen` RemoteEvent to that player, then returns `"Skin Studio opened."` (or why not).

### 6.2 Screen layout
The panel **docks to the right edge** so your real character stays visible on the left (it is not centred).
- `Theme.panel(gui)`, named `SkinStudio`, `Layout.Fit(panel)`, `PanelManager.Register(panel)`.
- On a PC it is `Config.SkinStudio.Panel.Width` (440) wide and full height minus the top bar.

```
┌───────────── Skin Studio ─────────────[✕]┐
│ [ preview viewport (turns) ]  Name  ★Rare │  header: small turntable preview + badges
│ Wearing: Moon Moth (draft)  [Wear on me ✓] │
├─[Skins]─[Look]─[Animate]─[Catalog]─[Save]──┤  tabs
│ (tab content, scrolls)                     │
├────────────────────────────────────────────┤
│ [↶ Undo] [↷ Redo] [Reset] [🎥 Turntable]   │  footer, always visible
│ status line (green ok / yellow warning)    │
└────────────────────────────────────────────┘
```
- **Phone** (`Layout.IsPhone()`, checked in Studio's device emulator):
  - a bottom sheet, full width and `PhoneHeightScale` (0.55) of the screen high
  - the same tabs; the header preview is hidden (your real character is above the sheet)
  - every control at least 44 px tall; slider buttons step by ±1 and ±10
- **Tabs:**

  | Tab | Contents |
  | --- | --- |
  | Skins | search box; Theme dropdown (All, 30 themes, Classic, Tower); rarity chips; "Drafts" and "Animated" toggles; a paged list (`ListPageSize`, `PhoneListPageSize`); buttons **New**, **Duplicate** |
  | Look | Basics (Name, Id, Theme, Rarity, Crate, Price, CrateOnly); Body; Head; Accent; Glow & particles; CRAZY |
  | Animate | the effect list editor (6.3) and Walk style |
  | Catalog | ids with Look up, thumbnails, and a notice when the feature is off |
  | Save | drafts list, Save, Delete, Copy code, Print, saving instructions and status |

  - **List rows:** a rarity dot, Name, Id (small), theme, and icons: 🎞 Animate, 🚶 Motion, 🛍 Catalog, ✎ draft, ✓ "in game files". Rows are text only; only the selected skin gets a 3D preview.
- **Opening and closing:**
  - Opening the panel never changes what you wear until you edit something, or tick **Wear on me** (default on in Studio).
  - Closing it stops wearing the draft (`StopWearing`) unless **Keep wearing after closing** is ticked.

### 6.3 Controls (`src/client/SkinStudioControls.luau`)
Each control is built from `SkinSchema.Fields` metadata (6.9), so a new Style key gets a control without UI work.

| Control | Used for | Behaviour |
| --- | --- | --- |
| Colour | every Color3 key | swatch → popover with the `Config.SkinStudio.Palette` grid (24 swatches), R/G/B sliders 0–255 with number boxes, a hex box, **Clear** (unset an optional key) |
| Material | Material keys | dropdown of `Config.SkinStudio.Materials` (a friendly list; the server accepts any `Enum.Material`) |
| Choice | Head, Face, Aura.Kind, Crazy.Orbit, Crazy.Effect, Theme, Rarity, Effect, Target, Axis, Motion, Catalog Type | dropdown. Head shows CRAZY heads with ⭐ and warns when another skin already uses one |
| Patterns | Accent.Pattern | chips; tap to add or remove, in order |
| Toggle | HideClothes, Crazy.Rainbow, Crazy.Pulse, CrateOnly, Reverse | on/off pill |
| Number | Transparency (0–0.9), Glow.Brightness (0–10), Glow.Range (0–60), Crazy.Count (1–8), Price, effect numbers | slider + box with min/max/step from metadata; dragging is one Undo step |
| Text | Name (1–40), Id (new skins only), Note | TextBox; Id auto-fills `<Theme>_<NameWithoutSpaces>` until edited by hand |
| Effect list | `Animate` | rows: Effect, Target (only `SkinAnimate.TargetsIn`), Speed, Amount, then the effect's `Params`; ✕ ▲ ▼ per row; **+ Add animation** (greyed at the rarity/`MaxEffects` limit with the reason) |
| Walk style | `Motion` | dropdown None + `SkinMotion.Info`; "Use my own animations" expander with Walk, Run and Idle id boxes and the ownership note |
| Catalog list | `Catalog` | id box + **Look up** (fills Type, shows name, creator, Roblox-made tick and thumbnail via `CatalogBadge`); Shirt, Pants, TShirt and Face boxes |

**Help text.** Every control has a `?` that shows its plain-English `Help` from the metadata, e.g. *"Glow: a light around you. Rare and up."* A warning line under a section shows that section's `SkinSchema.Check` warnings.

### 6.4 Drafts, live wearing and the turntable
```
type DraftRecord = {
	DraftId: string,   -- made by the server: "D<os.time()>_<counter>"
	Source: string?,   -- the catalogue Id this draft edits (nil = a new skin)
	Item: EncodedItem, -- { Id, Name, Rarity, Theme?, Crate?, Price?, CrateOnly?, OneInAMillion?, Odds?, Style }
	Updated: number,   -- os.time()
	Author: number,    -- UserId
	Note: string?,     -- up to 120 characters
}
```
- **Selecting a catalogue skin** makes an unsaved working draft (`Source = Id`):
  - Its **Id and Theme are locked**, because Ids never change.
  - `OneInAMillion`/`Odds` are shown read-only and carried over unchanged.
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
History is capped at `UndoSteps`. Undo, Redo and Reset each schedule a Wear like any change.

### 6.6 Server: `src/server/Services/SkinStudioService.luau`
`Start()` creates the remotes **first**, before any feature check:
- `Remotes.Function("SkinStudio")`
- `Remotes.Event("SkinStudioOpen")`

It then registers the F8 command and returns early when the feature is off. Every handler wraps its work in `pcall` and returns a `Reply`; it never errors back to the client.

`SkinStudio:InvokeServer(action: string, payload: any) -> { Ok: boolean, Message: string, Data: any? }`

| Action | Payload | Data | Checks (besides `Allowed`) |
| --- | --- | --- | --- |
| `"Hello"` | — | `{ DataStore = "On" \| "Off" \| "Failed", Drafts = { DraftRecord }, Wearing = string? }` | — |
| `"Wear"` | `{ DraftId: string?, Item: EncodedItem }` | `{ WornId: string }` | `WearCooldown`; JSON size ≤ `MaxDraftBytes`; `SkinSchema.Decode` + `Validate` (errors refuse, warnings allowed); character alive; not a hider |
| `"StopWearing"` | — | — | — |
| `"Save"` | `DraftRecord` (`DraftId` nil = new) | the stored `DraftRecord` | `SaveCooldown`; size; Validate (errors refuse); at most `MaxDrafts`; `Source` must be a real catalogue Id and the draft may not change its Id or Theme |
| `"Delete"` | `DraftId: string` | — | exists |
| `"LookupAsset"` | `id: number` | `{ Name, Type: string?, AssetType: string, Creator: string, RobloxMade: boolean, Problem: string? }` | `LookupCooldown`; integer range; `pcall(MarketplaceService.GetProductInfoAsync)` (falls back to `GetProductInfo`) |

- **Wearing:**
  - `ShopService.SetSkinOverride(player, wearItem)` then `ShopService.Dress(player)`.
  - `StopWearing` sets the override to nil and dresses again.
  - The override is dropped on `PlayerRemoving`.
- **Respawn:** `Dress` on `CharacterAdded` uses the override, so the draft comes back by itself.
- **Drafts are stored three ways:**
  1. in memory (`drafts[DraftId]`)
  2. in the **mirror** `ServerStorage.SkinStudioDrafts` (a Folder made at runtime): one `StringValue` per draft, `Name = DraftId`, `Value = JSON(DraftRecord)`, attributes `SkinId`, `Theme`, `Updated`
  3. in the **DataStore**, when `UseDataStore`: `DataStoreService:GetDataStore(DraftStore)`, key `DraftKey`, value `{ Version = 1, Drafts = { [DraftId] = DraftRecord } }`, written with `UpdateAsync`, merging by `Updated` (newest wins, so two Team Create editors don't wipe each other)
- **DataStore loading and failures:**
  - Loaded once at `Start` (`pcall`). On failure the status is `"Failed"` or `"Off"` (no published place, or Studio API access off) and the UI explains (6.8).
  - A failure never blocks memory or mirror saves.
  - Save writes on the button press only (Studio may stop before `PlayerRemoving` finishes).
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
**The main path is Studio MCP + `/save-skins`, during a playtest:**
1. In Skin Studio, press **Save** on each draft (Save tab). The status line says where it is kept:
   - *"Saved. Kept after Stop (DataStore on)."*, or
   - *"Saved for this playtest only. Run /save-skins in Claude Code before you press Stop."*
2. In Claude Code type `/save-skins` (`.claude/commands/save-skins.md`, B). It runs these steps:
   1. MCP `get_studio_state`.
   2. If a playtest is running: MCP `execute_luau` with `datamodel_type = "Server"`:
      `return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).Json()`.
      If stopped: the same call with `datamodel_type = "Edit"` (reads the DataStore; needs API access [M]). If that fails, ask Kieran to press Play and Save again.
   3. Write the result to `tests/out/skin-drafts.json` (git-ignored).
   4. Run `lune run tests/save-skins -- tests/out/skin-drafts.json --dry-run` and show Kieran the plan: which file, added or replaced, warnings, and the new rarity counts.
   5. Run it again without `--dry-run`, then `stylua src`, `selene src` and `lune run tests/run`.
   6. If a new skin changed a theme's rarity counts, update `tests/specs/skins.spec.luau` and `crates.spec.luau` the way `/add-skin` step 6 describes. Explain the new crate odds (`/add-skin` step 5).
   7. Fix test failures caused by the drafts, or tell Kieran which draft breaks which rule. Never weaken an unrelated test.
   8. Commit `Skin Studio: <n> skins` (only if Kieran agrees), and tell him which skins went in.

**The Lune tool `tests/save-skins.luau` (B):**
- **Usage:** `lune run tests/save-skins -- <drafts.json> [--dry-run] [--only D1,D2]`.
- **Generates its own text:** it builds the harness `Runtime` and `rt:require`s `SkinSchema`. For each draft it runs `Decode` and `Validate`, and **regenerates** the Luau with `SkinSchema.ToLuau`. It never pastes text from the JSON, so a stale or edited file can't inject code.
- **Refuses:**
  - drafts with errors
  - Classic or Tower skins
  - a `Source` whose Id changed
  - an Id that already exists in another theme file
  - a theme file without `local rgb = Color3.fromRGB` / `local M = Enum.Material`
- **Edits:** it uses pure helpers in `tests/tools/SkinFile.luau`:
  - **replace** the entry block containing `\t\tId = "<Id>",`: from the nearest `\t{` line above to the next `\t},` line
  - or **insert** a new entry after the last entry of the same `Rarity`, or before the closing `} :: { any }`
  - every other byte stays identical
  - the header count line (`(20): 12 Common, 5 Uncommon, 2 Rare, 1 CRAZY`) is updated when it matches that pattern
- **Output:** per theme, the rarity counts before and after, then the warnings. Exit code 1 if anything was refused.

**Copy code (always works, no setup):**
- The Save tab's **Copy code** opens a modal `TextBox` (MultiLine, `ClearTextOnFocus = false`). It holds `SkinSchema.ToLuau(item)`, computed on the client because the module is shared, plus a one-line hint: *"Ctrl+A, Ctrl+C, then paste it into Claude Code and say which theme file"*. If you type in it, the text resets when the box loses focus.
- **Print** writes the same text to Output between `Config.SkinStudio.ExportMarkers`. MCP `get_console_output` can read it too.

**Edit-mode helper `src/server/Tools/SkinExport.luau` (B):**
```
SkinExport.Json() -> string   -- {"Version":1,"From":"Playtest"|"DataStore"|"None","Drafts":[DraftRecord...],"Problem":string?}
SkinExport.Print()            -- Json() between the export markers, in chunks of at most 3,000 characters
```
- In a playtest it reads the `ServerStorage.SkinStudioDrafts` mirror. Otherwise it reads the DataStore (`pcall`).
- It is stateless, so requiring it from MCP or the command bar is safe.

**After saving:** Rojo syncs the changed theme files into Studio. On the next playtest, the Skins list marks a draft **✓ in game files** when `SkinSchema.Encode(draft.Item)` equals the catalogue entry's encoding, and offers **Delete draft**.

### 6.9 Shared module `src/shared/SkinSchema.luau` (builder B; pure, client + server)
```
export type Field = { Key: string, Path: { string }, Label: string, Help: string, Section: string,
	Control: "Color" | "Material" | "Choice" | "Patterns" | "Toggle" | "Number" | "Text"
		| "Effects" | "Motion" | "Catalog",
	Choices: (() -> { string })?, Min: number?, Max: number?, Step: number?,
	Optional: boolean, From: string? }  -- From = lowest rarity it suits ("Uncommon" for Head...)
SkinSchema.Fields: { Field }          -- item fields + every Style key, in export order
SkinSchema.ItemKeys: { string }       -- Id, Name, Rarity, Crate, Price, CrateOnly, OneInAMillion, Odds, Style
SkinSchema.Encode(item) -> EncodedItem          -- JSON-safe: Color3 "#RRGGBB", Enum.Material name
SkinSchema.Decode(encoded: any) -> (item?, { string } errors)
SkinSchema.Validate(item) -> (boolean, { string } errors, { string } warnings)
SkinSchema.Check(item, catalogue: { any }) -> { string } warnings   -- rarity rules (SkinAnimate.RarityProblems + the skins.spec rules), duplicate look (LookKey), CRAZY head already used, duplicate Name, test expectations (crate skin with own Crate/Price/HideClothes false)
SkinSchema.LookKey(style) -> string   -- exactly the key skins.spec uses
SkinSchema.IdOk(id, theme) -> (boolean, string?)   -- ^(%u%a+)_(%u%w+)$, prefix = theme, not "StudioDraft_", unique
SkinSchema.NewItem(theme: string) -> item
SkinSchema.Duplicate(item) -> item
SkinSchema.WearItem(record) -> item   -- { Id = "StudioDraft_...", ModelId = Item.Id, Slot = "Skin", Name, Rarity, Style + Kind/HideClothes defaults }
SkinSchema.ToLuau(item, theme: string?) -> string   -- one entry, one tab indented, in the theme files' style
```
**Validation errors** (the server refuses):
- not a table; unknown keys at any level; wrong types; nesting deeper than 4
- a colour that isn't `#RRGGBB`; a material that isn't an `Enum.Material` name
- `Head` not `HeadPieces.Has`; `Face` not in `HeadPieces.Faces`
- an unknown pattern (`Cosmetics.HasPattern`); `Aura.Kind` not in `Config.Skins.Auras`
- `Crazy.Orbit` not in `OrbitKinds`; `Crazy.Count` not an integer 1–8; `Crazy.Effect` not a key of `Config.Skins.Effects.Special` (the server can't require the client's SkinEffects)
- Animate, Motion or Catalog errors from A's `Normalize` functions
- out-of-range numbers: `Transparency` 0–0.9, `Glow.Brightness` 0–10, `Glow.Range` 0–60, `Price` an integer 0–10,000,000
- `Name` not 1–40 characters; any string over 60 characters
- `Rarity` not in `Config.Rarity.Order`; `Theme` not in `Config.Skins.Themes`; `Crate` not in `Config.Crates.List`
- a bad Id (`IdOk`); encoded size over `MaxDraftBytes`

**Warnings** (allowed in drafts, listed in the UI and by `/save-skins`): everything `Check` returns.

**ToLuau rules:**
- Uses the theme file's locals `rgb(...)` and `M.Name`.
- Leaves out what `Skins/init.luau` fills in: `Slot`, `Theme`, `Style.Kind`, `HideClothes = true`, and `Crate` when it equals the theme's crate.
- Key order follows `Fields`. Numbers are written shortest-exact (`1.5`, `0.35`). Strings are double-quoted with `\` and `"` escaped.
- `OneInAMillion`/`Odds` get the same comments the theme files use.

### 6.10 `Config.SkinStudio` (`src/shared/Config/SkinStudio.luau`, builder B)
```lua
return {
	AllowInLiveServers = false, -- true = admins can use it in live games too (Config.Admin decides who)
	UseDataStore = true, DraftStore = "SkinStudioDrafts_v1", DraftKey = "Drafts",
	MaxDrafts = 200, MaxDraftBytes = 16000,
	WearDelay = 0.35, PreviewDelay = 0.15, -- seconds after your last change
	WearCooldown = 0.25, SaveCooldown = 1, LookupCooldown = 1, -- per admin, checked on the server
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
| `Cosmetic_Skin` / preview model | `LiveStyle` | string (JSON) | Cosmetics (drafts only) |
| `AnimPivot` part | `AnimGroup`, `AnimSide`, and the copied custom `Animate`/`Speed`/`Amount`/`Axis`/`Delay`/`Every`/`Reverse`/`Color2` | various | Cosmetics |
| custom-model part or Model | `Animate`, `Speed`, `Amount`, `Axis`, `Delay`, `Every`, `Reverse`, `Color2` | various | Kieran in Studio |
| character | `SkinMotion` | string | Cosmetics |
| character | `SkinMotionIds` | string | Cosmetics |
| character | `SkinCatalogStatus` | string | SkinCatalogService |
| catalog Accessory | `SkinCatalog` | boolean | SkinCatalogService |

**Joints and instances:**
- `Motor6D` named `SkinMotor`, inside each `AnimPivot`.
- `ServerStorage.SkinStudioDrafts` (Folder of StringValues, runtime only).
- `Workspace.LocalSkinFx` (existing, client-only).

**Remotes** (B only; A adds none):
| Name | Kind | Direction |
| --- | --- | --- |
| `SkinStudio` | RemoteFunction | client → server |
| `SkinStudioOpen` | RemoteEvent | server → client |

**Feature switches** (`Config.Features`): `SkinAnimations = true`, `WalkStyles = true`, `SkinCatalog = false` (A); `SkinStudio = true` (B).

**Config sections:** `Config.SkinAnimate`, `Config.SkinMotion`, `Config.SkinCatalog` (A); `Config.SkinStudio` (B).

**Saved data:** none added.

---

## 8. File ownership
Two builders work in parallel. **Never edit a file the other builder owns.** The shared files at the bottom take only the listed lines, at the listed places, so git merges them cleanly.

**Builder A: animation system + catalog items**
| File | New / change |
| --- | --- |
| `src/shared/SkinAnimate.luau`, `src/shared/SkinMotion.luau`, `src/shared/SkinCatalog.luau` | new |
| `src/shared/Config/SkinAnimate.luau`, `Config/SkinMotion.luau`, `Config/SkinCatalog.luau` | new |
| `src/client/SkinAnim.luau`, `src/client/SkinWalk.luau`, `src/client/CatalogBadge.luau` | new |
| `src/server/Services/SkinCatalogService.luau` | new |
| `src/shared/Cosmetics.luau` | change (3.4, 4.2, 5.3 hooks) |
| `src/client/SkinFx.luau` | change (3.11) |
| `src/shared/DanceMoves.luau` | optional tiny export (4.3) |
| `src/shared/Tags.luau` | one line |
| `src/client/ShopUI.luau` | two hooks (3.7, 5.4) |
| `src/client/CrateUI.luau` | one hook (5.4) |
| `src/shared/Config/Skins/*.luau` | showcase animations on existing skins (section 9), and the Pumpkin.luau options comment |
| `tests/specs/skins.spec.luau` | change (section 10) |
| `tests/specs/skinanimate.spec.luau`, `skinmotion.spec.luau`, `skincatalog.spec.luau` | new |
| `.claude/commands/add-skin.md` | mention Animate, Motion and Catalog |
| `.claude/commands/animate-skin.md` | new: `/animate-skin <skin> <what should move>` |
| `docs/CUSTOMIZE.md` | sections "Animated skins", "Walk styles", "Catalog items in skins", inserted after "### Crate skins: add or change a skin" (before "### Trails"), plus 2 rows in "Turn animations off or down" |

**Builder B: Skin Studio + saving**
| File | New / change |
| --- | --- |
| `src/shared/SkinSchema.luau` | new |
| `src/shared/Config/SkinStudio.luau` | new |
| `src/server/Services/SkinStudioService.luau`, `src/server/Tools/SkinExport.luau` | new |
| `src/client/SkinStudioUI.luau`, `src/client/SkinStudioControls.luau`, `src/client/SkinStudioState.luau` | new |
| `src/server/Services/ShopService.luau` | change (6.7 only) |
| `src/shared/Config/Menu.luau` | the tile line, after the `EasterEggs` tile |
| `tests/save-skins.luau`, `tests/tools/SkinFile.luau` | new |
| `tests/specs/skinstudio.spec.luau` | new |
| `.claude/commands/save-skins.md` | new |
| `CLAUDE.md` | one line in the slash-command list: `/save-skins`, `/animate-skin` |
| `docs/CUSTOMIZE.md` | a new `## Skin Studio` section inserted right before `## Crates`, plus `/save-skins` in "Claude Code commands" |

**Shared hook points** (both builders edit; exact places)
| File | A adds | B adds |
| --- | --- | --- |
| `src/shared/Config/Features.luau` | 3 lines right after `SkinEffects = true, ...` | 1 line right after `Menu = true, ...` |
| `src/shared/Config/init.luau` | `SkinAnimate = require(script.SkinAnimate),` `SkinMotion = ...,` `SkinCatalog = ...,` right after `Skins = require(script.Skins.Settings),` | `SkinStudio = require(script.SkinStudio),` right after `ScreenMotion = require(script.ScreenMotion),` |
| `src/client/Main.client.luau` ORDER | `"SkinAnim", -- ...` and `"SkinWalk", -- ...` right after `"Dances"` | `"SkinStudioUI", -- ...` right after `"AdminUI"` |
| `src/server/Main.server.luau` ORDER | `"SkinCatalogService", -- ...` right after `"ShopService"` | `"SkinStudioService", -- ...` right after `"AdminService"` |

**Test harness:** if A needs Humanoid description stubs, A defines them inside its own spec with `Dom.define("Humanoid", {...})` (as `serverguard.spec` does), not in `tests/harness/`. B doesn't touch the harness.

**Neither builder edits:** `docs/V2-CHANGES.md`, `docs/PROGRESS.md` and `ROADMAP.md`. The integration step updates them.

---

## 9. Build order and sync points
- **A1 (first, small, ~1 h):**
  - all three Config files and the switches
  - `SkinAnimate`, `SkinMotion` and `SkinCatalog` shared modules with metadata, `Normalize`, encode/decode and the pure maths
  - `Tags.SkinAnim` and the hook lines
  - their unit tests

  Commit as `Skin animations: shared contract`. **B pulls A1 before wiring the Animate, Walk style and Catalog controls.** Until then B builds the core Style keys.
- **A2:** Cosmetics (pivots, LiveStyle, ModelId, Motion attributes, OnSkinChanged, catalog skip) + skins.spec updates.
- **A3:** SkinAnim + SkinFx changes + preview hooks.
- **A4:** SkinWalk.
- **A5:** SkinCatalogService + CatalogBadge.
- **A6:** Showcase skins, then docs and the slash command. Suggested showcase (Rare at most 3 effects, Motion Rare and up):
  - `Candy_BubblegumBat`: Flap
  - `Moonlight_MoonMoth`: slow Flap + Glow Pulse
  - `Candy_CottonCandyCat`: Wag
  - `WitchsBrew_BrewMistress`: Wag + Cape Breathe
  - `Pumpkin_SirGourdington`: Cape Breathe + Head Wobble
  - `ZombieTown_ZombieOverlord`: Flap + `Motion = "Zombie"`
  - `Pumpkin_MegaGourdSupreme`: Head Float + Accents Shimmer + `Motion = "Bouncy"`
  - `VampireCastle_NightLordSupreme`: Cape Wobble + `Motion = "Bat"`
  - `Moonlight_LunarLegend`: slow Head Spin + `Motion = "Ghost"`
- **B1:** Config.SkinStudio, SkinSchema (core keys: Encode/Decode/Validate/ToLuau/LookKey) + tests.
- **B2:** SkinStudioService, the ShopService hook, remotes, drafts (memory, mirror, DataStore), SkinExport, F8 command + tests.
- **B3:** SkinStudioState, SkinStudioControls, SkinStudioUI (PC and phone) + tests.
- **B4 (after A1):** Animate, Walk style and Catalog editors; SkinSchema delegates to A's `Normalize` functions.
- **B5:** `tests/save-skins.luau` + `SkinFile` + `/save-skins` + docs.
- **Each builder, before handing over:**
  - `stylua`, then `/tmp/claude-0/check/check.sh <new-game>` with no new type errors
  - `lune run tests/run` all green
  - catwalk renders of the showcase skins (A)
  - commits ending with the two attribution lines; no push

---

## 10. Tests
**Changes to existing specs (A):**
- `skins.spec`, "Skin styles":
  - `STYLE_KEYS` adds `Animate = "table"`, `Catalog = "table"` and `Motion` (accepts `"string"` or `"table"`; change the check to allow a set of types).
  - "points every ... at something that exists" also runs `SkinAnimate.Normalize`, `SkinMotion.Normalize` and `SkinCatalog.Normalize` on every catalogue skin, with no errors and no warnings.
  - "makes each rarity look better" adds `SkinAnimate.RarityProblems(item)` (Config-driven).
- `skins.spec`, "Wearing skins": the joint check becomes a chain rule. Every BasePart in `Cosmetic_Skin` is unanchored and `CanCollide = false`, and is either:
  - (a) joined by a `WeldConstraint` to a body part, or
  - (b) joined by a `WeldConstraint` to an `AnimPivot` in the model, or
  - (c) an `AnimPivot` whose `SkinMotor.Part0` is a body part or another `AnimPivot`

  Following the chain always ends at a body part outside the model. The snapshot also covers the character attributes `SkinMotion` and `SkinMotionIds`.
- `skins.spec`, "fills ... HideClothes": allow `HideClothes = false` when `Style.Catalog` has Shirt, Pants or TShirt.

**New: `skinanimate.spec` (A):**
- every effect has metadata and Config numbers, and the other way round
- `Normalize` fills defaults; a table of ~25 bad inputs is each refused with a message
- Offset, Tint and Brightness are finite and continuous (a small `dt` gives a small change), and deterministic for the same `t`
- `EncodeLive`/`DecodeLive` round trip; `StyleOf` prefers the catalogue
- pivots are built only for moving targets; a skin without Animate builds the **same instances** as with the feature off
- animated skins go on and come off R15 and R6 leaving the avatar exactly as it was
- custom-model `Animate` attributes become groups (a test model made in the runtime under `Custom.Cosmetics`)
- nothing is built or tagged with `SkinAnimations` off
- **client:**
  - budget (PC 8, phone 4, own character first, distance cull)
  - hider deactivates straight away on the attribute change
  - last-written guard (the server recolours mid-effect, then deactivate leaves it)
  - SparkleBurst never emits on a disabled emitter
  - over 5 virtual seconds with every effect running, no `Transparency`, `Enabled` or `LocalTransparencyModifier` change event fires
  - no frame connection when idle (perf pattern)
  - previews animate only while shown, motion on at most `MaxPreviewMotion`, none on phones

**New: `skinmotion.spec` (A):**
- every preset poses R15 and R6 with finite turns
- `Normalize` accepts presets and ids and refuses others
- the server sets and clears the attributes
- Add mode doesn't build up when the "animator" doesn't write (the test sets `Transform` by hand between frames)
- Set mode overrides; skips dancers, hiders, the seated and characters out of budget; clears joints on stop
- own-client uploaded tracks load, switch Walk/Run/Idle by speed, stop on clear (`rt:calls("Animator", "LoadAnimation")` or a stub)

**New: `skincatalog.spec` (A):**
- `Normalize` and `Key`
- with `Dom.define("Humanoid", { GetAppliedDescription, ApplyDescriptionAsync })` stubs (yields, failures):
  - applies once; newest wins; never for hiders (including one who becomes a hider during the yield)
  - restores `base` when the skin comes off
  - failure keeps the Part skin and sets the status
  - respawn applies again; feature off does nothing
- CatalogBadge shows thumbnails only for catalog skins

**New: `skinstudio.spec` (B):**
- **Schema:**
  - knows every Style key the catalogue uses
  - `Decode(Encode(item))` deep-equals the item for **all ~634 skins**
  - evaluating `ToLuau(item)` with `@lune/luau` `load` (env `rgb`, `M`) and re-applying the `Skins/init.luau` defaults deep-equals the item, for all skins
  - `LookKey` is unique across the catalogue
  - `Validate` refuses ~30 bad drafts (types, ranges, unknown keys, huge strings, deep nesting, a bad Id, `StudioDraft_` prefix)
  - `Check` warns for each rarity rule, a duplicate look and a used CRAZY head
- **Server:**
  - only admins, only in Studio unless `AllowInLiveServers`; the feature off answers "not allowed" and never errors
  - malformed or oversize payloads and non-string actions get Ok = false
  - cooldowns
  - Wear wears `StudioDraft_...` with `ModelId`, leaves the save untouched, survives respawn, `StopWearing` puts the equipped skin back, refused for a hider
  - Save/Delete in memory, mirror and DataStore; DataStore failure (`dataStores = false`, `rt.dataStoreFailures`) still saves to memory and mirror with the right status
  - `MaxDrafts`; `Source` id and theme locked
  - the F8 command fires `SkinStudioOpen` only for allowed players
  - `SkinExport.Json` from the mirror and from the DataStore
- **Client** (client runtime, `OnServerInvoke` stub):
  - shows nothing when off or not admin and never waits on a missing remote (remotes are looked up with `WaitForChild(name, 10)` inside the first Open, not in Mount)
  - the Menu tile is visible only for admins
  - search and filter
  - one Wear after the debounce for a burst of edits
  - Undo, Redo and Reset
  - Copy code text equals `ToLuau`
  - phone layout is a bottom sheet with tabs and 44 px controls
  - open/close 20 times keeps instance and connection counts flat (like `perf.spec`)
  - turntable restores the camera
- **Tool:** `SkinFile` replaces an entry, inserts after its rarity group and keeps every other byte identical. It refuses a renamed Id or an Id from another theme. Counts are right.

**Existing guards that must stay green:** `Startup.spec` (ORDER modules mount), `Menu.spec` (a tile with `Feature` is a boolean switch), `perf.spec` (idle work), `modules.spec`, and the catalogue counts. Showcase skins don't add skins, so counts don't change.

---

## 11. Performance budgets
| What | PC | Phone | Where |
| --- | --- | --- | --- |
| Characters with animated pieces | 8 | 4 | `SkinAnimate.MaxCharacters` / `PhoneMaxCharacters` |
| Characters with walk styles | 12 | 6 | `SkinMotion.MaxCharacters` / `PhoneMaxCharacters` |
| CRAZY effects (existing) | 6 | 6 | `Skins.Effects.MaxAnimated` (unchanged) |
| Animation range | 120 studs (half rate past 60) | same | `MaxDistance`, `HalfRateDistance` |
| Effects per skin | 6 (by rarity: 0/1/3/6) | — | validated |
| Moving groups per skin | 6 pivots | — | `MaxPivots` |
| Parts recoloured per effect | 40 | — | `MaxColorParts` |
| Parts in a `Cosmetic_Skin` | ≤ 120 including pivots | — | existing skins.spec test |
| Particles | SparkleBurst ≤ 50 per burst, at least 0.5 s apart; no new emitters | — | validated |
| Lights / Highlights | none added | — | rule D3 |
| Previews with moving pieces | 4 | 0 | `MaxPreviewMotion` |
| Idle cost | no frame connection when nothing animates | — | perf.spec pattern |
| Network | nothing per frame; attributes once per wear; Studio Wear ≤ 4/s per admin | — | D1, `WearCooldown` |
| Catalog applies | ≤ 1 per player per 2 s, one in flight per character | — | `SecondsBetweenApplies` |

Off-screen characters (except you) get no writes. All per-frame work is plain Lua property writes, with no instance creation per frame.

## 12. Security checklist
- **Remotes:** B adds two; A adds none. `SkinStudio` checks everything on the server: `Allowed` on every action, the action is a string, the payload type, the JSON size limit before decoding, `SkinSchema.Validate` (strict whitelist and ranges) and per-admin cooldowns. Errors become Replies, never script errors.
- **Hide & Seek:** a client never trusts its own guess. Hiders are skipped by every effect and walk style. Effects can't un-hide anything (D3), and Catalog re-checks the role after the yield.
- **Ownership:** the Studio override is the only way to wear an unowned skin. It is set only by `SkinStudioService` after `Allowed`, and the save never changes. Players get nothing new through Skin Studio.
- **Asset loads:** `AssetTypeVerification.Always` on every apply. Ids are integers, and types are whitelisted and layered types refused.
- **Export:** the save-skins tool regenerates code from validated data (it never pastes JSON text). Theme Ids never change.
- **DataStore:** only the server writes, only on Save, to a separate store name (`SkinStudioDrafts_v1`), never touching player data.

## 13. Docs to write
- **`docs/CUSTOMIZE.md` (A):**
  - **Animated skins**: what each effect does; copy-paste examples; targets; rarity limits; turning effects down.
  - **Animate parts of your own model**: the attribute table and the Pivot tool, then Save to File into `assets/Cosmetics/<SkinId>.rbxm` to keep it in git.
  - **Walk styles**: presets; your own animations; the ownership rule; R6 note.
  - **Catalog items in skins**: what's allowed and why; how to switch it on; the policy note; Studio test steps.
  - Two rows in "Turn animations off or down": `SkinAnimations`/`MaxCharacters` and `WalkStyles`/`MaxCharacters`.
- **`docs/CUSTOMIZE.md` (B), "## Skin Studio":**
  - how to open it
  - a tour of each tab
  - wearing and the turntable
  - saving (the three ways, with exact steps)
  - turning on Studio API access: Game Settings > Security > "Enable Studio Access to API Services" (the place must be published). With it on, Studio also uses the live player-data store, so his own save in Studio is real.
  - troubleshooting: *"Saved for this playtest only"*, *"Not allowed"*, *"Slow down"*, *"Animation didn't load"*
- **The Pumpkin.luau STYLE OPTIONS comment (A):** `Animate`, `Motion` and `Catalog` with one-line examples.
- **Slash commands:**
  - `/save-skins` (B, steps in 6.8)
  - `/animate-skin` (A: read the skin, pick effects within its rarity limit, edit the theme file, run tests, render with catwalk)
  - `/add-skin` gains a line on Animate, Motion and Catalog (A)
- Every new Config file opens with a plain-English header; every new module opens with a doc comment listing its API (like `SkinFx.luau`).

## 14. Needs testing in Studio (after both builders finish)
1. **Effects on R15, R6 and AnimationConstraint rigs:** Flap, Wag, Spin and Breathe pieces move smoothly while walking, jumping and dancing (pieces follow the dance), and on the next respawn.
2. **Other players' view:** a 2-player test. Same phase on both screens. Your own character always animates. Others stop beyond 120 studs.
3. **Phones:** the device emulator plus a real phone with 6+ animated and CRAZY skins in view. Frame rate is fine and the phone limits hold.
4. **Hide & Seek:** become a hider while wearing an animated or catalog skin. Nothing shows, nothing sparkles, nothing moves. Undisguise brings everything back.
5. **Ghosts:** caught players stay see-through with effects running.
6. **Walk styles:**
   - every preset on R15 and R6
   - blending with Roblox's walk, with no build-up or jitter (checks the base-tracking assumption)
   - dances still win
   - uploaded ids play for everyone; a non-owned id shows the Studio warning and falls back to the normal walk
7. **Catalog** (switch on):
   - a hat and a back item on a Part skin, with welds intact and the head piece correct
   - a classic shirt with `HideClothes = false`
   - taking it off restores your own avatar exactly
   - respawn; a bad id; a moderated id
   - with `AvatarUnificationMode` / `EnableSLIMAvatars` as set in this place
   - with BodyColors stashed (no duplicate BodyColors)
8. **Skin Studio:**
   - open from Menu and F8; edit every control; live wear updates within half a second; respawn keeps the draft
   - Undo/Reset; turntable; phone sheet
   - Save with and without Studio API access
   - `/save-skins` end to end through the MCP (playtest and edit mode); Copy code reaches the clipboard; Print appears in Output
9. **Previews:** shop cards and crate reveals of animated skins move (PC only), catalog thumbnails show, and closing the shop frees them.

## 15. Open questions for Kieran (sensible defaults are already in Config)
1. Should Common skins ever animate? (default: no; Uncommon 1 effect, Rare 3, CRAZY 6)
2. Catalog items: OK to put other creators' Roblox items into crate skins? (default: switched off; prefer Roblox-made items)
3. Walk styles only on Rare and CRAZY skins? (default: yes)
4. Is the game owned by you or by a group? This decides who must own uploaded animations.
5. Turn on Studio API access so drafts survive pressing Stop?
6. Happy with the 9 showcase skins in section 9, or pick your own?
