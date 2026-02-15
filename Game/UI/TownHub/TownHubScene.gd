extends Control

# ============================================================================
# TOWN HUB — CraftPix-themed shell with dynamic nav rail + town map grid
# ============================================================================

const TOWN_SCENE = preload("res://Game/UI/Town/TownScene.tscn")

const _SLOT_STYLE = preload("res://Themes/CraftPix/slot_inventory.tres")
const _HEADER_STYLE = preload("res://Themes/CraftPix/header_bar_teal_tinted.tres")

# Known town IDs (hardcoded — matches Data/Towns/*.json)
const KNOWN_TOWNS: Array[String] = ["town_greenroot", "town_timberfall"]

# Facility type → short nav label
const NAV_LABELS: Dictionary = {
	"dungeon": "Dungeon",
	"inn": "Inn",
	"shop": "Shop",
	"training_hall": "Training",
	"storage": "Storage",
}

# Facility type → building panel colour tint
const BUILDING_COLORS: Dictionary = {
	"dungeon": Color(0.6, 0.3, 0.3),
	"inn": Color(0.4, 0.55, 0.35),
	"shop": Color(0.55, 0.45, 0.3),
	"training_hall": Color(0.35, 0.4, 0.55),
	"storage": Color(0.45, 0.45, 0.45),
	"production": Color(0.5, 0.4, 0.3),
}
const BUILDING_COLOR_DEFAULT := Color(0.4, 0.4, 0.45)

@onready var _nav_vbox: VBoxContainer = %NavVBox
@onready var _nav_header_label: Label = %NavHeaderLabel
@onready var _content_header: PanelContainer = %ContentHeader
@onready var _content_vbox: VBoxContainer = %ContentVBox

var _town_scene_instance: Control = null
var _town_map_grid: GridContainer = null
var _nav_facility_buttons: Array[Button] = []
var _nav_travel_buttons: Array[Button] = []
var _icon_cache: Dictionary = {}  # icon_path → Texture2D


func _ready() -> void:
	print("[TownHub] Scene loaded — CraftPix shell active")
	_embed_town_scene()
	_build_nav_rail()
	_build_town_map()
	GameContext.location_changed.connect(_on_location_changed)


# ============================================================================
# EMBED TOWN SCENE
# ============================================================================

func _embed_town_scene() -> void:
	_content_header.visible = false

	_town_scene_instance = TOWN_SCENE.instantiate()
	_town_scene_instance.use_craftpix_skin = true
	_town_scene_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_town_scene_instance.size_flags_vertical = Control.SIZE_SHRINK_END
	_content_vbox.add_child(_town_scene_instance)

	# Create a container for the hero party bar at the bottom of the content area
	var party_bar_vbox = VBoxContainer.new()
	party_bar_vbox.name = "PartyBarVBox"
	party_bar_vbox.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(party_bar_vbox)
	_town_scene_instance.party_bar_target = party_bar_vbox

	print("[TownHub] Embedded TownScene into content area (CraftPix skin enabled)")


# ============================================================================
# NAV RAIL — Dynamic facility buttons + travel section
# ============================================================================

func _build_nav_rail() -> void:
	# Clear old dynamic buttons (keep NavHeader)
	for btn in _nav_facility_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_nav_facility_buttons.clear()
	for btn in _nav_travel_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_nav_travel_buttons.clear()

	# Remove old dynamic nodes (travel, dev) if present
	for old_name in ["TravelSeparator", "TravelLabel", "DevLabel", "DevResetSave", "DevAddGold"]:
		var old_node = _nav_vbox.get_node_or_null(old_name)
		if old_node:
			old_node.queue_free()

	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	_nav_header_label.text = town.display_name if town else town_id

	if town == null:
		return

	# Facility buttons
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		var label_text = _get_nav_label(facility_id, facility)
		var btn = Button.new()
		btn.text = label_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_facility_clicked.bind(facility_id))
		_nav_vbox.add_child(btn)
		_nav_facility_buttons.append(btn)

	# Spacer before travel
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.name = "TravelSeparator"
	_nav_vbox.add_child(spacer)

	# Travel label
	var travel_label = Label.new()
	travel_label.text = "— Travel —"
	travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_label.add_theme_font_size_override("font_size", 11)
	travel_label.modulate = Color(0.7, 0.7, 0.7)
	travel_label.name = "TravelLabel"
	_nav_vbox.add_child(travel_label)

	# Travel buttons
	for tid in KNOWN_TOWNS:
		var t = DataRegistry.get_town(tid) if DataRegistry.has_method("get_town") else null
		var t_name = t.display_name if t else tid
		var btn = Button.new()
		btn.text = t_name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tid == town_id:
			btn.disabled = true
		btn.pressed.connect(_on_travel_pressed.bind(tid))
		_nav_vbox.add_child(btn)
		_nav_travel_buttons.append(btn)

	# Dev buttons at bottom of nav
	var dev_label = Label.new()
	dev_label.text = "— Dev —"
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dev_label.add_theme_font_size_override("font_size", 11)
	dev_label.modulate = Color(0.5, 0.5, 0.5)
	dev_label.name = "DevLabel"
	_nav_vbox.add_child(dev_label)

	var btn_reset = Button.new()
	btn_reset.text = "Reset Save"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.modulate = Color(1, 0.6, 0.6)
	btn_reset.pressed.connect(_on_dev_reset_save)
	btn_reset.name = "DevResetSave"
	_nav_vbox.add_child(btn_reset)

	var btn_gold = Button.new()
	btn_gold.text = "+100 Gold"
	btn_gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_gold.modulate = Color(1, 0.9, 0.5)
	btn_gold.pressed.connect(_on_dev_add_gold)
	btn_gold.name = "DevAddGold"
	_nav_vbox.add_child(btn_gold)


