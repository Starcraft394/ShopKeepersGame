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

# Unlocks & Shop (for craft/shop facilities)
var unlocks: Array = []  # Array of unlock Dictionaries { id, unlock_group, label, required_tier, costs }
var recipes: Array = []  # DEPRECATED: Use unlocks instead
var shop_items: Array = []  # Array of shop item Dictionaries { item_id, price_gold, requires_unlock_group }
var crafting_recipes: Array = []  # Array of { output_id, output_qty, inputs: [{ item_id, qty }] }

# Pool-driven shop system
var shop_pool_id: String = ""  # ID of shop pool JSON (e.g., "pool_region1_general")
var shop_rolls: Dictionary = {}  # Category roll counts { "consumables": 2, "weapons": 2 }
var shop_items_legacy: Array = []  # Legacy fallback items if no pool configured
var stash_upgrades: Array = []  # Stash capacity upgrades available at this shop
var shop_profile: Dictionary = {}  # Town-unique shop profile { profile_id, category_weight_mult, rolls_override }

# Inn-specific: recruit level by tier
var recruit_level_by_tier: Dictionary = {}  # { "1": 1, "2": 2 } - hero level when recruiting at this tier
var recruit_candidates: Array = []  # Array of { class_id, cost_gold } for Inn recruitment
var max_party_size: int = 2  # Max party size for this inn

# Keeper NPC (for dialogue-driven facility UI)
var keeper_name: String = ""
var keeper_portrait: String = ""
var keeper_greetings: Array[String] = []

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

	# Keeper NPC fields
	instance.keeper_name = data.get("keeper_name", "")
	instance.keeper_portrait = data.get("keeper_portrait", "")
	instance.keeper_greetings.clear()
	var greetings_val = data.get("keeper_greetings", [])
	var greetings = greetings_val if greetings_val is Array else []
	for g in greetings:
		instance.keeper_greetings.append(str(g))

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

	# Parse unlocks, recipes (deprecated), and shop_items for craft/shop facilities
	var unlocks_val = data.get("unlocks", [])
	instance.unlocks = unlocks_val if unlocks_val is Array else []
	var recipes_val = data.get("recipes", [])
	instance.recipes = recipes_val if recipes_val is Array else []
	var shop_items_val = data.get("shop_items", [])
	instance.shop_items = shop_items_val if shop_items_val is Array else []
	var crafting_recipes_val = data.get("crafting_recipes", [])
	instance.crafting_recipes = crafting_recipes_val if crafting_recipes_val is Array else []

	# Pool-driven shop system fields
	instance.shop_pool_id = data.get("shop_pool_id", "")
	var shop_rolls_val = data.get("shop_rolls", {})
	instance.shop_rolls = shop_rolls_val if shop_rolls_val is Dictionary else {}
	var shop_items_legacy_val = data.get("shop_items_legacy", [])
	instance.shop_items_legacy = shop_items_legacy_val if shop_items_legacy_val is Array else []
	var stash_upgrades_val = data.get("stash_upgrades", [])
	instance.stash_upgrades = stash_upgrades_val if stash_upgrades_val is Array else []
	var shop_profile_val = data.get("shop_profile", {})
	instance.shop_profile = shop_profile_val if shop_profile_val is Dictionary else {}

	# Inn-specific fields
	var recruit_level_val = data.get("recruit_level_by_tier", {})
	instance.recruit_level_by_tier = recruit_level_val if recruit_level_val is Dictionary else {}
	var recruit_candidates_val = data.get("recruit_candidates", [])
	instance.recruit_candidates = recruit_candidates_val if recruit_candidates_val is Array else []
	instance.max_party_size = data.get("max_party_size", 2)

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
