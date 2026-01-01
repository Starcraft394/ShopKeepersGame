## ItemTemplate.gd
## Data container for item template definitions.
## Source: GDD Sections 7, 31, 34
class_name ItemTemplate
extends RefCounted

# Core Identity
var template_id: String = ""
var display_name: String = ""
var description: String = ""

# Item Classification
var item_type: String = ""  # "weapon", "armor", "accessory", "consumable", "tool", "backpack"
var item_subtype: String = ""  # "sword", "dagger", "staff", etc.
var slot: String = ""  # "weapon_main", "weapon_offhand", "head", "chest", "legs", "accessory_1", "accessory_2", "backpack"

# Tier & Quality
var tier: int = 1
var min_quality: int = 1
var max_quality: int = 5

# Base Stats (flat values)
var base_stats: Dictionary = {}

# Affix Configuration
var allowed_affixes: Array[String] = []
var min_affixes: int = 0
var max_affixes: int = 2

# Socket Configuration
var max_sockets: int = 0
var allowed_socket_types: Array[String] = []

# Refinement
var can_refine: bool = true
var max_refinement: int = 10

# Economy
var base_value: int = 100

# Visual
var icon_path: String = ""

# Factory method
static func from_dict(data: Dictionary) -> ItemTemplate:
	var instance = ItemTemplate.new()

	# Handle both "id" and "template_id" for flexibility
	instance.template_id = data.get("template_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.item_type = data.get("item_type", "")
	instance.item_subtype = data.get("item_subtype", "")
	instance.slot = data.get("slot", "")
	instance.tier = data.get("tier", 1)
	instance.min_quality = data.get("min_quality", 1)
	instance.max_quality = data.get("max_quality", 5)
	var base_stats_val = data.get("base_stats", {})
	instance.base_stats = base_stats_val if base_stats_val is Dictionary else {}
	instance.min_affixes = data.get("min_affixes", 0)
	instance.max_affixes = data.get("max_affixes", 2)
	instance.max_sockets = data.get("max_sockets", 0)
	instance.can_refine = data.get("can_refine", true)
	instance.max_refinement = data.get("max_refinement", 10)
	instance.base_value = data.get("base_value", 100)
	instance.icon_path = data.get("icon_path", "")

	# Convert typed arrays (clear + append pattern for safety)
	instance.allowed_affixes.clear()
	var affixes_val = data.get("allowed_affixes", [])
	var affixes = affixes_val if affixes_val is Array else []
	for a in affixes:
		instance.allowed_affixes.append(str(a))

	instance.allowed_socket_types.clear()
	var socket_types_val = data.get("allowed_socket_types", [])
	var socket_types = socket_types_val if socket_types_val is Array else []
	for s in socket_types:
		instance.allowed_socket_types.append(str(s))

	return instance

# Validation helper
func is_valid() -> bool:
	return template_id != "" and display_name != "" and item_type != ""

# Debug string
func _to_string() -> String:
	return "ItemTemplate(%s: %s [%s])" % [template_id, display_name, item_type]
