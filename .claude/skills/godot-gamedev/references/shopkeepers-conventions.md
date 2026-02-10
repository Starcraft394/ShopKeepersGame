# ShopKeepers Game Conventions

Project-specific patterns and invariants for the ShopKeepers tactical RPG.

## Project Structure

```
ShopKeepers Game/
├── Game/
│   ├── Core/
│   │   ├── DataRegistry.gd      # JSON loader (autoload)
│   │   ├── GameContext.gd       # Game state (autoload)
│   │   ├── SeededRNG.gd         # Deterministic RNG (autoload)
│   │   └── DataTypes/           # from_dict() factories
│   ├── Combat/
│   │   ├── CombatController.gd  # Combat orchestrator
│   │   ├── CombatUnit.gd        # Unit state
│   │   ├── TurnQueue.gd         # Turn ordering
│   │   ├── StatusRuntime.gd     # Legacy status effects
│   │   └── CombatResult.gd      # Outcome tracking
│   ├── UI/
│   │   ├── Town/TownScene.gd    # Town hub
│   │   ├── Combat/CombatScene.gd # Combat display
│   │   └── Dungeon/             # Dungeon scenes
│   └── Boot/game_boot.gd        # Entry point
├── Data/                         # JSON content
│   ├── Items/Templates/          # 89 item definitions
│   ├── Classes/                  # 16 hero classes
│   ├── Races/                    # 9 hero races
│   ├── Monsters/                 # 47 monsters
│   ├── Facilities/               # 20 facilities
│   ├── Abilities/                # 13 abilities
│   └── ...
├── DevTools/
│   ├── test_ability_execution_v1.gd  # Test suite
│   └── run_headless.bat              # Test runner
└── Themes/game_theme.tres
```

## Autoloads (DO NOT MODIFY ORDER)

```
DataRegistry  → res://Game/Core/DataRegistry.gd
GameContext   → res://Game/Core/GameContext.gd
SeededRng     → res://Game/Core/SeededRNG.gd
```

## Game Phases

```gdscript
enum GamePhase {
    BOOT,           # Initial load
    TOWN,           # Town hub (recruiting, shopping)
    DUNGEON_SELECT, # Choose dungeon
    COMBAT,         # Active combat
    DUNGEON_CAMP,   # Between rooms
    ROOM_EVENT,     # Non-combat event
    REWARDS,        # Post-combat
    RETURN_TO_TOWN  # Extract/flee
}
```

## Invariants (NEVER MODIFY WITHOUT EXPLICIT REQUEST)

### Combat Semantics
- Turn order: Higher effective speed first, player wins ties
- Stun checks: Both legacy StatusRuntime AND v1 status hooks
- Damage: Use effective stats (base + buffs), defense reduces physical only
- All RNG through SeededRNG

### Stash Banking Rules
- Stash is LOCKED during dungeon (COMBAT, DUNGEON_CAMP phases)
- Items bank to stash ONLY on extract/return to town
- `dungeon_items` = provisional (lost on flee)
- `run_items` = banked (persists)

### Loot Recipient Rules
- Manual routing ONLY (no auto-sort/prefs)
- Hero bags: NO stacking (each item = 1 slot)
- Shopkeeper bag: NO stacking (each item = 1 slot)
- Stash: ONLY place that stacks
- Pending acquisitions move 1 item per click to bags

### Hero Bag Rules
- Base capacity = 1 (without backpack)
- Backpack adds `bag_capacity_bonus`
- ALL item types allowed (v1.3)
- No category restrictions

## Logging Conventions

```gdscript
# Feature-prefixed logging
print("[Combat] Turn started: unit=%s" % unit_id)
print("[HeroBag] +1 %s hero=%s bag=%d/%d" % [item_id, hero_id, used, cap])
print("[FacilityUnlock] SUCCESS facility=%s unlock=%s" % [fac_id, unlock_id])
print("[Save] run_items serialized count=%d" % count)
print("[Load] run_items deserialized count=%d" % count)

# PASS/FAIL for tests
print("[PASS] Feature works as expected")
print("[FAIL] Expected %s, got %s" % [expected, actual])
```

## Save Schema Keys

