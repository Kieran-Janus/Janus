# Crate luck, pack guarantees and Deluxe crates: build spec

Written 14 October 2026 on branch `claude/clever-clarke-3zqgma` (base `3115265`) from Kieran's request about the Mystery Crates (Menu > Crates):

1. New base odds for every themed crate: Rare 15% (it was 2.5%), Uncommon stays 24%, CRAZY stays 0.02%, and Common drops to 60.98%. One-in-a-million skins keep their exact 0.0001%.
2. *"Make the odds higher the more you spend on them."* Kieran chose all three ways: a **luck meter**, **bigger packs** and **premium crates**.

This is the contract the builder follows. Paths are relative to `new-game/`. Kieran's plain-English guide goes in `docs/CUSTOMIZE.md` > "Crates" and `docs/V2-CHANGES.md` (section 11 lists both).

The game is for kids, and crates are paid random items. These hard rules apply everywhere:
- Every chance a player can get is shown as an exact number before they buy. That includes their luck-boosted odds and any pack guarantee.
- The server rolls with exactly the numbers the player was shown. It reads them from the saved data, never from the client.
- No fake near misses, no timers, no pressure, and no hidden changes to the odds.
- Players in regions where PolicyService restricts paid random items still can't buy.
- Robux receipts stay idempotent.

## 0. In plain English (for Kieran)
- **Better odds for everyone.** Every themed crate is now Common 60.98%, Uncommon 24%, Rare 15% (it was 2.5%) and CRAZY 0.02%. The three one-in-a-million skins keep exactly 0.0001%.
- **Luck meter.** Each themed crate has its own meter for each player, and it is saved.
  - Every crate that gives a Common or an Uncommon fills one step. Each step adds +2% to Rare, taken from Common.
  - A Rare or better empties the meter.
  - 15 steps is a full meter: the next crate is Rare or better for sure. So nobody ever opens more than 15 of the same crate in a row without a Rare: the 16th is always Rare or better.
  - The crate's page shows the meter and the exact chance of every skin in your next crate. An "Every chance" button lists the chances at every step.
- **Packs.** x5 always includes at least one Uncommon or better, and x10 at least one Rare or better.
  - A pack opens like that many single crates, one after another. The meter moves after each crate.
  - If the crates before the last one haven't given that rarity, the last crate can only give that rarity or better.
  - A small "Open 10?" window explains this and shows the exact chances first.
- **Deluxe crates.** The six classic crates get a Deluxe version, on a new "Deluxe" tab.
  - Same skins, for 2,000 coins.
  - No Commons: Uncommon 50%, Rare 49%, CRAZY 1%. That CRAZY chance is 50 times the normal crate's.
  - Coins only for now: the Robux button says "Coming soon" until you make products in Creator Hub.
  - They are not on the lobby stand.
- **Honest.** Every chance shows as an exact number (no more "<1%"). The server rolls with exactly the numbers on screen.
  - If your luck changed since the page was drawn (a Robux crate finished, or an F8 button was used), nothing is bought. The page redraws with the new numbers and says so.
  - No timers, no "so close!", and luck never runs out.
- **Still a gamble, not a cheap shop.** On average a themed crate gives a Rare every 4.8 opens (about 2,860 coins per Rare; the Rare Crate costs 800 and the Shop 1,000) and a CRAZY every 5,000 opens (about 3 million coins; the CRAZY Crate costs 80,000). A Deluxe CRAZY costs about 200,000 coins on average, twice its Shop price. Section 6 has every number.
- **Switches.** `CrateLuck`, `CratePacks` and `PremiumCrates` in `Config.Features` turn each part off on its own.

## 1. Key decisions
| # | Decision | Why |
| --- | --- | --- |
| D1 | Base odds `{ Common = 60.98, Uncommon = 24, Rare = 15, Crazy = 0.02 }`. | Kieran's numbers. 60.98 + 24 + 15 + 0.02 = 100. |
| D2 | **Luck meter:** +2% Rare (from Common) for each crate below Rare, 15 steps. A full meter makes the next crate Rare or better for sure. A Rare or better resets the meter to 0. | Small steps ("a bit"), a hard limit kids understand (at most 16 opens for a Rare), and sane economics: on average 1 Rare in 4.76 opens. Only 0.52% of streaks ever reach a full meter. |
| D3 | Luck never raises CRAZY or Uncommon. | CRAZY duplicates refund 50,000 coins and the CRAZY Crate costs 80,000, so CRAZY odds must stay tiny. A guaranteed crate rescales CRAZY a little (D5); section 6 shows that is harmless. |
| D4 | Only **themed crates** have a meter. Rarity crates and Deluxe crates don't, and a crate line with `Luck = false` has none either. | A rarity crate is 100% one rarity anyway. Deluxe odds are already boosted and stay one fixed, easy-to-read set. |
| D5 | **One guarantee rule**, used everywhere (`AtLeast`): rarities below the guaranteed one drop out, and the rest keep their proportions, scaled up to 100%. This is exactly "rolled again until it is that rarity or better". The full meter and both pack guarantees use it. | It reuses `scaledOdds`, which already drops rarities a crate has no skins of. Fixed-odds skins keep their exact chance. |
| D6 | **A pack is N single opens in a row plus a last-crate guarantee.** The meter moves after every crate, in order. | No loophole: a pack "frozen" at a full meter would give 10 guaranteed Rares for 6,000 coins, cheaper than 10 Rare Crates. Every crate's odds are also one row of the "Every chance" table, so all of them can be shown exactly before buying. |
| D7 | **The guaranteed last crate's luck is known in advance.** The guarantee only applies when every earlier crate was below the guaranteed rarity, which means below Rare too, so the meter went up by one each time. Its level is `min(L0 + N - 1, Steps)`, where L0 is the level when the player pressed the button. The confirm window prints its exact chances. | The guarantee can be shown exactly without listing every possible path through the pack. |
| D8 | **Shown-odds check.** The client sends the luck level it displayed. The server compares it with the level in the save. If they differ it takes no coins, refuses the purchase and sends the real level back. The client's number is never used to roll. | The server rolls with the numbers on screen, and decides everything itself. |
| D9 | The luck levels reach the client inside **ShopState** (`State.CrateLuck`). | `ShopService.Push` already runs after every crate grant (coins, Robux, F8), so no new event is needed. |
| D10 | **Exact odds everywhere.** `CrateOdds.Format` shows 3 decimals with trailing zeros removed. Tiny chances keep every digit that matters. A chance is never rounded to "0%" or "100%". `SmallOdds` ("<1%") is removed. | "Shown exactly" was the compliance gap noted in the code review. |
| D11 | **"Open another" no longer buys.** It becomes "Open again" and returns to the crate's page, which shows the new odds. | The odds may have changed with that open, so the next purchase must start from a page that shows them. |
| D12 | **Robux:** a new `PrepareCrateRobux` remote checks the shown level before the Roblox purchase window opens. The server then refuses coin opens of that crate until the receipt is granted or cancelled. `Grant`'s undo restores the luck when a save fails. | Robux opens use and move the meter like coin opens, and a receipt can arrive late or be retried. |
| D13 | **Deluxe crates** are built from one `Config.Crates.Premium.Crates` line each (`Id`, `Base`, `ProductId`), with the skins of `Base`. They cost 2,000 coins and are coins-only (`ProductId = 0`). | Config-driven: one line adds a Deluxe crate. The same skins means no catalogue work. |
| D14 | x5 and x10 always ask first ("Open Pumpkin Crate x10?"). There is no setting to skip it. | Packs cost 3,000 to 20,000 coins (800,000 for a CRAZY Crate x10), and the window is where the pack rules and the guaranteed crate's exact chances are shown, so it can't be optional. |

## 2. New base odds and every place the old numbers live
### 2.1 Config
`src/shared/Config/Crates.luau`, line 97:
```lua
	-- The chance of each rarity (percent) for every themed crate without its own Odds. Must add
	-- up to 100. Rarity names are the ones in Config/Rarity.luau. (Rare went up from 2.5 to 15
	-- in October 2026; Common went down to make room.) The luck meter (Luck below) moves some
	-- of Common to Rare for each player.
	Odds = { Common = 60.98, Uncommon = 24, Rare = 15, Crazy = 0.02 } :: { [string]: number },
```
Remove `SmallOdds` and its comment (lines 98-100). In its place:
```lua
	-- Chances always show as exact numbers on the crate page ("5.082%", "24%", "0.02%",
	-- "0.0001%"): a Roblox rule for paid random items, so there is no setting to round them.
```

### 2.2 Exact formatting (`src/shared/CrateOdds.luau`)
`CrateOdds.Format(percent)` works like this:
- 0 or less shows "0%", and 100 or more shows "100%".
- Under 0.001 it returns `Exact(percent)`, which keeps every digit that matters ("0.0001%", "0.00025%").
- Otherwise it formats with 3 decimals and removes trailing zeros and a trailing dot ("5.082%", "24%", "4.8%", "0.02%", "15.02%").
- If the rounded text reads 100 while the chance is under 100, it adds decimals (up to 6) until it doesn't ("99.9999%").

