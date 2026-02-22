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

# Per-region speed multiplier for monsters (40 SPD = 2 actions, 80 SPD = 3 actions)
const MONSTER_SPEED_SCALE: Dictionary = {
	1: 1.0,   # R1: SPD 10-20 → 10-20  (all 1 action)
	2: 1.0,   # R2: SPD 13-24 → 13-24  (all 1 action)
	3: 1.5,   # R3: SPD 16-30 → 24-45  (bosses 42-45 = 2 actions)
	4: 1.6,   # R4: SPD 20-38 → 32-61  (bosses 56-61 = 2 actions)
	5: 1.6,   # R5: SPD 23-45 → 37-72  (bosses 67-72 = 2 actions)
	6: 1.6,   # R6: SPD 27-55 → 43-88  (bosses 80-88 = 3 actions)
	7: 1.6,   # R7: SPD 32-60 → 51-96  (bosses 88-96 = 3 actions)
}

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

# Attack range type ("melee" or "ranged") — used by TargetingPolicy for row targeting
var attack_type: String = "melee"

# AI behavior tier (0=Feral, 1=Basic, 2=Tactical, 3=Strategic) — from MonsterData
var ai_tier: int = 0

# Weapon ability
var weapon_ability_id: String = ""
var weapon_ability_cooldown: int = 0
var weapon_ability_max_cooldown: int = 3

# Equipment abilities (T4 gear, max 2)
var equip_ability_ids: Array = []  # Array of ability_id strings
var equip_ability_cooldowns: Array = []  # Current cooldown per slot
var equip_ability_max_cooldowns: Array = []  # Max cooldown per slot

# ============================================================================
# CLASS KIT (M4)
# ============================================================================

var class_id: String = ""
var race_id: String = ""  # Hero race for race passive lookup
var hero_level: int = 1  # Hero level for passive scaling

# Passive references (loaded from ClassData)
var passive_a_id: String = ""
var passive_b_id: String = ""

# Passive runtime state (for stacking effects)
var killer_instinct_stacks: int = 0  # Tracks on-kill ATK buff stacks

# ============================================================================
# TEMPORARY BUFF TRACKING (Ability Execution v1 Hardening)
# ============================================================================
# Buffs are stored as: { "source": ability_id, "stats": {attack, defense, speed}, "remaining_rounds": int }
var active_buffs: Array = []

# ============================================================================
# STATUS HOOKS v1 - Minimal status effect lifecycle
# ============================================================================
# Statuses are stored as: { "id": status_id, "remaining_rounds": int, "source": ability_or_source_id }
# Reserved ID: "stunned" - blocks unit action for turn
var active_statuses: Array = []

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


## Check if unit is in middle row (y == 1). (3-Row Formation v1)
func is_middle_row() -> bool:
	return grid_y == 1


## Check if unit is in back row (y == 2). (3-Row Formation v1)
func is_back_row() -> bool:
	return grid_y == 2


## Check if position is assigned.
func has_position() -> bool:
	return grid_x >= 0 and grid_y >= 0


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init() -> void:
	statuses = StatusRuntime.new(unit_id)


## Helper to safely get DataRegistry autoload (avoids compile-time dependency).
static func _get_registry():
	var main_loop = Engine.get_main_loop() as SceneTree
	if main_loop and main_loop.root:
		return main_loop.root.get_node_or_null("DataRegistry")
	return null


