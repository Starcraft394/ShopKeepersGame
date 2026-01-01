32.1 Core Data Philosophy & Runtime Model Rules

This section defines the data-first philosophy used throughout Shops & Shadows.
All runtime systems, combat logic, facilities, and progression rely on explicit data models, not hard-coded behavior.

These rules apply to all entities defined in Section 32.

32.1.1 Data-Driven First

All gameplay systems are driven by externalized data, not embedded logic.

Heroes, items, facilities, enemies, and dungeons are defined via structured data

Balance changes should be possible without modifying code

Systems read from data; they do not infer missing information

Claude implementations must prefer:

Dictionaries / Resources / JSON-like structures

Declarative configuration

Explicit values over derived assumptions

32.1.2 Flat Numbers Over Percentages

All core values are stored as flat numbers.

Examples:

Attack = 42, not +15%

Damage bonus = +6, not 1.1x

Duration = 3 turns, not “short”

Percent modifiers:

Are applied at runtime

Are derived from passives, buffs, or abilities

Are never stored directly on items or heroes unless explicitly defined

This simplifies tuning, stacking rules, and UI clarity.

32.1.3 Explicit Ownership & Responsibility

Each system owns its data.

System	Owns
Hero	Stats, equipment, gold, abilities
Item	Stats, passives, refinement state
Facility	Production rules, slot configuration
Dungeon	Floors, rooms, enemies, rewards
Region	Passive pools, boss access
Meta Systems	Carryover rules, world tome

No system mutates another system’s data directly.
All changes flow through defined interfaces.

32.1.4 Deterministic Resolution

Once an action begins, its outcome is deterministic.

Examples:

Shop items are determined at refresh

Combat outcomes resolve turn by turn

Salvage outputs are fixed at salvage time

Randomness is allowed only when:

Explicitly triggered

Logged or traceable

Bound by known ranges

There is no hidden or background RNG.

32.1.5 No Implicit Defaults

If a value is not defined, it does not exist.

Rules:

No “assumed” stats

No hidden bonuses

No fallback behaviors

If a system requires data:

It must be present in the schema

Or explicitly blocked from running

This prevents bugs, exploits, and AI hallucination during implementation.

32.1.6 Schema Stability Over Time

Once defined, schemas:

May be extended

Must not be silently altered

Should remain backward-compatible when possible

Changes to schemas:

Require Fix Notes

Should include migration intent if applicable

This ensures long-term maintainability.

32.1.7 Turn-Based Combat Compatibility

All schemas assume:

Turn-based combat

Discrete resolution steps

Status effects evaluated once per turn

Tick-based logic is explicitly excluded unless defined later.

32.1.8 Claude Implementation Guidance

When implementing from this GDD:

Do not invent fields

Do not compress systems for convenience

Prefer clarity over optimization

Use readable names over shorthand

Follow section order strictly

If a value or rule is unclear:

Defer to Fix Notes

Do not infer intent

32.2 Core Entity Schemas — Hero & Item

This section defines the authoritative runtime data models for Heroes and Items.
All combat, inventory, facilities, and progression systems reference these schemas.

These are data-driven models, not hard-coded classes.

32.2.1 Hero Entity Schema

A Hero represents any controllable unit that can:

Equip items

Participate in combat

Be assigned to facilities

Gain levels, gold, and legacy status

Hero Core Identity
Hero {
  hero_id: string,
  name: string,
  race_id: string,
  class_id: string | null,
  level: int,
  experience: int,
  is_legacy: bool,
  is_undead: bool,
  is_defender: bool
}


Notes:

class_id may be null only in very early tutorial states

Class may be overwritten via Class Books

Undead heroes follow the same schema with flags

Hero Base Stats
Stats {
  max_health: int,
  current_health: int,
  attack: int,
  defense: int,
  speed: int,
  crit_chance: float,
  crit_damage: float,
  accuracy: float,
  evasion: float
}


Notes:

Stats are flat values

Percentage modifiers are applied at runtime, not stored

Hero Equipment Slots
Equipment {
  weapon_main: Item | null,
  weapon_offhand: Item | null,
  head: Item | null,
  chest: Item | null,
  legs: Item | null,
  accessory_1: Item | null,
  accessory_2: Item | null,
  backpack: Item | null,
  health_flask: Item (permanent)
}


