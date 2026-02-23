# ShopKeepers Game — Comprehensive Game Audit

**Date**: 2026-02-22
**Status**: COMPLETE — 9 automated tests + 7 agent analyses
**Companion document**: [BALANCE_AUDIT.md](BALANCE_AUDIT.md) (25 balance findings)

---

## Overview

This audit covers 4 areas the balance audit didn't: content completeness, data cross-references, progression flow, and art/asset coverage. Together with BALANCE_AUDIT.md, these provide a complete picture of game health before implementing fixes.

**Test Results**: 228 total (206 unit + 22 validation), 225 pass, 3 expected failures (pre-existing balance issues)

---

## Audit E: Content Completeness

### E1: Content Count Balance (Test 198) — PASS

All regions meet minimum content thresholds:
- Items per region: all ≥20 (checked via `region_N` tags)
- Monsters per region: all ≥10 (checked via `region_id`)
- Event tables: all ≥5 entries
- 430 total items, 112 monsters, 70 events, 38 loot tables, 7 event tables

### E2: Recipe Input Existence (Test 199) — PASS

All 58 recipe inputs/outputs resolve to valid items across 14 facility variants (alchemist, chef, + regional variants r2-r7).

### E3: Shop Pool Item Existence (Test 200) — PASS

All 170 shop pool item references resolve across 8 pool files (7 regional general + 1 upgrades).

### E4: Dungeon Monster Pool Integrity (Test 201) — PASS

All 416 dungeon monster/event references resolve across 7 dungeons. Checked: tier1_monster_ids, tier2_monster_ids, elite_monster_ids, tier1/2/elite_by_floor, boss_id, alt_boss_id, event_table_id.

### E5: Content Distribution Analysis (Agent)

**Items per Region**:
| Region | Total | Equipment | Consumable | Material |
|--------|-------|-----------|------------|----------|
| Base | 35 | 20 | 8 | 6 |
| R1 | **66** | 36 | **18** | 12 |
| R2 | 57 | 35 | 13 | 9 |
| R3 | **49** (lowest) | 34 | 7 | 8 |
| R4 | 52 | 36 | 7 | 9 |
| R5 | 57 | 41 | 7 | 9 |
| R6 | 56 | 40 | 7 | 9 |
| R7 | 58 | 42 | 7 | 9 |

**Recipes**: 58 total — alchemist (35) + chef (23). Base has 28, each region r2-r7 has exactly 5. No enchanter recipes exist.

**Monsters**: Perfectly uniform — 16 per region (112 total), 2 bosses each.

**Events**: Perfectly uniform — 10 per region (70 total), but mechanical variety drops in mid-game:
- `heal_hero` only in R1 and R6
- `modifier` (run-wide buffs) only in R1 and R7
- R2/R3/R4 each use only 1 status effect type

**T4 Equipment Gaps**:
- R3: 3 missing T4 (head, legs, accessory_2) — worst region
- R1: 2 missing T4 (legs, accessory_2)
- R2: 2 missing T4 (head, accessory_1)
- R4-R6: 1-2 missing T4 (mostly backpack)
- R7: Full T2-T4 coverage (only complete region)

**Key Issue — Consumable Cliff**: R1 has 18 consumables, R2 has 13, R3-R7 all have exactly 7. Steep drop in variety after early regions.

---

## Audit F: Data Cross-Reference

### F1: Orphaned Items (Test 202) — 179 ORPHANED ITEMS

**Critical Finding**: 179 out of 430 items (42%) are never referenced by ANY acquisition system (loot tables, events, recipes, shop pools, or gear whitelists). Players cannot obtain these items through normal gameplay.

**Breakdown by region**:
| Region | Orphaned Equipment | Orphaned Other | Total |
|--------|-------------------|----------------|-------|
| R1 (gw_) | 19 | 0 | 19 |
| R2 (fm_) | 18 | 0 | 18 |
| R3 (ss_) | 15 | 1 | 16 |
| R4 (ah_) | 18 | 0 | 18 |
| R5 (se_) | 18 | 0 | 18 |
| R6 (nc_) | 19 | 1 | 20 |
| R7 (fr_) | 17 | 0 | 17 |
| Base | 6 | 1 | 7 |
| Books | 0 | 15 | 15 |
| Other | 3 | 27 | 30 |

