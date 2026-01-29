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

# Quality tier weights for deterministic rolling
const QUALITY_WEIGHTS := [
	{ "value": 0, "weight": 70.0 },  # common
	{ "value": 1, "weight": 22.0 },  # uncommon
	{ "value": 2, "weight": 7.0 },   # rare
	{ "value": 3, "weight": 1.0 }    # epic
]

# Quality tier name prefixes
const QUALITY_PREFIXES := ["", "Fine ", "Rare ", "Epic "]

# Factory method: create instance from template with deterministic RNG
static func from_template(template: ItemTemplate, qty: int, rng: RandomNumberGenerator) -> ItemInstance:
	var instance = ItemInstance.new()
	instance.template_id = template.template_id
	instance.quantity = qty

	# Roll quality tier deterministically
	instance.quality_tier = SeededRNG.choose_weighted(QUALITY_WEIGHTS, rng)

	# Build display name with quality prefix
	var prefix = QUALITY_PREFIXES[instance.quality_tier]
	instance.display_name = prefix + template.display_name

	return instance

# Debug string
func _to_string() -> String:
	return "ItemInstance(%s x%d [Q%d])" % [display_name, quantity, quality_tier]
