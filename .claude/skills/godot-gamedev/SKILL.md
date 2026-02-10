---
name: godot-gamedev
description: >
  Build games with Godot 4.5+ and GDScript using data-driven architecture,
  test-first development, and deterministic design. Covers scene management,
  autoloads, JSON data loading, combat systems, UI/Control nodes, and headless
  testing. Trigger: "godot", "gdscript", "game development", "combat system",
  "turn-based", "autoload", "scene", "signal".
---

# Godot Game Development

A philosophy-first framework for building robust, maintainable games with Godot 4.5+ and GDScript.

## Philosophy: Data-Driven Determinism

Games are **state machines with visual feedback**. The best Godot architectures separate:
- **Data** (what exists) from **Logic** (what happens) from **Presentation** (what players see)
- **Deterministic core** (reproducible) from **Presentation randomness** (visual variety)

**Core principle: If you can't test it headless, you can't trust it.**

### The Three Pillars of Godot Architecture

1. **Autoloads as Services**: Global singletons for cross-scene state and utilities
2. **Data Registry Pattern**: JSON-driven content that loads once, references everywhere
3. **Scene-as-Component**: Scenes are reusable units, not monolithic levels

### Before Writing Code, Ask

- **State ownership**: Which autoload/node owns this data?
- **Persistence**: Does this survive scene changes? Game restarts?
- **Testability**: Can I verify this without launching the full game?
- **Determinism**: Given the same inputs, will this always produce the same outputs?

---

## Godot 4.5 Fundamentals

### Project Structure Pattern

```
project/
├── Game/
│   ├── Core/           # Autoloads, data types, utilities
│   │   ├── DataRegistry.gd    # JSON loader singleton
│   │   ├── GameContext.gd     # Game state singleton
│   │   └── DataTypes/         # from_dict() factory classes
│   ├── Combat/         # Combat system (isolated, testable)
│   ├── UI/             # Scene-based UI (Town/, Combat/, etc.)
│   └── Boot/           # Entry point, autoload validation
├── Data/               # JSON content (items, monsters, abilities)
├── DevTools/           # Test scripts, headless runners
├── Themes/             # Godot theme resources
└── Assets/             # Audio, icons, sprites
```

### Autoload Design

**Good autoload candidates:**
- State that persists across scenes (GameContext)
- Data that loads once and is referenced everywhere (DataRegistry)
- Utilities with no scene dependencies (SeededRNG)

**Bad autoload candidates:**
- UI elements (use scenes)
- Anything that needs `_process()` for gameplay (use nodes)
- Large objects that should be garbage collected

```gdscript
# Good: Stateless utility autoload
extends Node

func derive_seed(key: String, base: int) -> int:
    # Pure function, no state
    return hash(key) ^ base
```

### Signal-Driven Communication

**Pattern: Events flow up, commands flow down**

```gdscript
# Child emits events (doesn't know who listens)
signal item_selected(item_id: String)

# Parent connects and handles
child.item_selected.connect(_on_item_selected)

# Parent calls methods on children (commands)
child.refresh_display()
```

**Anti-pattern: Reaching up the tree**
```gdscript
# BAD: Child knows about parent structure
get_parent().get_parent().update_gold()

# GOOD: Child emits signal, parent handles
gold_changed.emit(new_amount)
```

---

## Data-Driven Content

### JSON Loading Pattern

```gdscript
# DataRegistry.gd (autoload)
var _items: Dictionary = {}

func _ready() -> void:
    _load_all_data()

func _load_all_data() -> void:
    var dir = DirAccess.open("res://Data/Items/")
    for file in dir.get_files():
        if file.ends_with(".json"):
            var data = _load_json("res://Data/Items/" + file)
            var item = ItemTemplate.from_dict(data)
            _items[item.id] = item

func get_item(id: String) -> ItemTemplate:
    return _items.get(id)
```

### Data Type Factory Pattern

```gdscript
# ItemTemplate.gd
class_name ItemTemplate
extends RefCounted

var id: String
var display_name: String
var base_stats: Dictionary

static func from_dict(data: Dictionary) -> ItemTemplate:
    var item = ItemTemplate.new()
    item.id = data.get("id", "")
    item.display_name = data.get("display_name", item.id)
    item.base_stats = data.get("base_stats", {})
    return item
```

**Key principle**: Data types use `from_dict()` factories, never direct dictionary access in game logic.

See references/data-patterns.md for JSON schema conventions.

---

## Combat System Patterns

### Turn-Based Architecture

```
CombatController (orchestrator)
├── TurnQueue (ordering)
├── CombatUnit[] (state)
├── StatusRuntime (per-unit effects)
└── CombatResult (outcome tracking)
```

**Invariants (DO NOT MODIFY without explicit request):**
- Turn order: Higher speed first, player wins ties
- Status ticks: Process at round start, before actions
- Damage calculation: Use effective stats (base + buffs)
- RNG: All randomness through SeededRNG

### Combat Unit Pattern

```gdscript
class_name CombatUnit
extends RefCounted

var unit_id: String
var base_attack: int
var base_defense: int
var buffs: Array = []

func get_effective_attack() -> int:
    var total = base_attack
    for buff in buffs:
        if buff.stat == "attack":
            total += buff.value
    return total
```

**Always use effective stats in calculations, never base stats directly.**

See references/combat-system.md for detailed combat semantics.

---

## UI/Control Patterns

### Dynamic UI Generation

