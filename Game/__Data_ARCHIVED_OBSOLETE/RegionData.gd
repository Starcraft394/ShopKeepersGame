## RegionData.gd
## Typed data container for region definitions.
## Source: MVP_Scope.md, GDD Section 16
# class_name RegionData  # DISABLED - duplicate of Core/DataTypes/RegionData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var region_index: int = 1
var dungeon_floor_count: int = 1
var monster_families: Array[String] = []

static func from_dict(data: Dictionary) -> RegionData:
	var instance = RegionData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.region_index = data.get("region_index", 1)
	instance.dungeon_floor_count = data.get("dungeon_floor_count", 1)

	var families = data.get("monster_families", [])
	for f in families:
		instance.monster_families.append(str(f))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
