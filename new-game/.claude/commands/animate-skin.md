---
description: Make a skin's pieces move or glow, or give it a walk style. Usage: /animate-skin <skin Id or name> <what should move>
---

Animate a skin: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Animated skins", "Animate parts of your own model" and "Walk styles", the effect list at the top of `src/shared/SkinAnimate.luau`, `src/shared/Config/SkinAnimate.luau` (the `Rarity` limits and each effect's `Presets` numbers) and `src/shared/Config/SkinMotion.luau`.
2. Find the skin in `src/shared/Config/Skins/<Theme>.luau` by its `Id` or `Name` (the Tormented Tower's skin is in `src/shared/Config/TowerParkour.luau` > `Skin`). Read its whole `Style`: which accent patterns it has (only `Wings`, `Tail` and `Cape` can move), its `Head`, `Glow`, `Aura` and `Crazy`. For `Part:<name>` targets, look up the head piece's part names in its builder in `src/shared/HeadPieces.luau` (or the custom model's parts).
3. Pick effects that match what I asked, within the skin's rarity (`Config.SkinAnimate.Rarity`: Common none, Uncommon 1, Rare 3, CRAZY 6; a `Motion` walk style only on Rare and CRAZY). If I asked for more than the rarity allows, say so and pick the best ones. Rules:
   - every `Target` must exist on the skin (Wings needs the Wings pattern, Glow needs a `Glow`, SparkleBurst needs an `Aura`), or the effect does nothing;
   - with `Crazy.Rainbow` no colour effect (`Pulse`, `ColorCycle`, `Flicker`, `Shimmer`) on `Accents`, `All` or a pattern name; with `Crazy.Pulse` no `Pulse` or `Flicker` on the `Glow` (a `ColorCycle` on the `Glow` is fine);
   - keep it calm: one or two moving groups is plenty, `Speed` 0.3 to 2, `SparkleBurst` `Every` 2 or more. Spooky-cute, never scary-gory.
   Don't change the skin's look, `Id`, `Rarity`, crate or price. Add `Animate = { ... }` (and `Motion = "..."`) as the last keys of its `Style`, written like the other animated skins (for example `Candy_BubblegumBat`, `Pumpkin_MegaGourdSupreme`).
4. If the skin uses a custom model and I asked to move a part of it, explain the Studio attribute steps from `docs/CUSTOMIZE.md` > "Animate parts of your own model" instead of writing code.
5. Run `stylua src`, `selene src` and `lune run tests/run`: `skins.spec` checks every skin's `Animate` and `Motion` (no errors, no warnings) and `skinanimate.spec` the rarity limits. Fix what they report.
6. Look at it: `lune run tests/catwalk -- ids <Id>` and render it as the command prints (pieces at rest). The renderer only makes still pictures, so describe the movement in words.
7. Playtest in Studio when it is connected: wear the skin (F8 > "Unlock all", Menu > Skins), walk, jump, dance at the Photo Spot and check the pieces move smoothly and stay attached; open the Shop and check the card's preview moves (PC).
8. Commit "Animate skin: <name>" (only the files you changed, by name). Tell me which effects you added, what each looks like, and how to make it faster, slower, bigger or smaller (`Speed`, `Amount`).
