# Shops & Shadows — Game Design Document (v1.3, Studio Developer Edition)

## 1. High-Level Overview

A single-player cozy grim-fantasy roguelite where the player is a **Shopkeeper** who hires heroes, manages a growing town, upgrades production facilities, explores corrupted lands, gathers resources, and ultimately rebuilds regions devastated by spreading corruption.

You are not the one swinging the sword. You are the one making sure the sword exists, the town stands, and the next band of would-be heroes has a reason to try again.

<!-- Developer Note: This GDD is structured for readability and modularity, optimized for Godot and Claude-based toolchains. -->

---

## 2. Core Fantasy & Vision

### 2.1 Core Fantasy

The fantasy: You are the quiet force behind every adventure.

Heroes come and go. Some die ignobly in forgotten tunnels. Some survive and grow into legends. The greatest of them eventually retire into permanent roles in your town’s infrastructure — blacksmiths, guards, trainers, and specialists that support future generations of adventurers.

You, the Shopkeeper:

- Recruit expendable heroes.
- Equip them from your limited, hand-curated shop inventory.
- Send them into corrupted regions to push back the darkness.
- Bring back resources to grow the town and unlock new options.
- Decide who becomes a **Legacy Hero** and what role they serve long-term.

You are not the warrior — you **empower** them.

### 2.2 Tone & Aesthetic

- **Cozy grim-fantasy** — think warm lantern-lit town interiors contrasted with ominous corrupted forests and ruins.
- The world is dangerous but not hopeless.
- Humor and charm exist in the personalities of heroes, townfolk, and events, even while the stakes remain high.

### 2.3 Design Pillars

1. **Town Growth ↔ Hero Power ↔ Region Cleanse**  
   The stronger the town, the better gear you can offer. Better gear lets heroes cleanse deeper corruption. Cleansed regions unlock more town growth.

2. **Persistent Progression with Disposable Heroes**  
   Heroes are intentionally expendable, but their contributions matter:
   - Their deaths feed your **Book of the Dead**.
   - Their successes can promote them into **Legacy roles**.

3. **Item-Centric Progression**  
   The backbone of progression is:
   - Resource → Facility → Crafted Gear → Shop → Heroes → Adventure → More Resource

4. **Exploration as Risk/Reward Routing**  
   Map choices matter. The player picks routes through combat, events, resources, and corruption risk — not just blindly marching forward.

---

## 3. World Structure & Regions

### 3.1 Regions Overview

The world is divided into **7 major regions** (initially 6 active + 1 final/endgame), each with:

- A unique biome
- A distinct corruption “flavor”
- Unique resource distributions
- Region-specific **legendary materials**
- A major **regional boss** whose defeat partially purifies the land

Regions unlock in a mostly linear fashion:

1. Verdant Isles (starter)
2. Timberwild Frontier
3. Ironmarch Foothills → **Town 3 Raid event**
4. Blazewind Barrens (post-raid)
5. Shattered Coast (Jeweler unlock)
6. Gloomspire Necropolis (undead/late-game)
7. Final region (endgame boss; TBD in expansion)

After Region 3, the **Town 3 Raid** occurs: corruption attacks your early hub, forcing you to defend and then **expand** your town. From this point on, town footprints are larger, and more facilities can be built.

### 3.2 Regional Legendary Materials

Each region has at least one unique legendary material:

- **Desert / Blazewind Barrens**  
  - *Sunshard Crystal*: used for legendary weapons/armor of a solar/fire theme.
- **Gloomspire Necropolis**  
  - *Soul Ore*: dense spiritual metal, used for spectral weapons and shields.  
  - *Spectral Logs*: ghost-touched wood for staves, bows, and ritual items.  
  - *Deadman’s Grass*: rare herb used in potent life/death potions and rituals.

Legendary materials are **not purchasable**, only earned from:
- Boss rewards
- High-tier corruption nodes
- Rare late-game events

### 3.3 Fog-of-War & Race Vision

Dungeon/adventure maps are node-based with fog-of-war:

- Party reveals adjacent nodes by default.
- Certain races offer vision bonuses:
  - **Elves** have **Keen Sight** → reveal +1 additional node in all directions.
