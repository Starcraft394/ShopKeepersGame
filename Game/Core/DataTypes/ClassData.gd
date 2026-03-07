## ClassData.gd
## Data container for class definitions.
## Source: GDD Sections 15, 22, 24, 33
class_name ClassData
extends RefCounted

# Core Identity
var class_id: String = ""
var display_name: String = ""
var description: String = ""
var archetype: String = ""  # vanguard, striker, warden, arcanist, etc.

# Unlock Requirements
var unlock_region: int = 1
var is_legacy: bool = false  # Legacy classes not in GDD, excluded from recruitment

# Base Stats (flat values per GDD 32.1.2)
var base_stats: Dictionary = {}

# Stat Growth Per Level (flat values per GDD 33.3)
var stat_growth: Dictionary = {}

# Ability References (IDs, not objects)
var ability_a_id: String = ""
var ability_b_id: String = ""
var passive_a_id: String = ""
var passive_b_id: String = ""

# Equipment Restrictions
var weapon_types: Array[String] = []

# Card Visuals (for combat tile backgrounds)
var card_prompt: String = ""
var card_palette: Dictionary = {}

# Sprite folders (class-based sprites, keyed by variant e.g. "default")
var sprites: Dictionary = {}

# Factory method to create from dictionary (JSON data)
static func from_dict(data: Dictionary) -> ClassData:
	var instance = ClassData.new()

	# Handle both "id" and "class_id" for flexibility
	instance.class_id = data.get("class_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.archetype = data.get("archetype", "")
	instance.unlock_region = data.get("unlock_region", 1)
	instance.is_legacy = data.get("is_legacy", false)
	var base_stats_val = data.get("base_stats", {})
	instance.base_stats = base_stats_val if base_stats_val is Dictionary else {}
	var stat_growth_val = data.get("stat_growth", {})
	instance.stat_growth = stat_growth_val if stat_growth_val is Dictionary else {}
	instance.ability_a_id = data.get("ability_a_id", "")
	instance.ability_b_id = data.get("ability_b_id", "")
	instance.passive_a_id = data.get("passive_a_id", "")
	instance.passive_b_id = data.get("passive_b_id", "")

	# Card visuals
	instance.card_prompt = data.get("card_prompt", "")
	var palette_val = data.get("card_palette", {})
	instance.card_palette = palette_val if palette_val is Dictionary else {}

	# Sprites
	var sprites_val = data.get("sprites", {})
	instance.sprites = sprites_val if sprites_val is Dictionary else {}

	# Convert typed arrays (clear + append pattern for safety)
	instance.weapon_types.clear()
	var weapons_val = data.get("weapon_types", [])
	var weapons = weapons_val if weapons_val is Array else []
	for w in weapons:
		instance.weapon_types.append(str(w))

	return instance

# Validation helper
func is_valid() -> bool:
	return class_id != "" and display_name != ""

# Calculate stats at a given level (base + growth * (level - 1))
func get_stats_at_level(level: int) -> Dictionary:
	var stats = base_stats.duplicate()
	if level > 1:
		for stat_key in stat_growth.keys():
			if stats.has(stat_key):
				stats[stat_key] = int(stats[stat_key]) + int(stat_growth[stat_key]) * (level - 1)
	return stats

# Get growth for a specific stat
func get_stat_growth(stat_key: String) -> int:
	return int(stat_growth.get(stat_key, 0))

# Debug string
func _to_string() -> String:
	return "ClassData(%s: %s [%s])" % [class_id, display_name, archetype]