Rules:

Weapon abilities come from weapon_main

Backpack modifies inventory size only

Health Flask is permanent and rechargeable

Hero Inventory
Inventory {
  slots_max: int,
  slots_used: int,
  items: Item[]
}


Notes:

Inventory slots are small by design (max ~6)

Resources are non-stacking

Gold is not stored here

Hero Abilities
Abilities {
  class_abilities: Ability[2],
  weapon_ability: Ability,
  passive_effects: Passive[]
}


Rules:

No ultimate abilities

Weapon ability is determined by weapon type

Item-granted abilities are rare and explicit

Hero Status Effects
StatusEffect {
  effect_id: string,
  stacks: int,
  duration: int,
  countdown_type: "turn" | "tick",
  icon_type: "stack" | "countdown",
  source: string
}


Rules:

Countdown effects use clock icon

Stack-based effects show numeric overlays

Effects update once per turn (turn-based combat)

Hero Gold & Economy
HeroEconomy {
  gold: int,
  insured_slots: Item[],
  defense_gold_pool: int
}


Rules:

Gold is hero-owned

Defense gold is earned separately

On hero death:

Items are lost

Gold is lost unless Bank is unlocked

32.2.2 Item Entity Schema

Items are immutable once created, except through:

Refinement

Socketing

Salvaging

Item Core Identity
Item {
  item_id: string,
  item_type: string,
  subtype: string,
  rarity: string,
  region_tags: string[],
  is_legendary: bool,
  is_blueprint_item: bool
}


Examples:

item_type: weapon, armor, tool, consumable, class_book

subtype: sword, bow, chest_armor, pickaxe

Item Stats
ItemStats {
  flat_stats: {
    attack?: int,
    defense?: int,
    speed?: int,
    health?: int,
    crit?: float
  }
}


Notes:

All stats are flat

No scaling formulas stored on item

Item Passives
Passive {
  passive_id: string,
  description: string,
  value: int,
  scaling_type: "flat" | "conditional"
}


Rules:

Blueprint items may have dual-region passives

Legendary passives are unique and named

Weapon Ability Binding
WeaponAbility {
  ability_id: string,
  trigger_type: "active",
  cooldown: int,
  effect_definition: string
}


Rules:

Every weapon type has one defined ability

Ability strength may scale via passives

Sockets & Gems
Sockets {
  max_sockets: int,
  filled_sockets: Gem[]
}


Rules:

Socketing happens before refinement

Gems are removable only via facility services

Refinement Data
Refinement {
  refinement_level: int,
  stat_group: "offense" | "defense" | "utility",
  risk_tier: int
}


Rules:

Refinement caps depend on rarity

Risk tiers introduce negative outcomes

Refined items salvage for reduced materials

Consumables
Consumable {
  charges_max: int,
  charges_current: int,
  effect_type: "heal" | "buff"
}


Rules:

Health Flask:

Permanent

Refilled on return to town

Potions:

Single-use

Buff-focused only

Salvage Output
SalvageResult {
  materials: Resource[],
  rare_chance: float
}


Rules:

No legendary materials returned

Refined items return fewer materials

Salvaging is irreversible

32.2.3 Shared Rules & Guarantees

Heroes and Items never mutate silently

All randomness is explicit and logged

UI reads directly from schema fields

No system bypasses these models

32.3 Core Entity Schemas — Facilities, Dungeons, Enemies

This section defines the remaining runtime gameplay entities required to execute towns, dungeon runs, combat encounters, and progression gates.

All schemas here follow the rules established in 32.1.

32.3.1 Facility Entity Schema

A Facility represents a town-based production and service node.
Facilities do not craft items directly; they consume materials to generate shop outputs or provide services.

Facility Core Identity
Facility {
  facility_id: string,
  facility_type: string,
  tier: int,
  town_id: string,
  is_unlocked: bool
}


Examples:

facility_type: blacksmith, alchemist, jeweler, training_hall, defense

Tier range: 1–4