- Corruption trails are shown visually, indicating where corruption has already spread or may spread next.

---

## 4. Core Gameplay Loop

### 4.1 Macro Loop

1. **Prepare Town**
   - Choose which facilities produce items.
   - Assign facility shop slots (which item categories are allowed to appear).
   - Ensure enough resources are in Storage to support crafting.
   - Use refinement and socketing (if unlocked) to improve gear.
   - Decide which heroes to hire/keep.
   - Allocate **insurance slots** for high-value items.

2. **Select Party & Equipment**
   - Shopkeeper chooses a party within current **Shop Level** capacity.  
     - Early: 3 heroes max.  
     - Later: up to 5–6 heroes.
   - Equip heroes:
     - Head / Chest / Legs / Weapons / Off-hands / Accessories.
   - Assign a **backpack** to each hero (small/medium/large).
   - Choose food, potions, and tools.

3. **Adventure Out**
   - Enter an adventure map in the chosen region.
   - Follow branching node paths:
     - Combat nodes
     - Resource rooms
     - Events
     - Rest rooms
     - Boss node at the end
   - The Shopkeeper does not appear on the battlefield but serves as the abstract “inventory brain”:
     - Party chooses whether resources go on heroes or into the **Shopkeeper’s bag**.

4. **Face Boss**
   - Multi-phase boss battle, often with unique tile patterns and corruption behavior.
   - Success:
     - Legendary materials
     - High-tier resources
     - Blueprint fragments
   - Failure:
     - Party wipe → only insured items survive; gold may be partially salvaged if a Bank exists.

5. **Return to Town**
   - All materials (except special Field Artificer items) are deposited into **Town Storage**.
   - Facilities consume resources on the next prep phase to refresh the shop’s stock.
   - Town upgrades may be constructed:
     - New facilities
     - Facility tier upgrades
     - Storage upgrades
     - Shop size increases

6. **Repeat in Next Region / Next Run**

---

### 4.2 Node Types

- **Combat Node**
  - Standard monster encounter.
  - Chance for monster part drops and gold.
  - Chance for background resource nodes to appear (clickable after combat).

- **Resource Room**
  - Focused on environmental resources:
    - Ore veins
    - Logging spots
    - Herb patches
  - Requires correct tools:
    - **Pickaxe** for ore
    - **Hatchet** for wood
    - **Herb Pouch** for herbs
  - Yields a small number of resources, with a small chance of higher-tier resources based on:
    - Tool quality
    - Hero traits
    - Race/class synergy with the environment

- **Event Room**
  - Narrative or mechanical choice events:
    - Lost traveler
    - Strange merchant
    - Spirit encounters
    - NPC requests (item in exchange for reward)
  - No skill checks; outcomes are based on player choice and risk tolerance.

- **Rest Room**
  - Appears every 4–5 rooms, never back-to-back.
  - Allows:
    - Healing
    - Food buffs
    - Potion crafting (if Alchemist facility exists)
    - **Field Artificer** crafting
  - Pre-boss rest room is guaranteed.

- **Boss Room**
  - Fixed at the end of each major route.
  - Multi-phase encounter tied to the region’s corruption theme.

---

## 5. Town Management & Facilities

### 5.1 Town Growth Over Time

The town progresses through several phases:

- **Early (Towns 1–3)**
  - Core facilities only:
    - Blacksmith
    - Leatherworker
    - Woodsman
    - Chef
    - Alchemist
  - Facilities can reach T4 in these early towns (but feature sets like Jeweler are locked until later regions).

- **Mid (Post Town 3 Raid: Town 4–5)**
  - Town layouts become larger.
  - **Guard Yard** unlocked (Town 4) for Town Defense.
  - **Jeweler** unlocked (Town 5) for socketing and gem crafting.

- **Late (Town 6+)**
  - Specialized late-game facilities:
    - Necropolis Forge
    - Glassworks (for advanced flask upgrades)
    - Future expansion facilities.

---

### 5.2 Facility Tiers & Services

All crafting facilities follow a common tier pattern:

