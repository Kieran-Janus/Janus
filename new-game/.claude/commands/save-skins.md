---
description: Save the skins made in Skin Studio into the game files (run it BEFORE pressing Stop). Usage: /save-skins [Id,Id to save only those]
---

Save my Skin Studio drafts into the theme files: $ARGUMENTS

Skin Studio (Menu > Skin Studio, or F8 > Skin Studio, in a Studio playtest) keeps saved drafts in the play server: `ServerStorage.SkinStudioDrafts`. They vanish when the playtest stops, so do this while it is still running. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` > "Skin Studio" and `docs/SKIN-STUDIO-SPEC.md` section 6.8 first.

1. **Which Studio MCP is connected?**
   - **Built-in Studio MCP**: tools `list_roblox_studios`, `get_studio_state`, `execute_luau`, `get_console_output`. Every call needs a `studio_id`: call `list_roblox_studios` first and pick the Studio with this place open (ask me if there are several). Go to step 2a.
   - **Older open-source MCP**: tools `run_code`, `get_console_output`, `start_stop_play`, `run_script_in_play_mode`, `get_studio_mode`. It can't read the play server, and `run_script_in_play_mode` starts a **new** playtest with no drafts: never use it here. Go to step 2b.
   - **No MCP**: go to step 2b (I copy the Output for you), or use Copy code in Skin Studio's Save tab and paste it here.
2. **Read the drafts.**
   - **a. Built-in MCP.** `get_studio_state`. While a playtest runs, `execute_luau` with `datamodel_type = "Server"`:
     `return require(game:GetService("ServerScriptService").Server.Tools.SkinExport).Count()`
     It answers JSON: `{"From":"Playtest","Drafts":n,"Pages":n}`. Then for each page `p` from 1 to `Pages`, the same with `.Json(p)`.
     If Studio is stopped: the same calls with `datamodel_type = "Edit"` read the DataStore copy, which only exists when `Config.SkinStudio.UseDataStore` was on (and Studio API access is enabled). `"From":"None"` means there's nothing: ask me to press Play, open Skin Studio and press Save again, or look in Output for the Stop print-out (step 2b).
   - **b. From Output.** Ask me to press **Print for Claude** in Skin Studio's Save tab (or check that Output still shows the print-out made when I pressed Stop). Call `get_console_output` and take every page between the lines `--[[ SKIN STUDIO BEGIN ]]` and `--[[ SKIN STUDIO END ]]` (`Config.SkinStudio.ExportMarkers`). Without an MCP, I paste those lines here.
3. Write each page, **exactly as received** (no reformatting), to `tests/out/skin-drafts/page-<n>.json` (git-ignored; clear old pages first).
4. Run `lune run tests/save-skins -- tests/out/skin-drafts --dry-run` (add `--only Id,Id` if I named skins). Show me the plan: which theme file, added or replaced, the rarity counts before and after, warnings, **economy changes** (rarity, crate or price of a skin players already own: they change what players own and the Robux crate odds) and anything refused with the reason. A page "damaged in copying" means: read that page again.
5. If I agree, run it again without `--dry-run`. Then `stylua src`, `selene src` and `lune run tests/run`.
6. A new skin changes its theme's rarity counts. Update `tests/specs/skins.spec.luau` (`COUNTS` / `NEWER_COUNTS` and the 630-ish total) and `tests/specs/crates.spec.luau` the way `/add-skin` step 6 says, and explain the new crate odds (`/add-skin` step 5). Changing an existing skin keeps the counts.
7. Fix test failures caused by the drafts, or tell me which draft breaks which rule (for example "a Common with a head piece"). Never weaken an unrelated test.
8. Catalog items: `save-skins` refuses an id that isn't in `Config.SkinCatalog.ApprovedIds`, and prints who made it (from the draft's lookups). Add an id there only when I say yes **and** the creator is Roblox, me or my group, with a comment naming the item, the creator and today's date.
9. Commit `Skin Studio: <n> skins` (only if I agree; never push unless I ask) and tell me which skins went in. Remind me the drafts are now in the game files, so Skin Studio shows them with ✓ next time.
