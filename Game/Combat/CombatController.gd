## CombatController.gd
## Main combat engine controller.
## Manages turn-based combat loop, unit actions, and combat resolution.
##
## Source: MVP_Milestones.md (M1), GDD Section 23
## Updated: M2.1 Hardening Pass - Clean API for UI
## Updated: M3 Grid Implementation - 4x2 formation, position-based targeting
## Updated: M4 Class Kit Integration - passive behaviors, active abilities
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal combat_started(player_units: Array, enemy_units: Array)
signal turn_started(unit: CombatUnit)
signal action_performed(action: CombatAction)
signal turn_ended(unit: CombatUnit)
signal round_ended(round_number: int)
signal combat_ended(result: CombatResult)
signal passive_triggered(unit: CombatUnit, passive_id: String, effect_desc: String)

# ============================================================================
# HERO CLASS MAPPING (Temporary until full hero system)
# ============================================================================

const HERO_CLASS_MAP = {
	"hero_1": "defender",
	"hero_2": "striker",
	"hero_3": "defender",
}

# ============================================================================
# STATE
# ============================================================================

var _player_units: Array = []
var _enemy_units: Array = []
var _all_units: Array = []
var _turn_queue: TurnQueue = null
var _rng: RandomNumberGenerator = null
var _result: CombatResult = null
var _targeting_policy: TargetingPolicy = null

var _is_combat_active: bool = false
var _current_round: int = 0
var _current_turn: int = 0
var _pending_actions: Array = []  # Actions from last step

# Configuration
const MAX_ROUNDS = 100  # Safety limit

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[CombatController] Ready.")


## Initialize combat without running the loop (for step-based UI).
func initialize_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null) -> void:
	print("\n" + "=".repeat(50))
	print("        COMBAT INITIALIZED")
	print("=".repeat(50) + "\n")

	_is_combat_active = true
	_current_round = 1
	_current_turn = 0
	_pending_actions.clear()

	# Set up RNG
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()

	# Set up targeting policy (M3: use grid-based targeting)
	_targeting_policy = TargetingPolicy.new(TargetingPolicy.TargetMode.GRID_DEFAULT, _rng)

	# Create units
	_create_units(hero_ids, enemy_ids)

	# Assign grid positions (M3)
	FormationAssigner.assign_default_formation(_player_units, _enemy_units)
	print("[CombatController] Formation assigned (4x2 grid)")

	# Apply passive stat bonuses (M4)
	_apply_all_passives()

	# Initialize result tracking
	_result = CombatResult.new()

	# Initialize turn queue
	_turn_queue = TurnQueue.new()
	_turn_queue.initialize(_all_units)

	combat_started.emit(_player_units, _enemy_units)


## Start a combat encounter (runs to completion).
func start_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null) -> CombatResult:
	initialize_combat(hero_ids, enemy_ids, rng)

	# Run combat loop
	_run_combat_loop()

	# Finalize result
	_result.set_outcome_from_combat(_player_units, _enemy_units)
	_result.calculate_rewards(_enemy_units)

	_is_combat_active = false
	combat_ended.emit(_result)

	return _result


## Create combat units from IDs.
func _create_units(hero_ids: Array, enemy_ids: Array) -> void:
	_player_units.clear()
	_enemy_units.clear()
	_all_units.clear()

	# Create hero units with proper class mapping
	for i in range(hero_ids.size()):
		var hero_id = hero_ids[i]
		var class_id = HERO_CLASS_MAP.get(hero_id, "defender")  # Fallback to defender
		var hero = CombatUnit.create_hero(hero_id, class_id, i)
		_player_units.append(hero)
		_all_units.append(hero)

	# Create enemy units
	for i in range(enemy_ids.size()):
		var enemy = CombatUnit.create_monster(enemy_ids[i], i)
		_enemy_units.append(enemy)
		_all_units.append(enemy)

	print("[CombatController] Created %d heroes vs %d enemies" % [
		_player_units.size(), _enemy_units.size()])


# ============================================================================
# M4 CLASS KIT - PASSIVE BEHAVIORS
# ============================================================================

## Apply all passive stat bonuses to player units.
func _apply_all_passives() -> void:
	print("[CombatController] Applying passive bonuses...")
	for unit in _player_units:
		_apply_passives_to_unit(unit)


