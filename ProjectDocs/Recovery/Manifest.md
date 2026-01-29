# Archive Recovery Manifest

**Generated:** 2026-01-01
**Purpose:** Extract source-of-truth design and data definitions from archives into a safe non-runtime location.

> **IMPORTANT:** These files are reference-only and are NOT loaded by the game.

---

## 1. Archive Roots Found

### _ARCHIVE_IMPLEMENTATION/ (10 backups)
| Folder | Date | Contents |
|--------|------|----------|
| M0_BACKUP_20251221_0117 | 2025-12-21 | Initial milestone backup |
| M0_3_GAMECONTEXT_BACKUP_20251221_0220 | 2025-12-21 | GameContext additions |
| M0_4_SEEDEDRNG_BACKUP_20251221_0328 | 2025-12-21 | SeededRNG additions |
| M1_COMBATCONTROLLER_BACKUP_20251226_0003 | 2025-12-26 | Combat system backup |
| M2_UI_BACKUP_20251226_0120 | 2025-12-26 | UI system backup |
| M2_1_HARDENING_BACKUP_20251226_0138 | 2025-12-26 | Hardening pass |
| M3_GRID_BACKUP_20251226_0200 | 2025-12-26 | Grid system backup |
| M3_1_GRIDSPACE_PATCH_BACKUP_20251226_0215 | 2025-12-26 | Grid patch |
| M4_CLASSKITS_BACKUP_20251226_0230 | 2025-12-26 | Class kits backup |
| PHASE_D_BACKUP_20251220_1200 | 2025-12-20 | Phase D backup |

### _ARCHIVE_INTEGRATION/ (5 backups)
| Folder | Date | Contents |
|--------|------|----------|
| 2025-12-15_1200 | 2025-12-15 | Original GDD sections (13-24), v1.3 full GDD |
| 2025-12-19 | 2025-12-19 | GDD sections 25-40, Master GDD |
| PHASE_3_BACKUP | 2025-12-20 | GDD sections 25-30 |
| PHASE_4_BACKUP | 2025-12-20 | GDD sections 31-40 |
| VALIDATION_PASS_BACKUP | 2025-12-20 | Validation pass |

---

## 2. Files Copied Per Category

| Category | Count | Notes |
|----------|-------|-------|
| **Design_Docs/** | 13 | Early GDD sections not in active repo |
| **Scripts_Reference/** | 3 | M0 baseline versions for comparison |
| **Data_JSON/** | 0 | All archive JSONs exist in active repo |

**Total Files Copied: 16**

---

## 3. File Copy Details

### Design_Docs/ (13 files)

| Source | Destination |
|--------|-------------|
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Sections13_14.md` | `Design_Docs/GDD_Sections13_14.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section15.md` | `Design_Docs/GDD_Section15.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section16.md` | `Design_Docs/GDD_Section16.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section17.md` | `Design_Docs/GDD_Section17.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section18.md` | `Design_Docs/GDD_Section18.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section19.md` | `Design_Docs/GDD_Section19.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Seciton20.md` | `Design_Docs/GDD_Seciton20.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section21.md` | `Design_Docs/GDD_Section21.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Secton22.md` | `Design_Docs/GDD_Secton22.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section23.md` | `Design_Docs/GDD_Section23.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_Section24_ClassKits.md` | `Design_Docs/GDD_Section24_ClassKits.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/Shops_And_Shadows_GDD_FULL_v1_3.md` | `Design_Docs/Shops_And_Shadows_GDD_FULL_v1_3.md` |
| `_ARCHIVE_INTEGRATION/2025-12-15_1200/GDD_FIX_NOTES.md` | `Design_Docs/GDD_FIX_NOTES.md` |

### Scripts_Reference/ (3 files)

| Source | Destination |
|--------|-------------|
| `_ARCHIVE_IMPLEMENTATION/M0_BACKUP_20251221_0117/Game/Core/DataRegistry.gd` | `Scripts_Reference/DataRegistry_M0.gd` |
| `_ARCHIVE_IMPLEMENTATION/M0_BACKUP_20251221_0117/Game/Core/DataTypes/ClassData.gd` | `Scripts_Reference/ClassData_M0.gd` |
| `_ARCHIVE_IMPLEMENTATION/M0_BACKUP_20251221_0117/Game/Core/DataTypes/RegionData.gd` | `Scripts_Reference/RegionData_M0.gd` |

### Data_JSON/ (0 files)

No files copied — all archive Data JSONs are duplicates of files already in active `Data/` folder.

---

## 4. Potentially Important but Missing

The following data types are referenced in GDD but have **no JSON files anywhere** (active or archive):

| Missing Data Type | Notes |
|-------------------|-------|
| **Town JSONs** | No `Data/Towns/` folder exists. TownData.gd does not exist. |
| **Dungeon JSONs** | No `Data/Dungeons/` folder exists. DungeonData.gd does not exist. |
| **Loot Table JSONs** | MonsterData references `loot_table_id` but no loot tables exist |
| **Hero JSONs** | No hero definition files found |
| **Event JSONs** | No dungeon event definitions found |
| **Room Template JSONs** | No room/encounter template files found |

---

## 5. Active Repo Coverage

### GDD Sections
| Section Range | Location |
|---------------|----------|
| Sections 1-12 | Integrated into `Shops_And_Shadows_MASTER_GDD.md` |
| Sections 13-14 | **Recovered** → `ProjectDocs/Recovery/Design_Docs/` |
| Sections 15-24 | **Recovered** → `ProjectDocs/Recovery/Design_Docs/` |
| Sections 25-41 | Active repo root (`GDD_Section25.md` through `GDD_Section41.md`) |

### Data Folders
| Folder | Status |
|--------|--------|
| Data/Abilities/ | ✅ Active (7 files) |
| Data/Classes/ | ✅ Active (3 files) |
| Data/Facilities/ | ✅ Active (1 file) |
| Data/Items/Templates/ | ✅ Active (1 file) |
| Data/Monsters/ | ✅ Active (32 files) |
| Data/Passives/ | ✅ Active (4 files) |
| Data/Races/ | ✅ Active (1 file) |
| Data/Regions/ | ✅ Active (1 file) |
| Data/StatusEffects/ | ✅ Active (3 files) |
| Data/Towns/ | ❌ Missing |
| Data/Dungeons/ | ❌ Missing |

---

## 6. Summary

- **Archives can now be safely ignored** for daily development
- All unique design documents have been recovered to `ProjectDocs/Recovery/Design_Docs/`
- Early script versions preserved in `ProjectDocs/Recovery/Scripts_Reference/` for reference
- **No Town or Dungeon data exists anywhere** — must be created from GDD specifications
- Active repo now contains complete GDD coverage (Sections 1-41)

---

*These files are reference-only and are not loaded by the game.*
