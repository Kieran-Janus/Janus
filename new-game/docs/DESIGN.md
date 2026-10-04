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

## Milestones to 20 October
Dates assume starting 4 October. Cut scope rather than slip the release.

| # | Dates | Goal | Done when |
| --- | --- | --- | --- |
| M1 | 4-6 Oct | Round loop with map voting, difficulty voting, pumpkins spawn and collect, round results | Full round playable solo in Studio |
| M2 | 7-9 Oct | Pumpkin King AI (pathfinding, hearing noise), catching, ghost/spectate state | A full 5-minute round with the King works with 2+ test players |
| M3 | 10-12 Oct | Proximity voice on, muffle and ghost effects, noise-to-King link | Voice and non-voice players both have a working round |
| M4 | 13-15 Oct | Shop, pumpkins currency, saving data (publish the place), VIP pass and products | Purchases work and data saves |
| M5 | 16-17 Oct | Second map, UI polish, sounds, thumbnails and icon | Everything looks release-ready |
| M6 | 18-19 Oct | Exploit/security audit (`prompts/06-review.md`), friends playtest, fix bugs | No critical bugs |
| Launch | 20 Oct | Set experience public | Live |

Publish a private build early (by M2) so you can test saving and voice, which only work on a published place.

## Config sections to add
`Config.Voice`, `Config.King`, `Config.Maps`, `Config.Difficulty`, `Config.Pumpkins`, `Config.Shop`, `Config.Monetization`, `Config.Voting`. Keep every number there.

## Open questions
1. Final game name.
2. Confirm the pitch and how it differs from the existing Halloween games.
3. Party minigames (answer 1e): are they part of the round (short tasks) or separate modes? MVP assumes pumpkin collection is the "party task" and extra modes come later.
4. Teams or free-for-all? MVP assumes free-for-all.
