# Shops & Shadows — Module Ownership Map
## Responsibility Boundaries & Access Rules

---

## Document Purpose

This document defines strict ownership boundaries for each module in the Shops & Shadows codebase.

**Rules:**
- Each module owns specific data and operations
- Modules communicate through defined interfaces only
- No module may directly mutate another module's internal state
- Cross-module effects use: signals, service interfaces, or command objects

**Source:** GDD Section 41.2, 41.3, 41.10

---

# Module Ownership Definitions

---

## 1. ECONOMY MODULE

**Location:** `res://Game/Economy/`
**Autoload:** `EconomySystem`

### Owns (Single Source of Truth)

| Data | Description |
|------|-------------|
| `global_gold` | The single gold pool for the entire campaign |
| `materials_inventory` | Shared material storage (all towns, all regions) |

### Public Interface (What Others Can Call)

```gdscript
# Gold Operations
func get_gold() -> int
func try_spend_gold(amount: int) -> bool
func add_gold(amount: int)
func has_sufficient_gold(amount: int) -> bool

# Material Operations
func get_material_count(material_id: String) -> int
func try_spend_materials(materials: Dictionary) -> bool
func add_material(material_id: String, qty: int)
func add_materials(materials: Dictionary)
func has_sufficient_materials(materials: Dictionary) -> bool

# Signals
signal gold_changed(new_amount: int)
signal materials_changed(material_id: String, new_amount: int)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Hero stats | Heroes don't carry gold |
| Item data | Items are separate from economy |
| Combat state | Economy is passive storage |
| Town facility tiers | Facilities request upgrades through economy |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Combat | `add_gold()` after victory |
| Town | `try_spend_gold()`, `try_spend_materials()` for upgrades |
| Shop | `try_spend_gold()` for purchases |
| Dungeon | `add_materials()` for loot collection |
| Save | Read-only snapshot for serialization |

---

## 2. COMBAT MODULE

**Location:** `res://Game/Combat/`
**Controllers:** `CombatController`, `UnitController`, `StatusController`, `TargetingService`

### Owns

| Data | Description |
|------|-------------|
| `turn_order` | Current combat turn sequence |
| `active_units` | All units currently in combat |
| `battlefield_grid` | Grid state, tile effects |
| `combat_phase` | Current phase (player turn, enemy turn, resolution) |
| `unit_positions` | Where each unit is on the grid |
| `unit_statuses` | Active status effects per unit |

### Public Interface

```gdscript
# Combat Lifecycle
func start_combat(heroes: Array[Hero], enemies: Array[Monster], grid: BattleGrid)
func end_combat() -> CombatResult
func is_combat_over() -> bool

# Turn Management
func get_current_unit() -> Unit
func get_turn_order() -> Array[Unit]
func advance_turn()

# Actions
func execute_action(unit: Unit, action: CombatAction) -> ActionResult

# Queries
func get_unit_at_position(pos: Vector2i) -> Unit
func get_valid_move_tiles(unit: Unit) -> Array[Vector2i]
func get_valid_targets(unit: Unit, ability: Ability) -> Array[Unit]

# Signals
signal combat_started()
signal turn_started(unit: Unit)
signal action_executed(result: ActionResult)
signal combat_ended(result: CombatResult)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Economy gold/materials | Request through EconomySystem after combat |
| Hero roster management | Combat uses copies, not live roster |
| Town facilities | Combat is isolated from town |
| Save system | Combat reports results, doesn't save directly |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Dungeon | `start_combat()`, receive `combat_ended` signal |
| AI | Read-only access to grid, units, statuses |
| UI | Read-only access for display |
| Status | Integrated component, not external module |

---

## 3. ITEMS MODULE

**Location:** `res://Game/Items/`
**Services:** `ItemFactory`, `RefinementService`, `SalvageService`

### Owns

| Data | Description |
|------|-------------|
| Item instances | All created items and their state |
| Pipeline state | Create → Socket → Refine tracking |
| Affix rolls | Generated affixes per item |
| Refinement history | +1 to +10 progression |

### Public Interface

```gdscript
# Item Creation
func create_item(template_id: String, quality: int, rng: SeededRNG) -> Item
func create_item_from_blueprint(blueprint_id: String, materials: Dictionary) -> Item

# Pipeline Operations (Order Enforced)
func add_socket(item: Item, socket_type: String) -> bool
func insert_gem(item: Item, socket_index: int, gem: Item) -> bool
func refine_item(item: Item, rng: SeededRNG) -> RefineResult

# Salvage
func salvage_item(item: Item) -> Dictionary  # materials returned

# Queries
func calculate_item_stats(item: Item) -> Dictionary
func get_item_value(item: Item) -> int
func can_socket(item: Item) -> bool
func can_refine(item: Item) -> bool

# Signals
signal item_created(item: Item)
signal item_refined(item: Item, new_level: int)
signal item_destroyed(item: Item)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Economy directly | Salvage returns materials via Economy |
| Hero equipment slots | Heroes manage their own equipment |
| Facility production | Facilities request items, don't create directly |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Town/Shop | `create_item()` for shop inventory |
| Hero | Receive items, query stats |
| Economy | Receives salvage materials |
| Save | Read-only for serialization |

---

## 4. TOWN MODULE

**Location:** `res://Game/Town/`
**Controllers:** `TownController`, `FacilityController`, `ShopController`

