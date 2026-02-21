# Balance Tier System — Complete Stat Tables

**Generated:** 2026-02-19
**System:** T1 (Base) / T2 (Regional Intro) / T3 (Regional Advanced) / T4 (Boss Crafted)
**Regions:** R1 Greenwood / R2 Fungalmire / R3 Tidelands / R4 Ashen Heights / R5 Starfall Edge / R6 Necropolis / R7 Fractured Realm

---

## 1. Design Principles

### Stat Budget System

Every item has a **total stat budget** determined by its tier and slot. The budget is the sum of all positive stats (negative stats like -SPD on heavy gear are NOT subtracted from budget; they are a trade-off that effectively increases the budget for other stats).

**Effective Budget = ATK + DEF + HP_weight + |SPD| * SPD_weight**

Where HP is weighted at 0.5 (since HP values are larger numbers but have diminishing returns) and SPD is weighted at 2.0 (since SPD is the most impactful combat stat — it determines action count thresholds at 10+ and 20+).

For simplicity in the tables below, raw stat values are shown. The budget math was used to calibrate relative power.

### Tier Budget Targets (Weapons — sword baseline)

| Tier | ATK | SPD | Total Raw | Budget | Price Range |
|------|-----|-----|-----------|--------|-------------|
| T1   | 3   | 0   | 3         | 3      | 15-25g      |
| T2   | 5-8 | 0-1 | 5-9       | 5-10   | 40-60g      |
| T3   | 8-15| 0-2 | 8-17      | 8-19   | 60-95g      |
| T4   | 12-23| 0-3 | 12-26    | 12-32  | 90-175g     |

### Region Scaling Multipliers

Stats increase per region. The multiplier applies to the **regional affix bonus** (the stats added on top of T1 base), not to T1 base stats themselves.

| Region | Multiplier | Description |
|--------|-----------|-------------|
| R1     | 1.00x     | Baseline regional gear |
| R2     | 1.12x     | ~10-15% above R1 |
| R3     | 1.30x     | ~25-35% above R1 |
| R4     | 1.50x     | ~40-55% above R1 |
| R5     | 1.70x     | ~60-80% above R1 |
| R6     | 1.95x     | ~85-110% above R1 |
| R7     | 2.30x     | ~120-150% above R1 |

### Regional Affix Flavors

Each region biases stats in a thematic direction. The affix determines which stats get bonus points beyond the base scaling.

| Region | Primary Affix | Secondary Affix | Flavor |
|--------|--------------|-----------------|--------|
| R1 Greenwood | HP +slight | Balanced | Natural resilience |
| R2 Fungalmire | DEF | HP | Fungal armor, resilience |
| R3 Tidelands | SPD | ATK (slight) | Swift currents |
| R4 Ashen Heights | ATK | SPD (slight) | Dragonfire aggression |
| R5 Starfall Edge | SPD | ATK | Cosmic precision |
| R6 Necropolis | HP | DEF | Undying fortitude |
| R7 Fractured Realm | ATK | All stats | Dimensional power |

---

## 2. T1 Base Items — Universal Starting Gear

These are the same across all regions. They are the foundation that T2/T3/T4 build upon.

### T1 Weapons

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| rusty_sword | Rusty Sword | sword | 3 | 0 | 0 | 0 | 3 | 20g | EXISTS - OK |
| hunting_bow | Hunting Bow | bow | 3 | 0 | 1 | 0 | 4 | 16g | EXISTS - OK |
| oak_staff | Oak Staff | staff | 3 | 0 | 0 | 3 | 6 | 18g | EXISTS - OK |
| wooden_mace | Wooden Mace | mace | 5 | 0 | -1 | 0 | 4 | 20g | EXISTS - OK |
| *bone_dagger* | *Bone Dagger* | *dagger* | *2* | *0* | *2* | *0* | *4* | *18g* | **NEW** |

> **Note:** T1 needs a dagger. Currently daggers only appear at R6 (nc_grave_dagger) and R7 (fr_void_fang). A T1 Bone Dagger establishes the archetype: low ATK, high SPD.

### T1 Offhands

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| wooden_shield | Wooden Shield | shield | 0 | 3 | 0 | 5 | 8 | 25g | EXISTS - OK |
| apprentice_focus | Apprentice Focus | focus | 1 | 0 | 0 | 3 | 4 | 22g | EXISTS - OK |

### T1 Armor

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| chainmail_vest | Chainmail Vest | heavy | 0 | 3 | -1 | 5 | 8 | 25g | EXISTS - **RESTAT** (currently T2, DEF 4/HP 8) |
| cloth_robe | Cloth Robe | light | 0 | 1 | 0 | 5 | 6 | 12g | EXISTS - OK |
| leather_vest | Leather Vest | light | 0 | 2 | 1 | 0 | 3 | 18g | EXISTS - OK |

> **Note:** The current game has no T1 heavy armor. Chainmail Vest is currently T2 R1. We need a new T1 heavy chest. Options:
> - **Rename chainmail_vest to T1** and create a new R1 T2 heavy chest, OR
> - **Create a new T1 heavy chest** (e.g., `padded_mail` — Padded Mail, DEF 3, SPD -1, HP 5)
>
> **Recommendation:** Create `padded_mail` as new T1 heavy armor. Keep chainmail_vest as R1 T2.

| *padded_mail* | *Padded Mail* | *heavy* | *0* | *3* | *-1* | *5* | *8* | *22g* | **NEW** |

### T1 Helmets

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| cloth_cap | Cloth Cap | light | 0 | 1 | 0 | 3 | 4 | 8g | EXISTS - OK |
| padded_coif | Padded Coif | heavy | 0 | 2 | 0 | 0 | 2 | 10g | EXISTS - **BUFF to DEF 2, HP 2** |
| tanned_leather_hood | Tanned Leather Hood | medium | 0 | 1 | 1 | 0 | 2 | 10g | EXISTS - OK |

### T1 Legs

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| cloth_leggings | Cloth Leggings | light | 0 | 1 | 0 | 3 | 4 | 8g | EXISTS - OK |
| tanned_leather_greaves | Tanned Leather Greaves | medium | 0 | 2 | 1 | 0 | 3 | 12g | EXISTS - OK |

### T1 Accessories

| ID | Name | Subtype | ATK | DEF | SPD | HP | Budget | Price | Status |
|----|------|---------|-----|-----|-----|----|--------|-------|--------|
| simple_ring | Simple Ring | ring | 0 | 0 | 0 | 5 | 5 | 20g | EXISTS - OK |
| copper_band | Copper Band | ring | 0 | 1 | 1 | 0 | 2 | 15g | EXISTS - OK |
| lucky_charm | Lucky Charm | amulet | 0 | 1 | 0 | 3 | 4 | 18g | EXISTS - OK |
| bone_charm | Bone Charm | amulet | 1 | 0 | 1 | 0 | 2 | 15g | EXISTS - OK |

### T1 Bags

| ID | Name | Capacity | Price | Status |
|----|------|----------|-------|--------|
| small_backpack | Small Backpack | +2 | 35g | EXISTS - OK |

---

## 3. Slot Budget Formulas by Tier

These are the **target stat budgets** for each slot at each tier. Regional scaling adjusts within these bands.

### Weapons (Main Hand)

| Slot | T1 Budget | T2 Budget | T3 Budget | T4 Budget |
|------|-----------|-----------|-----------|-----------|
| Sword (balanced) | 3 | 7-9 | 12-15 | 18-26 |
| Bow (spd-focused) | 4 | 7-9 | 13-15 | 19-27 |
| Staff (hp-focused) | 6 | 11-15 | 21-25 | 32-46 |
| Mace/Maul (atk, slow) | 4 | 6-9 | 13-15 | 18-25 |
| Dagger (spd-focused) | 4 | 7-9 | 12-15 | 19-24 |

### Offhands

| Slot | T1 Budget | T2 Budget | T3 Budget | T4 Budget |
|------|-----------|-----------|-----------|-----------|
| Shield (def+hp) | 8 | 13-16 | 22-25 | 31-46 |
| Focus (atk+spd+hp) | 4 | 8-10 | 14-16 | 20-30 |

### Armor

| Slot | T1 Budget | T2 Budget | T3 Budget | T4 Budget |
|------|-----------|-----------|-----------|-----------|
| Heavy chest (def+hp, -spd) | 8 | 11-17 | 23-28 | 35-52 |
| Light chest (def+spd or def+hp) | 3-6 | 7-10 | 7-16 | 18-29 |

### Other Slots

| Slot | T1 Budget | T2 Budget | T3 Budget | T4 Budget |
|------|-----------|-----------|-----------|-----------|
| Helmet | 2-4 | 8-9 | 12-14 | 22-27 |
| Legs | 3-4 | 7-9 | 5-10 | 12-17 |
| Ring | 2-5 | 8-11 | 14 | 19-28 |
| Amulet | 2-4 | 8-11 | 12-17 | 17-23 |
| Bag | +2 cap | +4 cap | +6 cap | +8 cap |

---

## 4. Complete Stat Tables — All Regions, All Tiers

### Legend
- **EXISTS-OK** = Item exists with correct stats for the new system
- **EXISTS-RESTAT** = Item exists but stats need adjustment
- **EXISTS-RETIER** = Item exists but needs tier/region reassignment
- **NEW** = Item does not exist yet, needs to be created

