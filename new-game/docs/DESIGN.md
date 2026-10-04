# Game design: Pumpkin Panic (working title)

Halloween party game with proximity voice chat. Release target: **20 October 2026**. Written 4 October 2026 from the owner's answers; items marked **(assumed)** were not answered and need confirming.

## Pitch (assumed)
32 players run around a spooky-cute map collecting pumpkins and finishing party-style tasks while the **Pumpkin King** hunts them. Talk to nearby players with proximity voice, but the King can hear you. Survive the 5 minutes with the most pumpkins.

Different from the owner's other Halloween games (Survive Halloween, Nightmare Trick or Treat): the hook is voice, shouting draws the monster, and 32-player lobby chaos. **(assumed, confirm)**

## Fixed decisions
| Topic | Decision |
| --- | --- |
| Audience | Kids of any age. Voice is a bonus: the game must be fully fun with voice off (voice only works for eligible players) |
| Players | Up to 32 per server |
| Round length | 5 minutes |
| Win condition | Survive and collect items (pumpkins) |
| Difficulty | Players vote Easy or Hard each round |
| Monster | The Pumpkin King |
| Maps | Several; players vote for the next map |
| Art | Spooky-cute cartoon |
| Voice | Optional bonus, **proximity**, with effects in certain cases (e.g. muffled through walls) |
| Monster hears voice | Yes: loud nearby voice attracts the King |
| Dead players | Choose: spectate, ghost chat, or haunt (all three offered; player picks) |
| AI | None in MVP (see suggestions) |

## Core loop
- **30 seconds:** run, collect pumpkins, avoid the King.
- **5 minutes (a round):** vote map and difficulty, survive, deposit pumpkins, rewards.
- **Long term:** spend pumpkins on cosmetics, pets, emotes; buy VIP and pumpkin packs.

## Round flow
1. Lobby: players gather; voting UI for **map** and **difficulty** (Easy/Hard) opens for 20 s.
2. Intermission countdown and teleport to the winning map.
3. 300-second round. Pumpkins spawn around the map. Pumpkin King spawns and hunts.
4. Players who are caught become ghosts (see Dead players).
5. Round ends at 0:00 or when everyone is caught. Rewards: pumpkins collected convert to currency; survivors get a bonus.

## Pumpkin King (monster)
- Server-controlled NPC using pathfinding.
- Hearing: nearby voice volume and player sprint noise raise a "noise" score; King walks toward the loudest recent noise source.
- Easy vs Hard: speed, hearing range, number of Kings (Hard may add a second King), and pumpkins needed.
- Tunables go in `Config.King`.

