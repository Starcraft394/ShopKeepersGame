# Combat System Reference

Detailed patterns for turn-based combat in Godot.

## Architecture Overview

```
CombatController.gd (Orchestrator)
│
├── Manages combat state machine (SETUP → RUNNING → ENDED)
├── Processes turns via TurnQueue
├── Delegates damage/heal/status to CombatUnits
└── Tracks results via CombatResult

TurnQueue.gd (Turn Ordering)
│
├── Rebuilds order each round based on effective speed
├── Tiebreaker: higher speed → player team → alphabetical unit_id
└── Skips dead units within current round

CombatUnit.gd (Unit State)
│
├── Base stats (health, attack, defense, speed)
├── Buffs array with duration tracking
├── Active statuses (DOT, stun, etc.)
└── Effective stat calculations (base + buffs)

StatusRuntime.gd (Per-Unit Effects)
│
├── Legacy status processing (stun, doom)
├── Tick at round start
└── Separate from v1 status hooks

CombatResult.gd (Outcome Tracking)
│
├── Victory/defeat/draw determination
├── Loot calculation from monster drops
└── Action log for replay/debugging
```

## Combat Flow (DO NOT MODIFY)

```
1. SETUP
   ├── Create CombatUnits from party + enemies
   ├── Apply class passives
   ├── Apply race passives
   ├── Apply equipment bonuses
   ├── Apply combat modifiers (from events)
   └── Initialize TurnQueue

2. ROUND START
   ├── Rebuild turn order (effective speed)
   ├── Tick status durations
   └── Process round-start effects

3. TURN PROCESSING
   ├── Get next unit from queue
   ├── Check stun (legacy + v1)
   │   └── If stunned → skip turn
   ├── Execute action (ability or basic attack)
   ├── Apply damage/healing
   ├── Apply status effects
   ├── Trigger on-kill passives
   ├── Tick cooldowns
   └── Check victory/defeat

4. ROUND END
   ├── Process doom triggers
   └── Continue to next round or end
```

## Stat Calculations

### Effective Stats (Always Use These)

```gdscript
func get_effective_attack() -> int:
    var total = base_attack
    for buff in buffs:
        if buff.stat == "attack":
            total += buff.value
    return total

func get_effective_defense() -> int:
    var total = base_defense
    for buff in buffs:
        if buff.stat == "defense":
            total += buff.value
    return total

func get_effective_speed() -> int:
    var total = base_speed
    for buff in buffs:
        if buff.stat == "speed":
            total += buff.value
    return total
```

### Damage Calculation

```gdscript
func calculate_damage(attacker: CombatUnit, target: CombatUnit, base_damage: int, damage_type: String) -> int:
    var effective_attack = attacker.get_effective_attack()
    var scaled_damage = base_damage + (effective_attack * scaling_factor)

    if damage_type == "physical":
        var effective_defense = target.get_effective_defense()
        scaled_damage = max(1, scaled_damage - effective_defense)

    return int(scaled_damage)
```

## Status Effect System

### v1 Status Hooks

```gdscript
# Applying a status
func apply_status_v1(status_id: String, duration: int, stacks: int = 1) -> void:
    var existing = _find_status(status_id)
    var status_data = DataRegistry.get_status_effect(status_id)
    var stacking_mode = status_data.stacking_mode  # "refresh" or "intensity"

    if existing != null:
        if stacking_mode == "refresh":
            existing.remaining_rounds = max(existing.remaining_rounds, duration)
        elif stacking_mode == "intensity":
            existing.stacks = min(existing.stacks + stacks, status_data.max_stacks)
            existing.remaining_rounds = duration
    else:
        active_statuses.append({
            "id": status_id,
            "stacks": stacks,
            "remaining_rounds": duration
        })
```

### Status Types

