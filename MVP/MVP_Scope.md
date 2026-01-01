# MVP_SCOPE.md — Shops & Shadows (Vertical Slice)

Version: 0.1 (MVP Slice Definition)  
Purpose: Define the smallest playable build that proves the core loop.  
Rule: This MVP is the gate before adding new regions, races, classes, town defense, blueprints, socketing, refinement risk, post-game, etc.

---

## 1) MVP Goal

Deliver a **single playable loop** where the player can:

1) Start in **Town**  
2) Choose a **Dungeon Floor**  
3) Fight through a short sequence of rooms  
4) **Defeat a Floor Boss**  
5) Return to town  
6) See the **Shop refresh** based on what was gathered/earned  
7) Buy/equip upgrades and repeat

If the player can complete that loop without debugging tools, the MVP is a success.

---

## 2) MVP Player Fantasy (What it should feel like)

- You are a **shopkeeper manager**, not a monster slayer.
- You recruit a few heroes, gear them from your shop, and send them into danger.
- You come back richer (or poorer), then make smarter shop decisions.
- The game is cozy grim-fantasy: readable, strategic, “one more run.”

---

## 3) MVP Content Boundaries (What’s IN vs OUT)

### 3.1 Included (IN)

**World / Progression**
- Region: **Region 1 — Forest Haven**
- Town: **Greenroot Village** (only)
- Dungeon: **Forest Haven Dungeon**
- Floors: **Floor 1 only** (farmable after first clear)
- Boss: **Floor 1 Boss** (simple)

**Heroes**
- Party Size: **3 heroes**
- Races: **Humans only**
- Classes: **2 starter class books available**
  - Defender (tank)
  - Striker (damage)
- Class swapping via class book overwrite is allowed (simple behavior).

**Items**
- Item generation: **randomized** from templates
- Categories in MVP:
  - Weapons: Sword / Axe (2 types)
  - Armor: Chest only (1 slot)
  - Accessory: 1 slot (ring)
  - Consumables: Food (1), Buff Potion (1)
  - Tools: Pickaxe + Hatchet (optional in MVP; see Tools section)
- **Quality only** in MVP (no rarity tiers yet unless already required by your current system).
- No socketing, no blueprints, no refinement risk (unless already locked as “core”; recommended OUT for MVP).

**Economy**
- Gold: **GLOBAL GOLD** only
- Materials: **GLOBAL SHARED INVENTORY**
- One simple gold sink: buy items from shop
- One simple gold source: combat rewards + floor completion

**Shop**
- Shop refresh occurs after:
  - Returning to town after completing Floor 1 OR
  - Successfully extracting at the end of Floor 1 (MVP only has 1 floor)
- Facilities: **Blacksmith only (Tier 1)**
- Shop has **5 stock slots**
- Player can allocate:
  - 3 blacksmith slots (weapons/armor mix) + 2 “general” slots (food/potion/accessory)
  - OR a simpler split (see Shop Setup)

**Combat**
- Turn-based grid combat (MVP grid = **4x2**)
- Intention arrows: enemies show intended target
- Status effects in MVP:
  - Burn (damage over time)
  - Stun (skip next turn)
- Enemy AI: simple targeting rules (nearest/frontline preference)
- No ultimates, no multi-phase boss

**UI**
- Town screen (facility + shop)
- Party screen (equip items)
- Dungeon screen (enter floor)
- Combat screen (grid + actions)
- Reward screen (loot → global inventory)
- Minimal tooltips

**Save**
- Basic save/load:
  - global gold
  - global inventory
  - hero roster (3 heroes)
  - equipped gear
  - floor completion flag

---

### 3.2 Excluded (OUT) — Explicitly Not in MVP

These are intentionally postponed:

- Additional towns / regions / region destruction
- Town defense system
- World Tome / post-game cycle
- Book of the Dead / revival systems
- Blueprints and legendary crafting rules
- Socketing
- Refinement risk curve
- Field Artificer class + crafting
- Alchemist / Chef facility depth (beyond 1 consumable category)
- Multiple floors per dungeon
- Region bosses / charge storage
- Corruption tiles / tile hazards (beyond basic “empty tiles”)
- 8 races, all region race unlock logic
- All late-game classes (Stormcaller, Lich, Void, etc.)

MVP rule: if a feature requires new menus, new currencies, or new subsystems, it is OUT.

---

## 4) MVP Core Loop (Detailed)

### 4.1 Start State
Player begins in **Greenroot Village** with:
- 3 human heroes (level 1)
- Starter gear (basic weapon + chest OR none; pick one standard)
- 1 class book for Defender and 1 class book for Striker available via shop or tutorial reward
- Blacksmith facility built (Tier 1)
- Global gold: small starter amount (e.g., 25)

### 4.2 Town Phase
Player can:
- Assign class books (overwrite class)
- Equip items
- View global gold + global inventory
- Select shop slot focus (simple)
- Buy up to 5 items (if available)

### 4.3 Dungeon Entry
Player chooses:
- Enter **Floor 1**
- Party: 3 heroes
- No early extraction in-room; extraction only at end-of-floor (MVP: end of run)

