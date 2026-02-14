## FormationAssigner.gd
## Assigns grid positions to combat units in a 4x2 formation.
## Front row (y=0) fills first, then back row (y=1).
##
## NOTE (M3.1): Player and Enemy each have their OWN separate 4x2 grid.
## player(0,0) and enemy(0,0) are valid - they occupy different grids.
## Overlap validation is per-team, not global.
##
## Source: M3 Grid Implementation, M3.1 Grid Space Patch
class_name FormationAssigner
extends RefCounted

# ============================================================================
# CONSTANTS
# ============================================================================

const DEFAULT_GRID_WIDTH = 4
const DEFAULT_GRID_HEIGHT = 3  # 3-Row Formation v1: Front/Middle/Back

const FRONT_ROW = 0
const MIDDLE_ROW = 1  # 3-Row Formation v1
const BACK_ROW = 2    # 3-Row Formation v1: was 1, now 2

# ============================================================================
# PUBLIC API
# ============================================================================

## Assign default formation to both player and enemy units.
## Units are sorted by unit_id for deterministic assignment.
## Returns true if all units were assigned valid positions.
static func assign_default_formation(
	player_units: Array,
	enemy_units: Array,
	grid_w: int = DEFAULT_GRID_WIDTH,
	grid_h: int = DEFAULT_GRID_HEIGHT
) -> bool:
	var player_ok = _assign_team_formation(player_units, grid_w, grid_h)
	var enemy_ok = _assign_team_formation(enemy_units, grid_w, grid_h)
	return player_ok and enemy_ok


## Assign formation to a single team's units.
static func assign_team_formation(
	units: Array,
	grid_w: int = DEFAULT_GRID_WIDTH,
	grid_h: int = DEFAULT_GRID_HEIGHT
) -> bool:
	return _assign_team_formation(units, grid_w, grid_h)


# ============================================================================
# INTERNAL
# ============================================================================

static func _assign_team_formation(units: Array, grid_w: int, grid_h: int) -> bool:
	if units.is_empty():
		return true

	var max_slots = grid_w * grid_h
	if units.size() > max_slots:
		push_warning("[FormationAssigner] Too many units (%d) for grid (%dx%d = %d slots)" % [
			units.size(), grid_w, grid_h, max_slots])
		# Continue anyway, some units won't fit

	# Sort units by unit_id for deterministic ordering
	var sorted_units = units.duplicate()
	sorted_units.sort_custom(_compare_by_unit_id)

	# Assign positions: front row first, left to right
	var slot_index = 0
	for unit in sorted_units:
		if slot_index >= max_slots:
			# Unit doesn't fit
			unit.set_position(-1, -1)
			continue

		var x = slot_index % grid_w
		var y = slot_index / grid_w  # Integer division: 0-3 = row 0, 4-7 = row 1

		unit.set_position(x, y)
		slot_index += 1

	return slot_index <= max_slots


static func _compare_by_unit_id(a: CombatUnit, b: CombatUnit) -> bool:
	return a.unit_id < b.unit_id


# ============================================================================
# QUERY HELPERS
# ============================================================================

## Get all units in front row (y == 0).
static func get_front_row_units(units: Array) -> Array:
	var front: Array = []
	for unit in units:
		if unit.is_alive and unit.is_front_row():
			front.append(unit)
	return front


## Get all units in middle row (y == 1). (3-Row Formation v1)
static func get_middle_row_units(units: Array) -> Array:
	var middle: Array = []
	for unit in units:
		if unit.is_alive and unit.is_middle_row():
			middle.append(unit)
	return middle


## Get all units in back row (y == 2). (3-Row Formation v1)
static func get_back_row_units(units: Array) -> Array:
	var back: Array = []
	for unit in units:
		if unit.is_alive and unit.is_back_row():
			back.append(unit)
	return back


## Check if any units are alive in front row.
static func has_front_row_alive(units: Array) -> bool:
	for unit in units:
		if unit.is_alive and unit.is_front_row():
			return true
	return false


## Check if any units are alive in middle row. (3-Row Formation v1)
static func has_middle_row_alive(units: Array) -> bool:
	for unit in units:
		if unit.is_alive and unit.is_middle_row():
			return true
	return false


## Check if any units are alive in back row. (3-Row Formation v1)
static func has_back_row_alive(units: Array) -> bool:
	for unit in units:
		if unit.is_alive and unit.is_back_row():
			return true
	return false


## Get all occupied position keys for validation (team-local).
static func get_occupied_positions(units: Array) -> Array:
	var positions: Array = []
	for unit in units:
		if unit.has_position():
			positions.append(unit.get_position_key())
	return positions


## Validate that no two units within the SAME team share the same position.
## NOTE: This checks a single team's array. Use validate_no_overlap_per_team()
## for checking both teams at once.
static func validate_no_overlap(units: Array) -> bool:
	var seen: Dictionary = {}
	for unit in units:
		if not unit.has_position():
			continue
		var key = unit.get_position_key()
		if seen.has(key):
			push_error("[FormationAssigner] Position overlap at %s: %s and %s" % [
				key, seen[key], unit.unit_id])
			return false
		seen[key] = unit.unit_id
	return true


## Validate both teams have no internal overlaps.
## NOTE (M3.1): Player and enemy grids are SEPARATE.
## player(0,0) and enemy(0,0) is ALLOWED - they're on different grids.
static func validate_no_overlap_per_team(player_units: Array, enemy_units: Array) -> bool:
	var player_ok = validate_no_overlap(player_units)
	var enemy_ok = validate_no_overlap(enemy_units)
	return player_ok and enemy_ok


# ============================================================================
# DEBUG
# ============================================================================

## Print formation layout to console.
static func print_formation(units: Array, team_name: String = "Team") -> void:
	print("\n[FormationAssigner] %s Formation:" % team_name)

	# Build grid display
	var grid: Dictionary = {}
	for unit in units:
		if unit.has_position():
			var key = unit.get_position_key()
			var status = "OK" if unit.is_alive else "DEAD"
			grid[key] = "%s(%s)" % [unit.display_name.left(4), status]

	# Print rows (back row first for visual clarity)
	print("  BACK ROW (y=1):")
	var back_line = "    "
	for x in range(DEFAULT_GRID_WIDTH):
		var key = "%d_1" % x
		if grid.has(key):
			back_line += "[%s] " % grid[key]
		else:
			back_line += "[    ] "
	print(back_line)

	print("  FRONT ROW (y=0):")
	var front_line = "    "
	for x in range(DEFAULT_GRID_WIDTH):
		var key = "%d_0" % x
		if grid.has(key):
			front_line += "[%s] " % grid[key]
		else:
			front_line += "[    ] "
	print(front_line)
