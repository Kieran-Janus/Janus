---
description: Full playtest of every feature in Studio, then fix what's broken and commit.
---

Do a full verification pass of the game. Read `CLAUDE.md`, `docs/PROGRESS.md`, `docs/V2-CHANGES.md` and `docs/CUSTOMIZE.md` first. For the detailed, step-by-step test of every v2 feature (2 players, phones), use `/verify-v2` instead; this is the shorter whole-game pass.

1. Run `stylua src`, `selene src` and `lune run tests/run` from `new-game/`; fix what they report.
2. Start a Studio playtest through the Studio connection and read Output from the start. Fix every red error and every `[Main] ... failed to ...` warning.
3. Check each feature, briefly, and note pass/fail:
   - Lobby: spawn on the round "BOO!" stone facing the Ready circle; the Pumpkin Shop keeper opens the shop (Skins tab); Voting Board, Leaderboard Gravestone and Photo Spot prompts; no Witch Wanda, Boo Guide or tutorial pop-ups (all removed in v2).
   - Top-left Menu (key M): every tile opens its panel; only one panel at a time; Escape closes it.
   - Ready pad: standing on it shows READY on the sign and opens the vote; players off the pad stay in the lobby and can spectate.
   - Rounds: King Hunt (pumpkins, the King, minions, ghosts, results, back to the lobby), Hide & Seek and ScareMaze (F8 > "<mode>: force next round").
   - Shop: every tab; rarity prices (Common 125, Uncommon 500, Rare 1,000, CRAZY 100,000); buy, equip, unequip each slot; skins restore the avatar when removed; a hat sits on top of a skin's head piece.
   - Crates: odds preview adds up to 100%, opening with coins, the crate stand prompts.
   - Lobby extras: parkour, Candy Rush, Web Scour, secret pumpkins.
   - Menu > Codes: PUMPKIN works once, then says already used; a wrong code is refused.
   - Daily toast appears on join (F8 > Reset daily reward, then rejoin the playtest to see it again).
   - Menu > Invite opens Roblox's invite prompt (or a friendly message in Studio).
   - F8 admin panel: every button works.
   - Custom models: if anything is in `ReplicatedStorage.Custom`, it shows up in place of the placeholder.
4. Use a local server with 2 players (Test > Clients and Servers) for anything multiplayer (catching, Hide & Seek, ScareMaze, Candy Rush races, spectating, friend bonus, voice routing). If the Studio connection can't start it, ask me to.
5. Fix what fails (smallest correct fix, numbers stay in Config). Re-test the fixed items and run `lune run tests/run` again.
6. Update `docs/PROGRESS.md` notes with a short pass/fail list, commit "verify: <summary>" and push to the current branch.
7. Report: what passed, what you fixed, anything that still needs the owner (e.g. Robux IDs, publishing).