## Apply passive stat bonuses to a single unit.
func _apply_passives_to_unit(unit: CombatUnit) -> void:
	if unit.passive_a_id != "":
		_apply_single_passive(unit, unit.passive_a_id)
	if unit.passive_b_id != "":
		_apply_single_passive(unit, unit.passive_b_id)


## Apply a single passive effect to a unit.
func _apply_single_passive(unit: CombatUnit, passive_id: String) -> void:
	var passive = DataRegistry.get_passive(passive_id)
	if passive == null:
		push_warning("[CombatController] Passive not found: %s" % passive_id)
		return

	# Check if passive is stat bonus type
	if not passive.is_stat_bonus():
		return  # on_kill passives are handled differently

	# Check trigger conditions
	if passive.is_conditional():
		if passive.requires_front_row() and not unit.is_front_row():
			print("[CombatController] %s: %s requires front row (unit in row %d)" % [
				unit.display_name, passive.display_name, unit.grid_y])
			return

	# Apply stat bonus
	var stat = passive.get_bonus_stat()
	var bonus = passive.get_bonus_value()

	match stat:
		"health":
			unit.max_health += bonus
			unit.current_health += bonus
			print("[CombatController] %s: +%d HP from %s" % [unit.display_name, bonus, passive.display_name])
		"attack":
			unit.attack += bonus
			print("[CombatController] %s: +%d ATK from %s" % [unit.display_name, bonus, passive.display_name])
		"defense":
			unit.defense += bonus
			print("[CombatController] %s: +%d DEF from %s" % [unit.display_name, bonus, passive.display_name])
		"speed":
			unit.speed += bonus
			print("[CombatController] %s: +%d SPD from %s" % [unit.display_name, bonus, passive.display_name])

	passive_triggered.emit(unit, passive_id, "+%d %s" % [bonus, stat.to_upper()])


## Determine which ability a unit should use (priority: Active A > Active B > Weapon > Basic).
func _get_ability_to_use(unit: CombatUnit) -> Dictionary:
	# Priority 1: Class Active A
	if unit.is_ability_a_ready():
		var ability = DataRegistry.get_ability(unit.ability_a_id)
		if ability != null:
			return {"type": "ability_a", "ability": ability}

	# Priority 2: Class Active B
	if unit.is_ability_b_ready():
		var ability = DataRegistry.get_ability(unit.ability_b_id)
		if ability != null:
			return {"type": "ability_b", "ability": ability}

	# Priority 3: Weapon Ability
	if unit.is_weapon_ability_ready():
		return {"type": "weapon", "ability": null}

	# Fallback: Basic Attack
	return {"type": "basic", "ability": null}


## Calculate damage for an ability.
func _calculate_ability_damage(unit: CombatUnit, ability: AbilityData) -> int:
	var base = ability.base_damage
	var scaling = ability.attack_scaling
	var total = int(base + (unit.attack * scaling))
	return maxi(1, total)


## Apply status effect from an ability.
func _apply_ability_status(target: CombatUnit, ability: AbilityData, source: CombatUnit) -> void:
	var status_id = ability.applies_status_id
	var stacks = ability.status_stacks

	if status_id == "stun":
		if target.apply_stun(stacks, source.unit_id):
			print("  %s is stunned for %d turn(s)!" % [target.display_name, stacks])
	elif status_id == "doom":
		target.apply_doom(stacks, 5, source.unit_id)
		print("  %s is doomed! (+%d stacks)" % [target.display_name, stacks])
	else:
		# Generic status handling could go here
		print("  Applied %s to %s" % [status_id, target.display_name])


## Trigger on_kill passives when a unit kills an enemy.
func _trigger_on_kill_passives(killer: CombatUnit) -> void:
	if killer.team != CombatUnit.Team.PLAYER:
		return  # Only player units have class passives

	for passive_id in [killer.passive_a_id, killer.passive_b_id]:
		if passive_id == "":
			continue

		var passive = DataRegistry.get_passive(passive_id)
		if passive == null:
			continue

		if not passive.is_on_kill():
			continue

		# Apply on_kill effect
		var cd_reduction = passive.get_weapon_cooldown_reduction()
		if cd_reduction > 0:
			killer.reduce_weapon_cooldown(cd_reduction)
			print("[CombatController] %s: %s triggered! Weapon CD reduced by %d" % [
				killer.display_name, passive.display_name, cd_reduction])
			passive_triggered.emit(killer, passive_id, "Weapon CD -%d" % cd_reduction)


