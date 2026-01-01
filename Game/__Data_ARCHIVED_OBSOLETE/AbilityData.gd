## AbilityData.gd
## Typed data container for ability definitions.
## Source: MVP_Scope.md, GDD Section 23, 24
# class_name AbilityData  # DISABLED - duplicate of Core/DataTypes/AbilityData.gd
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var ability_type: String = ""   # "attack", "buff", "debuff", "heal"
var damage_type: String = ""    # "physical", "magical", "true"
var target_type: String = ""    # "single_enemy", "all_enemies", "self", "single_ally"
var base_damage: int = 0
var cooldown: int = 0
var status_effect_ids: Array[String] = []

static func from_dict(data: Dictionary) -> AbilityData:
	var instance = AbilityData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.ability_type = data.get("ability_type", "")
	instance.damage_type = data.get("damage_type", "")
	instance.target_type = data.get("target_type", "")
	instance.base_damage = data.get("base_damage", 0)
	instance.cooldown = data.get("cooldown", 0)

	var effects = data.get("status_effect_ids", [])
	for e in effects:
		instance.status_effect_ids.append(str(e))

	return instance

func is_valid() -> bool:
	return id != "" and display_name != ""
