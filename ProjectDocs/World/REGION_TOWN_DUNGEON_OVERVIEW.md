# Region, Town & Dungeon Overview

**Generated:** 2026-01-01
**Purpose:** Document all world definitions found in the codebase to prevent "plan loss" during development.
**Status:** Reference document for planning - NOT wired into DataRegistry yet.

---

## Implementation Status Matrix

| Concept | Active Code (.gd)? | Active Data Folder? | In Archive Only? | Missing Entirely? |
|---------|-------------------|---------------------|------------------|-------------------|
| **RegionData** | YES | YES (`Data/Regions/`) | NO | NO |
| **TownData** | NO | NO | NO | YES (schema in GDD only) |
| **DungeonData** | NO | NO | NO | YES (schema in GDD only) |
| **Region loader** | YES (DataRegistry) | - | - | - |
| **Town loader** | NO | - | - | YES |
| **Dungeon loader** | NO | - | - | YES |

---

## Region 1 - Forest Haven (Implemented)

**Source:** `Data/Regions/region_1.json`

```json
{
  "id": "region_1",
  "display_name": "Forest Haven",
  "description": "A lush forest region with low-level threats. The starting area for new adventurers.",
  "region_index": 1,
  "dungeon_floor_count": 1,
  "monster_families": ["beast"]
}
```

### RegionData.gd Schema (Active)

The following fields are supported by `Game/Core/DataTypes/RegionData.gd`:

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| region_id | String | "" | Core identity |
| display_name | String | "" | UI display |
| description | String | "" | Flavor text |
| region_index | int | 1 | 1-7 |
| requires_region_id | String | "" | Unlock gate |
| town_ids | Array[String] | [] | **NOT POPULATED YET** |
| dungeon_floor_count | int | 4 | |
| boss_id | String | "" | |
| monster_families | Array[String] | [] | |
| elite_monster_ids | Array[String] | [] | |
| resource_types | Array[String] | [] | |
| passive_pool_ids | Array[String] | [] | |
| corruption_level | String | "none" | |
| max_boss_charges | int | 10 | |
| charges_per_floor | int | 1 | |
| map_icon_path | String | "" | |
| background_path | String | "" | |

---

## Town Definitions (From GDD - NOT Implemented)

**Source:** `GDD_Section16.md`, `MVP_Scope.md`

### Region 1 Towns

| Town ID (Proposed) | Display Name | Type | Function |
|--------------------|--------------|------|----------|
| `town_thornhaven` | Thornhaven | Starter Town | Tutorial, Race unlock (Human/Elf/Dwarf), Starter classes: Warrior, Ranger, Mage, Rogue, Acolyte |

**MVP Scope Note:** MVP uses only **Thornhaven** with Blacksmith T1.

### Proposed Town Schema (From GDD Section 32)

```
Town {
  town_id: string,
  region_id: string,
  display_name: string,
  town_type: "race_unlock" | "class_unlock" | "starter" | "special",
  facility_ids: string[],
  dungeon_id: string,
  is_unlocked: bool
}
```

### All Regions Town Summary (From GDD_Section16.md)

| Region | Town A (Race Unlock) | Town B (Class Unlock) |
|--------|---------------------|----------------------|
| 1 - Forest Haven | Thornhaven (Human/Elf/Dwarf + Warrior/Ranger/Mage/Rogue/Acolyte) | *(consolidated into single town)* |
| 2 - Fungalmire | SproutRest (Mossfolk) | Magic Caps Rest (Sporeweaver/Grove Guardian) |
| 3 - Sunken Strand | Shelldrift Harbor (Tidelings) | Mistwhisper Shoals (Tempest Caller/Harpooner) |
| 4 - Ashen Horizons | TBD (Dragonkin) | TBD (Fire/Sand classes) |
| 5 - Starfall Expanse | TBD (Starborn/Crystalfolk) | TBD (Chronomancer/Riftblade) |
| 6 - Necropolis | TBD (Undead) | TBD (Dark Channeler/Lich) |
| 7 - Final Realm | Special/Single Town | No unlocks |

---

## Dungeon Definitions (From GDD - NOT Implemented)

**Source:** `GDD_Section32.md`

### Dungeon Schema (From GDD)

