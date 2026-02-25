## ItemInstance.gd
## Runtime container for an instantiated item with rolled quality.
## Source: GDD Sections 7, 31
class_name ItemInstance
extends RefCounted

# Reference to source template
var template_id: String = ""

# Stack quantity
var quantity: int = 1

# Rolled quality tier: 0=common, 1=uncommon, 2=rare, 3=epic
var quality_tier: int = 0

# Generated display name with quality prefix
var display_name: String = ""

# Regional affix data (applied to gear drops)
var source_region: String = ""    # Region where this item was obtained
var affix_id: String = ""         # Regional affix key (e.g., "region_1")
var affix_stats: Dictionary = {}  # Bonus stats from affix (e.g., { "health": 2 })
var affix_prefix: String = ""     # Display prefix (e.g., "Verdant")

# NG+ bonus stat lines (generated at drop time based on region completions + cycle)
var bonus_stat_lines: Array = []  # [{"stat": "speed", "value": 1}, ...]

# Quality tier weights for deterministic rolling
const QUALITY_WEIGHTS := [
	{ "value": 0, "weight": 70.0 },  # common
	{ "value": 1, "weight": 22.0 },  # uncommon
	{ "value": 2, "weight": 7.0 },   # rare
	{ "value": 3, "weight": 1.0 }    # epic
]

# Quality tier name prefixes
const QUALITY_PREFIXES := ["", "Fine ", "Rare ", "Epic "]

# Quality tier display names
const QUALITY_NAMES := ["Common", "Uncommon", "Rare", "Epic"]

# Quality tier colors for borders and text
const QUALITY_COLORS: Array[Color] = [
	Color(0.6, 0.6, 0.6, 1.0),   # Common: gray (text only, no border)
	Color(0.3, 0.8, 0.3, 1.0),   # Uncommon: green
	Color(0.3, 0.5, 1.0, 1.0),   # Rare: blue
	Color(0.7, 0.3, 0.9, 1.0),   # Epic: purple
]

## Check whether a template should roll quality (equipment/tools only)
static func should_roll_quality(template: ItemTemplate) -> bool:
	if template.category == "equipment":
		return true
	if template.item_type in ["weapon", "armor", "accessory", "tool", "backpack"]:
		return true
	return false

# Factory method: create instance from template with deterministic RNG
static func from_template(template: ItemTemplate, qty: int, rng: RandomNumberGenerator) -> ItemInstance:
	var instance = ItemInstance.new()
	instance.template_id = template.template_id
	instance.quantity = qty

	# Only roll quality for equipment/tools; materials, consumables, books stay Q0
	if should_roll_quality(template):
		instance.quality_tier = SeededRNG.choose_weighted(QUALITY_WEIGHTS, rng)
	else:
		instance.quality_tier = 0

	# Build display name with quality prefix
	var prefix = QUALITY_PREFIXES[instance.quality_tier]
	instance.display_name = prefix + template.display_name

	return instance

## Apply quality-tier colored border to a Button node.
## Does nothing for quality_tier 0 (common).
static func apply_quality_border_to_button(btn: Button, quality_tier: int) -> void:
	if quality_tier <= 0:
		return
	var color: Color = QUALITY_COLORS[clampi(quality_tier, 0, 3)]
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	btn.add_theme_stylebox_override("normal", style)
	# Hover: slightly brighter
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	btn.add_theme_stylebox_override("hover", hover_style)
	# Pressed: slightly darker
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	btn.add_theme_stylebox_override("pressed", pressed_style)

# Debug string
func _to_string() -> String:
	return "ItemInstance(%s x%d [Q%d])" % [display_name, quantity, quality_tier]