---

### 4.1 SWORDS (weapon_main, subtype: sword)

**Archetype:** Balanced — moderate ATK, slight SPD at higher tiers

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | rusty_sword | Rusty Sword | 3 | 0 | 0 | 0 | 20g | EXISTS-OK |
| R1 | T2 | iron_sword | Iron Sword | 5 | 0 | 1 | 0 | 40g | EXISTS-RESTAT (cur ATK 6, price 45) |
| R1 | T3 | gw_verdant_blade | Verdant Blade | 8 | 0 | 1 | 2 | 65g | NEW |
| R1 | T4 | gw_thornguard_sword | Thornguard Sword | 12 | 0 | 1 | 4 | 100g | NEW |
| R2 | T2 | fm_spore_blade | Spore Blade | 6 | 0 | 0 | 3 | 45g | EXISTS-RESTAT (cur ATK 8, SPD 1, HP 0) |
| R2 | T3 | fm_mycelium_saber | Mycelium Saber | 9 | 1 | 0 | 4 | 72g | NEW |
| R2 | T4 | fm_fungal_ruin_blade | Fungal Ruin Blade | 13 | 1 | 0 | 6 | 112g | NEW |
| R3 | T2 | ss_tide_sword | Tide Sword | 6 | 0 | 2 | 0 | 50g | NEW |
| R3 | T3 | ss_coral_blade | Coral Blade | 10 | 0 | 2 | 0 | 78g | EXISTS-RESTAT (cur ATK 11, SPD 1) |
| R3 | T4 | ss_leviathan_blade | Leviathan Blade | 14 | 0 | 3 | 0 | 120g | NEW |
| R4 | T2 | ah_ember_sword | Ember Sword | 7 | 0 | 1 | 0 | 55g | NEW |
| R4 | T3 | ah_ember_blade | Ember Blade | 12 | 0 | 2 | 0 | 88g | EXISTS-RESTAT (cur ATK 13) |
| R4 | T4 | ah_drakefang_blade | Drakefang Blade | 17 | 0 | 2 | 0 | 135g | NEW |
| R5 | T2 | se_crystal_sword | Crystal Sword | 7 | 0 | 2 | 0 | 60g | NEW |
| R5 | T3 | se_prism_edge | Prism Edge | 13 | 0 | 2 | 0 | 95g | NEW |
| R5 | T4 | se_prism_blade | Prism Blade | 18 | 0 | 3 | 0 | 140g | EXISTS-RESTAT (cur ATK 16, SPD 2) |
| R6 | T2 | nc_grave_sword | Grave Sword | 7 | 0 | 1 | 3 | 62g | NEW |
| R6 | T3 | nc_soul_edge | Soul Edge | 13 | 0 | 1 | 5 | 100g | NEW |
| R6 | T4 | nc_soul_reaver | Soul Reaver | 19 | 0 | 2 | 4 | 155g | EXISTS-RESTAT (cur ATK 19, SPD 2, HP 0) |
| R7 | T2 | fr_rift_sword | Rift Sword | 8 | 0 | 2 | 2 | 68g | NEW |
| R7 | T3 | fr_null_blade | Null Blade | 15 | 0 | 2 | 3 | 115g | NEW |
| R7 | T4 | fr_void_edge | Void Edge | 22 | 0 | 3 | 3 | 175g | EXISTS-RESTAT (cur ATK 23, HP 0) |

---

### 4.2 BOWS (weapon_main, subtype: bow)

**Archetype:** SPD-focused — moderate ATK, higher SPD than swords

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | hunting_bow | Hunting Bow | 3 | 0 | 1 | 0 | 16g | EXISTS-OK |
| R1 | T2 | composite_bow | Composite Bow | 4 | 0 | 2 | 0 | 40g | EXISTS-RESTAT (cur ATK 5) |
| R1 | T3 | gw_longbow | Greenwood Longbow | 7 | 0 | 2 | 2 | 62g | NEW |
| R1 | T4 | gw_thornshot_bow | Thornshot Bow | 10 | 0 | 3 | 3 | 98g | NEW |
| R2 | T2 | fm_fungal_shortbow | Fungal Shortbow | 5 | 0 | 1 | 3 | 45g | NEW |
| R2 | T3 | fm_fungal_longbow | Fungal Longbow | 8 | 0 | 2 | 3 | 70g | EXISTS-RESTAT (cur ATK 7, HP 0; retier from T2) |
| R2 | T4 | fm_sporewoven_bow | Sporewoven Bow | 11 | 0 | 2 | 5 | 108g | NEW |
| R3 | T2 | ss_driftwood_bow | Driftwood Bow | 5 | 0 | 2 | 0 | 48g | NEW |
| R3 | T3 | ss_tidestriker_bow | Tidestriker Bow | 8 | 0 | 3 | 0 | 75g | EXISTS-RESTAT (cur ATK 10) |
| R3 | T4 | ss_leviathan_bow | Leviathan Bow | 12 | 0 | 4 | 0 | 118g | NEW |
| R4 | T2 | ah_cinder_bow | Cinder Bow | 6 | 0 | 2 | 0 | 52g | NEW |
| R4 | T3 | ah_scorched_longbow | Scorched Longbow | 10 | 0 | 3 | 0 | 82g | EXISTS-RESTAT (cur ATK 12) |
| R4 | T4 | ah_drakefire_bow | Drakefire Bow | 14 | 0 | 3 | 0 | 130g | NEW |
| R5 | T2 | se_astral_shortbow | Astral Shortbow | 6 | 0 | 3 | 0 | 58g | NEW |
| R5 | T3 | se_starfall_shortbow | Starfall Shortbow | 11 | 0 | 3 | 0 | 90g | NEW |
| R5 | T4 | se_starfall_bow | Starfall Bow | 15 | 0 | 4 | 0 | 142g | EXISTS-OK |
| R6 | T2 | nc_spectral_bow | Spectral Bow | 6 | 0 | 2 | 3 | 60g | NEW |
| R6 | T3 | nc_wraith_shortbow | Wraith Shortbow | 12 | 0 | 3 | 3 | 98g | NEW |
| R6 | T4 | nc_wraith_bow | Wraith Bow | 17 | 0 | 4 | 3 | 155g | EXISTS-RESTAT (cur ATK 18, HP 0) |
| R7 | T2 | fr_rift_bow | Rift Bow | 7 | 0 | 3 | 2 | 65g | NEW |
| R7 | T3 | fr_null_bow | Null Bow | 14 | 0 | 4 | 2 | 110g | NEW |
| R7 | T4 | fr_entropy_bow | Entropy Bow | 20 | 0 | 5 | 2 | 170g | EXISTS-RESTAT (cur ATK 22, HP 0) |

---

### 4.3 STAVES (weapon_main, subtype: staff)

**Archetype:** HP-focused — moderate ATK, significant HP bonus, no SPD

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | oak_staff | Oak Staff | 3 | 0 | 0 | 3 | 18g | EXISTS-OK |
| R1 | T2 | arcane_staff | Arcane Staff | 4 | 0 | 0 | 6 | 42g | EXISTS-RESTAT (cur ATK 5) |
| R1 | T3 | gw_living_staff | Living Staff | 7 | 0 | 0 | 10 | 68g | NEW |
| R1 | T4 | gw_heartwood_staff | Heartwood Staff | 10 | 0 | 0 | 16 | 105g | NEW |
| R2 | T2 | fm_spore_staff | Spore Staff | 5 | 0 | 0 | 8 | 48g | NEW |
| R2 | T3 | fm_fungal_staff | Fungal Staff | 7 | 0 | 0 | 12 | 75g | EXISTS-RESTAT (cur ATK 7, HP 8; retier from T2) |
| R2 | T4 | fm_mycelium_heart_staff | Mycelium Heart Staff | 11 | 0 | 0 | 18 | 115g | NEW |
| R3 | T2 | ss_driftwood_staff | Driftwood Staff | 5 | 0 | 0 | 8 | 50g | NEW |
| R3 | T3 | ss_coral_staff | Coral Staff | 8 | 0 | 0 | 13 | 78g | EXISTS-RESTAT (cur ATK 9, HP 12) |
| R3 | T4 | ss_leviathan_staff | Leviathan Staff | 12 | 0 | 0 | 20 | 122g | NEW |
| R4 | T2 | ah_cinder_staff | Cinder Staff | 6 | 0 | 0 | 9 | 55g | NEW |
| R4 | T3 | ah_obsidian_staff | Obsidian Staff | 10 | 0 | 0 | 14 | 85g | EXISTS-RESTAT (cur ATK 11) |
| R4 | T4 | ah_drakeheart_staff | Drakeheart Staff | 14 | 0 | 0 | 22 | 135g | NEW |
| R5 | T2 | se_crystal_staff | Crystal Staff | 6 | 0 | 0 | 10 | 58g | NEW |
| R5 | T3 | se_astral_staff | Astral Staff | 11 | 0 | 0 | 16 | 95g | NEW |
| R5 | T4 | se_prism_staff | Prism Staff | 15 | 0 | 0 | 24 | 145g | EXISTS-RESTAT (cur ATK 14, HP 18) |
| R6 | T2 | nc_grave_staff | Grave Staff | 6 | 0 | 0 | 12 | 62g | NEW |
| R6 | T3 | nc_soul_staff | Soul Staff | 12 | 0 | 0 | 18 | 105g | NEW |
| R6 | T4 | nc_bone_staff | Bone Staff | 17 | 0 | 0 | 28 | 160g | EXISTS-RESTAT (cur ATK 17, HP 22) |
| R7 | T2 | fr_rift_wand | Rift Wand | 7 | 0 | 0 | 13 | 68g | NEW |
| R7 | T3 | fr_null_staff | Null Staff | 14 | 0 | 0 | 22 | 118g | NEW |
| R7 | T4 | fr_rift_staff | Rift Staff | 20 | 0 | 0 | 34 | 185g | EXISTS-RESTAT (cur ATK 20, HP 26) |