| Type | Behavior |
|------|----------|
| **stun** | Blocks action, refresh only |
| **poisoned** | DOT, intensity stacking |
| **bleeding** | DOT, intensity stacking |
| **burn** | DOT, intensity stacking |
| **doom** | Countdown, triggers damage at 0 |

### DOT Processing

```gdscript
func process_dot_tick() -> int:
    var total_damage = 0
    for status in active_statuses:
        var data = DataRegistry.get_status_effect(status.id)
        if data.category == "dot":
            var tick_damage = data.base_value * status.stacks
            total_damage += tick_damage
    return total_damage
```

## Buff System

### Buff Structure

```gdscript
var buff = {
    "id": "shadowstep_speed",
    "stat": "speed",
    "value": 5,
    "remaining_rounds": 2,
    "source": "ability",
    "tags": ["offense", "self"]
}
```

### Buff Lifecycle

```
1. Applied via apply_buff()
2. Added to buffs array
3. Affects effective stat calculations immediately
4. Ticked at round start (remaining_rounds -= 1)
5. Removed when remaining_rounds <= 0
```

## Grid System (M3.1)

```
Player Grid (4x2)        Enemy Grid (4x2)
+---+---+---+---+       +---+---+---+---+
| 0 | 1 | 2 | 3 | y=0   | 0 | 1 | 2 | 3 | y=0 (front)
+---+---+---+---+       +---+---+---+---+
| 0 | 1 | 2 | 3 | y=1   | 0 | 1 | 2 | 3 | y=1 (back)
+---+---+---+---+       +---+---+---+---+
```

### Melee Targeting Rule

```gdscript
# Melee weapons (sword, axe, etc.) must target front row if occupied
func get_valid_targets(attacker: CombatUnit, targets: Array) -> Array:
    if is_melee_weapon(attacker.weapon_id):
        var front_row = targets.filter(func(t): return t.grid_y == 0 and t.is_alive())
        if front_row.size() > 0:
            return front_row
    return targets.filter(func(t): return t.is_alive())
```

## Determinism Requirements

### SeededRNG Usage

```gdscript
# All combat randomness must use SeededRNG
var damage_roll = SeededRNG.randi_range(min_damage, max_damage)
var crit_check = SeededRNG.randf() < crit_chance
var loot_roll = SeededRNG.randf()

# NEVER use:
# - randi()
# - randf()
# - RandomNumberGenerator.new() without seed
```

### Reproducibility Test

```gdscript
# Same seed + same actions = identical results
func test_combat_determinism():
    SeededRNG.set_seed(12345)
    var result_a = run_combat_simulation()

    SeededRNG.set_seed(12345)
    var result_b = run_combat_simulation()

    assert(result_a.damage_dealt == result_b.damage_dealt)
    assert(result_a.turns_taken == result_b.turns_taken)
```

## Testing Combat Features

### Unit Test Pattern

```gdscript
static func _test_damage_calculation() -> Dictionary:
    print("--- TEST: Damage Calculation ---")

    var attacker = CombatUnit.new()
    attacker.base_attack = 10

    var target = CombatUnit.new()
    target.base_defense = 5
    target.current_hp = 100

    var damage = calculate_damage(attacker, target, 15, "physical")
    # Expected: 15 + 10 (attack) - 5 (defense) = 20

    var passed = damage == 20
    if passed:
        print("[PASS] Damage calculation correct: %d" % damage)
    else:
        print("[FAIL] Expected 20, got %d" % damage)

    return {"name": "Damage Calculation", "passed": passed}
```

## Invariants Checklist

Before modifying combat code, verify:

- [ ] Turn order uses effective speed, not base speed
- [ ] Player team wins speed ties
- [ ] Stun checks both legacy and v1 systems
- [ ] DOT damage scales with stacks
- [ ] All RNG uses SeededRNG
- [ ] Status duration +1 accounts for round-start tick
- [ ] Melee front-row blocking is enforced
- [ ] Passive application order: Class → Race → Equipment
