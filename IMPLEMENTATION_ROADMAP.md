# Shops & Shadows — Implementation Roadmap
## Godot 4.x Module Implementation Order

---

## Document Purpose

This roadmap defines the order in which game systems should be implemented, based on:
- Dependency analysis (lowest dependency first)
- GDD section references
- Godot node requirements
- Risk identification

**Source Documents:**
- Master GDD v2.0 (Sections 1–40)
- GDD Section 41 (Modular Coding & Architecture)

---

## System Categories

Each system is classified as one of:

| Type | Description |
|------|-------------|
| **Data** | Static configuration loaded at startup (Resources, JSON) |
| **Runtime** | Active gameplay systems that process game state |
| **Service** | Autoload singletons providing cross-cutting functionality |
| **UI** | User interface screens, menus, HUD elements |

---

## Implementation Tiers

Systems are grouped into **Tiers 0–4** based on dependency order.
Each tier must be substantially complete before the next tier begins.

---

# TIER 0 — Foundation Layer (No Dependencies)

These systems have zero gameplay dependencies and must exist first.

---

## 0.1 Project Structure & Conventions

**Type:** Infrastructure
**GDD Sections:** 13, 14, 41.2
**Godot Nodes:** None (folder structure only)

**Deliverables:**
- `res://Game/` folder structure per Section 41.2
- `res://Data/` folder structure
- `res://UI/` folder structure
- `res://Tests/` folder structure
- `res://DevTools/` folder structure
- Naming conventions document
- `.gitignore` for Godot 4.x

**Risks:** None
**Dependencies:** None

---

## 0.2 DataRegistry (Autoload)

**Type:** Service
**GDD Sections:** 14, 32.1, 41.3, 41.4
**Godot Nodes:** Autoload singleton (Node)

**Responsibility:**
- Load and cache all static data tables
- Provide lookup functions for: classes, races, items, passives, monsters, status effects
- Validate data schema on load (dev mode)

**Key Functions:**
```
get_class_data(class_id) -> ClassData
get_race_data(race_id) -> RaceData
get_item_template(item_id) -> ItemTemplate
get_passive(passive_id) -> PassiveData
get_monster(monster_id) -> MonsterData
get_status_effect(effect_id) -> StatusEffectData
```

**Risks:**
- Schema drift if data files are edited manually
- Missing validation could allow invalid data to propagate

**Dependencies:** None

---

## 0.3 GameContext (Autoload)

**Type:** Service
**GDD Sections:** 36.1, 41.3
**Godot Nodes:** Autoload singleton (Node)

**Responsibility:**
- Hold references to other systems
- Track current game phase (Town / Dungeon / Defense / Menu)
- Store run metadata (seed, current region, current town)
- Provide debug flags

**Key Functions:**
```
get_current_phase() -> GamePhase
set_current_phase(phase: GamePhase)
get_run_seed() -> int
get_current_region() -> RegionData
get_current_town() -> TownData
is_debug_mode() -> bool
```

**Risks:**
- Becoming a "god object" if too much is added
- Must resist urge to store gameplay state here

**Dependencies:** 0.2 DataRegistry

---

## 0.4 Seeded RNG Wrapper

**Type:** Service (sub-component of GameContext)
**GDD Sections:** 41.5
**Godot Nodes:** RefCounted class

**Responsibility:**
- Provide all randomness for gameplay systems
- Seed from `run_seed`
- Allow state save/restore for replay

**Key Functions:**
```
rand_int(min: int, max: int) -> int
rand_float(min: float, max: float) -> float
rand_choice(array: Array) -> Variant
rand_weighted(weights: Dictionary) -> Variant
get_state() -> Dictionary
set_state(state: Dictionary)
```

**Risks:**
- Developers calling `randf()` directly instead of using wrapper
- Need linting/review process to catch violations

**Dependencies:** None

---

# TIER 1 — Core Data & Economy (Minimal Runtime)

These systems handle persistent state but have minimal gameplay logic.

---

## 1.1 EconomySystem (Autoload)

**Type:** Service
**GDD Sections:** 11, 35, 41.3, 41.10
**Godot Nodes:** Autoload singleton (Node)

