# Class Passives v1 Implementation Plan

**Date:** 2026-01-16
**Scope:** Region 1 classes (defender, striker, warden)

---

## 1. Current Implementation Inventory

### Passive Data Files
**Location:** `Data/Passives/`

| File | Passive ID | Type | Effect |
|------|------------|------|--------|
| def_iron_skin.json | def_iron_skin | stat_bonus | +2 DEF |
| def_front_line_bonus.json | def_front_line_bonus | conditional_stat_bonus | +10 HP (front row) |
| str_killer_instinct.json | str_killer_instinct | stat_bonus | +2 ATK |
| str_execute_momentum.json | str_execute_momentum | on_kill | Reduce weapon CD |

### Class JSON References
**Location:** `Data/Classes/`

| Class | passive_a_id | passive_b_id | Status |
|-------|--------------|--------------|--------|
| defender.json | bulwark_stance | shielding_presence | IDs not in Data/Passives/ |
| striker.json | momentum_edge | finishers_instinct | IDs not in Data/Passives/ |
| warden.json | living_bond | verdant_renewal | IDs not in Data/Passives/ |

### Passive Loading/Application Code
**Location:** `Game/Combat/CombatController.gd`

| Function | Line | Purpose |
|----------|------|---------|
| _apply_all_passives() | ~197 | Called at combat init, applies stat bonuses |
| _apply_passives_to_unit() | ~204 | Applies unit's passive_a and passive_b |
| _apply_single_passive() | ~212 | Handles stat_bonus and conditional types |
| _trigger_on_kill_passives() | ~407 | Handles on_kill passive triggers |

### Passive Data Structure
**Location:** `Game/Core/DataTypes/PassiveData.gd`

Current supported types:
- `stat_bonus` - Flat stat increase at combat start
- `conditional_stat_bonus` - Conditional (e.g., front row) stat increase
- `on_kill` - Trigger effect on killing blow

**Missing for v1:**
- Level-scaled bonuses
- On-kill stacking buffs
- Round-start triggers

### Hero Level Availability
- `CombatUnit.source_id` contains the hero_id
- Hero level can be fetched via `GameContext.get_hero(source_id).get("level", 1)`
- Need to add `hero_level` property to CombatUnit for passive scaling

---

## 2. V1 Passive Specifications

### (A) Defender - bulwark_stance
**Trigger:** Combat start
**Effect:** Grant Defender +DEF = (2 + hero_level)
**Implementation:**
- Add level-scaled bonus calculation in `_apply_single_passive()`
- Create `bulwark_stance.json` with new `passive_type: "level_scaled_stat_bonus"`

### (B) Striker - killer_instinct
**Trigger:** On kill
**Effect:** Striker gains +(1 + floor(level/2)) ATK per kill, stacks persist for combat duration
**Implementation:**
- Track kill count in CombatUnit
- Modify `_trigger_on_kill_passives()` to apply stacking ATK buff
- Create `killer_instinct.json` (different from existing str_killer_instinct)

### (C) Warden - verdant_renewal
**Trigger:** Start of each round
**Effect:** Heal lowest HP% ally by (3 + hero_level) HP
**Implementation:**
- Add round-start passive trigger hook
- Connect to `round_ended` signal (fires at round boundary)
- Create `verdant_renewal.json` with `passive_type: "round_start_heal"`

---

## 3. Code Changes

### CombatUnit.gd
**Add:**
```gdscript
var hero_level: int = 1  # Hero level for passive scaling
var killer_instinct_stacks: int = 0  # Tracks on-kill ATK stacks
```

**Modify:** `create_hero()` to store hero_level from effective_stats

### CombatController.gd
**Add:**
```gdscript
func _apply_round_start_passives() -> void
    # Called at start of each round
    # Handles verdant_renewal healing
```

**Modify:**
- `_apply_single_passive()` - Handle level-scaled bonuses
- `_trigger_on_kill_passives()` - Handle killer_instinct stacking
- Round transition code to call `_apply_round_start_passives()`

### PassiveData.gd
**Add passive_type values:**
- `level_scaled_stat_bonus` - For bulwark_stance
- `on_kill_stacking_buff` - For killer_instinct
- `round_start_heal` - For verdant_renewal

---

## 4. Data Files to Create/Update

### Create:
- `Data/Passives/bulwark_stance.json`
- `Data/Passives/killer_instinct.json`
- `Data/Passives/verdant_renewal.json`

### Update (optional):
- Can leave class JSONs as-is since they already reference these IDs

---

## 5. Testing Strategy

### Logging Format
Each passive must log when triggered:

```
[Passive] bulwark_stance hero=<id> name=<name> level=<n> def_before=<n> def_after=<n>
[Passive] killer_instinct hero=<id> name=<name> level=<n> stacks=<n> atk_before=<n> atk_after=<n> target=<enemy_id>
[Passive] verdant_renewal healer=<id> level=<n> target=<ally_id> hp_before=<n> hp_after=<n>
```

### Manual Test Cases
1. **Defender bulwark_stance:** Recruit Lv1 Defender -> Combat -> Verify +3 DEF
2. **Striker killer_instinct:** Recruit Striker, get a kill -> Verify ATK increase logged
3. **Warden verdant_renewal:** Recruit Warden + damaged ally -> Multiple rounds -> Verify healing each round

---

## 6. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Break existing passives | Keep stat_bonus type unchanged, add new types |
| Break smoke tests | Run headless validation after each change |
| Double-apply passives | Guard against re-application |
| Hero level not available | Add hero_level to CombatUnit, populate from effective_stats |
