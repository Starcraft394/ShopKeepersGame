# Region 1 Implementation Inventory

This document catalogs all Region 1 implementation artifacts.

---

## 1. Data Files

### 1.1 Town Definitions
| File | ID | Facilities |
|------|-----|------------|
| `Data/Towns/town_thornhaven.json` | town_thornhaven | 10 facilities (see below) |

### 1.2 Facility JSON Files

| File | ID | Type | Sells Items? | Notes |
|------|-----|------|--------------|-------|
| `Data/Facilities/dungeon_thornhaven.json` | dungeon_thornhaven | dungeon | NO | Floor selection |
| `Data/Facilities/inn.json` | inn | inn | NO | Hero recruitment (merged with Housing) |
| `Data/Facilities/shop_thornhaven.json` | shop_thornhaven | shop | YES | General Store - pool-driven |
| `Data/Facilities/blacksmith.json` | blacksmith | blacksmith | NO | Unlocks offhands_t1 |
| `Data/Facilities/leatherworker.json` | leatherworker | production | NO | Crafting placeholder |
| `Data/Facilities/woodsman.json` | woodsman | woodsman | NO | Flavor only |
| `Data/Facilities/chef.json` | chef | production | NO | Crafting placeholder |
| `Data/Facilities/alchemist.json` | alchemist | alchemist | NO | Unlocks consumables_t2 |
| `Data/Facilities/training_hall.json` | training_hall | training_hall | YES | Sells class books |
| `Data/Facilities/storage.json` | storage | storage | NO | Bank/stash management |

### 1.3 Shop Pool Files
| File | ID | Categories |
|------|-----|------------|
| `Data/Shops/Pools/pool_region1_general.json` | pool_region1_general | consumables, weapons, offhands, books |
| `Data/Shops/Pools/pool_region1_upgrades.json` | pool_region1_upgrades | Stash upgrades |

---

## 2. GDScript Files

### 2.1 Core Data Types
| File | Purpose |
|------|---------|
| `Game/Core/DataTypes/FacilityData.gd` | Facility data container with shop_profile support |
| `Game/Core/DataTypes/TownData.gd` | Town data container |
| `Game/Core/DataTypes/ItemTemplate.gd` | Item template data |
| `Game/Core/DataTypes/ItemInstance.gd` | Runtime item instance |
| `Game/Core/DataTypes/ClassData.gd` | Class definitions |

### 2.2 Core Systems
| File | Purpose |
|------|---------|
| `Game/Core/GameContext.gd` | Game state, gold, inventory, shop refresh |
| `Game/Core/DataRegistry.gd` | JSON data loading/caching |
| `Game/Core/SeededRNG.gd` | Deterministic RNG for shop rolls |

### 2.3 UI
| File | Purpose |
|------|---------|
| `Game/UI/Town/TownScene.gd` | Main town UI, facility panels, shop system |

---

## 3. Implemented Systems

### 3.1 Gold System (GameContext.gd)

| Currency | Variable | Purpose |
|----------|----------|---------|
| Player Gold | `player_gold` | Persistent meta-currency |
| Run Gold | `run_gold` | Banked gold for current town phase |
| Dungeon Gold | `dungeon_gold` | Provisional gold (in-dungeon) |

**Functions:**
- `get_run_gold()`, `add_run_gold()`, `spend_run_gold()`
- `get_player_gold()`, `add_player_gold()`, `spend_player_gold()`
- Gold used for: shop purchases, recruitment, training, upgrades

### 3.2 Shop System (TownScene.gd)

**Pool-Driven Inventory Generation:**
- `_generate_pool_inventory()` - Seeded RNG shop inventory
- Uses `shop_pool_id`, `shop_rolls`, `shop_profile` from facility JSON
- Applies `weight_by_tier` from pool JSON
- Applies `category_weight_mult` from shop_profile
- Supports `rolls_override` per-town customization

**Refresh System:**
- `get_shop_refresh_cost()` - Formula: `min(50, 5 * (refresh_count + 1))`
- `can_afford_shop_refresh()`, `spend_shop_refresh()`
- Refresh increments `shop_refresh_counts[shop_id]`
- Refresh costs run_gold