**Notable categories**:
- **15 class books** (book_striker, book_warden, etc.) — all orphaned, likely awaiting BookUI shop integration
- **~140 equipment items** across all regions — T3/T4 gear with no drop source
- **Base items** (cloth_robe, padded_mail, bone_dagger, apprentice_focus, small_backpack, sturdy_backpack) — starter gear with no acquisition path
- **Consumables**: smoke_bomb, minor_stamina_snack, torch — utility items with no source

### F2: Dead-End Materials (Test 203) — 25 DEAD-END MATERIALS

25 material items exist but are never consumed by any recipe:

| Category | Items |
|----------|-------|
| **Boss Trophies (7)** | boss_trophy_greenwood, boss_trophy_fungalmire, boss_trophy_sunken_strand, boss_trophy_ashen_horizons, boss_trophy_starfall_expanse, boss_trophy_necropolis, boss_trophy_fractured_realm |
| **Regional T2-T3 (10)** | driftwood, tidal_pearl, obsidian_shard, magma_core, molten_core, stormglass_fragment, astral_fragment, starfall_core_fragment, temporal_residue, deadmans_grass |
| **Regional T3-T4 (5)** | cursed_relic, wailing_shard, fractured_soulglass, void_crystal, primordial_essence |
| **T4 Special (2)** | fr_dimensional_essence, wood_bundle |
| **Basic (1)** | iron_scrap |

**Boss trophies** are particularly notable — players defeat bosses expecting trophy materials to unlock recipes, but no recipes consume them.

### F3: Status Effect Reference Integrity (Test 204) — PASS

All 31 ability status effect references (`applies_status_id`) resolve to valid status effects.

### F4: Full Cross-Reference Map (Agent)

**Reference distribution** (430 items):
| Status | Count | % |
|--------|-------|---|
| Orphaned (0 systems) | 179 | 42% |
| Single-entry (1 system, fragile) | 118 | 27% |
| Multi-entry (2+ systems, robust) | 133 | 31% |

**Single-entry-point breakdown**:
- 74 **shop-only** equipment (R3-R7 each have 13 T2 items only in shop pools)
- 21 **craft-only** consumables (intentional design)
- 18 **loot-only** items (incl. 7 boss trophies + 8 dead-end materials + 3 consumables)
- 5 **event-only** items (most fragile — random encounters, may never be seen)

**Cross-region contamination** (7 items):
- `glowing_spore` tagged R1, used in R2 loot/events (should be R2 or base)
- `bone_fragment` tagged R1, drops in R6 (thematic fit but wrong tag)
- `cursed_dust` tagged R1, drops in R7 (wrong tag)
- `phoenix_ash` tagged R2, drops in R4 (should be R4)
- `void_essence` tagged R2, drops in R5 (should be R5 or base)
- `ancient_bone` tagged R2, drops in R3 elites
- `strong_healing_tonic` tagged R1, in R4-R7 boss/elite loot (likely intentional universal)

**Crafting-loot integration**: Only 11 items (2.6%) overlap between loot and crafting — systems are almost completely disjoint by design.

**Shop pool region mismatches**: 36 instances of R1 baseline gear in R2-R7 shops — likely intentional (starter equipment availability).

---

## Audit G: Progression Flow

### G1: Region-Town-Dungeon Chain (Test 205) — PASS

R1→R7 progression chain is intact:
- All 7 regions exist with valid `requires_region_id` chain (R1→R2→...→R7)
- All 7 towns resolve from their regions
- All 7 dungeons resolve from their towns
- All bosses and event tables resolve

### G2: Facility Upgrade Affordability (Agent)

