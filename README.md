# Farever Toolset

Companion tools for Farever (Shiro Games): a combat-log viewer, a gear/drop browser, and two in-game plugins — a combat logger and a class-mechanics tracker.

## Getting the files

There are no release downloads or packages. Browse the folders above and grab the files you want directly (use the **Raw** button on a file, or **Code → Download ZIP** to get everything at once).

## Tools (open in any browser)

- `tools/farever_log_viewer.html` — Load a combat log, see it split into fights with every enemy named, plus per-skill and per-target damage breakdowns.
- `tools/farever_gear_browser.html` — Browse items by slot (Head, Chest, Weapons, and so on). Shows rarity, level, affinity, granted skills, and where each item drops.

Both are single self-contained files. Double-click to open; nothing to install.

## Plugins (in-game)

Both plugins go in the farever-minimap mod's plugin folder and load automatically (the mod picks up changes about once a second, so you don't need to restart the game):

```
<Farever install>/data/plugins/
```

### `plugin/farever_logger.lua` — combat logger

Writes a combat-log file that the viewer reads. It picks up your character name on its own, so there's nothing to configure. Combat autosaves continuously, so a crash keeps your run.

### `plugin/chaincast_tracker.lua` — class-mechanics tracker

A small, movable overlay for mechanics the game shows poorly or hides behind the character sheet — Chaincast stacks, weapon stack counters, and passive cooldowns.

Each tracked mechanic is a colored shape (square, circle, diamond, or bar — your choice) that fills and changes color as it builds: red while building, yellow when full, green when ready. Drag it where your eye wants it during combat.

Settings live in a config block at the top of the file: pick the shape, size, which mechanics to track, and whether to show text labels. It only shows mechanics relevant to what you're playing, so it stays out of the way on other classes.

## Data

The `data/` folder holds the reference data the tools use (item names, talents, drop locations). It can be refreshed when the game updates.

## Notes

- Armor drop locations are community-sourced; weapon and monster drops come from the game's reference data. Some items list more than one possible source.
- A "what you own vs. what's missing" collection checklist isn't possible from a plugin yet — it needs a feature the mod would have to add.
- The tracker's coverage depends on which mechanics have been mapped so far; it's easy to add more as their in-game IDs are confirmed.
