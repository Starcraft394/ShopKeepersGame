## RaceData.gd
## Typed data container for hero race definitions.
## Source: MVP_Scope.md, GDD Section 15
# class_name RaceData  # DISABLED - duplicate of Core/DataTypes/RaceData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var stat_modifiers: Dictionary = {}
var passive_id: String = ""
var trait_tags: Array[String] = []

static func from_dict(data: Dictionary) -> RaceData:
	var instance = RaceData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.stat_modifiers = data.get("stat_modifiers", {})
	instance.passive_id = data.get("passive_id", "")

	var tags = data.get("trait_tags", [])
	for t in tags:
		instance.trait_tags.append(str(t))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