```gdscript
func _build_item_list(items: Array) -> void:
    # Clear existing children
    for child in container.get_children():
        child.queue_free()

    # Build new UI
    for item in items:
        var row = HBoxContainer.new()

        var label = Label.new()
        label.text = item.display_name
        row.add_child(label)

        var button = Button.new()
        button.text = "Select"
        button.pressed.connect(_on_item_selected.bind(item.id))
        row.add_child(button)

        container.add_child(row)
```

### Theme Consistency

```gdscript
# Use theme overrides sparingly, prefer theme resources
label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))

# Better: Define in Themes/game_theme.tres
# Then apply theme to root Control node
```

See references/ui-patterns.md for Control node best practices.

---

## Testing & Validation

### Headless Test Pattern

```gdscript
# DevTools/test_my_feature.gd
static func run_tests() -> Dictionary:
    var results = {"passed": 0, "failed": 0}

    var t1 = _test_feature_a()
    if t1["passed"]:
        results["passed"] += 1
    else:
        results["failed"] += 1

    return results

static func _test_feature_a() -> Dictionary:
    print("--- TEST: Feature A ---")

    # Setup
    var original_state = GameContext.some_value
    GameContext.some_value = "test_value"

    # Execute
    var result = GameContext.do_something()

    # Assert
    var passed = result == expected_value
    if passed:
        print("[PASS] Feature A works")
    else:
        print("[FAIL] Expected %s, got %s" % [expected_value, result])

    # Cleanup
    GameContext.some_value = original_state

    return {"name": "Feature A", "passed": passed}
```

### Test Runner Script

```bash
# DevTools/run_headless.bat
godot --headless --path . --script res://DevTools/run_tests_headless.gd --quit
```

**Every feature change must include tests. No exceptions.**

---

## Save/Load Patterns

### Serialization Strategy

```gdscript
func save_game() -> void:
    var data = {
        "version": 1,
        "player_gold": player_gold,
        "inventory": _serialize_inventory(),
        "unlocks": unlocked_groups.duplicate()
    }
    var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(data, "\t"))

func _serialize_inventory() -> Array:
    var result = []
    for item in inventory:
        if item is ItemInstance:
            result.append(item.to_dict())
        elif item is Dictionary:
            result.append(item)
    return result
```

### Migration Pattern

```gdscript
func load_game() -> void:
    var data = _load_json("user://savegame.json")
    var version = data.get("version", 0)

    # Apply migrations
    if version < 1:
        data = _migrate_v0_to_v1(data)

    # Load current format
    player_gold = data.get("player_gold", 0)
```

---

## Anti-Patterns to Avoid

❌ **God Autoload**: Single autoload with thousands of lines
Why bad: Impossible to test, hard to understand
Better: Split by domain (GameContext, DataRegistry, SeededRNG)

❌ **Dictionary Soup**: Passing raw dictionaries through game logic
Why bad: No type safety, easy to misspell keys
Better: Data type classes with `from_dict()` factories

❌ **Scene Tree Coupling**: Using `get_node("../../../SomeNode")`
Why bad: Breaks when hierarchy changes
Better: Signals, autoloads, or dependency injection

❌ **Untested Features**: "It works in the editor"
Why bad: Breaks silently, regressions go unnoticed
Better: Headless tests for all game logic

❌ **Magic Strings**: `if item.type == "weapon"`
Why bad: Typos cause silent failures
Better: Enums or constants: `if item.type == ItemType.WEAPON`

❌ **Presentation in Logic**: Combat system spawns particles
Why bad: Can't test headless, couples systems
Better: Combat emits signals, UI observes and spawns effects

❌ **Mutable Shared State**: Multiple systems modifying same dictionary
Why bad: Race conditions, unpredictable behavior
Better: Clear ownership, copy-on-write, or immutable patterns

---

## Variation Guidance

**IMPORTANT**: Godot projects vary significantly. Adapt these patterns:

- **Solo dev vs team**: Solo can use simpler patterns; teams need stricter conventions
- **Prototype vs production**: Prototypes can skip tests; production requires them
- **Real-time vs turn-based**: Real-time needs `_process()`; turn-based can be event-driven
- **2D vs 3D**: Different node types, but same architectural principles
- **Mobile vs desktop**: Mobile needs touch input patterns, performance budgets

**Avoid converging on**:
- Always using the same node hierarchy
- Copy-pasting boilerplate without understanding
- Over-engineering simple features
- Under-engineering complex systems

---

## Quick Reference

### Common Operations

| Task | Pattern |
|------|---------|
| Load JSON | `DataRegistry.get_item(id)` |
| Persist state | `GameContext.save_game()` |
| Scene change | `get_tree().change_scene_to_file()` |
| Dynamic UI | Create nodes in code, `queue_free()` to remove |
| Signals | `signal_name.emit()` / `.connect()` |
| Deterministic random | `SeededRNG.randi_range()` |

### Godot 4.5 Syntax Notes

```gdscript
# Typed arrays
var items: Array[ItemTemplate] = []

# Dictionary access with default
var value = dict.get("key", default_value)

# Null-safe navigation
var name = item.template.display_name if item.template else "Unknown"

# String formatting
print("[System] Value=%d" % value)
print("[System] A=%s B=%d" % [str_val, int_val])
```

---

## Remember

**Godot empowers rapid iteration. These patterns protect that speed at scale.**

The best Godot projects:
- Load data once, reference everywhere
- Test logic without launching the game
- Separate what the game knows from what players see
- Use signals to decouple systems
- Treat scenes as reusable components

**Claude is capable of extraordinary Godot development. These guidelines illuminate the path—they don't fence it.**
