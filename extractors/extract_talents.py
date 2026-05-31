#!/usr/bin/env python3
"""
extract_talents.py  -  pull all class talent trees out of data.cdb

Run extract_names.py first to get data.cdb out of res.light.pak, then:
    python extract_talents.py data.cdb   (or names_out/data.cdb)

Talents in Farever are modeled as skills: each class unit has a talentTrees
entry (root/desc/talents[]), and each talent references a skill (with tier &
branch giving its tree position, and props.talent.maxPoints). This joins the
two and writes farever_talents.json. Re-run after each patch to auto-update.
"""
import sys, json
path = sys.argv[1] if len(sys.argv) > 1 else "data.cdb"
data = json.load(open(path, "r", encoding="utf-8"))
def sheet(n): return [s for s in data["sheets"] if s["name"] == n][0]
skills = {s["id"]: s for s in sheet("skill")["lines"] if s.get("id")}
units  = {u["id"]: u for u in sheet("unit")["lines"]  if u.get("id")}

def max_points(sk):
    p = sk.get("props")
    if isinstance(p, dict):
        return (p.get("talent") or {}).get("maxPoints")
    return None

out = {}
for cls in ("Warrior", "Mage", "Rogue", "Priest"):
    if cls not in units: continue
    trees = []
    for t in units[cls].get("talentTrees", []):
        nodes = []
        for tl in t.get("talents", []):
            sk = skills.get(tl.get("skill"), {})
            tx = sk.get("texts") or {}
            nodes.append({
                "skill": tl.get("skill"), "name": tx.get("name"),
                "desc": tx.get("desc"), "tier": tl.get("tier"),
                "branch": tl.get("branch"), "maxPoints": max_points(sk),
            })
        trees.append({"root": t.get("root"), "desc": t.get("desc"), "talents": nodes})
    out[cls] = trees
    print(f"{cls}: {sum(len(tr['talents']) for tr in trees)} talents")

json.dump(out, open("farever_talents.json", "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print("wrote farever_talents.json")
