---
description: Build the next unfinished milestone from docs/PROGRESS.md, test it in Studio, commit it, and mark it done.
---

Work through the next unfinished milestone for this game.

1. Read `CLAUDE.md`, `docs/DESIGN.md` and `docs/PROGRESS.md`. Find the first row whose Status is `todo` or `in progress`. Tell me which milestone you picked and your plan in 5 lines or fewer.
2. Build it following `docs/DESIGN.md`. Obey the rules in `CLAUDE.md`: every tunable in `src/shared/Config.luau`, server-authoritative, `--!strict`, `Remotes` for networking, new services registered in `Main.server.luau`.
3. Run `stylua src` and `selene src`, then fix what they report.
4. Playtest in Studio through the Studio connection (a local server with 2 players when the feature involves more than one player). Read Output. Fix any red errors and repeat. If the same error survives 3 attempts, stop and report it instead of guessing further.
5. When it works, update `docs/PROGRESS.md` (set the row to `done`, add one line under Notes about what was built), then commit on the current branch with the message "<milestone>: <short summary>" and push to the current branch only.
6. Stop and report in this format:
   - What was built
   - What I tested and the result
   - What you (the owner) must do next, if the row says "Needs the owner"
   - Which milestone `/next-milestone` will do next

Hard limits:
- Do not start the following milestone in the same run. I will run the command again.
- Do not spend money, create gamepasses or products, publish the experience, or make it public. If a milestone needs those, build everything you can, mark the row `blocked` with the exact steps I must do, and stop.
- Never put API keys or secrets in files.
- Never push to any branch other than the current one, and never force-push.
- If a Creator Store model is used, remove unexpected scripts from it and list each asset id you used.
