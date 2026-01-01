## MonsterData.gd
## Typed data container for monster definitions.
## Source: MVP_Scope.md, GDD Section 17
# class_name MonsterData  # DISABLED - duplicate of Core/DataTypes/MonsterData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var family: String = ""
var tier: int = 1
var base_stats: Dictionary = {}
var ability_ids: Array[String] = []
var gold_drop_min: int = 0
var gold_drop_max: int = 0

static func from_dict(data: Dictionary) -> MonsterData:
	var instance = MonsterData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.family = data.get("family", "")
	instance.tier = data.get("tier", 1)
	instance.base_stats = data.get("base_stats", {})
	instance.gold_drop_min = data.get("gold_drop_min", 0)
	instance.gold_drop_max = data.get("gold_drop_max", 0)

	var abilities = data.get("ability_ids", [])
	for a in abilities:
		instance.ability_ids.append(str(a))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
