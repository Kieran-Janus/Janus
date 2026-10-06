# Custom art

Models saved here (as `.rbxm` / `.rbxmx`) appear in Studio under
`ReplicatedStorage > Custom > Characters`, `> Cosmetics` or `> Props`, and the game uses them
instead of the Part-built placeholders. Name each file after what it replaces, e.g.
`Characters/PumpkinKing.rbxm`, `Cosmetics/WitchHat.rbxm`, `Props/JackOLantern.rbxm`.

- `Characters/`: the King, minions and the Pumpkin Shop keeper (`PumpkinVendor`).
- `Cosmetics/`: hats, pets and skin head pieces, named after the shop item Id.
- `Props/`: pumpkins and decorations. One model reskins every copy in the lobby AND every
  round map at once: `Pumpkin`, `JackOLantern`, `CollectPumpkin` (King Hunt pickups),
  `HidingPumpkin` (Hide & Seek), `ParkourPumpkin`, `Lantern`, `Lamppost`, `HayBale`,
  `Gravestone`, `DeadTree`... The full table (what each is, where it appears, its size) is in
  `docs/CUSTOMIZE.md` > "Swap every copy of something at once". (In Studio, a built one shows
  its name in the attribute `PropName`.)

Hand-edited round maps don't go here: they live in `ServerStorage > Maps`, saved in the
`maps/` folder next to this one.

Full guide: `docs/CUSTOMIZE.md`.