```
Dungeon {
  dungeon_id: string,
  region_id: string,
  town_id: string,
  max_floor: int,
  completed_floors: int
}

DungeonFloor {
  floor_id: string,
  floor_index: int,
  room_sequence: Room[],
  resource_pools: Resource[],
  enemy_table: Enemy[],
  is_completed: bool
}

Room {
  room_id: string,
  room_type: string,  // "combat", "resource", "event", "rest"
  encounter_data: object
}
```

### MVP Dungeon (Region 1)

- **Dungeon:** Forest Haven Dungeon
- **Floors:** 1 (MVP), up to 4 (full game per RegionData default)
- **Room count:** 4-6 rooms per floor
- **Boss:** Floor 1 Boss (simple, telegraphed mechanic)

---

## Boss Definitions (From GDD)

| Region | Boss Name | Type |
|--------|-----------|------|
| 1 | The Thorn-Ent | Region Boss |
| 2 | The Spiral Mycelium | Region Boss |
| 3 | The Tide Sovereign | Region Boss |
| 4 | The Cinder Monarch | Region Boss |
| 5 | The Shattered Oracle | Region Boss |
| 6 | The Ossuary King | Region Boss |
| 7 | The Prime Corruptor | Final Boss |

---

## Monster Families by Region (From GDD)

| Region | Monster Families |
|--------|-----------------|
| 1 - Forest Haven | Forest Wolves, Vinebound Horrors, Spriggan Tricksters, Moss Trolls, Ancient Root Golems |
| 2 - Fungalmire | Fungal Shamblers, Spore Wisps, Rotcap Brutes, Hallucinogenic Myconids, Bloom Giants |
| 3 - Sunken Strand | Tidewalkers, Storm Wisps, Crustacean Brutes, Drowned Spirits, Mistborn Leviathans |
| 4 - Ashen Horizons | Ember Drakes, Lava Golems, Ash Wraiths, Scorpion Titans, Fire Djinn |
| 5 - Starfall Expanse | Reality Phantoms, Crystal Wraiths, Starfall Beasts, Time-Lost Knights |
| 6 - Necropolis | Bone Legionnaires, Ghoul Stalkers, Wraith Choirs, Death Knights, Gravefiends |

---

## Regional Boons (From GDD)

| Region | Combat Boon | Gathering Boon |
|--------|-------------|----------------|
| 1 | +X% Max HP | +X% Wood yield |
| 2 | +X% Regeneration | +X% Herb yield |
| 3 | +X% Dodge/Evasion | +X% Fishing yield |
| 4 | +X% Fire Resistance | +X% Ore quality |
| 5 | +X% Mana | +X% Crystal yield |
| 6 | +X% Corruption Resistance | +X% Soul resources |
| 7 | +X% All Stats | None |

---

## Implementation Next Steps

### Phase 1: Data Structures (Required)
1. Create `Game/Core/DataTypes/TownData.gd`
2. Create `Game/Core/DataTypes/DungeonData.gd`
3. Add town/dungeon loaders to `DataRegistry.gd`

### Phase 2: Data Files (Required)
1. Create `Data/Towns/` folder
2. Create `Data/Towns/town_thornhaven.json`
3. Create `Data/Dungeons/` folder
4. Create `Data/Dungeons/dungeon_thornhaven.json`

### Phase 3: Wire Up (Required)
1. Update `region_1.json` to include `town_ids: ["town_thornhaven"]`
2. Link dungeons to towns in town JSON

---

## Source Files Used

### Active (Non-Archive)
- `Data/Regions/region_1.json`
- `Game/Core/DataTypes/RegionData.gd`
- `Game/Core/DataRegistry.gd`
- `Game/Core/GameContext.gd`
- `GDD_Section16.md`
- `GDD_Section32.md`
- `MVP_Scope.md`

### Archive (Reference Only)
- `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section16.md`

---

## Notes

- **TownData.gd does not exist** - Must be created before towns can be loaded
- **DungeonData.gd does not exist** - Must be created before dungeons can be loaded
- **town_ids in region_1.json is empty** - Must be populated after TownData system exists
- **32 monsters exist** for Region 1 (Tier 1-3, standard/elite/boss)
- **GDD is authoritative** for world structure until data files are created