**Gating:**
- `requires_unlock_group` - Must have unlock group in `unlocked_groups`
- `required_town_tier` - Town must be at tier
- `required_dungeon_floor_unlocked` - Floor must be unlocked
- Locked items show "(Category: Reason)" in UI

### 3.3 Facility UI Handlers (TownScene.gd)

| Facility Type | Handler | UI Panel |
|---------------|---------|----------|
| dungeon | `_show_facility_panel()` | Floor selection, enter/continue/exit |
| inn | `_show_facility_panel()` | Recruit heroes, party management |
| shop | `_show_facility_panel()` | Buy items, stash upgrades, refresh |
| blacksmith | `_show_facility_panel()` | Unlock groups, view unlocks |
| alchemist | `_show_facility_panel()` | Unlock groups, view unlocks |
| training_hall | `_show_facility_panel()` | Buy books, apply training buffs |
| storage | `_show_facility_panel()` | Deposit/withdraw, compact stash |
| production | `_show_facility_panel()` | Placeholder panel |
| woodsman | `_show_facility_panel()` | Flavor text only |

### 3.4 Town Reset (GameContext.gd)

When returning to town:
- Heroes healed to full HP
- Status effects cleared
- Logged: `[TownReset] healed=true cleared_status=true`

---

## 4. Save/Load System

### 4.1 Saved Data (GameContext.gd)

```
player_gold, run_gold, dungeon_gold
run_items, player_items
owned_heroes, selected_party
unlocked_groups, facility_tiers
unlocked_dungeon_floors, selected_start_floors
bonus_stash_capacity, purchased_upgrades
shop_refresh_counts
```

### 4.2 Migration Support
- `mender` class auto-migrates to `warden`
- Legacy `book_mender.json` points to warden class

---

## 5. UI Implementation Status

### 5.1 Facility Panel Features

| Facility | Services Panel | Items List | Unlock Panel | Upgrade Button |
|----------|---------------|------------|--------------|----------------|
| dungeon | Floor selection | - | - | - |
| inn | Recruit list | - | - | Upgrade (T2) |
| shop | - | Pool items | - | - |
| blacksmith | - | - | Unlock groups | Upgrade (T2) |
| alchemist | - | - | Unlock groups | Upgrade (T2) |
| training_hall | Training buffs | Book items | - | Upgrade (T2) |
| storage | Transfer panel | Stash list | - | Upgrade (T2) |
| production | - | - | - | - |
| woodsman | Flavor text | - | - | - |

### 5.2 Shop v1.5 Features

| Feature | Status | Location |
|---------|--------|----------|
| Pool-driven inventory | IMPLEMENTED | TownScene._generate_pool_inventory() |
| Seeded RNG | IMPLEMENTED | Uses SeededRNG.gd |
| Town-unique profiles | IMPLEMENTED | shop_profile in facility JSON |
| Tier-weighted selection | IMPLEMENTED | weight_by_tier in pool JSON |
| Category weight multipliers | IMPLEMENTED | category_weight_mult in shop_profile |
| Rolls override | IMPLEMENTED | rolls_override in shop_profile |
| Refresh cost system | IMPLEMENTED | GameContext refresh APIs |
| Gating by unlock group | IMPLEMENTED | requires_unlock_group |
| Gating by floor | IMPLEMENTED | required_dungeon_floor_unlocked |
| Gating by town tier | IMPLEMENTED | required_town_tier |
| Locked item UI | IMPLEMENTED | Shows "(Category: Reason)" |

---

## 6. Verified Compliance

### 6.1 Item Selling
- General Store (shop_thornhaven): HAS shop_pool_id, shop_rolls, shop_profile
- Training Hall: HAS shop_items with class books
- All other facilities: shop_items = [] (correct)

### 6.2 Removed/Merged Facilities
- healer.json: DELETED (town reset heals)
- housing.json: DELETED (merged into Inn)

### 6.3 Class Rename
- mender -> warden: COMPLETED
- book_mender.json: Points to warden class
- Migration: IMPLEMENTED in GameContext.load_game()

---

*Generated: 2026-01-10*
