• Added standardized enemy archetype system
• Ensured AI is deterministic and turn-based
• Avoided dynamic reaction logic
• Ensured compatibility with Town Defense auto-resolve
• No changes required to earlier sections

• Corrected Region Boss charge system (1 charge per floor, max 10 stored)
• Ensured 1 charge = 1 Region Boss attempt
• Clarified dungeon failure floor reset rules
• Guaranteed legendary on first region boss kill (campaign only)
• Prevented legendary bloat on repeat kills
• No conflicts with Sections 20–25

• Established authoritative status effect framework
• Defined global stacking, countdown, and UI rules
• Formalized Doom-style countdown effects
• Clarified boss interaction with status effects
• Linked weapon identity to status application
• No changes required to earlier sections

• Defined combat, shop, dungeon, and town UI rules
• Clarified status, tile, and ability presentation
• Ensured low-clutter, context-driven information flow
• Confirmed turn-based combat UI requirements
• No changes required to earlier sections

• Defined campaign vs meta save separation
• Locked autosave points to safe checkpoints
• Clarified hero death and town persistence
• Formalized dungeon floor and region boss persistence
• Ensured shared inventory consistency
• No changes required to earlier sections

• Defined audio clarity-first philosophy
• Prevented audio overload in combat
• Clarified boss, status, and UI audio rules
• Ensured accessibility and player control
• No changes required to earlier sections

• Added material cost preview to shop slot selection
• Clarified global material stockpiling
• Converted Health Flask into permanent rechargeable item
• Separated sustain (flask) from buff potions
• Defined Blueprint purpose and epic crafting rules
• Distinguished Legendary crafting from Blueprint crafting
• Confirmed no hero-level crafting

GDD_FIX_NOTES — Item System Clarifications & Additions
🔧 FIX 31.A — Item Rarity & Blueprint Role Clarification

Issue:
Item rarity, blueprint crafting, and legendary crafting were described across multiple sections but lacked a single authoritative definition hierarchy.

Resolution:
Establish a clear rarity philosophy:

Common → Rare

RNG stat ranges

0–1 passive modifiers

Epic (Blueprint Crafted)

Crafted using Blueprints

Combines two regional passive pools

Allows stat priority selection (one stat guaranteed max roll)

Deterministic structure, still RNG within bounds

Legendary

Not sold in shops

Crafted only via T4 facilities using Legendary Materials

Unique named effects and mechanics

Non-deterministic, region-flavored

Blueprints are not region-locked, but are unlocked via region progression (floor boss drops).

🔧 FIX 31.B — Item Modification Order Rules

Issue:
Order of socketing, refinement, blueprint crafting, and legendary crafting was implicit and could lead to contradictions.

Resolution:
Define a universal item modification order:

Item is created (Facility / Blueprint / Legendary Craft)

Socketing occurs first (Jeweler)

Refinement occurs second (Facility T3+)

Legendary items may have reduced refinement caps

Blueprint-crafted items refine normally but cannot gain legendary-only effects

This order applies globally to all items.

🔧 FIX 31.C — Facility-Based Item Generation Transparency

Issue:
Material consumption for shop item generation was not fully visible or predictable to the player.

Resolution:
When selecting facility shop slots:

The UI displays:

Materials required per slot

Total materials to be pulled from shared storage

Players may intentionally over-supply materials to stockpile for:

Future shop refreshes

Facility upgrades

Shared storage is never auto-drained; all inputs are explicit player choices

🔧 FIX 31.D — Salvaging System (New)

Addition:
Introduce Item Salvaging as a late-early / midgame system.

Salvaging Rules:

Any non-locked item may be salvaged in town

Salvaging returns:

Base materials used to generate the item

A small chance at rare or region-specific components

Salvaging does not return:

Legendary materials

Blueprint unlocks

Refined items return less material

Salvaging serves as:

Item sink

Resource smoothing tool

Inventory cleanup mechanic

Salvaging is intentionally simpler than crafting and does not require a new facility (can be accessed via existing facilities or shop UI).

🔧 FIX 31.E — Item System Overview Documentation Gap

Issue:
Items functioned correctly across systems but lacked a single documentation anchor.

Resolution:
Plan a future Item System Overview subsection to consolidate:

Item anatomy (stats, passives, sockets, abilities)

Rarity effects

Region passive pools

Weapon ability hooks

No gameplay changes required.

• Defined authoritative Hero and Item runtime schemas
• Clarified gold ownership and loss rules
• Formalized weapon ability binding to items
• Unified refinement, socketing, and salvage behavior
• Ensured compatibility with turn-based combat
• No conflicts with Sections 23–31

• Established global data-driven design rules
• Clarified flat-number philosophy
• Defined deterministic resolution expectations
• Prevented implicit defaults and hidden logic
• Ensured compatibility with turn-based combat
• Prepared groundwork for schema extensions in 32.3+

• Defined Facility production and service schemas
• Clarified dungeon floor selection and farming rules
• Formalized enemy and boss entity structures
• Integrated region boss charge system
• Ensured compatibility with town defense and combat rules
• No conflicts with Sections 18, 20, 26, or 31

