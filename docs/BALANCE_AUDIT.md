# Balance Audit Findings

> **Generated:** 2026-02-22
> **Status:** COMPLETE — 9 tests + 6 agent analyses + 2 specialist reviews

**Test Results: 215 passed, 3 failed (187 unit + 9 balance + 22 playtest = 218 total)**

---

## Table of Contents

- [Category A: Equipment & Economy](#category-a-equipment--economy)
- [Category B: Monster & Combat Balance](#category-b-monster--combat-balance)
- [Category C: Class & Ability Balance](#category-c-class--ability-balance)
- [Category D: Event & Loot Economy](#category-d-event--loot-economy)
- [Post-Audit Reviews](#post-audit-reviews)
- [Prioritized Fix List](#prioritized-fix-list)

---

## Category A: Equipment & Economy

### A1: Equipment Stat Budget Bounds
**Test 188 — FAILED (11 violations out of 265 equipment items)**

Budget = sum of positive stats (ATK + DEF + HP + SPD). Ranges: T1[0-10], T2[5-20], T3[5-32], T4[12-48], T5[13-58]

| Item | Tier | Slot | Budget | Expected | Over By |
|------|------|------|--------|----------|---------|
| fr_dimensional_plate | T4 | armor | 62 | 12-48 | +14 |
| fr_null_barrier | T4 | offhand | 54 | 12-48 | +6 |
| fr_rift_staff | T4 | weapon | 54 | 12-48 | +6 |
| nc_ossuary_plate | T4 | armor | 52 | 12-48 | +4 |
| fr_null_plate | T3 | armor | 44 | 5-32 | +12 |
| fr_null_shield | T3 | offhand | 37 | 5-32 | +5 |
| fr_null_staff | T3 | weapon | 36 | 5-32 | +4 |
| nc_ossuary_mail | T3 | armor | 37 | 5-32 | +5 |
| fr_rift_vest | T2 | armor | 26 | 5-20 | +6 |
| fr_rift_shield | T2 | offhand | 22 | 5-20 | +2 |
| nc_bone_vest | T2 | armor | 23 | 5-20 | +3 |

**Analysis**: All violations are R6 (Necropolis) and R7 (Fractured Realm) items. The late-game gear is significantly over-budget, especially armor pieces. This creates a power spike where R6/R7 equipment vastly outscales R5 gear.

**Options**: (A) Reduce stats on these 11 items to fit within budget, or (B) Widen the tier ranges to accommodate late-game power (T4 max → 62, T3 max → 44). Option A preserves balance; Option B accepts power creep.

### A2: Equipment Slot Coverage Per Tier
**Test 189 — PASSED**

All tiers have required slot coverage. Summary:
- T1: 4 weapon_main, 2 weapon_offhand, 2 chest, 3 head, 2 legs, 2 accessories, 1 backpack
- T2-T4: Full coverage across all slots
- T5: Present in weapon, chest, head, legs, offhand, accessories

### A3: Economy Value Consistency
**Test 190 — PASSED**

Average base_value scales monotonically across tiers. No equipment with base_value=0, no buy/sell inversions.

### A4: Consumable Power-vs-Cost Scaling
**Agent Analysis — COMPLETE**

**Key Metric**: value_per_gold = use_value / base_value (higher = more gold-efficient)

**HoT vs Instant Heal Efficiency Gap**:
- HoT tonics: 1.76-3.00 val/gold (T1 Minor Healing Tonic = 3.00)
- Instant food: 1.00-1.67 val/gold (T1 Mushroom Stew = 1.50)
- HoTs are ~2x more efficient, making food feel like vendor trash

**Tier Inversions (higher tier cheaper per HP)**:

| Item | Tier | val/gold | Beats |
|------|------|----------|-------|
| Miner's Ration | T2 | 2.75 | All T1 food except Minor Healing Tonic |
| Tidal Tonic / Magma Tonic | T3 | 2.40 | T2 Strong Healing Tonic (1.80) |
| Starlight Elixir / Grave Elixir | T4 | 2.50 | Nearly all lower-tier items |

**Dead Consumables** (no use_effect defined):
- `minor_stamina_snack` (T1, 6g) — does nothing when used
- `smoke_bomb` (T1, 12g) — does nothing when used

**Other Issues**:
- `nc_phylactery_tonic` (refillable T4): 36 hot_heal for 105g (0.34 val/gold) — weakest tonic in game
- `fr_entropy_charge` (T4 debuff): 80g for 8 accuracy debuff — 2.5x pricier than comparable `nc_banshee_vial` (35g for 7)
- `legendary_feast` (T4): 50 heal_and_buff_all for 80g (0.63 val/gold) — worst healing efficiency

**Recommendations**:
1. Fix dead consumables: add use_effect to minor_stamina_snack and smoke_bomb
2. Raise T3/T4 HoT base_value to enforce descending val/gold by tier
3. Buff Phylactery Tonic use_value from 36 to 90
4. Raise Miner's Ration base_value from 8 to 15
5. Reduce Entropy Charge base_value from 80 to 45

---

## Category B: Monster & Combat Balance

### B1: Monster Stat Envelope
**Test 191 — FAILED (14 violations out of 112 monsters)**

Ranges: T1 HP[40-300] ATK[8-60] DEF[2-25] SPD[8-50], T2 HP[100-500] ATK[15-80] DEF[6-40] SPD[12-50], T3 HP[250-1500] ATK[25-100] DEF[10-50] SPD[15-60]

| Monster | Tier | Stat | Value | Expected | Issue |
|---------|------|------|-------|----------|-------|
| cultist_enforcer | T2 | health | 54 | 100-500 | Likely wrong tier (should be T1) |
| cultist_enforcer | T2 | defense | 4 | 6-40 | Confirms wrong tier |
| webspinner | T2 | health | 58 | 100-500 | Likely wrong tier (should be T1) |
| webspinner | T2 | defense | 4 | 6-40 | Confirms wrong tier |
| tf_sawbone_enforcer | T3 | health | 110 | 250-1500 | Likely wrong tier (should be T2) |
| tf_sawbone_enforcer | T3 | attack | 24 | 25-100 | Confirms wrong tier |
| tf_sawbone_enforcer | T3 | defense | 8 | 10-50 | Confirms wrong tier |
| fr_entropy_slug | T1 | health | 304 | 40-300 | Slightly over — R7 T1 expected to be high |
| fr_rift_imp | T1 | speed | 53 | 8-50 | R7 speed creep |
| fr_void_mite | T1 | speed | 53 | 8-50 | R7 speed creep |
| fr_corruption_champion | T2 | health | 540 | 100-500 | R7 T2 elite — slightly over |
| fr_corruption_champion | T2 | speed | 52 | 12-50 | R7 speed creep |
| fr_dimensional_horror | T2 | speed | 56 | 12-50 | R7 speed creep |
| tf_rustwood_construct | T2 | speed | 11 | 12-50 | Construct should be slow (possibly intentional) |

**Analysis**: Two distinct issues:
1. **Tier misassignment** (HIGH): `cultist_enforcer`, `webspinner`, and `tf_sawbone_enforcer` have stats that don't match their declared tier. They should be re-tiered.
2. **R7 stat creep** (MEDIUM): Final Realm monsters slightly exceed T1/T2 bounds — may be intentional to reflect endgame difficulty. Consider widening R7 bounds or capping stats.
3. **tf_rustwood_construct** speed=11 (LOW): Likely intentional (slow construct). Could widen T2 SPD floor to 10.

### B2: Monster Ability Reference Integrity
**Test 192 — PASSED**

All 112 monsters have valid ability references. AI tier / ability count rules are consistent.

### B3: Loot Table Integrity
**Test 193 — PASSED**

All 38 loot tables valid. All monster loot_table_id references resolve. No negative weights, no min>max qty issues.

### B4: Monster Pool Diversity Per Region
**Agent Analysis — COMPLETE**

**Role Distribution**:

| Region | Total | T1 | T2 | T3 | Melee% | Ranged% | Mage% | Families | Boss Roles |
|--------|-------|----|----|----|---------||---------|----------|------------|
| R1 Thornhaven | 16 | 7 | 5 | 4 | **87.5%** | 6.3% | **0.0%** | 5 (beast, humanoid, ooze, plant, construct) | melee+melee |
| R2 Fungalmire | 18 | 6 | 8 | 2 | 50.0% | 11.1% | 38.9% | 1 (spore) | **mage+mage** |
| R3 Sunken Strand | 20 | 6 | 10 | 2 | 60.0% | 15.0% | 25.0% | 1 (coastal) | **melee+melee** |
| R4 Ashen Horizons | 16 | 6 | 8 | 2 | 62.5% | 12.5% | 25.0% | 1 (volcanic) | **melee+melee** |
| R5 Starfall Expanse | 18 | 6 | 8 | 2 | 44.4% | 11.1% | 44.4% | 1 (crystal) | mage+melee |
| R6 Necropolis | 16 | 6 | 8 | 2 | 50.0% | 12.5% | 37.5% | 1 (necro) | mage+melee |
| R7 Final Realm | 16 | 6 | 8 | 2 | 56.3% | 12.5% | 31.3% | 1 (void) | **mage+mage** |

**Findings**:
1. **R1 has ZERO mage monsters** (87.5% melee) — players never learn to counter magical threats before R2's 39% mage pool. Abrupt difficulty shock on region transition.
2. **Both bosses share the same role in 4 regions** — R2 (both mage), R3 (both melee), R4 (both melee), R7 (both mage). Players who build to counter one boss type trivially defeat both.
3. **T3 monsters are exclusively bosses** — no "tough regular" T3 enemies in any region. Dungeon progression feels binary (T1/T2 fodder → boss).
4. **All regions except R1 are mono-family** — family-based mechanics would be trivial in R2-R7.
5. **tf_sawbone_enforcer** confirmed wrong tier (T3 with T2 stats, ai_tier 2) — corroborates Test 191 finding.

**Recommendations**:
1. Add 2-3 mage/ranged monsters to R1 (target: 65% melee, 15% ranged, 20% mage)
2. Diversify boss roles: ensure each region's 2 bosses have different combat roles
3. Add 1-2 non-boss T3 "tough regular" enemies per region to smooth difficulty curve
4. Move tf_sawbone_enforcer to T2 (matching its stats and ai_tier)

---

## Category C: Class & Ability Balance

### C1: Class Ability & Passive Reference Integrity
**Test 194 — PASSED**

All 15 classes have valid ability and passive references.

### C2: Class Stat Growth Consistency
**Test 195 — FAILED (1 violation)**

| Class | Archetype | HP/lv | ATK/lv | DEF/lv | SPD/lv | Total | Expected | Issue |
|-------|-----------|-------|--------|--------|--------|-------|----------|-------|
| lich | dps | +4 | +2 | +1 | +2 | 9 | 10-18 | Below minimum |

**Analysis**: Lich has the lowest total growth in the game (9/level). This is thematic (glass cannon / undead decay) but creates a scaling problem — at level 20, Lich falls ~20 stat points behind other DPS classes. The Phylactery passive (revive on death) partially compensates, but the growth penalty may be too harsh.

**Options**: (A) Raise Lich HP growth from +4 to +5 (total=10, minimum viable), or (B) Raise ATK growth from +2 to +3 (total=10, lean into glass cannon identity). Option B preserves the fragile theme while keeping growth competitive.

### C3: Ability Power Analysis
**Agent Analysis — COMPLETE**

**Methodology**: `effective_power = base_damage * (1 + attack_scaling)`, `power_per_cd = effective_power / max(cooldown, 1)`

**Single-Target Damage Outliers** (average power/cd for non-outlier class abilities ~6.8):

| Ability | Class | Base | Scaling | CD | Power/CD | vs Average | Verdict |
|---------|-------|------|---------|-----|----------|------------|---------|
| death_bolt | Lich (R6) | 22 | 1.5 | 2 | **27.50** | 4.0x | **CRITICAL OUTLIER** |
| light_lance | Prism Lancer (R5) | 18 | 1.3 | 2 | **20.70** | 3.0x | **OUTLIER** |
| cinder_strike | Ashblade (R4) | 16 | 1.4 | 2 | **19.20** | 2.8x | **OUTLIER** (also applies burning) |
| void_tear | Void Herald (R7) | 16 | 1.2 | 2 | **17.60** | 2.6x | **OUTLIER** |
| lightning_bolt | Stormcaller (R3) | 14 | 1.2 | 2 | **15.40** | 2.3x | **OUTLIER** |
| fungal_frenzy | Fungal Berserker (R2) | 12 | 1.3 | 2 | 13.80 | 2.0x | High |

**Pattern**: All 5 outliers share `high base + high scaling + CD 2`. This is a systematic design issue, not individual item tuning.

**Region Power Creep**:

| Region | Avg DPS Power/CD | Ratio vs R1 |
|--------|------------------|-------------|
| R1 Striker | 6.80-8.80 | 1.0x |
| R2 Fungal Berserker | 13.80 | 1.8x |
| R3 Stormcaller | 15.40 | 2.0x |
| R4 Ashblade | 19.20 | 2.5x |
| R5 Prism Lancer | 20.70 | 2.7x |
| R6 Lich | 27.50 | 3.6x |
| R7 Void Herald | 17.60 | 2.3x |

**Heal Outliers**:
- **healing_tide** (Tidechaser): 18 base, CD 2 → **9.0 heal/cd** — outperforms all other heals
- **natures_embrace** (Druid): 15 base + regenerating, CD 2 → **7.5 heal/cd** + HoT

**Strictly Better Pairs**: R1 Striker abilities (`str_precise_strike` at 8.80 power/cd) are strictly dominated by every R3+ DPS ability (same target type, higher power, same or lower CD).

**AoE Balance**: Well-balanced at 1.40-4.80 power/cd range. AoE-to-single ratio ~3:1 is reasonable.

**Recommendations**:
1. **Nerf death_bolt urgently** — reduce base to 18 + raise CD to 3 (15.0 power/cd)
2. **Raise CD to 3** for light_lance, cinder_strike, void_tear, lightning_bolt
3. **Remove burning from cinder_strike** — it double-dips (top-tier damage AND DoT)
4. **Buff R1 Striker** — lower str_precise_strike CD from 3 to 2 (13.2 power/cd)
5. **Raise healing_tide CD to 3** (6.0 heal/cd, matching the pack)

### C4: Passive Dead Pick Audit
**Agent Analysis — COMPLETE**

**Orphaned Passives** (4 found — dead data from earlier design):
- `def_iron_skin` — claims defender, superseded by `bulwark_stance`
- `def_front_line_bonus` — claims defender, superseded by `shielding_presence`
- `str_killer_instinct` — claims striker, different from active `killer_instinct` (naming collision risk)
- `str_execute_momentum` — claims striker, superseded by `finishers_instinct`

**Strictly Worse Equipment Passive Pairs**:

| Weaker | Stronger | Issue |
|--------|----------|-------|
| gw_passive_heal (2 HP/round) | gw_passive_regen (3 HP/round) | Same trigger, lower value |
| ss_passive_speed (+2 SPD) | ss_passive_swiftness (+3 SPD) | Same trigger, lower value |
| se_passive_temporal (-1 weapon CD) | se_passive_cdr (-1 ALL CDs) | Same trigger, strictly narrower |

**Underpowered Class Passives**:
- **living_bond** (Warden): +5 HP flat, never scales. At level 5, `verdant_growth` gives all allies +7 HP each. Synergy rating: **C**
- **dark_pact** (Dark Channeler): +2+lvl ATK with -5 HP cost. `static_charge` (Stormcaller) gives +3+lvl with NO cost. Pays more for less.
- **reality_warp** (Void Herald): +2+lvl/2 ATK — half the scaling of `focused_light` or `static_charge`

**Overpowered Equipment Passive**:
- **se_passive_cosmic** (Cosmic Attunement): +2 ATK, +2 DEF, +2 SPD, +5 HP — equivalent to 3-4 other equipment passives combined

**Class Synergy Ratings**:

| Rating | Classes |
|--------|---------|
| A+ | Fungal Berserker, Stormcaller, Pyrewarden, Ashblade |
| A | Defender, Striker, Tidechaser, Prism Lancer, Voidwalker |
| B+ | Druid, Lich |
| B- | Dark Channeler, Void Herald |
| C | Warden (living_bond drags it down) |

**Recommendations**:
1. Delete or repurpose 4 orphaned passives (dead data)
2. Fix strictly-worse equipment pairs (add secondary effects or merge)
3. Buff living_bond to scale with level: "+2+level HP" or rework to heal amplification
4. Buff dark_pact to +3+level ATK (matching static_charge) with -5 HP cost
5. Buff reality_warp to +3+level ATK (remove /2 divisor)
6. Nerf se_passive_cosmic: reduce to +1/+1/+1/+3 HP

---

## Category D: Event & Loot Economy

### D1: Event Outcome Integrity
**Test 196 — PASSED**

All 70 events have valid structure, item references resolve, status references resolve, damage amounts are positive.

### D2: Event Reward Scaling by Region
**Agent Analysis — COMPLETE**

| Region | Events | Avg Gold/Evt | Avg Items/Evt | Avg Dmg/Evt | Net Gold | Verdict |
|--------|--------|-------------|---------------|-------------|----------|---------|
| R1 Thornhaven | 10 | ~7.8 | ~2.1 | ~4.2 HP | +4.6 | Baseline — Balanced |
| R2 Fungalmire | 10 | ~5.4 | ~2.8 | ~3.5 HP | +2.6 | Item-rich, gold-light |
| R3 Sunken Strand | 10 | ~7.2 | ~2.6 | ~3.1 HP | +4.8 | Balanced, slightly generous |
| R4 Ashen Horizons | 10 | ~8.6 | ~2.3 | ~5.8 HP | +6.6 | High gold, high damage |
| R5 Starfall Expanse | 10 | ~5.1 | ~2.9 | ~3.0 HP | +0.9 | Item-rich, gold-costly |
| R6 Necropolis | 10 | ~12.4 | ~2.3 | ~4.1 HP | +10.3 | **TOO GENEROUS — gold outlier** |
| R7 Fractured Realm | 10 | ~6.8 | ~2.5 | ~5.6 HP | +3.0 | High risk, moderate reward |

**Findings**:
- **R6 Necropolis gold is 2.2x R1 baseline** — Restless Tomb, Grave Offering, Crypt Entrance, Spectral Echo all yield 20-30g with minimal risk
- **R2 Fungalmire is gold-poor** — heavy on material drops but almost no raw gold
- **R4/R7 damage-only outcomes** — several events deal 6-8 party damage with zero reward
- **R5 Time Merchant** has 25% chance to lose 15-22g and get almost nothing back

**Recommendations**:
1. Reduce R6 gold rewards by 30-40% (cap best outcomes at 20-22g)
2. Add 4-8g to 2-3 R2 events
3. Add consolation items to damage-only outcomes in R4/R7
4. Reduce R5 Time Merchant swindle cost to 10-15g

### D3: Loot Table Weight Distribution
**Agent Analysis — COMPLETE**

**Regional tables**: All 28 well-structured, no dominant items (max 33%), consistent patterns across regions.

**Monster-type tables with issues**:

| Table | Top Item | Top % | Empty % | Entries | Issue |
|-------|----------|-------|---------|---------|-------|
| lt_food_meat | raw_meat | 80% | 20% | 2 | Dominant item + low variety |
| lt_bat_parts | bat_wing | 70% | **30%** | 2 | Dominant + excessive empty + low variety |
| lt_undead_parts | bone_fragment | 65% | 20% | 3 | Dominant item |

**Other findings**:
- R2 uncommon has anomalously high empty rate (15% vs 8-10% for other regions)
- R7 boss max_drops=6 (vs 5 everywhere else) — good endgame touch
- All boss tables guarantee boss_trophy at weight 20 — excellent consistency
- lt_base_materials is the only table with 0% empty — good design

**Recommendations**:
1. Add 1-2 entries to lt_bat_parts and lt_food_meat, reduce empty rates
2. Add secondary drop to lt_undead_parts (e.g. iron_scrap)
3. Reduce R2 uncommon empty from 15% to 10%
4. Consider extending R7's max_drops=6 to R6 bosses

---

## Post-Audit Reviews

### Gameplay Guide Agent Review
**COMPLETE**

**Key Insight**: The audit's priority list is ordered by data severity, but player experience priority differs. Issues affecting the first 2 hours of play matter more for retention than late-game power outliers.

**Teachability Issues**:
- **R1's all-melee pool is the #1 teachability failure** — players learn one rule (row positioning), then R2 silently changes it with 39% mage enemies. This is a conceptual rug-pull, not a difficulty spike.
- **Dead consumables erode item trust** — a player who buys smoke_bomb (12g) and sees nothing happen will distrust the entire item/crafting system. 5-minute fix, outsized retention impact.
- **Mis-tiered monsters make difficulty unreadable** — players use monster difficulty to gauge readiness. T2 monsters with T1 stats feel like bugs.

**Frustration Points**:
- **Damage-only event outcomes (R4/R7)** — pure punishment with zero reward teaches players to skip events entirely, collapsing a major content pillar. Every negative outcome needs *some* consolation.
- **R5 Time Merchant (25% swindle)** — feels like a slot machine, not a decision, in R5's already gold-scarce economy.
- **The Lich paradox** — strongest ability (4x average) + weakest growth (9/level) = coin-flip design. Feels awful regardless of outcome.

**Progression Feel**:
- **R1-to-R2 is the critical retention cliff** — three things change simultaneously: mage enemies appear, R2 classes are 2x stronger, both R2 bosses are mage-type.
- **R6 = loot pinata, R7 = less generous** — inverts the intended difficulty arc. R6-R7 should escalate, not deflate.
- **Striker obsolescence** — the first class every player invests in becomes dead weight by R2. Lowering str_precise_strike CD to 2 keeps R1 heroes viable.

**Player Experience Priority (reordered)**:
1. Fix dead consumables (smoke_bomb, minor_stamina_snack) — first-hour trust
2. Add mage/ranged monsters to R1 — first-region teachability
3. Fix monster tier misassignments — difficulty legibility
4. Add consolation rewards to damage-only events — event engagement
5. Nerf death_bolt + CD-2 outlier pattern — combat fairness
6. Buff Striker + fix Warden's living_bond — starter class viability
7. Reduce R6 gold + rebalance R6/R7 equipment — late-game progression arc
8. Diversify boss roles per region — strategic depth at peak moments

**Deprioritized** (low player impact): orphaned passives, strictly-worse passive pairs, R7 speed creep, loot table dominance, HoT vs food efficiency gap.

### Item Curator Agent Review
**COMPLETE**

**Safe to Implement Immediately** (zero cross-reference risk):
- All ability stat changes (death_bolt, light_lance, cinder_strike, void_tear, lightning_bolt, healing_tide, str_precise_strike)
- Lich class stat growth
- All passive stat changes (living_bond, dark_pact, reality_warp, se_passive_cosmic)
- Dead consumable fixes (minor_stamina_snack, smoke_bomb)
- Delete `str_execute_momentum.json` only (no code references)

**Safe but Verify Recipe Economics**:
- nc_phylactery_tonic use_value 36→90 (check alchemist recipe input costs)
- fr_entropy_charge base_value 80→45 (check R7 alchemist recipe costs)
- miners_ration base_value 8→15 (check R2 chef recipe costs)

**Requires Dungeon JSON Coordination**:
- Monster tier changes (cultist_enforcer, webspinner → T1; tf_sawbone_enforcer → T2) — must also move them in dungeon_thornhaven.json's `tier1_monster_ids`/`tier2_monster_ids` arrays

**Requires GDScript Code Changes First**:
- 3 orphaned passives (def_iron_skin, def_front_line_bonus, str_killer_instinct) are still hard-referenced in CombatController.gd and DataRegistry.gd for validation. Must update code before deleting JSON files.

**Requires Gameplay Testing**:
- 11 over-budget equipment stat reductions — significant numbers (HP reductions of 2-14 points); items appear in boss loot tables and shop pools. Reducing stats makes R6/R7 boss loot feel less rewarding.

**No Recolour/Icon Impact**: All changes are numeric fields only (stats, prices, cooldowns). No icon_path, display_name, or ID changes needed. Ledger, HTML reference, and recolour pipeline unaffected.

---

## Prioritized Fix List

### CRITICAL (Game-Breaking Power Imbalances)
1. **death_bolt is 4x average power/cd** — Lich's primary ability (27.5 power/cd) dwarfs everything. Reduce base to 18 + raise CD to 3
2. **5 DPS class abilities share CD 2 outlier pattern** — light_lance, cinder_strike, void_tear, lightning_bolt, fungal_frenzy all need CD raised to 3
3. **cinder_strike double-dips** — top-tier damage AND applies burning DoT. Remove burning or reduce base damage

### HIGH Priority (Data Errors)
4. **Monster tier misassignment**: `cultist_enforcer` and `webspinner` are T2 with T1 stats → change to T1
5. **tf_sawbone_enforcer** is T3 with T2 stats → change to T2
6. **2 dead consumables**: `minor_stamina_snack` and `smoke_bomb` have no use_effect
7. **4 orphaned passives**: def_iron_skin, def_front_line_bonus, str_killer_instinct, str_execute_momentum — dead data, delete or repurpose

### MEDIUM Priority (Balance Tuning)
8. **Lich stat growth**: total=9, below minimum 10 → raise ATK+1 (lean into glass cannon)
9. **11 over-budget equipment items**: R6/R7 gear exceeds tier stat budget → reduce stats or widen tier ranges
10. **R6 Necropolis event gold is 2.2x baseline** → reduce gold rewards by 30-40%
11. **R1 has zero mage monsters** (87.5% melee) → add 2-3 mage/ranged creatures
12. **Both bosses share role in 4 regions** (R2, R3, R4, R7) → diversify boss combat roles
13. **healing_tide outlier** (9.0 heal/cd vs ~6.0 average) → raise CD to 3
14. **Underpowered class passives**: living_bond (+5 HP flat), dark_pact (less than static_charge + HP cost), reality_warp (half scaling)
15. **se_passive_cosmic too strong** (+2 ATK/DEF/SPD +5 HP) → reduce to +1/+1/+1/+3
16. **HoT vs food efficiency gap**: HoTs ~2x more gold-efficient than food → raise T3/T4 HoT base_values
17. **Phylactery Tonic severely undertuned** (0.34 val/gold) → buff use_value from 36 to 90
18. **Entropy Charge overpriced** (80g for 8 debuff vs Banshee Vial 35g for 7) → reduce to 45g

### LOW Priority (Polish)
19. **R7 monster speed creep**: 5 monsters slightly exceed T1/T2 bounds → widen R7 bounds or cap at 50
20. **tf_rustwood_construct**: SPD=11 vs T2 floor of 12 → intentional, widen floor to 10
21. **3 loot tables with dominant items**: lt_food_meat (80%), lt_bat_parts (70%), lt_undead_parts (65%) → add entries
22. **T3 monsters are exclusively bosses** → consider adding non-boss T3 "tough regulars"
23. **3 strictly-worse equipment passive pairs** → differentiate or merge
24. **R1 Striker falls off hard** (8.8 power/cd vs 13.8+ in R2+) → lower str_precise_strike CD to 2
25. **Tier inversions in healing consumables** → adjust base_values for Miner's Ration, T3/T4 HoTs
