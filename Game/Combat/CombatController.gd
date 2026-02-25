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
signal status_changed(unit_id: String)  # Status UI v1.6: Emitted when status applied/stacked/expired
signal all_statuses_ticked()  # Status UI v1.6: Emitted after round-start status tick
signal intent_decided(actor_id: String, action_type: String, ability_id: String, target_id: String)  # v1.9B: Intent surface
signal player_input_required(unit: CombatUnit, available_actions: Array)  # Player Actions v1
signal target_selection_required(unit: CombatUnit, valid_targets: Array, action_type: String, ability: AbilityData)  # Player Actions v1
signal multi_action_update(unit: CombatUnit, actions_remaining: int, actions_total: int)  # Player Actions v1
signal combat_continue_ready()  # Player Actions v1: Emitted when ready for next step (auto-flow)

# ============================================================================
# HERO CLASS MAPPING (Legacy fallback for hardcoded hero_ids)
# ============================================================================

const LEGACY_HERO_CLASS_MAP = {
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
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _result: CombatResult = null
var _targeting_policy: TargetingPolicy = null

var _is_combat_active: bool = false
var _current_round: int = 0
var _current_turn: int = 0
var last_expired_statuses: Dictionary = {}  # Status UI v2: unit_id -> Array of expired status IDs
var _pending_actions: Array = []  # Actions from last step

# Encounter snapshot (frozen at combat start, used for rewards)
var _encounter_dungeon_id: String = ""
var _encounter_floor: int = 0
var _encounter_floor_count: int = 4
var _encounter_is_boss: bool = false
var _encounter_boss_id: String = ""

# Configuration
const MAX_ROUNDS = 100  # Safety limit
const ENEMY_ACTION_DELAY: float = 0.6  # Delay between enemy actions for visual clarity

# ============================================================================
# PLAYER INPUT STATE (Player Actions v1)
# ============================================================================

var _awaiting_player_input: bool = false
var _input_unit: CombatUnit = null
var _selected_action_type: String = ""  # "basic", "ability_a", "ability_b", "consumable"
var _selected_ability: AbilityData = null

# ============================================================================
# MULTI-ACTION STATE (Speed Multi-Actions v1)
# ============================================================================

var _unit_remaining_actions: Dictionary = {}  # { unit_id: int }
var _current_multi_action_unit: CombatUnit = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	print("[CombatController] Ready.")


## Initialize combat without running the loop (for step-based UI).
## Optional modifier dict can contain: player_spd_bonus, enemy_spd_bonus, player_start_damage, bonus_gold
func initialize_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null, modifier: Dictionary = {}) -> void:
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

	# Apply hero row assignments (3-Row Formation v1)
	# Override row for player units based on saved assignments
	for unit in _player_units:
		var hero_id = unit.source_id
		var assigned_row = GameContext.get_hero_row(hero_id)
		unit.grid_y = assigned_row
	print("[CombatController] Formation assigned (3-row: Front/Middle/Back)")

	# Apply passive stat bonuses (M4)
	_apply_all_passives()

	# Apply race passives (v1)
	_apply_race_passives()

	# Apply equipment stat bonuses from equipped items
	_apply_equipment_bonuses()

	# HP Clamp v1: Ensure current_health does not exceed max_health after all bonuses
	# This fixes a bug where persisted HP from previous combat (with bonuses applied)
	# would be restored, then bonuses applied again, causing current > max.
	_clamp_player_hp()

	# T4 combat_start tag effects (e.g., speed buffs) BEFORE speed modifiers
	_process_combat_start_tag_effects()

	# Apply combat modifier speed bonuses BEFORE TurnQueue is built
	_apply_combat_modifier_speeds(modifier)

	# Initialize result tracking
	_result = CombatResult.new()

	# Initialize turn queue (uses unit.speed for ordering)
	_turn_queue = TurnQueue.new()
	_turn_queue.initialize(_all_units)

	# Apply combat modifier damage/gold AFTER units are set up
	_apply_combat_modifier_effects(modifier)

	# Apply pending event statuses (queued from dungeon events)
	var pending_statuses = GameContext.consume_pending_combat_statuses()
	if not pending_statuses.is_empty():
		_apply_pending_event_statuses(pending_statuses)

	combat_started.emit(_player_units, _enemy_units)


## Set encounter context snapshot (call after initialize_combat, before combat runs).
## These values are frozen and used for reward calculation regardless of GameContext changes.
func set_encounter_context(dungeon_id: String, floor_num: int, floor_count: int, is_boss: bool, boss_id: String) -> void:
	_encounter_dungeon_id = dungeon_id
	_encounter_floor = floor_num
	_encounter_floor_count = floor_count
	_encounter_is_boss = is_boss
	_encounter_boss_id = boss_id


## Start a combat encounter (runs to completion).
func start_combat(hero_ids: Array, enemy_ids: Array, rng: RandomNumberGenerator = null) -> CombatResult:
	initialize_combat(hero_ids, enemy_ids, rng)

	# Run combat loop
	_run_combat_loop()

	# Finalize result
	_result.set_outcome_from_combat(_player_units, _enemy_units)
	_result.set_rng(_rng)
	_result.is_boss_encounter = _encounter_is_boss
	_result.calculate_rewards(_enemy_units)

	# Health Persistence v1: Save surviving heroes' HP
	_persist_hero_hp()

	_is_combat_active = false
	combat_ended.emit(_result)

	return _result


## Create combat units from IDs.
func _create_units(hero_ids: Array, enemy_ids: Array) -> void:
	_player_units.clear()
	_enemy_units.clear()
	_all_units.clear()

	# Consumables v1: Reset consumable usage tracking at combat start
	if GameContext.has_method("reset_combat_consumables"):
		GameContext.reset_combat_consumables()

	# Create hero units with effective stats (level-scaled + race modifiers)
	print("\n[HeroStats] === Combat Spawning ===")
	for i in range(hero_ids.size()):
		var hero_id = hero_ids[i]

		# Skip dead heroes — they shouldn't enter combat
		if GameContext.has_method("has_hero_hp") and GameContext.has_hero_hp(hero_id):
			var hp_check = GameContext.get_hero_hp(hero_id)
			if int(hp_check.get("current", 1)) <= 0:
				print("[HP] skip_dead_hero hero=%s hp=0 (excluded from combat)" % hero_id)
				continue

		var class_id = "defender"  # Default fallback
		var effective_stats: Dictionary = {}

		# Try to get hero data and effective stats from GameContext
		var hero_data = GameContext.get_hero(hero_id) if GameContext.has_method("get_hero") else {}
		if not hero_data.is_empty():
			class_id = hero_data.get("class_id", "defender")
			# Get level-scaled + race-modified stats
			effective_stats = GameContext.get_hero_effective_stats(hero_id)
			var level = effective_stats.get("level", 1)
			var race_id = effective_stats.get("race_id", "human")
			print("[HeroStats] %s (Lv%d %s %s): HP=%d ATK=%d DEF=%d SPD=%d" % [
				effective_stats.get("name", hero_id), level, race_id, class_id,
				effective_stats.get("health", 0), effective_stats.get("attack", 0),
				effective_stats.get("defense", 0), effective_stats.get("speed", 0)])
		else:
			# Legacy fallback for hardcoded hero_1, hero_2, etc.
			class_id = LEGACY_HERO_CLASS_MAP.get(hero_id, "defender")
			print("[HeroStats] %s (legacy %s): using base class stats" % [hero_id, class_id])

		var hero = CombatUnit.create_hero(hero_id, class_id, i, effective_stats)

		# Health Persistence v1: Apply persisted HP if hero fought before in this dungeon run
		if GameContext.has_method("has_hero_hp") and GameContext.has_hero_hp(hero_id):
			var hp_data = GameContext.get_hero_hp(hero_id)
			hero.current_health = hp_data.get("current", hero.max_health)
			print("[HP] restore_for_combat hero=%s hp=%d/%d (from_persistence)" % [hero_id, hero.current_health, hero.max_health])
		else:
			print("[HP] new_hero_in_run hero=%s hp=%d/%d (first_combat)" % [hero_id, hero.current_health, hero.max_health])

		_player_units.append(hero)
		_all_units.append(hero)

	print("[HeroStats] === End Hero Stats ===\n")

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

## Apply all passive stat bonuses to player and enemy units.
func _apply_all_passives() -> void:
	print("[CombatController] Applying passive bonuses...")
	for unit in _player_units:
		_apply_passives_to_unit(unit)
	for unit in _enemy_units:
		_apply_monster_passives(unit)


## Apply passive stat bonuses to a monster unit (bypasses hero level-gating).
func _apply_monster_passives(unit: CombatUnit) -> void:
	if unit.passive_a_id != "":
		_apply_single_passive(unit, unit.passive_a_id)
	if unit.passive_b_id != "":
		_apply_single_passive(unit, unit.passive_b_id)


## Apply passive stat bonuses to a single unit (respects level-gating).
func _apply_passives_to_unit(unit: CombatUnit) -> void:
	if unit.passive_a_id != "" and GameContext.is_ability_slot_unlocked("passive_a", unit.hero_level):
		_apply_single_passive(unit, unit.passive_a_id)
	if unit.passive_b_id != "" and GameContext.is_ability_slot_unlocked("passive_b", unit.hero_level):
		_apply_single_passive(unit, unit.passive_b_id)


## Apply a single passive effect to a unit.
func _apply_single_passive(unit: CombatUnit, passive_id: String) -> void:
	var passive = DataRegistry.get_passive(passive_id)
	if passive == null:
		push_warning("[CombatController] Passive not found: %s" % passive_id)
		return

	# Handle level-scaled stat bonus (e.g., bulwark_stance)
	if passive.passive_type == "level_scaled_stat_bonus":
		_apply_level_scaled_passive(unit, passive)
		return

	# Handle level-scaled stat bonus with cost (e.g., dark_pact: +ATK but -HP)
	if passive.passive_type == "level_scaled_stat_bonus_with_cost":
		_apply_level_scaled_passive_with_cost(unit, passive)
		return

	# Skip non-stat-bonus types (on_kill, round_start handled elsewhere)
	if not passive.is_stat_bonus():
		return

	# Check trigger conditions
	if passive.is_conditional():
		if passive.requires_front_row() and not unit.is_front_row():
			print("[CombatController] %s: %s requires front row (unit in row %d)" % [
				unit.display_name, passive.display_name, unit.grid_y])
			return

	# Apply stat bonus using buff system for tracking
	var stat = passive.get_bonus_stat()
	var bonus = passive.get_bonus_value()

	if stat == "" or bonus == 0:
		return

	# Health bonuses are applied directly (not tracked as buff since they affect max HP)
	if stat == "health":
		unit.max_health += bonus
		unit.current_health += bonus
		print("[CombatController] %s: +%d HP from %s (direct)" % [unit.display_name, bonus, passive.display_name])
		passive_triggered.emit(unit, passive_id, "+%d HP" % bonus)
		return

	# Apply non-health bonuses as a tracked buff
	var buff_stats = {stat: bonus}
	var buff_id = "passive_" + passive_id
	unit.apply_buff(buff_id, buff_stats, 999)  # 999 = effectively permanent for combat

	print("[CombatController] %s: +%d %s from %s (tracked as buff)" % [unit.display_name, bonus, stat.to_upper(), passive.display_name])
	passive_triggered.emit(unit, passive_id, "+%d %s" % [bonus, stat.to_upper()])


## Apply a level-scaled stat bonus passive (e.g., bulwark_stance, burning_presence).
## Formula: bonus = base_bonus + (level / divisor)
## Uses buff system for tracking so bonuses appear in stat tooltips.
func _apply_level_scaled_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var stat = passive.get_bonus_stat()
	var base_bonus = passive.get_bonus_value()
	var level = unit.hero_level
	var level_divisor = max(1, passive.get_level_divisor())
	var scaled_bonus = base_bonus + int(level / level_divisor)

	if stat == "" or scaled_bonus == 0:
		return

	# Apply as a tracked buff with very long duration (combat-permanent)
	# This allows the bonus to show in stat tooltips
	var buff_stats = {stat: scaled_bonus}
	var buff_id = "passive_" + passive.passive_id
	unit.apply_buff(buff_id, buff_stats, 999)  # 999 = effectively permanent for combat

	print("[Passive] %s hero=%s name=%s level=%d +%d %s (tracked as buff)" % [
		passive.passive_id, unit.source_id, unit.display_name, level, scaled_bonus, stat])
	passive_triggered.emit(unit, passive.passive_id, "+%d %s (level-scaled)" % [scaled_bonus, stat.to_upper()])


## Apply a level-scaled stat bonus passive WITH a stat cost (e.g., dark_pact).
## Formula: bonus = base_bonus + (level / divisor), then apply cost to another stat.
func _apply_level_scaled_passive_with_cost(unit: CombatUnit, passive: PassiveData) -> void:
	var stat = passive.get_bonus_stat()
	var base_bonus = passive.get_bonus_value()
	var level = unit.hero_level
	var level_divisor = max(1, passive.get_level_divisor())
	var scaled_bonus = base_bonus + int(level / level_divisor)

	if stat != "" and scaled_bonus > 0:
		var buff_stats = {stat: scaled_bonus}
		var buff_id = "passive_" + passive.passive_id
		unit.apply_buff(buff_id, buff_stats, 999)
		print("[Passive] %s hero=%s name=%s level=%d +%d %s (level-scaled with cost)" % [
			passive.passive_id, unit.source_id, unit.display_name, level, scaled_bonus, stat])
		passive_triggered.emit(unit, passive.passive_id, "+%d %s (level-scaled)" % [scaled_bonus, stat.to_upper()])

	# Apply cost (e.g., reduce max HP)
	var cost_stat: String = passive.cost.get("stat", "")
	var cost_value: int = int(passive.cost.get("value", 0))
	if cost_stat != "" and cost_value != 0:
		if cost_stat == "health":
			unit.max_health += cost_value  # cost_value is negative
			unit.current_health = mini(unit.current_health, unit.max_health)
			print("[Passive] %s: %d max HP from %s (cost)" % [unit.display_name, cost_value, passive.display_name])
		else:
			# Generic stat cost — apply as debuff
			var debuff_stats = {cost_stat: cost_value}
			var debuff_id = "passive_cost_" + passive.passive_id
			unit.apply_buff(debuff_id, debuff_stats, 999)
			print("[Passive] %s: %d %s from %s (cost)" % [unit.display_name, cost_value, cost_stat.to_upper(), passive.display_name])


# ============================================================================
# RACE PASSIVES
# ============================================================================

## Apply race passives to all player units at combat start.
## Race passives are applied AFTER class passives and BEFORE equipment bonuses.
func _apply_race_passives() -> void:
	print("[CombatController] Applying race passives...")
	for unit in _player_units:
		_apply_race_passive_to_unit(unit)


## Apply race passive to a single player unit.
func _apply_race_passive_to_unit(unit: CombatUnit) -> void:
	if unit.race_id == "":
		return

	var race_data = DataRegistry.get_race(unit.race_id)
	if race_data == null:
		return

	var passive_id = race_data.racial_passive_id
	if passive_id == "":
		return

	var passive = DataRegistry.get_passive(passive_id)
	if passive == null:
		push_warning("[RacePassive] Passive not found: %s for race %s" % [passive_id, unit.race_id])
		return

	# Handle race_multi_stat_bonus type (human, dwarf, voidwalker, crystalborn)
	if passive.passive_type == "race_multi_stat_bonus":
		_apply_race_multi_stat_passive(unit, passive)
		return

	# Handle simple stat_bonus type (elf)
	if passive.passive_type == "stat_bonus":
		_apply_race_stat_bonus_passive(unit, passive)
		return

	# Handle damage_reduction type (dragonkin_scales)
	if passive.passive_type == "damage_reduction":
		_apply_race_damage_reduction_passive(unit, passive)
		return


