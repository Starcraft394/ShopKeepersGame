## RaceData.gd
## Data container for race definitions.
## Source: GDD Sections 8, 15
class_name RaceData
extends RefCounted

# Core Identity
var race_id: String = ""
var display_name: String = ""
var description: String = ""

# Unlock Requirements
var unlock_region: int = 1

# Base Stat Modifiers (flat values, applied to hero base stats)
var stat_modifiers: Dictionary = {}

# Racial Passive (unique mechanical trait, NOT stat bonuses per GDD)
var racial_passive_id: String = ""

# Visual/Thematic
var portrait_path: String = ""

# Factory method
static func from_dict(data: Dictionary) -> RaceData:
	var instance = RaceData.new()

	# Handle both "id" and "race_id" for flexibility
	instance.race_id = data.get("race_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.unlock_region = data.get("unlock_region", 1)
	var stat_modifiers_val = data.get("stat_modifiers", {})
	instance.stat_modifiers = stat_modifiers_val if stat_modifiers_val is Dictionary else {}
	# Handle both "racial_passive_id" and "passive_id" for flexibility
	instance.racial_passive_id = data.get("racial_passive_id", data.get("passive_id", ""))
	instance.portrait_path = data.get("portrait_path", "")

	return instance

# Validation helper
func is_valid() -> bool:
	return race_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "RaceData(%s: %s)" % [race_id, display_name]