## Create a player unit from hero data.
## If effective_stats dict is provided (from GameContext.get_hero_effective_stats()),
## use those level-scaled + race-modified stats instead of base class stats.
static func create_hero(hero_id: String, class_id_param: String, unit_index: int, effective_stats: Dictionary = {}) -> CombatUnit:
	var unit = CombatUnit.new()
	unit.unit_id = "hero_%d" % unit_index
	unit.source_id = hero_id
	unit.class_id = class_id_param
	unit.team = Team.PLAYER

	# Try to load class data for abilities/passives (use helper for safe access)
	var registry = _get_registry()
	var class_data = registry.get_class_data(class_id_param) if registry else null

	# Use effective stats if provided (level-scaled + race modifiers)
	if not effective_stats.is_empty():
		unit.display_name = effective_stats.get("name", "Hero %d" % unit_index)
		unit.max_health = int(effective_stats.get("health", 80))
		unit.attack = int(effective_stats.get("attack", 12))
		unit.defense = int(effective_stats.get("defense", 8))
		unit.speed = int(effective_stats.get("speed", 10))
		unit.hero_level = int(effective_stats.get("level", 1))
		unit.race_id = effective_stats.get("race_id", "human")

		# M4: Load class kit (passives and abilities) from class data
		if class_data != null:
			unit.passive_a_id = class_data.passive_a_id
			unit.passive_b_id = class_data.passive_b_id
			unit.ability_a_id = class_data.ability_a_id
			unit.ability_b_id = class_data.ability_b_id

			# Load ability cooldowns from AbilityData
			if registry:
				var ability_a = registry.get_ability(unit.ability_a_id)
				if ability_a != null:
					unit.ability_a_max_cooldown = ability_a.cooldown
				var ability_b = registry.get_ability(unit.ability_b_id)
				if ability_b != null:
					unit.ability_b_max_cooldown = ability_b.cooldown
	elif class_data != null:
		# Legacy fallback: use base class stats (no level scaling)
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
		if registry:
			var ability_a = registry.get_ability(unit.ability_a_id)
			if ability_a != null:
				unit.ability_a_max_cooldown = ability_a.cooldown
			var ability_b = registry.get_ability(unit.ability_b_id)
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

	# T4 equipment abilities: load from effective_stats if provided
	var equip_ids = effective_stats.get("equip_ability_ids", [])
	if equip_ids is Array and equip_ids.size() > 0:
		for ea_id in equip_ids:
			unit.equip_ability_ids.append(str(ea_id))
			var ea_data = registry.get_ability(str(ea_id)) if registry else null
			var ea_cd: int = ea_data.cooldown if ea_data != null else 3
			unit.equip_ability_cooldowns.append(0)
			unit.equip_ability_max_cooldowns.append(ea_cd)
		print("[CombatUnit] Equipment abilities: %s" % str(unit.equip_ability_ids))

	print("[CombatUnit] Created hero: %s (HP:%d ATK:%d DEF:%d SPD:%d)" % [
		unit.display_name, unit.max_health, unit.attack, unit.defense, unit.speed])

	return unit


## Create an enemy unit from monster data.
static func create_monster(monster_id: String, unit_index: int) -> CombatUnit:
	var unit = CombatUnit.new()
	unit.unit_id = "enemy_%d" % unit_index
	unit.source_id = monster_id
	unit.team = Team.ENEMY

	# Try to load monster data (use helper for safe access)
	var registry = _get_registry()
	var monster_data = registry.get_monster(monster_id) if registry else null
	if monster_data != null:
		unit.display_name = monster_data.display_name
		unit.max_health = monster_data.base_stats.get("health", 30)
		unit.attack = monster_data.base_stats.get("attack", 6)
		unit.defense = monster_data.base_stats.get("defense", 2)
		unit.speed = monster_data.base_stats.get("speed", 10)
		unit.attack_type = monster_data.attack_type
		unit.ai_tier = monster_data.ai_tier
	else:
		# Placeholder stats if monster not found
		unit.display_name = "Monster %d" % unit_index
		unit.max_health = 25
		unit.attack = 5
		unit.defense = 2
		unit.speed = 8

	# Apply challenge level scaling (session-only playtest tool)
	var _gc = Engine.get_main_loop().root.get_node_or_null("GameContext") if Engine.get_main_loop() else null
	if _gc and _gc.challenge_level > 0:
		unit.max_health = int(unit.max_health * _gc.get_hp_multiplier())
		unit.attack = int(unit.attack * _gc.get_damage_multiplier())

	# Apply region-based monster speed scaling
	if _gc:
		var region: int = _gc.current_region
		var scale: float = MONSTER_SPEED_SCALE.get(region, 1.0)
		if scale != 1.0:
			unit.speed = int(unit.speed * scale)

	unit.current_health = unit.max_health
	unit.statuses = StatusRuntime.new(unit.unit_id)

	var _cl: int = _gc.challenge_level if _gc else 0
	print("[CombatUnit] Created monster: %s (HP:%d ATK:%d DEF:%d SPD:%d CL:%d)" % [
		unit.display_name, unit.max_health, unit.attack, unit.defense, unit.speed, _cl])

	return unit


# ============================================================================
# COMBAT ACTIONS
# ============================================================================

