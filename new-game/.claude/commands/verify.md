---
description: Full playtest of every feature in Studio, then fix what's broken and commit.
---

Do a full verification pass of the game. Read `CLAUDE.md`, `docs/PROGRESS.md` and `docs/CUSTOMIZE.md` first.

1. Run `stylua src` and `selene src`; fix what they report (ignore selene if its Roblox std library can't be generated).
2. Start a Studio playtest through the Studio connection and read Output from the start. Fix every red error.
3. Check each feature, briefly, and note pass/fail:
   - Hub: spawn on the pad, NPC prompts open the right dialog or shop, photo spot emotes, voting board, leaderboard.
   - Round: voting, map loads, pumpkins spawn and collect, King spawns after the delay and chases, minions behave, catching turns you into a ghost, ghost modes, round results, back to hub.
   - Shop: every tab including Skins; buy, equip, unequip each slot; skins restore the avatar when removed; a hat on top of a skin head piece sits on top of it.
   - Codes button: PUMPKIN works once, then says already used; a wrong code is refused.
   - Daily toast appears on join (F8 > Reset daily, then rejoin the playtest to see it again).
   - Invite button opens Roblox's invite prompt (or a friendly message in Studio).
   - F8 admin panel: every button works.
   - Custom models: if anything is in `ReplicatedStorage.Custom`, it shows up in place of the placeholder.
4. Use a local server with 2 players for anything multiplayer (catching, friend bonus, voice routing).
5. Fix what fails (smallest correct fix, numbers stay in Config). Re-test the fixed items.
6. Update `docs/PROGRESS.md` notes with a short pass/fail list, commit "verify: <summary>" and push to the current branch.
7. Report: what passed, what you fixed, anything that still needs the owner (e.g. Robux IDs, publishing).