## Apply race multi-stat bonus passive (human_adaptability, dwarf_deep_miner).
## Uses buff system for tracking so bonuses appear in stat tooltips.
func _apply_race_multi_stat_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var level = unit.hero_level
	var changes: Array[String] = []
	var buff_stats: Dictionary = {}

	# Collect flat stat bonuses
	if passive.effect.has("attack"):
		var bonus = int(passive.effect.get("attack", 0))
		if bonus != 0:
			buff_stats["attack"] = buff_stats.get("attack", 0) + bonus
			changes.append("+%d ATK" % bonus)

	if passive.effect.has("defense"):
		var bonus = int(passive.effect.get("defense", 0))
		if bonus != 0:
			buff_stats["defense"] = buff_stats.get("defense", 0) + bonus
			changes.append("+%d DEF" % bonus)

	if passive.effect.has("speed"):
		var bonus = int(passive.effect.get("speed", 0))
		if bonus != 0:
			buff_stats["speed"] = buff_stats.get("speed", 0) + bonus
			changes.append("+%d SPD" % bonus)

	# Apply conditional speed bonus at level threshold (human_adaptability)
	if passive.effect.has("speed_at_level"):
		var speed_data = passive.effect.get("speed_at_level", {})
		var min_level = int(speed_data.get("min_level", 99))
		var spd_bonus = int(speed_data.get("bonus", 0))
		if level >= min_level and spd_bonus != 0:
			buff_stats["speed"] = buff_stats.get("speed", 0) + spd_bonus
			changes.append("+%d SPD (Lv%d+)" % [spd_bonus, min_level])

	# Health bonuses are applied directly (not tracked as buff since they affect max HP)
	if passive.effect.has("health"):
		var bonus = int(passive.effect.get("health", 0))
		if bonus != 0:
			unit.max_health += bonus
			unit.current_health += bonus
			changes.append("+%d HP" % bonus)

	# Apply level-scaled health bonus (dwarf_deep_miner)
	if passive.effect.has("health_scaled"):
		var hp_data = passive.effect.get("health_scaled", {})
		var base_hp = int(hp_data.get("base", 0))
		var per_level = int(hp_data.get("per_level", 0))
		var hp_bonus = base_hp + (per_level * level)
		if hp_bonus > 0:
			unit.max_health += hp_bonus
			unit.current_health += hp_bonus
			changes.append("+%d HP (scaled)" % hp_bonus)

	# Map dodge_chance to evasion stat (voidwalker_phase)
	if passive.effect.has("dodge_chance"):
		var bonus = int(passive.effect.get("dodge_chance", 0))
		if bonus != 0:
			buff_stats["evasion"] = buff_stats.get("evasion", 0) + bonus
			changes.append("+%d EVA" % bonus)

	# Map magic_damage_reduction_percent to resist stat (crystalborn_refraction)
	if passive.effect.has("magic_damage_reduction_percent"):
		var bonus = int(passive.effect.get("magic_damage_reduction_percent", 0))
		if bonus != 0:
			buff_stats["resist"] = buff_stats.get("resist", 0) + bonus
			changes.append("+%d RES" % bonus)

	# Apply non-health bonuses as a tracked buff
	if not buff_stats.is_empty():
		var buff_id = "passive_" + passive.passive_id
		unit.apply_buff(buff_id, buff_stats, 999)  # 999 = effectively permanent for combat

	if changes.size() > 0:
		print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d bonuses=%s (tracked as buff)" % [
			passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level, ", ".join(changes)])
		passive_triggered.emit(unit, passive.passive_id, ", ".join(changes))


## Apply simple race stat bonus passive (elf_keen_sight).
## Uses buff system for tracking so bonuses appear in stat tooltips.
func _apply_race_stat_bonus_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var stat = passive.get_bonus_stat()
	var bonus = passive.get_bonus_value()
	var level = unit.hero_level

	if stat == "" or bonus == 0:
		return

	# Health bonuses are applied directly (not tracked as buff since they affect max HP)
	if stat == "health":
		unit.max_health += bonus
		unit.current_health += bonus
		print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d +%d HP (direct)" % [
			passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level, bonus])
		passive_triggered.emit(unit, passive.passive_id, "+%d HP" % bonus)
		return

	# Apply non-health bonuses as a tracked buff
	var buff_stats = {stat: bonus}
	var buff_id = "passive_" + passive.passive_id
	unit.apply_buff(buff_id, buff_stats, 999)  # 999 = effectively permanent for combat

	print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d +%d %s (tracked as buff)" % [
		passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level, bonus, stat.to_upper()])
	passive_triggered.emit(unit, passive.passive_id, "+%d %s" % [bonus, stat.to_upper()])


## Apply race damage reduction passive (dragonkin_scales).
## Maps damage_reduction_percent to flat DEF+RES buff.
## Burn immunity is handled via race trait_tags ("immune_fire").
func _apply_race_damage_reduction_passive(unit: CombatUnit, passive: PassiveData) -> void:
	var level = unit.hero_level
	var dr_pct = int(passive.effect.get("damage_reduction_percent", 0))
	var changes: Array[String] = []
	var buff_stats: Dictionary = {}

	# Map damage_reduction_percent to defense and resist bonuses
	if dr_pct > 0:
		var def_bonus = int(dr_pct / 2)
		var res_bonus = dr_pct - def_bonus
		if def_bonus > 0:
			buff_stats["defense"] = def_bonus
			changes.append("+%d DEF" % def_bonus)
		if res_bonus > 0:
			buff_stats["resist"] = res_bonus
			changes.append("+%d RES" % res_bonus)

	if not buff_stats.is_empty():
		var buff_id = "passive_" + passive.passive_id
		unit.apply_buff(buff_id, buff_stats, 999)

	if changes.size() > 0:
		print("[RacePassive] id=%s hero=%s name=%s race=%s level=%d bonuses=%s (tracked as buff)" % [
			passive.passive_id, unit.source_id, unit.display_name, unit.race_id, level, ", ".join(changes)])
		passive_triggered.emit(unit, passive.passive_id, ", ".join(changes))


## Apply round-start passives (e.g., verdant_renewal).
## Called at the beginning of each round (after round 1).
func _apply_round_start_passives() -> void:
	for unit in _player_units:
		if not unit.is_alive:
			continue
		for passive_id in [unit.passive_a_id, unit.passive_b_id]:
			if passive_id == "":
				continue
			var passive = DataRegistry.get_passive(passive_id)
			if passive == null:
				continue
			if passive.passive_type == "round_start_heal":
				_apply_verdant_renewal(unit, passive)


## Apply verdant_renewal: heal lowest HP% ally by (3 + level).
func _apply_verdant_renewal(healer: CombatUnit, passive: PassiveData) -> void:
	# Find lowest HP% ally (including self)
	var lowest_unit: CombatUnit = null
	var lowest_hp_pct: float = 2.0  # > 100%

	for ally in _player_units:
		if not ally.is_alive:
			continue
		var hp_pct = float(ally.current_health) / float(ally.max_health)
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			lowest_unit = ally

	if lowest_unit == null:
		return

	# Calculate heal amount: base_bonus (3) + level
	var base_heal = passive.get_bonus_value()  # Should be 3
	var level = healer.hero_level
	var heal_amount = base_heal + level

	var hp_before = lowest_unit.current_health
	var actual_heal = lowest_unit.heal(heal_amount)
	var hp_after = lowest_unit.current_health

	if actual_heal > 0:
		print("[Passive] %s healer=%s level=%d target=%s hp_before=%d hp_after=%d" % [
			passive.passive_id, healer.source_id, level, lowest_unit.source_id, hp_before, hp_after])
		passive_triggered.emit(healer, passive.passive_id, "Healed %s +%d HP" % [lowest_unit.display_name, actual_heal])


# ============================================================================
# EQUIPMENT STAT BONUSES
# ============================================================================

## DEPRECATED: Equipment bonuses are now applied via GameContext.get_hero_effective_stats()
## which is called during CombatUnit.create_hero(). This function is kept as a no-op
## for compatibility but does nothing. Equipment stats are per-hero and include all
## 7 equipment slots: weapon, offhand, helmet, armor, legs, ring, amulet.
func _apply_equipment_bonuses() -> void:
	# No-op: Equipment bonuses already included in hero effective stats
	# See GameContext._get_hero_equipment_stat_bonuses() for implementation
	pass


# ============================================================================
# HP CLAMP (Bug Fix: current_health exceeding max_health)
# ============================================================================

## Clamp all player unit current_health to not exceed max_health.
## Called after all stat bonuses (passives, race, equipment) are applied.
## Fixes bug where persisted HP from previous combat (with bonuses) would be
## restored, then bonuses applied again, causing current_health > max_health.
func _clamp_player_hp() -> void:
	for unit in _player_units:
		if unit.current_health > unit.max_health:
			print("[HP] clamp unit=%s current=%d max=%d (clamped to %d)" % [
				unit.display_name, unit.current_health, unit.max_health, unit.max_health])
			unit.current_health = unit.max_health
		if unit.current_health <= 0:
			unit.is_alive = false
			print("[HP] dead_sync unit=%s hp=%d (marked dead)" % [unit.display_name, unit.current_health])


# ============================================================================
# COMBAT MODIFIER APPLICATION
# ============================================================================

## Apply speed bonuses from combat modifier (call BEFORE TurnQueue initialization).
func _apply_combat_modifier_speeds(modifier: Dictionary) -> void:
	if modifier.is_empty():
		return

	print("[CombatMod] Consumed modifier: %s" % str(modifier))

	# Apply player speed bonus
	var player_spd_bonus = modifier.get("player_spd_bonus", 0)
	if player_spd_bonus != 0:
		for unit in _player_units:
			unit.speed += player_spd_bonus
			print("[CombatMod] %s SPD: %d -> %d (+%d)" % [
				unit.display_name, unit.speed - player_spd_bonus, unit.speed, player_spd_bonus])
		print("[CombatMod] Applied player_spd_bonus=%d to %d heroes" % [player_spd_bonus, _player_units.size()])

	# Apply enemy speed bonus
	var enemy_spd_bonus = modifier.get("enemy_spd_bonus", 0)
	if enemy_spd_bonus != 0:
		for unit in _enemy_units:
			unit.speed += enemy_spd_bonus
			print("[CombatMod] %s SPD: %d -> %d (+%d)" % [
				unit.display_name, unit.speed - enemy_spd_bonus, unit.speed, enemy_spd_bonus])
		print("[CombatMod] Applied enemy_spd_bonus=%d to %d enemies" % [enemy_spd_bonus, _enemy_units.size()])


## Apply non-speed modifier effects (call AFTER units are fully set up).
func _apply_combat_modifier_effects(modifier: Dictionary) -> void:
	if modifier.is_empty():
		return

	# Apply player start damage (damage at combat start, clamp HP to 1 minimum)
	var player_start_damage = modifier.get("player_start_damage", 0)
	if player_start_damage > 0:
		for unit in _player_units:
			# Calculate damage, but clamp so HP never goes below 1
			var max_damage = unit.current_health - 1
			var actual_damage = mini(player_start_damage, max_damage)
			if actual_damage > 0:
				unit.current_health -= actual_damage
				print("[CombatMod] %s takes %d start damage (HP: %d/%d)" % [
					unit.display_name, actual_damage, unit.current_health, unit.max_health])
		print("[CombatMod] Applied player_start_damage=%d to %d heroes (clamped to 1 HP min)" % [
			player_start_damage, _player_units.size()])

	# Apply player defense bonus (consumable buff)
	var player_def_bonus = modifier.get("player_def_bonus", 0)
	if player_def_bonus != 0:
		for unit in _player_units:
			unit.defense += player_def_bonus
			print("[CombatMod] %s DEF: %d -> %d (+%d)" % [
				unit.display_name, unit.defense - player_def_bonus, unit.defense, player_def_bonus])
		print("[CombatMod] Applied player_def_bonus=%d to %d heroes" % [player_def_bonus, _player_units.size()])

	# Apply player evasion bonus (consumable buff)
	var player_eva_bonus = modifier.get("player_eva_bonus", 0)
	if player_eva_bonus != 0:
		for unit in _player_units:
			unit.evasion += player_eva_bonus
			print("[CombatMod] %s EVA: %d -> %d (+%d)" % [
				unit.display_name, unit.evasion - player_eva_bonus, unit.evasion, player_eva_bonus])
		print("[CombatMod] Applied player_eva_bonus=%d to %d heroes" % [player_eva_bonus, _player_units.size()])

	# Apply bonus gold (add directly to dungeon stash)
	var bonus_gold = modifier.get("bonus_gold", 0)
	if bonus_gold > 0:
		GameContext.add_dungeon_gold(bonus_gold)
		print("[CombatMod] Applied bonus_gold=%d to dungeon stash" % bonus_gold)


## Apply pending status effects queued from dungeon events.
func _apply_pending_event_statuses(statuses: Array) -> void:
	for entry in statuses:
		var status_id: String = entry.get("status_id", "")
		var duration: int = entry.get("duration", 2)
		var target_type: String = entry.get("target", "random_hero")
		if status_id == "":
			continue
		match target_type:
			"random_hero":
				var living: Array = _player_units.filter(func(u): return u.is_alive)
				if living.size() > 0:
					var target = living[_rng.randi() % living.size()]
					target.apply_status_v1(status_id, duration, "event")
					print("[CombatMod] Applied %s (%d turns) to %s (from event)" % [status_id, duration, target.display_name])
			"party":
				for unit in _player_units:
					if unit.is_alive:
						unit.apply_status_v1(status_id, duration, "event")
				print("[CombatMod] Applied %s (%d turns) to entire party (from event)" % [status_id, duration])


## Determine which ability a unit should use.
## Heroes + ai_tier 1/3: fixed priority A > B > weapon > basic.
## ai_tier 0 (Feral): basic/weapon only — ignores abilities.
## ai_tier 2 (Tactical): random pick from ready abilities.
func _get_ability_to_use(unit: CombatUnit) -> Dictionary:
	var is_enemy: bool = unit.team == CombatUnit.Team.ENEMY

	# AI Tier 0 (Feral): basic attack only — ignores abilities
	if is_enemy and unit.ai_tier == 0:
		if unit.is_weapon_ability_ready():
			return {"type": "weapon", "ability": null}
		return {"type": "basic", "ability": null}

	# AI Tier 2 (Tactical): random pick from ready abilities
	if is_enemy and unit.ai_tier == 2:
		var ready: Array = []
		if unit.is_ability_a_ready():
			var ab = DataRegistry.get_ability(unit.ability_a_id)
			if ab:
				ready.append({"type": "ability_a", "ability": ab})
		if unit.is_ability_b_ready():
			var ab = DataRegistry.get_ability(unit.ability_b_id)
			if ab:
				ready.append({"type": "ability_b", "ability": ab})
		if not ready.is_empty():
			return ready[_rng.randi() % ready.size()]
		if unit.is_weapon_ability_ready():
			return {"type": "weapon", "ability": null}
		return {"type": "basic", "ability": null}

	# Heroes + AI Tier 1 (Basic) + Tier 3 (Strategic): fixed priority A > B > weapon > basic
	if unit.is_ability_a_ready():
		var ability = DataRegistry.get_ability(unit.ability_a_id)
		if ability != null:
			return {"type": "ability_a", "ability": ability}
	if unit.is_ability_b_ready():
		var ability = DataRegistry.get_ability(unit.ability_b_id)
		if ability != null:
			return {"type": "ability_b", "ability": ability}
	if unit.is_weapon_ability_ready():
		return {"type": "weapon", "ability": null}
	return {"type": "basic", "ability": null}


## Calculate damage for an ability.
## Uses effective attack (base + buff bonuses) for scaling.
func _calculate_ability_damage(unit: CombatUnit, ability: AbilityData) -> int:
	var base = ability.base_damage
	var scaling = ability.attack_scaling
	var eff_atk = unit.get_effective_attack()
	var total = int(base + (eff_atk * scaling))
	return maxi(1, total)


## Apply pre-hit combat modifiers: evasion check, crit roll, armor pen passthrough.
## Returns: { "evaded": bool, "raw_damage": int, "was_crit": bool, "armor_pen": int }
## Call BEFORE take_damage(). After take_damage(), call _apply_post_hit() for thorns/life_steal.
func _apply_pre_hit(attacker: CombatUnit, target: CombatUnit, raw_damage: int, damage_type: String) -> Dictionary:
	var result = { "evaded": false, "raw_damage": raw_damage, "was_crit": false, "armor_pen": 0 }

	# Evasion check
	var evasion_chance = target.get_effective_evasion()
	if evasion_chance > 0:
		var roll = _rng.randi_range(1, 100)
		if roll <= evasion_chance:
			result["evaded"] = true
			print("[Combat] %s evades attack from %s! (roll=%d, evasion=%d%%)" % [
				target.display_name, attacker.display_name, roll, evasion_chance])
			return result

	# Crit check (1.5x damage)
	var crit_chance_val = attacker.get_effective_crit_chance()
	if crit_chance_val > 0:
		var roll = _rng.randi_range(1, 100)
		if roll <= crit_chance_val:
			result["was_crit"] = true
			result["raw_damage"] = int(raw_damage * 1.5)
			print("[Combat] %s CRITICAL HIT! (roll=%d, crit=%d%%, dmg: %d->%d)" % [
				attacker.display_name, roll, crit_chance_val, raw_damage, result["raw_damage"]])

	# Armor penetration (physical only)
	if damage_type == "physical":
		result["armor_pen"] = attacker.get_effective_armor_penetration()

	return result