---

### 4.4 MACES/MAULS (weapon_main, subtype: mace)

**Archetype:** ATK-focused, slow — highest ATK, negative SPD penalty

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | wooden_mace | Wooden Mace | 5 | 0 | -1 | 0 | 20g | EXISTS-OK |
| R1 | T2 | iron_greataxe | Iron Greataxe | 7 | 0 | -1 | 0 | 48g | EXISTS-RESTAT (cur ATK 8, SPD -2) |
| R1 | T3 | gw_ironbark_maul | Ironbark Maul | 11 | 0 | -1 | 2 | 72g | NEW |
| R1 | T4 | gw_ancient_maul | Ancient Maul | 16 | 0 | -2 | 3 | 108g | NEW |
| R2 | T2 | fm_spore_mace | Spore Mace | 8 | 0 | -1 | 3 | 52g | NEW |
| R2 | T3 | fm_fungal_crusher | Fungal Crusher | 12 | 0 | -1 | 4 | 80g | NEW |
| R2 | T4 | fm_mycelium_maul | Mycelium Maul | 17 | 0 | -2 | 5 | 120g | NEW |
| R3 | T2 | ss_barnacle_mace | Barnacle Mace | 8 | 0 | -1 | 0 | 52g | NEW |
| R3 | T3 | ss_coral_crusher | Coral Crusher | 13 | 0 | -1 | 0 | 82g | NEW |
| R3 | T4 | ss_tidal_maul | Tidal Maul | 18 | 0 | -2 | 0 | 128g | NEW |
| R4 | T2 | ah_obsidian_mace | Obsidian Mace | 9 | 0 | -1 | 0 | 58g | NEW |
| R4 | T3 | ah_volcanic_maul | Volcanic Maul | 14 | 0 | -2 | 0 | 90g | EXISTS-RESTAT (cur ATK 15) |
| R4 | T4 | ah_drake_maul | Drake Maul | 21 | 0 | -2 | 0 | 145g | NEW |
| R5 | T2 | se_crystal_mace | Crystal Mace | 9 | 0 | -1 | 0 | 62g | NEW |
| R5 | T3 | se_temporal_maul | Temporal Maul | 16 | 0 | -2 | 0 | 98g | NEW |
| R5 | T4 | se_chrono_cleaver | Chrono Cleaver | 22 | 0 | -2 | 0 | 155g | EXISTS-RESTAT (cur ATK 20) |
| R6 | T2 | nc_bone_mace | Bone Mace | 9 | 0 | -1 | 3 | 65g | NEW |
| R6 | T3 | nc_ossuary_maul | Ossuary Maul | 16 | 0 | -2 | 5 | 108g | NEW |
| R6 | T4 | nc_deathknell_maul | Deathknell Maul | 24 | 0 | -2 | 5 | 168g | NEW |
| R7 | T2 | fr_rift_mace | Rift Mace | 10 | 0 | -1 | 2 | 70g | NEW |
| R7 | T3 | fr_null_maul | Null Maul | 19 | 0 | -2 | 3 | 122g | NEW |
| R7 | T4 | fr_entropy_maul | Entropy Maul | 28 | 0 | -3 | 2 | 185g | EXISTS-RESTAT (cur ATK 28, HP 0) |

---

### 4.5 DAGGERS (weapon_main, subtype: dagger)

**Archetype:** SPD-focused — lowest ATK of weapons, highest SPD. Designed for striker/rogue archetypes.

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | bone_dagger | Bone Dagger | 2 | 0 | 2 | 0 | 18g | **NEW** |
| R1 | T2 | gw_thorn_dagger | Thorn Dagger | 3 | 0 | 3 | 0 | 38g | NEW |
| R1 | T3 | gw_briar_fang | Briar Fang | 5 | 0 | 4 | 0 | 60g | NEW |
| R1 | T4 | gw_vinetooth_dagger | Vinetooth Dagger | 8 | 0 | 5 | 0 | 95g | NEW |
| R2 | T2 | fm_spore_knife | Spore Knife | 3 | 0 | 3 | 2 | 42g | NEW |
| R2 | T3 | fm_fungal_fang | Fungal Fang | 6 | 0 | 3 | 3 | 65g | NEW |
| R2 | T4 | fm_mycelium_stiletto | Mycelium Stiletto | 9 | 0 | 4 | 4 | 105g | NEW |
| R3 | T2 | ss_coral_knife | Coral Knife | 4 | 0 | 3 | 0 | 45g | NEW |
| R3 | T3 | ss_tide_fang | Tide Fang | 6 | 0 | 5 | 0 | 72g | NEW |
| R3 | T4 | ss_riptide_dagger | Riptide Dagger | 9 | 0 | 6 | 0 | 112g | NEW |
| R4 | T2 | ah_ember_knife | Ember Knife | 5 | 0 | 3 | 0 | 50g | NEW |
| R4 | T3 | ah_cinder_fang | Cinder Fang | 8 | 0 | 4 | 0 | 78g | NEW |
| R4 | T4 | ah_draketalon | Draketalon | 12 | 0 | 5 | 0 | 125g | NEW |
| R5 | T2 | se_crystal_knife | Crystal Knife | 5 | 0 | 4 | 0 | 55g | NEW |
| R5 | T3 | se_prism_fang | Prism Fang | 9 | 0 | 5 | 0 | 88g | NEW |
| R5 | T4 | se_temporal_dagger | Temporal Dagger | 12 | 0 | 6 | 0 | 135g | NEW |
| R6 | T2 | nc_bone_knife | Bone Knife | 5 | 0 | 3 | 2 | 58g | NEW |
| R6 | T3 | nc_wraith_fang | Wraith Fang | 9 | 0 | 4 | 3 | 92g | NEW |
| R6 | T4 | nc_grave_dagger | Grave Dagger | 13 | 0 | 5 | 3 | 148g | EXISTS-RESTAT (cur ATK 14, SPD 5, HP 0) |
| R7 | T2 | fr_rift_knife | Rift Knife | 6 | 0 | 4 | 2 | 65g | NEW |
| R7 | T3 | fr_null_fang | Null Fang | 11 | 0 | 5 | 2 | 105g | NEW |
| R7 | T4 | fr_void_fang | Void Fang | 16 | 0 | 7 | 2 | 170g | EXISTS-RESTAT (cur ATK 17, HP 0) |

---

### 4.6 SHIELDS (weapon_offhand, subtype: shield)

**Archetype:** DEF + HP — pure defensive, no ATK or SPD

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | wooden_shield | Wooden Shield | 0 | 3 | 0 | 5 | 25g | EXISTS-OK |
| R1 | T2 | reinforced_shield | Reinforced Shield | 0 | 4 | 0 | 8 | 42g | EXISTS-RESTAT (cur DEF 5, HP 8) |
| R1 | T3 | gw_ironbark_shield | Ironbark Shield | 0 | 7 | 0 | 12 | 68g | NEW |
| R1 | T4 | gw_ancient_aegis | Ancient Aegis | 0 | 10 | 0 | 18 | 105g | NEW |
| R2 | T2 | fm_sporecap_shield | Sporecap Shield | 0 | 5 | 0 | 10 | 48g | EXISTS-RESTAT (cur DEF 6) |
| R2 | T3 | fm_mycelium_bulwark | Mycelium Bulwark | 0 | 8 | 0 | 14 | 75g | NEW |
| R2 | T4 | fm_fungal_ruin_shield | Fungal Ruin Shield | 0 | 11 | 0 | 22 | 118g | NEW |
| R3 | T2 | ss_shell_shield | Shell Shield | 0 | 5 | 0 | 10 | 50g | NEW |
| R3 | T3 | ss_abalone_shield | Abalone Shield | 0 | 8 | 0 | 15 | 80g | EXISTS-RESTAT (cur DEF 8, HP 14) |
| R3 | T4 | ss_leviathan_aegis | Leviathan Aegis | 0 | 12 | 0 | 22 | 128g | NEW |
| R4 | T2 | ah_obsidian_shield | Obsidian Shield | 0 | 6 | 0 | 10 | 55g | NEW |
| R4 | T3 | ah_drake_buckler | Drake Buckler | 0 | 9 | 0 | 16 | 88g | EXISTS-OK |
| R4 | T4 | ah_drakescale_aegis | Drakescale Aegis | 0 | 14 | 0 | 24 | 142g | NEW |
| R5 | T2 | se_crystal_shield | Crystal Shield | 0 | 6 | 0 | 12 | 60g | NEW |
| R5 | T3 | se_prism_shield | Prism Shield | 0 | 10 | 0 | 18 | 95g | NEW |
| R5 | T4 | se_echo_shield | Echo Shield | 0 | 14 | 0 | 26 | 150g | EXISTS-RESTAT (cur DEF 11, HP 20) |
| R6 | T2 | nc_bone_shield | Bone Shield | 0 | 6 | 0 | 14 | 65g | NEW |
| R6 | T3 | nc_ossuary_shield | Ossuary Shield | 0 | 11 | 0 | 20 | 108g | NEW |
| R6 | T4 | nc_spectral_aegis | Spectral Aegis | 0 | 16 | 0 | 30 | 165g | EXISTS-RESTAT (cur DEF 13, HP 24) |
| R7 | T2 | fr_rift_shield | Rift Shield | 0 | 7 | 0 | 15 | 72g | NEW |
| R7 | T3 | fr_null_shield | Null Shield | 0 | 13 | 0 | 24 | 120g | NEW |
| R7 | T4 | fr_null_barrier | Null Barrier | 0 | 18 | 0 | 36 | 185g | EXISTS-RESTAT (cur DEF 16, HP 30) |

