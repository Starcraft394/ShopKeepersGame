# Shops & Shadows — Implementation Entry Point
## First System Definition & Public API

---

## The First System: DataRegistry

**System ID:** `DataRegistry`
**Type:** Autoload Service (Singleton)
**Location:** `res://Game/Core/DataRegistry.gd`
**Tier:** 0.2

---

## Why DataRegistry First?

### 1. Zero Gameplay Dependencies

DataRegistry has no dependencies on any other gameplay system. It only requires:
- The Godot engine
- Data files on disk (JSON or Resources)

Every other system in the game depends on DataRegistry for static data lookup:
- Heroes need race/class definitions
- Items need templates and affix pools
- Monsters need stat templates
- Combat needs ability definitions
- Status effects need the registry

### 2. Enables All Other Development

Once DataRegistry exists and is populated with placeholder data:
- Hero system can look up race/class stats
- Item system can look up templates
- Combat can resolve abilities
- AI can query enemy definitions

Without DataRegistry, no other system can be meaningfully implemented.

### 3. Establishes Data-Driven Pattern

Implementing DataRegistry first enforces the "data-driven first" principle from GDD 32.1.1 and Section 41.4:
- All values come from data, not hard-coded logic
- Systems read from data; they do not infer
- Balance changes require data edits, not code changes

### 4. Simple to Verify

DataRegistry is straightforward to test:
- Load a data file → verify it loads
- Query an ID → verify it returns correct data
- Query invalid ID → verify it returns null/error

This gives early confidence in the foundation.

---

## DataRegistry Public API

### Type Definitions

```gdscript
# Data container types (RefCounted)
class_name ClassData extends RefCounted
class_name RaceData extends RefCounted
class_name ItemTemplate extends RefCounted
class_name PassiveData extends RefCounted
class_name MonsterData extends RefCounted
class_name StatusEffectData extends RefCounted
class_name AbilityData extends RefCounted
class_name RegionData extends RefCounted
class_name FacilityData extends RefCounted
```

### Core Lookup Functions

```gdscript
# Class System
func get_class_data(class_id: String) -> ClassData
func get_all_classes() -> Array[ClassData]
func class_exists(class_id: String) -> bool

# Race System
func get_race_data(race_id: String) -> RaceData
func get_all_races() -> Array[RaceData]
func race_exists(race_id: String) -> bool

# Item Templates
func get_item_template(template_id: String) -> ItemTemplate
func get_templates_by_type(item_type: String) -> Array[ItemTemplate]
func get_templates_by_tier(tier: int) -> Array[ItemTemplate]
func template_exists(template_id: String) -> bool

# Passives
func get_passive(passive_id: String) -> PassiveData
func get_passives_by_category(category: String) -> Array[PassiveData]
func passive_exists(passive_id: String) -> bool

# Monsters
func get_monster(monster_id: String) -> MonsterData
func get_monsters_by_region(region_id: String) -> Array[MonsterData]
func get_monsters_by_family(family_id: String) -> Array[MonsterData]
func monster_exists(monster_id: String) -> bool

# Status Effects (Registry-First Enforcement)
func get_status_effect(effect_id: String) -> StatusEffectData
func get_all_status_effects() -> Array[StatusEffectData]
func status_effect_exists(effect_id: String) -> bool
func validate_status_effect(effect_id: String) -> bool  # Returns false + logs if invalid

# Abilities
func get_ability(ability_id: String) -> AbilityData
func get_abilities_by_class(class_id: String) -> Array[AbilityData]
func ability_exists(ability_id: String) -> bool

# Regions
func get_region(region_id: String) -> RegionData
func get_all_regions() -> Array[RegionData]
func region_exists(region_id: String) -> bool

# Facilities
func get_facility(facility_id: String) -> FacilityData
func get_all_facilities() -> Array[FacilityData]
func facility_exists(facility_id: String) -> bool
```

### Initialization & Lifecycle

```gdscript
# Called on autoload ready
func _ready():
    _load_all_data()

# Manual reload (dev mode only)
func reload_all_data() -> bool

# Data loading
func _load_all_data() -> void
func _load_classes() -> void
func _load_races() -> void
func _load_items() -> void
func _load_passives() -> void
func _load_monsters() -> void
func _load_status_effects() -> void
func _load_abilities() -> void
func _load_regions() -> void
func _load_facilities() -> void
```

### Validation & Debug

```gdscript
# Schema validation (dev mode)
func validate_all_data() -> Array[String]  # Returns list of errors
func validate_class_data(data: Dictionary) -> bool
func validate_item_template(data: Dictionary) -> bool
# ... etc for each type

# Debug helpers
func get_load_stats() -> Dictionary  # counts per type
func print_registry_summary() -> void
```