## Apply post-hit effects: thorns retaliation and life steal.
## Call AFTER take_damage() with the actual damage dealt.
## Emits action_performed for pop text display of secondary effects.
func _apply_post_hit(attacker: CombatUnit, target: CombatUnit, actual_damage: int, damage_type: String) -> void:
	# Thorns: flat damage returned to attacker on physical hits
	if damage_type == "physical" and target.is_alive:
		var thorns_val = target.get_effective_thorns()
		if thorns_val > 0:
			var thorns_dmg = attacker.take_damage(thorns_val, "true")
			print("[Combat] %s takes %d thorns damage from %s!" % [
				attacker.display_name, thorns_dmg, target.display_name])
			# Emit pop text action (no actor_id to suppress attack line)
			var thorns_action = CombatAction.new()
			thorns_action.action_type = CombatAction.ActionType.BUFF
			thorns_action.target_id = attacker.unit_id
			thorns_action.damage_dealt = thorns_dmg
			thorns_action.message = "Thorns: %d" % thorns_dmg
			action_performed.emit(thorns_action)

	# Reflect: return % of damage to attacker
	if target.is_alive and target.reflect_percent > 0 and actual_damage > 0:
		var reflect_dmg = maxi(1, int(actual_damage * target.reflect_percent / 100.0))
		var reflect_actual = attacker.take_damage(reflect_dmg, "magical")
		print("[Combat] %s reflects %d damage to %s! (%d%%)" % [
			target.display_name, reflect_actual, attacker.display_name, target.reflect_percent])
		var reflect_action = CombatAction.new()
		reflect_action.action_type = CombatAction.ActionType.BUFF
		reflect_action.actor_id = target.unit_id
		reflect_action.actor_name = target.display_name
		reflect_action.target_id = attacker.unit_id
		reflect_action.target_name = attacker.display_name
		reflect_action.damage_dealt = reflect_actual
		reflect_action.message = "Reflect: %d" % reflect_actual
		action_performed.emit(reflect_action)

	# Life steal: % of damage dealt healed
	if actual_damage > 0 and attacker.is_alive:
		var ls_pct = attacker.get_effective_life_steal()
		if ls_pct > 0:
			var heal_amount = maxi(1, int(actual_damage * ls_pct / 100.0))
			var actual_heal = attacker.heal(heal_amount)
			if actual_heal > 0:
				print("[Combat] %s life steals %d HP (%d%% of %d)" % [
					attacker.display_name, actual_heal, ls_pct, actual_damage])
				# Emit pop text action (no actor_id to suppress attack line)
				var ls_action = CombatAction.new()
				ls_action.action_type = CombatAction.ActionType.BUFF
				ls_action.target_id = attacker.unit_id
				ls_action.healing_done = actual_heal
				ls_action.message = "Life Steal: +%d HP" % actual_heal
				action_performed.emit(ls_action)

	# Tag effects: on_melee_hit_received (fires on target for physical melee hits)
	if damage_type == "physical" and target.is_alive and attacker.attack_type == "melee":
		_check_tag_effects(target, "on_melee_hit_received", {"attacker": attacker})

	# Tag effects: on_low_hp (fires on target after taking damage)
	if target.is_alive:
		_check_tag_effects(target, "on_low_hp")

	# Death check: attacker may have died from thorns or reflect damage
	if not attacker.is_alive:
		var death_action = CombatAction.create_death(attacker)
		_result.add_action(death_action)
		action_performed.emit(death_action)


## Compute internal status duration from designer-specified duration.
## Adds +1 to account for round-start tick timing, ensuring the status
## produces the intended number of ticks/blocks before expiring.
## e.g., duration=2 → internal=3 → ticks 3→2→1→0 (2 meaningful ticks)
func _compute_internal_status_duration(requested_duration: int) -> int:
	return requested_duration + 1


## Apply status effect from an ability.
## For Status Hooks v1 statuses (like "stun"), uses apply_status_v1().
## For legacy statuses ("stun", "doom"), also uses the old StatusRuntime system.
## Status v1.3: Checks for immunity/resist from race trait_tags before applying.
func _apply_ability_status(target: CombatUnit, ability: AbilityData, source: CombatUnit) -> void:
	var status_id = ability.applies_status_id
	var stacks = ability.status_stacks
	var duration = ability.applies_status_duration

	# Legacy statuses bypass v1.3 resist system
	if status_id == "stun":
		if target.apply_stun(stacks, source.unit_id):
			print("  %s is stunned for %d turn(s)!" % [target.display_name, stacks])
		return
	elif status_id == "doom":
		target.apply_doom(stacks, 5, source.unit_id)
		print("  %s is doomed! (+%d stacks)" % [target.display_name, stacks])
		return

	# Status Hooks v1+ statuses: check resist/immunity first (Status v1.3)
	if not target.is_alive:
		return  # Don't apply statuses to dead targets

	var resist_result = target.would_block_status(status_id)

	# Check immunity
	if resist_result["blocked"]:
		print("[Status] blocked unit=%s id=%s reason=%s source=%s" % [
			target.display_name, status_id, resist_result["reason"], ability.ability_id])
		return

	# Apply duration adjustment from resist (clamp minimum to 1)
	var adjusted_duration = duration + resist_result["duration_delta"]
	adjusted_duration = maxi(1, adjusted_duration)

	if resist_result["duration_delta"] != 0:
		print("[Status] resist unit=%s id=%s requested=%d adjusted=%d reason=%s source=%s" % [
			target.display_name, status_id, duration, adjusted_duration, resist_result["reason"], ability.ability_id])

	# Apply status with adjusted duration
	if adjusted_duration > 0:
		var internal_duration = _compute_internal_status_duration(adjusted_duration)
		target.apply_status_v1(status_id, internal_duration, ability.ability_id)
		if resist_result["duration_delta"] == 0:
			print("[Status] applied unit=%s id=%s duration=%d (internal=%d) source=%s" % [
				target.display_name, status_id, adjusted_duration, internal_duration, ability.ability_id])
		status_changed.emit(target.unit_id)  # Status UI v1.6: Notify UI of status change
	else:
		print("  Applied %s to %s" % [status_id, target.display_name])


## Trigger on_kill passives when a unit kills an enemy.
## target_id is the enemy that was killed.
func _trigger_on_kill_passives(killer: CombatUnit, target_id: String = "") -> void:
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

		# Handle on_kill_stacking_buff: stacking stat buff on kill (e.g., killer_instinct, void_resonance)
		if passive.passive_type == "on_kill_stacking_buff":
			var max_stacks = passive.get_effect_max_stacks()
			# Check if already at max stacks
			if killer.killer_instinct_stacks >= max_stacks:
				print("[Passive] %s hero=%s name=%s stacks=%d (max reached)" % [
					passive_id, killer.source_id, killer.display_name, killer.killer_instinct_stacks])
				continue
			# void_resonance uses flat bonus; all others use legacy level-scaled formula
			var atk_per_stack: int
			if passive_id == "void_resonance":
				atk_per_stack = passive.get_bonus_value()
			else:
				atk_per_stack = passive.get_bonus_value() + int(killer.hero_level / 2)
			var atk_before = killer.attack
			killer.killer_instinct_stacks += 1
			killer.attack += atk_per_stack
			var atk_after = killer.attack
			print("[Passive] %s hero=%s name=%s stacks=%d/%d atk_before=%d atk_after=%d target=%s" % [
				passive_id, killer.source_id, killer.display_name,
				killer.killer_instinct_stacks, max_stacks, atk_before, atk_after, target_id])
			passive_triggered.emit(killer, passive_id, "+%d ATK (stack %d/%d)" % [atk_per_stack, killer.killer_instinct_stacks, max_stacks])
			continue

		# Legacy: Apply on_kill weapon cooldown reduction
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

	if not _is_combat_active or _awaiting_player_input:
		return _pending_actions

	# Continue multi-action unit if they have remaining actions
	if _current_multi_action_unit != null:
		var remaining = _unit_remaining_actions.get(_current_multi_action_unit.unit_id, 0)
		if remaining > 0 and _current_multi_action_unit.is_alive:
			_process_unit_turn_step(_current_multi_action_unit)
			# After processing, check if we need to emit signal
			if not _check_combat_end():
				if not _awaiting_player_input:
					# Signal to continue — whether turn ended or unit has more actions
					combat_continue_ready.emit()
			return _pending_actions
		else:
			# Done with this unit
			_current_multi_action_unit = null
			_turn_queue.advance()

	# Check if round is complete, start new round if needed
	if _turn_queue.is_round_complete():
		_current_round += 1
		_result.total_rounds = _current_round
		# Tick temporary buffs BEFORE rebuilding turn order (speed buffs affect order)
		_tick_all_buffs()
		# Tick status effects AFTER buffs (Status Hooks v1)
		_tick_all_statuses()
		_turn_queue.start_new_round()
		_apply_round_start_passives()  # Trigger round-start passives (e.g., verdant_renewal)
		_process_round_start_tag_effects()  # T4 round_start tag effects (e.g., regen)
		_process_round_start_deaths()  # Emit death actions for DOT/tag kills
		_unit_remaining_actions.clear()  # Reset action counts for new round
		round_ended.emit(_current_round)
		if _check_combat_end():
			return _pending_actions

	# Get next unit
	var unit = _turn_queue.get_next_unit()
	if unit == null:
		return _pending_actions

	# Initialize action count for this unit if not already set
	if not _unit_remaining_actions.has(unit.unit_id):
		var eff_speed = unit.get_effective_speed()
		_unit_remaining_actions[unit.unit_id] = _calculate_actions_for_speed(eff_speed)
		print("[MultiAction] unit=%s speed=%d actions=%d" % [
			unit.display_name, eff_speed, _unit_remaining_actions[unit.unit_id]])

	_current_multi_action_unit = unit

	# Process this unit's turn
	_process_unit_turn_step(unit)

	# Check combat end (don't advance queue here - handled by _consume_action)
	if not _check_combat_end():
		# If not awaiting player input, signal to continue
		if not _awaiting_player_input:
			combat_continue_ready.emit()

	return _pending_actions


## Tick temporary buffs on all units (called at round start).
func _tick_all_buffs() -> void:
	for unit in _all_units:
		if unit.is_alive:
			if unit.has_active_buffs():
				unit.tick_buffs()
			unit.tick_shield()
			unit.tick_reflect()


## Tick status effects on all units (called at round start, after buffs).
## Status Hooks v1.2.1 - lifecycle ticking with DOT damage handled internally.
## Status UI v2: Collects expired statuses into last_expired_statuses for pop-text.
func _tick_all_statuses() -> void:
	last_expired_statuses.clear()
	for unit in _all_units:
		if unit.active_statuses.size() > 0:
			var expired = unit.tick_statuses()  # Returns Array of expired status IDs
			if expired.size() > 0:
				last_expired_statuses[unit.unit_id] = expired
	all_statuses_ticked.emit()  # Status UI v1.6: Notify UI to refresh all badges


## Check for deaths caused by round-start effects (DOT, tag damage).
## Units killed by status ticks or tag effects need death actions emitted
## so the UI updates and targeting correctly excludes them.
func _process_round_start_deaths() -> void:
	for unit in _all_units:
		if not unit.is_alive and not unit.get_meta("death_emitted", false):
			unit.set_meta("death_emitted", true)
			print("[Combat] %s died from round-start effects (DOT/tag)" % unit.display_name)
			var death_action = CombatAction.create_death(unit)
			_pending_actions.append(death_action)
			_result.add_action(death_action)
			action_performed.emit(death_action)


## Get list of defeated enemy monster_ids (source_id for dead enemies).
## Used by SideQuestSystem for kill tracking.
func get_defeated_enemy_ids() -> Array:
	var result: Array = []
	for unit in _enemy_units:
		if unit.current_health <= 0:
			result.append(unit.source_id)
	return result


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

	# Status v1.6: get sorted snapshot of active_statuses for UI badges
	var v1_statuses = unit.get_status_snapshot_sorted()

	# Status UI v1.7: get sorted snapshot of active_buffs for UI badges
	var v1_buffs = unit.get_buff_snapshot_sorted()

	var team_str = "player" if unit.team == CombatUnit.Team.PLAYER else "enemy"

	# Include effective stats (base + buff bonuses) for UI display
	return {
		"id": unit.unit_id,
		"source_id": unit.source_id,
		"class_id": unit.class_id,
		"name": unit.display_name,
		"hp": unit.current_health,
		"max_hp": unit.max_health,
		"base_hp": unit.max_health,
		"speed": unit.get_effective_speed(),
		"attack": unit.get_effective_attack(),
		"defense": unit.get_effective_defense(),
		"base_speed": unit.speed,
		"base_attack": unit.attack,
		"base_defense": unit.defense,
		"crit_chance": unit.get_effective_crit_chance(),
		"evasion": unit.get_effective_evasion(),
		"resist": unit.get_effective_resist(),
		"thorns": unit.get_effective_thorns(),
		"armor_penetration": unit.get_effective_armor_penetration(),
		"life_steal": unit.get_effective_life_steal(),
		"weapon_cooldown": unit.weapon_ability_cooldown,
		"weapon_max_cooldown": unit.weapon_ability_max_cooldown,
		"ability_a_id": unit.ability_a_id,
		"ability_b_id": unit.ability_b_id,
		"ability_a_cooldown": unit.ability_a_cooldown,
		"ability_b_cooldown": unit.ability_b_cooldown,
		"passive_a_id": unit.passive_a_id,
		"passive_b_id": unit.passive_b_id,
		"statuses": statuses,
		"active_statuses_v1": v1_statuses,
		"active_buffs": unit.active_buffs.size(),
		"active_buffs_v1": v1_buffs,  # Status UI v1.7: Buff snapshots for UI
		"is_alive": unit.is_alive,
		"team": team_str,
		"pos": {"x": unit.grid_x, "y": unit.grid_y},
		"team_pos_key": "%s:%d,%d" % [team_str, unit.grid_x, unit.grid_y],
		"portrait_path": _get_unit_portrait(unit),
		"shield_hp": unit.shield_hp,
		"shield_remaining_rounds": unit.shield_remaining_rounds,
		"reflect_percent": unit.reflect_percent,
		"attack_type": unit.attack_type,
	}


## Get portrait path for a combat unit (hero or monster).
func _get_unit_portrait(unit: CombatUnit) -> String:
	if unit.team == CombatUnit.Team.PLAYER:
		var hero = GameContext.get_hero(unit.source_id)
		return hero.get("portrait_path", "") if not hero.is_empty() else ""
	else:
		var monster = DataRegistry.get_monster(unit.source_id)
		return monster.portrait_path if monster != null else ""


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


## Status UI v1.6.1: Public accessor for CombatUnit by ID.
## Returns the CombatUnit or null if not found.
func get_unit_by_id(unit_id: String) -> CombatUnit:
	return _find_unit_by_id(unit_id)


## DEV TOOL: Buff all enemy stats by a multiplier (e.g., 1.25 = +25%).
## Increases ATK, DEF, SPD, and HP (both max and current proportionally).
func buff_all_enemies(multiplier: float) -> void:
	for unit in _enemy_units:
		if unit == null or not unit.is_alive:
			continue
		# Store HP ratio to preserve after max HP change
		var hp_ratio = float(unit.current_health) / float(unit.max_health) if unit.max_health > 0 else 1.0

		# Buff stats
		unit.attack = int(unit.attack * multiplier)
		unit.defense = int(unit.defense * multiplier)
		unit.speed = int(unit.speed * multiplier)
		unit.max_health = int(unit.max_health * multiplier)
		unit.current_health = int(unit.max_health * hp_ratio)  # Maintain HP ratio

		print("[DevBuff] %s: ATK=%d DEF=%d SPD=%d HP=%d/%d" % [
			unit.display_name, unit.attack, unit.defense, unit.speed,
			unit.current_health, unit.max_health])


## Get CombatUnit by source_id (hero_id or monster_id).
## Used for looking up combat units when you only have the GameContext hero_id.
func get_unit_by_source_id(source_id: String) -> CombatUnit:
	for unit in _all_units:
		if unit.source_id == source_id:
			return unit
	return null


