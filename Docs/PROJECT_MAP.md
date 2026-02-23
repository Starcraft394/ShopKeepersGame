# Project Map

> Directory index for agent quick-reference. Maintained by Repo Auditor.
> Last updated: 2026-02-22

---

## Quick Reference

| Looking for...            | Path                                                                         |
|---------------------------|------------------------------------------------------------------------------ |
| Item templates            | `Data/Items/Templates/` (430 files)                                          |
| Monster data              | `Data/Monsters/` (112 JSON files)                                            |
| Class definitions         | `Data/Classes/` (15 files)                                                   |
| Abilities                 | `Data/Abilities/` (80 files: 62 hero + 18 monster)                           |
| Passives                  | `Data/Passives/` (66 files)                                                  |
| Status effects            | `Data/StatusEffects/` (13 files)                                             |
| Facility configs          | `Data/Facilities/` (22 files)                                                |
| Crafting recipes          | `Data/Facilities/*.json` (embedded in facility files, look for `is_craft: true`) |
| Mixing recipes            | `Data/Recipes/` (14 files)                                                   |
| Loot tables               | `Data/LootTables/` (38 files)                                                |
| Region definitions        | `Data/Regions/` (7 files)                                                    |
| Race definitions          | `Data/Races/` (9 files)                                                      |
| Dungeon definitions       | `Data/Dungeons/` (7 files)                                                   |
| Event definitions         | `Data/Events/Definitions/` (70 files)                                        |
| Event tables              | `Data/Events/` (7 region-combined JSON at top level)                         |
| Campaign dialogs          | `Data/Campaign/` (7 region dialog files)                                     |
| Tutorials                 | `Data/Tutorials/` (14 files)                                                 |
| Town configs              | `Data/Towns/` (7 files)                                                      |
| Shop pools                | `Data/Shops/Pools/` (8 files)                                                |
| Affixes                   | `Data/Affixes/` (1 file)                                                     |
| Autoloads (singletons)    | `Game/Core/` (DataRegistry, GameContext, SeededRNG, DebugLog, UIAudio, RegionTheme) |
| Core systems              | `Game/Core/` (TutorialOverlay, CampaignDialog, BackgroundManager)            |
| Data type classes         | `Game/Core/DataTypes/` (16 GDScript classes)                                 |
| Combat system             | `Game/Combat/` (8 GDScript files)                                            |
| UI scenes                 | `Game/UI/` (7 subdirectories, 24 files total)                                |
| Boot/routing              | `Game/Boot/` (game_boot.gd + .tscn)                                         |
| Art packs (source)        | `Assets/_ArtPacks/` (75+ packs, ~14,800 files)                              |
| Integrated icons          | `Assets/Icons/` (46 PNGs across 4 subdirectories)                            |
| UI art assets             | `Assets/UI/` (CraftPix + Kenney, ~2,682 files)                              |
| Audio / BGM               | `Assets/Audio/BGM/` (21 tracks: 7 region + 3 scene + 2 combat + 2 stingers + 7 source) |
| Audio / SFX               | `Assets/Audio/SFX/` (27 sound effects across 5 categories)                   |
| Audio / UI                | `Assets/Audio/UI/Kenney/` (Kenney UI audio pack)                             |
| Theme files               | `Themes/` (game_theme.tres + CraftPix/ with 16 .tres files)                 |
| Tests                     | `DevTools/test_ability_execution_v1.gd` (178 unit tests + 22 validation = 200 total) |
| Test runner               | `DevTools/run_headless.bat`                                                  |
| Agent definitions         | `.claude/agents/` (12 agent prompts + README)                                |
| Skills                    | `.claude/skills/godot-gamedev/` (project-relevant skill)                     |
| Reference docs            | `Docs/` (33 .md + 1 .html + subdirectories)                                 |
| Project docs              | `ProjectDocs/` (Recovery archive + World specs)                              |
| Master GDD                | `Shops_And_Shadows_MASTER_GDD.md` (root)                                    |
| Project status            | `PROJECT_STATUS.md` (root)                                                   |

