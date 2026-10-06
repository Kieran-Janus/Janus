---
description: Hide a new secret pumpkin (Easter egg) in the lobby. Usage: /add-secret-pumpkin <where, look and coins>
---

Add a secret pumpkin: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Secret pumpkins", the header and `List` of `src/shared/Config/EasterEggs.luau`, `src/server/Hub/Sections/EasterEggs.luau` (how anchors and offsets are placed) and `src/server/Services/EasterEggService.luau`.
2. Add one line to `List`:
   - `Id`: new and unique (search the file). It is saved in players' data: never reuse or rename one.
   - `Name`, `Coins` (at most `MaxCoins`; the others give 25-100), `Look` (`GoldenPumpkin`, `Candy`, `Lollipop`, `Skull` or `Ghost`).
   - `Anchor`: a tag name, an NPC Id, a lobby zone, a landmark or `"Hub"` (the list is in the file's header). An egg anchored to a switched-off feature is left out, so prefer anchors that are always there.
   - `Offset = Vector3.new(right, up, back)` from the anchor, `Snap` if it should drop onto the ground.
   - `Hint`: a short, kid-friendly riddle shown in Menu > Secret Pumpkins.
3. Run `stylua src`, `selene src` and `lune run tests/run` (the eggs spec checks every egg).
4. Playtest in Studio: find the new `EasterEgg` part (attribute `EggId`). Check it isn't inside a wall, under the ground or floating out of reach, and that it isn't obvious from the spawn. Walk to it and collect it: the toast shows the coins and Menu > Secret Pumpkins counts it. F8 > "Easter eggs: reset mine" afterwards.
5. A saved lobby gets new eggs automatically when the game starts. Moving an egg that is already in a saved lobby needs a rebuild or a hand move in `Workspace.Hub.EasterEggs`: tell me which.
6. Commit "Secret pumpkin: <name>" and push to the current branch. Tell me where it is (a spoiler, just for me) and its riddle.