`Exact` stays as it is (the tests use it). In CrateUI, `richEscape` stays (it is harmless), but its comment no longer mentions "<1%".

### 2.3 Every place that hard-codes or quotes the old numbers
| Where | Today | Becomes |
| --- | --- | --- |
| `src/shared/Config/Crates.luau` header, lines 9-21 | "Common 73.48 means 73.48 in 100 opens"; "12 Commons share 73.48% (6.123% each), 5 Uncommons share 24% (4.800% each), 2 Rares share 2.5% (1.250% each) and its one CRAZY skin has 0.020%"; "Rare and CRAZY were made rarer in the big skin update (Rare 5% -> 2.5%, CRAZY 0.1% -> 0.02%)" | "Common 60.98 means 60.98 in 100 opens"; "12 Commons share 60.98% (5.082% each), 5 Uncommons share 24% (4.8% each), 2 Rares share 15% (7.5% each) and its one CRAZY skin has 0.02%"; "Rare went up to 15% in October 2026 (it was 2.5%); CRAZY stays 0.02%". Add a pointer: "LUCK, PACKS AND DELUXE CRATES: see Luck, Open.Guarantee and Premium below (docs/CRATE-LUCK-SPEC.md)". |
| Same header, "Prices" paragraph, lines 57-66 | "One open is worth about 257 coins at shop prices (0.7348 x 125 + 0.24 x 500 + 0.025 x 1000 + 0.0002 x 100000)" | "One open is worth about 366 coins at shop prices (0.6098 x 125 + 0.24 x 500 + 0.15 x 1000 + 0.0002 x 100000), about 418 on average with the luck meter. A player who already owns everything gets back about 208 in duplicate coins, so a crate never pays for itself. Deluxe crates: 2,000 coins, worth about 1,740." |
| Same file, line 97 and lines 98-100 | `Odds` 73.48/24/2.5/0.02 and `SmallOdds = "<1%"` | Section 2.1. |
| Same file, `Text.OpenAnother` | "Open another" | "Open again" (section 7.4). |
| `src/shared/CrateOdds.luau` header, line 26 | `Format(percent) -> string "0.100%", or "0.0001%" for tiny chances` | `Format(percent) -> string  exact: "5.082%", "24%", "0.02%", "0.0001%"`. Also document `Boost` and the new arguments (section 3.4). |
| `src/shared/CrateOdds.luau`, lines 280-293 | The `SmallOdds` comment and branch | Section 2.2. |
| `src/client/CrateUI.luau`, line 185 | A comment about "<1%" needing "&lt;" | "RichText: escape <, > and &." |
| `src/client/CrateUI.luau`, line 915 | `"CRAZY <1%  Rare 2.5%  Uncommon 24%  Common 73.5%"` | `"CRAZY 0.02%  Rare 15%  Uncommon 24%  Common 60.98%" (for your next crate)` |
| `src/client/CrateUI.luau` header, lines 13-21 | "% chance", "Open another" | Exact chances, luck strip, "Every chance", the pack window and "Open again". |
| `tests/specs/crates.spec.luau`, lines 40-44 | `73.48`, `2.5` "(was 5)", `0.02` | `60.98`, `24`, `15` "(was 2.5)", `0.02` |
| Same file, lines 130-142 | `Format(chances[1].Chance) == "<1%"`, `Exact(73.48/12) == "6.123%"`, `Format(73.48/12) == "6.1%"`, `Format(0.5) == "<1%"` | `Format(...) == "0.02%"`, `Exact(60.98/12) == "5.082%"`, `Format(60.98/12) == "5.082%"`, `Format(24) == "24%"`, `Format(4.8) == "4.8%"`, `Format(0.5) == "0.5%"`, `Format(0.0001) == "0.0001%"`, `Format(99.9999) == "99.9999%"`, `Format(100) == "100%"`. Keep the `Exact` checks. |
| Same file, line 196 | one-in-a-million `Format == "<1%"` | `"0.0001%"` |
| Same file, lines 976-1001 (the RichText odds line) | Expects `"&lt;1%"` in the Pumpkin line | No `&lt;` anywhere; the Pumpkin line contains `CRAZY 0.02%`, `Rare 15%`, `Uncommon 24%`, `Common 60.98%`. The comment "e.g. Rare 2.5%" becomes "e.g. Rare 15%". |
| Same file, lines 1024-1025 and the VampireCastle check | `"6.1%"`, `"<1%"`, `"<1%"` | `Pumpkin_PumpkinSpice` `"5.082%"`, `Pumpkin_MegaGourdSupreme` `"0.02%"`, `VampireCastle_NightLordSupreme` `"0.0001%"` |
| `docs/CUSTOMIZE.md`, lines 800-806 | The odds bullet with 73.48, "6.123%", "<1%", `SmallOdds` | Section 11. |
| `docs/V2-CHANGES.md`, lines 162, 163, 224 and 419 | 73.48 / 24 / 2.5 / 0.02, "6.1%", "<1%", `SmallOdds` | The new numbers, exact display, and a pointer to the new section (section 11). |
| `docs/V2-CHANGES.md`, line 531 (Robux crates) | "All 34 crates have a Robux slot" | Add: "Deluxe crates have a Robux slot too (`Config.Crates.Premium.Crates`, `ProductId`), 'Coming soon' until you fill it in." |
| `.claude/commands/add-skin.md`, line 14 | "its 5.833% Common chance" (already stale) | "its 5.082% Common chance" |
| `.claude/commands/verify-v2.md`, lines 53-55 | "lists 10 crates", "5.833% / 4.980% / 2.500% / 0.100%", "coins go down by 300", "all ProductIds are 0" | 22 crates (16 + 6 Deluxe with 12 themes on); "each Common 5.082%, each Uncommon 4.8%, each Rare 7.5%, the CRAZY 0.02%"; coins go down by 600; the luck strip moves; themed crates have real product ids, Deluxe ones say "Coming soon". |
| `.claude/commands/add-crate.md`, line 12 | "themed crates are 300" | "themed crates are 600". Add a step: "a Deluxe version is one line in `Premium.Crates`". |
| `tests/README.md`, line 42 (the `crates.spec` row) | No luck, packs or Deluxe | Mention exact odds, and add a row for `crates-luck.spec` (section 10). |

`src/shared/Config/Rarity.luau`'s `DuplicateRefund` comment ("a duplicate Rare almost the whole crate") is still true (500 of 600). No change.

## 3. Luck meter
### 3.1 Rules
- **Per player, per crate Id.** Saved in `data.Crates.Luck[crateId]` as a whole number from 0 to `Steps`. 0 is not stored.
- **Which crates:** `CrateLuck.Applies(crate)` is true when all of these hold:
  - `Config.Features.CrateLuck` is on;
  - the crate has no `Rarity` (not a rarity crate);
  - it has no `Base` (not Deluxe);
  - its line doesn't say `Luck = false`.
- **A crate rolled at level L** uses these odds:
  - Common loses `a = min(L, Steps) × PerStep`, and Rare gains it. This is applied to the crate's configured odds before rarities without skins drop out and the rest are scaled. If Common has less than `a`, only what Common has moves.
  - Uncommon, CRAZY and fixed-odds skins don't change.
- **Full meter.** At L = `Steps` with `FullGuarantee` on, the crate also gets `AtLeast = "Rare"` (D5).
- **After each crate** (each one counts, in order, also inside a pack):
  - Rare or better: L becomes 0.
  - Anything below Rare: L becomes `min(L + 1, Steps)`.
- **What moves the meter.** Coin opens, Robux opens, packs (crate by crate) and the F8 free crate (Studio admin) all count. Nothing else changes it. It never decays, expires, depends on time or is changed by the server on its own.
- **Steps lowered in Config.** Saved levels above the new `Steps` read as `Steps`, which is a full meter. The docs say so.

### 3.2 Config (`src/shared/Config/Crates.luau`, after `Odds`)
```lua
	-- LUCK METER (switch: Config.Features.CrateLuck). Each player has a meter for each themed
	-- crate (saved). Every crate that gives something below Rare fills one step: Rare gets
	-- PerStep % more and Common PerStep % less, for that player's next crate of that kind.
	-- A Rare or better empties the meter. A full meter (Steps steps) makes the next crate Rare
	-- or better for sure (FullGuarantee). The crate page always shows the meter and the exact
	-- chance of every skin for the next crate, and "Every chance" lists every step.
	-- Rarity crates and Deluxe crates have no meter (nor does a crate line with Luck = false).
	-- Keep Steps x PerStep at or below Odds.Common (the tests check it).
	Luck = {
		PerStep = 2, -- percent moved from Common to Rare per step
		Steps = 15, -- steps in a full meter
		FullGuarantee = true, -- true = a full meter makes the next crate Rare or better for sure
		Boost = "Rare", -- the rarity the meter raises (getting this or better empties it)
		TakeFrom = "Common", -- the rarity the extra chance is taken from
		-- After pressing a Robux button, coin opens of that crate wait this long (seconds) for
		-- Roblox's purchase window, so the Robux crate rolls with the luck you saw.
		RobuxHoldSeconds = 60,
	},
```
Add `Luck: boolean?` to `export type Crate`, with the comment `-- false = no luck meter for this crate`.

