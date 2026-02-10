# Shops & Shadows - Project Status Report
*Last Updated: 2026-02-10*

## Quick Summary
| System | Status | Completion |
|--------|--------|------------|
| Combat (Player-Controlled) | DONE | 100% |
| Town & Facilities | DONE | 95% |
| Equipment Facility UI | DONE | 100% |
| Shop Slot Allocation | DONE | 100% |
| Recipe Unlock System | DONE | 100% |
| Hero Recruitment | DONE | 100% |
| Dungeon Progression | DONE | 90% |
| Loot Tables | DONE | 100% |
| Save/Load | DONE | 100% |

---

## RECENT SESSION WORK (2026-02-10)

### Equipment Facility System - COMPLETED
- [x] **Per-Recipe Unlocking**: Each recipe has individual `unlock_cost` (no group unlocking)
- [x] **New Equipment UI**: Tabs (All/Locked/Unlocked) + Type Filters (1H/2H/Helm/Body/Legs/Offhand/Accessory/Backpack)
- [x] **Huntsman Facility**: Bows, leather armor, backpacks (wolf_pelt, spider_silk, wood)
- [x] **Enchanter Facility**: Staves, focuses, accessories, rings (herb_sprig, wood, cursed_dust, bone)
- [x] **Equipment Tooltips**: Stat display using `get_stat_bonuses_with_quality()`

### Data Expansion - COMPLETED
- [x] 24 new abilities across all class archetypes
- [x] 24 new passives for combat depth
- [x] 40+ new item templates (materials, consumables, equipment)
- [x] 9 loot tables for monster drops
- [x] 4 foraging monsters (berry_thicket, forest_hare, mushroom_cluster, wild_turkey)
- [x] All monsters now have loot_table_id assignments

### Consumable Facilities - COMPLETED
- [x] **Chef Facility**: Food crafting from raw_meat, wild_berries, forest_mushroom
- [x] **Alchemist Facility**: Potions, antidotes, elixirs from monster drops

---

## COMBAT SYSTEM - DONE

### Player-Controlled Combat - FULLY IMPLEMENTED
- [x] **Action Selection**: UI buttons show Basic Attack, Ability A, Ability B, Pass
- [x] **Target Selection**: Click valid targets based on ability type
- [x] **Player Input Signals**: `player_input_required`, `target_selection_required`
- [x] **Hybrid System**: Player units wait for input, enemies auto-execute

### Speed-Based Multi-Actions - FULLY IMPLEMENTED
| Speed | Actions |
|-------|---------|
| 0-9 | 1 action |
| 10-19 | 2 actions |
| 20+ | 3 actions (capped) |

- [x] `multi_action_update` signal tracks remaining actions
- [x] Each action consumes from remaining pool
- [x] Can pass to skip remaining actions

### Consumable Use in Combat - FULLY IMPLEMENTED
- [x] **Right-click hero bag** to open consumable popup menu
- [x] Shows available consumables with "Use [Item]" options
- [x] 1 consumable per hero per combat limit (shows disabled if used)
- [x] Enemy AI auto-uses consumables (healing at 50% HP, cleanse for DOT/stun)
- [x] Tooltip: "Right-click to use consumable" on hero bag display

### Combat Files
- `Game/Combat/CombatController.gd` - Core logic (~2900 lines)
- `Game/UI/Combat/CombatScene.gd` - UI handling (~3700 lines)

---

## TOWN & FACILITY SYSTEMS - DONE

### General Store (Slot Allocation) - DONE
- [x] Shop tier system (Tier 1: 4 slots, Tier 2: 6 slots, Tier 3: 8 slots)
- [x] +/- buttons to allocate slots to facilities
- [x] Contributing facilities: Blacksmith, Huntsman, Enchanter, Alchemist, Chef
- [x] Items generated based on allocated slots
- [x] Per-facility seeded RNG (no cross-contamination)
- [x] Item tooltips showing stats on hover
- [x] Sell Items popup window
- [x] Refresh triggers on dungeon return

### Equipment Facilities - PER-RECIPE UNLOCK SYSTEM
| Facility | Type | Produces | Materials |
|----------|------|----------|-----------|
| Blacksmith | equipment | Weapons, Shields, Heavy Armor | iron_scrap, wood_bundle |
| Huntsman | equipment | Bows, Light Armor, Backpacks | wolf_pelt, spider_silk, wood_bundle |
| Enchanter | equipment | Staves, Focuses, Accessories | herb_sprig, wood_bundle, cursed_dust, bone_fragment |

