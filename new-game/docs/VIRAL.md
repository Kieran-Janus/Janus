# Making Pumpkin Panic go viral

Research done 4 October 2026. Sources at the bottom. Short version: **the hook is already right**. Roblox games where "the monster can hear your voice" are an established TikTok genre (Threshold, Silent Mansion, The Mimic). What decides whether this one spreads is (1) how many people who see the thumbnail actually play, (2) whether the first minute is fun, and (3) whether people come back and bring friends.

## How Roblox picks games for the Home page
Over 90% of players start on Home, which is driven by the "Recommended For You" algorithm. Since late 2025 it ranks on:

| Signal | What it means | What we do about it |
| --- | --- | --- |
| Play-through rate | % of people who see the tile and click Play | Thumbnail + icon + title (M7); A/B test thumbnails in Creator Hub |
| First-play bounce rate | People leaving after a short first session | Fun inside 30 s: no long waits, the Ready pad right in front of the spawn, lobby minigames while you wait, a round starts fast |
| Play days per user | How many different days people play | Daily streak rewards, codes, weekly updates, limited events |
| Playtime per user | Minutes per session | 5-minute rounds that chain, ghost modes so dead players stay |
| Intentional co-play | Players joining *with friends* (invites, private servers) | Invite button, friend bonus, private servers |
| D1 / D7 / D28 retention | Coming back after 1, 7, 28 days | Streak, unlock goals (shop), events, codes |
| Spend days / Robux | Days with purchases | Fair VIP + cosmetics, never pay-to-win |

## The viral loop for this game
1. **Clip moment:** a kid whispers, the Pumpkin King turns and charges. Players record and post it. The game should make this *easy to see*: a big readable "THE KING HEARD YOU!" moment, a voice-meter, ghost spectating of your friends.
2. **Search moment:** viewers search "Roblox pumpkin king voice game". Use those words in the title and description.
3. **First minute:** they land in a lively hub, a round starts within ~30 s, the King shows up within 15 s of the round. Never sit them in an empty lobby.
4. **Come back:** daily streak, codes from YouTubers, new cosmetic every update.
5. **Bring friends:** invite button, "play with friends" coin bonus, the game is funnier with friends on voice.

## What was built for this (overnight, see docs/PROGRESS.md)
- **Codes** (`Config.Codes`): redeemable codes for coins/items, with expiry dates. Give a code to every YouTuber/TikToker who covers the game; announce new codes with each update.
- **Daily streak** (`Config.Daily`): a reward each day you come back, bigger on day 3/7.
- **Invite button + friend bonus** (`Config.Social`): HUD button prompts Roblox's invite screen; players get extra coins per round for each friend in the server.
- **Favourite prompt**: after a player's first finished round, Roblox's "Add to favourites" prompt appears once. Favourites feed the algorithm and the player's Home page.
- **Character skins** (new shop tab) and a model swap system so every character can look unique (docs/CUSTOMIZE.md).

## Launch checklist (in order)
1. **Name:** pick a searchable title, e.g. "Pumpkin Panic 🎃 [VOICE CHAT]" or "Pumpkin King Hears You 🎃". Fix the "Haloween" typo.
2. **Description:** first line says the hook: "The Pumpkin King can HEAR you. Whisper, sprint and hide to survive 5-minute rounds with up to 32 players." Then features, then the current code.
3. **Icon:** the Pumpkin King's face, big, high contrast, no small text (`thumbnails/output/pumpkin-panic/`).
4. **Thumbnails:** at least 3 (King chasing kids; group of friends hiding; hub at night). Turn on thumbnail A/B testing in Creator Hub and keep the winner. Minimal text.
5. **Age guidelines questionnaire and genre/tags:** Horror (light), Party, Social.
6. **Voice:** Spatial Voice on (done in M3). Say "Voice chat optional" in the description so non-voice kids still join.
7. **Private servers:** enable (free or cheap). They count as intentional co-play.
8. **Soft launch** private to friends 1-2 days before 20 Oct; fix bugs; then public.
9. **Creators:** message 10-20 small Roblox horror/Halloween TikTokers and YouTubers with a personal code (e.g. `KIERAN50`). Small creators answer, and their audiences are the right age.
10. **Ads:** if you spend anything, spend it on the first 3-5 days after launch, when the algorithm is deciding.

## After launch: an update every week until Halloween, then every 2 weeks
- New cosmetic set + new code each update (update log on the in-game board).
- Halloween night (31 Oct) event: Blood Moon round, double pumpkins, limited "Midnight" cosmetic.
- Ideas with the best effort-to-virality ratio: a "Whisper mode" round where any talking is extra loud; a **Pumpkin King voice line** when he spots someone; a spectator **"Haunt cam"** for ghosts to watch friends; a third map (Graveyard Party); seasonal reskin for Christmas ("Krampus Panic") to keep the game alive after October.

## Sources
- [Roblox Recommended For You algorithm update (DevForum)](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575)
- [Improved Recommended For You and creator analytics (DevForum)](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441)
- [Roblox discovery docs](https://create.roblox.com/docs/discovery)
- [Why the discovery algorithm favors games that bring friends together](https://www.maxpowergaming.co/post/why-roblox-s-new-discovery-algorithm-favors-games-that-bring-friends-together)
- [TikTok: Roblox game where the monster can hear your voice chat](https://www.tiktok.com/discover/roblox-game-where-the-monster-can-hear-your-voice-chat)
- [TikTok: horror games with proximity chat](https://www.tiktok.com/discover/horror-game-with-proximity-chat)
- [Most popular Roblox games 2026 (Udonis)](https://www.blog.udonis.co/mobile-marketing/mobile-games/most-popular-roblox-games)
- [Roblox charts 2026 (EJAW)](https://ejaw.net/roblox-charts/)
- [Player invite prompts (Roblox docs)](https://create.roblox.com/docs/production/promotion/invite-prompts)
- [Thumbnail A/B testing improvements (DevForum)](https://devforum.roblox.com/t/improvements-to-thumbnail-ab-testing/3659601)
- [How Roblox content creators grow on YouTube and TikTok](https://rolearn.dev/insights/roblox-content-creator-growth-youtube-tiktok/)
