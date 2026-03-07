## AbilityData.gd
## Data container for ability definitions.
## Source: GDD Sections 23, 24
class_name AbilityData
extends RefCounted

# Core Identity
var ability_id: String = ""
var display_name: String = ""
var description: String = ""

# Classification
var ability_type: String = ""  # "basic_attack", "class_a", "class_b", "weapon", "item"
var source_class_id: String = ""  # If class-specific

# Targeting (per GDD 38.3)
var target_type: String = "single_enemy"  # "single_enemy", "single_ally", "self", "all_enemies", "all_allies", "aoe_tile"
var range_min: int = 1
var range_max: int = 1
var requires_los: bool = true

# Ability Targeting v1 - Data-driven targeting rules
var target_team: String = "enemy"  # "enemy", "ally", "self"
var target_rule: String = "any"  # "any", "lowest_hp_pct", "highest_atk", "lowest_hp_abs", "unbuffed"
var requires_target_alive: bool = true
var can_overheal: bool = false
var allow_self_target: bool = false

# Cost
var cooldown: int = 0  # Turns before reuse
var resource_cost: Dictionary = {}  # e.g., {"mana": 10}

# Effect
var effect_type: String = "damage"  # "damage", "heal", "buff", "debuff", "status", "summon", "move"
var base_damage: int = 0
var damage_type: String = "physical"  # "physical", "magical", "true"
var base_heal: int = 0

# Status Application
var applies_status_id: String = ""
var status_stacks: int = 1
var status_chance: float = 1.0
var applies_status_duration: int = 0  # Duration in rounds for Status Hooks v1 (0 = use stacks for legacy)

# Scaling (flat values, not percentages)
var attack_scaling: float = 1.0  # Multiplier applied to attack stat

# Multi-hit abilities (e.g., twin_strike)
var hit_count: int = 1  # Number of hits per use

# Buff abilities (e.g., shadowstep, barkskin_blessing)
var buff_stats: Dictionary = {}  # e.g., {"attack": 4, "speed": 3}
var buff_duration: int = 0  # Turns the buff lasts (0 = permanent for combat)

# Self-buff/debuff on ability use (e.g., fungal_frenzy, smoke_dash)
var self_buff: Dictionary = {}  # e.g., {"stat": "attack", "value": 4, "duration": 2}
var self_debuff: Dictionary = {}  # e.g., {"stat": "defense", "value": -2, "duration": 2}
var self_damage: int = 0  # HP cost to cast (e.g., shadow_mend)

# Enemy debuff on hit (e.g., void_anchor, entropy_blast)
var enemy_debuff: Dictionary = {}  # e.g., {"stat": "speed", "value": -3, "duration": 2}

# Ally buff for multi-target buffs (e.g., raise_dead)
var ally_buff: Dictionary = {}  # e.g., {"stats": ["attack", "speed"], "value": 3, "duration": 3}

# Special mechanics
var armor_piercing: bool = false  # Ignore defense (e.g., light_lance, phase_strike)
var cleanses_debuffs: int = 0  # Number of debuffs to remove (e.g., cleansing_wave)
var shield_value: int = 0  # Temporary HP shield (e.g., prism_barrier)
var shield_duration: int = 0  # Shield duration in rounds
var reflect_percent: int = 0  # Damage reflection (e.g., light_refraction)

# Dual effect (damage + heal, e.g., life_drain)
var heal_target_rule: String = ""  # Target rule for heal portion of damage_and_heal

# AoE (Grid Combat v1)
var aoe_shape: String = "none"  # "none", "square"
var aoe_size: int = 0           # 0=single tile (1x1), 1=3x3, 2=5x5

# Visual
var icon_path: String = ""
var animation_id: String = ""

# Status UI v1.7 - Buff badge display metadata (optional, safe defaults)
var ui_name: String = ""   # Display name for buff tooltips (fallback to display_name)
var ui_short: String = ""  # Short label e.g. "ATK+", "DEF+", "BUFF"
var ui_icon: String = ""   # Optional icon resource path for buff badge

# Status UI v1.7.1 - Tag-driven sorting metadata (optional, safe defaults)
var buff_tags: Array = []  # Tags for sort priority: "defense", "offense", "utility"
var ui_category: String = ""  # Category hint: "buff", "debuff", "damage", etc.