### 3.3 Saved data (`src/shared/Config/init.luau`, `Data.Template`, line 1683)
```lua
			-- Crates opened (ever) and each themed crate's luck meter ([crate Id] = steps, 1 to
			-- Config.Crates.Luck.Steps; a crate with no line is at 0).
			Crates = { Opened = 0, Luck = {} :: { [string]: number } },
```
`DataService.fromSave` merges `Crates` one level deep, so an old save simply has no `Luck` and gets `{}`. A saved `Luck` arrives unchecked, so it is cleaned:
- **On every read**, `CrateLuck.Get` uses `CrateLuck.Clamp`: a number that isn't finite, or anything that isn't a number, counts as 0. A finite number is floored and clamped to 0..`Steps`.
- **On every write**, `CrateLuck.Set` puts `{}` in place of a non-table `data.Crates` or `data.Crates.Luck`. It keeps at most 64 entries: string keys of up to 64 characters with whole-number values 1..Steps. It drops the rest and stores nil for 0.
- `Grant`'s existing repair `data.Crates = { Opened = 0 }` becomes `{ Opened = 0, Luck = {} }`.

Luck lives in the same save blob as coins and skins, so a crash rolls them back together and never leaves them inconsistent. A Rare or better triggers the save that already happens straight away (`SaveRightAway`), and that save includes the reset.

### 3.4 The odds maths
**`src/shared/CrateOdds.luau`** (shared; it does not require CrateLuck):
```lua
export type Boost = {
	Shift: { [string]: number }?, -- percent added to (negative: taken from) each rarity's odds
	AtLeast: string?, -- only this rarity or better: lower rarities drop out, the rest scale up
}
```
- `configuredOdds(crate, boost?)` copies the configured odds. It adds each `Shift` (never going below 0). If `AtLeast` is set and `CanGuarantee` holds, it sets every rarity below `AtLeast` to 0. `scaledOdds` then works exactly as today.
- `scaledOdds`, `RarityOdds`, `Chances`, `Roll` and `Reel` take an optional last argument `boost: Boost?`. With nil they behave exactly as today. `Reel` draws its strip, including the TeaseGuard cards, from `Chances(crate, boost)`: the odds actually rolled.
- `CrateOdds.CanGuarantee(crate, rarity) -> boolean` is true when some rarity at or above `rarity` has both configured odds above 0 and at least one shared (not fixed-odds) skin in the crate. If it is false, `AtLeast` is ignored and the UI promises nothing (for example, x10 on the Common Crate).
- Fixed-odds skins (the one-in-a-million ones, `item.Odds`) keep exactly their chance under every boost. They are CRAZY, so they are never below an `AtLeast`. The tests check this.
- **Deluxe:** `local source = crate.Base or crate.Id`. `Items(crate)` uses `item.Crate == source`, and `fixedOdds` does too, so a one-in-a-million skin would keep its 0.0001% in a Deluxe crate as well.
- `CrateOdds.Available(crate) -> boolean` is false for a crate with `Base` while `Config.Features.PremiumCrates` is off. `Get` and `List` skip crates that aren't available. `ByProductId` still finds them, so a receipt pays the coin fallback (section 5.5).
- `CrateOdds.Higher(a, b) -> string?` returns the higher of two rarity names (either may be nil).
- `Format` changes as in section 2.2.

**New `src/shared/CrateLuck.luau`** (shared, pure functions; it requires Config and CrateOdds):
```
CrateLuck.Applies(crate) -> boolean                 section 3.1
CrateLuck.Steps() -> number                         max(1, floor(Config.Crates.Luck.Steps))
CrateLuck.Clamp(value: unknown) -> number           whole number 0..Steps (junk -> 0)
CrateLuck.Get(data, crate) -> number                server: the saved level (0 if not Applies)
CrateLuck.Set(data, crate, level)                   server: stores it, cleaning the table (3.3)
CrateLuck.Snapshot(data) -> { [crateId]: number }   non-zero levels of available crates where it
                                                    applies; {} when CrateLuck is off. Iterates
                                                    CrateOdds.List(), so junk keys never leave
                                                    the server
CrateLuck.Boost(crate, level, atLeast?) -> Boost?   the boost for one roll: the luck shift, the
                                                    full-meter guarantee and a pack guarantee
                                                    (the higher of the two); nil = plain odds
CrateLuck.After(crate, level, rarity) -> number     the level after a crate gave `rarity`
CrateLuck.Guarantee(crate, count) -> string?        Open.Guarantee[count] while CratePacks is on
                                                    and CrateOdds.CanGuarantee(crate, it); else nil
CrateLuck.PackLevel(crate, level, count) -> number  level of the guaranteed last crate:
                                                    min(level + count - 1, Steps) when Applies, else 0
```
`Boost`, in full:
```lua
function CrateLuck.Boost(crate, level, atLeast: string?): CrateOdds.Boost?
	local cfg = Config.Crates.Luck
	local shift = nil
	if CrateLuck.Applies(crate) then
		local l = CrateLuck.Clamp(level)
		local base = if type(crate.Odds) == "table" then crate.Odds else Config.Crates.Odds
		local amount = math.min(l * cfg.PerStep, base[cfg.TakeFrom] or 0)
		if amount > 0 then
			shift = { [cfg.TakeFrom] = -amount, [cfg.Boost] = amount }
		end
		if cfg.FullGuarantee and l >= CrateLuck.Steps() then
			atLeast = CrateOdds.Higher(atLeast, cfg.Boost)
		end
	end
	if atLeast and not CrateOdds.CanGuarantee(crate, atLeast) then
		atLeast = nil
	end
	if shift == nil and atLeast == nil then
		return nil
	end
	return { Shift = shift, AtLeast = atLeast }
end
```
The UI and the server call **this same function** with the same level. That is what makes the shown odds and the rolled odds identical.

### 3.5 Worked example: the Pumpkin Crate (12 Common, 5 Uncommon, 2 Rare, 1 CRAZY)
Uncommon is 4.8% each and CRAZY 0.02% at luck 0 to 14.

| Luck | Common each | Rare each | Rare or better |
| --- | --- | --- | --- |
| 0 | 5.082% | 7.5% | 15.02% |
| 1 | 4.915% | 8.5% | 17.02% |
| 2 | 4.748% | 9.5% | 19.02% |
| 3 | 4.582% | 10.5% | 21.02% |
| 4 | 4.415% | 11.5% | 23.02% |
| 5 | 4.248% | 12.5% | 25.02% |
| 6 | 4.082% | 13.5% | 27.02% |
| 7 | 3.915% | 14.5% | 29.02% |
| 8 | 3.748% | 15.5% | 31.02% |
| 9 | 3.582% | 16.5% | 33.02% |
| 10 | 3.415% | 17.5% | 35.02% |
| 11 | 3.248% | 18.5% | 37.02% |
| 12 | 3.082% | 19.5% | 39.02% |
| 13 | 2.915% | 20.5% | 41.02% |
| 14 | 2.748% | 21.5% | 43.02% |
| 15 (full) | 0% (Uncommon 0%) | 49.978% | 100% (CRAZY 0.044%) |

The newer crates have no ordinary CRAZY skin, so their odds are scaled over 99.98:
- **Zombie Town** (13/5/3) at luck 0: Common 60.992% (13 × 4.692%), Uncommon 24.005% (5 × 4.801%), Rare 15.003% (3 × 5.001%). Full meter: Rare 100% (3 × 33.333%).
- **Vampire Castle**: Night Lord Supreme is 0.0001% at every step. At luck 0 Rare is 15.003%; a full meter gives Rare 99.9999% (3 × 33.333%).

### 3.6 Server (`src/server/Services/CrateService.luau`)
- **`CrateService.Grant(player, crate, paid, atLeast: string?) -> (Result?, undo)`**:
  ```
  level   = CrateLuck.Get(data, crate)
  boost   = CrateLuck.Boost(crate, level, atLeast)
  chances = CrateOdds.Chances(crate, boost)
  item    = CrateOdds.Pick(chances, rng:NextNumber())        -- (nil -> return nil, noUndo)
  ...ownership / refund / Opened as today...
  after   = CrateLuck.After(crate, level, rarity)
  CrateLuck.Set(data, crate, after)
  result.Luck = level; result.LuckAfter = after
  result.Guaranteed = boost and boost.AtLeast or nil
  result.Reel = CrateOdds.Reel(crate, item.Id, rng, reel.Cards, winIndex, boost)
  undo(): today's undo, plus CrateLuck.Set(data, crate, level)
  ```
- **`onOpen(player, crateId, countIn, shownLuck)`** runs these checks in order. Steps 1-7 are today's, in today's order.
  1. The id is a string of at most 64 characters.
  2. `Features.Crates` is on, else "Closed".
  3. The count is nil or in `Open.Counts`, else "NoCrate".
  4. The cooldown has passed (set before the remaining checks, as today).
  5. `CrateOdds.Get` finds the crate (this now respects `PremiumCrates`), with a price and items.
  6. The policy check: nil gives "StillChecking", true gives "Restricted".
  7. The save is loaded.
  8. **Robux hold:** if this player has a live hold on this crate, fail with `Text.RobuxFirst`.
  9. **Shown luck:** `typeof(shownLuck) == "number" and shownLuck == CrateLuck.Get(data, crate)`. Otherwise fail with `Text.OddsChanged` and `Luck = <current level>`, and take no coins. Crates without a meter expect 0, so a missing or nil value is always refused.
  10. `Spend(price * count)`, else "NoCoins".
  11. Open the crates (section 4.3).
  12. Refund crates that weren't granted, save if any is Rare or better, Push, and return. All as today.
