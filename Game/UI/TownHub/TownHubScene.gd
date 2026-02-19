extends Control

# ============================================================================
# TOWN HUB — CraftPix-themed shell with dynamic nav rail + town map grid
# ============================================================================

const TOWN_SCENE = preload("res://Game/UI/Town/TownScene.tscn")

const _SLOT_STYLE = preload("res://Themes/CraftPix/slot_inventory.tres")
const _HEADER_STYLE = preload("res://Themes/CraftPix/header_bar_teal_tinted.tres")

# Town IDs loaded dynamically from region data
var _known_towns: Array[String] = []

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


func _get_known_towns() -> Array[String]:
	if _known_towns.is_empty():
		var region_id: String = GameContext.get_current_region_id() if GameContext.has_method("get_current_region_id") else "region_1"
		var region = DataRegistry.get_region(region_id) if DataRegistry.has_method("get_region") else null
		if region and not region.town_ids.is_empty():
			for tid in region.town_ids:
				_known_towns.append(tid)
		else:
			_known_towns = ["town_thornhaven"]
	return _known_towns


func _ready() -> void:
	print("[TownHub] Scene loaded — CraftPix shell active")

	# Apply town entry reset (heal survivors, remove dead heroes, refresh shops).
	# This MUST run before embedding TownScene because the boot router changes
	# the phase from TOWN to TOWN_HUB, which causes TownScene's own phase check
	# to skip the reset.  Covers the defeat→town path.
	GameContext.apply_town_entry_reset()

	_embed_town_scene()
	_build_nav_rail()
	_build_town_map()
	GameContext.location_changed.connect(_on_location_changed)
	_check_first_launch_guidance()
	_check_facilities_overview()
	_check_region_unlock_notification()


# ============================================================================
# EMBED TOWN SCENE
# ============================================================================

func _embed_town_scene() -> void:
	_content_header.visible = false

	_town_scene_instance = TOWN_SCENE.instantiate()
	_town_scene_instance.use_craftpix_skin = true
	_town_scene_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_town_scene_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Create party bar container and add it to the tree BEFORE TownScene,
	# so it's already in the scene tree when TownScene._ready() populates it.
	# (Adding children to an orphan container causes layout to not calculate.)
	var party_bar_vbox = VBoxContainer.new()
	party_bar_vbox.name = "PartyBarVBox"
	party_bar_vbox.add_theme_constant_override("separation", 6)
	party_bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_bar_vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	_town_scene_instance.party_bar_target = party_bar_vbox

	_content_vbox.add_child(party_bar_vbox)
	_content_vbox.add_child(_town_scene_instance)
	# Move party bar below TownScene so it renders at the bottom
	_content_vbox.move_child(party_bar_vbox, _content_vbox.get_child_count() - 1)

	print("[TownHub] Embedded TownScene into content area (CraftPix skin enabled)")


# ============================================================================
# NAV RAIL — Dynamic facility buttons + travel section
# ============================================================================

func _build_nav_rail() -> void:
	# Clear ALL dynamic children (keep NavHeader panel which contains NavHeaderLabel)
	_nav_facility_buttons.clear()
	_nav_travel_buttons.clear()
	var nav_header_panel = _nav_header_label.get_parent() if is_instance_valid(_nav_header_label) else null
	for child in _nav_vbox.get_children():
		if child == nav_header_panel:
			continue
		_nav_vbox.remove_child(child)
		child.queue_free()

	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	_nav_header_label.text = town.display_name if town else town_id

	if town == null:
		return

	# Facility buttons (tinted by region theme)
	var palette: Dictionary = RegionTheme.get_palette_for_current_region()
	var theme_col: Color = palette.get("theme", Color(0.4, 0.6, 0.5))
	var nav_tint: Color = Color(
		clampf(theme_col.r * 1.5 + 0.2, 0.0, 1.0),
		clampf(theme_col.g * 1.5 + 0.2, 0.0, 1.0),
		clampf(theme_col.b * 1.5 + 0.2, 0.0, 1.0)
	)
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		var label_text = _get_nav_label(facility_id, facility)
		var btn = Button.new()
		btn.text = label_text
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.modulate = nav_tint
		btn.pressed.connect(_on_facility_clicked.bind(facility_id))
		_nav_vbox.add_child(btn)
		_nav_facility_buttons.append(btn)

	# Region navigation section
	var all_regions: Array = DataRegistry.get_all_regions() if DataRegistry.has_method("get_all_regions") else []
	if all_regions.size() > 1:
		all_regions.sort_custom(func(a, b): return a.region_index < b.region_index)
		var region_label = Label.new()
		region_label.text = "— Regions —"
		region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		region_label.add_theme_font_size_override("font_size", 11)
		region_label.modulate = Color(0.7, 0.7, 0.7)
		region_label.name = "RegionLabel"
		_nav_vbox.add_child(region_label)

		var current_region_id: String = GameContext.get_current_region_id() if GameContext.has_method("get_current_region_id") else "region_1"
		for region in all_regions:
			var rbtn = Button.new()
			var region_color: Color = Color.from_string(region.theme_color, Color.WHITE)
			rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var is_unlocked: bool = GameContext.is_region_unlocked(region.region_id)
			if not is_unlocked:
				rbtn.text = region.display_name + " [Locked]"
				rbtn.disabled = true
				rbtn.modulate = Color(0.4, 0.4, 0.4)
			elif region.region_id == current_region_id:
				rbtn.text = region.display_name
				rbtn.disabled = true
				rbtn.modulate = Color(
					clampf(region_color.r * 1.5 + 0.2, 0.0, 1.0),
					clampf(region_color.g * 1.5 + 0.2, 0.0, 1.0),
					clampf(region_color.b * 1.5 + 0.2, 0.0, 1.0)
				)
			else:
				rbtn.text = region.display_name
				rbtn.modulate = Color(
					clampf(region_color.r * 1.5 + 0.2, 0.0, 1.0),
					clampf(region_color.g * 1.5 + 0.2, 0.0, 1.0),
					clampf(region_color.b * 1.5 + 0.2, 0.0, 1.0)
				)
			rbtn.pressed.connect(_on_region_pressed.bind(region.region_id))
			_nav_vbox.add_child(rbtn)

	# Spacer before travel
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.name = "TravelSeparator"
	_nav_vbox.add_child(spacer)

	# Travel section (hidden when only 1 town in region)
	var towns: Array[String] = _get_known_towns()
	if towns.size() > 1:
		var travel_label = Label.new()
		travel_label.text = "— Travel —"
		travel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		travel_label.add_theme_font_size_override("font_size", 11)
		travel_label.modulate = Color(0.7, 0.7, 0.7)
		travel_label.name = "TravelLabel"
		_nav_vbox.add_child(travel_label)

		for tid in towns:
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

	# Options button (opens pause/settings menu)
	var btn_options = Button.new()
	btn_options.text = "Options"
	btn_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_options.modulate = Color(0.8, 0.8, 1.0)
	btn_options.pressed.connect(_on_options_pressed)
	btn_options.name = "Options"
	_nav_vbox.add_child(btn_options)

	# Save & Exit button
	var btn_save_exit = Button.new()
	btn_save_exit.text = "Save & Exit"
	btn_save_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_exit.modulate = Color(0.6, 1.0, 0.6)
	btn_save_exit.pressed.connect(_on_save_and_exit)
	btn_save_exit.name = "SaveExit"
	_nav_vbox.add_child(btn_save_exit)

	# Dev buttons — only visible in editor / debug builds
	if OS.is_debug_build():
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