- **Tier 1 — Basic Production**
  - Can craft simple items from common resources.
  - Provides low-tier gear and consumables to the shop.

- **Tier 2 — Improved Production**
  - Better stat ranges.
  - Slightly more resource-efficient.
  - Expands item variety.

- **Tier 3 — Refinement Unlock**
  - Unlocks **Refinement** services:
    - Incrementally boosting items with some risk at higher levels.
  - May add special services per facility (e.g., re-rolling certain stats).

- **Tier 4 — Legendary & Blueprint Crafting**
  - Allows use of legendary materials.
  - Enables **Blueprint Recipes**.
  - Produces rare and legendary items.

<!-- Developer Note: Implement facilities as data-driven processors, each with a config for inputs, outputs, and tier-based rule sets. -->

---

### 5.3 Facility Types (Core)

#### Blacksmith
- Produces: weapons, heavy armor, shields, metal tools (pickaxe).
- Uses: ore resources.
- Refinement: improves physical stats, durability, and special weapon traits.
- Legendary: region-themed legendary weapons and armor.

#### Leatherworker
- Produces: light armor, medium armor, some accessories.
- Uses: monster hides, leather-related monster parts.
- Refinement: dodge, mobility, and utility stats.
- Legendary: nimble armor sets, dodge-heavy passives.

#### Woodsman
- Produces: bows, staves, wooden shields, woodcutting hatchets.
- Uses: wood resources.
- Refinement: ranged damage, accuracy, and sometimes elemental procs when combined with Jeweler.

#### Chef
- Produces: food items.
- Uses: herbs + monster meats.
- Effects:
  - Baseline: small healing.
  - Higher tiers: long-lasting buffs (damage, defense, speed, resistances).

#### Alchemist
- Produces: potions and multi-dose flasks.
- Uses: herbs + glass (later, via Glassworks).
- Effects:
  - Basic potions: small heals, small buffs.
  - High tiers: potent effects with multiple doses per flask.

---

### 5.4 Jeweler (Town 5 Unlock)

- Produces: gems, socketed items, gem fusions.
- Gem rarities:
  - Common → simple stat bonus.
  - Uncommon → small utility effect.
  - Rare → stronger bonus or mixed stats.
  - Epic → proc-based or conditional effects.
  - Legendary → powerful and unique.

- Tier services:
  - **T1** — Basic socketing, 1-socket gear.
  - **T2** — More sockets, mid-tier gems, minor polishing (small rerolls).
  - **T3** — Gem fusion and refinement with risk.
  - **T4** — Legendary gemworking; unique gem abilities.

---

### 5.5 Legacy Heroes as Workers

Heroes that become **Legacy** can be assigned as workers:

- **At facilities**:
  - Improve production quality.
  - Slightly reduce crafting time (for delayed items like legendaries).
  - Add small, thematic bonuses (e.g., a retired Ranger at the Woodsman improves bows).

- **At guard/yards**:
  - Improve Town Defense success.
  - Provide passive buffs in that region.

Legacy heroes can be **recalled** for adventuring:
- They temporarily leave their job.
- Their job slot becomes empty until replaced or they return.

---

### 5.6 Town Defense

After the Town 3 Raid:

- **Guard Yard** unlocks.
- Periodic corruption assaults target the town.
- Player assigns heroes as defenders:
  - Melee fighters
  - Ranged defenders
  - Casters
- Success yields:
  - Resources
  - Reputation
  - Possibly rare materials
- Failure:
  - Temporary town facility debuffs
  - Minor resource loss

---

## 6. Combat System

### 6.1 Battlefield Grid

The battlefield is a **tile grid**:

- Early game: **4 columns × 2 rows** (front/back).
- After Town 3: **4 columns × 3 rows** for both sides.
  - Allows more tactical formation.
  - Supports large enemies and AoE patterns.

Heroes and enemies occupy distinct tiles. Targeting is based on:
- Rows (front/back/mid)
- Columns (left/right)
- Area patterns (line, diamond, cross, etc.)

---

### 6.2 Turn Order & Actions

Turn order is typically:

- Initiative = Base Speed + weapon modifiers + temporary effects.
- Re-evaluated at key points (e.g., major buffs/debuffs).

