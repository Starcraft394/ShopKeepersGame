## CombatResult.gd
## Summary of a completed combat encounter.
##
## Source: MVP_Milestones.md (M1)
class_name CombatResult
extends RefCounted

# ============================================================================
# ENUMS
# ============================================================================

enum Outcome {
	VICTORY,       # All enemies defeated
	DEFEAT,        # All players defeated
	FLEE,          # Player fled (not in MVP)
	DRAW           # Edge case / timeout
}

# ============================================================================
# DATA
# ============================================================================

var outcome: Outcome = Outcome.VICTORY
var is_victory: bool:
	get: return outcome == Outcome.VICTORY
var total_rounds: int = 0
var total_turns: int = 0

# Unit final states
var surviving_heroes: Array = []      # Array of unit_id strings
var fallen_heroes: Array = []         # Array of unit_id strings
var defeated_enemies: Array = []      # Array of unit_id strings

# Combat statistics
var total_damage_dealt_by_players: int = 0
var total_damage_dealt_by_enemies: int = 0
var total_healing_done: int = 0
var weapon_abilities_used: int = 0
var status_effects_applied: int = 0

# Action log
var action_log: Array = []  # Array of CombatAction

# Rewards (placeholder for M2+)
var gold_earned: int = 0
var materials_earned: Dictionary = {}
var items_dropped: Array = []

# RNG for deterministic loot rolling
var _rng: RandomNumberGenerator = null

# Guard to prevent double-adding rewards to stash
var _stash_applied: bool = false

# Combat context for loot bias (dungeon_id, region_id, town_id)
var _context: Dictionary = {}

# Boss encounter flag - affects loot table selection
var is_boss_encounter: bool = false
var is_campaign_victory: bool = false


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func set_context(ctx: Dictionary) -> void:
	_context = ctx


func _get_bias_tags() -> Array:
	var tags: Array = []
	# Add region tag dynamically
	var region_id: String = _context.get("region_id", "")
	if region_id != "":
		tags.append(region_id)
	# Add dungeon encounter_tags from data
	var dungeon_id: String = _context.get("dungeon_id", "")
	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	if dungeon != null:
		for tag in dungeon.encounter_tags:
			if tag not in tags:
				tags.append(tag)
	return tags


func _pick_biased_item_id(table_id: String, bias_tags: Array) -> String:
	var table = DataRegistry.get_loot_table(table_id)
	if table == null:
		return ""

	# Build weighted list filtered by bias tags
	var filtered: Array = []
	for entry in table.entries:
		var entry_id: String = entry.get("item_id", "")
		if entry_id == "":
			continue
		var template = DataRegistry.get_item_template(entry_id)
		if template == null:
			continue
		# Check if template tags overlap with bias_tags
		var has_match = false
		for tag in template.tags:
			if tag in bias_tags:
				has_match = true
				break
		if has_match:
			filtered.append({ "value": entry_id, "weight": float(entry.get("weight", 1)) })

	if filtered.is_empty():
		return ""

	return SeededRNG.choose_weighted(filtered, _rng)

# ============================================================================
# INITIALIZATION
# ============================================================================

func set_outcome_from_combat(player_units: Array, enemy_units: Array) -> void:
	surviving_heroes.clear()
	fallen_heroes.clear()
	defeated_enemies.clear()

	var players_alive = false
	var enemies_alive = false

	for unit in player_units:
		if unit.is_alive:
			surviving_heroes.append(unit.unit_id)
			players_alive = true
		else:
			fallen_heroes.append(unit.unit_id)

	for unit in enemy_units:
		if not unit.is_alive:
			defeated_enemies.append(unit.unit_id)
		else:
			enemies_alive = true

	if not enemies_alive and players_alive:
		outcome = Outcome.VICTORY
	elif not players_alive:
		outcome = Outcome.DEFEAT
	else:
		outcome = Outcome.DRAW


func add_action(action: CombatAction) -> void:
	action.round_number = total_rounds
	action.turn_number = total_turns
	action_log.append(action)

	# Update statistics
	if action.action_type == CombatAction.ActionType.BASIC_ATTACK or \
	   action.action_type == CombatAction.ActionType.WEAPON_ABILITY or \
	   action.action_type == CombatAction.ActionType.EQUIPMENT_ABILITY:
		if action.actor_id.begins_with("hero"):
			total_damage_dealt_by_players += action.damage_dealt
		else:
			total_damage_dealt_by_enemies += action.damage_dealt

		if action.action_type == CombatAction.ActionType.WEAPON_ABILITY:
			weapon_abilities_used += 1

	if action.status_applied != "":
		status_effects_applied += 1

	total_healing_done += action.healing_done


