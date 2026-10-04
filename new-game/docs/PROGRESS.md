# Milestone progress

The `/next-milestone` command reads this file. Update the Status column when a milestone is finished. Do not delete rows.

| # | Goal | Status | Needs the owner? |
| --- | --- | --- | --- |
| M1 | Round loop, map and difficulty voting, pumpkins | done | no |
| M2 | Pumpkin King, catching, ghost state | done | no |
| M3 | Proximity voice, muffle and ghost effects, noise-to-King link | done | publish + friend voice test |
| M4 | Spawn hub: decorations, NPCs, voting board, leaderboard | done | look at it, pick assets |
| M5 | Minion monsters (Skeleton Patrol, Bat Swarm, Ghost Cat) and map art pass on 2 maps | todo | pick Creator Store assets |
| M6 | Shop, pumpkin currency, saving, VIP pass and products | todo | create gamepass/product IDs in Creator Hub |
| M7 | UI polish, thumbnails and icon, security audit, playtest | todo | thumbnails, friends playtest |
| Launch | Set the experience public on 20 October | todo | yes: only the owner does this |

Status values: `todo`, `in progress`, `done`, `blocked` (add the reason in a note below).

## Notes
- M4: "Spooky Town Square" built from Parts by `src/server/Hub/HubBuilder.luau` (rebuilt at runtime only if `Workspace.Hub` is missing), with dusk lighting, particles, 5 NPCs plus a photo spot with emotes, a live Voting Board and a Leaderboard Gravestone; all tested in Studio. Save the place to keep the Studio copy. Hub lighting also darkens the maps, so M5 needs per-map lighting.