func _get_nav_label(facility_id: String, facility) -> String:
	if facility == null:
		return facility_id
	if NAV_LABELS.has(facility.facility_type):
		return NAV_LABELS[facility.facility_type]
	return facility.display_name


# ============================================================================
# TOWN MAP GRID — Clickable building panels (center area)
# ============================================================================

func _build_town_map() -> void:
	# Remove old grid if rebuilding
	if _town_map_grid != null and is_instance_valid(_town_map_grid):
		_town_map_grid.queue_free()
		_town_map_grid = null

	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return

	# Town name header in content area
	var header_panel = _content_vbox.get_node_or_null("TownMapHeader")
	if header_panel == null:
		header_panel = PanelContainer.new()
		header_panel.name = "TownMapHeader"
		header_panel.add_theme_stylebox_override("panel", _HEADER_STYLE)
		header_panel.custom_minimum_size = Vector2(0, 32)
		var header_label = Label.new()
		header_label.name = "TownMapHeaderLabel"
		header_label.text = town.display_name
		header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header_label.add_theme_font_size_override("font_size", 15)
		header_panel.add_child(header_label)
		# Insert at top of content vbox (index 0 = ContentHeader which is hidden)
		_content_vbox.add_child(header_panel)
		_content_vbox.move_child(header_panel, 0)
	else:
		var lbl = header_panel.get_node_or_null("TownMapHeaderLabel")
		if lbl:
			lbl.text = town.display_name

	# Scroll container for grid
	var scroll = _content_vbox.get_node_or_null("TownMapScroll")
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "TownMapScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		# Insert after header
		_content_vbox.add_child(scroll)
		_content_vbox.move_child(scroll, 1)

	# Grid container
	_town_map_grid = GridContainer.new()
	_town_map_grid.name = "TownMapGrid"
	_town_map_grid.columns = 3
	_town_map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_town_map_grid.add_theme_constant_override("h_separation", 12)
	_town_map_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_town_map_grid)

	# Create building panels
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		var panel = _create_building_panel(facility_id, facility)
		_town_map_grid.add_child(panel)

	print("[TownHub] Town map built: %d buildings in grid" % town.facility_ids.size())


func _create_building_panel(facility_id: String, facility) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(140, 100)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _SLOT_STYLE)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_building_gui_input.bind(facility_id))

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Building icon — TextureRect if icon_path available, ColorRect fallback
	var icon_tex: Texture2D = null
	if facility != null and facility.icon_path != "":
		icon_tex = _load_icon(facility.icon_path)

	if icon_tex != null:
		var tex_rect = TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.custom_minimum_size = Vector2(64, 64)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)
	else:
		var sprite_placeholder = ColorRect.new()
		sprite_placeholder.custom_minimum_size = Vector2(64, 64)
		sprite_placeholder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tint = BUILDING_COLOR_DEFAULT
		if facility != null and BUILDING_COLORS.has(facility.facility_type):
			tint = BUILDING_COLORS[facility.facility_type]
		sprite_placeholder.color = tint
		sprite_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(sprite_placeholder)

	# Building name label
	var label = Label.new()
	label.text = facility.display_name if facility else facility_id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	return panel


func _on_building_gui_input(event: InputEvent, facility_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[TownHub] Building clicked: %s" % facility_id)
		_on_facility_clicked(facility_id)


# ============================================================================
# CALLBACKS
# ============================================================================

func _on_facility_clicked(facility_id: String) -> void:
	if _town_scene_instance and _town_scene_instance.has_method("show_facility_by_id"):
		_town_scene_instance.show_facility_by_id(facility_id)


func _on_travel_pressed(town_id: String) -> void:
	if _town_scene_instance and _town_scene_instance.has_method("switch_town"):
		_town_scene_instance.switch_town(town_id)


func _on_location_changed(_region_id: String, _town_id: String) -> void:
	print("[TownHub] Location changed — rebuilding nav rail + town map")
	_build_nav_rail()

	# Clear and rebuild town map
	var scroll = _content_vbox.get_node_or_null("TownMapScroll")
	if scroll:
		for child in scroll.get_children():
			child.queue_free()
		_town_map_grid = null

	# Defer rebuild so queue_free completes first
	call_deferred("_build_town_map")


func _on_dev_reset_save() -> void:
	print("[TownHub] DEV: Reset Save pressed")
	if GameContext.has_method("reset_save_game"):
		GameContext.reset_save_game()
	get_tree().call_deferred("change_scene_to_file", "res://Game/Boot/game_boot.tscn")


func _on_dev_add_gold() -> void:
	print("[TownHub] DEV: +100 Gold pressed")
	GameContext.add_run_gold(100)
	GameContext.save_game()
	print("[TownHub] Added 100 gold. New total: %d" % GameContext.get_run_gold())


# ============================================================================
# ICON LOADING
# ============================================================================

func _load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	if not ResourceLoader.exists(path):
		print("[TownHub] Icon not found: %s" % path)
		return null
	var tex = ResourceLoader.load(path) as Texture2D
	if tex != null:
		_icon_cache[path] = tex
	return tex
