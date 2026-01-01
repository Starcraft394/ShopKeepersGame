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
