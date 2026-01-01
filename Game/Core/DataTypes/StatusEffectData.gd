## StatusEffectData.gd
## Data container for status effect registry entries.
## Source: GDD Sections 27, 39, 41.7
## NOTE: This is the AUTHORITATIVE registry. No status may be applied
## unless it exists here (per GDD 41.7 Registry-First Enforcement).
class_name StatusEffectData
extends RefCounted

# Core Identity
var effect_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification (per GDD 27.2, 39.2)
var category: String = ""  # "dot", "control", "buff", "debuff", "countdown"

# Stack Behavior (per GDD 27.3, 39.4)
var max_stacks: int = 1
var stack_type: String = "linear"  # "linear", "threshold", "countdown_extension"

# Duration
var base_duration: int = -1  # -1 = permanent until removed
var duration_type: String = "turns"  # "turns", "permanent"

# Effect Values (flat numbers per GDD 32.1.2)
var base_value: int = 0
var value_per_stack: int = 0

# Resolution
var resolution_timing: String = "turn_end"  # "turn_start", "turn_end", "immediate", "on_countdown_zero"

# Cleanse/Dispel
var is_cleansable: bool = true
var dispel_type: String = "debuff"  # "buff", "debuff", "none"

# UI
var icon_path: String = ""
var color_category: String = "red"  # "red"=damage, "blue"=control, "green"=buff, "purple"=countdown

# Factory method
static func from_dict(data: Dictionary) -> StatusEffectData:
	var instance = StatusEffectData.new()

	# Handle both "id" and "effect_id" for flexibility
	instance.effect_id = data.get("effect_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.category = data.get("category", "")
	instance.max_stacks = data.get("max_stacks", 1)
	instance.stack_type = data.get("stack_type", "linear")
	instance.base_duration = data.get("base_duration", -1)
	instance.duration_type = data.get("duration_type", "turns")
	instance.base_value = data.get("base_value", 0)
	instance.value_per_stack = data.get("value_per_stack", 0)
	instance.resolution_timing = data.get("resolution_timing", "turn_end")
	instance.is_cleansable = data.get("is_cleansable", true)
	instance.dispel_type = data.get("dispel_type", "debuff")
	instance.icon_path = data.get("icon_path", "")
	instance.color_category = data.get("color_category", "red")

	return instance

# Validation helper
func is_valid() -> bool:
	return effect_id != "" and display_name != "" and category != ""

# Check if this is a countdown-type effect
func is_countdown() -> bool:
	return category == "countdown" or stack_type == "countdown_extension"

# Debug string
func _to_string() -> String:
	return "StatusEffectData(%s: %s [%s])" % [effect_id, display_name, category]
