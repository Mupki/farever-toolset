# Farever Damage Model — authoritative constants from data.cdb
# Extracted from game data; supersedes community-calc approximations.

## Armor / resistance mitigation (CONFIRMED)
Formula (from constant ResistanceScalableReductionFormula):
    mitigation = resist / (resist + a + b * attackerLevel)
    a = 385, b = 100
  => damage_taken_multiplier = 1 - mitigation   (i.e. you deal that fraction of raw)
  Example: L20 attacker vs 1500-armor target:
    1500 / (1500 + 100*20 + 385) = 1500/3885 = 0.386 mitigated -> 0.614 dealt
  NOTE: bosses store Armor = None; the per-unit 'resist' input is NOT a flat CDB
        field. Likely derived (level/type). STILL TO PIN DOWN.
  Related: ArmorLevelScalingRatio = {'float': 0.3}; Armor_ExpectedReduction = {'float': 0.25}

## Rating -> % conversions (CURVES, not flat divisors)
These use scalingOperator [2, 150, 1000, X] = a diminishing-returns curve.
A flat "x/1250" or "x/1555" is only a local linear fit; the real curve bends,
which is why patch-to-patch "divisor" numbers disagree.
    CritChance     <- CritChanceRating   scale=0.1  op=[2,150,1000,20]
    ArmorPenetration<- ArmorPenRating     scale=0.1  op=[2,150,1000,50]
    SpellPenetration<- SpellPenRating     scale=0.1  op=[2,150,1000,50]
    Fervor         <- FervorRating        scale=0.05 op=[2,150,1000,20]
  TODO: decode the [2,a,b,c] curve exactly (fit to 3 real rating->% data points,
        or find implementation in hlboot). Do NOT ship a flat divisor as truth.

## Attribute -> stat scaling (HYBRID — breaks old single-attr assumption)
    CritChance  <- Dexterity (0.014) AND Intellect (0.014)
    CritDamage  <- Strength  (0.01)  AND Faith     (0.01)

## Weapon contribution
    WeaponPowerRatio (mainhand) = 0.4
      "Percent of AP/SP scaling replaced by a flat amount from the weapon's base
       damage." Trinket = 1.0.  (This is likely the '0.4' modifier seen in-game.)

## Level scaling helpers
    LevelScalingFormula_EarlyMaxLevel start*pow(pow(end/start,1/(maxLevel-1)),x-1), maxLevel ref 50
    GearStatsRatio_Scaling_Bounds: 0.5 of stats @L1 -> 0.9 @L50

## Patch note (user-reported, UNVERIFIED): crit divisor 1250 -> 1555 (Aragon).
   Reconciliation: both are linear fits of the curve above; the curve is the truth.

## EMPIRICAL rating->% fits (from user's "Farever stat tests", PRE crit-change)
Measured in-game, single-variable, Warrior L16 base statline. These calibrate
the CDB operators [2,150,1000,X] (scale shown). The last operator param X tracks
the rate (ArmorPen X=50 ≈ 2x Crit X=20, matching measured 18.6 vs 9.3 %/100).

  ArmorPen (op X=50, scale .1): ~18.6 %/100 rating, divisor ~538.  LINEAR across 13-55.
  Crit     (op X=20, scale .1): ~9.3  %/100 rating, divisor ~1070. Near-linear 0-67,
                                begins to bend (DR) at higher rating toward the 1000 param.
  Fervor   (op X=20, scale .05): ~7.3 %/100 rating, divisor ~1365. LINEAR in tested band.

Crit base (0 rating) from attributes: ~5.4% at L1, ~5.6-5.9% mid-level with ~22-34
Dex/Int. Crit is hybrid Dex+Int (0.014 each per CDB). CritDamage ~150% base, barely
moves with Str/Faith in tested range.

NOTE: ALL above is PRE the crit nerf the user reported (1250->1555-ish). The METHOD
is proven: 3-4 fresh (rating, %) points post-patch will re-lock the crit curve exactly.
The operator-param insight (X drives rate) means once decoded, all four convert with
ONE formula parameterized by X — no per-stat divisor guessing.

## PENETRATION STACKING ENGINE (CONFIRMED — from user's Gruffy M.PEN test)
Two-phase mitigation, validated against 12 data-point pairs (fits within rounding).
Reading: test "damage" values are HIT DAMAGE (not %); full bypass = raw hit = 47.

  effective_mitigation = base_mit
                         * (1 - sum_of_target_debuffs)   # PHASE 1: additive pool
                         * (1 - talent_ignore_pct)        # PHASE 2: multiplicative
                         * (1 - gear_pen_pct)             # PHASE 2: multiplicative
  final_damage = raw_hit * (1 - effective_mitigation)

KEY RULES (the practical takeaways):
 - TARGET DEBUFFS are additive WITH EACH OTHER (Beefury 40% + Melting Faith 8%
   = 48% shred of the base resist pool). This is the party/external phase.
 - YOUR pen sources (gear %, talent IGNORE %) are MULTIPLICATIVE against the
   already-shredded pool -> stacking multiple pen sources has diminishing returns
   among themselves (NOT additive with debuffs, NOT additive with each other).
 - "IGNORE X%" (e.g. Piercing Light) is the strongest single mechanic: at 100%
   ignore the remaining mitigation is zeroed regardless of gear/debuffs -> damage
   flatlines at the raw ceiling. Can't over-cap or be wasted by party shred.
 - Test-derived: Gruffy (L17 open-world) base MAGIC mitigation ~= 0.40-0.41,
   raw Sunlight hit = 47. (Bosses store Armor=None in CDB, so this empirical
   read is how we learn a specific target's real defense.)
 - CONFIRMS earlier theory: a pen DEBUFF != adding to your pen STAT. Different phases.

## SUNLIGHT / PRIEST PARTY THEORYCRAFT (UNVERIFIED — Gemini, test later)
Plausible but NOT measured. Treat as hypotheses to validate:
 - Snapshotting: Sunlight base damage scales off the CASTER's Faith/Int at cast;
   secondary stats (crit, fervor, pen) read from whoever TRIGGERS the proc.
 - Cooldown brackets multiply: Blessing of Fervor (+10% fervor) x Crusader (+10%
   dmg) = 1.21 net before crit.
 - Node value ranking (4-player, modeled, NOT measured): Crit Burn +28.4%,
   Piercing Light +24.5%, +15% magic-to-hemorrhaged +15%; bleed nodes "trap".
 - AoE splash: 1 + 0.5*(targets-1).
 TODO: verify any of these with real multi-target / party logs before trusting.