**Gold Income per Dungeon Run**:
| Region | Combat Gold | Event Gold | Total/Run | Floors |
|--------|-------------|------------|-----------|--------|
| R1 | 155 | 25 | **~180g** | 4 |
| R2 | 140 | 30 | **~170g** | 4 |
| R3 | 161 | 30 | **~191g** | 4 |
| R4 | 205 | 33 | **~238g** | 4 |
| R5 | 367 | 42 | **~409g** | 5 |
| R6 | 423 | 56 | **~479g** | 5 |
| R7 | 611 | 49 | **~660g** | 6 |

**Total Facility Costs (all 9 facilities, T1→T4)**:
| Region | All-T2 | All-T3 | All-T4 | Realistic Runs to T4 |
|--------|--------|--------|--------|-----------------------|
| R1 | 625 | 2,320 | 6,570 | ~57 |
| R2 | 830 | 3,190 | 9,080 | ~85 |
| R3 | 1,095 | 4,170 | 11,830 | ~100 |
| R4 | 1,450 | 5,540 | 15,750 | ~108 |
| R5 | 1,820 | 6,935 | 19,700 | ~79 |
| R6 | 2,175 | 8,310 | 23,625 | ~81 |
| R7 | 2,800 | 10,730 | 30,550 | ~75 |

**Key Issues**:
1. **R2-R4 Gold Income Valley**: Costs scale 1.4x-2.4x vs R1, but income barely increases (0.94x-1.32x). Net difficulty is 1.47x-1.82x harder than R1. R5+ compensates with extra floors.
2. **Storage disproportionately expensive**: Gold-only costs, 15-24% of total town cost, poor value at +5 capacity/tier.
3. **T4 effectively unreachable**: 57-108 realistic runs per region. T4 is endgame fantasy content.
4. **tidal_pearl bottleneck in R3**: Elite/boss only drop, needed at qty 3/7/14 for alchemist upgrades.
5. **R7 rare material quantities excessive**: Training Hall T4 needs primordial_essence×22, fractured_soulglass×16, void_crystal×14 — all weight 4-5 drops.
6. **Cross-region recipe dependencies**: `herb_sprig` and `raw_meat` only drop in R1 but needed by all regional recipes.

### G3: XP Curve & Ability Timing (Agent)

**XP Formula**: `floor(8 + 7*(L-1) + 3.2*(L-1)^1.7)` — RuneScape-style exponential. Max level 55.

**Ability Unlock Thresholds**:
| Slot | Level | Cumulative XP |
|------|-------|--------------|
| ability_a | 5 | 260 |
| passive_a | 15 | 2,459 |
| ability_b | 25 | 8,955 |
| passive_b | 40 | 29,994 |

**XP per Combat** (base, before race/Training Hall modifiers):
| Region | Normal | Elite (1.5x) | Boss (2.5x) | Est. XP/Run |
|--------|--------|-------------|-------------|-------------|
| R1 | 15 | 22 | 37 | ~179 |
| R2 | 28 | 42 | 70 | ~406 |
| R3 | 45 | 67 | 112 | ~741 |
| R4 | 70 | 105 | 175 | ~1,225 |
| R5 | 100 | 150 | 250 | ~2,400 |
| R6 | 140 | 210 | 350 | ~3,360 |
| R7 | 190 | 285 | 475 | ~5,985 |

**Race XP Modifiers**: Human 1.10, Elf/Dwarf/Mossfolk/Tidelings 1.00, Dragonkin 0.90, Crystalborn 0.85, Undead 0.80, Voidwalkers **0.75**.

**Realistic Multi-Region Path** (~18 runs total across all 7 regions to reach L40+):
- ability_a (L5): ~2 runs in R1 — well aligned
- passive_a (L15): R3/R4 — well aligned
- ability_b (L25): R5/R6 boundary — well aligned
- passive_b (L40): Late R6 or R7 — tight, may need grinding

