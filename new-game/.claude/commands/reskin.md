---
description: Restyle a character, NPC, monster or lobby decoration. Usage: /reskin <who or what> <how it should look>
---

Restyle: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md` ("Builder mode" and "Swap a decoration everywhere: props") and `src/shared/CustomAssets.luau`.
2. Work out what it is and where its model goes:
   - A character: `PumpkinKing`, `SkeletonPatrol`, `Bat`, `GhostCat` or `PumpkinVendor` (the Pumpkin Shop keeper, the only shopkeeper since v2) -> `ReplicatedStorage.Custom.Characters`.
   - A cosmetic: its item Id from `Config.Shop.Items` or `src/shared/Config/Skins/` -> `ReplicatedStorage.Custom.Cosmetics`.
   - A decoration or feature prop (`JackOLantern`, `ClockTower`, `VendorStall`, `ParkourTrophy`, `CandyCane`, `EggGoldenPumpkin`, `PumpkinCrate`, `HidingPumpkin`, `ScareZombie`...; the full list is in `docs/CUSTOMIZE.md`, or read the `PropName` attribute in Studio) -> `ReplicatedStorage.Custom.Props`.
3. If I gave a Creator Store asset id or a model name, insert it through the Studio connection, strip scripts, name it exactly right and put it in the folder above. Otherwise build the new look in Studio from Parts/MeshParts as a Model (spooky-cute, readable silhouette, glowing eyes, never gory), with its front facing the pivot's LookVector, and put it there.
4. Also save it to git: export the model as `assets/<Characters|Cosmetics|Props>/<Name>.rbxmx` (XML, so diffs are readable) if the Studio connection can; otherwise tell me to right-click > Save to File.
5. Playtest and look at it in context (lobby or a round). Characters: adjust the size in `Config.Custom.Heights` if needed. The shopkeeper must pass its checks (visible, about the right height, seen over the counter) or the built one stays: read the Output.
6. Commit "Reskin <name>" and push.
