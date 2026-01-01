📄 MVP_Milestones.md

Shops & Shadows — MVP Vertical Slice Execution Plan
Version: 1.0
Status: Locked (Execution Document)
Depends On:

MVP_Scope.md (authoritative scope)

Shops_And_Shadows_MASTER_GDD.md

IMPLEMENTATION_ROADMAP.md

🔑 Purpose of This Document

This file defines how the MVP is built, not what it is.

This is an engineering execution plan

Claude should treat milestones as checkpoints

Scope changes must NOT be made here

Each milestone must be fully functional before proceeding

🧱 Milestone ↔ Implementation Tier Mapping
MVP Milestone	Implementation Tier(s)	Goal
M0	Tier 0	Project boots, data loads
M1	Tier 1	Combat loop exists
M2	Tier 2	Shop + town loop exists
M3	Tier 3	Dungeon progression exists
M4	Tier 4	Persistence + meta loop
M5	All	MVP validation & lock
🟦 M0 — Project Boot & Data Spine

Tier Mapping: Tier 0 (0.1–0.4)

🎯 Objective

The game launches, loads data, and can simulate logic without UI.

Required Systems

DataRegistry (autoload)

SeededRNG

GameContext

Basic data schemas

Required Files / Outputs

DataRegistry.gd (autoloaded)

Data classes:

ClassData

RaceData

ItemTemplate

AbilityData

StatusEffectData

MonsterData

Minimal JSON data:

1 class

1 race

1 monster

1 weapon

1 ability

1 status effect

Success Criteria

Game boots without errors

DataRegistry.run_smoke_test() passes

Data can be queried globally

No gameplay yet — logic only

🚫 Do NOT implement UI or scenes yet

🟦 M1 — Core Combat Slice

Tier Mapping: Tier 1 (1.1–1.4)

🎯 Objective

A single combat encounter can be simulated end-to-end.

Combat Assumptions

Turn-based (per GDD)

Grid-based (simplified grid acceptable)

No animations required yet

Required Systems

CombatController

TurnManager

AbilityExecutor

StatusEffectResolver

TargetingLogic (basic)

Required Gameplay

Party of 2 heroes vs 2 enemies

Heroes have:

Basic attack

1 class ability

Enemies auto-attack only

Status effects tick correctly

Win / Lose is detected

Success Criteria

Combat resolves deterministically

Status effects apply and expire

Death is permanent

Combat can be simulated via logs (UI optional)

🚫 No shop, no dungeon, no town yet

🟦 M2 — Shop & Town Loop

Tier Mapping: Tier 2 (2.1–2.4)

🎯 Objective

Player can return to town, buy items, and prepare for combat.

Required Systems

ShopInventoryGenerator

FacilitySlotResolver

GlobalGoldManager

InventorySystem

ItemGenerationPipeline (Create → Quality → Affix)

Required Gameplay

One town

One shop

One facility (Blacksmith)

Shop refreshes on:

Floor completion

Town return

Global gold only (no per-hero gold)

Success Criteria

Items are generated via facility slots

Gold is spent globally

Heroes can equip / unequip items

Inventory persists between combats (session-level)

🚫 No dungeon progression yet

🟦 M3 — Dungeon Progression Loop

Tier Mapping: Tier 3 (3.1–3.5)

🎯 Objective

Player can clear dungeon floors, extract, and progress.

Required Systems

DungeonFloorController

FloorStateTracker

ExtractionHandler

LootResolver

RegionChargeTracker (basic)

Required Gameplay

Single dungeon

2 floors minimum

Floor completion:

Refreshes shop

Awards loot

Extraction rules:

Mid-floor extraction loses loot

Floor completion allows safe return

Death is permanent

Success Criteria

Player can:

Enter dungeon

Clear floor

Return to town

Re-enter dungeon

Dungeon state resets correctly

Loot is consistent with GDD rules

🟦 M4 — Persistence & Meta Progression

Tier Mapping: Tier 4 (4.1–4.4)

🎯 Objective

The game can be saved, loaded, and resumed safely.

Required Systems

SaveManager

Serialization schemas

Versioned save data

Global inventory persistence

Required Persistence

Heroes (alive/dead)

Inventory

Global gold

Dungeon progress

Facility tiers

Success Criteria

Save → Quit → Load restores state

Dead heroes stay dead

Shop state restores correctly

No duplicated items or gold

🟦 M5 — MVP Validation & Lock

Tier Mapping: All

🎯 Objective

Confirm MVP meets scope and is safe to extend.

Validation Checklist

MVP_Scope.md fully satisfied

No placeholder systems

No debug-only shortcuts

All loops function without editor intervention

Deliverables

MVP build playable end-to-end

Known issues documented

Next-phase roadmap approved

🚫 No new features allowed in M5

🧠 Rules for Claude (IMPORTANT)

Do not implement future systems early

Do not refactor scope during milestones

If blocked, STOP and report

Always complete current milestone before proceeding

🔒 Lock Status

MVP scope is locked

Milestones are locked

Only fixes via Fix Notes may alter behavior

✅ End of MVP_Milestones.md