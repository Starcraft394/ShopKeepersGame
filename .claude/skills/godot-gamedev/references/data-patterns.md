# Data Patterns Reference

JSON schema conventions and data loading patterns for Godot projects.

## Data Registry Architecture

```gdscript
# DataRegistry.gd (Autoload)
extends Node

# Private caches
var _classes: Dictionary = {}
var _races: Dictionary = {}
var _items: Dictionary = {}
var _abilities: Dictionary = {}
var _monsters: Dictionary = {}
var _facilities: Dictionary = {}
var _dungeons: Dictionary = {}

signal data_loaded

func _ready() -> void:
    _load_all_data()
    data_loaded.emit()

func _load_all_data() -> void:
    _load_category("Classes", _classes, ClassData)
    _load_category("Races", _races, RaceData)
    _load_category("Items/Templates", _items, ItemTemplate)
    # ... etc

func _load_category(folder: String, cache: Dictionary, type_class) -> void:
    var path = "res://Data/%s/" % folder
    var dir = DirAccess.open(path)
    if dir == null:
        return

    for file in dir.get_files():
        if file.ends_with(".json"):
            var data = _load_json(path + file)
            var obj = type_class.from_dict(data)
            cache[obj.id] = obj
```

## JSON Schema Conventions

### Item Template Schema

```json
{
  "id": "healing_tonic",
  "display_name": "Healing Tonic",
  "description": "Restores health when consumed.",
  "item_type": "consumable",
  "item_subtype": "potion",
  "category": "consumable",
  "slot": "",
  "tier": 1,
  "base_stats": {},
  "use_effect": "heal",
  "use_value": 25,
  "base_value": 15,
  "tags": ["region_1", "consumable", "healing"]
}
```

### Equipment Schema

```json
{
  "id": "iron_sword",
  "display_name": "Iron Sword",
  "description": "A sturdy blade.",
  "item_type": "equipment",
  "item_subtype": "sword",
  "category": "weapon",
  "slot": "weapon",
  "equip_slot": "weapon",
  "tier": 2,
  "base_stats": {
    "attack": 8
  },
  "stat_bonuses": {
    "attack": 2
  },
  "base_value": 50,
  "tags": ["region_1", "weapon", "sword", "melee"]
}
```

### Class Schema

```json
{
  "id": "defender",
  "display_name": "Defender",
  "description": "A stalwart protector.",
  "archetype": "vanguard",
  "unlock_region": 1,
  "base_stats": {
    "health": 120,
    "attack": 8,
    "defense": 15,
    "speed": 6
  },
  "stat_growth": {
    "health": 12,
    "attack": 2,
    "defense": 3,
    "speed": 1
  },
  "ability_a_id": "guardian_challenge",
  "ability_b_id": "aegis_slam",
  "passive_a_id": "bulwark_stance",
  "passive_b_id": "shielding_presence",
  "weapon_types": ["sword", "axe", "hammer"]
}
```

### Facility Schema

```json
{
  "id": "blacksmith",
  "display_name": "Blacksmith",
  "description": "Forges weapons and armor.",
  "facility_type": "production",
  "max_tier": 3,
  "unlock_region": 1,
  "slots_per_tier": {
    "1": 2,
    "2": 3,
    "3": 4
  },
  "upgrade_costs": {
    "2": {
      "gold": 100,
      "items": [
        { "item_id": "iron_scrap", "qty": 5 }
      ]
    }
  },
  "services_per_tier": {
    "1": ["repair", "basic_craft"],
    "2": ["repair", "basic_craft", "upgrade"]
  },
  "unlocks": [
    {
      "id": "unlock_weapons_t2",
      "unlock_group": "weapons_t2",
      "label": "Unlock Tier 2 Weapons",
      "required_tier": 2,
      "costs": [
        { "item_id": "iron_scrap", "qty": 10 }
      ]
    }
  ]
}
```

### Monster Schema

```json
{
  "id": "goblin",
  "display_name": "Goblin",
  "description": "A sneaky creature.",
  "family": "humanoid",
  "region_id": "region_1",
  "tier": 1,
  "base_stats": {
    "health": 30,
    "attack": 6,
    "defense": 2,
    "speed": 10
  },
  "ability_ids": ["basic_attack"],
  "passive_ids": [],
  "loot_table_id": "lt_region1_common",
  "gold_drop_min": 5,
  "gold_drop_max": 12
}
```

### Status Effect Schema

```json
{
  "id": "poisoned",
  "display_name": "Poisoned",
  "description": "Takes damage each turn.",
  "category": "dot",
  "stacking_mode": "intensity",
  "max_stacks": 5,
  "base_duration": 3,
  "base_value": 3,
  "is_cleansable": true,
  "tags": ["debuff", "dot", "nature"],
  "ui_name": "Poisoned",
  "ui_short": "PSN"
}
```