### Owns

| Data | Description |
|------|-------------|
| `town_data` | Per-town state (name, region, layout) |
| `facility_states` | Tier, slots, assigned heroes per facility |
| `shop_inventory` | Current items available for purchase |
| `production_queue` | Committed material slots |

### Public Interface

```gdscript
# Town Management
func get_current_town() -> TownData
func get_all_towns() -> Array[TownData]

# Facility Operations
func get_facility(facility_id: String) -> FacilityData
func get_facility_tier(facility_id: String) -> int
func can_upgrade_facility(facility_id: String) -> bool
func upgrade_facility(facility_id: String) -> bool
func assign_hero_to_facility(facility_id: String, hero: Hero) -> bool
func remove_hero_from_facility(facility_id: String, hero: Hero)

# Production Slots
func get_available_slots(facility_id: String) -> int
func preview_slot_cost(facility_id: String, slot_config: Dictionary) -> Dictionary
func commit_production_slot(facility_id: String, slot_index: int, materials: Dictionary) -> bool

# Shop Operations
func refresh_shop(rng: SeededRNG)
func get_shop_items() -> Array[Item]
func can_purchase_item(item_index: int) -> bool
func purchase_item(item_index: int) -> Item

# Signals
signal facility_upgraded(facility_id: String, new_tier: int)
signal shop_refreshed()
signal item_purchased(item: Item)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Economy internals | Request through EconomySystem |
| Combat state | Town and combat are separate phases |
| Dungeon floor data | Dungeon manages its own state |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Economy | `try_spend_*()` for purchases/upgrades |
| Items | `create_item()` for shop generation |
| Heroes | Read roster, assign to facilities |
| UI | Read-only for display |

---

## 5. DUNGEON MODULE

**Location:** `res://Game/Dungeons/`
**Controllers:** `DungeonController`, `FloorController`, `RoomController`

### Owns

| Data | Description |
|------|-------------|
| `current_floor` | Active floor state |
| `room_graph` | Room connections and types |
| `encounter_data` | Enemy spawns per room |
| `loot_tables` | Pending loot from cleared rooms |
| `region_charges` | Boss access charges (0-10) |

### Public Interface

```gdscript
# Dungeon Navigation
func enter_dungeon(region: RegionData, floor_index: int)
func get_current_floor() -> FloorData
func get_available_rooms() -> Array[RoomData]
func enter_room(room_index: int)
func complete_room(result: RoomResult)

# Floor Progression
func can_continue_to_next_floor() -> bool
func advance_floor()
func extract_from_dungeon() -> ExtractionResult
func complete_floor() -> FloorResult

# Boss Access
func get_region_charges(region: RegionData) -> int
func add_region_charge(region: RegionData)
func can_attempt_boss(region: RegionData) -> bool
func consume_boss_charge(region: RegionData) -> bool

# Signals
signal floor_entered(floor: FloorData)
signal room_entered(room: RoomData)
signal room_completed(room: RoomData, result: RoomResult)
signal floor_completed(result: FloorResult)
signal extraction_completed(result: ExtractionResult)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Town state | Dungeon and town are separate phases |
| Economy directly | Reports loot, Economy adds it |
| Hero permanent state | Uses run-local copies |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Combat | Started by dungeon for combat rooms |
| Economy | Receives loot on extraction/completion |
| Save | Run state saved by SaveSystem |
| AI | Access enemy data for rooms |

---

## 6. AI MODULE

**Location:** `res://Game/AI/`
**Services:** `TargetingService`, `BehaviorResolver`

### Owns

| Data | Description |
|------|-------------|
| `target_scores` | Calculated scores per potential target |
| `action_selection` | Chosen action per AI turn |
| `intent_display` | What the enemy plans to do |

### Public Interface

```gdscript
# Target Evaluation (Stateless)
func evaluate_targets(unit: Unit, grid: BattleGrid) -> Array[TargetScore]
func get_best_target(unit: Unit, grid: BattleGrid) -> Unit

# Action Selection
func select_action(unit: Unit, grid: BattleGrid, ai_tier: int) -> AIAction
func get_available_actions(unit: Unit) -> Array[AIAction]

# Intent
func get_intent(unit: Unit, selected_action: AIAction) -> IntentData
func is_action_still_valid(unit: Unit, action: AIAction, grid: BattleGrid) -> bool

# Scoring Components (Exposed for Debug)
func calculate_threat_value(target: Unit) -> float
func calculate_vulnerability_value(target: Unit) -> float
func calculate_opportunity_modifier(attacker: Unit, target: Unit) -> float
func calculate_deterrent(target: Unit) -> float
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Combat execution | AI selects actions, Combat executes |
| Unit stats directly | Read-only access |
| Turn order | Managed by Combat |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| Combat | `select_action()`, `get_intent()` |
| UI | `get_intent()` for display |

---

## 7. SAVE MODULE

**Location:** `res://Game/Save/`
**Autoload:** `SaveSystem`