---

### 4.7 FOCUS (weapon_offhand, subtype: focus)

**Archetype:** ATK + SPD + HP hybrid — offensive caster offhand

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | apprentice_focus | Apprentice Focus | 1 | 0 | 0 | 3 | 22g | EXISTS-OK |
| R1 | T2 | wooden_focus | Wooden Focus | 2 | 0 | 1 | 4 | 42g | EXISTS-RESTAT (cur HP 5) |
| R1 | T3 | gw_living_focus | Living Focus | 3 | 0 | 1 | 7 | 65g | NEW |
| R1 | T4 | gw_heartwood_focus | Heartwood Focus | 4 | 0 | 1 | 12 | 100g | NEW |
| R2 | T2 | fm_spore_focus | Spore Focus | 2 | 0 | 1 | 6 | 48g | EXISTS-RESTAT (cur ATK 3) |
| R2 | T3 | fm_mycelium_focus | Mycelium Focus | 3 | 0 | 1 | 9 | 72g | NEW |
| R2 | T4 | fm_fungal_heart_focus | Fungal Heart Focus | 5 | 0 | 1 | 14 | 112g | NEW |
| R3 | T2 | ss_coral_focus | Coral Focus | 2 | 0 | 2 | 5 | 50g | NEW |
| R3 | T3 | ss_sea_glass_focus | Sea Glass Focus | 4 | 0 | 2 | 8 | 78g | EXISTS-OK |
| R3 | T4 | ss_leviathan_focus | Leviathan Focus | 5 | 0 | 2 | 13 | 120g | NEW |
| R4 | T2 | ah_cinder_focus | Cinder Focus | 3 | 0 | 1 | 6 | 55g | NEW |
| R4 | T3 | ah_ember_focus | Ember Focus | 5 | 0 | 1 | 10 | 82g | EXISTS-OK |
| R4 | T4 | ah_drakeheart_focus | Drakeheart Focus | 7 | 0 | 2 | 15 | 132g | NEW |
| R5 | T2 | se_astral_focus | Astral Focus | 3 | 0 | 2 | 6 | 60g | NEW |
| R5 | T3 | se_prism_focus | Prism Focus | 5 | 0 | 2 | 10 | 92g | NEW |
| R5 | T4 | se_starlight_focus | Starlight Focus | 7 | 0 | 2 | 15 | 142g | EXISTS-RESTAT (cur ATK 6, HP 12) |
| R6 | T2 | nc_grave_focus | Grave Focus | 3 | 0 | 1 | 9 | 62g | NEW |
| R6 | T3 | nc_soul_focus | Soul Focus | 5 | 0 | 1 | 14 | 100g | NEW |
| R6 | T4 | nc_soulfire_focus | Soulfire Focus | 8 | 0 | 1 | 20 | 158g | EXISTS-RESTAT (cur ATK 7, HP 14) |
| R7 | T2 | fr_rift_focus | Rift Focus | 4 | 0 | 2 | 9 | 68g | NEW |
| R7 | T3 | fr_null_focus_t3 | Null Orb | 6 | 0 | 2 | 15 | 115g | NEW |
| R7 | T4 | fr_null_focus | Null Focus | 10 | 0 | 3 | 22 | 180g | EXISTS-RESTAT (cur ATK 9, SPD 3, HP 18) |

---

### 4.8 HEAVY ARMOR (chest, subtype: heavy_chest)

**Archetype:** DEF + HP, -SPD penalty — tank gear

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | padded_mail | Padded Mail | 0 | 3 | -1 | 5 | 22g | **NEW** |
| R1 | T2 | chainmail_vest | Chainmail Vest | 0 | 4 | -1 | 8 | 35g | EXISTS-OK |
| R1 | T3 | gw_ironbark_plate | Ironbark Plate | 0 | 6 | -1 | 14 | 62g | NEW |
| R1 | T4 | gw_ancient_plate | Ancient Plate | 0 | 9 | -1 | 20 | 98g | NEW |
| R2 | T2 | fm_mycelium_vest | Mycelium Vest | 0 | 5 | -1 | 10 | 48g | EXISTS-RESTAT (cur DEF 6, HP 12) |
| R2 | T3 | fm_fungal_plate | Fungal Plate | 0 | 7 | -1 | 16 | 72g | NEW |
| R2 | T4 | fm_mycelium_ruin_plate | Mycelium Ruin Plate | 0 | 10 | -1 | 24 | 115g | NEW |
| R3 | T2 | ss_shell_vest | Shell Vest | 0 | 5 | -1 | 10 | 50g | NEW |
| R3 | T3 | ss_barnacle_plate | Barnacle Plate | 0 | 8 | -1 | 18 | 80g | EXISTS-RESTAT (cur DEF 8, HP 16) |
| R3 | T4 | ss_leviathan_plate | Leviathan Plate | 0 | 11 | -1 | 26 | 125g | NEW |
| R4 | T2 | ah_obsidian_vest | Obsidian Vest | 0 | 6 | -1 | 12 | 58g | NEW |
| R4 | T3 | ah_magma_plate | Magma Plate | 0 | 9 | -2 | 20 | 90g | EXISTS-RESTAT (cur DEF 10) |
| R4 | T4 | ah_drakescale_plate | Drakescale Plate | 0 | 13 | -2 | 28 | 140g | NEW |
| R5 | T2 | se_crystal_vest | Crystal Vest | 0 | 6 | -1 | 14 | 62g | NEW |
| R5 | T3 | se_astral_plate | Astral Plate | 0 | 10 | -1 | 22 | 98g | NEW |
| R5 | T4 | se_crystal_ward | Crystal Ward | 0 | 14 | -1 | 30 | 148g | EXISTS-RESTAT (cur DEF 12, HP 24) |
| R6 | T2 | nc_bone_vest | Bone Vest | 0 | 7 | -1 | 16 | 68g | NEW |
| R6 | T3 | nc_ossuary_mail | Ossuary Mail | 0 | 11 | -2 | 26 | 110g | NEW |
| R6 | T4 | nc_ossuary_plate | Ossuary Plate | 0 | 16 | -2 | 36 | 168g | EXISTS-RESTAT (cur DEF 15, HP 30) |
| R7 | T2 | fr_rift_vest | Rift Vest | 0 | 8 | -1 | 18 | 75g | NEW |
| R7 | T3 | fr_null_plate | Null Plate | 0 | 14 | -2 | 30 | 128g | NEW |
| R7 | T4 | fr_dimensional_plate | Dimensional Plate | 0 | 20 | -2 | 42 | 190g | EXISTS-RESTAT (cur DEF 18, HP 36) |

---

### 4.9 LIGHT ARMOR (chest, subtype: light_chest)

