# Farever Toolset

Companion tools for **Farever** (Shiro Games): a combat-log viewer, a gear/drop
browser, and an in-game logging plugin.

## Tools (open in any browser)

- **tools/farever_log_viewer.html** — Load a combat log, see it split into fights
  with every enemy named, plus per-skill and per-target damage breakdowns.
- **tools/farever_gear_browser.html** — Browse items by slot (Head, Chest, Weapons,
  and so on). Shows rarity, level, affinity, granted skills, and where each item
  drops.

Both are single self-contained files. Double-click to open; nothing to install.

## Plugin (in-game logger)

**plugin/farever_logger.lua** goes in the farever-minimap mod's plugin folder:

```
<Farever install>/data/plugins/farever_logger.lua
```

It loads automatically and writes a combat-log file the viewer reads. It picks up
your character name on its own, so there's nothing to configure.

## Data

The `data/` folder holds the reference data the tools use (item names, talents,
drop locations). It can be refreshed when the game updates.

## Notes

- Armor drop locations are community-sourced; weapon and monster drops come from
  the game's reference data. Some items list more than one possible source.
- A "what you own vs. what's missing" collection checklist isn't possible from a
  plugin yet — it needs a feature the mod would have to add.
