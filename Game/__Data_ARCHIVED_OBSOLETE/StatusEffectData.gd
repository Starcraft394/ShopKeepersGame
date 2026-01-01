## StatusEffectData.gd
## Typed data container for status effect definitions.
## Source: MVP_Scope.md, GDD Section 27, 39
# class_name StatusEffectData  # DISABLED - duplicate of Core/DataTypes/StatusEffectData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var category: String = ""       # "dot", "control", "buff", "debuff"
var max_stacks: int = 1
var duration: int = 1
var base_value: int = 0
var is_cleansable: bool = true

static func from_dict(data: Dictionary) -> StatusEffectData:
	var instance = StatusEffectData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.category = data.get("category", "")
	instance.max_stacks = data.get("max_stacks", 1)
	instance.duration = data.get("duration", 1)
	instance.base_value = data.get("base_value", 0)
	instance.is_cleansable = data.get("is_cleansable", true)
	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