## Get combat stats for a unit as a safe dictionary (avoids RefCounted property access issues).
## Returns {"valid": false} if unit not found or invalid.
## Uses get() for ALL property access to prevent crashes on RefCounted objects.
## Accepts either source_id (hero_id) or unit_id for flexible lookup.
func get_unit_combat_stats(lookup_id: String) -> Dictionary:
	DebugLog.combat("get_unit_combat_stats called with lookup_id=%s, _all_units.size()=%d" % [lookup_id, _all_units.size()])
	for unit in _all_units:
		if unit == null:
			continue
		# Use get() for safe property access on RefCounted objects
		var src_id = unit.get("source_id")
		var u_id = unit.get("unit_id")
		var alive = unit.get("is_alive")
		DebugLog.combat("  Checking unit: source_id=%s, unit_id=%s, alive=%s" % [str(src_id), str(u_id), str(alive)])
		# Match by either source_id or unit_id
		if (src_id != lookup_id and u_id != lookup_id) or alive != true:
			continue
		# Safely get all stats using get() - returns null if property access fails
		# NOTE: Properties are current_health and max_health (not current_hp/max_hp)
		var hp = unit.get("current_health")
		var max_hp_val = unit.get("max_health")
		if hp == null or max_hp_val == null:
			DebugLog.warn("  Found unit but current_health/max_health is null")
			continue
		# For methods, check they exist and call safely
		var attack_val = 0
		var defense_val = 0
		var speed_val = 0
		if unit.has_method("get_effective_attack"):
			attack_val = unit.get_effective_attack()
		if unit.has_method("get_effective_defense"):
			defense_val = unit.get_effective_defense()
		if unit.has_method("get_effective_speed"):
			speed_val = unit.get_effective_speed()
		DebugLog.combat("  FOUND: hp=%d/%d atk=%d def=%d spd=%d" % [hp, max_hp_val, attack_val, defense_val, speed_val])
		return {
			"current_hp": hp,
			"max_hp": max_hp_val,
			"attack": attack_val,
			"defense": defense_val,
			"speed": speed_val,
			"valid": true
		}
	DebugLog.warn("get_unit_combat_stats: unit not found for lookup_id=%s" % lookup_id)
	return {"valid": false}


## Status UI v1.6.2: Get sorted status snapshot for a specific unit.
## Returns empty Array if unit not found. Used by CombatScene for efficient badge refresh.
func get_unit_status_snapshot_sorted(unit_id: String) -> Array:
	var unit = _find_unit_by_id(unit_id)
	if unit == null or not unit.is_alive:
		return []
	return unit.get_status_snapshot_sorted()


## Status UI v1.7: Get sorted buff snapshot for a specific unit.
## Returns empty Array if unit not found. Used by CombatScene for buff badge refresh.
func get_unit_buff_snapshot_sorted(unit_id: String) -> Array:
	var unit = _find_unit_by_id(unit_id)
	if unit == null or not unit.is_alive:
		return []
	return unit.get_buff_snapshot_sorted()


## v1.9B: Get turn timeline snapshot showing all alive units in the full round order.
## Returns Array of {unit_id, name, team, speed, is_current, has_acted, portrait_path, intent}.
func get_turn_timeline_snapshot(_count: int = 6) -> Array:
	if _turn_queue == null:
		return []
	var snapshot = _turn_queue.get_full_round_snapshot()
	for entry in snapshot:
		var unit = get_unit_by_id(entry["unit_id"])
		entry["portrait_path"] = _get_unit_portrait(unit) if unit != null else ""
		entry["intent"] = get_unit_intent_preview(entry["unit_id"]) if unit != null else {}
	return snapshot


## Get reordered timeline: upcoming units first, then acted units (for "move to end" display).
func get_reordered_timeline_snapshot() -> Array:
	if _turn_queue == null:
		return []
	var snapshot = _turn_queue.get_reordered_round_snapshot()
	for entry in snapshot:
		var unit = get_unit_by_id(entry["unit_id"])
		entry["portrait_path"] = _get_unit_portrait(unit) if unit != null else ""
		entry["intent"] = get_unit_intent_preview(entry["unit_id"]) if unit != null else {}
	return snapshot


## Predict what a unit will do on its next turn (read-only, no side effects).
## Returns dict with action_type, ability_name, ability_desc, target_name, ready_abilities, is_stunned.
func get_unit_intent_preview(unit_id: String) -> Dictionary:
	var unit = get_unit_by_id(unit_id)
	if unit == null:
		return {}

	var result: Dictionary = {
		"action_type": "",
		"ability_name": "",
		"ability_desc": "",
		"target_name": "",
		"target_rule": "",
		"is_player": unit.team == CombatUnit.Team.PLAYER,
		"ready_abilities": [],
		"is_stunned": false,
	}

	# Check stun
	if unit.has_status_v1("stunned"):
		result["is_stunned"] = true
		result["action_type"] = "stunned"
		return result

	# Player heroes: list abilities with cooldown info
	if unit.team == CombatUnit.Team.PLAYER:
		result["action_type"] = "player"
		if unit.ability_a_id != "":
			var ab = DataRegistry.get_ability(unit.ability_a_id)
			if ab:
				result["ready_abilities"].append({
					"name": ab.display_name,
					"desc": ab.description,
					"ready": unit.is_ability_a_ready(),
					"cooldown": unit.ability_a_cooldown,
				})
		if unit.ability_b_id != "":
			var ab = DataRegistry.get_ability(unit.ability_b_id)
			if ab:
				result["ready_abilities"].append({
					"name": ab.display_name,
					"desc": ab.description,
					"ready": unit.is_ability_b_ready(),
					"cooldown": unit.ability_b_cooldown,
				})
		if unit.weapon_ability_id != "":
			result["ready_abilities"].append({
				"name": "Weapon Attack",
				"desc": "1.5x attack damage",
				"ready": unit.is_weapon_ability_ready(),
				"cooldown": unit.weapon_ability_cooldown,
			})
		return result

	# Tactical enemies (ai_tier 2): can't predict due to RNG, list ready abilities
	if unit.ai_tier == 2:
		result["action_type"] = "tactical"
		if unit.ability_a_id != "" and unit.is_ability_a_ready():
			var ab = DataRegistry.get_ability(unit.ability_a_id)
			if ab:
				result["ready_abilities"].append({"name": ab.display_name, "desc": ab.description})
		if unit.ability_b_id != "" and unit.is_ability_b_ready():
			var ab = DataRegistry.get_ability(unit.ability_b_id)
			if ab:
				result["ready_abilities"].append({"name": ab.display_name, "desc": ab.description})
		if unit.is_weapon_ability_ready():
			result["ready_abilities"].append({"name": "Weapon Attack", "desc": ""})
		if result["ready_abilities"].is_empty():
			result["ready_abilities"].append({"name": "Basic Attack", "desc": ""})
		return result

	# Deterministic enemies (ai_tier 0, 1, 3): predict exact action
	var choice = _get_ability_to_use(unit)
	var ability: AbilityData = choice["ability"]

	if ability != null:
		result["action_type"] = "ability"
		result["ability_name"] = ability.display_name
		result["ability_desc"] = ability.description
		var target = _pick_target_for_ability(unit, ability)
		if target != null:
			result["target_name"] = target.display_name
		result["target_rule"] = ability.target_rule
	else:
		result["action_type"] = choice["type"]
		result["ability_name"] = "Weapon Attack" if choice["type"] == "weapon" else "Basic Attack"
		var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
		var target = _targeting_policy.select_target(unit, enemies)
		if target != null:
			result["target_name"] = target.display_name

	return result


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
		# Tick temporary buffs BEFORE rebuilding turn order (speed buffs affect order)
		_tick_all_buffs()
		# Tick status effects AFTER buffs (Status Hooks v1)
		_tick_all_statuses()
		_turn_queue.start_new_round()
		_apply_round_start_passives()  # Trigger round-start passives (e.g., verdant_renewal)
		_process_round_start_tag_effects()  # T4 round_start tag effects (e.g., regen)
		_process_round_start_deaths()  # Emit death actions for DOT/tag kills
		if _check_combat_end():
			return

	if _current_round >= MAX_ROUNDS:
		print("[CombatController] Combat ended: MAX ROUNDS reached")


func _process_unit_turn(unit: CombatUnit) -> void:
	_current_turn += 1
	_result.total_turns = _current_turn

	print("\n[Turn %d] %s's turn" % [_current_turn, unit.display_name])
	turn_started.emit(unit)

	# Process turn start - check if stunned (legacy StatusRuntime)
	var can_act = unit.statuses.process_turn_start()

	# Also check Status Hooks v1 "stun" status
	if can_act and unit.is_action_blocked_by_status():
		can_act = false

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
	# v2.1 Fix: Guard against null unit to prevent crash
	if unit == null:
		push_warning("[Combat] _process_unit_turn_step called with null unit, skipping turn")
		return

	_current_turn += 1
	_result.total_turns = _current_turn

	# Emit multi-action update for UI
	var total_actions = _calculate_actions_for_speed(unit.get_effective_speed())
	var remaining = _unit_remaining_actions.get(unit.unit_id, 1)
	multi_action_update.emit(unit, remaining, total_actions)

	turn_started.emit(unit)

	# Process turn start - check if stunned (legacy StatusRuntime)
	var can_act = unit.statuses.process_turn_start()

	# Also check Status Hooks v1 "stun" status
	if can_act and unit.is_action_blocked_by_status():
		can_act = false

	if not can_act:
		var action = CombatAction.create_skip(unit, "Stunned!")
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		_finish_unit_action(unit)
		return

	# Branch: Player vs Enemy
	if unit.team == CombatUnit.Team.PLAYER:
		# Player turn - wait for input
		_awaiting_player_input = true
		_input_unit = unit
		var available = _get_available_actions(unit)
		print("[Combat] Emitting player_input_required for %s (actions=%d)" % [unit.display_name, available.size()])
		player_input_required.emit(unit, available)
		print("[Combat] player_input_required emitted, awaiting_player_input=%s" % str(_awaiting_player_input))
		# Do NOT continue - wait for player input via submit_player_action/target
	else:
		# Enemy AI - auto-use consumable and execute
		_try_auto_use_consumable(unit)
		_execute_unit_action_step(unit)
		_finish_unit_action(unit)


## Finish a unit's action: process doom, consume action.
## Note: Cooldowns tick in _consume_action() when the unit's full turn ends (not per action).
func _finish_unit_action(unit: CombatUnit) -> void:
	# Process doom damage (happens per action for consistent behavior)
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

	# Consume action and potentially advance queue
	_consume_action(unit)


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
	var eff_atk = unit.get_effective_attack()

	if ability != null:
		# Class ability damage (uses effective attack via _calculate_ability_damage)
		raw_damage = _calculate_ability_damage(unit, ability)
		damage_type = ability.damage_type
		print("  %s uses %s!" % [unit.display_name, ability.display_name])
	elif ability_type == "weapon":
		# Weapon ability damage (1.5x effective attack)
		raw_damage = int(eff_atk * 1.5)
	else:
		# Basic attack (uses effective attack)
		raw_damage = eff_atk

	# Apply combat stat modifiers (evasion, crit, armor_pen)
	var hit = _apply_pre_hit(unit, target, raw_damage, damage_type)
	if hit["evaded"]:
		var action = CombatAction.create_attack(unit, target, 0, is_ability)
		action.was_evaded = true
		action.message = "%s's attack was evaded by %s!" % [unit.display_name, target.display_name]
		_result.add_action(action)
		action_performed.emit(action)
		# Still put ability on cooldown
		match ability_type:
			"ability_a": unit.use_ability_a()
			"ability_b": unit.use_ability_b()
			"weapon": unit.use_weapon_ability()
		return

	var actual_damage = target.take_damage(hit["raw_damage"], damage_type, hit["armor_pen"])
	_apply_post_hit(unit, target, actual_damage, damage_type)

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	action.was_critical = hit["was_crit"]
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

	# Tag effects: on_attack (basic/weapon attacks only, not class abilities)
	if ability == null or ability_type in ["basic", "weapon"]:
		_check_tag_effects(unit, "on_attack", {"target": target})

	if not target.is_alive:
		status_changed.emit(target.unit_id)  # Clear status badges on death
		var death_action = CombatAction.create_death(target)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)  # M4: on_kill passive trigger
		_check_tag_effects(unit, "on_kill")


func _execute_unit_action_step(unit: CombatUnit) -> void:
	# M4: Determine ability to use (priority: Active A > Active B > Weapon > Basic)
	var ability_choice = _get_ability_to_use(unit)
	var ability_type = ability_choice["type"]
	var ability: AbilityData = ability_choice["ability"]

	# Log AI decision in required format
	var chose_id = ability.ability_id if ability != null else ability_type
	print("[AI] actor=%s chose=%s cdA=%d cdB=%d" % [
		unit.display_name, chose_id, unit.ability_a_cooldown, unit.ability_b_cooldown])

	# Route class abilities to specialized handler
	if ability != null:
		_execute_class_ability_step(unit, ability, ability_type)
		return

	# Use targeting policy for weapon/basic attacks
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		# v1.9B: Emit intent even with no target
		intent_decided.emit(unit.unit_id, ability_type, "", "")
		return

	# v1.9B: Emit intent before execution
	intent_decided.emit(unit.unit_id, ability_type, "", target.unit_id)

	var raw_damage: int
	var is_ability: bool = ability_type != "basic"
	var eff_atk = unit.get_effective_attack()

	if ability_type == "weapon":
		# Weapon ability damage (1.5x effective attack)
		raw_damage = int(eff_atk * 1.5)
	else:
		# Basic attack (uses effective attack)
		raw_damage = eff_atk

	# Apply combat stat modifiers (evasion, crit, armor_pen)
	var hit = _apply_pre_hit(unit, target, raw_damage, "physical")
	if hit["evaded"]:
		var action = CombatAction.create_attack(unit, target, 0, is_ability)
		action.was_evaded = true
		action.message = "%s's attack was evaded by %s!" % [unit.display_name, target.display_name]
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		if ability_type == "weapon":
			unit.use_weapon_ability()
		return

	var actual_damage = target.take_damage(hit["raw_damage"], "physical", hit["armor_pen"])
	_apply_post_hit(unit, target, actual_damage, "physical")

	# Tag effects: on_attack (basic/weapon attacks in step mode)
	_check_tag_effects(unit, "on_attack", {"target": target})

	var action = CombatAction.create_attack(unit, target, actual_damage, is_ability)
	action.was_critical = hit["was_crit"]
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	if ability_type == "weapon":
		unit.use_weapon_ability()

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)
		_check_tag_effects(unit, "on_kill")


# ============================================================================
# ABILITY TARGETING v1 - Data-driven target selection
# ============================================================================

## Pick a target for an ability based on its targeting data.
## Returns the selected target, or null if no valid target exists.
## Logs: [Target] ability=<id> caster=<name> picked=<target_name|none> team=<ally/enemy/self> rule=<rule> reason=<ok|no_valid_target|fallback_attack>
func _pick_target_for_ability(caster: CombatUnit, ability: AbilityData) -> CombatUnit:
	var target_team = ability.target_team
	var target_rule = ability.target_rule
	var allow_self = ability.allow_self_target

	# Determine candidate pool based on target_team
	var candidates: Array = []

	if target_team == "self":
		# Self-targeting: only the caster
		candidates = [caster] if caster.is_alive else []
	elif target_team == "ally":
		# Ally targeting: same team as caster
		candidates = _player_units if caster.team == CombatUnit.Team.PLAYER else _enemy_units
		candidates = candidates.filter(func(u): return u.is_alive)
		# Remove self unless allowed
		if not allow_self:
			candidates = candidates.filter(func(u): return u != caster)
		# If no allies remain and self is allowed, include self
		if candidates.is_empty() and allow_self and caster.is_alive:
			candidates = [caster]
	elif target_team == "enemy":
		# Enemy targeting: opposite team
		candidates = _enemy_units if caster.team == CombatUnit.Team.PLAYER else _player_units
		candidates = candidates.filter(func(u): return u.is_alive)

	# If no candidates, log and return null
	if candidates.is_empty():
		print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=no_valid_target" % [
			ability.ability_id, caster.display_name, target_team, target_rule])
		return null

	# Taunt enforcement: if targeting enemies and any candidate is taunting, force target
	if target_team == "enemy":
		for c in candidates:
			if c.has_status_v1("taunting"):
				print("[Target] ability=%s caster=%s picked=%s team=%s rule=%s reason=taunt_forced" % [
					ability.ability_id, caster.display_name, c.display_name, target_team, target_rule])
				return c

	# Apply target_rule to select from candidates
	var target: CombatUnit = null

	match target_rule:
		"any":
			# Pick first for determinism
			target = candidates[0]
		"lowest_hp_pct":
			# Pick ally/enemy with lowest HP percentage
			var lowest_pct: float = 2.0
			for c in candidates:
				var pct = float(c.current_health) / float(c.max_health)
				if pct < lowest_pct:
					lowest_pct = pct
					target = c
		"lowest_hp_abs":
			# Pick target with lowest absolute HP
			var lowest_hp: int = 999999
			for c in candidates:
				if c.current_health < lowest_hp:
					lowest_hp = c.current_health
					target = c
		"highest_atk":
			# Pick target with highest attack
			var highest_atk: int = -1
			for c in candidates:
				var atk = c.get_effective_attack()
				if atk > highest_atk:
					highest_atk = atk
					target = c
		"unbuffed":
			# Pick an unbuffed ally (no active_buffs); fallback to lowest_hp_pct if all buffed
			for c in candidates:
				if not c.has_active_buffs():
					target = c
					break
			# Fallback: lowest HP% if all are buffed
			if target == null:
				var lowest_pct: float = 2.0
				for c in candidates:
					var pct = float(c.current_health) / float(c.max_health)
					if pct < lowest_pct:
						lowest_pct = pct
						target = c
		_:
			# Default: pick first
			target = candidates[0]

	# Log target selection
	if target != null:
		print("[Target] ability=%s caster=%s picked=%s team=%s rule=%s reason=ok" % [
			ability.ability_id, caster.display_name, target.display_name, target_team, target_rule])
	else:
		print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=no_valid_target" % [
			ability.ability_id, caster.display_name, target_team, target_rule])

	return target