**Archetype:** DEF + SPD (leather) or DEF + HP (cloth/robe) — lighter, no penalty

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | leather_vest | Leather Vest | 0 | 2 | 1 | 0 | 18g | EXISTS-OK |
| Base | T1 | cloth_robe | Cloth Robe | 0 | 1 | 0 | 5 | 12g | EXISTS-OK |
| R1 | T2 | gw_ranger_vest | Ranger's Vest | 0 | 3 | 1 | 3 | 38g | NEW |
| R1 | T3 | gw_living_vest | Living Vest | 0 | 4 | 1 | 6 | 58g | NEW |
| R1 | T4 | gw_thornhide_vest | Thornhide Vest | 0 | 6 | 2 | 8 | 92g | NEW |
| R2 | T2 | fm_fungal_tunic | Fungal Tunic | 0 | 3 | 0 | 6 | 42g | NEW |
| R2 | T3 | fm_mycelium_tunic | Mycelium Tunic | 0 | 5 | 0 | 9 | 62g | NEW |
| R2 | T4 | fm_sporeguard_vest | Sporeguard Vest | 0 | 7 | 0 | 12 | 105g | NEW |
| R3 | T2 | ss_kelp_tunic | Kelp Tunic | 0 | 3 | 1 | 3 | 45g | NEW |
| R3 | T3 | ss_kelp_vest | Kelp Vest | 0 | 5 | 2 | 3 | 68g | EXISTS-RESTAT (cur DEF 5, HP 0) |
| R3 | T4 | ss_tidewoven_vest | Tidewoven Vest | 0 | 7 | 2 | 6 | 108g | NEW |
| R4 | T2 | ah_cinder_tunic | Cinder Tunic | 0 | 4 | 1 | 3 | 52g | NEW |
| R4 | T3 | ah_drake_jerkin | Drake Jerkin | 0 | 6 | 1 | 6 | 78g | EXISTS-RESTAT (cur DEF 7, HP 8) |
| R4 | T4 | ah_drakeweave_vest | Drakeweave Vest | 0 | 8 | 2 | 8 | 118g | NEW |
| R5 | T2 | se_astral_tunic | Astral Tunic | 0 | 4 | 2 | 3 | 58g | NEW |
| R5 | T3 | se_crystal_robe | Crystal Robe | 0 | 6 | 2 | 6 | 88g | NEW |
| R5 | T4 | se_astral_robe | Astral Robe | 0 | 9 | 2 | 10 | 128g | EXISTS-RESTAT (cur DEF 8, HP 8) |
| R6 | T2 | nc_shroud_tunic | Shroud Tunic | 0 | 4 | 1 | 6 | 62g | NEW |
| R6 | T3 | nc_wraith_tunic | Wraith Tunic | 0 | 7 | 1 | 10 | 95g | NEW |
| R6 | T4 | nc_wraith_robe | Wraith Robe | 0 | 10 | 2 | 14 | 142g | EXISTS-RESTAT (cur DEF 10, HP 12) |
| R7 | T2 | fr_rift_tunic | Rift Tunic | 0 | 5 | 2 | 6 | 68g | NEW |
| R7 | T3 | fr_null_shroud | Null Shroud | 0 | 8 | 2 | 10 | 108g | NEW |
| R7 | T4 | fr_void_shroud | Void Shroud | 0 | 13 | 3 | 16 | 168g | EXISTS-RESTAT (cur DEF 12, HP 14) |

---

### 4.10 HELMETS (head)

**Archetype:** DEF + HP (heavy) or DEF + SPD (light). Helmets provide ~40% of chest armor budget.

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | padded_coif | Padded Coif | 0 | 2 | 0 | 2 | 10g | EXISTS-RESTAT (cur HP 0) |
| Base | T1 | cloth_cap | Cloth Cap | 0 | 1 | 0 | 3 | 8g | EXISTS-OK |
| Base | T1 | tanned_leather_hood | Tanned Leather Hood | 0 | 1 | 1 | 0 | 10g | EXISTS-OK |
| R1 | T2 | iron_helmet | Iron Helmet | 0 | 3 | 0 | 5 | 25g | EXISTS-OK |
| R1 | T3 | gw_ironbark_helm | Ironbark Helm | 0 | 4 | 0 | 7 | 42g | NEW |
| R1 | T4 | gw_ancient_helm | Ancient Helm | 0 | 6 | 0 | 10 | 65g | NEW |
| R2 | T2 | fm_sporeguard_helm | Sporeguard Helm | 0 | 3 | 0 | 6 | 28g | EXISTS-RESTAT (cur DEF 4, HP 6, SPD -1) |
| R2 | T3 | fm_fungal_crown | Fungal Crown | 0 | 5 | 0 | 8 | 48g | NEW |
| R2 | T4 | fm_mycelium_crown | Mycelium Crown | 0 | 7 | 0 | 12 | 72g | NEW |
| R3 | T2 | ss_shell_helm | Shell Helm | 0 | 3 | 1 | 4 | 30g | NEW |
| R3 | T3 | ss_tidecrest_helm | Tidecrest Helm | 0 | 4 | 1 | 6 | 50g | EXISTS-RESTAT (cur DEF 5, SPD -1, HP 8) |
| R3 | T4 | ss_leviathan_helm | Leviathan Helm | 0 | 6 | 1 | 10 | 78g | NEW |
| R4 | T2 | ah_cinder_helm | Cinder Helm | 0 | 3 | 0 | 6 | 32g | NEW |
| R4 | T3 | ah_volcanic_helm | Volcanic Helm | 0 | 5 | 0 | 9 | 55g | EXISTS-RESTAT (cur DEF 5, SPD -1, HP 10) |
| R4 | T4 | ah_drakescale_helm | Drakescale Helm | 0 | 8 | 0 | 13 | 85g | NEW |
| R5 | T2 | se_crystal_helm | Crystal Helm | 0 | 4 | 1 | 5 | 38g | NEW |
| R5 | T3 | se_astral_helm | Astral Helm | 0 | 6 | 1 | 8 | 62g | NEW |
| R5 | T4 | se_prism_helm | Prism Helm | 0 | 8 | 1 | 12 | 95g | EXISTS-RESTAT (cur DEF 8, SPD -1, HP 15) |
| R6 | T2 | nc_bone_helm | Bone Helm | 0 | 4 | 0 | 8 | 42g | NEW |
| R6 | T3 | nc_ossuary_helm | Ossuary Helm | 0 | 7 | 0 | 12 | 72g | NEW |
| R6 | T4 | nc_bone_crown | Bone Crown | 0 | 10 | 0 | 16 | 108g | EXISTS-RESTAT (cur DEF 9, SPD -1) |
| R7 | T2 | fr_rift_helm | Rift Helm | 0 | 5 | 1 | 7 | 48g | NEW |
| R7 | T3 | fr_null_helm | Null Helm | 0 | 8 | 1 | 12 | 82g | NEW |
| R7 | T4 | fr_void_helm | Void Helm | 0 | 12 | 0 | 20 | 125g | EXISTS-RESTAT (cur DEF 10, SPD -1, HP 18) |

---

### 4.11 LEGS (legs)

**Archetype:** DEF + SPD (light) or DEF + HP (heavy). ~35% of chest armor budget.

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | cloth_leggings | Cloth Leggings | 0 | 1 | 0 | 3 | 8g | EXISTS-OK |
| Base | T1 | tanned_leather_greaves | Tanned Leather Greaves | 0 | 2 | 1 | 0 | 12g | EXISTS-OK |
| R1 | T2 | iron_greaves | Iron Greaves | 0 | 3 | 0 | 5 | 25g | EXISTS-RESTAT (cur HP 6) |
| R1 | T3 | gw_ironbark_greaves | Ironbark Greaves | 0 | 4 | 0 | 7 | 40g | NEW |
| R1 | T4 | gw_ancient_greaves | Ancient Greaves | 0 | 5 | 0 | 10 | 62g | NEW |
| R2 | T2 | fm_mycelium_leggings | Mycelium Leggings | 0 | 3 | 0 | 5 | 28g | EXISTS-RESTAT (cur HP 4) |
| R2 | T3 | fm_fungal_greaves | Fungal Greaves | 0 | 4 | 0 | 8 | 45g | NEW |
| R2 | T4 | fm_mycelium_ruin_greaves | Mycelium Ruin Greaves | 0 | 6 | 0 | 12 | 70g | NEW |
| R3 | T2 | ss_kelp_leggings | Kelp Leggings | 0 | 3 | 1 | 2 | 30g | NEW |
| R3 | T3 | ss_kelp_greaves | Kelp Greaves | 0 | 4 | 1 | 4 | 48g | EXISTS-RESTAT (cur HP 0) |
| R3 | T4 | ss_tidewoven_greaves | Tidewoven Greaves | 0 | 5 | 2 | 6 | 72g | NEW |
| R4 | T2 | ah_cinder_greaves | Cinder Greaves | 0 | 3 | 1 | 3 | 32g | NEW |
| R4 | T3 | ah_drake_greaves | Drake Greaves | 0 | 5 | 1 | 5 | 52g | EXISTS-RESTAT (cur DEF 4) |
| R4 | T4 | ah_drakescale_greaves | Drakescale Greaves | 0 | 7 | 1 | 7 | 80g | NEW |
| R5 | T2 | se_astral_boots | Astral Boots | 0 | 3 | 2 | 2 | 38g | NEW |
| R5 | T3 | se_crystal_leggings | Crystal Leggings | 0 | 5 | 2 | 4 | 58g | NEW |
| R5 | T4 | se_astral_leggings | Astral Leggings | 0 | 6 | 2 | 8 | 85g | EXISTS-RESTAT (cur DEF 5, HP 5) |
| R6 | T2 | nc_bone_greaves | Bone Greaves | 0 | 4 | 0 | 6 | 42g | NEW |
| R6 | T3 | nc_ossuary_greaves | Ossuary Greaves | 0 | 6 | 0 | 10 | 65g | NEW |
| R6 | T4 | nc_wraith_leggings | Wraith Leggings | 0 | 8 | 0 | 14 | 95g | EXISTS-RESTAT (cur DEF 6, SPD 1, HP 8) |
| R7 | T2 | fr_rift_greaves | Rift Greaves | 0 | 4 | 2 | 4 | 48g | NEW |
| R7 | T3 | fr_null_greaves | Null Greaves | 0 | 6 | 2 | 8 | 75g | NEW |
| R7 | T4 | fr_void_greaves | Void Greaves | 0 | 9 | 2 | 12 | 115g | EXISTS-RESTAT (cur DEF 7, HP 8) |

