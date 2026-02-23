extends Control

const SLOT_STYLE = preload("res://Themes/CraftPix/slot_inventory.tres")

# ============================================================================
# SHOP INVENTORY (Phase 3 — GameContext transaction wiring)
# ============================================================================

var _shop_items: Array = []  # Array[ItemTemplate]
var _selected_template: ItemTemplate = null

@onready var _grid: GridContainer = %Grid
@onready var _item_label: Label = %ItemLabel
@onready var _buy_button: Button = %BuyButton
@onready var _det_header_label: Label = %DetHeaderLabel
@onready var _inv_header_label: Label = %InvHeaderLabel


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	_buy_button.disabled = true
	_load_shop_items()
	_populate_grid()
	_update_gold_display()


func _load_shop_items() -> void:
	var all_items: Array = DataRegistry.get_all_item_templates()
	# Filter to buyable items: consumables, equipment, materials (skip books for now)
	for item in all_items:
		if item is ItemTemplate and item.category != "book":
			_shop_items.append(item)
	# Sort by type then name for consistent display
	_shop_items.sort_custom(func(a: ItemTemplate, b: ItemTemplate) -> bool:
		if a.item_type != b.item_type:
			return a.item_type < b.item_type
		return a.display_name < b.display_name
	)
	print("[ShopScene] Loaded %d items from DataRegistry (filtered from %d)" % [
		_shop_items.size(), all_items.size()
	])


func _populate_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	for template in _shop_items:
		_grid.add_child(_create_slot(template))


func _create_slot(template: ItemTemplate) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 40)
	panel.add_theme_stylebox_override("panel", SLOT_STYLE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = template.display_name
	panel.gui_input.connect(_on_slot_input.bind(template))

	var label := Label.new()
	label.text = template.display_name.left(4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", GameContext.fs(11))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


func _on_slot_input(event: InputEvent, template: ItemTemplate) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_item(template)


func _select_item(template: ItemTemplate) -> void:
	_selected_template = template
	var buy_price := _get_buy_price(template)
	_det_header_label.text = template.display_name

	var details := "%s\n" % template.display_name
	details += "Type: %s" % template.item_type.capitalize()
	if template.item_subtype != "":
		details += " (%s)" % template.item_subtype
	details += "\nTier: %d\n" % template.tier
	details += "Buy: %d gold  |  Sell: %d gold\n" % [buy_price, template.base_value]
	if template.description != "":
		details += "\n%s\n" % template.description
	var effect_label: String = template.get_effect_label()
	if effect_label != "":
		details += "\n%s\n" % effect_label
	if not template.base_stats.is_empty():
		details += "\nStats:"
		for stat_name in template.base_stats:
			details += "\n  %s: +%s" % [stat_name.capitalize(), str(template.base_stats[stat_name])]

	_item_label.text = details
	_buy_button.disabled = false
	_buy_button.text = "Buy (%d gold)" % buy_price
	print("[ShopScene] Selected: %s (buy=%d)" % [template.template_id, buy_price])


func _on_buy_pressed() -> void:
	if _selected_template == null:
		return
	var buy_price := _get_buy_price(_selected_template)
	if not GameContext.spend_player_gold(buy_price):
		_item_label.text = "Not enough gold!\nNeed %d, have %d." % [
			buy_price, GameContext.get_player_gold()
		]
		UIAudio.play_sfx("error_insufficient")
		print("[ShopScene] BUY FAILED: %s — insufficient gold (%d/%d)" % [
			_selected_template.template_id, GameContext.get_player_gold(), buy_price
		])
		return
	GameContext.add_player_item(_selected_template.template_id, 1)
	UIAudio.play_sfx("item_buy")
	_item_label.text = "Purchased %s!\n\nGold remaining: %d" % [
		_selected_template.display_name, GameContext.get_player_gold()
	]
	_update_gold_display()
	print("[ShopScene] BUY OK: %s for %d gold (remaining: %d)" % [
		_selected_template.template_id, buy_price, GameContext.get_player_gold()
	])


func _update_gold_display() -> void:
	_inv_header_label.text = "Shop — %d gold" % GameContext.get_player_gold()


func _get_buy_price(template: ItemTemplate) -> int:
	if template.buy_value > 0:
		return template.buy_value
	return template.base_value * 2
