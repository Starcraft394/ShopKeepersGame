# R1-R7 Full Playthrough — Gap Closure Plan (v3)

## Design Pillars (from user)

**Equipment Progression:**
- **T1**: Base items from crafting. Base mats only.
- **T2**: Same base items + regional affix. Base + region mats.
- **T3**: Same base items + enhanced regional affix. Region mats only.
- **T4**: Unique regional items (fm_, ss_, ah_, se_, nc_, fr_) — boss drops / super-rare elite only. NOT craftable.

**Mat Tier Rules (mixing & crafting):**
- T1 recipes: base mats only
- T2 recipes: base + region mats
- T3-T4 recipes: region mats only

**Base items cover all slots everywhere.** Head, legs, bags don't need regional variants — they scale through crafting tiers with affixes applied.

---

## Tier 1: Game-Breaking Code Bugs

### Bug 1 — Region int/string desync
**File:** `Game/Core/GameContext.gd`

`set_location()` (line 588) updates `_current_region_id` (string) but NOT `current_region` (int). `set_current_region()` (line 494) does the reverse. UI calls `set_location()` on town switch, so `current_region` stays stale at 1.

**Fix:** In `set_location()`, after line 599, extract region number and sync:
```gdscript
var region_num = int(region_id.replace("region_", ""))
if region_num >= 1 and region_num <= 7:
    set_current_region(region_num)
```

### Bug 2 — Location not saved/loaded
**File:** `Game/Core/GameContext.gd`

`save_game()` (line 4092) saves `current_region` (int) but NOT `_current_region_id` or `_current_town_id`. On load (line 4297), both reset to `"region_1"` / `"town_thornhaven"`.

**Fix:**
1. Add to save_data dict (~line 4130): `"region_id": _current_region_id, "town_id": _current_town_id`
2. In `load_game()` after line 4503: restore both strings, then call `set_location()` to sync

### Bug 3 — Loot downgrade R1-only
**File:** `Game/Combat/CombatResult.gd` (line 274)

`_get_effective_table_id()` only handles `lt_region1_boss`/`lt_region1_elite`. R2-R7 elite/boss tables pass through for non-boss encounters — elites in R2+ use their full loot tables even for normal mobs.

**Fix:** Replace the match with a generic suffix check:
```gdscript
func _get_effective_table_id(original_table_id: String) -> String:
    if is_boss_encounter:
        return original_table_id
    if original_table_id.ends_with("_boss") or original_table_id.ends_with("_elite"):
        return original_table_id.rsplit("_", true, 1)[0] + "_uncommon"
    return original_table_id
```

### Bug 4 — Stale `"wood"` references to deleted template
**Files:** `Game/Core/GameContext.gd` (line 976), `Game/UI/Town/TownScene.gd` (line 1353)

`wood.json` was deleted but two code references remain.

**Fix:** Replace `"wood"` with `"wood_bundle"` in both locations.

---

## Tier 2: Broken Data References

### Ref 1 — `miners_ration` (recipe output, no template)
**File:** `Data/Recipes/mixing_chef_r2.json` line 16

**Fix:** Create `Data/Items/Templates/miners_ration.json` — R2 food consumable, heals ~15 HP, tier 2, tags `["region_2", "consumable", "food"]`

### Ref 2 — `fr_dimensional_essence` (2 events, no template)
**Files:** `Data/Events/Definitions/evt_fr_abyss_echo.json`, `evt_fr_dimensional_rift.json`

**Fix:** Create `Data/Items/Templates/fr_dimensional_essence.json` — R7 material, tier 3, tags `["region_7", "material"]`

### Ref 3 — `cursed_relic` (1 event, no template)
**File:** `Data/Events/Definitions/evt_nc_cursed_altar.json`

**Fix:** Create `Data/Items/Templates/cursed_relic.json` — R6 material, tier 3, tags `["region_6", "material"]`

---

## Tier 3: Stale Mountain/Ironpeak Theme References

### Theme 1 — R2 shop pool description
**File:** `Data/Shops/Pools/pool_region2_general.json` line 4
```
"description": "Item pool for general stores in Region 2 mountain towns"
```
**Fix:** → `"Item pool for general stores in Region 2 Fungalmire towns"`

### Theme 2 — R2 regional affix still mountain-themed
**File:** `Data/Affixes/regional_affixes.json` lines 8-10
```json
"region_2": {
    "prefix": "Stoneforged",
    "stat_bonus": { "defense": 3 },
    "description": "Tempered in mountain stone"
}
```
**Fix:** → `"prefix": "Sporetouched"`, `"description": "Laced with fungal mycelium"`