**Key Issues**:
1. **Late-recruit L1 gap**: Heroes recruited in R7 start at L1 with 0 XP — no catch-up. They face L40+ content without abilities.
2. **Voidwalker XP penalty**: 0.75x modifier means 47% more combats than Human to reach same level. passive_b needs 211 R7 combats from zero.
3. **Event XP is flat 20 regardless of region**: 133% of R1 combat but only 10.5% of R7 combat. Becomes irrelevant in late regions.
4. **Training Hall underwhelming per-tier**: +2% per tier barely noticeable. Only meaningful as cumulative stack across all regions.
5. **passive_b effectively endgame-only**: Only original party members see it; late recruits never reach L40.

### G4: Equipment Tier Progression (Agent)

**Equipment totals**: 284 items (20 base T1, 98 T2, 98 T3, 68 T4).

**Slot Coverage Ranking**:
| Slot | Total | T4 Count | Notes |
|------|-------|----------|-------|
| weapon_main | 99 | 24 | Best served, 5 per region per tier |
| chest | 41 | 10 | Good |
| weapon_offhand | 40 | 10 | Good |
| head | 22 | 5 | Thin — 1 per region per tier, no variety |
| legs | 22 | 6 | Thin — 1 per region per tier |
| accessory_1 | 21 | 5 | Thin |
| accessory_2 | 20 | 4 | Thinnest, T4 gaps in R1/R3 |
| backpack | 19 | 4 | T4 gaps in R4/R5/R6 |

**CRITICAL — Gear Whitelists Drastically Incomplete**:
| Dungeon | Whitelist Size | Regional Items | Coverage |
|---------|---------------|----------------|----------|
| R1 (Thornhaven) | 11 | 36 | 31% — **all base T1, zero regional** |
| R2 (Sproutrest) | 10 | 35 | 29% — **all R1 items, zero R2** |
| R3-R7 | **5 each** | 34-42 | **12-15%** |

**Key Issues**:
1. **R1 whitelist has zero regional gear** — only base T1 items drop from combat
2. **R2 whitelist uses R1 items** — Fungalmire dungeon drops Greenwood gear (likely copy-paste error)
3. **R3-R7 have only 5 items each** — most equipment slots have zero whitelist presence
4. **No T4 in any whitelist** — endgame gear has no combat drop pathway
5. **Head, legs, backpack never in any whitelist** — rely entirely on shops/events
6. **Zero variety in defensive slots** — 1 item per region per tier for head/legs/ring/amulet

**Backpack progression**: Uniform capacity (T1=+2, T2=+4, T3=+6, T4=+8). T4 missing in R4/R5/R6.

---

## Audit H: Art/Asset Coverage

### H1: Asset Path Validation (Test 206) — PASS

All 430 items have non-empty `icon_path` starting with `res://`.
All 112 monsters have non-empty `portrait_path` starting with `res://`.

### H2: Asset File Existence (Agent) — 99.5% VERIFIED (3 MISSING)

601 unique asset paths checked. 598 exist on disk. 3 missing.

| Category | Checked | Missing |
|----------|---------|---------|
| Item icons | 430 | 0 |
| Monster portraits | 110 | 0 |
| Race portraits | 44 | 0 |
| Tutorial portraits | 6 | 0 |
| Campaign dialog portraits | 8 | **3** |
| Facility keeper portraits | 9 | 0 |

**3 Missing Files** — all campaign dialog portraits referencing wrong subfolder:
| Dialog | Expected Path | Fix |
|--------|--------------|-----|
| r6_first_arrival | `.../GoblinOrc/PNG/Simple_color/Icon15.png` | Change to `Transperent/` |
| r7_first_arrival | `.../GoblinOrc/PNG/Simple_color/Icon40.png` | Change to `Transperent/` |
| r7_merchant_epilogue | `.../GoblinOrc/PNG/Simple_color/Icon40.png` | Change to `Transperent/` |

**Root cause**: GoblinOrc pack only has `Transperent/` subfolder. The `Simple_color/` subfolder doesn't exist. Fix: change path in `campaign_dialog_r6.json` and `campaign_dialog_r7.json`.

