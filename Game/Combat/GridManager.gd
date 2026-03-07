## GridManager.gd
## Manages a unified 8x4 combat grid shared by both teams.
## Handles occupancy, pathfinding (BFS), range queries, and AoE resolution.
##
## Grid layout:
##   Cols 0-1: Player spawn zone (back=0, front=1)
##   Cols 2-5: Open battlefield
##   Cols 6-7: Enemy spawn zone (front=6, back=7)
##   Rows 0-3: Vertical lanes
##
## Source: Grid Combat System v1
class_name GridManager
extends RefCounted

# ============================================================================
# CONSTANTS
# ============================================================================

const GRID_WIDTH: int = 8
const GRID_HEIGHT: int = 4

const PLAYER_SPAWN_COLS: Array = [0, 1]
const ENEMY_SPAWN_COLS: Array = [4, 5, 6, 7]

# Cardinal directions for BFS traversal (no diagonals)
const DIRECTIONS: Array = [
	Vector2i(1, 0),   # right
	Vector2i(-1, 0),  # left
	Vector2i(0, 1),   # down
	Vector2i(0, -1),  # up
]

# ============================================================================
# STATE
# ============================================================================

# 2D occupancy grid: _grid[x][y] -> CombatUnit or null
var _grid: Array = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	_grid.resize(GRID_WIDTH)
	for x in range(GRID_WIDTH):
		_grid[x] = []
		_grid[x].resize(GRID_HEIGHT)
		for y in range(GRID_HEIGHT):
			_grid[x][y] = null


# ============================================================================
# OCCUPANCY API
# ============================================================================

## Place a unit at the given position. Returns false if out of bounds or occupied.
func place_unit(unit: CombatUnit, pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		push_warning("[GridManager] Cannot place %s at %s: out of bounds" % [unit.unit_id, pos])
		return false
	if _grid[pos.x][pos.y] != null:
		push_warning("[GridManager] Cannot place %s at %s: tile occupied by %s" % [
			unit.unit_id, pos, _grid[pos.x][pos.y].unit_id])
		return false
	_grid[pos.x][pos.y] = unit
	unit.grid_x = pos.x
	unit.grid_y = pos.y
	return true


## Remove a unit from its current grid position.
func remove_unit(unit: CombatUnit) -> void:
	var pos = Vector2i(unit.grid_x, unit.grid_y)
	if is_in_bounds(pos) and _grid[pos.x][pos.y] == unit:
		_grid[pos.x][pos.y] = null


## Move a unit to a new position. Returns false if invalid.
func move_unit(unit: CombatUnit, to: Vector2i) -> bool:
	if not is_in_bounds(to):
		return false
	if _grid[to.x][to.y] != null:
		return false  # Destination occupied

	# Remove from old position
	var from = Vector2i(unit.grid_x, unit.grid_y)
	if is_in_bounds(from) and _grid[from.x][from.y] == unit:
		_grid[from.x][from.y] = null

	# Place at new position
	_grid[to.x][to.y] = unit
	unit.grid_x = to.x
	unit.grid_y = to.y
	return true


## Swap two units' grid positions. Both must be placed on the grid.
## Returns false if either unit is not on the grid.
func swap_units(unit_a: CombatUnit, unit_b: CombatUnit) -> bool:
	var pos_a = Vector2i(unit_a.grid_x, unit_a.grid_y)
	var pos_b = Vector2i(unit_b.grid_x, unit_b.grid_y)
	if not is_in_bounds(pos_a) or not is_in_bounds(pos_b):
		return false
	if _grid[pos_a.x][pos_a.y] != unit_a or _grid[pos_b.x][pos_b.y] != unit_b:
		return false
	# Swap grid entries
	_grid[pos_a.x][pos_a.y] = unit_b
	_grid[pos_b.x][pos_b.y] = unit_a
	# Update unit positions
	unit_a.grid_x = pos_b.x
	unit_a.grid_y = pos_b.y
	unit_b.grid_x = pos_a.x
	unit_b.grid_y = pos_a.y
	return true


## Get all tiles in the player spawn zone (cols 0-1).
func get_player_spawn_tiles() -> Array:
	var tiles: Array = []
	for col in PLAYER_SPAWN_COLS:
		for row in range(GRID_HEIGHT):
			tiles.append(Vector2i(col, row))
	return tiles


## Get the unit at a position, or null if empty/out of bounds.
func get_unit_at(pos: Vector2i) -> CombatUnit:
	if not is_in_bounds(pos):
		return null
	return _grid[pos.x][pos.y]


## Check if a tile is empty and in bounds.
func is_tile_empty(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return false
	return _grid[pos.x][pos.y] == null


## Check if a position is within grid bounds.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT


## Check if two positions are adjacent (Manhattan distance == 1).
func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return manhattan_distance(a, b) == 1


# ============================================================================
# DISTANCE & PATHFINDING
# ============================================================================

## Manhattan distance between two positions.
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Get all tiles reachable within a movement range using BFS.
## Cannot pass through enemy-occupied tiles. Can pass through ally tiles but not stop on them.
func get_reachable_tiles(from: Vector2i, move_range: int, mover_team: CombatUnit.Team = CombatUnit.Team.PLAYER) -> Array:
	var reachable: Array = []
	if not is_in_bounds(from):
		return reachable

	var visited: Dictionary = {}
	var queue: Array = []  # [Vector2i, distance]
	queue.append([from, 0])
	visited[from] = true

	while queue.size() > 0:
		var current = queue.pop_front()
		var pos: Vector2i = current[0]
		var dist: int = current[1]

		# Add to reachable if it's empty (not the starting tile)
		if pos != from and is_tile_empty(pos):
			reachable.append(pos)

		# Don't expand beyond move_range
		if dist >= move_range:
			continue

		for dir in DIRECTIONS:
			var neighbor: Vector2i = pos + dir
			if not is_in_bounds(neighbor):
				continue
			if visited.has(neighbor):
				continue

			# Check if neighbor is passable
			var occupant = _grid[neighbor.x][neighbor.y]
			if occupant != null:
				# Can pass through allies but enemy blocks movement
				if occupant.team != mover_team:
					visited[neighbor] = true
					continue  # Enemy blocks — mark visited but don't expand
				# Ally: can pass through but can't stop on them
				# Still expand through them
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])
			else:
				visited[neighbor] = true
				queue.append([neighbor, dist + 1])

	return reachable