### Signals

```gdscript
signal data_loaded()
signal data_load_failed(error: String)
signal validation_error(type: String, id: String, message: String)
```

---

## Data Inputs

### Expected Data Files

| File Path | Contents |
|-----------|----------|
| `res://Data/Classes/*.json` or `*.tres` | Class definitions |
| `res://Data/Races/*.json` or `*.tres` | Race definitions |
| `res://Data/Items/Templates/*.json` | Item templates |
| `res://Data/Items/Affixes/*.json` | Affix pools |
| `res://Data/Passives/*.json` | Passive abilities |
| `res://Data/Monsters/*.json` | Monster templates |
| `res://Data/StatusEffects/*.json` | Status effect registry |
| `res://Data/Abilities/*.json` | Ability definitions |
| `res://Data/Regions/*.json` | Region definitions |
| `res://Data/Facilities/*.json` | Facility definitions |

### Minimum Viable Data Set

To unblock other systems, DataRegistry needs at least:

```
Data/
├── Classes/
│   └── warrior.json      # 1 starter class
├── Races/
│   └── human.json        # 1 starter race
├── Items/
│   └── Templates/
│       └── basic_sword.json  # 1 weapon template
├── Monsters/
│   └── goblin.json       # 1 basic enemy
├── StatusEffects/
│   └── burn.json         # 1 DoT effect
│   └── stun.json         # 1 control effect
├── Abilities/
│   └── basic_attack.json # 1 universal ability
├── Regions/
│   └── region_1.json     # Starting region
└── Facilities/
    └── blacksmith.json   # 1 starter facility
```

---

## Data Output Examples

### ClassData Structure

```gdscript
class_name ClassData extends RefCounted

var class_id: String
var display_name: String
var description: String
var unlock_region: int
var base_stats: Dictionary  # { "health": 100, "attack": 10, ... }
var ability_a_id: String
var ability_b_id: String
var passive_a_id: String
var passive_b_id: String
var weapon_types: Array[String]  # allowed weapon categories
```

### ItemTemplate Structure

```gdscript
class_name ItemTemplate extends RefCounted

var template_id: String
var display_name: String
var item_type: String  # "weapon", "armor", "accessory", etc.
var slot: String       # "weapon_main", "chest", etc.
var tier: int
var base_stats: Dictionary
var allowed_affixes: Array[String]
var max_sockets: int
var can_refine: bool
```

### StatusEffectData Structure

```gdscript
class_name StatusEffectData extends RefCounted

var effect_id: String
var display_name: String
var category: String  # "dot", "control", "buff", "debuff", "countdown"
var icon_path: String
var max_stacks: int
var stack_type: String  # "linear", "threshold", "countdown_extension"
var base_value: int
var duration: int  # -1 for permanent until removed
var is_cleansable: bool
var dispel_type: String  # "buff", "debuff", "none"
```

---

## Implementation Notes

### GDD Alignment

- **Section 14:** Godot Data Architecture patterns
- **Section 32.1:** Data-driven philosophy
- **Section 41.3:** DataRegistry as allowed autoload
- **Section 41.4:** Resource vs JSON guidance
- **Section 41.7:** Status effect registry-first enforcement

### Key Implementation Rules

1. **Read-Only Data**
   - All returned data should be treated as immutable
   - Consider returning copies or using `@readonly` patterns

2. **Lazy Loading Option**
   - May load all on startup OR load per-category on first access
   - For MVP, load all on startup is simpler

3. **Validation in Dev Mode**
   - Validate schema on load
   - Log warnings for missing fields
   - Error on malformed data

4. **ID Conventions**
   - All IDs are `snake_case`
   - IDs are stable (never renamed without migration)

---

## Success Criteria

DataRegistry is complete when:

- [ ] All data types load without errors
- [ ] All lookup functions return correct data
- [ ] Invalid ID queries return null (not crash)
- [ ] Validation catches malformed data in dev mode
- [ ] Minimum viable data set is populated
- [ ] `data_loaded` signal fires on successful init
- [ ] Other systems can query DataRegistry from `_ready()`

---

## Next Steps After DataRegistry

Once DataRegistry is implemented and verified:

1. **GameContext (Tier 0.3)** — Can now reference DataRegistry
2. **Seeded RNG (Tier 0.4)** — Independent, can parallel
3. **EconomySystem (Tier 1.1)** — Uses DataRegistry for material definitions
4. **Entity Systems (Tier 2)** — All use DataRegistry for templates

---

*Document created: 2025-12-20*
*Source: Master GDD v2.0 + Section 41*
*Ready for Phase D: Code Generation (awaiting confirmation)*