---

### 4.12 RINGS (accessory_1, subtype: ring)

**Archetype:** Stat-flexible — HP-focused at base, regional flavor at higher tiers

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | simple_ring | Simple Ring | 0 | 0 | 0 | 5 | 20g | EXISTS-OK |
| Base | T1 | copper_band | Copper Band | 0 | 1 | 1 | 0 | 15g | EXISTS-OK |
| R1 | T2 | silver_ring | Silver Ring | 0 | 0 | 0 | 8 | 38g | EXISTS-OK |
| R1 | T3 | gw_emerald_ring | Emerald Ring | 0 | 1 | 0 | 10 | 55g | NEW |
| R1 | T4 | gw_heartwood_ring | Heartwood Ring | 0 | 1 | 0 | 16 | 85g | NEW |
| R2 | T2 | fm_bioluminescent_ring | Bioluminescent Ring | 0 | 1 | 0 | 9 | 45g | EXISTS-RESTAT (cur DEF 0, SPD 1, HP 10) |
| R2 | T3 | fm_fungal_ring | Fungal Signet | 0 | 2 | 0 | 12 | 62g | NEW |
| R2 | T4 | fm_mycelium_ring | Mycelium Heart Ring | 0 | 3 | 0 | 18 | 95g | NEW |
| R3 | T2 | ss_pearl_ring | Pearl Ring | 0 | 0 | 1 | 8 | 42g | NEW |
| R3 | T3 | ss_tidecaller_ring | Tidecaller's Ring | 1 | 0 | 1 | 12 | 65g | EXISTS-RESTAT (cur ATK 2, SPD 0) |
| R3 | T4 | ss_leviathan_ring | Leviathan Ring | 1 | 0 | 2 | 16 | 98g | NEW |
| R4 | T2 | ah_obsidian_ring | Obsidian Ring | 2 | 0 | 0 | 8 | 48g | NEW |
| R4 | T3 | ah_ember_ring | Ember Ring | 3 | 0 | 0 | 12 | 70g | NEW |
| R4 | T4 | ah_drake_ring | Drake Ring | 4 | 0 | 1 | 16 | 105g | NEW |
| R5 | T2 | se_crystal_ring | Crystal Ring | 1 | 0 | 1 | 8 | 52g | NEW |
| R5 | T3 | se_astral_ring | Astral Ring | 1 | 0 | 2 | 12 | 75g | NEW |
| R5 | T4 | se_temporal_band | Temporal Band | 0 | 0 | 3 | 18 | 115g | EXISTS-RESTAT (cur HP 16) |
| R6 | T2 | nc_bone_ring | Bone Ring | 0 | 1 | 0 | 10 | 55g | NEW |
| R6 | T3 | nc_deathward_band | Deathward Band | 0 | 2 | 0 | 16 | 82g | NEW |
| R6 | T4 | nc_deathward_ring | Deathward Ring | 0 | 3 | 0 | 22 | 125g | EXISTS-RESTAT (cur HP 20) |
| R7 | T2 | fr_rift_ring | Rift Ring | 1 | 0 | 2 | 8 | 60g | NEW |
| R7 | T3 | fr_null_ring | Null Ring | 1 | 0 | 3 | 14 | 92g | NEW |
| R7 | T4 | fr_rift_band | Rift Band | 2 | 0 | 4 | 22 | 150g | EXISTS-RESTAT (cur ATK 0, HP 24) |

---

### 4.13 AMULETS (accessory_2, subtype: amulet)

**Archetype:** Mixed stats — more diverse stat distributions than rings

| Region | Tier | ID | Name | ATK | DEF | SPD | HP | Price | Status |
|--------|------|----|------|-----|-----|-----|----|-------|--------|
| Base | T1 | lucky_charm | Lucky Charm | 0 | 1 | 0 | 3 | 18g | EXISTS-OK |
| Base | T1 | bone_charm | Bone Charm | 1 | 0 | 1 | 0 | 15g | EXISTS-OK |
| R1 | T2 | warriors_pendant | Warrior's Pendant | 2 | 1 | 0 | 4 | 40g | EXISTS-RESTAT (cur ATK 3, DEF 2, HP 3) |
| R1 | T3 | gw_emerald_pendant | Emerald Pendant | 2 | 2 | 0 | 6 | 58g | NEW |
| R1 | T4 | gw_heartwood_pendant | Heartwood Pendant | 3 | 2 | 0 | 10 | 90g | NEW |
| R2 | T2 | fm_mycelium_pendant | Mycelium Pendant | 0 | 2 | 0 | 8 | 42g | EXISTS-RESTAT (cur DEF 3) |
| R2 | T3 | fm_sporeguard_pendant | Sporeguard Pendant | 0 | 3 | 0 | 12 | 60g | NEW |
| R2 | T4 | fm_fungal_heart_pendant | Fungal Heart Pendant | 0 | 4 | 0 | 18 | 95g | NEW |
| R3 | T2 | ss_pearl_pendant | Pearl Pendant | 2 | 1 | 1 | 3 | 48g | NEW |
| R3 | T3 | ss_pearl_amulet | Pearl Amulet | 2 | 2 | 1 | 6 | 68g | EXISTS-RESTAT (cur ATK 3, DEF 3, SPD 0) |
| R3 | T4 | ss_leviathan_amulet | Leviathan Amulet | 3 | 2 | 1 | 10 | 105g | NEW |
| R4 | T2 | ah_cinder_pendant | Cinder Pendant | 3 | 0 | 0 | 6 | 50g | NEW |
| R4 | T3 | ah_cinder_amulet | Cinder Amulet | 4 | 0 | 0 | 10 | 72g | EXISTS-RESTAT (cur ATK 3, HP 14) |
| R4 | T4 | ah_drakeheart_amulet | Drakeheart Amulet | 5 | 0 | 1 | 14 | 112g | NEW |
| R5 | T2 | se_crystal_pendant | Crystal Pendant | 2 | 1 | 1 | 5 | 55g | NEW |
| R5 | T3 | se_astral_pendant | Astral Pendant | 3 | 2 | 1 | 8 | 78g | NEW |
| R5 | T4 | se_echo_amulet | Echo Amulet | 4 | 3 | 1 | 12 | 118g | EXISTS-RESTAT (cur ATK 5, DEF 4, SPD 0, HP 8) |
| R6 | T2 | nc_bone_pendant | Bone Pendant | 0 | 2 | 0 | 10 | 58g | NEW |
| R6 | T3 | nc_ossuary_pendant | Ossuary Pendant | 0 | 4 | 0 | 14 | 85g | NEW |
| R6 | T4 | nc_bonecaller_amulet | Bonecaller Amulet | 0 | 5 | 0 | 22 | 135g | EXISTS-RESTAT (cur HP 18) |
| R7 | T2 | fr_rift_pendant | Rift Pendant | 3 | 1 | 1 | 5 | 65g | NEW |
| R7 | T3 | fr_null_pendant | Null Pendant | 4 | 3 | 1 | 8 | 98g | NEW |
| R7 | T4 | fr_dimensional_locket | Dimensional Locket | 6 | 4 | 2 | 10 | 165g | EXISTS-RESTAT (cur HP 0) |

---

### 4.14 BAGS (backpack)

**Archetype:** Capacity bonus only. No combat stats. Progression is +2 per tier.

| Region | Tier | ID | Name | Capacity | Price | Status |
|--------|------|----|------|----------|-------|--------|
| Base | T1 | small_backpack | Small Backpack | +2 | 35g | EXISTS-OK |
| R1 | T2 | sturdy_backpack | Sturdy Backpack | +4 | 70g | EXISTS-OK |
| R1 | T3 | gw_ranger_pack | Ranger's Pack | +6 | 110g | NEW |
| R1 | T4 | gw_thornhide_pack | Thornhide Pack | +8 | 155g | NEW |
| R2 | T2 | fm_spore_satchel | Spore Satchel | +4 | 75g | NEW |
| R2 | T3 | fm_mycelium_pack | Mycelium Pack | +6 | 118g | NEW |
| R2 | T4 | fm_fungal_heart_pack | Fungal Heart Pack | +8 | 165g | NEW |
| R3 | T2 | ss_kelp_satchel | Kelp Satchel | +4 | 78g | NEW |
| R3 | T3 | ss_shell_pack | Shell Pack | +6 | 122g | NEW |
| R3 | T4 | ss_leviathan_pack | Leviathan Pack | +8 | 172g | NEW |
| R4 | T2 | ah_cinder_satchel | Cinder Satchel | +4 | 82g | NEW |
| R4 | T3 | ah_drake_pack | Drake Pack | +6 | 128g | NEW |
| R4 | T4 | ah_drakescale_pack | Drakescale Pack | +8 | 180g | NEW |
| R5 | T2 | se_crystal_satchel | Crystal Satchel | +4 | 88g | NEW |
| R5 | T3 | se_astral_pack | Astral Pack | +6 | 135g | NEW |
| R5 | T4 | se_starfall_pack | Starfall Pack | +8 | 190g | NEW |
| R6 | T2 | nc_bone_satchel | Bone Satchel | +4 | 92g | NEW |
| R6 | T3 | nc_wraith_pack | Wraith Pack | +6 | 140g | NEW |
| R6 | T4 | nc_spectral_pack | Spectral Pack | +8 | 198g | NEW |
| R7 | T2 | fr_rift_satchel | Rift Satchel | +4 | 98g | NEW |
| R7 | T3 | fr_null_pack | Null Pack | +6 | 148g | NEW |
| R7 | T4 | fr_void_pack | Void Pack | +8 | 210g | NEW |