- **`CrateService.Luck(player, crateId) -> number`** returns the current level (0 if unknown). Tests and F8 use it.
- The result of a refusal can now carry `Luck`. `fail()` stays; set `result.Luck` after calling it.

### 3.7 Getting the level to the client
- `ShopService.State` adds `CrateLuck = CrateLuck.Snapshot(data)`, and `{}` while the save isn't loaded. Add `CrateLuck: { [string]: number }` to `export type State`. ShopService requires only the shared `CrateLuck`, so there is no cycle with CrateService.
- `GetShopState` (the panel opening) and the `ShopState` event (after every grant, purchase and F8 change) carry it.
- Every Result has `Luck` and `LuckAfter`. The client takes `LuckAfter` of the last result as the new level straight away, so the page is right even before the State push arrives.
- **Client rules (CrateUI):**
  - `luck: { [string]: number }` only ever holds `CrateLuck.Clamp`ed values. `luckKnown` becomes true at the first State with `Ready == true`.
  - Until then, the buy buttons of a crate with a meter show `Text.Checking` and are disabled.
  - The level a crate page shows is `luckOf(crate) = if CrateLuck.Applies(crate) then luck[crate.Id] or 0 else 0`. That number is sent as `shownLuck`.
  - When a State or Result changes the level of the crate on screen while its page (or the pack window, or "Every chance") is open, the page is redrawn. The pack window and "Every chance" close, and the message reads `Text.OddsChanged`. Nothing changes silently.

### 3.8 Robux opens
- **New RemoteFunction `PrepareCrateRobux(crateId, shownLuck) -> { Ok, Message, CrateId, Luck }`**, created at the top of `CrateService.Start()` before the feature check, like `OpenCrate`. Its checks:
  - the id is valid;
  - `Features.Crates` and `RobuxCrates` are on;
  - the cooldown has passed (the same `RequestCooldown` map);
  - `Get` finds the crate and its `ProductId ~= 0`;
  - the player isn't restricted and their save is loaded;
  - the shown luck equals the saved level (otherwise `OddsChanged` with `Luck`).

  On success it sets a **hold**, `holds[player][crate.Id] = os.clock() + Luck.RobuxHoldSeconds`, and returns `Ok = true`. The client then calls `PromptProductPurchase` as today.
- **The hold** refuses coin opens of that crate only (other crates are fine), with `Text.RobuxFirst`. It ends in any of these ways:
  - the server-side `MarketplaceService.PromptProductPurchaseFinished(userId, productId, false)` fires for that crate's product (connected in `Start()` after the feature check);
  - it times out;
  - the receipt is granted;
  - the player leaves (cleared in `PlayerRemoving`).

  `PromptProductPurchaseFinished(..., true)` renews it for another `RobuxHoldSeconds`.
- **MonetizationService:**
  - In `handleReceipt`, as soon as a crate product and the player are known (before `WaitForLoad`), call `CrateService.ReceiptStarted(player, crate)`. That sets the hold to "until finished", which also covers a receipt Roblox hands over as the player joins.
  - Every exit of `processCrateReceipt` calls `CrateService.ReceiptFinished(player, crate, keepHold)`. `keepHold` is true only when the save failed. The hold then stays for the rest of the session, so the retry rolls at the restored level.
  - `processCrateReceipt` calls `Grant(player, crate, "Robux")`, which reads the current saved level. Thanks to the check and the hold, that is the level the player saw.
  - When the save fails, `undo()` puts the level back exactly.
