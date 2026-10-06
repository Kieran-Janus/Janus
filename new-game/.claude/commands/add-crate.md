---
description: Add a new mystery crate (its skins, price, odds and stand display). Usage: /add-crate <theme or idea>
---

Add a crate: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Crates" and "Crate skins", the header of `src/shared/Config/Crates.luau`, `src/shared/Config/Skins/Settings.luau`, `src/shared/CrateOdds.luau`, `src/shared/CrateArt.luau` and `src/server/Hub/Sections/CrateStand.luau`.
2. Decide what's inside and tell me the plan:
   - **A new theme** (usual): a new file `src/shared/Config/Skins/<Theme>.luau` with 20 skins (12 Common, 5 Uncommon, 2 Rare, 1 CRAZY, following the rarity look rules in `/add-skin`), plus a line in `Themes` in `Skins/Settings.luau` with `Crate = "<Theme>Crate"`.
   - **Existing skins**: set `Crate = "<CrateId>"` on them. A skin is in one themed crate only, so moving skins takes them out of their old crate: warn me.
   - **A rarity crate**: `Rarity = "<Rarity>"` gives every crate skin of that rarity.
3. Add the crate to `List` in `Config/Crates.luau`: `Id` (unique, never renamed once live), `Name`, `Blurb`, `Color`, `Trim`, `Glow`, `Topper`, `Price` (coins; themed crates are 300), `Robux = { ProductId = 0, SuggestedRobux = 49 }`, and `Odds` only if it needs its own (they must add up to 100).
4. The crate stand must still fit its zone (`Config.Lobby.Zones.Crates`). If the stand gets crowded, adjust `Config.Crates.Stand` or the zone, and check nothing overlaps the Pumpkin Shop.
5. Raise `Config.Hub.BuildVersion` by one so an unlocked saved lobby rebuilds with the new stand. For a Locked lobby, tell me: copy one `<CrateId>Display` model on the stand and set its `CratePrompt` part's `CrateId` attribute to the new Id (or `Bake.Hub(true)`, which replaces my hand edits).
6. Run `stylua src`, `selene src` and `lune run tests/run` (the crates spec checks every crate's odds and contents).
7. Playtest in Studio: F8 > "Rebuild hub" and "Crates: +100k coins". Menu > Crates lists it; its preview shows every skin and chances adding up to 100%; open it a few times; the stand prompt opens it; a duplicate refunds coins.
8. Robux: never create products yourself. Tell me the steps: Creator Hub > Pumpkin Panic > Monetization > Developer Products > Create, then paste the Product ID into the crate's `Robux.ProductId`.
9. Commit "Add crate: <name>" and push to the current branch.
