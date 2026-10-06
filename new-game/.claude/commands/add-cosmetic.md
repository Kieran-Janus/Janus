---
description: Add a new hat, pet, trail or skin to the shop. Usage: /add-cosmetic <describe it>
---

Add a new shop cosmetic: $ARGUMENTS

1. Read `CLAUDE.md`, `docs/CUSTOMIZE.md`, `src/shared/Cosmetics.luau` and `Config.Shop`.
2. Pick the Slot (Skin, Hat, Trail or Pet), a unique Id, a Name and a `Rarity` ("Common", "Uncommon", "Rare" or "Crazy"; the price comes from `Config.Rarity`, read it with `Items.Price(item)`; only add `Price = N` to override). VIP-only items: `VipOnly = true, Price = 0`. Crate skins (the 120 themed ones) go in a theme file in `src/shared/Config/Skins/`: use `/add-skin` for those.
3. For the look: if an existing builder fits, use it with new Style colours. Otherwise write a new Part-built builder in `src/shared/Cosmetics.luau` in the same spooky-cute style (smooth plastic, neon glow details), following the origin rules at the top of that file. If I named a model that's already in `ReplicatedStorage.Custom.Cosmetics`, use `Style = { Kind = "Custom" }`.
4. Add the item to `Config.Shop.Items` (in `src/shared/Config/init.luau`) in its slot's group. Run `lune run tests/run`.
5. Playtest: open the shop, check the preview, buy it (F8 > +Coins first), equip and unequip it. Check it on the character from the front and side.
6. Commit "Add cosmetic: <name>" and push. Tell me the Id, price and how to change its look later.