## Apply defense soft-cap: full value up to 20, half from 21-40, 20% above 40.
## Prevents high-DEF units from becoming immune to physical damage.
static func get_soft_capped_defense(raw_def: int) -> int:
	if raw_def <= 20:
		return raw_def
	elif raw_def <= 40:
		return 20 + int((raw_def - 20) * 0.5)
	else:
		return 30 + int((raw_def - 40) * 0.2)


## Take damage. Returns actual damage dealt.
## Uses effective defense (base + buff bonuses) with soft-cap for damage reduction.
func take_damage(raw_damage: int, damage_type: String = "physical") -> int:
	if not is_alive:
		return 0

	# Apply defense reduction for physical damage (soft-capped effective defense)
	var actual_damage = raw_damage
	if damage_type == "physical":
		var eff_def = get_soft_capped_defense(get_effective_defense())
		actual_damage = maxi(1, raw_damage - eff_def)

	current_health -= actual_damage
	print("[CombatUnit] %s takes %d damage (raw: %d, eff_def: %d). HP: %d/%d" % [
		display_name, actual_damage, raw_damage, get_effective_defense(), current_health, max_health])

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


## Check if equipment ability at given index is ready (off cooldown).
func is_equip_ability_ready(index: int) -> bool:
	if index < 0 or index >= equip_ability_ids.size():
		return false
	return equip_ability_cooldowns[index] <= 0 and equip_ability_ids[index] != ""


## Use equipment ability at given index (put on cooldown).
func use_equip_ability(index: int) -> void:
	if index < 0 or index >= equip_ability_ids.size():
		return
	equip_ability_cooldowns[index] = equip_ability_max_cooldowns[index]
	print("[CombatUnit] %s used equip ability %d (%s). Cooldown: %d" % [
		display_name, index, equip_ability_ids[index], equip_ability_cooldowns[index]])


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
	for idx in range(equip_ability_cooldowns.size()):
		if equip_ability_cooldowns[idx] > 0:
			equip_ability_cooldowns[idx] -= 1


## Get initiative value for turn ordering (uses effective speed including buffs).
func get_initiative() -> int:
	return get_effective_speed()


# ============================================================================
# TEMPORARY BUFF MANAGEMENT
# ============================================================================

## Apply a temporary buff from an ability.
## Returns the buff entry that was added.
func apply_buff(ability_id: String, stats: Dictionary, duration: int) -> Dictionary:
	var buff_entry = {
		"source": ability_id,
		"stats": stats.duplicate(),
		"remaining_rounds": duration
	}
	active_buffs.append(buff_entry)
	print("[Buff] applied unit=%s source=%s stats=%s duration=%d" % [
		display_name, ability_id, JSON.stringify(stats), duration])
	return buff_entry


## Tick all buffs (decrement remaining_rounds) and remove expired ones.
## Called at round start. Returns array of expired buff sources.
func tick_buffs() -> Array:
	var expired: Array = []
	var remaining: Array = []

	for buff in active_buffs:
		buff["remaining_rounds"] -= 1
		if buff["remaining_rounds"] <= 0:
			expired.append(buff["source"])
			print("[Buff] expired unit=%s source=%s" % [display_name, buff["source"]])
		else:
			print("[Buff] tick unit=%s source=%s remaining=%d" % [
				display_name, buff["source"], buff["remaining_rounds"]])
			remaining.append(buff)

	active_buffs = remaining
	return expired


## Get effective attack (base + buff bonuses).
func get_effective_attack() -> int:
	var total = attack
	for buff in active_buffs:
		total += int(buff["stats"].get("attack", 0))
	return total


## Get effective defense (base + buff bonuses).
func get_effective_defense() -> int:
	var total = defense
	for buff in active_buffs:
		total += int(buff["stats"].get("defense", 0))
	return total


## Get effective speed (base + buff bonuses).
func get_effective_speed() -> int:
	var total = speed
	for buff in active_buffs:
		total += int(buff["stats"].get("speed", 0))
	return total


## Check if unit has any active buffs.
func has_active_buffs() -> bool:
	return active_buffs.size() > 0


## Get buff bonus for a specific stat.
func get_buff_bonus(stat: String) -> int:
	var total = 0
	for buff in active_buffs:
		total += int(buff["stats"].get(stat, 0))
	return total


# ============================================================================
# BUFF SNAPSHOT API (Status UI v1.7)
# ============================================================================

