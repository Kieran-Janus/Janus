# Crate luck, pack guarantees and Deluxe crates: build spec

Written 14 October 2026 on branch `claude/clever-clarke-3zqgma` (base `3115265`) from Kieran's request about the Mystery Crates (Menu > Crates). Revised the same day after a review: section 16 lists what changed and the few points decided differently.

1. New base odds for every themed crate: Rare 15% (it was 2.5%), Uncommon stays 24%, CRAZY stays 0.02%, and Common drops to 60.98%. One-in-a-million skins keep their exact 0.0001%.
2. *"Make the odds higher the more you spend on them."* Kieran chose all three ways: a **luck meter**, **bigger packs** and **premium crates**.

This is the contract the builder follows. Paths are relative to `new-game/`. Kieran's plain-English guide goes in `docs/CUSTOMIZE.md` > "Crates" and `docs/V2-CHANGES.md` (section 11 lists both).

The game is for kids, and crates are paid random items. These hard rules apply everywhere:
- Every chance a player can get is shown as an exact number before they buy. That includes their luck-boosted odds and any pack guarantee.
- The server rolls with exactly the numbers the player was shown. It reads them from the saved data, never from the client. (The one exception is a Robux crate that Roblox hands over late; section 3.8 says when, and its opening then shows the luck it used.)
- No fake near misses, no timers, no pressure, and no hidden changes to the odds.
- Players in regions where PolicyService restricts paid random items still can't buy.
- Robux receipts stay idempotent.

## 0. In plain English (for Kieran)
- **Better odds for everyone.** Every themed crate is now Common 60.98%, Uncommon 24%, Rare 15% (it was 2.5%) and CRAZY 0.02%. The three one-in-a-million skins keep exactly 0.0001%.
- **Luck meter.** Each themed crate has its own meter for each player, and it is saved.
  - Every crate that gives a Common or an Uncommon fills one step. Each step adds +2% to Rare, taken from Common.
  - A Rare or better empties the meter.
  - 15 steps is a full meter: the next crate is Rare or better for sure. So nobody ever opens more than 15 of the same crate in a row without a Rare: the 16th is always Rare or better.
  - The crate's page shows the meter and the exact chance of every skin in your next crate. An "Every chance" button lists the chances at every step. On phones a one-line summary ("Luck 4/15 · Rare or better 23.02%") sits right above the buy buttons, so it is always in view.
  - A crate whose Rare skins are all hidden (`SkinsOff`) has no meter and no Rare guarantee, so hiding skins can never turn a guarantee into a free CRAZY.
- **Packs.** x5 always includes at least one Uncommon or better, and x10 at least one Rare or better.
  - A pack opens like that many single crates, one after another. The meter moves after each crate.
  - If the crates before the last one haven't given that rarity, the last crate can only give that rarity or better.
  - A small "Open 10?" window explains this and shows the exact chances first.
  - **Packs are never worse than single opens, but the bonus is small:** from the same luck, an x10 gives about 3% more Rares or better than 10 single opens (1.99 against 1.93 from an empty meter), and over time about 1% more. An x5 only promises an Uncommon.
- **Deluxe crates.** The six classic crates get a Deluxe version, on a new "Deluxe" tab.
  - Same skins, for 2,000 coins.
  - No Commons: Uncommon 50%, Rare 49%, CRAZY 1%. That CRAZY chance is 50 times the normal crate's. (The Commons still show on the page, at 0%.)
  - Coins only for now: the Robux button says "Coming soon" until you make products in Creator Hub.
  - They are not on the lobby stand.
  - **Heads-up:** the "X unboxed a CRAZY skin!" message for the whole server will come about 15 times as often for each coin spent on Deluxe crates as on normal ones. `Config.Crates.AnnounceCrazy = false` turns those messages off.
- **Honest.** Every chance shows as an exact number (no more "<1%"; tiny ones keep 4 digits, like "0.04442%"). The server rolls with exactly the numbers on screen.
  - If your luck changed while the page was just sitting there (a Robux crate finished, or an F8 button was used), the page redraws with the new numbers and says so. If you press a button on old numbers, nothing is bought and the page shows the new ones.
  - A normal open never shows that message: the page knows its own open is on its way.
  - No timers, no "so close!", and luck never runs out.
- **Robux crates** roll at the luck you saw. While Roblox finishes the purchase, that one crate can't be opened with coins. If you leave straight after paying, or the save fails, Roblox gives you the crate later, and then it rolls at your luck at that moment; its opening says which luck it used.
- **Still a gamble, not a cheap shop.** On average a themed crate gives a Rare every 4.8 opens (about 2,860 coins per Rare; the Rare Crate costs 800 and the Shop 1,000) and a CRAZY every 5,000 opens (about 3 million coins; the CRAZY Crate costs 80,000). A Deluxe CRAZY costs about 200,000 coins on average, twice its Shop price. Section 6 has every number.
- **Switches.** `CrateLuck`, `CratePacks` and `PremiumCrates` in `Config.Features` turn each part off on its own. Turning `CrateLuck` off keeps everyone's saved luck for when you turn it back on.

## 1. Key decisions
| # | Decision | Why |
| --- | --- | --- |
| D1 | Base odds `{ Common = 60.98, Uncommon = 24, Rare = 15, Crazy = 0.02 }`. | Kieran's numbers. 60.98 + 24 + 15 + 0.02 = 100. |
| D2 | **Luck meter:** +2% Rare (from Common) for each crate below Rare, 15 steps. A full meter makes the next crate Rare or better for sure. A Rare or better resets the meter to 0. | Small steps ("a bit"), a hard limit kids understand (at most 16 opens for a Rare), and sane economics: on average 1 Rare in 4.76 opens. Only 0.52% of streaks ever reach a full meter. |
| D3 | Luck never raises CRAZY or Uncommon. A crate only has a meter when both the rarity it raises (`Luck.Boost`) and the one it takes from (`Luck.TakeFrom`) have odds and at least one skin in that crate. | CRAZY duplicates refund 50,000 coins and the CRAZY Crate costs 80,000, so CRAZY odds must stay tiny. Without Rare skins, the moved chance would be rescaled onto Uncommon and CRAZY. A guaranteed crate rescales CRAZY a little (D5); section 6 shows that is harmless. |
| D4 | Only **themed crates** have a meter. Rarity crates and Deluxe crates don't, and a crate line with `Luck = false` has none either. | A rarity crate is 100% one rarity anyway. Deluxe odds are already boosted and stay one fixed, easy-to-read set. |
| D5 | **One guarantee rule**, used everywhere (`AtLeast = G`): rarities below G drop out, and the rest keep their proportions, scaled up to 100%. This is exactly "rolled again until it is G or better". The full meter and both pack guarantees use it. **G itself must have odds above 0 and at least one shared skin in the crate**, or there is no guarantee (and the UI promises none). | It reuses `scaledOdds`. Fixed-odds skins keep their exact chance. Requiring G itself stops a crate with hidden Rares from turning "Rare or better" into "100% CRAZY" for 600 coins. |
| D6 | **A pack is N single opens in a row plus a last-crate guarantee.** The meter moves after every crate, in order. | No loophole: a pack "frozen" at a full meter would give 10 guaranteed Rares for 6,000 coins, cheaper than 10 Rare Crates. Every crate's odds are also one row of the "Every chance" table, so all of them can be shown exactly before buying. |
| D7 | **The guaranteed last crate's luck is known in advance.** The guarantee only applies when every earlier crate was below the guaranteed rarity G. G is never above `Luck.Boost` (D15), so those crates were also below Rare and the meter went up by one each time. Its level is `min(L0 + N - 1, Steps)`, where L0 is the level when the player pressed the button. The confirm window prints its exact chances. | The guarantee can be shown exactly without listing every possible path through the pack. |
| D8 | **Shown-odds check.** The client sends the luck level it displayed and, for a pack, the guarantee its window showed. The server compares them with its own. If they differ it takes no coins, refuses the purchase and sends the real level back. The client's numbers are never used to roll. | The server rolls with the numbers on screen, and decides everything itself. |
| D9 | The luck levels reach the client inside **ShopState** (`State.CrateLuck`), with a per-player **`LuckVersion`** that goes up with every luck change. Results carry it too, and the client ignores anything older than what it has. | `ShopService.Push` already runs after every crate grant (coins, Robux, F8), so no new event is needed. The version stops a cached or late answer from putting back an old level. |
| D10 | **Exact odds everywhere.** `CrateOdds.Format` shows 3 decimals from 1% up and 4 significant figures under 1%, with trailing zeros removed. A chance is never rounded to "0%" or "100%" (only a real 0 shows "0%"). `SmallOdds` ("<1%") is removed. | "Shown exactly" was the compliance gap noted in the code review. Fixed decimals would round 0.04254% up to "0.043%" and overstate a CRAZY chance. |
| D11 | **"Open another" no longer buys.** It becomes "Open again" and returns to the crate's page, which shows the new odds. | The odds may have changed with that open, so the next purchase must start from a page that shows them. |
| D12 | **Robux:** a new `PrepareCrateRobux` remote checks the shown level before the Roblox purchase window opens. The server then refuses coin opens of that crate until the purchase is cancelled, or its receipt has been handled (whatever the outcome). A player's crate receipts are handled one at a time. `Grant`'s undo restores the luck when a save fails. | Robux opens use and move the meter like coin opens, and a receipt can arrive late or be retried. |
| D13 | **Deluxe crates** are built from one `Config.Crates.Premium.Crates` line each (`Id`, `Base`, `ProductId`), with the skins of `Base`. They cost 2,000 coins and are coins-only (`ProductId = 0`). | Config-driven: one line adds a Deluxe crate. The same skins means no catalogue work. |
| D14 | x5 and x10 always ask first ("Open Pumpkin Crate x10?"). There is no setting to skip it. | Packs cost 3,000 to 20,000 coins (800,000 for a CRAZY Crate x10), and the window is where the pack rules and the guaranteed crate's exact chances are shown, so it can't be optional. |
| D15 | **Rarity order is enforced in code, not only in tests.** `Luck.Boost` must be below the top (rainbow) rarity and `Luck.TakeFrom` below `Luck.Boost`; otherwise no crate has a meter. A pack guarantee above `Luck.Boost` is ignored. Each case `warn`s once. | D7's formula is only right when guarantees are at or below Boost, and a `"Crazy"` guarantee or Boost would hand out cheap CRAZY skins. |
| D16 | **A player's own open never shows "your chances changed".** While an open or Robux purchase of a crate is on its way, a new level for it is stored without redrawing. The message only appears for a change that arrives while the page is idle, or when the server refuses. | Every successful open pushes the new State before its answer arrives; without this, every open would say "nothing was bought". |

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
	-- "0.04442%", "0.0001%"): a Roblox rule for paid random items, so there is no setting to
	-- round them.