### Owns

| Data | Description |
|------|-------------|
| `save_version` | Current schema version |
| `save_files` | All save data on disk |
| `migration_rules` | Version upgrade paths |

### Public Interface

```gdscript
# Campaign Save
func has_campaign_save() -> bool
func save_campaign() -> bool
func load_campaign() -> CampaignData
func delete_campaign_save()

# Run Save
func save_run_state(run_data: RunData)
func load_run_state() -> RunData
func clear_run_state()
func has_run_state() -> bool

# Meta Save
func save_meta() -> bool
func load_meta() -> MetaData

# Version Management
func get_save_version() -> int
func migrate_save(from_version: int, data: Dictionary) -> Dictionary
func create_backup()

# Signals
signal save_completed(success: bool)
signal load_completed(data: Variant)
```

### Must NOT Touch

| Forbidden | Reason |
|-----------|--------|
| Gameplay state directly | Only serializes snapshots |
| Economy modification | Read-only for serialization |

### Access Rules

| Module | Allowed Operations |
|--------|-------------------|
| All Modules | Provide snapshot data when requested |
| GameContext | Trigger save/load at checkpoints |

---

# Cross-Module Communication Rules

## Allowed Patterns

### 1. Signals (Preferred)
```gdscript
# Emitter
signal gold_changed(new_amount: int)

# Receiver
EconomySystem.gold_changed.connect(_on_gold_changed)
```

### 2. Service Calls (For Transactions)
```gdscript
# Request through service interface
var success = EconomySystem.try_spend_gold(100)
if success:
    proceed_with_action()
```

### 3. Command Objects (For Complex Operations)
```gdscript
# Create command
var cmd = PurchaseItemCommand.new(item, buyer)

# Execute through appropriate system
ShopController.execute_command(cmd)
```

## Forbidden Patterns

### 1. Direct State Mutation
```gdscript
# FORBIDDEN
EconomySystem.gold = EconomySystem.gold - 100

# CORRECT
EconomySystem.try_spend_gold(100)
```

### 2. Cross-Module Internal Access
```gdscript
# FORBIDDEN
var internal_data = CombatController._unit_positions

# CORRECT
var positions = CombatController.get_unit_positions()
```

### 3. Circular Dependencies
```gdscript
# FORBIDDEN: Combat depends on Town, Town depends on Combat

# CORRECT: Both depend on shared services (Economy, Data)
```

---

# Data Flow Diagrams

## Gold Flow
```
Combat Victory → EconomySystem.add_gold()
Defense Victory → EconomySystem.add_gold()
Salvage Item → EconomySystem.add_materials() + add_gold()
Shop Purchase → EconomySystem.try_spend_gold()
Facility Upgrade → EconomySystem.try_spend_gold() + try_spend_materials()
```

## Item Flow
```
Facility Commit → Items.create_item() → Shop Inventory
Shop Purchase → Hero Equipment / Inventory
Dungeon Loot → Shopkeeper Bag → (on return) Shared Storage
Salvage → Items.salvage_item() → Economy.add_materials()
```

## Save Data Flow
```
Checkpoint → SaveSystem reads from:
  - EconomySystem (gold, materials)
  - TownController (facilities, shops)
  - Roster (heroes, equipment)
  - DungeonController (run state)

Load → SaveSystem writes to each module's load_from_save()
```

---

# Module Dependency Matrix

| Module | Depends On | Depended By |
|--------|-----------|-------------|
| DataRegistry | None | All |
| GameContext | DataRegistry | All |
| EconomySystem | DataRegistry | Combat, Town, Dungeon, Save |
| SaveSystem | All (read-only) | GameContext |
| AudioSystem | None | UI, Combat |
| Items | DataRegistry, RNG | Town, Hero, Combat |
| Heroes | DataRegistry, Items | Combat, Town, Dungeon |
| Monsters | DataRegistry | Combat, Dungeon |
| Combat | Heroes, Monsters, Status, AI | Dungeon, UI |
| Status | DataRegistry | Combat |
| Town | Economy, Items | UI, Save |
| Dungeon | Combat, Economy | UI, Save |
| AI | Combat (read-only) | Combat |
| UI | All (read-only) | None |

---

*Document created: 2025-12-20*
*Source: Master GDD v2.0 + Section 41*