## Returns Array of buff snapshots for UI display (Status UI v1.7, v1.7.1).
## Each entry: { "source", "ui_name", "ui_short", "ui_icon", "stats", "remaining_rounds", "buff_tags" }
func get_buff_snapshot() -> Array:
	var result: Array = []
	var registry = _get_registry()

	for buff in active_buffs:
		var source = buff.get("source", "unknown")
		var stats = buff.get("stats", {})
		var remaining = buff.get("remaining_rounds", 0)

		# Derive UI metadata from AbilityData or PassiveData if available
		var ui_name = source.capitalize()  # Fallback
		var ui_short = _derive_buff_ui_short(stats)  # Derive from stats
		var ui_icon = ""  # Optional, default empty
		var buff_tags: Array = []  # v1.7.1: For tag-driven sorting

		if registry:
			# Check if this is a passive buff (source starts with "passive_")
			if source.begins_with("passive_"):
				var passive_id = source.substr(8)  # Remove "passive_" prefix
				var passive_data = registry.get_passive(passive_id)
				if passive_data:
					if passive_data.display_name != "":
						ui_name = passive_data.display_name
					ui_short = "PASS"  # Short label for passives
					buff_tags = ["passive"]
			else:
				# Try to get ability data
				var ability_data = registry.get_ability(source)
				if ability_data:
					# Use display_name if available
					if ability_data.display_name != "":
						ui_name = ability_data.display_name
					# Use ui_* fields from AbilityData if available (v1.7)
					if "ui_name" in ability_data and ability_data.ui_name != "":
						ui_name = ability_data.ui_name
					if "ui_short" in ability_data and ability_data.ui_short != "":
						ui_short = ability_data.ui_short
					if "ui_icon" in ability_data and ability_data.ui_icon != "":
						ui_icon = ability_data.ui_icon
					# v1.7.1: Include buff_tags for sorting
					if "buff_tags" in ability_data and ability_data.buff_tags.size() > 0:
						buff_tags = ability_data.buff_tags.duplicate()

		result.append({
			"source": source,
			"ui_name": ui_name,
			"ui_short": ui_short,
			"ui_icon": ui_icon,
			"stats": stats.duplicate(),
			"remaining_rounds": remaining,
			"buff_tags": buff_tags
		})

	return result


## Returns sorted buff snapshot for UI badges (Status UI v1.7, v1.7.1).
## Ordering: tag priority ASC (defense first), remaining_rounds DESC, ui_short ASC, source ASC.
func get_buff_snapshot_sorted() -> Array:
	var snapshot = get_buff_snapshot()
	if snapshot.size() <= 1:
		return snapshot

	# Sort using custom comparator
	snapshot.sort_custom(_compare_buff_for_display)
	return snapshot


## Comparator for buff display ordering (Status UI v1.7.1).
## Primary: Tag priority ASC (defense=0 > offense=1 > utility=2 > misc=3).
## Secondary: remaining_rounds DESC (longer buffs first).
## Tertiary: ui_short ASC.
## Quaternary: source ASC.
static func _compare_buff_for_display(a: Dictionary, b: Dictionary) -> bool:
	# v1.7.1: Primary sort by tag priority
	var priority_a = _get_buff_display_priority(a.get("buff_tags", []))
	var priority_b = _get_buff_display_priority(b.get("buff_tags", []))

	if priority_a != priority_b:
		return priority_a < priority_b  # Lower priority value = higher display priority

	# Secondary: remaining_rounds DESC
	var remaining_a = a.get("remaining_rounds", 0)
	var remaining_b = b.get("remaining_rounds", 0)

	if remaining_a != remaining_b:
		return remaining_a > remaining_b  # DESC: longer first

	# Tertiary: ui_short ASC
	var short_a = a.get("ui_short", "")
	var short_b = b.get("ui_short", "")

	if short_a != short_b:
		return short_a < short_b  # ASC

	# Quaternary: source ASC
	return a.get("source", "") < b.get("source", "")


## Get display priority based on buff_tags (Status UI v1.7.1).
## Priority: defense=0, offense=1, utility=2, misc=3 (unknown/empty).
## Returns lowest priority found in tags (most important tag wins).
static func _get_buff_display_priority(tags: Array) -> int:
	var best_priority = 3  # Default to misc (lowest priority)

	for tag in tags:
		match tag:
			"defense":
				return 0  # Defense is highest priority, return immediately
			"offense":
				best_priority = mini(best_priority, 1)
			"utility":
				best_priority = mini(best_priority, 2)
			# Unknown tags stay at default 3 (misc)

	return best_priority


