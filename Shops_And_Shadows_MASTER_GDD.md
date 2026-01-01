# Shops & Shadows — Master Game Design Document
## Version 2.0 (Full 40-Section Integration)

---

# Table of Contents

1. [High-Level Overview](#1-high-level-overview)
2. [Core Fantasy & Vision](#2-core-fantasy--vision)
3. [World Structure & Regions](#3-world-structure--regions)
4. [Core Gameplay Loop](#4-core-gameplay-loop)
5. [Town Management & Facilities](#5-town-management--facilities)
6. [Combat System](#6-combat-system)
7. [Items, Crafting, Refinements & Backpacks](#7-items-crafting-refinements--backpacks)
8. [Heroes (Races, Classes, Passives)](#8-heroes-races-classes-passives)
9. [Monsters & Corruption](#9-monsters--corruption)
10. [UI / UX](#10-ui--ux)
11. [Economy & Resource Flow](#11-economy--resource-flow)
12. [Glossary & Developer Notes](#12-glossary--developer-notes)
13. [Production Roadmap & Development Strategy](#13-production-roadmap--development-strategy)
14. [Godot Data Architecture](#14-godot-data-architecture)
15. [Races & Classes Framework](#15-races--classes-framework)
16. [Regions Overview](#16-regions-overview)
17. [Monster Family Framework](#17-monster-family-framework)
18. [Resource & Facility Input System](#18-resource--facility-input-system)
19. [Town Defense System](#19-town-defense-system)
20. [Dungeon Node & Multi-Floor System](#20-dungeon-node--multi-floor-system)
21. [Postgame & New Cycle (NG+) System](#21-postgame--new-cycle-ng-system)
22. [Class System](#22-class-system)
23. [Turn-Based Ability & Combat System](#23-turn-based-ability--combat-system)
24. [Class Ability Kits](#24-class-ability-kits)
25. [Enemy AI Archetypes & Behavior Rules](#25-enemy-ai-archetypes--behavior-rules)
26. [Boss Design Rules](#26-boss-design-rules)
27. [Status Effect Registry](#27-status-effect-registry)
28. [UI & Player Feedback Rules](#28-ui--player-feedback-rules)
29. [Save System & Persistence Rules](#29-save-system--persistence-rules)
30. [Audio Design & Feedback Rules](#30-audio-design--feedback-rules)
31. [Item System & Generation](#31-item-system--generation)
32. [Core Data Philosophy, Entity Schemas & Scene Architecture](#32-core-data-philosophy-entity-schemas--scene-architecture)
33. [Progression, Scaling & Balance Framework](#33-progression-scaling--balance-framework)
34. [Item System & Procedural Generation Framework](#34-item-system--procedural-generation-framework)
35. [Economy, Gold Flow & Resource Balance](#35-economy-gold-flow--resource-balance)
36. [Player Flow, Menus & Core Game Loop](#36-player-flow-menus--core-game-loop)
37. [UI State Mapping & Interaction Rules](#37-ui-state-mapping--interaction-rules)
38. [Enemy AI & Targeting Logic](#38-enemy-ai--targeting-logic)
39. [Status Effects System](#39-status-effects-system)
40. [Balance & Scaling Framework](#40-balance--scaling-framework)

---

# 1. High-Level Overview

A single-player cozy grim-fantasy roguelite where the player is a **Shopkeeper** who hires heroes, manages a growing town, upgrades production facilities, explores corrupted lands, gathers resources, and ultimately rebuilds regions devastated by spreading corruption.

You are not the one swinging the sword. You are the one making sure the sword exists, the town stands, and the next band of would-be heroes has a reason to try again.

> **Godot Implementation Note:** This GDD is structured for readability and modularity, optimized for Godot 4.x and Claude-based toolchains.

---

# 2. Core Fantasy & Vision

## 2.1 Core Fantasy

The fantasy: You are the quiet force behind every adventure.

Heroes come and go. Some die ignobly in forgotten tunnels. Some survive and grow into legends. The greatest of them eventually retire into permanent roles in your town's infrastructure — blacksmiths, guards, trainers, and specialists that support future generations of adventurers.

You, the Shopkeeper:
- Recruit expendable heroes
- Equip them from your limited, hand-curated shop inventory
- Send them into corrupted regions to push back the darkness
- Bring back resources to grow the town and unlock new options
- Decide who becomes a **Legacy Hero** and what role they serve long-term

You are not the warrior — you **empower** them.

## 2.2 Tone & Aesthetic

- **Cozy grim-fantasy** — think warm lantern-lit town interiors contrasted with ominous corrupted forests and ruins
- The world is dangerous but not hopeless
- Humor and charm exist in the personalities of heroes, townfolk, and events, even while the stakes remain high

## 2.3 Design Pillars

1. **Town Growth ↔ Hero Power ↔ Region Cleanse**
   The stronger the town, the better gear you can offer. Better gear lets heroes cleanse deeper corruption. Cleansed regions unlock more town growth.

2. **Persistent Progression with Disposable Heroes**
   Heroes are intentionally expendable, but their contributions matter:
   - Their deaths feed your **Book of the Dead**
   - Their successes can promote them into **Legacy roles**

3. **Item-Centric Progression**
   The backbone of progression is:
   Resource → Facility → Crafted Gear → Shop → Heroes → Adventure → More Resource

4. **Exploration as Risk/Reward Routing**
   Map choices matter. The player picks routes through combat, events, resources, and corruption risk — not just blindly marching forward.

---

# 3. World Structure & Regions

## 3.1 Regions Overview

The world is divided into **7 major regions**, each with:
- A unique biome
- A distinct corruption "flavor"
- Unique resource distributions
- Region-specific **legendary materials**
- A major **regional boss** whose defeat partially purifies the land

### Final Region Names (Canonical)

| Region | Name | Theme |
|--------|------|-------|
| 1 | **Forest Haven** | Ancient forest, natural magic |
| 2 | **The Fungalmire** | Fungal forest, spores, bioluminescence |
| 3 | **The Sunken Strand** | Coastal ruins, shifting tides |
| 4 | **Ashen Horizons** | Scorched sands, volcanic ridges |
| 5 | **Starfall Expanse** | Crystal groves, arcane influences |
| 6 | **The Necropolis** | Bone, grave-dust, forbidden magic |
| 7 | **Final Realm** | Collapsing reality, void fissures |

### Region Unlock Sequence

Regions unlock in a mostly linear fashion:
1. Forest Haven (starter)
2. The Fungalmire
3. The Sunken Strand → **Town Destruction Event begins**
4. Ashen Horizons (post-destruction trigger)
5. Starfall Expanse
6. The Necropolis
7. Final Realm (endgame boss)

## 3.2 Town Structure Per Region

Each region (except 1 and 7) contains **two towns**:
- **Town A** → Unlocks a **new race**
- **Town B** → Unlocks **two new classes**

**Region 1** has two starter towns introducing the foundational races and classes.
**Region 7** has a special foothold town/ritual nexus structure.

## 3.3 Town Destruction Timeline (Tier-Down Model)

After completing certain regions, a scripted event reduces towns in earlier regions:

| Trigger | Effect |
|---------|--------|
| Complete Region 3 | A random Region 1 town has all buildings reset to **Tier 1** |
| Complete Region 4 | A random Region 2 town is reduced to **Tier 2** baseline |
| Complete Region 5 | A random Region 3 town is reduced to **Tier 3** baseline |

**Important Rules:**
- Only these scripted events can destroy/reduce a town entirely
- Regular failed defenses tier down buildings by 1 but **never below Tier 1**
- Towns remain rebuildable and functional after tier-down

## 3.4 Regional Boons

When **both towns** in a region are operational (all buildings at Tier 1+), the region grants passive boons:

| Region | Combat Boon | Gathering Boon |
|--------|-------------|----------------|
| Forest Haven | +X% Max HP | +X% Wood yield |
| The Fungalmire | +X% Regeneration | +X% Herb yield |
| The Sunken Strand | +X% Dodge/Evasion | +X% Fishing yield |
| Ashen Horizons | +X% Fire Resistance | +X% Ore quality |
| Starfall Expanse | +X% Mana | +X% Crystal yield |
| The Necropolis | +X% Corruption Resistance | +X% Soul resources |
| Final Realm | +X% All Stats | None |

*X = total building levels across both towns in that region*

**Boon Reduction:** Town destruction reduces boon power proportionally.

## 3.5 Regional Legendary Materials

Each region has at least one unique legendary material:

- **Forest Haven:** Verdant Resin (T3)
- **The Fungalmire:** Biolum Essence
- **The Sunken Strand:** Stormglass Fragment
- **Ashen Horizons:** Molten Core
- **Starfall Expanse:** Starfall Core Fragment
- **The Necropolis:** Wailing Shard, Soul Ore, Spectral Logs, Deadman's Grass
- **Final Realm:** Void Crystal, Fractured Soulglass, Primordial Essence

Legendary materials are **not purchasable**, only earned from:
- Boss rewards
- High-tier corruption nodes
- Rare late-game events

## 3.6 Fog-of-War & Race Vision

Dungeon/adventure maps are node-based with fog-of-war:
- Party reveals adjacent nodes by default
- Certain races offer vision bonuses:
  - **Elves** have **Keen Sight** → reveal +1 additional node in all directions
- Corruption trails are shown visually, indicating where corruption has already spread or may spread next

---

# 4. Core Gameplay Loop

## 4.1 Macro Loop

1. **Prepare Town**
   - Choose which facilities produce items
   - Assign facility shop slots (which item categories are allowed to appear)
   - Ensure enough resources are in Storage to support crafting
   - Use refinement and socketing (if unlocked) to improve gear
   - Decide which heroes to hire/keep
   - Allocate **insurance slots** for high-value items

2. **Select Party & Equipment**
   - Shopkeeper chooses a party within current **Shop Level** capacity
     - Early: 3 heroes max
     - Later: up to 5–6 heroes
   - Equip heroes: Head / Chest / Legs / Weapons / Off-hands / Accessories
   - Assign a **backpack** to each hero (small/medium/large)
   - Choose food, potions, and tools

3. **Adventure Out**
   - Enter an adventure map in the chosen region
   - Follow branching node paths: Combat nodes, Resource rooms, Events, Rest rooms, Boss node
   - The Shopkeeper does not appear on the battlefield but serves as the abstract "inventory brain"

4. **Face Boss**
   - Multi-phase boss battle, often with unique tile patterns and corruption behavior
   - Success: Legendary materials, high-tier resources, blueprint fragments
   - Failure: Party wipe → only insured items survive; gold may be partially salvaged if a Bank exists

5. **Return to Town**
   - All materials deposited into **Shopkeeper Storage** (global, shared across all towns)
   - Facilities consume resources on the next prep phase to refresh the shop's stock
   - Town upgrades may be constructed

6. **Repeat in Next Region / Next Run**

## 4.2 Node Types

### Combat Node
- Standard monster encounter
- Chance for monster part drops and gold
- Chance for background resource nodes to appear (clickable after combat)

### Resource Room
- Focused on environmental resources: Ore veins, Logging spots, Herb patches
- **Requires correct tools:**
  - **Pickaxe** for ore
  - **Hatchet** for wood
  - **Herb Pouch** for herbs
  - **Fishing Pole** for fish
- Yields a small number of resources, with a small chance of higher-tier resources

### Event Room
- Narrative or mechanical choice events
- Lost traveler, strange merchant, spirit encounters, NPC requests
- No skill checks; outcomes are based on player choice and risk tolerance

### Rest Room
- Appears every 4–5 rooms, never back-to-back
- Allows: Healing, Food buffs, Potion usage, **Field Artificer** crafting
- Pre-boss rest room is guaranteed

### Boss Room
- Fixed at the end of each major route
- Multi-phase encounter tied to the region's corruption theme

---

# 5. Town Management & Facilities

## 5.1 Town Growth Over Time

The town progresses through several phases:

**Early (Regions 1–3)**
- Core facilities only: Blacksmith, Leatherworker, Woodsman, Chef, Alchemist
- Facilities can reach T4 in these early towns

**Mid (Post Region 3: Regions 4–5)**
- Town layouts become larger
- **Guard Yard** unlocked for Town Defense
- **Jeweler** unlocked for socketing and gem crafting

**Late (Region 6+)**
- Specialized late-game facilities: Necropolis Forge, Glassworks

## 5.2 Facility Tiers & Services

All crafting facilities follow a common tier pattern:

| Tier | Features |
|------|----------|
| **T1** | Basic production, simple items from common resources |
| **T2** | Better stat ranges, slightly more efficient, expanded variety |
| **T3** | **Refinement Unlock** — incremental boosting with risk |
| **T4** | **Legendary & Blueprint Crafting** — use legendary materials |

> **Godot Implementation Note:** Implement facilities as data-driven processors, each with a config for inputs, outputs, and tier-based rule sets.

## 5.3 Facility Types (Core)

### Blacksmith
- **Produces:** weapons, heavy armor, shields, metal tools (pickaxe)
- **Uses:** ore resources
- **Refinement:** improves physical stats, durability, and special weapon traits
- **Legendary:** region-themed legendary weapons and armor

### Leatherworker
- **Produces:** light armor, medium armor, some accessories
- **Uses:** monster hides, leather-related monster parts
- **Refinement:** dodge, mobility, and utility stats
- **Legendary:** nimble armor sets, dodge-heavy passives

### Woodsman
- **Produces:** bows, staves, wooden shields, woodcutting hatchets
- **Uses:** wood resources
- **Refinement:** ranged damage, accuracy
- **Legendary:** elemental bows, powerful staves

### Chef
- **Produces:** food items
- **Uses:** herbs + monster meats (including **Meaty Bone**)
- **Effects:** Baseline healing; higher tiers provide long-lasting buffs

### Alchemist
- **Produces:** potions and multi-dose flasks
- **Uses:** herbs + glass (later, via Glassworks)
- **Effects:** Basic potions (heals, buffs); high tiers (potent effects, multiple doses)

### Guard Yard (Unlocked Post-Region 3)
- **Unique global facility** for Town Defense
- Provides defense grid, hero placement slots, defense treasury
- Heroes placed here are removed from adventuring roster but cannot die in defense

## 5.4 Jeweler (Region 5 Unlock)

- **Produces:** gems, socketed items, gem fusions
- **Gem rarities:** Common → Uncommon → Rare → Epic → Legendary

| Tier | Services |
|------|----------|
| T1 | Basic socketing, 1-socket gear |
| T2 | More sockets, mid-tier gems, minor polishing |
| T3 | Gem fusion and refinement with risk |
| T4 | Legendary gemworking; unique gem abilities |

## 5.5 Legacy Heroes as Workers

Heroes that become **Legacy** can be assigned as workers:
- **At facilities:** Improve production quality, reduce crafting time, add thematic bonuses
- **At Guard Yard:** Improve Town Defense success, provide passive buffs

Legacy heroes can be **recalled** for adventuring:
- They temporarily leave their job
- Their job slot becomes empty until replaced or they return

## 5.6 Starter Town Kit

Only Town 1 starts empty. Before moving to a new region, players gather materials to build the **Starter Town Kit**, which auto-constructs in any new town:
- Training Hall (T1)
- Blacksmith (T1)
- Leatherworker (T1)
- Alchemist (T1)
- Storage
- Housing (T1)
- Shop (fed by facilities)

This ensures no rebuild grind and clean pacing.

---

# 6. Combat System

## 6.1 Combat Model

Shops & Shadows uses a **strict turn-based combat system** built around a tactical grid. Each unit (hero or enemy) takes one action per turn in an ordered sequence.

**Key Principles:**
- No real-time timers
- Cooldowns are tracked in turns, not seconds
- **No ultimate abilities** — each hero uses: Basic Attack + Class Ability A + Class Ability B + Weapon Ability + Passives

## 6.2 Battlefield Grid

The battlefield is a **tile grid**:
- Early game: **4 columns × 2 rows** (front/back)
- After Region 3: **4 columns × 3 rows** for both sides

Heroes and enemies occupy distinct tiles. Targeting is based on rows, columns, and area patterns (line, diamond, cross, etc.).

## 6.3 Turn Structure

Combat proceeds in discrete rounds:

1. **Status Tick Phase**
   - Apply damage-over-time (burn, poison, bleed, etc.)
   - Apply heal-over-time effects
   - Decay temporary shields and round-based buffs/debuffs

2. **KO & Death Check**
   - Units reduced to 0 HP are removed from combat
   - Special survival effects resolve here

3. **Initiative Calculation**
   - Determine action order based on: Class, Weapon type, Initiative modifiers

4. **Action Phase**
   - Units act one at a time in initiative order
   - On their turn, a unit chooses: Basic Attack, Class Ability A, Class Ability B, or Weapon Ability

5. **End-of-Round Triggers**
   - Any "at end of round" effects resolve
   - Turn counters for cooldowns and statuses decrement

## 6.4 Initiative Rules

Initiative is a simple ordering score:
- Each class has a base initiative band (Striker high, Defender low)
- Each weapon type modifies initiative (daggers > swords > hammers)
- Ties broken by: Lowest current HP (enemies) or left-to-right grid placement (heroes)

## 6.5 Tile Effects

Most tiles are **normal**. Some can be temporarily altered:
- **Burning** — damage over time
- **Blessed** — extra healing or defense
- **Sticky** — movement penalties
- **Poisoned** — poison damage and/or debuffs
- **Corrupted** — corruption-themed penalties (late-game only)

### Corruption Tile Timing

| Region | Corruption Tiles |
|--------|------------------|
| Regions 1–3 | **No corruption tiles** |
| Region 4 | Visual hints only; no tile effects |
| Region 5 | Event-based tile hazards |
| Region 6 | Active corruption tiles begin |
| Region 7 | Fully corrupted tile mechanics |

## 6.6 Ability Types (Per Hero)

Every hero's combat kit consists of:
1. **Basic Attack** (from equipped weapon) — always available, no cooldown
2. **Class Ability A** — core tactical skill, 1–3 turn cooldown
3. **Class Ability B** — higher impact skill, 2–5 turn cooldown
4. **Weapon Ability** — granted by weapon type, 2–4 turn cooldown
5. **2 Class Passives** — always on
6. **Race Passives** — always on, if any

## 6.7 Weapon Abilities

Each weapon type grants a unique ability:

| Weapon | Ability | Effect |
|--------|---------|--------|
| Sword | Cleave | Hit target + adjacent units |
| Dagger | Quick Strike | High-initiative attack, may inflict bleed |
| Hammer | Crushing Blow | Heavy hit with stun chance |
| Axe | Sundering Chop | Hit + apply armor reduction |
| Bow | Power Shot | High-damage, ignores part of defense |
| Crossbow | Piercing Bolt | Line attack hitting multiple units |
| Throwing Knives | Blade Fan | Low damage spread across 2–3 enemies |
| Staff | Arcane Pulse | Magic AoE around target |
| Wand | Focus Beam | Concentrated magic hit |
| Tome | Spellweave | Buff that amplifies next class ability |

Weapon abilities make weapon choice tactically meaningful.

## 6.8 Status Effect System

Status effects follow a consistent structure:

**Damage-over-Time:**
- **Poison** (stacks)
- **Bleed** (stacks, often from physical abilities)
- **Burn** (stronger but refreshes rather than stacking)
- **Shock** (counts as DoT, triggers Overload at 3 stacks)

**Heal-over-Time:**
- **Regeneration** (flat heal at start of turn)

**Control:**
- **Slow** (initiative penalty)
- **Dazed** (skip next action, from Stormcaller Overload)
- **Stun** (lose one action) — used sparingly

**Shields:**
- Temporary flat HP buffer that absorbs damage before HP

### Special Status: Doom (Countdown Execution)

**Doom is NOT a DoT** — it is a countdown-based execution effect:
- **Doom (X)** = number of turns before resolution
- At end of target's turn, Doom decreases by 1
- When Doom reaches 0: target takes **heavy true damage** (ignores armor, cannot crit)
- Applying Doom to a target with Doom increases countdown (delays but amplifies)
- UI: Clock icon showing turns remaining

## 6.9 Boss Fights

Bosses are:
- Multi-phase (70% HP → Phase 2, 40% HP → Phase 3)
- Often manipulate tiles (corrupted zones, hazards)
- May summon adds or alter turn order
- Have phase thresholds with telegraphed special moves

---

# 7. Items, Crafting, Refinements & Backpacks

## 7.1 Resource Tiers

**Universal Basic Materials (Global Drops):**
- Softwood (T1)
- Copper Ore (T1)
- Common Herb (unlocked with Alchemist)
- **Meaty Bone** — universal hybrid material for early upgrades, food, and low-tier facility needs

**Regional Materials (T2–T4):**
Each region provides unique woods, ores, herbs, foods, and specialty materials (see Section 18).

## 7.2 Tools

Tools gate resource collection:
- **Pickaxe** — required for ore nodes
- **Hatchet** — required for wood nodes
- **Herb Pouch** — required for herb nodes (stores 5-stacks)
- **Fishing Pole** — catches regional fish, rare treasure bottles

**Tool Rules:**
- Tools never break — only upgrade
- Starter tools given when building T1 facilities
- Higher tiers → more/better drops

## 7.3 Refinement System (T3 Facility Feature)

Refinement allows incremental upgrades with risk:

### Refinement Levels

| Levels | Risk | Effect |
|--------|------|--------|
| **1–4** | Safe | Always positive stat increase from chosen group |
| **5–8** | Risk | Positive increase + 5–20% chance of small negative side effect |
| **9–10** | Break Risk | 30%/50% chance of item destruction; survivors get strong stat increase |

### Stat Groups (Player Chooses One Per Item)

**Offense:** Damage, Speed, Crit Chance
**Defense:** Max HP, Physical Resistance, Magic Resistance, Block/Dodge
**Technique:** Cooldown Reduction, Mana Efficiency, Healing Received, Elemental proc chance

Each refinement selects **one random stat** from the chosen group to increase.

## 7.4 Legendary Crafting (T4)

Legendary items must be:
- Crafted at **T4 facilities** using legendary materials
- Each craft locks the facility's "legendary slot" for one expedition
- Produces a **random legendary** item within that facility's category

Legendary items:
- Have unique passives
- Are primary candidates for insurance
- Tie into region flavor

## 7.5 Facility Item Generation (Autocrafting)

**The player does NOT manually craft items.** Facilities auto-generate shop stock:

1. Player selects facility slots for the shop
2. Facility consumes: basic materials, region materials, (optional) specialty materials
3. Facility crafts 1 random item per slot
4. Item pulls from: facility's item list, region's passive pool, tier matching material quality

Higher-tier materials = better items and stronger passive rolls.

## 7.6 Backpacks & Inventory

**Heroes:**
- Small: 3 slots
- Medium: 4 slots
- Large: 6 slots (late-game)

**Shopkeeper:**
- Separate bag with 6–8 slots
- Primary resource collection buffer
- **Resources do NOT stack** — each occupies one slot

## 7.7 Insurance Slots

- Limited (2–4 based on upgrades)
- Mark items as protected from loss on party wipe
- Filled manually during prep/rest phases
- UI warns before big fights if high-value items are uninsured

---

# 8. Heroes (Races, Classes, Passives)

## 8.1 Hero Acquisition & Classes

### Early Game (Tutorial)
- Heroes have **no classes** initially
- Only Basic Attack, no abilities
- Tutorial dungeon teaches combat fundamentals

### After First Dungeon
- Player builds: Storage, Training Hall, basic facilities
- Training Hall sells starter **Class Books**

### Assigning Classes
- **Class Books** appear in the shop once their region unlocks them
- Class Books can **overwrite existing classes** with no penalty
- Class assignment costs gold, possibly some resources
- Hero retains: race, gear, and level

## 8.2 Races

### Starter Races (Region 1)

| Race | Identity | Racial Trait | Town Affinity |
|------|----------|--------------|---------------|
| **Human** | Flexible, adaptable | Versatile Learner: +10% XP | +2% worker speed |
| **Elf** | Agile, perceptive | Keen Sight: +1 fog reveal | Woodsman, Jeweler, Alchemist |
| **Dwarf** | Durable, stubborn | Deep Miner: +1 ore roll | Blacksmith bonuses |

### Midgame Races

| Region | Race | Racial Trait |
|--------|------|--------------|
| 2 | **Mossfolk** | Sporebond: +2% regen, weak poison resist, extra herb finds |
| 3 | **Tidelings** | Amphibious: immune to Wet penalties, +SPD on wet tiles |
| 4 | **Dragonkin** (Locked) | Scaled Hide / Embersoul: reduced large hit damage, fire affinity |
| 5 | **Crystalborn** (Locked) | Refraction Field / Resonance Echo: magic resist, echo effect |
| 6 | **Undead** | Deathless: immune to poison/bleed/sleep, reduced food healing |
| 7 | **Voidwalkers** (Locked) | Voidborne / Flicker Step: corruption immunity, avoid fatal hit |

**Locked Races:** Dragonkin (Region 4), Crystalborn (Region 5), Voidwalkers (Region 7) are region-locked until their towns are reached.

## 8.3 Race + Class Non-Restrictive Synergy

No race restricts any class. Instead, small synergy bonuses exist:
- Elf Ranger: +1 Accuracy
- Dwarf Warrior: +1 Armor
- Mossfolk Druid: +1 Regen

These are flavorful, non-punishing bonuses. **No stat-based synergy bonuses** — only unique mechanical traits per race.

## 8.4 Total Classes: 16

| Region | Classes Unlocked |
|--------|------------------|
| Region 1 | Defender, Warden, Striker (3 starters) |
| Region 2 | Druid, Fungal Berserker |
| Region 3 | Tidechaser, Stormcaller |
| Region 4 | Pyrewarden, Ashblade |
| Region 5 | Prism Sentinel, Prism Lancer |
| Region 6 | Dark Channeler, Lich |
| Region 7 | Voidwalker, Void Herald |

**Total: 16 Classes**

---

# 9. Monsters & Corruption

## 9.1 Monster Family Framework

Monsters are grouped into families sharing visual identity, behavior, and (from Region 2 onward) a family-wide passive trait.

### Complexity Ramp

| Region | Complexity |
|--------|------------|
| Region 1 | No family passives, no active abilities. Basic attacks only. |
| Regions 2–3 | Family passives introduced. Still only basic-attack + passive triggers. |
| Regions 4–7 | Monsters may have one active ability (simple cooldown) + family passive |

## 9.2 Monster Roles & AI Types

**Roles:**
- **Tank:** High HP/DEF, slow, takes hits
- **Striker:** High ATK/SPD, fragile, targets backliners
- **Support:** Buffs/debuffs, lower damage
- **Artillery:** Ranged damage, prefers back row
- **Disruptor:** Position manipulation, push/pull

**AI Types:**
- Frontliner AI: Target nearest enemy in front rows
- Flanker AI: Prefer lowest-DEF or lowest-HP targets
- Ranged AI: Stay on back tiles, target low-HP or random
- Support AI: Buff allies or debuff dangerous heroes

## 9.3 Region Monster Families

### Region 1 — Forest Haven (No passives/abilities)
- Forest Wolves (Striker)
- Rootkin Sprites (Light support)
- Moss Trolls (Tank)
- Bandit Rabble (Basic strikers)

### Region 2 — The Fungalmire (Family passives only)
- Sporekin Shamblers (Sporeburst: on death, poison adjacent heroes)
- Rotcap Myconids (Rot-Soaked Hide: reduced physical, increased fire damage)
- Bloom Giants (Tank, slow, high HP)

### Region 3 — The Sunken Strand (Passives + tile interactions)
- Tidewalkers (Amphibious: bonus SPD/Dodge on wet tiles)
- Crustacean Brutes (Tank, physical armor)
- Drowned Spirits (Drowned Echo: on death, debuff attacker)

### Region 4 — Ashen Horizons (Passives + 1 ability)
- Ember Drakes (Artillery, fire breath)
- Lava Golems (Tank, fire retaliate)
- Ash Wraiths (Support caster, fire/curse)

### Region 5 — Starfall Expanse (Passives + ability)
- Crystal Wraiths
- Reality Phantoms
- Starfall Beasts

### Region 6 — The Necropolis (Heavy passives + ability)
- Bone Legionnaires (Reanimate chance)
- Ghoul Stalkers (Bleed on hit)
- Wraith Choirs (Magic resist + terror)
- Gravefiends

### Region 7 — Final Realm
- Corruption avatars and mixed-corruption monsters
- Boss/elite heavy; ability use more frequent (still capped at 1 active per creature)

## 9.4 Monster Drops & Resource Families

| Monster Type | Drops | Facility Use |
|--------------|-------|--------------|
| Beasts | Hides, meat, monster parts | Leatherworker, Chef |
| Fungi/Myconids | Spores, fungal caps | Alchemist, Chef |
| Constructs/Elementals | Ore fragments, cores | Blacksmith |
| Undead | Soul shards, bone dust | Necropolis facilities |
| Arcane Beings | Crystal shards, stardust | Starfall crafting |

---

# 10. UI / UX

## 10.1 Combat UI

**Hero Panels:**
- Show HP, mana, buffs/debuffs
- Expandable to show abilities, items, passives, gear summary

**Enemy Intent Indicators:**
- Show intended target and attack type
- Helps tactical decision-making

**Tile Highlighting:**
- Hover displays tile effect and duration

**Boss UI:**
- HP bar with phase indicators

**Damage Numbers (Color-Coded):**
- White: Physical
- Blue: Magic
- Yellow: Crit
- Red outline: Lethal hit
- Purple: Corruption-based

**Status Icons:**
- Doom uses **clock icon** showing turns remaining (distinct from DoTs)

## 10.2 Adventure Map UI

- Node map with fog-of-war
- Clearly marked: Combat, Events, Resources, Rest rooms, Boss
- Corruption trails: Visual indicator of spread
- Background resource nodes: Clickable after battles

## 10.3 Town & Shop UI

**Facility Slot Assignment Panel:**
- Choose which facilities fill which shop slots
- Shows resource consumption preview and expected item categories

**Shop Inventory View:**
- Items displayed with: Name, Rarity color, Short stat summary, Socket/refinement icons

**Storage UI:**
- Lists resources (no stacking — meaningful space management)
- Shows legendary material count prominently
- **Global shared storage** — not per-town

---

# 11. Economy & Resource Flow

## 11.1 Gold (Global Currency)

**Gold is a single, shared global resource.**

**Earned from:** Combat encounters, Events, Boss fights, Town Defense victories, Salvaging items
**Spent on:** Shop items, Facility upgrades, Tools, Backpacks, Town services, Refinement, Blueprint crafting

**Global Gold Rules:**
- All gold earned flows into the global pool automatically
- There is no per-hero gold tracking
- Defense gold is NOT a separate storage — it flows directly to global gold
- Shop purchases draw from global gold, not hero-specific gold
- Hero rotation does not affect economic access

**Hero death:**
- Gold is never lost on hero death (it's already in global pool)
- Bank facility provides other economic benefits (future expansion)

## 11.2 Resource Flow

1. Heroes and Shopkeeper gather resources on adventures
2. On successful return: Resources move into **Shared Global Storage**
3. Facilities consume resources each "cycle" to produce items
4. Items appear in the Shop for purchase
5. Heroes equip items → undertake new adventures → more resources

**Storage Rules:**
- **Shopkeeper storage = main resource hub**
- Resources deposited automatically at expedition end
- Background-click bonus resources allowed
- Manual facility resource loading (no auto-pull)

---

# 12. Glossary & Developer Notes

| Term | Definition |
|------|------------|
| **Shopkeeper** | Player avatar; manages town, hires, and equips heroes |
| **Facility** | Production building with tiers and services |
| **Refinement** | Risk-based item stat improvement (T3+) |
| **Legendary Material** | Region-locked, ultra-rare crafting material |
| **Insurance Slot** | Protects items from loss on party wipe |
| **Legacy Hero** | Hero elevated to permanent town role |
| **Corruption Node** | Map node with increased difficulty and rewards |
| **Blueprint** | Special recipe for unique items |
| **Backpack** | Hero-specific inventory extension |
| **Class Book** | Item that assigns/overwrites a hero's class |
| **Meaty Bone** | Universal hybrid material (replaces "Monster Bones") |
| **Doom** | Countdown-based execution effect (NOT a DoT) |

> **Godot Implementation Note:** Represent heroes, items, facilities, regions, and nodes via data assets (JSON or Godot Resources) to allow tool pipelines to auto-modify content.

---

# 13. Production Roadmap & Development Strategy

## 13.1 Production Philosophy

**Data-Driven First:**
- All gameplay values from data (JSON, .tres files), not hard-coded logic
- Claude can modify or generate content safely

**AI-Augmented Development Workflow:**
- Claude handles: GDScript, Scene templates, Resource file generation, Debugging, Refactoring, Balancing
- You make design decisions — Claude implements them

**Chunk-Based Development:**
- Everything built in small, testable chunks
- Prevents burnout and reduces implementation errors

## 13.2 Development Phases

### Phase 0 — Foundations
- Install Godot 4.x and set up project
- Establish folder structure and naming conventions
- Define JSON schemas
- Create test scenes

### Phase 1 — Core Systems Implementation
- Hero + Monster entity classes
- Stats component, Ability resolver, Turn Manager
- Combat grid, Map system (fog-of-war, branching nodes)
- Town v1 (storage, shop), Tools + resource gathering

### Phase 2 — Core Gameplay Features
- Facilities T1–T3, Refinement system
- Consumables/flasks, Backpacks
- Boss fights (multi-phase), Classes (starter set)
- Legacy system (v1), Town defense (prototype)

### Phase 3 — Content Expansion
- Regions 3–5
- Town destruction events
- Jeweler system, Socket/gem system
- Legendary/Blueprint crafting
- More classes, races, special encounters

### Phase 4 — Endgame & Final Regions
- Region 6 (Necropolis), Region 7 (Final Realm)
- Advanced corruption mechanics
- Final boss, Late-game legacy roles
- Replay/challenge modifiers

### Phase 5 — Polish & QA
- Balancing, UI polish, Sound & VFX
- Accessibility options, Optimization, Stability testing

---

# 14. Godot Data Architecture

## 14.1 Project Folder Structure

```
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
```

## 14.2 Core Managers (Autoload Singletons)

| Manager | Responsibility |
|---------|----------------|
| **DataManager** | Loads JSON/.tres data, lookup tables, reference validation |
| **TurnManager** | Combat round order, initiative, turn transitions, end-of-turn effects |
| **TileManager** | Battlefield tile states (Burning, Corrupted, etc.), duration tracking |
| **CombatManager** | High-level combat flow, spawn, victory/defeat, loot |
| **FacilityManager** | Crafting, refinement, legendary crafting, worker bonuses |
| **MapManager** | Node traversal, fog-of-war, corruption spread, events |

## 14.3 Data Schemas

### Hero Schema
```json
{
  "id": "hero_01",
  "name": "Elin",
  "race": "Elf",
  "class": "Striker",
  "stats": {
    "hp": 100, "mana": 30, "atk": 12, "def": 6, "spd": 5,
    "res": { "physical": 0, "magic": 0, "corruption": 0 }
  },
  "passives": ["keen_sight"],
  "abilities": ["twin_strike", "shadowstep"],
  "inventory": ["starter_dagger"],
  "backpack_size": 3,
  "legacy": false
}
```

### Monster Schema
```json
{
  "monster_id": "sporekin_shambler_t1",
  "family_id": "sporekin",
  "region_id": "fungalmire",
  "tier": "normal",
  "role": "tank",
  "base_stats": { "hp": 40, "atk": 6, "def": 5, "spd": 3, "mag": 2, "res": 3 },
  "behavior_tags": ["frontliner"],
  "family_passive_id": "sporeburst",
  "active_ability_id": null,
  "drops": {
    "primary": ["fungal_cap", "spore_sac"],
    "secondary": ["rare_spore_bloom"]
  }
}
```

### Ability Schema
```json
{
  "id": "guardian_challenge",
  "source": "class_a",
  "type": "active",
  "cooldown": 2,
  "targeting": "single_enemy",
  "effect": {
    "damage": "light_physical",
    "status": "taunt",
    "status_duration": 1
  },
  "additional": { "self_armor": 2, "armor_duration": 1 },
  "tags": ["Physical", "Control", "Tank"]
}
```

---

# 15. Races & Classes Framework

## 15.1 System Goals

- **Player Agency:** Races and classes are player-driven unlocks
- **Clarity & Identity:** Distinct thematic and mechanical roles
- **Thematic Regional Progression:** New unlocks match region environments
- **Non-Restrictive Synergy:** Races don't restrict class options
- **Hero Training Economy:** Class books appear in shop, not facilities (exception: Lich ritual)

## 15.2 Race Introduction Structure

| Region | Race Unlock |
|--------|-------------|
| 1 | Human, Elf, Dwarf (starter trio) |
| 2 | Mossfolk |
| 3 | Tidelings |
| 4 | Dragonkin (locked until Region 4) |
| 5 | Crystalborn (locked until Region 5) |
| 6 | Undead |
| 7 | Voidwalkers (locked until Region 7) |

**Total Races: 9**

## 15.3 Class Introduction Structure

| Region | Classes |
|--------|---------|
| 1 | Defender, Warden, Striker |
| 2 | Druid, Fungal Berserker |
| 3 | Tidechaser, Stormcaller |
| 4 | Pyrewarden, Ashblade |
| 5 | Prism Sentinel, Prism Lancer |
| 6 | Dark Channeler, Lich |
| 7 | Voidwalker, Void Herald |

**Total Classes: 16**

## 15.4 Region Unlock Flow

- **Town A** = Race unlock
- **Town B** = 2-Class Pair unlock

**Class Book Rules:**
- Class Books can **overwrite existing class** assignments with no penalty
- Books appear in shop after region unlock
- Lich requires special sacrifice ritual (see Section 24.13)

---

# 16. Regions Overview

## 16.1 Region 1 — Forest Haven

**Biome:** Ancient forest, natural magic, cozy and calm

**Town A — Greenroot Village (Starter Town)**
- Race introduction: Human, Elf, Dwarf
- Tutorial town, starts with no buildings

**Town B — Timberfall (Starter Class Town)**
- Unlocks: Defender, Warden, Striker
- Introduces crafting via basic facilities

**Enemy Families:** Forest Wolves, Rootkin Sprites, Moss Trolls, Bandit Rabble

**Boss:** The Thorn-Ent

**Regional Boon:** Combat +X% Max HP, Gathering +X% Wood yield

**Corruption:** Dormant Nature Corruption (late/postgame only)

---

## 16.2 Region 2 — The Fungalmire

**Biome:** Deep fungal forest, spores, bioluminescence

**Town A — SproutRest**
- Race unlock: Mossfolk

**Town B — Magic Caps Rest**
- Classes: Druid, Fungal Berserker

**Enemy Families:** Sporekin Shamblers, Rotcap Myconids, Bloom Giants

**Boss:** The Spiral Mycelium

**Regional Boon:** Combat +X% Regeneration, Gathering +X% Herb yield

**Corruption:** Spore Corruption (dormant until late game)

---

## 16.3 Region 3 — The Sunken Strand

**Biome:** Fog-soaked coastal ruins, shifting tides

**Town A — Shelldrift Harbor**
- Race unlock: Tidelings

**Town B — Mistwhisper Shoals**
- Classes: Tidechaser, Stormcaller

**Enemy Families:** Tidewalkers, Crustacean Brutes, Drowned Spirits

**Boss:** The Tide Sovereign

**Regional Boon:** Combat +X% Dodge/Evasion, Gathering +X% Fishing yield

**Critical Event:** After Region 3 completion:
- A random Region 1 town is destroyed (buildings reset to Tier 1)
- Town Defense system activates globally

---

## 16.4 Region 4 — Ashen Horizons

**Biome:** Scorched sands, volcanic ridges, firestorms

**Town A** — Race unlock: **Dragonkin** (locked until this region)

**Town B** — Classes: Pyrewarden, Ashblade

**Enemy Families:** Ember Drakes, Lava Golems, Ash Wraiths, Scorpion Titans

**Boss:** The Cinder Monarch

**Regional Boon:** Combat +X% Fire Resistance, Gathering +X% Ore quality

**Corruption:** Flame Corruption (not active until late/postgame)

**Post-Completion:** Region 2 town reduced to Tier 2

---

## 16.5 Region 5 — Starfall Expanse

**Biome:** Crystal groves, floating stones, distorted reality

**Town A** — Race unlock: **Crystalborn** (locked until this region)

**Town B** — Classes: Prism Sentinel, Prism Lancer

**Enemy Families:** Reality Phantoms, Crystal Wraiths, Starfall Beasts

**Boss:** The Shattered Oracle

**Regional Boon:** Combat +X% Mana, Gathering +X% Crystal yield

**Corruption:** Arcane Corruption (late/postgame)

**Post-Completion:** Region 3 town reduced to Tier 3

---

## 16.6 Region 6 — The Necropolis

**Biome:** Bone, grave-dust, lingering souls, forbidden magic

**Town A** — Race unlock: Undead

**Town B** — Classes: Dark Channeler, Lich (special ritual)

**Enemy Families:** Bone Legionnaires, Ghoul Stalkers, Wraith Choirs, Death Knights, Gravefiends

**Boss:** The Ossuary King

**Regional Boon:** Combat +X% Corruption Resistance, Gathering +X% Soul resources

**Corruption:** Death Corruption (active)

---

## 16.7 Region 7 — Final Realm

**Biome:** Collapsing reality, void fissures, endgame difficulty

**Town Structure:** Special foothold/ritual nexus (single town)

**Classes:** Voidwalker, Void Herald

**Race:** **Voidwalkers** (locked until this region)

**Boss:** The Prime Corruptor

**Regional Boon:** Combat +X% All Stats, Gathering: None

---

# 17. Monster Family Framework

## 17.1 Design Goals

- **Clarity:** Players can glance at a monster and understand its role
- **Thematic Consistency:** Families reinforce region themes
- **Scalable Complexity:** Early regions simple, later regions add depth
- **Data-Driven:** Easy to describe in JSON for Godot/Claude
- **Reward Clarity:** Each family ties to specific resource types

## 17.2 Monster Family Data Fields

```json
{
  "family_id": "sporekin",
  "display_name": "Sporekin",
  "region_id": "fungalmire",
  "roles": ["tank", "striker"],
  "family_passive_id": "sporeburst",
  "primary_drops": ["fungal_cap"],
  "secondary_drops": ["rare_spore_bloom"],
  "notes": "Explodes in a small spore cloud on death."
}
```

## 17.3 Monster Tiers & Scaling

- **Normal:** Baseline stats
- **Elite:** ~+30–50% HP/ATK, better SPD/RES
- **Champion:** Rare elite with boosted passive
- **Boss:** Unique, defined separately

Scaling factors: Region modifier, Floor depth, Difficulty mode

---

# 18. Resource & Facility Input System

## 18.1 Universal Basic Materials (Global Drops)

- **Softwood** (T1)
- **Copper Ore** (T1)
- **Common Herb** (unlocked with Alchemist)
- **Meaty Bone** — universal hybrid material

## 18.2 Regional Materials

### Region 1 — Forest Haven
- **Wood:** Ironbark (T2), Verdantwood (T3)
- **Ore:** Greenstone Ore (T2)
- **Foods:** Wolf Meat, Boar Meat, Forest Roots, Berries
- **Specialty:** Verdant Resin (T3)
- **Passive Pool:** Nature Harmony, Forest Swiftness, Thorn Guard

### Region 2 — The Fungalmire
- **Wood:** Spiritbark (T2), Glowroot Timber (T3)
- **Ore:** Mycelium-Touched Ore (T2), Rot-Iron (T3)
- **Herbs:** Fungalcaps, Glowshrooms, Rotcap Spores
- **Specialty:** Biolum Essence
- **Passive Pool:** Sporeburst Edge, Glowguard, Rot-Flesh Armor

### Region 3 — The Sunken Strand
- **Wood:** Kelpwood
- **Ore:** Tide-Tempered Ore (T2), Stormglass Mineral (T3)
- **Herbs:** Tide Moss, Shock Kelp
- **Foods:** Crustacean Meat, Electric Eel Strips
- **Specialty:** Stormglass Fragment
- **Passive Pool:** Amphibious Blessing, Stormcharged, Wet-Skin Resistance

### Region 4 — Ashen Horizons
- **Wood:** Charwood
- **Ore:** Flame-Touched Ore (T3), Obsidian Glass (T2), Molten Ore (T4)
- **Herbs:** Ash Bloom, Flare Petals
- **Foods:** Fire Peppers, Charred Meat Cuts
- **Specialty:** Molten Core
- **Passive Pool:** Fireblood, Molten Edge, Smoldering Shield

### Region 5 — Starfall Expanse
- **Wood:** Starseed Timber
- **Ore:** Astral Ore, Crystal Shards
- **Herbs:** Dream Petal, Reality Root
- **Foods:** Astral Fruit, Floating Lotus
- **Specialty:** Starfall Core Fragment
- **Passive Pool:** Reality Bend, Astral Shield, Voidtouch

### Region 6 — The Necropolis
- **Wood:** Soulwood
- **Ore:** Grave Iron, Soul-Infused Alloy
- **Herbs:** Witherbloom, Deathroot
- **Foods:** Bone Broth, Ghast Mush
- **Specialty:** Wailing Shard
- **Passive Pool:** Lifedrain, Necrotic Vigor, Deathward

### Region 7 — Final Realm
- **Materials:** Void Crystal, Fractured Soulglass, Primordial Essence
- **Passive Pool:** Worldbreaker, Corruption Shield, Reality Warp

## 18.3 Tools (Finalized)

| Tool | Function | Notes |
|------|----------|-------|
| Hatchet | Harvests all wood nodes | Higher tiers → better drops |
| Pickaxe | Mines ore, crystals, volcanic glass | Tier-gated for high-end materials |
| Herb Pouch | Gathers herbs, fungi, magical plants | Stores 5-stacks |
| Fishing Pole | Catches regional fish | Rarity-based loot, rare treasure bottles |

**Tools never break — only upgrade.**

## 18.4 Field Artificer Resource Privilege

The Field Artificer has special carry rules:
- Can retain 1–2 special materials AND 1–2 crafted items
- BUT only if they return to town alive
- Their kept items do not enter town storage
- If they die → everything lost as normal

**Field Artificer Resource Inputs (NOT herbs):**
- Metals/ores
- Leather/hardened hides
- Monster parts (claws, teeth, scales)
- Crystals/glass shards
- Mechanical scrap/"gear fragments"

---

# 19. Town Defense System

## 19.1 Activation

Town Defense begins **after Region 3 completion**.

In NG+ (postgame cycles): Town Defense activates after **Region 1**.

## 19.2 Attack Triggers

Whenever the player returns from an expedition:
1. Select threatened region (based on story progression)
2. Random town in that region is chosen
3. Attack chance roll: **Base 35%**, +5% per win (max 60%)
4. If both towns have ALL buildings at Tier 1: chance becomes **10%**

**Attack frequency does NOT escalate per region — only enemy strength scales.**

## 19.3 The Guard Yard

The Guard Yard is a **unique global facility** providing:
- Defense Grid (3×2 formation: 3 Defensive slots, 3 Offensive slots)
- Hero placement with Town Defense Bonuses
- Battle preview and auto-resolve toggle
- Gold rewards flow directly to global gold pool

**Important:** Heroes in Guard Yard:
- Are removed from adventuring roster
- **Cannot die during defense**
- Gain passive XP for each defense
- Can be replaced at any time

### Guard Yard Tier Unlocks

| Tier | Defensive Slots | Offensive Slots |
|------|-----------------|-----------------|
| T1 | 1 | 1 |
| T2 | 2 | 1 |
| T3 | 2 | 2 |
| T4 | 3 | 3 |

## 19.4 Town Defense Bonuses (Defense Battles Only)

| Tier | Bonuses |
|------|---------|
| T1 | +5% Max HP, +5% DEF |
| T2 | +10% Max HP, +10% DEF, +5% All Resistances |
| T3 | +15% Max HP, +10% DEF, +10% All Resistances, +5% Damage |
| T4 | +20% Max HP, +15% DEF, +15% All Resistances, +10% Damage |

## 19.5 Defense Outcomes

### Victory
- Town survives (no building damage)
- Gold reward added to global gold pool + XP for heroes
- Attack chance increases by +5% (max 60%)

### Defeat (Safe Loss)
- One random building tiers down by 1 (but **never below Tier 1**)
- Attack chance resets to 35%
- If BOTH towns reach all Tier 1: attack chance becomes 10%
- **Heroes still survive** — this is pressure, not punishment

## 19.6 Defense Rewards

**Defense Victory Gold:**
- Gold earned from defense victories flows directly into the **global gold pool**
- There is no separate "Defense Treasury" — all gold is unified
- Defense gold can be spent on any purchase (shop, facilities, refinement)

**Defense XP:**
- Heroes assigned to defense gain XP for each battle
- XP scales with defense difficulty

## 19.7 Threat Progression

| Trigger | Threatened Region | Enemy Strength |
|---------|-------------------|----------------|
| After R3 | Region 1 | Early enemies, scaled |
| After R4 | Region 2 | Stronger fungal enemies |
| After R5 | Region 3 | Tide monsters with stronger passives |
| After R6 | Region 4 | Fire/Arcane threats |
| After R7 | Region 5–6 | Extremely strong mixed corruption |

---

# 20. Dungeon Node & Multi-Floor System

## 20.1 Dungeon Structure

Each Town Dungeon contains up to four floors, based on Dungeon Facility Tier:

| Facility Tier | Floors Available |
|---------------|------------------|
| T1 | Floor 1 |
| T2 | Floors 1–2 |
| T3 | Floors 1–3 |
| T4 | Floors 1–4 (Boss Floor) |

Each floor is a self-contained node map leading to a floor exit.

## 20.2 Floor Completion = Checkpoint Choice

When the party reaches the end of a floor:

**Return to Town:**
- Shop refreshes (using input materials, facility autocrafting, rarity rolls)
- All floor materials go to Town Storage
- Heroes keep XP gained
- Floors remain unlocked for re-entry

**Continue to Next Floor:**
- No Shop Refresh
- Resources in Shopkeeper Bag remain
- Buffs remain active
- **XP bonus applies** (see below)
- Difficulty increases

## 20.3 Continuous Run XP Bonus

| Floor Reached | XP Bonus |
|---------------|----------|
| 1 | +0% (baseline) |
| 2 | +10% |
| 3 | +20% |
| 4 | +30% |

## 20.4 Mid-Floor Retreat

If the player retreats before completing a floor:
- Run ends immediately
- **All materials gathered this floor are lost**
- **Shop does NOT refresh**
- Heroes keep XP earned so far
- Heroes do not die

## 20.5 Hero Death Rules

- **Death is permanent in dungeons**
- Dead heroes recorded in Book of the Dead
- Only the Shopkeeper survives by fleeing with insured items

## 20.6 Boss Floor (Floor 4)

- Only available at T4
- One unique boss encounter
- Defeating grants:
  - 1 Boss Material (Uncommon 50%, Rare 30%, Epic 15%, Legendary 5%)
  - Shop refresh
  - Region Dungeon unlock (when both towns' T4 bosses defeated)

## 20.7 Region Dungeon

After both town dungeons completed:
- One extremely hard floor
- Beating it unlocks the next region
- Drops Region Boss Material
- Slightly improved rarity table (+2–5% Epic/Legendary chance)

---

# 21. Postgame & New Cycle (NG+) System

## 21.1 Campaign Completion → New Cycle

When the player completes Region 7's final boss:

**Retained:**
- Carryover party (5 heroes initially; increases in future cycles)
- Their gear, traits, affinities, and levels
- Selection of Prestige Materials
- Cosmetic "Memorial Hero" data
- All previously unlocked races

**Reset:**
- All towns, facilities, dungeons revert to initial T1/T2 states
- Shop state
- Regular hero roster
- Book of the Dead (archived and restarted)

## 21.2 Carryover Party System

| Cycle | Carryover Limit |
|-------|-----------------|
| 2 | 5 |
| 3 | 6 |
| 4 | 7 |
| 5+ | 8 (cap) |

## 21.3 Memorial Heroes

- Select up to 5 fallen heroes from Book of the Dead
- Provide cosmetic appearance entries in future hire pools
- **No stat bonuses** — pure world-building and emotional continuity

## 21.4 Prestige Material Carryover

At campaign completion:
- 10 Basic Materials
- 5 Rare Materials
- 1 Epic/Legendary Material

These go into a "Cycle Vault" accessible from any town.

## 21.5 Shared Global Storage

In all cycles:
- **Town Storage is unified** — no per-town or per-region storage
- Dramatically reduces UI complexity

## 21.6 NG+ Changes

- Town Defense activates after **Region 1** (15% base chance)
- All previously unlocked races remain globally unlocked
- Corruption active from Region 1
- Tile hazards appear immediately
- Elite room frequency increased
- Dungeon scaling begins one region earlier

## 21.7 The World Tome (Meta Progression)

After completing a campaign, the World Tome unlocks.

**Structure:**
- 3 Pages: Heroes, Facilities, Dungeons & Events
- Each page: 5 nodes
- Each node: 3 ranks
- Cost: **5 Tome Points per rank** (10 for Shop Rarity Floor)
- **Total cost: 225 Tome Points**

### Heroes Page
- Hero ATK Boost: +15% → +30% → +45%
- Hero Max HP Boost: +5% → +10% → +20%
- XP Gain: +10% → +20% → +35%
- Crit Chance: +3% → +6% → +10%
- Resistances: +3% → +6% → +10%

### Facilities Page
- Crafting Quality: +6% → +12% → +20%
- Facility Upgrade Cost Reduction: -12% → -24% → -36%
- Shop Rarity Floor: Minimum Uncommon → Minimum Rare → Minimum Rare+
- Shop Slot Expansion: +1 → +2 → +3 slots
- Worker XP from Production: XP = Items × 5 (then ×1.5, then ×2.0)

### Dungeons & Events Page
- Elite Rewards: +3% → +7% → +12%
- Resource Yield: +5% → +10% → +15%
- Corruption Hazard Resistance: -4% → -8% → -12%
- Better Event Rewards: +5% → +10% → +20%
- Boss Material Rarity: +3% → +6% → +10%

---

# 22. Class System

## 22.1 Class Archetypes

All classes belong to one of eight archetypes defining behavior, positioning, and scaling:

| Archetype | Role |
|-----------|------|
| **Vanguard** | Tanks & mitigation specialists |
| **Striker** | Agile melee/ranged DPS |
| **Arcanist** | Magic-damage spellcasters |
| **Warden** | Healers, buffers, party-support |
| **Ranger** | Ranged physical attackers |
| **Invoker** | Summoners, minion-based classes |
| **Channeler** | HP manipulation, dark magic, curses |
| **Artificer** | Utility, dungeon support, blueprint synergy |

## 22.2 Class Ability Structure

Each class uses:
- **Basic Attack** — from weapon
- **Class Ability A** — core tactical skill (1–3 turn cooldown)
- **Class Ability B** — higher impact skill (2–5 turn cooldown)
- **Weapon Ability** — from weapon type (2–4 turn cooldown)
- **2 Class Passives** — always active

**There are NO ultimate abilities.**

## 22.3 Full Class List (16 Classes)

### Region 1 — Starters
1. **Defender** (Vanguard) — Tank/Protector
2. **Warden** (Warden) — Healer-Protector Hybrid
3. **Striker** (Striker) — Dual-path DPS (melee OR ranged)

### Region 2 — The Fungalmire
4. **Druid** (Warden) — Sporecaster/Nature Manipulator
5. **Fungal Berserker** (Striker) — DoT-consuming frontline bruiser

### Region 3 — The Sunken Strand
6. **Tidechaser** (Arcanist) — Wave-Mage/Flow Manipulator
7. **Stormcaller** (Arcanist) — Lightning Caster/Control DPS

### Region 4 — Ashen Horizons
8. **Pyrewarden** (Vanguard) — Dragonkin Fire Control
9. **Ashblade** (Striker) — Assassin/Execution Specialist

### Region 5 — Starfall Expanse
10. **Prism Sentinel** (Vanguard) — Crystalborn Defensive Controller
11. **Prism Lancer** (Striker) — Crystal DPS/Line Specialist

### Region 6 — The Necropolis
12. **Dark Channeler** (Channeler) — Soul/Doom Manipulator
13. **Lich** (Channeler) — Arcane Commander/Sacrifice Engine

### Region 7 — Final Realm
14. **Voidwalker** (Striker) — Control/Assassin Hybrid
15. **Void Herald** (Warden) — Support/Corruptor

## 22.4 Class Books

- Classes assigned using **Class Books** from shop
- Class Books **can overwrite existing classes** with no penalty
- Overwriting costs gold, instantly changes class, retains race/gear/level

---

# 23. Turn-Based Ability & Combat System

## 23.1 Hero Combat Kit

Every hero has:
1. **Basic Attack** (from weapon) — always available
2. **Class Ability A** — 1–3 turn cooldown
3. **Class Ability B** — 2–5 turn cooldown
4. **Weapon Ability** — 2–4 turn cooldown
5. **2 Class Passives** — always on
6. **Race Passives** — always on (if any)

**No ultimate abilities. No real-time timers.**

## 23.2 Ability Definition Template

```
Metadata:
- Name
- Source: (Class / Weapon / Enemy / Item)
- Type: (Basic / ClassA / ClassB / WeaponAbility / EnemyAbility)

Mechanics:
- Cooldown (in turns; 0 for basic attacks)
- Targeting rule (single, row, 2x2, etc.)
- Effect description (damage/heal/buff)
- Flat values (damage, shield, etc.)
- Status applied (if any)
- Status details (duration, magnitude, stack rule)

Tags:
- Damage type: (Physical / Magical / Element)
- Archetype tags
- Synergy notes
```

## 23.3 Status Effects Summary

### Damage-over-Time
- **Poison** (stacks)
- **Bleed** (stacks, physical abilities)
- **Burn** (refreshes, fire damage)
- **Shock** (stacks to 3, triggers Overload)
- **Spores** (max 3, DoT from Druid)

### Heal-over-Time
- **Regeneration** (flat heal at turn start)

### Control
- **Slow** (initiative penalty)
- **Dazed** (skip next action, from Overload)
- **Stun** (lose action) — rare

### Shields
- Temporary HP buffer

### Special: Doom (Countdown Execution)
- **NOT a DoT**
- Doom (X) = turns until resolution
- At 0: heavy true damage (ignores armor)
- Stacking increases countdown (delays but amplifies)
- UI: Clock icon

### Special: Ash Marks
- NOT DoTs
- Setup mechanic for Ashblade execution

### Special: Corruption
- Threshold-based mechanic for Void Herald
- Does nothing until threshold (3) reached
- Then triggers effect and consumes stacks

---

# 24. Class Ability Kits

## 24.1 Defender (Region 1 | Vanguard)

**Role:** Tank / Protector
**Fantasy:** Heavily armored frontline who absorbs hits and controls enemy focus

### Passive A — Bulwark Stance
At start of Defender's turn → gain +1 Flat Armor (capped at 5)

### Passive B — Shielding Presence
Adjacent allies gain +2 Shield at start of their turn (refreshes)

### Class Ability A — Guardian's Challenge
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Light damage + Apply Taunt (1 turn)
- Additional: Defender gains +2 Armor (1 turn)

### Class Ability B — Aegis Slam
- Cooldown: 4 turns
- Target: 2x2 cluster or single heavy hit
- Effect: Moderate physical damage + Apply Slow (1 turn)
- Additional: Defender gains +10 Shield

---

## 24.2 Warden (Region 1 | Healer-Protector)

**Role:** Support / Healer
**Fantasy:** Forest guardian with organic, grounded healing

### Passive A — Living Bond
When Warden heals any ally → heal lowest-HP ally for +2 HP

### Passive B — Verdant Renewal
At end of each round → all allies gain +1 Regen (1 turn)

### Class Ability A — Nature's Grace
- Cooldown: 2 turns
- Target: Single ally
- Effect: Moderate HP heal + Apply Regen (2 turns)

### Class Ability B — Barkskin Blessing
- Cooldown: 4 turns
- Target: Self or single ally
- Effect: +8 Shield + +2 Flat Armor (2 turns)

---

## 24.3 Striker (Region 1 | Dual-Path DPS)

**Role:** Agile DPS (melee OR ranged)
**Fantasy:** Fast, precise combatant with flexible weapon paths

### Passive A — Momentum Edge
If Striker acts before target → first damaging action deals +2 damage

### Passive B — Finisher's Instinct
Deal +3 damage to enemies under 25% max HP

### Class Ability A — Twin Strike
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Two separate light hits (each can trigger on-hit effects)

### Class Ability B — Shadowstep
- Cooldown: 4 turns
- Target: Self
- Effect: Gain Evasion (1 turn) + Optional reposition to any tile

---

## 24.4 Druid (Region 2 | Sporecaster)

**Role:** DoT/Support Hybrid
**Fantasy:** Fungal mystic manipulating life cycles

### Passive A — Spore Bloom
Damaging abilities apply 1 Spore (max 3 per enemy). Spores deal +1 damage at end of enemy's turn.

### Passive B — Mycelial Renewal
At round end → lowest-HP ally gains +3 healing per spored enemy

### Class Ability A — Sporeburst
- Cooldown: 3 turns
- Target: 2×2 cluster
- Effect: Light magic damage + Apply 2 Spores (if already had Spores → increase to 3)

### Class Ability B — Cycle of Life
- Cooldown: 5 turns
- Target: Single ally + global enemy check
- Effect: Heal ally (moderate) + Apply Regen (1 turn) + For each enemy with Spores → deal +1 damage to random enemy

---

## 24.5 Fungal Berserker (Region 2 | DoT Consumer)

**Role:** Frontline Bruiser
**Fantasy:** Toxic warrior converting pain into power

### Signature Mechanic — Feral Charges
- Max 5 stacks
- Each charge grants +1 flat damage to all attacks
- Gained by consuming DoTs from allies/enemies

### Passive A — Devour Affliction
When attacking enemy with any DoT → consume 1 stack, deal +1 damage, gain +1 Feral Charge

### Passive B — Feral Resilience
Gain +1 Armor per 2 Feral Charges. At 5 charges first time each combat → Heal +3 HP

### Class Ability A — Cannibalize Affliction
- Cooldown: 5 turns
- Target: 1 ally
- Effect: Cleanse ALL DoT stacks → gain Feral Charges + Stored Agony (bonus damage on next attack)

### Class Ability B — Retching Frenzy
- Cooldown: 4 turns
- Target: Enemy frontline row
- Effect: Moderate physical damage. Spend up to 2 Feral Charges → +2 damage each + apply random DoT

---

## 24.6 Tidechaser (Region 3 | Wave-Mage)

**Role:** Control / Utility Caster
**Fantasy:** Water-shaping battle mage controlling flow

### Passive A — Flow State
After any push/pull/reposition → gain +2 Initiative (1 turn) + +1 Shield

### Passive B — Undertow Pressure
When pushing/pulling enemy → that enemy takes +1 damage on next hit

### Class Ability A — Tidal Push
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Light magic damage + push back 1 tile (if blocked → apply Slow)

### Class Ability B — Crashing Wake
- Cooldown: 4 turns
- Target: Choose 1 ally
- Effect: Move ally to any tile + deal magic splash damage around new position + allies adjacent to new position gain +2 Shield

---

## 24.7 Stormcaller (Region 3 | Lightning Caster)

**Role:** Control DPS
**Fantasy:** Volatile lightning mage building to Overloads

### Signature Mechanic — Shock → Overload → Daze
- Shock (DoT): Max 3 stacks, deals 1 lightning damage per stack at turn end
- At 3 Shock when hit by Stormcaller ability → **Overload**: +3 lightning damage, remove Shock, apply **Dazed** (skip next action)

### Passive A — Static Charge
Basic attacks apply 1 Shock

### Passive B — Storm Feedback
When Overload triggers → gain +2 Shield + +1 Initiative next turn

### Class Ability A — Lightning Lance
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Moderate lightning damage + Apply 1 Shock. If target has 3 Shock → trigger Overload

### Class Ability B — Storm Surge
- Cooldown: 5 turns
- Target: 2×2 cluster
- Effect: Light lightning damage + Apply 1 Shock to all. Any target at 3 Shock triggers Overload

---

## 24.8 Pyrewarden (Region 4 | Dragonkin Vanguard)

**Role:** Fire Control Tank
**Fantasy:** Disciplined frontline channeling internal flame

### Signature Mechanic — Ember Stacks
- Max 3 per enemy
- Ember does NOT deal damage on its own
- Consumed by Pyrewarden abilities for bonus effects

### Passive A — Living Furnace
At end of turn → apply 1 Ember to all adjacent enemies (if already 3 Ember → apply Burn instead)

### Passive B — Forged in Flame
Gain +1 Armor while any enemy has Ember/Burn. When enemy gains Burn → gain +1 Shield

### Class Ability A — Scorching Thrust
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Moderate physical + fire damage + Consume all Ember (+1 damage each). If 3 consumed → apply Burn (2)

### Class Ability B — Blazing Line
- Cooldown: 4 turns
- Target: Line (up to 3 tiles forward)
- Effect: Light fire damage + Apply 1 Ember to all. Targets with 3 Ember receive Burn (1) instead

---

## 24.9 Ashblade (Region 4 | Assassin)

**Role:** Execution Specialist
**Fantasy:** Methodical killer marking targets for execution

### Signature Mechanic — Ash Marks
- Max 3 stacks
- Does NOT deal damage
- **NOT a DoT** — consumed for execution effects

### Passive A — Cinder Focus
Deal +2 damage to enemies with no adjacent allies

### Passive B — Smoke Veil
On enemy kill → gain Evasion (1 turn) + +1 Initiative next turn

### Class Ability A — Ash Brand
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Light physical damage + Apply 1 Ash Mark. Deal +1 bonus per existing Ash Mark

### Class Ability B — Execution Cut
- Cooldown: 5 turns
- Target: Single enemy
- Effect: Heavy physical damage + Consume all Ash Marks (+2 damage each). If 3 consumed → apply Bleed (2) + gain +1 Initiative

---

## 24.10 Prism Sentinel (Region 5 | Crystalborn Defender)

**Role:** Defensive Controller
**Fantasy:** Living crystalline guardian creating protective zones

### Signature Mechanic — Refraction Zone
- Tile-based defensive construct (1 at a time, duration 2 turns)
- First damage each turn to ally in zone: reduced by 3, reflected to random enemy

### Passive A — Crystalline Poise
If Prism Sentinel doesn't move this turn → gain +2 Shield + +1 Armor until next turn

### Passive B — Refractive Memory
When zone redirects damage → gain +1 Initiative next turn

### Class Ability A — Prism Anchor
- Cooldown: 3 turns
- Target: Any empty tile
- Effect: Create Refraction Zone (replaces existing if present)

### Class Ability B — Shatter Pulse
- Cooldown: 5 turns
- Target: Active Refraction Zone
- Effect: Consume zone → deal moderate crystal damage to all adjacent enemies + Apply Slow (1 turn). Bonus: +2 damage per turn zone was active (max +4)

---

## 24.11 Prism Lancer (Region 5 | Crystal DPS)

**Role:** Line Damage Specialist
**Fantasy:** Crystal beams punishing poor positioning

### Passive A — Perfect Alignment
When hitting 2+ enemies in a straight line → deal +2 bonus damage to all

### Passive B — Crystalline Focus
If didn't move this turn → next damaging ability deals +3 bonus damage

### Class Ability A — Prism Beam
- Cooldown: 2 turns
- Target: Straight line (up to 3 tiles)
- Effect: Moderate crystal damage to all enemies in line. Triggers Perfect Alignment if applicable

### Class Ability B — Shattering Convergence
- Cooldown: 5 turns
- Target: Single enemy
- Effect: Heavy crystal damage. If enemy directly behind target → +4 bonus to primary + moderate damage to secondary + Armor Break (1 turn) to both

---

## 24.12 Dark Channeler (Region 6 | Doom Manipulator)

**Role:** Control/Inevitability Specialist
**Fantasy:** Forbidden rites practitioner deciding when enemies fall

### Signature Mechanics
- **Soul Charges** (max 5): Gained when enemies die (extra if they had Doom)
- **Doom** (countdown execution): NOT a DoT, heavy true damage when reaches 0

### Passive A — Grave Resonance
When enemy dies → gain +1 Soul Charge. If enemy had Doom → +1 additional

### Passive B — Inevitable Collapse
Enemies with Doom deal –1 damage. When reaching Doom (1) → apply Slow (1 turn)

### Class Ability A — Soul Brand
- Cooldown: 2 turns
- Target: Single enemy
- Effect: Light dark damage + Apply Doom (2). If 2+ Soul Charges → spend 2 to apply Doom (3) instead

### Class Ability B — Fate Sever
- Cooldown: 5 turns
- Target: Single enemy with Doom
- Effect: Reduce Doom by 1. If reaches 0 → resolve immediately. Empowered (3 Soul Charges): Resolve Doom instantly, gain +1 Soul Charge back

---

## 24.13 Lich (Region 6 | Arcane Commander)

**Role:** Sacrifice Engine / Minion Controller
**Fantasy:** Master of death through binding and sacrifice

### Unlock Requirement
Sacrificing a **high-level Legacy Hero** creates the Lich Class Book. The sacrificed hero becomes the **Phylact Minion** and is recorded in the Book of the Dead.

### Signature Mechanic — Phylact Minion
- Inherits sacrificed hero's race, class ability, and both passives
- Acts immediately before Lich each turn
- If destroyed → reforms after combat
- Cannot be transferred or duplicated

### Passive A — Bound Beyond Death
While Phylact alive: Lich gains +3 flat damage. Phylact gains +20 Max HP + +1 Armor

### Passive B — Harvest the Unliving
On any unit death: gain Harvest Stacks (+1 for Husk, +2 for enemy, +4 for ally hero). Max 8 stacks. +1 flat damage per stack

### Class Ability A — Raise Husk
- Cooldown: 2 turns
- Target: Adjacent empty tile
- Effect: Summon Temporary Husk (low HP, basic melee attack, removed at combat end)

### Class Ability B — Rite of Final Offering
- Cooldown: 4 turns
- Effect: Consume all Harvest Stacks + all Temporary Husks. For each: Heal Lich +3 HP, heal Phylact +5 HP, deal 2 damage to all enemies

**Restrictions:** No tile-based bonuses. No percentage scaling. Cannot target living allies.

---

## 24.14 Voidwalker (Region 7 | Control Assassin)

**Role:** Threat Denial / Reality Manipulation
**Fantasy:** Entity not fully existing in the same space as enemies

### Signature Mechanic — Phased State
- Cannot be directly targeted or affected by enemies while Phased
- Can still occupy and block tiles
- Ends at start of next turn unless extended

### Passive A — Unstable Presence
When entering Phased → nearest enemy suffers **Disorientation** (loses next attack action)

### Passive B — Fractured Reality
When exiting Phased → gain +2 flat damage for next attack/ability

### Class Ability A — Phase Step
- Cooldown: 2 turns
- Target: Self or adjacent tile
- Effect: Instantly move to tile + enter Phased + remove movement-impairing effects

### Class Ability B — Void Rend
- Cooldown: 3 turns
- Target: Adjacent enemy
- Effect: 8 flat damage (ignores armor). If cast while Phased → exit Phase + trigger Fractured Reality bonus

---

## 24.15 Void Herald (Region 7 | Support Corruptor)

**Role:** Battlefield Control through Corruption
**Fantasy:** Rewriting expectations, distorting threat perception

### Signature Mechanic — Corruption Threshold
- Corruption is a non-damaging counter on units
- Does nothing until threshold (3) reached
- At threshold: effect triggers, stacks consumed

### Passive A — Whispered Collapse
When enemy reaches Corruption Threshold → enemy loses 1 Armor + deals –2 damage on next attack

### Passive B — Profane Benediction
When ally reaches Corruption Threshold → ally gains +2 damage + +2 Armor (1 round)

### Class Ability A — Mark of the Void
- Cooldown: 2 turns
- Target: Any unit (ally or enemy)
- Effect: Apply 2 Corruption (1 if target already has Corruption)

### Class Ability B — Reality Fracture
- Cooldown: 4 turns
- Target: All enemies in a row or column
- Effect: Apply 1 Corruption to each. If any enemy triggers threshold → all affected enemies take 3 damage

---

# Appendix: Quick Reference Tables

## Status Effects Quick Reference

| Status | Type | Stacking | Notes |
|--------|------|----------|-------|
| Poison | DoT | Stacks | Tick at turn end |
| Bleed | DoT | Stacks | Physical sources |
| Burn | DoT | Refreshes | Fire damage |
| Shock | DoT | 3 max | Triggers Overload at 3 |
| Spores | DoT | 3 max | Druid-specific |
| Regen | HoT | Refreshes | Heal at turn start |
| Shield | Buffer | Stacks | Absorbs before HP |
| Slow | Control | N/A | Initiative penalty |
| Dazed | Control | N/A | Skip next action |
| Taunt | Control | N/A | Forces targeting |
| Doom | Execution | Stacks | Countdown, NOT DoT |
| Ember | Setup | 3 max | Pyrewarden-specific |
| Ash Mark | Setup | 3 max | Ashblade-specific, NOT DoT |
| Corruption | Threshold | 3 trigger | Void Herald-specific |
| Phased | State | N/A | Cannot be targeted |

## Region Unlock Summary

| Region | Race Unlocked | Classes Unlocked |
|--------|---------------|------------------|
| 1 | Human, Elf, Dwarf | Defender, Warden, Striker |
| 2 | Mossfolk | Druid, Fungal Berserker |
| 3 | Tidelings | Tidechaser, Stormcaller |
| 4 | Dragonkin (locked) | Pyrewarden, Ashblade |
| 5 | Crystalborn (locked) | Prism Sentinel, Prism Lancer |
| 6 | Undead | Dark Channeler, Lich |
| 7 | Voidwalkers (locked) | Voidwalker, Void Herald |

---

# 25. Enemy AI Archetypes & Behavior Rules

## 25.1 Design Goals

Enemy AI is designed to be:

- **Readable** — players can predict intent
- **Consistent** — same archetype behaves the same everywhere
- **Composable** — bosses and elites build on archetypes
- **Non-cheaty** — no hidden stat inflation or reaction timing

Enemy AI does not adapt dynamically to player strategy mid-combat. Difficulty is created through composition, positioning, and ability timing, not reactive intelligence.

## 25.2 Turn-Based AI Core Rules

All enemies follow these universal rules:

- Enemies act once per turn
- Enemies choose one action: Move, Attack, or Use Ability
- Enemies do not change targets mid-action
- Enemies do not pre-calculate future turns
- Enemies never break grid rules

This keeps AI deterministic and debuggable in Godot.

## 25.3 Enemy Targeting Priority System

Enemies select targets using the following priority order:

1. **Forced Targeting** — Taunt, Doom effects, AI overrides
2. **Threat Value** — Units dealing highest recent damage, units applying control effects
3. **Proximity** — Nearest reachable target
4. **Role Bias** — Archetype-specific preference (see below)

If multiple targets tie, selection is random.

## 25.4 Enemy Archetype List (Core)

Each enemy belongs to one primary archetype.

### 25.4.1 Bruiser

**Role:** Frontline pressure

**Behavior:**
- Prioritizes nearest enemy
- Moves forward aggressively
- Rarely retreats

**Ability Use:**
- Uses abilities on cooldown
- No target switching logic

**Examples:** Orc Warriors, Undead Knights, Crystal Sentinels

### 25.4.2 Skirmisher

**Role:** Flanking damage

**Behavior:**
- Prioritizes low-armor or isolated units
- Avoids heavily defended tiles
- Will reposition if blocked

**Ability Use:**
- Prefers attacking backline
- Uses mobility abilities first

**Examples:** Ashblades, Void Stalkers, Beast Hunters

### 25.4.3 Caster

**Role:** Pressure & control

**Behavior:**
- Stays at max range
- Avoids frontline engagement
- Repositions if threatened

**Ability Use:**
- Uses abilities before basic attacks
- Prioritizes clustered targets

**Examples:** Dark Acolytes, Storm Shamans, Crystal Channelers

### 25.4.4 Support

**Role:** Sustain & disruption

**Behavior:**
- Positions behind allies
- Avoids danger zones
- Retreats when threatened

**Ability Use:**
- Buffs allies under threat
- Debuffs highest-damage hero

**Examples:** Void Herald enemies, Fungal Shamans, Cult Priests

### 25.4.5 Sentinel

**Role:** Area denial

**Behavior:**
- Holds position
- Controls chokepoints
- Rarely advances

**Ability Use:**
- Uses zone or reaction abilities
- Punishes movement

**Examples:** Crystal Wardens, Living Statues, Void Anchors

## 25.5 Elite Enemy Modifiers

Elite enemies are not new archetypes. Instead, they gain 1–2 modifiers:

- +1 ability
- Enhanced version of an archetype rule
- Increased HP / armor
- Minor immunity (e.g., cannot be slowed)

Elites do not gain new AI logic.

## 25.6 Boss AI Rules

Bosses are composed of:

- 1 primary archetype
- 1–2 phase triggers
- Scripted ability timing

Bosses:
- Do not react to player actions dynamically
- Do not change archetypes mid-fight
- Use abilities at fixed HP thresholds or turn counts

This keeps bosses fair and learnable.

## 25.7 Region-Based AI Flavor

Regions modify how archetypes express, not their rules:

| Region | AI Flavor |
|--------|-----------|
| Region 1 | Simple, direct |
| Region 2 | Aggressive, swarm behavior |
| Region 3 | Control-heavy, movement denial |
| Region 4 | Burst windows, execution |
| Region 5 | Position punishment |
| Region 6 | Attrition & inevitability |
| Region 7 | Target denial & rule bending |

## 25.8 Town Defense AI Simplification

Town Defense battles use the same archetypes with simplifications:

- No repositioning logic
- No retreat logic
- Reduced target priority layers

This allows fast auto-resolution without invalid outcomes.

## 25.9 Godot Implementation Notes

Enemy AI can be implemented as:

- `EnemyArchetype` enum
- Shared `ChooseAction()` function
- Per-archetype targeting bias
- Fixed priority weights

No behavior trees or planners required.

## 25.10 AI Debug Visibility (Developer Only)

For development:

- Display enemy archetype icon
- Optional debug overlay showing chosen target

This is not player-facing.

---

# 26. Boss Design Rules

## 26.1 Boss Design Pillars

Bosses exist to test mastery of systems, not to invalidate them.

A boss encounter must always:
- Reinforce mechanics introduced earlier in the region
- Be learnable through observation and iteration
- Reward positioning, timing, and preparation
- Remain fair even when difficult

Bosses must never:
- Break core combat rules
- React dynamically to player inputs ("AI cheating")
- Hard-counter specific classes or builds
- Use ultimate-style abilities

Boss difficulty comes from composition, mechanics, and pressure, not surprise lethality.

## 26.2 Boss Structure Overview

Every boss encounter is built from the same structural components:

- **Primary AI Archetype** (from Section 25)
- **1–2 Unique Boss Mechanics**
- **Boss Arena Modifier** (optional, region-dependent)
- **Phase Progression Method** (HP or turn-based)

This structure ensures consistency while allowing meaningful variation.

### Boss Arena Modifiers (Later Regions)

In later regions (Region 5+), boss arenas may include:

- Summoned objects (turrets, anchors, pylons, growths)
- Objects may have HP or a countdown timer
- Objects apply pressure (damage, buffs, debuffs, denial)

Objects are:
- Limited in number
- Clearly telegraphed
- Never infinite or self-respawning

Early-region bosses use clean arenas with minimal modifiers.

## 26.3 Boss Phases

Bosses escalate through phases, not enrages.

**Phase Triggers:**
- HP thresholds (e.g. 70%, 40%)
- Turn count (e.g. Turn 6)

**Phase Effects:**
- Unlock new abilities
- Modify existing abilities
- Introduce arena pressure
- Change targeting patterns

Phases must:
- Be predictable
- Never reset cooldowns unfairly
- Never remove player buffs/debuffs
- Never skip turn order

## 26.4 Boss Ability Rules

Bosses typically have 2–4 abilities.

All abilities:
- Have visible telegraphs
- Obey cooldowns
- Respect turn order

**No ultimate abilities.**
**No reactive "counterplay AI."**

Boss abilities are enhanced expressions of archetype behavior, not new rule systems.

## 26.5 Arena & Positioning Design

Boss encounters emphasize grid awareness without overwhelming the player.

Design rules:
- Early regions: clean grids
- Later regions: limited, readable pressure
- Hazards are temporary or destructible
- Positioning always matters, guessing never does

## 26.6 Region-Based Boss Identity

| Region | Boss Focus |
|--------|------------|
| Region 1 | Basic damage & positioning |
| Region 2 | Status interaction (simple) |
| Region 3 | Movement & tempo |
| Region 4 | Burst windows |
| Region 5 | Geometry & formation pressure |
| Region 6 | Attrition & inevitability |
| Region 7 | Rule distortion (non-cheating) |

Boss mechanics must align with regional themes and class kits.

## 26.7 Dungeon Bosses vs Region Bosses

There are two boss types, serving different purposes.

### Dungeon Bosses
- Guard individual dungeon floors
- Can be fought repeatedly
- Moderate difficulty
- Primary purposes: Teach mechanics, Provide resources, Progress Region Boss access

Dungeon bosses scale slightly with dungeon tier.

### Region Bosses
- Gate progression to the next region
- Single-floor encounters
- High mechanical and stat difficulty
- Farmable in a controlled way

## 26.8 Region Boss Access — Charged Key System

Region Boss access uses a single persistent charge object.

**How Charges Work:**
- Each dungeon floor completion grants +1 Region Charge
- Completing all 4 floors = 4 charges
- Charges are stored up to a maximum of 10
- 1 Region Charge is consumed per Region Boss attempt

This means:
- A full dungeon clear allows 1 boss attempt
- Players may stockpile charges (up to 10)
- Players can fight the Region Boss multiple times in succession if charged

**Design Goals:**
- Encourages dungeon mastery
- Allows farming without forcing repetition every time
- Prevents infinite boss spam
- Respects player time

Charges persist until spent or the region is completed.

## 26.9 Failure & Retry Rules

### Dungeon Failure

If all heroes die mid-floor:
- The run ends
- The dungeon resets to the start of that floor

On retry, the player may:
- Restart the same floor
- Choose any previously unlocked lower floor

### Region Boss Failure

- Shopkeeper survives
- Heroes may die permanently
- Charges are not refunded
- Boss may be retried if charges remain

## 26.10 Rewards & Drops

### Dungeon Boss Rewards
- Resources
- Gold
- Chance at higher-tier materials
- No guaranteed high-rarity drops

### Region Boss Rewards

**First Defeat (Campaign Clear Only):**
- Guaranteed Legendary item
- Region progression unlock
- One region-specific crafting material

**Subsequent Defeats:**
- Legendary no longer guaranteed
- Drops roll from: Uncommon, Rare, Epic, Legendary (low chance)

Prevents legendary bloat while keeping farming meaningful.

## 26.11 Boss Repetition & Scaling

**Dungeon bosses:**
- Scale modestly with dungeon tier

**Region bosses:**
- Fixed difficulty
- Serve as progression benchmarks
- Do not scale infinitely

## 26.12 Godot / Claude Implementation Notes

Bosses are implemented using:
- Enemy entity
- Phase Controller
- Ability unlock flags
- Fixed trigger logic

No behavior trees required. Deterministic execution only.

---

# 27. Status Effect Registry

## 27.1 Purpose & Design Philosophy

Status effects in Shops & Shadows exist to:
- Create tactical pressure
- Reinforce class and weapon identity
- Reward positioning, timing, and preparation

They are not intended to:
- Replace core combat decisions
- Create hidden math or opaque scaling
- Become mandatory for success

All status effects must be:
- Readable at a glance
- Predictable in outcome
- Limited in scope

If a status effect cannot be clearly understood from its icon, number, and tooltip, it does not belong in the game.

## 27.2 Status Effect Categories

Every status effect belongs to exactly one category.

**Allowed Categories:**
- Damage-over-Time (DoT)
- Control & Disruption
- Buffs & Enhancements
- Debuffs & Weakening
- Countdown Effects
- Special / Rule-Bending (late-game only)

Categories exist to prevent overlapping mechanics and runaway complexity.

## 27.3 Global Stack Rules

All status effects obey global stacking rules.

**Stack Types:**

| Type | Behavior |
|------|----------|
| Flat Stacks | Each stack adds a fixed value (e.g., +2 damage per stack) |
| Duration Stacks | Adds or refreshes duration |
| Countdown Extension | Adds time before effect triggers |

**Global Rules:**
- Status effects may define a max stack cap
- Reapplying an effect: Refreshes duration OR extends countdown
- Effects never scale exponentially
- Percentage scaling is avoided unless explicitly stated

## 27.4 Countdown Status Effects

Countdown effects use a **clock icon**.

**Rules:**
- Number shown = turns remaining
- Countdown decreases at end of turn
- Effect triggers when countdown reaches 0

**Stack Interaction:**
- Adding stacks: Increases countdown duration AND increases final effect magnitude proportionally
- Power is derived from time invested, not burst stacking

**Use Cases:**
- Doom
- Delayed explosions
- Ritual completions

Countdown effects are primarily used by: Bosses, Late-game classes, High-tier enemies

## 27.5 Damage-over-Time (DoT) Effects

DoTs represent sustained pressure.

**Rules:**
- Trigger at end of affected unit's turn
- Scale linearly
- Respect armor and mitigation rules unless stated otherwise
- Cannot crit
- Are removed on death

**Boss Interaction:**
- Bosses may have: Reduced DoT duration, Reduced max stacks
- Bosses are never fully immune unless explicitly stated

## 27.6 Control & Disruption Effects

Control effects limit enemy actions.

**Common Effects:**
- Stun (skip next action)
- Daze (reduced accuracy / effectiveness)
- Root (movement restricted)
- Slow (initiative reduction)
- Push / Pull (forced movement)

**Rules:**
- Control effects do not stack indefinitely
- Bosses resist control: Reduced duration, Partial effect
- Hard immunity is rare and clearly communicated

## 27.7 Buffs & Debuffs

Buffs and debuffs modify stats temporarily.

**Rules:**
- Prefer flat values over percentages
- Duration-based
- Visible stacking indicators
- Buffs and debuffs of same type do not multiply

**Priority:**
- Highest magnitude applies
- Newer applications refresh duration

## 27.8 Tile-Based Status Effects

Tiles may apply effects but are not status effects themselves.

**Rules:**
- Tiles apply effects on: Entry, Start of turn
- Tile effects: Are visually distinct, Do not stack infinitely
- Leaving a tile may remove the effect unless stated otherwise

This keeps tiles tactical without overwhelming the status system.

## 27.9 Status Effects & Bosses

Bosses interact with status effects differently.

**Boss Rules:**
- Reduced stack caps
- Reduced duration
- Phase-based cleansing allowed
- No full immunity unless explicitly designed

Bosses are meant to be pressured, not disabled.

## 27.10 Status Effects & Weapons

Weapons are a primary source of status effects.

**Rules:**
- Each weapon type may: Apply a thematic status, Modify how a status behaves
- Higher-tier weapons may: Increase stack cap, Extend duration, Change application timing

Weapon passives enhance statuses — they do not replace them.

## 27.11 Cleansing, Resistance & Immunity

**Cleansing:**
- Removes one or more effects
- Does not affect tiles
- Rare and intentional

**Resistance:**
- Reduces duration or effect
- Never nullifies entirely unless stated

**Immunity:**
- Extremely rare
- Used only for specific boss mechanics
- Always communicated clearly

## 27.12 Visual Language & UI Rules

Status clarity is mandatory.

**UI Rules:**
- Each status has: Unique icon, Consistent color, Stack number or countdown clock
- Tooltips always show: Effect, Stack behavior, Duration logic
- Numbers always mean the same thing: Stacks = power, Clock = time

## 27.13 Authoritative Status Effect Registry

The following status effects are approved for use:

| Status | Category | Stack Type | Max Stacks | Notes |
|--------|----------|------------|------------|-------|
| Poison | DoT | Flat | 5 | Tick at turn end |
| Bleed | DoT | Flat | 5 | Physical sources |
| Burn | DoT | Refresh | N/A | Fire damage, refreshes duration |
| Shock | DoT | Flat | 3 | Triggers Overload at 3 |
| Spores | DoT | Flat | 3 | Druid-specific |
| Regen | HoT | Refresh | N/A | Heal at turn start |
| Shield | Buffer | Additive | N/A | Absorbs before HP |
| Slow | Control | N/A | N/A | Initiative penalty |
| Dazed | Control | N/A | N/A | Skip next action |
| Stun | Control | N/A | N/A | Lose action (rare) |
| Taunt | Control | N/A | N/A | Forces targeting |
| Root | Control | N/A | N/A | Cannot move |
| Doom | Countdown | Extension | N/A | Heavy true damage at 0, NOT DoT |
| Ember | Setup | Flat | 3 | Pyrewarden-specific, NOT DoT |
| Ash Mark | Setup | Flat | 3 | Ashblade-specific, NOT DoT |
| Corruption | Threshold | Flat | 3 | Void Herald-specific, triggers at threshold |
| Phased | State | N/A | N/A | Cannot be targeted |
| Armor Break | Debuff | Duration | N/A | Reduced armor |
| Weakness | Debuff | Duration | N/A | Reduced damage |

**No new status effects may be added outside this registry.**

---

# 28. UI & Player Feedback Rules

## 28.1 UI Design Philosophy

The UI in Shops & Shadows exists to:
- Communicate intent and consequence
- Reduce cognitive load
- Support strategic decision-making

The UI must never:
- Hide critical information
- Overwhelm the player with constant indicators
- Require memorization of invisible rules

UI clarity takes priority over visual flair.

## 28.2 Global UI Rules

Across all game modes:
- Only show information relevant to the current interaction
- Avoid persistent clutter
- Use color, iconography, and motion sparingly but consistently

**Interaction Priority:**
1. Combat-critical information
2. Immediate player choices
3. Long-term context (collapsed or optional)

## 28.3 Combat UI

**Battlefield View:**
- Grid-based battlefield always visible
- Clear front/back rows (early game)
- Expanded grid (later regions) shown explicitly

**Unit Indicators:**
Each unit displays:
- Health bar
- Resource bar (mana, energy, etc.)
- Status effect icons (Section 27 rules)
- Targeting indicators (who is attacking whom)

No hidden stats.

## 28.4 Turn & Action Feedback

Combat is turn-based.

**UI must clearly show:**
- Current acting unit
- Upcoming turn order (short horizon, not full timeline)
- Ability cooldowns as numeric counters

No round counter is required.

## 28.5 Ability UI

**Hero Ability Panel:**
When a hero is selected, show:
- Class ability A
- Class ability B
- Weapon ability
- Passive summary (icons only)

Cooldowns shown as numbers on ability icons. Disabled abilities remain visible (never hidden).

**Weapon Abilities:**
- Shown in a dedicated slot
- Icon and tooltip clearly identify weapon origin

## 28.6 Status Effect UI

Status effects follow Section 27 rules.

**Visual Language:**
- Stack number = power
- Clock icon = countdown
- Color-coded by category:
  - Red: damage
  - Purple: debuff
  - Green: buff
  - Yellow: control
  - Blue: countdown/special

Hovering any icon shows full tooltip.

## 28.7 Tile & Environment UI

Tiles are quiet by default.

**Rules:**
- Tile effects are only highlighted when:
  - A unit is selected
  - The tile is hovered
  - The tile is actively affecting a unit
- Persistent tiles show an infinity symbol
- Temporary tiles show a countdown

This prevents visual overload.

## 28.8 Shop UI

**Shop Layout:**
- Shared inventory across all towns (global gold system)
- Only the current town's shop refreshes
- Shop slots are limited and chosen by the player

**Item Display:**
Each item shows:
- Rarity color
- Core stats
- Relevant passives
- Refinement indicators (e.g. +3 in blue)

Unavailable items are never shown.

## 28.9 Facility UI

Facilities have:
- Upgrade tier clearly displayed
- Input requirements shown before confirmation
- Visual feedback when producing shop items

**Hero Assignment:**
- Heroes assigned to facilities are shown as portraits
- Hovering shows: Hero level, Job bonuses, XP gain indicators

## 28.10 Town Defense UI

Town Defense UI includes:
- Defensive grid layout
- Offensive and defensive placement zones
- Auto-resolve toggle
- Preview of defending bonuses (HP, DEF, etc.)

If a defense fails:
- A clear downgrade animation is shown
- The affected building is highlighted

**No heroes die in defense combat.**

## 28.11 Dungeon & Floor UI

**Dungeon Selection:**
- Player selects: Dungeon, Floor number
- Locked floors are clearly marked

**Floor Completion:**
On floor clear, player chooses:
- Continue to next floor
- Return to town

XP bonus for continuous floors is displayed.

**Mid-floor extraction:**
- Is allowed
- Clearly warns that all collected materials from current floor will be lost

## 28.12 Inventory UI

**Hero Inventory:**
- Static slot layout: Gear slots, Backpack slot
- Backpack size clearly shown
- No weight system

**Shopkeeper Bag:**
- Larger capacity
- Items highlighted if uninsured
- Insurance slots marked in red

Warnings appear before entering risky content.

## 28.13 Book of the Dead UI

- Fallen heroes listed chronologically
- Favorites pinned to top
- Sacrificed heroes clearly marked
- Used as visual/lore reference, not power scaling

## 28.14 Map & Region UI

- Regions displayed as nodes
- Towns visible within regions
- Region boons shown as icons
- Active corruption or threats highlighted only when relevant

Fog of war is used selectively.

## 28.15 Feedback & Animation Rules

All actions must have:
- Visual feedback
- Audio feedback
- Timing consistency

Critical events (death, boss phase change, town damage) must be unmistakable.

## 28.16 Accessibility & Readability

- Colorblind-safe palettes
- Icons never rely on color alone
- Scalable UI text
- Tooltips always available

---

# 29. Save System & Persistence Rules

## 29.1 Save Philosophy

The save system in Shops & Shadows must be:
- Reliable
- Transparent
- Resistant to corruption
- Friendly to iteration and debugging

The game is not permadeath at the campaign level, but individual heroes and towns may suffer permanent consequences.

## 29.2 Save Types

### Campaign Save
Represents one full campaign run.

Includes:
- World progression
- Regions unlocked
- Town states
- Hero roster
- Inventory and storage (global)

Only one active campaign save at a time (initially).

### Meta Save
Persists across campaign restarts.

Stores:
- World Tome progress
- Favorite heroes
- Unlocked races/classes
- Settings & accessibility options

## 29.3 Autosave Rules

Autosaves occur at safe checkpoints only:
- Entering a town
- Completing a dungeon floor
- Completing a region
- Before and after region boss fights
- After town defense resolution

Autosaves **never** occur:
- Mid-combat
- Mid-floor
- Mid-decision prompt

This prevents soft-locks and exploit abuse.

## 29.4 Manual Saves

- Manual saving is allowed only in towns
- Manual saves overwrite the current campaign save
- No save scumming during combat or dungeon runs

## 29.5 Hero Persistence Rules

Each hero stores:
- Race
- Class
- Level & XP
- Equipped items
- Inventory
- Status (Alive / Dead / Sacrificed)

**Hero Death:**
- Permanent in-campaign
- Recorded in the Book of the Dead
- Cannot be reverted via reload

## 29.6 Town Persistence Rules

Each town stores:
- Region association
- Facility tiers
- Assigned heroes
- Defense readiness
- Damage state (tiered-down buildings)

Town destruction and downgrades are persistent until repaired.

## 29.7 Dungeon Persistence Rules

- Dungeon floors unlock permanently once cleared
- Failure resets only the current floor
- Floor selection persists between runs
- Region Boss charge count is saved persistently

## 29.8 Inventory Persistence

**Shared Inventory:**
- One global inventory across all towns
- Resources are never duplicated
- Facility upgrades pull from shared inventory manually

**Shopkeeper Bag:**
- Emptied at run start
- Filled only during dungeon runs
- Lost on mid-run extraction or party wipe

## 29.9 World Tome Persistence

World Tome progress:
- Stored in Meta Save
- Persists across campaigns
- Cannot be respecced initially (future option)

World Tome points are 0 on first campaign run.

## 29.10 Book of the Dead Persistence

Records all fallen and sacrificed heroes.

Favorites persist across cycles.

Used for:
- Memorial reference
- Lich interactions
- Cosmetic callbacks (future)

No mechanical bonuses are granted by default.

## 29.11 Post-Game & New Cycle Persistence

On campaign completion, player selects:
- Carryover heroes (limited)
- Carryover resources (slot-limited)

World resets:
- Towns
- Regions
- Dungeons

Changes:
- Difficulty increases
- Corruption and advanced mechanics activate

Meta progression remains intact.

## 29.12 Data Integrity & Recovery

To protect player data:
- Saves are versioned
- Previous save is backed up automatically
- Corrupt saves fall back to last valid state

Claude/Godot implementations must:
- Validate save schema on load
- Gracefully handle missing fields

## 29.13 Godot Implementation Notes

Recommended structure:
- JSON or Godot Resource-based saves
- Separate files for: Campaign state, Meta progression
- Clear schema versioning

No hidden or implicit save logic.

---

# 30. Audio Design & Feedback Rules

## 30.1 Audio Design Philosophy

Audio in Shops & Shadows exists to:
- Reinforce clarity and intent
- Provide immediate feedback for player actions
- Support atmosphere without overwhelming the player

Audio must never:
- Obscure gameplay information
- Replace visual clarity
- Become fatiguing during long play sessions

Audio is supportive, not dominant.

## 30.2 Global Audio Rules

Across the entire game:
- Every meaningful action has audio feedback
- No audio cue should be the only indicator of information
- Volume balance favors: Combat-critical sounds → UI sounds → Ambient audio → Music

Audio settings must be adjustable independently.

## 30.3 Combat Audio

### 30.3.1 Basic Combat Sounds
- **Attacks:** Light, medium, heavy variants
- **Impacts:** Hit, Block, Miss
- **Death:** Short, clear, non-dramatic

No overly long combat sounds.

### 30.3.2 Ability Audio

Every ability has:
- Cast sound
- Impact or resolution sound

Ability audio must:
- Match element/type (fire, void, crystal, etc.)
- Be distinct from basic attacks

Cooldown completion may have a subtle audio cue (optional, toggleable).

No global "ability spam" effects.

## 30.4 Status Effect Audio

Status effects use lightweight, non-repeating cues.

**Application:**
- Single short sound on application
- No looping sounds per unit

**Countdown Effects:**
- Subtle tick when countdown decreases
- Clear cue when countdown reaches 0

No constant ticking sounds.

## 30.5 Weapon Audio Identity

Weapon types have thematic audio identity.

**Examples:**
- Swords: clean metallic strikes
- Hammers: heavy impact with low-frequency emphasis
- Bows: snap + release
- Staves: tonal hum or pulse

Higher-tier weapons may add layered sound detail, not louder volume.

## 30.6 Enemy & Boss Audio

**Standard Enemies:**
- Short attack and death sounds
- Minimal vocalization
- Avoid audio clutter in group fights

**Bosses:**
Clear audio telegraphs for:
- Phase changes
- Major abilities

Boss audio must:
- Be readable
- Never mislead
- Never mask UI sounds

Boss audio escalates tension but stays controlled.

## 30.7 Town & Facility Audio

**Town Ambience:**
- Soft looping ambience per region
- Minimal NPC chatter
- Subtle environmental sounds

**Facilities:**
- Each facility has: One ambient loop, One interaction sound
- Upgraded facilities may slightly enrich audio texture

No production "machinery noise spam".

## 30.8 Shop & UI Audio

**UI Interaction Sounds:**
- Confirm
- Cancel
- Error / unavailable
- Purchase success

UI sounds must be: Short, Soft, Never startling

**Shop Audio:**
- Item purchase confirmation
- Rarity-based accent (very subtle)
- No gacha-style stingers

Legendary items do not use loud or flashy audio.

## 30.9 Dungeon & Exploration Audio

**Dungeon Ambience:**
- Region-specific loops
- Light reverb
- Minimal melodic content

**Room Transitions:**
Short stinger on:
- Floor completion
- Boss room entry

Exploration audio should never distract from combat decisions.

## 30.10 Music System Rules

**Music Layers:**
- Town music
- Dungeon exploration music
- Combat music
- Boss music

Music transitions are: Smooth, Crossfaded, Non-abrupt

**Music Priority:**
1. Boss music
2. Combat music
3. Dungeon ambience
4. Town ambience

Music pauses or fades during critical UI interactions.

## 30.11 Dynamic Audio Rules

Dynamic audio may respond to:
- Combat intensity
- Boss phase changes
- Low party health (subtle)

Dynamic changes must:
- Never spike volume
- Never override player control

## 30.12 Accessibility & Audio Options

Audio options must include:
- Master volume
- Music volume
- SFX volume
- UI volume
- Mute toggles

Optional:
- Visual alternatives for critical audio cues
- Subtitle-like indicators for major events

## 30.13 Godot Implementation Notes

Recommended approach:
- Audio buses by category
- One-shot sound nodes for effects
- Looping ambience via controlled audio players
- No hardcoded volume values

All audio triggers should be event-driven.

---

# 31. Item System & Generation

## 31.1 Design Goals

The item system in Shops & Shadows is designed to support strategic preparation, region identity, and long-term progression, without overwhelming the player with excessive loot or micromanagement.

**Core goals:**
- Items are earned through planning, not random drops
- Facilities, not heroes, are the primary source of gear
- Regions influence item identity and passive traits
- Scarcity creates meaningful decisions without hard failure states
- Items reinforce the shopkeeper fantasy of provisioning heroes

There is no traditional crafting at the hero level. Instead, facilities consume materials to produce randomized but controlled items for the shop.

## 31.2 Item Categories

Items are grouped into the following categories:

**Equipment:**
- Weapons
- Armor (Head, Chest, Legs)
- Accessories

**Consumables:**
- Health Flask (permanent)
- Potions (buff-based)

**Tools:**
- Pickaxe (mining)
- Hatchet (woodcutting)
- Fishing Pole (fishing & rare finds)
- Herb Pouch (herb storage)

**Special:**
- Blueprint-crafted items
- Legendary items

## 31.3 Item Data Structure

Each item is defined by:
- Item ID
- Category & Slot
- Rarity
- Region Identity
- Base Stats
- Passive Effects
- Weapon Ability (if applicable)
- Refinement Count (if applicable)

All item values are flat numeric values, not percentages, unless otherwise specified.

## 31.4 Item Rarity Tiers

| Rarity | Notes |
|--------|-------|
| Common | Basic stats, no passives |
| Uncommon | Slightly improved stats |
| Rare | One passive effect |
| Epic | Strong stats, multiple passives (Blueprint-crafted) |
| Legendary | Unique effects, crafted only at T4 facilities |

Legendary items never appear in shops randomly.

## 31.5 Facility-Based Item Generation

Items are generated exclusively through town facilities.

### Shop Slot Selection

At each facility, the player:
- Chooses how many shop slots the facility will fill
- Selects the item type for each slot (e.g. sword, armor)
- Sees a live preview of:
  - Materials required per slot
  - Total materials that will be pulled from storage

Materials are not consumed until the next shop refresh.

### Generation Timing

- Items are generated when returning from an expedition
- Only the shop in the current town refreshes
- Materials are consumed at refresh time

### Material Economy Rules

- All towns share one **global material inventory**
- Materials are never auto-pulled
- Players must manually commit materials per shop cycle
- Dungeon rewards are tuned so:
  - Basic materials accumulate naturally
  - Higher tiers require intentional farming

Running out of materials is a player-driven choice, not a punishment.

## 31.6 Region Identity & Item Passives

Each region contributes 2–3 possible passive effects to items crafted there.

**Rules:**
- Items roll one region passive (two for blueprint items)
- Passives are small, focused, and thematic
- No item rolls more than two region passives

**Examples:**
- Forest regions favor survivability or regeneration
- Fungal regions favor status effects or resource synergy
- Volcanic regions favor damage over time or risk/reward

## 31.7 Weapons & Weapon Abilities

Every weapon type grants a weapon ability.

Weapon abilities are:
- Separate from class abilities
- Activated manually
- Modified by weapon quality and passives

Higher-tier weapons may:
- Increase ability damage
- Add secondary effects
- Alter targeting rules

Weapon abilities provide tactical identity without adding extra UI slots.

## 31.8 Armor & Defensive Gear

Armor provides:
- Flat defensive stats
- Occasional passive effects

Armor does not grant active abilities.

Armor types (metal, leather, cloth) influence:
- Stat distributions
- Refinement options
- Facility upgrade requirements

## 31.9 Inventory & Backpacks

### Hero Inventory
- Maximum of 6 slots
- Typical usage: Weapon, Armor, Accessory, Health Flask, 1–2 flex slots
- Gold is tracked separately (global pool) and does not occupy inventory space

### Shopkeeper Bag
- Larger than hero inventories
- Used only during expeditions
- Must be emptied into town storage on return

Resources are non-stacking, reinforcing strategic inventory use.

## 31.10 Tools & Resource Gathering

Tools are required to gather specific resources.

| Tool | Resource |
|------|----------|
| Pickaxe | Ore, stone |
| Hatchet | Wood |
| Fishing Pole | Fish & rare finds |
| Herb Pouch | Herbs (holds up to 5) |

**Rules:**
- If a monster or environment drops a resource and the correct tool is missing, the resource is not obtained
- The shopkeeper may comment on missing tools after failed gathers
- Tools are crafted at facilities and can be purchased once a T1 facility exists

## 31.11 Consumables

### Health Flask (Permanent)
- Every hero has one Health Flask
- Occupies one inventory slot
- Starts at 5/5 charges
- Charges are consumed on use
- Automatically refills: When returning to town, After dungeon completion

The flask cannot be destroyed, duplicated, or traded.

### Flask Upgrades
Provided by Glass/Jeweler facilities. May:
- Increase max charges
- Improve healing amount
- Add minor effects

### Potions
- Crafted by Alchemist facilities
- Single-use consumables
- Provide buffs, not healing
- Can target self or allies

## 31.12 Refinement & Reforging

Refinement is unlocked at T3 facilities. Max refinement level: 10.

### Risk Zones

| Levels | Risk |
|--------|------|
| 1–4 | Safe |
| 5–8 | Increasing chance of negative effect |
| 9–10 | High risk of item destruction |

Players choose a stat group (e.g. Offense, Defense), not a specific stat.

All refinement changes are visually displayed on the item.

## 31.13 Blueprints & Legendary Crafting

### Blueprints
- Drop from dungeon floor bosses
- Not region-locked
- Permanently unlock epic crafting recipes

Blueprint-crafted items:
- Are Epic rarity
- Roll two region passives
- Allow the player to select a stat priority
- Guarantee one stat at maximum roll

Blueprints emphasize control and planning.

### Legendary Crafting
- Requires legendary materials
- Crafted at T4 facilities
- Produces a random legendary of selected type
- No stat guarantees

Legendary crafting emphasizes power and risk.

## 31.14 Gold Economy & Item Access

**Global Gold System:**
- All gold earned (combat, defense, events) flows into the **global gold pool**
- Shop purchases draw from global gold
- Gold is shared across all heroes and towns

When an item is purchased:
- It is removed from the shop
- Other heroes cannot buy it

## 31.15 Item Loss & Risk

- Uninsured items are lost on hero death
- Insured items are retained
- Shopkeeper always escapes with insured items only

This reinforces meaningful risk without full run loss.

## 31.16 Salvaging System

Any non-locked item may be salvaged in town.

**Salvaging Returns:**
- Base materials used to generate the item
- A small chance at rare or region-specific components

**Salvaging Does NOT Return:**
- Legendary materials
- Blueprint unlocks

Refined items return less material.

**Purpose:**
- Item sink
- Resource smoothing tool
- Inventory cleanup mechanic

Salvaging is accessible via existing facilities or shop UI.

## 31.17 Godot Implementation Notes

- Item generation is deterministic after shop selection
- Facilities act as item factories
- Shared inventory simplifies state tracking
- All values use flat numbers for ease of tuning

---

# 32. Core Data Philosophy, Entity Schemas & Scene Architecture

## 32.1 Core Data Philosophy & Runtime Model Rules

This section defines the data-first philosophy used throughout Shops & Shadows.
All runtime systems, combat logic, facilities, and progression rely on explicit data models, not hard-coded behavior.

### 32.1.1 Data-Driven First

All gameplay systems are driven by externalized data, not embedded logic.

- Heroes, items, facilities, enemies, and dungeons are defined via structured data
- Balance changes should be possible without modifying code
- Systems read from data; they do not infer missing information

Claude implementations must prefer:
- Dictionaries / Resources / JSON-like structures
- Declarative configuration
- Explicit values over derived assumptions

### 32.1.2 Flat Numbers Over Percentages

All core values are stored as flat numbers.

**Examples:**
- Attack = 42, not +15%
- Damage bonus = +6, not 1.1x
- Duration = 3 turns, not "short"

Percent modifiers:
- Are applied at runtime
- Are derived from passives, buffs, or abilities
- Are never stored directly on items or heroes unless explicitly defined

### 32.1.3 Explicit Ownership & Responsibility

| System | Owns |
|--------|------|
| Hero | Stats, equipment, abilities |
| Item | Stats, passives, refinement state |
| Facility | Production rules, slot configuration |
| Dungeon | Floors, rooms, enemies, rewards |
| Region | Passive pools, boss access |
| Meta Systems | Carryover rules, world tome |
| Global Pool | Gold, shared inventory |

No system mutates another system's data directly. All changes flow through defined interfaces.

### 32.1.4 Deterministic Resolution

Once an action begins, its outcome is deterministic.

- Shop items are determined at refresh
- Combat outcomes resolve turn by turn
- Salvage outputs are fixed at salvage time

Randomness is allowed only when: Explicitly triggered, Logged or traceable, Bound by known ranges.

There is no hidden or background RNG.

### 32.1.5 No Implicit Defaults

If a value is not defined, it does not exist.

- No "assumed" stats
- No hidden bonuses
- No fallback behaviors

### 32.1.6 Schema Stability Over Time

Once defined, schemas:
- May be extended
- Must not be silently altered
- Should remain backward-compatible when possible

### 32.1.7 Turn-Based Combat Compatibility

All schemas assume:
- Turn-based combat
- Discrete resolution steps
- Status effects evaluated once per turn

### 32.1.8 Claude Implementation Guidance

When implementing from this GDD:
- Do not invent fields
- Do not compress systems for convenience
- Prefer clarity over optimization
- Use readable names over shorthand
- Follow section order strictly

## 32.2 Core Entity Schemas — Hero & Item

### 32.2.1 Hero Entity Schema

**Hero Core Identity:**
```
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
```

**Hero Base Stats:**
```
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
```

**Hero Equipment Slots:**
```
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
```

**Hero Inventory:**
- slots_max: int (max ~6)
- slots_used: int
- items: Item[]
- Gold is NOT stored here (uses global pool)

**Hero Abilities:**
- class_abilities: Ability[2]
- weapon_ability: Ability
- passive_effects: Passive[]

No ultimate abilities. Weapon ability determined by weapon type.

### 32.2.2 Item Entity Schema

Items are immutable once created, except through: Refinement, Socketing, Salvaging

**Item Core Identity:**
```
Item {
  item_id: string,
  item_type: string,
  subtype: string,
  rarity: string,
  region_tags: string[],
  is_legendary: bool,
  is_blueprint_item: bool
}
```

**Item Modification Order (CRITICAL):**
1. Create item
2. Socketing
3. Refinement

Salvage reduces return if refined.

## 32.3 Core Entity Schemas — Facilities, Dungeons, Enemies

### 32.3.1 Facility Entity Schema

```
Facility {
  facility_id: string,
  facility_type: string,
  tier: int,
  town_id: string,
  is_unlocked: bool
}
```

### 32.3.2 Dungeon Entity Schema

```
Dungeon {
  dungeon_id: string,
  region_id: string,
  town_id: string,
  max_floor: int,
  completed_floors: int
}
```

### 32.3.3 Enemy Entity Schema

```
Enemy {
  enemy_id: string,
  enemy_family: string,
  region_id: string,
  level: int,
  is_boss: bool
}
```

### 32.3.4 Boss Entity Schema

- First campaign kill of a region boss guarantees Legendary
- Subsequent kills follow normal rarity rules
- Floor bosses drop Blueprints

### 32.3.5 Region Boss Access (Charged System)

- Each floor completion grants +1 Region Charge
- Charges accumulate up to 10
- 1 charge is consumed per Region Boss attempt

## 32.4 Persistence & Save Architecture

### 32.4.1 Save Layer Overview

| Save Layer | Scope | When It Updates |
|------------|-------|-----------------|
| Run Save | Current dungeon run | During combat & rooms |
| Campaign Save | Current campaign | On town return & progression |
| Meta Save | Post-campaign carryover | On campaign completion |

### 32.4.2 Campaign Save

```
CampaignSave {
  regions_unlocked: string[],
  towns: Town[],
  facilities: Facility[],
  heroes: Hero[],
  shared_storage: Resource[],
  global_gold: int,
  dungeon_progress: Dungeon[],
  region_charges: int
}
```

### 32.4.3 Autosave & Safety Rules

**Autosave Triggers:** Floor completion, Town return, Boss defeat, Facility upgrades

**Forbidden Save Events:** Mid-turn combat, Mid-resolution of ability effects, During RNG roll loops

## 32.5 Scene Architecture

### 32.5.1 High-Level Scene Hierarchy

```
GameRoot
 ├─ MetaController
 ├─ CampaignController
 │   ├─ TownController
 │   ├─ DungeonController
 │   └─ WorldEventController
 └─ UIController
```

### 32.5.2 Controller Responsibilities

| Controller | Owns | Does NOT Handle |
|------------|------|-----------------|
| MetaController | World Tome, Meta Save, Book of the Dead | Combat, Town logic |
| CampaignController | Campaign Save, Region progression, Global gold | Combat resolution |
| TownController | Facilities, Shop refresh, Defense | Dungeon logic |
| DungeonController | Run Save, Floor sequence, Extraction | Item generation |
| BattleController | Turn order, Grid, Damage, Victory | Saving, Loot |
| AIController | Target selection, Priority evaluation | Damage math |
| UIController | Rendering, Player input | Game logic |

### 32.5.3 Communication Rules

Controllers communicate via signals and data snapshots. No scene directly edits another scene's internal state.

## 32.6 Claude + Godot Implementation Contract

### 32.6.1 Core Principles

- **Data Drives Everything:** Code reads data and executes rules
- **Flat Numbers Stored, Modifiers Computed:** Apply bonuses at runtime
- **Deterministic Once Started:** RNG must be centralized and controllable

### 32.6.2 Project Structure (Godot 4.x)

```
/Scenes
  /Root, /Town, /Dungeon, /Battle, /UI
/Systems
  /Persistence, /Economy, /Combat, /AI, /Generation
/Data
  /Regions, /Facilities, /Items, /Enemies, /Dungeons, /Classes, /Races
/Resources
  /Icons, /SFX, /VFX
```

### 32.6.3 RNG Rules (Critical)

Use one RNG owner with: Seed support, Named roll methods, Optional debug logs

### 32.6.4 Scope Control

Claude must NOT invent: Additional facilities, New currencies, New stats, Extra ability slots, New progression layers

If a design gap exists: Add a TODO comment, do not implement guesses.

### 32.6.5 Implementation Milestone Order

1. Load schemas and validate
2. TownController + basic shop refresh
3. Inventory & equipment management
4. DungeonController room sequence
5. BattleController basic auto-attacks
6. Add class abilities
7. Add weapon abilities
8. Add refinement + socketing
9. Add bosses + region charges
10. Add meta systems (World Tome)

---

# 33. Progression, Scaling & Balance Framework

This section defines how Shops & Shadows scales over time while maintaining clarity, challenge, and long-term stability.
Progression is multi-axis, intentionally paced, and resistant to runaway power.

## 33.1 Design Goals

The progression system must:
- Feel rewarding without exponential stat growth
- Support farming without trivializing content
- Encourage experimentation, not single optimal builds
- Scale cleanly into post-campaign cycles
- Remain readable for non-technical players

No single progression axis should dominate all others.

## 33.2 Primary Progression Axes

Progression occurs across five parallel axes:

**Hero Progression:**
- Levels
- Base stats
- Class abilities

**Item Progression:**
- Rarity
- Refinement
- Sockets
- Blueprint crafting

**Facility Progression:**
- Tier upgrades (T1–T4)
- Service unlocks
- Shop output control

**Region Progression:**
- Dungeon floors
- Region bosses
- Race and class unlocks

**Meta Progression:**
- World Tome
- Carryover heroes/resources
- Post-campaign cycles

Each axis advances independently but synergizes with others.

## 33.3 Hero Leveling Model

**XP Sources:**
- Combat victories
- Dungeon completion
- Facility assignment (passive XP)
- Defense participation

**Level Curve:**
- Early levels: fast, frequent upgrades
- Mid levels: steady, predictable
- Late levels: slower, incremental gains

Hero level ups provide:
- Small flat stat increases
- No automatic ability unlocks (class defines abilities)

Levels enhance consistency, not burst power.

## 33.4 Enemy Scaling Model

Enemy strength scales by region and floor, not by hero level directly.

**Baseline Scaling:**
- Each region defines a base enemy stat band
- Dungeon floors add incremental difficulty
- Bosses sit above floor averages

**Scaling Rules:**
- Enemies never "match" hero stats
- Scaling assumes: Partial gear, Mixed party composition
- Defense encounters scale slower than dungeon encounters

**Enemy abilities are introduced gradually:**
- Regions 1–3: auto-attacks only
- Region 4+: limited abilities
- Regions 6–7: layered mechanics (still controlled)

## 33.5 Loot & Economy Scaling

**Material Flow:**
- Basic materials: Drop consistently, Accumulate naturally
- Region-specific materials: Drop selectively, Gate higher upgrades

**Gold Flow (Global Gold System):**
- All gold flows into global pool
- Earned via: Combat, Defense battles, Events, Salvaging
- Shop purchases draw from global gold

Gold income is tuned so:
- Players can equip heroes reasonably
- Over-gearing requires intentional farming

## 33.6 Item Power Growth Controls

To prevent item bloat:
- Refinement risk increases sharply after mid levels
- Salvaging returns diminishing materials
- Legendary items remain rare and controlled
- Blueprint items trade raw power for consistency

No item alone should invalidate:
- Positioning
- Party composition
- Tactical play

## 33.7 Difficulty Bands by Region

| Region | Difficulty Focus |
|--------|------------------|
| 1 | Core mechanics, low pressure |
| 2 | Resource identity, mild complexity |
| 3 | Party synergy importance |
| 4 | Enemy abilities introduced |
| 5 | Status interaction depth |
| 6 | Multi-threat encounters |
| 7 | Endgame systems combined |

Difficulty increases via mechanics, not raw stats alone.

## 33.8 Post-Campaign Cycle Scaling

After campaign completion:
- Game restarts from Region 1
- Enemy difficulty increases globally
- Corruption tiles and hazards re-enter

Player retains:
- Selected heroes
- World Tome bonuses
- Limited resources

Scaling rules:
- Early regions are harder than first campaign
- Late regions approach "perfect play" expectations
- Farming remains viable but slower

Post-campaign cycles emphasize mastery, not grind.

## 33.9 Anti-Runaway Safeguards

**Hard limits:**
- Inventory size caps
- Refinement caps (max 10)
- Socket limits
- Ability slots fixed (2 class + 1 weapon)

**Soft limits:**
- Diminishing returns on stacking effects
- Increased risk at high power
- More complex enemy responses

The game discourages "one build solves all."

## 33.10 Tuning Targets (MVP Baselines)

These are initial tuning goals, not permanent locks:

| Target | Value |
|--------|-------|
| Standard combat length | 4–7 turns |
| Boss combat length | 8–12 turns |
| Shop upgrades per region | 2–4 meaningful improvements |
| Expected hero deaths | Occasional, not constant |
| Defense failures | Rare with preparation, common if ignored |

## 33.11 Balance Adjustment Philosophy

Balance changes should:
- Favor clarity over precision
- Adjust numbers before mechanics
- Avoid retroactive player punishment

When in doubt:
- Reduce enemy output slightly
- Increase player agency instead of raw stats

---

# 34. Item System & Procedural Generation Framework

## 34.1 Item Design Philosophy

Items in Shops & Shadows are procedurally generated, facility-driven, and risk-oriented. They are designed to support a long-term roguelite loop where gear is constantly replaced, refined, salvaged, or lost.

**Core principles:**
- Items are primarily acquired through shops, not drops
- Facilities influence item output; players do not hand-craft items
- Items must be readable, replaceable, and disposable
- True BiS items are possible, but only through: Long-term RNG, Refinement risk, Repeated investment over time
- There is no guaranteed path to BiS
- Losing or breaking a near-BiS item is an intended outcome

**Non-goals:**
- No deterministic crafting trees
- No static, fixed legendary uniques
- No durability micromanagement
- No inventory clutter systems

## 34.2 Item Categories

| Category | Procedurally Generated | Notes |
|----------|------------------------|-------|
| Weapons | Yes | Primary source of combat abilities |
| Armor | Yes | Defensive stats |
| Accessories | Yes | Utility and passive effects |
| Tools | Yes | Resource-gathering gating |
| Consumables | Semi | Flask is permanent; others generated |
| Class Books | No | Quality-only, no rarity |

## 34.3 Item Identity Model

Each item is defined by a small, composable identity:

```
Item = Base Item + Quality Tier + Affix Set + (Optional) Region Passive Influence
```

Items are not stored as named entities. Names, stats, and descriptors are derived dynamically from their properties.

## 34.4 Quality System

Quality determines stat magnitude and risk, not mechanics.

| Quality | Descriptor Examples | Stat Range | Refinement Risk | Salvage Yield |
|---------|---------------------|------------|-----------------|---------------|
| Common | Rusty, Worn | Low | None (1–4 safe) | Low |
| Uncommon | Sturdy, Sharpened | Low–Mid | Very Low | Low–Mid |
| Rare | Fine, Exceptional | Mid–High | Moderate | Mid |
| Epic | Masterwork | High | High | High |
| Legendary | Mythic | Very High | Very High | Very High |

**Quality affects:**
- Stat roll ranges
- Consumable potency
- Refinement risk scaling
- Salvage output

**Quality does NOT affect:**
- Ability mechanics
- Class access
- Core gameplay rules

## 34.5 Procedural Naming Rules

**Standard Naming Grammar:**
`[Quality Descriptor] – [Base Item] – Of [Affix Theme]`

**Examples:**
- Rusty Sword
- Exceptional Dagger of Precision
- Masterwork Axe of Rupture
- Mythic Greataxe (legendary override)

Rules:
- "Of X" appears only if an affix theme exists
- Legendary items may override grammar for thematic names
- Names are derived; they are not manually authored

## 34.6 Affix System

Items may roll 1–3 affixes maximum depending on quality and facility tier.

### Affix Categories

**Offense:**
- +Flat Damage
- +Crit Chance
- +Crit Damage
- +Ability Damage (flat)

**Defense:**
- +Max HP
- −Damage Taken
- +Block Chance
- −Status Stack Received

**Utility:**
- +Speed (Turn Order)
- −Ability Cooldown (minimum 1 turn)
- +Resource Yield
- +Gold Gain

**Economy:**
- +Salvage Yield
- +Rare Material Chance
- −Shop Purchase Cost

**Cooldown reduction rules:**
- Cannot reduce abilities below 1 turn
- Appears only on Rare+
- Epic rolls higher values

**Affix rules:**
- No region affects affix pools
- Regions influence passives, not affixes
- Higher quality improves roll values, not mechanics

## 34.7 Facility-Based Item Generation

Facilities do not craft items directly. They generate shop inventory.

**Shop Slot Selection:**
- Player selects item type per slot
- UI displays: Materials required, Quality floor and ceiling, Possible affix categories

**Material Consumption:**
- Materials are pulled from shared storage (global inventory)
- Pull occurs on return from dungeon
- If insufficient materials: Slot is skipped, No partial generation

## 34.8 Consumables

### Health Flask
- Permanent inventory item
- Starts at 5/5 charges
- Refills on town return
- Upgraded via Jeweler / Glass facility
- Quality does not affect base flask

### Potions
- Buff-only consumables
- Single-use
- Quality increases: Buff duration, Buff potency

### Food
- Always provides small healing
- Higher quality adds buffs
- Chef can enhance food using herbs
- Quality improves duration and effect strength

No consumable tiers; quality only.

## 34.9 Tools

| Tool | Purpose |
|------|---------|
| Pickaxe | Ore |
| Hatchet | Wood |
| Fishing Pole | Fish + rare drops |
| Herb Pouch | Holds up to 5 herbs |

**Tool Scaling Model:**
- Quality → Resource quantity bonus
- Rarity → Rare resource chance
- No tool = no resource

**Example:**
- Exceptional Hatchet → +1 Wood, +5% rare chance
- Epic Hatchet → +2 Wood, +15% rare chance

## 34.10 Blueprints

Blueprints are recipes, not items.

**Rules:**
- Dropped from dungeon floor bosses
- Not region-locked
- Enable Epic-quality crafting

**Blueprint crafting allows:**
- Dual-region passive pools
- Player-selected stat priority
- Output remains random within constraints

Blueprint crafting:
- Requires facility interaction
- Consumes special materials
- Produces one Epic item

## 34.11 Legendary Items

**Legendary items:**
- Never appear in shop rolls
- Require: Facility Tier 4, Legendary material, Item type selection

**Output:**
- Random Legendary of chosen type
- No static uniques
- Region-themed passives may appear

## 34.12 Salvaging

Salvaging destroys an item to return materials.

**Rules:**
- Yield scales with quality
- Prevents hoarding
- Feeds upgrade, refinement, and blueprint loops
- Essential economic sink

## 34.13 Class Books (Special Case)

| Property | Rule |
|----------|------|
| Rarity | None |
| Quality | Yes |
| Stackable | No |
| Overwrites Class | Yes |

Quality improves:
- Passive values
- Ability numbers

Class books do not use affixes or rarity tiers.

## 34.14 UI & Player Readability

- Tooltips explain: Quality, Affixes, Facility source
- No hidden math
- Complexity introduced gradually
- Refinement and risk clearly communicated

---

# 35. Economy, Gold Flow & Resource Balance

## 35.1 Economy Design Goals

The economy of Shops & Shadows is designed to be tight, readable, and decision-driven. Gold and materials are meant to enable progression while forcing meaningful tradeoffs, not passive accumulation.

**Primary goals:**
- Reduce player bookkeeping and cognitive load
- Ensure gold is always valuable at every stage of the game
- Support frequent hero rotation without friction
- Prevent runaway inflation or infinite loops
- Reinforce the shop- and facility-driven progression loop
- Make losses (item breakage, bad refinements) meaningful but fair

## 35.2 Currencies & Value Types

### Gold (Global Currency)

**Gold is a single, shared global resource.**

Gold is used for:
- Purchasing items from shops
- Upgrading facilities
- Refining items
- Blueprint crafting
- Flask upgrades
- Late-game services

Gold is earned from:
- Dungeon combat
- Floor completion
- Dungeon bosses
- Region bosses
- Events
- Salvaging items
- Town defense victories

**There is no per-hero gold tracking. All gold earned flows into the global pool automatically.**

### Materials

Materials are stored in a **shared inventory across all towns and regions**.

Material types include:
- Basic materials (global, always relevant)
- Regional materials (used for higher tiers)
- Rare, Epic, and Legendary materials (gated progression)

**Key rules:**
- Materials are never auto-consumed
- Players manually commit materials to: Facility upgrades, Shop production slots, Blueprint crafting
- Materials persist across towns and regions

## 35.3 Gold Sources

Gold enters the economy through multiple controlled sources:

**Primary Sources:**
- Enemy combat rewards
- Dungeon floor completion bonuses
- Dungeon boss rewards
- Region boss rewards

**Secondary Sources:**
- Events and encounters
- Salvaging items
- Town defense victories

**Design intent:**
- Early game gold is scarce but sufficient
- Mid-game gold stabilizes and enables planning
- Late-game gold pressure returns via higher costs and risks

## 35.4 Gold Sinks

Gold must be continually spent to maintain progression.

**Major Gold Sinks:**
- Shop purchases
- Facility tier upgrades
- Item refinement attempts
- Blueprint crafting
- Flask upgrades
- Late-game services and rerolls

**Design intent:**
- Gold should rarely feel "solved"
- Hoarding is allowed, but always competes with opportunity cost
- No activity generates gold without also presenting spending pressure

## 35.5 Shop Pricing Philosophy

Shop prices are deterministic and transparent.

**Prices are influenced by:**
- Item category (weapon, armor, tool, etc.)
- Item quality
- Facility tier producing the item
- Current region difficulty

**Rules:**
- No dynamic supply/demand simulation
- No hidden inflation modifiers
- Shop prices scale upward across regions, not within a single region
- Legendary items never appear in shop rolls

## 35.6 Facility Upgrade Costs

Facility upgrades require:
- Gold
- Materials (basic → regional → rare)

**Cost philosophy:**
- Tier 1–2 upgrades are accessible and frequent
- Tier 3 upgrades require planning
- Tier 4 upgrades require commitment and saving

Facilities do not auto-consume materials or gold. All upgrades are player-initiated.

## 35.7 Material Flow & Stockpiling

The economy is designed so materials accumulate naturally over time.

**Key rules:**
- Dungeon runs provide more materials than are immediately needed
- Players are encouraged to stockpile for: Facility upgrades, Blueprint crafting, Legendary attempts
- Resource scarcity is regional, not global

This prevents:
- Always-empty storage
- Forced grinding loops
- Accidental material starvation

## 35.8 Defense Economy

Town defense is an economic stabilizer, not a punishment loop.

**Defense rewards:**
- Gold (added directly to global gold pool)
- Hero XP for stationed defenders

**Important rules:**
- Heroes do not die in defense battles
- Defense acts as: Passive gold income, Safe hero training, Long-term town value protection
- Defense gold is not tracked separately and does not require manual transfer

## 35.9 Salvage vs Sell Decisions

When an item is no longer needed, the player must choose:

**Sell:**
- Immediate gold gain
- Supports short-term purchases

**Salvage:**
- Returns materials
- Supports long-term progression
- Fuels refinement, upgrades, and blueprints

There is no universally correct choice. The optimal decision depends on:
- Current progression stage
- Material needs
- Gold pressure

## 35.10 Inflation & Anti-Bloat Controls

To prevent economic collapse or item saturation, the game relies on:
- Refinement break risk
- Salvage loss
- Facility tier caps
- Shop slot limits
- Legendary crafting gates
- Region-based scaling

No infinite loops exist for: Gold, Materials, Items

## 35.11 Post-Campaign Economy Scaling

In post-campaign cycles:
- All systems remain the same
- Costs increase
- Rewards increase
- Pressure increases

The economy scales horizontally, not by adding new currencies.

---

# 36. Player Flow, Menus & Core Game Loop

This section defines the authoritative player flow for Shops & Shadows.
It governs when systems are accessible, how state changes, and what is saved or lost, ensuring consistent behavior across UI, combat, and progression.

**This section supersedes any implied flow from earlier sections.**

## 36.1 Core Gameplay Loop (Authoritative)

The game operates on the following loop:

```
Town Phase
 → Shop & Facilities
 → Party Assembly
 → Dungeon Selection
 → Dungeon Floors (1–4)
 → Floor Completion / Failure
 → Resolution (Loot / Death / Defense)
 → Return to Town
```

**Hard Rules:**
- The player may only be in one phase at a time
- Phase transitions are explicit and saved
- No system is accessible outside its allowed phase

## 36.2 Town Phase Rules

The Town Phase is the only phase where management actions occur.

**Allowed Actions:**
- Buy items from the shop
- Assign facility slots
- Upgrade facilities
- Assign heroes to facilities
- Change hero equipment
- Use class books
- Refine items
- Salvage items
- Craft via blueprints
- Configure town defense
- View world map
- Select dungeon / floor

**Locked Actions:**
- No combat
- No dungeon events
- No resource gathering
- No shop refresh unless triggered by rules

**Town Inventory Rules:**
- Inventory is shared globally
- **Gold is global** (single shared pool)
- Materials are never auto-consumed
- All facility material pulls require player confirmation

## 36.3 Shop Interaction Flow

### Shop Availability
- Only accessible in the current town
- Only refreshes when:
  - A dungeon floor is completed
  - The player returns to town after extraction
  - A defense resolution completes

### Shop Slot Selection
When selecting shop slots:
- Player sees:
  - Required materials per slot
  - Material source (global storage)
  - Resulting item types
- Materials are only consumed after confirmation
- Cancelling reverts all changes

### Shop Restrictions
- No shop access inside dungeons
- No mid-run refresh
- Legendary items never appear naturally

## 36.4 Party Assembly & Preparation

### Party Rules
- Party size is fixed by progression
- Only selected party enters dungeon
- Heroes not in party may remain in town roles

### Equipment Rules
Each hero must have:
- Weapon
- Armor
- Accessories
- Health Flask (permanent)

Weapon ability is previewed before entry.
Consumables occupy inventory slots.

### Class Rules
- Class books overwrite existing class
- Class changes only allowed in town
- Lich class obeys sacrifice rules

## 36.5 Dungeon Entry & Floor Selection

### Dungeon Entry
Player selects:
- Dungeon
- Floor (if unlocked)

Floor selection persists between runs.

### Floor Rules
- Floors unlock sequentially
- Once a dungeon boss is defeated:
  - All floors remain unlocked permanently
- Region dungeon access requires charged progress (Section 26)

## 36.6 In-Dungeon Rules

### Allowed Actions
- Combat actions
- Movement
- Ability usage
- Consumable usage
- Environmental interactions

### Locked Actions
- No shop access
- No equipment changes
- No class changes
- No refining or salvaging

### Extraction Rules
- Extraction allowed only at end of floor
- Player chooses:
  - Continue to next floor
  - Return to town

### Early Exit
Exiting mid-floor:
- Heroes survive
- All run loot is lost
- No shop refresh
- No progress saved

## 36.7 Death, Failure & Resolution

### Hero Death
- Death is permanent
- Hero recorded in Book of the Dead
- Equipment dropped unless insured
- No revival

### Floor Failure
Party wiped:
- Player restarts at beginning of that floor
- Player may choose earlier floor instead

### Floor Completion
- Loot finalized
- Shop refresh triggered
- Autosave occurs
- Optional XP bonus if continuing run

## 36.8 Town Defense Resolution

### Timing
Town defense resolves:
- When player returns to town
- After dungeon completion or extraction

### Outcomes
**Victory:**
- Defense gold added to global pool
- Heroes gain XP

**Failure:**
- One random building tiers down (min T1)
- Attack chance resets per rules

### Defense Rules
- No hero death
- No item loss
- Formation matters
- Defensive bonuses apply only to assigned units

## 36.9 Save System & Autosaves

Autosaves occur:
- On floor completion
- On town return
- After defense resolution
- After boss defeat
- After campaign completion

Manual saving is not required.

## 36.10 Player Information Guarantees

The game must always clearly display:
- Material costs before commitment
- Refinement risks
- Permanent loss warnings
- Boss requirements
- Region charge progress
- Inventory limits

**No hidden mechanics or silent failures.**

## 36.11 Explicit Non-Goals

The game does not include:
- Real-time combat
- Manual defense combat (viewing optional only)
- **Per-hero gold tracking** (gold is global)
- Timed crafting queues
- Hidden stat scaling
- Forced grind loops

---

# 37. UI State Mapping & Interaction Rules

This section defines all UI states, what is visible, what is interactive, and what is locked at any given time.

Its purpose is to:
- Prevent UI overlap and clutter
- Ensure Godot scenes are cleanly separated
- Make interaction rules unambiguous for automation
- Avoid "can I do X right now?" edge cases

**This section is authoritative for UI behavior.**

## 37.1 UI Design Principles

### Single Primary Focus Rule
- Only one primary interaction panel may be active at a time
- Secondary info panels may appear only if contextual

### Context-Driven Visibility
- UI appears only when relevant
- No persistent clutter
- Hidden by default, revealed by intent

### State-Locked Interactions
If an action is not allowed in the current phase, the UI element:
- Is hidden OR
- Is visible but disabled with tooltip

### Explicit Player Feedback
- Every locked action explains why it is locked

## 37.2 Global UI Layers (Always Available)

These elements are always present regardless of state:

**Top Bar:**
- Global Gold
- Region Name
- Current Town Name
- World Tome access (post-campaign only)

**Bottom Bar:**
- Party Summary (portraits only)
- Current Phase Indicator (Town / Dungeon / Defense)

**Overlay Tooltips:**
- Hover-based explanations
- No modal blocking unless explicitly stated

## 37.3 Town Phase UI States

### 37.3.1 Town Overview Screen (Default)

**Visible:**
- Town map background
- Facility icons
- Shop icon
- Dungeon entrance icon
- Defense facility icon

**Hidden:**
- Inventory
- Hero details
- Shop contents

**Actions:**
- Click facility → Facility UI
- Click shop → Shop UI
- Click dungeon → Dungeon Select
- Click hero portrait → Hero Detail

### 37.3.2 Facility UI State

**Visible:**
- Facility name & tier
- Assigned heroes
- Upgrade button
- Facility-specific controls (refine, blueprint, etc.)

**Hidden:**
- Shop inventory
- Dungeon UI

**Rules:**
- Material requirements shown before confirmation
- No auto-pulling from inventory
- Locked features show unlock conditions

### 37.3.3 Shop UI State

**Visible:**
- Shop item grid
- Item costs
- Item stats & passives
- Shop slot configuration (if editing)

**Hidden:**
- Facility UI
- Dungeon UI

**Rules:**
- Purchasing removes item from shop globally
- No item duplication
- Shop refresh only via rules (Section 36)

### 37.3.4 Hero Detail UI

**Visible:**
- Stats
- Equipment
- Abilities
- Passives
- Inventory
- Flask charges

**Expandable Panels:**
- Ability details
- Weapon ability
- Refinement history (hover)

**Rules:**
- No equipment changes outside town
- Class books usable only here
- Warnings shown for irreversible actions

## 37.4 Dungeon Selection UI

**Visible:**
- Dungeon list
- Floor selection
- Floor completion indicators
- Region charge progress (if applicable)

**Locked:**
- Floors not yet unlocked
- Region boss if insufficient charges

**Rules:**
- Player explicitly selects floor
- Last selected floor remembered
- Entry confirmation required

## 37.5 In-Dungeon Combat UI

### 37.5.1 Combat Grid View

**Visible:**
- Grid tiles
- Units
- Active effects (icons only)
- Enemy intent indicators

**Hidden:**
- Inventory management
- Shop
- Facility UI

### 37.5.2 Selected Unit Panel (Bottom)

Appears when a unit is selected.

**Shows:**
- HP / Mana
- Active status effects (with countdown icons)
- Abilities
- Weapon ability
- Equipped items (icons only)

**Rules:**
- One selected unit at a time
- Switching selection collapses previous panel

### 37.5.3 Tile Inspection Mode

**Activated by:**
- Holding inspect key
- Clicking inspect icon

**Shows:**
- Tile effects
- Duration (∞ or countdown)
- Source (enemy / environment / ability)

Hidden otherwise.

## 37.6 Extraction & Floor Completion UI

### End-of-Floor Panel

**Options:**
- Continue to next floor
- Return to town

**Displays:**
- XP gained
- Items collected
- Warnings about continuing

**Rules:**
- Extraction only allowed here
- Autosave triggers on choice

## 37.7 Defense Resolution UI

**Triggered On:**
- Return to town
- Defense event roll

**Displays:**
- Outcome (Victory / Failure)
- Gold gained
- Building tier changes (if any)
- XP gained by defenders

**Rules:**
- No interaction during resolution
- Option to view replay (optional)

## 37.8 Modal UI Rules

### Hard Modal (Blocks Everything)
- Class overwrite confirmation
- Hero sacrifice
- Item destruction
- Town destruction events

### Soft Modal (Non-Blocking)
- Tooltips
- Info panels
- Warnings

## 37.9 Error Handling & Edge Cases

- Invalid actions never fail silently
- UI must explain:
  - Why something is locked
  - What is required to unlock it
- No overlapping modals
- No action chains without confirmation

## 37.10 Accessibility & Clarity (Baseline)

- Icons always paired with tooltip text
- Status effects use:
  - Color
  - Symbol
  - Countdown number
- No color-only indicators

---

# 38. Enemy AI & Targeting Logic

This section defines how enemies think, how they choose targets, and how they act in combat.

**Note:** For enemy archetypes and behavior patterns, see **Section 25 (Enemy AI Archetypes & Behavior Rules)**. This section (38) defines targeting logic and AI tier progression.

Enemy AI is designed to be:
- Predictable but not trivial
- Readable to the player
- Scalable across regions
- Compatible with turn-based grid combat

## 38.1 AI Design Goals

### Clarity Over Complexity
- The player should understand why enemies act the way they do
- Intent indicators always reflect next action

### Threat-Based, Not Random
- Enemies evaluate targets based on threat and opportunity
- Randomness is used only as a tiebreaker

### Tiered Intelligence
- Early regions use simple AI
- Later regions unlock advanced behaviors
- Bosses override standard rules

## 38.2 Enemy AI Tiers

Enemy behavior is defined by AI Tier, not enemy type.

### AI Tier 0 — Feral
(Region 1)
- Always attacks nearest valid target
- No ability usage
- No positioning logic
- Ignores status effects

**Used for:** Wildlife, Early corrupted creatures

### AI Tier 1 — Basic Combatant
(Region 2–3)
- Chooses targets based on proximity + low HP
- May avoid heavily armored targets
- Can use one basic ability on cooldown
- Understands taunt

**Used for:** Trained humanoids, Organized monsters

### AI Tier 2 — Tactical
(Region 4–5)
- Evaluates threat score
- Prioritizes:
  - Healers
  - Low-defense units
  - Units with dangerous status effects
- Uses abilities intelligently
- Can reposition

**Used for:** Elite enemies, Dungeon captains

### AI Tier 3 — Strategic
(Region 6–7, Bosses)
- Predicts player formations
- Baits cooldowns
- Targets synergies
- Spawns or commands sub-units

**Used for:** Bosses, Commanders, Void entities

## 38.3 Target Evaluation System

Each enemy calculates a Target Score for every valid enemy unit.

### Base Formula (Conceptual)
```
Target Score =
    Threat Value
  + Vulnerability Value
  + Opportunity Modifiers
  - Deterrents
```

### 38.3.1 Threat Value
Calculated from:
- Damage dealt recently
- Healing performed
- Buffs applied
- Aggro-generating abilities

High threat = more likely target.

### 38.3.2 Vulnerability Value
Increases when:
- HP is low
- Armor / defense is low
- Unit is crowd-controlled
- Unit is isolated

### 38.3.3 Opportunity Modifiers
Bonuses applied for:
- Backline access
- AoE potential
- Ability synergy (e.g., shock stacks present)
- Finishing blow potential

### 38.3.4 Deterrents
Reduces score when:
- Target has taunt
- Target has thorns / retaliation
- Target has high defense
- Target is guarded

## 38.4 Taunt & Forced Targeting Rules

- Taunt overrides target scoring
- If multiple taunts exist:
  - Highest taunt strength wins
- Bosses may partially resist taunt
- Taunt duration is always visible to the player

## 38.5 Enemy Ability Usage Logic

Enemies with abilities follow this order:

1. **Check Ability Availability**
   - Cooldown
   - Resource cost

2. **Check Value**
   - Will it hit multiple targets?
   - Will it interrupt?
   - Will it secure a kill?

3. **Execute Ability**
   - If no valid ability → basic attack

Abilities are never wasted randomly.

## 38.6 Movement & Positioning Rules

Enemies may reposition if:
- A better target is reachable
- They can avoid retaliation
- A formation bonus is disrupted

**Restrictions:**
- One movement per turn
- No movement if rooted
- Boss movement rules may override

## 38.7 Enemy Intent System

Before acting, each enemy displays an Intent Icon:
- Attack target
- Ability type
- AoE indicator (if applicable)

**Intent is:**
- Locked once shown
- Only changed by interrupts or forced movement

## 38.8 Status Effect Awareness

Enemy AI:
- Understands stuns, roots, taunts
- Partially understands DoTs
- Fully understands countdown effects (e.g., Doom)

Higher AI tiers respond more intelligently.

## 38.9 Boss AI Overrides

Bosses may:
- Ignore taunt
- Target objectives instead of units
- Spawn hazards or turrets
- Act on multiple initiative counts

Boss logic is scripted on top of AI Tier 3.

## 38.10 Defense Battle AI Adjustments

In Town Defense:
- Enemies prioritize structures only if allowed
- Otherwise follow standard targeting
- No permanent death for heroes
- AI difficulty scales with region progression

## 38.11 Difficulty Scaling Hooks

Enemy AI scaling knobs:
- Target score weights
- Ability cooldown efficiency
- Willingness to reposition
- Coordination between enemies

**Used by:** Region, Dungeon tier, Post-campaign mode

---

# 39. Status Effects System

This section defines the runtime rules governing status effects, including how they are applied, stacked, displayed, resolved, and removed.

**Note:** For the authoritative list of approved status effects and their registry entries, see **Section 27 (Status Effect Registry)**. This section (39) defines implementation behavior.

The system is designed to be:
- Turn-based
- Readable
- Composable across abilities, items, and enemies
- Expandable without rework

## 39.1 Design Goals

### Clarity First
Every status effect must clearly communicate:
- What it does
- How long it lasts
- What happens when it resolves

### Limited Stacking, Meaningful Impact
- Fewer stacks, stronger effects
- Avoids "spreadsheet combat"

### Unified Countdown Logic
- No hidden timers
- Countdown-based effects resolve predictably

## 39.2 Status Effect Categories

All status effects fall into one of five categories:

### A. Damage Over Time (DoT)
Deals damage each turn or on resolution.

**Examples:** Burn, Bleed, Shock (non-stun damage component), Poison

### B. Control
Restricts actions or positioning.

**Examples:** Stun, Root, Daze, Fear

### C. Buff
Improves stats or abilities.

**Examples:** Defense Up, Attack Up, Cooldown Reduction, Shield

### D. Debuff
Reduces stats or applies penalties.

**Examples:** Armor Break, Weakness, Slow, Vulnerability

### E. Countdown Effects
- Resolve only when timer reaches zero
- Damage or transformation occurs on resolution

**Examples:** Doom, Delayed Explosion, Crystal Shatter, Void Collapse

## 39.3 Universal Status Properties

Every status effect has the following properties:

| Property | Description |
|----------|-------------|
| Name | Unique identifier |
| Category | One of the five categories |
| Source | Ability / Item / Enemy |
| Stacks | Current stack count |
| Max Stacks | Hard cap |
| Duration / Timer | Turns remaining |
| Refresh Rule | Replace / Extend / Amplify |
| Dispel Type | Buff / Debuff / None |
| Icon | UI reference |
| Priority | Resolution order |

## 39.4 Stack Behavior Rules

### 39.4.1 Stack Types

Status effects use one of the following stack models:

**A. Linear Stack**
- Each stack adds flat value
- Example: Burn: +2 damage per stack

**B. Threshold Stack**
- Effects trigger at stack thresholds
- Example: Shock: At 5 stacks → Daze

**C. Countdown Extension**
- Each stack increases resolution timer
- Used for Doom-type effects

### 39.4.2 Stack Limits
- Most effects cap at 3–5 stacks
- Boss-only effects may cap higher
- UI always shows: Stack count, Max possible

## 39.5 Countdown Effects (Core Mechanic)

Countdown effects are a key system pillar.

### Rules
- Countdown decreases at end of unit's turn
- When countdown reaches 0:
  - Effect resolves
  - Damage / transformation occurs
  - Status is removed

### Example — Doom
- Doom(2): Resolves in 2 turns
- Doom(4): Resolves in 4 turns, Deals increased damage

Applying additional stacks:
- Increases timer
- Increases final damage

## 39.6 Status Application Rules

Status application always succeeds unless:
- Target is immune
- Status explicitly resists

If status already exists:
- Apply stack rules
- Refresh or extend duration as defined

**Immunity is explicit, not assumed.**

## 39.7 Removal & Cleansing

### Removal Types
- Cleanse Buff
- Cleanse Debuff
- Full Purge
- Manual Removal (Ability-specific)

### Rules
- Countdown effects are harder to cleanse
- Boss effects may be immune to cleanse

## 39.8 Status Priority & Resolution Order

Statuses resolve in this order:
1. Control checks (stun, root)
2. Countdown resolution
3. DoT ticks
4. Buff / Debuff expiry

This order is consistent across all combat types.

## 39.9 UI & Readability Rules

Each status icon shows:
- Icon image
- Stack number
- Countdown (if applicable)

**Color coding:**
- Red: Damage
- Blue: Control
- Green: Buff
- Purple: Countdown / Corruption

**Hover tooltip includes:**
- Full description
- Source
- Resolution effect

## 39.10 Enemy vs Hero Status Rules

- Heroes and enemies use the same system
- Bosses may have:
  - Stack resistance
  - Partial immunity
  - Modified resolution

## 39.11 Status Synergies

Some statuses interact:
- Shock + Wet → Bonus effect
- Burn + Oil → Amplified damage
- Doom + Void → Extended resolution

**Synergies are explicitly defined, never implicit.**

## 39.12 Expansion Hooks

System supports:
- New categories
- Region-specific effects
- Post-campaign corruption mechanics
- Item-based status modification

No refactor required.

---

# 40. Balance & Scaling Framework

This section defines how Shops & Shadows scales difficulty, rewards, and power across:
- Regions
- Dungeons
- Heroes
- Items
- Facilities
- Post-campaign cycles

The goal is to ensure the game remains:
- Challenging but fair
- Predictable but flexible
- Resistant to runaway power
- Tunable via data, not code rewrites

## 40.1 Balance Design Philosophy

### Horizontal Progression Over Vertical Spikes
- Power grows through options, not raw numbers
- Synergy matters more than stat inflation

### Risk-Based Power
- High power requires risk (refinement, death, resource loss)
- Safe play yields stability, not dominance

### Region-Gated Difficulty
- Difficulty increases by region, not endlessly per dungeon
- Regions act as clear balance brackets

## 40.2 Core Scaling Axes

All balance scaling operates on four primary axes:

### A. Region Index
- Primary difficulty driver
- Controls: Enemy stats, AI tier, Status complexity, Reward ceilings

### B. Dungeon Floor
- Controls encounter density
- Introduces stronger enemy compositions
- Slightly increases rewards per floor

### C. Facility Tier
- Increases player options, not raw stats
- Enables higher-quality items and systems

### D. Post-Campaign Cycle
- Reuses same systems with higher pressure
- No new currencies introduced

## 40.3 Hero Power Scaling

### Hero Strength Comes From:
- Class abilities
- Weapon abilities
- Status synergy
- Positioning
- Item quality (not quantity)

### Explicit Non-Scaling Factors
- No exponential stat growth
- No infinite level scaling
- No multiplicative stacking beyond defined limits

## 40.4 Enemy Scaling Rules

Enemies scale by region, not by time spent farming.

**Enemy scaling increases:**
- Max HP
- Damage
- Ability access
- AI tier
- Resistance to stacking effects

**Enemy scaling does NOT:**
- Increase endlessly
- Ignore player systems
- Require grind to overcome

## 40.5 Item Power Ceilings

Item strength is bounded by:
- Quality tier
- Affix caps
- Refinement risk

**Rules:**
- Refinement above safe tiers introduces break chance
- Perfect items are possible but rare
- Legendary items are strong but not mandatory

## 40.6 Refinement Risk Curve

Refinement tiers are grouped:

| Tier Range | Risk |
|------------|------|
| +1 to +4 | Safe |
| +5 to +8 | Increasing negative effects |
| +9 to +10 | High break chance |

**Design Intent:**
- Early refinement feels rewarding
- Mid refinement feels risky
- Late refinement is a gamble

## 40.7 Facility Scaling Impact

Facilities scale option space, not raw power.

**Examples:**
- More shop slots
- Higher quality floors
- Access to blueprints
- Refinement systems

Facilities never trivialize combat alone.

## 40.8 Gold & Economy Scaling

**Gold scaling rules:**
- Early regions: tight but forgiving
- Mid regions: stable with planning
- Late regions: pressure returns

Gold sinks scale faster than sources to prevent hoarding dominance.

## 40.9 Defense Scaling

Town defense difficulty scales by:
- Region progression
- Number of towns owned
- Campaign phase

**Defense remains:**
- Non-lethal to heroes
- A training and income system
- A maintenance pressure, not a punishment

## 40.10 Region Boss Scaling

**Region bosses:**
- Use fixed stat brackets per region
- Do not scale infinitely
- Remain dangerous due to mechanics, not numbers

**Repeat kills reward:**
- Normalized loot chances
- No guaranteed legendary after first clear

## 40.11 Status Effect Scaling

Status scaling is bounded by:
- Stack caps
- Countdown limits
- Boss resistances

**Higher regions:**
- Introduce more countdown effects
- Reduce effectiveness of low-tier status spam

## 40.12 Post-Campaign Scaling

**Post-campaign cycles:**
- Increase enemy pressure
- Increase material requirements
- Increase refinement risk relevance

No new systems introduced.

## 40.13 Anti-Exploitation Rules

To prevent degenerate strategies:
- No infinite loops
- No passive-only wins
- No zero-risk farming

All powerful strategies require exposure to loss.

## 40.14 Balance Data Ownership

**All scaling values are:**
- Data-driven
- Editable via tables
- Not hardcoded

**Claude should:**
- Implement systems with tunable values
- Avoid baking numbers into logic

---

# Document Footer

## Master GDD Version 2.0 — Complete

**Sections:** 1–40 (Fully Integrated)
**Last Updated:** 2025-12-20
**Integration Status:** Complete

### Key Authoritative Rules Applied:
- **Global Gold System:** Single shared currency pool across all heroes and towns
- **Shared Inventory:** Materials persist globally, no per-town separation
- **Item Modification Order:** Create → Socket → Refine
- **Region Boss Charge System:** 1 charge per floor, max 10, 1 consumed per attempt
- **Salvaging:** Returns base materials only (no legendary materials)
- **Status Effects:** Per Section 27 registry, countdown-based, capped stacks
- **Data-Driven Design:** Flat integers, no percentages stored

### Fix Notes Applied:
- Fix 35.F: Global Gold System (Sections 11, 19, 31, 32, 33, 35, 36, 37)
- Fix 31.C: Salvaging System (Section 31.16)
- Fix 31.D: Item Modification Order (Section 31.14)
- Fix 26: Region Boss Charge Mechanics (Section 26)

---

*End of Master Game Design Document*
