# Race Passives v1 Manual Test Script

**Date:** 2026-01-16
**Version:** v1.0

---

## Prerequisites

- Game boots to Town phase without errors
- Headless validation passes (Passives: 10)
- Heroes can be recruited from Inn

---

## Test Setup

1. Start a new game or load existing save
2. Go to Inn facility
3. Recruit 3 heroes with the SAME class (e.g., all Defenders) but DIFFERENT races:
   - 1x Human Defender
   - 1x Elf Defender
   - 1x Dwarf Defender
4. Add all 3 to party
5. Enter dungeon and start combat

---

## Test 1: Human - Adaptability (human_adaptability)

**Expected Effect:** +1 ATK, +1 DEF at combat start. +1 SPD if level >= 3.

### Level 1-2 Human:
Expected log:
```
[RacePassive] id=human_adaptability hero=<id> name=<name> race=human level=1 before={HP:X ATK:Y DEF:Z SPD:W} after={HP:X ATK:Y+1 DEF:Z+1 SPD:W}
```

### Level 3+ Human:
Expected log:
```
[RacePassive] id=human_adaptability hero=<id> name=<name> race=human level=3 before={HP:X ATK:Y DEF:Z SPD:W} after={HP:X ATK:Y+1 DEF:Z+1 SPD:W+1}
```

### Verification:
| Level | ATK Bonus | DEF Bonus | SPD Bonus |
|-------|-----------|-----------|-----------|
| 1     | +1        | +1        | 0         |
| 2     | +1        | +1        | 0         |
| 3+    | +1        | +1        | +1        |

---

## Test 2: Elf - Keen Sight (elf_keen_sight)

**Expected Effect:** +2 SPD at combat start (flat, no level scaling).

Expected log:
```
[RacePassive] id=elf_keen_sight hero=<id> name=<name> race=elf level=<n> before={speed:X} after={speed:X+2}
```

### Verification:
- Elf should act earlier in turn order due to +2 SPD
- Compare turn order with a non-Elf of same class/level to verify SPD difference

| Level | SPD Bonus |
|-------|-----------|
| Any   | +2        |

---

## Test 3: Dwarf - Deep Miner (dwarf_deep_miner)

**Expected Effect:** +1 DEF (flat) and +HP = (5 + level * 2) at combat start.

Expected log:
```
[RacePassive] id=dwarf_deep_miner hero=<id> name=<name> race=dwarf level=<n> before={HP:X ATK:Y DEF:Z SPD:W} after={HP:X+bonus ATK:Y DEF:Z+1 SPD:W}
```

### Verification:
| Level | HP Bonus | DEF Bonus |
|-------|----------|-----------|
| 1     | +7 (5+2) | +1        |
| 2     | +9 (5+4) | +1        |
| 3     | +11 (5+6)| +1        |
| 4     | +13 (5+8)| +1        |
| 5     | +15 (5+10)| +1       |

---

## Test 4: Turn Order Verification

**Objective:** Verify Elf's +2 SPD bonus affects turn order.

### Setup:
1. Recruit 3 Defenders: Human, Elf, Dwarf (all same level)
2. Base Defender speed from class = 6
3. Race stat_modifiers:
   - Human: SPD +0
   - Elf: SPD +3 (from race stat_modifiers)
   - Dwarf: SPD -3 (from race stat_modifiers)

### Expected Base Speeds (before race passive):
- Human Defender: 6 + 0 = 6
- Elf Defender: 6 + 3 = 9
- Dwarf Defender: 6 - 3 = 3

### Expected Final Speeds (after race passive):
- Human Defender: 6 + 0 + 0 (no SPD passive at Lv1-2) = 6
- Elf Defender: 9 + 2 (elf_keen_sight) = 11
- Dwarf Defender: 3 + 0 = 3

### Expected Turn Order:
1. Elf (SPD 11)
2. Human (SPD 6)
3. Dwarf (SPD 3)

---

## Test 5: Stacking with Class Passives

**Objective:** Verify race passives stack correctly with class passives.

### Example: Dwarf Defender (Level 1)
Class passive (bulwark_stance): +DEF = (2 + level) = +3
Race passive (dwarf_deep_miner): +1 DEF, +7 HP

Expected sequence in logs:
1. `[Passive] bulwark_stance ...` (class passive first)
2. `[RacePassive] dwarf_deep_miner ...` (race passive second)

Total DEF increase: +3 (class) + 1 (race) = +4

---

## Test 6: No Race Passive on Enemies

**Objective:** Verify enemies do NOT receive race passives.

### Verification:
- Check logs during combat init
- `[RacePassive]` logs should ONLY appear for player heroes
- No race passive logs for goblins, wolves, or other monsters

---

## Pass/Fail Criteria

| Test | Criteria | Pass/Fail |
|------|----------|-----------|
| Headless Boot | Exit code 0, Passives: 10 | |
| human_adaptability | +1 ATK, +1 DEF; +1 SPD at Lv3+ | |
| elf_keen_sight | +2 SPD flat | |
| dwarf_deep_miner | +1 DEF, +(5+level*2) HP | |
| Turn Order | Elf acts before Human before Dwarf | |
| Class+Race Stack | Both passives apply, correct total | |
| Enemies No Passive | No [RacePassive] logs for enemies | |

---

## Headless Validation Output

```
[DataRegistry] Passives: seen=10 ok=10 bad=0
[BOOT] All checks passed!
EXIT_CODE=0
```

---

## Notes

- Race passives are applied AFTER class passives, BEFORE equipment bonuses
- Race passives are combat-start effects (not round-based)
- Human's XP modifier (1.1x) is separate from combat passive
- Effects are deterministic (no RNG)
- Speed affects turn order calculation via TurnQueue
