## FacilityData.gd
## Data container for facility definitions.
## Source: GDD Sections 5, 18
class_name FacilityData
extends RefCounted

# Core Identity
var facility_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification
var facility_type: String = ""  # "production", "service", "defense", "special"

# Tier Configuration
var max_tier: int = 4
var unlock_region: int = 1

# Production (for production-type facilities)
var produces_item_types: Array[String] = []
var input_resource_types: Array[String] = []

# Slots per Tier (per GDD 5.2)
var slots_per_tier: Dictionary = {}  # { "1": 2, "2": 3, "3": 4, "4": 5 }

# Upgrade Costs per Tier
var upgrade_costs: Dictionary = {}  # { "2": { "gold": 500, "wood": 10 }, ... }

# Services Unlocked per Tier
var services_per_tier: Dictionary = {}  # { "3": ["refinement"], "4": ["legendary_craft"] }

# Hero Assignment
var allows_hero_assignment: bool = true
var max_assigned_heroes: int = 1

# Visual
var icon_path: String = ""
var building_scene_path: String = ""

# Factory method
static func from_dict(data: Dictionary) -> FacilityData:
	var instance = FacilityData.new()

	# Handle both "id" and "facility_id" for flexibility
	instance.facility_id = data.get("facility_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.facility_type = data.get("facility_type", "production")
	instance.max_tier = data.get("max_tier", 4)
	instance.unlock_region = data.get("unlock_region", 1)
	var slots_val = data.get("slots_per_tier", {})
	instance.slots_per_tier = slots_val if slots_val is Dictionary else {}
	var costs_val = data.get("upgrade_costs", {})
	instance.upgrade_costs = costs_val if costs_val is Dictionary else {}
	var services_val = data.get("services_per_tier", {})
	instance.services_per_tier = services_val if services_val is Dictionary else {}
	instance.allows_hero_assignment = data.get("allows_hero_assignment", true)
	instance.max_assigned_heroes = data.get("max_assigned_heroes", 1)
	instance.icon_path = data.get("icon_path", "")
	instance.building_scene_path = data.get("building_scene_path", "")

	# Convert typed arrays (clear + append pattern for safety)
	instance.produces_item_types.clear()
	var item_types_val = data.get("produces_item_types", [])
	var item_types = item_types_val if item_types_val is Array else []
	for t in item_types:
		instance.produces_item_types.append(str(t))

	instance.input_resource_types.clear()
	var resource_types_val = data.get("input_resource_types", [])
	var resource_types = resource_types_val if resource_types_val is Array else []
	for r in resource_types:
		instance.input_resource_types.append(str(r))

	return instance

# Validation helper
func is_valid() -> bool:
	return facility_id != "" and display_name != ""

# Get slots for a specific tier
func get_slots_for_tier(tier: int) -> int:
	var tier_str = str(tier)
	if slots_per_tier.has(tier_str):
		return int(slots_per_tier[tier_str])
	return 0

# Debug string
func _to_string() -> String:
	return "FacilityData(%s: %s [%s])" % [facility_id, display_name, facility_type]
