## TargetingPolicy.gd
## Handles target selection for combat actions.
## Supports both simple and grid-based targeting modes.
##
## Source: M2.1 Hardening Pass, M3 Grid Implementation
class_name TargetingPolicy
extends RefCounted

# ============================================================================
# TARGETING MODES
# ============================================================================

enum TargetMode {
	LOWEST_HP,      # Default: target lowest HP enemy
	FIRST_ALIVE,    # Target first alive in list order
	RANDOM,         # Random target (uses RNG)
	HIGHEST_THREAT, # Future: based on threat/aggro
	NEAREST,        # Future: grid-based nearest
	GRID_DEFAULT,   # M3: Respects front/back row based on weapon range
}

# ============================================================================
# RANGE CATEGORIES
# ============================================================================

enum RangeCategory {
	MELEE,   # Can only target front row if enemies there
	RANGED,  # Can target any row
}

# ============================================================================
# STATE
# ============================================================================

var _mode: TargetMode = TargetMode.LOWEST_HP
var _rng: RandomNumberGenerator = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(mode: TargetMode = TargetMode.LOWEST_HP, rng: RandomNumberGenerator = null) -> void:
	_mode = mode
	_rng = rng


## Set targeting mode.
func set_mode(mode: TargetMode) -> void:
	_mode = mode


# ============================================================================
# PUBLIC API
# ============================================================================

## Select a target from available enemies.
## Returns null if no valid target found.
func select_target(attacker: CombatUnit, enemies: Array) -> CombatUnit:
	# Filter to alive enemies only
	var alive_enemies: Array = []
	for enemy in enemies:
		if enemy.is_alive:
			alive_enemies.append(enemy)

	if alive_enemies.is_empty():
		return null

	match _mode:
		TargetMode.LOWEST_HP:
			return _select_lowest_hp(alive_enemies)
		TargetMode.FIRST_ALIVE:
			return _select_first_alive(alive_enemies)
		TargetMode.RANDOM:
			return _select_random(alive_enemies)
		TargetMode.GRID_DEFAULT:
			return _select_grid_default(attacker, alive_enemies)
		_:
			return _select_lowest_hp(alive_enemies)


## Select multiple targets (for future AoE abilities).
func select_targets(attacker: CombatUnit, enemies: Array, count: int) -> Array:
	var alive_enemies: Array = []
	for enemy in enemies:
		if enemy.is_alive:
			alive_enemies.append(enemy)

	if alive_enemies.is_empty():
		return []

	# Sort by HP for consistent selection
	alive_enemies.sort_custom(_compare_by_hp_then_id)

	var targets: Array = []
	for i in range(mini(count, alive_enemies.size())):
		targets.append(alive_enemies[i])

	return targets


# ============================================================================
# TARGETING IMPLEMENTATIONS
# ============================================================================

func _select_lowest_hp(enemies: Array) -> CombatUnit:
	if enemies.is_empty():
		return null

	# Sort by HP, then by unit_id for stable ordering
	var sorted = enemies.duplicate()
	sorted.sort_custom(_compare_by_hp_then_id)
	return sorted[0]


func _select_first_alive(enemies: Array) -> CombatUnit:
	if enemies.is_empty():
		return null
	return enemies[0]


func _select_random(enemies: Array) -> CombatUnit:
	if enemies.is_empty():
		return null

	if _rng != null:
		var index = _rng.randi_range(0, enemies.size() - 1)
		return enemies[index]
	else:
		# Fallback to first if no RNG
		return enemies[0]


## Grid-based targeting: respects front/back row based on attacker's range.
func _select_grid_default(attacker: CombatUnit, enemies: Array) -> CombatUnit:
	var range_cat = get_attacker_range(attacker)

	if range_cat == RangeCategory.MELEE:
		return _select_melee_target(enemies)
	else:
		return _select_ranged_target(enemies)


## Melee targeting: must target front row if any alive, else back row.
func _select_melee_target(enemies: Array) -> CombatUnit:
	var front_row = get_front_row_units(enemies)
	var back_row = get_back_row_units(enemies)

	# Prefer front row
	if not front_row.is_empty():
		front_row.sort_custom(_compare_by_hp_then_id)
		return front_row[0]

	# Fall back to back row
	if not back_row.is_empty():
		back_row.sort_custom(_compare_by_hp_then_id)
		return back_row[0]

	return null


## Ranged targeting: can target any row, picks lowest HP.
func _select_ranged_target(enemies: Array) -> CombatUnit:
	if enemies.is_empty():
		return null

	var sorted = enemies.duplicate()
	sorted.sort_custom(_compare_by_hp_then_id)
	return sorted[0]


# ============================================================================
# GRID HELPERS
# ============================================================================

## Get all alive units in front row (y == 0).
static func get_front_row_units(enemies: Array) -> Array:
	var front: Array = []
	for enemy in enemies:
		if enemy.is_alive and enemy.is_front_row():
			front.append(enemy)
	return front


## Get all alive units in back row (y == 1).
static func get_back_row_units(enemies: Array) -> Array:
	var back: Array = []
	for enemy in enemies:
		if enemy.is_alive and enemy.is_back_row():
			back.append(enemy)
	return back


## Determine attacker's range category based on weapon.
## Temporary logic: "sword" in ability ID = MELEE, else RANGED.
static func get_attacker_range(attacker: CombatUnit) -> RangeCategory:
	var weapon_id = attacker.weapon_ability_id.to_lower()

	# Temporary rule: sword = melee
	if weapon_id.contains("sword"):
		return RangeCategory.MELEE

	# Default to ranged for now
	return RangeCategory.RANGED


## Check if attacker can target a specific unit based on grid rules.
static func can_target(attacker: CombatUnit, target: CombatUnit, all_enemies: Array) -> bool:
	if not target.is_alive:
		return false

	var range_cat = get_attacker_range(attacker)

	if range_cat == RangeCategory.RANGED:
		# Ranged can target anyone
		return true

	# Melee: can only target back row if front row is empty
	if target.is_back_row():
		var front_row = get_front_row_units(all_enemies)
		if not front_row.is_empty():
			return false  # Front row blocks back row

	return true


# ============================================================================
# COMPARISON HELPERS
# ============================================================================

## Compare by HP first, then by unit_id for stable ordering.
static func _compare_by_hp_then_id(a: CombatUnit, b: CombatUnit) -> bool:
	if a.current_health != b.current_health:
		return a.current_health < b.current_health
	return a.unit_id < b.unit_id


# ============================================================================
# TEAM HELPERS
# ============================================================================

## Get enemies for the opposing team.
static func get_enemies_for_team(all_units: Array, attacker_team: CombatUnit.Team) -> Array:
	var enemies: Array = []
	var target_team = CombatUnit.Team.ENEMY if attacker_team == CombatUnit.Team.PLAYER else CombatUnit.Team.PLAYER

	for unit in all_units:
		if unit.team == target_team:
			enemies.append(unit)

	return enemies


## Get allies for the same team.
static func get_allies_for_team(all_units: Array, team: CombatUnit.Team) -> Array:
	var allies: Array = []

	for unit in all_units:
		if unit.team == team:
			allies.append(unit)

	return allies
