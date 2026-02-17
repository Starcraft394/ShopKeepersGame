## DungeonData.gd
## Data container for dungeon definitions.
## Source: GDD Section 20
class_name DungeonData
extends RefCounted

# Core Identity
var dungeon_id: String = ""
var display_name: String = ""
var description: String = ""

# Region Reference
var region_id: String = ""

# Town Reference
var town_id: String = ""

# Dungeon Configuration
var floor_count: int = 4
var rooms_per_floor: int = 1  # Legacy static value, see min/max_rooms_per_floor
var boss_id: String = ""
var alt_boss_id: String = ""  # Alternate boss (50/50 random pick if set)

# Gear whitelist for equipment drops
var gear_whitelist: Array[String] = []

# Dynamic room generation (2-choice system)
var min_rooms_per_floor: int = 3
var max_rooms_per_floor: int = 5
var choice_b_event_weight: float = 0.65  # Weight for Choice B being Event room
var choice_b_elite_weight: float = 0.35  # Weight for Choice B being Elite combat
var event_table_id: String = ""  # Which event table to use for Event rooms

# Theme tags for encounter filtering
var encounter_tags: Array[String] = []

# Monster pools for themed encounters
var tier1_monster_ids: Array[String] = []
var tier2_monster_ids: Array[String] = []
var elite_monster_ids: Array[String] = []

# Per-floor theming and monster pools
var floor_theme: Array[String] = []
var tier1_by_floor: Array = []  # Array of Array[String]
var tier2_by_floor: Array = []  # Array of Array[String]
var elite_by_floor: Array = []  # Array of Array[String]

# Room types per floor (nested array: [floor_index][room_index] -> room_type string)
# DEPRECATED: Use dynamic 2-choice system instead (min/max_rooms_per_floor, choice weights)
# Valid types: "combat", "elite", "event" (treasure/shrine folded into event)
var room_types_by_floor: Array = []  # Array of Array[String]

# Factory method
static func from_dict(data: Dictionary) -> DungeonData:
	var instance = DungeonData.new()

	# Handle both "id" and "dungeon_id" for flexibility
	instance.dungeon_id = data.get("dungeon_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.region_id = data.get("region_id", "")
	instance.town_id = data.get("town_id", "")
	instance.floor_count = data.get("floor_count", 4)
	instance.rooms_per_floor = data.get("rooms_per_floor", 1)
	instance.boss_id = data.get("boss_id", "")
	instance.alt_boss_id = data.get("alt_boss_id", "")

	# Gear whitelist for equipment drops
	instance.gear_whitelist.clear()
	var gear_whitelist_val = data.get("gear_whitelist", [])
	var gear_whitelist_arr = gear_whitelist_val if gear_whitelist_val is Array else []
	for item in gear_whitelist_arr:
		instance.gear_whitelist.append(str(item))

	# Dynamic room generation fields
	instance.min_rooms_per_floor = data.get("min_rooms_per_floor", 3)
	instance.max_rooms_per_floor = data.get("max_rooms_per_floor", 5)
	instance.choice_b_event_weight = data.get("choice_b_event_weight", 0.65)
	instance.choice_b_elite_weight = data.get("choice_b_elite_weight", 0.35)
	instance.event_table_id = data.get("event_table_id", "")

	# Convert typed arrays (clear + append pattern for safety)
	instance.encounter_tags.clear()
	var encounter_tags_val = data.get("encounter_tags", [])
	var encounter_tags_arr = encounter_tags_val if encounter_tags_val is Array else []
	for item in encounter_tags_arr:
		instance.encounter_tags.append(str(item))

	instance.tier1_monster_ids.clear()
	var tier1_val = data.get("tier1_monster_ids", [])
	var tier1_arr = tier1_val if tier1_val is Array else []
	for item in tier1_arr:
		instance.tier1_monster_ids.append(str(item))

	instance.tier2_monster_ids.clear()
	var tier2_val = data.get("tier2_monster_ids", [])
	var tier2_arr = tier2_val if tier2_val is Array else []
	for item in tier2_arr:
		instance.tier2_monster_ids.append(str(item))

	instance.elite_monster_ids.clear()
	var elite_val = data.get("elite_monster_ids", [])
	var elite_arr = elite_val if elite_val is Array else []
	for item in elite_arr:
		instance.elite_monster_ids.append(str(item))

	# Per-floor theming
	instance.floor_theme.clear()
	var floor_theme_val = data.get("floor_theme", [])
	var floor_theme_arr = floor_theme_val if floor_theme_val is Array else []
	for item in floor_theme_arr:
		instance.floor_theme.append(str(item))

	# Per-floor monster pools (nested arrays)
	instance.tier1_by_floor.clear()
	for row in _parse_nested_string_array(data.get("tier1_by_floor", [])):
		instance.tier1_by_floor.append(row)

	instance.tier2_by_floor.clear()
	for row in _parse_nested_string_array(data.get("tier2_by_floor", [])):
		instance.tier2_by_floor.append(row)

	instance.elite_by_floor.clear()
	for row in _parse_nested_string_array(data.get("elite_by_floor", [])):
		instance.elite_by_floor.append(row)

	# Room types per floor (nested array)
	instance.room_types_by_floor.clear()
	for row in _parse_nested_string_array(data.get("room_types_by_floor", [])):
		instance.room_types_by_floor.append(row)

	return instance


# Helper for nested array parsing
static func _parse_nested_string_array(val) -> Array:
	var result: Array = []
	if not val is Array:
		return result
	for outer_item in val:
		var inner: Array[String] = []
		if outer_item is Array:
			for inner_item in outer_item:
				inner.append(str(inner_item))
		result.append(inner)
	return result

# Validation helper
func is_valid() -> bool:
	return dungeon_id != "" and display_name != "" and region_id != ""

# Debug string
func _to_string() -> String:
	return "DungeonData(%s: %s [%d floors])" % [dungeon_id, display_name, floor_count]
