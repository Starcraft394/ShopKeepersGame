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

	# Handle both "id" and "region_id" for flexibility
	instance.region_id = data.get("region_id", data.get("id", ""))
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

	# Convert typed arrays (clear + append pattern for safety)
	instance.town_ids.clear()
	var town_ids_val = data.get("town_ids", [])
	var town_ids_arr = town_ids_val if town_ids_val is Array else []
	for item in town_ids_arr:
		instance.town_ids.append(str(item))

	instance.monster_families.clear()
	var monster_families_val = data.get("monster_families", [])
	var monster_families_arr = monster_families_val if monster_families_val is Array else []
	for item in monster_families_arr:
		instance.monster_families.append(str(item))

	instance.elite_monster_ids.clear()
	var elite_monster_ids_val = data.get("elite_monster_ids", [])
	var elite_monster_ids_arr = elite_monster_ids_val if elite_monster_ids_val is Array else []
	for item in elite_monster_ids_arr:
		instance.elite_monster_ids.append(str(item))

	instance.resource_types.clear()
	var resource_types_val = data.get("resource_types", [])
	var resource_types_arr = resource_types_val if resource_types_val is Array else []
	for item in resource_types_arr:
		instance.resource_types.append(str(item))

	instance.passive_pool_ids.clear()
	var passive_pool_ids_val = data.get("passive_pool_ids", [])
	var passive_pool_ids_arr = passive_pool_ids_val if passive_pool_ids_val is Array else []
	for item in passive_pool_ids_arr:
		instance.passive_pool_ids.append(str(item))

	return instance

# Validation helper
func is_valid() -> bool:
	return region_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "RegionData(%s: %s [R%d])" % [region_id, display_name, region_index]