**Responsibility:**
- Own global gold pool (single source of truth)
- Own shared materials inventory
- Provide transactional spend/add operations
- Emit signals when economy changes

**Key Functions:**
```
get_gold() -> int
try_spend_gold(amount: int) -> bool
add_gold(amount: int)

get_material_count(material_id: String) -> int
try_spend_materials(materials: Dictionary) -> bool
add_material(material_id: String, qty: int)
add_materials(materials: Dictionary)

has_sufficient_gold(amount: int) -> bool
has_sufficient_materials(materials: Dictionary) -> bool
```

**Signals:**
```
signal gold_changed(new_amount: int)
signal materials_changed(material_id: String, new_amount: int)
```

**Risks:**
- Other systems bypassing EconomySystem to modify gold/materials
- Need strict code review to enforce ownership

**Dependencies:** 0.2 DataRegistry (for material definitions)

---

## 1.2 SaveSystem (Autoload)

**Type:** Service
**GDD Sections:** 29, 32.4, 41.3, 41.11
**Godot Nodes:** Autoload singleton (Node)

**Responsibility:**
- Serialize/deserialize game state
- Manage save file versioning
- Handle migration for older saves
- Provide checkpoint functionality

**Save Layers (per GDD 32.4):**
- Run Save (current dungeon state)
- Campaign Save (towns, heroes, global gold, materials)
- Meta Save (World Tome, unlocks, settings)

**Key Functions:**
```
save_campaign() -> bool
load_campaign() -> CampaignData | null
has_campaign_save() -> bool

save_run_state(run_data: RunData)
load_run_state() -> RunData | null
clear_run_state()

save_meta() -> bool
load_meta() -> MetaData

get_save_version() -> int
migrate_save(from_version: int, data: Dictionary) -> Dictionary
```

**Risks:**
- Save corruption from partial writes
- Schema changes breaking old saves
- Need backup mechanism

**Dependencies:**
- 0.2 DataRegistry (for schema validation)
- 1.1 EconomySystem (save includes gold/materials)

---

## 1.3 AudioSystem (Autoload)

**Type:** Service
**GDD Sections:** 30, 41.3
**Godot Nodes:** Autoload singleton (Node) + AudioStreamPlayer pool

**Responsibility:**
- Play SFX and music via named cues
- Manage audio bus volumes
- Prevent direct AudioStreamPlayer usage in gameplay scripts

**Key Functions:**
```
play_sfx(cue_name: String, volume_db: float = 0.0)
play_music(track_name: String, fade_time: float = 1.0)
stop_music(fade_time: float = 1.0)
set_bus_volume(bus_name: String, volume_db: float)
get_bus_volume(bus_name: String) -> float
```

**Risks:**
- Audio pool exhaustion under heavy combat
- Need proper pooling strategy

**Dependencies:** None

---

# TIER 2 — Entity Systems (Heroes, Items, Monsters)

These systems define the core entities that exist in the game world.

---

## 2.1 Hero Entity System

**Type:** Runtime
**GDD Sections:** 8, 15, 22, 24, 32.2.1
**Godot Nodes:** RefCounted (HeroData) + Node2D (HeroVisual)

**Responsibility:**
- Define hero data structure (stats, equipment, abilities)
- Calculate derived stats from equipment + passives
- Track hero state (alive, dead, legacy, defender)

**Schema (per GDD 32.2.1):**
```
Hero {
  hero_id, name, race_id, class_id, level, experience,
  is_legacy, is_undead, is_defender,
  stats: Stats,
  equipment: Equipment,
  inventory: Array[Item]
}
```

**Key Functions:**
```
create_hero(race_id, name) -> Hero
assign_class(hero: Hero, class_id: String)
calculate_stats(hero: Hero) -> Stats
equip_item(hero: Hero, slot: String, item: Item) -> bool
unequip_item(hero: Hero, slot: String) -> Item | null
is_alive(hero: Hero) -> bool
```

**Risks:**
- Stat calculation complexity (base + equipment + passives + buffs)
- Need clear layer order for modifiers