---

## Directory Tree (depth 2)

```
ShopKeepers Game/
|-- project.godot
|-- main.gd / main.tscn
|-- CLAUDE.md
|-- PROJECT_STATUS.md
|-- MVP_Scope.md
|-- Shops_And_Shadows_MASTER_GDD.md
|
|-- Assets/
|   |-- _ArtPacks/            75+ art packs (~14,800 files)
|   |   |-- AlchemyItems/     Axes/  Berries/  Bows/  Bracers/
|   |   |-- Avatars_*/        12+ avatar packs (races, classes)
|   |   |-- BuffIcons/        BuffSkills/  Curses/
|   |   |-- CraftingMaterials/  CraftingMaterials2/
|   |   |-- Cuirass/  Daggers/  Farming/  Fishing/  Food/
|   |   |-- FruitsVegetables/  Gems/  Helmets/  Herbs/
|   |   |-- Ingredients/  LootDrops/  Loot_*/
|   |   |-- Maces/  MagicArtifacts/  MagicBooks/  MeatSkins/
|   |   |-- Mining/  Monsters_*/  Mushrooms/  Potions/
|   |   |-- Rings/  RPGThings/  Runes/  Sabatons/
|   |   |-- ShieldsAmulets/  Sigils/  Skills_*/  Spears/
|   |   |-- Swords/  Treasure/  Trousers/
|   |-- _Downloads/            3 files (staging area)
|   |-- Audio/
|   |   |-- BGM/               21 tracks total
|   |   |   |-- Region/        7 region BGM (.mp3) + 3 scene BGM (.wav: town, shop, camp)
|   |   |   |-- Combat/        2 combat BGM (.wav: normal, boss)
|   |   |   |-- Stingers/      2 stingers (.wav: victory, defeat)
|   |   |   |-- *.mp3          7 source/candidate tracks
|   |   |-- SFX/               27 sound effects (.mp3)
|   |   |   |-- Combat/Magic/  10 spell SFX
|   |   |   |-- Combat/Status/ 7 status SFX
|   |   |   |-- Events/        4 event SFX
|   |   |   |-- Inventory/     1 inventory SFX
|   |   |   |-- Stingers/      1 stinger SFX (level_up)
|   |   |   |-- Town/          1 town SFX
|   |   |-- UI/
|   |   |   |-- Kenney/        Kenney UI audio pack (clicks, switches, rollovers)
|   |-- Icons/
|   |   |-- Buffs/             3 PNGs
|   |   |-- Facilities/        10 PNGs
|   |   |-- Items/             22 PNGs
|   |   |-- Status/            11 PNGs
|   |-- UI/
|   |   |-- CraftPix/          55 files (RPG UI kit)
|   |   |-- Kenney/            2,627 files (UI pack)
|
|-- Data/
|   |-- Abilities/             80 files (62 hero + 18 monster)
|   |-- Affixes/               1 file
|   |-- Campaign/              7 files (campaign_dialog_r1-r7.json)
|   |-- Classes/               15 files
|   |-- Dungeons/              7 files
|   |-- Events/
|   |   |-- Definitions/       70 files
|   |   |-- et_region*.json    7 region event tables
|   |-- Facilities/            22 files
|   |-- Items/
|   |   |-- Templates/         430 files
|   |-- LootTables/            38 files
|   |-- Monsters/              112 JSON files
|   |-- Passives/              66 files
|   |-- Races/                 9 files
|   |-- Recipes/               14 files
|   |-- Regions/               7 files
|   |-- Shops/
|   |   |-- Pools/             8 files
|   |-- StatusEffects/         13 files
|   |-- Towns/                 7 files
|   |-- Tutorials/             14 files
|
|-- DevTools/                  30 files
|   |-- test_ability_execution_v1.gd   (main test suite, 178 unit tests)
|   |-- test_playtest_v1.gd            (playtest scenarios, 22 validation tests)
|   |-- run_headless.bat               (test runner)
|   |-- run_headless.ps1               (PowerShell test runner)
|   |-- run_tests_headless.gd          (headless bootstrap)
|   |-- convert_icons.gd              (icon conversion utility)
|   |-- generate_items_html_data.py    (HTML data generator)
|   |-- generate_placeholder_icons.gd  (placeholder icon generator)
|   |-- generate_backgrounds.py        (background image generator)
|   |-- gameicons_search.gd           (game-icons.net search)
|   |-- gameicons_apply_batch.gd      (batch icon applier)
|   |-- select_game_icons.gd          (icon selector)
|   |-- recolour_avatars.py           (avatar recolor script)
|   |-- recolour_monsters.py          (monster recolor script)
|   |-- recolour_items.py             (item icon recolor script, 51 jobs)
|   |-- build_icon_ledger.py          (icon ledger generator)
|   |-- build_needs_icons.py          (missing icons report)
|   |-- copy_audio.ps1                (audio copy utility)
|   |-- pixellab_prompts.json         (PixelLab AI prompt data)
|   |-- Godot_v4.5.1-stable_win64.exe (local Godot binary)
|
|-- Docs/
|   |-- Art/                   2 files (art direction, UI theme rules)
|   |-- Attribution/           5 files (licenses, credits)
|   |-- icon_descriptions/     46 JSON files (per-pack icon descriptions)
|   |-- Icons/                 2 files (icon library location, status mapping)
|   |-- *.md                   33 reference documents
|   |-- item_icon_reference.html  (visual HTML gallery)
|
|-- Game/
|   |-- Boot/                  3 files (game_boot.gd, .tscn, .uid)
|   |-- Combat/                16 files (8 .gd + 8 .uid)
|   |-- Core/                  18 files (9 .gd + 9 .uid)
|   |   |-- DataTypes/         32 files (16 .gd + 16 .uid)
|   |   |-- *.gd               9 scripts (6 autoloads + 3 systems)
|   |-- UI/
|   |   |-- Combat/            3 files (.gd, .tscn, .uid)
|   |   |-- Demos/             3 files (CraftPix demo scenes)
|   |   |-- Dungeon/           3 files (DungeonCampScene .gd, .tscn, .uid)
|   |   |-- Rooms/             3 files (RoomEventScene .gd, .tscn, .uid)
|   |   |-- Shop/              3 files (.gd, .tscn, .uid)
|   |   |-- Storage/           3 files (.gd, .tscn, .uid)
|   |   |-- Town/              3 files (.gd, .tscn, .uid)
|   |   |-- TownHub/           3 files (.gd, .tscn, .uid)
|   |-- __Data_ARCHIVED_OBSOLETE/  17 files (legacy)
|   |-- AI/  Dungeons/  Economy/  Events/  Items/  Save/  State/  Town/  Utils/
|       (empty placeholder directories for future systems)
|
|-- MVP/                       3 files (scope, milestones, exit criteria)
|
|-- ProjectDocs/
|   |-- Recovery/
|   |   |-- Data_JSON/         0 files
|   |   |-- Design_Docs/       13 files
|   |   |-- Scripts_Reference/ 4 files
|   |   |-- Manifest.md
|   |-- World/
|   |   |-- CANONICAL_FACILITIES_T1.md
|   |   |-- LOOT_TABLES_SPEC_DRAFT.md
|   |   |-- REGION_TOWN_DUNGEON_OVERVIEW.md
|   |   |-- REGION_TOWN_INDEX.md
|   |   |-- REGION1_TOWNS_AND_DUNGEONS.md
|   |   |-- Reference_JSON/
|
|-- Themes/
|   |-- game_theme.tres
|   |-- CraftPix/              16 .tres files + SLICING_REFERENCE.md
|
|-- .claude/
|   |-- agents/                12 agent prompts + README
|   |-- plans/
|   |-- skills/
|   |   |-- godot-gamedev/     Project-relevant skill (combat, data, UI patterns)
|   |-- settings.local.json
|
|-- Archive/                   Legacy GDD sections, implementation planning
|-- _ARCHIVE_IMPLEMENTATION/   Empty (archived)
|-- _ARCHIVE_INTEGRATION/      Empty (archived)
|-- Tests/                     Empty (tests live in DevTools/)
|-- UI/                        Empty (UI scenes live in Game/UI/)
```