## Find shortest path from one position to another using BFS.
## Returns array of positions (excluding 'from', including 'to').
## Returns empty array if no path exists.
func get_path(from: Vector2i, to: Vector2i, mover_team: CombatUnit.Team = CombatUnit.Team.PLAYER) -> Array:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	if from == to:
		return []

	var visited: Dictionary = {}
	var parent: Dictionary = {}  # pos -> parent pos
	var queue: Array = []
	queue.append(from)
	visited[from] = true

	while queue.size() > 0:
		var pos: Vector2i = queue.pop_front()

		if pos == to:
			# Reconstruct path
			var path: Array = []
			var current = to
			while current != from:
				path.push_front(current)
				current = parent[current]
			return path

		for dir in DIRECTIONS:
			var neighbor: Vector2i = pos + dir
			if not is_in_bounds(neighbor):
				continue
			if visited.has(neighbor):
				continue

			var occupant = _grid[neighbor.x][neighbor.y]
			if occupant != null and neighbor != to:
				# Can only pass through allies, enemies block
				if occupant.team != mover_team:
					visited[neighbor] = true
					continue
			# Ally-occupied or empty: passable
			visited[neighbor] = true
			parent[neighbor] = pos
			queue.append(neighbor)

	return []  # No path found


# ============================================================================
# RANGE QUERIES
# ============================================================================

## Get all units within a Manhattan distance range from origin.
## Filters by team if specified (null = all teams).
func get_targets_in_range(origin: Vector2i, min_range: int, max_range: int, team_filter = null) -> Array:
	var targets: Array = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var unit = _grid[x][y]
			if unit == null:
				continue
			if not unit.is_alive:
				continue
			var pos = Vector2i(x, y)
			var dist = manhattan_distance(origin, pos)
			if dist >= min_range and dist <= max_range:
				if team_filter == null or unit.team == team_filter:
					targets.append(unit)

	return targets


## Get all tiles within a Manhattan distance range from origin.
func get_tiles_in_range(origin: Vector2i, min_range: int, max_range: int) -> Array:
	var tiles: Array = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2i(x, y)
			var dist = manhattan_distance(origin, pos)
			if dist >= min_range and dist <= max_range:
				tiles.append(pos)

	return tiles


# ============================================================================
# AOE RESOLUTION
# ============================================================================

## Resolve a square AoE pattern centered on a tile.
## size=0 → 1x1 (just the center), size=1 → 3x3, size=2 → 5x5
## Returns array of in-bounds Vector2i positions.
func resolve_aoe_square(center: Vector2i, size: int) -> Array:
	var tiles: Array = []

	for dx in range(-size, size + 1):
		for dy in range(-size, size + 1):
			var pos = Vector2i(center.x + dx, center.y + dy)
			if is_in_bounds(pos):
				tiles.append(pos)

	return tiles


## Get all units hit by a square AoE.
## Optionally filter by team.
func get_units_in_aoe_square(center: Vector2i, size: int, team_filter = null) -> Array:
	var units: Array = []
	var tiles = resolve_aoe_square(center, size)

	for pos in tiles:
		var unit = _grid[pos.x][pos.y]
		if unit != null and unit.is_alive:
			if team_filter == null or unit.team == team_filter:
				units.append(unit)

	return units


# ============================================================================
# FORMATION ASSIGNMENT
# ============================================================================