## Attempt to pick a target for ability; fallback to basic attack if needed.
## Returns a dict with "target" and "fallback" keys.
func _pick_target_with_fallback(caster: CombatUnit, ability: AbilityData) -> Dictionary:
	var target = _pick_target_for_ability(caster, ability)

	if target != null:
		return {"target": target, "fallback": false}

	# Fallback logic based on ability type
	# For heal/buff: fallback to self if allow_self_target, else skip ability and use basic attack
	if ability.effect_type in ["heal", "buff"]:
		if ability.allow_self_target and caster.is_alive:
			print("[Target] ability=%s caster=%s picked=%s team=self rule=fallback_self reason=fallback_attack" % [
				ability.ability_id, caster.display_name, caster.display_name])
			return {"target": caster, "fallback": false}
		else:
			# Fall back to basic attack on enemy
			print("[Target] ability=%s caster=%s picked=none team=%s rule=%s reason=fallback_attack" % [
				ability.ability_id, caster.display_name, ability.target_team, ability.target_rule])
			return {"target": null, "fallback": true}

	# For damage: fallback to any alive enemy
	if ability.effect_type == "damage":
		var enemies = _enemy_units if caster.team == CombatUnit.Team.PLAYER else _player_units
		for e in enemies:
			if e.is_alive:
				print("[Target] ability=%s caster=%s picked=%s team=enemy rule=any reason=fallback_attack" % [
					ability.ability_id, caster.display_name, e.display_name])
				return {"target": e, "fallback": false}

	return {"target": null, "fallback": true}


# ============================================================================
# CLASS ABILITY EXECUTION (Ability Execution v1)
# ============================================================================

## Execute a class ability based on its effect_type and target_type.
func _execute_class_ability_step(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	print("[Ability] %s uses %s (effect=%s, target=%s, team=%s, rule=%s)" % [
		unit.display_name, ability.display_name, ability.effect_type, ability.target_type,
		ability.target_team, ability.target_rule])

	# NG+: Track seen abilities for infusion system
	if ability != null and ability.ability_id != "":
		GameContext.mark_ability_seen(ability.ability_id)

	# v1.9B: Pre-determine target for intent signal
	var intent_target_id = ""
	if ability.effect_type == "damage":
		var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
		var intent_target = _targeting_policy.select_target(unit, enemies)
		if intent_target != null:
			intent_target_id = intent_target.unit_id
	elif ability.effect_type in ["heal", "buff"]:
		var pick_result = _pick_target_for_ability(unit, ability)
		if pick_result != null:
			intent_target_id = pick_result.unit_id
	intent_decided.emit(unit.unit_id, "class_ability", ability.ability_id, intent_target_id)

	# Route based on effect_type (pass player_target so player's choice is respected)
	match ability.effect_type:
		"damage":
			_execute_damage_ability(unit, ability, ability_type, player_target)
		"heal":
			# Check for cleansing heal (all_allies + cleanses_debuffs)
			if ability.target_type == "all_allies" and ability.cleanses_debuffs > 0:
				_execute_cleanse_heal_ability(unit, ability, ability_type)
			elif ability.target_type == "all_allies":
				_execute_aoe_heal_ability(unit, ability, ability_type)
			else:
				_execute_heal_ability(unit, ability, ability_type, player_target)
		"buff":
			# Check for AoE buff (all_allies)
			if ability.target_type == "all_allies":
				_execute_aoe_buff_ability(unit, ability, ability_type)
			else:
				_execute_buff_ability(unit, ability, ability_type, player_target)
		"damage_and_heal":
			_execute_drain_ability(unit, ability, ability_type, player_target)
		"debuff":
			# Debuff-only abilities (e.g., void_anchor)
			_execute_debuff_ability(unit, ability, ability_type, player_target)
		_:
			# Fallback: treat as damage ability
			_execute_damage_ability(unit, ability, ability_type, player_target)

	# Tag effects: on_ability_use (fires after any class/equip ability)
	_check_tag_effects(unit, "on_ability_use")


## Execute a damage-type ability (guardian_challenge, aegis_slam, twin_strike).
## Supports single target and AoE (all_enemies) abilities.
## player_target: if provided, use the player's chosen target instead of AI policy.
func _execute_damage_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)

	# Check for AoE ability (all_enemies)
	if ability.target_type == "all_enemies":
		_execute_aoe_damage_ability(unit, ability, ability_type, enemies)
		return

	# Single target: use player's selection if available, else AI targeting policy
	var target: CombatUnit = null
	if player_target != null and player_target.is_alive:
		target = player_target
	else:
		target = _targeting_policy.select_target(unit, enemies)

	if target == null:
		return

	# Handle multi-hit abilities (twin_strike)
	var hits = ability.hit_count if ability.hit_count > 0 else 1
	var total_damage = 0
	var hits_landed = 0
	var any_crit = false

	for i in range(hits):
		# Check if target died mid-combo (skip remaining hits)
		if not target.is_alive:
			for j in range(i, hits):
				print("[Ability] %s caster=%s target=%s dmg=0 hit=%d/%d (skipped - target dead)" % [
					ability.ability_id, unit.display_name, target.display_name, j + 1, hits])
			break

		var raw_damage = _calculate_ability_damage(unit, ability)
		var actual_damage: int

		if ability.armor_piercing:
			# Armor piercing = true damage, but still apply evasion/crit
			var hit = _apply_pre_hit(unit, target, raw_damage, "true")
			if hit["evaded"]:
				print("[Ability] %s caster=%s target=%s hit=%d/%d EVADED" % [
					ability.ability_id, unit.display_name, target.display_name, i + 1, hits])
				continue
			if hit["was_crit"]:
				any_crit = true
			actual_damage = target.take_damage(hit["raw_damage"], "true")
		else:
			var hit = _apply_pre_hit(unit, target, raw_damage, ability.damage_type)
			if hit["evaded"]:
				print("[Ability] %s caster=%s target=%s hit=%d/%d EVADED" % [
					ability.ability_id, unit.display_name, target.display_name, i + 1, hits])
				continue
			if hit["was_crit"]:
				any_crit = true
			actual_damage = target.take_damage(hit["raw_damage"], ability.damage_type, hit["armor_pen"])

		_apply_post_hit(unit, target, actual_damage, ability.damage_type)
		total_damage += actual_damage
		hits_landed += 1

		print("[Ability] %s caster=%s target=%s dmg=%d hit=%d/%d%s%s" % [
			ability.ability_id, unit.display_name, target.display_name, actual_damage, i + 1, hits,
			" (piercing)" if ability.armor_piercing else "",
			" (CRIT)" if any_crit else ""])

	# Create action for UI
	var action = CombatAction.create_ability_attack(unit, target, ability.ability_id, ability.display_name, total_damage)
	action.was_critical = any_crit
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])

	# Apply status effect if ability has one
	if ability.applies_status_id != "":
		_apply_ability_status(target, ability, unit)

	# Apply enemy debuff if ability has one (e.g., entropy_blast)
	if not ability.enemy_debuff.is_empty():
		_apply_enemy_debuff(target, ability.enemy_debuff, ability.ability_id)

	# Apply self buff/debuff if ability has them (e.g., fungal_frenzy)
	_apply_self_effects(unit, ability)

	# Handle death
	if not target.is_alive:
		status_changed.emit(target.unit_id)  # Clear status badges on death
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)
		_check_tag_effects(unit, "on_kill")


## Execute an AoE damage ability (spore_cloud, storm_surge, etc.)
func _execute_aoe_damage_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, enemies: Array) -> void:
	var alive_enemies = enemies.filter(func(e): return e.is_alive)
	if alive_enemies.is_empty():
		return

	var total_damage = 0
	var targets_hit = 0
	var any_crit = false

	for enemy in alive_enemies:
		var raw_damage = _calculate_ability_damage(unit, ability)
		var actual_damage: int

		if ability.armor_piercing:
			var hit = _apply_pre_hit(unit, enemy, raw_damage, "true")
			if hit["evaded"]:
				print("[Ability] %s caster=%s target=%s EVADED (AoE)" % [
					ability.ability_id, unit.display_name, enemy.display_name])
				continue
			if hit["was_crit"]:
				any_crit = true
			actual_damage = enemy.take_damage(hit["raw_damage"], "true")
		else:
			var hit = _apply_pre_hit(unit, enemy, raw_damage, ability.damage_type)
			if hit["evaded"]:
				print("[Ability] %s caster=%s target=%s EVADED (AoE)" % [
					ability.ability_id, unit.display_name, enemy.display_name])
				continue
			if hit["was_crit"]:
				any_crit = true
			actual_damage = enemy.take_damage(hit["raw_damage"], ability.damage_type, hit["armor_pen"])

		_apply_post_hit(unit, enemy, actual_damage, ability.damage_type)
		total_damage += actual_damage
		targets_hit += 1

		print("[Ability] %s caster=%s target=%s dmg=%d (AoE %d/%d)" % [
			ability.ability_id, unit.display_name, enemy.display_name, actual_damage,
			targets_hit, alive_enemies.size()])

		# Apply status effect to each target
		if ability.applies_status_id != "":
			_apply_ability_status(enemy, ability, unit)

		# Apply enemy debuff to each target
		if not ability.enemy_debuff.is_empty():
			_apply_enemy_debuff(enemy, ability.enemy_debuff, ability.ability_id)

	# Create action for UI (use first target for display)
	var action = CombatAction.create_ability_attack(unit, alive_enemies[0], ability.ability_id, ability.display_name, total_damage)
	action.is_aoe = true
	action.targets_hit = targets_hit
	action.was_critical = any_crit
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])

	# Apply self effects
	_apply_self_effects(unit, ability)

	# Check for deaths
	for enemy in alive_enemies:
		if not enemy.is_alive:
			status_changed.emit(enemy.unit_id)  # Clear status badges on death
			var death_action = CombatAction.create_death(enemy)
			_pending_actions.append(death_action)
			_result.add_action(death_action)
			action_performed.emit(death_action)
			_trigger_on_kill_passives(unit, enemy.source_id)
			_check_tag_effects(unit, "on_kill")


## Execute a heal-type ability (natures_grace).
## Uses data-driven targeting via _pick_target_for_ability().
func _execute_heal_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	# Use player's selection if available, else data-driven targeting
	var target: CombatUnit = null
	var pick_result: Dictionary = {"fallback": false, "target": null}
	if player_target != null and player_target.is_alive:
		target = player_target
	else:
		pick_result = _pick_target_with_fallback(unit, ability)
		target = pick_result["target"]

	# If fallback to basic attack (no valid heal target)
	if pick_result["fallback"]:
		_execute_basic_attack_fallback(unit)
		return

	if target == null:
		return

	# Calculate heal amount
	var hp_before = target.current_health
	var heal_amount = ability.base_heal
	var actual_heal = target.heal(heal_amount)
	var hp_after = target.current_health

	# Log in required format
	print("[Ability] %s caster=%s target=%s heal=%d hp_before=%d hp_after=%d" % [
		ability.ability_id, unit.display_name, target.display_name, actual_heal, hp_before, hp_after])

	# Create action for UI
	var action = CombatAction.create_heal(unit, target, ability.ability_id, ability.display_name, actual_heal)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Apply self effects (self_buff, self_debuff) if present
	_apply_self_effects(unit, ability)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Execute a buff-type ability (shadowstep, barkskin_blessing).
## Buffs are tracked with duration and expire automatically at round start.
## Uses data-driven targeting via _pick_target_for_ability().
func _execute_buff_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	# Use player's selection if available, else data-driven targeting
	var target: CombatUnit = null
	var pick_result: Dictionary = {"fallback": false, "target": null}
	if player_target != null and player_target.is_alive:
		target = player_target
	else:
		pick_result = _pick_target_with_fallback(unit, ability)
		target = pick_result["target"]

	# If fallback to basic attack (no valid buff target)
	if pick_result["fallback"]:
		_execute_basic_attack_fallback(unit)
		return

	if target == null:
		return

	# Apply buff using tracking system (duration-based expiry)
	var duration = ability.buff_duration if ability.buff_duration > 0 else 99  # 0 = permanent for combat
	if not ability.buff_stats.is_empty():
		target.apply_buff(ability.ability_id, ability.buff_stats, duration)

	# Apply shield if ability has shield_value
	if ability.shield_value > 0:
		var shield_dur: int = ability.shield_duration if ability.shield_duration > 0 else 2
		target.apply_shield(ability.shield_value, shield_dur)

	# Apply reflect if ability has reflect_percent
	if ability.reflect_percent > 0:
		var ref_dur: int = ability.shield_duration if ability.shield_duration > 0 else 2
		target.apply_reflect(ability.reflect_percent, ref_dur)

	# Log in required format
	print("[Ability] %s caster=%s target=%s buff=%s shield=%d reflect=%d duration=%d" % [
		ability.ability_id, unit.display_name, target.display_name,
		JSON.stringify(ability.buff_stats), ability.shield_value, ability.reflect_percent, duration])

	# Build description for UI action
	var buff_desc_parts: Array[String] = []
	if ability.buff_stats.has("attack"):
		buff_desc_parts.append("+%d ATK" % int(ability.buff_stats.get("attack", 0)))
	if ability.buff_stats.has("defense"):
		buff_desc_parts.append("+%d DEF" % int(ability.buff_stats.get("defense", 0)))
	if ability.buff_stats.has("speed"):
		buff_desc_parts.append("+%d SPD" % int(ability.buff_stats.get("speed", 0)))
	if ability.buff_stats.has("health"):
		buff_desc_parts.append("+%d HP" % int(ability.buff_stats.get("health", 0)))
	if ability.shield_value > 0:
		buff_desc_parts.append("Shield %d" % ability.shield_value)
	if ability.reflect_percent > 0:
		buff_desc_parts.append("Reflect %d%%" % ability.reflect_percent)

	var buff_desc = ", ".join(buff_desc_parts)
	if ability.buff_duration > 0:
		buff_desc += " for %d rounds" % ability.buff_duration

	# Create action for UI
	var action = CombatAction.create_buff(unit, target, ability.ability_id, ability.display_name, buff_desc)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Apply self effects (self_buff, self_debuff) if present
	_apply_self_effects(unit, ability)

	# Put ability on cooldown and log
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Execute an AoE heal ability (healing_tide for all allies, etc.)
func _execute_aoe_heal_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	var allies = _player_units if unit.team == CombatUnit.Team.PLAYER else _enemy_units
	var alive_allies = allies.filter(func(a): return a.is_alive)

	if alive_allies.is_empty():
		return

	var targets_healed = 0
	var total_heal = 0

	for ally in alive_allies:
		var hp_before = ally.current_health
		var actual_heal = ally.heal(ability.base_heal)
		var hp_after = ally.current_health
		total_heal += actual_heal
		targets_healed += 1

		print("[Ability] %s caster=%s target=%s heal=%d hp_before=%d hp_after=%d (AoE %d/%d)" % [
			ability.ability_id, unit.display_name, ally.display_name, actual_heal, hp_before, hp_after,
			targets_healed, alive_allies.size()])

	# Create action for UI
	var action = CombatAction.create_heal(unit, alive_allies[0], ability.ability_id, ability.display_name, total_heal)
	action.is_aoe = true
	action.targets_hit = targets_healed
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Apply self effects (self_buff, self_debuff) if present
	_apply_self_effects(unit, ability)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Execute an AoE buff ability (raise_dead, etc.)