---

## Key Files

### Project Root
| File | Purpose |
|------|---------|
| `project.godot` | Godot project config (autoloads, input maps, display settings) |
| `main.gd` / `main.tscn` | Entry point scene |
| `CLAUDE.md` | Agent instructions and project guide |
| `PROJECT_STATUS.md` | Current project status report |
| `Shops_And_Shadows_MASTER_GDD.md` | Master Game Design Document (40 sections) |
| `MVP_Scope.md` | MVP vertical slice definition |

### Autoloads (Game/Core/)
| File | Singleton | Purpose |
|------|-----------|---------|
| `Game/Core/DataRegistry.gd` | DataRegistry | Loads all JSON data at startup, provides lookup methods |
| `Game/Core/GameContext.gd` | GameContext | Game state, save/load, phase management, hero roster |
| `Game/Core/SeededRNG.gd` | SeededRNG | Deterministic random number generation |
| `Game/Core/DebugLog.gd` | DebugLog | Logging utility |
| `Game/Core/UIAudio.gd` | UIAudio | UI sound effects and BGM playback |
| `Game/Core/RegionTheme.gd` | RegionTheme | Region-based theming (colors, backgrounds) |

### Core Systems (Game/Core/)
| File | Purpose |
|------|---------|
| `Game/Core/TutorialOverlay.gd` | Tutorial overlay UI (CanvasLayer layer 10, contextual tutorials) |
| `Game/Core/CampaignDialog.gd` | Campaign dialog system (static query + overlay factory) |
| `Game/Core/BackgroundManager.gd` | Background image management |