Facility Production Configuration
FacilityProduction {
  max_shop_slots: int,
  active_shop_slots: int,
  slot_definitions: Slot[],
  material_inputs: Resource[]
}


Rules:

Player selects slot count and item type per slot

UI previews exact material cost

Materials are consumed on shop refresh only

Facility Slot Definition
Slot {
  slot_id: string,
  item_category: string,
  item_subtype: string | null
}


Examples:

Weapon slot → subtype selectable (sword, bow)

Armor slot → subtype selectable (head, chest)

Facility Assigned Heroes
FacilityAssignment {
  assigned_heroes: Hero[],
  xp_gain_enabled: bool,
  xp_per_item: int
}


Rules:

Heroes assigned to facilities gain XP based on items produced

XP scales via World Tome nodes

Assigned heroes retain identity and equipment

Facility Services

Facilities may provide non-item services:

Examples:

Refinement (T3+)

Socketing

Flask upgrades

Legendary crafting

Defense deployment

Each service is gated by:

Facility type

Facility tier

32.3.2 Dungeon Entity Schema

A Dungeon represents a multi-floor progression container tied to a town.

Dungeon Core Identity
Dungeon {
  dungeon_id: string,
  region_id: string,
  town_id: string,
  max_floor: int,
  completed_floors: int
}


Rules:

Floors unlock sequentially

After dungeon completion, all floors remain selectable for farming

Dungeon Floor Schema
DungeonFloor {
  floor_id: string,
  floor_index: int,
  room_sequence: Room[],
  resource_pools: Resource[],
  enemy_table: Enemy[],
  is_completed: bool
}


Rules:

Player may select which unlocked floor to enter

Shop refresh occurs only on floor completion

Early extraction forfeits all collected items

Room Schema
Room {
  room_id: string,
  room_type: string,
  encounter_data: object
}


Room types include:

Combat

Resource

Event

Rest (fixed placement rules)

32.3.3 Enemy Entity Schema

Enemies are combat-only entities controlled by AI.

Enemy Core Identity
Enemy {
  enemy_id: string,
  enemy_family: string,
  region_id: string,
  level: int,
  is_boss: bool
}

Enemy Stats
EnemyStats {
  health: int,
  attack: int,
  defense: int,
  speed: int
}


Rules:

Flat stats only

Scaling occurs via region and floor modifiers

Enemy Passives
EnemyPassive {
  passive_id: string,
  description: string,
  trigger_condition: string
}


Rules:

Universal passives begin after Region 1

Region identity influences passive pools

Enemies do not refine or evolve mid-combat

Enemy Abilities
EnemyAbility {
  ability_id: string,
  cooldown: int,
  effect_definition: string
}


Rules:

Regions 1–3: enemies use auto-attacks only

Region 4+: enemies may have abilities

Ability triggers are deterministic

32.3.4 Boss Entity Schema

Bosses are special enemies that gate progression.

Boss Identity
Boss {
  boss_id: string,
  boss_type: "floor" | "region",
  region_id: string,
  level: int
}

Boss Mechanics
BossMechanic {
  mechanic_id: string,
  description: string,
  trigger_turn: int | null,
  countdown: int | null
}


Examples:

Summoned turrets

Delayed arena-wide effects

Phase transitions

Boss Rewards
BossReward {
  guaranteed_drop: Item | Resource,
  bonus_drops: Resource[],
  first_kill_only: bool
}


Rules:

First campaign kill of a region boss guarantees Legendary

Subsequent kills follow normal rarity rules

Floor bosses drop Blueprints

32.3.5 Region Boss Access (Charged System)

Region Boss access uses a charge-based system.

Rules:

Each floor completion grants +1 Region Charge

Charges accumulate up to 10

1 charge is consumed per Region Boss attempt

Charges persist across runs and towns within the region

This allows:

Controlled farming

Prevention of rapid boss spam

32.3.6 Combat Integration Rules

Enemies follow same grid rules as heroes

No hero deaths occur in town defense combat

Enemy AI uses:

Target priority

Status evaluation

Turn-based execution

32.3.7 Persistence Rules

Dungeon floor completion is saved immediately

Boss kills update progression flags

Failed dungeon attempts reset to floor start