**Additional**: 6 regional shop keepers have names but no portrait assigned (cosmetic, no crash). Only `shop_thornhaven` (Pemberton) has a portrait.

### H3: Avatar Pack Diversity (Agent) — ALL 9 RACES BELOW THRESHOLD

**Critical Finding**: Every race has only 4-5 portraits despite most backing packs having 48 available images.

**Race Portrait Counts**:
| Race | Portraits | Pack Source | Pack Size | Utilization |
|------|-----------|-------------|-----------|-------------|
| Human | 5 | Avatars_MedievalPeople | 48 | 10% |
| Elf | 5 | Avatars_Elf | 48 | 10% |
| Dwarf | 5 | Avatars_Dwarf | 50 | 10% |
| Mossfolk | 5 | Avatars_Mossfolk_PNG | 48 | 10% |
| Tidelings | 5 | Avatars_Tidelings_PNG | 48 | 10% |
| Dragonkin | 5 | Avatars_Demon | 48 | 10% |
| Crystalborn | 5 | Avatars_Crystalborn_PNG | 48 | 10% |
| Undead | **4** | Avatars_Undead | 48 | 8% |
| Voidwalkers | 5 | Avatars_Voidwalkers_PNG | **5** | 100% (capped) |

**Unused Packs** (3 packs, 146 PNGs, zero references):
- `Avatars_DarkElf` (48) — no DarkElf race exists
- `Avatars_GoblinOrc` (50) — no Goblin/Orc race exists
- `Avatars_Medieval` (48) — Human uses MedievalPeople instead

**Key Issues**:
1. **Voidwalkers hard-capped**: Only 5 images exist in the entire pack — zero expansion room
2. **Undead has only 4 portraits** — data entry oversight (48 available in pack)
3. With party size 4, recruiting same-race heroes has ~40% chance of duplicate portraits from a pool of 5
4. Overall asset utilization: 44/527 PNGs assigned (8.3%)
5. Style consistency is clean — no race mixes packs

---

## Prioritized Findings

### CRITICAL (4)

| # | Finding | Audit | Impact |
|---|---------|-------|--------|
| 1 | **179 orphaned items (42%)** — equipment, books, consumables with zero acquisition path | F1 | Players can never obtain 42% of designed content |
| 2 | **Gear whitelists drastically incomplete** — R3-R7 have only 5 items each (12-15%), R1 has zero regional gear, R2 uses R1's items | G4 | Most equipment cannot drop from combat — the primary acquisition method |
| 3 | **Late-recruit L1 gap** — heroes recruited in R5-R7 start at L1 facing L25-40 content with no abilities, no catch-up | G3 | Recruited heroes are unusable for multiple runs |
| 4 | **R2-R4 gold income valley** — costs scale 1.4x-2.4x vs R1 but income barely increases (0.94x-1.32x) | G2 | Mid-game feels punishing; upgrade purchasing power decreases |

### HIGH (5)

| # | Finding | Audit | Impact |
|---|---------|-------|--------|
| 5 | **25 dead-end materials** (incl. 7 boss trophies, 18 regional) with no recipe use | F2 | Inventory clutter; boss trophies feel unrewarding |
| 6 | **15 class books orphaned** — no distribution system (shop, event, loot) | F1/F4 | Class XP books unavailable to players |
| 7 | **No T4 in any gear whitelist** — endgame equipment has no combat drop path | G4 | T4 items only obtainable through shops (if listed) |
| 8 | **All 9 races below 10-portrait threshold** (4-5 each, packs have 48) | H3 | ~40% duplicate portrait chance in same-race party of 4 |
| 9 | **Voidwalker 0.75x XP penalty** — 47% more combats than Human; passive_b needs 211 R7 combats | G3 | Late-game race feels punishing to level |

### MEDIUM (8)