func _execute_aoe_buff_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	var allies = _player_units if unit.team == CombatUnit.Team.PLAYER else _enemy_units
	var alive_allies = allies.filter(func(a): return a.is_alive)

	if alive_allies.is_empty():
		return

	var targets_buffed = 0

	# Build buff stats from ally_buff or buff_stats
	var buff_stats: Dictionary = {}
	var duration: int = 3

	if not ability.ally_buff.is_empty():
		var stats_arr = ability.ally_buff.get("stats", [])
		var value = int(ability.ally_buff.get("value", 0))
		duration = int(ability.ally_buff.get("duration", 3))
		for stat in stats_arr:
			buff_stats[stat] = value
	elif not ability.buff_stats.is_empty():
		buff_stats = ability.buff_stats
		duration = ability.buff_duration if ability.buff_duration > 0 else 3

	for ally in alive_allies:
		if not buff_stats.is_empty():
			ally.apply_buff(ability.ability_id, buff_stats, duration)
		# Apply shield to each ally if ability has shield_value
		if ability.shield_value > 0:
			var shield_dur: int = ability.shield_duration if ability.shield_duration > 0 else 2
			ally.apply_shield(ability.shield_value, shield_dur)
		# Apply reflect to each ally if ability has reflect_percent
		if ability.reflect_percent > 0:
			var ref_dur: int = ability.shield_duration if ability.shield_duration > 0 else 2
			ally.apply_reflect(ability.reflect_percent, ref_dur)
		targets_buffed += 1

		print("[Ability] %s caster=%s target=%s buff=%s shield=%d reflect=%d duration=%d (AoE %d/%d)" % [
			ability.ability_id, unit.display_name, ally.display_name,
			JSON.stringify(buff_stats), ability.shield_value, ability.reflect_percent, duration, targets_buffed, alive_allies.size()])

	# Create action for UI
	var buff_desc = ", ".join(buff_stats.keys().map(func(k): return "+%d %s" % [buff_stats[k], k.to_upper()]))
	var action = CombatAction.create_buff(unit, alive_allies[0], ability.ability_id, ability.display_name, buff_desc)
	action.is_aoe = true
	action.targets_hit = targets_buffed
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Apply self effects (self_buff, self_debuff) if present
	_apply_self_effects(unit, ability)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Execute a debuff-only ability (void_anchor).
func _execute_debuff_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)

	# Check for AoE debuff
	if ability.target_type == "all_enemies":
		var alive_enemies = enemies.filter(func(e): return e.is_alive)
		if alive_enemies.is_empty():
			return

		for enemy in alive_enemies:
			# Apply status effect if present
			if ability.applies_status_id != "":
				_apply_ability_status(enemy, ability, unit)

			# Apply enemy debuff
			if not ability.enemy_debuff.is_empty():
				_apply_enemy_debuff(enemy, ability.enemy_debuff, ability.ability_id)

			print("[Ability] %s caster=%s target=%s debuff applied" % [
				ability.ability_id, unit.display_name, enemy.display_name])

		# Create action for UI
		var action = CombatAction.new()
		action.action_type = CombatAction.ActionType.BUFF
		action.actor_id = unit.unit_id
		action.actor_name = unit.display_name
		action.target_id = alive_enemies[0].unit_id
		action.target_name = alive_enemies[0].display_name
		action.ability_id = ability.ability_id
		action.ability_name = ability.display_name
		action.is_aoe = true
		action.targets_hit = alive_enemies.size()
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
	else:
		# Single target debuff: use player's selection if available
		var target: CombatUnit = null
		if player_target != null and player_target.is_alive:
			target = player_target
		else:
			target = _targeting_policy.select_target(unit, enemies)
		if target == null:
			return

		if ability.applies_status_id != "":
			_apply_ability_status(target, ability, unit)

		if not ability.enemy_debuff.is_empty():
			_apply_enemy_debuff(target, ability.enemy_debuff, ability.ability_id)

		print("[Ability] %s caster=%s target=%s debuff applied" % [
			ability.ability_id, unit.display_name, target.display_name])

		var action = CombatAction.new()
		action.action_type = CombatAction.ActionType.BUFF
		action.actor_id = unit.unit_id
		action.actor_name = unit.display_name
		action.target_id = target.unit_id
		action.target_name = target.display_name
		action.ability_id = ability.ability_id
		action.ability_name = ability.display_name
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)

	# Apply self effects (e.g., taunt on self)
	_apply_self_effects(unit, ability)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Apply self-buff and self-debuff from an ability (e.g., fungal_frenzy, smoke_dash).
func _apply_self_effects(unit: CombatUnit, ability: AbilityData) -> void:
	# Apply self buff
	if not ability.self_buff.is_empty():
		var stat = ability.self_buff.get("stat", "")
		var value = int(ability.self_buff.get("value", 0))
		var duration = int(ability.self_buff.get("duration", 2))
		if stat != "" and value != 0:
			var buff_stats = {stat: value}
			unit.apply_buff(ability.ability_id + "_self", buff_stats, duration)
			print("[Ability] %s self_buff=%s +%d for %d rounds" % [
				ability.ability_id, stat, value, duration])

	# Apply self debuff
	if not ability.self_debuff.is_empty():
		var stat = ability.self_debuff.get("stat", "")
		var value = int(ability.self_debuff.get("value", 0))
		var duration = int(ability.self_debuff.get("duration", 2))
		if stat != "" and value != 0:
			var debuff_stats = {stat: value}  # Value is already negative
			unit.apply_buff(ability.ability_id + "_self_debuff", debuff_stats, duration)
			print("[Ability] %s self_debuff=%s %d for %d rounds" % [
				ability.ability_id, stat, value, duration])

	# Apply self damage (HP cost)
	if ability.self_damage > 0:
		var hp_before = unit.current_health
		unit.current_health = maxi(1, unit.current_health - ability.self_damage)
		print("[Ability] %s self_damage=%d hp_before=%d hp_after=%d" % [
			ability.ability_id, ability.self_damage, hp_before, unit.current_health])


## Apply enemy debuff from an ability (e.g., void_anchor, entropy_blast).
func _apply_enemy_debuff(target: CombatUnit, debuff: Dictionary, ability_id: String) -> void:
	var stat = debuff.get("stat", "")
	var value = int(debuff.get("value", 0))
	var duration = int(debuff.get("duration", 2))
	if stat == "" or value == 0:
		return

	var debuff_stats = {stat: value}
	target.apply_buff(ability_id + "_debuff", debuff_stats, duration)
	print("[Ability] %s enemy_debuff=%s %d for %d rounds target=%s" % [
		ability_id, stat, value, duration, target.display_name])


## Execute a damage_and_heal ability (life_drain).
## Damages an enemy and heals an ally based on the damage dealt.
func _execute_drain_ability(unit: CombatUnit, ability: AbilityData, ability_type: String, player_target: CombatUnit = null) -> void:
	# Get damage target (enemy): use player's selection if available
	var enemies = TargetingPolicy.get_enemies_for_team(_all_units, unit.team)
	var damage_target: CombatUnit = null
	if player_target != null and player_target.is_alive:
		damage_target = player_target
	else:
		damage_target = _targeting_policy.select_target(unit, enemies)

	if damage_target == null:
		return

	# Deal damage (with evasion/crit/armor_pen)
	var raw_damage = _calculate_ability_damage(unit, ability)
	var hit = _apply_pre_hit(unit, damage_target, raw_damage, ability.damage_type)
	if hit["evaded"]:
		var action = CombatAction.create_ability_attack(unit, damage_target, ability.ability_id, ability.display_name, 0)
		action.was_evaded = true
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		_put_ability_on_cooldown(unit, ability_type)
		return

	var actual_damage = damage_target.take_damage(hit["raw_damage"], ability.damage_type, hit["armor_pen"])
	_apply_post_hit(unit, damage_target, actual_damage, ability.damage_type)

	print("[Ability] %s caster=%s damage_target=%s dmg=%d%s" % [
		ability.ability_id, unit.display_name, damage_target.display_name, actual_damage,
		" (CRIT)" if hit["was_crit"] else ""])

	# Find heal target
	var heal_target: CombatUnit = null
	var heal_rule = ability.heal_target_rule if ability.heal_target_rule != "" else "lowest_hp_pct"

	if heal_rule == "lowest_hp_pct":
		heal_target = _find_lowest_hp_ally(unit)
	else:
		heal_target = unit  # Default to self

	# Apply heal
	if heal_target != null:
		var heal_amount = ability.base_heal if ability.base_heal > 0 else int(actual_damage * 0.5)
		var hp_before = heal_target.current_health
		var actual_heal = heal_target.heal(heal_amount)
		var hp_after = heal_target.current_health

		print("[Ability] %s caster=%s heal_target=%s heal=%d hp_before=%d hp_after=%d" % [
			ability.ability_id, unit.display_name, heal_target.display_name, actual_heal, hp_before, hp_after])

	# Create action for UI
	var action = CombatAction.create_ability_attack(unit, damage_target, ability.ability_id, ability.display_name, actual_damage)
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])

	# Apply status effect if ability has one
	if ability.applies_status_id != "":
		_apply_ability_status(damage_target, ability, unit)

	# Handle death
	if not damage_target.is_alive:
		var death_action = CombatAction.create_death(damage_target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, damage_target.source_id)
		_check_tag_effects(unit, "on_kill")


## Execute a heal ability that also cleanses debuffs (cleansing_wave).
func _execute_cleanse_heal_ability(unit: CombatUnit, ability: AbilityData, ability_type: String) -> void:
	var allies = _player_units if unit.team == CombatUnit.Team.PLAYER else _enemy_units
	var alive_allies = allies.filter(func(a): return a.is_alive)

	if alive_allies.is_empty():
		return

	var targets_healed = 0

	for ally in alive_allies:
		var hp_before = ally.current_health
		var actual_heal = ally.heal(ability.base_heal)
		var hp_after = ally.current_health

		# Cleanse debuffs
		var cleansed = []
		if ability.cleanses_debuffs > 0:
			cleansed = _cleanse_debuffs_from_unit(ally, ability.cleanses_debuffs)

		targets_healed += 1
		print("[Ability] %s caster=%s target=%s heal=%d hp_before=%d hp_after=%d cleansed=%s" % [
			ability.ability_id, unit.display_name, ally.display_name, actual_heal, hp_before, hp_after, str(cleansed)])

	# Create action for UI
	var action = CombatAction.create_heal(unit, alive_allies[0], ability.ability_id, ability.display_name, ability.base_heal)
	action.is_aoe = true
	action.targets_hit = targets_healed
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	# Put ability on cooldown
	_put_ability_on_cooldown(unit, ability_type)
	print("[CD] set ability=%s unit=%s cd=%d" % [ability.ability_id, unit.display_name,
		unit.ability_a_cooldown if ability_type == "ability_a" else unit.ability_b_cooldown])


## Cleanse up to N debuffs from a unit.
## Returns array of cleansed status IDs.
func _cleanse_debuffs_from_unit(unit: CombatUnit, count: int) -> Array:
	var cleansed: Array = []
	var debuff_ids = ["poisoned", "bleeding", "burning", "stun", "weakened", "slowed"]

	var i = 0
	while i < unit.active_statuses.size() and cleansed.size() < count:
		var status = unit.active_statuses[i]
		var status_id = status.get("id", "")
		if status_id in debuff_ids:
			cleansed.append(status_id)
			unit.active_statuses.remove_at(i)
			print("[Status] cleansed unit=%s id=%s" % [unit.display_name, status_id])
		else:
			i += 1

	return cleansed


## Find the lowest HP% ally (including caster).
func _find_lowest_hp_ally(caster: CombatUnit) -> CombatUnit:
	var allies = _player_units if caster.team == CombatUnit.Team.PLAYER else _enemy_units
	var lowest_unit: CombatUnit = null
	var lowest_hp_pct: float = 2.0  # > 100%

	for ally in allies:
		if not ally.is_alive:
			continue
		var hp_pct = float(ally.current_health) / float(ally.max_health)
		if hp_pct < lowest_hp_pct:
			lowest_hp_pct = hp_pct
			lowest_unit = ally

	return lowest_unit


## Put the used ability on cooldown.
func _put_ability_on_cooldown(unit: CombatUnit, ability_type: String) -> void:
	match ability_type:
		"ability_a":
			unit.use_ability_a()
		"ability_b":
			unit.use_ability_b()


## Execute a basic attack as fallback when ability targeting fails.
## Used when heal/buff has no valid target and allow_self_target is false.
func _execute_basic_attack_fallback(unit: CombatUnit) -> void:
	var enemies = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
	var target: CombatUnit = null

	for e in enemies:
		if e.is_alive:
			target = e
			break

	if target == null:
		print("[Combat] %s has no valid attack target (fallback failed)" % unit.display_name)
		return

	var eff_atk = unit.get_effective_attack()
	var hit = _apply_pre_hit(unit, target, eff_atk, "physical")
	if hit["evaded"]:
		var action = CombatAction.create_attack(unit, target, 0, false)
		action.was_evaded = true
		action.message = "%s's attack was evaded by %s!" % [unit.display_name, target.display_name]
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		return

	var actual_damage = target.take_damage(hit["raw_damage"], "physical", hit["armor_pen"])
	_apply_post_hit(unit, target, actual_damage, "physical")

	var action = CombatAction.create_attack(unit, target, actual_damage, false)
	action.was_critical = hit["was_crit"]
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	print("[Combat] %s performs basic attack (fallback) on %s for %d damage" % [
		unit.display_name, target.display_name, actual_damage])

	if not target.is_alive:
		status_changed.emit(target.unit_id)  # Clear status badges on death
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)
		_check_tag_effects(unit, "on_kill")


