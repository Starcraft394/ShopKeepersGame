## PassiveData.gd
## Data container for passive ability definitions.
## Source: GDD Sections 8, 22, 24
## Updated: M4 Class Kit Integration
class_name PassiveData
extends RefCounted

# Core Identity
var passive_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification
var category: String = ""  # "racial", "class", "item", "region"
var source_type: String = ""  # "race", "class", "equipment", "buff"
var source_class_id: String = ""  # Class this passive belongs to (M4)

# Effect Definition
var effect_type: String = ""  # "stat_modifier", "trigger", "aura", "conditional"
var effect_data: Dictionary = {}

# M4 Simplified Fields
var passive_type: String = ""  # "stat_bonus", "conditional_stat_bonus", "on_kill"
var trigger: String = "always"  # "always", "on_front_row", "on_kill"
var effect: Dictionary = {}  # {stat: "defense", bonus: 2} or {reduce_weapon_cooldown: 1}

# Stacking Rules
var max_stacks: int = 1
var is_unique: bool = true  # Only one instance allowed?

# Visual
var icon_path: String = ""

# Factory method
static func from_dict(data: Dictionary) -> PassiveData:
	var instance = PassiveData.new()

	# Handle both "id" and "passive_id" for flexibility
	instance.passive_id = data.get("passive_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.category = data.get("category", "")
	instance.source_type = data.get("source_type", "")
	instance.source_class_id = data.get("source_class_id", "")
	instance.effect_type = data.get("effect_type", "")
	var effect_data_val = data.get("effect_data", {})
	instance.effect_data = effect_data_val if effect_data_val is Dictionary else {}
	instance.max_stacks = data.get("max_stacks", 1)
	instance.is_unique = data.get("is_unique", true)
	instance.icon_path = data.get("icon_path", "")

	# M4 fields
	instance.passive_type = data.get("passive_type", "")
	instance.trigger = data.get("trigger", "always")
	var effect_val = data.get("effect", {})
	instance.effect = effect_val if effect_val is Dictionary else {}

	return instance

# Validation helper
func is_valid() -> bool:
	return passive_id != "" and display_name != ""

# ============================================================================
# M4 HELPER METHODS
# ============================================================================

## Check if this passive provides a flat stat bonus
func is_stat_bonus() -> bool:
	return passive_type == "stat_bonus" or passive_type == "conditional_stat_bonus"

## Get the stat this passive affects (if stat_bonus type)
func get_bonus_stat() -> String:
	return effect.get("stat", "")

## Get the bonus value (if stat_bonus type)
func get_bonus_value() -> int:
	return effect.get("bonus", 0)

## Check if this passive triggers on kill
func is_on_kill() -> bool:
	return trigger == "on_kill" or passive_type == "on_kill" or passive_type == "on_kill_stacking_buff"

## Check if this is a conditional passive (e.g., front row only)
func is_conditional() -> bool:
	return passive_type == "conditional_stat_bonus" or trigger != "always"

## Get the condition for this passive
func get_condition() -> String:
	return trigger

## Check if condition requires front row
func requires_front_row() -> bool:
	return trigger == "on_front_row"

## Get weapon cooldown reduction (for on_kill passives)
func get_weapon_cooldown_reduction() -> int:
	return effect.get("reduce_weapon_cooldown", 0)

# Debug string
func _to_string() -> String:
	return "PassiveData(%s: %s [%s])" % [passive_id, display_name, passive_type]