Each hero turn:
- 1 primary action (attack, skill, defend, use consumable).
- Movement or certain utility actions may be free or partial depending on design.

---

### 6.3 Tile Effects

Most tiles are **normal**. Some can be temporarily altered by skills, bosses, or corruption:

- **Burning** — damage over time.
- **Blessed** — extra healing or defense.
- **Sticky** — movement penalties.
- **Poisoned** — poison damage and/or debuffs.
- **Corrupted** — corruption-themed penalties, lower resistances, or boss synergies.

UI behavior:
- Hovering over a tile highlights it.
- Tooltip shows:
  - Tile type
  - Effect summary
  - Duration (e.g., “2 rounds” or “∞” for permanent).

---

### 6.4 Ability Types

- **Damage**
  - Single-target strikes.
  - Row attacks.
  - Column attacks.
  - Full AoE.

- **Support**
  - Direct heals.
  - Shields/barriers.
  - Buffs to stats or resistances.

- **Utility**
  - Pushing/pulling units.
  - Swapping unit positions.
  - Creating or removing tile effects.

---

### 6.5 Consumables in Combat

- One consumable use per hero turn (unless a specific passive breaks this rule).
- Multi-dose flasks:
  - 3-dose baseline.
  - Upgradable via Glassworks and Alchemist later.
- Food buffs:
  - Applied before or at rest rooms.
  - Persist across multiple battles with a visible turn/floor counter.

---

### 6.6 Boss Fights

Bosses are:
- Multi-phase.
- Often manipulate tiles (corrupted zones, hazards).
- May summon adds or alter turn order.
- Have phase thresholds such as:
  - 70% HP → Phase 2
  - 40% HP → Phase 3

Boss UI:
- Boss HP bar.
- Phase indicators.
- Effects icons.

---

<!-- Developer Note: Implement combat as a state machine with separate managers for turn order, tiles, and effects. Use data-driven skill definitions. -->

## 7. Items, Crafting, Refinements & Backpacks

### 7.1 Resource Tiers

Core resource tiers:

- **T1** — Copper, Softwood, Common Herbs  
- **T2** — Iron, Oakwood, Sharp Herbs  
- **T3** — Silver, Spiritwood, Bloom Herbs  
- **T4** — Mythril, Eldertree, Soul Herbs  

Late-game:
- Legendary materials (e.g., Sunshard, Soul Ore) per region.

---

### 7.2 Tools

Tools are **not** standard gear. They are special items that gate resource collection:

- **Pickaxe** — required for ore nodes.
- **Hatchet** — required for wood nodes.
- **Herb Pouch** — required for herb nodes; may hold a limited number of herbs.

Without tool:
> “You lack the proper tool to gather this.”

Tools:
- Are bought once early (low gold cost after building the facility).
- Can be upgraded by relevant facilities for higher resource yields.

---

### 7.3 Refinement (Tier 3 Facility Feature)

Refinement allows incremental upgrades with risk:

**Refinement Levels:**
- **1–4:** Safe  
  - Always positive increases in one stat from the chosen stat group.

- **5–8:** Risk  
  - In addition to a positive stat increase, there is a **5–20% chance** of a small negative side effect appearing (e.g., slight penalty to another stat).

- **9–10:** Break Risk  
  - Item has a **30% (9) / 50% (10)** chance to be destroyed on refinement attempt.
  - If it survives, it receives a strong stat increase.

---

#### Stat Groups (Player Chooses One Per Item)

- **Offense:**
  - Damage
  - Speed
  - Crit Chance

- **Defense:**
  - Max HP
  - Physical Resistance
  - Magic Resistance
  - Block/Dodge

- **Technique:**
  - Cooldown Reduction
  - Mana Efficiency
  - Healing Received
  - Elemental or special proc chance

Each refinement selects **one random stat** from the chosen group to increase.

---

### 7.4 Legendary Crafting (Tier 4)

Legendary items cannot be bought in shops or found in standard loot. They must be:

- Crafted at **T4 facilities** using legendary materials.
- Each craft:
  - Requires a legendary material from that region.
  - Locks the facility’s “legendary slot” for one expedition.
  - Produces a **random legendary** item within that facility’s category (e.g., weapon, armor, gem).

Legendary items:
- Have unique passives.
- Are primary candidates for insurance.
- Tie into region flavor (e.g., Sunshard gear burns, Soul gear interacts with undead).

---

### 7.5 Gems & Socketing

Handled primarily by the **Jeweler** (unlocked at Town 5):

**Gem Rarity Tiers:**

- Common → small single-stat bonuses.
- Uncommon → slightly stronger bonuses or secondary stats.
- Rare → mixed stats or small conditional effects.
- Epic → procs or strong conditional bonuses.
- Legendary → unique build-defining effects.

Gear may have:
- 0–3 sockets depending on item type and Jeweler services.

Socketing UI:
- Shows socket slots.
- Shows inserted gems.
- Displays combined effects.

Higher Jeweler tiers:
- Allow more sockets.
- Enable **Gem Fusion** (combine two lower rarity gems into a higher one).
- Allow gem refinement (small risk of negative twist).

---

### 7.6 Backpacks & Inventory

Heroes:

- Start with smaller backpacks:
  - **Small**: 3 slots
  - **Medium**: 4 slots
  - **Large**: 6 slots (late-game)

Backpack slots are used for:
- Consumables (food, potions)
- Extra gear
- Sometimes resources (early game)

Gold is shown separately and not a backpack slot item.

Shopkeeper:

- Has a **separate bag** with 6–8 slots.
- Used primarily as the **resource collection buffer**.
- **Resources do NOT stack** — each resource occupies one slot, pushing strategic decisions.

---

### 7.7 Insurance Slots

Insurance slots:
- Limited (e.g., 2–4 based on upgrades).
- Mark items as protected from loss if the entire party dies.
- Are filled manually during prep / rest phases.
- UI warns before big fights if high-value items are uninsured.

---

## 8. Heroes (Races, Classes, Passives)

### 8.1 Races (Examples & Hooks)

- **Human**
  - Balanced stats.
  - Broad class compatibility.

- **Elf**
  - Keen Sight: +1 node vision into fog-of-war.
  - Good synergy with ranged and magical classes.

- **Dwarf**
  - Increased ore yield from mining nodes.
  - Slight resistance bonuses.

- **Beastkin**
  - Increased monster part drop rates.
  - Synergizes with Leatherworker and Chef outputs.

More races can be introduced in later towns and expansions.

---

### 8.2 Classes (Examples)

- **Warrior**
  - Front-line melee.
  - Taunts, shields, and damage.

- **Ranger**
  - Ranged damage.
  - Synergizes with Woodsman and Jeweler (bows and gemmed gear).

- **Mage**
  - AoE and tile manipulation.
  - Synergizes with Alchemist and Jeweler.

- **Field Artificer** (Mid/Late Unlock)
  - Crafts during **Rest Rooms** only.
  - Has **two extra crafted-item slots** that are treated specially:
    - These items can bypass automatic transfer to Storage at run end.
  - Tear-Off Passive: increased chances to harvest extra monster parts.
  - High synergy with resource collection and blueprint usage.

---

### 8.3 Legacy System

Heroes can become **Legacy Heroes** by:

- Surviving major milestones (finishing a region, etc.).
- Meeting certain achievement-like milestones (e.g., number of boss kills, number of successful runs).

Legacy Heroes:
- Are stored in a **Legacy Roster**.
- Can be assigned to:
  - Facilities (e.g., a Warrior becomes a town guard captain).
  - Town Defense posts.
- Provide passive bonuses based on:
  - Race
  - Class
  - Traits

Legacy Carry Limit:
- Scales with **number of towns owned**.
- Prevents hoarding every hero forever.

---

## 9. Monsters & Corruption

### 9.1 Monster Families

Each region has distinct monster families, e.g.:

- Undead (Gloomspire Necropolis)
- Fey and forest beasts (Timberwild Frontier)
- Golems and miners (Ironmarch Foothills)
- Desert monsters, sand beasts (Blazewind Barrens)
- Spectral horrors (late-game corruption nodes)

