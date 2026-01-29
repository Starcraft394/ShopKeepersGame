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


func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


func set_context(ctx: Dictionary) -> void:
	_context = ctx


func _get_bias_tags() -> Array:
	var tags: Array = ["region_1"]  # Always include region
	var dungeon_id = _context.get("dungeon_id", "")
	match dungeon_id:
		"dungeon_greenroot":
			tags.append("greenroot")
			tags.append("forest")
		"dungeon_timberfall":
			tags.append("timberfall")
			tags.append("frontier")
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
	   action.action_type == CombatAction.ActionType.WEAPON_ABILITY:
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

# Region 1 equipment whitelist for gear drops
const REGION1_GEAR_WHITELIST := ["crude_sword", "wooden_shield", "iron_dagger", "reinforced_shield"]

# Gear drop chance by encounter type: normal=8%, elite=15%, boss=25%
const GEAR_DROP_CHANCE_NORMAL := 0.08
const GEAR_DROP_CHANCE_ELITE := 0.15
const GEAR_DROP_CHANCE_BOSS := 0.25

# Quality roll weights: Q0=70%, Q1=20%, Q2=9%, Q3=1%
const QUALITY_WEIGHTS := [
	{ "value": 0, "weight": 70.0 },
	{ "value": 1, "weight": 20.0 },
	{ "value": 2, "weight": 9.0 },
	{ "value": 3, "weight": 1.0 }
]


## Roll for a gear drop. Returns ItemInstance or null.
## Only drops from Region 1 whitelist. Quality rolled separately.
func _roll_gear_drop(bias_tags: Array) -> ItemInstance:
	if _rng == null:
		return null

	# Check if we're in region_1
	if not "region_1" in bias_tags:
		return null

	# Determine drop chance based on encounter type
	var drop_chance := GEAR_DROP_CHANCE_NORMAL
	var source_type := "combat_normal"
	if is_boss_encounter:
		drop_chance = GEAR_DROP_CHANCE_BOSS
		source_type = "boss"
	elif GameContext.is_current_room_elite():
		drop_chance = GEAR_DROP_CHANCE_ELITE
		source_type = "combat_elite"

	# Roll for gear drop
	var roll = _rng.randf()
	if roll >= drop_chance:
		return null  # No gear drop this time

	# Select random gear from whitelist
	var gear_id = REGION1_GEAR_WHITELIST[_rng.randi() % REGION1_GEAR_WHITELIST.size()]

	# Roll quality tier
	var quality_tier = SeededRNG.choose_weighted(QUALITY_WEIGHTS, _rng)

	# Create ItemInstance
	var template = DataRegistry.get_item_template(gear_id)
	if template == null:
		return null

	var instance = ItemInstance.new()
	instance.template_id = gear_id
	instance.quantity = 1
	instance.quality_tier = quality_tier

	# Build display name with quality prefix
	var prefix = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
	instance.display_name = prefix + template.display_name

	print("[Loot] gear_drop item=%s q=%d source=%s" % [gear_id, quality_tier, source_type])
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

	# Non-boss: override to material-only tables
	match original_table_id:
		"lt_region1_boss", "lt_region1_elite":
			return "lt_region1_uncommon"  # Downgrade to materials + consumables
		_:
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
