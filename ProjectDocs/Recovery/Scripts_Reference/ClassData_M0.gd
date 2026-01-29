## ClassData.gd
## Data container for class definitions.
## Source: GDD Sections 15, 22, 24
class_name ClassData
extends RefCounted

# Core Identity
var class_id: String = ""
var display_name: String = ""
var description: String = ""

# Unlock Requirements
var unlock_region: int = 1

# Base Stats (flat values per GDD 32.1.2)
var base_stats: Dictionary = {}

# Ability References (IDs, not objects)
var ability_a_id: String = ""
var ability_b_id: String = ""
var passive_a_id: String = ""
var passive_b_id: String = ""

# Equipment Restrictions
var weapon_types: Array[String] = []

# Factory method to create from dictionary (JSON data)
static func from_dict(data: Dictionary) -> ClassData:
	var instance = ClassData.new()

	instance.class_id = data.get("class_id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.unlock_region = data.get("unlock_region", 1)
	instance.base_stats = data.get("base_stats", {})
	instance.ability_a_id = data.get("ability_a_id", "")
	instance.ability_b_id = data.get("ability_b_id", "")
	instance.passive_a_id = data.get("passive_a_id", "")
	instance.passive_b_id = data.get("passive_b_id", "")

	# Convert weapon_types array
	var weapons = data.get("weapon_types", [])
	instance.weapon_types = []
	for w in weapons:
		instance.weapon_types.append(str(w))

	return instance

# Validation helper
func is_valid() -> bool:
	return class_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "ClassData(%s: %s)" % [class_id, display_name]