---

## Tier 4: Shop Pool Overhaul

### Pool 1 — R2 pool has wrong equipment
**File:** `Data/Shops/Pools/pool_region2_general.json`

Weapons section has R1 items (`iron_sword`, `iron_greataxe`, `composite_bow`). Should have fm_ equipment. But per the T4 design, regional equipment is boss-only — so the weapons/offhands section should have **upgraded base items** instead, matching the T2 crafting tier.

**Fix:** Replace R2 pool weapons/offhands with base T2 items:
- Weapons: `iron_sword` (T1), `iron_greataxe` (T2), `composite_bow` (T2)
- Offhands: `reinforced_shield` (T2), `wooden_focus` (T2)

Actually these ARE the correct T2 base items. The pool is fine for T1/T2 base equipment. Remove the T2 `requires_unlock_group` fields since they're orphaned (see Pool 3 below). The pool's `required_dungeon_floor_unlocked` already gates T2 items.

### Pool 2 — `books_t1` unlock group is dead (ALL pools)
**Files:** All 7 `pool_region*_general.json`

Every pool's books section uses `"requires_unlock_group": "books_t1"`. This group was removed. Books in shop pools are permanently invisible.

**Fix:** Remove the `"books"` section entirely from all 7 shop pools. Books are handled by Training Hall `shop_items` with `required_facility_tier` gating.

### Pool 3 — Orphaned unlock groups
**Files:** All 7 `pool_region*_general.json`

Groups `consumables_t2`, `weapons_t2`, `offhands_t2` are referenced in pools but no facility grants them — all 3 equipment facilities have `"unlocks": []`.

**Fix (Option C — recommended):** Remove `requires_unlock_group` from T2+ pool entries. The pool's existing `required_dungeon_floor_unlocked` field already provides sufficient gating (T2 items require floor 2 unlocked). Keep `requires_unlock_group` only on T1 entries where `DEFAULT_UNLOCK_GROUPS` already covers it.

**Why Option C over Option A:** Option A (adding to defaults) would make ALL T2 items visible from game start. Option C preserves the floor-gating that already exists — you need to clear floor 1 before T2 items appear.

---

## Tier 5: Loot Table Cleanup — T4 Boss-Only

Per the design, regional prefix equipment (fm_, ss_, ah_, se_, nc_, fr_) is T4 boss/rare-elite only.

### Current state:
| Region | Boss Table | Elite Table | Shop Pool |
|--------|-----------|-------------|-----------|
| R2 (fm_) | **MISSING** — boss table has R1 items | **MISSING** — elite has R1 items | R1 items |
| R3 (ss_) | Has ss_ items | Has ss_ items | Has ss_ items |
| R4 (ah_) | Has ah_ items | Has ah_ items | Has ah_ items |
| R5 (se_) | Has se_ items | Has se_ items | Has se_ items |
| R6 (nc_) | Has nc_ items | Has nc_ items | Has nc_ items |
| R7 (fr_) | Has fr_ items | Has fr_ items | Has fr_ items |

### Fixes needed:

**5a — Add fm_ equipment to R2 boss table:**
Replace R1 equipment entries in `lt_region2_boss.json` with fm_ items:
- `fm_spore_blade`, `fm_fungal_longbow`, `fm_fungal_staff` (weapons)
- `fm_sporecap_shield`, `fm_spore_focus` (offhands)
- `fm_mycelweave_robe`, `fm_mycelweave_hood`, `fm_sporehide_greaves` (armor/head/legs — if they exist)

**5b — Remove regional equipment from R3-R7 elite tables:**
For each `lt_region*_elite.json` (R3-R7), remove equipment entries (ss_, ah_, se_, nc_, fr_ items) and redistribute weight to material/consumable entries.

**5c — Remove regional equipment from R3-R7 shop pools:**
For each `pool_region*_general.json` (R3-R7), replace regional weapons/offhands with base T2 equipment. The pools should sell base gear, not T4 items.

**5d — Fix R2 elite table:**
Replace R1 equipment entries in `lt_region2_elite.json` with region-appropriate materials.

---

## Tier 6: Affix Scaling

Current affix values are flat across all tiers (2-5 stat points total). For T2-T3 crafting to feel meaningful, affixes need tier-aware scaling.

