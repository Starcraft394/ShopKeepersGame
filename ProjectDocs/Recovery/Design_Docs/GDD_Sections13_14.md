GDD ADDENDUM — FULL SECTIONS 13 & 14
Shops & Shadows — Studio Developer Edition
-------------------------------------------------------
13. PRODUCTION ROADMAP & DEVELOPMENT STRATEGY

This roadmap defines the full production cycle for Shops & Shadows, optimized for:

Godot 4.x

AI-assisted coding (Claude)

Pixellab sprite generation

Modular content development

Scalability and clarity

13.1 Production Philosophy
Data-Driven First

All gameplay values come from data (JSON, .tres files), not hard-coded logic.
Claude can modify or generate content safely.

AI-Augmented Development Workflow

Claude handles:

Writing GDScript

Scene templates

Resource file generation

Debugging

Refactoring

Balancing

You make design decisions — Claude implements them.

Chunk-Based Development

Everything is built in small, testable chunks:

Items

Heroes

Regions

Systems

UI elements

This prevents burnout and reduces implementation errors.

13.2 Development Phases
PHASE 0 — Foundations (2–4 Weeks)

Goal: Create the baseline environment.

Install Godot 4.x and set up the project

Establish folder structure

Define naming conventions

Define JSON schemas for heroes, items, facilities, regions, monsters, events

Create test scenes:

Combat sandbox

Node-based map prototype

Town UI mockup

Create version control repository

PHASE 1 — Core Systems Implementation (6–10 Weeks)

Goal: First playable loop.

Systems implemented:

Hero + Monster entity classes

Stats component

Ability resolver

Turn Manager

Combat grid

Map system (fog-of-war, branching nodes)

Town v1 (storage, shop)

Tools + resource gathering logic

Outcome:
A player can go:

➡️ Town → Adventure → Combat → Return

PHASE 2 — Core Gameplay Features (8–14 Weeks)

Goal: Make the game feel real.

Additions:

Facilities T1–T3

Refinement system

Consumables / flasks

Backpacks

Boss fights (multi-phase)

Classes (starter set)

Legacy system (v1)

Town defense (prototype)

Early corruption system

Outcome:
Regions 1–2 fully playable with meaningful systems.

PHASE 3 — Content Expansion (12–24 Weeks)

Goal: Bring the world to life.

Add:

Regions 3–5

Town Raid event (Region 3)

Jeweler system

Socket/gem system

Legendary crafting

Blueprint crafting

More classes, races

Special encounters / NPCs

Outcome:
Midgame loop complete.

PHASE 4 — Endgame & Final Regions (10–20 Weeks)

Add:

Region 6 (Necropolis)

Region 7 (final realm)

Advanced corruption mechanics

Final boss

Late-game legacy roles

Replay/challenge modifiers

PHASE 5 — Polish & QA (8–16 Weeks)

Refine:

Balancing

UI polish

Sound & VFX

Accessibility options

Optimization

Stability testing

13.3 AI-Assisted Workflow Summary

Claude handles:

GDScript

Data generation

Scene creation

Refactoring

Bug fixing

Implementing new features

Pixellab handles:

Sprite sheets

Animation frames

Consistent pixel style

Godot handles:

Scene and UI management

Game loop

Rendering

Data loading

------------------------------------------------------
14. GODOT DATA ARCHITECTURE (STUDIO ENGINEERING SPEC)
------------------------------------------------------

This defines the core technical blueprint Claude will use when generating code.

Everything is modular, data-driven, and replaceable without rewriting systems.

14.1 Project Folder Structure
res://
  assets/
    sprites/
    animations/
    icons/
  data/
    heroes/
    items/
    abilities/
    monsters/
    events/
    facilities/
    regions/
  scenes/
    battle/
    map/
    town/
  scripts/
    core/
    systems/
    managers/
    entities/
    ui/


This structure ensures:

Claude knows where to place scripts

Godot loads data predictably

Modular content can be expanded without breakage

14.2 Core Managers (Autoload Singletons)
DataManager

