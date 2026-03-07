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
var _grid_manager = null  # Grid Combat v1: Optional GridManager for range-based targeting

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(mode: TargetMode = TargetMode.LOWEST_HP, rng: RandomNumberGenerator = null) -> void:
	_mode = mode
	_rng = rng


## Set targeting mode.
func set_mode(mode: TargetMode) -> void:
	_mode = mode


## Grid Combat v1: Set GridManager for range-based targeting.
func set_grid_manager(gm) -> void:
	_grid_manager = gm


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

	# Grid Combat v1: Filter by attack range if grid_manager is available
	var in_range_enemies: Array = alive_enemies
	if _grid_manager != null:
		in_range_enemies = _filter_by_attack_range(attacker, alive_enemies)

	# Taunt enforcement: if any enemy has "taunting" status AND is in range, force target
	for enemy in alive_enemies:
		if enemy.has_status_v1("taunting"):
			# Grid Combat v1: Melee can only be taunted if target is in range
			if _grid_manager != null and not _is_in_attack_range(attacker, enemy):
				continue  # Taunt ignored — out of range for melee
			return enemy

	# If grid filtering left no targets in range, fall back to all alive
	# (this lets the AI know it should move first, but as a safety fallback)
	var target_pool: Array = in_range_enemies if not in_range_enemies.is_empty() else alive_enemies

	match _mode:
		TargetMode.LOWEST_HP:
			return _select_lowest_hp(target_pool)
		TargetMode.FIRST_ALIVE:
			return _select_first_alive(target_pool)
		TargetMode.RANDOM:
			return _select_random(target_pool)
		TargetMode.GRID_DEFAULT:
			return _select_grid_default(attacker, target_pool)
		_:
			return _select_lowest_hp(target_pool)


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


## Melee targeting: must target frontmost alive row (Front → Middle → Back).
## (3-Row Formation v1)
func _select_melee_target(enemies: Array) -> CombatUnit:
	var front_row = get_front_row_units(enemies)
	var middle_row = get_middle_row_units(enemies)
	var back_row = get_back_row_units(enemies)

	# Prefer front row
	if not front_row.is_empty():
		front_row.sort_custom(_compare_by_hp_then_id)
		return front_row[0]

	# Then middle row
	if not middle_row.is_empty():
		middle_row.sort_custom(_compare_by_hp_then_id)
		return middle_row[0]

	# Fall back to back row
	if not back_row.is_empty():
		back_row.sort_custom(_compare_by_hp_then_id)
		return back_row[0]

	return null


## Ranged targeting: can target any row, picks lowest %HP.
func _select_ranged_target(enemies: Array) -> CombatUnit:
	if enemies.is_empty():
		return null

	var sorted = enemies.duplicate()
	sorted.sort_custom(_compare_by_hp_pct_then_id)
	return sorted[0]


# ============================================================================
# GRID COMBAT v1: RANGE-BASED TARGETING
# ============================================================================

## Check if attacker can reach target based on grid distance.
## Melee: adjacent only (Manhattan distance 1). Ranged: any tile.
func _is_in_attack_range(attacker: CombatUnit, target: CombatUnit) -> bool:
	if _grid_manager == null:
		return true  # No grid = always in range (legacy)
	var range_cat = get_attacker_range(attacker)
	if range_cat == RangeCategory.RANGED:
		return true  # Ranged can hit any tile
	# Melee: must be adjacent (Manhattan dist <= 1)
	var attacker_pos = Vector2i(attacker.grid_x, attacker.grid_y)
	var target_pos = Vector2i(target.grid_x, target.grid_y)
	var dist = _grid_manager.manhattan_distance(attacker_pos, target_pos)
	return dist <= 1


## Filter enemies to only those within attack range.
func _filter_by_attack_range(attacker: CombatUnit, enemies: Array) -> Array:
	var in_range: Array = []
	for enemy in enemies:
		if _is_in_attack_range(attacker, enemy):
			in_range.append(enemy)
	return in_range


# ============================================================================
# GRID HELPERS (Legacy Row-Based)
# ============================================================================

## Get all alive units in front row (y == 0).
static func get_front_row_units(enemies: Array) -> Array:
	var front: Array = []
	for enemy in enemies:
		if enemy.is_alive and enemy.is_front_row():
			front.append(enemy)
	return front


## Get all alive units in middle row (y == 1). (3-Row Formation v1)
static func get_middle_row_units(enemies: Array) -> Array:
	var middle: Array = []
	for enemy in enemies:
		if enemy.is_alive and enemy.is_middle_row():
			middle.append(enemy)
	return middle


## Get all alive units in back row (y == 2). (3-Row Formation v1)
static func get_back_row_units(enemies: Array) -> Array:
	var back: Array = []
	for enemy in enemies:
		if enemy.is_alive and enemy.is_back_row():
			back.append(enemy)
	return back


## Determine attacker's range category based on attack_type or weapon.
## Checks explicit attack_type first (monsters + heroes), falls back to weapon heuristic.
static func get_attacker_range(attacker: CombatUnit) -> RangeCategory:
	# Explicit attack_type takes priority
	if attacker.attack_type == "ranged":
		return RangeCategory.RANGED
	if attacker.attack_type == "melee":
		return RangeCategory.MELEE

	# Fallback: weapon-based heuristic for heroes without explicit attack_type
	var weapon_id = attacker.weapon_ability_id.to_lower()
	if weapon_id.contains("sword") or weapon_id.contains("mace") or weapon_id.contains("axe"):
		return RangeCategory.MELEE

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


## Compare by HP percentage first, then by unit_id for stable ordering.
## Used by ranged targeting to focus the most-injured unit by %, not absolute HP.
static func _compare_by_hp_pct_then_id(a: CombatUnit, b: CombatUnit) -> bool:
	var pct_a: float = float(a.current_health) / float(a.max_health)
	var pct_b: float = float(b.current_health) / float(b.max_health)
	if not is_equal_approx(pct_a, pct_b):
		return pct_a < pct_b
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