## Derive ui_short from buff stats (Status UI v1.7).
## Single stat: "ATK+", "DEF+", "SPD+". Multi-stat: "BUFF".
static func _derive_buff_ui_short(stats: Dictionary) -> String:
	if stats.size() == 1:
		if stats.has("attack"):
			return "ATK+"
		if stats.has("defense"):
			return "DEF+"
		if stats.has("speed"):
			return "SPD+"
	# Multi-stat or unrecognized: generic BUFF
	return "BUFF"


# ============================================================================
# STATUS HOOKS v1 - Lifecycle methods
# ============================================================================

## Apply a status effect to this unit (Status v1.4 with stacking).
## Supports stacking_mode: "refresh" (duration only) or "intensity" (stacks increase).
## Duration passed should be internal_duration (already has +1 applied).
func apply_status_v1(status_id: String, duration_rounds: int, source: String = "") -> void:
	# Look up status data for stacking rules
	var registry = _get_registry()
	var status_data = registry.get_status_effect(status_id) if registry else null
	var stacking_mode = status_data.stacking_mode if status_data else "refresh"
	var max_stacks = status_data.max_stacks if status_data else 1


	# Check if status already exists
	for status in active_statuses:
		if status["id"] == status_id:
			var old_stacks = status.get("stacks", 1)

			if stacking_mode == "intensity":
				# Intensity stacking: increase stacks up to max, refresh duration
				var new_stacks = mini(old_stacks + 1, max_stacks)
				status["stacks"] = new_stacks
				status["remaining_rounds"] = duration_rounds
				print("[Status] stack unit=%s id=%s old_stacks=%d new_stacks=%d duration=%d source=%s" % [
					display_name, status_id, old_stacks, new_stacks, duration_rounds, source])
			else:
				# Refresh stacking: keep stacks, refresh duration if longer
				status["remaining_rounds"] = maxi(status["remaining_rounds"], duration_rounds)
				print("[Status] refresh unit=%s id=%s stacks=%d duration=%d source=%s" % [
					display_name, status_id, old_stacks, duration_rounds, source])
			return

	# Add new status with stacks=1
	var status_entry = {
		"id": status_id,
		"remaining_rounds": duration_rounds,
		"source": source,
		"stacks": 1
	}
	active_statuses.append(status_entry)
	print("[Status] applied unit=%s id=%s duration=%d stacks=1 source=%s" % [
		display_name, status_id, duration_rounds, source])


## Apply a HOT (heal-over-time) status with a custom per-tick heal value (Status v1.5).
## Used by consumable potions where heal_per_tick varies by item tier/region.
## Stacking follows the same rules as apply_status_v1().
func apply_hot_v1(status_id: String, duration_rounds: int, heal_per_tick: int, source: String = "") -> void:
	var registry = _get_registry()
	var status_data = registry.get_status_effect(status_id) if registry else null
	var stacking_mode: String = status_data.stacking_mode if status_data else "refresh"
	var max_stacks: int = status_data.max_stacks if status_data else 1

	for status in active_statuses:
		if status["id"] == status_id:
			var old_stacks = status.get("stacks", 1)
			if stacking_mode == "intensity":
				var new_stacks = mini(old_stacks + 1, max_stacks)
				status["stacks"] = new_stacks
				status["remaining_rounds"] = duration_rounds
				status["heal_per_tick"] = maxi(status.get("heal_per_tick", 0), heal_per_tick)
				print("[Status] hot_stack unit=%s id=%s old_stacks=%d new_stacks=%d hpt=%d duration=%d source=%s" % [
					display_name, status_id, old_stacks, new_stacks, status["heal_per_tick"], duration_rounds, source])
			else:
				status["remaining_rounds"] = maxi(status["remaining_rounds"], duration_rounds)
				status["heal_per_tick"] = maxi(status.get("heal_per_tick", 0), heal_per_tick)
				print("[Status] hot_refresh unit=%s id=%s stacks=%d hpt=%d duration=%d source=%s" % [
					display_name, status_id, old_stacks, status["heal_per_tick"], duration_rounds, source])
			return

	var status_entry = {
		"id": status_id,
		"remaining_rounds": duration_rounds,
		"source": source,
		"stacks": 1,
		"heal_per_tick": heal_per_tick
	}
	active_statuses.append(status_entry)
	print("[Status] hot_applied unit=%s id=%s duration=%d hpt=%d stacks=1 source=%s" % [
		display_name, status_id, duration_rounds, heal_per_tick, source])