Loads all JSON and .tres data.

Lookup tables

Check for missing ID references

Store globally accessible data

TurnManager

Controls combat round order.

Initiative

Turn transitions

Action queue

End-of-turn effects

TileManager

Controls battlefield tile states.

Burning, Corrupted, Poisoned, Blessed, Sticky

Duration tracking

Tile grid updates

CombatManager

High-level combat flow.

Initialize encounter

Spawn heroes/enemies

Detect victory/defeat

Handle loot events

FacilityManager

Handles crafting, refinement, legendary crafting.

Resource validation

Worker (legacy hero) bonuses

Crafting timers

MapManager

Controls node traversal.

Fog-of-war

Corruption spread

Path decisions

Triggering events

14.3 Data Schemas

Claude will generate and manipulate data in these formats.

Hero Schema
{
  "id": "hero_01",
  "name": "Elin",
  "race": "Elf",
  "class": "Ranger",
  "stats": {
    "hp": 100,
    "mana": 30,
    "atk": 12,
    "def": 6,
    "spd": 5,
    "res": {
      "physical": 0,
      "magic": 0,
      "corruption": 0
    }
  },
  "passives": ["keen_sight"],
  "abilities": ["arrow_shot", "multi_shot"],
  "inventory": ["starter_bow"],
  "backpack_size": 3,
  "legacy": false
}

Item Schema
{
  "id": "longsword_01",
  "type": "weapon",
  "rarity": "common",
  "stats": {
    "atk": 12,
    "crit": 3
  },
  "refinement": 0,
  "sockets": 0,
  "gems": [],
  "effects": []
}

Facility Schema
{
  "id": "blacksmith",
  "tier": 1,
  "produces": ["weapons", "metal_armor"],
  "consumes": ["ore"],
  "services": ["refine"],
  "worker_bonuses": {
    "race": { "dwarf": 0.1 },
    "class": { "warrior": 0.05 }
  }
}

Monster Schema
{
  "id": "skeleton_01",
  "family": "undead",
  "stats": {
    "hp": 50,
    "atk": 8,
    "spd": 3
  },
  "abilities": ["bone_slash"],
  "drops": [
    { "resource": "bone_fragment", "chance": 0.45 }
  ]
}

Ability Schema
{
  "id": "fire_bolt",
  "type": "damage",
  "pattern": "single",
  "mana_cost": 10,
  "cooldown": 2,
  "effects": ["burn_small"]
}

Region Schema
{
  "id": "region_1",
  "name": "Verdant Isles",
  "legendary_material": "none",
  "biome": "forest",
  "corruption_type": "spores",
  "nodes": ["node_1", "node_2"]
}

Node Schema
{
  "id": "node_1",
  "type": "combat",
  "difficulty": 1,
  "rewards": ["wood"],
  "corruption": 0
}

14.4 Entity Scenes
HeroEntity.tscn

AnimatedSprite2D

StatsComponent

AbilityComponent

InventoryComponent

MonsterEntity.tscn

Same structure except no inventory.

14.5 Art & Animation Pipeline

Pixellab outputs:

Idle frames

Walk cycles

Attack sequences

Hurt animations

Death animations

Claude will:

Automatically stitch them into spritesheets

Create animations via AnimatedSprite2D

Build animation states (“idle”, “walk”, “attack”, “hurt”, “death”)

Godot expects:

res://assets/animations/[hero_id]/idle.png  
res://assets/animations/[hero_id]/walk.png

14.6 Data Rules for AI-Assisted Content

IDs must be unique and stable

Data references must be valid

Schemas cannot be altered by AI unless instructed

Assets must follow directory conventions

Item & hero balance must stay within reasonable bounds

14.7 Expansion Hooks

Future systems will attach cleanly:

Boss templates

Trait systems

Town specializations

More races & classes

Seasonal events

Corruption modifiers

Event chain system

🎉 END OF FULL SECTIONS 13 + 14

These are now complete, fully expanded, and ready for integration.