**Dependencies:**
- 0.2 DataRegistry (class/race data)
- 2.2 Item System (equipment)

---

## 2.2 Item System

**Type:** Runtime
**GDD Sections:** 7, 31, 34, 41.8
**Godot Nodes:** RefCounted (ItemData)

**Responsibility:**
- Define item data structure
- Generate items from templates + quality
- Enforce item pipeline: Create → Socket → Refine
- Calculate item stats from base + affixes + refinement

**Schema (per GDD 32.2.2):**
```
Item {
  item_id, template_id, quality, rarity,
  base_stats: Dictionary,
  affixes: Array[Affix],
  sockets: Array[Socket],
  refinement_level: int,
  is_insured: bool
}
```

**Key Functions:**
```
create_item(template_id, quality, rng: SeededRNG) -> Item
add_socket(item: Item, socket_type: String) -> bool
insert_gem(item: Item, socket_index: int, gem: Item) -> bool
refine_item(item: Item, rng: SeededRNG) -> RefineResult
salvage_item(item: Item) -> Dictionary  # materials returned
calculate_item_stats(item: Item) -> Dictionary
```

**Pipeline Enforcement:**
- Items track `pipeline_stage: enum { CREATED, SOCKETED, REFINED }`
- Socketing only allowed if stage == CREATED
- Refining only allowed if stage <= SOCKETED

**Risks:**
- Complex affix rolling logic
- Refinement risk curve must match GDD 40.6

**Dependencies:**
- 0.2 DataRegistry (item templates, affix pools)
- 0.4 Seeded RNG

---

## 2.3 Monster Entity System

**Type:** Runtime
**GDD Sections:** 9, 17, 25, 38
**Godot Nodes:** RefCounted (MonsterData) + Node2D (MonsterVisual)

**Responsibility:**
- Define monster data structure
- Load monster templates with stats, abilities, AI tier
- Track runtime state (health, statuses, position)

**Schema:**
```
Monster {
  monster_id, template_id, name,
  stats: Stats,
  abilities: Array[AbilityData],
  ai_tier: int,
  passives: Array[PassiveData],
  current_health: int,
  statuses: Array[StatusInstance]
}
```

**Key Functions:**
```
create_monster(template_id: String, level_modifier: int = 0) -> Monster
get_ai_behavior(monster: Monster) -> AIBehavior
is_alive(monster: Monster) -> bool
```

**Risks:**
- AI tier complexity (Tier 0-3 per GDD 38.2)
- Need clear separation between data and behavior

**Dependencies:**
- 0.2 DataRegistry (monster templates)

---

# TIER 3 — Gameplay Systems (Combat, Dungeon, Town)

These are the core gameplay loops that use entities from Tier 2.

---

## 3.1 Status Effect System

**Type:** Runtime
**GDD Sections:** 27, 39, 41.7
**Godot Nodes:** RefCounted (StatusController)

**Responsibility:**
- Apply, stack, and resolve status effects
- Enforce registry-first rule (no unlisted statuses)
- Track countdowns and trigger resolution

**Registry Enforcement (per 41.7):**
- All status applications must validate against DataRegistry
- Unknown status in dev mode: raise error
- Unknown status in release: ignore + log warning

**Key Functions:**
```
apply_status(target: Unit, effect_id: String, stacks: int, source: Unit) -> bool
remove_status(target: Unit, effect_id: String, stacks: int = -1)
resolve_turn_end(target: Unit)  # process DoTs, countdowns
cleanse_category(target: Unit, category: String)
get_active_statuses(target: Unit) -> Array[StatusInstance]
```

**Resolution Order (per GDD 39.8):**
1. Control checks (stun, root)
2. Countdown resolution
3. DoT ticks
4. Buff/Debuff expiry

**Risks:**
- Complex interaction between status types
- Countdown effects need careful timing

**Dependencies:**
- 0.2 DataRegistry (status effect registry)
- 2.1/2.3 Entity systems (targets)

---

## 3.2 Combat System

**Type:** Runtime
**GDD Sections:** 6, 23, 25, 38, 41.6
**Godot Nodes:** Node (CombatController) + Node2D (BattlefieldView)

