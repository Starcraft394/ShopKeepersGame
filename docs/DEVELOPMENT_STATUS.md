# ShopKeepers Game - Development Status

**Last Updated:** 2026-02-22

---

## MVP Status Overview

| Category | Status | Notes |
|----------|--------|-------|
| Core Systems | ✅ Complete | DataRegistry, GameContext, SeededRNG |
| Combat System | ✅ Complete | Player-controlled, multi-actions, consumables, monster abilities, combat roles |
| Town/Facilities | ✅ Complete | All facility types with tier progression |
| Dungeon System | ✅ Complete | 7 dungeons, 4 floors each, per-room seeding, room choice system |
| Save/Load | ✅ Complete | Full state persistence |
| UI Framework | ✅ Complete | Town, Combat, Party, BookUI, RPG UI Pack |
| Campaign | ✅ Complete | 32 dialogs across 7 regions, 3 display types |

---

## Content Inventory

| Content Type | Count | Status |
|--------------|-------|--------|
| Classes | 15 | ✅ All implemented |
| Races | 9 | ✅ All implemented |
| Abilities | 80 | ✅ 62 hero abilities + 18 monster abilities |
| Passives | 66 | ✅ No stubs |
| Monsters | 112 | ✅ 7 regions, all with attack_type, abilities, combat roles |
| Dungeons | 7 | All regions implemented |
| Item Templates | 430 | Consumables, gear, books, materials |
| Facilities | 22 | All types with tier progression |
| Regions | 7 | Thornhaven → Fractured Realm |
| Events | 70 | 57 migrated to v2 + 13 new, weighted outcomes |
| Tutorials | 12 | Full onboarding sequence (incl. party_bar) |
| Loot Tables | 38 | Region-specific drop tables |
| Campaign Dialogs | 32 | 7 regions, 3 display types, trigger system |

---

## Combat System Features (All Implemented)

- [x] Player action selection (Basic Attack, Ability A, Ability B, Pass, Use Item)
- [x] Target selection with validation (single/AoE/self)
- [x] Speed-based multi-actions (Speed 40+ = 2 actions, 80+ = 3 actions)
- [x] Consumable usage as free action (hero keeps their attack turn)
- [x] Turn queue with speed ordering
- [x] Status effects (burn, stun, poison, bleed, HOT, etc.)
- [x] Buff/debuff system with per-unit status independence
- [x] Cooldown management
- [x] Per-room RNG seeding for enemy variety
- [x] Front/back row grid targeting with TargetingPolicy
- [x] Combat roles (melee, ranged, mage) with different targeting behavior
- [x] Monster ability system (18 monster abilities, AI tier-based selection)
- [x] Dead hero filtering in loot routing
- [x] Full party wipe cleanup via exit_to_town()

---

## Recent Work (2026-02-22)

### Monster Ability System
- [x] 18 monster abilities with AI tier-based selection
- [x] Combat roles (melee, ranged, mage) with different targeting
- [x] Front/back row grid targeting with TargetingPolicy
- [x] 112 monsters updated with abilities, combat roles, and AI tiers
- [x] 6 ranged monster conversions in R5-R7

### Campaign & Story
- [x] Campaign dialog system — 32 dialogs across 7 regions, 3 display types (full_screen_overlay, portrait_text_box, event_popup)
- [x] Trigger system (region_first_arrival, boss_first_kill, herald_visit, dungeon_camp_story, keeper_story)
- [x] Campaign epilogue dialogs

### UI & Visual
- [x] BookUI system — animated book overlay (Bestiary, recipe books, handbook)
- [x] RPG UI Pack integration — HP bars, dividers, banners, slot art
- [x] Text size scaling system — configurable font sizes
- [x] ESC closeable stack — LIFO order UI management
- [x] Stock Shop two-state flow — commit allocations, refresh system

### Systems
- [x] Event system overhaul — v2 schema with weighted outcomes per choice
- [x] Facility tier restructure — Storage capacity, Inn race filters, Training XP, Equipment quality, Shop refresh
- [x] Dungeon room choice system — floor-based room selection
- [x] HOT (heal over time) mechanic
- [x] Icon ledger and recolour pipeline