### Consumable Facilities - DIRECT CRAFTING
| Facility | Type | Produces | Materials |
|----------|------|----------|-----------|
| Alchemist | production | Potions, Antidotes, Elixirs | herb_sprig, slime_gel, spider_fang, bat_wing |
| Chef | production | Food (HP restoration) | raw_meat, wild_berries, forest_mushroom |

### Other Facilities Status
| Facility | Type | Status | Notes |
|----------|------|--------|-------|
| General Store | shop | DONE | Slot allocation, buy/sell |
| Inn | inn | DONE | Recruit heroes, manage party |
| Storage | storage | DONE | View stash, equip gear, sell |
| Training Hall | training | DONE | Assign classes from books |
| Dungeon | dungeon | DONE | Select floor, enter dungeon |

---

## DATA CONTENT

### Items: 78+ Templates
| Type | Count | Examples |
|------|-------|----------|
| Consumables | 27 | Healing tonics, antidotes, class books (15) |
| Armor | 13+ | Leather vest, chainmail, iron helmet, greaves |
| Weapons | 12+ | Swords, axes, bows, staves, maces |
| Materials | 12+ | Wood, herbs, iron, pelts, silk, gel, dust, bone |
| Accessories | 6+ | Rings, charms, pendants, focuses |
| Backpacks | 2 | Small (base), Sturdy (+3 capacity) |
| Food | 6 | Cooked meat, berries, rations, feasts |

### Classes: 15 Playable
| Region | Classes |
|--------|---------|
| Region 1 | Defender, Striker, Warden |
| Region 2 | Druid, Fungal Berserker |
| Region 3 | Tidechaser, Stormcaller |
| Region 4 | Pyrewarden, Ashblade |
| Region 5 | Prism Sentinel, Prism Lancer |
| Region 6 | Dark Channeler, Lich |
| Region 7 | Voidwalker, Void Herald |

### Abilities: 37 Total
- 1 Basic Attack
- ~18 Class A abilities (primary)
- ~17 Class B abilities (secondary)
- Covers all archetypes: vanguard, striker, mage, healer, support

### Passives: 37 Total
- Class passives (2 per class)
- Racial passives (1 per race)
- Equipment passives
- Status effect passives

### Loot Tables: 13 Defined
| Table | Source | Drops |
|-------|--------|-------|
| lt_region1_common | Tier 1 monsters | 1-2 items |
| lt_region1_uncommon | Tier 2 monsters | 1-3 items |
| lt_region1_elite | Elite monsters | 2-4 items |
| lt_region1_boss | Bosses | 3-5 items |
| lt_beast_wolf | Wolves | wolf_pelt |
| lt_beast_boar | Boars | boar_tusk, raw_meat |
| lt_spider_parts | Spiders | spider_silk, spider_fang |
| lt_ooze_parts | Oozes | slime_gel |
| lt_undead_parts | Undead | bone_fragment, cursed_dust |
| lt_bat_parts | Bats | bat_wing |
| lt_cultist_parts | Cultists | cursed_dust |
| lt_food_meat | Beast foraging | raw_meat |
| lt_food_plant | Plant foraging | wild_berries, forest_mushroom |

### Dungeons: 2 Complete
1. **Greenroot Woods** - 4 floors, forest theme, Boss: Thorn Ent
2. **Timberfall Depths** - 4 floors, industrial theme, Boss: Iron Foreman

### Enemies: 47+ Types
- **Tier 1**: goblin, wolf, bat_swarm, slime, spider, bandit, skeleton
- **Tier 2**: moss_troll, rootkin, bramble_stalker, cultist, acid_slime
- **Elites**: briar_guardian, dire_boar_elite, skeleton_veteran_elite
- **Bosses**: thorn_ent, iron_foreman, crypt_lord
- **Foraging**: berry_thicket, forest_hare, mushroom_cluster, wild_turkey

---

## MVP MILESTONES STATUS

### M0: Project Boot & Data Spine - COMPLETE
- [x] Game launches and loads data
- [x] DataRegistry autoloads 281 JSON files
- [x] SeededRNG implemented
- [x] Core data schemas validate

### M1: Core Combat Slice - COMPLETE
- [x] Turn-based combat playable
- [x] Status effects work
- [x] Class abilities work
- [x] Enemy AI attacks
- [x] Win/loss detection

### M2: Shop & Town Loop - COMPLETE
- [x] Gold system works
- [x] Shop generates items via facility slots
- [x] Heroes can equip/unequip
- [x] Inventory persists

