## CombatAction.gd
## Represents a single action taken during combat.
## Used for logging and potential replay/undo systems.
##
## Source: MVP_Milestones.md (M1)
class_name CombatAction
extends RefCounted

# ============================================================================
# ENUMS
# ============================================================================

enum ActionType {
	BASIC_ATTACK,
	WEAPON_ABILITY,
	CLASS_ABILITY,
	EQUIPMENT_ABILITY,  # T4 equipment-granted ability
	ITEM_USE,
	SKIP,           # Stunned or otherwise unable to act
	DOOM_TRIGGER,   # Doom damage occurs
	DEATH,
	BUFF            # Buff/debuff application
}

# ============================================================================
# DATA
# ============================================================================

var action_type: ActionType = ActionType.BASIC_ATTACK
var actor_id: String = ""
var actor_name: String = ""
var target_id: String = ""
var target_name: String = ""
var ability_id: String = ""
var ability_name: String = ""
var damage_dealt: int = 0
var healing_done: int = 0
var status_applied: String = ""
var status_stacks: int = 0
var was_critical: bool = false
var was_evaded: bool = false
var round_number: int = 0
var turn_number: int = 0
var message: String = ""

# AoE action metadata
var is_aoe: bool = false
var targets_hit: int = 0

# ============================================================================
# FACTORY METHODS
# ============================================================================

static func create_attack(actor: CombatUnit, target: CombatUnit, damage: int, is_weapon_ability: bool = false) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.WEAPON_ABILITY if is_weapon_ability else ActionType.BASIC_ATTACK
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.damage_dealt = damage

	if is_weapon_ability:
		action.ability_id = actor.weapon_ability_id
		action.message = "%s uses weapon ability on %s for %d damage!" % [
			actor.display_name, target.display_name, damage]
	else:
		action.message = "%s attacks %s for %d damage." % [
			actor.display_name, target.display_name, damage]

	return action


static func create_skip(actor: CombatUnit, reason: String) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.SKIP
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.message = "%s cannot act: %s" % [actor.display_name, reason]
	return action


static func create_status_applied(actor: CombatUnit, target: CombatUnit, status_id: String, stacks: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.WEAPON_ABILITY
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.status_applied = status_id
	action.status_stacks = stacks
	action.message = "%s applies %s (%d) to %s" % [
		actor.display_name, status_id, stacks, target.display_name]
	return action


static func create_doom_trigger(target: CombatUnit, damage: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.DOOM_TRIGGER
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.damage_dealt = damage
	action.message = "DOOM triggers on %s for %d damage!" % [target.display_name, damage]
	return action


static func create_death(unit: CombatUnit) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.DEATH
	action.actor_id = unit.unit_id
	action.actor_name = unit.display_name
	action.message = "%s has been defeated!" % unit.display_name
	return action


static func create_ability_attack(actor: CombatUnit, target: CombatUnit, ability_id: String, ability_name: String, damage: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.CLASS_ABILITY
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.ability_id = ability_id
	action.damage_dealt = damage
	action.message = "%s uses %s on %s for %d damage!" % [
		actor.display_name, ability_name, target.display_name, damage]
	return action


static func create_heal(actor: CombatUnit, target: CombatUnit, ability_id: String, ability_name: String, heal_amount: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.CLASS_ABILITY
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.ability_id = ability_id
	action.healing_done = heal_amount
	action.message = "%s uses %s on %s, healing %d HP!" % [
		actor.display_name, ability_name, target.display_name, heal_amount]
	return action


static func create_equipment_ability(actor: CombatUnit, target: CombatUnit, ability_id_param: String, ability_name: String, damage: int) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.EQUIPMENT_ABILITY
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.ability_id = ability_id_param
	action.damage_dealt = damage
	action.message = "%s uses [Equip] %s on %s for %d damage!" % [
		actor.display_name, ability_name, target.display_name, damage]
	return action


static func create_buff(actor: CombatUnit, target: CombatUnit, ability_id: String, ability_name: String, buff_desc: String) -> CombatAction:
	var action = CombatAction.new()
	action.action_type = ActionType.CLASS_ABILITY
	action.actor_id = actor.unit_id
	action.actor_name = actor.display_name
	action.target_id = target.unit_id
	action.target_name = target.display_name
	action.ability_id = ability_id
	action.message = "%s uses %s on %s: %s" % [
		actor.display_name, ability_name, target.display_name, buff_desc]
	return action


# ============================================================================
# DEBUG
# ============================================================================

func get_log_string() -> String:
	return "[R%d T%d] %s" % [round_number, turn_number, message]