---

## 5. T4 Regional Passive Tags / Abilities

Each T4 item should have a regional tag that enables a passive combat effect when equipped. These effects are small but meaningful, reinforcing the region's identity.

### T4 Tag Definitions

| Region | Tag Name | Effect | Flavor |
|--------|----------|--------|--------|
| R1 Greenwood | `regenerating` | Heal 2 HP at start of each combat round | Living wood stitches wounds |
| R2 Fungalmire | `spore_shield` | 15% chance to apply Poisoned (1 stack, 2t) to melee attacker when hit | Toxic spores burst from gear |
| R3 Tidelands | `swift_current` | +1 SPD (stacks with base stats, applied as hidden buff at combat start) | Ocean currents quicken the bearer |
| R4 Ashen Heights | `burning_edge` | 10% chance on attack to apply Burning (1 stack, 2t) to target | Dragonfire lingers on strikes |
| R5 Starfall Edge | `temporal_echo` | When an ability goes on cooldown, 20% chance to reduce it by 1 turn | Cosmic echoes accelerate recovery |
| R6 Necropolis | `undying_will` | When HP drops below 25%, gain +3 DEF for 2 turns (once per combat) | Death refuses to claim its bearer |
| R7 Fractured Realm | `dimensional_rift` | On kill, 25% chance to deal 8 void damage to a random enemy | Reality fractures bleed into foes |

### Tag Application Rules

1. Only T4 gear carries a regional tag
2. Tags are **per-item**, not per-set — equipping multiple T4 items from the same region does NOT stack the same tag
3. Tags from **different regions** CAN coexist on the same hero (mixing T4 from different regions is viable)
4. Bags do NOT carry combat tags (they have capacity only)
5. Tags are stored in the item JSON under `"combat_tag"` field

### Example JSON Addition for T4 Items

```json
{
  "id": "gw_thornguard_sword",
  "combat_tag": "regenerating",
  "combat_tag_effect": {
    "trigger": "round_start",
    "effect": "heal_self",
    "value": 2
  }
}
```

---

## 6. Stat Budget Validation

### Per-Region Total Stat Budget (Full Equipment Set — sword + shield + heavy chest + helmet + legs + ring + amulet)

This shows the total stats a hero would have from a full set of equipment at each tier, per region.

| Region | Tier | Total ATK | Total DEF | Total SPD | Total HP | Grand Total |
|--------|------|-----------|-----------|-----------|----------|-------------|
| Any | T1 | 3 | 12 | 0 | 20 | 35 |
| R1 | T2 | 7 | 18 | 1 | 38 | 64 |
| R1 | T3 | 10 | 28 | 1 | 56 | 95 |
| R1 | T4 | 15 | 39 | 1 | 88 | 143 |
| R2 | T2 | 6 | 19 | 0 | 44 | 69 |
| R2 | T3 | 9 | 29 | 0 | 68 | 106 |
| R2 | T4 | 13 | 42 | 0 | 104 | 159 |
| R3 | T2 | 8 | 16 | 5 | 30 | 59 |
| R3 | T3 | 13 | 27 | 5 | 49 | 94 |
| R3 | T4 | 18 | 38 | 8 | 70 | 134 |
| R4 | T2 | 12 | 18 | 1 | 33 | 64 |
| R4 | T3 | 19 | 29 | 1 | 51 | 100 |
| R4 | T4 | 27 | 42 | 2 | 74 | 145 |
| R5 | T2 | 10 | 17 | 5 | 32 | 64 |
| R5 | T3 | 16 | 30 | 5 | 54 | 105 |
| R5 | T4 | 22 | 41 | 8 | 84 | 155 |
| R6 | T2 | 7 | 20 | 1 | 54 | 82 |
| R6 | T3 | 13 | 37 | 0 | 82 | 132 |
| R6 | T4 | 19 | 53 | 0 | 126 | 198 |
| R7 | T2 | 14 | 19 | 5 | 40 | 78 |
| R7 | T3 | 20 | 38 | 5 | 71 | 134 |
| R7 | T4 | 30 | 55 | 3 | 118 | 206 |

### Validation Against Combat Math

- **T1 monster avg DEF: 11** — T1 hero ATK 3 (from sword) + class base ATK 8-18 = 11-21 total ATK, giving 0-10 effective damage per hit. Reasonable for early game.
- **T2 monster avg DEF: 19.4** — R1 T2 hero ATK 7 (from sword) + class ATK = 15-25. Effective damage 0-6. Requires class scaling + levels.
- **T3 monster avg DEF: 24.9** — R4 T3 hero ATK 19 (from sword) + class ATK = 27-37. Effective damage 2-12. Healthy at mid-game.
- **R7 T4 total ATK: 30** (equipment only) + class ATK 14-18 + levels = 44-48+. Vs T3 boss DEF 24.9 = ~19-23 effective damage per hit. Strong but appropriate for endgame gear.

---

## 7. Migration Impact Summary

### Items That Need RESTAT (stat changes only)

| ID | Current → New | Change Description |
|----|---------------|-------------------|
| iron_sword | ATK 6→5, price 45→40 | Slight reduction to fit T2 R1 budget |
| composite_bow | ATK 5→4 | Slight reduction, SPD stays 2 |
| arcane_staff | ATK 5→4 | Slight reduction, HP stays 6 |
| iron_greataxe | ATK 8→7, SPD -2→-1 | Reduced to fit T2 budget, less punishing |
| fm_spore_blade | ATK 8→6, SPD 1→0, add HP 3 | Rebalanced for R2 DEF/HP flavor |
| fm_sporecap_shield | DEF 6→5 | Slight reduction for T2 |
| fm_mycelium_vest | DEF 6→5, HP 12→10 | Reduced to T2 budget |
| fm_sporeguard_helm | DEF 4→3, remove SPD -1 | Cleaned up for T2 |
| fm_mycelium_leggings | HP 4→5 | Slight buff |
| fm_bioluminescent_ring | remove SPD 1, add DEF 1, HP 10→9 | Realigned to R2 DEF flavor |
| fm_mycelium_pendant | DEF 3→2 | Reduced to T2 budget |
| fm_spore_focus | ATK 3→2 | Reduced to T2 budget |
| ss_coral_blade | ATK 11→10, SPD 1→2 | Realigned for R3 SPD flavor |
| ss_tidestriker_bow | ATK 10→8 | Reduced to T3 budget |
| ss_coral_staff | ATK 9→8, HP 12→13 | Minor rebalance |
| ss_barnacle_plate | HP 16→18 | Slight buff |
| ss_tidecrest_helm | DEF 5→4, flip SPD -1→+1, HP 8→6 | Realigned for R3 SPD flavor |
| ss_kelp_vest | add HP 3 | Buff to fill budget |
| ss_kelp_greaves | add HP 4 | Buff to fill budget |
| ss_tidecaller_ring | ATK 2→1, add SPD 1 | Realigned for R3 SPD flavor |
| ss_pearl_amulet | ATK 3→2, DEF 3→2, add SPD 1, HP 6→6 | Realigned for R3 SPD flavor |
| ah_ember_blade | ATK 13→12 | Slight reduction |
| ah_volcanic_maul | ATK 15→14 | Slight reduction |
| ah_scorched_longbow | ATK 12→10 | Reduced to T3 budget |
| ah_obsidian_staff | ATK 11→10 | Slight reduction |
| ah_magma_plate | DEF 10→9, remove extra SPD -2→-2 | Minor trim |
| ah_volcanic_helm | remove SPD -1, HP 10→9 | Cleaned up |
| ah_drake_greaves | DEF 4→5 | Slight buff |
| ah_cinder_amulet | ATK 3→4, HP 14→10 | Rebalanced for R4 ATK flavor |
| ah_drake_jerkin | DEF 7→6, HP 8→6 | Reduced to T3 budget |
| se_prism_blade | ATK 16→18, SPD 2→3 | Buff to T4 R5 level |
| se_starfall_bow | OK as-is | No change needed |
| se_chrono_cleaver | ATK 20→22 | Buff to T4 R5 level |
| se_prism_staff | ATK 14→15, HP 18→24 | Buff to T4 R5 level |
| se_echo_shield | DEF 11→14, HP 20→26 | Buff to T4 R5 level |
| se_starlight_focus | ATK 6→7, HP 12→15 | Buff to T4 R5 level |
| se_crystal_ward | DEF 12→14, HP 24→30 | Buff to T4 R5 level |
| se_astral_robe | DEF 8→9, HP 8→10 | Slight buff |
| se_prism_helm | flip SPD -1→+1, HP 15→12 | Realigned for R5 SPD flavor |
| se_astral_leggings | DEF 5→6, HP 5→8 | Buff to T4 level |
| se_temporal_band | HP 16→18 | Slight buff |
| se_echo_amulet | ATK 5→4, DEF 4→3, add SPD 1, HP 8→12 | Rebalanced |
| nc_soul_reaver | add HP 4 | Buff for R6 HP flavor |
| nc_wraith_bow | ATK 18→17, add HP 3 | Rebalanced for R6 HP flavor |
| nc_bone_staff | HP 22→28 | Buff to T4 R6 level |
| nc_grave_dagger | ATK 14→13, add HP 3 | Rebalanced for R6 HP flavor |
| nc_spectral_aegis | DEF 13→16, HP 24→30 | Buff to T4 R6 level |
| nc_soulfire_focus | ATK 7→8, HP 14→20 | Buff to T4 R6 level |
| nc_ossuary_plate | DEF 15→16, HP 30→36 | Buff to T4 R6 level |
| nc_wraith_robe | HP 12→14 | Slight buff |
| nc_bone_crown | DEF 9→10, remove SPD -1, HP stays 16 | Cleaned up |
| nc_wraith_leggings | DEF 6→8, remove SPD 1, HP 8→14 | Realigned for R6 HP/DEF |
| nc_deathward_ring | HP 20→22 | Slight buff |
| nc_bonecaller_amulet | HP 18→22 | Buff to T4 R6 level |
| fr_void_edge | ATK 23→22, add HP 3 | Minor rebalance |
| fr_entropy_bow | ATK 22→20, add HP 2 | Rebalanced |
| fr_rift_staff | HP 26→34 | Buff to T4 R7 level |
| fr_entropy_maul | add HP 2 | Small buff |
| fr_void_fang | ATK 17→16, add HP 2 | Rebalanced |
| fr_null_barrier | DEF 16→18, HP 30→36 | Buff to T4 R7 level |
| fr_null_focus | ATK 9→10, HP 18→22 | Buff to T4 R7 level |
| fr_dimensional_plate | DEF 18→20, HP 36→42 | Buff to T4 R7 level |
| fr_void_shroud | DEF 12→13, HP 14→16 | Slight buff |
| fr_void_helm | DEF 10→12, remove SPD -1, HP 18→20 | Buff + cleanup |
| fr_void_greaves | DEF 7→9, HP 8→12 | Buff to T4 R7 level |
| fr_rift_band | add ATK 2, HP 24→22 | Rebalanced |
| fr_dimensional_locket | ATK 6→6, DEF 5→4, HP 0→10 | Major rebalance, add HP |
| warriors_pendant | ATK 3→2, DEF 2→1, HP 3→4 | Reduced to T2 budget |
| iron_greaves | HP 6→5 | Slight reduction |
| padded_coif | add HP 2 | Buff |