• Defined three-layer save architecture
• Clarified extraction vs death persistence rules
• Formalized Book of the Dead storage
• Locked town defense resolution timing
• Prevented mid-run campaign corruption
• Ensured compatibility with World Tome system

• Defined authoritative ownership per scene
• Prevented logic duplication across controllers
• Clarified destruction lifecycle of DungeonController
• Ensured clean separation of UI and game logic
• Aligned scene roles with persistence layers (32.4)

• Added long-form implementation contract for Claude + Godot
• Locked deterministic RNG standards and validation rules
• Established mandatory system boundaries and folder structure
• Prevented UI-driven state mutation
• Confirmed turn-based combat and ability slot limits
• Added milestone order to avoid rework

• Defined five parallel progression axes
• Established enemy scaling independent of hero level
• Clarified loot and gold pacing expectations
• Added post-campaign scaling rules
• Introduced hard and soft power caps
• Aligned difficulty growth with mechanics over stats

35.F FIX NOTES — GLOBAL GOLD SYSTEM UPDATE

The following clarifications apply across the GDD:

Gold is a single global resource

All gold earned (combat, events, defense) flows into the global pool

Per-hero gold tracking is deprecated

Defense gold is no longer a separate storage

Shop purchases do not depend on hero-specific gold

Hero rotation does not affect economic access

Sections impacted conceptually (no rewrite yet):

Section 19 — Town Defense

Section 21 — Campaign & Post-Campaign Flow

Section 24 — Class Kits (implicit gold usage)

Section 31 — Shops & Facilities

FIX NOTES — SECTION 36
Affects / Clarifies

Section 20 (Dungeon Flow)

Section 26 (Boss Access)

Section 31 (Shops & Crafting)

Section 35 (Global Gold)

Key Clarifications Added

Shop refresh rules unified

Extraction penalties finalized

Floor-based saving enforced

Global inventory reinforced

Defense resolution timing fixed

No contradictions found with existing sections.

FIX NOTES — SECTION 37
Clarifies / Touches

Section 20 (Dungeon Flow)

Section 31 (Shop & Facilities)

Section 36 (Core Loop)

Section 23 (Abilities & Weapon Skills)

New Clarifications Added

Single-panel interaction rule

Explicit extraction UI

Defense resolution display

Tile inspection visibility rules

No conflicts detected.

FIX NOTES — SECTION 38
Clarifies / Touches

Section 19 (Town Defense)

Section 20 (Dungeon Flow)

Section 23 (Abilities)

Section 37 (UI Intent Indicators)

New Systems Defined

AI Tier system

Target score framework

Enemy intent locking

Boss AI override rules

No contradictions found.

FIX NOTES — SECTION 39
Affected Sections

Section 23 (Abilities)

Section 24 (Class Kits)

Section 26 (Boss Mechanics)

Section 38 (Enemy AI)

Clarifications

Countdown effects standardized

Stack behavior unified

UI rules finalized

No Conflicts Detected

# 41. Modular Coding & Architecture (Godot 4.x)

This section defines the code architecture rules for Shops & Shadows so the project remains modular, data-driven, and Claude/Godot-friendly.

---

## 41.1 Architecture Goals

**Primary goals:**
- Reduce coupling between systems (combat, items, towns, UI, saving)
- Make behaviors data-driven (JSON/Resource data instead of hard-coded logic)
- Keep systems testable in isolation (headless/unit tests where possible)
- Allow incremental implementation (Tier 0 → Tier 3 complexity)
- Ensure the Master GDD remains the single source of truth

**Non-goals:**
- Premature optimization
- Large inheritance chains
- God objects (single scripts with “everything” inside)

---

## 41.2 Project Module Boundaries

Use modules as folders + namespaces (by convention), not engine-level packages.

Recommended top-level folders:
- `res://Game/` (core gameplay runtime)
- `res://Data/` (static data: classes, items, monsters, passives, configs)
- `res://UI/` (menus, HUD, tooltips, inspectors)
- `res://Audio/` (SFX, music, audio buses, cues)
- `res://Tests/` (test scenes, harnesses, deterministic simulations)
- `res://DevTools/` (debug overlays, spawn menus, logging tools)

Core runtime modules:
- `Game/State/` (game state machine, run lifecycle)
- `Game/Combat/` (grid combat runtime, status resolution)
- `Game/Items/` (generation, refinement, salvage, blueprints)
- `Game/Town/` (facilities, production slots, upgrades)
- `Game/Dungeons/` (floors, encounters, node graphs)
- `Game/AI/` (targeting + behavior rules)
- `Game/Save/` (persistence, versioning, migration)
- `Game/Economy/` (global gold + material ledger rules)
- `Game/Events/` (event rolls, region passives, scripted triggers)

**Rule:** No module is allowed to directly modify another module’s internal state.
All cross-module effects must go through:
1) events/signals, or
2) service interfaces (autoload “systems”), or
3) explicit command objects (“apply this change”).

---

## 41.3 Autoload Systems (Singletons) — Allowed List

Use Autoloads sparingly. These are the only “global” singletons permitted:

- `GameContext`  
  Holds references to other systems, current run metadata (seed, region, town), and debug flags.