- **Robux opens always count:** they read and move the meter like coin opens. The `CrateResult` event carries `Luck` and `LuckAfter`.
- `CanOpenWithRobux(player, waitSeconds, crate?)` returns false for a crate that isn't `Available` (Deluxe while `PremiumCrates` is off). The buyer then gets the coin fallback, never nothing.
- **Client:**
  - `openWithRobux` invokes `PrepareCrateRobux(crate.Id, luckOf(crate))` first.
  - On `Ok = false` it updates the luck if `Luck` came back, redraws and shows the message.
  - On `Ok = true` it sets `robuxPending = crate.Id` and `busy = true`, and prompts.
  - `busy` stays true until `PromptProductPurchaseFinished(false)`, until a `CrateResult` for that crate arrives, or until `RobuxHoldSeconds` after `PromptProductPurchaseFinished(true)`. While busy, every buy button does nothing (today's `busy` check).
- **Known limit (documented in V2-CHANGES):** suppose a save fails, the player leaves, saves fail again later, and Roblox retries the receipt in a later session after the player has opened that crate again. Then the retried crate rolls at the luck shown on the crate page at the moment it is granted. In every other case it rolls at the level shown when R$ was pressed.

### 3.9 F8 commands (`registerAdmin`, only while `Features.CrateLuck` is on)
- `CrateLuckUp`, labelled "Crates: +5 luck on Pumpkin Crate" (`Config.Crates.Admin.LuckSteps = 5` on `Admin.FreeCrate`). It sets the level to `min(level + 5, Steps)`, calls `ShopService.Push`, and returns "Pumpkin Crate luck: 5 / 15".
- `CrateLuckReset`, labelled "Crates: reset my luck". It clears `data.Crates.Luck` and calls Push.
- `CrateFree` (Grant, "Free") moves the meter like any open. That is honest (it is the real meter) and only for Studio admins.

### 3.10 Switched off
| Switch | Behaviour |
| --- | --- |
| `Features.Crates` off | Same as today: remotes exist (including `PrepareCrateRobux`), and nothing opens. Saved luck is kept. |
| `Features.CrateLuck` off | `Applies` is false: plain odds, no strip, `Snapshot` = `{}`, the server expects `shownLuck == 0`, and `Grant` leaves saved levels untouched (frozen, back when switched on). The F8 luck commands aren't registered. |
| A theme switched off (`Skins/InGame.luau`) | Its crate and its Deluxe crate leave the game. Its saved luck stays and is used again when the theme comes back. |

## 4. Packs (x5 and x10)
### 4.1 Rules
- A pack of N (from `Open.Counts`) costs N × Price, taken in one go as today. It opens N crates one after another, exactly like N single opens. Crate k uses the meter level after crates 1..k-1.
- **Guarantee** (`Open.Guarantee[N]`, with `CratePacks` on and `CanGuarantee`): if crates 1..N-1 gave nothing at or above the guaranteed rarity G, crate N is rolled with `AtLeast = G`. Otherwise crate N is a normal roll.
  - x5: Uncommon or better.
  - x10: Rare or better.
- **With the meter:** when the guarantee applies, the meter went up at every earlier crate (they were all below G, which is at most Rare). So crate N's level is `min(L0 + N - 1, Steps)` = `CrateLuck.PackLevel`, and `CrateLuck.Boost` combines the two guarantees by taking the higher one.
- If `L0 + N - 1 >= Steps` (with `FullGuarantee`), the meter fills up inside the pack unless a Rare or better comes first, so the pack contains a Rare or better for sure either way, and the pack guarantee can never be needed. The window says so (`Text.PackFullFirst`) instead of printing the guarantee chances.
- After the pack, the meter is wherever the crate-by-crate rule left it.

### 4.2 Config (`Open`)
```lua
	Open = {
		Counts = { 1, 5, 10 },
		SkipKey = Enum.KeyCode.Space,
		-- PACK GUARANTEES (switch: Config.Features.CratePacks). Opening x5 or x10 at once
		-- promises at least one skin of this rarity or better. The crates open one by one; if
		-- the ones before the last haven't given it, the last crate can only give that rarity
		-- or better (picked among those skins with their usual chances, scaled up to 100%).
		-- (x5 and x10 always ask "Open ... x10?" first, with the price, how packs work and every
		-- chance: that window is where the guaranteed crate's chances are shown.)
		Guarantee = { [5] = "Uncommon", [10] = "Rare" } :: { [number]: string },
	},
```

### 4.3 Server: opening crate k of N (in `onOpen`, replacing today's loop)
```lua
local guarantee = CrateLuck.Guarantee(crate, count) -- nil for x1, CratePacks off, or impossible
local met = false
for k = 1, count do
	local atLeast = if guarantee and k == count and not met then guarantee else nil
	local result = CrateService.Grant(player, crate, "Coins", atLeast)
	if not result then
		break
	end
	table.insert(results, result)
	if guarantee and CrateOdds.RarityIndex(result.Rarity) >= CrateOdds.RarityIndex(guarantee) then
		met = true
	end
end
```
Each `Grant` reads the level that the previous one wrote, which gives the crate-by-crate rule. The results keep their real order. The client plays them in that order, so the guaranteed crate is always the last one, never shuffled. Robux products stay single crates. The F8 free crate is a single open.

### 4.4 What the player sees before buying a pack
- Next to the luck strip (in `Info` on PC, in `Side` on phones; also on crates without a meter) there is a line (`Text.PackLine`) for each count with a guarantee for this crate: "x5: at least one Uncommon or better   x10: at least one Rare or better".
- Pressing x5 or x10 opens the **pack window** (section 7.3) instead of buying, on every crate (rarity crates too: their window says `PackHowFixed`).
- The window shows:
  - the price;
  - `Text.PackHow` (or `PackHowFixed` for a crate without a meter);
  - the current level;
  - `Text.PackGuarantee`, with the exact chances of the guaranteed crate: `CrateOdds.Chances(crate, CrateLuck.Boost(crate, CrateLuck.PackLevel(crate, L0, N), G))`, grouped by rarity, or `PackFullFirst`;
  - an "Every chance" button;
  - "Open 10 for 6,000 Coins" and "Cancel".
- Confirm sends `OpenCrate(id, N, L0)`. Every crate in the pack therefore uses one row of "Every chance" or the guaranteed chances printed in the window, and all of them were shown before buying.

### 4.5 Examples (Pumpkin Crate, starting at luck 0)
- **x10:** crates 1-9 use luck 0, 1, 2... (back to 0 after a Rare). If crates 1-9 give no Rare, crate 10 is at luck 9 and can only be Rare or better: CRAZY 0.061%, Rare 99.939% (49.97% each). That happens in 9.30% of x10 packs.
- **x5:** if crates 1-4 are all Common, crate 5 is at luck 4 and can't be Common: CRAZY 0.043%, Rare 48.915% (24.458% each), Uncommon 51.042% (10.208% each). That happens in 11.27% of x5 packs.
- **At luck 11 or more,** an x5 is already sure to include a Rare or better (the meter fills by crate 5 at the latest). The same holds for an x10 at luck 6 or more.

## 5. Deluxe crates (premium)
### 5.1 What they are
There are six, one for each classic crate on the lobby stand: Pumpkin, Candy, Spooky, Graveyard, Monster and Moonlight. Only these six have an ordinary CRAZY skin, so "much better CRAZY odds" means something for them.
- Same skins as their base crate.
- 2,000 coins.
- Odds Common 0, Uncommon 50, Rare 49, CRAZY 1. For Pumpkin that is each Uncommon 10%, each Rare 24.5%, the CRAZY 1%.
- No luck meter. The pack guarantees apply as for any crate: x10 can only reach the guaranteed crate when crates 1-9 are all Uncommon (0.195%), and then that crate is Rare 98%, CRAZY 2%. x5 never needs its guarantee (there are no Commons).
- Tab "Deluxe" (right after "Classic"). The NEW ribbon is shown.
- Robux "Coming soon" (`ProductId = 0`), `SuggestedRobux = 249` as a note.
- Not on the lobby stand. `CrateStand` only shows `Stand.Themed` and rarity crates, so there is no `Config.Hub.BuildVersion` bump. The crate stand test already expects exactly that set.

### 5.2 Config (`src/shared/Config/Crates.luau`, before `List`)
```lua
	-- DELUXE CRATES (switch: Config.Features.PremiumCrates). A pricier version of a themed
	-- crate: the same skins, much better odds, no luck meter. Each line in Crates makes one from
	-- its Base crate (same shape and colours, gold trim), on the Category tab of Menu > Crates
	-- (not on the lobby stand). Never rename an Id once the game is live. ProductId 0 = its
	-- Robux button says "Coming soon" (make a Developer Product in Creator Hub to sell it).
	Premium = {
		Price = 2000, -- coins
		Odds = { Common = 0, Uncommon = 50, Rare = 49, Crazy = 1 } :: { [string]: number },
		Category = "Deluxe",
		NameFormat = "Deluxe %s", -- %s = the base crate's name
		Blurb = "Same skins, no Commons, much better Rare and CRAZY chances.",
		Trim = rgb(255, 205, 60), -- gold bands and lid edge
		Look = { Shake = 1.3, Sparkles = 16 }, -- added to the base crate's Look
		New = true, -- NEW ribbon on their cards
		SuggestedRobux = 249, -- only a note: the real price is set in Creator Hub
		Crates = {
			{ Id = "PumpkinDeluxeCrate", Base = "PumpkinCrate", ProductId = 0 },
			{ Id = "CandyDeluxeCrate", Base = "CandyCrate", ProductId = 0 },
			{ Id = "SpookyDeluxeCrate", Base = "SpookyCrate", ProductId = 0 },
			{ Id = "GraveyardDeluxeCrate", Base = "GraveyardCrate", ProductId = 0 },
			{ Id = "MonsterDeluxeCrate", Base = "MonsterCrate", ProductId = 0 },
			{ Id = "MoonlightDeluxeCrate", Base = "MoonlightCrate", ProductId = 0 },
		} :: { { Id: string, Base: string, ProductId: number } },
	},
```
- `Categories` gets `"Deluxe"` after `"Classic"`. A tab with no crates is already hidden (`showList` skips it), so it disappears while `PremiumCrates` is off.
- Add `Base: string?` to `export type Crate` (and to `CrateOdds.Crate`), with the comment `-- (Deluxe crates) the crate whose skins it gives`.

### 5.3 Building the entries (end of `Crates.luau`, before the theme filter)
For each `Premium.Crates` line whose `Base` is a crate in `List` without `Rarity` or `Base`, append:
```lua
{
	Id = line.Id, Base = base.Id, Name = Premium.NameFormat:format(base.Name),
	Blurb = Premium.Blurb, Color = base.Color, Trim = Premium.Trim, Glow = base.Glow,
	Topper = base.Topper, Look = <base.Look with Premium.Look's keys on top>,
	Category = Premium.Category, Price = Premium.Price, Odds = table.clone(Premium.Odds),
	Robux = { ProductId = line.ProductId, SuggestedRobux = Premium.SuggestedRobux },
	New = Premium.New,
}
```
A line with an unknown `Base` is skipped with a `warn`, and a test catches it.

The theme filter becomes `if not off[crate.Id] and not (crate.Base and off[crate.Base]) then`. `PremiumCrates` is **not** read here. It is checked at run time by `CrateOdds.Available`, so tests (and Kieran) can flip it during a playtest.

### 5.4 Code that must know about `Base`
- `CrateOdds.Items` and `fixedOdds` use `crate.Base or crate.Id` (section 3.4).
- `CrateLuck.Applies` is false for crates with a `Base`.
- `SkinSchema.crateIds()` (Skin Studio's check of a skin's `Crate`) leaves out crates with a `Base`. A skin can only name a real themed crate.
- `CrateArt` needs nothing: it builds from the Look, Color, Trim and Glow. A custom model goes in `ReplicatedStorage.Custom.Props`, named after the Deluxe Id.
- `CrateIdle` and `CrateStand` need nothing (not on the stand).

### 5.5 Robux
`ProductId` 0 makes the button read "Coming soon", as today. When Kieran adds a product later, `ByProductId` finds the crate even while `PremiumCrates` is off. `CanOpenWithRobux(..., crate)` is then false, so the buyer gets 2,000 coins (the crate's coin `Price`), never nothing.

## 6. Economy
Shop prices: Common 125, Uncommon 500, Rare 1,000, CRAZY 100,000. Duplicate refunds: 60, 250, 500, 50,000. "Value" means the expected skin value at Shop prices for a player who owns nothing. "Refund" means the expected duplicate coins for a player who already owns everything. The numbers are for the Pumpkin Crate; the newer crates differ by less than 0.01%. The `crates-luck.spec` economy test recomputes them from Config.

| One crate | Price | Rare or better | CRAZY | Value | Refund | Coins per Rare+ | Coins per CRAZY | Value per coin |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Themed, luck 0 | 600 | 15.02% | 0.02% | 366 | 182 | 3,995 | 3,000,000 | 0.61 |
| Themed, luck 14 | 600 | 43.02% | 0.02% | 611 | 305 | 1,395 | 3,000,000 | 1.02 |
| Themed, full meter | 600 | 100% | 0.044% | 1,044 | 522 | 600 | 1,350,600 | 1.74 |
| **Themed, long-run average (singles)** | 600 | 21.01% (1 in 4.76) | 0.0200% | **418** | 208 | **2,856** | **≈3,000,000** | **0.70** |
| x5 pack from luck 0, per crate | 600 | 0.918 per pack | 0.0205% | 398 | 198 | 3,267 | 2,925,713 | 0.66 |
| x10 pack from luck 0, per crate | 600 | 1.994 per pack | 0.0204% | 409 | 203 | 3,009 | 2,944,443 | 0.68 |
| x10 guaranteed crate (luck 9) | 600 | 100% | 0.061% | 1,060 | 530 | 600 | 990,600 | 1.77 |
| **Deluxe** | 2,000 | 50% | 1% | 1,740 | 870 | 4,000 | **200,000** | **0.87** |
| Deluxe x10 guaranteed crate | 2,000 | 100% | 2% | 2,980 | 1,490 | 2,000 | 100,000 | 1.49 |
| Rare Crate (rarity crate) | 800 | 100% Rare | 0 | 1,000 | 500 | 800 | - | 1.25 |
| CRAZY Crate (rarity crate) | 80,000 | 100% CRAZY | 100% | 100,000 | 50,000 | - | 80,000 | 1.25 |
| Shop (you choose the skin) | 1,000 / 100,000 | - | - | - | - | 1,000 | 100,000 | 1.00 |

How long the meter stays at each level over time: 0: 21.0%, 1: 17.9%, 2: 14.8%, 3: 12.0%, 4: 9.5%, 5: 7.3%, 6: 5.5%, 7: 4.0%, 8: 2.8%, 9: 2.0%, 10: 1.3%, 11-15: 2.0% together.

**Invariants.** The economy test checks each one for every crate in `List`, at every reachable level, with and without each guarantee:
- **I1** A player who owns everything always loses coins: `price > Σ p(rarity) × DuplicateRefund`. Worst themed state: 530 < 600. Worst Deluxe state: 1,490 < 2,000.
- **I2** No crate state is a cheap route to CRAZY: `price / p(CRAZY) ≥` the CRAZY Crate's price (80,000). Worst themed state: 990,600. Worst Deluxe state: 100,000. Over time: about 3,000,000 (themed) and 200,000 (Deluxe). Rarity crates satisfy it with equality or have no CRAZY.
- **I3** Themed and Deluxe crates are not a cheap route to Rare over time: coins per Rare or better ≥ the Rare Crate's price (800). Themed: 2,856. Deluxe: 4,000.
- **I4** The long-run value per coin of themed crates, packs and Deluxe crates is below 1. They stay worse value than the Shop (1.00) and the rarity crates (1.25). Themed: 0.70, packs: 0.66-0.68, Deluxe: 0.87.
- **I5** `Luck.Steps × Luck.PerStep ≤ Odds.Common`, so luck never needs more Common than there is.

Single states above 1 value per coin (full meter, guaranteed crates) are paid for by the unlucky opens before them. Only the averages matter, and they meet I3 and I4. No prices change: themed 600, rarity crates 100 / 400 / 800 / 80,000, Shop 125 / 500 / 1,000 / 100,000.

## 7. UI (`src/client/CrateUI.luau`)
All new words are in `Config.Crates.Text` (section 8.3), and text is never smaller than `Config.UI.MinTextSize` (14). The windows are views inside the Crates panel, not new panels, so they don't call `PanelManager.Register`. The Back and close buttons and Escape work as today.

### 7.1 Crate page: the luck strip and the pack line
- **Where:**
  - PC (`compact` false): a new `Preview.Info` frame at the top of the right column, above `Preview.Items`. The grid moves down by its height. Luck is 56 px tall and the pack line 20 px. The side column stays as it is: it already uses nearly all of its height on PC (it would scroll and hide the buy buttons).
  - Phone (`compact` true): `Luck` and `Packs` go inside `Side`, right after `Odds`. LayoutOrder is a whole number, so renumber: `Odds` 4, `Luck` 5, `Packs` 6, then `Buy` 7, `Extras` 8 and `Nav` 9 (tests find them by name). On phones the side already scrolls with its buy buttons pinned below it.
  - Tests find them with `preview:FindFirstChild("Luck", true)`.
- **`Luck`** is a Frame, only for crates where `CrateLuck.Applies` and only when the player isn't restricted. It holds:
  - `Title`: "Luck 4 / 15" (`Text.LuckTitle`), or `Text.LuckFull` when the meter is full.
  - `Bar`: `Steps` segment frames named `Step1`..`StepN` when `Steps ≤ 20` (one `Fill` frame otherwise). Filled segments use the Rare colour (`Config.Rarity.Levels.Rare.Color`) and empty ones `Theme.Button`. No flashing, no pulsing, no sound.
  - `Chance`: "Rare or better, next crate: 23.02%" (`Text.LuckNext`). That is `Format(sum of RarityOdds(crate, boost) for the rarities at or above Rare)`.
  - `Help` (PC only, muted): `Text.LuckHelp`.
  - `EveryChance`: a TextButton that opens 7.2.

  PC layout: row 1 is Title (left), Bar (middle) and Chance (right); row 2 is Help and EveryChance. Phone layout: Title, Bar, Chance and EveryChance stacked, about 100 px. The help text is in the "Every chance" view.
- **`Packs`**: a TextLabel that lists `Text.PackLine` for each count with a guarantee for this crate. It is hidden when there are none, or when the player is restricted.
- **The grid and the odds line** use the boost for the player's current level: `CrateOdds.Chances(crate, CrateLuck.Boost(crate, luckOf(crate)))` and `RarityOdds(...)`, both printed with `Format`. The grid's cards keep their names (`Items.<itemId>.Chance`).

### 7.2 "Every chance" (`Preview.LuckTable`, covering the preview)
- `Title` (`Text.LuckTableTitle`), and `Help` (`Text.LuckHelp`).
- `Rows`: a ScrollingFrame with one RichText TextLabel per level, `Row0`..`Row<Steps>`. Each row is built from `CrateOdds.Chances(crate, CrateLuck.Boost(crate, L))`, grouped by rarity from highest to lowest, for example: "**Luck 4**  CRAZY 0.02% · Rare 23% (11.5% each) · Uncommon 24% (4.8% each) · Common 52.98% (4.415% each)".
  - Rarities at 0% are written as "0%" in the full row.
  - The player's row has a highlighted background and `Text.LuckYou`.
- A fixed-odds skin gets its own first row: "Night Lord Supreme: 0.0001% at every luck step".
- `Back` returns to the page, or to the pack window when it was opened from there.
- Phone: the same view, with rows that wrap (AutomaticSize Y).

### 7.3 The pack window (`Preview.PackConfirm`, covering the preview)
- `Title`: "Open Pumpkin Crate x10?"
- `Body`: a ScrollingFrame with one RichText label. It holds the price line, `PackHow`, "Your luck now: 4 / 15 (Rare or better next: 23.02%)" (only for crates with a meter), and `PackGuarantee` with the exact chances (4.4) or `PackFullFirst`.
- `EveryChance`.
- `Confirm`: "Open 10 for 6,000 Coins", in the selected colour.
- `Cancel`.

No timer and nothing preselected. Cancel closes it (Escape closes the whole panel, as today). The same layout is used on phones, with the buttons in a row at the bottom (36 px).

### 7.4 After opening
- **"Open again"** (`OpenAnother`, on the reveal card and in the Quick open footer) calls `showPreview(crate)` and never invokes a remote. Remove the direct buys, and `lastCount` and `lastPaid` once nothing uses them.
- **Guaranteed crates** say so honestly. When a result has `Guaranteed`, the reveal card's `News` line starts with `Text.Guaranteed` (like `OneInAMillion`), and its Quick-open card gets a `Guaranteed` tag. The luck itself is not shown on the reveal: no "next time 25%!" nudges. The player sees it on the page.
- **`asResult`** also checks the new fields:
  - `Luck` and `LuckAfter`, if present, are whole numbers from 0 to `Steps`;
  - `Guaranteed`, if present, is a rarity in `Config.Rarity.Order`;
  - otherwise the result is rejected, as today.

  A refusal (`Ok = false`) with a valid `Luck` updates `luck[CrateId]` and redraws.
- **Deluxe crates** appear on the "Deluxe" tab with the price "2,000 Coins", x5 "10,000" and x10 "20,000", and a Robux button that says "Coming soon". No luck strip.

## 8. Reference
### 8.1 Remotes
| Remote | Kind | Client to server | Server to client | Created |
| --- | --- | --- | --- | --- |
| `OpenCrate` | RemoteFunction | `(crateId: string ≤ 64, count: number? in Open.Counts, shownLuck: number)` | `Result` (with `Results` for a pack) | top of `CrateService.Start()` (unchanged) |
| `PrepareCrateRobux` | RemoteFunction (new) | `(crateId: string ≤ 64, shownLuck: number)` | `{ Ok: boolean, Message: string, CrateId: string, Luck: number? }` | top of `CrateService.Start()`, before the feature check |
| `CrateResult` | RemoteEvent | - | `Result` (Robux, F8) | unchanged |
| `GetShopState` / `ShopState` | existing | - | `State` + `CrateLuck: { [crateId]: number }` | ShopService (unchanged) |

### 8.2 Result (CrateService and CrateUI types)
The existing fields stay: `Ok, Message, CrateId, ItemId, ItemName, Rarity, Duplicate, Refund, Reel, WinIndex, Paid, OneInAMillion, Results`. New fields:
- `Luck: number?`: the level this crate was rolled at. On a refusal it is the player's current level.
- `LuckAfter: number?`: the level after this crate.
- `Guaranteed: string?`: the `AtLeast` rarity used for this roll (pack guarantee or full meter); nil for a normal roll.

### 8.3 Config keys (all in `src/shared/Config/Crates.luau` unless noted)
- `Odds` (2.1). `SmallOdds` is removed.
- `Luck = { PerStep = 2, Steps = 15, FullGuarantee = true, Boost = "Rare", TakeFrom = "Common", RobuxHoldSeconds = 60 }` (3.2).
- `Open.Guarantee = { [5] = "Uncommon", [10] = "Rare" }` (4.2).
- `Premium = { Price = 2000, Odds, Category = "Deluxe", NameFormat, Blurb, Trim, Look, New, SuggestedRobux = 249, Crates = { 6 lines } }` (5.2). `Categories` gains "Deluxe".
- `Admin.LuckSteps = 5` (3.9).
- `Text` changes and additions. A `%s` rarity is the rarity's `Name` from `Config.Rarity`.
  ```lua
  OpenAnother = "Open again", -- after a reveal: back to the crate's page, with your new chances
  OddsChanged = "Your chances for this crate just changed, so nothing was bought. Check them, then press Open again.",
  RobuxFirst = "Your Robux crate is still opening. Try this crate again in a moment.",
  LuckTitle = "Luck %d / %d", -- steps now, steps in a full meter
  LuckFull = "Luck full! Your next crate is %s or better for sure.",
  LuckNext = "%s or better, next crate: %s",
  LuckHelp = "Every crate below %s adds %s to %s (taken from %s). A %s or better starts it again at 0. A full meter = %s or better for sure.",
  EveryChance = "Every chance",
  LuckTableTitle = "%s: every chance at every luck step",
  LuckRow = "Luck %d",
  LuckRowFull = "Luck %d (full)",
  LuckYou = "  ◀ you",
  Each = "%s each",
  FixedRow = "%s: %s at every luck step",
  PackLine = "x%d: at least one %s or better",
  PackTitle = "Open %s x%d?",
  PackPrice = "Price: %s %s",
  PackHow = "The %d crates open one after another, just like %d single opens: each one uses your luck at that moment (Every chance shows them all).",
  PackHowFixed = "Every crate in the pack has the chances shown on this page.",
  PackGuarantee = "If crates 1 to %d give nothing %s or better, crate %d can only be %s or better. Its chances: %s",
  PackFullFirst = "If no %s or better comes first, your luck meter fills up during this pack, and a full meter makes that crate %s or better for sure.",
  PackConfirm = "Open %d for %s %s",
  Cancel = "Cancel",
  Guaranteed = "GUARANTEED",
  ```
- `src/shared/Config/Features.luau`:
  ```lua
  	CrateLuck = true, -- each themed crate's luck meter (Config.Crates.Luck)
  	CratePacks = true, -- x5 / x10 guarantees (Config.Crates.Open.Guarantee); off = packs open without one
  	PremiumCrates = true, -- the Deluxe crates (Config.Crates.Premium), on their own tab
  ```
- `src/shared/Config/init.luau`: `Data.Template.Crates = { Opened = 0, Luck = {} }` (3.3).

### 8.4 Module functions
- **CrateOdds:**
  - new: `Boost`, `CanGuarantee`, `Available`, `Higher`;
  - optional `boost` argument on `RarityOdds`, `Chances`, `Roll` and `Reel`;
  - `Format` is exact;
  - `Get` and `List` skip unavailable crates;
  - `Base` is followed in `Items` and `fixedOdds`.
- **CrateLuck** (new): section 3.4.
- **CrateService:**
  - `Grant(player, crate, paid, atLeast?)`;
  - `Luck(player, crateId)`;
  - `ReceiptStarted(player, crate)` and `ReceiptFinished(player, crate, keepHold)`;
  - `CanOpenWithRobux(player, waitSeconds?, crate?)`.
- **ShopService:** `State.CrateLuck`.
- **SkinSchema:** `crateIds()` leaves out crates with a `Base`.

## 9. Honesty and policy checklist
| # | Rule | How | Proved by (section 10) |
| --- | --- | --- | --- |
| H1 | Every chance a purchase can give is shown exactly before buying | A single open (coins or Robux) uses the grid and odds line at the current level. A pack uses the "Every chance" rows (all levels) and the guaranteed crate's chances in the pack window. Deluxe and rarity crates use the grid. `Format` is exact. | C1, C2, C3, C5, O1 |
| H2 | The server rolls with those numbers | `Grant` calls `CrateLuck.Boost(crate, savedLevel, atLeast)` and `CrateOdds.Chances`, the same functions as the UI. The level comes only from the save. | O3, S1, S6 |
| H3 | The odds can't change between seeing and buying without the player knowing | The shown-luck check (coins), `PrepareCrateRobux` plus the hold (Robux), a redraw with `OddsChanged`, and "Open again" going to the page | S2, R1, R2, C4, C6 |
| H4 | No fake near misses | `Reel` draws from the odds actually rolled, and `TeaseGuard` keeps neighbours from being rarer. The beam shows the real rarity. | O4 |
| H5 | No pressure | No timers or countdowns. Luck never decays or expires. No "only N more" or "so close" wording, no flashing or sounds on the meter, nothing preselected in the pack window, Cancel always there. | Studio checklist (14); text review |
| H6 | No hidden odds changes | Luck changes only with the player's own opens (and Studio F8 admin buttons). There are no time, region or spending modifiers. Every change redraws the page. | S1, S3, C4 |
| H7 | PolicyService | Restricted players see no buy buttons, luck strip or pack line. `OpenCrate` and `PrepareCrateRobux` refuse them. A Robux receipt gives coins (2,000 for Deluxe) and never touches luck. | S5, R3, C7 |
| H8 | Robux receipts stay idempotent | `pending` and `Receipts` are unchanged. `undo` restores luck. A retry is counted once. | R2 |
| H9 | Kids don't spend big by accident | x5 and x10 always open the pack window first (Deluxe x10 costs 20,000 coins, CRAZY Crate x10 800,000). | C5 |
| H10 | The economy stays sane | I1 to I5 | E1 |

## 10. Tests
Run `lune run tests/run -- crates` while building. It picks up both files below, because their names contain "crates". Run the full suite at the end.

### 10.1 New `tests/specs/crates-luck.spec.luau`
- **Config (K1):**
  - `Luck` has the right types, `PerStep > 0`, a whole-number `Steps ≥ 1`, and I5.
  - Every `Open.Guarantee` key is in `Open.Counts`, and every value is a rarity name.
  - `Premium.Odds` adds up to 100.
  - Every `Premium.Crates` line names an existing themed `Base`, and Deluxe Ids are unique.
  - `Categories` contains `Premium.Category`.
  - The 6 Deluxe crates are in `List` with `Price` 2000, `ProductId` 0 and their base's skins.
  - `Features.CrateLuck`, `CratePacks` and `PremiumCrates` are booleans.
- **Odds (O1-O4):**
  - **O1:** for every crate × level 0..Steps × `AtLeast` in {nil, each guarantee}: `Chances` add up to 100 (1e-9) and are all above 0; fixed skins are exactly their `Odds`; and the `RarityOdds` totals match. The Pumpkin table in 3.5 is checked at levels 0, 4, 14 and 15 with `Format`. So are Zombie Town (no CRAZY), Vampire Castle (0.0001% at every level and under every guarantee), Deluxe Pumpkin (10% / 24.5% / 1%) and the guaranteed crates of 4.5.
  - **O2:** `Boost` is nil for rarity crates and Deluxe crates at any level, and for every crate while `CrateLuck` is off. `CanGuarantee(CommonCrate, "Rare")` is false.
  - **O3:** 100,000 simulated rolls at level 7 match `Chances(crate, Boost(crate, 7))` within 5 standard deviations. The same holds for the x10 guaranteed crate.
  - **O4:** with a boost (level 15 and `AtLeast`), the reel's cards next to the win are never rarer than it.
- **Economy (E1):** a pure-maths check over Config of I1 to I4. It uses a Markov chain over the meter levels for the long-run numbers (singles and packs), and `T.note`s the section 6 table. A Config change that breaks a rule fails the test, and its message names the rule.
- **Server (S1-S6)** (copy `serverWorld` or move it to a small shared helper):
  - **S1:** forcing outcomes (temporarily set `crate.Odds`, as the one-in-a-million test does, and `Luck.PerStep = 0` where needed): a Common adds 1, an Uncommon adds 1, and a Rare or CRAZY resets to 0. The level stops at `Steps`. A full meter gives `Guaranteed = "Rare"`, a Rare or better, and then 0. `Result.Luck` and `LuckAfter` are right, and `data.Crates.Luck` holds the level (nil at 0).
  - **S2:** a missing, wrong-type or stale `shownLuck` is refused with `OddsChanged` and the right `Luck`, takes no coins and leaves the meter alone. The correct value opens.
  - **S3:** saved junk (`"4"`, -3, 2.5, 1e9 becomes Steps, NaN, a nested table, a non-table `Luck`, 100 junk keys) is cleaned. `ShopService.State(player).CrateLuck` lists only non-zero levels of real crates.
  - **S4:** rarity crates and Deluxe crates never change luck. With `CrateLuck` off, levels freeze and 0 is expected. The F8 commands `CrateLuckUp` and `CrateLuckReset` work and push State.
  - **S5:** a restricted player is refused by `OpenCrate` and `PrepareCrateRobux`. With `PremiumCrates` off, Deluxe crates aren't in `List`, `OpenCrate` gives "NoCrate", and a Deluxe receipt (with a test `ProductId`) gives 2,000 coins.
  - **S6 (packs):**
    - With Rare forced rare (`Odds = { Common = 99.98, Rare = 0.02 }`, `PerStep = 0`), 200 x10 packs each contain a Rare or better, the 10th has `Guaranteed = "Rare"` exactly when 1-9 had none, and the same holds for x5 and Uncommon.
    - With normal odds, the `Results[k].Luck` sequence follows the meter rule.
    - With `CratePacks` off there is no `Guaranteed`.
    - One payment, as before.
- **Robux (R1-R3):**
  - **R1:** `PrepareCrateRobux` refuses stale luck (returning `Luck`), crates with `ProductId` 0, and `RobuxCrates` off. On success, coin opens of that crate get `RobuxFirst`, other crates open, and the hold ends with the server's `PromptProductPurchaseFinished(false)` and after `RobuxHoldSeconds`.
  - **R2:** the receipt rolls at the saved level, and `CrateResult` has `Luck` and `LuckAfter`. When the save fails, the level is exactly the old one and the hold stays. A retry rolls at that same level, is counted once and clears the hold.
  - **R3:** a restricted buyer gets coins and an unchanged meter.
- **Client (C1-C7)** (fake remotes, as the x10 test does):
  - **C1:** with State `CrateLuck = { PumpkinCrate = 4 }`, the strip reads "Luck 4 / 15", 4 of 15 steps are filled, and Chance reads "23.02%". Every item card equals `Format` of the level-4 chances, and the odds line matches.
  - **C2:** CommonCrate and Deluxe have no `Luck`. The Deluxe tab lists 6 cards reading "2,000 Coins", and the Deluxe Robux button reads "Coming soon".
  - **C3:** "Every chance" has rows `Row0`..`Row15`, and `Row4` is marked. The texts equal the `Chances` maths. Vampire Castle has the fixed row.
  - **C4:** a ShopState push with a new level while the page is open redraws it and shows `OddsChanged`. A refused `OpenCrate` with `Luck = 6` redraws to 6.
  - **C5:** x10 opens `PackConfirm` and invokes nothing. The guarantee text equals the 4.5 chances, Cancel invokes nothing, and Confirm invokes `("PumpkinCrate", 10, 4)`. The x1 button invokes `("PumpkinCrate", nil, 4)`.
  - **C6:** "Open again" on the reveal and in the Quick-open footer shows the page and invokes nothing. The `Guaranteed` tag shows on a guaranteed result.
  - **C7:** a restricted player has no Luck, Packs or buy rows. On a phone (`gui:SetAttribute("ForceTouch", true)` and `AbsoluteSize` 640×302, as `candyrush.spec` does), `Luck` is inside `Side`, and every new frame lies within the panel.

### 10.2 Updates to existing specs
- `crates.spec.luau`: the rows of section 2.3.
  - The `serverWorld().open(player, crateId, count?, luck?)` helper sends `luck` (default `CrateService.Luck(player, crateId)`).
  - The fake `OpenCrate` records the third argument.
  - The x10 and Quick-open client tests press `PackConfirm.Confirm` after `OpenCoins10`.
  - The "spins to the server's result" test stays as it is, and the `OpenAnother` check stays: the button is still there.
  - Admin labels: add `CrateLuckUp` and `CrateLuckReset`.
  - The "lists every crate on its tab" test is unchanged (it already compares tabs with `Categories` and visits ≤ 4 pages).
- `Core.spec.luau`: the switch list gains `CrateLuck`, `CratePacks` and `PremiumCrates`. Template: `template.Crates.Luck` is an empty table.
- `skins.spec.luau` line 157: also check that a Deluxe crate exists only while its base theme is on.
- `crateart.spec`, `props.spec`, `towerrun.spec` and `crateidle.spec` need no edits. They loop over `Config.Crates.List` and must pass with the Deluxe crates in it: a valid Look, and the Ids count as prop names. Run them.

## 11. Docs to update
- `docs/CUSTOMIZE.md` > "Crates":
  - Rewrite the Odds bullet: the new numbers and exact display, with no `SmallOdds`.
  - Add three bullets in Kieran's words: **Luck meter** (`Luck` keys, what each does, "lower `Steps` = players near the top get a full meter"), **Packs** (`Open.Guarantee`, the pack window) and **Deluxe crates** (`Premium`: price, odds, one line per crate, Robux "Coming soon", not on the stand).
  - Add the three switches.
  - Add a short "Keep it fair" note: the economy test and what each rule means.
- `docs/V2-CHANGES.md`:
  - a new dated section "Crate luck, packs and Deluxe crates (October 2026)": what players see, the switches, how to undo (switches), the known Robux limit (3.8) and the Studio checks;
  - fix lines 162, 163, 224, 419 and 531.
- The `Crates.luau` header, the `CrateOdds.luau` header, the `CrateUI.luau` header, and the `CrateService.luau` and `MonetizationService.luau` headers (new remote, `shownLuck`, hold).
- `.claude/commands/add-crate.md`, `add-skin.md` and `verify-v2.md` (2.3), and `tests/README.md`.

## 12. Feature switches
| Switch | Off means | Still works |
| --- | --- | --- |
| `CrateLuck` | No meter: plain odds, no strip, saved levels frozen, `shownLuck` must be 0 | Packs (without luck inside: each crate uses the page's odds, `PackHowFixed`), Deluxe |
| `CratePacks` | x5 and x10 open without a guarantee; no pack line | The pack window still opens (price, how packs work, Every chance) |
| `PremiumCrates` | Deluxe crates are hidden (no tab), `OpenCrate` refuses them, Robux receipts give coins | Everything else |
| `Crates` | Everything off as today; all remotes still exist | - |
| `RobuxCrates` | No Robux buttons; `PrepareCrateRobux` refuses | Coin opens |

Every `Mount` and `Start` works with each switch off: remotes are created before the feature checks, and the client checks the flag before using a feature. Each switch can be flipped during a test (the code reads the flag at use time, not at load).

## 13. Build order and files
1. **Config:** `Crates.luau` (`Odds`, no `SmallOdds`, `Luck`, `Open.Guarantee`, `Premium`, `Categories`, `Admin.LuckSteps`, `Text`, the types, building the Deluxe entries and the theme filter, the header), `Features.luau` and `init.luau` (Template). Then `Core.spec`.
2. **Shared:** `CrateOdds.luau` (Boost, Format, Available, CanGuarantee, Higher, Base) and the new `CrateLuck.luau`. Then K1, O1-O4 and E1.
3. **Server:** `CrateService.luau` (Grant, onOpen, PrepareCrateRobux, holds, Luck, ReceiptStarted and ReceiptFinished, the F8 commands, `PromptProductPurchaseFinished`), `MonetizationService.luau` (hold calls, `CanOpenWithRobux` with the crate), `ShopService.luau` (`State.CrateLuck`) and `SkinSchema.luau` (`crateIds`). Then S1-S6 and R1-R3.
4. **Client:** `CrateUI.luau` (exact chances, the luck strip, Every chance, the pack line and window, Open again, Robux prepare, new result fields, Checking until luck is known). Then C1-C7.
5. **Docs** (section 11).
6. `/tmp/claude-0/tools/stylua src`, then `/tmp/claude-0/check/check.sh <new-game path>` (no new type errors), `lune run tests/run -- crates`, and the full `lune run tests/run`.

No lobby (`Kit.prop`) or hub changes, no `Config.Hub.BuildVersion` bump, and no new Menu tiles.

## 14. Studio test list (Kieran's PC)
1. F8 > "Crates: +100k coins". Menu > Crates > Pumpkin Crate:
   - every chance is an exact number (5.082%, 4.8%, 7.5%, 0.02%) and no "<1%" appears anywhere;
   - the strip reads "Luck 0 / 15" and "Rare or better, next crate: 15.02%".
2. Open x1 a few times. After each Common or Uncommon the meter goes up one step, and the chances go up by 2% for Rare and down for Common. A Rare empties it. "Open again" goes back to the page (it never buys by itself).
3. F8 > "+5 luck" while the page is open: the page redraws and says the chances changed. Press Open on a page that was drawn before that, then check that nothing was bought.
4. x10:
   - the window shows the price, how packs work and the exact chances of the guaranteed crate;
   - Cancel buys nothing;
   - Confirm opens 10, and at least one is Rare or better;
   - a guaranteed last crate says GUARANTEED;
   - the meter on the page matches the crate-by-crate rule.
5. "Every chance" on PC and on a phone (Device emulator, iPhone on its side): rows readable, your row marked, nothing cut off. On phones the strip is in the left column, which scrolls while the buy buttons stay put.
6. The Deluxe tab: six crates, 2,000 Coins, "Coming soon" on Robux, gold trim, NEW ribbon, chances 10% / 24.5% / 1%, no luck strip; open one; not on the lobby stand.
7. A Robux crate (a real product id, as a test purchase):
   - while the Roblox window is open nothing else can be opened;
   - after buying, the opening plays and the meter moves;
   - cancel the window: everything opens again at once.
8. `Config.Crates.Policy.TestAsRestricted = true`: no buy buttons, luck strip or pack line; the chances are still shown.
9. Switch `CrateLuck`, `CratePacks` and `PremiumCrates` off one at a time: the game runs without errors in Output, and the right parts disappear.
10. Leave and rejoin: the meter level is kept.