**Responsibility:**
- Manage turn order and phase progression
- Process unit actions (move, attack, ability)
- Coordinate with StatusController for effect resolution
- Handle victory/defeat conditions

**Components (per GDD 41.6):**
- `CombatController` — turn order, phase progression
- `UnitController` — individual unit actions
- `StatusController` — status resolution (see 3.1)
- `TargetingService` — target selection (pure functions)

**Key Functions:**
```
# CombatController
start_combat(heroes: Array[Hero], enemies: Array[Monster], grid: BattleGrid)
get_turn_order() -> Array[Unit]
advance_turn()
is_combat_over() -> bool
get_combat_result() -> CombatResult

# UnitController
execute_move(unit: Unit, target_tile: Vector2i) -> bool
execute_attack(unit: Unit, target: Unit) -> AttackResult
execute_ability(unit: Unit, ability: Ability, targets: Array) -> AbilityResult

# TargetingService (stateless)
get_valid_targets(unit: Unit, ability: Ability, grid: BattleGrid) -> Array[Unit]
calculate_target_score(attacker: Unit, target: Unit) -> float
```

**Risks:**
- Complex interaction between abilities, statuses, and positioning
- Turn order edge cases (speed ties, initiative modifiers)
- Need comprehensive test coverage

**Dependencies:**
- 2.1 Hero System
- 2.3 Monster System
- 3.1 Status Effect System
- 0.4 Seeded RNG

---

## 3.3 Town & Facility System

**Type:** Runtime
**GDD Sections:** 5, 18, 41.9
**Godot Nodes:** Node (TownController) + Control (TownUI)

**Responsibility:**
- Track facility states (tier, slots, assigned heroes)
- Process production slot commits
- Trigger shop refresh on appropriate events
- Manage facility upgrades

**Slot Commit Pattern (per GDD 41.9):**
- Show material requirements before confirmation
- Materials consumed only on explicit commit
- Cancel reverts all changes

**Key Functions:**
```
# TownController
get_facility(facility_id: String) -> FacilityData
upgrade_facility(facility_id: String) -> bool
assign_hero_to_facility(facility_id: String, hero: Hero) -> bool
commit_production_slot(facility_id: String, slot_index: int, materials: Dictionary) -> bool

# ShopController
refresh_shop(town: TownData, rng: SeededRNG)
get_shop_items(town: TownData) -> Array[Item]
purchase_item(town: TownData, item_index: int) -> bool
```

**Risks:**
- Complex facility tier interactions
- Shop refresh timing rules (GDD 36.3)

**Dependencies:**
- 0.2 DataRegistry (facility definitions)
- 1.1 EconomySystem (material consumption)
- 2.2 Item System (item generation)

---

## 3.4 Dungeon System

**Type:** Runtime
**GDD Sections:** 20, 26
**Godot Nodes:** Node (DungeonController) + Node2D (DungeonMap)

**Responsibility:**
- Generate dungeon floors with rooms
- Track floor progression and completion
- Manage region boss charge system
- Handle extraction and floor completion

**Charge System (per GDD 26.8):**
- +1 Region Charge per floor completion
- Max 10 charges stored
- 1 charge consumed per Region Boss attempt

**Key Functions:**
```
generate_floor(region: RegionData, floor_index: int, rng: SeededRNG) -> FloorData
get_room(floor: FloorData, room_index: int) -> RoomData
complete_room(floor: FloorData, room_index: int, result: RoomResult)
can_attempt_boss(region: RegionData) -> bool
consume_boss_charge(region: RegionData) -> bool
extract_from_floor(floor: FloorData) -> ExtractionResult
```

**Risks:**
- Complex room generation logic
- Boss access timing and charge tracking

**Dependencies:**
- 0.2 DataRegistry (room templates, enemy pools)
- 0.4 Seeded RNG
- 3.2 Combat System (for combat rooms)

---

## 3.5 AI System

**Type:** Runtime
**GDD Sections:** 25, 38
**Godot Nodes:** RefCounted (AIController)