# Factory method
static func from_dict(data: Dictionary) -> AbilityData:
	var instance = AbilityData.new()

	# Handle both "id" and "ability_id" for flexibility
	instance.ability_id = data.get("ability_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.ability_type = data.get("ability_type", "")
	instance.source_class_id = data.get("source_class_id", "")
	instance.target_type = data.get("target_type", "single_enemy")
	instance.range_min = data.get("range_min", 1)
	instance.range_max = data.get("range_max", 1)
	instance.requires_los = data.get("requires_los", true)

	# Ability Targeting v1 - Data-driven targeting rules (safe defaults)
	instance.target_team = data.get("target_team", "enemy")
	instance.target_rule = data.get("target_rule", "any")
	instance.requires_target_alive = data.get("requires_target_alive", true)
	instance.can_overheal = data.get("can_overheal", false)
	instance.allow_self_target = data.get("allow_self_target", false)
	instance.cooldown = data.get("cooldown", 0)
	var resource_cost_val = data.get("resource_cost", {})
	instance.resource_cost = resource_cost_val if resource_cost_val is Dictionary else {}
	instance.effect_type = data.get("effect_type", "damage")
	instance.base_damage = data.get("base_damage", 0)
	instance.damage_type = data.get("damage_type", "physical")
	instance.base_heal = data.get("base_heal", 0)
	instance.applies_status_id = data.get("applies_status_id", "")
	instance.status_stacks = data.get("status_stacks", 1)
	instance.status_chance = data.get("status_chance", 1.0)
	instance.applies_status_duration = data.get("applies_status_duration", 0)
	instance.attack_scaling = data.get("attack_scaling", 1.0)
	instance.hit_count = data.get("hit_count", 1)
	var buff_stats_val = data.get("buff_stats", {})
	instance.buff_stats = buff_stats_val if buff_stats_val is Dictionary else {}
	instance.buff_duration = data.get("buff_duration", 0)

	# Self-buff/debuff on ability use
	var self_buff_val = data.get("self_buff", {})
	instance.self_buff = self_buff_val if self_buff_val is Dictionary else {}
	var self_debuff_val = data.get("self_debuff", {})
	instance.self_debuff = self_debuff_val if self_debuff_val is Dictionary else {}
	instance.self_damage = int(data.get("self_damage", 0))

	# Enemy debuff on hit
	var enemy_debuff_val = data.get("enemy_debuff", {})
	instance.enemy_debuff = enemy_debuff_val if enemy_debuff_val is Dictionary else {}

	# Ally buff for multi-target
	var ally_buff_val = data.get("ally_buff", {})
	instance.ally_buff = ally_buff_val if ally_buff_val is Dictionary else {}

	# Special mechanics
	instance.armor_piercing = data.get("armor_piercing", false)
	instance.cleanses_debuffs = int(data.get("cleanses_debuffs", 0))
	instance.shield_value = int(data.get("shield_value", 0))
	instance.shield_duration = int(data.get("shield_duration", 0))
	instance.reflect_percent = int(data.get("reflect_percent", 0))
	instance.heal_target_rule = data.get("heal_target_rule", "")

	# AoE (Grid Combat v1)
	instance.aoe_shape = data.get("aoe_shape", "none")
	instance.aoe_size = int(data.get("aoe_size", 0))

	instance.icon_path = data.get("icon_path", "")
	instance.animation_id = data.get("animation_id", "")

	# Status UI v1.7 - Buff badge display metadata (safe defaults)
	instance.ui_name = data.get("ui_name", "")
	instance.ui_short = data.get("ui_short", "")
	instance.ui_icon = data.get("ui_icon", "")

	# Status UI v1.7.1 - Tag-driven sorting metadata (safe defaults)
	var buff_tags_val = data.get("buff_tags", [])
	instance.buff_tags = buff_tags_val if buff_tags_val is Array else []
	instance.ui_category = data.get("ui_category", "")

	return instance

# Validation helper
func is_valid() -> bool:
	return ability_id != "" and display_name != ""

# Debug string
func _to_string() -> String:
	return "AbilityData(%s: %s [%s])" % [ability_id, display_name, ability_type]