32.4 Persistence & Save Architecture

This section defines how game state is saved, reset, and persisted across dungeon runs, towns, regions, and campaign cycles.

All persistence rules are explicit and deterministic.

32.4.1 Save Layer Overview

The game uses three distinct save layers, each with a different lifespan and purpose.

Save Layer	Scope	When It Updates
Run Save	Current dungeon run	During combat & rooms
Campaign Save	Current campaign	On town return & progression
Meta Save	Post-campaign carryover	On campaign completion

Each layer is isolated and never overwrites another.

32.4.2 Run Save (Dungeon Session State)

The Run Save exists only while inside a dungeon.

Run Save Contains
RunSave {
  current_dungeon_id: string,
  current_floor_index: int,
  current_room_index: int,
  party_state: Hero[],
  shopkeeper_inventory: Item[],
  temporary_resources: Resource[],
  active_status_effects: StatusEffect[]
}

Run Save Rules

Updated after:

Every combat

Every room completion

Deleted when:

Returning to town

Party wipes

Manual extraction

Failure Rules

If all heroes die:

Run Save is discarded

Campaign Save remains intact

If player extracts early:

All Run Save items/resources are lost

Campaign Save resumes unchanged

32.4.3 Campaign Save (Primary Progression State)

The Campaign Save tracks all long-term progression during a single campaign.

Campaign Save Contains
CampaignSave {
  regions_unlocked: string[],
  towns: Town[],
  facilities: Facility[],
  heroes: Hero[],
  shared_storage: Resource[],
  dungeon_progress: Dungeon[],
  region_charges: int,
  world_events: EventFlags
}

Campaign Save Rules

Updates occur:

On returning to town

On floor completion

On boss defeat

Campaign Save is never affected by:

Mid-run failure

Combat-only losses

Town destruction and tier reductions are applied here

32.4.4 Meta Save (Post-Campaign Carryover)

The Meta Save is created only when a campaign is completed.

Meta Save Contains
MetaSave {
  world_tome_points: int,
  unlocked_world_tome_nodes: string[],
  carryover_heroes: Hero[],
  carryover_resources: Resource[],
  book_of_the_dead: Hero[],
  campaign_count: int
}

Meta Save Rules

Campaign 1 starts with:

0 World Tome points

Post-campaign:

Player selects carryover heroes

Player selects carryover materials (slot-limited)

Meta Save never changes mid-campaign

32.4.5 Book of the Dead Persistence

The Book of the Dead is a persistent record.

Rules:

All fallen heroes are recorded

Sacrificed heroes (e.g. Lich) are also recorded

Favorites are preserved across cycles

No passive bonuses are granted by default

Book of the Dead data persists only in Meta Save.

32.4.6 Defense & Offline Resolution Saves

Town defense battles are resolved on return from dungeon runs.

Defense Save Rules

Defense outcomes are calculated:

After returning to town

Before shop refresh

Results affect:

Building tier changes

Defense gold pools

No hero deaths occur in defense battles

32.4.7 Autosave & Safety Rules
Autosave Triggers

Floor completion

Town return

Boss defeat

Facility upgrades

Safety Rules

No autosave during combat resolution

No overwrite during schema changes

Failed writes retry before abort

32.4.8 Versioning & Migration

Every save file includes:

save_version: string


Rules:

New versions may extend saves

No silent data removal

Deprecated fields are ignored safely

32.4.9 Claude Implementation Guidance

When implementing persistence:

Treat saves as immutable snapshots

Never infer missing fields

Always validate schema before load

Separate run logic from campaign logic strictly

32.5.1 High-Level Scene Hierarchy

The game is structured around a small number of authoritative controllers.

GameRoot
 ├─ MetaController
 ├─ CampaignController
 │   ├─ TownController
 │   ├─ DungeonController
 │   └─ WorldEventController
 └─ UIController


Each controller owns only its domain and communicates via signals or data passing.

32.5.2 MetaController (Global / Cross-Campaign)

Scope: Exists across all campaigns.

Responsibilities

World Tome progression

Meta Save loading/saving

Book of the Dead persistence

Campaign reset initialization

Carryover selection logic

Does NOT Handle

Combat

Town logic

