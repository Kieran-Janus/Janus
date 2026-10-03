# Quick tweaks

Most tweaks are one line in `src/shared/Config.luau`. Just say what you want:

```
Make rounds 3 minutes, winner reward 250, and require 3 players.
```
```
Rename the currency to Gems and start new players with 50.
```
```
The game feels too grindy. Look at Config and propose a rebalance with before/after numbers, then apply it.
```

If a tweak needs code (not just a number), Claude should first move the value into Config, then change it.