# ============================================================================
# CLEAN API FOR UI (M2.1)
# ============================================================================

## Step exactly one turn. Returns array of CombatActions that occurred.
func step_one_turn() -> Array:
	_pending_actions.clear()

	if not _is_combat_active:
		return _pending_actions

	# Check if round is complete, start new round if needed
	if _turn_queue.is_round_complete():
		_current_round += 1
		_result.total_rounds = _current_round
		_turn_queue.start_new_round()
		round_ended.emit(_current_round)

	# Get next unit
	var unit = _turn_queue.get_next_unit()
	if unit == null:
		return _pending_actions

	# Process this unit's turn
	_process_unit_turn_step(unit)

	# Advance queue
	_turn_queue.advance()

	# Check combat end
	_check_combat_end()

	return _pending_actions


## Get snapshot of all units for UI display.
func get_units_snapshot() -> Dictionary:
	var player_data: Array = []
	var enemy_data: Array = []

	for unit in _player_units:
		player_data.append(_unit_to_snapshot(unit))

	for unit in _enemy_units:
		enemy_data.append(_unit_to_snapshot(unit))

	return {
		"player": player_data,
		"enemy": enemy_data
	}


## Convert a unit to a snapshot dictionary.
func _unit_to_snapshot(unit: CombatUnit) -> Dictionary:
	var statuses: Array = []

	if unit.statuses.is_stunned():
		var stun = unit.statuses.get_status("stun")
		statuses.append({
			"id": "stun",
			"duration": stun.duration
		})

	if unit.statuses.has_status("doom"):
		statuses.append({
			"id": "doom",
			"stacks": unit.statuses.get_doom_stacks(),
			"countdown": unit.statuses.get_doom_countdown()
		})

	var team_str = "player" if unit.team == CombatUnit.Team.PLAYER else "enemy"

	return {
		"id": unit.unit_id,
		"name": unit.display_name,
		"hp": unit.current_health,
		"max_hp": unit.max_health,
		"speed": unit.speed,
		"attack": unit.attack,
		"defense": unit.defense,
		"weapon_cooldown": unit.weapon_ability_cooldown,
		"weapon_max_cooldown": unit.weapon_ability_max_cooldown,
		"statuses": statuses,
		"is_alive": unit.is_alive,
		"team": team_str,
		"pos": {"x": unit.grid_x, "y": unit.grid_y},
		"team_pos_key": "%s:%d,%d" % [team_str, unit.grid_x, unit.grid_y]
	}


## Get current turn info for UI.
func get_turn_info() -> Dictionary:
	var current_actor = _turn_queue.get_next_unit() if _turn_queue != null else null

	return {
		"round": _current_round,
		"turn": _current_turn,
		"current_actor_id": current_actor.unit_id if current_actor else "",
		"current_actor_name": current_actor.display_name if current_actor else "",
		"current_actor_team": "player" if current_actor and current_actor.team == CombatUnit.Team.PLAYER else "enemy",
		"is_round_complete": _turn_queue.is_round_complete() if _turn_queue else true
	}


## Check if combat is over.
func is_combat_over() -> bool:
	return not _is_combat_active


## Get the combat result (only valid after combat ends).
func get_result() -> CombatResult:
	return _result


## Apply status effect to a unit by ID (for demo/testing).
func apply_status_to_unit(unit_id: String, status_id: String, value: int) -> bool:
	var unit = _find_unit_by_id(unit_id)
	if unit == null:
		return false

	if status_id == "stun":
		unit.apply_stun(value, "demo")
		return true
	elif status_id == "doom":
		unit.apply_doom(value, 5, "demo")
		return true

	return false


func _find_unit_by_id(unit_id: String) -> CombatUnit:
	for unit in _all_units:
		if unit.unit_id == unit_id:
			return unit
	return null


# ============================================================================
# COMBAT LOOP (Full auto-run)
# ============================================================================

