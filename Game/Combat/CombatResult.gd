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

func calculate_rewards(enemy_data: Array) -> void:
	# Calculate gold from defeated enemies
	gold_earned = 0
	for unit in enemy_data:
		if not unit.is_alive:
			var monster = DataRegistry.get_monster(unit.source_id)
			if monster != null:
				# Simple average for now
				gold_earned += (monster.gold_drop_min + monster.gold_drop_max) / 2
			else:
				gold_earned += 10  # Fallback


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
