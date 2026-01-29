# Class Passives v1 Manual Test Script

**Date:** 2026-01-16
**Version:** v1.0

---

## Prerequisites

- Game boots to Town phase without errors
- Headless validation passes (Passives: 7)
- Heroes can be recruited from Inn

---

## Test 1: Defender - bulwark_stance

**Objective:** Verify Defender gains +DEF = (2 + level) at combat start

### Steps:
1. Start game, go to Inn
2. Recruit a Defender hero (any race)
3. Note the hero's level (e.g., Level 1)
4. Add Defender to party
5. Enter dungeon and start combat

### Expected Log Output:
```
[Passive] bulwark_stance hero=<hero_id> name=<name> level=1 defense_before=X defense_after=X+3
```

### Expected Results:
- For Level 1 Defender: DEF increases by 3 (2 + 1)
- For Level 2 Defender: DEF increases by 4 (2 + 2)
- For Level 3 Defender: DEF increases by 5 (2 + 3)

### Formula Verification:
| Level | Expected DEF Bonus |
|-------|-------------------|
| 1     | +3                |
| 2     | +4                |
| 3     | +5                |
| 4     | +6                |
| 5     | +7                |

---

## Test 2: Striker - killer_instinct

**Objective:** Verify Striker gains stacking ATK buff on kills

### Steps:
1. Recruit a Striker hero
2. Add Striker to party (optionally with another hero to help)
3. Enter combat
4. Ensure Striker lands the killing blow on an enemy

### Expected Log Output:
```
[Passive] killer_instinct hero=<hero_id> name=<name> level=1 stacks=1 atk_before=X atk_after=X+1 target=<enemy_id>
```

### Expected Results:
- Level 1 Striker: +1 ATK per kill (1 + floor(1/2) = 1 + 0 = 1)
- Level 2 Striker: +2 ATK per kill (1 + floor(2/2) = 1 + 1 = 2)
- Level 3 Striker: +2 ATK per kill (1 + floor(3/2) = 1 + 1 = 2)
- Level 4 Striker: +3 ATK per kill (1 + floor(4/2) = 1 + 2 = 3)

### Formula Verification:
| Level | ATK per Kill |
|-------|--------------|
| 1     | +1           |
| 2     | +2           |
| 3     | +2           |
| 4     | +3           |
| 5     | +3           |

### Stacking Test:
1. Kill first enemy -> Verify stacks=1
2. Kill second enemy -> Verify stacks=2, ATK increases again
3. Both kills in same combat should stack

---

## Test 3: Warden - verdant_renewal

**Objective:** Verify Warden heals lowest HP% ally at start of each round

### Steps:
1. Recruit a Warden hero
2. Recruit at least one other hero
3. Add both to party
4. Enter combat
5. Let combat proceed until Round 2 starts
6. Ideally, have an ally take damage before Round 2

### Expected Log Output:
```
[Passive] verdant_renewal healer=<warden_id> level=1 target=<ally_id> hp_before=X hp_after=X+4
```

### Expected Results:
- Level 1 Warden: Heals +4 HP (3 + 1)
- Level 2 Warden: Heals +5 HP (3 + 2)
- Level 3 Warden: Heals +6 HP (3 + 3)

### Formula Verification:
| Level | Heal Amount |
|-------|-------------|
| 1     | +4 HP       |
| 2     | +5 HP       |
| 3     | +6 HP       |
| 4     | +7 HP       |
| 5     | +8 HP       |

### Edge Cases:
- If all allies are at full HP, no healing occurs (but passive should still attempt to select lowest HP%)
- Warden can heal self if Warden has lowest HP%
- Healing is clamped to max HP

---

## Test 4: Combination Test

**Objective:** Verify all three passives work together without conflict

### Steps:
1. Recruit one Defender, one Striker, one Warden
2. Add all three to party
3. Enter combat

### Expected:
- Defender gets bulwark_stance DEF bonus at combat start
- Striker gets killer_instinct ATK buff when killing enemies
- Warden heals lowest HP% ally at Round 2, Round 3, etc.

### No Conflicts:
- Passives should not interfere with each other
- Combat should complete normally
- No errors or crashes

---

## Automated Verification

Run headless validation:
```bash
godot --headless --quit
```

Expected output:
```
[DataRegistry] Passives: seen=7 ok=7 bad=0
```

---

## Pass/Fail Criteria

| Test | Criteria | Pass/Fail |
|------|----------|-----------|
| Headless Boot | Exit code 0 | |
| bulwark_stance | DEF increases by (2 + level) at combat start | |
| killer_instinct | ATK increases by (1 + level/2) per kill, stacks | |
| verdant_renewal | Lowest HP% ally healed by (3 + level) each round | |
| Combination | All passives work together without errors | |

---

## Notes

- All passives are deterministic (no RNG)
- Level scaling is linear
- Passives do not require UI changes
- Logs are the primary verification method