Each family:
- Has affinities/weaknesses.
- Drops specific monster parts for crafting (Leatherworker, Chef, etc.).

---

### 9.2 Corruption System

Corruption is:

- Represented on the map as **corruption trails**.
- More intense in certain regions.
- Capable of:
  - Increasing node difficulty.
  - Introducing corrupted tiles in combat.
  - Enabling unique enemy modifiers.

Some corrupted nodes:
- Spread corruption to neighboring nodes.
- Yield better rewards but are much riskier.

Regional bosses:
- Act as anchors for each region’s corruption.
- Defeating them permanently clears some corrupted nodes and opens new paths or facilities.

---

## 10. UI / UX

### 10.1 Combat UI

Key components:

- **Hero Panels**
  - Show HP, mana, buffs/debuffs.
  - Can be expanded or collapsed.
  - When expanded: show abilities, items, passives, and gear summary.

- **Enemy Intent Indicators**
  - Show intended target and approximate attack type.
  - Helps the player make tactical decisions.

- **Tile Highlighting**
  - Hover displays tile effect and duration.

- **Boss UI**
  - Boss HP bar and phase indicators.

- **Damage Numbers**
  - Color-coded:
    - White: Physical
    - Blue: Magic
    - Yellow: Crit
    - Red outline: lethal hit
    - Purple: corruption-based

---

### 10.2 Adventure Map UI

- Node map with fog-of-war.
- Clearly marked:
  - Combat nodes
  - Events
  - Resources
  - Rest rooms
  - Boss

- Corruption trails:
  - Visual indicator of where corruption has spread or is spreading.

- Background resource nodes:
  - Clickable after battles if present.
  - Highlighted subtly.

---

### 10.3 Town & Shop UI

- **Facility Slot Assignment Panel**
  - Choose which facilities fill which shop slots.
  - Shows resource consumption preview and expected item categories.

- **Shop Inventory View**
  - Items displayed with:
    - Name
    - Rarity color
    - Short stat summary
    - Icons for sockets/refinement level.

- **Storage UI**
  - Lists resources.
  - No stacking of base resources (design choice to prioritize meaningful space management).
  - Shows legendary material count prominently.

---

## 11. Economy & Resource Flow

### 11.1 Gold

- Earned from:
  - Combat encounters
  - Events
  - Boss fights
- Spent on:
  - Items in the shop
  - Facility upgrades
  - Tools
  - Backpacks
  - Possibly some town services.

Hero death:
- Without a **Bank**:
  - Hero’s gold is lost with them.
- With a Bank:
  - Some percentage (e.g., 25%) is salvaged and split between survivors or town coffers.

---

### 11.2 Resource Flow

1. Heroes and Shopkeeper gather resources on adventures.
2. On successful return:
   - Resources move into **Town Storage**.
3. Facilities consume resources each “cycle” to produce items.
4. Items appear in the Shop for purchase.
5. Heroes equip items → undertake new adventures → more resources.

Legendary materials:
- Bypass standard storage for special UI emphasis.
- Are used only in legendary crafting or certain high-tier blueprints.

---

## 12. Glossary & Developer Notes

- **Shopkeeper** — The player avatar; manages town, hires, and equips heroes.
- **Facility** — Production building (Blacksmith, Alchemist, etc.) with tiers and services.
- **Refinement** — Risk-based item stat improvement unlocked at Tier 3 facilities.
- **Legendary Material** — Region-locked, ultra-rare item used only for legendary crafts.
- **Insurance Slot** — Protects specific items from loss on party wipe.
- **Legacy Hero** — Hero elevated into a permanent town role; grants passive bonuses.
- **Corruption Node** — Map node with increased difficulty and unique rewards/risks.
- **Blueprint** — Special recipe enabling unique items, often requiring multiple expeditions to complete.
- **Backpack** — Hero-specific inventory extension that determines how many items they can carry.

<!-- Developer Note: Represent heroes, items, facilities, regions, and nodes via data assets (e.g., JSON or Godot Resources) to allow tool pipelines (Claude, scripts) to auto-modify content. -->