### Data Types (Game/Core/DataTypes/)
| File | Class | Purpose |
|------|-------|---------|
| `AbilityData.gd` | AbilityData | Ability definition wrapper |
| `CampaignDialogData.gd` | CampaignDialogData | Campaign dialog data (from_dict factory) |
| `ClassData.gd` | ClassData | Hero class definitions |
| `DungeonData.gd` | DungeonData | Dungeon configuration |
| `EventData.gd` | EventData | Event definition wrapper (v2 outcomes) |
| `EventTableData.gd` | EventTableData | Event table/weighting |
| `FacilityData.gd` | FacilityData | Town facility configs |
| `ItemInstance.gd` | ItemInstance | Runtime item instance (with affixes) |
| `ItemTemplate.gd` | ItemTemplate | Static item template from JSON |
| `LootTableData.gd` | LootTableData | Loot table definition |
| `MonsterData.gd` | MonsterData | Monster stat block |
| `PassiveData.gd` | PassiveData | Passive ability definition |
| `RaceData.gd` | RaceData | Playable race definition |
| `RegionData.gd` | RegionData | Region world data |
| `StatusEffectData.gd` | StatusEffectData | Status effect definition |
| `TownData.gd` | TownData | Town configuration |

### Combat (Game/Combat/)
| File | Purpose |
|------|---------|
| `CombatUnit.gd` | Runtime unit in combat (stats, abilities, status) |
| `CombatAction.gd` | Action resolution (damage, healing, status application) |
| `CombatController.gd` | Combat flow orchestration |
| `CombatResult.gd` | Combat outcome data |
| `TurnQueue.gd` | Turn order management |
| `StatusRuntime.gd` | Active status effect tracking |
| `TargetingPolicy.gd` | Target selection logic |
| `FormationAssigner.gd` | Row/formation placement |

