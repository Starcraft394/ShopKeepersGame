## FacilityData.gd
## Typed data container for facility definitions.
## Source: MVP_Scope.md, GDD Section 18
# class_name FacilityData  # DISABLED - duplicate of Core/DataTypes/FacilityData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var facility_type: String = ""  # "production", "service"
var max_tier: int = 1
var base_slots: int = 1
var produces_item_types: Array[String] = []

static func from_dict(data: Dictionary) -> FacilityData:
	var instance = FacilityData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.facility_type = data.get("facility_type", "")
	instance.max_tier = data.get("max_tier", 1)
	instance.base_slots = data.get("base_slots", 1)

	var types = data.get("produces_item_types", [])
	for t in types:
		instance.produces_item_types.append(str(t))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
