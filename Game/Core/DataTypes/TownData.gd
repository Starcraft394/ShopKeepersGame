## TownData.gd
## Data container for town definitions.
## Source: GDD Sections 3, 5
class_name TownData
extends RefCounted

# Core Identity
var town_id: String = ""
var display_name: String = ""
var description: String = ""

# Region Reference
var region_id: String = ""

# Dungeon Reference
var dungeon_id: String = ""

# Facilities in this town (IDs)
var facility_ids: Array[String] = []

# Unlock requirement (region index needed)
var unlock_region: int = 1

# Factory method
static func from_dict(data: Dictionary) -> TownData:
	var instance = TownData.new()

	# Handle both "id" and "town_id" for flexibility
	instance.town_id = data.get("town_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.region_id = data.get("region_id", "")
	instance.dungeon_id = data.get("dungeon_id", "")
	instance.unlock_region = data.get("unlock_region", 1)

	# Convert typed array (clear + append pattern for safety)
	instance.facility_ids.clear()
	var facility_ids_val = data.get("facility_ids", [])
	var facility_ids_arr = facility_ids_val if facility_ids_val is Array else []
	for item in facility_ids_arr:
		instance.facility_ids.append(str(item))

	return instance

# Validation helper
func is_valid() -> bool:
	return town_id != "" and display_name != "" and region_id != ""

# Debug string
func _to_string() -> String:
	return "TownData(%s: %s)" % [town_id, display_name]