### Previous Session (2026-02-19)
- [x] Tutorial back button — navigate backwards with Back btn / LEFT arrow / Backspace
- [x] Enemy AI front-row targeting — 112 monsters classified as melee/ranged via attack_type field
- [x] Status effect bleed bug — dead units now return empty snapshots, status_changed emitted on death
- [x] Combat "Use Item" button — free action, hero keeps attack turn after using consumable
- [x] Combat loot dead hero filter — dead heroes excluded from loot routing panel
- [x] Full party wipe cleanup — defeat handler now uses GameContext.exit_to_town()
- [x] Dungeon camp UI overhaul — region-themed panels, hero cards with portraits + HP bars, CanvasLayer overlay

### Previous Session (2026-02-10)
- [x] Stale item references cleaned (18 items, 8 files)
- [x] Facility upgrade bug fixed (set_facility_tier → upgrade_facility)
- [x] Production facility upgrade UI added (Chef/Alchemist)
- [x] All 15 classes made purchaseable (unlock_region: 1)
- [x] All 9 races made purchaseable (unlock_region: 1)
- [x] 6 racial passives created (mossfolk, tideling, dragonkin, crystalborn, undead, voidwalker)
- [x] Dungeon enemy variety fixed (SeededRNG.encounter_seed per room)

---

## Balance Status: NEEDS REVIEW

### Hero Classes - Issues Identified (from earlier audit)

| Class | Issue | Priority |
|-------|-------|----------|
| Void Herald | 84 ATK + 41 SPD at L10, dominates | CRITICAL |
| Prism Sentinel | 290 HP + 68 DEF at L10, unkillable | CRITICAL |
| Lich | 80 ATK at L10, glass cannon too strong | HIGH |
| Pyrewarden | 270 HP + 64 DEF, nearly unkillable | HIGH |
| Ashblade | Strong ATK + survivability combo | MONITOR |

> **Note:** These issues were identified in an earlier audit. With monster abilities, combat roles, and AI tiers now implemented, some of these balance concerns may have shifted. A comprehensive re-evaluation is needed.

### Monster Balance

Monsters now have abilities (not just basic_attack), combat roles (melee/ranged/mage), and AI tiers for ability selection. All monsters have been rebalanced with proper stats.

| Monster | Issue | Priority |
|---------|-------|----------|
| Logsplitter Brute | 68 HP exceeds Tier 3 elites | MEDIUM |
| Rootbound Shaman | ATK 14 is boss-level | MEDIUM |
| Cultist | ATK 7 matches Tier 2 | LOW |

### Ability/Passive Balance - Issues Identified (from earlier audit)

| Ability/Passive | Issue | Priority |
|-----------------|-------|----------|
| Void Tear | 24 dmg + 1.6x scaling, highest | CRITICAL |
| Light Lance | Armor piercing + high damage | HIGH |
| Shadow Mend | 25 heal for 5 HP cost (5:1 ratio) | HIGH |
| Reality Warp | +4 + level ATK, best offensive | CRITICAL |
| Crystal Shell | +4 + level DEF, best defensive | HIGH |
| Phylactery | Revive at 25% HP, too forgiving | HIGH |
| Void Resonance | Infinite stacking ATK per kill | CRITICAL |

---

## Test Status

- **200 tests total** (178 unit + 22 validation) — all passing
- Headless validation: PASSED
- Test runner: `DevTools\run_headless.bat`

---

## Deferred Features (Not MVP)

- [ ] Town Defense mechanics
- [ ] Blueprint crafting
- [ ] Socketing system
- [ ] Refinement system
- [ ] Corruption (R6+)
- [ ] World Tome
- [ ] Post-game content

---

## Next Priority: Full Balance Review

With monster abilities, combat roles, and AI tiers now implemented, run a comprehensive balance pass covering hero classes, monster encounters, ability scaling, and economy.