### Boot & Routing
| File | Purpose |
|------|---------|
| `Game/Boot/game_boot.gd` | Scene router (routes by GameContext.GamePhase) |
| `Game/Boot/game_boot.tscn` | Boot scene |

### Testing
| File | Purpose |
|------|---------|
| `DevTools/test_ability_execution_v1.gd` | Main test suite (178 unit tests) |
| `DevTools/test_playtest_v1.gd` | Playtest scenario tests (22 validation tests) |
| `DevTools/run_headless.bat` | Headless test runner (CI entry point) |
| `DevTools/run_headless.ps1` | PowerShell test runner |
| `DevTools/run_tests_headless.gd` | Headless bootstrap script |

### Reference Documents
| File | Purpose |
|------|---------|
| `Docs/ITEM_MANIFEST.md` | Auto-generated item inventory (430 items) |
| `Docs/MONSTER_MANIFEST.md` | Auto-generated monster inventory (112 monsters) |
| `Docs/BALANCE_REFERENCE.md` | Auto-generated balance data reference |
| `Docs/BALANCE_TIER_SYSTEM.md` | Tier system balance documentation |
| `Docs/TIER_SYSTEM_SPEC.md` | Tier system specification |
| `Docs/ITEM_ICON_LEDGER.md` | Auto-generated icon assignment ledger |
| `Docs/CAMPAIGN_REFERENCE.md` | Campaign dialog system technical reference |
| `Docs/CAMPAIGN_STORY.md` | Campaign narrative prose |
| `Docs/SOUND_MASTER.md` | Audio asset master reference |
| `Docs/GAME_GUIDE.md` | Player-facing game guide |
| `Docs/LORE_REFERENCE.md` | Complete world lore summary |
| `Docs/item_icon_reference.html` | Visual HTML gallery of all item icons |

---

## File Counts

### Data/ (868 JSON files total)
| Directory | Files | Description |
|-----------|------:|-------------|
| `Data/Items/Templates/` | 430 | Item template definitions |
| `Data/Monsters/` | 112 | Monster stat blocks |
| `Data/Abilities/` | 80 | Active abilities (62 hero + 18 monster) |
| `Data/Events/Definitions/` | 70 | Event scripts (v2 weighted outcomes) |
| `Data/Passives/` | 66 | Passive abilities |
| `Data/LootTables/` | 38 | Loot drop tables |
| `Data/Facilities/` | 22 | Town facility configs |
| `Data/Classes/` | 15 | Hero class definitions |
| `Data/Recipes/` | 14 | Mixing/crafting recipes |
| `Data/Tutorials/` | 14 | Tutorial definition files |
| `Data/StatusEffects/` | 13 | Status effect definitions |
| `Data/Races/` | 9 | Playable race definitions |
| `Data/Shops/Pools/` | 8 | Shop inventory pools |
| `Data/Regions/` | 7 | Region world data |
| `Data/Dungeons/` | 7 | Dungeon configurations |
| `Data/Events/` (top-level) | 7 | Region event tables |
| `Data/Towns/` | 7 | Town configurations |
| `Data/Campaign/` | 7 | Campaign dialog files (r1-r7) |
| `Data/Affixes/` | 1 | Item affix definitions |

### Game/ (50 .gd files, 10 .tscn files)
| Directory | .gd | .tscn | Description |
|-----------|----:|------:|-------------|
| `Game/Core/` | 9 | 0 | Autoloads, overlays, and systems |
| `Game/Core/DataTypes/` | 16 | 0 | Data wrapper classes |
| `Game/Combat/` | 8 | 0 | Combat system scripts |
| `Game/Boot/` | 1 | 1 | Boot scene and router |
| `Game/UI/Combat/` | 1 | 1 | Combat UI |
| `Game/UI/Demos/` | 0 | 3 | Demo scenes |
| `Game/UI/Dungeon/` | 1 | 1 | Dungeon camp UI |
| `Game/UI/Rooms/` | 1 | 1 | Room event UI |
| `Game/UI/Shop/` | 1 | 1 | Shop UI |
| `Game/UI/Storage/` | 1 | 1 | Storage/stash UI |
| `Game/UI/Town/` | 1 | 1 | Town UI |
| `Game/UI/TownHub/` | 1 | 1 | Town hub UI |

