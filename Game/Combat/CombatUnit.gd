## CombatUnit.gd
## Runtime representation of a unit in combat.
## Holds stats, status tracking, and ability cooldowns.
##
## Source: MVP_Milestones.md (M1), GDD Section 23
class_name CombatUnit
extends RefCounted

# ============================================================================
# ENUMS
# ============================================================================

enum Team { PLAYER, ENEMY }

# ============================================================================
# IDENTITY
# ============================================================================

var unit_id: String = ""          # Unique ID for this combat instance
var source_id: String = ""        # Original data ID (hero_id or monster_id)
var display_name: String = ""
var team: Team = Team.PLAYER

# ============================================================================
# STATS (Runtime values)
# ============================================================================

var max_health: int = 100
var current_health: int = 100
var attack: int = 10
var defense: int = 5
var speed: int = 10

# ============================================================================
# COMBAT STATE
# ============================================================================

var is_alive: bool = true
var statuses: StatusRuntime = null

# Weapon ability
var weapon_ability_id: String = ""
var weapon_ability_cooldown: int = 0
var weapon_ability_max_cooldown: int = 3

# ============================================================================
# CLASS KIT (M4)
# ============================================================================

var class_id: String = ""

# Passive references (loaded from ClassData)
var passive_a_id: String = ""
var passive_b_id: String = ""

# Active ability references (loaded from ClassData)
var ability_a_id: String = ""
var ability_b_id: String = ""
var ability_a_cooldown: int = 0
var ability_b_cooldown: int = 0
var ability_a_max_cooldown: int = 0
var ability_b_max_cooldown: int = 0

# Position (M3 Grid System)
# NOTE: Player and Enemy each have their OWN 4x2 grid.
# player(0,0) and enemy(0,0) are on separate grids - no conflict.
var grid_x: int = -1  # -1 = unassigned
var grid_y: int = -1  # -1 = unassigned

# ============================================================================
# GRID POSITION (M3, M3.1)
# ============================================================================

## Set grid position.
func set_position(x: int, y: int) -> void:
	grid_x = x
	grid_y = y


## Get position as unique key string (e.g., "2_1").
## NOTE: This is team-local; use get_team_pos_key() for globally unique key.
func get_position_key() -> String:
	return "%d_%d" % [grid_x, grid_y]


## Get team-qualified position key (e.g., "player:0,0" or "enemy:1,0").
## This is globally unique across both grids.
func get_team_pos_key() -> String:
	var team_str = "player" if team == Team.PLAYER else "enemy"
	return "%s:%d,%d" % [team_str, grid_x, grid_y]


## Check if unit is in front row (y == 0).
func is_front_row() -> bool:
	return grid_y == 0


## Check if unit is in back row (y == 1).
func is_back_row() -> bool:
	return grid_y == 1


## Check if position is assigned.
func has_position() -> bool:
	return grid_x >= 0 and grid_y >= 0


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	statuses = StatusRuntime.new(unit_id)


