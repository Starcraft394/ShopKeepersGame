extends Control

const SLOT_STYLE = preload("res://Themes/CraftPix/slot_inventory.tres")
const GRID_CAPACITY := 24

# ============================================================================
# STORAGE (Phase 4 — player_items wiring + sell junk MVP)
# ============================================================================

@onready var _grid: GridContainer = %Grid
@onready var _count_label: Label = %CountLabel
@onready var _header_label: Label = %HeaderLabel
@onready var _btn_sort: Button = %BtnSort
@onready var _btn_filter: Button = %BtnFilter
@onready var _btn_sell_junk: Button = %BtnSellJunk


func _ready() -> void:
	print("[StorageScene] Loaded")
	# Hide unimplemented Sort/Filter buttons for playtest
	_btn_sort.visible = false
	_btn_filter.visible = false
	_btn_sell_junk.pressed.connect(_on_sell_junk_pressed)
	_refresh()


func _refresh() -> void:
	_populate_grid()
	_update_header()


func _populate_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	var items := GameContext.get_player_items()
	var slot_count := 0

	for item_id in items:
		var qty: int = items[item_id]
		if qty <= 0:
			continue
		var template: ItemTemplate = DataRegistry.get_item_template(item_id)
		var dname: String = template.display_name if template else item_id
		_grid.add_child(_create_slot(item_id, dname, qty))
		slot_count += qty

	# Fill remaining capacity with empty slots
	var filled := _grid.get_child_count()
	for i in range(filled, GRID_CAPACITY):
		_grid.add_child(_create_empty_slot())

	_count_label.text = "%d / %d slots" % [slot_count, GRID_CAPACITY]


func _create_slot(item_id: String, display_name: String, qty: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 40)
	panel.add_theme_stylebox_override("panel", SLOT_STYLE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "%s x%d" % [display_name, qty]

	var label := Label.new()
	label.text = "%s\nx%d" % [display_name.left(3), qty] if qty > 1 else display_name.left(4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", GameContext.fs(10))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


func _create_empty_slot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(40, 40)
	panel.add_theme_stylebox_override("panel", SLOT_STYLE)
	panel.modulate = Color(1, 1, 1, 0.4)
	return panel


func _update_header() -> void:
	_header_label.text = "Storage — %d gold" % GameContext.get_player_gold()


func _on_sort_pressed() -> void:
	print("[StorageScene] Sort pressed (TODO: implement sort modes)")
	_refresh()


func _on_filter_pressed() -> void:
	print("[StorageScene] Filter pressed (TODO: implement filter categories)")


func _on_sell_junk_pressed() -> void:
	var items := GameContext.get_player_items()
	var sold_count := 0
	var gold_earned := 0

	# Sell tier-1 materials at base_value
	var to_sell: Array[Dictionary] = []
	for item_id in items:
		var template: ItemTemplate = DataRegistry.get_item_template(item_id)
		if template == null:
			continue
		if template.item_type == "material" and template.tier <= 1:
			to_sell.append({"id": item_id, "qty": items[item_id], "value": template.base_value})

	for entry in to_sell:
		var total_value: int = entry["value"] * entry["qty"]
		GameContext.remove_player_item(entry["id"], entry["qty"])
		GameContext.add_player_gold(total_value)
		gold_earned += total_value
		sold_count += entry["qty"]
		print("[StorageScene] Sold %dx %s for %d gold" % [entry["qty"], entry["id"], total_value])

	if sold_count > 0:
		print("[StorageScene] Sell Junk complete: %d items for %d gold" % [sold_count, gold_earned])
	else:
		print("[StorageScene] Sell Junk: no junk materials found")

	_refresh()