## Data Type Classes

### from_dict() Factory Pattern

```gdscript
# ItemTemplate.gd
class_name ItemTemplate
extends RefCounted

var id: String
var display_name: String
var description: String
var item_type: String
var category: String
var slot: String
var tier: int
var base_stats: Dictionary
var base_value: int
var tags: Array

static func from_dict(data: Dictionary) -> ItemTemplate:
    var item = ItemTemplate.new()
    item.id = data.get("id", "")
    item.display_name = data.get("display_name", item.id)
    item.description = data.get("description", "")
    item.item_type = data.get("item_type", "")
    item.category = data.get("category", item.item_type)
    item.slot = data.get("slot", "")
    item.tier = int(data.get("tier", 1))
    item.base_stats = data.get("base_stats", {})
    item.base_value = int(data.get("base_value", 0))
    item.tags = data.get("tags", [])
    return item

func to_dict() -> Dictionary:
    return {
        "id": id,
        "display_name": display_name,
        "description": description,
        "item_type": item_type,
        "category": category,
        "slot": slot,
        "tier": tier,
        "base_stats": base_stats,
        "base_value": base_value,
        "tags": tags
    }
```

### Handling Optional Fields

```gdscript
# Safe access with defaults
var value = data.get("optional_field", default_value)

# Type coercion for numbers (JSON may load as float)
var tier = int(data.get("tier", 1))
var price = float(data.get("price", 0.0))

# Array with empty default
var tags = data.get("tags", [])

# Nested dictionary with empty default
var stats = data.get("base_stats", {})
var attack = int(stats.get("attack", 0))
```

## Gating System

### Unlock Groups

```gdscript
# Default unlocks (always available)
const DEFAULT_UNLOCK_GROUPS = [
    "consumables_t1",
    "weapons_t1",
    "books_t1",
    "materials_t1"
]

# Check if group is unlocked
func has_unlocked_group(group_id: String) -> bool:
    if group_id in DEFAULT_UNLOCK_GROUPS:
        return true
    return unlocked_groups.get(group_id, false)

# Unlock a group
func unlock_group(group_id: String) -> void:
    unlocked_groups[group_id] = true
    save_game()
```

### Shop Item Gating

```json
{
  "item_id": "iron_sword",
  "price_gold": 100,
  "requires_unlock_group": "weapons_t2",
  "required_facility_tier": 2
}
```

```gdscript
func _filter_shop_items(items: Array) -> Array:
    return items.filter(func(item):
        # Check unlock group
        var group = item.get("requires_unlock_group", "")
        if group != "" and not GameContext.has_unlocked_group(group):
            return false

        # Check facility tier
        var req_tier = item.get("required_facility_tier", 1)
        var current_tier = GameContext.get_facility_tier(town_id, facility_id)
        if current_tier < req_tier:
            return false

        return true
    )
```

## Validation Patterns

### Schema Validation

```gdscript
func _validate_item(data: Dictionary) -> bool:
    # Required fields
    if not data.has("id") or data.id == "":
        push_error("Item missing id")
        return false

    if not data.has("item_type"):
        push_error("Item %s missing item_type" % data.id)
        return false

    # Type checks
    if data.has("tier") and not (data.tier is int or data.tier is float):
        push_error("Item %s tier must be numeric" % data.id)
        return false

    return true
```

### Load-Time Warnings

```gdscript
func _load_json(path: String) -> Dictionary:
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Could not open: %s" % path)
        return {}

    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    if error != OK:
        push_error("JSON parse error in %s: %s" % [path, json.get_error_message()])
        return {}

    return json.data
```

## Performance Considerations

### Lazy Loading (Optional)

```gdscript
# For very large data sets, load on demand
var _monsters_loaded: bool = false

func get_monster(id: String) -> MonsterData:
    if not _monsters_loaded:
        _load_monsters()
    return _monsters.get(id)
```

### Reference vs Copy

```gdscript
# Data registry returns references (read-only use)
var item = DataRegistry.get_item("healing_tonic")

# If you need to modify, duplicate first
var item_copy = item.duplicate()
item_copy.base_value = 100  # Only affects copy
```

## Common Patterns

### Tag-Based Filtering

```gdscript
func get_items_by_tag(tag: String) -> Array:
    return _items.values().filter(func(item):
        return tag in item.tags
    )

# Usage
var consumables = DataRegistry.get_items_by_tag("consumable")
var region1_items = DataRegistry.get_items_by_tag("region_1")
```

### Tier Scaling

```gdscript
func get_scaled_value(base: int, tier: int, scale_factor: float = 0.2) -> int:
    return int(base * (1.0 + scale_factor * (tier - 1)))

# Tier 1: base
# Tier 2: base * 1.2
# Tier 3: base * 1.4
```
