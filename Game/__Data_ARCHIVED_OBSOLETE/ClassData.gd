## ClassData.gd
## Typed data container for hero class definitions.
## Source: MVP_Scope.md, GDD Section 22
# class_name ClassData  # DISABLED - duplicate of Core/DataTypes/ClassData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var base_stats: Dictionary = {}
var ability_ids: Array[String] = []
var passive_ids: Array[String] = []
var weapon_types: Array[String] = []

static func from_dict(data: Dictionary) -> ClassData:
	var instance = ClassData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.base_stats = data.get("base_stats", {})

	var abilities = data.get("ability_ids", [])
	for a in abilities:
		instance.ability_ids.append(str(a))

	var passives = data.get("passive_ids", [])
	for p in passives:
		instance.passive_ids.append(str(p))

	var weapons = data.get("weapon_types", [])
	for w in weapons:
		instance.weapon_types.append(str(w))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