## Show a welcome banner and auto-open Inn when the player has no heroes.
func _check_first_launch_guidance() -> void:
	if GameContext.get_party_size() > 0:
		return
	# Show welcome tutorial before auto-navigating to Inn
	var overlay = TutorialOverlay.try_show(self, "tutorial_welcome")
	if overlay != null:
		await overlay.tutorial_finished
	# No heroes — nudge player to the Inn
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return
	var inn_id: String = ""
	for fac_id in town.facility_ids:
		var fac = DataRegistry.get_facility(fac_id)
		if fac != null and fac.facility_type == "inn":
			inn_id = fac_id
			break
	if inn_id != "":
		# Small delay so TownScene finishes initialization before we navigate
		call_deferred("_on_facility_clicked", inn_id)
		print("[TownHub] First launch — auto-opening Inn for hero recruitment")


## Show facilities overview tutorial after first dungeon extraction.
func _check_facilities_overview() -> void:
	if not GameContext.has_completed_tutorial("tutorial_first_extraction"):
		return
	var overlay = TutorialOverlay.try_show(self, "tutorial_facilities_overview")
	if overlay != null:
		await overlay.tutorial_finished


## Show a region-unlocked banner if a new region was just unlocked.
func _check_region_unlock_notification() -> void:
	if not GameContext.has_method("get_pending_region_unlock"):
		return
	var unlocked_id: String = GameContext.get_pending_region_unlock()
	if unlocked_id == "":
		return
	GameContext.clear_pending_region_unlock()
	var region = DataRegistry.get_region(unlocked_id) if DataRegistry.has_method("get_region") else null
	var region_name: String = region.display_name if region else unlocked_id
	# Build a CanvasLayer overlay notification
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var panel = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER_TOP
	panel.position = Vector2(0, 20)
	panel.size = Vector2(400, 60)
	panel.add_theme_stylebox_override("panel", _create_notification_style())
	canvas.add_child(panel)
	var label = Label.new()
	label.text = "New Region Unlocked: %s!" % region_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(1, 0.9, 0.4, 1)
	panel.add_child(label)
	# Auto-dismiss after 4 seconds
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func(): canvas.queue_free())
	print("[TownHub] Showing region unlock notification: %s" % region_name)


func _create_notification_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.25, 0.95)
	style.border_color = Color(1, 0.85, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


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
		# Region-tinted header (runtime StyleBoxFlat instead of static .tres)
		var palette: Dictionary = RegionTheme.get_palette_for_current_region()
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = palette.get("title_bar", Color(0.18, 0.22, 0.3, 0.9))
		header_style.content_margin_left = 8
		header_style.content_margin_top = 4
		header_style.content_margin_right = 8
		header_style.content_margin_bottom = 4
		header_style.set_corner_radius_all(4)
		header_panel.add_theme_stylebox_override("panel", header_style)
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
		scroll.size_flags_stretch_ratio = 3  # Take 75% of shared space with TownScene
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
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	label.text = _get_nav_label(facility_id, facility)
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


func _on_region_pressed(region_id: String) -> void:
	var region: RegionData = DataRegistry.get_region(region_id)
	if region == null or region.town_ids.is_empty():
		print("[TownHub] Cannot travel to region %s — no towns" % region_id)
		return
	var target_town: String = region.town_ids[0]
	print("[TownHub] Travelling to region %s → %s" % [region_id, target_town])
	_known_towns.clear()
	if _town_scene_instance and _town_scene_instance.has_method("switch_town"):
		_town_scene_instance.switch_town(target_town)


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


func _on_options_pressed() -> void:
	var ui_audio = get_node_or_null("/root/UIAudio")
	if ui_audio and ui_audio.has_method("show_options_menu"):
		ui_audio.show_options_menu()


func _on_save_and_exit() -> void:
	print("[TownHub] Save & Exit pressed")
	GameContext.save_game()
	get_tree().quit()


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
