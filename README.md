# Farever Toolset

Companion tools and game-data extractors for **Farever** (Shiro Games). Everything
here is built from the game's own `data.cdb` plus hand-sourced community data, so it
stays accurate and can be regenerated after each patch.

## What's in here

```
tools/      Web tools (open the .html files in any browser — no install)
plugin/     In-game Lua plugin for the farever-minimap mod
data/       Extracted game data (units, talents, items, drops, damage model)
extractors/ Python scripts that regenerate the data from the game files
```

## Tools (web — just open them)

- **tools/farever_log_viewer.html** — Reads combat logs produced by the logger
  plugin (or Companion `.log` files), segments them into fights, names every
  enemy from the real game data, and shows per-skill/per-target breakdowns.
- **tools/farever_gear_browser.html** — Browse all 518 items slot-first
  (Head, Chest, Weapons, etc.). Shows rarity, level, affinity, granted skills,
  and **where each item drops** — weapon drops from the game files (with %),
  armor locations from the community wiki (dungeon, class, normal/hard).

Both are single self-contained files. Double-click to open; nothing to install.

## Plugin (in-game logger)

**plugin/farever_logger.lua** drops into the farever-minimap mod's plugin folder:

```
<Farever install>/data/plugins/farever_logger.lua
```

It hot-reloads (~1s) and writes a combat-log store file the viewer reads. It
auto-detects your character name from the game (`farever.player`), so there's
nothing to type in.

### Known limitations / next steps for the plugin

- **Owned-collection reading is NOT possible from a Lua plugin today.** Reading
  which mounts/gliders/minions you own (for a "what to farm" checklist) needs the
  mod author to expose `ent.Hero.loadout` / collection state to the Lua API. The
  pointer chain is documented but lives mod-side (C++), not in plugins.
- **Dated log files: not yet implemented.** The logger currently writes to one
  store file that each session reuses. A nice improvement is to stamp the
  filename per session (e.g. `farever_log_2026-05-29_2315.lua`) so each run is a
  separate file. This is a small plugin edit but must be tested in-game.

## Data (extracted from the game)

- **farever_data.json** — master file: units, skills, items, item types, talents,
  loot tables, drop sources, zones, attribute scaling, damage constants, and a
  `wikiDrops` section (hand-sourced armor → dungeon/class/slot).
- **farever_wiki_drops.json** — standalone community drop tables (dungeon + world).
- **farever_talents.json** — all 4 classes' talent trees.
- **farever_unit_names.json / farever_id_to_name.json** — internal id → display name.
- **Farever_Damage_Model_from_CDB.md** — the confirmed damage model: armor
  mitigation formula `resist / (resist + 385 + 100·attackerLevel)`, the two-phase
  penetration engine (target debuffs additive, then your pen multiplicative), and
  empirical stat-rating fits.

## Regenerating data after a patch

The data is not hand-maintained — it's extracted. After a game update:

1. `python extractors/extract_names.py res.light.pak` → pulls `data.cdb` out of the pak.
2. `python extractors/extract_all.py data.cdb` → regenerates `farever_data.json`.
3. (optional) `python extractors/extract_talents.py data.cdb` → talent trees only.

Re-paste the community wiki armor tables if those changed, then the tools pick up
the new data automatically.

## Credits

Damage model and penetration engine reverse-engineered from in-game testing.
Community armor drop locations sourced from the Farever wiki. Weapon/monster drops
and all names/talents extracted directly from the game's `data.cdb`.
