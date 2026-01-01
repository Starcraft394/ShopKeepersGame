## ItemTemplate.gd
## Typed data container for item template definitions.
## Source: MVP_Scope.md, GDD Section 31, 34
# class_name ItemTemplate  # DISABLED - duplicate of Core/DataTypes/ItemTemplate.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var item_type: String = ""  # "weapon", "armor", "accessory", "consumable"
var slot: String = ""       # "weapon", "chest", "accessory", "consumable"
var tier: int = 1
var base_stats: Dictionary = {}
var base_value: int = 0

static func from_dict(data: Dictionary) -> ItemTemplate:
	var instance = ItemTemplate.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.item_type = data.get("item_type", "")
	instance.slot = data.get("slot", "")
	instance.tier = data.get("tier", 1)
	instance.base_stats = data.get("base_stats", {})
	instance.base_value = data.get("base_value", 0)
	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