**Responsibility:**
- Evaluate targets using scoring system
- Select actions based on AI tier
- Handle forced targeting (taunt, abilities)
- Provide intent indicators

**AI Tiers (per GDD 38.2):**
- Tier 0 (Feral): Attack nearest
- Tier 1 (Basic): Proximity + low HP
- Tier 2 (Tactical): Threat scoring, ability usage
- Tier 3 (Strategic): Prediction, synergy targeting

**Key Functions:**
```
# Stateless evaluation
evaluate_targets(unit: Unit, grid: BattleGrid) -> Array[TargetScore]
select_action(unit: Unit, grid: BattleGrid, ai_tier: int) -> AIAction
get_intent(unit: Unit, selected_action: AIAction) -> IntentData

# Scoring components
calculate_threat_value(target: Unit) -> float
calculate_vulnerability_value(target: Unit) -> float
calculate_opportunity_modifier(attacker: Unit, target: Unit) -> float
calculate_deterrent(target: Unit) -> float
```

**Risks:**
- Scoring weights need extensive tuning
- AI behavior must be readable to players

**Dependencies:**
- 3.1 Status System (for status awareness)
- 3.2 Combat System (for grid access)

---

# TIER 4 — UI & Polish Systems

These systems provide the player interface and feedback.

---

## 4.1 UIRouter (Autoload)

**Type:** Service
**GDD Sections:** 28, 37, 41.3
**Godot Nodes:** Autoload singleton (Node)

**Responsibility:**
- Control screen transitions
- Manage UI state mapping
- Enforce single-primary-focus rule (GDD 37.1)

**Key Functions:**
```
push_screen(screen_id: String, params: Dictionary = {})
pop_screen()
replace_screen(screen_id: String, params: Dictionary = {})
show_modal(modal_id: String, params: Dictionary = {}) -> ModalResult
get_current_screen() -> String
```

**Dependencies:**
- 0.3 GameContext (phase awareness)

---

## 4.2 Combat UI

**Type:** UI
**GDD Sections:** 28.3, 28.4, 28.5, 37.5
**Godot Nodes:** Control (BattlefieldUI)

**Components:**
- Grid view with unit indicators
- Turn order display
- Selected unit panel
- Ability bar
- Status effect icons
- Tile inspection mode

**Dependencies:**
- 3.2 Combat System
- 4.1 UIRouter

---

## 4.3 Town UI

**Type:** UI
**GDD Sections:** 28.8, 28.9, 37.3
**Godot Nodes:** Control (TownUI)

**Components:**
- Town overview map
- Facility interaction screens
- Shop interface
- Hero management
- Inventory view

**Dependencies:**
- 3.3 Town System
- 4.1 UIRouter

---

## 4.4 Debug Overlay & Dev Tools

**Type:** UI (Dev Only)
**GDD Sections:** 41.12
**Godot Nodes:** CanvasLayer (DebugOverlay)

**Components:**
- Debug overlay (seed, gold, region, floor, statuses)
- Spawner tool (heroes, enemies, items, resources)
- Combat sandbox scene

**Dependencies:**
- All Tier 0-3 systems

---

# Implementation Summary

| Tier | Systems | Est. Complexity |
|------|---------|-----------------|
| 0 | Project Structure, DataRegistry, GameContext, RNG | Low |
| 1 | EconomySystem, SaveSystem, AudioSystem | Medium |
| 2 | Hero, Item, Monster entities | Medium |
| 3 | Status, Combat, Town, Dungeon, AI | High |
| 4 | UIRouter, Combat UI, Town UI, Debug Tools | Medium |

---

# Risk Summary

| Risk | Mitigation |
|------|------------|
| God object anti-pattern | Strict module boundaries, code review |
| Direct RNG calls | Linting rules, wrapper enforcement |
| Economy bypass | EconomySystem ownership, no direct mutation |
| Status effect complexity | Registry-first validation, extensive tests |
| Save corruption | Atomic writes, backup mechanism |
| Combat edge cases | Deterministic testing, combat sandbox |

---

*Document created: 2025-12-20*
*Source: Master GDD v2.0 + Section 41*
