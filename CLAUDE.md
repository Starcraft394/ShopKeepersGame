# ShopKeepers Game — Claude Code Project Guide

## Project Overview

**ShopKeepers Game** is a tactical RPG / auto-battler with extraction mechanics and a town management loop, built in **Godot 4.5+ with GDScript**.

## Quick Start

```bash
# Run tests
DevTools\run_headless.bat

# Current test count: 264 tests (242 unit + 22 validation)
# All tests must pass before committing
```

## Architecture

### Autoloads (Global Singletons)
- **DataRegistry** — Loads all JSON data at startup
- **GameContext** — Game state, save/load, phase management
- **SeededRNG** — Deterministic random number generation

### Key Directories
- `Game/Core/` — Autoloads and data types
- `Game/Combat/` — Turn-based combat system
- `Game/UI/` — Scene-based UI (Town, Combat, Dungeon)
- `Data/` — JSON content (items, monsters, classes, etc.)
- `DevTools/` — Test suite and headless runners

## Invariants (DO NOT MODIFY)

These rules are locked unless explicitly requested:

1. **Combat Semantics** — CombatUnit, TurnQueue, StatusRuntime, damage/status math
2. **Stash Banking** — Stash locked during dungeon; banks on extract only
3. **Loot Recipient** — Manual routing only (no auto-sort)
4. **Dungeon Bags** — No stacking; stash is the only place that stacks
5. **Determinism** — All RNG through SeededRNG

## Development Workflow

### Every Change Must:
1. Include tests in `DevTools/test_ability_execution_v1.gd`
2. Pass headless validation: `DevTools\run_headless.bat`
3. Follow logging conventions: `[FeatureName] message`

### Test Pattern
```gdscript
static func _test_feature() -> Dictionary:
    print("--- TEST XX: Feature Name ---")
    # Setup → Execute → Assert → Cleanup
    return {"name": "Feature Name", "passed": bool}
```

## Available Agents

See `.claude/agents/` for specialized agent prompts:

| Agent | Purpose |
|-------|---------|
| **Repo Auditor** | Scan repo, assess state, propose next milestone |
| **Implementer** | Test-driven implementation, minimal diffs |
| **UI Refiner** | Visual cleanup, theme consistency |
| **Data Curator** | JSON validation, content extension |
| **Art Director** | Art asset tracking, integration, consistency |
| **Story Architect** | Narrative content, lore, campaign arcs, event text |
| **Balancer** | Game balance analysis, stat curves, ability tuning |
| **Gameplay Guide** | Player guide, tutorials, onboarding |
| **Monster Curator** | Monster manifest, roles, abilities, AI tiers |
| **Sound Director** | Audio assets, BGM, SFX integration |
| **Icon Mapper** | Icon assignment, ledger, recolour pipeline |
| **Item Curator** | Item manifest, HTML reference, slot coverage |
| **Controls Agent** | Input controls, keyboard/mouse/gamepad mapping, focus navigation |
| **Playtest Agent** | Steam Playtest prep, analytics, telemetry, feedback, GDPR compliance |

## Skills

The `godot-gamedev` skill is loaded automatically for Godot development tasks. It provides:
- Data-driven architecture patterns
- Combat system guidelines
- UI/Control best practices
- Testing patterns

See `.claude/skills/godot-gamedev/SKILL.md` for the full skill definition.

## Current State (v2.1)

### Implemented
- Hero recruitment, rename, dismiss
- Per-hero equipment (weapon, offhand, bag)
- Backpacks with capacity bonuses
- Hero bags (all item types, no stacking)
- Shopkeeper bag (town storage)
- Loot recipient routing (manual)
- Facility unlock purchases
- Party size: base 4 at all Inn tiers (`PARTY_SIZE_BY_INN_TIER = {1:4, 2:4, 3:4, 4:4}`)
- Starting gold: 400 (`run_gold`)
- Manage Gear popup with bag inventory, remove buttons, and "Add Item to Bag" stash selector
- Storage "To Bag" button for consumables with hero chooser and capacity indicators
- Camp flee removed (flee only mid-combat on hero death; survivors drop all equipment and bag items)
- Tutorial system: 12 tutorials with TutorialOverlay (welcome, dungeon, combat, camp, events, extraction, facilities, equipment facilities, training hall, production, manage roster, party bar)
- Monster ability system: 18 abilities, combat roles (melee/ranged/mage), AI tier-based selection
- Campaign dialog system: 32 dialogs across 7 regions with overlay UI
- Event v2 system: weighted random outcomes per choice
- BookUI: animated book overlay (Bestiary, recipe books, handbook)
- RPG UI Pack: HP bars, dividers, banners, slot art
- Speed multi-actions: 40+ SPD = 2 actions, 80+ SPD = 3 actions
- Stock Shop: two-state allocation/refresh flow
- ESC closeable stack: LIFO UI management
- Text size scaling system
- HOT (heal-over-time) mechanic
- 430 items, 112 monsters, 80 abilities, 66 passives, 15 classes, 9 races
- 234 headless tests (212 unit + 22 validation), 233 pass, 1 expected failure

### Facility Tier System
- **Storage**: Capacity-gated stash (base 30 + 5 per Storage tier). `add_run_item()` returns bool, blocks when full.
- **Inn**: T1-T2 recruits are region-native races only; T3+ all unlocked races. T2+ recruits get starting equipment.
- **Training Hall**: +2% global XP bonus per tier across all regions. T3+ = 50% book discount.
- **Equipment Facility**: T1 = 100% common; T2-T3 = 75/20/5 common/uncommon/rare; T4 = 50/30/15/5. T3+ = 25% price discount.
- **Shop**: Tier-based refresh limit (T1=1, T2=2, T3=3, T4=4). Refresh button in UI with cost/remaining display.
- Production facility `slots_per_tier` = mixing/crafting slots, not shop display slots.

### Recent Changes
- Facility tier restructure (Storage, Inn, Training Hall, Equipment, Shop all have meaningful tier progression)
- Tutorial system v1 (11 contextual tutorials with TutorialOverlay component)
- Party size locked to 4 at all tiers
- Starting gold raised to 400
- Manage Gear popup expanded with bag management (view, remove, add from stash)
- Storage "To Bag" transfers for consumables
- Camp flee removed; flee only mid-combat with full equipment/bag drop penalty
- Facility Unlock UI v1 (leatherworker backpack unlocks)
- Loot Recipient v1.3 (all items in bags, no stacking)
- Hero Recruit v2.1 (combat identity, Inn UI)

## Data Schemas

### Item Template
```json
{
  "id": "item_id",
  "display_name": "Name",
  "item_type": "consumable|equipment|material",
  "tier": 1,
  "base_stats": {},
  "tags": ["region_1", "category"]
}
```

### Facility Unlock
```json
{
  "id": "unlock_id",
  "unlock_group": "group_id",
  "label": "Display Label",
  "required_tier": 1,
  "costs": [{"item_id": "x", "qty": 2}]
}
```

## Common Operations

| Task | Code |
|------|------|
| Get item data | `DataRegistry.get_item_template("id")` |
| Get hero | `GameContext.get_hero("hero_id")` |
| Add to stash | `GameContext.add_run_item("id", qty)` |
| Check unlock | `GameContext.has_unlocked_group("group")` |
| Save game | `GameContext.save_game()` |

## Links

- Project root: `c:\Users\rober\OneDrive\ShopKeepers Game`
- Tests: `DevTools/test_ability_execution_v1.gd`
- Save file: `user://savegame.json`