# ============================================================================
# REWARD CALCULATION (Placeholder)
# ============================================================================

# Gear drop rate scaling: base % per floor index (0-3)
const FLOOR_DROP_BONUS := [1, 2, 3, 5]

# Quality roll weights for SHOP equipment: Q0=70%, Q1=20%, Q2=9%, Q3=1%
const QUALITY_WEIGHTS := [
	{ "value": 0, "weight": 70.0 },
	{ "value": 1, "weight": 20.0 },
	{ "value": 2, "weight": 9.0 },
	{ "value": 3, "weight": 1.0 }
]

# Quality roll weights for DUNGEON gear drops: Q2=85%, Q3=15% (Rare or Epic only)
const GEAR_DROP_QUALITY_WEIGHTS := [
	{ "value": 2, "weight": 85.0 },
	{ "value": 3, "weight": 15.0 }
]


## Map dungeon floor index to equipment tier (floor 0→T1, floor 1→T2, floor 2→T3, floor 3+→T4).
static func get_equipment_tier_for_floor(floor_index: int) -> int:
	return clampi(floor_index + 1, 1, 4)


## Calculate gear drop chance based on floor index and completed regions.
## Formula: (completed_regions * 1 + floor_bonus) / 100, with elite/boss multipliers.
static func get_gear_drop_chance(floor_index: int, is_elite: bool, is_boss: bool, completed_region_count: int = -1) -> float:
	var completed: int = completed_region_count if completed_region_count >= 0 else GameContext.get_completed_region_count()
	var base: float = (completed * 1 + FLOOR_DROP_BONUS[clampi(floor_index, 0, FLOOR_DROP_BONUS.size() - 1)]) / 100.0
	if is_boss:
		return base * 2.5
	elif is_elite:
		return base * 1.5
	return base


## Roll for a gear drop. Returns ItemInstance or null.
## Uses region+tier equipment pool based on floor index with scaled drop chance.
func _roll_gear_drop(bias_tags: Array) -> ItemInstance:
	if _rng == null:
		return null

	# Calculate drop chance from floor + completed regions
	var floor_index: int = _context.get("floor_index", 0)
	var is_elite_room: bool = GameContext.is_current_room_elite()
	var drop_chance: float = get_gear_drop_chance(floor_index, is_elite_room, is_boss_encounter)

	var source_type := "combat_normal"
	if is_boss_encounter:
		source_type = "boss"
	elif is_elite_room:
		source_type = "combat_elite"

	# Roll for gear drop
	var roll: float = _rng.randf()
	if roll >= drop_chance:
		return null

	# Determine equipment tier from floor and region
	var region_id: String = _context.get("region_id", "")
	if region_id == "":
		return null
	var equip_tier: int = get_equipment_tier_for_floor(floor_index)

	# Query equipment pool for this region+tier, with fallback chain:
	# 1. region_X + tier_N (region-specific gear at this tier)
	# 2. base + tier_N (universal gear at this tier — e.g., T1 starter items)
	# 3. region_X + tier_N+1 (bump tier up if nothing exists)
	var pool: Array = DataRegistry.get_equipment_for_region_tier(region_id, equip_tier)
	if pool.is_empty():
		pool = DataRegistry.get_equipment_for_region_tier("base", equip_tier)
	if pool.is_empty() and equip_tier < 4:
		pool = DataRegistry.get_equipment_for_region_tier(region_id, equip_tier + 1)
	if pool.is_empty():
		return null

	# Select random gear from pool
	var gear_id: String = pool[_rng.randi() % pool.size()]

	# Roll quality tier (Rare or Epic only for dungeon drops)
	var quality_tier: int = SeededRNG.choose_weighted(GEAR_DROP_QUALITY_WEIGHTS, _rng)

	# Create ItemInstance
	var template = DataRegistry.get_item_template(gear_id)
	if template == null:
		return null

	var instance = ItemInstance.new()
	instance.template_id = gear_id
	instance.quantity = 1
	instance.quality_tier = quality_tier

	# Build display name with quality prefix
	var prefix: String = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
	var base_name: String = prefix + template.display_name

	# Apply regional affix
	var affix: Dictionary = DataRegistry.get_regional_affix(region_id)
	if not affix.is_empty():
		instance.source_region = region_id
		instance.affix_id = region_id
		var affix_stat_bonus = affix.get("stat_bonus", {})
		instance.affix_stats = affix_stat_bonus if affix_stat_bonus is Dictionary else {}
		instance.affix_prefix = affix.get("prefix", "")
		instance.display_name = instance.affix_prefix + " " + base_name
	else:
		instance.display_name = base_name

	print("[Loot] gear_drop item=%s q=%d chance=%.1f%% source=%s floor=%d tier=T%d pool=%d affix=%s" % [gear_id, quality_tier, drop_chance * 100.0, source_type, floor_index, equip_tier, pool.size(), instance.affix_prefix])
	return instance