### Current affixes:
| Region | Prefix | Stats | Total Points |
|--------|--------|-------|-------------|
| R1 | Verdant | +2 HP | 2 |
| R2 | Stoneforged* | +3 DEF | 3 |
| R3 | Tideforged | +2 SPD | 2 |
| R4 | Embertouched | +3 ATK | 3 |
| R5 | Starforged | +2 ATK, +2 SPD | 4 |
| R6 | Deathbound | +3 HP, +2 ATK | 5 |
| R7 | Voidtouched | +2 SPD, +3 DEF | 5 |

*R2 needs retheme to "Sporetouched" (Tier 3 above)

### Problem:
- Stat budgets already scale by region (R1=2, R7=5), which is good for loot drops
- But for CRAFTED items, a Verdant Rusty Sword in R1 only gets +2 HP — barely noticeable
- T2 vs T3 crafting has no differentiation — both would apply the same affix

### Proposed fix — Tier multiplier:
Add a `tier_multiplier` concept to crafting (NOT to loot drops — loot keeps current values):
- **T2 crafted**: Apply 1x regional affix (current values)
- **T3 crafted**: Apply 1.5x regional affix (rounded up)

This is a **future enhancement** — can ship without it. For v1, T2 and T3 crafted items both get 1x affix, but T3 unlock costs are higher (region-only mats = harder to get).

**Immediate fix:** Just retheme R2 affix and leave values as-is. The natural region scaling (R1=2pts → R7=5pts) already provides progression for loot drops.

---

## Tier 7: Crafting Tier System (Code + Data)

### Current state:
- Crafting produces plain items via `GameContext.add_run_item(output_id, qty)` — no quality, no affixes
- `ItemInstance` class fully supports affixes (affix_id, affix_stats, affix_prefix, source_region)
- Combat loot creates `ItemInstance` objects with affixes applied (CombatResult.gd:247-260)
- Facilities already have `regional_upgrade_costs` for R2-R7 tier upgrades (data exists!)
- But `crafting_recipes` are R1-only in all 3 facilities

### What needs to change:

**7a — Code: Crafting applies regional affix at T2+**
**File:** `Game/UI/Town/TownScene.gd` `_on_craft_recipe_pressed()` (line 3578)

When `required_tier >= 2`, instead of plain `add_run_item()`:
1. Create an `ItemInstance` from the output template
2. Apply the current region's affix (same logic as CombatResult.gd:248-256)
3. Add to shopkeeper_bag (or appropriate bag) as an `ItemInstance`

**7b — Data: Add T2-T3 crafting recipes per facility**
Each facility needs T2-T3 recipes that re-craft base items with regional material costs.

Example for Blacksmith R2 T2:
```json
{
    "output_id": "rusty_sword",
    "output_qty": 1,
    "required_tier": 2,
    "equipment_type": "1h_weapon",
    "unlock_cost": [
        { "item_id": "iron_scrap", "qty": 1 },
        { "item_id": "spore_cluster", "qty": 2 }
    ],
    "region": "region_2",
    "affix_tier": 2
}
```

**Design question:** Should there be separate recipes per region, or one recipe that adapts to current region?

**Recommended: Region-specific recipes** stored in the facility's `crafting_recipes` array with a `"region"` field. The crafting UI filters by current region. This lets each region have different material costs matching its available materials.

### Scope concern:
This is the largest single change in the plan. It touches:
- Crafting code (TownScene.gd)
- Item storage path (run_items → ItemInstance)
- All 3 facility JSONs (blacksmith, huntsman, enchanter)
- UI display for crafted items with affixes

**Recommendation:** Implement Tiers 1-5 first (bug fixes + data cleanup), then tackle Tier 7 as a separate focused effort.

---

## Tier 8: Mixing Recipes R3-R7

### Missing files (10):
- `mixing_chef_r3.json` through `mixing_chef_r7.json`
- `mixing_alchemist_r3.json` through `mixing_alchemist_r7.json`

### Mat tier rules:
- T1 (`required_tier: 1`): Base mats only (herb, mushroom, raw_meat, etc.)
- T2 (`required_tier: 2`): Base + region mats
- T3 (`required_tier: 3`): Region mats only

### Template (follow existing R2 pattern):
```json
{
  "facility_id": "chef",
  "recipes": [
    {
      "input_a": "regional_mat",
      "input_b": "base_mat",
      "input_c": "",
      "output_id": "regional_consumable",
      "output_qty": 1,
      "required_tier": 2
    }
  ]
}
```

### Prerequisites:
- Verify all regional materials exist as templates (most created in previous session)
- Verify all output consumables exist as templates (create any missing ones)

---

## Tier 9: Art Gaps (informational, not blocking)

