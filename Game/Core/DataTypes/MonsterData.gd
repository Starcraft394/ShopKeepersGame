## MonsterData.gd
## Data container for monster template definitions.
## Source: GDD Sections 9, 17, 25, 38
class_name MonsterData
extends RefCounted

# Core Identity
var monster_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification
var family: String = ""  # "beast", "fungi", "aquatic", "draconic", "crystal", "undead", "void"
var region_id: String = ""
var tier: int = 1

# Base Stats (flat values)
var base_stats: Dictionary = {}

# AI Configuration (per GDD Section 38.2)
var ai_tier: int = 0  # 0=Feral, 1=Basic, 2=Tactical, 3=Strategic
var attack_type: String = "melee"  # "melee" or "ranged" — affects targeting row priority

# Abilities (IDs)
var ability_ids: Array[String] = []

# Passives (IDs)
var passive_ids: Array[String] = []

# Loot Configuration
var loot_table_id: String = ""
var gold_drop_min: int = 0
var gold_drop_max: int = 0

# Visual
var sprite_path: String = ""
var portrait_path: String = ""

# Special Flags
var is_elite: bool = false
var is_boss: bool = false

# Factory method
static func from_dict(data: Dictionary) -> MonsterData:
	var instance = MonsterData.new()

	# Handle both "id" and "monster_id" for flexibility
	instance.monster_id = data.get("monster_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.family = data.get("family", "")
	instance.region_id = data.get("region_id", "")
	instance.tier = data.get("tier", 1)
	var base_stats_val = data.get("base_stats", {})
	instance.base_stats = base_stats_val if base_stats_val is Dictionary else {}
	instance.ai_tier = data.get("ai_tier", 0)
	instance.attack_type = data.get("attack_type", "melee")
	instance.loot_table_id = data.get("loot_table_id", "")
	instance.gold_drop_min = data.get("gold_drop_min", 0)
	instance.gold_drop_max = data.get("gold_drop_max", 0)
	instance.sprite_path = data.get("sprite_path", "")
	instance.portrait_path = data.get("portrait_path", "")
	instance.is_elite = data.get("is_elite", false)
	instance.is_boss = data.get("is_boss", false)

	# Convert typed arrays (clear + append pattern for safety)
	instance.ability_ids.clear()
	var abilities_val = data.get("ability_ids", [])
	var abilities = abilities_val if abilities_val is Array else []
	for a in abilities:
		instance.ability_ids.append(str(a))

	instance.passive_ids.clear()
	var passives_val = data.get("passive_ids", [])
	var passives = passives_val if passives_val is Array else []
	for p in passives:
		instance.passive_ids.append(str(p))

	return instance

# Validation helper
func is_valid() -> bool:
	return monster_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "MonsterData(%s: %s [AI:%d])" % [monster_id, display_name, ai_tier]