## Create a player unit from hero data.
static func create_hero(hero_id: String, class_id_param: String, unit_index: int) -> CombatUnit:
	var unit = CombatUnit.new()
	unit.unit_id = "hero_%d" % unit_index
	unit.source_id = hero_id
	unit.class_id = class_id_param
	unit.team = Team.PLAYER

	# Try to load class data
	var class_data = DataRegistry.get_class_data(class_id_param)
	if class_data != null:
		unit.display_name = class_data.display_name
		unit.max_health = class_data.base_stats.get("health", 100)
		unit.attack = class_data.base_stats.get("attack", 10)
		unit.defense = class_data.base_stats.get("defense", 5)
		unit.speed = class_data.base_stats.get("speed", 10)

		# M4: Load class kit (passives and abilities)
		unit.passive_a_id = class_data.passive_a_id
		unit.passive_b_id = class_data.passive_b_id
		unit.ability_a_id = class_data.ability_a_id
		unit.ability_b_id = class_data.ability_b_id

		# Load ability cooldowns from AbilityData
		var ability_a = DataRegistry.get_ability(unit.ability_a_id)
		if ability_a != null:
			unit.ability_a_max_cooldown = ability_a.cooldown
		var ability_b = DataRegistry.get_ability(unit.ability_b_id)
		if ability_b != null:
			unit.ability_b_max_cooldown = ability_b.cooldown

		print("[CombatUnit] Loaded class kit: passives=[%s, %s] abilities=[%s (cd:%d), %s (cd:%d)]" % [
			unit.passive_a_id, unit.passive_b_id,
			unit.ability_a_id, unit.ability_a_max_cooldown,
			unit.ability_b_id, unit.ability_b_max_cooldown])
	else:
		# Placeholder stats if class not found
		unit.display_name = "Hero %d" % unit_index
		unit.max_health = 80
		unit.attack = 12
		unit.defense = 8
		unit.speed = 10

	unit.current_health = unit.max_health
	unit.statuses = StatusRuntime.new(unit.unit_id)

	# Set up weapon ability (placeholder)
	unit.weapon_ability_id = "weapon_sword_strike"
	unit.weapon_ability_max_cooldown = 3

	print("[CombatUnit] Created hero: %s (HP:%d ATK:%d DEF:%d SPD:%d)" % [
		unit.display_name, unit.max_health, unit.attack, unit.defense, unit.speed])

	return unit


## Create an enemy unit from monster data.
static func create_monster(monster_id: String, unit_index: int) -> CombatUnit:
	var unit = CombatUnit.new()
	unit.unit_id = "enemy_%d" % unit_index
	unit.source_id = monster_id
	unit.team = Team.ENEMY

	# Try to load monster data
	var monster_data = DataRegistry.get_monster(monster_id)
	if monster_data != null:
		unit.display_name = monster_data.display_name
		unit.max_health = monster_data.base_stats.get("health", 30)
		unit.attack = monster_data.base_stats.get("attack", 6)
		unit.defense = monster_data.base_stats.get("defense", 2)
		unit.speed = monster_data.base_stats.get("speed", 10)
	else:
		# Placeholder stats if monster not found
		unit.display_name = "Monster %d" % unit_index
		unit.max_health = 25
		unit.attack = 5
		unit.defense = 2
		unit.speed = 8

	unit.current_health = unit.max_health
	unit.statuses = StatusRuntime.new(unit.unit_id)

	print("[CombatUnit] Created monster: %s (HP:%d ATK:%d DEF:%d SPD:%d)" % [
		unit.display_name, unit.max_health, unit.attack, unit.defense, unit.speed])

	return unit


# ============================================================================
# COMBAT ACTIONS
# ============================================================================

## Take damage. Returns actual damage dealt.
func take_damage(raw_damage: int, damage_type: String = "physical") -> int:
	if not is_alive:
		return 0

	# Apply defense reduction for physical damage
	var actual_damage = raw_damage
	if damage_type == "physical":
		actual_damage = maxi(1, raw_damage - defense)

	current_health -= actual_damage
	print("[CombatUnit] %s takes %d damage (raw: %d). HP: %d/%d" % [
		display_name, actual_damage, raw_damage, current_health, max_health])

	if current_health <= 0:
		current_health = 0
		is_alive = false
		print("[CombatUnit] %s has been defeated!" % display_name)

	return actual_damage


## Heal the unit. Returns actual healing done.
func heal(amount: int) -> int:
	if not is_alive:
		return 0

	var old_health = current_health
	current_health = mini(current_health + amount, max_health)
	var actual_heal = current_health - old_health

	if actual_heal > 0:
		print("[CombatUnit] %s healed for %d. HP: %d/%d" % [
			display_name, actual_heal, current_health, max_health])

	return actual_heal