| Category | Count | Notes |
|----------|-------|-------|
| Items missing icons | ~142/220 | All expansion region items + new base gear |
| Facilities missing keeper_portrait | 13 | All dungeons (7) + non-R1 shops (6) |

**No action now** — user is working on art selection separately.

---

## Implementation Order

### Phase 1: Bug Fixes (Tiers 1-3)
1. Fix GameContext.gd: region sync (Bug 1), save/load (Bug 2), `"wood"` ref (Bug 4)
2. Fix CombatResult.gd: loot downgrade (Bug 3)
3. Fix TownScene.gd: `"wood"` ref (Bug 4)
4. Create 3 missing item templates (Refs 1-3)
5. Fix R2 pool description + R2 regional affix theme (Themes 1-2)
6. **Run tests**

### Phase 2: Data Cleanup (Tiers 4-5)
7. Remove books sections from all 7 shop pools (Pool 2)
8. Remove orphaned `requires_unlock_group` from T2+ pool entries (Pool 3)
9. Add fm_ equipment to R2 boss table, remove R1 equipment (5a)
10. Remove R1 equipment from R2 elite table (5d)
11. Remove regional equipment from R3-R7 elite tables (5b)
12. Replace regional equipment in R3-R7 shop pools with base T2 items (5c)
13. **Run tests**

### Phase 3: Mixing Recipes (Tier 8)
14. Audit regional materials — verify all templates exist
15. Create R3-R7 mixing recipes (10 files) following mat tier rules
16. **Run tests**

### Phase 4: Crafting Tier System (Tier 7) — SEPARATE EFFORT
17. Add affix application to crafting code path
18. Add T2-T3 regional crafting recipes to all 3 facilities
19. Update crafting UI to show affix preview
20. **Run tests**

---

## Files to Modify

### Phase 1
| File | Change |
|------|--------|
| `Game/Core/GameContext.gd` | Sync region int/string, persist location, fix `"wood"` ref |
| `Game/Combat/CombatResult.gd` | Generic loot downgrade for all regions |
| `Game/UI/Town/TownScene.gd` | Fix `"wood"` ref |
| `Data/Items/Templates/miners_ration.json` | NEW — R2 food consumable |
| `Data/Items/Templates/fr_dimensional_essence.json` | NEW — R7 material |
| `Data/Items/Templates/cursed_relic.json` | NEW — R6 material |
| `Data/Shops/Pools/pool_region2_general.json` | Fix description |
| `Data/Affixes/regional_affixes.json` | Retheme R2 affix |

### Phase 2
| File | Change |
|------|--------|
| `Data/Shops/Pools/pool_region*_general.json` (7) | Remove books, clean unlock groups |
| `Data/LootTables/lt_region2_boss.json` | Add fm_ equipment, remove R1 gear |
| `Data/LootTables/lt_region2_elite.json` | Remove equipment, reweight to materials |
| `Data/LootTables/lt_region*_elite.json` (R3-R7) | Remove regional equipment entries |
| `Data/Shops/Pools/pool_region*_general.json` (R3-R7) | Replace regional with base T2 equipment |

### Phase 3
| File | Change |
|------|--------|
| `Data/Recipes/mixing_chef_r3-r7.json` (5) | NEW mixing recipes |
| `Data/Recipes/mixing_alchemist_r3-r7.json` (5) | NEW mixing recipes |
| `Data/Items/Templates/*.json` (TBD) | NEW — any missing recipe outputs |

### Phase 4 (future)
| File | Change |
|------|--------|
| `Game/UI/Town/TownScene.gd` | Crafting code to create ItemInstance with affix |
| `Data/Facilities/blacksmith.json` | Add R2-R7 T2-T3 crafting recipes |
| `Data/Facilities/huntsman.json` | Add R2-R7 T2-T3 crafting recipes |
| `Data/Facilities/enchanter.json` | Add R2-R7 T2-T3 crafting recipes |

---

## Verification

1. `DevTools\run_headless.bat` — all tests pass after each phase
2. No "mountain", "ironpeak", "Stoneforged" in Data/ (grep clean)
3. `set_location("region_5", "town_x")` → `current_region` == 5
4. Save in R5 → reload → still in R5 with correct town
5. Non-boss R4 encounter → drops from `lt_region4_uncommon` (not elite)
6. R2 boss drops fm_ equipment (not iron_sword)
7. R3-R7 elite tables have NO regional equipment
8. No `books_t1` or orphaned unlock groups in any shop pool
9. All pool item_ids cross-reference to existing templates
10. All mixing recipe inputs/outputs have valid templates