Dungeon logic

Item generation

32.5.3 CampaignController (Primary Runtime Owner)

Scope: Active campaign only.

Responsibilities

Campaign Save ownership

Region progression tracking

Active town selection

Global shared storage

Campaign-level flags (town destruction, unlocks)

Does NOT Handle

Combat resolution

Per-room logic

UI rendering

CampaignController is the authoritative source of truth during a campaign.

32.5.4 TownController

Scope: Current town only.

Responsibilities

Facility management

Facility tier upgrades

Shop slot configuration

Shop refresh execution

Town defense resolution

Assigned heroes in facilities

Local shop UI data

Does NOT Handle

Dungeon logic

Enemy logic

Hero combat behavior

TownController requests item generation from Facilities but does not roll items itself.

32.5.5 FacilityScene (Per-Facility Instance)

Scope: One facility.

Responsibilities

Validating material inputs

Declaring production rules

Providing service availability (refinement, socketing, upgrades)

Tracking assigned heroes and XP gain

Reporting output definitions to TownController

Does NOT Handle

Inventory storage

Item stat rolling

Shop ownership

Facilities define what can be made, not what is sold.

32.5.6 DungeonController

Scope: One dungeon run.

Responsibilities

Floor selection

Room sequencing

Run Save ownership

Shopkeeper bag tracking

Resource collection

Extraction handling

Failure handling

Does NOT Handle

Town persistence

Item generation

Facility logic

DungeonController is destroyed when returning to town.

32.5.7 BattleController

Scope: Single combat encounter.

Responsibilities

Turn order

Grid state

Ability execution

Status effect resolution

Damage calculations

Victory / defeat result

Does NOT Handle

Saving

Loot distribution

Enemy spawning tables

UI menus

BattleController is fully deterministic once combat begins.

32.5.8 HeroScene

Scope: One hero unit.

Responsibilities

Reading hero data

Executing abilities

Applying status effects

Equipment stat contribution

Death handling (combat only)

Does NOT Handle

AI decisions (delegated)

Save writing

Item generation

HeroScene never mutates campaign data directly.

32.5.9 EnemyScene

Scope: One enemy unit.

Responsibilities

Stat usage

Passive triggers

Ability execution (post-Region 3)

AI behavior execution

Does NOT Handle

Loot tables

Save logic

Spawn rules

32.5.10 AIController

Scope: Shared.

Responsibilities

Target selection

Ability usage decisions

Priority evaluation

Does NOT Handle

Damage math

Status application

Turn resolution

AIController suggests actions, BattleController executes them.

32.5.11 Item & Inventory Components
ItemComponent

Pure data container

No logic

InventoryComponent

Slot validation

Item addition/removal

Capacity checks

Neither component performs:

Stat calculations

UI rendering

32.5.12 UIController

Scope: Global UI layer.

Responsibilities

Rendering data

Handling player input

Sending commands to controllers

Does NOT Handle

Game logic

Calculations

Save mutation

UI is strictly read-only for state.

32.5.13 Communication Rules

Controllers communicate via:

Signals

Data snapshots

No scene directly edits another scene’s internal state

No circular dependencies

32.6 Claude + Godot Implementation Contract (Long Form)

This section defines the non-negotiable implementation rules for building Shops & Shadows in Godot 4.x with Claude in VS Code.
It exists to prevent rework, hallucinated systems, and inconsistent structure.

All code must follow the data-driven philosophy in 32.1 and the schemas in 32.2–32.5.

32.6.1 Core Principles
Rule 1 — Data Drives Everything

All content should be definable in data:

Heroes, items, enemies, facilities, dungeons, regions, passives

Code reads data and executes rules

Code must not hard-code progression or balance

Rule 2 — Flat Numbers Stored, Modifiers Computed

Store flat values in data

Apply bonuses at runtime

Avoid embedding derived numbers into saves unless explicitly required

Rule 3 — Deterministic Once Started

After a combat begins, it must resolve deterministically

After a shop refresh is committed, the results must be reproducible for that refresh state

RNG must be centralized and controllable

32.6.2 Project Structure Rules (Godot 4.x)
Recommended Folder Layout
/Scenes
  /Root
  /Town
  /Dungeon
  /Battle
  /UI