## Check if weapon ability is ready (off cooldown).
func is_weapon_ability_ready() -> bool:
	return weapon_ability_cooldown <= 0 and weapon_ability_id != ""


## Use weapon ability (put on cooldown).
func use_weapon_ability() -> void:
	weapon_ability_cooldown = weapon_ability_max_cooldown
	print("[CombatUnit] %s used weapon ability. Cooldown: %d" % [display_name, weapon_ability_cooldown])


# ============================================================================
# CLASS ABILITY HELPERS (M4)
# ============================================================================

## Check if class ability A is ready (off cooldown).
func is_ability_a_ready() -> bool:
	return ability_a_cooldown <= 0 and ability_a_id != ""


## Check if class ability B is ready (off cooldown).
func is_ability_b_ready() -> bool:
	return ability_b_cooldown <= 0 and ability_b_id != ""


## Use class ability A (put on cooldown).
func use_ability_a() -> void:
	ability_a_cooldown = ability_a_max_cooldown
	print("[CombatUnit] %s used ability A (%s). Cooldown: %d" % [display_name, ability_a_id, ability_a_cooldown])


## Use class ability B (put on cooldown).
func use_ability_b() -> void:
	ability_b_cooldown = ability_b_max_cooldown
	print("[CombatUnit] %s used ability B (%s). Cooldown: %d" % [display_name, ability_b_id, ability_b_cooldown])


## Reduce weapon cooldown by amount (for on_kill passive effects).
func reduce_weapon_cooldown(amount: int) -> void:
	weapon_ability_cooldown = maxi(0, weapon_ability_cooldown - amount)
	print("[CombatUnit] %s weapon cooldown reduced by %d. Now: %d" % [display_name, amount, weapon_ability_cooldown])


## Tick cooldowns at end of turn.
func tick_cooldowns() -> void:
	if weapon_ability_cooldown > 0:
		weapon_ability_cooldown -= 1
	if ability_a_cooldown > 0:
		ability_a_cooldown -= 1
	if ability_b_cooldown > 0:
		ability_b_cooldown -= 1


## Get initiative value for turn ordering.
func get_initiative() -> int:
	return speed


# ============================================================================
# STATUS HELPERS
# ============================================================================

func is_stunned() -> bool:
	return statuses.is_stunned()


func apply_stun(duration: int, source_id: String = "") -> bool:
	return statuses.apply_stun(duration, source_id)


func apply_doom(stacks: int, max_stacks: int, source_id: String = "") -> int:
	return statuses.apply_doom(stacks, max_stacks, source_id)


# ============================================================================
# DEBUG
# ============================================================================

func get_status_string() -> String:
	var status_str = statuses.get_summary()
	var cooldown_parts = []
	if weapon_ability_cooldown > 0:
		cooldown_parts.append("Wpn:%d" % weapon_ability_cooldown)
	if ability_a_cooldown > 0:
		cooldown_parts.append("A:%d" % ability_a_cooldown)
	if ability_b_cooldown > 0:
		cooldown_parts.append("B:%d" % ability_b_cooldown)
	var cooldown_str = ""
	if cooldown_parts.size() > 0:
		cooldown_str = " [CD:" + ",".join(cooldown_parts) + "]"
	return "[%s] HP:%d/%d %s%s" % [display_name, current_health, max_health, status_str, cooldown_str]


func get_summary() -> Dictionary:
	return {
		"unit_id": unit_id,
		"display_name": display_name,
		"team": "PLAYER" if team == Team.PLAYER else "ENEMY",
		"class_id": class_id,
		"current_health": current_health,
		"max_health": max_health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"is_alive": is_alive,
		"statuses": statuses.get_summary(),
		"weapon_cooldown": weapon_ability_cooldown,
		"ability_a_cooldown": ability_a_cooldown,
		"ability_b_cooldown": ability_b_cooldown,
		"passive_a_id": passive_a_id,
		"passive_b_id": passive_b_id
	}
