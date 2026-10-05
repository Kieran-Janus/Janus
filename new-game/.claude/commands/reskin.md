---
description: Restyle a character, NPC or monster. Usage: /reskin <who> <how it should look>
---

Restyle: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` and `src/shared/CustomAssets.luau`.
2. Work out which character it is (PumpkinKing, SkeletonPatrol, Bat, GhostCat, PumpkinVendor (the Pumpkin Shop keeper), or a cosmetic Id).
3. If I gave a Creator Store asset id or a model name, insert it through the Studio connection, strip scripts, name it correctly and put it in `ReplicatedStorage.Custom.<Characters|Cosmetics>`. Otherwise build the new look in Studio from Parts/MeshParts as a Model (spooky-cute, readable silhouette, glowing eyes), with its front facing the pivot's LookVector, and put it in the same place.
4. Also save it to git: export the model as `assets/<Characters|Cosmetics>/<Name>.rbxmx` (XML, so diffs are readable) if the Studio connection can; otherwise tell me to right-click > Save to File.
5. Playtest and look at it in context (hub or a round). Adjust size in `Config.Custom.Heights` if needed.
6. Commit "Reskin <name>" and push.