## Roll quality tier for gear drops (0-3).
## Distribution: Q0=70%, Q1=20%, Q2=9%, Q3=1%
static func roll_gear_quality(rng: RandomNumberGenerator) -> int:
	if rng == null:
		return 0
	return SeededRNG.choose_weighted(QUALITY_WEIGHTS, rng)


## Get the appropriate loot table ID based on encounter type.
## Non-boss encounters use material-only tables.
func _get_effective_table_id(original_table_id: String) -> String:
	if is_boss_encounter:
		return original_table_id  # Boss can use any table

	# Non-boss: downgrade boss/elite tables to uncommon (materials + consumables)
	if original_table_id.ends_with("_boss") or original_table_id.ends_with("_elite"):
		return original_table_id.rsplit("_", true, 1)[0] + "_uncommon"
	return original_table_id  # Keep common/uncommon as-is


func calculate_rewards(enemy_data: Array) -> void:
	# Reset rewards
	gold_earned = 0
	items_dropped = []

	# Get bias tags for current combat context
	var bias_tags = _get_bias_tags()
	print("[LootBias] dungeon=%s tags=%s boss=%s" % [
		_context.get("dungeon_id", ""), str(bias_tags), str(is_boss_encounter)
	])

	# Temporary dict to merge quantities by item_id
	var merged: Dictionary = {}
	var _sample_table_printed := false

	for unit in enemy_data:
		if not unit.is_alive:
			var monster = DataRegistry.get_monster(unit.source_id)
			if monster != null:
				# Print sample table once
				if not _sample_table_printed and monster.loot_table_id != "":
					var effective_id = _get_effective_table_id(monster.loot_table_id)
					print("[LootBias] sample_table=%s (effective=%s)" % [monster.loot_table_id, effective_id])
					_sample_table_printed = true
				# Gold: simple average
				gold_earned += (monster.gold_drop_min + monster.gold_drop_max) / 2

				# Loot: roll from loot table if available
				if monster.loot_table_id != "" and _rng != null:
					var effective_table_id = _get_effective_table_id(monster.loot_table_id)
					var table = DataRegistry.get_loot_table(effective_table_id)
					if table != null:
						var rolls = SeededRNG.roll_loot_table(table, _rng)
						for drop in rolls:
							var item_id: String = drop.get("item_id", "")
							var qty: int = drop.get("quantity", 1)
							if item_id != "":
								# Check if item matches bias, if not try biased reroll
								var template = DataRegistry.get_item_template(item_id)
								var matches_bias = false
								if template != null:
									for tag in template.tags:
										if tag in bias_tags:
											matches_bias = true
											break
								if not matches_bias:
									var biased_id = _pick_biased_item_id(effective_table_id, bias_tags)
									if biased_id != "":
										item_id = biased_id
								merged[item_id] = merged.get(item_id, 0) + qty

					# Floor 1 bonus: base materials drop in all dungeons on first floor
					var floor_idx: int = _context.get("floor_index", -1)
					if floor_idx == 0:
						var base_table = DataRegistry.get_loot_table("lt_base_materials")
						if base_table != null:
							var base_rolls = SeededRNG.roll_loot_table(base_table, _rng)
							for base_drop in base_rolls:
								var base_id: String = base_drop.get("item_id", "")
								var base_qty: int = base_drop.get("quantity", 1)
								if base_id != "":
									merged[base_id] = merged.get(base_id, 0) + base_qty
			else:
				gold_earned += 10  # Fallback

	# Convert merged drops to ItemInstance objects
	for item_id in merged.keys():
		var template = DataRegistry.get_item_template(item_id)
		if template != null:
			var instance = ItemInstance.from_template(template, merged[item_id], _rng)
			items_dropped.append(instance)
		else:
			push_warning("[CombatResult] Unknown item template: %s" % item_id)

	# Gear drops v1: Small chance to drop equipment after combat
	var gear_drop = _roll_gear_drop(bias_tags)
	if gear_drop != null:
		items_dropped.append(gear_drop)

	# Challenge level scaling (session-only playtest tool)
	if GameContext.challenge_level > 0:
		gold_earned = int(gold_earned * GameContext.get_gold_multiplier())
		# Boss bonus: extra loot roll at challenge >= 5
		if GameContext.boss_bonus_enabled() and is_boss_encounter and _rng != null:
			for unit in enemy_data:
				if not unit.is_alive:
					var monster = DataRegistry.get_monster(unit.source_id)
					if monster != null and monster.loot_table_id != "":
						var eff_table = _get_effective_table_id(monster.loot_table_id)
						var table = DataRegistry.get_loot_table(eff_table)
						if table != null:
							var bonus_rolls = SeededRNG.roll_loot_table(table, _rng)
							for bdrop in bonus_rolls:
								var bid: String = bdrop.get("item_id", "")
								var bqty: int = bdrop.get("quantity", 1)
								if bid != "":
									var btemplate = DataRegistry.get_item_template(bid)
									if btemplate:
										items_dropped.append(ItemInstance.from_template(btemplate, bqty, _rng))
							print("[Challenge] Boss bonus loot roll (CL=%d)" % GameContext.challenge_level)
						break  # One bonus roll from first dead boss only

	# Validation print with room/floor context
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()
	var floor_num = GameContext.get_current_floor()
	var dungeon = DataRegistry.get_dungeon(GameContext.get_current_dungeon_id()) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4
	print("[RewardsScope] boss=%s room=%d/%d floor=%d/%d items=%d gold=%d" % [
		str(is_boss_encounter), room_idx + 1, rooms_per_floor, floor_num, floor_count,
		items_dropped.size(), gold_earned
	])
	for d in items_dropped:
		print("  [Drop] %s x%d (Q%d)" % [d.display_name, d.quantity, d.quality_tier])


