# Canonical Tier 1 Facility Set

**Source:** Shops_And_Shadows_MASTER_GDD.md (Sections 5.3, 5.6)
**Purpose:** Define the standard T1 facility kit for Region 1 towns (and new town auto-construction).

---

## GDD Reference

### Early (Regions 1-3) Core Facilities
Per GDD Section 5.2:
- Blacksmith
- Leatherworker
- Woodsman
- Chef
- Alchemist

### Starter Town Kit (T1)
Per GDD Section 5.6 - auto-constructed in new towns:
- Training Hall (T1)
- Blacksmith (T1)
- Leatherworker (T1)
- Alchemist (T1)
- Storage
- Housing (T1)
- Shop (fed by facilities)

---

## Canonical T1 Facility Files

| Filename | ID | Type | Role |
|----------|-----|------|------|
| `blacksmith.json` | blacksmith | production | Weapons, heavy armor, metal tools |
| `leatherworker.json` | leatherworker | production | Light/medium armor, accessories |
| `woodsman.json` | woodsman | production | Bows, staves, wooden shields |
| `chef.json` | chef | production | Food items (healing, buffs) |
| `alchemist.json` | alchemist | production | Potions, flasks, elixirs |
| `training_hall.json` | training_hall | service | Hero training, class assignment |
| `storage.json` | storage | special | Material storage (global) |
| `housing.json` | housing | special | Hero rest, HP recovery |

**Total:** 8 facilities

---

## Schema Reference (FacilityData.gd)

Required fields for `is_valid()`:
- `id` (or `facility_id`) - must be non-empty
- `display_name` - must be non-empty

Standard fields:
```json
{
  "id": "facility_id_here",
  "display_name": "Display Name",
  "description": "Description text.",
  "facility_type": "production|service|defense|special",
  "max_tier": 1,
  "unlock_region": 1,
  "slots_per_tier": { "1": 2 },
  "upgrade_costs": { "2": { "resource_id": amount } },
  "services_per_tier": { "1": ["service_label"] },
  "produces_item_types": ["weapon", "armor", "consumable"],
  "input_resource_types": ["iron_scrap", "wood_bundle"],
  "allows_hero_assignment": true,
  "max_assigned_heroes": 1
}
```

---

## Production Facilities - Input/Output Summary

| Facility | Inputs | Outputs |
|----------|--------|---------|
| Blacksmith | iron_scrap, wood_bundle | weapon, armor |
| Leatherworker | herb_sprig, wood_bundle | armor, accessory |
| Woodsman | wood_bundle | weapon |
| Chef | herb_sprig, wood_bundle | consumable |
| Alchemist | herb_sprig | consumable |

---

## Copy Rules (For New Towns)

To reuse this facility set in a new town:

1. **Duplicate all 8 JSON files** to `Data/Facilities/` (or a town-specific subfolder if implemented)
2. **Change IDs** to include town prefix if needed (e.g., `tf_blacksmith` for Timberfall)
3. **Update services_per_tier** labels if town has different capabilities
4. **Adjust max_tier** as appropriate for the town's progression level

**Note:** The current FacilityData.gd schema does NOT include a `town_id` field. Town-facility associations must be managed separately (e.g., via RegionData.town_ids or a future TownData system).

---

## Validation Checklist

- [x] All files have valid JSON syntax
- [x] All files have `id` and `display_name` (passes is_valid())
- [x] All Dictionaries use string keys for tier numbers ("1", "2", etc.)
- [x] All arrays are proper arrays (even if empty)
- [x] DataRegistry loads from `Data/Facilities/` folder

---

*Generated: 2026-01-01*
*These files are reference-only documentation. Facilities are loaded by DataRegistry at runtime.*