### Items That Need RETIER (tier/region reassignment)

| ID | Current Tier | New Tier | Reason |
|----|-------------|----------|--------|
| fm_fungal_longbow | T2 | T3 | R2 T2 bow is new (fm_fungal_shortbow); this becomes T3 |
| fm_fungal_staff | T2 | T3 | R2 T2 staff is new (fm_spore_staff); this becomes T3 |

### New Items Count

| Category | Count |
|----------|-------|
| Swords | 14 new |
| Bows | 14 new |
| Staves | 14 new |
| Maces | 17 new |
| Daggers | 19 new (including T1 bone_dagger) |
| Shields | 14 new |
| Focus | 14 new |
| Heavy Armor | 14 new (including T1 padded_mail) |
| Light Armor | 14 new |
| Helmets | 14 new |
| Legs | 14 new |
| Rings | 14 new |
| Amulets | 14 new |
| Bags | 19 new |
| **TOTAL** | **213 new items** |

### Items Unchanged (EXISTS-OK)

| ID | Name | Why OK |
|----|------|--------|
| rusty_sword | Rusty Sword | T1 base, stats correct |
| hunting_bow | Hunting Bow | T1 base, stats correct |
| oak_staff | Oak Staff | T1 base, stats correct |
| wooden_mace | Wooden Mace | T1 base, stats correct |
| wooden_shield | Wooden Shield | T1 base, stats correct |
| apprentice_focus | Apprentice Focus | T1 base, stats correct |
| leather_vest | Leather Vest | T1 base, stats correct |
| cloth_robe | Cloth Robe | T1 base, stats correct |
| cloth_cap | Cloth Cap | T1 base, stats correct |
| tanned_leather_hood | Tanned Leather Hood | T1 base, stats correct |
| cloth_leggings | Cloth Leggings | T1 base, stats correct |
| tanned_leather_greaves | Tanned Leather Greaves | T1 base, stats correct |
| simple_ring | Simple Ring | T1 base, stats correct |
| copper_band | Copper Band | T1 base, stats correct |
| lucky_charm | Lucky Charm | T1 base, stats correct |
| bone_charm | Bone Charm | T1 base, stats correct |
| small_backpack | Small Backpack | T1 base, capacity +2 correct |
| chainmail_vest | Chainmail Vest | R1 T2 heavy, stats correct |
| iron_helmet | Iron Helmet | R1 T2, stats correct |
| silver_ring | Silver Ring | R1 T2, stats correct |
| sturdy_backpack | Sturdy Backpack | R1 T2, capacity +4 correct |
| ss_sea_glass_focus | Sea Glass Focus | R3 T3, stats correct |
| ah_ember_focus | Ember Focus | R4 T3, stats correct |
| ah_drake_buckler | Drake Buckler | R4 T3, stats correct |
| se_starfall_bow | Starfall Bow | R5 T4, stats correct |

---

## 8. Recipe Structure Guide

### T2 Recipe Pattern (Regional Introductory)
```
T1 Base Item + 2x Common Regional Material → T2 Regional Item
Example: Rusty Sword + 2x Fungal Fiber → Spore Blade (fm_spore_blade)
```

### T3 Recipe Pattern (Regional Advanced)
```
T1 Base Item + 3x Common Regional Material + 1x Rare Regional Material → T3 Regional Item
Example: Rusty Sword + 3x Fungal Fiber + 1x Spore Cluster → Mycelium Saber (fm_mycelium_saber)
```

### T4 Recipe Pattern (Boss Crafted)
```
T2 or T3 Regional Item + 2x Rare Regional Material + 1x Boss Trophy → T4 Boss Item
Example: Mycelium Saber + 2x Spore Cluster + 1x Mycelium Heart → Fungal Ruin Blade (fm_fungal_ruin_blade)
```

### Material Mapping by Region

| Region | Common Material(s) | Rare Material(s) | Boss Trophy |
|--------|--------------------|-------------------|-------------|
| R1 Greenwood | iron_scrap, wood_bundle, wolf_pelt, spider_silk | cursed_dust, glowing_spore | (none yet — needs boss_trophy_greenwood) |
| R2 Fungalmire | fungal_fiber, mycelium_thread | spore_cluster | boss_trophy_fungalmire (Mycelium Heart) |
| R3 Tidelands | driftwood, ss_kelp_sinew, sea_salt_crystal | tidal_pearl, ss_crustacean_shell | boss_trophy_sunken_strand (Leviathan Scale) |
| R4 Ashen Heights | ember_dust, volcanic_glass, obsidian_shard | ah_drake_scale, magma_core | boss_trophy_ashen_horizons (Drake Heart) |
| R5 Starfall Edge | starfall_dust, prism_shard | astral_fragment, se_echo_essence | boss_trophy_starfall_expanse (Starfall Core) |
| R6 Necropolis | nc_grave_dust, spectral_log, soul_ore | nc_wraith_thread, nc_bone_marrow | boss_trophy_necropolis (Lich Phylactery) |
| R7 Fractured Realm | fr_entropy_residue, fr_null_fragment | fr_dimensional_essence, fr_rift_membrane | boss_trophy_fractured_realm (Void Shard) |

> **Note:** R1 Greenwood has no boss trophy yet. A `boss_trophy_greenwood` (e.g., "Elderwood Heart") needs to be created for R1 T4 recipes.

---

## 9. Implementation Priority

### Phase 1: Restat Existing Items (Low Risk)
1. Update all EXISTS-RESTAT items to new stat values
2. Update tier fields for RETIER items
3. Add `combat_tag` fields to existing T4 items
4. **Est. files changed:** ~65 item JSONs

### Phase 2: Create T1 Gap-Fillers
1. Create `bone_dagger` (T1 weapon)
2. Create `padded_mail` (T1 heavy chest)
3. Create `boss_trophy_greenwood` (R1 material)
4. **Est. new files:** 3

### Phase 3: Create T2 Items (All Regions)
1. Create all T2 items for R2-R7 (R1 T2 mostly exists)
2. Create T2 bags for all regions
3. Add T2 recipes to facilities
4. **Est. new files:** ~60 item JSONs + ~60 recipe JSONs

### Phase 4: Create T3 Items (All Regions)
1. Create all T3 items for R1-R7
2. Create T3 bags for all regions
3. Add T3 recipes to facilities
4. **Est. new files:** ~75 item JSONs + ~75 recipe JSONs

### Phase 5: Create T4 Items (Gap-Fill)
1. Create missing T4 items (R1 T4 gear, plus slots missing in other regions)
2. Update existing T4 recipes if needed
3. **Est. new files:** ~40 item JSONs + ~40 recipe JSONs
