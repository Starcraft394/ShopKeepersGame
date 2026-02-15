## ItemTemplate.gd
## Data container for item template definitions.
## Source: GDD Sections 7, 31, 34
class_name ItemTemplate
extends RefCounted

# Core Identity
var template_id: String = ""
var display_name: String = ""
var description: String = ""

# Item Classification
var item_type: String = ""  # "weapon", "armor", "accessory", "consumable", "material", "tool", "backpack"
var item_subtype: String = ""  # "sword", "dagger", "staff", etc.
var slot: String = ""  # Legacy detailed slot: "weapon_main", "head", "chest", "legs", etc.
var equip_slot: String = ""  # Equipment slot: "weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet", "bag", or "" (not equippable)
var category: String = ""  # "material", "consumable", "equipment", "book" - for filtering

# Tier & Quality
var tier: int = 1
var min_quality: int = 1
var max_quality: int = 5

# Base Stats (flat values)
var base_stats: Dictionary = {}

# Affix Configuration
var allowed_affixes: Array[String] = []
var min_affixes: int = 0
var max_affixes: int = 2

# Socket Configuration
var max_sockets: int = 0
var allowed_socket_types: Array[String] = []

# Refinement
var can_refine: bool = true
var max_refinement: int = 10

# Economy
var base_value: int = 100  # Sell value (player sells to shop)
var buy_value: int = 0  # Buy value (shop sells to player); 0 = use base_value * 2
var stack_max: int = 999  # Max stack size (consumables/materials)

# Visual
var icon_path: String = ""

# Tags for filtering/theming
var tags: Array[String] = []

# Consumable-specific (for camp/combat use)
var use_effect: String = ""  # "heal", "cure_poison", "cure_bleeding", etc.
var use_value: int = 0  # Effect magnitude (heal amount, etc.)

# Equipment stat bonuses (v2: explicit stat grants for weapons/offhands)
# Falls back to base_stats for backwards compatibility
var stat_bonuses: Dictionary = {}  # { "attack": int, "defense": int, "speed": int, "health": int }

# Backpack-specific: bonus bag capacity when equipped (NOT scaled by quality)
var bag_capacity_bonus: int = 0

# Quality tier multipliers: Q0=1.0, Q1=1.1, Q2=1.2, Q3=1.35
const QUALITY_MULTIPLIERS := [1.0, 1.1, 1.2, 1.35]

# Icon texture cache (shared across all ItemTemplate instances)
static var _icon_cache: Dictionary = {}  # icon_path -> Texture2D|null


## Load and cache the icon texture for this item. Returns null if no icon.
func get_icon_texture() -> Texture2D:
	if icon_path == "":
		return null
	if _icon_cache.has(icon_path):
		return _icon_cache[icon_path]
	var texture: Texture2D = null
	if ResourceLoader.exists(icon_path):
		var loaded = ResourceLoader.load(icon_path)
		if loaded is Texture2D:
			texture = loaded
	_icon_cache[icon_path] = texture
	return texture


## Create a TextureRect sized for inline icon display (16x16 default).
## Returns null if no icon available.
func create_icon_rect(icon_size: int = 16) -> TextureRect:
	var tex = get_icon_texture()
	if tex == null:
		return null
	var rect = TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect

## Create an icon display with quality-tier colored border for equipment.
## Returns a plain TextureRect for common (Q0) or non-equipment items.
## Returns a PanelContainer wrapping the icon for Q1+ equipment.
## Returns null if no icon available.
func create_bordered_icon(icon_size: int = 16, quality_tier: int = 0) -> Control:
	var tex = get_icon_texture()
	if tex == null:
		return null

	var rect = TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# No border for common items or non-equipment
	if quality_tier <= 0:
		return rect
	var is_equipment: bool = category == "equipment" or item_type in ["weapon", "armor", "accessory", "tool", "backpack"]
	if not is_equipment:
		return rect

	# Wrap in PanelContainer with colored border
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ItemInstance.QUALITY_COLORS[clampi(quality_tier, 0, 3)]
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 1.0
	style.content_margin_top = 1.0
	style.content_margin_right = 1.0
	style.content_margin_bottom = 1.0

	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(icon_size + 6, icon_size + 6)
	panel.add_child(rect)
	return panel