### 4.4 Dungeon Rooms (Floor 1)
Floor 1 contains:
- 4–6 rooms total
- Room composition:
  - 3–5 combat rooms
  - 0–1 event room (optional for MVP)
  - 1 boss room (final)

### 4.5 Combat Resolution
Each combat:
- Turn-based on 4x2 grid
- Heroes act: move OR attack OR ability (if available)
- Enemies act: attack or simple ability (optional: boss only)

### 4.6 Rewards & Return
After floor completion:
- Earn gold
- Earn a small set of materials
- Chance at 1 equipment drop (optional)
- Return to town (forced in MVP)

### 4.7 Shop Refresh
Upon return:
- Shop stock refreshes using:
  - Blacksmith slot allocation
  - Available materials in global inventory
- Player buys new items (global gold)

### 4.8 Repeat
Player can re-run Floor 1 to farm materials and gold.

---

## 5) MVP Systems Required (Minimum Implementation Set)

### 5.1 Data & Registries
- DataRegistry (loads JSON)
- SeededRNG (deterministic per run)
- Status registry (Burn/Stun at minimum)

### 5.2 Economy
- GlobalGold: add/spend
- GlobalInventory: add/remove materials + items
- Purchase flow: try_spend_gold(cost)

### 5.3 Party & Equipment
- Hero entity (stats, class, gear slots)
- Gear slots in MVP:
  - weapon
  - chest
  - accessory
  - consumable (food OR potion; simplest is 1 slot)
- Equipment affects stats (damage/defense/HP)

### 5.4 Items
- ItemTemplate + random roll by Quality
- Minimal affix system optional; if included:
  - 1–2 affixes only
  - no refinement/sockets

### 5.5 Shop
- Generate 5 items per refresh
- Shop items are unique: bought item is removed from stock
- Shop refresh happens only on floor completion/return to town

### 5.6 Dungeon Flow
- Floor definition
- Room sequence generation
- Combat encounter selection from small pool

### 5.7 Combat
- Grid
- Turn order
- Basic attacks
- 1 class ability per class OR weapon ability (pick one for MVP)
- Status apply/resolve

### 5.8 UI
- Town UI
- Shop UI
- Party equipment UI
- Dungeon entry UI
- Combat UI

### 5.9 Save
- Save/Load core state

---

## 6) MVP Combat Rules (Simplified)

### 6.1 Grid
- Grid size: 4 columns x 2 rows
- Front row: closer to enemies
- Back row: safer positioning

### 6.2 Turns
- Turn order determined by speed (or fixed hero order for MVP)
- Each unit acts once per round

### 6.3 Actions
- Move (1 tile)
- Attack (target in range; melee adjacent, ranged up to 2 tiles if needed)
- Ability (class-based OR weapon-based)

### 6.4 Status Effects (MVP)
- Burn: deals damage at start of turn for X turns
- Stun: skip next action, then remove

---

## 7) MVP Shop Setup (Simple Option)

MVP uses the simplest production approach:
- Player chooses shop “focus”:
  - Focus A: Weapons-heavy
  - Focus B: Armor-heavy
  - Focus C: Balanced
- Behind the scenes, Blacksmith produces items accordingly.
- Materials required are shown (preview), but MVP can allow production if materials are sufficient.

Shop slots: 5
- 3 slots: Blacksmith output
- 2 slots: General consumables/accessory

---

## 8) MVP Materials (Minimal Set)

MVP uses 4–6 materials max to avoid clutter:

- wood_basic
- ore_basic
- hide_basic (optional; can skip if leather facility is OUT)
- meat_basic (food)
- herb_basic (potion/food; optional)
- gold (currency, not inventory stack)

**Rule:** Materials gained per room are small (1–3), boss gives slightly more.

---

## 9) MVP Boss Requirements

Floor 1 boss should:
- Be beatable with starter gear after 1–2 loops
- Have 1 “telegraphed” mechanic:
  - e.g., charges a heavy hit next turn (intention icon)
- Drop:
  - guaranteed gold + materials
  - small chance at a higher-quality item

No turrets, no multi-phase, no summon adds in MVP.

---

## 10) MVP Success Criteria (Definition of Done)

MVP is complete when:

1) Player can start a new run
2) Buy/equip items
3) Enter Floor 1
4) Clear rooms + boss
5) Receive rewards into global inventory
6) Return to town
7) Shop refreshes based on materials
8) Player can buy upgrades and repeat
9) Save/load works without losing core state

---

## 11) MVP Stretch Goals (Only if MVP is stable)

These are allowed ONLY after the success criteria is met:

- Add 1 event room type
- Add 1 more monster family
- Add 1 weapon ability per weapon type
- Add a second floor (Floor 2) but no region progression yet
- Add tool gating for extra material bonuses

---

## Fix Notes — MVP Scope

- Ensure “Global Gold + Shared Inventory” is consistently used in all MVP systems.
- Exclude Town Defense, World Tome, post-game cycles, blueprints, socketing, and refinement risk until MVP success criteria is met.
- MVP uses only Region 1 / Greenroot Village / Blacksmith Tier 1 / Floor 1 dungeon loop.