func _run_combat_loop() -> void:
	while _is_combat_active and _current_round < MAX_ROUNDS:
		_result.total_rounds = _current_round
		print("\n--- ROUND %d ---" % _current_round)

		# Process each unit's turn
		while not _turn_queue.is_round_complete():
			var unit = _turn_queue.get_next_unit()
			if unit == null:
				break

			_process_unit_turn(unit)
			_turn_queue.advance()

			# Check for combat end
			if _check_combat_end():
				return

		round_ended.emit(_current_round)
		_current_round += 1
		_turn_queue.start_new_round()

	if _current_round >= MAX_ROUNDS:
		print("[CombatController] Combat ended: MAX ROUNDS reached")


func _process_unit_turn(unit: CombatUnit) -> void:
	_current_turn += 1
	_result.total_turns = _current_turn

	print("\n[Turn %d] %s's turn" % [_current_turn, unit.display_name])
	turn_started.emit(unit)

	# Process turn start - check if stunned
	var can_act = unit.statuses.process_turn_start()

	if not can_act:
		var action = CombatAction.create_skip(unit, "Stunned!")
		_result.add_action(action)
		action_performed.emit(action)
		print("  %s is stunned and cannot act!" % unit.display_name)
	else:
		_execute_unit_action(unit)

	# Process turn end
	unit.tick_cooldowns()
	var doom_damage = unit.statuses.process_turn_end()

	if doom_damage > 0:
		var actual_damage = unit.take_damage(doom_damage, "true")
		var doom_action = CombatAction.create_doom_trigger(unit, actual_damage)
		_result.add_action(doom_action)
		action_performed.emit(doom_action)

		if not unit.is_alive:
			var death_action = CombatAction.create_death(unit)
			_result.add_action(death_action)
			action_performed.emit(death_action)

	turn_ended.emit(unit)


## Process unit turn for step-based combat (stores actions in _pending_actions).
func _process_unit_turn_step(unit: CombatUnit) -> void:
	_current_turn += 1
	_result.total_turns = _current_turn

	turn_started.emit(unit)

	# Process turn start - check if stunned
	var can_act = unit.statuses.process_turn_start()

	if not can_act:
		var action = CombatAction.create_skip(unit, "Stunned!")
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
	else:
		_execute_unit_action_step(unit)

	# Process turn end
	unit.tick_cooldowns()
	var doom_damage = unit.statuses.process_turn_end()

	if doom_damage > 0:
		var actual_damage = unit.take_damage(doom_damage, "true")
		var doom_action = CombatAction.create_doom_trigger(unit, actual_damage)
		_pending_actions.append(doom_action)
		_result.add_action(doom_action)
		action_performed.emit(doom_action)

		if not unit.is_alive:
			var death_action = CombatAction.create_death(unit)
			_pending_actions.append(death_action)
			_result.add_action(death_action)
			action_performed.emit(death_action)

	turn_ended.emit(unit)


func _execute_unit_action(unit: CombatUnit) -> void:
	# Use targeting policy
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		print("  No valid target found")
		return

	# M4: Determine ability to use (priority: Active A > Active B > Weapon > Basic)
	var ability_choice = _get_ability_to_use(unit)
	var ability_type = ability_choice["type"]
	var ability: AbilityData = ability_choice["ability"]

	var raw_damage: int
	var damage_type: String = "physical"
	var is_ability: bool = ability_type != "basic"

	if ability != null:
		# Class ability damage
		raw_damage = _calculate_ability_damage(unit, ability)
		damage_type = ability.damage_type
		print("  %s uses %s!" % [unit.display_name, ability.display_name])
	elif ability_type == "weapon":
		# Weapon ability damage (1.5x)
		raw_damage = int(unit.attack * 1.5)
	else:
		# Basic attack
		raw_damage = unit.attack

	var actual_damage = target.take_damage(raw_damage, damage_type)

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	match ability_type:
		"ability_a":
			unit.use_ability_a()
		"ability_b":
			unit.use_ability_b()
		"weapon":
			unit.use_weapon_ability()

	# Apply status effect if ability has one
	if ability != null and ability.applies_status_id != "":
		_apply_ability_status(target, ability, unit)

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit)  # M4: on_kill passive trigger