## Tick all statuses (decrement remaining_rounds) and remove expired ones.
## Called at round start after buff ticking. Returns array of expired status IDs.
## DOT damage scales with stacks (Status v1.4): dmg = base_value + value_per_stack * (stacks - 1)
## HOT healing (Status v1.5): heals HP per tick for statuses with "healing" tag.
func tick_statuses() -> Array:
	var expired: Array = []
	var remaining: Array = []

	# Get registry for DOT/HOT lookup (if available)
	var registry = _get_registry()

	for status in active_statuses:
		var status_id = status["id"]
		var stacks = status.get("stacks", 1)
		var hp_before = current_health
		var dot_dmg = 0
		var hot_heal = 0

		if registry and is_alive:
			var status_data = registry.get_status_effect(status_id)
			if status_data:
				# Check for DOT damage (Status v1.4: scale with stacks)
				if status_data.category == "dot":
					dot_dmg = status_data.base_value + status_data.value_per_stack * (stacks - 1)
					if dot_dmg > 0:
						current_health -= dot_dmg
						if current_health <= 0:
							current_health = 0
							is_alive = false
				# Check for HOT healing (Status v1.5: regenerating/healing statuses)
				elif status_data.tags is Array and "healing" in status_data.tags:
					var hpt: int = status.get("heal_per_tick", 0)
					if hpt == 0:
						# Fallback: standard formula from status data
						hpt = status_data.base_value + status_data.value_per_stack * (stacks - 1)
					if hpt > 0 and current_health < max_health:
						current_health = mini(current_health + hpt, max_health)
						hot_heal = current_health - hp_before

		# Decrement duration
		status["remaining_rounds"] -= 1

		if status["remaining_rounds"] <= 0:
			# Status expires this tick
			expired.append(status_id)
			if dot_dmg > 0:
				print("[Status] tick unit=%s id=%s stacks=%d dmg=%d hp_before=%d hp_after=%d remaining=0" % [
					display_name, status_id, stacks, dot_dmg, hp_before, current_health])
			elif hot_heal > 0:
				print("[Status] tick unit=%s id=%s stacks=%d heal=%d hp_before=%d hp_after=%d remaining=0" % [
					display_name, status_id, stacks, hot_heal, hp_before, current_health])
			print("[Status] expired unit=%s id=%s stacks=%d" % [display_name, status_id, stacks])
		else:
			# Status continues
			if dot_dmg > 0:
				print("[Status] tick unit=%s id=%s stacks=%d dmg=%d hp_before=%d hp_after=%d remaining=%d" % [
					display_name, status_id, stacks, dot_dmg, hp_before, current_health, status["remaining_rounds"]])
			elif hot_heal > 0:
				print("[Status] tick unit=%s id=%s stacks=%d heal=%d hp_before=%d hp_after=%d remaining=%d" % [
					display_name, status_id, stacks, hot_heal, hp_before, current_health, status["remaining_rounds"]])
			else:
				print("[Status] tick unit=%s id=%s stacks=%d remaining=%d" % [
					display_name, status_id, stacks, status["remaining_rounds"]])
			remaining.append(status)

		# Handle death from DOT
		if not is_alive:
			print("[CombatUnit] %s has been defeated by %s!" % [display_name, status_id])

	active_statuses = remaining
	return expired


## Check if unit has a specific status effect (Status Hooks v1).
func has_status_v1(status_id: String) -> bool:
	for status in active_statuses:
		if status["id"] == status_id:
			return true
	return false


## Check if unit is blocked from acting by "stunned" status (Status Hooks v1).
## Returns true if unit should skip their turn.
func is_action_blocked_by_status() -> bool:
	if has_status_v1("stunned"):
		print("[Status] blocked unit=%s id=stunned action_skipped=true" % display_name)
		return true
	return false


## Clear all status effects (Status Hooks v1).
func clear_statuses_v1() -> void:
	active_statuses.clear()
	print("[Status] cleared unit=%s" % display_name)