### Assets/
| Directory | Files | Description |
|-----------|------:|-------------|
| `Assets/_ArtPacks/` | ~14,800 | 75+ source art packs (PNGs + .import) |
| `Assets/UI/Kenney/` | 2,627 | Kenney UI pack |
| `Assets/UI/CraftPix/` | 55 | CraftPix RPG UI kit |
| `Assets/Audio/BGM/` | 21 | Background music tracks (7 region + 3 scene + 2 combat + 2 stingers + 7 source) |
| `Assets/Audio/SFX/` | 27 | Sound effects (combat, events, inventory, town) |
| `Assets/Audio/UI/Kenney/` | ~80 | Kenney UI audio (clicks, switches, rollovers) |
| `Assets/Icons/` | 46 | Integrated game icons (3 Buffs, 10 Facilities, 22 Items, 11 Status) |

---

## Reference Documents

### Docs/ (top-level)
| File | Description |
|------|-------------|
| `BACKGROUNDS_MASTER.md` | Unified background system specification |
| `BALANCE_REFERENCE.md` | Auto-generated balance data for analysis |
| `BALANCE_TIER_SYSTEM.md` | Tier system balance documentation |
| `CAMPAIGN_REFERENCE.md` | Campaign dialog system technical reference |
| `CAMPAIGN_STORY.md` | Campaign narrative prose (7 regions) |
| `CANON_NOTES_AND_SUGGESTIONS.md` | Working lore suggestions and conflict resolution |
| `CLASS_PASSIVES_GDD_EXTRACT.md` | Class passives rules extracted from GDD |
| `CLASS_PASSIVES_IMPLEMENTATION_PLAN.md` | Implementation plan for class passives v1 |
| `CLASS_PASSIVES_TEST_SCRIPT.md` | Manual test script for class passives |
| `DEVELOPMENT_STATUS.md` | Development status tracker |
| `GAME_GUIDE.md` | Player-facing game guide |
| `HERO_SYSTEM_GDD_EXTRACT.md` | Hero system rules extracted from GDD |
| `ITEM_AUDIT.md` | Item data audit report |
| `ITEM_ICON_LEDGER.md` | Auto-generated icon assignment ledger |
| `ITEM_ICON_UPDATE_PLAN.md` | Icon update plan |
| `ITEM_MANIFEST.md` | Auto-generated item inventory (430 items) |
| `ITEMS_NEEDING_ICONS.md` | Items missing icon assignments |
| `LORE_REFERENCE.md` | Complete world lore and narrative reference |
| `MONSTER_MANIFEST.md` | Auto-generated monster inventory (112 monsters) |
| `PIXELLAB_REFERENCE.md` | PixelLab AI art generation reference |
| `PROJECT_MAP.md` | This file -- project directory index |
| `RACE_PASSIVES_TEST_SCRIPT.md` | Manual test script for race passives |
| `RECIPE_AUDIT.md` | Recipe data audit report |
| `RECIPE_AUDIT_WITH_INGREDIENTS.md` | Recipe audit with ingredient details |
| `REGION1_FACILITIES_MASTER.md` | Region 1 facilities single source of truth |
| `REGION1_GDD_IMPLEMENTATION_AUDIT.md` | Audit of GDD vs implementation for Region 1 |
| `REGION1_GDD_RULES_EXTRACT.md` | Region 1 canonical rules from GDD |
| `REGION1_IMPLEMENTATION_INVENTORY.md` | Region 1 implementation artifact catalog |
| `REGION1_TEST_CHECKLIST.md` | Region 1 manual test checklist |
| `ROW_SYSTEM_SMOKE_TEST.md` | 3-row formation system verification checklist |
| `SHOPS_AND_SHADOWS_CANON_OVERVIEW.md` | Locked canon: metaphysical, political, timeline rules |
| `SOUND_MASTER.md` | Audio asset master reference |
| `TIER_SYSTEM_SPEC.md` | Tier system specification |
| `item_icon_reference.html` | Visual HTML gallery of all item icons |