| # | Finding | Audit | Impact |
|---|---------|-------|--------|
| 10 | **3 campaign dialog portrait paths broken** (GoblinOrc Simple_color → Transperent) | H2 | Missing speaker portraits in R6/R7 dialogs |
| 11 | **7 cross-region mistagged items** (glowing_spore, phoenix_ash, etc.) | F4 | Wrong region tags on loot drops |
| 12 | **Consumable cliff R1→R3+** (18→7 per region) | E5 | Late regions feel repetitive with fewer potions/food |
| 13 | **R3 thinnest region** — fewest items (49), most T4 gaps (3), fewest effect types (7) | E5 | Weakest content region |
| 14 | **Event XP flat 20 regardless of region** (133% of R1 combat, 10.5% of R7) | G3 | Events become irrelevant for XP in late game |
| 15 | **Storage disproportionately expensive** — 15-24% of total town cost, gold-only | G2 | Poor value proposition for capacity upgrade |
| 16 | **tidal_pearl bottleneck in R3** — elite/boss only, needed at qty 3/7/14 | G2 | Alchemist upgrades gated behind rare drop |
| 17 | **T4 backpack gaps in R4/R5/R6** — cap at +6, no region-themed T4 effects | G4 | Missing endgame backpack variety |

### LOW (5)

| # | Finding | Audit | Impact |
|---|---------|-------|--------|
| 18 | **6 shop keepers without portraits** (cosmetic, no crash) | H2 | Minor visual gap |
| 19 | **3 unused avatar packs** (DarkElf, GoblinOrc, Medieval = 146 PNGs) | H3 | Wasted disk space / import churn |
| 20 | **herb_sprig/raw_meat cross-region dependency** — only in R1 loot, all recipes need them | G2 | Mild convenience friction |
| 21 | **No enchanter recipes** — only alchemist and chef have mixing recipes | E5 | Planned future content |
| 22 | **Zero variety in defensive equipment slots** — exactly 1 item per region per tier | G4 | No build diversity for head/legs/ring/amulet |

---

## Post-Audit Reviews

Three specialist agents reviewed BOTH `BALANCE_AUDIT.md` (25 findings) AND `GAME_AUDIT.md` (22 findings) together, producing cross-document analyses and a unified fix plan.

---

### Cross-Document Interactions (Gameplay + Balance Agent)

Seven key interactions were identified where findings from both audits compound:

**1. R1 Mage Gap × Gear Whitelists — COMPOUNDING, CRITICAL**
The R1 dungeon has 87.5% melee monsters and zero mages (Balance B4), while R1's gear whitelist contains zero regional equipment (Game G4). Players exit R1 with base T1 gear AND no mage-counter tactics, then hit R2's 39% mage wall. R2 compounds this — its whitelist uses R1 items (copy-paste error). This is the single largest retention cliff.

**2. The Lich Paradox — death_bolt (C3) × Stat Growth (C2) × Voidwalker XP (G3)**
Strongest ability (death_bolt 4.0x power/cd) on weakest growth (9/level). Creates a glass-nuke binary. Voidwalker 0.80x XP modifier on Undead Liches recruited in R6 means 25% more combats to level AND starting at L1 against L30+ content. Fix: nerf death_bolt CD first, then raise Lich ATK growth to +3.

**3. Over-Budget R6/R7 Equipment (A1) × Progression Demands (G2/G3) — PARTIALLY JUSTIFIED**
R6/R7 dungeons are longer (5-6 floors) with harder enemies. Some stat overshoot is justified. But R6 is also the gold-generous event region (2.2x baseline, Balance D2), creating a double-reward "loot piñata" that inverts the R6→R7 difficulty arc. Fix: reduce R6 event gold first, then reassess equipment.

**4. Consumable Cliff (E5) × Dead Consumables (A4) — COMPOUNDING**
R1 has 18 consumables but 2 (`smoke_bomb`, `minor_stamina_snack`) have no `use_effect` — they do nothing. Both are also orphaned (F1). R3-R7 each have only 7 consumables. So R1's apparent variety is partly illusory, making the cliff even sharper.