## Get stat bonuses for this equipment with quality multiplier applied.
## Returns empty dict for non-equipment items.
## quality_tier: 0=common, 1=uncommon, 2=rare, 3=epic
func get_stat_bonuses_with_quality(quality_tier: int = 0) -> Dictionary:
	# Use stat_bonuses if set, otherwise fall back to base_stats
	var bonuses = stat_bonuses if not stat_bonuses.is_empty() else base_stats
	if bonuses.is_empty():
		return {}

	# Clamp quality tier to valid range
	var q = clampi(quality_tier, 0, QUALITY_MULTIPLIERS.size() - 1)
	var multiplier = QUALITY_MULTIPLIERS[q]

	var result: Dictionary = {}
	for stat_key in bonuses:
		var base_val = int(bonuses[stat_key])
		result[stat_key] = int(base_val * multiplier)
	return result

## Get effective buy value (for shop purchases).
## Returns buy_value if set, otherwise base_value * 2.
func get_buy_value() -> int:
	if buy_value > 0:
		return buy_value
	return base_value * 2

## Get effective sell value (for selling to shop).
## Returns base_value (or half for balance - using full value for now).
func get_sell_value() -> int:
	return base_value

# Factory method
static func from_dict(data: Dictionary) -> ItemTemplate:
	var instance = ItemTemplate.new()

	# Handle both "id" and "template_id" for flexibility
	instance.template_id = data.get("template_id", data.get("id", ""))
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.item_type = data.get("item_type", "")
	instance.item_subtype = data.get("item_subtype", "")
	instance.slot = data.get("slot", "")
	instance.equip_slot = data.get("equip_slot", "")
	instance.category = data.get("category", "")  # v1: category for filtering
	instance.tier = data.get("tier", 1)
	instance.min_quality = data.get("min_quality", 1)
	instance.max_quality = data.get("max_quality", 5)
	var base_stats_val = data.get("base_stats", {})
	instance.base_stats = base_stats_val if base_stats_val is Dictionary else {}
	instance.min_affixes = data.get("min_affixes", 0)
	instance.max_affixes = data.get("max_affixes", 2)
	instance.max_sockets = data.get("max_sockets", 0)
	instance.can_refine = data.get("can_refine", true)
	instance.max_refinement = data.get("max_refinement", 10)
	# v1: Economy fields with gold_value fallback for legacy templates
	instance.base_value = data.get("base_value", data.get("gold_value", 100))
	instance.buy_value = data.get("buy_value", 0)  # 0 = use base_value * 2
	instance.stack_max = data.get("stack_max", 999)
	instance.icon_path = data.get("icon_path", "")
	# v1: Consumable use effect fields
	instance.use_effect = data.get("use_effect", "")
	instance.use_value = data.get("use_value", 0)

	# v2: Equipment stat bonuses (separate from base_stats for clarity)
	var stat_bonuses_val = data.get("stat_bonuses", {})
	instance.stat_bonuses = stat_bonuses_val if stat_bonuses_val is Dictionary else {}

	# v5: Backpack bag capacity bonus (not quality-scaled)
	instance.bag_capacity_bonus = int(data.get("bag_capacity_bonus", 0))

	# Convert typed arrays (clear + append pattern for safety)
	instance.allowed_affixes.clear()
	var affixes_val = data.get("allowed_affixes", [])
	var affixes = affixes_val if affixes_val is Array else []
	for a in affixes:
		instance.allowed_affixes.append(str(a))

	instance.allowed_socket_types.clear()
	var socket_types_val = data.get("allowed_socket_types", [])
	var socket_types = socket_types_val if socket_types_val is Array else []
	for s in socket_types:
		instance.allowed_socket_types.append(str(s))

	instance.tags.clear()
	var tags_val = data.get("tags", [])
	var tags_arr = tags_val if tags_val is Array else []
	for t in tags_arr:
		instance.tags.append(str(t))

	return instance

# Validation helper
func is_valid() -> bool:
	return template_id != "" and display_name != "" and item_type != ""

# Debug string
func _to_string() -> String:
	return "ItemTemplate(%s: %s [%s])" % [template_id, display_name, item_type]
