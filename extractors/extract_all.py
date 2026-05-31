#!/usr/bin/env python3
"""
extract_all.py  -  master extractor: turn data.cdb into clean, joined JSON.

This is the data layer for everything (viewer naming, calculator, gear-drop
viewer, talent UI). Run extract_names.py first to get data.cdb out of the pak,
then:
    python extract_all.py data.cdb           (or names_out/data.cdb)

Writes one farever_data.json with these sections, relationships pre-joined:
  units      : id -> name, lvl, type, faction, stats, skills, talentTrees
  skills     : id -> name, desc, nature, type, props
  items      : id -> name, type, affinity, faction, rarity, level, iLevel,
               affixes (stats), skills, and DROPPED_BY (reverse loot lookup)
  itemTypes  : id -> name, slot info
  talents    : class -> trees (joined to skill names/desc/maxPoints)
  lootTables : id -> [ {item, proba, minLvl, maxLvl, conds} ]
  attributes : id -> scaling/operators (the damage-model curves)
  affinities : id -> name
  constants  : flat dict of the damage-model constants we care about

Re-run after every patch to regenerate everything at once.
"""
import sys, json

path = sys.argv[1] if len(sys.argv) > 1 else "data.cdb"
data = json.load(open(path, "r", encoding="utf-8"))

def sheet(n):
    for s in data["sheets"]:
        if s["name"] == n:
            return s
    return {"lines": [], "columns": []}

def rows(n):
    return sheet(n).get("lines", []) or []

def nm(o):
    return (o.get("texts") or {}).get("name")

def desc(o):
    return (o.get("texts") or {}).get("desc")

out = {}

# ---- skills (needed for talent join) ----
skills = {}
for s in rows("skill"):
    if not s.get("id"):
        continue
    p = s.get("props")
    skills[s["id"]] = {
        "name": nm(s), "desc": desc(s), "nature": s.get("nature"),
        "type": s.get("type"), "mastery": s.get("mastery"),
        "maxPoints": (p.get("talent") or {}).get("maxPoints") if isinstance(p, dict) else None,
    }
out["skills"] = skills

# ---- units ----
units = {}
for u in rows("unit"):
    if not u.get("id"):
        continue
    units[u["id"]] = {
        "name": nm(u), "lvl": u.get("lvl"), "maxLvl": u.get("maxLvl"),
        "type": u.get("type"), "faction": u.get("faction"),
        "stats": u.get("stats", []),
        "skills": [sk.get("skill") for sk in u.get("skills", [])],
    }
out["units"] = units

# ---- talents (join class tree -> skill names) ----
talents = {}
for cls in ("Warrior", "Mage", "Rogue", "Priest"):
    src = next((u for u in rows("unit") if u.get("id") == cls), None)
    if not src:
        continue
    trees = []
    for t in src.get("talentTrees", []):
        nodes = []
        for tl in t.get("talents", []):
            sk = skills.get(tl.get("skill"), {})
            nodes.append({
                "skill": tl.get("skill"), "name": sk.get("name"),
                "desc": sk.get("desc"), "tier": tl.get("tier"),
                "branch": tl.get("branch"), "maxPoints": sk.get("maxPoints"),
            })
        trees.append({"root": t.get("root"), "desc": t.get("desc"), "talents": nodes})
    talents[cls] = trees
out["talents"] = talents

# ---- loot tables ----
loot = {}
for lt in rows("lootTable"):
    lid = lt.get("id")
    entries = []
    for r in lt.get("loot", []):
        entries.append({"item": r.get("item"), "proba": r.get("proba"),
                        "minLvl": r.get("minLvl"), "maxLvl": r.get("maxLvl")})
    loot[lid] = entries
out["lootTables"] = loot

# ---- reverse "dropped by" index, attributed to the UNIT that uses each table ----
# A unit can reference up to two tables: props.bossLootTable and props.lootTable.
# We credit the drop to the unit (by display name) so "what drops X" is answered
# in terms of the monster, matching the in-game Codex.
dropped_by = {}
def credit(unit_id, table_id):
    if not table_id or table_id not in loot:
        return
    u = next((x for x in rows("unit") if x.get("id") == unit_id), None)
    src_name = (u.get("texts") or {}).get("name") if u else None
    for r in loot[table_id]:
        if r["item"]:
            dropped_by.setdefault(r["item"], []).append({
                "source": unit_id, "sourceName": src_name or unit_id,
                "table": table_id, "proba": r["proba"]})
for u in rows("unit"):
    p = u.get("props")
    if isinstance(p, dict):
        credit(u.get("id"), p.get("bossLootTable"))
        credit(u.get("id"), p.get("lootTable"))
# mobs also inherit their family loot table from their unitType (e.g. every
# Kobold-type mob drops the "Kobold" table). Credit those to each unit of the type.
type_table = {t.get("id"): t.get("lootTable") for t in rows("unitType") if t.get("id")}
for u in rows("unit"):
    tt = type_table.get(u.get("type"))
    if tt:
        credit(u.get("id"), tt)

# ---- zone hierarchy (continent regions -> child zones) ----
zones = {}
for z in rows("zone"):
    if not z.get("id"):
        continue
    zones[z["id"]] = {"name": nm(z), "parent": z.get("parent"),
                      "level": z.get("level"), "type": z.get("type")}
out["zones"] = zones

# ---- items (+ dropped_by joined in) ----
items = {}
for it in rows("item"):
    if not it.get("id"):
        continue
    items[it["id"]] = {
        "name": nm(it), "type": it.get("type"), "affinity": it.get("affinity"),
        "faction": it.get("faction"), "rarity": it.get("rarity"),
        "level": it.get("level"), "iLevel": it.get("iLevel"),
        "affixes": it.get("affixes", []), "skills": it.get("skills", []),
        "droppedBy": dropped_by.get(it["id"], []),
    }
out["items"] = items

# ---- item types (slots) ----
out["itemTypes"] = {t["id"]: {"name": nm(t), **{k: v for k, v in t.items()
                    if k not in ("id", "texts", "gfx")}}
                    for t in rows("itemType") if t.get("id")}

# ---- attributes (damage-model curves/operators) ----
out["attributes"] = {a["id"]: {"name": nm(a), "scaling": a.get("scaling"),
                     "defVal": a.get("defVal")}
                     for a in rows("attribute") if a.get("id")}

# ---- affinities ----
out["affinities"] = {a["id"]: nm(a) for a in rows("affinity") if a.get("id")}

# ---- selected constants (damage model) ----
con = {}
for c in rows("constant"):
    cid = c.get("id") or c.get("name")
    if not cid:
        continue
    if any(k in str(cid) for k in ("Armor", "Resist", "Crit", "Pen", "Fervor",
            "WeaponPower", "Reduction", "Scaling", "Mitig", "Level")):
        con[cid] = c.get("v", c.get("value"))
out["constants"] = con

json.dump(out, open("farever_data.json", "w", encoding="utf-8"),
          ensure_ascii=False, separators=(",", ":"))

print("wrote farever_data.json")
for k in ("units", "skills", "items", "itemTypes", "talents", "lootTables",
          "zones", "attributes", "affinities", "constants"):
    v = out[k]
    n = sum(len(t) for t in v.values()) if k == "talents" else len(v)
    print(f"  {k:12} {n}")
nd = sum(1 for it in items.values() if it["droppedBy"])
print(f"  items with a known drop source: {nd}")