```gdscript
# GameContext.save_game() persists:
{
    "unlocked_dungeon_floors": {},    # floor progression
    "selected_start_floors": {},      # preferred start
    "hero_equipment": {},             # per-hero gear
    "hero_bags": {},                  # per-hero inventory
    "owned_heroes": [],               # hero roster
    "selected_party": [],             # current party
    "hero_id_counter": 0,             # unique ID generation
    "unlocked_groups": {},            # shop gating
    "learned_classes": {},            # from books
    "facility_tiers": {},             # upgrades
    "town_tiers": {},                 # town progression
    "player_gold": 0,                 # spending money
    "run_gold": 0,                    # banked gold
    "run_items": [],                  # banked items
    "shopkeeper_bag": [],             # town storage
    "housing_upgrades": {},           # stash upgrades
    "bonus_stash_capacity": 0,        # from upgrades
    "shop_refresh_counts": {},        # deterministic gen
    "current_region": 1               # region progression
}
```

## Test Conventions

### Test Function Pattern

```gdscript
static func _test_feature_name() -> Dictionary:
    print("--- TEST XX: Feature Description ---")

    # Save originals
    var orig_state = GameContext.some_state.duplicate(true)

    # Setup
    GameContext.some_state = test_value

    # Execute
    var result = GameContext.do_something()

    # Assert
    var passed = result == expected
    if passed:
        print("[PASS] Description of what passed")
    else:
        print("[FAIL] Expected X, got Y")

    # Cleanup
    GameContext.some_state = orig_state

    return {"name": "Feature Description", "passed": passed}
```

### Test Registration

```gdscript
# In run_tests():
var t86 = _test_feature_name()
results["tests"].append(t86)
if t86["passed"]:
    results["passed"] += 1
else:
    results["failed"] += 1
```

### Running Tests

```bash
# From project root
DevTools\run_headless.bat

# Expected output:
# Stage 1 (Import/Validation): PASSED
# Stage 2 (Test Suite): X passed, Y failed
```

## Data Access Patterns

### DataRegistry Access

```gdscript
# Get typed data (returns RefCounted objects)
var item = DataRegistry.get_item_template("healing_tonic")
var hero_class = DataRegistry.get_class("defender")
var monster = DataRegistry.get_monster("goblin")
var facility = DataRegistry.get_facility("blacksmith")
var ability = DataRegistry.get_ability("aegis_slam")
var status = DataRegistry.get_status_effect("poisoned")
```

### GameContext State Access

```gdscript
# Gold
var gold = GameContext.get_run_gold()
GameContext.add_run_gold(50)
GameContext.remove_run_gold(30)

# Items
var count = GameContext.get_run_item_count("herb")
GameContext.add_run_item("herb", 3)
GameContext.remove_run_item("herb", 1)

# Heroes
var hero = GameContext.get_hero("hero_defender_1")
var party = GameContext.get_selected_party()
GameContext.add_hero_to_party("hero_defender_1")

# Equipment
var weapon_id = GameContext.get_hero_weapon("hero_id")
GameContext.equip_hero_item("hero_id", "weapon", "iron_sword")

# Bags
var bag = GameContext.get_hero_bag("hero_id")
var cap = GameContext.get_hero_bag_capacity("hero_id")
GameContext.add_item_to_hero_bag("hero_id", "healing_tonic", 1)

# Unlocks
var unlocked = GameContext.has_unlocked_group("weapons_t2")
GameContext.unlock_group("weapons_t2")

# Facility tiers
var tier = GameContext.get_facility_tier("town_greenroot", "blacksmith")
GameContext.upgrade_facility("town_greenroot", "blacksmith")
```

## Unlock Group IDs

### Default Groups (Always Unlocked)
- `consumables_t1`
- `weapons_t1`
- `books_t1`
- `materials_t1`

### Purchasable Groups
- `backpacks_t1` (Leatherworker unlock)
- `backpacks_t2` (Leatherworker unlock, tier 2)
- `weapons_t2` (Blacksmith unlock, tier 2)
- `consumables_t2` (Alchemist unlock)

## Version History

| Version | Feature |
|---------|---------|
| v1.0 | Base hero recruitment, equipment |
| v1.1 | Backpack slot, hero bags |
| v1.2 | Shopkeeper bag, stash banking rules |
| v1.3 | All item types in bags, no stacking |
| v2.0 | Combat identity, Inn UI improvements |
| v2.1 | Facility unlocks, unlock purchase UI |

## Common Gotchas

1. **Godot 4 Dictionary.get()** takes only 1 argument. Use `dict.get("key")` or access property directly for objects.

2. **Facility data** is an object with properties (`facility.unlocks`), not a dictionary.

3. **Item data** from DataRegistry is `ItemTemplate` RefCounted object, not raw dictionary.

4. **queue_free()** is deferred. For immediate removal, use `remove_child()` + `free()`.

5. **Signal connections** persist even after node is queued for deletion. Disconnect first if needed.

6. **run_items** contains both `ItemInstance` objects and `Dictionary` entries. Handle both in loops.
