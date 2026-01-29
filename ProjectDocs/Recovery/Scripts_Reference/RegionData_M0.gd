## RegionData.gd
## Data container for region definitions.
## Source: GDD Sections 3, 16
class_name RegionData
extends RefCounted

# Core Identity
var region_id: String = ""
var display_name: String = ""
var description: String = ""

# Region Index (1-7)
var region_index: int = 1

# Unlock Requirements
var requires_region_id: String = ""  # Previous region that must be completed

# Towns in this Region (IDs)
var town_ids: Array[String] = []

# Dungeon Configuration
var dungeon_floor_count: int = 4
var boss_id: String = ""

# Monster Pools
var monster_families: Array[String] = []
var elite_monster_ids: Array[String] = []

# Resource Types Available
var resource_types: Array[String] = []

# Region Passive Pool (boons available)
var passive_pool_ids: Array[String] = []

# Corruption Level (per GDD Section 3.2)
var corruption_level: String = "none"  # "none", "visual", "event", "active", "full"

# Boss Charge System (per GDD 26.8)
var max_boss_charges: int = 10
var charges_per_floor: int = 1

# Visual
var map_icon_path: String = ""
var background_path: String = ""

# Factory method
static func from_dict(data: Dictionary) -> RegionData:
	var instance = RegionData.new()

	instance.region_id = data.get("region_id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.region_index = data.get("region_index", 1)
	instance.requires_region_id = data.get("requires_region_id", "")
	instance.dungeon_floor_count = data.get("dungeon_floor_count", 4)
	instance.boss_id = data.get("boss_id", "")
	instance.corruption_level = data.get("corruption_level", "none")
	instance.max_boss_charges = data.get("max_boss_charges", 10)
	instance.charges_per_floor = data.get("charges_per_floor", 1)
	instance.map_icon_path = data.get("map_icon_path", "")
	instance.background_path = data.get("background_path", "")

	# Convert arrays
	for arr_name in ["town_ids", "monster_families", "elite_monster_ids", "resource_types", "passive_pool_ids"]:
		var arr = data.get(arr_name, [])
		var typed_arr: Array[String] = []
		for item in arr:
			typed_arr.append(str(item))
		instance.set(arr_name, typed_arr)

	return instance

# Validation helper
func is_valid() -> bool:
	return region_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "RegionData(%s: %s [R%d])" % [region_id, display_name, region_index]