## Assign spawn positions for both teams on the unified grid.
## Players go to cols 0-1, enemies go to cols 4-7.
## Melee/tank classes go to front columns, ranged/mage to back.
func assign_spawn_formation(player_units: Array, enemy_units: Array) -> void:
	_assign_player_spawn(player_units)
	_assign_enemy_spawn(enemy_units)


func _assign_player_spawn(units: Array) -> void:
	if units.is_empty():
		return

	var front_col: int = 1  # Player front = col 1 (closer to center)
	var back_col: int = 0   # Player back = col 0

	# Separate units into melee (front) and ranged/mage (back)
	var melee_units: Array = []
	var ranged_units: Array = []
	for unit in units:
		if unit.attack_type == "ranged" or unit.attack_type == "mage":
			ranged_units.append(unit)
		else:
			melee_units.append(unit)

	melee_units.sort_custom(func(a, b): return a.unit_id < b.unit_id)
	ranged_units.sort_custom(func(a, b): return a.unit_id < b.unit_id)

	# Place melee in front col, overflow to back col
	var row: int = 0
	for unit in melee_units:
		if row < GRID_HEIGHT:
			place_unit(unit, Vector2i(front_col, row))
			row += 1
		else:
			var overflow_row = row - GRID_HEIGHT
			if overflow_row < GRID_HEIGHT:
				place_unit(unit, Vector2i(back_col, overflow_row))
			row += 1

	# Place ranged in back col, overflow to front col
	row = 0
	for unit in ranged_units:
		while row < GRID_HEIGHT and _grid[back_col][row] != null:
			row += 1
		if row < GRID_HEIGHT:
			place_unit(unit, Vector2i(back_col, row))
			row += 1
		else:
			for fy in range(GRID_HEIGHT):
				if _grid[front_col][fy] == null:
					place_unit(unit, Vector2i(front_col, fy))
					break


## Assign enemy spawn across right half (cols 4-7).
## Melee prefer col 4 (closest to heroes), ranged/mage prefer col 5.
## Overflow spills to cols 6-7.
func _assign_enemy_spawn(units: Array) -> void:
	if units.is_empty():
		return

	var melee_units: Array = []
	var ranged_units: Array = []
	for unit in units:
		if unit.attack_type == "ranged" or unit.attack_type == "mage":
			ranged_units.append(unit)
		else:
			melee_units.append(unit)

	melee_units.sort_custom(func(a, b): return a.unit_id < b.unit_id)
	ranged_units.sort_custom(func(a, b): return a.unit_id < b.unit_id)

	# Enemy columns in priority order: front=4, second=5, overflow=6,7
	var melee_cols: Array = [4, 5, 6, 7]
	var ranged_cols: Array = [5, 4, 6, 7]

	# Place melee units — fill col 4 first (4 rows), then spill right
	for unit in melee_units:
		var placed = false
		for col in melee_cols:
			for row in range(GRID_HEIGHT):
				if _grid[col][row] == null:
					place_unit(unit, Vector2i(col, row))
					placed = true
					break
			if placed:
				break

	# Place ranged/mage units — fill col 5 first, then spill
	for unit in ranged_units:
		var placed = false
		for col in ranged_cols:
			for row in range(GRID_HEIGHT):
				if _grid[col][row] == null:
					place_unit(unit, Vector2i(col, row))
					placed = true
					break
			if placed:
				break


# ============================================================================
# QUERY HELPERS
# ============================================================================

## Get all occupied positions as an array of Vector2i.
func get_occupied_positions() -> Array:
	var positions: Array = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if _grid[x][y] != null:
				positions.append(Vector2i(x, y))
	return positions


## Get all units on the grid.
func get_all_units() -> Array:
	var units: Array = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if _grid[x][y] != null:
				units.append(_grid[x][y])
	return units


## Validate that no two units share the same position.
func validate_no_overlap() -> bool:
	var seen: Dictionary = {}
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var unit = _grid[x][y]
			if unit == null:
				continue
			var key = "%d_%d" % [x, y]
			if seen.has(key):
				push_error("[GridManager] Position overlap at %s: %s and %s" % [
					key, seen[key], unit.unit_id])
				return false
			seen[key] = unit.unit_id
	return true


# ============================================================================
# DEBUG
# ============================================================================

## Print grid layout to console for debugging.
func print_grid() -> void:
	print("\n[GridManager] Grid Layout (%dx%d):" % [GRID_WIDTH, GRID_HEIGHT])
	var header := "  "
	for x in range(GRID_WIDTH):
		header += "Col%d  " % x
	print(header)

	for y in range(GRID_HEIGHT):
		var row_str = "R%d " % y
		for x in range(GRID_WIDTH):
			var unit = _grid[x][y]
			if unit == null:
				row_str += "[    ] "
			else:
				var team_char = "P" if unit.team == CombatUnit.Team.PLAYER else "E"
				row_str += "[%s%s] " % [team_char, unit.display_name.left(3)]
		print(row_str)