### M3: Dungeon Progression - COMPLETE
- [x] Player can enter floors
- [x] Clearing grants loot
- [x] Shop refreshes on return
- [x] Dungeon re-entry works

### M4: Persistence & Meta - COMPLETE
- [x] Save/load works
- [x] All state persists
- [x] No duplication bugs

### M5: MVP Validation - 90% COMPLETE
- [x] Full loop playable
- [x] Equipment facility per-recipe unlocking
- [x] Consumable crafting defined
- [ ] Event variety expansion
- [ ] Balance pass

---

## REMAINING WORK (Priority Order)

### High Priority
1. **Consumable Crafting UI** - Alchemist/Chef have recipes, need execution UI
2. **Event Expansion** - Define 10+ room event variations
3. **Multi-Floor Testing** - Verify 4-floor dungeon progression

### Medium Priority
4. **Hero Facility Assignment** - Structure exists, needs UI
5. **Balance Tuning** - Adjust costs, stats, drop rates

### Low Priority / Polish
6. **More Equipment Variety** - Expand tier 2+ items
7. **UI Polish** - Improve layouts and feedback
8. **Additional Dungeons** - Region 2+ content

---

## KEY FILES

### Core Systems
| File | Lines | Purpose |
|------|-------|---------|
| `Game/Core/GameContext.gd` | ~4,755 | Central game state, persistence |
| `Game/UI/Town/TownScene.gd` | ~5,081 | Town UI, facility panels |
| `Game/Combat/CombatController.gd` | ~2,902 | Combat logic, turn management |
| `Game/UI/Combat/CombatScene.gd` | ~3,705 | Combat UI, unit displays |
| `Game/UI/Dungeon/DungeonCampScene.gd` | ~1,012 | Camp UI, room choices |

### Data Folders
| Folder | Files | Content |
|--------|-------|---------|
| `Data/Facilities/` | 20 | Facility definitions |
| `Data/Items/Templates/` | 78+ | Item templates |
| `Data/Classes/` | 15 | Class definitions |
| `Data/Abilities/` | 37 | Ability definitions |
| `Data/Passives/` | 37 | Passive definitions |
| `Data/Monsters/` | 47+ | Monster definitions |
| `Data/LootTables/` | 13 | Loot table definitions |

---

## TESTS

### Headless Test Suite
- **Location**: `DevTools/test_ability_execution_v1.gd`
- **Runner**: `DevTools/run_headless.bat`
- **Status**: 87 tests passing

### Coverage Areas
- Ability execution
- Status effects
- Combat mechanics
- Equipment bonuses
- Save/load cycles
- Hero management

---

## NOTES

- **Combat IS player-controlled** - Not fully automated
- **Speed multi-actions work** - Speed 10+ gets extra actions
- **Consumables work** - Right-click hero bag in combat to use
- **Equipment Facilities use per-recipe unlocking** - No group system
- **Consumable Facilities use direct crafting** - Tier-based, inputs array
- **All monsters have loot_table_id** - Drop materials for crafting
- **Item stat_bonuses complete** - Quality multipliers apply

---

## ARCHITECTURE NOTES

### Two Facility Systems
1. **Equipment Facilities** (Blacksmith, Huntsman, Enchanter)
   - `facility_type: "equipment"`
   - Per-recipe `unlock_cost` arrays
   - Unlocked items appear in General Store
   - UI: Tabs + Type Filters

2. **Consumable Facilities** (Alchemist, Chef)
   - `facility_type: "alchemist"` or `"chef"`
   - Direct crafting with `inputs` arrays
   - Tier-based recipe availability
   - UI: Traditional recipe list

### Invariants (Do Not Modify Without Request)
1. **Combat Semantics** - CombatUnit, TurnQueue, StatusRuntime
2. **Stash Banking** - Locks during dungeon, banks on extract
3. **Loot Recipient** - Manual routing only
4. **Dungeon Bags** - No stacking (stash only)
5. **Determinism** - All RNG through SeededRNG

---

## DOCUMENTATION

### Active Documents (Root)
- `PROJECT_STATUS.md` - This file, current implementation status
- `Shops_And_Shadows_MASTER_GDD.md` - Consolidated game design document
- `MVP_Scope.md` - MVP feature scope definition
- `CLAUDE.md` - Claude Code instructions

### Archived Documents
- `Archive/GDD_Sections/` - Individual GDD section files
- `Archive/Implementation_Planning/` - Roadmaps, integration logs
- `ProjectDocs/` - Recovery and world design docs
- `MVP/` - MVP milestone and criteria docs

*This document should be updated as features are completed.*