**5. Boss Trophies (F2) × Facility Economy (G2) — MISSED OPPORTUNITY**
7 boss trophies drop reliably but no recipe consumes them. Boss kills feel unrewarding while facility upgrades lack trophy-tier currency. Fix: create trophy trade-in recipes (trophy → T3 material bundle or T4 consumable).

**6. Orphaned Items (F1) × Gear Whitelists (G4) — SAME PROBLEM, TWO ANGLES**
179 orphaned items and skeletal gear whitelists are the same issue. The ~140 orphaned equipment items ARE the missing whitelist entries. Fixing G4 (expand whitelists) simultaneously fixes most of F1.

**7. Late-Recruit Gap (G3) × R1 Striker Obsolescence (C3/C4)**
Dismissing an obsolete R1 Striker to recruit a Prism Lancer in R5 gives a L1 hero with no abilities facing L25+ content. The game punishes both keeping the starter (weak abilities) and replacing it (level gap).

---

### Item Triage (Items Agent)

**Orphaned Items — 179 items triaged into 3 buckets:**

| Action | Count | Description |
|--------|-------|-------------|
| Wire to gear whitelists | ~80 | T3/T4 regional equipment — add to dungeon `gear_whitelist` arrays |
| Wire to shops/events | ~30 | 15 class books (to regional shops), base starter gear (to R1 shop), T3 signatures (to shop pools) |
| Fix/defer | ~15 | Dead consumables (add `use_effect`), `torch` (defer), truly redundant items |

**Gear Whitelist Expansion** — Specific item lists for all 7 dungeons:
- R1 Thornhaven: 11→20 items (add T2 base + T3/T4 regional `gw_` items)
- R2 Sproutrest: 10→18 items (replace R1 items with R2 `fm_` items)
- R3-R7: 5→18 items each (T2 regional + T3 regional + 1-2 T4 regional)

**Boss Trophy Recipes** — 7 new alchemist recipes:
- Each consumes 1 boss trophy + 2 dead-end regional materials → T4 consumable
- Elegantly solves both F2 (dead-end materials) and F1 (orphaned T4 consumables)

**Over-Budget Orphaned Items — Fix BEFORE wiring:**
| Item | Tier | Over-Budget By | Fix |
|------|------|---------------|-----|
| `fr_null_plate` | T3 | +12 | DEF 14→10, HP 30→20 |
| `fr_null_shield` | T3 | +5 | HP -5 |
| `fr_null_staff` | T3 | +4 | ATK -4 |
| `nc_ossuary_mail` | T3 | +5 | HP -5 |

**Class Books Distribution**: All 15 books added to regional shops (R1: book_striker/defender/warden/druid; R2: book_fungal_berserker; R3-R7: 2 books each). Price scale: 80-250g by region.

---

### Project Health Scorecard (Repo Agent)

| Area | Rating | Justification |
|------|--------|---------------|
| Data Integrity | 3/5 | All reference chains pass. 7 mistagged items, 3 broken portraits, 3 mis-tiered monsters at the edges. |
| Content Completeness | 2/5 | 430 items exist but 42% orphaned. Content IS there but NOT wired. |
| Balance | 3/5 | Stat budgets well-defined but violated by 11 items, 14 monsters. CD-2 outlier pattern across 5+ classes. |
| Art/Assets | 4/5 | 99.5% paths resolve. Main gap: portrait variety (4-5 per race, 48 available). |
| Progression Flow | 2/5 | Region chain intact, XP curve sound. But late-recruit gap, flat event XP, gold valley, unreachable T4. |
| Code Quality | 4/5 | 228 tests, all pass. Impressive for GDScript. Gap: validation tests report but don't enforce. |
| **Overall** | **3.0/5** | **Structurally sound, content pipeline incomplete.** |

**Root Cause Assessment**: The primary problem is not a code bug or architecture flaw — it's an **incomplete data pipeline**. Hundreds of items were designed with stats and art, but never connected to acquisition systems. The secondary problem is a **balance tuning pass that was never done** (CD-2 outlier, flat event XP, gold valley).