## Returns Array of status snapshots for UI display (Status v1.5, v1.6, v1.6.3).
## Each entry: { "id", "ui_short", "ui_name", "ui_icon", "stacks", "remaining_rounds", "tags" }
func get_status_snapshot() -> Array:
	var result: Array = []
	var registry = _get_registry()

	for status in active_statuses:
		var status_id = status["id"]
		var stacks = status.get("stacks", 1)
		var remaining = status.get("remaining_rounds", 0)

		# Lookup UI metadata and tags from registry
		var ui_short = status_id.to_upper().substr(0, 3)  # Fallback: first 3 chars
		var ui_name = ""  # v1.6.3: For tooltips
		var ui_icon = ""  # v1.6.3: For optional icons
		var tags: Array = []
		if registry:
			var status_data = registry.get_status_effect(status_id)
			if status_data:
				if status_data.ui_short != "":
					ui_short = status_data.ui_short
				ui_name = status_data.ui_name
				ui_icon = status_data.ui_icon
				tags = status_data.tags.duplicate()

		result.append({
			"id": status_id,
			"ui_short": ui_short,
			"ui_name": ui_name,
			"ui_icon": ui_icon,
			"stacks": stacks,
			"remaining_rounds": remaining,
			"tags": tags
		})

	return result


## Returns sorted status snapshot for UI badges (Status v1.6).
## Ordering: control first, then dot, then others. Within group: sort by id.
func get_status_snapshot_sorted() -> Array:
	var snapshot = get_status_snapshot()
	if snapshot.size() <= 1:
		return snapshot

	# Sort using custom comparator
	snapshot.sort_custom(_compare_status_for_display)
	return snapshot


## Comparator for status display ordering (Status v1.6).
## Priority: control (0), dot (1), other (2). Then by id alphabetically.
static func _compare_status_for_display(a: Dictionary, b: Dictionary) -> bool:
	var priority_a = _get_status_display_priority(a.get("tags", []))
	var priority_b = _get_status_display_priority(b.get("tags", []))

	if priority_a != priority_b:
		return priority_a < priority_b

	# Same priority: sort by id alphabetically
	return a.get("id", "") < b.get("id", "")


## Get display priority based on tags: control=0, dot=1, other=2.
static func _get_status_display_priority(tags: Array) -> int:
	for tag in tags:
		if tag == "control":
			return 0
	for tag in tags:
		if tag == "dot":
			return 1
	return 2


# ============================================================================
# STATUS RESIST/IMMUNITY (Status v1.3)
# ============================================================================

## Get trait tags from this unit's race data.
## Returns empty array if race not found or unit has no race.
func get_trait_tags() -> Array:
	if race_id == "":
		return []
	var registry = _get_registry()
	if not registry:
		return []
	var race_data = registry.get_race(race_id)
	if not race_data:
		return []
	return race_data.trait_tags


## Check if this unit would block or resist a status effect.
## Returns: { "blocked": bool, "reason": String, "duration_delta": int }
## - blocked: true if status should not be applied at all
## - reason: trait tag that caused block/resist (e.g., "immune_poison", "resist_bleed")
## - duration_delta: negative value to reduce duration (e.g., -1 for resist)
func would_block_status(status_id: String) -> Dictionary:
	var result = { "blocked": false, "reason": "", "duration_delta": 0 }

	# Get status data for tags
	var registry = _get_registry()
	if not registry:
		return result
	var status_data = registry.get_status_effect(status_id)
	if not status_data:
		return result

	var status_tags = status_data.tags
	var trait_tags = get_trait_tags()

	# Check immunities first (immunity beats resist)
	for tag in status_tags:
		var immunity_trait = "immune_" + tag
		if trait_tags.has(immunity_trait):
			result["blocked"] = true
			result["reason"] = immunity_trait
			return result

	# Check resists (reduce duration by 1)
	for tag in status_tags:
		var resist_trait = "resist_" + tag
		if trait_tags.has(resist_trait):
			result["duration_delta"] = -1
			result["reason"] = resist_trait
			return result

	return result


# ============================================================================
# STATUS HELPERS (Legacy StatusRuntime)
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
	for idx in range(equip_ability_cooldowns.size()):
		if equip_ability_cooldowns[idx] > 0:
			cooldown_parts.append("E%d:%d" % [idx, equip_ability_cooldowns[idx]])
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
