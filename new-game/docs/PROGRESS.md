# Milestone progress

The `/next-milestone` command reads this file. Update the Status column when a milestone is finished. Do not delete rows.

| # | Goal | Status | Needs the owner? |
| --- | --- | --- | --- |
| M1 | Round loop, map and difficulty voting, pumpkins | done | no |
| M2 | Pumpkin King, catching, ghost state | done | no |
| M3 | Proximity voice, muffle and ghost effects, noise-to-King link | done | publish + friend voice test |
| M4 | Spawn hub: decorations, NPCs, voting board, leaderboard | done | look at it, pick assets |
| M5 | Minion monsters (Skeleton Patrol, Bat Swarm, Ghost Cat) and map art pass on 2 maps | done | pick Creator Store assets |
| M6 | Shop, pumpkin currency, saving, VIP pass and products | blocked | create gamepass/product IDs in Creator Hub |
| V1 | Verify the overnight cloud work in Studio (run `/verify`): skins tab, custom models, codes, daily streak, invite, F8 admin panel, anti-teleport pumpkins | todo | no |
| M7 | UI polish, thumbnails and icon, security audit, playtest | in progress | upload thumbnails, friends playtest |
| Launch | Set the experience public on 20 October | todo | yes: only the owner does this |

Status values: `todo`, `in progress`, `done`, `blocked` (add the reason in a note below).

## Notes
- M4: "Spooky Town Square" built from Parts by `src/server/Hub/HubBuilder.luau` (rebuilt at runtime only if `Workspace.Hub` is missing), with dusk lighting, particles, 5 NPCs plus a photo spot with emotes, a live Voting Board and a Leaderboard Gravestone; all tested in Studio. Save the place to keep the Studio copy. Hub lighting also darkens the maps, so M5 needs per-map lighting.
- M5: `MinionService` adds Skeleton Patrols (slow + knockback + noise), Bat Swarms (zig-zag dart, slow) and Ghost Cats (steal a pumpkin that drops back later), all in `Config.Monsters`. Both maps are now themed builds in `src/server/Maps/` (Pumpkin Patch: corn maze, barn shortcut, risky pumpkin field, graveyard; Mansion: 9 furnished rooms, secret doors the King can't path through) with hiding spots, jump fences, hotspots, glowing pumpkins, particles and per-map lighting/ambient sound switched on the client (`ZoneLighting`); tested Easy and Hard in Studio. Still Part-built art: the owner can swap in Creator Store models and set `AmbientSound.SoundId` per map.
- M6: Witch Wanda's shop (B key, Shop button, Witch Wanda, Pumpkin Vendor) sells 12 Part-built hats, trails and pets (`Config.Shop`, `src/shared/Cosmetics.luau`); buying/equipping is server-validated in `ShopService` and saved (Owned, Equipped). `MonetizationService` handles the VIP gamepass (+10% speed, King tracker on T, chat tag, 3 VIP-only cosmetics) and 3 coin packs with receipt-safe granting. Saving tested in Studio across sessions; all IDs are 0, so Robux buttons show "Coming soon".
- **M6 blocked: owner steps.** In Creator Hub (create.roblox.com) > this experience > Monetization:
  1. Passes > Create a Pass named "VIP" (icon optional) > set it On Sale with a price (suggested 249 Robux). Copy its Pass ID into `Config.Monetization.VipGamePassId`.
  2. Developer Products > create "Pumpkin Pouch" (suggested 25 R$), "Pumpkin Cart" (99 R$) and "Pumpkin Mountain" (249 R$). Copy each Product ID into the matching `Id` in `Config.Monetization.Products`.
  3. Publish the place (File > Publish to Roblox) and test one purchase in a live server: Studio test purchases don't charge but also don't prove ProcessReceipt on Roblox's servers.
  Then set this row to `done`. Real prices are whatever you set in Creator Hub; the shop reads them live.
- **Overnight (cloud session, not yet run in Studio):** written and statically checked (luau-lsp with Roblox types, StyLua, Rojo build), but nobody has pressed Play on it yet, so V1 must run first.
  - Customisation: `src/shared/CustomAssets.luau` + `assets/` → `ReplicatedStorage.Custom` (ignoreUnknownInstances). Custom models replace the King (plain model or animated R15 rig), minions, the Witch/Boo/Vendor NPCs (also on a hub saved in Studio) and any cosmetic. Guide: `docs/CUSTOMIZE.md`.
  - New Skins shop tab (Skeleton, Pumpkin Head, Zombie, Ghost, Mummy, VIP Pumpkin King): recolour, hide clothes, head pieces; restores the avatar when removed; hats sit on top of head pieces.
  - Viral features (`docs/VIRAL.md`): Codes (button above Shop; `Config.Codes`), daily streak toast (`Config.Daily`), +10% round coins per friend in the server (cap 50%) and optional group bonus (`Config.Social`), Invite button, one-time favourite prompt after the first round.
  - F8 admin panel in Studio (`AdminService`, `AdminUI`).
  - M7 security audit done; fixes: pumpkin anti-teleport check, AI chat off until it has a UI plus a whole-server request cap, vote spam guard 0.5 s, admin check uses the server-set attribute, three small leaks on players leaving mid-load.
  - M7 art: `thumbnails/output/pumpkin-panic/thumbnail-1920x1080.png` and `icon-512x512.png` (`ONLY=pumpkin-panic node thumbnails/render.mjs` to re-render).
  - Fixed `stylua.toml` (the `syntax` key broke StyLua 0.20, the pinned version).
  - Clip moment: "THE KING HEARD YOU!" banner + flash when the King turns to your noise; nearby players see "The King heard X!" (`Config.King.Heard`, `KingHeardUI`).
  - Skins re-apply after `CharacterAppearanceLoaded` so late-loading clothes don't cover them.
  - Claude Code commands added: `/verify`, `/add-cosmetic`, `/reskin`, `/add-npc`, `/add-monster`, `/add-map`, `/new-code`, `/new-event`, `/tweak`, `/polish-hub`.

