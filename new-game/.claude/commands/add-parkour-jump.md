---
description: Add a jump (or a few) to the lobby parkour course. Usage: /add-parkour-jump <what and where>
---

Add to the parkour course: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Parkour jumps", all of `src/shared/Config/Parkour.luau` (the `Course` format and the `Jumps` limits), `src/shared/ParkourLogic.luau` (`Check`, `Jump`, `Reach`) and `src/server/Hub/Sections/Parkour.luau`.
2. Plan the change and tell me in 3 lines: between which pieces it goes, its `Kind`, and roughly how high.
   - Pieces stay inside the parkour zone: right -30 to 30, back -22 to 22, up to 60 (`Config.Lobby.Zones.Parkour`).
   - Gaps at most `Jumps.MaxGap` (9 studs) across and `Jumps.MaxRise` (5) up; `Spicy = true` allows 10 and 5.5. Keep `Jumps.Headroom` (10 studs) free above each piece. It must be fair for a kid on a phone.
   - Keep `Start` first and `Finish` last; checkpoints are numbered in the order they appear.
3. Edit `Course`: copy a line of the same `Kind`, paste it in the right place, change its `Offset` (right, up, back). Move later pieces if needed so every jump stays within the limits. A new `Kind` needs a builder in `Sections/Parkour.luau` plus its entry in `ParkourLogic.Kinds` and `Config.Parkour.Sizes`.
4. Run `stylua src`, `selene src` and `lune run tests/run`. The parkour spec checks every jump in the course: fix anything too far, too high or overlapping. It also expects exactly 3 checkpoints and 20-28 jumps; if my request needs more, update that rule in `tests/specs/parkour.spec.luau` on purpose and tell me.
5. Raise `Config.Hub.BuildVersion` by one so an unlocked saved lobby gets the new course. If my lobby is Locked, tell me: either `Bake.Hub(true)` (replaces my hand edits) or copy and move one of the jump parts by hand in `Workspace.Hub.Parkour`.
6. Playtest in Studio: F8 > "Rebuild hub", then "Parkour: teleport to start". Climb the whole course with a normal character, including the new jump. Check checkpoints still count 1/2/3 in order and the Output has no "too far" or "too high" warnings.
7. Commit "Parkour: <summary>" and push to the current branch.
