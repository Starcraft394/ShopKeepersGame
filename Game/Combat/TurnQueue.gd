## TurnQueue.gd
## Manages turn order for combat.
## Initiative ties: PLAYER FIRST, then stable ID sort.
##
## Source: MVP_Milestones.md (M1), GDD Section 23
class_name TurnQueue
extends RefCounted

# ============================================================================
# STATE
# ============================================================================

var _units: Array = []           # All units in combat
var _turn_order: Array = []      # Sorted order for current round
var _current_index: int = 0
var _round_number: int = 0

# ============================================================================
# INITIALIZATION
# ============================================================================

## Initialize the queue with combat units.
func initialize(units: Array) -> void:
	_units = units.duplicate()
	_round_number = 0
	_rebuild_turn_order()


## Rebuild turn order based on initiative.
## Sort by: Speed (descending), then Player first, then unit_id (stable).
func _rebuild_turn_order() -> void:
	_turn_order.clear()
	_current_index = 0

	# Filter alive units
	for unit in _units:
		if unit.is_alive:
			_turn_order.append(unit)

	# Sort: higher speed first, player team first on ties, then by unit_id
	_turn_order.sort_custom(_compare_initiative)

	_round_number += 1
	print("[TurnQueue] Round %d order:" % _round_number)
	for i in range(_turn_order.size()):
		var unit = _turn_order[i]
		print("  %d. %s (SPD:%d, %s)" % [
			i + 1, unit.display_name, unit.speed,
			"PLAYER" if unit.team == CombatUnit.Team.PLAYER else "ENEMY"])


## Compare two units for turn order.
## Returns true if 'a' should go before 'b'.
func _compare_initiative(a: CombatUnit, b: CombatUnit) -> bool:
	# Higher speed goes first
	if a.speed != b.speed:
		return a.speed > b.speed

	# Tie-breaker 1: Player team goes first
	if a.team != b.team:
		return a.team == CombatUnit.Team.PLAYER

	# Tie-breaker 2: Stable sort by unit_id
	return a.unit_id < b.unit_id


# ============================================================================
# PUBLIC API
# ============================================================================

## Get the next unit to act. Returns null if round is over.
func get_next_unit() -> CombatUnit:
	# Skip dead units
	while _current_index < _turn_order.size():
		var unit = _turn_order[_current_index]
		if unit.is_alive:
			return unit
		_current_index += 1

	return null


## Advance to the next unit after current one has acted.
func advance() -> void:
	_current_index += 1


## Check if the current round is complete.
func is_round_complete() -> bool:
	return _current_index >= _turn_order.size()


## Start a new round (recalculate turn order).
func start_new_round() -> void:
	_rebuild_turn_order()


## Get the current round number.
func get_round_number() -> int:
	return _round_number


## Get all living units.
func get_living_units() -> Array:
	var living = []
	for unit in _units:
		if unit.is_alive:
			living.append(unit)
	return living


## Get living units of a specific team.
func get_living_units_by_team(team: CombatUnit.Team) -> Array:
	var living = []
	for unit in _units:
		if unit.is_alive and unit.team == team:
			living.append(unit)
	return living


## Check if a team has been wiped.
func is_team_wiped(team: CombatUnit.Team) -> bool:
	for unit in _units:
		if unit.is_alive and unit.team == team:
			return false
	return true


## Get the first alive enemy for simple targeting.
func get_first_alive_enemy(attacker_team: CombatUnit.Team) -> CombatUnit:
	var target_team = CombatUnit.Team.ENEMY if attacker_team == CombatUnit.Team.PLAYER else CombatUnit.Team.PLAYER
	for unit in _units:
		if unit.is_alive and unit.team == target_team:
			return unit
	return null


## Remove a unit from tracking (on death).
func remove_unit(unit: CombatUnit) -> void:
	# Don't actually remove, just mark as dead - handled by is_alive check
	pass


# ============================================================================
# DEBUG
# ============================================================================

func get_turn_order_string() -> String:
	var parts = []
	for i in range(_turn_order.size()):
		var unit = _turn_order[i]
		var marker = ">" if i == _current_index else " "
		var alive_marker = "" if unit.is_alive else "[DEAD]"
		parts.append("%s%d.%s%s" % [marker, i + 1, unit.display_name, alive_marker])
	return " | ".join(parts)
