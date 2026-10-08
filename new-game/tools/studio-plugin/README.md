# Pumpkin Tools (Studio plugin)

A panel in Studio for changing how things look and what words say, by clicking them.

## Install (once)
From the `new-game` folder:

```
rojo build tools/studio-plugin --plugin PumpkinTools.rbxm
```

Then close and reopen Studio. A **Pumpkin Tools** button appears in the **Plugins** tab. Click it to show the panel.

## Looks
1. Click anything in the game view (a pumpkin, a lamppost, a tree...). The panel shows what it is and what every copy is called.
2. Find a model in the Toolbox, right-click it > **Copy Asset ID**, and paste the number into the box.
3. **Only the selected one(s)**: just what you clicked changes. **Every <name>**: every copy changes.

**Your own model (make your own skin):** build a model (or insert one and edit it), select it, press **Remember the selected model as my look**. Then click what it should replace and press **Give the selected one(s) my look** or **Give every copy my look**.

**Things in the rounds** (not in the lobby to click): the Pumpkin King, skeletons, bats, ghost cats, the shopkeeper, the King Hunt pumpkins, the Hide & Seek pumpkins and the King statue each have a **Toolbox code** button (uses the code in the box) and a **My look** button (uses your remembered model).

Ctrl+Z undoes a change. Save the place (Ctrl+S) to keep it.

## Words
- **Signs:** click a sign in the game view. Its words appear in the panel. Type new words, then **Only here** (just that sign) or **Everywhere** (every place those words show, also on screens and when the game changes them).
- **Words on screens:** press Play, open the panel, press **Pick text**, then click any words on the screen. Type the new words and press **Everywhere**. These changes are kept for when you stop the game (the panel adds them then).
- **Any words:** type the game's words exactly and your words, then **Change everywhere**.
- **Your word changes** lists them all; **Undo** removes one.

Word changes live in the place (`ReplicatedStorage > TextOverrides`), so save the place. Ask Claude Code to copy them into `src/shared/Config/TextOverrides.luau` so they are in git too.

## Code
`src/init.server.luau` (the panel), `src/Ui.luau` (building the panel), `src/Texts.luau` (word changes). The looks use the game's `src/server/Tools/Swap.luau` (`Selected`, `Toolbox`, `SelectedModel`, `UseModel`, `Character`); the words are shown by `src/client/TextOverrides.luau`.