/Systems
  /Persistence
  /Economy
  /Combat
  /AI
  /Generation
/Data
  /Regions
  /Facilities
  /Items
  /Enemies
  /Dungeons
  /Classes
  /Races
/Resources
  /Icons
  /SFX
  /VFX
/Scripts


Rules:

Scene logic goes in /Scenes/*

Pure system logic goes in /Systems/*

Data definitions go in /Data/*

32.6.3 Source of Truth Rules
CampaignController is the Truth

Campaign state must be owned by CampaignController

No other scene writes campaign state directly

DungeonController Owns Run State

RunSave lives only in DungeonController

RunSave must be destroyed on town return/extraction/wipe

UI is Read-Only

UI never modifies state directly

UI sends “commands” to controllers

Controllers validate and apply

32.6.4 Schema Enforcement
Validation Required

Claude must implement:

Schema validation at load time

Default values only if explicitly declared

Versioning (save_version) for all save layers

If a field is missing:

Fail gracefully

Log clearly

Do not invent behavior

32.6.5 Save System Requirements
Three Save Layers

Must be separate files or separate blocks:

RunSave

CampaignSave

MetaSave

Autosave Triggers

Floor completion

Town return

Boss defeat

Facility upgrades

Forbidden Save Events

Mid-turn combat

Mid-resolution of ability effects

During RNG roll loops

32.6.6 RNG Rules (Critical)
Centralized RNG

Use one RNG owner (e.g., RNGService) with:

Seed support

Named roll methods

Optional debug logs

RNG Must Be Explicit

Forbidden:

Calling random() directly inside random systems scattered around code

Allowed:

rng.roll_table("blacksmith_weapon_pool")

rng.roll_range("refinement_risk", min, max)

Debug Mode

Add a debug flag that can:

Print seeds and roll outcomes

Replay a shop refresh deterministically

32.6.7 Item Generation Rules
Facility Item Generation

Slot selection drives material requirements

UI must show:

Per-slot input cost

Total cost

Materials are consumed only at shop refresh

Blueprint & Legendary Rules

Blueprint items:

Epic

Dual-region passives

Stat priority with one max-roll guarantee

Legendary items:

Not shop-random

Crafted only with Legendary Materials at T4 facilities

Modification Order

Must enforce:

Create item

Socketing

Refinement

Salvage reduces return if refined

32.6.8 Combat Rules Implementation
Turn-Based Only

Each combat has discrete turns

Status effects resolve once per turn

No tick-based resolution unless explicitly added later

BattleController Executes Everything

AI chooses actions

BattleController validates & applies

HeroScene/EnemyScene should not “decide outcomes”

No Ultimate Abilities

Only:

2 class actives

weapon ability

passives

32.6.9 AI Rules Implementation
AI Suggests, Controller Executes

AI selects target and action

BattleController executes deterministically

Simple First

No complex heuristics early

Ensure stable, predictable behavior

Expand later with data-driven weights if needed

32.6.10 UI Implementation Rules
No UI-Driven State

UI must not:

Modify stats

Remove items directly

Assign heroes directly without controller

UI must:

Request action

Display result

Inventory & Equipment UI

UI must support:

Drag-drop with validation

Tooltips showing:

Base stats

refinement deltas

passive descriptions

socket contents

32.6.11 Logging & Debugging Standards

Claude should implement:

Clear error logs

Warnings for invalid configs

Debug overlays optional, but not required

Minimum logging areas:

Save load failures

Missing fields

RNG calls in debug mode

Item generation outcomes

Combat resolution errors

32.6.12 Scope Control Rules
Do Not Add Systems

Claude must not invent:

Additional facilities

New currencies

New stats

Extra ability slots

New progression layers

If a design gap exists:

Add a TODO comment

Do not implement guesses

32.6.13 Implementation Milestone Order (Recommended)

Load schemas and validate

TownController + basic shop refresh

Inventory & equipment management

DungeonController room sequence (no combat)

BattleController basic auto-attacks

Add class abilities

Add weapon abilities

Add refinement + socketing

Add bosses + region charges

Add meta systems (World Tome)