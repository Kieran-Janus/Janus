# AI NPC / AI feature

```
Add an AI NPC called [NAME] who [ROLE, e.g. runs the shop and gives hints about secrets].
- Add the persona to Config.AI.Npcs (short, kid-safe, in character, max 2 sentences per reply).
- Add a ProximityPrompt on the NPC model (tag it with CollectionService "AINpc") that opens a chat box on the client.
- The client calls Remotes.Function("AskNpc"); the server (AIService) enforces cooldown, length, and TextService filtering.
- Give the NPC game awareness: pass the player's coins / current round state as a short context line from the server (never from the client).
```

Other AI feature ideas to ask for: daily quests generated per player, AI event announcer for round results, pet/item name generator, tutorial coach that adapts to what the player is stuck on, support bot answering "how do I...".