**Single Highest-Leverage Action**: Write `DevTools/generate_gear_whitelists.py` to auto-populate dungeon whitelists from regional item data. This one script resolves the largest finding in both audits and drops the orphan rate from 42% to ~15%.

---

### Unified Priority — Top 15 Fixes (3 Sprints)

#### Sprint 1: "First Impressions" — R1/R2 Experience & Trust (~1-2 days)

| # | Finding | Source | Action |
|---|---------|--------|--------|
| 1 | Dead consumables | A4 | Add `use_effect` to `smoke_bomb`, `minor_stamina_snack` |
| 2 | R1 gear whitelist zero regional | G4 | Expand to 20 items (T1-T4 `gw_` regional) |
| 3 | R2 gear whitelist uses R1 items | G4 | Replace with 18 R2 `fm_` regional items |
| 4 | R1 zero mage monsters | B4 | Add 2-3 mage/ranged monsters to R1 pool |
| 5 | Monster tier misassignment | B1 | Fix cultist_enforcer, webspinner → T1; tf_sawbone_enforcer → T2 |
| 6 | 3 broken campaign portraits | H2 | Change `Simple_color/` → `Transperent/` in campaign JSONs |

#### Sprint 2: "Combat Fairness" — Ability/Class Balance (~0.5-1 day)

| # | Finding | Source | Action |
|---|---------|--------|--------|
| 7 | death_bolt 4x power outlier | C3 | base 22→18, CD 2→3 |
| 8 | 5 DPS abilities CD-2 outlier | C3 | Raise CD to 3 for light_lance, cinder_strike, void_tear, lightning_bolt |
| 9 | healing_tide outlier | C3 | Raise CD to 3 |
| 10 | Lich stat growth below min | C2 | ATK growth +2→+3 |
| 11 | R1 Striker falls off | C3 | Lower str_precise_strike CD 3→2 |
| 12 | Damage-only events (R4/R7) | D2 | Add consolation rewards to negative outcomes |
| 13 | 3 underpowered class passives | C4 | Buff living_bond, dark_pact, reality_warp |

#### Sprint 3: "Loot Loop" — Item Acquisition & Economy (~2-3 days)

| # | Finding | Source | Action |
|---|---------|--------|--------|
| 14 | R3-R7 whitelists (5 items each) | G4 | Auto-generate: expand to 15-20 items each |
| 15 | 7 boss trophies dead-end | F2 | Add trophy → T4 consumable recipes |
| 16 | 15 class books orphaned | F1 | Add to regional shop pools |
| 17 | R6 event gold 2.2x baseline | D2 | Reduce R6 gold rewards by 30-40% |
| 18 | 11 over-budget R6/R7 equipment | A1 | Reduce stats to tier budget before wiring |
| 19 | R2-R4 gold valley | G2 | Reduce upgrade costs OR increase income |
| 20 | Flat 20 event XP | G3 | Scale by region (replace hardcoded 20 in RoomEventScene.gd) |

**Total estimated effort**: 4-6 days of focused data work with minimal code changes and low regression risk.

---

### Interaction Matrix — Game Fixes That Change Balance Findings

| Game Fix | Balance Finding Affected | Direction |
|----------|--------------------------|-----------|
| Expand gear whitelists (G4) | A1 over-budget items | Dilutes outliers (soft mitigation) |
| Expand gear whitelists (G4) | F1 orphaned items | Directly resolves ~100 orphaned equipment |
| Fix R2-R4 gold valley (G2) | D2 R6 gold outlier | Narrowing gap from both sides |
| Add boss trophy recipes (F2) | G2 facility affordability | Indirect income via trophy→material→sell |
| Fix late-recruit gap (G3) | C2 Lich growth | Less punishing if recruits start at scaled level |
| Add class book distribution (F1) | C3 Striker obsolescence | XP books help R1 classes keep pace |
| Fix consumable cliff (E5) | A4 HoT vs food gap | More variety may make food feel less bad |