- `SaveSystem`  
  Handles serialize/deserialize, version migrations, checkpoints.

- `DataRegistry`  
  Loads and caches data tables (classes, items, passives, monsters, status registry).

- `EconomySystem`  
  Owns **global gold** and the **shared materials inventory** (no per-hero gold).

- `AudioSystem`  
  Plays SFX/music via named cues; prevents direct AudioStreamPlayer logic in gameplay scripts.

- `UIRouter`  
  Controls screen transitions and UI state mapping.

Everything else should be constructed per scene/run as normal nodes (not global).

---

## 41.4 Data-Driven Rules (How “Design” Becomes Code)

Every “design rule” should map to:
- a **data object** (Resource or JSON), plus
- a **resolver** (code that interprets the data)

### 41.4.1 Use Resources for Authoritative Tables
Prefer Godot `Resource` types when:
- Designers want to edit values in-editor
- Data needs strong typing

Prefer JSON when:
- Data is large and bulk-edited externally
- Data is generated procedurally by tools

**Rule:** Either approach is valid, but the runtime must treat it as read-only “source data”.

---

## 41.5 Deterministic Simulation Requirements

Shops & Shadows uses many random systems (item generation, refinement, enemy spawns).
To keep debugging sane:

**Rule:** All randomness must come from a single seeded RNG per run:
- `run_seed` stored in save
- `rng_state` optionally stored for exact replay (optional early; recommended later)

**Forbidden:** Calling `randf()` or `randi()` directly inside gameplay code without using the run RNG wrapper.

---

## 41.6 Combat Runtime Structure (Tick vs Turn)

Combat is designed to be **turn-based** for readability and strategy (grid clarity).

Implementation guideline:
- `CombatController` owns turn order and phase progression
- `UnitController` owns actions (move/attack/abilities)
- `StatusController` owns status add/remove/resolve rules
- `TargetingService` provides target lists and scoring (pure functions)

**Rule:** Targeting logic must be stateless and testable (input state → output decision).

---

## 41.7 Status Effects — Registry-First Enforcement

The **Status Effect Registry** is authoritative.

**Rule:** No status may be applied unless it exists in the registry.
If code attempts to apply an unknown status:
- In dev mode: raise an error + log the caller
- In release: ignore + log warning

Status UI conventions:
- Icon + stack number
- Countdown statuses use clock icon + number (turns remaining)

---

## 41.8 Item Pipeline — Immutable Step Order

The item modification pipeline is fixed:
1) Create (base + quality)
2) Socket (if allowed)
3) Refine (risk curve; can add/alter)

**Rule:** Code must enforce this pipeline order.
No system may “refine then socket” or “re-roll base after refine”.

---

## 41.9 Facility Production — Slot Commit Pattern

Facilities generate shop items by consuming materials committed into **production slots**.

Implementation rule:
- Facility screen shows:
  - slot selection
  - exact material pull preview
  - confirm button to commit materials

**Rule:** Materials are never auto-consumed in the background.

---

## 41.10 Global Gold + Shared Inventory — Single Source of Truth

Economy rules:
- Gold is global (one pool)
- Materials are shared globally (one inventory)
- Town defense rewards add to global gold
- No per-hero gold tracking exists

Implementation rule:
- `EconomySystem` is the *only* code allowed to:
  - add/subtract gold
  - add/subtract materials
- Other modules must request changes via:
  - `EconomySystem.try_spend_gold(cost) -> bool`
  - `EconomySystem.add_material(material_id, qty)`
  - `EconomySystem.try_spend_materials(dict) -> bool`

---

## 41.11 Save Versioning & Migration

All saves must include:
- `save_version`
- `run_seed`
- `global_gold`
- `materials_inventory`
- party roster snapshot
- facility states (tiers + slot commits)

Migration rules:
- Migrations must be additive whenever possible
- When removing a field, keep a fallback read path for 1 major version

---

## 41.12 Debug & Dev Tools (Required)

To keep Claude/Godot iteration fast, implement:

- **Debug Overlay**
  - current seed
  - global gold
  - current region/town
  - current floor
  - active statuses on selected unit

- **Spawner Tool (Dev only)**
  - spawn hero
  - spawn enemy
  - grant gold/materials
  - spawn an item by template + quality

- **Combat Sandbox Scene**
  - load a fixed scenario
  - run deterministic turns
  - print outcome summary

---

## 41.13 “Claude-Friendly” Implementation Rules

To keep generated code reliable:

- Keep functions small (≤ ~50 lines whenever possible)
- Prefer pure functions for scoring/targeting/resolution
- Avoid deeply nested logic; use early returns
- Use explicit enums/constants (no magic strings)
- All data ids are snake_case and stable
- Every major system exposes a minimal public API

---

## Fix Notes — Section 41

- If any section still references “per-hero gold” or “defense treasury”, it must be replaced with **global gold** rules (Section 35 + Section 41.10).
- If any duplicated older sections exist in the Master GDD (example: Town Defense mentioning Defense Treasury), remove the duplicate block and keep the global-gold version only.
- Ensure Section 27/39 status rules match Section 41.7 “registry-first enforcement”.