### Docs/Art/
| File | Description |
|------|-------------|
| `ART_DIRECTION_MASTER.md` | Locked art direction authority brief |
| `UI_THEME_RULES.md` | CraftPix-based UI theme standards |

### Docs/Attribution/
| File | Description |
|------|-------------|
| `ATTRIBUTION.md` | Third-party asset attribution |
| `GAME_ICONS_ATTRIBUTION.md` | Per-icon game-icons.net attribution |
| `LICENSES_README.md` | License overview |
| `Kenney_UI_Audio_License.txt` | Kenney UI audio license |
| `Kenney_UI_Pack_License.txt` | Kenney UI pack license |

### Docs/Icons/
| File | Description |
|------|-------------|
| `GAME_ICONS_LIBRARY_LOCATION.md` | Location of game-icons.net SVG bundle |
| `STATUS_ICON_MAPPING.md` | Status/buff icon selection mapping |

### Docs/icon_descriptions/
46 JSON files containing per-pack AI-generated icon visual descriptions (one per art pack).

### ProjectDocs/
| File | Description |
|------|-------------|
| `Recovery/Manifest.md` | Archive recovery manifest |
| `Recovery/Design_Docs/` | 13 recovered design documents |
| `Recovery/Scripts_Reference/` | 4 recovered script references |
| `World/CANONICAL_FACILITIES_T1.md` | Canonical Tier 1 facility set from GDD |
| `World/LOOT_TABLES_SPEC_DRAFT.md` | Loot tables specification (not implemented) |
| `World/REGION_TOWN_DUNGEON_OVERVIEW.md` | Region/town/dungeon overview |
| `World/REGION_TOWN_INDEX.md` | Region and town index |
| `World/REGION1_TOWNS_AND_DUNGEONS.md` | Region 1 towns and dungeons detail |

### Themes/
| File | Description |
|------|-------------|
| `Themes/game_theme.tres` | Root game theme |
| `Themes/CraftPix/SLICING_REFERENCE.md` | 9-slice source reference for CraftPix UI |
| `Themes/CraftPix/*.tres` | 16 theme resource files (buttons, panels, slots) |

### Root-level Documents
| File | Description |
|------|-------------|
| `CLAUDE.md` | Agent instructions and project guide |
| `PROJECT_STATUS.md` | Current project status report |
| `MVP_Scope.md` | MVP vertical slice definition |
| `Shops_And_Shadows_MASTER_GDD.md` | Master GDD (40 sections) |

### .claude/agents/
| File | Purpose |
|------|---------|
| `repo-auditor.md` | Scan repo, assess state, propose next milestone |
| `implementer.md` | Test-driven implementation, minimal diffs |
| `ui-refiner.md` | Visual cleanup, theme consistency |
| `data-curator.md` | JSON validation, content extension |
| `item-curator.md` | Item data curation and management |
| `monster-curator.md` | Monster data curation and management |
| `art-director.md` | Art asset tracking, integration, consistency |
| `icon-mapper.md` | Icon assignment and mapping |
| `balancer.md` | Game balance analysis and tuning |
| `story-architect.md` | Narrative design and quest writing |
| `gameplay-guide.md` | Gameplay documentation and player guidance |
| `sound-director.md` | Audio asset management and sound design |