## Voice chat
- Roblox Spatial Voice for proximity (enable in experience settings; voice eligibility is Roblox's rule, verify current requirements in the docs).
- Effects (verify API names against current Roblox audio docs before building): muffled voice through walls or when hiding in a closet; ghost echo for dead players; pitch-shift options as paid cosmetic voice effects.
- Ghost-only chat for dead players if feasible with the audio API; otherwise degrade gracefully to text-free spectating.
- Noise-to-monster mechanic must **never depend on voice**: sprint, pumpkin pickup and shouting emotes also make noise, so non-voice players are not at a disadvantage.
- All voice tuning (range, muffle strength, noise values) in `Config.Voice`.

## Economy
- **Pumpkins**: collected in-round, converted to the currency at round end. Also sold in packs via Developer Products.
- **Shop**: lots of cosmetics (costumes, hats, pets, trails, emotes, voice effects).
- **VIP gamepass**: cosmetics, chat tag, and the owner's chosen gameplay edge below.
- **Paid gameplay edge (owner's choice):** faster walking and a monster tracker.
  Recommendation: keep both modest (e.g. +10% speed; tracker shows King direction with a cooldown) so non-payers are not at a hard disadvantage. Make the numbers `Config.Monetization.*` so they can be tuned after launch.

## Maps
Players vote between 3 maps each round. MVP ships with **2 maps**, 3rd and 4th after launch:
1. Haunted Pumpkin Patch
2. Spooky Mansion
3. (post-launch) Graveyard Party
4. (post-launch) Candy Cave

Map definitions live in `Config.Maps` (name, thumbnail asset id, spawn points folder name).

## AI (optional, post-MVP suggestions)
- **Ghost announcer**: a short, filtered AI line for notable moments ("Pumpkin King just caught three players!"). Uses the AIService and Cloudflare proxy already in the repo.
- **Witch shopkeeper NPC** who answers questions and recommends items.
- **Daily quests** generated per player.
Not needed for 20 October. Do them only if M5 finishes early.

## Spawn hub (lobby): "Spooky Town Square"
Players spawn here between rounds. Spooky-cute, busy, and fun to stand around in.
- Decorations: jack-o-lanterns, bunting, cobwebs, tombstones, a crooked clock tower, fog, floating candles, ambient music.
- Interactive NPCs (all `Config.Npcs`): **Witch Wanda** (shop and cosmetics), **Boo Guide** (tutorial and tips), **Pumpkin Vendor** (buy pumpkin packs), **Voting Board** (map and difficulty votes), **Leaderboard Gravestone** (top pumpkin collectors).
- Photo spot with emotes, a trick-or-treat door minigame for small rewards (optional).
- Voice is on in the hub so players chat while waiting.

## Monsters
- **Pumpkin King**: the boss and main threat (M2).
- Minions that make maps feel alive (pick 3 for launch, keep numbers in `Config.Monsters`):
  - **Skeleton Patrol**: slow, walks fixed routes, blocks corridors.
  - **Bat Swarm**: fast but short range, flies in zig-zags.
  - **Ghost Cat**: steals a carried pumpkin if it touches you.
  - **Scarecrow**: freezes in place until you get close.

## Maps (upgrade from placeholders)
Each map needs: a distinct layout with hiding spots, shortcuts and risky pumpkin areas; lighting (Atmosphere, fog, ColorCorrection, Bloom); particle effects (fireflies, mist, falling leaves); ambient sound; a themed prop kit. MVP ships 2 maps, both properly decorated.

## Art plan (important)
Claude can build layout, gameplay, lighting, effects and scripts directly in Studio through the Studio connection, and can kitbash scenes from Parts. For *high-quality* spooky-cute models it needs assets: use the Creator Store (check each model for scripts and licence before using), Roblox's built-in mesh generation, or AI mesh tools (Meshy, Tripo) cleaned up in Blender. Treat any free model as untrusted: strip unexpected scripts.

## Milestones to 20 October (revised)
Dates assume starting 4 October. Cut scope rather than slip the release.

| # | Dates | Goal | Done when |
| --- | --- | --- | --- |
| M1 | done | Round loop, map and difficulty voting, pumpkins | Full round playable |
| M2 | done | Pumpkin King AI, catching, ghost state | 5-minute round with King works |
| M3 | 5-7 Oct | Proximity voice, muffle and ghost effects, noise-to-King link | Voice and non-voice players both play fine |
| M4 | 8-10 Oct | Spawn hub with decorations, NPCs, voting board, leaderboard | Hub looks alive and NPCs work |
| M5 | 11-14 Oct | Minion monsters, map art pass on 2 maps (lighting, particles, props, sound) | Maps feel finished |
| M6 | 14-16 Oct | Shop, pumpkins currency, saving (publish the place), VIP pass and products | Purchases work and data saves |
| M7 | 17-19 Oct | UI polish, thumbnails and icon, security audit (`prompts/06-review.md`), friends playtest | No critical bugs |
| Launch | 20 Oct | Set experience public | Live |

Publish a private build by M3 so you can test saving and voice, which only work on a published place. If time runs short, cut minion types first, then the trick-or-treat minigame, then the second map.

## Config sections to add
`Config.Voice`, `Config.King`, `Config.Maps`, `Config.Difficulty`, `Config.Pumpkins`, `Config.Shop`, `Config.Monetization`, `Config.Voting`. Keep every number there.

## Open questions
1. Final game name.
2. Confirm the pitch and how it differs from the existing Halloween games.
3. Party minigames (answer 1e): are they part of the round (short tasks) or separate modes? MVP assumes pumpkin collection is the "party task" and extra modes come later.
4. Teams or free-for-all? MVP assumes free-for-all.
