# Region 1 GDD Rules Extract

This document extracts the canonical rules from `Shops_And_Shadows_MASTER_GDD.md` that apply to Region 1 implementation.

---

## 1. Town Phase Rules (GDD 36.2)

### Allowed Actions
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

### Locked Actions
- No combat
- No dungeon events
- No resource gathering
- **No shop refresh unless triggered by rules**

### Town Inventory Rules
- Inventory is shared globally
- **Gold is global** (single shared pool)
- Materials are never auto-consumed
- All facility material pulls require player confirmation

---

## 2. Core Facility Types (GDD 5.3)

Region 1 includes these core facilities (Early: Regions 1-3):

| Facility | Produces | Uses | Notes |
|----------|----------|------|-------|
| **Blacksmith** | weapons, heavy armor, shields, metal tools | ore resources | Physical gear |
| **Leatherworker** | light/medium armor, accessories | monster hides, leather parts | Dodge/mobility |
| **Woodsman** | bows, staves, wooden shields, hatchets | wood resources | Ranged damage |
| **Chef** | food items | herbs + monster meats | Healing, buffs |
| **Alchemist** | potions and multi-dose flasks | herbs + glass | Heals, buffs, potent effects |

### Facility Tiers (GDD 5.2)

| Tier | Features |
|------|----------|
| **T1** | Basic production, simple items from common resources |
| **T2** | Better stat ranges, slightly more efficient, expanded variety |
| **T3** | **Refinement Unlock** - incremental boosting with risk |
| **T4** | **Legendary & Blueprint Crafting** - use legendary materials |

### Region 1 Tier Cap
- Facilities can reach **T4** in early towns (Regions 1-3)

---

## 3. Starter Town Kit (GDD 5.6)

Town 1 starts empty. New regions get the Starter Town Kit:
- Training Hall (T1)
- Blacksmith (T1)
- Leatherworker (T1)
- Alchemist (T1)
- Storage
- Housing (T1)
- Shop (fed by facilities)

---

## 4. Shop Interaction Flow (GDD 36.3)

### Shop Availability
- Only accessible in the current town
- Only refreshes when:
  - A dungeon floor is completed
  - The player returns to town after extraction
  - A defense resolution completes

### Shop Slot Selection
When selecting shop slots:
- Player sees: Required materials per slot, Material source (global storage), Resulting item types
- Materials are only consumed after confirmation
- Cancelling reverts all changes

### Shop Restrictions
- No shop access inside dungeons
- No mid-run refresh
- **Legendary items never appear naturally**

---

## 5. Shop Pricing Philosophy (GDD 35.5)

Prices are deterministic and transparent.

**Prices influenced by:**
- Item category (weapon, armor, tool, etc.)
- Item quality
- Facility tier producing the item
- Current region difficulty

**Rules:**
- No dynamic supply/demand simulation
- No hidden inflation modifiers
- Shop prices scale upward across regions, not within a single region
- Legendary items never appear in shop rolls

---

## 6. Gold System (GDD 11.1, 35.2)

### Global Gold Rules
- **Gold is a single, shared global resource**
- All gold earned flows into the global pool automatically
- There is no per-hero gold tracking
- Defense gold is NOT a separate storage - it flows directly to global gold
- Shop purchases draw from global gold, not hero-specific gold
- Hero rotation does not affect economic access
- Gold is never lost on hero death (it's already in global pool)

### Gold Sources
- Enemy combat rewards
- Dungeon floor completion bonuses
- Dungeon boss rewards
- Region boss rewards
- Events and encounters
- Salvaging items
- Town defense victories

### Gold Sinks
- Shop purchases
- Facility tier upgrades
- Item refinement attempts
- Blueprint crafting
- Flask upgrades
- Late-game services and rerolls

---

## 7. Item-Selling Rules

### Which Facilities Sell Items

Based on GDD analysis:

| Facility | Sells Items? | What They Sell |
|----------|-------------|----------------|
| **General Store (Shop)** | YES | Consumables, weapons, armor, accessories |
| **Training Hall** | YES | Class Books (GDD line 617: "Training Hall sells starter Class Books") |
| **Blacksmith** | NO | Unlocks item groups, does not sell |
| **Leatherworker** | NO | Production facility |
| **Woodsman** | NO | Production facility - does NOT sell materials |
| **Chef** | NO | Production facility |
| **Alchemist** | NO | Unlocks item groups, does not sell |
| **Storage** | NO | Bank management only |
| **Inn** | NO | Hero recruitment only |

### HARD RULE: Only General Store + Training Hall sell items
- All other facilities provide services (unlocks, crafting, storage, recruitment)
- Woodsman explicitly does NOT sell materials

---

## 8. Facility Upgrade Costs (GDD 35.6)

Facility upgrades require:
- Gold
- Materials (basic -> regional -> rare)

**Cost Philosophy:**
- Tier 1-2 upgrades are accessible and frequent
- Tier 3 upgrades require planning
- Tier 4 upgrades require commitment and saving

Facilities do not auto-consume materials or gold. All upgrades are player-initiated.

---

## 9. Town Return Behavior (GDD 36.7)

### Floor Completion
- Loot finalized
- Shop refresh triggered
- Autosave occurs
- Optional XP bonus if continuing run

### Extraction Rules
- Extraction allowed only at end of floor
- Player chooses: Continue to next floor OR Return to town

### Early Exit (mid-floor)
- Heroes survive
- All run loot is lost
- No shop refresh
- No progress saved

---

## 10. Region 1 Specific Rules

### Town Structure (GDD 3.2)
- Region 1 has **two starter towns** introducing foundational races and classes
- Towns A and B introduce different content

### Regional Boon (GDD 3.4)
When both Region 1 towns operational:
- Combat Boon: +X% Max HP
- Gathering Boon: +X% Wood yield

### Legendary Material (GDD 3.5)
- **Verdant Resin (T3)** - Forest Haven legendary material

---

## 11. UI Rules (GDD 10.3)

### Facility Slot Assignment Panel
- Choose which facilities fill which shop slots
- Shows resource consumption preview and expected item categories

### Shop Inventory View
- Items displayed with: Name, Rarity color, Short stat summary, Socket/refinement icons

### Storage UI
- Lists resources (no stacking - meaningful space management)
- Shows legendary material count prominently
- **Global shared storage** - not per-town

---

## 12. Explicit Non-Goals (GDD 36.11)

The game does NOT include:
- Real-time combat
- Manual defense combat (viewing optional only)
- **Per-hero gold tracking** (gold is global)
- Timed crafting queues
- Hidden stat scaling
- Forced grind loops

---

## Summary: Region 1 Hard Rules

1. **Gold is global** - no per-hero, no dungeon-only gold
2. **Only General Store + Training Hall sell items**
3. **Woodsman does NOT sell materials**
4. **No Healer facility** - town return auto-heals
5. **Inn + Housing merged** - single facility for recruitment
6. **Shop refreshes only on**: floor completion, extraction, or defense resolution
7. **Legendary items never in shop rolls**
8. **Materials never auto-consumed** - player must confirm

---

*Extracted from: Shops_And_Shadows_MASTER_GDD.md v2.0*
*Generated: 2026-01-10*
