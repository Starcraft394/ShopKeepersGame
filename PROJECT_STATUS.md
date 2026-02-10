# Shops & Shadows - Project Status Report
*Last Updated: 2026-02-08*

## Quick Summary
| System | Status | Completion |
|--------|--------|------------|
| Combat (Player-Controlled) | DONE | 100% |
| Town & Facilities | DONE | 93% |
| Equipment System | DONE | 100% |
| Shop Slot Allocation | DONE | 100% |
| Recipe Unlock System | DONE | 100% |
| Hero Recruitment | DONE | 100% |
| Dungeon Progression | DONE | 90% |
| Save/Load | DONE | 100% |

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
- `Game/Combat/CombatController.gd` - Core logic (~2800 lines)
- `Game/UI/Combat/CombatScene.gd` - UI handling

---

## TOWN & FACILITY SYSTEMS - DONE

### General Store (Slot Allocation) - DONE
- [x] Shop tier system (Tier 1: 4 slots, Tier 2: 6 slots, Tier 3: 8 slots)
- [x] +/- buttons to allocate slots to facilities
- [x] Contributing facilities: Blacksmith, Leatherworker, Alchemist
- [x] Items generated based on allocated slots
- [x] Per-facility seeded RNG (no cross-contamination)
- [x] Item tooltips showing stats on hover
- [x] Sell Items popup window
- [x] Refresh removed (triggers on dungeon return)

### Recipe Unlock System - DONE
- [x] Facilities have purchasable unlocks (costs materials)
- [x] Unlocked recipes appear in shop based on slot allocation
- [x] Quality determined by facility tier at time of unlock
- [x] Default unlocks: healing_tonic, rusty_sword, rusty_shield

### Equipment System (7 Slots + Bag) - DONE
- [x] **Slots**: weapon, offhand, helmet, armor, legs, ring, amulet
- [x] **Bag**: Separate slot with capacity (base 1, backpack adds more)
- [x] Per-hero equipment storage
- [x] Quality tiers: Common (1.0x), Uncommon (1.1x), Rare (1.2x), Epic (1.35x)
- [x] Stat bonuses from equipment apply in combat

### Facilities Status

| Facility | Type | Status | Notes |
|----------|------|--------|-------|
| General Store | shop | DONE | Slot allocation, buy/sell |
| Blacksmith | blacksmith | DONE | Unlock weapons/shields/armor |
| Alchemist | alchemist | DONE | Unlock consumables |
| Leatherworker | production | DONE | Unlock armor/accessories/backpacks |
| Inn | inn | DONE | Recruit heroes, manage party |
| Storage | storage | DONE | View stash, equip gear, sell |
| Training Hall | training | DONE | Assign classes from books |
| Dungeon | dungeon | DONE | Select floor, enter dungeon |
| Woodsman | woodsman | NOT DONE | Placeholder only |

### NOT Implemented (Town)
- [ ] Woodsman facility (placeholder)
- [ ] Crafting execution (recipes defined, no UI to craft)
- [ ] Hero assignment to facilities (structure exists, no UI)

---

## DATA CONTENT

### Items: 63 Templates
| Type | Count | Examples |
|------|-------|----------|
| Consumables | 27 | Healing tonics, antidotes, class books |
| Armor | 13 | Leather vest, chainmail, iron helmet |
| Weapons | 10 | Swords, axes, bows, daggers |
| Materials | 6 | Wood, herbs, iron scrap |
| Accessories | 4 | Rings, charms, pendants |
| Backpacks | 2 | Small, sturdy |
| Tools | 1 | Torch |

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

### Dungeons: 2 Complete
1. **Greenroot Woods** - 4 floors, forest theme, Boss: Thorn Ent
2. **Timberfall Depths** - 4 floors, industrial theme, Boss: Iron Foreman

### Enemies: 30+ Types
- Tier 1: goblin, wolf, slime, spider, bandit, skeleton
- Tier 2: moss_troll, rootkin, bramble_stalker, cultist
- Elites: briar_guardian, dire_boar_elite
- Bosses: thorn_ent, iron_foreman

---

## MVP MILESTONES STATUS

### M0: Project Boot & Data Spine - COMPLETE
- [x] Game launches and loads data
- [x] DataRegistry autoloads JSON
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

### M5: MVP Validation - IN PROGRESS
- [x] Full loop playable
- [ ] All polish complete
- [ ] Known issues documented

---

## REMAINING WORK (Priority Order)

### Completed (This Session)
- [x] **Shop Refresh on Dungeon Return** - Wired up in `exit_to_town()` (GameContext.gd:4013-4015)
- [x] **Blacksmith Items Complete** - All weapons/shields/armor have proper stat_bonuses
- [x] **Blacksmith Recipes** - Added unlock_groups and iron_sword recipe
- [x] **Item Stats Standardized** - All 27 equippable items now have stat_bonuses

### High Priority
1. **Alchemist Recipes** - Add consumable recipes so Alchemist slots are useful in shop

### Medium Priority
2. **Woodsman Facility** - Implement material gathering/bonuses
3. **Crafting System** - Execute recipes at facilities (structure exists)
4. **Hero Facility Assignment** - Structure exists, needs UI

### Low Priority / Polish
5. **More Equipment Variety** - Add items to diversify shop offerings
6. **Balance Tuning** - Adjust costs, stats, quality chances
7. **UI Polish** - Improve layouts and feedback

---

## KEY FILES

### Core Systems
- `Game/Core/GameContext.gd` - Central game state (3700+ lines)
- `Game/UI/Town/TownScene.gd` - Town UI (4500+ lines)
- `Game/Combat/CombatController.gd` - Combat logic (2800+ lines)
- `Game/UI/Combat/CombatScene.gd` - Combat UI

### Data
- `Data/Facilities/*.json` - Facility definitions
- `Data/Items/Templates/*.json` - Item templates
- `Data/Classes/*.json` - Class definitions
- `Data/Abilities/*.json` - Ability definitions
- `Data/Dungeons/*.json` - Dungeon configurations

---

## NOTES

- **Combat IS player-controlled** - Not fully automated
- **Speed multi-actions work** - Speed 10+ gets extra actions
- **Consumables work** - Right-click hero bag in combat to use
- **Shop slot allocation works** - Recent implementation complete
- **Recipe unlocks work** - Facilities unlock items for shop
- **Equipment 7+1 slots work** - Per-hero equipment tracking
- **Item stat_bonuses complete** - All 27 equipment items have stat_bonuses with quality multipliers
- **Shop refresh on dungeon return** - Automatically increments when exiting dungeon

*This document should be updated as features are completed.*

---

## DOCUMENTATION

### Active Documents (Root)
- `PROJECT_STATUS.md` - This file, current implementation status
- `Shops_And_Shadows_MASTER_GDD.md` - Consolidated game design document (40 sections)
- `MVP_Scope.md` - MVP feature scope definition
- `CLAUDE.md` - Claude Code instructions

### Archived Documents
- `Archive/GDD_Sections/` - Individual GDD section files (18 files)
- `Archive/Implementation_Planning/` - Roadmaps, integration logs, phase deliverables
- `Docs/` - Region-specific implementation docs
- `ProjectDocs/` - Recovery and world design docs
- `MVP/` - MVP milestone and criteria docs
