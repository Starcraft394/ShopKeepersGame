# Region 1 Facilities Master List

This is the single source of truth for all Region 1 town facilities.

## Facility Summary

| Facility ID (GR) | Facility ID (TF) | Type | Purpose |
|------------------|------------------|------|---------|
| dungeon_greenroot | dungeon_timberfall | dungeon | Dungeon entrance, floor selection, run management |
| inn | inn_tf | inn | Hero recruitment, party management (merged Inn+Housing) |
| shop_greenroot | shop_timberfall | shop | General store - consumables, weapons, stash capacity upgrades |
| blacksmith | blacksmith_tf | blacksmith | Unlock weapons and armor tiers |
| leatherworker | leatherworker_tf | production | Crafting placeholder (future) |
| woodsman | woodsman_tf | woodsman | Flavor/placeholder - NO materials shop |
| chef | chef_tf | production | Crafting placeholder (future) |
| alchemist | alchemist_tf | alchemist | Unlock consumable tiers |
| training_hall | training_hall_tf | training_hall | Class learning from books |
| storage | storage_tf | storage | Bank stash management, item transfers |

## Removed Facilities
- **healer** - Removed. Returning to town automatically heals heroes and clears status effects.
- **housing** - Merged into Inn. Stash capacity upgrades moved to General Store.

## Facility Details

### 1. Dungeon (`dungeon`)
- **Purpose**: Entry point to dungeon runs, floor selection
- **Resources**: Reads unlocked_dungeon_floors, selected_start_floors from GameContext
- **Actions**: Enter dungeon, continue run, exit run, select start floor

### 2. Inn (`inn`)
- **Purpose**: Hero recruitment and party management (merged with Housing)
- **Resources**:
  - Writes: owned_heroes, selected_party (Run Stash gold for recruitment)
  - Reads: Run Stash gold for affordability
- **Actions**: Recruit heroes, add/remove from party
- **Note**: NO stash capacity upgrades (moved to General Store)

### 3. General Store (`shop`)
- **Purpose**: Buy consumables, weapons, and stash capacity upgrades
- **Resources**:
  - Writes: run_items (purchased items), bonus_stash_capacity
  - Reads: Run Stash gold, unlocked_groups for gating
- **Actions**: Buy items, purchase stash capacity upgrade
- **Inventory**: Generated via seeded RNG based on (town_id, shop_id, town_tier, highest_floor)

### 4. Blacksmith (`blacksmith`)
- **Purpose**: Unlock weapon/armor item groups
- **Resources**:
  - Writes: unlocked_groups
  - Reads: Run Stash gold + materials
- **Actions**: Unlock item groups (weapons_t1, offhands_t1, etc.)

### 5. Leatherworker (`production`)
- **Purpose**: Crafting facility (placeholder for future)
- **Resources**: N/A (placeholder)
- **Actions**: None currently

### 6. Woodsman (`woodsman`)
- **Purpose**: Flavor/placeholder - does NOT sell materials
- **Resources**: N/A
- **Actions**: None (flavor text only)
- **IMPORTANT**: NO shop_items, NO materials shop

### 7. Chef (`production`)
- **Purpose**: Crafting facility (placeholder for future)
- **Resources**: N/A (placeholder)
- **Actions**: None currently

### 8. Alchemist (`alchemist`)
- **Purpose**: Unlock consumable item groups
- **Resources**:
  - Writes: unlocked_groups
  - Reads: Run Stash gold + materials
- **Actions**: Unlock item groups (consumables_t2, etc.)

### 9. Training Hall (`training_hall`)
- **Purpose**: Learn classes from books
- **Resources**:
  - Writes: learned_classes
  - Reads: run_items (for books), Run Stash gold
- **Actions**: Buy class books, consume books to learn classes

### 10. Storage (`storage`)
- **Purpose**: Bank management, view stash, item transfers
- **Resources**:
  - Reads/Writes: run_gold, run_items, player_gold, player_items
- **Actions**: Deposit/withdraw gold, transfer items, view aggregated stash

## Town Reset Behavior
When returning to town (extract/exit dungeon):
- All heroes restored to full HP
- All status effects cleared
- Log: `[TownReset] healed=true cleared_status=true`

## Shop RNG System
General Store inventory is generated deterministically:
- Seed derived from: town_id + shop_facility_id + town_tier + highest_unlocked_floor
- Items selected from defined pool
- Unlock-group and progression gating applied after selection
- Log: `[ShopRNG] seed=X town=Y shop=Z picked=[...] shown=A locked=B`
