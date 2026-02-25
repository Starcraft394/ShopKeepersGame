# Region 1 Manual Test Checklist

Last Verified: 2026-01-10
Godot Version: 4.5.1

---

## Automated Verification

- [x] Godot --headless --quit runs without errors
- [x] All facility JSON files parse correctly
- [x] All class JSON files exist (defender, striker, warden)
- [x] No orphaned healer/housing JSON files
- [x] Shop pool JSON files valid

---

## Facility UI Tests (TownScene)

### Dungeon Facility
- [ ] Panel opens when clicking dungeon
- [ ] Shows floor selection buttons
- [ ] Enter Dungeon button works
- [ ] Continue Run button shows when applicable
- [ ] Exit Run button shows when in-run

### Inn Facility
- [ ] Panel shows recruit candidates (defender, striker, warden)
- [ ] Recruit costs 50 gold from run_gold
- [ ] Recruited heroes appear in owned_heroes
- [ ] Party management (add/remove) works
- [ ] Max party size enforced (2)

### General Store (Shop)
- [ ] Pool-driven inventory generates correctly
- [ ] Seed is deterministic (same town/shop/tier/floor = same items)
- [ ] Refresh button shows cost (5g, 10g, 15g...)
- [ ] Refresh disabled if can't afford
- [ ] Refresh changes inventory
- [ ] Buy button deducts run_gold
- [ ] Purchased items appear in run_items
- [ ] Locked categories show "(Category: Reason)"
- [ ] Stash upgrades available

### Blacksmith
- [ ] Panel shows unlock groups
- [ ] Unlock offhands_t1 works
- [ ] Requires correct materials
- [ ] Upgrade button shows (tier 2)

### Alchemist
- [ ] Panel shows unlock groups
- [ ] Unlock consumables_t2 works
- [ ] Requires correct materials
- [ ] shop_items is EMPTY (verified)

### Training Hall
- [ ] Shows class books for sale (book_defender, book_striker, book_warden)
- [ ] Buying book deducts 100 run_gold
- [ ] Book appears in inventory
- [ ] Learning book updates learned_classes
- [ ] Training buffs work

### Storage (Bank)
- [ ] Shows run_gold balance
- [ ] Shows run_items
- [ ] Deposit/Withdraw gold works
- [ ] Transfer items works
- [ ] Compact stash button works

### Woodsman
- [ ] Panel shows flavor text
- [ ] NO shop_items visible
- [ ] NO services available (placeholder)

### Production (Chef, Leatherworker)
- [ ] Panel shows placeholder message
- [ ] No services active

---

## Gold System Tests

### Three-Tier Gold
- [ ] player_gold persists between sessions
- [ ] run_gold used for town purchases
- [ ] dungeon_gold earned in combat
- [ ] Extraction commits dungeon_gold -> run_gold
- [ ] Flee clears dungeon_gold but preserves run_gold

### Shop Refresh Costs
- [ ] First refresh: 5 gold
- [ ] Second refresh: 10 gold
- [ ] Third refresh: 15 gold
- [ ] Max cost: 50 gold (at 10 refreshes)
- [ ] Cost shown on button
- [ ] Button disabled if insufficient gold

---

## Gating Tests

### Unlock Groups
- [ ] Items with requires_unlock_group not shown until unlocked
- [ ] Default unlocks: consumables_t1, weapons_t1, books_t1, materials_t1
- [ ] Blacksmith unlock adds offhands_t1
- [ ] Alchemist unlock adds consumables_t2

### Floor Gating
- [ ] Items with required_dungeon_floor_unlocked > 1 locked initially
- [ ] Unlocking floor 2 makes floor 2 items available

### Town Tier Gating
- [ ] Items with required_town_tier > 1 locked at tier 1
- [ ] Upgrading town tier unlocks higher tier items

---

## Save/Load Tests

- [ ] Save game writes to disk
- [ ] Load game restores all state
- [ ] Migration: mender -> warden in learned_classes
- [ ] Migration: mender -> warden in hero class_ids
- [ ] shop_refresh_counts persisted

---

## Town Reset Tests

- [ ] Returning to town heals all heroes
- [ ] Returning to town clears status effects
- [ ] Log shows: "[TownReset] healed=true cleared_status=true"

---

## Region 1 Classes

### Defender
- [ ] Class data loads correctly
- [ ] book_defender teaches defender class
- [ ] Recruitable at Inn

### Striker
- [ ] Class data loads correctly
- [ ] book_striker teaches striker class
- [ ] Recruitable at Inn

### Warden
- [ ] Class data loads correctly (NEW: warden.json created)
- [ ] book_warden teaches warden class
- [ ] book_mender (legacy) teaches warden class
- [ ] Recruitable at Inn

---

## Known Issues / Backlog

- [ ] Facility max_tier is 2, GDD says 4 (not blocking)
- [ ] Woodsman/Chef/Leatherworker production not implemented (placeholder)
- [ ] T3 Refinement system not implemented
- [ ] T4 Legendary crafting not implemented

---

## Notes

All critical bugs from the audit have been fixed:
1. Orphaned healer/housing files: DELETED
2. bonus_starting_gold: REMOVED
3. mender -> warden: RENAMED with migration
4. Alchemist shop_items: CLEARED
5. Shop v1.5 weight issues: FIXED