func _check_combat_end() -> bool:
	if _turn_queue.is_team_wiped(CombatUnit.Team.ENEMY):
		print("\n[CombatController] All enemies defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		_result.set_rng(_rng)
		# Set context for loot bias and drop rate scaling
		var ctx = {
			"region_id": GameContext.get_current_region_id(),
			"floor_index": maxi(GameContext.current_floor - 1, 0)
		}
		var town = DataRegistry.get_town(GameContext.get_current_town_id())
		if town != null:
			ctx["dungeon_id"] = town.dungeon_id
		_result.set_context(ctx)
		_result.is_boss_encounter = _encounter_is_boss
		_result.calculate_rewards(_enemy_units)
		# Apply rewards (guarded against double-add)
		if not _result._stash_applied:
			_result._stash_applied = true
			# Gold goes directly to stash (no recipient choice)
			GameContext.add_rewards(_result.gold_earned, [])
			# Items become pending acquisitions for player routing
			for item in _result.items_dropped:
				var drop_id = ""
				var drop_quality = 0
				var drop_affix: Dictionary = {}
				if item is ItemInstance:
					drop_id = item.template_id
					drop_quality = item.quality_tier
					if item.affix_id != "":
						drop_affix = {
							"source_region": item.source_region,
							"affix_id": item.affix_id,
							"affix_stats": item.affix_stats,
							"affix_prefix": item.affix_prefix
						}
					# NG+ bonus stat lines (generated at drop time)
					if item.bonus_stat_lines.size() > 0:
						drop_affix["bonus_stat_lines"] = item.bonus_stat_lines
				elif item is Dictionary:
					drop_id = item.get("item_id", item.get("template_id", ""))
					drop_quality = int(item.get("quality_tier", 0))
				if drop_id != "":
					var drop_qty: int = item.quantity if item is ItemInstance else int(item.get("qty", item.get("quantity", 1)))
					GameContext.acquire_item_with_recipient(drop_id, drop_qty, drop_quality, "combat", drop_affix)
			# Apply dungeon floor bonus using SNAPSHOT values (not mutable GameContext state)
			GameContext.apply_dungeon_floor_reward_snapshot(
				_encounter_dungeon_id,
				_encounter_floor,
				_encounter_floor_count,
				_encounter_is_boss,
				_encounter_boss_id,
				_rng
			)
			print("[RunStash] Gold=%d Items=%d Pending=%d" % [GameContext.run_gold, GameContext.run_items.size(), GameContext.get_all_pending_acquisitions().size()])
		# Region completion: mark region as completed when boss is defeated
		if _encounter_is_boss:
			var region_id: String = GameContext.get_current_region_id()
			GameContext.mark_region_completed(region_id)
			# Campaign victory: R7 boss defeated = campaign complete
			if region_id == "region_7":
				_result.is_campaign_victory = true
		# Health Persistence v1: Save surviving heroes' HP
		_persist_hero_hp()
		combat_ended.emit(_result)
		return true

	if _turn_queue.is_team_wiped(CombatUnit.Team.PLAYER):
		print("\n[CombatController] All heroes defeated!")
		_is_combat_active = false
		_result.set_outcome_from_combat(_player_units, _enemy_units)
		# Health Persistence v1: Save surviving heroes' HP (even on defeat, for dead heroes)
		_persist_hero_hp()
		combat_ended.emit(_result)
		return true

	return false


## Health Persistence v1: Save all player unit HP to GameContext.
## Uses source_id (actual hero_id like "hero_warrior_1") for consistent key.
func _persist_hero_hp() -> void:
	for unit in _player_units:
		if GameContext.has_method("set_hero_hp"):
			# Use source_id (actual hero_id) not unit_id (combat index)
			var hero_id = unit.source_id if unit.source_id != "" else unit.unit_id
			GameContext.set_hero_hp(hero_id, unit.current_health, unit.max_health)
			print("[HP] persist_after_combat hero=%s hp=%d/%d" % [hero_id, unit.current_health, unit.max_health])


# ============================================================================
# CONSUMABLES v1 - AUTO USE
# ============================================================================

## Try to auto-use a consumable for a player hero at turn start.
## Rules:
## - Each hero can use 1 consumable per combat
## - HP <= 50%: use healing consumable
## - Has DOT status: use cleanse consumable
## - Has stunned: use stun removal (if available)
func _try_auto_use_consumable(unit: CombatUnit) -> void:
	var hero_id = unit.unit_id

	# Check if this hero has already used a consumable this combat
	if not GameContext.can_hero_use_consumable(hero_id):
		return

	# Check HP ratio - if <= 50%, look for healing
	var hp_ratio = float(unit.current_health) / float(unit.max_health)
	if hp_ratio <= 0.5:
		var heal_info = GameContext.find_healing_consumable(hero_id)
		if not heal_info.is_empty():
			_use_healing_consumable(unit, heal_info)
			return

	# Check for DOT statuses (poisoned, bleeding)
	if _unit_has_dot_status(unit):
		var cleanse_info = GameContext.find_cleanse_consumable("dot", hero_id)
		if not cleanse_info.is_empty():
			_use_cleanse_consumable(unit, cleanse_info, "dot")
			return

	# Check for stunned status
	if unit.is_action_blocked_by_status():
		var stun_info = GameContext.find_cleanse_consumable("stun", hero_id)
		if not stun_info.is_empty():
			_use_cleanse_consumable(unit, stun_info, "stun")
			return


## Check if unit has a DOT status (poisoned or bleeding).
func _unit_has_dot_status(unit: CombatUnit) -> bool:
	for status in unit.active_statuses:
		var status_id = status.get("id", "")
		if status_id in ["poisoned", "bleeding"]:
			return true
	return false


## Use a healing consumable on a unit.
func _use_healing_consumable(unit: CombatUnit, heal_info: Dictionary) -> void:
	var item_id = heal_info.get("item_id", "")
	var heal_amount = heal_info.get("use_value", 12)  # Default 12 for heal_small
	var source = heal_info.get("source", "dungeon")
	var bag_hero_id = heal_info.get("hero_id", "")

	# HOT potion: apply regenerating status instead of instant heal (Status v1.5)
	var item_template = DataRegistry.get_item_template(item_id)
	if item_template != null and item_template.use_effect == "hot_heal":
		GameContext.consume_stash_item(item_id, source, bag_hero_id)
		GameContext.mark_consumable_used(unit.unit_id)
		var ht: int = item_template.hot_turns if item_template.hot_turns > 0 else 3
		var heal_per_tick: int = ceili(float(item_template.use_value) / float(ht))
		var internal_duration: int = _compute_internal_status_duration(ht)
		unit.apply_hot_v1("regenerating", internal_duration, heal_per_tick, item_id)
		status_changed.emit(unit.unit_id)
		print("[Consumable] hot_use unit=%s hero=%s item=%s hpt=%d turns=%d source=%s" % [
			unit.display_name, unit.unit_id, item_id, heal_per_tick, ht, source])
		var action = CombatAction.new()
		action.action_type = CombatAction.ActionType.ITEM_USE
		action.actor_id = unit.unit_id
		action.actor_name = unit.display_name
		action.target_id = unit.unit_id
		action.target_name = unit.display_name
		action.healing_done = 0
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		return

	var hp_before = unit.current_health
	var actual_heal = unit.heal(heal_amount)
	var hp_after = unit.current_health

	# Consume item from stash or hero bag
	GameContext.consume_stash_item(item_id, source, bag_hero_id)
	GameContext.mark_consumable_used(unit.unit_id)

	print("[Consumable] use unit=%s hero=%s item=%s effect=heal source=%s hp_before=%d hp_after=%d removed_statuses=[]" % [
		unit.display_name, unit.unit_id, item_id, source, hp_before, hp_after])

	# Create action for UI (using ITEM_USE type for consumables)
	var action = CombatAction.new()
	action.action_type = CombatAction.ActionType.ITEM_USE
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.target_id = unit.unit_id
	action.target_name = unit.display_name
	action.healing_done = actual_heal
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)


## Use a cleanse consumable to remove status effects.
func _use_cleanse_consumable(unit: CombatUnit, cleanse_info: Dictionary, effect_type: String) -> void:
	var item_id = cleanse_info.get("item_id", "")
	var use_effect = cleanse_info.get("use_effect", "")
	var source = cleanse_info.get("source", "dungeon")
	var bag_hero_id = cleanse_info.get("hero_id", "")

	var hp_before = unit.current_health
	var removed_statuses: Array = []

	# Remove appropriate statuses
	if effect_type == "dot":
		removed_statuses = _remove_dot_statuses(unit)
	elif effect_type == "stun":
		removed_statuses = _remove_stun_status(unit)

	# Consume item from stash or hero bag
	GameContext.consume_stash_item(item_id, source, bag_hero_id)
	GameContext.mark_consumable_used(unit.unit_id)

	print("[Consumable] use unit=%s hero=%s item=%s effect=%s source=%s hp_before=%d hp_after=%d removed_statuses=%s" % [
		unit.display_name, unit.unit_id, item_id, use_effect, source, hp_before, unit.current_health, str(removed_statuses)])

	# Create action for UI (using SKIP type with descriptive reason)
	var action = CombatAction.create_skip(unit, "Used " + item_id.replace("_", " ").capitalize())
	action.status_applied = "cleanse"  # Signal to UI
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)


## Remove DOT statuses from unit.
func _remove_dot_statuses(unit: CombatUnit) -> Array:
	var removed: Array = []
	var i = 0
	while i < unit.active_statuses.size():
		var status = unit.active_statuses[i]
		var status_id = status.get("id", "")
		if status_id in ["poisoned", "bleeding"]:
			removed.append(status_id)
			unit.active_statuses.remove_at(i)
		else:
			i += 1
	return removed


## Remove stun status from unit.
func _remove_stun_status(unit: CombatUnit) -> Array:
	var removed: Array = []
	var i = 0
	while i < unit.active_statuses.size():
		var status = unit.active_statuses[i]
		var status_id = status.get("id", "")
		if status_id == "stun":
			removed.append(status_id)
			unit.active_statuses.remove_at(i)
		else:
			i += 1
	return removed


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


# ============================================================================
# PLAYER ACTIONS v1 - Multi-Action and Player Input
# ============================================================================

## Calculate number of actions based on unit speed.
## More conservative formula to prevent action spam:
## Speed 0-9: 1 action, 10-19: 2 actions, 20+: 3 actions (cap)
func _calculate_actions_for_speed(speed: int) -> int:
	if speed >= 80:
		return 3
	elif speed >= 40:
		return 2
	else:
		return 1


## Consume one action from the unit's remaining actions.
## Advances turn queue when all actions exhausted.
## Cooldowns only tick when full turn ends (all actions used).
func _consume_action(unit: CombatUnit) -> void:
	_unit_remaining_actions[unit.unit_id] = _unit_remaining_actions.get(unit.unit_id, 1) - 1
	if _unit_remaining_actions[unit.unit_id] <= 0:
		# Full turn ended - NOW tick cooldowns (once per turn, not per action)
		unit.tick_cooldowns()
		print("[MultiAction] %s turn ended - cooldowns ticked" % unit.display_name)
		_current_multi_action_unit = null
		_turn_queue.advance()


## Get available actions for a player unit.
func _get_available_actions(unit: CombatUnit) -> Array:
	var actions = [{"type": "basic", "name": "Basic Attack", "enabled": true, "cooldown": 0}]

	if unit.ability_a_id != "" and GameContext.is_ability_slot_unlocked("ability_a", unit.hero_level):
		var ability = DataRegistry.get_ability(unit.ability_a_id)
		actions.append({
			"type": "ability_a",
			"name": ability.display_name if ability else unit.ability_a_id,
			"enabled": unit.is_ability_a_ready(),
			"cooldown": unit.ability_a_cooldown,
			"ability": ability
		})

	if unit.ability_b_id != "" and GameContext.is_ability_slot_unlocked("ability_b", unit.hero_level):
		var ability = DataRegistry.get_ability(unit.ability_b_id)
		actions.append({
			"type": "ability_b",
			"name": ability.display_name if ability else unit.ability_b_id,
			"enabled": unit.is_ability_b_ready(),
			"cooldown": unit.ability_b_cooldown,
			"ability": ability
		})

	# Equipment abilities (T4 gear, max 2)
	for idx in range(unit.equip_ability_ids.size()):
		var ea_id = unit.equip_ability_ids[idx]
		if ea_id != "":
			var ea_data = DataRegistry.get_ability(ea_id)
			actions.append({
				"type": "equip_ability_%d" % idx,
				"name": ea_data.display_name if ea_data else ea_id,
				"enabled": unit.is_equip_ability_ready(idx),
				"cooldown": unit.equip_ability_cooldowns[idx],
				"ability": ea_data,
				"equip_index": idx
			})

	# Pass action - skip remaining actions and end turn
	actions.append({"type": "pass", "name": "Pass", "enabled": true, "cooldown": 0})

	return actions


## Called by UI when player selects an action type.
func submit_player_action(action_type: String) -> void:
	print("[Combat] submit_player_action called with action_type=%s" % action_type)
	if not _awaiting_player_input or _input_unit == null:
		print("[Combat] submit_player_action returning early")
		return

	_selected_action_type = action_type

	# Get ability if needed
	if action_type == "ability_a":
		_selected_ability = DataRegistry.get_ability(_input_unit.ability_a_id)
	elif action_type == "ability_b":
		_selected_ability = DataRegistry.get_ability(_input_unit.ability_b_id)
	elif action_type.begins_with("equip_ability_"):
		var idx = int(action_type.substr(14))
		if idx >= 0 and idx < _input_unit.equip_ability_ids.size():
			_selected_ability = DataRegistry.get_ability(_input_unit.equip_ability_ids[idx])
		else:
			_selected_ability = null
	else:
		_selected_ability = null

	# Determine valid targets
	var valid_targets = _get_valid_targets(_input_unit, action_type, _selected_ability)
	target_selection_required.emit(_input_unit, valid_targets, action_type, _selected_ability)


## Get valid targets for an action.
func _get_valid_targets(unit: CombatUnit, action_type: String, ability: AbilityData) -> Array:
	var targets = []

	if ability != null:
		match ability.target_type:
			"single_enemy":
				var enemies = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
				for e in enemies:
					if e.is_alive:
						targets.append({"unit_id": e.unit_id, "name": e.display_name, "is_ally": false})
			"single_ally", "lowest_hp_ally":
				var allies = _player_units if unit.team == CombatUnit.Team.PLAYER else _enemy_units
				for a in allies:
					if a.is_alive:
						targets.append({"unit_id": a.unit_id, "name": a.display_name, "is_ally": true})
			"self":
				targets.append({"unit_id": unit.unit_id, "name": unit.display_name, "is_ally": true})
			"all_enemies", "all_allies":
				# AoE - no target selection needed, auto-execute
				targets.append({"unit_id": "aoe", "name": "All", "is_ally": ability.target_type == "all_allies"})
			_:
				# Default to enemies for damage abilities
				var enemies = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
				for e in enemies:
					if e.is_alive:
						targets.append({"unit_id": e.unit_id, "name": e.display_name, "is_ally": false})
	else:
		# Basic attack - target enemies
		var enemies = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
		for e in enemies:
			if e.is_alive:
				targets.append({"unit_id": e.unit_id, "name": e.display_name, "is_ally": false})

	return targets


## Called by UI when player clicks a target.
func submit_player_target(target_id: String) -> void:
	print("[Combat] submit_player_target called with target_id=%s awaiting=%s input_unit=%s" % [
		target_id, str(_awaiting_player_input), _input_unit.display_name if _input_unit else "null"])
	if not _awaiting_player_input or _input_unit == null:
		print("[Combat] submit_player_target returning early - not awaiting or no input unit")
		return

	_awaiting_player_input = false

	var target: CombatUnit = null
	if target_id != "aoe":
		target = get_unit_by_id(target_id)

	# Execute the chosen action
	_execute_player_action(_input_unit, _selected_action_type, target, _selected_ability)

	# Finish the action (doom, consume action - cooldowns tick when turn fully ends)
	_finish_unit_action(_input_unit)

	_input_unit = null
	_selected_action_type = ""
	_selected_ability = null

	if not _check_combat_end():
		# Auto-continue: execute enemies, then prompt next player
		_continue_to_next_turn()


## Convenience: submit a basic attack on a specific target in one step.
## Returns true if the action was submitted, false if invalid.
func submit_basic_attack_on_target(target_id: String) -> bool:
	if not _awaiting_player_input or _input_unit == null:
		return false
	var targets: Array = _get_valid_targets(_input_unit, "basic", null)
	for t in targets:
		if t["unit_id"] == target_id:
			_selected_action_type = "basic"
			_selected_ability = null
			submit_player_target(target_id)
			return true
	return false


## Execute a player-chosen action.
func _execute_player_action(unit: CombatUnit, action_type: String, target: CombatUnit, ability: AbilityData) -> void:
	if action_type.begins_with("equip_ability_"):
		var idx = int(action_type.substr(14))
		_execute_equipment_ability_step(unit, ability, idx, target)
		return
	match action_type:
		"basic":
			_execute_basic_attack_player(unit, target)
		"ability_a":
			_execute_class_ability_step(unit, ability, "ability_a", target)
		"ability_b":
			_execute_class_ability_step(unit, ability, "ability_b", target)


## Execute a basic attack from player input (with specific target).
func _execute_basic_attack_player(unit: CombatUnit, target: CombatUnit) -> void:
	if target == null:
		print("[Combat] %s basic attack: no target" % unit.display_name)
		return

	var eff_atk = unit.get_effective_attack()
	var hit = _apply_pre_hit(unit, target, eff_atk, "physical")
	if hit["evaded"]:
		var action = CombatAction.create_attack(unit, target, 0, false)
		action.was_evaded = true
		action.message = "%s's attack was evaded by %s!" % [unit.display_name, target.display_name]
		action.round_number = _current_round
		action.turn_number = _current_turn
		_pending_actions.append(action)
		_result.add_action(action)
		action_performed.emit(action)
		return

	var actual_damage = target.take_damage(hit["raw_damage"], "physical", hit["armor_pen"])
	_apply_post_hit(unit, target, actual_damage, "physical")

	# Tag effects: on_attack (player basic attack)
	_check_tag_effects(unit, "on_attack", {"target": target})

	var action = CombatAction.create_attack(unit, target, actual_damage, false)
	action.was_critical = hit["was_crit"]
	action.round_number = _current_round
	action.turn_number = _current_turn
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)

	print("[Combat] %s attacks %s for %d damage" % [unit.display_name, target.display_name, actual_damage])

	if not target.is_alive:
		status_changed.emit(target.unit_id)  # Clear status badges on death
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		_trigger_on_kill_passives(unit, target.source_id)
		_check_tag_effects(unit, "on_kill")


## Execute an equipment ability (T4 gear-granted ability).
## Routes through the same class ability execution pipeline.
func _execute_equipment_ability_step(unit: CombatUnit, ability: AbilityData, equip_index: int, target: CombatUnit) -> void:
	if ability == null:
		print("[Combat] %s equip ability %d: no ability data" % [unit.display_name, equip_index])
		return

	print("[Combat] %s uses equipment ability [%d] %s" % [unit.display_name, equip_index, ability.display_name])

	# Use the same execution pipeline as class abilities (pass player target)
	_execute_class_ability_step(unit, ability, "equip_%d" % equip_index, target)

	# Put equipment ability on cooldown (class ability step handles class cooldowns,
	# but we need to handle equip cooldown separately)
	unit.use_equip_ability(equip_index)


