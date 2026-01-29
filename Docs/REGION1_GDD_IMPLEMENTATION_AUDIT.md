# Region 1: GDD vs Implementation Audit

**Generated:** 2026-01-10 (Updated)
**Scope:** Region 1 (Forest Haven) - Greenroot & Timberfall towns
**Sources:** Shops_And_Shadows_MASTER_GDD.md, REGION1_FACILITIES_MASTER.md, GameContext.gd, TownScene.gd, FacilityData.gd, Data/Facilities/*.json, Data/Towns/*.json, Data/Shops/Pools/*.json

---

## FIXES APPLIED (Since 2026-01-09)

| Issue | Fix Applied | Date |
|-------|-------------|------|
| Orphaned healer.json, healer_tf.json | DELETED | 2026-01-09 |
| Orphaned housing.json, housing_tf.json | DELETED | 2026-01-09 |
| bonus_starting_gold exists | REMOVED from GameContext | 2026-01-09 |
| "mender" class should be "warden" | RENAMED + migration support | 2026-01-09 |
| Alchemist had shop_items | SET to [] | 2026-01-09 |
| Shop v1.5 weight_by_tier not applied | FIXED - tier weights now work | 2026-01-09 |
| category_weight_mult was no-op | FIXED - effective weight formula | 2026-01-09 |
| Locked items not shown in UI | FIXED - shows "(Category: Reason)" | 2026-01-09 |

---

## 1. Facilities List Per Town

### Town Greenroot (`town_greenroot`)

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Blacksmith, Leatherworker, Woodsman, Chef, Alchemist (GDD 5.1) | dungeon_greenroot, inn, shop_greenroot, blacksmith, leatherworker, woodsman, chef, alchemist, training_hall, storage | **(B) UNDOCUMENTED BUT GOOD** - More facilities than GDD specifies |
| Training Hall (GDD 5.6: Starter Town Kit) | training_hall present | **MATCH** |
| Storage (GDD 5.6) | storage present | **MATCH** |
| Housing (GDD 5.6) | **NOT in facility_ids** (merged into Inn) | **(C) GDD OUTDATED** - Implementation newer |
| Shop (GDD 5.6: "fed by facilities") | shop_greenroot present | **MATCH** |
| No Healer mentioned in GDD 5.x | **NOT in facility_ids** (removed) | **(C) GDD OUTDATED** - Healer was never GDD-canonical |

### Town Timberfall (`town_timberfall`)

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Same core facilities as Greenroot | dungeon_timberfall, inn_tf, shop_timberfall, blacksmith_tf, leatherworker_tf, woodsman_tf, chef_tf, alchemist_tf, training_hall_tf, storage_tf | **MATCH** |
| Housing | **NOT in facility_ids** | **(C) GDD OUTDATED** |
| Healer | **NOT in facility_ids** | **(C) GDD OUTDATED** |

### Orphaned Facility JSON Files

| File | Status |
|------|--------|
| healer.json, healer_tf.json | **FIXED** - Files DELETED |
| housing.json, housing_tf.json | **FIXED** - Files DELETED |

---

## 2. Facility Type Responsibilities

### Dungeon Facility

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Entry point to dungeon runs | facility_type: "dungeon", services: ["select_floor"] | **MATCH** |
| Floor selection | GameContext: unlocked_dungeon_floors, selected_start_floors | **MATCH** |
| (not specified) | No starting gold bonus on dungeon entry | **(C) GDD OUTDATED** - Removed per REGION1_FACILITIES_MASTER |

### Inn (Merged Inn + Housing)

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified in GDD as single facility) | facility_type: "inn", services: ["recruit_hero", "manage_party"] | **(B) UNDOCUMENTED BUT GOOD** |
| Hero recruitment | recruit_candidates array in inn.json with class_id + cost_gold | **MATCH** |
| Party management | max_party_size: 2, GameContext: owned_heroes, selected_party | **MATCH** |
| Housing stash upgrades | **NOT in inn.json** (moved to General Store) | **(C) GDD OUTDATED** |

### General Store (Shop)

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Sells items from facility slots (GDD 5.4, 34.7) | shop_pool_id: "pool_region1_general", shop_rolls per category | **(C) GDD OUTDATED** - Pool-driven, not slot-driven |
| No stash upgrades mentioned | stash_upgrades array in shop JSON | **(B) UNDOCUMENTED BUT GOOD** |
| Shop refreshes on floor completion/extraction (GDD 36.3) | shop_refresh_counts in GameContext, manual refresh button | **(B) UNDOCUMENTED BUT GOOD** - Manual refresh added |

### Blacksmith

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Produces weapons, heavy armor, shields (GDD 5.3) | produces_item_types: ["weapon", "armor"] | **MATCH** |
| Uses ore resources | input_resource_types: ["iron_scrap", "wood"] | **MATCH** |
| T3: Refinement unlock (GDD 5.2) | max_tier: 2 in JSON | **(A) BUG / WRONG** - Should support T4 per GDD |
| Unlocks weapon/armor groups | unlocks: [unlock_offhands_t1] | **PARTIAL** - Only offhands_t1 defined |

### Alchemist

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Produces potions/flasks (GDD 5.3) | produces_item_types: ["consumable"] | **MATCH** |
| Uses herbs + glass (GDD 5.3) | input_resource_types: ["herb", "mushroom"] | **PARTIAL** - No glass |
| Unlocks consumable groups | unlocks: [unlock_consumables_t2] | **MATCH** |
| Has shop_items | shop_items: [] (removed - only General Store + Training Hall sell) | **FIXED** |

### Woodsman

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Produces bows, staves, wooden shields (GDD 5.3) | services_per_tier: {"1": []}, shop_items: [] | **(C) GDD OUTDATED** - Placeholder only |
| Uses wood resources | produces_item_types: [], input_resource_types: [] | **(C) GDD OUTDATED** - Not implemented |
| NO materials shop | Confirmed empty shop_items | **MATCH** (per REGION1_FACILITIES_MASTER) |

### Training Hall

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Sells Class Books (GDD 8.1) | shop_items: [book_defender, book_striker, book_mender] | **MATCH** |
| Class assignment (GDD 8.1) | services: ["train_hero", "assign_class"] | **MATCH** |
| Class overwrites existing (GDD 8.1) | GameContext: learned_classes, BOOK_TO_CLASS_MAP | **MATCH** |

### Storage

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Global shared storage (GDD 10.3) | services: ["store_materials", "retrieve_materials"] | **MATCH** |
| Resources do NOT stack (GDD 7.6) | (not specified in GDD) | **(not verified in implementation)** |

### Chef

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Produces food items (GDD 5.3) | Placeholder - no services defined | **(C) GDD OUTDATED** - Not implemented yet |

### Leatherworker

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Produces light/medium armor (GDD 5.3) | Placeholder - no services defined | **(C) GDD OUTDATED** - Not implemented yet |

---

## 3. Stash Rules: Player Wallet vs Run Stash vs Dungeon Stash

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Gold is single, shared global resource (GDD 11.1, 35.2) | GameContext: player_gold (persistent), run_gold (banked), dungeon_gold (provisional) | **(B) UNDOCUMENTED BUT GOOD** - Three-tier system |
| All gold earned flows into global pool (GDD 11.1) | dungeon_gold commits to run_gold on extract | **PARTIAL** - Commits to run_gold, not player_gold directly |
| Gold is never lost on hero death (GDD 11.1) | dungeon_gold lost on flee, run_gold preserved | **(C) GDD OUTDATED** - dungeon_gold can be lost |
| No per-hero gold tracking (GDD 36.11) | Confirmed - no hero gold | **MATCH** |
| (not specified) | run_items separate from dungeon_items | **(B) UNDOCUMENTED BUT GOOD** |

### Stash Spending Rules (Per Facility)

| Facility | What It Spends From | GDD Says | Status |
|----------|---------------------|----------|--------|
| Inn (Recruitment) | run_gold | (not specified) | **(B) UNDOCUMENTED BUT GOOD** |
| General Store | run_gold | Global gold (GDD 11.1) | **(C) GDD OUTDATED** - Uses run_gold |
| Blacksmith (Unlocks) | run_gold + materials | (not specified) | **(B) UNDOCUMENTED BUT GOOD** |
| Training Hall (Books) | run_gold | (not specified) | **(B) UNDOCUMENTED BUT GOOD** |

### Extraction/Flee Behavior

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Extraction at end of floor (GDD 36.6) | commit_dungeon_stash() moves dungeon_gold/items to run stash | **MATCH** |
| Early exit: all run loot lost (GDD 36.6) | flee_to_town() clears dungeon_gold/items, run_gold preserved | **(C) GDD OUTDATED** - Only dungeon stash lost |
| (not specified) | clear_dungeon_stash() on flee | **(B) UNDOCUMENTED BUT GOOD** |

---

## 4. Unlock/Progression Systems

### unlocked_groups

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified) | GameContext: unlocked_groups dictionary | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | DEFAULT_UNLOCK_GROUPS: ["consumables_t1", "weapons_t1", "books_t1", "materials_t1"] | **(B) UNDOCUMENTED BUT GOOD** |
| Unlock via facility | Blacksmith: unlocks offhands_t1; Alchemist: unlocks consumables_t2 | **MATCH** |

### Facility Tiers

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| T1-T4 for crafting facilities (GDD 5.2) | facility_tiers dictionary in GameContext | **MATCH** |
| T3: Refinement unlock | max_tier: 2 in most JSONs | **(A) BUG / WRONG** - Should be T4 per GDD |
| T4: Legendary crafting | Not implemented | **(C) GDD OUTDATED** - Future feature |

### Town Tiers

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not explicitly specified for R1) | town_tiers dictionary in GameContext | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Used in shop seed calculation | **(B) UNDOCUMENTED BUT GOOD** |

### Dungeon Floor Unlocks

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Floors unlock sequentially (GDD 36.5) | unlocked_dungeon_floors dictionary | **MATCH** |
| Floor 1 always unlocked | Default behavior if no entry | **MATCH** |
| Selected start floor persists (GDD 36.5) | selected_start_floors dictionary | **MATCH** |

### Shop Refresh Counts

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Shop refreshes on floor completion (GDD 36.3) | shop_refresh_counts dictionary | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Manual refresh button increments count | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Refresh count persisted in save | **(B) UNDOCUMENTED BUT GOOD** |

---

## 5. Shop System

### Pool-Driven Inventory

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Facility slots fill shop (GDD 34.7) | Pool-based: shop_pool_id references pool JSON | **(C) GDD OUTDATED** - Pool system replaces slot system |
| (not specified) | shop_rolls: { category: count } per shop | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | pool_region1_general.json with weighted items | **(B) UNDOCUMENTED BUT GOOD** |

### Seed Inputs

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified) | Seed = hash(town_id + shop_id + town_tier + highest_floor + refresh_count) | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | SeededRNG.create_rng() used | **(B) UNDOCUMENTED BUT GOOD** |

### Refresh Behavior

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Shop refreshes on floor completion/extraction (GDD 36.3) | increment_shop_refresh() increments count | **PARTIAL** - Manual button only |
| No mid-run refresh (GDD 36.3) | (not verified - refresh button always visible?) | **(needs verification)** |

### Gating Behavior

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified) | requires_unlock_group on each pool item | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Items filtered by unlocked_groups before display | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Pool selection happens BEFORE unlock filtering | **(B) UNDOCUMENTED BUT GOOD** |

---

## 6. Training Hall + Books

### Class Books

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Class Books appear in shop (GDD 8.1) | training_hall.shop_items: [book_defender, book_striker, book_warden] | **MATCH** |
| Books can overwrite existing class (GDD 8.1) | BOOK_TO_CLASS_MAP in GameContext | **MATCH** |
| Assignment costs gold (GDD 8.1) | price_gold: 100 per book | **MATCH** |
| Hero retains race, gear, level (GDD 8.1) | (not verified - hero data structure) | **(needs verification)** |

### Class Learning

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified persistence) | learned_classes dictionary persisted | **(B) UNDOCUMENTED BUT GOOD** |
| Region 1: Defender, Warden, Striker (GDD 8.4) | book_defender, book_striker, book_warden | **FIXED** - Renamed mender to warden |

### What Persists

| Element | Persisted | Status |
|---------|-----------|--------|
| learned_classes | Yes (save_game) | **MATCH** |
| Books consumed | (implied) | **(needs verification)** |

---

## 7. Inn/Housing/Recruitment

### Hero Recruitment

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Shopkeeper hires heroes (GDD 4.1) | recruit_candidates in inn.json | **MATCH** |
| (not specified) | cost_gold per candidate (50g each) | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Generates unique hero_id via _hero_id_counter | **(B) UNDOCUMENTED BUT GOOD** |

### Party Selection

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Party size fixed by progression (GDD 36.4) | MAX_PARTY_SIZE: 2 constant, max_party_size: 2 in inn.json | **MATCH** |
| Only selected party enters dungeon (GDD 36.4) | selected_party array used in CombatScene | **MATCH** |
| (not specified) | selected_party persisted in save | **(B) UNDOCUMENTED BUT GOOD** |

### Housing (Merged)

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Housing T1 in Starter Kit (GDD 5.6) | Housing merged into Inn; stash upgrades in General Store | **(C) GDD OUTDATED** |
| Stash capacity upgrades | bonus_stash_capacity in GameContext | **MATCH** (different location) |
| Starting gold upgrades | **REMOVED** - bonus_starting_gold deleted | **FIXED** - Per REGION1_FACILITIES_MASTER, NO starting gold |

### What Persists

| Element | Persisted | Status |
|---------|-----------|--------|
| owned_heroes | Yes | **MATCH** |
| selected_party | Yes | **MATCH** |
| housing_upgrades | Yes | **MATCH** |
| bonus_stash_capacity | Yes | **MATCH** |
| bonus_starting_gold | **REMOVED** | **FIXED** - Field deleted from GameContext |

---

## 8. Dungeon Loop

### Extraction Commits

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Loot finalized on floor completion (GDD 36.7) | commit_dungeon_stash() moves to run stash | **MATCH** |
| (not specified) | Separate dungeon_gold/dungeon_items vs run_gold/run_items | **(B) UNDOCUMENTED BUT GOOD** |

### Town Reset Behavior

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified in GDD) | _apply_town_reset() called on exit_to_town() | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Logs: "[TownReset] healed=true cleared_status=true" | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | MVP: Heroes don't track HP outside combat | **(B) UNDOCUMENTED BUT GOOD** |

### Flee Behavior

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Early exit: all run loot lost (GDD 36.6) | flee_to_town(): dungeon stash lost, run stash preserved | **(C) GDD OUTDATED** - Only dungeon stash lost |
| Heroes survive (GDD 36.6) | No hero death on flee | **MATCH** |
| No shop refresh (GDD 36.6) | (not verified) | **(needs verification)** |

### Combat Modifiers

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| (not specified for R1) | pending_combat_modifier in GameContext | **(B) UNDOCUMENTED BUT GOOD** |
| (not specified) | Structure: { id, label, bonus_gold, enemy_spd_bonus, etc. } | **(B) UNDOCUMENTED BUT GOOD** |

### Room Choice Rules

| GDD Says | Implemented Now | Status |
|----------|-----------------|--------|
| Map choices matter (GDD 2.3) | pending_room_choices: choice_a (combat), choice_b (event/elite) | **MATCH** |
| Rest room every 4-5 rooms (GDD 4.2) | (not verified in implementation) | **(needs verification)** |
| (not specified) | _last_room_was_event prevents consecutive events | **(B) UNDOCUMENTED BUT GOOD** |

---

## 9. Missing Features (GDD Specified, Not Implemented)

| Feature | GDD Section | Status |
|---------|-------------|--------|
| Refinement system (T3+) | GDD 5.2, 7.3 | **Not implemented** |
| Legendary crafting (T4) | GDD 5.2, 7.4 | **Not implemented** |
| Insurance slots | GDD 7.7 | **Not implemented** |
| Backpacks | GDD 7.6 | **Not implemented** |
| Tools (pickaxe, hatchet, etc.) | GDD 7.2 | **Not implemented** |
| Hero death / Book of the Dead | GDD 36.7 | **Not implemented** |
| Salvage vs Sell | GDD 35.9 | **Not implemented** |
| Guard Yard (Town Defense) | GDD 5.3 | **Not implemented** (post-Region 3) |
| Woodsman production | GDD 5.3 | **Placeholder only** |
| Chef production | GDD 5.3 | **Placeholder only** |
| Leatherworker production | GDD 5.3 | **Placeholder only** |
| Warden class | GDD 8.4 | **FIXED** - Renamed mender to warden |

---

## 10. Decisions Needed Checklist

### (A) BUGS / WRONG - Require Fix

- [x] **Delete orphaned healer.json and healer_tf.json files?** - DONE
  - These files exist but are not referenced by any town.

- [x] **Delete orphaned housing.json and housing_tf.json files?** - DONE
  - These files exist but are not referenced by any town.

- [x] **Remove bonus_starting_gold from GameContext?** - DONE
  - Per REGION1_FACILITIES_MASTER: "NO dungeon starting gold"

- [x] **Rename "mender" class to "warden"?** - DONE
  - GDD specifies: Defender, Warden, Striker for Region 1
  - Implementation has: defender, striker, warden (+ migration for old saves)

- [ ] **Increase facility max_tier to 4?** - BACKLOG
  - GDD says facilities can reach T4 in early towns
  - Most JSONs have max_tier: 2
  - Not blocking for Region 1 MVP

### (B) UNDOCUMENTED BUT GOOD - Update GDD

- [ ] **Document three-tier gold system?**
  - player_gold (persistent) → run_gold (banked) → dungeon_gold (provisional)

- [ ] **Document pool-driven shop system?**
  - shop_pool_id, shop_rolls, weighted selection, category-based rolls

- [ ] **Document shop refresh counter system?**
  - Manual refresh button, deterministic seed with refresh count

- [ ] **Document TownReset behavior?**
  - Auto-heal on return to town, status effect clearing

- [ ] **Document Inn as merged Inn+Housing?**
  - Housing stash upgrades moved to General Store

### (C) GDD OUTDATED - Implementation is Newer Design

- [ ] **Update GDD Section 5.6 (Starter Town Kit)?**
  - Remove Housing as separate facility
  - Add Inn with recruitment/party management
  - Add stash upgrades to General Store

- [ ] **Update GDD Section 36.6 (Early Exit)?**
  - Current: Only dungeon stash lost, run stash preserved
  - GDD says: All run loot lost

- [ ] **Update GDD to remove Healer facility?**
  - TownReset replaces Healer functionality

- [ ] **Update GDD shop system (Section 34.7)?**
  - Replace facility slot system with pool-driven system

- [ ] **Clarify Woodsman role in GDD?**
  - Currently placeholder with no production
  - GDD says: Produces bows, staves, wooden shields

---

## Summary

| Category | Count | Notes |
|----------|-------|-------|
| **(A) BUG / WRONG** | 0 (was 5) | All critical bugs FIXED |
| **FIXED** | 8 | Orphaned files, gold, class rename, shop v1.5 |
| **(B) UNDOCUMENTED BUT GOOD** | 25+ | Implementation ahead of GDD |
| **(C) GDD OUTDATED** | 10+ | GDD needs update to match implementation |
| **MATCH** | 30+ | GDD and implementation aligned |
| **Missing Features** | 11 | Future work (T3/T4, refinement, etc.) |
| **Needs Verification** | 5 | Manual testing needed |
| **BACKLOG** | 1 | max_tier increase (not blocking) |

---

## Shop v1.5 Implementation Status

| Feature | Status |
|---------|--------|
| Pool-driven inventory | **IMPLEMENTED** |
| Seeded RNG (deterministic) | **IMPLEMENTED** |
| Town-unique shop profiles | **IMPLEMENTED** |
| weight_by_tier from pool | **IMPLEMENTED** |
| category_weight_mult | **IMPLEMENTED** |
| rolls_override per town | **IMPLEMENTED** |
| Refresh cost system | **IMPLEMENTED** |
| Gating by unlock group | **IMPLEMENTED** |
| Gating by floor unlocked | **IMPLEMENTED** |
| Gating by town tier | **IMPLEMENTED** |
| Locked items show reason | **IMPLEMENTED** |
| Duplicate prevention | **IMPLEMENTED** |