# ============================================================================
# DEBUG / OUTPUT
# ============================================================================

func get_outcome_string() -> String:
	match outcome:
		Outcome.VICTORY: return "VICTORY"
		Outcome.DEFEAT: return "DEFEAT"
		Outcome.FLEE: return "FLED"
		Outcome.DRAW: return "DRAW"
		_: return "UNKNOWN"


func print_summary() -> void:
	print("\n" + "=".repeat(50))
	print("           COMBAT RESULT: %s" % get_outcome_string())
	print("=".repeat(50))
	print("Rounds: %d | Total Turns: %d" % [total_rounds, total_turns])
	print("")
	print("--- Heroes ---")
	print("  Surviving: %s" % str(surviving_heroes))
	print("  Fallen:    %s" % str(fallen_heroes))
	print("")
	print("--- Enemies ---")
	print("  Defeated: %s" % str(defeated_enemies))
	print("")
	print("--- Statistics ---")
	print("  Player Damage Dealt:  %d" % total_damage_dealt_by_players)
	print("  Enemy Damage Dealt:   %d" % total_damage_dealt_by_enemies)
	print("  Weapon Abilities:     %d" % weapon_abilities_used)
	print("  Status Effects:       %d" % status_effects_applied)
	print("")
	if outcome == Outcome.VICTORY:
		print("--- Rewards ---")
		print("  Gold Earned: %d" % gold_earned)
	print("=".repeat(50) + "\n")


func print_action_log() -> void:
	print("\n--- Combat Log ---")
	for action in action_log:
		print(action.get_log_string())
	print("--- End Log ---\n")


func get_summary_dict() -> Dictionary:
	return {
		"outcome": get_outcome_string(),
		"total_rounds": total_rounds,
		"total_turns": total_turns,
		"surviving_heroes": surviving_heroes,
		"fallen_heroes": fallen_heroes,
		"defeated_enemies": defeated_enemies,
		"damage_by_players": total_damage_dealt_by_players,
		"damage_by_enemies": total_damage_dealt_by_enemies,
		"gold_earned": gold_earned
	}