func _execute_unit_action_step(unit: CombatUnit) -> void:
	# Use targeting policy
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		return

	# M4: Determine ability to use (priority: Active A > Active B > Weapon > Basic)
	var ability_choice = _get_ability_to_use(unit)
	var ability_type = ability_choice["type"]
	var ability: AbilityData = ability_choice["ability"]

	var raw_damage: int
	var damage_type: String = "physical"
	var is_ability: bool = ability_type != "basic"

	if ability != null:
		# Class ability damage
		raw_damage = _calculate_ability_damage(unit, ability)
		damage_type = ability.damage_type
	elif ability_type == "weapon":
		# Weapon ability damage (1.5x)
		raw_damage = int(unit.attack * 1.5)
	else:
		# Basic attack
		raw_damage = unit.attack

	var actual_damage = target.take_damage(raw_damage, damage_type)

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	match ability_type:
		"ability_a":
			unit.use_ability_a()
		"ability_b":
			unit.use_ability_b()
		"weapon":
			unit.use_weapon_ability()

	# Apply status effect if ability has one
	if ability != null and ability.applies_status_id != "":
		_apply_ability_status(target, ability, unit)

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit)  # M4: on_kill passive trigger


func _check_combat_end() -> bool:
	if _turn_queue.is_team_wiped(CombatUnit.Team.ENEMY):
		print("\n[CombatController] All enemies defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		combat_ended.emit(_result)
		return true

	if _turn_queue.is_team_wiped(CombatUnit.Team.PLAYER):
		print("\n[CombatController] All heroes defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		combat_ended.emit(_result)
		return true

	return false


# ============================================================================
# PUBLIC API - TEST BATTLE
# ============================================================================

func start_test_battle() -> CombatResult:
	print("[CombatController] Starting test battle...")
	var seed_val = GameContext.get_run_seed() if GameContext.get_run_seed() > 0 else 12345
	var rng = SeededRNG.create_rng(seed_val)
	var heroes = ["hero_1", "hero_2", "hero_3"]
	var enemies = ["goblin", "goblin"]
	return start_combat(heroes, enemies, rng)


# ============================================================================
# SMOKE TEST
# ============================================================================

func run_smoke_test() -> bool:
	print("\n" + "=".repeat(60))
	print("    CombatController M4 SMOKE TEST (Class Kit Integration)")
	print("=".repeat(60) + "\n")

	var passed = true
	var total_checks = 0
	var passed_checks = 0

	var test_seed = 12345
	var rng = SeededRNG.create_rng(test_seed)

	# Check 1: Initialize combat
	print("--- Check 1: Initialize Combat ---")
	total_checks += 1
	initialize_combat(["hero_1", "hero_2"], ["goblin", "goblin"], rng)
	if _is_combat_active and _player_units.size() == 2 and _enemy_units.size() == 2:
		print("[PASS] Combat initialized: 2v2")
		passed_checks += 1
	else:
		print("[FAIL] Combat not initialized correctly")
		passed = false

	# Check 2: Hero class mapping
	print("\n--- Check 2: Hero Class Mapping ---")
	total_checks += 1
	var hero1_class = _player_units[0].display_name
	var hero2_class = _player_units[1].display_name
	if hero1_class == "Defender" and hero2_class == "Striker":
		print("[PASS] Hero classes: %s, %s" % [hero1_class, hero2_class])
		passed_checks += 1
	else:
		print("[FAIL] Expected Defender/Striker, got %s/%s" % [hero1_class, hero2_class])
		passed = false

	# Check 3: Formation assignment - no overlap within each team (M3.1)
	print("\n--- Check 3: Formation - Per-Team No Overlap ---")
	total_checks += 1
	if FormationAssigner.validate_no_overlap_per_team(_player_units, _enemy_units):
		print("[PASS] No overlap within each team formation")
		passed_checks += 1
	else:
		print("[FAIL] Position overlap detected within a team")
		passed = false

	# Check 4: Separate grids - player(0,0) and enemy(0,0) both allowed (M3.1)
	print("\n--- Check 4: Separate Grids - Same Coords OK ---")
	total_checks += 1
	var player_pos = _player_units[0].get_team_pos_key()
	var enemy_pos = _enemy_units[0].get_team_pos_key()
	# Both should be at (0,0) on their respective grids
	if player_pos == "player:0,0" and enemy_pos == "enemy:0,0":
		print("[PASS] player(0,0) and enemy(0,0) coexist on separate grids")
		passed_checks += 1
	else:
		print("[FAIL] Expected player:0,0 and enemy:0,0, got %s and %s" % [player_pos, enemy_pos])
		passed = false

	# Check 5: All units positioned with team_pos_key
	print("\n--- Check 5: All Units Positioned ---")
	total_checks += 1
	var all_positioned = true
	for unit in _all_units:
		if not unit.has_position():
			all_positioned = false
			break
	if all_positioned:
		print("[PASS] All units have grid positions")
		for unit in _player_units:
			print("  %s" % unit.get_team_pos_key())
		for unit in _enemy_units:
			print("  %s" % unit.get_team_pos_key())
		passed_checks += 1
	else:
		print("[FAIL] Some units missing positions")
		passed = false

	# Check 6: Snapshot includes team_pos_key
	print("\n--- Check 6: Snapshot Has team_pos_key ---")
	total_checks += 1
	var snapshot = get_units_snapshot()
	var has_key = snapshot["player"][0].has("team_pos_key") and snapshot["enemy"][0].has("team_pos_key")
	if has_key:
		print("[PASS] Snapshot has team_pos_key: %s" % snapshot["player"][0]["team_pos_key"])
		passed_checks += 1
	else:
		print("[FAIL] Snapshot missing team_pos_key")
		passed = false

	# Check 7: Melee cannot target back row if front row alive
	print("\n--- Check 7: Melee Blocked by Front Row ---")
	total_checks += 1
	# Set up: 3 enemies, 2 front, 1 back
	# Reset for clean test
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1"], ["goblin", "goblin", "goblin"], rng)
	# Hero 1 has sword = melee
	# Manually position enemies: 2 front, 1 back
	_enemy_units[0].set_position(0, 0)  # front
	_enemy_units[1].set_position(1, 0)  # front
	_enemy_units[2].set_position(0, 1)  # back
	# Make back row enemy lowest HP
	_enemy_units[2].current_health = 1

	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	var melee_target = _targeting_policy.select_target(_player_units[0], enemies)
	# Melee should NOT target back row enemy despite lowest HP
	if melee_target != _enemy_units[2]:
		print("[PASS] Melee attacker cannot target back row (front row blocks)")
		passed_checks += 1
	else:
		print("[FAIL] Melee attacker incorrectly targeted back row")
		passed = false

	# Check 8: Melee can target back row if front row empty
	print("\n--- Check 8: Melee Can Target Back Row (Front Empty) ---")
	total_checks += 1
	# Kill front row units
	_enemy_units[0].is_alive = false
	_enemy_units[1].is_alive = false
	enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	melee_target = _targeting_policy.select_target(_player_units[0], enemies)
	if melee_target == _enemy_units[2]:
		print("[PASS] Melee attacker can target back row when front empty")
		passed_checks += 1
	else:
		print("[FAIL] Melee attacker could not target back row")
		passed = false

	# Check 9: Ranged can target back row even if front row alive
	print("\n--- Check 9: Ranged Can Target Back Row ---")
	total_checks += 1
	# Reset and use ranged attacker
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1"], ["goblin", "goblin", "goblin"], rng)
	# Make hero ranged by clearing weapon ability id (no sword = ranged)
	_player_units[0].weapon_ability_id = "bow_shot"  # Not sword = ranged
	# Position enemies
	_enemy_units[0].set_position(0, 0)  # front
	_enemy_units[1].set_position(1, 0)  # front
	_enemy_units[2].set_position(0, 1)  # back
	# Make back row enemy lowest HP
	_enemy_units[2].current_health = 1

	enemies = TargetingPolicy.get_enemies_for_team(_all_units, CombatUnit.Team.PLAYER)
	var ranged_target = _targeting_policy.select_target(_player_units[0], enemies)
	if ranged_target == _enemy_units[2]:
		print("[PASS] Ranged attacker can target back row (lowest HP)")
		passed_checks += 1
	else:
		print("[FAIL] Ranged attacker did not target lowest HP back row")
		passed = false

	# Check 10: Step and complete combat
	print("\n--- Check 10: Combat Runs to Completion ---")
	total_checks += 1
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1", "hero_2"], ["goblin", "goblin"], rng)
	var step_count = 0
	while not is_combat_over() and step_count < 50:
		step_one_turn()
		step_count += 1

	if is_combat_over():
		print("[PASS] Combat completed in %d steps" % step_count)
		passed_checks += 1
	else:
		print("[FAIL] Combat did not complete")
		passed = false

	# ========================================
	# M4 CLASS KIT CHECKS
	# ========================================

	# Check 11: Class kit loaded (passives and abilities)
	print("\n--- Check 11: M4 Class Kit Loaded ---")
	total_checks += 1
	rng = SeededRNG.create_rng(test_seed)
	initialize_combat(["hero_1", "hero_2"], ["goblin"], rng)
	var defender = _player_units[0]
	var striker = _player_units[1]

	var kit_loaded = (
		defender.passive_a_id == "def_iron_skin" and
		defender.passive_b_id == "def_front_line_bonus" and
		defender.ability_a_id == "def_shield_bash" and
		striker.passive_a_id == "str_killer_instinct" and
		striker.ability_a_id == "str_precise_strike"
	)
	if kit_loaded:
		print("[PASS] Class kits loaded: Defender passives=[%s, %s], Striker passives=[%s, %s]" % [
			defender.passive_a_id, defender.passive_b_id,
			striker.passive_a_id, striker.passive_b_id])
		passed_checks += 1
	else:
		print("[FAIL] Class kits not loaded correctly")
		passed = false

	# Check 12: Passive stat bonus applied (Defender +2 DEF)
	print("\n--- Check 12: M4 Passive Stat Bonus Applied ---")
	total_checks += 1
	# Defender base DEF from JSON is 15, passive adds +2 = 17
	# Also +10 HP if front row
	var expected_def = 15 + 2  # base + iron_skin
	if defender.defense == expected_def:
		print("[PASS] Defender DEF = %d (base 15 + 2 from Iron Skin)" % defender.defense)
		passed_checks += 1
	else:
		print("[FAIL] Defender DEF = %d, expected %d" % [defender.defense, expected_def])
		passed = false

	# Check 13: Striker passive applied (+2 ATK)
	print("\n--- Check 13: M4 Striker Passive Applied ---")
	total_checks += 1
	# Striker base ATK from JSON is 14, passive adds +2 = 16
	var expected_atk = 14 + 2
	if striker.attack == expected_atk:
		print("[PASS] Striker ATK = %d (base 14 + 2 from Killer Instinct)" % striker.attack)
		passed_checks += 1
	else:
		print("[FAIL] Striker ATK = %d, expected %d" % [striker.attack, expected_atk])
		passed = false

	# Check 14: Ability cooldowns initialized
	print("\n--- Check 14: M4 Ability Cooldowns Initialized ---")
	total_checks += 1
	# Shield Bash has cooldown 4, Fortify has cooldown 3
	var cooldowns_ok = (
		defender.ability_a_max_cooldown == 4 and
		defender.ability_b_max_cooldown == 3 and
		defender.ability_a_cooldown == 0 and  # Should start at 0 (ready)
		striker.ability_a_max_cooldown == 3
	)
	if cooldowns_ok:
		print("[PASS] Ability cooldowns: Defender A=%d/%d, B=%d/%d" % [
			defender.ability_a_cooldown, defender.ability_a_max_cooldown,
			defender.ability_b_cooldown, defender.ability_b_max_cooldown])
		passed_checks += 1
	else:
		print("[FAIL] Ability cooldowns not initialized correctly")
		passed = false

	# Check 15: Front row conditional passive (+10 HP)
	print("\n--- Check 15: M4 Front Row Conditional Passive ---")
	total_checks += 1
	# Defender in front row should get +10 HP from def_front_line_bonus
	# Base HP is 120, +10 = 130
	var expected_hp = 120 + 10
	if defender.is_front_row() and defender.max_health == expected_hp:
		print("[PASS] Defender front row HP = %d (base 120 + 10 from Front Line Bonus)" % defender.max_health)
		passed_checks += 1
	else:
		print("[FAIL] Defender HP = %d (front_row=%s), expected %d" % [defender.max_health, defender.is_front_row(), expected_hp])
		passed = false

	# Final result
	print("\n" + "=".repeat(60))
	if passed:
		print("  M4 SMOKE TEST PASSED (%d/%d checks)" % [passed_checks, total_checks])
	else:
		print("  M4 SMOKE TEST FAILED (%d/%d checks)" % [passed_checks, total_checks])
	print("=".repeat(60) + "\n")

	return passed
