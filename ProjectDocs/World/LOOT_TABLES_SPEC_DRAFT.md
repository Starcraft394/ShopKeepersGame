# Loot Tables Specification Draft

**Status:** NOT IMPLEMENTED
**Created:** 2026-01-02
**Purpose:** Define minimal loot table system aligned with existing SeededRNG utilities.

---

## 1. Data Location

```
Data/LootTables/
  lt_region1_common.json
  lt_region1_uncommon.json
  lt_region1_elite.json
  lt_region1_boss.json
```

---

## 2. Proposed JSON Schema

Aligns with `SeededRNG.choose_weighted(entries, rng)` which expects:
- `entries`: Array of `{ "value": any, "weight": float }`

### LootTableData Schema

```json
{
  "id": "lt_region1_common",
  "display_name": "Region 1 Common Loot",
  "description": "Basic drops from tier 1-2 monsters.",
  "min_drops": 1,
  "max_drops": 2,
  "entries": [
    { "item_id": "wood_bundle", "weight": 30, "min_qty": 1, "max_qty": 2 },
    { "item_id": "herb_sprig", "weight": 25, "min_qty": 1, "max_qty": 2 },
    { "item_id": "iron_scrap", "weight": 15, "min_qty": 1, "max_qty": 1 },
    { "item_id": "", "weight": 30 }
  ]
}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | String | Yes | Unique loot table identifier |
| `display_name` | String | Yes | Human-readable name |
| `description` | String | No | Optional description |
| `min_drops` | int | Yes | Minimum items rolled (default: 1) |
| `max_drops` | int | Yes | Maximum items rolled (default: 1) |
| `entries` | Array | Yes | Weighted drop entries |
| `entries[].item_id` | String | Yes | ItemTemplate ID (empty = no drop) |
| `entries[].weight` | float | Yes | Relative weight for selection |
| `entries[].min_qty` | int | No | Minimum quantity (default: 1) |
| `entries[].max_qty` | int | No | Maximum quantity (default: 1) |

---

## 3. Example Loot Tables (Region 1)

### lt_region1_common.json
For tier 1-2 monsters (gr_rootkin_sprite, tf_bandit_raider, etc.)

```json
{
  "id": "lt_region1_common",
  "display_name": "Region 1 Common Loot",
  "description": "Basic drops from low-tier forest creatures.",
  "min_drops": 1,
  "max_drops": 2,
  "entries": [
    { "item_id": "wood_bundle", "weight": 30, "min_qty": 1, "max_qty": 2 },
    { "item_id": "herb_sprig", "weight": 25, "min_qty": 1, "max_qty": 2 },
    { "item_id": "iron_scrap", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "minor_healing_tonic", "weight": 5, "min_qty": 1, "max_qty": 1 },
    { "item_id": "", "weight": 30 }
  ]
}
```

### lt_region1_uncommon.json
For tier 2-3 monsters (gr_moss_troll, tf_sawbone_enforcer, etc.)

```json
{
  "id": "lt_region1_uncommon",
  "display_name": "Region 1 Uncommon Loot",
  "description": "Better drops from mid-tier threats.",
  "min_drops": 1,
  "max_drops": 3,
  "entries": [
    { "item_id": "iron_scrap", "weight": 25, "min_qty": 1, "max_qty": 2 },
    { "item_id": "herb_sprig", "weight": 20, "min_qty": 1, "max_qty": 3 },
    { "item_id": "minor_healing_tonic", "weight": 15, "min_qty": 1, "max_qty": 1 },
    { "item_id": "antidote_vial", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "leather_vest", "weight": 5, "min_qty": 1, "max_qty": 1 },
    { "item_id": "", "weight": 25 }
  ]
}
```

### lt_region1_elite.json
For elite monsters (gr_briar_guardian, etc.)

```json
{
  "id": "lt_region1_elite",
  "display_name": "Region 1 Elite Loot",
  "description": "Guaranteed drops from elite enemies.",
  "min_drops": 2,
  "max_drops": 4,
  "entries": [
    { "item_id": "iron_scrap", "weight": 20, "min_qty": 2, "max_qty": 3 },
    { "item_id": "minor_healing_tonic", "weight": 20, "min_qty": 1, "max_qty": 2 },
    { "item_id": "leather_vest", "weight": 15, "min_qty": 1, "max_qty": 1 },
    { "item_id": "iron_dagger", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "wooden_sword", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "simple_ring", "weight": 5, "min_qty": 1, "max_qty": 1 },
    { "item_id": "", "weight": 20 }
  ]
}
```

### lt_region1_boss.json
For boss monster (thorn_ent)

```json
{
  "id": "lt_region1_boss",
  "display_name": "Region 1 Boss Loot",
  "description": "Rare drops from the Thorn Ent.",
  "min_drops": 3,
  "max_drops": 5,
  "entries": [
    { "item_id": "iron_scrap", "weight": 15, "min_qty": 3, "max_qty": 5 },
    { "item_id": "herb_sprig", "weight": 15, "min_qty": 3, "max_qty": 5 },
    { "item_id": "minor_healing_tonic", "weight": 15, "min_qty": 2, "max_qty": 3 },
    { "item_id": "leather_vest", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "oak_staff", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "tanned_leather_hood", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "lucky_charm", "weight": 5, "min_qty": 1, "max_qty": 1 },
    { "item_id": "simple_ring", "weight": 10, "min_qty": 1, "max_qty": 1 },
    { "item_id": "", "weight": 10 }
  ]
}
```

---

## 4. Optional Minimal Diff Plan (NOT APPLIED)

### 4.1 Create LootTableData.gd

```gdscript
# Game/Core/DataTypes/LootTableData.gd
class_name LootTableData
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var min_drops: int = 1
var max_drops: int = 1
var entries: Array = []  # Array of { item_id, weight, min_qty, max_qty }