```

### 2.2 Exact formatting (`src/shared/CrateOdds.luau`)
`CrateOdds.Format(percent)` works like this:
- 0 or less shows "0%", and 100 or more shows "100%".
- From 1 up: 3 decimals, then trailing zeros and a trailing dot are removed ("5.082%", "24%", "4.8%", "15.02%", "49.978%").
- Under 1: 4 significant figures (`3 - floor(log10(percent))` decimals), trailing zeros removed ("0.5%", "0.02%", "0.04254%", "0.04442%", "0.06057%", "0.1235%", "0.00025%", "0.0001%"). So a tiny chance can never round to 0 or be overstated.
- If the rounded text reads 100 while the chance is under 100, it adds decimals (up to 6) until it doesn't ("99.9999%").

`Exact` stays as it is (the tests use it). In CrateUI, `richEscape` stays (it is harmless), but its comment no longer mentions "<1%".

### 2.3 Every place that hard-codes or quotes the old numbers
| Where | Today | Becomes |
| --- | --- | --- |
| `src/shared/Config/Crates.luau` header, lines 9-21 | "Common 73.48 means 73.48 in 100 opens"; "12 Commons share 73.48% (6.123% each), 5 Uncommons share 24% (4.800% each), 2 Rares share 2.5% (1.250% each) and its one CRAZY skin has 0.020%"; "Rare and CRAZY were made rarer in the big skin update (Rare 5% -> 2.5%, CRAZY 0.1% -> 0.02%)" | "Common 60.98 means 60.98 in 100 opens"; "12 Commons share 60.98% (5.082% each), 5 Uncommons share 24% (4.8% each), 2 Rares share 15% (7.5% each) and its one CRAZY skin has 0.02%"; "Rare went up to 15% in October 2026 (it was 2.5%); CRAZY stays 0.02%". Add a pointer: "LUCK, PACKS AND DELUXE CRATES: see Luck, Open.Guarantee, RobuxOpen and Premium below (docs/CRATE-LUCK-SPEC.md)". |
| Same header, "Prices" paragraph, lines 57-66 | "One open is worth about 257 coins at shop prices (0.7348 x 125 + 0.24 x 500 + 0.025 x 1000 + 0.0002 x 100000)" | "One open is worth about 366 coins at shop prices (0.6098 x 125 + 0.24 x 500 + 0.15 x 1000 + 0.0002 x 100000), about 418 on average with the luck meter. A player who already owns everything gets back about 208 in duplicate coins, so a crate never pays for itself. Packs are worth about 1% more per crate over time. Deluxe crates: 2,000 coins, worth about 1,740." |
| Same file, line 97 and lines 98-100 | `Odds` 73.48/24/2.5/0.02 and `SmallOdds = "<1%"` | Section 2.1. |
| Same file, `Text.OpenAnother` | "Open another" | "Open again" (section 7.4). |
| `src/shared/CrateOdds.luau` header, line 26 | `Format(percent) -> string "0.100%", or "0.0001%" for tiny chances` | `Format(percent) -> string  exact: "5.082%", "24%", "0.02%", "0.04442%", "0.0001%"`. Also document `Boost`, `Shares`, `Shown` and the new arguments (section 3.4). |
| `src/shared/CrateOdds.luau`, lines 280-293 | The `SmallOdds` comment and branch | Section 2.2. |
| `src/client/CrateUI.luau`, line 185 | A comment about "<1%" needing "&lt;" | "RichText: escape <, > and &." |
| `src/client/CrateUI.luau`, line 915 | `"CRAZY <1%  Rare 2.5%  Uncommon 24%  Common 73.5%"` | `"CRAZY 0.02%  Rare 15%  Uncommon 24%  Common 60.98%" (for your next crate)` |
| `src/client/CrateUI.luau` header, lines 13-21 | "% chance", "Open another" | Exact chances, luck strip and phone summary line, "Every chance", the pack window, Robux check and "Open again". |
| `tests/specs/crates.spec.luau`, lines 40-44 | `73.48`, `2.5` "(was 5)", `0.02` | `60.98`, `24`, `15` "(was 2.5)", `0.02` |
| Same file, lines 130-142 | `Format(chances[1].Chance) == "<1%"`, `Exact(73.48/12) == "6.123%"`, `Format(73.48/12) == "6.1%"`, `Format(0.5) == "<1%"` | `Format(...) == "0.02%"`, `Exact(60.98/12) == "5.082%"`, `Format(60.98/12) == "5.082%"`, `Format(24) == "24%"`, `Format(4.8) == "4.8%"`, `Format(0.5) == "0.5%"`, `Format(0.02 / 47.02 * 100) == "0.04254%"`, `Format(0.123456) == "0.1235%"`, `Format(0.00025) == "0.00025%"`, `Format(0.0001) == "0.0001%"`, `Format(99.9999) == "99.9999%"`, `Format(100) == "100%"`, `Format(0) == "0%"`. Keep the `Exact` checks. |
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
  - `CrateLuck.ConfigOk()`: `Luck.Boost` is a rarity below the top (rainbow) one in `Config.Rarity.Order`, and `Luck.TakeFrom` is a rarity below `Luck.Boost` (D15);
  - the crate has no `Rarity` (not a rarity crate);
  - it has no `Base` (not Deluxe);
  - its line doesn't say `Luck = false`;
  - `CrateOdds.Shares(crate, Luck.Boost)` and `CrateOdds.Shares(crate, Luck.TakeFrom)`: both rarities have configured odds above 0 and at least one shared (not fixed-odds) skin in this crate (D3). Hiding a theme's Rares with `SkinsOff` therefore removes its meter (its saved level is kept, frozen).
- **A crate rolled at level L** uses these odds:
  - Common loses `a = min(L, Steps) × PerStep`, and Rare gains it. This is applied to the crate's configured odds before rarities without skins drop out and the rest are scaled. If Common has less than `a`, only what Common has moves.
  - Uncommon, CRAZY and fixed-odds skins don't change.
- **Full meter.** At L = `Steps` with `FullGuarantee` on, the crate also gets `AtLeast = Luck.Boost` (D5).
- **After each crate** (each one counts, in order, also inside a pack), only for a crate where `Applies` is true:
  - Rare or better: L becomes 0.
  - Anything below Rare: L becomes `min(L + 1, Steps)`.
- **What moves the meter.** Coin opens, Robux opens, packs (crate by crate) and the F8 free crate (Studio admin) all count. Nothing else changes it. It never decays, expires, depends on time or is changed by the server on its own.
- **Never erased by a switch.** While `Applies` is false (switch off, theme or Rares hidden), opens don't read or write that crate's saved level. It is used again when `Applies` is true again.
- **Steps lowered in Config.** Saved levels above the new `Steps` read as `Steps`, which is a full meter. The docs say so.

### 3.2 Config (`src/shared/Config/Crates.luau`, after `Odds`)
```lua
	-- LUCK METER (switch: Config.Features.CrateLuck). Each player has a meter for each themed
	-- crate (saved). Every crate that gives something below Rare fills one step: Rare gets
	-- PerStep % more and Common PerStep % less, for that player's next crate of that kind.
	-- A Rare or better empties the meter. A full meter (Steps steps) makes the next crate Rare
	-- or better for sure (FullGuarantee). The crate page always shows the meter and the exact
	-- chance of every skin for the next crate, and "Every chance" lists every step.
	-- Rarity crates and Deluxe crates have no meter (nor does a crate line with Luck = false,
	-- or a crate whose Rare skins are all hidden).
	-- Keep Steps x PerStep at or below Odds.Common (the tests check it). Boost must be below
	-- CRAZY and TakeFrom below Boost, or no crate gets a meter (Output says why).
	Luck = {
		PerStep = 2, -- percent moved from Common to Rare per step
		Steps = 15, -- steps in a full meter
		FullGuarantee = true, -- true = a full meter makes the next crate Rare or better for sure
		Boost = "Rare", -- the rarity the meter raises (getting this or better empties it)
		TakeFrom = "Common", -- the rarity the extra chance is taken from
	},

	-- ROBUX OPENS. Pressing a crate's R$ button first checks the luck you saw. Then that crate
	-- can't be opened with coins until Roblox's purchase is cancelled or its crate has opened,
	-- so the Robux crate rolls with the luck you saw. Other crates open as normal.
	RobuxOpen = {
		Cooldown = 1, -- seconds between two R$ presses by one player (its own timer)
		HoldSeconds = 60, -- how long the hold waits for you to finish Roblox's purchase window
		MaxHoldSeconds = 600, -- after you buy: the hold lasts until the crate opens, at most this
		ClientWaitSeconds = 60, -- after you buy: the other buttons wait this long for the opening
		RemoteWaitSeconds = 5, -- the first R$ press waits this long for the server's check
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
- **On every write**, `CrateLuck.Set`, in this order:
  1. puts `{}` in place of a non-table `data.Crates` or `data.Crates.Luck`;
  2. drops junk: non-string keys, keys over 64 characters, and values that `Clamp` to 0 (every other value is stored `Clamp`ed); the new level is stored, nil for 0;
  3. only if more than 64 entries are left, drops entries whose key is not a known crate (sorted by key, so it is the same every time) until 64 remain. A known crate is one in `Config.Crates.List` or the `Crate` of any theme in `Config/Skins/Settings.luau` `AllThemes`, so a switched-off theme's level is never dropped.
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
- **`CrateOdds.Shares(crate, rarity) -> boolean`**: the crate's configured odds give `rarity` more than 0, and the crate has at least one skin of that rarity without fixed odds.
- **`CrateOdds.CanGuarantee(crate, rarity) -> boolean`** = `Shares(crate, rarity)`: the guaranteed rarity *itself* must be possible (D5). If it is false, `AtLeast` is ignored and the UI promises nothing (for example, x10 on the Common Crate, or "Rare or better" on a crate whose Rares are hidden).
- **`CrateOdds.Shown(crate, boost?) -> { Chance }`**: every skin of `Items(crate)`, in the same order as `Chances` (fixed-odds skins first, then highest rarity first, Config order inside a rarity), with `Chance = 0` for the ones that can't drop under that boost. Only the UI uses it; `Roll`, `Pick` and `Reel` keep using `Chances`.
- Fixed-odds skins (the one-in-a-million ones, `item.Odds`) keep exactly their chance under every boost. They are CRAZY, so they are never below an `AtLeast`. The tests check this.
- **Deluxe:** `local source = crate.Base or crate.Id`. `Items(crate)` uses `item.Crate == source`, and `fixedOdds` does too, so a one-in-a-million skin would keep its 0.0001% in a Deluxe crate as well.
- `CrateOdds.Available(crate) -> boolean` is false for a crate with `Base` while `Config.Features.PremiumCrates` is off. `Get` and `List` skip crates that aren't available. `ByProductId` still finds them, so a receipt pays the coin fallback (section 5.5).
- `CrateOdds.Higher(a, b) -> string?` returns the higher of two rarity names (either may be nil).
- `Format` changes as in section 2.2.

**New `src/shared/CrateLuck.luau`** (shared, pure functions; it requires Config and CrateOdds):
```
CrateLuck.ConfigOk() -> boolean                     Boost below the top rarity, TakeFrom below
                                                    Boost (D15); warns once when false
CrateLuck.Applies(crate) -> boolean                 section 3.1
CrateLuck.Steps() -> number                         max(1, floor(Config.Crates.Luck.Steps))
CrateLuck.Clamp(value: unknown) -> number           whole number 0..Steps (junk -> 0)
CrateLuck.Get(data, crate) -> number                server: the saved level (0 if not Applies)
CrateLuck.Set(data, crate, level)                   server: stores it, cleaning the table (3.3);
                                                    callers only call it when Applies
CrateLuck.Snapshot(data) -> { [crateId]: number }   loops over the saved keys only: for each,
                                                    CrateOdds.Get(id) (so junk keys and hidden
                                                    crates never leave the server) and Applies;
                                                    keeps non-zero Clamped levels; {} when
                                                    CrateLuck is off
CrateLuck.Boost(crate, level, atLeast?) -> Boost?   the boost for one roll: the luck shift, the
                                                    full-meter guarantee and a pack guarantee
                                                    (the higher of the two); nil = plain odds
CrateLuck.After(crate, level, rarity) -> number     the level after a crate gave `rarity`
CrateLuck.Guarantee(crate, count) -> string?        Open.Guarantee[count] while CratePacks is on,
                                                    when it is a rarity at or below a valid
                                                    Luck.Boost (else nil and a warn, once) and
                                                    CrateOdds.CanGuarantee(crate, it); else nil
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
The UI and the server call **this same function** with the same level. That is what makes the shown odds and the rolled odds identical. (`Applies` already checked that Boost is possible, so the full-meter guarantee always holds when it is on.)

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
| 15 (full) | 0% (Uncommon 0%) | 49.978% | 100% (CRAZY 0.04442%) |

The newer crates have no ordinary CRAZY skin, so their odds are scaled over 99.98:
- **Zombie Town** (13/5/3) at luck 0: Common 60.992% (13 × 4.692%), Uncommon 24.005% (5 × 4.801%), Rare 15.003% (3 × 5.001%). Full meter: Rare 100% (3 × 33.333%).
- **Vampire Castle**: Night Lord Supreme is 0.0001% at every step. At luck 0 Rare is 15.003%; a full meter gives Rare 99.9999% (3 × 33.333%).
- **Pumpkin with both Rares hidden** (`SkinsOff`): no meter, no Rare guarantee. Plain odds Common 71.741%, Uncommon 28.235%, CRAZY 0.02353%. The x5 guarantee still works: Uncommon 99.917%, CRAZY 0.08326%.

### 3.6 Server (`src/server/Services/CrateService.luau`)
- **`CrateService.Grant(player, crate, paid, atLeast: string?) -> (Result?, undo)`**:
  ```
  applies = CrateLuck.Applies(crate)
  level   = if applies then CrateLuck.Get(data, crate) else 0
  boost   = CrateLuck.Boost(crate, level, atLeast)
  chances = CrateOdds.Chances(crate, boost)
  item    = CrateOdds.Pick(chances, rng:NextNumber())        -- (nil -> return nil, noUndo)
  ...ownership / refund / Opened as today...
  after   = level
  if applies then
    after = CrateLuck.After(crate, level, rarity)
    CrateLuck.Set(data, crate, after); ShopService.LuckChanged(player)
    result.Luck = level; result.LuckAfter = after
  end
  result.LuckVersion = ShopService.LuckVersion(player)
  result.Guaranteed  = boost and boost.AtLeast or nil
  result.Reel = CrateOdds.Reel(crate, item.Id, rng, reel.Cards, winIndex, boost)
  undo(): today's undo, plus, only if applies and CrateLuck.Get(data, crate) == after:
          CrateLuck.Set(data, crate, level); ShopService.LuckChanged(player)
  ```
  With `CrateLuck` off (or the crate's Rares hidden), nothing reads or writes the saved level, so it survives (3.1).
- **`onOpen(player, crateId, countIn, shownLuck, shownGuarantee)`** runs these checks in order. Steps 1-7 are today's, in today's order.
  1. The id is a string of at most 64 characters.
  2. `Features.Crates` is on, else "Closed".
  3. The count is nil (counts as 1) or in `Open.Counts`, else "NoCrate".
  4. The cooldown has passed (`RequestCooldown`, set before the remaining checks, as today).
  5. `CrateOdds.Get` finds the crate (this now respects `PremiumCrates`), with a price and items.
  6. The policy check: nil gives "StillChecking", true gives "Restricted".
  7. The save is loaded.
  8. **Robux hold:** if this player has a live hold on this crate (3.8), fail with `Text.RobuxFirst`.
  9. **Shown luck:** `typeof(shownLuck) == "number" and shownLuck == CrateLuck.Get(data, crate)`. Crates without a meter expect 0, so a missing value is always refused.
  10. **Shown guarantee:** `shownGuarantee` is nil or a string, and equals `CrateLuck.Guarantee(crate, count)` (nil for x1).
  11. A failed 9 or 10 gives `Text.OddsChanged` with `Luck = <current level>` and takes no coins.
  12. `Spend(price * count)`, else "NoCoins".
  13. Open the crates (section 4.3).
  14. Refund crates that weren't granted, save if any is Rare or better, Push, and return. All as today. A batch's `LuckAfter` is the last crate's (4.3).
- **`CrateService.Luck(player, crateId) -> number`** returns the current level (0 if unknown). Tests and F8 use it.
- Every result, refusals included, carries `LuckVersion`. A refusal can also carry `Luck`. `fail()` stays; set the fields after calling it.

### 3.7 Getting the level to the client
- **Server (`ShopService`):**
  - `State` adds `CrateLuck = CrateLuck.Snapshot(data)` (`{}` while the save isn't loaded) and `LuckVersion = ShopService.LuckVersion(player)`. Add both to `export type State`. ShopService requires only the shared `CrateLuck`, so there is no cycle with CrateService.
  - New `ShopService.LuckChanged(player) -> number` raises the player's `LuckVersion` by 1 and returns it; `ShopService.LuckVersion(player) -> number` reads it (0 at first). It lives only in memory for the session and is cleared on `PlayerRemoving`. CrateService calls `LuckChanged` after every `CrateLuck.Set` (grants, undo, F8).
  - `Push` also refreshes the `GetShopState` cache (`lastState[player] = { At = now, State = state }`), so the 0.2 s cache (`Performance.ShopStateCooldown`) never answers with a level older than the last push.
- `GetShopState` (the panel opening), the `ShopState` event (after every grant, purchase and F8 change) and the `EquipItem` answer all carry it.
- **Client rules (CrateUI):**
  - `luck: { [crateId]: number }` only ever holds `CrateLuck.Clamp`ed values. Next to it, `luckVer[crateId]` is the `LuckVersion` each level came from, and `snapshotVer` the newest full State used. `luckKnown` becomes true at the first State with `Ready == true`.
  - **Newer wins.** A State with `LuckVersion` below `snapshotVer` is ignored. Otherwise, for every crate in it or in `luck`, it is used when its version is at least that crate's `luckVer` (missing = 0). A single level from a Result or a refusal is used when its `LuckVersion` is at least `luckVer[id] or snapshotVer`. So a cached or late answer never puts an old level back.
  - Until `luckKnown`, the buy buttons of a crate with a meter show `Text.Checking` and are disabled.
  - The level a crate page shows is `luckOf(crate) = if CrateLuck.Applies(crate) then luck[crate.Id] or 0 else 0`. That number is sent as `shownLuck`, and the page remembers it as `drawnLevel`.
  - **In flight.** `inFlight[crateId]` is true from an `OpenCrate` or `PrepareCrateRobux` call for that crate until its answer, and `robuxWaiting[crateId]` while a Robux purchase of it isn't finished (3.8).
  - **When a level changes:** if the crate's page (or the pack window, or "Every chance") is on screen, the new `luckOf(crate)` differs from `drawnLevel`, and that crate is neither `inFlight` nor `robuxWaiting`, the page is redrawn, the pack window and "Every chance" close, and the message reads `Text.OddsChanged`. While it is in flight, the level is only stored: the open's own State push never shows that message (D16).
  - **When a request ends with a refusal** (any message), the client uses its `Luck`, then: if `luckOf(crate)` differs from `drawnLevel`, the page is redrawn with `Text.OddsChanged`; otherwise the refusal's own message shows.
  - After a successful open the page isn't on screen (the opening plays). "Open again" redraws it from the newest level.

### 3.8 Robux opens
**Server (CrateService):**
- **New RemoteFunction `PrepareCrateRobux(crateId, shownLuck) -> { Ok, Message, CrateId, Luck, LuckVersion }`**, created at the top of `CrateService.Start()` before the feature check, like `OpenCrate`. Its checks:
  - the id is valid;
  - `Features.Crates` and `RobuxCrates` are on;
  - its **own** cooldown has passed (`RobuxOpen.Cooldown`, map `lastPrepare`; it doesn't share `RequestCooldown`, so cancelling the Roblox window and then opening with coins never says "Slow down!");
  - `Get` finds the crate and its `ProductId ~= 0`;
  - the player isn't restricted and their save is loaded;
  - no receipt of this crate is being handled for this player, and no bought purchase of it is still waiting for its receipt (else `RobuxFirst`);
  - the shown luck equals the saved level (otherwise `OddsChanged` with `Luck`).

  On success it sets `prepared[player][crate.Id] = { Until = os.clock() + RobuxOpen.HoldSeconds, Bought = false }` (a press while a not-yet-bought record exists just renews it) and returns `Ok = true`.
- **Two kinds of hold**, both refusing coin opens of that crate only (other crates are fine), with `Text.RobuxFirst`:
  - **prepared** (a timed record, live while `os.clock() < Until`): removed when the server-side `MarketplaceService.PromptProductPurchaseFinished(userId, productId, false)` fires for that crate's product, when a receipt for that crate finishes, or when the player leaves. `PromptProductPurchaseFinished(..., true)` sets `Bought = true` and `Until = os.clock() + RobuxOpen.MaxHoldSeconds`: it then lasts until the receipt has been handled (or the player leaves), with a 10-minute safety limit (section 16). That event is connected in `Start()` after the feature check; with no prepared record for that crate (for example the receipt was handled first), it does nothing.
  - **receiving** (a counter, `receiving[player][crate.Id]`): `CrateService.ReceiptStarted(player, crate)` adds 1, `CrateService.ReceiptFinished(player, crate, granted)` takes 1 away (never below 0) and removes the prepared record. Two receipts for the same crate (for example retries on join) each keep their own count, so one finishing never releases the other's hold.
  - Both are cleared in `PlayerRemoving`.
- **`ReceiptFinished(player, crate, granted)`** with `granted = false` (the receipt is not done: save failed, save not loaded, an error...) and the player still in the game sends a `CrateResult` `{ Ok = false, Message = Text.RobuxLater, CrateId, Paid = "Robux", Luck, LuckVersion }`. The hold ends, so the crate isn't locked for the session with a misleading "still opening" message. A granted receipt already sent its own `CrateResult`.

**MonetizationService:**
- **`processReceipt` pairs every start with a finish.** Right after the `pending` check it looks up the crate (`CrateOdds.ByProductId`) and the player. If both exist:
  1. `CrateService.ReceiptStarted(player, crate)` (before `WaitForLoad`, so it also covers a receipt Roblox hands over as the player joins);
  2. it **waits its turn**: one crate receipt per player at a time (`crateTurn[player]`, polled every 0.1 s while the player is in the game). So receipt A's undo can never overwrite receipt B's step while both are saving;
  3. `pcall(handleReceipt, ...)` as today;
  4. it releases the turn and calls `CrateService.ReceiptFinished(player, crate, ok and decision == PurchaseGranted)`.

  Every exit of `handleReceipt` (`WaitForLoad` false, no data, already granted, a pcall error, a failed save) therefore ends the hold.
- `processCrateReceipt` calls `Grant(player, crate, "Robux")`, which reads the current saved level. Thanks to the check and the hold, that is the level the player saw. When the save fails, `undo()` puts the level back exactly.
- `CanOpenWithRobux(player, waitSeconds, crate?)` returns false for a crate that isn't `Available` (Deluxe while `PremiumCrates` is off). The buyer then gets the coin fallback, never nothing.
- **Robux opens always count:** they read and move the meter like coin opens. The `CrateResult` event carries `Luck`, `LuckAfter` and `LuckVersion`.

**Client (CrateUI):**
- `PrepareCrateRobux` is **not** in the `Net` table (that would make every crate panel wait for it before `net` is set and `CrateResult` is connected). The first R$ press looks it up with `ReplicatedStorage.Remotes:WaitForChild("PrepareCrateRobux", RobuxOpen.RemoteWaitSeconds)` and keeps it. If it isn't there, the press shows "Something went wrong, try again." and the buttons work again.
- `openWithRobux(crate)`: sets `busy = true`, `inFlight[crate.Id] = true`, and invokes `PrepareCrateRobux(crate.Id, luckOf(crate))`.
  - On `Ok = false`: `busy` and `inFlight` are cleared, the refusal rule of 3.7 applies.
  - On `Ok = true`: `robuxWaiting[crate.Id] = true`, message `WaitingRobux`, and `PromptProductPurchase`. If that call errors, `busy` and `robuxWaiting` are cleared and the message says so.
- `robuxWaiting[crate.Id]` ends with the client's `PromptProductPurchaseFinished(false)` for that product, or any `CrateResult` for that crate (Ok or not, including `RobuxLater`). `busy` ends at the same moments, or `RobuxOpen.ClientWaitSeconds` after `PromptProductPurchaseFinished(true)` (then the message is `Text.RobuxSlow` and other crates can be opened; the server still holds that one crate, and its opening plays whenever the result arrives).
- **The opening of a Robux crate says which luck it used** (`Text.RobuxLuck`, "Opened at luck 3 / 15", from the result's `Luck`), on crates with a meter.

**When a Robux crate can roll at a different level than the one shown (documented in V2-CHANGES, Known limits).** A Robux crate always rolls at the level saved at the moment Roblox hands the receipt to the game. While the player stays in the game, the hold makes that the level they saw. It can differ when:
- the player leaves right after paying, and the receipt is handled in a later session after they have opened that crate again (on this or another server);
- the save fails (`RobuxLater`): the hold ends, and Roblox retries later, sometimes only when the player rejoins;
- Roblox takes more than 10 minutes (`MaxHoldSeconds`) to hand it over;
- a retried old receipt of the same crate lands while a new purchase window is open.

In every case the opening shows the level it used. Nothing else about the purchase changes: it is granted once and saved before Roblox is told.

### 3.9 F8 commands (`registerAdmin`, Studio only, like `CrateFreeCrazy`, and only while `Features.CrateLuck` is on)
- `CrateLuckUp`, labelled "Crates: +5 luck on Pumpkin Crate" (`Config.Crates.Admin.LuckSteps = 5` on `Admin.FreeCrate`). It sets the level to `min(level + 5, Steps)`, calls `LuckChanged` and `ShopService.Push`, and returns "Pumpkin Crate luck: 5 / 15".
- `CrateLuckQuiet`, labelled "Crates: +1 luck on Pumpkin Crate, screen not told (tests the odds check)". It changes the level and calls `LuckChanged`, but doesn't Push. The F8 panel doesn't close the Crates panel, so the page stays on the old numbers (Studio test step 3).
- `CrateLuckReset`, labelled "Crates: reset my luck". It clears `data.Crates.Luck`, calls `LuckChanged` and Push.
- Each command's function checks `RunService:IsStudio()` again and returns "Studio only." otherwise.
- `CrateFree` (Grant, "Free") moves the meter like any open. That is honest (it is the real meter) and only for admins.

### 3.10 Switched off
| Switch | Behaviour |
| --- | --- |
| `Features.Crates` off | Same as today: remotes exist (including `PrepareCrateRobux`), and nothing opens. Saved luck is kept. |
| `Features.CrateLuck` off | `Applies` is false: plain odds, no strip, `Snapshot` = `{}`, the server expects `shownLuck == 0`, and `Grant` neither reads nor writes saved levels (frozen, back when switched on). The F8 luck commands aren't registered. |
| A theme switched off (`Skins/InGame.luau`) | Its crate and its Deluxe crate leave the game. Its saved luck stays (never dropped by `Set`) and is used again when the theme comes back. |
| A theme's Rares all hidden (`SkinsOff`) | That crate has no meter and no Rare guarantee; its saved level is kept. |

## 4. Packs (x5 and x10)
### 4.1 Rules
- A pack of N (from `Open.Counts`) costs N × Price, taken in one go as today. It opens N crates one after another, exactly like N single opens. Crate k uses the meter level after crates 1..k-1.
- **Guarantee** (`G = CrateLuck.Guarantee(crate, N)`: `Open.Guarantee[N]`, with `CratePacks` on, G at or below `Luck.Boost`, and G itself possible in the crate): if crates 1..N-1 gave nothing at or above G, crate N is rolled with `AtLeast = G`. Otherwise crate N is a normal roll.
  - x5: Uncommon or better.
  - x10: Rare or better.
- **With the meter:** when the guarantee applies, every earlier crate was below G, which is at most Rare (D15), so the meter went up at every one. So crate N's level is `min(L0 + N - 1, Steps)` = `CrateLuck.PackLevel`, and `CrateLuck.Boost` combines the two guarantees by taking the higher one.
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
		-- Never above Luck.Boost (a higher one is ignored). A crate with no skins of that
		-- rarity gets no guarantee. (x5 and x10 always ask "Open ... x10?" first, with the
		-- price, how packs work and every chance: that window is where the guaranteed crate's
		-- chances are shown.)
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

The batch result is still `table.clone(first)` with `Results`, but the server sets **`batch.LuckAfter = results[#results].LuckAfter`** and `batch.LuckVersion` to the version after the last crate. The client also reads the last entry of `Results`, so either way the page shows the level after the whole pack.

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
- Confirm sends `OpenCrate(id, N, L0, G)`, where G is the guarantee the window was drawn with (nil if it promised none). The server refuses if its own `CrateLuck.Guarantee(crate, N)` differs (3.6, step 10). Every crate in the pack therefore uses one row of "Every chance" or the guaranteed chances printed in the window, and all of them were shown before buying.

### 4.5 Examples (Pumpkin Crate, starting at luck 0)
- **x10:** crates 1-9 use luck 0, 1, 2... (back to 0 after a Rare). If crates 1-9 give no Rare, crate 10 is at luck 9 and can only be Rare or better: CRAZY 0.06057%, Rare 99.939% (49.97% each). That happens in 9.30% of x10 packs.
- **x5:** if crates 1-4 are all Common, crate 5 is at luck 4 and can't be Common: CRAZY 0.04254%, Rare 48.915% (24.458% each), Uncommon 51.042% (10.208% each). That happens in 11.27% of x5 packs.
- **At luck 11 or more,** an x5 is already sure to include a Rare or better (the meter fills by crate 5 at the latest). The same holds for an x10 at luck 6 or more.

## 5. Deluxe crates (premium)
### 5.1 What they are
There are six, one for each classic crate on the lobby stand: Pumpkin, Candy, Spooky, Graveyard, Monster and Moonlight. Only these six have an ordinary CRAZY skin, so "much better CRAZY odds" means something for them.
- Same skins as their base crate.
- 2,000 coins.
- Odds Common 0, Uncommon 50, Rare 49, CRAZY 1. For Pumpkin that is each Uncommon 10%, each Rare 24.5%, the CRAZY 1%, and each Common 0% (still shown on the page).
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
	-- A CRAZY from a Deluxe crate is announced to the whole server like any other
	-- (AnnounceCrazy), so those messages come more often.
	Premium = {
		Price = 2000, -- coins
		Odds = { Common = 0, Uncommon = 50, Rare = 49, Crazy = 1 } :: { [string]: number },
		Category = "Deluxe",
		NameFormat = "Deluxe %s", -- %s = the base crate's name
		Blurb = "Same skins, no Commons, much better Rare and CRAZY chances.",
		Trim = rgb(255, 205, 60), -- gold bands and lid edge
		Look = { Sparkles = 16 }, -- these keys replace the base crate's Look
		ShakeTimes = 1.25, -- shakes this many times as hard as its base crate (Monster: 1.4 -> 1.75)
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
	Topper = base.Topper,
	Look = <base.Look with Premium.Look's keys on top, and
	        Shake = (base.Look.Shake or LookDefaults.Shake) * Premium.ShakeTimes>,
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
- `CrateArt` builds from the Look, Color, Trim and Glow. For the custom model it tries `CustomAssets.Clone("Props", crate.Id)` first, then `crate.Base`, so Kieran's custom Pumpkin Crate model is used for the Deluxe one too (a model named after the Deluxe Id replaces it).
- CrateUI's `themeOf(crate)` looks up `crate.Base or crate.Id`, so "Buy in the Shop" on a Deluxe page keeps the theme filter.
- `CrateIdle` and `CrateStand` need nothing (not on the stand).

### 5.5 Robux
`ProductId` 0 makes the button read "Coming soon", as today. When Kieran adds a product later, `ByProductId` finds the crate even while `PremiumCrates` is off. `CanOpenWithRobux(..., crate)` is then false, so the buyer gets 2,000 coins (the crate's coin `Price`), never nothing. (A crate whose *theme* is switched off is a different, older gap: section 15.)

### 5.6 Announcements
Every CRAZY is announced to the whole server (`AnnounceCrazy`). Per coin spent, a Deluxe crate gives a CRAZY about 15 times as often as a themed crate (1% for 2,000 coins against about 0.02% for 600), so those messages will come about 15 times as often from Deluxe spending. The CUSTOMIZE "Deluxe crates" bullet tells Kieran, with `AnnounceCrazy = false` as the way to turn them off.

## 6. Economy
Shop prices: Common 125, Uncommon 500, Rare 1,000, CRAZY 100,000. Duplicate refunds: 60, 250, 500, 50,000. "Value" means the expected skin value at Shop prices for a player who owns nothing. "Refund" means the expected duplicate coins for a player who already owns everything. The numbers are for the Pumpkin Crate; the newer crates differ by less than 0.01%. The `crates-luck.spec` economy test recomputes them from Config.

**One crate in one state:**

| One crate | Price | Rare or better | CRAZY | Value | Refund | Coins per Rare+ | Coins per CRAZY | Value per coin |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Themed, luck 0 | 600 | 15.02% | 0.02% | 366 | 182 | 3,995 | 3,000,000 | 0.61 |
| Themed, luck 14 | 600 | 43.02% | 0.02% | 611 | 305 | 1,395 | 3,000,000 | 1.02 |
| Themed, full meter | 600 | 100% | 0.04442% | 1,044 | 522 | 600 | 1,350,600 | 1.74 |
| x10 guaranteed crate (luck 9) | 600 | 100% | 0.06057% | 1,060 | 530 | 600 | 990,600 | 1.77 |
| x5 guaranteed crate (luck 4) | 600 | 48.96% | 0.04254% | 787 | 393 | 1,226 | 1,410,600 | 1.31 |
| **Deluxe** | 2,000 | 50% | 1% | 1,740 | 870 | 4,000 | **200,000** | **0.87** |
| Deluxe x10 guaranteed crate | 2,000 | 100% | 2% | 2,980 | 1,490 | 2,000 | 100,000 | 1.49 |
| Rare Crate (rarity crate) | 800 | 100% Rare | 0 | 1,000 | 500 | 800 | - | 1.25 |
| CRAZY Crate (rarity crate) | 80,000 | 100% CRAZY | 100% | 100,000 | 50,000 | - | 80,000 | 1.25 |
| Shop (you choose the skin) | 1,000 / 100,000 | - | - | - | - | 1,000 | 100,000 | 1.00 |

**Packs against the same number of single opens, from the same starting luck** (the only fair comparison: both start where the player is):

| Start | Pack | Rare or better per pack | Same number of single opens | Bonus | Value per crate (pack / singles) |
| --- | --- | --- | --- | --- | --- |
| Luck 0 | x5 | 0.918 | 0.889 | +3.3% | 398 / 390 |
| Luck 0 | x10 | 1.994 | 1.932 | +3.2% | 409 / 404 |
| The usual spread of luck (singles' long run) | x5 | 1.070 | 1.050 | +1.9% | 424 / 419 |
| The usual spread of luck | x10 | 2.134 | 2.101 | +1.6% | 421 / 419 |

**Over time** (a player who always buys the same way; long-run averages per crate):

| Always buys | Rare or better | CRAZY | Value | Refund | Coins per Rare+ | Coins per CRAZY | Value per coin |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Single opens** | 21.01% (1 in 4.76) | 0.0200% | **418** | 208 | **2,856** | **2,995,984** | **0.70** |
| x5 packs | 21.27% (1 in 4.70) | 0.0203% | 423 | 210 | 2,821 | 2,950,666 | 0.70 |
| x10 packs | 21.18% (1 in 4.72) | 0.0202% | 420 | 209 | 2,833 | 2,968,534 | 0.70 |

In plain English: **a pack is never worse than the same number of single opens** (the guarantee only removes lower rarities from one crate), **but the bonus is small**: about 3% more Rares from an empty meter, about 1% over time, because a guaranteed Rare also empties the meter. An x5 only promises an Uncommon: its guarantee crate is a Rare or better 49% of the time.

How long the meter stays at each level over time (single opens): 0: 21.0%, 1: 17.9%, 2: 14.8%, 3: 12.0%, 4: 9.5%, 5: 7.3%, 6: 5.5%, 7: 4.0%, 8: 2.8%, 9: 2.0%, 10: 1.3%, 11-15: 2.0% together.

**Invariants.** The economy test checks each one for every crate in `List`, at every reachable level, with and without each guarantee:
- **I1** A player who owns everything always loses coins: `price > Σ p(rarity) × DuplicateRefund`. Worst themed state: 530 < 600. Worst Deluxe state: 1,490 < 2,000.
- **I2** No crate state is a cheap route to CRAZY: `price / p(CRAZY) ≥` the CRAZY Crate's price (80,000). Worst themed state: 990,600 (720,600 with a theme's Rares hidden, test E2). Worst Deluxe state: 100,000. Over time: about 3,000,000 (themed) and 200,000 (Deluxe). Rarity crates satisfy it with equality or have no CRAZY.
- **I3** Themed and Deluxe crates are not a cheap route to Rare over time: coins per Rare or better ≥ the Rare Crate's price (800). Themed: 2,821 to 2,856. Deluxe: 4,000.
- **I4** The long-run value per coin of themed crates, packs and Deluxe crates is below 1. They stay worse value than the Shop (1.00) and the rarity crates (1.25). Themed singles and packs: 0.70. Deluxe: 0.87.
- **I5** `Luck.Steps × Luck.PerStep ≤ Odds.Common`, so luck never needs more Common than there is.
- **I6** From every starting level, a pack gives at least as many Rares or better, and at least as much value, as the same number of single opens.

Single states above 1 value per coin (full meter, guaranteed crates) are paid for by the unlucky opens before them. Only the averages matter, and they meet I3 and I4. No prices change: themed 600, rarity crates 100 / 400 / 800 / 80,000, Shop 125 / 500 / 1,000 / 100,000.

## 7. UI (`src/client/CrateUI.luau`)
All new words are in `Config.Crates.Text` (section 8.3), and text is never smaller than `Config.UI.MinTextSize` (14). The windows are views inside the Crates panel, not new panels, so they don't call `PanelManager.Register`. The Back and close buttons and Escape work as today.

### 7.1 Crate page: the luck strip, the phone summary line and the pack line
- **Where:**
  - PC (`compact` false): a new `Preview.Info` frame at the top of the right column, above `Preview.Items`. The grid moves down by its height. Luck is 56 px tall and the pack line 20 px. The side column stays as it is: it already uses nearly all of its height on PC (it would scroll and hide the buy buttons).
  - Phone (`compact` true): `Luck` and `Packs` go inside `Side`, right after `Odds`. LayoutOrder is a whole number, so renumber: `Odds` 4, `Luck` 5, `Packs` 6, then `Buy` 7, `Extras` 8 and `Nav` 9 (tests find them by name). On phones the side already scrolls with its buy buttons pinned below it.
  - **Phone summary line.** On a 640×302 screen only about 110 px of `Side` show above the pinned buttons, so the strip is out of view. A one-line TextLabel **`LuckLine`** goes at the top of the pinned `Buttons` frame (LayoutOrder 0, 20 px, `Text.LuckShort`: "Luck 4/15 · Rare or better 23.02%", or "Luck full · Rare or better 100%"). `buttonsHeight` grows by 20 + 6 when the line is shown (a crate with a meter and a player who isn't restricted), and `Side` shrinks to match. Restricted players and crates without a meter keep today's heights (32 px when restricted).
  - Tests find them with `preview:FindFirstChild("Luck", true)` and `preview:FindFirstChild("LuckLine", true)`.
  - **As built:** "Luck 4/15 · Rare or better 23.02%" is about 220 px at 14 px, and the pinned column is 160 px wide, so `LuckLine` wraps onto two lines: it is 36 px tall and `buttonsHeight` grows by 36 + 6 (on 640×302 the scrolling `Side` keeps about 65 px). On PC the strip's help line wraps too, so `Info` sizes itself to its text and the grid starts under it, wherever that is (the strip is about 100 px, not 56).
- **`Luck`** is a Frame, only for crates where `CrateLuck.Applies` and only when the player isn't restricted. It holds:
  - `Title`: "Luck 4 / 15" (`Text.LuckTitle`), or `Text.LuckFull` when the meter is full.
  - `Bar`: `Steps` segment frames named `Step1`..`StepN` when `Steps ≤ 20` (one `Fill` frame otherwise). Filled segments use the Rare colour (`Config.Rarity.Levels.Rare.Color`) and empty ones `Theme.Button`. No flashing, no pulsing, no sound.
  - `Chance`: "Rare or better, next crate: 23.02%" (`Text.LuckNext`). That is `Format(sum of RarityOdds(crate, boost) for the rarities at or above Rare)`.
  - `Help` (PC only, muted): `Text.LuckHelp`.
  - `EveryChance`: a TextButton that opens 7.2.

  PC layout: row 1 is Title (left), Bar (middle) and Chance (right); row 2 is Help and EveryChance. Phone layout: Title, Bar, Chance and EveryChance stacked, about 100 px. The help text is in the "Every chance" view.
  **As built (PC):** row 1 is Title (left half) and Bar (right half), row 2 is Chance and EveryChance, row 3 is Help. At a full meter the Title is the long `LuckFull` sentence, which doesn't fit beside the Bar and Chance in one row.
- **`Packs`**: a TextLabel that lists `Text.PackLine` for each count with a guarantee for this crate. It is hidden when there are none, or when the player is restricted.
- **The grid shows every skin of the crate** (the base crate's skins for Deluxe): `CrateOdds.Shown(crate, CrateLuck.Boost(crate, luckOf(crate)))`, each card printed with `Format`, so a skin that can't drop right now reads "0%" (at a full meter the 12 Commons and 5 Uncommons; on every Deluxe page the Commons). The cards keep their names (`Items.<itemId>.Chance`).
- **The odds line** uses the same boost and lists every rarity the crate has skins of, highest first, "0%" included ("CRAZY 0.04442%  Rare 99.956%  Uncommon 0%  Common 0%").

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
- `Confirm`: "Open 10 for 6,000 Coins", in the selected colour. It sends the level and the guarantee the window was drawn with (4.4).
- `Cancel`.

No timer and nothing preselected. Cancel closes it (Escape closes the whole panel, as today). The same layout is used on phones, with the buttons in a row at the bottom (36 px).

**As built:** the window's EveryChance button is only on crates with a meter (on the others every row would be the same; `PackHowFixed` already says every crate has the page's chances). The luck line in the body is `Text.PackLuckNow`. The guaranteed crate's chances list only the rarities it can give. Four more `Text` keys: `PackLuckNow`, `LuckHelpNoFull` (the help without its last sentence when `Luck.FullGuarantee` is false; `LuckFull` and `LuckShortFull` are then not used either), `TryAgain` and `RobuxFailed` (Roblox's purchase window didn't open).

### 7.4 After opening
- **"Open again"** (`OpenAnother`, on the reveal card and in the Quick open footer) calls `showPreview(crate)` and never invokes a remote. Remove the direct buys, and `lastCount` and `lastPaid` once nothing uses them.
- After a pack, the level comes from the last entry of `Results` (the batch's `LuckAfter` says the same).
- **Guaranteed crates** say so honestly. When a result has `Guaranteed`, the reveal card's `News` line starts with `Text.Guaranteed` (like `OneInAMillion`), and its Quick-open card gets a `Guaranteed` tag. The luck itself is not shown on the reveal: no "next time 25%!" nudges. The player sees it on the page.
- **Robux reveals** add `Text.RobuxLuck` ("Opened at luck 3 / 15") from the result's `Luck`, on crates with a meter: the level actually used (3.8).
- **`asResult`** also checks the new fields:
  - `Luck` and `LuckAfter`, if present, are whole numbers from 0 to `Steps`;
  - `LuckVersion`, if present, is a whole number ≥ 0;
  - `Guaranteed`, if present, is a rarity in `Config.Rarity.Order`;
  - otherwise the result is rejected, as today.

  A refusal (`Ok = false`) with a valid `Luck` updates `luck[CrateId]` under the version rule (3.7).
- **Deluxe crates** appear on the "Deluxe" tab with the price "2,000 Coins", x5 "10,000" and x10 "20,000", and a Robux button that says "Coming soon". No luck strip.

## 8. Reference
### 8.1 Remotes
| Remote | Kind | Client to server | Server to client | Created |
| --- | --- | --- | --- | --- |
| `OpenCrate` | RemoteFunction | `(crateId: string ≤ 64, count: number in Open.Counts (the client always sends one, 1 for x1), shownLuck: number, shownGuarantee: string?)` | `Result` (with `Results` for a pack) | top of `CrateService.Start()` (unchanged) |
| `PrepareCrateRobux` | RemoteFunction (new) | `(crateId: string ≤ 64, shownLuck: number)` | `{ Ok: boolean, Message: string, CrateId: string, Luck: number?, LuckVersion: number }` | top of `CrateService.Start()`, before the feature check; the client looks it up on the first R$ press, with a timeout |
| `CrateResult` | RemoteEvent | - | `Result` (Robux, F8, `RobuxLater`) | unchanged |
| `GetShopState` / `ShopState` | existing | - | `State` + `CrateLuck: { [crateId]: number }` + `LuckVersion: number` | ShopService (Push refreshes the GetShopState cache) |

### 8.2 Result (CrateService and CrateUI types)
The existing fields stay: `Ok, Message, CrateId, ItemId, ItemName, Rarity, Duplicate, Refund, Reel, WinIndex, Paid, OneInAMillion, Results`. New fields:
- `Luck: number?`: the level this crate was rolled at (crates with a meter). On a refusal it is the player's current level.
- `LuckAfter: number?`: the level after this crate. On a batch it is the level after the **last** crate.
- `Guaranteed: string?`: the `AtLeast` rarity used for this roll (pack guarantee or full meter); nil for a normal roll.
- `LuckVersion: number`: the player's `LuckVersion` after this result (every result, refusals too).

### 8.3 Config keys (all in `src/shared/Config/Crates.luau` unless noted)
- `Odds` (2.1). `SmallOdds` is removed.
- `Luck = { PerStep = 2, Steps = 15, FullGuarantee = true, Boost = "Rare", TakeFrom = "Common" }` (3.2).
- `RobuxOpen = { Cooldown = 1, HoldSeconds = 60, MaxHoldSeconds = 600, ClientWaitSeconds = 60, RemoteWaitSeconds = 5 }` (3.2, 3.8).
- `Open.Guarantee = { [5] = "Uncommon", [10] = "Rare" }` (4.2).
- `Premium = { Price = 2000, Odds, Category = "Deluxe", NameFormat, Blurb, Trim, Look = { Sparkles = 16 }, ShakeTimes = 1.25, New, SuggestedRobux = 249, Crates = { 6 lines } }` (5.2). `Categories` gains "Deluxe".
- `Admin.LuckSteps = 5` (3.9).
- `Text` changes and additions. A `%s` rarity is the rarity's `Name` from `Config.Rarity`.
  ```lua
  OpenAnother = "Open again", -- after a reveal: back to the crate's page, with your new chances
  OddsChanged = "Your chances for this crate just changed, so nothing was bought. Have a look at the new chances first.",
  RobuxFirst = "Your Robux crate is still on its way. This crate opens again once it has arrived.",
  RobuxLater = "Your Robux crate didn't open yet. Don't worry: Roblox will give it to you again soon (sometimes when you next join).",
  RobuxSlow = "Roblox is taking a while. Your Robux crate opens as soon as it arrives.",
  RobuxLuck = "Opened at luck %d / %d", -- on a Robux crate's reveal: the luck it really used
  LuckTitle = "Luck %d / %d", -- steps now, steps in a full meter
  LuckFull = "Luck full. Your next crate is %s or better for sure.",
  LuckNext = "%s or better, next crate: %s",
  LuckShort = "Luck %d/%d · %s or better %s", -- the phone line above the buy buttons
  LuckShortFull = "Luck full · %s or better %s",
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
  	CrateLuck = true, -- each themed crate's luck meter (Config.Crates.Luck); off keeps saved luck
  	CratePacks = true, -- x5 / x10 guarantees (Config.Crates.Open.Guarantee); off = packs open without one
  	PremiumCrates = true, -- the Deluxe crates (Config.Crates.Premium), on their own tab
  ```
- `src/shared/Config/init.luau`: `Data.Template.Crates = { Opened = 0, Luck = {} }` (3.3).

### 8.4 Module functions
- **CrateOdds:**
  - new: `Boost` (type), `Shares`, `CanGuarantee`, `Shown`, `Available`, `Higher`;
  - optional `boost` argument on `RarityOdds`, `Chances`, `Roll` and `Reel`;
  - `Format` is exact (2.2);
  - `Get` and `List` skip unavailable crates;
  - `Base` is followed in `Items` and `fixedOdds`.
- **CrateLuck** (new): section 3.4.
- **CrateService:**
  - `Grant(player, crate, paid, atLeast?)`;
  - `Luck(player, crateId)`;
  - `ReceiptStarted(player, crate)` and `ReceiptFinished(player, crate, granted)`;
  - `CanOpenWithRobux(player, waitSeconds?, crate?)`.
- **ShopService:** `State.CrateLuck`, `State.LuckVersion`, `LuckChanged(player)`, `LuckVersion(player)`; `Push` refreshes the `GetShopState` cache.
- **MonetizationService:** `processReceipt` pairs `ReceiptStarted` / `ReceiptFinished` and handles one crate receipt per player at a time.
- **CrateArt:** custom model falls back to `crate.Base`.
- **SkinSchema:** `crateIds()` leaves out crates with a `Base`.

## 9. Honesty and policy checklist
| # | Rule | How | Proved by (section 10) |
| --- | --- | --- | --- |
| H1 | Every chance a purchase can give is shown exactly before buying | A single open (coins or Robux) uses the grid and odds line at the current level, with every skin listed (0% ones too). A pack uses the "Every chance" rows (all levels) and the guaranteed crate's chances in the pack window. Deluxe and rarity crates use the grid. `Format` is exact, with 4 significant figures under 1%. | C1, C2, C3, C5, C10, O1 |
| H2 | The server rolls with those numbers | `Grant` calls `CrateLuck.Boost(crate, savedLevel, atLeast)` and `CrateOdds.Chances`, the same functions as the UI. The level comes only from the save. The pack guarantee is the one the window showed. | O3, S1, S6 |
| H3 | The odds can't change between seeing and buying without the player knowing | The shown-luck and shown-guarantee checks (coins), `PrepareCrateRobux` plus the holds (Robux), versions so an old level never comes back, a redraw with `OddsChanged` for changes on an idle page, and "Open again" going to the page. The rare late Robux receipt shows the level it used (3.8). | S2, S7, R1, R2, R4, C4, C6, C8 |
| H4 | No fake near misses | `Reel` draws from the odds actually rolled, and `TeaseGuard` keeps neighbours from being rarer. The beam shows the real rarity. | O4 |
| H5 | No pressure | No timers or countdowns. Luck never decays or expires. No "only N more" or "so close" wording (no "!" on a full meter), no flashing or sounds on the meter, nothing preselected in the pack window, Cancel always there. | Studio checklist (14); text review |
| H6 | No hidden odds changes | Luck changes only with the player's own opens (and Studio F8 admin buttons). There are no time, region or spending modifiers. Every change redraws the page or is refused at purchase. A switch never erases saved luck. | S1, S3, S4, C4 |
| H7 | PolicyService | Restricted players see no buy buttons, luck strip, phone luck line or pack line. `OpenCrate` and `PrepareCrateRobux` refuse them. A Robux receipt gives coins (2,000 for Deluxe) and never touches luck. | S5, R3, C7 |
| H8 | Robux receipts stay idempotent | `pending` and `Receipts` are unchanged. `undo` restores luck. A retry is counted once. Crate receipts of one player are handled one at a time. | R2, R4 |
| H9 | Kids don't spend big by accident | x5 and x10 always open the pack window first (Deluxe x10 costs 20,000 coins, CRAZY Crate x10 800,000). | C5 |
| H10 | The economy stays sane | I1 to I6, in code (D3, D5, D15) as well as in the tests | E1, E2, K1 |

## 10. Tests
Run `lune run tests/run -- crates` while building. It picks up both files below, because their names contain "crates". Run the full suite at the end.

### 10.1 New `tests/specs/crates-luck.spec.luau`
- **Config (K1):**
  - `Luck` has the right types, `PerStep > 0`, a whole-number `Steps ≥ 1`, and I5.
  - **Rarity order (D15):** `Luck.Boost` is in `Config.Rarity.Order` and below the top (rainbow) rarity; `Luck.TakeFrom` is below `Luck.Boost`; every `Open.Guarantee` value is a rarity at or below `Luck.Boost`, and every key is in `Open.Counts`. Then, in code: with `Guarantee[10] = "Crazy"`, `CrateLuck.Guarantee(PumpkinCrate, 10)` is nil; with `Luck.Boost = "Crazy"` or `Luck.TakeFrom = "Rare"`, `Applies` is false for every crate (restore afterwards).
  - `RobuxOpen` has positive numbers, and `MaxHoldSeconds ≥ HoldSeconds`.
  - `Premium.Odds` adds up to 100, and `Premium.ShakeTimes ≥ 1`.
  - Every `Premium.Crates` line names an existing themed `Base`, and Deluxe Ids are unique.
  - `Categories` contains `Premium.Category`.
  - The 6 Deluxe crates are in `List` with `Price` 2000, `ProductId` 0 and their base's skins. The Deluxe Monster's `Look.Shake` is above the Monster Crate's.
  - `Features.CrateLuck`, `CratePacks` and `PremiumCrates` are booleans.
- **Odds (O1-O5):**
  - **O1:** for every crate × level 0..Steps × `AtLeast` in {nil, each guarantee}: `Chances` add up to 100 (1e-9) and are all above 0; fixed skins are exactly their `Odds`; and the `RarityOdds` totals match. The Pumpkin table in 3.5 is checked at levels 0, 4, 14 and 15 with `Format` (full: "49.978%", "0.04442%"). So are Zombie Town (no CRAZY), Vampire Castle (0.0001% at every level and under every guarantee), Deluxe Pumpkin (10% / 24.5% / 1%) and the guaranteed crates of 4.5 ("0.06057%", "0.04254%").
  - **O2:** `Boost` is nil for rarity crates and Deluxe crates at any level, and for every crate while `CrateLuck` is off. `CanGuarantee(CommonCrate, "Rare")` and `CanGuarantee(CrazyCrate, "Rare")` are false; `CanGuarantee(PumpkinCrate, "Rare")` is true.
  - **O3:** 100,000 simulated rolls at level 7 match `Chances(crate, Boost(crate, 7))` within 5 standard deviations. The same holds for the x10 guaranteed crate.
  - **O4:** with a boost (level 15 and `AtLeast`), the reel's cards next to the win are never rarer than it.
  - **O5:** `Shown(PumpkinCrate, Boost(PumpkinCrate, 15))` has all 20 skins, in `Chances` order, 17 of them at 0; `Shown(PumpkinDeluxeCrate)` has 20 with the 12 Commons at 0; the non-zero entries equal `Chances`.
- **Economy (E1, E2):**
  - **E1:** a pure-maths check over Config of I1 to I4 and I6. It uses a Markov chain over the meter levels for the long-run numbers (singles, x5-only and x10-only), compares each pack with the same number of single opens from every starting level, and `T.note`s the section 6 tables. A Config change that breaks a rule fails the test, and its message names the rule.
  - **E2 (hidden Rares):** take Pumpkin's two Rares out of `Config.Shop.Items` (what `SkinsOff` does; put them back afterwards). Then `Applies(PumpkinCrate)` and `CanGuarantee(PumpkinCrate, "Rare")` are false, and for every level and every guarantee, `600 / p(CRAZY) ≥` the CRAZY Crate's price (worst: 720,600, the x5 guarantee). With the old rule this state was 100% CRAZY.
- **Server (S1-S7)** (copy `serverWorld` or move it to a small shared helper):
  - **S1:** forcing outcomes (temporarily set `crate.Odds`, as the one-in-a-million test does, and `Luck.PerStep = 0` where needed): a Common adds 1, an Uncommon adds 1, and a Rare or CRAZY resets to 0. The level stops at `Steps`. A full meter gives `Guaranteed = "Rare"`, a Rare or better, and then 0. `Result.Luck` and `LuckAfter` are right, and `data.Crates.Luck` holds the level (nil at 0).
  - **S2:** a missing, wrong-type or stale `shownLuck` is refused with `OddsChanged` and the right `Luck`, takes no coins and leaves the meter alone. The correct value opens.
  - **S3:** saved junk (`"4"`, -3, 2.5, 1e9 becomes Steps, NaN, a nested table, a non-table `Luck`, 100 junk keys) is cleaned. With 100 junk keys plus real levels (one of them a switched-off theme's crate, `WerewolfWoodsCrate`), `Set` keeps every real one and at most 64 entries. `ShopService.State(player).CrateLuck` lists only non-zero levels of real, available crates.
  - **S4:** rarity crates and Deluxe crates never change luck. **With `CrateLuck` off, a saved Pumpkin level of 7 survives an open (0 is expected as `shownLuck`), and reads 7 again when it is switched back on.** The F8 commands `CrateLuckUp`, `CrateLuckQuiet` and `CrateLuckReset` are registered only in Studio, work, and push State (Quiet doesn't).
  - **S5:** a restricted player is refused by `OpenCrate` and `PrepareCrateRobux`. With `PremiumCrates` off, Deluxe crates aren't in `List`, `OpenCrate` gives "NoCrate", and a Deluxe receipt (with a test `ProductId`) gives 2,000 coins.
  - **S6 (packs):**
    - With Rare forced rare (`Odds = { Common = 99.98, Rare = 0.02 }`, `PerStep = 0`), 200 x10 packs each contain a Rare or better, the 10th has `Guaranteed = "Rare"` exactly when 1-9 had none, and the same holds for x5 and Uncommon.
    - With normal odds, the `Results[k].Luck` sequence follows the meter rule, and `batch.LuckAfter == Results[#Results].LuckAfter`.
    - A `shownGuarantee` that differs from the server's (`nil` for an x10, or `"Uncommon"`) is refused with `OddsChanged` and takes no coins.
    - With `CratePacks` off there is no `Guaranteed`, and `shownGuarantee` must be nil.
    - One payment, as before.
  - **S7 (versions):** every luck change raises `LuckVersion`; every State and Result carries it; a refusal carries the current one. `GetShopState` called right after an open (within `ShopStateCooldown`) returns the new level, because `Push` refreshed the cache.
- **Robux (R1-R4):**
  - **R1:** `PrepareCrateRobux` refuses stale luck (returning `Luck`), crates with `ProductId` 0, and `RobuxCrates` off. It has its own cooldown: an `OpenCrate` of another crate right after it isn't "Slow down!". On success, coin opens of that crate get `RobuxFirst`, other crates open, and the hold ends with the server's `PromptProductPurchaseFinished(false)` and after `HoldSeconds`. After `PromptProductPurchaseFinished(true)` it lasts past `HoldSeconds`, until the receipt finishes (or `MaxHoldSeconds`).
  - **R2:** the receipt rolls at the saved level, and `CrateResult` has `Luck`, `LuckAfter` and `LuckVersion`. When the save fails, the level is exactly the old one, **the hold ends**, and the player gets a `CrateResult` with `RobuxLater`. A retry rolls at that same level (when nothing opened in between), is counted once and sends the normal result.
  - **R3:** a restricted buyer gets coins and an unchanged meter.
  - **R4 (bookkeeping):** the hold is released on every exit: `WaitForLoad` false, no data, already granted, and `handleReceipt` erroring (make `DataService.Get` throw once). Two receipts for the same crate at once: the first finishing doesn't release the second's hold (the counter). Two crate receipts of one player arriving together are handled one after the other; with the first one's save failing, the meter ends exactly where the second one left it (no drift), and both retries are counted once.
- **Client (C1-C11)** (fake remotes, as the x10 test does, except C8):
  - **C1:** with State `CrateLuck = { PumpkinCrate = 4 }`, the strip reads "Luck 4 / 15", 4 of 15 steps are filled, and Chance reads "23.02%". Every item card equals `Format` of the level-4 chances, and the odds line matches.
  - **C2:** CommonCrate and Deluxe have no `Luck` or `LuckLine`. The Deluxe tab lists 6 cards reading "2,000 Coins", and the Deluxe Robux button reads "Coming soon".
  - **C3:** "Every chance" has rows `Row0`..`Row15`, and `Row4` is marked. The texts equal the `Chances` maths. Vampire Castle has the fixed row.
  - **C4:** a ShopState push with a new level and a newer `LuckVersion` while the page is idle redraws it and shows `OddsChanged`. A push with an **older** `LuckVersion` changes nothing. A refused `OpenCrate` with `Luck = 6` redraws to 6 with `OddsChanged`; a `NoCoins` refusal with an unchanged level shows `NoCoins`.
  - **C5:** x10 opens `PackConfirm` and invokes nothing. The guarantee text equals the 4.5 chances, Cancel invokes nothing, and Confirm invokes `("PumpkinCrate", 10, 4, "Rare")`. The x1 button invokes `("PumpkinCrate", 1, 4, nil)`.
  - **C6:** "Open again" on the reveal and in the Quick-open footer shows the page and invokes nothing. The `Guaranteed` tag shows on a guaranteed result.
  - **C7:** a restricted player has no Luck, LuckLine, Packs or buy rows (pinned height 32, as today). On a phone (`gui:SetAttribute("ForceTouch", true)` and `AbsoluteSize` 640×302, as `candyrush.spec` does): `Luck` is inside `Side`; **`LuckLine` is inside the pinned `Buttons` frame (not the scrolling `Side`), reads "Luck 4/15 · Rare or better 23.02%", and `Buttons.Size.Y.Offset` is at least the sum of its visible rows plus the 6 px gaps**, with `Side` ending where `Buttons` starts. Every new frame lies within the panel.
  - **C8 (real server, no fake remotes):** the client's `OpenCrate`, `PrepareCrateRobux` and `GetShopState` call the real `serverWorld` (each client `OnServerInvoke` forwards to `server:invokeServer`), and the server's recorded `ShopState` / `CrateResult` events are replayed to the client in the order they were fired. A successful x1, an x10 and a Robux purchase (test product, receipt run through `MarketplaceService.ProcessReceipt`) never show `OddsChanged`, both with the push replayed before the answer (the real order) and after it. After each, "Open again" shows the new level.
  - **C9:** after an x10 result whose `Results[1].LuckAfter` is 5 and `Results[10].LuckAfter` is 0, "Open again" shows luck 0.
  - **C10:** at level 15 the Pumpkin grid has all 20 cards and 17 read "0%"; the Deluxe Pumpkin grid has 20 cards with the 12 Commons at "0%"; the odds line includes "Common 0%".
  - **C11 (Robux client):** `Mount` doesn't wait for `PrepareCrateRobux` (with it missing, `CrateResult` is still connected and the panel works); an R$ press with it missing shows the error after `RemoteWaitSeconds` and leaves the buttons usable; `PromptProductPurchase` throwing (override the harness stub) leaves them usable; a `RobuxLater` result ends the wait; a Robux reveal shows "Opened at luck 3 / 15".

### 10.2 Updates to existing specs
- `crates.spec.luau`: the rows of section 2.3.
  - The `serverWorld().open(player, crateId, count?, luck?, guarantee?)` helper sends `count or 1`, `luck` (default `CrateService.Luck(player, crateId)`) and `guarantee` (default `CrateLuck.Guarantee(crate, count)`).
  - The fake `OpenCrate` records the third and fourth arguments.
  - The x10 and Quick-open client tests press `PackConfirm.Confirm` after `OpenCoins10`.
  - The "spins to the server's result" test stays as it is, and the `OpenAnother` check stays: the button is still there.
  - Admin labels: `CrateLuckUp`, `CrateLuckQuiet` and `CrateLuckReset` in Studio only (like `CrateFreeCrazy`).
  - The "lists every crate on its tab" test is unchanged (it already compares tabs with `Categories` and visits ≤ 4 pages).
- `Core.spec.luau`: the switch list (lines 19-33) gains `CrateLuck`, `CratePacks` and `PremiumCrates`. Template: `template.Crates.Luck` is an empty table.
- `config.spec.luau` needs no edit, but it **fails** until `docs/V2-CHANGES.md` "## Turn a feature off" has a row ending `` | `CrateLuck = true,` | ``, `` | `CratePacks = true,` | `` and `` | `PremiumCrates = true,` | `` (section 11).
- `phoneui.spec.luau`: add `"PrepareCrateRobux"` to `REMOTE_FUNCTIONS`, and extend "pins the crate's Open buttons" with the `LuckLine` checks of C7.
- `skins.spec.luau` line 157: also check that a Deluxe crate exists only while its base theme is on.
- `crateart.spec`, `props.spec`, `towerrun.spec` and `crateidle.spec` need no edits. They loop over `Config.Crates.List` and must pass with the Deluxe crates in it: a valid Look, and the Ids count as prop names. Run them.

## 11. Docs to update
- `docs/CUSTOMIZE.md` > "Crates":
  - Rewrite the Odds bullet: the new numbers and exact display, with no `SmallOdds`.
  - Add four bullets in Kieran's words: **Luck meter** (`Luck` keys, what each does, "lower `Steps` = players near the top get a full meter", "a crate whose Rares are all hidden has no meter"), **Packs** (`Open.Guarantee`, the pack window, "never above `Luck.Boost`", and the honest summary of section 6: never worse than singles, small bonus, x5 only promises an Uncommon), **Robux opens** (`RobuxOpen`) and **Deluxe crates** (`Premium`: price, odds, one line per crate, `ShakeTimes`, Robux "Coming soon", not on the stand, CRAZY announcements about 15 times as often per coin and `AnnounceCrazy`).
  - Add the three switches.
  - Add a short "Keep it fair" note: the economy test and what each rule means.
- `docs/V2-CHANGES.md`:
  - a new dated section "Crate luck, packs and Deluxe crates (October 2026)": what players see, the switches, how to undo (switches), and the Studio checks;
  - **three rows in "## Turn a feature off"**, in the table's exact format (`config.spec` checks it):
    - `| Crate luck meter (off = plain odds; everyone's saved luck is kept for later) | \`CrateLuck = true,\` |`
    - `| Pack guarantees for x5 / x10 (off = packs open without one) | \`CratePacks = true,\` |`
    - `| Deluxe crates (off = the Deluxe tab disappears) | \`PremiumCrates = true,\` |`
  - "Known limits": the Robux luck case of 3.8, in plain words, and that the opening shows the luck used;
  - fix lines 162, 163, 224, 419 and 531.
- The `Crates.luau` header, the `CrateOdds.luau` header, the `CrateUI.luau` header, and the `CrateService.luau`, `MonetizationService.luau` and `ShopService.luau` headers (new remote, `shownLuck`, `shownGuarantee`, holds, receipt turns, `LuckVersion`).
- `.claude/commands/add-crate.md`, `add-skin.md` and `verify-v2.md` (2.3), and `tests/README.md`.

## 12. Feature switches
| Switch | Off means | Still works |
| --- | --- | --- |
| `CrateLuck` | No meter: plain odds, no strip, saved levels kept untouched, `shownLuck` must be 0 | Packs (without luck inside: each crate uses the page's odds, `PackHowFixed`), Deluxe |
| `CratePacks` | x5 and x10 open without a guarantee; no pack line | The pack window still opens (price, how packs work, Every chance) |
| `PremiumCrates` | Deluxe crates are hidden (no tab), `OpenCrate` refuses them, Robux receipts give coins | Everything else |
| `Crates` | Everything off as today; all remotes still exist | - |
| `RobuxCrates` | No Robux buttons; `PrepareCrateRobux` refuses | Coin opens |

Every `Mount` and `Start` works with each switch off: remotes are created before the feature checks, the client looks up `PrepareCrateRobux` only when R$ is pressed (with a timeout), and checks the flag before using a feature. Each switch can be flipped during a test (the code reads the flag at use time, not at load).

## 13. Build order and files
1. **Config:** `Crates.luau` (`Odds`, no `SmallOdds`, `Luck`, `RobuxOpen`, `Open.Guarantee`, `Premium`, `Categories`, `Admin.LuckSteps`, `Text`, the types, building the Deluxe entries and the theme filter, the header), `Features.luau` and `init.luau` (Template). Then `Core.spec` and the three V2-CHANGES switch rows (`config.spec`).
2. **Shared:** `CrateOdds.luau` (Boost, Shares, CanGuarantee, Shown, Format, Available, Higher, Base), the new `CrateLuck.luau` and `CrateArt.luau` (Base fallback). Then K1, O1-O5, E1 and E2.
3. **Server:** `CrateService.luau` (Grant, onOpen, PrepareCrateRobux, prepared and receiving holds, Luck, ReceiptStarted and ReceiptFinished, the Studio F8 commands, `PromptProductPurchaseFinished`), `MonetizationService.luau` (paired hold calls, one crate receipt per player at a time, `CanOpenWithRobux` with the crate), `ShopService.luau` (`State.CrateLuck`, `LuckVersion`, Push refreshes the cache) and `SkinSchema.luau` (`crateIds`). Then S1-S7 and R1-R4.
4. **Client:** `CrateUI.luau` (exact chances, every skin in the grid, the luck strip and the phone `LuckLine`, Every chance, the pack line and window, Open again, versions and in-flight rules, lazy Robux prepare, new result fields, Checking until luck is known, `themeOf`). Then C1-C11 and the `phoneui.spec` edits.
5. **Docs** (section 11).
6. `/tmp/claude-0/tools/stylua src`, then `/tmp/claude-0/check/check.sh <new-game path>` (no new type errors), `lune run tests/run -- crates`, and the full `lune run tests/run`.

Files: `src/shared/Config/Crates.luau`, `src/shared/Config/Features.luau`, `src/shared/Config/init.luau`, `src/shared/CrateOdds.luau`, `src/shared/CrateLuck.luau` (new), `src/shared/CrateArt.luau`, `src/shared/SkinSchema.luau`, `src/server/Services/CrateService.luau`, `src/server/Services/MonetizationService.luau`, `src/server/Services/ShopService.luau`, `src/client/CrateUI.luau`, `tests/specs/crates-luck.spec.luau` (new), `tests/specs/crates.spec.luau`, `tests/specs/Core.spec.luau`, `tests/specs/phoneui.spec.luau`, `tests/specs/skins.spec.luau`, `docs/CUSTOMIZE.md`, `docs/V2-CHANGES.md`, `tests/README.md`, `.claude/commands/add-crate.md`, `add-skin.md`, `verify-v2.md`.

No lobby (`Kit.prop`) or hub changes, no `Config.Hub.BuildVersion` bump, and no new Menu tiles.

## 14. Studio test list (Kieran's PC)
1. F8 > "Crates: +100k coins". Menu > Crates > Pumpkin Crate:
   - every chance is an exact number (5.082%, 4.8%, 7.5%, 0.02%) and no "<1%" appears anywhere;
   - the strip reads "Luck 0 / 15" and "Rare or better, next crate: 15.02%".
2. Open x1 a few times. After each Common or Uncommon the meter goes up one step, and the chances go up by 2% for Rare and down for Common. A Rare empties it. "Open again" goes back to the page (it never buys by itself). No open ever says "your chances just changed".
3. The odds check: with the Pumpkin page open, press F8 > "Crates: +1 luck on Pumpkin Crate, screen not told" (the page keeps the old numbers), close F8, then press "Open 600 Coins". Nothing is bought (coins stay the same), the page redraws with the new luck and says the chances changed. Then F8 > "+5 luck" while the page is open: it redraws straight away and says so.
4. x10:
   - the window shows the price, how packs work and the exact chances of the guaranteed crate;
   - Cancel buys nothing;
   - Confirm opens 10, and at least one is Rare or better;
   - a guaranteed last crate says GUARANTEED;
   - the meter on the page afterwards is the one after the 10th crate.
5. Level 15 (F8 "+5 luck" three times): the grid still shows all 20 skins, the Commons and Uncommons at 0%.
6. "Every chance" on PC and on a phone (Device emulator, iPhone on its side): rows readable, your row marked, nothing cut off. On phones the line "Luck 4/15 · Rare or better 23.02%" is visible right above the buy buttons without scrolling; the full strip is in the left column, which scrolls while the buy buttons stay put.
7. The Deluxe tab: six crates, 2,000 Coins, "Coming soon" on Robux, gold trim, NEW ribbon, chances 10% / 24.5% / 1% (Commons 0%), no luck strip; the Deluxe Monster shakes harder than the Monster Crate; "Buy in the Shop" opens the Shop on the Pumpkin theme; open one; not on the lobby stand.
8. A Robux crate (a real product id, as a test purchase):
   - while the Roblox window is open nothing else can be opened;
   - after buying, the opening plays, says "Opened at luck N / 15", and the meter moves;
   - cancel the window: everything opens again at once, and opening that crate with coins straight away doesn't say "Slow down!".
9. `Config.Crates.Policy.TestAsRestricted = true`: no buy buttons, luck strip, luck line or pack line; the chances are still shown.
10. Switch `CrateLuck`, `CratePacks` and `PremiumCrates` off one at a time: the game runs without errors in Output, and the right parts disappear. Open a Pumpkin Crate with `CrateLuck` off, switch it back on: the earlier luck is still there.
11. Leave and rejoin: the meter level is kept.

## 15. Found in today's code (not caused by this spec; separate fixes)
- **Robux receipts for a crate whose theme is switched off are never handled.** The theme filter removes the crate from `Config.Crates.List`, and `CrateOdds.ByProductId` only searches that list, so `handleReceipt` treats it as an unknown product and answers "not yet" forever. It should pay the coin fallback (`Price`, or `RobuxFallbackCoins`). Fix: keep the full crate list (for example `Config.Crates.AllList`, filled before the filter) for `ByProductId`, and make `CanOpenWithRobux` false for those crates. The same applies to a Deluxe crate whose base theme is off. Suggested as its own small change with a `crates.spec` test.
- **`DataService` has no session locking.** Two servers can load the same save at once. Luck adds no new exploit: coins, skins and luck are in one blob and always roll back together, and a Robux receipt is still saved before it is granted. Worth its own task (`UpdateAsync` with a session lock) if it ever matters.

## 16. Review (14 October 2026)
A review of the first version found 15 problems; all of them are fixed above. The main ones: guarantees and luck now need the rarity itself to be possible (D3, D5, test E2), the rarity order is enforced in code (D15), a normal open no longer shows "nothing was bought" (D16, 3.7, C8), switches never erase saved luck (3.6, S4), the Robux bookkeeping pairs every hold with a release and handles a player's receipts one at a time (3.8, R4), the pack comparison in section 6 is now like for like, small chances keep 4 significant figures (2.2), and the phone shows a luck line without scrolling (7.1).

### Decisions (points decided differently from the review, and why)
- **The hold after a finished purchase has a 10-minute safety limit** (`RobuxOpen.MaxHoldSeconds = 600`) instead of lasting until the player leaves. Roblox normally hands a receipt over within seconds, so this changes nothing in practice. But if Roblox never hands it over in this session, the crate would otherwise refuse coin opens for hours with "still on its way". The rare crate that rolls later shows the luck it used (3.8).
- **Studio test step 3 uses a Studio-only F8 button (`CrateLuckQuiet`) instead of the command bar.** A module required from the command bar during a playtest is a separate copy from the one the running game uses, so it can't reliably reach the game's loaded saves. The F8 panel isn't managed by PanelManager, so it doesn't close the Crates panel, and the page keeps its old numbers.
- **Two of the review's sample strings were recomputed.** The full-meter CRAZY chance is 0.02 / 45.02 = 0.044425%, which is "0.04442%" (not "0.04443%"), and the x10 guaranteed crate's is 0.02 / 33.02 = 0.060569%, which is "0.06057%" (not "0.06063%"). "0.04254%" for the x5 crate is right. Sections 2.2, 3.5, 4.5, 6 and the tests use the recomputed values.
- **The client tracks versions per crate**, not only one number. A single-crate update (a result or a refusal) can then never make the client skip a full State that holds other crates' changes.
- **Small additions beyond the review:** a meter also needs skins of `Luck.TakeFrom` (not only Boost), `CrateLuckReset` is Studio-only too, and the odds line lists 0% rarities like the grid. Each keeps the rules simple to explain.