## Called by UI when player uses a consumable from hero bag.
## source_hero_id: the hero whose bag the item is consumed from (defaults to hero_id).
func submit_consumable_use(item_id: String, hero_id: String, free_action: bool = false, source_hero_id: String = "") -> void:
	if not _awaiting_player_input:
		return

	# Determine which hero's bag to consume from
	var bag_owner: String = source_hero_id if source_hero_id != "" else hero_id

	# HOT potion in combat: apply regenerating status instead of instant heal (Status v1.5)
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.use_effect == "hot_heal":
		var consumed = GameContext.consume_stash_item(item_id, "hero_bag", bag_owner)
		if consumed:
			GameContext.mark_consumable_used(bag_owner)
			var target_unit: CombatUnit = get_unit_by_source_id(hero_id)
			if target_unit != null:
				var ht: int = template.hot_turns if template.hot_turns > 0 else 3
				var heal_per_tick: int = ceili(float(template.use_value) / float(ht))
				var internal_duration: int = _compute_internal_status_duration(ht)
				target_unit.apply_hot_v1("regenerating", internal_duration, heal_per_tick, item_id)
				status_changed.emit(target_unit.unit_id)
				print("[Combat] HOT consumable: %s on %s from %s's bag hpt=%d turns=%d (free=%s)" % [
					item_id, hero_id, bag_owner, heal_per_tick, ht, str(free_action)])
				# CombatAction for UI
				var action = CombatAction.new()
				action.action_type = CombatAction.ActionType.ITEM_USE
				action.actor_id = _input_unit.unit_id if _input_unit else target_unit.unit_id
				action.actor_name = _input_unit.display_name if _input_unit else target_unit.display_name
				action.target_id = target_unit.unit_id
				action.target_name = target_unit.display_name
				action.healing_done = 0
				_pending_actions.append(action)
				_result.add_action(action)
				action_performed.emit(action)

			if free_action:
				if _input_unit != null:
					var available = _get_available_actions(_input_unit)
					player_input_required.emit(_input_unit, available)
			else:
				_finish_unit_action(_input_unit)
				_awaiting_player_input = false
				_input_unit = null
				if not _check_combat_end():
					_continue_to_next_turn()
		else:
			_check_combat_end()
		return

	# Sync target hero's combat HP to persistence before using consumable,
	# so _apply_camp_heal() has accurate HP data (not stale "full HP" default)
	var pre_unit: CombatUnit = get_unit_by_source_id(hero_id)
	if pre_unit != null:
		GameContext.set_hero_hp(hero_id, pre_unit.current_health, pre_unit.max_health)

	var result = GameContext.use_consumable_on_hero(item_id, hero_id, "hero_bag", bag_owner)
	if result.get("success", false):
		print("[Combat] Consumable used: %s on %s from %s's bag - %s (free=%s)" % [item_id, hero_id, bag_owner, result.get("detail", ""), str(free_action)])
		# Mark the bag owner (acting hero) as having used their consumable this combat
		GameContext.mark_consumable_used(bag_owner)

		# Update CombatUnit HP and emit action for UI refresh
		var target_unit: CombatUnit = get_unit_by_source_id(hero_id)
		var effect: String = result.get("effect", "")
		if target_unit != null and effect in ["heal", "heal_small", "heal_large", "heal_and_buff"]:
			var actual_heal: int = target_unit.heal(result.get("amount", 0))
			# Create CombatAction so UI shows heal pop text and refreshes HP
			var action = CombatAction.new()
			action.action_type = CombatAction.ActionType.ITEM_USE
			action.actor_id = _input_unit.unit_id if _input_unit else target_unit.unit_id
			action.actor_name = _input_unit.display_name if _input_unit else target_unit.display_name
			action.target_id = target_unit.unit_id
			action.target_name = target_unit.display_name
			action.healing_done = actual_heal
			_pending_actions.append(action)
			_result.add_action(action)
			action_performed.emit(action)

		if free_action:
			# Free action: hero keeps their turn — re-emit input prompt
			if _input_unit != null:
				var available = _get_available_actions(_input_unit)
				player_input_required.emit(_input_unit, available)
		else:
			# Normal action: consumes the turn
			_finish_unit_action(_input_unit)

			_awaiting_player_input = false
			_input_unit = null

			if not _check_combat_end():
				_continue_to_next_turn()
	else:
		_check_combat_end()


## Cancel target selection and return to action selection.
func cancel_player_action() -> void:
	if _awaiting_player_input and _input_unit != null:
		var available = _get_available_actions(_input_unit)
		player_input_required.emit(_input_unit, available)


## Called by UI when player chooses to pass (skip remaining actions).
func submit_pass_action() -> void:
	if not _awaiting_player_input or _input_unit == null:
		return

	_awaiting_player_input = false
	var unit = _input_unit

	# Log the pass
	var action = CombatAction.create_skip(unit, "Passed")
	_pending_actions.append(action)
	_result.add_action(action)
	action_performed.emit(action)
	print("[Combat] %s passes their turn" % unit.display_name)

	# Set remaining actions to 1 so _finish_unit_action + _consume_action will end the turn
	_unit_remaining_actions[unit.unit_id] = 1
	_finish_unit_action(unit)

	_input_unit = null
	_selected_action_type = ""
	_selected_ability = null

	if not _check_combat_end():
		_continue_to_next_turn()


## Check if combat is waiting for player input.
func is_awaiting_player_input() -> bool:
	return _awaiting_player_input


## Continue combat flow after player action: auto-execute enemies, then prompt next player.
## Uses async delays between enemy actions for visual clarity.
func _continue_to_next_turn() -> void:
	# Auto-execute all enemy turns until it's a player's turn (or combat ends)
	var is_first_enemy_action := true
	while _is_combat_active and not _awaiting_player_input:
		# Check if current multi-action unit still has actions
		if _current_multi_action_unit != null:
			var remaining = _unit_remaining_actions.get(_current_multi_action_unit.unit_id, 0)
			if remaining > 0 and _current_multi_action_unit.is_alive:
				if _current_multi_action_unit.team == CombatUnit.Team.PLAYER:
					# Player unit has more actions - prompt for input
					_awaiting_player_input = true
					_input_unit = _current_multi_action_unit
					var available = _get_available_actions(_current_multi_action_unit)
					player_input_required.emit(_current_multi_action_unit, available)
					return
				else:
					# Enemy unit - execute automatically with delay for visual pacing
					if not is_first_enemy_action:
						await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
					is_first_enemy_action = false
					# v2.1 Fix: Re-check unit validity after await (may have been freed)
					if _current_multi_action_unit == null:
						push_warning("[Combat] _current_multi_action_unit became null after delay, breaking loop")
						break
					_process_unit_turn_step(_current_multi_action_unit)
					if _check_combat_end():
						return
					continue

		# Round boundary check
		if _turn_queue.is_round_complete():
			_current_round += 1
			_tick_all_buffs()
			_tick_all_statuses()
			_turn_queue.start_new_round()
			_apply_round_start_passives()
			_process_round_start_tag_effects()
			_process_round_start_deaths()  # Emit death actions for DOT/tag kills
			_unit_remaining_actions.clear()
			round_ended.emit(_current_round)
			if _check_combat_end():
				return

		# Get next unit
		var unit = _turn_queue.get_next_unit()
		if unit == null:
			return

		# Initialize action count
		if not _unit_remaining_actions.has(unit.unit_id):
			var eff_speed = unit.get_effective_speed()
			_unit_remaining_actions[unit.unit_id] = _calculate_actions_for_speed(eff_speed)
			print("[MultiAction] unit=%s speed=%d actions=%d" % [
				unit.display_name, eff_speed, _unit_remaining_actions[unit.unit_id]])

		_current_multi_action_unit = unit

		if unit.team == CombatUnit.Team.PLAYER:
			# Player's turn - wait for input
			_awaiting_player_input = true
			_input_unit = unit
			var available = _get_available_actions(unit)
			player_input_required.emit(unit, available)
			return
		else:
			# Enemy's turn - auto-execute with delay for visual pacing
			if not is_first_enemy_action:
				await get_tree().create_timer(ENEMY_ACTION_DELAY).timeout
			is_first_enemy_action = false
			_process_unit_turn_step(unit)
			if _check_combat_end():
				return


# ============================================================================
# COMBAT TAG EFFECTS (T4 Regional Set Bonuses)
# ============================================================================

## Central trigger: check all combat_tag_effects on a unit for a given trigger.
## context: {"target": CombatUnit, "attacker": CombatUnit} depending on trigger.
func _check_tag_effects(unit: CombatUnit, trigger_name: String, context: Dictionary = {}) -> void:
	if unit.combat_tag_effects.is_empty():
		return
	for effect in unit.combat_tag_effects:
		if effect.get("trigger", "") != trigger_name:
			continue
		var item_id: String = effect.get("item_id", "")

		# on_low_hp: check HP threshold
		if trigger_name == "on_low_hp":
			var threshold: float = effect.get("threshold", 0.25)
			var hp_pct: float = float(unit.current_health) / float(unit.max_health)
			if hp_pct > threshold:
				continue

		# Handle "once" flag (on_low_hp effects)
		if effect.get("once", false):
			if unit._triggered_once_effects.has(item_id):
				continue

		# Roll chance (JSON 0.0-1.0; default 1.0 = always)
		var chance: float = effect.get("chance", 1.0)
		if chance < 1.0:
			if not SeededRNG.roll_chance(chance * 100.0, _rng):
				continue

		# Mark "once" effects as triggered
		if effect.get("once", false):
			unit._triggered_once_effects[item_id] = true

		_execute_tag_effect(unit, effect, context)


## Execute a single combat tag effect that passed its chance roll.
func _execute_tag_effect(unit: CombatUnit, effect: Dictionary, context: Dictionary) -> void:
	var effect_type: String = effect.get("effect", "")
	match effect_type:
		"apply_status":
			_tag_effect_apply_status(unit, effect, context)
		"damage_random_enemy":
			_tag_effect_damage_random_enemy(unit, effect)
		"buff_stat":
			_tag_effect_buff_stat(unit, effect)
		"heal":
			_tag_effect_heal(unit, effect)
		"reduce_cooldown":
			_tag_effect_reduce_cooldown(unit, effect)
		_:
			push_warning("[TagEffect] Unknown effect type: %s" % effect_type)


## apply_status: Apply a status to a target based on trigger context.
func _tag_effect_apply_status(unit: CombatUnit, effect: Dictionary, context: Dictionary) -> void:
	var status_id: String = effect.get("status", "")
	var item_id: String = effect.get("item_id", "")
	if status_id == "":
		return

	# Determine target based on trigger
	var target: CombatUnit = null
	var trigger: String = effect.get("trigger", "")
	match trigger:
		"on_attack":
			target = context.get("target")
		"on_melee_hit_received":
			target = context.get("attacker")
		_:
			target = context.get("target")

	if target == null or not target.is_alive:
		return

	# Check resist/immunity
	var resist_result = target.would_block_status(status_id)
	if resist_result["blocked"]:
		print("[TagEffect] blocked unit=%s target=%s status=%s reason=%s item=%s" % [
			unit.display_name, target.display_name, status_id, resist_result["reason"], item_id])
		return

	var duration: int = int(effect.get("duration", 2))
	duration += resist_result["duration_delta"]
	duration = maxi(1, duration)
	var internal_duration = _compute_internal_status_duration(duration)

	target.apply_status_v1(status_id, internal_duration, "tag_" + item_id)
	status_changed.emit(target.unit_id)

	print("[TagEffect] apply_status unit=%s target=%s status=%s duration=%d item=%s" % [
		unit.display_name, target.display_name, status_id, duration, item_id])

	var action = CombatAction.new()
	action.action_type = CombatAction.ActionType.BUFF
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.status_applied = status_id
	action.message = "%s: %s!" % [_get_tag_effect_label(item_id), status_id.capitalize()]
	action_performed.emit(action)


## damage_random_enemy: Deal flat damage to a random alive enemy.
func _tag_effect_damage_random_enemy(unit: CombatUnit, effect: Dictionary) -> void:
	var damage_val: int = int(effect.get("damage", 0))
	var dmg_type: String = effect.get("damage_type", "physical")
	var item_id: String = effect.get("item_id", "")
	if damage_val <= 0:
		return

	var enemies: Array = _enemy_units if unit.team == CombatUnit.Team.PLAYER else _player_units
	var alive: Array = enemies.filter(func(e): return e.is_alive)
	if alive.is_empty():
		return

	var target: CombatUnit = alive[_rng.randi() % alive.size()]
	var actual: int = target.take_damage(damage_val, dmg_type)

	print("[TagEffect] damage_random unit=%s target=%s dmg=%d type=%s item=%s" % [
		unit.display_name, target.display_name, actual, dmg_type, item_id])

	var action = CombatAction.new()
	action.action_type = CombatAction.ActionType.BUFF
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.damage_dealt = actual
	action.message = "%s: %d %s dmg!" % [_get_tag_effect_label(item_id), actual, dmg_type]
	action_performed.emit(action)

	if not target.is_alive:
		var death_action = CombatAction.create_death(target)
		_pending_actions.append(death_action)
		_result.add_action(death_action)
		action_performed.emit(death_action)
		# Trigger on_kill passives (but NOT on_kill tag effects to prevent infinite loops)
		_trigger_on_kill_passives(unit, target.source_id)


## buff_stat: Apply a temporary stat buff to self.
func _tag_effect_buff_stat(unit: CombatUnit, effect: Dictionary) -> void:
	var stat: String = effect.get("stat", "")
	var value: int = int(effect.get("value", 0))
	var duration: int = int(effect.get("duration", 99))
	var item_id: String = effect.get("item_id", "")
	if stat == "" or value == 0:
		return

	var buff_stats: Dictionary = {stat: value}
	unit.apply_buff("tag_" + item_id, buff_stats, duration)

	print("[TagEffect] buff_stat unit=%s stat=%s value=%d duration=%d item=%s" % [
		unit.display_name, stat, value, duration, item_id])

	var action = CombatAction.new()
	action.action_type = CombatAction.ActionType.BUFF
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.target_id = unit.unit_id
	action.target_name = unit.display_name
	action.message = "%s: +%d %s" % [_get_tag_effect_label(item_id), value, stat.to_upper()]
	action_performed.emit(action)


## heal: Heal self by flat value.
func _tag_effect_heal(unit: CombatUnit, effect: Dictionary) -> void:
	var value: int = int(effect.get("value", 0))
	var item_id: String = effect.get("item_id", "")
	if value <= 0 or not unit.is_alive:
		return

	var actual: int = unit.heal(value)
	if actual > 0:
		print("[TagEffect] heal unit=%s value=%d actual=%d item=%s" % [
			unit.display_name, value, actual, item_id])

		var action = CombatAction.new()
		action.action_type = CombatAction.ActionType.BUFF
		action.actor_id = unit.unit_id
		action.actor_name = unit.display_name
		action.target_id = unit.unit_id
		action.target_name = unit.display_name
		action.healing_done = actual
		action.message = "%s: +%d HP" % [_get_tag_effect_label(item_id), actual]
		action_performed.emit(action)


## reduce_cooldown: Reduce all ability cooldowns by value.
func _tag_effect_reduce_cooldown(unit: CombatUnit, effect: Dictionary) -> void:
	var value: int = int(effect.get("value", 0))
	var item_id: String = effect.get("item_id", "")
	if value <= 0:
		return

	var reduced_any: bool = false
	if unit.weapon_ability_cooldown > 0:
		unit.weapon_ability_cooldown = maxi(0, unit.weapon_ability_cooldown - value)
		reduced_any = true
	if unit.ability_a_cooldown > 0:
		unit.ability_a_cooldown = maxi(0, unit.ability_a_cooldown - value)
		reduced_any = true
	if unit.ability_b_cooldown > 0:
		unit.ability_b_cooldown = maxi(0, unit.ability_b_cooldown - value)
		reduced_any = true
	for idx in range(unit.equip_ability_cooldowns.size()):
		if unit.equip_ability_cooldowns[idx] > 0:
			unit.equip_ability_cooldowns[idx] = maxi(0, unit.equip_ability_cooldowns[idx] - value)
			reduced_any = true

	if reduced_any:
		print("[TagEffect] reduce_cooldown unit=%s value=%d item=%s" % [
			unit.display_name, value, item_id])

		var action = CombatAction.new()
		action.action_type = CombatAction.ActionType.BUFF
		action.actor_id = unit.unit_id
		action.actor_name = unit.display_name
		action.target_id = unit.unit_id
		action.target_name = unit.display_name
		action.message = "%s: CD -%d" % [_get_tag_effect_label(item_id), value]
		action_performed.emit(action)


## Get short display label for tag effect pop text.
func _get_tag_effect_label(item_id: String) -> String:
	var template = DataRegistry.get_item_template(item_id)
	if template != null:
		return template.display_name
	return item_id


## Fire combat_start tag effects for all player units.
func _process_combat_start_tag_effects() -> void:
	for unit in _player_units:
		if unit.is_alive:
			_check_tag_effects(unit, "combat_start")


## Fire round_start tag effects for all alive player units.
func _process_round_start_tag_effects() -> void:
	for unit in _player_units:
		if unit.is_alive:
			_check_tag_effects(unit, "round_start")