static func from_dict(data: Dictionary) -> LootTableData:
    var instance = LootTableData.new()
    instance.id = data.get("id", "")
    instance.display_name = data.get("display_name", "")
    instance.description = data.get("description", "")
    instance.min_drops = data.get("min_drops", 1)
    instance.max_drops = data.get("max_drops", 1)

    var raw_entries = data.get("entries", [])
    instance.entries.clear()
    for e in raw_entries:
        if e is Dictionary:
            instance.entries.append(e)

    return instance

func is_valid() -> bool:
    return id != "" and display_name != "" and not entries.is_empty()
```

### 4.2 Update DataRegistry.gd

```gdscript
# Add to DATA CACHES section:
var _loot_tables: Dictionary = {}       # id -> LootTableData

# Add to _load_all_data():
_load_folder("LootTables", _loot_tables, LootTableData)

# Add to PUBLIC API - LOOKUPS:
func get_loot_table(id: String) -> LootTableData:
    return _loot_tables.get(id, null)

func get_all_loot_tables() -> Array:
    return _loot_tables.values()

# Add to _print_summary():
print("  Loot Tables:    %d" % _loot_tables.size())

# Add to get_summary_counts():
"loot_tables": _loot_tables.size(),
```

### 4.3 Add roll_loot() utility

```gdscript
# Game/Core/LootRoller.gd (or add to SeededRNG.gd)
static func roll_loot(table: LootTableData, rng: RandomNumberGenerator) -> Array:
    var results: Array = []
    if table == null or table.entries.is_empty():
        return results

    var drop_count = rng.randi_range(table.min_drops, table.max_drops)

    # Convert entries to choose_weighted format
    var weighted: Array = []
    for e in table.entries:
        weighted.append({ "value": e, "weight": e.get("weight", 1.0) })

    for i in range(drop_count):
        var chosen = SeededRNG.choose_weighted(weighted, rng)
        if chosen and chosen.get("item_id", "") != "":
            var item_id = chosen.get("item_id")
            var qty = rng.randi_range(chosen.get("min_qty", 1), chosen.get("max_qty", 1))
            results.append({ "item_id": item_id, "quantity": qty })

    return results
```

---

## 5. Monster Assignment Plan (when implemented)

| Monster | Tier | Loot Table |
|---------|------|------------|
| gr_rootkin_sprite | 1 | lt_region1_common |
| tf_bandit_raider | 1 | lt_region1_common |
| gr_moss_troll | 2 | lt_region1_uncommon |
| tf_sawbone_enforcer | 2 | lt_region1_uncommon |
| gr_briar_guardian | 3 (elite) | lt_region1_elite |
| thorn_ent | boss | lt_region1_boss |

---

## 6. Implementation Checklist

- [ ] Create `Game/Core/DataTypes/LootTableData.gd`
- [ ] Add `_loot_tables` cache to DataRegistry.gd
- [ ] Add `_load_folder("LootTables", ...)` call
- [ ] Add `get_loot_table()` API
- [ ] Create `Data/LootTables/` folder
- [ ] Create 4 loot table JSON files
- [ ] Update monster JSONs with loot_table_id values
- [ ] Add roll_loot() utility function
- [ ] Test deterministic rolling with SeededRNG
