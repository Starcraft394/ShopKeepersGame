# Phase D Deliverables — DataRegistry (Tier 0.2)

**Generated:** 2025-12-20
**Status:** COMPLETE

---

## Summary

DataRegistry is the foundational autoload singleton that loads and caches all static game data. It is the SINGLE SOURCE OF TRUTH for game data lookups.

---

## Files Created

### Core System

| File | Purpose |
|------|---------|
| `Game/Core/DataRegistry.gd` | Main autoload singleton |

### Data Container Classes

| File | Purpose |
|------|---------|
| `Game/Core/DataTypes/ClassData.gd` | Hero class definitions |
| `Game/Core/DataTypes/RaceData.gd` | Hero race definitions |
| `Game/Core/DataTypes/ItemTemplate.gd` | Item base templates |
| `Game/Core/DataTypes/PassiveData.gd` | Passive ability definitions |
| `Game/Core/DataTypes/MonsterData.gd` | Monster templates |
| `Game/Core/DataTypes/StatusEffectData.gd` | Status effect definitions |
| `Game/Core/DataTypes/AbilityData.gd` | Active ability definitions |
| `Game/Core/DataTypes/RegionData.gd` | Region/world definitions |
| `Game/Core/DataTypes/FacilityData.gd` | Town facility definitions |

### Minimum Viable Data Set (JSON)

| File | ID | Description |
|------|-----|-------------|
| `Data/Classes/warrior.json` | `warrior` | Starter class |
| `Data/Races/human.json` | `human` | Starter race |
| `Data/Items/Templates/basic_sword.json` | `basic_sword` | Basic weapon |
| `Data/Monsters/goblin.json` | `goblin` | Basic enemy |
| `Data/StatusEffects/burn.json` | `burn` | DoT effect |
| `Data/StatusEffects/stun.json` | `stun` | Control effect |
| `Data/Abilities/basic_attack.json` | `basic_attack` | Universal ability |
| `Data/Regions/region_1.json` | `region_1` | Starting region |
| `Data/Facilities/blacksmith.json` | `blacksmith` | Starter facility |

---

## Godot Autoload Registration

To register DataRegistry as an autoload in Godot:

1. Open your Godot project
2. Go to **Project → Project Settings → Autoload**
3. Click the folder icon and browse to `res://Game/Core/DataRegistry.gd`
4. Set the **Node Name** to `DataRegistry`
5. Ensure **Enable** checkbox is checked
6. Click **Add**

The autoload should appear in the list as:
```
DataRegistry | res://Game/Core/DataRegistry.gd | Enabled
```

---

## Smoke Test Checklist

### Automated Test

Run in Godot console or call from any script:
```gdscript
DataRegistry.run_smoke_test()
```

Expected output:
```
=== DataRegistry Smoke Test ===
  PASS: Data loaded successfully
  PASS: Class 'warrior' exists
  PASS: Race 'human' exists
  PASS: Item template 'basic_sword' exists
  PASS: Monster 'goblin' exists
  PASS: Status effect 'burn' exists
  PASS: Status effect 'stun' exists
  PASS: Ability 'basic_attack' exists
  PASS: Region 'region_1' exists
  PASS: Facility 'blacksmith' exists
  PASS: All cross-references valid
=== Smoke Test PASSED ===
```

### Manual Verification

- [ ] Open Godot project (no script errors on load)
- [ ] Run the game once (press F5 or Play button)
- [ ] Check Output panel for `[DataRegistry] All data loaded successfully!`
- [ ] Check Output panel for registry summary with 1+ count for each type
- [ ] No red error messages in Output panel

### API Spot Checks

Try these in Godot console or a test script:
```gdscript
# Should return ClassData with display_name "Warrior"
print(DataRegistry.get_class_data("warrior").display_name)

# Should return true
print(DataRegistry.status_effect_exists("burn"))

# Should return 1 (one class loaded)
print(DataRegistry.get_load_stats().classes)
```

---

## Known Cross-Reference Warning

The `region_1.json` references `boss_id: "goblin_chief"` which does not exist yet in the minimum viable data set. The validation system will report this as a warning:

```
Region 'region_1' references missing boss 'goblin_chief'
```

This is expected and will resolve when the full monster data is populated.

---

## Public API Summary

### Lookup Functions (per type)
- `get_<type>(id)` — Returns data or null
- `get_all_<type>s()` — Returns array of all
- `<type>_exists(id)` — Returns bool

### Special Queries
- `get_templates_by_type(item_type)` — Filter items by type
- `get_templates_by_tier(tier)` — Filter items by tier
- `get_passives_by_category(category)` — Filter passives
- `get_monsters_by_region(region_id)` — Monsters in region
- `get_monsters_by_family(family)` — Monsters by family
- `get_abilities_by_class(class_id)` — Abilities for class
- `validate_status_effect(effect_id)` — Registry-first enforcement (GDD 41.7)

### Lifecycle
- `reload_all_data()` — Dev mode only, reloads from disk
- `is_data_loaded()` — Returns true if ready
- `get_load_stats()` — Returns Dictionary of counts

### Debug
- `print_registry_summary()` — Logs all counts
- `validate_all_data()` — Returns array of cross-ref errors
- `run_smoke_test()` — Full verification, returns bool

### Signals
- `data_loaded()` — Emitted when all data loads successfully
- `data_load_failed(error)` — Emitted on load failure
- `validation_error(type, id, message)` — Per-item validation issues

---

## Next System

**Ready for:** GameContext (Tier 0.3) or SeededRNG (Tier 0.4)

Per IMPLEMENTATION_ROADMAP.md, the next systems to implement are:
- **GameContext** — Central game state coordinator
- **SeededRNG** — Deterministic random number generation

---

*Phase D: DataRegistry — COMPLETE*
