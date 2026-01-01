## AbilityData.gd
## Data container for ability definitions.
## Source: GDD Sections 23, 24
class_name AbilityData
extends RefCounted

# Core Identity
var ability_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification
var ability_type: String = ""  # "basic_attack", "class_a", "class_b", "weapon", "item"
var source_class_id: String = ""  # If class-specific

# Targeting (per GDD 38.3)
var target_type: String = "single_enemy"  # "single_enemy", "single_ally", "self", "all_enemies", "all_allies", "aoe_tile"
var range_min: int = 1
var range_max: int = 1
var requires_los: bool = true

# Cost
var cooldown: int = 0  # Turns before reuse
var resource_cost: Dictionary = {}  # e.g., {"mana": 10}

# Effect
var effect_type: String = "damage"  # "damage", "heal", "buff", "debuff", "status", "summon", "move"
var base_damage: int = 0
var damage_type: String = "physical"  # "physical", "magical", "true"
var base_heal: int = 0

# Status Application
var applies_status_id: String = ""
var status_stacks: int = 1
var status_chance: float = 1.0

# Scaling (flat values, not percentages)
var attack_scaling: float = 1.0  # Multiplier applied to attack stat

# Visual
var icon_path: String = ""
var animation_id: String = ""

# Factory method
static func from_dict(data: Dictionary) -> AbilityData:
	var instance = AbilityData.new()

	# Handle both "id" and "ability_id" for flexibility
	instance.ability_id = data.get("ability_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.ability_type = data.get("ability_type", "")
	instance.source_class_id = data.get("source_class_id", "")
	instance.target_type = data.get("target_type", "single_enemy")
	instance.range_min = data.get("range_min", 1)
	instance.range_max = data.get("range_max", 1)
	instance.requires_los = data.get("requires_los", true)
	instance.cooldown = data.get("cooldown", 0)
	var resource_cost_val = data.get("resource_cost", {})
	instance.resource_cost = resource_cost_val if resource_cost_val is Dictionary else {}
	instance.effect_type = data.get("effect_type", "damage")
	instance.base_damage = data.get("base_damage", 0)
	instance.damage_type = data.get("damage_type", "physical")
	instance.base_heal = data.get("base_heal", 0)
	instance.applies_status_id = data.get("applies_status_id", "")
	instance.status_stacks = data.get("status_stacks", 1)
	instance.status_chance = data.get("status_chance", 1.0)
	instance.attack_scaling = data.get("attack_scaling", 1.0)
	instance.icon_path = data.get("icon_path", "")
	instance.animation_id = data.get("animation_id", "")

	return instance

# Validation helper
func is_valid() -> bool:
	return ability_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "AbilityData(%s: %s [%s])" % [ability_id, display_name, ability_type]
