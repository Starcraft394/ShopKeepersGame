# ShopKeepers Game - Development Status

**Last Updated:** 2026-02-10

---

## MVP Status Overview

| Category | Status | Notes |
|----------|--------|-------|
| Core Systems | ✅ Complete | DataRegistry, GameContext, SeededRNG |
| Combat System | ✅ Complete | Player-controlled, multi-actions, consumables |
| Town/Facilities | ✅ Complete | All facility types with upgrades |
| Dungeon System | ✅ Complete | 2 dungeons, 4 floors each, per-room seeding |
| Save/Load | ✅ Complete | Full state persistence |
| UI Framework | ✅ Complete | Town, Combat, Party screens |

---

## Content Inventory

| Content Type | Count | Status |
|--------------|-------|--------|
| Classes | 15 | ✅ All implemented |
| Races | 9 | ✅ All implemented |
| Abilities | 36 | ✅ No stubs |
| Passives | 43 | ✅ No stubs |
| Monsters | 46 | ✅ Full variety |
| Dungeons | 2 | Greenroot + Timberfall |
| Item Templates | 80 | Consumables, gear, books, materials |
| Facilities | 20 | 10 types × 2 towns |

---

## Combat System Features (All Implemented)

- [x] Player action selection (Basic Attack, Ability A, Ability B, Pass)
- [x] Target selection with validation (single/AoE/self)
- [x] Speed-based multi-actions (Speed 10+ = 2 actions, 20+ = 3)
- [x] Consumable usage (1 per hero per combat)
- [x] Turn queue with speed ordering
- [x] Status effects (burn, stun, poison, etc.)
- [x] Buff/debuff system
- [x] Cooldown management
- [x] Per-room RNG seeding for enemy variety

---

## Recent Session Fixes (2026-02-10)

- [x] Stale item references cleaned (18 items, 8 files)
- [x] Facility upgrade bug fixed (set_facility_tier → upgrade_facility)
- [x] Production facility upgrade UI added (Chef/Alchemist)
- [x] All 15 classes made purchaseable (unlock_region: 1)
- [x] All 9 races made purchaseable (unlock_region: 1)
- [x] 6 racial passives created (mossfolk, tideling, dragonkin, crystalborn, undead, voidwalker)
- [x] Dungeon enemy variety fixed (SeededRNG.encounter_seed per room)

---

## Balance Status: NEEDS WORK

### Hero Classes - Issues Identified

| Class | Issue | Priority |
|-------|-------|----------|
| Void Herald | 84 ATK + 41 SPD at L10, dominates | CRITICAL |
| Prism Sentinel | 290 HP + 68 DEF at L10, unkillable | CRITICAL |
| Lich | 80 ATK at L10, glass cannon too strong | HIGH |
| Pyrewarden | 270 HP + 64 DEF, nearly unkillable | HIGH |
| Ashblade | Strong ATK + survivability combo | MONITOR |

### Monster Balance - Issues Identified

| Monster | Issue | Priority |
|---------|-------|----------|
| Tier 1 Elites | Too weak (same HP as base mobs) | HIGH |
| Logsplitter Brute | 68 HP exceeds Tier 3 elites | MEDIUM |
| Rootbound Shaman | ATK 14 is boss-level | MEDIUM |
| Cultist | ATK 7 matches Tier 2 | LOW |

### Ability/Passive Balance - Issues Identified

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

## Deferred Features (Not MVP)

- [ ] Regions 2-7
- [ ] Town Defense mechanics
- [ ] Blueprint crafting
- [ ] Socketing system
- [ ] Refinement system
- [ ] Corruption (R6+)
- [ ] World Tome
- [ ] Post-game content

---

## Next Priority: Balance Pass

1. Hero stat adjustments (nerf outliers)
2. Monster scaling adjustments (buff Tier 1 elites)
3. Ability damage/healing rebalancing
4. Passive effect reduction
