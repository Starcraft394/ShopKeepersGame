## TownScene.gd
## Town hub UI with location display, stash viewer, facilities, and dungeon actions.
## Routes through game_boot for phase-based scene transitions.
extends Control

const BOOT_SCENE_PATH = "res://Game/Boot/game_boot.tscn"

# ============================================================================
# NODE REFERENCES
# ============================================================================

# Location section
@onready var location_label: Label = %LocationLabel
@onready var town_name_label: Label = %TownNameLabel
@onready var progress_label: Label = %ProgressLabel

# Stash section (dual stash display)
@onready var banked_stash_label: Label = %BankedStashLabel
@onready var unbanked_stash_label: Label = %UnbankedStashLabel
@onready var stash_list_vbox: VBoxContainer = %StashListVBox

# Facilities section
@onready var facilities_vbox: VBoxContainer = %FacilitiesVBox

# Action buttons
@onready var enter_dungeon_button: Button = %EnterDungeonButton
@onready var continue_run_button: Button = %ContinueRunButton
@onready var exit_dungeon_button: Button = %ExitDungeonButton

# Town switch buttons (removed — single town per region for now)

# Heroes section
@onready var heroes_vbox: VBoxContainer = %HeroesVBox

# Debug section
@onready var clear_stash_button: Button = %ClearStashButton
@onready var reset_save_button: Button = %ResetSaveButton
@onready var add_gold_button: Button = %AddGoldButton

# Facility overlay (CanvasLayer with draggable floating panels)
var _facility_overlay: CanvasLayer = null
var _open_panels: Dictionary = {}  # facility_id -> { "panel", "content_vbox", "actions_container" }
var _dragging_panel: PanelContainer = null
var _drag_offset: Vector2 = Vector2.ZERO
var _resizing_panel: PanelContainer = null
var _resize_edge: int = 0      # bitmask: 1=left, 2=right, 4=top, 8=bottom
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _resize_start_panel_pos: Vector2 = Vector2.ZERO
const RESIZE_MARGIN := 8
const PANEL_MIN_SIZE := Vector2(360, 300)
const PANEL_MAX_SIZE := Vector2(1200, 900)
# Regional Inn recruit base cost (index 0 unused, 1-7 for regions)
const RECRUIT_BASE_COST_BY_REGION: Array = [0, 50, 65, 85, 110, 145, 185, 235]

# ============================================================================
# CRAFTPIX SKIN (optional visual override — default false)
# ============================================================================
@export var use_craftpix_skin: bool = false

# Dynamic facility action container (created at runtime)
var _facility_actions_container: VBoxContainer = null

# Region color palette (populated in _apply_craftpix_skin)
var _region_palette: Dictionary = {}
var _current_facility_type: String = ""
var _current_facility = null  # Current facility data (for recipes/shop)
var _current_facility_id: String = ""  # Facility ID for seeding/logging

# Storage filter state
var _storage_filter: String = "all"  # "all", "materials", "consumables", "equipment", "books"
var _storage_view: String = "stash"  # "stash", "equipment"
var _storage_selected_hero_id: String = ""
var _storage_hero_filter: String = "party"  # "party" or town_id like "town_thornhaven"

# Manage Gear overlay (used from Inn roster)
var _manage_gear_overlay: CanvasLayer = null
var _manage_gear_hero_id: String = ""
var _manage_gear_filter: String = "party"  # "party" or town_id like "town_thornhaven"
var _manage_gear_content: VBoxContainer = null

# Dismiss warning overlay
var _dismiss_warning_overlay: CanvasLayer = null

# Sell overlay (replaces broken Window popup)
var _sell_overlay: CanvasLayer = null

# Bench hero picker overlay (opened from empty party bar slots)
var _bench_picker_overlay: CanvasLayer = null
var _sell_gold_label: Label = null
var _sell_items_container: VBoxContainer = null

# Bag select overlay (party bar quick-bag button)
var _bag_select_overlay: CanvasLayer = null
var _bag_select_hero_id: String = ""
var _bag_select_content: VBoxContainer = null

# Training Hall: selected hero for class assignment
var _training_selected_hero_id: String = ""

# Equipment Facility: filter and tab state
var _equipment_tab: String = "all"  # "all", "locked", "unlocked"
var _equipment_type_filter: String = "all"  # "all", "1h_weapon", "2h_weapon", "helmet", "armor", "legs", "offhand", "accessory", "backpack"
var _equipment_view: String = "recipes"  # "recipes", "upgrade", "repair"
var _upgrade_tier_tab: int = 0  # 0 = auto-select next available

# Inn view state
var _inn_view: String = "recruit"  # "recruit", "roster", "upgrade"
var _highlight_roster_tab: bool = false  # Pulse roster tab after first hire

# Shop view state
var _shop_view: String = "buy"  # "buy", "upgrade"
var _temp_shop_allocations: Dictionary = {}  # facility_id -> slot count (unstocked state only)

# Training Hall view state
var _training_view: String = "books"  # "books", "assign", "upgrade"

# Production (Chef/Alchemist) view state — per-facility to avoid cross-panel bleed
var _production_views: Dictionary = {}  # facility_id -> view string (default "mix")
var _mix_slots: Dictionary = {}  # facility_id -> { "a": "", "b": "", "c": "", "picking": "", "result": "" }

# Dungeon view state
var _dungeon_view: String = "enter"  # "enter" (only view for now)

# NPC greeting persistence (reset on panel open, persists across view switches)
var _facility_greeting: String = ""

# Remembered panel sizes (persists across open/close within session)
var _panel_sizes: Dictionary = {}  # facility_id -> Vector2

# Hero party card expand state (persists across refreshes)

# External container for hero party bar (set by TownHubScene)
var party_bar_target: Control = null

# Storage equip flow state
var _equip_pending_item_id: String = ""
var _equip_pending_slot: String = ""
var _equip_pending_quality: int = 0
var _equip_pending_affix_data: Dictionary = {}
var _equip_selected_hero_id: String = ""

# Storage bag-transfer flow state
var _bag_transfer_pending_item_id: String = ""

# ============================================================================
# HELPERS
# ============================================================================

## Immediately remove all children from a container so they vanish from the tree
## in the current frame.  queue_free() alone defers removal to end-of-frame,
## which lets ghost nodes stay visible when the container is repopulated in the
## same frame (e.g. _refresh_facility_panel → _build_inn_ui).
func _clear_children_immediate(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## Apply gold-bordered "selected" style to a button (replaces disabled+green pattern)
static func _apply_selected_button_style(btn: Button) -> void:
	var sel = StyleBoxFlat.new()
	sel.bg_color = Color(0.18, 0.22, 0.15, 0.9)
	sel.set_border_width_all(2)
	sel.border_color = Color(0.6, 0.5, 0.3, 0.8)
	sel.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sel)
	btn.add_theme_stylebox_override("hover", sel)
	btn.add_theme_stylebox_override("pressed", sel)
	btn.add_theme_stylebox_override("focus", sel)


# ============================================================================
# FACILITY OVERLAY — CanvasLayer-based modal (replaces Window node)
# ============================================================================
# Godot 4 Window nodes break when the scene is embedded inside another scene
# (popup_centered() silently fails). This overlay renders on a high CanvasLayer
# so it always appears on top, regardless of scene nesting depth.

func _build_facility_overlay() -> void:
	# CanvasLayer — renders above everything else (panels added directly)
	_facility_overlay = CanvasLayer.new()
	_facility_overlay.layer = 10
	_facility_overlay.name = "FacilityOverlay"
	add_child(_facility_overlay)
	print("[TownScene] Facility overlay built (CanvasLayer layer=10, multi-panel)")


## Create a new draggable facility panel and return its info dict.
func _create_facility_panel(facility_id: String) -> Dictionary:
	var panel = PanelContainer.new()
	panel.name = "FacilityPanel_%s" % facility_id
	# Restore remembered size or use default (larger default to reduce scrolling)
	var remembered_size = _panel_sizes.get(facility_id, Vector2(560, 600))
	# Clamp to 85% of viewport so panels never extend off-screen
	var vp_size = get_viewport().get_visible_rect().size
	remembered_size.x = mini(int(remembered_size.x), int(vp_size.x * 0.85))
	remembered_size.y = mini(int(remembered_size.y), int(vp_size.y * 0.85))
	panel.custom_minimum_size = remembered_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# CanvasLayer breaks theme propagation — apply theme explicitly
	if use_craftpix_skin:
		panel.theme = _CRAFTPIX_THEME
	else:
		panel.theme = preload("res://Themes/game_theme.tres")

	# Region-tinted panel background for text readability
	var panel_body_style = StyleBoxFlat.new()
	panel_body_style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	panel_body_style.border_color = _region_palette.get("border", Color(0.35, 0.30, 0.22, 0.8))
	panel_body_style.set_border_width_all(1)
	panel_body_style.set_corner_radius_all(4)
	panel_body_style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", panel_body_style)

	# Stagger position so panels don't stack exactly
	var offset_idx = _open_panels.size()
	panel.position = Vector2(80 + offset_idx * 30, 40 + offset_idx * 30)

	# Interior background image (if available for this facility type)
	var facility_for_bg = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
	var bg_type: String = facility_for_bg.facility_type if facility_for_bg != null else ""
	var bg_path: String = "res://Assets/Backgrounds/%s_interior.png" % bg_type
	if bg_type != "" and ResourceLoader.exists(bg_path):
		var bg_tex: Texture2D = ResourceLoader.load(bg_path)
		if bg_tex != null:
			var bg_rect = TextureRect.new()
			bg_rect.name = "PanelBackground"
			bg_rect.texture = bg_tex
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_rect.modulate = Color(1, 1, 1, 0.3)
			bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(bg_rect)

	# Main content VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(main_vbox)

	# --- Title bar (drag handle) ---
	var title_bar = HBoxContainer.new()
	title_bar.name = "TitleBar"
	title_bar.add_theme_constant_override("separation", 4)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP

	# Title bar background for visibility (region-tinted)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = _region_palette.get("title_bar", Color(0.18, 0.22, 0.3, 0.9))
	title_style.content_margin_left = 8
	title_style.content_margin_top = 4
	title_style.content_margin_right = 4
	title_style.content_margin_bottom = 4
	title_style.set_corner_radius_all(2)

	var title_panel = PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", title_style)
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(title_panel)

	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 4)
	title_panel.add_child(title_hbox)

	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = facility_id.capitalize()
	title_label.add_theme_font_size_override("font_size", GameContext.fs(16))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(title_label)

	if OS.is_debug_build() or GameContext.tester_mode:
		var dev_gold_btn = Button.new()
		dev_gold_btn.text = "+100g"
		dev_gold_btn.custom_minimum_size = Vector2(52, 24)
		dev_gold_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		dev_gold_btn.modulate = Color(1, 0.9, 0.5, 0.7)
		dev_gold_btn.pressed.connect(_on_add_gold_pressed)
		title_hbox.add_child(dev_gold_btn)

	var gold_label = Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: %d" % GameContext.get_run_gold()
	gold_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(gold_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close_facility_panel.bind(facility_id))
	title_hbox.add_child(close_btn)

	# Unified panel input handles both drag (title bar) and resize (edges)
	panel.gui_input.connect(_on_panel_gui_input.bind(panel, facility_id))

	# Margin wrapper for scroll content
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(margin)

	# ScrollContainer for actions content
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	# Actions container (facility-specific UI goes here)
	var actions_container = VBoxContainer.new()
	actions_container.name = "ActionsContainer"
	actions_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_container.add_theme_constant_override("separation", 6)
	scroll.add_child(actions_container)

	# Add panel to overlay
	_facility_overlay.add_child(panel)

	# Corner accent overlay (sibling in CanvasLayer, not a PanelContainer child)
	var accent_overlay = _create_accent_overlay(panel, facility_id)

	var info = {
		"panel": panel,
		"title_label": title_label,
		"gold_label": gold_label,
		"actions_container": actions_container,
		"accent_overlay": accent_overlay,
	}
	return info


func _has_open_panels() -> bool:
	return _open_panels.size() > 0


func _close_all_panels() -> void:
	for fid in _open_panels.keys():
		_on_close_facility_panel(fid)
	print("[FacilityOverlay] Closed all panels")


func _on_close_facility_panel(facility_id: String) -> void:
	if not _open_panels.has(facility_id):
		return
	# Block Inn close during first launch until player has at least 1 party member
	if facility_id == "inn" and not GameContext.has_completed_tutorial("tutorial_party_bar"):
		if GameContext.selected_party.size() == 0:
			_show_inn_recruit_reminder()
			return
	var was_inn: bool = (facility_id == "inn")
	var info = _open_panels[facility_id]
	var panel = info.get("panel")
	# Unregister from ESC-close stack
	if panel != null and is_instance_valid(panel):
		UIAudio.unregister_closeable(panel)
	# Remember panel size for next open
	if panel != null and is_instance_valid(panel):
		_panel_sizes[facility_id] = panel.size
	var accent = info.get("accent_overlay")
	if accent != null and is_instance_valid(accent):
		accent.queue_free()
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	_open_panels.erase(facility_id)
	# Clear equip flow state when closing storage panel
	_equip_pending_item_id = ""
	_equip_pending_slot = ""
	_equip_pending_quality = 0
	_equip_pending_affix_data = {}
	_equip_selected_hero_id = ""
	print("[FacilityOverlay] Closed panel: %s" % facility_id)
	# After Inn close: show Mira's party bar / gear / formation tutorial (once)
	if was_inn and not GameContext.has_completed_tutorial("tutorial_party_bar"):
		TutorialOverlay.try_show(self, "tutorial_party_bar")


## Show a timed warning when the player tries to close the Inn without a party member.
func _show_inn_recruit_reminder() -> void:
	if _facility_actions_container == null:
		return
	var existing = _facility_actions_container.get_node_or_null("RecruitReminder")
	if existing != null:
		return
	var reminder = Label.new()
	reminder.name = "RecruitReminder"
	reminder.text = "You need at least one hero in your party before leaving the Inn!"
	reminder.add_theme_font_size_override("font_size", GameContext.fs(15))
	reminder.modulate = Color(1.0, 0.7, 0.3, 1)
	reminder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reminder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facility_actions_container.add_child(reminder)
	_facility_actions_container.move_child(reminder, 0)
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(reminder, "modulate:a", 0.0, 0.5)
	tween.tween_callback(reminder.queue_free)


## Detect which edge(s) the mouse is near. Returns bitmask: 1=left, 2=right, 4=top, 8=bottom.
func _detect_resize_edge(local_pos: Vector2, panel_size: Vector2) -> int:
	var edge: int = 0
	if local_pos.x < RESIZE_MARGIN:
		edge |= 1  # left
	elif local_pos.x > panel_size.x - RESIZE_MARGIN:
		edge |= 2  # right
	if local_pos.y < RESIZE_MARGIN:
		edge |= 4  # top
	elif local_pos.y > panel_size.y - RESIZE_MARGIN:
		edge |= 8  # bottom
	return edge


## Map edge bitmask to cursor shape.
func _cursor_for_edge(edge: int) -> Control.CursorShape:
	match edge:
		5:  # top+left
			return Control.CURSOR_FDIAGSIZE
		10: # bottom+right
			return Control.CURSOR_FDIAGSIZE
		6:  # top+right
			return Control.CURSOR_BDIAGSIZE
		9:  # bottom+left
			return Control.CURSOR_BDIAGSIZE
		1, 2: # left or right
			return Control.CURSOR_HSIZE
		4, 8: # top or bottom
			return Control.CURSOR_VSIZE
		_:
			return Control.CURSOR_ARROW


## Unified panel input handler — drag (title bar) + resize (edges/corners).
func _on_panel_gui_input(event: InputEvent, panel: PanelContainer, facility_id: String) -> void:
	var local_pos: Vector2 = panel.get_local_mouse_position()
	var edge = _detect_resize_edge(local_pos, panel.size)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Bring panel (and its accent overlay) to front
			if panel.get_parent() != null:
				panel.get_parent().move_child(panel, -1)
			_bring_accent_to_front(facility_id)

			if edge != 0:
				# Start resize
				_resizing_panel = panel
				_resize_edge = edge
				_resize_start_pos = event.global_position
				_resize_start_size = panel.size
				_resize_start_panel_pos = panel.position
				_dragging_panel = null
			else:
				# Click anywhere — start drag
				_dragging_panel = panel
				_drag_offset = panel.position - event.global_position
				_resizing_panel = null
		else:
			# Mouse released
			if _resizing_panel == panel:
				_resizing_panel = null
				_resize_edge = 0
			if _dragging_panel == panel:
				_dragging_panel = null
			panel.mouse_default_cursor_shape = Control.CURSOR_ARROW

	elif event is InputEventMouseMotion:
		if _resizing_panel == panel:
			_handle_resize_motion(panel, event.global_position, facility_id)
		elif _dragging_panel == panel:
			panel.position = event.global_position + _drag_offset
			_sync_accent_overlay(panel, facility_id)
		else:
			# Hover — update cursor (resize arrows on edges, move elsewhere)
			if edge != 0:
				panel.mouse_default_cursor_shape = _cursor_for_edge(edge)
			else:
				panel.mouse_default_cursor_shape = Control.CURSOR_MOVE


## Apply resize delta based on edge bitmask.
func _handle_resize_motion(panel: PanelContainer, global_pos: Vector2, facility_id: String) -> void:
	var delta: Vector2 = global_pos - _resize_start_pos
	var new_size: Vector2 = _resize_start_size
	var new_pos: Vector2 = _resize_start_panel_pos

	# Right edge: increase width
	if _resize_edge & 2:
		new_size.x = _resize_start_size.x + delta.x
	# Left edge: decrease width + shift right
	if _resize_edge & 1:
		new_size.x = _resize_start_size.x - delta.x
		new_pos.x = _resize_start_panel_pos.x + delta.x
	# Bottom edge: increase height
	if _resize_edge & 8:
		new_size.y = _resize_start_size.y + delta.y
	# Top edge: decrease height + shift down
	if _resize_edge & 4:
		new_size.y = _resize_start_size.y - delta.y
		new_pos.y = _resize_start_panel_pos.y + delta.y

	# Clamp size
	new_size.x = clampf(new_size.x, PANEL_MIN_SIZE.x, PANEL_MAX_SIZE.x)
	new_size.y = clampf(new_size.y, PANEL_MIN_SIZE.y, PANEL_MAX_SIZE.y)

	# If left/top edge, adjust position to keep opposite edge fixed
	if _resize_edge & 1:
		new_pos.x = _resize_start_panel_pos.x + (_resize_start_size.x - new_size.x)
	if _resize_edge & 4:
		new_pos.y = _resize_start_panel_pos.y + (_resize_start_size.y - new_size.y)

	panel.custom_minimum_size = new_size
	panel.size = new_size
	panel.position = new_pos
	_sync_accent_overlay(panel, facility_id)


# ============================================================================
# CORNER ACCENT OVERLAYS — siblings in CanvasLayer (not PanelContainer children)
# ============================================================================

## Create a transparent overlay Control that draws L-shaped corner accents.
## Added as a sibling in _facility_overlay so PanelContainer layout can't interfere.
func _create_accent_overlay(panel: PanelContainer, facility_id: String) -> Control:
	var overlay = Control.new()
	overlay.name = "Accents_%s" % facility_id
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.position = panel.position
	overlay.size = panel.size
	_facility_overlay.add_child(overlay)
	overlay.draw.connect(_draw_corner_accents.bind(overlay))
	overlay.queue_redraw()
	return overlay


## Draw L-shaped corner accents using draw_rect (no child nodes needed).
func _draw_corner_accents(overlay: Control) -> void:
	var s: Vector2 = overlay.size
	var accent_color: Color = _region_palette.get("accent", Color(0.4, 0.65, 0.6, 0.5))
	var arm: float = 18.0
	var thick: float = 3.0
	var m: float = 1.0

	# Top-left L
	overlay.draw_rect(Rect2(m, m, arm, thick), accent_color)
	overlay.draw_rect(Rect2(m, m, thick, arm), accent_color)
	# Top-right L
	overlay.draw_rect(Rect2(s.x - m - arm, m, arm, thick), accent_color)
	overlay.draw_rect(Rect2(s.x - m - thick, m, thick, arm), accent_color)
	# Bottom-left L
	overlay.draw_rect(Rect2(m, s.y - m - thick, arm, thick), accent_color)
	overlay.draw_rect(Rect2(m, s.y - m - arm, thick, arm), accent_color)
	# Bottom-right L
	overlay.draw_rect(Rect2(s.x - m - arm, s.y - m - thick, arm, thick), accent_color)
	overlay.draw_rect(Rect2(s.x - m - thick, s.y - m - arm, thick, arm), accent_color)


## Keep accent overlay in sync with its panel's position and size.
func _sync_accent_overlay(panel: PanelContainer, facility_id: String) -> void:
	if not _open_panels.has(facility_id):
		return
	var accent = _open_panels[facility_id].get("accent_overlay")
	if accent == null or not is_instance_valid(accent):
		return
	accent.position = panel.position
	accent.size = panel.size
	accent.queue_redraw()


## Auto-fit panel height to content, clamped to viewport limits.
func _auto_fit_panel_height(facility_id: String) -> void:
	if not _open_panels.has(facility_id):
		return
	var info = _open_panels[facility_id]
	var panel = info.get("panel") as PanelContainer
	var actions = info.get("actions_container") as VBoxContainer
	if panel == null or actions == null:
		return

	# Wait one frame for layout to propagate minimum sizes
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return

	# Calculate ideal height: title bar + margins + content
	var content_min_h: float = actions.get_combined_minimum_size().y
	var overhead: float = 80.0  # title bar (~40) + margins (8+4+8) + separators + padding
	var ideal_h: float = content_min_h + overhead

	# Clamp to panel limits and 85% viewport
	var vp_h: float = get_viewport().get_visible_rect().size.y
	var max_h: float = minf(vp_h * 0.85, PANEL_MAX_SIZE.y)
	ideal_h = clampf(ideal_h, PANEL_MIN_SIZE.y, max_h)

	var new_size = Vector2(panel.size.x, ideal_h)
	panel.custom_minimum_size = new_size
	panel.size = new_size
	_panel_sizes[facility_id] = new_size
	_sync_accent_overlay(panel, facility_id)


## Bring accent overlay to front (above its panel).
func _bring_accent_to_front(facility_id: String) -> void:
	if not _open_panels.has(facility_id):
		return
	var accent = _open_panels[facility_id].get("accent_overlay")
	if accent != null and is_instance_valid(accent) and accent.get_parent() != null:
		accent.get_parent().move_child(accent, -1)


# ============================================================================
# CRAFTPIX SKIN — runtime visual override (no .tscn changes)
# ============================================================================

const _CRAFTPIX_THEME = preload("res://Themes/CraftPix/craftpix_ui_tinted.tres")
const _CRAFTPIX_HEADER = preload("res://Themes/CraftPix/header_bar_teal_tinted.tres")


func _apply_craftpix_skin() -> void:
	# 0) Populate region color palette
	_region_palette = RegionTheme.get_palette_for_current_region()

	# 1) Swap root theme to CraftPix
	theme = _CRAFTPIX_THEME

	# 2) Update background colour to region-tinted dark
	var bg: ColorRect = get_node_or_null("Background")
	if bg:
		bg.color = _region_palette.get("bg_dark", Color(0.15, 0.15, 0.2, 1))

	# 3) Tighten margins (20 → 16, CraftPix standard)
	var margin: MarginContainer = get_node_or_null("MarginContainer")
	if margin:
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 16)

	# 4) Get the main VBox that holds all sections
	var main_vbox: VBoxContainer = get_node_or_null("MarginContainer/ScrollContainer/MainVBox")
	if main_vbox == null:
		push_warning("[TownScene] CraftPix skin: MainVBox not found")
		return

	main_vbox.add_theme_constant_override("separation", 12)

	# 5) Hide the debug-style title label (TownHub shell has its own header)
	var title_label: Label = main_vbox.get_node_or_null("TitleLabel")
	if title_label:
		title_label.visible = false

	# 6) Hide all HSeparators (sections now separated by panel wrappers)
	for child in main_vbox.get_children():
		if child is HSeparator:
			child.visible = false

	# 7) Hide all sections — TownHub nav rail / map grid / facilities replaces everything
	for section_name in ["LocationSection", "StashSection", "FacilitiesSection", "HeroesSection", "ActionSection", "TownSwitchSection", "DebugSection"]:
		var section = main_vbox.get_node_or_null(section_name)
		if section:
			section.visible = false

	print("[TownScene] CraftPix skin applied")


## Wraps an existing section VBox inside a CraftPix panel with a teal header bar.
## The section is reparented: MainVBox > PanelContainer > VBox > [header, section].
func _craftpix_wrap_section(parent: VBoxContainer, section_name: String, header_text: String) -> void:
	var section: Control = parent.get_node_or_null(section_name)
	if section == null:
		return

	var idx: int = section.get_index()

	# Hide the old "=== Section ===" header label (first child of each section VBox)
	if section is VBoxContainer and section.get_child_count() > 0:
		var first_child: Node = section.get_child(0)
		if first_child is Label:
			var label_text: String = first_child.text
			if label_text.begins_with("===") or label_text.begins_with("--"):
				first_child.visible = false

	# Create wrapper: PanelContainer > MarginContainer > InnerVBox
	var panel := PanelContainer.new()
	panel.name = section_name + "Panel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Region-tinted section background (slightly lighter than main panel)
	var section_style = StyleBoxFlat.new()
	section_style.bg_color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
	section_style.set_corner_radius_all(3)
	section_style.set_content_margin_all(2)
	panel.add_theme_stylebox_override("panel", section_style)

	var inner_margin := MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", 8)
	inner_margin.add_theme_constant_override("margin_top", 0)
	inner_margin.add_theme_constant_override("margin_right", 8)
	inner_margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(inner_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	inner_margin.add_child(inner_vbox)

	# Create teal header bar
	var header_panel := PanelContainer.new()
	header_panel.custom_minimum_size = Vector2(0, 28)
	header_panel.add_theme_stylebox_override("panel", _CRAFTPIX_HEADER)

	var header_label := Label.new()
	header_label.text = header_text
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	header_panel.add_child(header_label)

	inner_vbox.add_child(header_panel)

	# Reparent the section into the wrapper
	parent.remove_child(section)
	inner_vbox.add_child(section)

	# Insert wrapper at the original index
	if idx >= parent.get_child_count():
		parent.add_child(panel)
	else:
		parent.add_child(panel)
		parent.move_child(panel, idx)


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Build the facility overlay (CanvasLayer — replaces old Window node)
	_build_facility_overlay()

	# Connect button signals
	enter_dungeon_button.pressed.connect(_on_enter_dungeon_pressed)
	continue_run_button.pressed.connect(_on_continue_run_pressed)
	exit_dungeon_button.pressed.connect(_on_exit_dungeon_pressed)
	# Town switch buttons removed (single town per region)
	clear_stash_button.pressed.connect(_on_clear_stash_pressed)
	reset_save_button.pressed.connect(_on_reset_save_pressed)
	add_gold_button.pressed.connect(_on_add_gold_pressed)

	# Rebuild party bar whenever the party changes (e.g. recruit at Inn)
	GameContext.party_changed.connect(_on_party_changed)

	# Apply CraftPix skin before any UI population (when embedded in TownHub)
	if use_craftpix_skin:
		_apply_craftpix_skin()

	# Ensure all heroes are fully healed when entering town view
	if GameContext.get_phase() == GameContext.GamePhase.TOWN:
		GameContext.apply_town_entry_reset()

	# Check if roster highlight should persist (hired hero but never visited roster)
	if GameContext.get_roster().size() > 0 and not GameContext.has_completed_tutorial("visited_roster_after_hire"):
		_highlight_roster_tab = true

	# Initial UI refresh
	_refresh_ui()
	_populate_facilities_list()

	# Log state on load
	var region_id = GameContext.get_current_region_id()
	var town_id = GameContext.get_current_town_id()
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()
	var dungeon_str = dungeon_id if dungeon_id != "" else "none"
	print("[TownScene] script=%s" % get_script().resource_path)
	print("[TownScene] Loaded. Location=%s/%s Dungeon=%s Floor=%d Room=%d/%d" % [
		region_id, town_id, dungeon_str, floor_num, room_idx + 1, rooms_per_floor
	])

	# Play region-specific background music
	UIAudio.play_region_bgm(region_id)


# ============================================================================
# UI REFRESH
# ============================================================================

func _refresh_ui() -> void:
	_update_location_labels()
	_update_button_states()
	_populate_stash_list()
	_populate_heroes_section()


func _update_location_labels() -> void:
	var region_id = GameContext.get_current_region_id()
	var town_id = GameContext.get_current_town_id()
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()

	# Location label
	location_label.text = "Location: %s / %s" % [region_id, town_id]

	# Town name label (get display name from TownData)
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var town_name = town.display_name if town != null and town.display_name != "" else town_id
	town_name_label.text = "Town: %s" % town_name

	# Progress label
	if dungeon_id == "":
		progress_label.text = "Dungeon: none | Floor: 0/0 | Room: 0/0"
	else:
		# Get dungeon display name and floor count
		var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
		var dungeon_name = dungeon.display_name if dungeon != null and dungeon.display_name != "" else dungeon_id
		var floor_count = dungeon.floor_count if dungeon != null else 4
		progress_label.text = "%s | Floor %d/%d | Room %d/%d" % [
			dungeon_name, floor_num, floor_count, room_idx + 1, rooms_per_floor
		]


func _update_button_states() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	var in_dungeon = dungeon_id != ""
	var town_id = GameContext.get_current_town_id()

	# Get town's dungeon_id to check if town has a dungeon
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var town_has_dungeon = town != null and town.dungeon_id != ""

	# Enter Dungeon: enabled only if not in dungeon AND town has a dungeon
	enter_dungeon_button.disabled = in_dungeon or not town_has_dungeon

	# Continue Run: enabled only if in dungeon
	continue_run_button.disabled = not in_dungeon

	# Exit Dungeon: enabled only if in dungeon
	exit_dungeon_button.disabled = not in_dungeon

	# Town switch buttons removed (single town per region)


func _populate_stash_list() -> void:
	# Items v6: Get detailed stash summaries
	var run_summary = {}
	var dungeon_summary = {}
	if GameContext.has_method("get_run_stash_detailed_summary"):
		run_summary = GameContext.get_run_stash_detailed_summary()
	else:
		var run_stash = GameContext.get_run_stash_summary()
		run_summary = { "gold": run_stash.gold, "total_items": run_stash.items_count }

	if GameContext.has_method("get_dungeon_stash_detailed_summary"):
		dungeon_summary = GameContext.get_dungeon_stash_detailed_summary()
	else:
		var dungeon_stash = GameContext.get_dungeon_stash_summary()
		dungeon_summary = { "gold": dungeon_stash.gold, "total_items": dungeon_stash.items_count }

	# Items v6: Format banked stash with detailed summary
	banked_stash_label.text = "Run Stash (Banked): %d gold | Items: %d | Gear: %d Mats: %d Cons: %d" % [
		run_summary.get("gold", 0),
		run_summary.get("total_items", 0),
		run_summary.get("gear_count", 0),
		run_summary.get("mat_count", 0),
		run_summary.get("cons_count", 0)]

	# Items v6: Format dungeon stash (only show if in dungeon or has items)
	var in_dungeon = GameContext.current_dungeon_id != ""
	if in_dungeon or dungeon_summary.get("total_items", 0) > 0 or dungeon_summary.get("gold", 0) > 0:
		unbanked_stash_label.text = "Dungeon Stash (Unbanked): %d gold | Items: %d | Gear: %d Mats: %d Cons: %d" % [
			dungeon_summary.get("gold", 0),
			dungeon_summary.get("total_items", 0),
			dungeon_summary.get("gear_count", 0),
			dungeon_summary.get("mat_count", 0),
			dungeon_summary.get("cons_count", 0)]
		unbanked_stash_label.visible = true
	else:
		unbanked_stash_label.text = "(No dungeon stash - in town)"
		unbanked_stash_label.visible = true

	# Clear existing items in list (immediate removal prevents ghost nodes)
	_clear_children_immediate(stash_list_vbox)

	# Aggregate items by template_id + quality_tier
	# Key format: "template_id:quality_tier" for ItemInstance, "template_id:0" for Dictionary
	var aggregated: Dictionary = {}  # key -> { display_name, qty, quality_tier }
	var items = GameContext.run_items
	print("[TownUI] Populating stash with %d raw items" % items.size())

	for item in items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1

		if item is ItemInstance:
			# ItemInstance from dungeon loot
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name  # Already has quality prefix
			qty = item.quantity
		elif item is Dictionary:
			# Dictionary from shop purchase or add_run_item { item_id, qty, quality_tier }
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			quality_tier = int(item.get("quality_tier", 0))
			# Look up template for display name
			if template_id != "":
				var tpl = DataRegistry.get_item_template(template_id)
				if tpl != null:
					var prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quality_tier, 0, 3)]
					display_name = prefix + tpl.display_name
				else:
					print("[TownUI] Missing item template for id=%s" % template_id)
					display_name = template_id
			else:
				display_name = "(unknown)"
		else:
			print("[TownUI] Unknown item type in stash: %s" % str(item))
			continue

		# Aggregate by template_id + quality_tier
		var key = "%s:%d" % [template_id, quality_tier]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			aggregated[key] = {
				"template_id": template_id,
				"display_name": display_name,
				"qty": qty,
				"quality_tier": quality_tier
			}

	# Populate list from aggregated data with tooltips
	if aggregated.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "(empty)"
		empty_label.modulate = Color(0.78, 0.78, 0.78, 1)
		stash_list_vbox.add_child(empty_label)
	else:
		for key in aggregated.keys():
			var entry = aggregated[key]
			# Items v7: HBox with icon + label
			var tpl = DataRegistry.get_item_template(entry.template_id)
			var item_row = HBoxContainer.new()
			item_row.add_theme_constant_override("separation", 4)

			# Add item icon with quality border if available
			if tpl != null:
				var icon_ctrl = tpl.create_bordered_icon(16, entry.quality_tier)
				if icon_ctrl != null:
					item_row.add_child(icon_ctrl)

			var item_label = Label.new()
			item_label.text = "%s x%d" % [entry.display_name, entry.qty]
			# Color label text by quality
			if entry.quality_tier > 0:
				item_label.modulate = ItemInstance.QUALITY_COLORS[clampi(entry.quality_tier, 0, 3)]

			# Build tooltip with item details (equipment + consumable aware)
			var tooltip_parts: Array[String] = []
			tooltip_parts.append(entry.display_name)
			tooltip_parts.append("ID: %s" % entry.template_id)
			tooltip_parts.append("Qty: %d" % entry.qty)
			if tpl != null:
				# Equipment-specific info: slot, quality with multiplier
				if tpl.equip_slot != "":
					tooltip_parts.append("Slot: %s" % tpl.equip_slot)
					const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
					var q_tier = clampi(entry.quality_tier, 0, 3)
					var mult = QUALITY_MULT[q_tier]
					tooltip_parts.append("Quality: %s (x%.2f)" % [ItemInstance.QUALITY_NAMES[q_tier], mult])
					# Final stat bonuses (scaled by completed regions)
					var region_bonus: float = GameContext.get_completed_region_count() * 0.1
					var bonuses = tpl.get_stat_bonuses_with_quality(entry.quality_tier, region_bonus)
					if not bonuses.is_empty():
						var bonus_parts: Array[String] = []
						for bk in CombatUnit.STAT_KEYS:
							if bonuses.get(bk, 0) > 0:
								bonus_parts.append("%s +%d" % [CombatUnit.STAT_ABBREV.get(bk, bk), bonuses[bk]])
						if not bonus_parts.is_empty():
							tooltip_parts.append("Stats (final): %s" % ", ".join(bonus_parts))
					# Show affix bonus if present
					if entry is ItemInstance and entry.affix_prefix != "":
						var affix_desc: String = DataRegistry.get_regional_affix(entry.affix_id).get("description", "")
						var affix_stat_parts: Array[String] = []
						for ak in entry.affix_stats:
							affix_stat_parts.append("+%d %s" % [int(entry.affix_stats[ak]), ak.to_upper().left(3)])
						tooltip_parts.append("Affix: %s (%s)" % [entry.affix_prefix, ", ".join(affix_stat_parts)])
						if affix_desc != "":
							tooltip_parts.append(affix_desc)
				# Consumable-specific info
				elif tpl.use_effect != "":
					tooltip_parts.append(tpl.get_effect_label())
				tooltip_parts.append("Sell: %d gold" % tpl.base_value)
			item_label.tooltip_text = "\n".join(tooltip_parts)
			item_label.mouse_filter = Control.MOUSE_FILTER_STOP

			item_row.add_child(item_label)
			stash_list_vbox.add_child(item_row)
		print("[TownUI] Stash list populated with %d unique item types" % aggregated.size())


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

## Check if all party heroes are in the middle row and warning not yet dismissed.
func _check_formation_warning() -> bool:
	if GameContext.has_completed_tutorial("warning_formation_all_middle"):
		return false
	var party: Array = GameContext.selected_party
	if party.size() <= 1:
		return false  # Solo hero — row positioning less critical
	for hero_id in party:
		if GameContext.get_hero_row(hero_id) != 1:
			return false  # At least one hero is NOT in middle row
	return true


## Show formation warning overlay. Returns true if user chose to continue anyway.
func _show_formation_warning() -> bool:
	var user_continue: bool = false

	# Overlay
	var overlay := CanvasLayer.new()
	overlay.layer = 11

	# Full-screen backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	# Content VBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Margin inside panel
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(inner_vbox)

	# Title
	var title := Label.new()
	title.text = "Formation Warning"
	title.add_theme_font_size_override("font_size", GameContext.fs(18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner_vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	inner_vbox.add_child(sep)

	# Message
	var msg := Label.new()
	msg.text = "All your heroes are positioned in the Middle row. Consider moving some to the Front row (to absorb melee hits) or Back row (to protect ranged/mage heroes).\n\nYou can change positions using the [F] [M] [B] buttons on hero cards."
	msg.add_theme_font_size_override("font_size", GameContext.fs(14))
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner_vbox.add_child(msg)

	# Checkbox
	var checkbox := CheckBox.new()
	checkbox.text = "Don't show this again"
	checkbox.add_theme_font_size_override("font_size", GameContext.fs(13))
	inner_vbox.add_child(checkbox)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	inner_vbox.add_child(btn_row)

	var back_btn := Button.new()
	back_btn.text = "Go Back"
	back_btn.custom_minimum_size = Vector2(120, 36)
	back_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	btn_row.add_child(back_btn)

	var continue_btn := Button.new()
	continue_btn.text = "Continue Anyway"
	continue_btn.custom_minimum_size = Vector2(160, 36)
	continue_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	btn_row.add_child(continue_btn)

	add_child(overlay)

	# Await user response
	var clicked_continue: bool = false
	var done_signal: Signal = back_btn.pressed  # placeholder

	back_btn.pressed.connect(func():
		clicked_continue = false
		overlay.set_meta("done", true)
	)
	continue_btn.pressed.connect(func():
		clicked_continue = true
		overlay.set_meta("done", true)
	)

	# Poll until a button is pressed (overlay.set_meta triggers exit)
	while not overlay.has_meta("done"):
		await get_tree().process_frame

	# Handle dismiss checkbox
	if clicked_continue and checkbox.button_pressed:
		GameContext.complete_tutorial("warning_formation_all_middle")
		print("[TownUI] Formation warning dismissed permanently")

	user_continue = clicked_continue
	overlay.queue_free()

	print("[TownUI] Formation warning -> %s" % ("continue" if user_continue else "go back"))
	return user_continue


func _on_enter_dungeon_pressed() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.dungeon_id == "":
		print("[TownUI] EnterDungeon FAILED - no dungeon for town '%s'" % town_id)
		return

	# Guard: Require at least one party member
	if GameContext.selected_party.size() == 0:
		print("[TownUI] EnterDungeon BLOCKED - no heroes in party! Visit Inn to recruit.")
		progress_label.text = "Need at least 1 hero! Visit Inn to recruit."
		progress_label.modulate = Color(1, 0.5, 0.5, 1)
		return

	# Formation warning: all heroes in middle row
	if _check_formation_warning():
		var proceed: bool = await _show_formation_warning()
		if not proceed:
			return

	# Tutorial before first dungeon run
	var overlay = TutorialOverlay.try_show(self, "tutorial_first_dungeon")
	if overlay != null:
		await overlay.tutorial_finished

	# Save checkpoint before dungeon (anti-save-scum: reload returns here)
	GameContext.save_game()

	# Enter dungeon (sets dungeon save lock)
	GameContext.enter_dungeon(town.dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[TownUI] EnterDungeon -> dungeon_id=%s floor=%d room=%d/%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _on_continue_run_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[TownUI] ContinueRun FAILED - not in a dungeon")
		return

	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[TownUI] ContinueRun -> dungeon_id=%s floor=%d room=%d/%d" % [
		dungeon_id,
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _on_exit_dungeon_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[TownUI] ExitDungeon ignored - not in a dungeon")
		return

	print("[TownUI] ExitDungeon -> from dungeon_id=%s" % dungeon_id)

	# Exit to town (this sets phase to TOWN internally)
	GameContext.exit_to_town()

	# Refresh UI
	_refresh_ui()


func _switch_town(new_town_id: String) -> void:
	var current_dungeon = GameContext.get_current_dungeon_id()

	# If in dungeon, exit first to avoid inconsistent state
	if current_dungeon != "":
		print("[TownUI] SwitchTown -> exiting dungeon first")
		GameContext.exit_to_town()

	# Set new location (look up region from town data)
	var town_data = DataRegistry.get_town(new_town_id)
	var target_region: String = town_data.region_id if town_data != null else GameContext.get_current_region_id()
	GameContext.set_location(target_region, new_town_id)

	print("[TownUI] SwitchTown -> town_id=%s" % new_town_id)

	# Re-apply skin so region palette colors update
	if use_craftpix_skin:
		_apply_craftpix_skin()

	# Refresh UI and facilities list
	_refresh_ui()
	_populate_facilities_list()


func _on_clear_stash_pressed() -> void:
	# Safe call guard
	if GameContext.has_method("clear_run_stash"):
		GameContext.clear_run_stash()
		print("[TownUI] ClearStash -> stash cleared")
	else:
		print("[TownUI] ClearStash FAILED - method not available")

	# Refresh UI
	_refresh_ui()


## DEV TOOL: Reset save data and reinitialize to fresh state.
## This deletes the save file and clears all runtime state.
func _on_reset_save_pressed() -> void:
	print("[TownUI] RESET SAVE button pressed")

	# Call GameContext reset function
	if GameContext.has_method("reset_save_game"):
		GameContext.reset_save_game()
	else:
		push_warning("[TownUI] reset_save_game not found in GameContext")
		return

	# Close facility panels if open
	if _has_open_panels():
		_close_all_panels()

	# Clear training hall selection state
	_training_selected_hero_id = ""

	# Refresh entire UI
	_refresh_ui()
	_populate_facilities_list()

	print("[TownUI] UI refreshed after save reset")


func _on_add_gold_pressed() -> void:
	print("[TownUI] +100 GOLD (DEV) button pressed")
	GameContext.add_run_gold(100)
	GameContext.save_game()  # Persist banked gold
	var new_gold: int = GameContext.get_run_gold()
	print("[TownUI] Added 100 gold to run stash (saved). New total: %d" % new_gold)
	_refresh_ui()
	# Update gold labels in open facility panels without full rebuild
	for fid in _open_panels:
		var gold_lbl = _open_panels[fid].get("gold_label")
		if gold_lbl:
			gold_lbl.text = "Gold: %d" % new_gold


func _on_close_facility_pressed() -> void:
	_close_all_panels()
	print("[FacilityUI] Close")


# ============================================================================
# FACILITIES
# ============================================================================

func _populate_facilities_list() -> void:
	# Clear existing facility buttons (immediate removal prevents ghost nodes)
	_clear_children_immediate(facilities_vbox)

	# Get current town
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.facility_ids.size() == 0:
		# No facilities - show placeholder
		var placeholder = Label.new()
		placeholder.text = "(no facilities)"
		placeholder.modulate = Color(0.78, 0.78, 0.78, 1)
		facilities_vbox.add_child(placeholder)
		return

	# CraftPix skin: use 2-column grid of styled buttons
	if use_craftpix_skin:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		facilities_vbox.add_child(grid)

		for facility_id in town.facility_ids:
			var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
			var button = Button.new()
			if facility != null:
				button.text = facility.display_name
				button.tooltip_text = "%s — %s" % [facility.display_name, facility.facility_type]
			else:
				button.text = facility_id
			button.custom_minimum_size = Vector2(0, 36)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.set_meta("facility_id", facility_id)
			button.pressed.connect(_on_facility_button_pressed.bind(facility_id))
			grid.add_child(button)
	else:
		# Default layout: centered buttons in a VBox
		for facility_id in town.facility_ids:
			var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null

			var button = Button.new()
			if facility != null:
				button.text = "%s (%s)" % [facility.display_name, facility.facility_type]
			else:
				button.text = facility_id + " (unknown)"

			button.custom_minimum_size = Vector2(200, 28)
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

			# Store facility_id in metadata for the click handler
			button.set_meta("facility_id", facility_id)
			button.pressed.connect(_on_facility_button_pressed.bind(facility_id))

			facilities_vbox.add_child(button)

	print("[TownUI] Populated %d facilities for town '%s'" % [town.facility_ids.size(), town_id])


func _on_facility_button_pressed(facility_id: String) -> void:
	print("[FacilityUI] Button pressed: %s" % facility_id)
	_show_facility_panel(facility_id)


## Public API: open a facility by type (e.g. "shop", "storage", "dungeon").
## Finds the matching facility_id for the current town and opens it.
func show_facility_by_type(facility_type: String) -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return
	for facility_id in town.facility_ids:
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		if facility != null and facility.facility_type == facility_type:
			_show_facility_panel(facility_id)
			return
	print("[TownUI] No facility of type '%s' in town '%s'" % [facility_type, town_id])


## Public API: open a facility by its exact ID (used by TownHub nav rail / map grid).
func show_facility_by_id(facility_id: String) -> void:
	_show_facility_panel(facility_id)


## Public API: switch to another town (used by TownHub travel buttons).
func switch_town(new_town_id: String) -> void:
	_switch_town(new_town_id)


func _show_facility_panel(facility_id: String) -> void:
	# If already open, bring to front and refresh
	if _open_panels.has(facility_id):
		var existing = _open_panels[facility_id]
		var panel = existing.get("panel")
		if panel != null and is_instance_valid(panel) and panel.get_parent() != null:
			panel.get_parent().move_child(panel, -1)
		# Re-point the actions container for any subsequent UI builder calls
		_facility_actions_container = existing.get("actions_container")
		_current_facility_id = facility_id
		var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
		_current_facility = facility
		_current_facility_type = facility.facility_type if facility != null else ""
		print("[FacilityUI] Focused existing panel: %s" % facility_id)
		return

	var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null

	# Store facility for recipes/shop access
	_current_facility = facility
	_current_facility_id = facility_id

	# Reset view states for new panel
	_facility_greeting = ""
	_inn_view = "recruit"
	_shop_view = "buy"
	_temp_shop_allocations = {}
	_equipment_view = "recipes"
	_training_view = "books"
	if not GameContext.has_completed_tutorial("dungeon_dangers_seen"):
		_dungeon_view = "dangers"
	else:
		_dungeon_view = "enter"
	_storage_view = "stash"

	# Create a new panel
	var info = _create_facility_panel(facility_id)
	_open_panels[facility_id] = info

	# Populate title bar
	if facility == null:
		info["title_label"].text = facility_id.capitalize()
		_current_facility_type = ""
	else:
		var town_id = GameContext.get_current_town_id()
		var current_tier = GameContext.get_facility_tier(town_id, facility_id)
		info["title_label"].text = "%s T%d" % [facility.display_name, current_tier]
		_current_facility_type = facility.facility_type

	# Re-point _facility_actions_container to this panel's actions area
	_facility_actions_container = info["actions_container"]

	# Register panel with ESC-close stack
	var panel_node = info["panel"]
	UIAudio.register_closeable(panel_node, _on_close_facility_panel.bind(facility_id))

	# Create dynamic action UI based on facility type
	_create_facility_actions(facility)

	print("[FacilityUI] Opened panel: %s" % facility_id)


func _create_facility_actions(facility) -> void:
	# Clear actions container and repopulate
	if _facility_actions_container == null:
		return
	_clear_children_immediate(_facility_actions_container)

	# Add separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Add type-specific UI
	if facility == null:
		return

	# Show facility-group tutorials on first visit
	match facility.facility_type:
		"equipment":
			TutorialOverlay.try_show(self, "tutorial_equipment_facilities")
		"training_hall":
			TutorialOverlay.try_show(self, "tutorial_training_hall")
		"production":
			TutorialOverlay.try_show(self, "tutorial_production")
		"storage":
			TutorialOverlay.try_show(self, "tutorial_storage")

	match facility.facility_type:
		"dungeon":
			_build_dungeon_ui()
		"storage":
			_build_storage_ui()
		"shop":
			_build_shop_ui()
		"equipment":
			_build_equipment_ui()
		"training_hall":
			_build_training_ui()
		"inn":
			_build_inn_ui()
		"production":
			_build_production_ui()
		_:
			var info = Label.new()
			info.text = "(No actions available)"
			info.modulate = Color(0.78, 0.78, 0.78, 1)
			_facility_actions_container.add_child(info)

	# Auto-fit panel height to content
	_auto_fit_panel_height(_current_facility_id)


# ============================================================================
# FACILITY UI BUILDERS
# ============================================================================

func _build_storage_ui() -> void:
	# Equip mode: show hero picker or comparison instead of normal storage
	if _equip_pending_item_id != "":
		if _equip_selected_hero_id != "":
			_build_equip_comparison_ui()
		else:
			_build_equip_hero_picker_ui()
		return

	# Bag transfer mode: show hero picker for bag item transfer
	if _bag_transfer_pending_item_id != "":
		_build_bag_transfer_hero_picker_ui()
		return

	print("[Storage] opened view=%s" % _storage_view)

	# NPC header with Aldric portrait + greeting + menu
	var facility = _current_facility
	if facility != null and facility.keeper_name != "":
		var menu = [
			{"view": "stash", "label": "Bank Stash"},
			{"view": "equipment", "label": "Manage Equipment"},
			{"view": "upgrade", "label": "Upgrade Storage"},
		]
		_build_npc_header(facility, menu, _storage_view, _on_storage_view_pressed)
	var npc_sep = HSeparator.new()
	_facility_actions_container.add_child(npc_sep)

	if _storage_view == "equipment":
		_build_storage_equipment_ui()
		return

	if _storage_view == "upgrade":
		_build_storage_upgrade_view()
		return

	# Show gold balance
	var run_gold = GameContext.get_run_gold()
	var gold_label = Label.new()
	gold_label.text = "Bank Gold: %d" % run_gold
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Stash capacity display
	var stash_count: int = GameContext.get_current_stash_count()
	var stash_max: int = GameContext.get_max_stash_capacity()
	var capacity_label = Label.new()
	capacity_label.text = "Stash: %d / %d slots" % [stash_count, stash_max]
	var ratio: float = float(stash_count) / float(maxi(1, stash_max))
	if ratio >= 0.9:
		capacity_label.modulate = Color(1.0, 0.4, 0.4, 1)
	elif ratio >= 0.7:
		capacity_label.modulate = Color(1.0, 0.85, 0.4, 1)
	else:
		capacity_label.modulate = Color(0.7, 1.0, 0.7, 1)
	_facility_actions_container.add_child(capacity_label)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Category filter buttons
	var filter_header = Label.new()
	filter_header.text = "-- Bank Stash --"
	filter_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	filter_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(filter_header)

	var filter_row = HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row)

	var filters = ["all", "materials", "consumables", "equipment", "books"]
	for f in filters:
		var btn = Button.new()
		btn.text = f.capitalize()
		btn.custom_minimum_size = Vector2(70, 24)
		btn.disabled = (_storage_filter == f)
		btn.pressed.connect(_on_storage_filter_pressed.bind(f))
		filter_row.add_child(btn)

	# Compact stash button
	var compact_btn = Button.new()
	compact_btn.text = "Compact Stash"
	compact_btn.custom_minimum_size = Vector2(120, 26)
	compact_btn.pressed.connect(_on_storage_compact_pressed)
	_facility_actions_container.add_child(compact_btn)

	# Build stash display grouped by template + quality
	var stash_items = _get_aggregated_stash_items()
	var filtered_items = _filter_stash_items(stash_items, _storage_filter)

	var count_label = Label.new()
	count_label.text = "Showing %d / %d item stacks" % [filtered_items.size(), stash_items.size()]

	count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(count_label)

	if filtered_items.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "(No items in this category)"
		empty_label.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(empty_label)
	else:
		var stash_grid = GridContainer.new()
		stash_grid.columns = 2
		stash_grid.add_theme_constant_override("h_separation", 8)
		stash_grid.add_theme_constant_override("v_separation", 2)
		_facility_actions_container.add_child(stash_grid)
		for item in filtered_items:
			var row = _create_stash_item_row(item)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stash_grid.add_child(row)


func _get_aggregated_stash_items() -> Array:
	# Returns Array of { template_id, quality_tier, qty, display_name, category, affix_id, affix_prefix, affix_stats, source_region }
	var result: Array = []
	var aggregated: Dictionary = {}

	for item in GameContext.run_items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1
		var affix_id := ""
		var affix_prefix := ""
		var affix_stats: Dictionary = {}
		var source_region := ""

		if item is ItemInstance:
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name
			qty = item.quantity
			affix_id = item.affix_id if "affix_id" in item else ""
			affix_prefix = item.affix_prefix if "affix_prefix" in item else ""
			affix_stats = item.affix_stats if "affix_stats" in item else {}
			source_region = item.source_region if "source_region" in item else ""
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			quality_tier = int(item.get("quality_tier", 0))
			affix_id = item.get("affix_id", "")
			affix_prefix = item.get("affix_prefix", "")
			affix_stats = item.get("affix_stats", {})
			source_region = item.get("source_region", "")
			var tpl = DataRegistry.get_item_template(template_id)
			if tpl != null:
				var prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quality_tier, 0, 3)]
				display_name = prefix + tpl.display_name
			else:
				display_name = template_id
		else:
			continue

		# Include affix_id in key so different affixes stay separate
		var key = "%s:%d:%s" % [template_id, quality_tier, affix_id]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			var category = _get_item_category(template_id)
			aggregated[key] = {
				"template_id": template_id,
				"quality_tier": quality_tier,
				"qty": qty,
				"display_name": display_name,
				"category": category,
				"affix_id": affix_id,
				"affix_prefix": affix_prefix,
				"affix_stats": affix_stats,
				"source_region": source_region,
			}

	for key in aggregated.keys():
		result.append(aggregated[key])

	# Sort by category priority: materials first, then equipment, then consumables, then books, then other
	result.sort_custom(_sort_stash_items_by_category)

	return result


## Sort comparator for stash items by category (materials first, then equipment, then consumables)
func _sort_stash_items_by_category(a: Dictionary, b: Dictionary) -> bool:
	var category_order = {
		"materials": 0,
		"equipment": 1,
		"consumables": 2,
		"books": 3,
		"other": 4
	}
	var a_order = category_order.get(a.category, 5)
	var b_order = category_order.get(b.category, 5)
	if a_order != b_order:
		return a_order < b_order
	# Secondary sort: alphabetical by display_name
	return a.display_name.naturalnocasecmp_to(b.display_name) < 0


func _get_item_category(template_id: String) -> String:
	# Determine category from template tags or item_type
	var tpl = DataRegistry.get_item_template(template_id)
	if tpl == null:
		# Fallback for known IDs
		if template_id.begins_with("book_"):
			return "books"
		if template_id in ["herb_sprig", "forest_mushroom", "iron_scrap", "wood_bundle"]:
			return "materials"
		return "other"

	# Check tags first
	for tag in tpl.tags:
		if tag == "book":
			return "books"
		if tag in ["material", "resource", "crafting"]:
			return "materials"

	# Fallback to item_type
	match tpl.item_type:
		"consumable":
			return "consumables"
		"weapon", "armor", "accessory", "offhand":
			return "equipment"
		"tool", "backpack":
			return "equipment"
		_:
			# Check if it has an equip slot
			if tpl.equip_slot != "":
				return "equipment"
			# Default to materials for unknown
			return "materials"


func _filter_stash_items(items: Array, filter: String) -> Array:
	if filter == "all":
		return items
	var result: Array = []
	for item in items:
		if item.category == filter:
			result.append(item)
	return result


func _create_stash_item_row(item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Item icon
	var tpl = DataRegistry.get_item_template(item.template_id)
	if tpl != null:
		var quality_tier = int(item.get("quality_tier", 0))
		var icon_ctrl = tpl.create_bordered_icon(18, quality_tier)
		if icon_ctrl != null:
			row.add_child(icon_ctrl)

	var label = Label.new()
	var quality_prefix = ""
	if item.quality_tier > 0:
		quality_prefix = "[Q%d] " % item.quality_tier
	var affix_prefix_text: String = item.get("affix_prefix", "")
	if affix_prefix_text != "":
		label.text = "%s%s %s x%d" % [quality_prefix, affix_prefix_text, item.display_name, item.qty]
	else:
		label.text = "%s%s x%d" % [quality_prefix, item.display_name, item.qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tpl != null:
		var tooltip_parts: Array[String] = []
		tooltip_parts.append(item.display_name)
		tooltip_parts.append("ID: %s" % item.template_id)
		tooltip_parts.append("Qty: %d" % item.qty)

		# Equipment-specific info: slot, quality with multiplier
		if tpl.equip_slot != "":
			tooltip_parts.append("Slot: %s" % tpl.equip_slot)
			# Quality line with multiplier info
			const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
			var q_tier = clampi(item.quality_tier, 0, 3)
			var mult = QUALITY_MULT[q_tier]
			tooltip_parts.append("Quality: %s (x%.2f)" % [ItemInstance.QUALITY_NAMES[q_tier], mult])
			# Final stat bonuses after quality multiplier + region scaling
			var region_bonus: float = GameContext.get_completed_region_count() * 0.1
			var bonuses = tpl.get_stat_bonuses_with_quality(item.quality_tier, region_bonus)
			if not bonuses.is_empty():
				var bonus_parts: Array[String] = []
				for bk in CombatUnit.STAT_KEYS:
					if bonuses.get(bk, 0) > 0:
						bonus_parts.append("%s +%d" % [CombatUnit.STAT_ABBREV.get(bk, bk), bonuses[bk]])
				if not bonus_parts.is_empty():
					tooltip_parts.append("Stats (final): %s" % ", ".join(bonus_parts))
			# Show affix bonus if present (item may be dict or ItemInstance)
			var bag_affix_prefix: String = item.get("affix_prefix", "") if item is Dictionary else (item.affix_prefix if "affix_prefix" in item else "")
			var bag_affix_id: String = item.get("affix_id", "") if item is Dictionary else (item.affix_id if "affix_id" in item else "")
			if bag_affix_prefix != "":
				var bag_affix_stats = item.get("affix_stats", {}) if item is Dictionary else (item.affix_stats if "affix_stats" in item else {})
				var affix_stat_parts: Array[String] = []
				if bag_affix_stats is Dictionary:
					for ak in bag_affix_stats:
						affix_stat_parts.append("+%d %s" % [int(bag_affix_stats[ak]), ak.to_upper().left(3)])
				tooltip_parts.append("Affix: %s (%s)" % [bag_affix_prefix, ", ".join(affix_stat_parts)])
				var bag_affix_desc: String = DataRegistry.get_regional_affix(bag_affix_id).get("description", "")
				if bag_affix_desc != "":
					tooltip_parts.append(bag_affix_desc)
		else:
			# Non-equipment items: simpler quality display
			if item.quality_tier > 0:
				tooltip_parts.append("Quality: %s" % ItemInstance.QUALITY_NAMES[clampi(item.quality_tier, 0, 3)])

		# Materials: Show what recipes can be crafted with this item
		if item.category == "materials":
			var recipes = GameContext.get_recipes_using_material(item.template_id)
			if recipes.size() > 0:
				tooltip_parts.append("")
				tooltip_parts.append("Used in recipes:")
				for recipe_info in recipes:
					tooltip_parts.append("  • %s (%s)" % [recipe_info.recipe_name, recipe_info.facility_name])

		# Consumables: Show effect description
		if item.category == "consumables" and tpl.use_effect != "":
			tooltip_parts.append("")
			tooltip_parts.append("Effect: %s" % tpl.get_effect_label())

		tooltip_parts.append("")
		tooltip_parts.append("Sell: %d gold" % tpl.base_value)
		label.tooltip_text = "\n".join(tooltip_parts)
		label.mouse_filter = Control.MOUSE_FILTER_STOP  # Enable tooltip on hover
	row.add_child(label)

	# Category tag
	var cat_label = Label.new()
	cat_label.text = "(%s)" % item.category
	cat_label.modulate = Color(0.78, 0.78, 0.78, 1)
	row.add_child(cat_label)

	# v3: Equip button for all equipment items (hero picker flow)
	if tpl != null and tpl.equip_slot != "":
		var affix_data: Dictionary = {}
		if item.get("affix_id", "") != "":
			affix_data = {
				"source_region": item.get("source_region", ""),
				"affix_id": item.get("affix_id", ""),
				"affix_stats": item.get("affix_stats", {}),
				"affix_prefix": item.get("affix_prefix", ""),
			}
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(60, 24)
		equip_btn.pressed.connect(_on_equip_item_pressed.bind(item.template_id, tpl.equip_slot, item.quality_tier, affix_data))
		row.add_child(equip_btn)

	# "To Bag" button for consumables (hero picker flow)
	if item.category == "consumables":
		var bag_btn = Button.new()
		bag_btn.text = "To Bag"
		bag_btn.custom_minimum_size = Vector2(60, 24)
		bag_btn.pressed.connect(_on_bag_transfer_pressed.bind(item.template_id))
		row.add_child(bag_btn)

	return row


func _on_storage_filter_pressed(filter: String) -> void:
	_storage_filter = filter
	print("[Storage] filter=%s" % filter)
	_refresh_facility_panel()


func _on_storage_view_pressed(view: String) -> void:
	_storage_view = view
	_refresh_facility_panel()


func _build_storage_upgrade_view() -> void:
	var facility = _current_facility
	if facility == null:
		return
	var town_id = GameContext.get_current_town_id()
	var current_tier: int = GameContext.get_facility_tier(town_id, facility.facility_id)
	var max_tier: int = facility.max_tier

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)
		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var selected_tier: int = _upgrade_tier_tab

	# Capacity info for this tier
	var capacity_bonus: int = selected_tier * GameContext.STASH_CAPACITY_PER_STORAGE_TIER
	var capacity_label = Label.new()
	capacity_label.text = "Tier %d — Stash Capacity: +%d slots" % [selected_tier, capacity_bonus]
	capacity_label.add_theme_font_size_override("font_size", GameContext.fs(16))
	capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capacity_label.modulate = Color(0.85, 0.85, 0.85, 1)
	_facility_actions_container.add_child(capacity_label)

	if selected_tier <= current_tier:
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Completed"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

	elif selected_tier == current_tier + 1:
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

	else:
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)

	# Current total capacity summary
	var total_sep = HSeparator.new()
	_facility_actions_container.add_child(total_sep)
	var current_max: int = GameContext.get_max_stash_capacity()
	var current_count: int = GameContext.get_current_stash_count()
	var summary_label = Label.new()
	summary_label.text = "Current Stash: %d / %d slots" % [current_count, current_max]
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ratio: float = float(current_count) / float(maxi(1, current_max))
	if ratio >= 0.9:
		summary_label.modulate = Color(1.0, 0.4, 0.4, 1)
	elif ratio >= 0.7:
		summary_label.modulate = Color(1.0, 0.85, 0.4, 1)
	else:
		summary_label.modulate = Color(0.7, 1.0, 0.7, 1)
	_facility_actions_container.add_child(summary_label)


func _build_storage_equipment_ui() -> void:
	var full_roster = GameContext.get_roster()
	if full_roster.size() == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No heroes recruited yet."
		empty_lbl.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(empty_lbl)
		return

	# ---- Filter tab row: [Party] [Town1 (N)] [Town2 (N)] ... ----
	var filter_row = HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row)

	# Party tab
	var party_tab = Button.new()
	party_tab.text = "Party (%d)" % GameContext.selected_party.size()
	party_tab.custom_minimum_size = Vector2(70, 26)
	party_tab.add_theme_font_size_override("font_size", GameContext.fs(13))
	party_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _storage_hero_filter == "party":
		var tab_style = StyleBoxFlat.new()
		tab_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
		tab_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
		tab_style.set_border_width_all(2)
		tab_style.set_corner_radius_all(4)
		party_tab.add_theme_stylebox_override("normal", tab_style)
	party_tab.pressed.connect(func():
		_storage_hero_filter = "party"
		_storage_selected_hero_id = ""
		_refresh_facility_panel()
	)
	filter_row.add_child(party_tab)

	# Town bench tabs — show towns with benched heroes or current town
	var current_town: String = GameContext.get_current_town_id()
	var all_regions = DataRegistry.get_all_regions()
	for region in all_regions:
		if region == null:
			continue
		for town_id in region.town_ids:
			var bench_count: int = GameContext.get_inn_bench_count(town_id)
			if bench_count == 0 and town_id != current_town:
				continue
			var town_data = DataRegistry.get_town(town_id)
			var town_name: String = town_data.display_name if town_data != null else town_id
			var tab_btn = Button.new()
			tab_btn.text = "%s (%d)" % [town_name, bench_count]
			tab_btn.custom_minimum_size = Vector2(60, 26)
			tab_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if _storage_hero_filter == town_id:
				var tab_style = StyleBoxFlat.new()
				tab_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
				tab_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
				tab_style.set_border_width_all(2)
				tab_style.set_corner_radius_all(4)
				tab_btn.add_theme_stylebox_override("normal", tab_style)
			var bound_town: String = town_id
			tab_btn.pressed.connect(func():
				_storage_hero_filter = bound_town
				_storage_selected_hero_id = ""
				_refresh_facility_panel()
			)
			filter_row.add_child(tab_btn)

	# ---- Build roster based on filter ----
	var roster: Array = []
	if _storage_hero_filter == "party":
		for pid in GameContext.get_selected_party():
			var hdata: Dictionary = GameContext.get_hero(pid)
			if not hdata.is_empty():
				roster.append(hdata)
	else:
		roster = GameContext.get_inn_bench_heroes(_storage_hero_filter)

	if roster.is_empty():
		var empty_lbl = Label.new()
		if _storage_hero_filter == "party":
			empty_lbl.text = "(No heroes in party)"
		else:
			empty_lbl.text = "(No heroes benched at this inn)"
		empty_lbl.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(empty_lbl)
		return

	# Auto-select first hero if none selected or stale
	var valid_selection = false
	for h in roster:
		if h.get("hero_id", "") == _storage_selected_hero_id:
			valid_selection = true
			break
	if not valid_selection:
		_storage_selected_hero_id = roster[0].get("hero_id", "")

	# Hero selector row with portraits
	var hero_row = HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 6)
	_facility_actions_container.add_child(hero_row)

	for hero_data in roster:
		var hid = hero_data.get("hero_id", "")
		var is_selected: bool = (hid == _storage_selected_hero_id)

		var hero_btn_vbox = VBoxContainer.new()
		hero_btn_vbox.add_theme_constant_override("separation", 2)

		# Portrait button
		var portrait_btn = Button.new()
		portrait_btn.custom_minimum_size = Vector2(44, 44)
		portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var portrait_path: String = hero_data.get("portrait_path", "")
		if portrait_path != "" and ResourceLoader.exists(portrait_path):
			var ptex = ResourceLoader.load(portrait_path) as Texture2D
			if ptex:
				portrait_btn.icon = ptex
				portrait_btn.expand_icon = true
		else:
			portrait_btn.text = hid.left(2).to_upper()
		if is_selected:
			var sel_style = StyleBoxFlat.new()
			sel_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
			sel_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
			sel_style.set_border_width_all(2)
			sel_style.set_corner_radius_all(4)
			portrait_btn.add_theme_stylebox_override("normal", sel_style)
		portrait_btn.pressed.connect(_on_storage_hero_selected.bind(hid))
		hero_btn_vbox.add_child(portrait_btn)

		# Name label below portrait
		var name_lbl = Label.new()
		name_lbl.text = hero_data.get("name", "?")
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.modulate = Color(0.5, 1.0, 0.8, 1) if is_selected else Color(0.7, 0.7, 0.7, 1)
		hero_btn_vbox.add_child(name_lbl)

		hero_row.add_child(hero_btn_vbox)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# ---- Selected hero info ----
	var hero = GameContext.get_hero(_storage_selected_hero_id)
	if hero.is_empty():
		return
	var hero_id: String = _storage_selected_hero_id
	var hero_name: String = hero.get("name", "Unknown")
	var race_id: String = hero.get("race_id", "human")
	var class_id: String = hero.get("class_id", "")
	var hero_level: int = int(hero.get("level", 1))

	var race_data = DataRegistry.get_race(race_id)
	var class_data = DataRegistry.get_class_data(class_id)
	var race_name: String = race_data.display_name if race_data and race_data.display_name != "" else race_id.capitalize()
	var cls_name: String = class_data.display_name if class_data and class_data.display_name != "" else class_id.capitalize()

	# Two-column layout: left = identity + stats, right = abilities + passives
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	_facility_actions_container.add_child(columns)

	# ======== LEFT COLUMN: Identity + Stats ========
	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	# Portrait + Name/Race/Class header
	var identity_hbox = HBoxContainer.new()
	identity_hbox.add_theme_constant_override("separation", 8)
	left_col.add_child(identity_hbox)

	var portrait_path: String = hero.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var ptex = ResourceLoader.load(portrait_path) as Texture2D
		if ptex:
			var portrait_rect = TextureRect.new()
			portrait_rect.texture = ptex
			portrait_rect.custom_minimum_size = Vector2(64, 64)
			portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			identity_hbox.add_child(portrait_rect)

	var identity_vbox = VBoxContainer.new()
	identity_vbox.add_theme_constant_override("separation", 1)
	identity_hbox.add_child(identity_vbox)

	var name_header = Label.new()
	name_header.text = hero_name
	name_header.add_theme_font_size_override("font_size", GameContext.fs(18))
	name_header.modulate = Color(0.9, 0.8, 0.5, 1)
	identity_vbox.add_child(name_header)

	var race_lbl = Label.new()
	race_lbl.text = "%s  %s  Lv %d" % [race_name, cls_name, hero_level]
	race_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	race_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
	identity_vbox.add_child(race_lbl)

	# Stats block
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var stat_defs: Array = [
		{"key": "health", "label": "HP", "color": Color(0.4, 0.9, 0.4, 1)},
		{"key": "attack", "label": "ATK", "color": Color(0.9, 0.5, 0.4, 1)},
		{"key": "defense", "label": "DEF", "color": Color(0.5, 0.7, 0.9, 1)},
		{"key": "speed", "label": "SPD", "color": Color(0.9, 0.9, 0.4, 1)},
		{"key": "crit_chance", "label": "CRIT", "color": Color(1.0, 0.7, 0.3, 1)},
		{"key": "evasion", "label": "EVD", "color": Color(0.6, 0.9, 0.6, 1)},
		{"key": "resist", "label": "RES", "color": Color(0.7, 0.5, 0.9, 1)},
		{"key": "thorns", "label": "THN", "color": Color(0.8, 0.4, 0.4, 1)},
		{"key": "armor_penetration", "label": "PEN", "color": Color(0.9, 0.6, 0.5, 1)},
		{"key": "life_steal", "label": "LSTL", "color": Color(0.8, 0.3, 0.3, 1)},
	]

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 2)
	left_col.add_child(stats_grid)

	var stat_descriptions: Dictionary = {
		"health": "HP (Hit Points)\nHero is defeated at 0 HP.\nRestored by healing effects and potions.",
		"attack": "ATK (Attack Power)\nDetermines physical damage dealt.\nDamage = max(1, ATK - target DEF)",
		"defense": "DEF (Defense)\nReduces incoming physical damage.\nDamage = max(1, attacker ATK - DEF)",
		"speed": "SPD (Speed)\nDetermines turn order each round.\nHigher speed acts first.\n10+ = 2 actions per turn\n20+ = 3 actions per turn",
		"crit_chance": "CRIT (Critical Hit Chance)\n% chance to deal 1.5x damage.\nCapped at 50%.",
		"evasion": "EVD (Evasion)\n% chance to dodge attacks.\nCapped at 50%.",
		"resist": "RES (Resistance)\nReduces fire, dark, and void damage.\nUses same soft-cap as defense.",
		"thorns": "THN (Thorns)\nFlat damage returned to physical attackers.\nBypasses defense (true damage).",
		"armor_penetration": "PEN (Armor Penetration)\nReduces target's effective defense.\nApplied before defense soft-cap.",
		"life_steal": "LSTL (Life Steal)\n% of damage dealt healed.\nOnly from direct attacks, not DOTs.",
	}

	# Core stats always shown; new stats only if > 0
	var inn_core_keys = ["health", "attack", "defense", "speed"]
	for sd in stat_defs:
		var val = int(eff_stats.get(sd.key, 0))
		if val == 0 and sd.key not in inn_core_keys:
			continue
		var stat_label = Label.new()
		stat_label.text = sd.label
		stat_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_label.modulate = sd.color
		stat_label.custom_minimum_size = Vector2(32, 0)
		stat_label.mouse_filter = Control.MOUSE_FILTER_STOP
		stat_label.tooltip_text = stat_descriptions.get(sd.key, sd.label)
		stats_grid.add_child(stat_label)

		var stat_val = Label.new()
		stat_val.text = str(val)
		stat_val.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_val.modulate = Color(0.9, 0.9, 0.9, 1)
		stat_val.tooltip_text = build_inn_stat_tooltip(sd.key.capitalize(), hero_id)
		stat_val.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_grid.add_child(stat_val)

	# ======== RIGHT COLUMN: Abilities + Passives ========
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	# Abilities
	var ab_header = Label.new()
	ab_header.text = "Abilities"
	ab_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	ab_header.modulate = Color(0.9, 0.8, 0.5, 1)
	right_col.add_child(ab_header)

	if class_data:
		for ab_info in [{"id": class_data.ability_a_id, "tag": "A", "slot": "ability_a"}, {"id": class_data.ability_b_id, "tag": "B", "slot": "ability_b"}]:
			if ab_info.id == "":
				continue
			var ability = DataRegistry.get_ability(ab_info.id)
			var ab_name: String = ability.display_name if ability else ab_info.id.replace("_", " ").capitalize()
			var ab_desc: String = ability.description if ability and ability.description != "" else ""
			var unlocked: bool = GameContext.is_ability_slot_unlocked(ab_info.slot, hero_level)
			var ab_lbl = Label.new()
			if unlocked:
				ab_lbl.text = "%s: %s" % [ab_info.tag, ab_name]
				ab_lbl.modulate = Color(0.8, 0.9, 1.0, 1)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ab_info.slot, 1)
				ab_lbl.text = "%s: %s (Lv %d)" % [ab_info.tag, ab_name, req_lv]
				ab_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
			ab_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			if ab_desc != "":
				ab_lbl.tooltip_text = ab_desc
				ab_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			right_col.add_child(ab_lbl)

	# Passives
	var ps_header = Label.new()
	ps_header.text = "Passives"
	ps_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	ps_header.modulate = Color(0.9, 0.8, 0.5, 1)
	right_col.add_child(ps_header)

	if class_data:
		for ps_info in [{"id": class_data.passive_a_id, "tag": "1", "slot": "passive_a"}, {"id": class_data.passive_b_id, "tag": "2", "slot": "passive_b"}]:
			if ps_info.id == "":
				continue
			var passive = DataRegistry.get_passive(ps_info.id)
			var ps_name: String = passive.display_name if passive else ps_info.id.replace("_", " ").capitalize()
			var ps_desc: String = passive.description if passive and passive.description != "" else ""
			var ps_unlocked: bool = GameContext.is_ability_slot_unlocked(ps_info.slot, hero_level)
			var ps_lbl = Label.new()
			if ps_unlocked:
				ps_lbl.text = "%s: %s" % [ps_info.tag, ps_name]
				ps_lbl.modulate = Color(0.7, 0.85, 0.7, 1)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ps_info.slot, 1)
				ps_lbl.text = "%s: %s (Lv %d)" % [ps_info.tag, ps_name, req_lv]
				ps_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
			ps_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			if ps_desc != "":
				ps_lbl.tooltip_text = ps_desc
				ps_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			right_col.add_child(ps_lbl)

	# Racial passive
	if race_data and race_data.racial_passive_id != "":
		var rp = DataRegistry.get_passive(race_data.racial_passive_id)
		var rp_name: String = rp.display_name if rp else race_data.racial_passive_id.replace("_", " ").capitalize()
		var rp_desc: String = rp.description if rp and rp.description != "" else ""
		var rp_lbl = Label.new()
		rp_lbl.text = "R: %s" % rp_name
		rp_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		rp_lbl.modulate = Color(0.7, 0.85, 0.7, 1)
		if rp_desc != "":
			rp_lbl.tooltip_text = rp_desc
			rp_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		right_col.add_child(rp_lbl)

	# ======== INLINE MANAGE GEAR ========
	var gear_sep = HSeparator.new()
	_facility_actions_container.add_child(gear_sep)

	var gear_header = Label.new()
	gear_header.text = "Equipment"
	gear_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	gear_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_facility_actions_container.add_child(gear_header)

	var equip = GameContext.get_hero_equipment(hero_id)
	var slot_names: Dictionary = {
		"weapon": "Weapon", "offhand": "Offhand", "helmet": "Helmet",
		"armor": "Armor", "legs": "Legs", "ring": "Ring", "amulet": "Amulet", "bag": "Bag"
	}

	for slot in GameContext.ALL_EQUIP_SLOTS:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 6)
		_facility_actions_container.add_child(slot_hbox)

		# Slot label
		var slot_label = Label.new()
		slot_label.text = "%s:" % slot_names.get(slot, slot.capitalize())
		slot_label.custom_minimum_size = Vector2(55, 0)
		slot_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		slot_label.modulate = Color(0.7, 0.7, 0.7, 1)
		slot_hbox.add_child(slot_label)

		# Current item
		var slot_data: Dictionary = equip.get(slot, {})
		var item_id: String = slot_data.get("id", "")
		var quality: int = int(slot_data.get("quality", 0))

		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl:
				# Icon
				var icon_node = tpl.create_bordered_icon(24, quality)
				if icon_node:
					icon_node.tooltip_text = _build_equipment_slot_tooltip(slot, item_id, quality, slot_data)
					icon_node.mouse_filter = Control.MOUSE_FILTER_STOP
					slot_hbox.add_child(icon_node)
				# Name
				var prefix: String = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
				var item_lbl = Label.new()
				item_lbl.text = "%s%s" % [prefix, tpl.display_name]
				item_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
				item_lbl.modulate = Color(0.9, 0.7, 0.5, 1)
				item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				item_lbl.tooltip_text = _build_equipment_slot_tooltip(slot, item_id, quality, slot_data)
				item_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
				slot_hbox.add_child(item_lbl)
			else:
				var empty_item = Label.new()
				empty_item.text = "(unknown)"
				empty_item.add_theme_font_size_override("font_size", GameContext.fs(13))
				empty_item.modulate = Color(0.7, 0.7, 0.7, 1)
				empty_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_hbox.add_child(empty_item)
		else:
			var empty_item = Label.new()
			empty_item.text = "(empty)"
			empty_item.add_theme_font_size_override("font_size", GameContext.fs(13))
			empty_item.modulate = Color(0.7, 0.7, 0.7, 1)
			empty_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_hbox.add_child(empty_item)

		# Equip button
		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(50, 22)
		equip_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		equip_btn.pressed.connect(_on_equip_slot_pressed.bind(hero_id, slot))
		slot_hbox.add_child(equip_btn)

		# Unequip button (only if slot has item)
		if item_id != "":
			var unequip_btn = Button.new()
			unequip_btn.text = "X"
			unequip_btn.custom_minimum_size = Vector2(24, 22)
			unequip_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			unequip_btn.tooltip_text = "Unequip to stash"
			unequip_btn.pressed.connect(_on_unequip_slot_pressed.bind(hero_id, slot))
			slot_hbox.add_child(unequip_btn)

	# ======== BAG CONTENTS ========
	var bag_sep2 = HSeparator.new()
	_facility_actions_container.add_child(bag_sep2)

	var bag_capacity: int = GameContext.get_hero_bag_capacity(hero_id)
	var bag_items: Array = GameContext.get_hero_bag(hero_id)
	var bag_header = Label.new()
	bag_header.text = "Bag (%d/%d)" % [bag_items.size(), bag_capacity]
	bag_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	bag_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_facility_actions_container.add_child(bag_header)

	for i in range(bag_items.size()):
		var entry: Dictionary = bag_items[i]
		var bag_item_id: String = entry.get("item_id", "")
		var bag_hbox = HBoxContainer.new()
		bag_hbox.add_theme_constant_override("separation", 6)
		_facility_actions_container.add_child(bag_hbox)

		var btpl = DataRegistry.get_item_template(bag_item_id)
		if btpl:
			var bicon = btpl.create_bordered_icon(20, 0)
			if bicon:
				bicon.mouse_filter = Control.MOUSE_FILTER_STOP
				bicon.tooltip_text = btpl.display_name
				bag_hbox.add_child(bicon)

		var bag_item_lbl = Label.new()
		bag_item_lbl.text = btpl.display_name if btpl else bag_item_id
		bag_item_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		bag_item_lbl.modulate = Color(0.7, 0.9, 0.7, 1)
		bag_item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_hbox.add_child(bag_item_lbl)

		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(55, 22)
		remove_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		var captured_bag_id: String = bag_item_id
		remove_btn.pressed.connect(func():
			GameContext.move_item_hero_bag_to_stash(hero_id, captured_bag_id)
			_refresh_facility_panel()
		)
		bag_hbox.add_child(remove_btn)

	if bag_items.size() < bag_capacity:
		var add_btn = Button.new()
		add_btn.text = "Add Item to Bag"
		add_btn.custom_minimum_size = Vector2(120, 24)
		add_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		add_btn.pressed.connect(func():
			_show_bag_item_selection(hero_id)
		)
		_facility_actions_container.add_child(add_btn)


func _on_storage_hero_selected(hero_id: String) -> void:
	_storage_selected_hero_id = hero_id
	_refresh_facility_panel()


func _on_storage_compact_pressed() -> void:
	# Re-aggregate display (no actual data change needed since we aggregate on display)
	print("[Storage] compacted")
	_refresh_facility_panel()


func _create_item_transfer_row(item_id: String, qty: int, source: String, action: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label = Label.new()
	var display_name = item_id
	var template = DataRegistry.get_item_template(item_id) if DataRegistry.has_method("get_item_template") else null
	if template != null and template.display_name != "":
		display_name = template.display_name
	label.text = "%s x%d (%s)" % [display_name, qty, source]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn = Button.new()
	btn.text = action.capitalize()
	btn.custom_minimum_size = Vector2(80, 24)
	btn.pressed.connect(_on_item_transfer_pressed.bind(item_id, action))
	row.add_child(btn)

	return row


func _build_shop_ui() -> void:
	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No shop available)"
		no_data.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_data)
		return

	TutorialOverlay.try_show(self, "tutorial_shop")

	var facility = _current_facility
	var town_id = GameContext.get_current_town_id()
	var facility_id = facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# NPC header: portrait + greeting + menu options
	var menu = [
		{"view": "buy", "label": "Browse Wares"},
		{"view": "sell", "label": "Sell Items"},
		{"view": "upgrade", "label": "Upgrade Store"},
	]
	_build_npc_header(facility, menu, _shop_view, _on_shop_view_pressed)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Dispatch to selected view
	match _shop_view:
		"buy":
			_build_shop_buy_view(facility, current_tier)
		"upgrade":
			_build_shop_upgrade_view(facility, current_tier)

	print("[ShopUI] facility=%s tier=%d view=%s" % [facility_id, current_tier, _shop_view])


## Shop buy view: two-state flow (unstocked → allocate → stock → browse items)
func _build_shop_buy_view(facility, current_tier: int) -> void:
	var town_id = GameContext.get_current_town_id()
	var shop_id = _current_facility_id
	var saved_allocations: int = GameContext.get_shop_allocated_slots(town_id)

	# Stash full warning (shown in both states)
	var stash_count: int = GameContext.get_current_stash_count()
	var stash_max: int = GameContext.get_max_stash_capacity()
	if stash_count >= stash_max:
		var warn = Label.new()
		warn.text = "Stash Full (%d/%d slots) — Sell items to make room!" % [stash_count, stash_max]
		warn.add_theme_font_size_override("font_size", GameContext.fs(14))
		warn.modulate = Color(1.0, 0.4, 0.3, 1)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(warn)

	if saved_allocations > 0:
		_build_shop_stocked_view(facility, current_tier, town_id, shop_id)
	else:
		_build_shop_unstocked_view(facility, current_tier, town_id, shop_id)


## Unstocked state: allocation controls + Stock Shop button, no items yet.
func _build_shop_unstocked_view(facility, current_tier: int, town_id: String, shop_id: String) -> void:
	var max_slots: int = GameContext.get_shop_max_slots(town_id)
	var temp_total: int = _get_temp_allocated_total()

	var hint = Label.new()
	hint.text = "Choose how many slots each facility fills, then stock the shop."
	hint.add_theme_font_size_override("font_size", GameContext.fs(13))
	hint.modulate = Color(0.7, 0.8, 0.9, 1)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facility_actions_container.add_child(hint)

	# Allocation rows (reads from _temp_shop_allocations)
	for contrib_facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var facility_data = DataRegistry.get_facility(contrib_facility_id)
		var display_name: String = facility_data.display_name if facility_data != null else contrib_facility_id.capitalize()
		var current_alloc: int = _temp_shop_allocations.get(contrib_facility_id, 0)
		var recipe_count: int
		if facility_data != null and facility_data.mixing_recipe_file != "":
			recipe_count = GameContext.get_facility_shop_recipes(contrib_facility_id).size()
		else:
			recipe_count = GameContext.get_facility_unlocked_recipes(contrib_facility_id).size()

		var alloc_row = HBoxContainer.new()
		alloc_row.add_theme_constant_override("separation", 4)

		# Facility icon (20x20)
		var icon_path: String = facility_data.icon_path if facility_data != null else ""
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var icon_tex = ResourceLoader.load(icon_path) as Texture2D
			if icon_tex != null:
				var icon_rect = TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(20, 20)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				alloc_row.add_child(icon_rect)

		var fac_tier: int = GameContext.get_facility_tier(town_id, contrib_facility_id)
		var fac_label = Label.new()
		fac_label.text = "%s T%d" % [display_name, fac_tier]
		fac_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		fac_label.tooltip_text = "Recipes unlocked: %d" % recipe_count
		if recipe_count == 0:
			fac_label.modulate = Color(0.7, 0.7, 0.7, 1)
		alloc_row.add_child(fac_label)

		var recipe_label = Label.new()
		recipe_label.text = "Recipes: %d" % recipe_count
		recipe_label.add_theme_font_size_override("font_size", GameContext.fs(12))
		recipe_label.modulate = Color(0.6, 0.7, 0.6, 1) if recipe_count > 0 else Color(0.7, 0.7, 0.7, 1)
		alloc_row.add_child(recipe_label)

		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size = Vector2(22, 22)
		minus_btn.disabled = current_alloc <= 0
		minus_btn.pressed.connect(_on_temp_slot_minus.bind(contrib_facility_id))
		alloc_row.add_child(minus_btn)

		var slot_count = Label.new()
		slot_count.text = "%d" % current_alloc
		slot_count.custom_minimum_size = Vector2(16, 0)
		slot_count.add_theme_font_size_override("font_size", GameContext.fs(13))
		slot_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alloc_row.add_child(slot_count)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size = Vector2(22, 22)
		plus_btn.disabled = temp_total >= max_slots or recipe_count == 0 or current_alloc >= recipe_count
		if current_alloc >= recipe_count and recipe_count > 0:
			plus_btn.tooltip_text = "All %d recipes allocated" % recipe_count
		plus_btn.pressed.connect(_on_temp_slot_plus.bind(contrib_facility_id))
		alloc_row.add_child(plus_btn)

		_facility_actions_container.add_child(alloc_row)

	# Slots summary
	var slots_label = Label.new()
	slots_label.text = "Slots: %d / %d" % [temp_total, max_slots]
	slots_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	slots_label.modulate = Color(0.7, 1.0, 0.7, 1) if temp_total < max_slots else Color(1.0, 0.9, 0.5, 1)
	_facility_actions_container.add_child(slots_label)

	# Stock Shop button — enabled only when all slots allocated
	var stock_btn = Button.new()
	stock_btn.text = "Stock Shop (%d/%d)" % [temp_total, max_slots]
	stock_btn.custom_minimum_size = Vector2(180, 32)
	stock_btn.disabled = temp_total != max_slots
	if temp_total == max_slots:
		stock_btn.modulate = Color(1.0, 0.9, 0.5, 1)
	stock_btn.pressed.connect(_on_stock_shop_pressed)
	_facility_actions_container.add_child(stock_btn)


## Stocked state: read-only allocation summary + items + Refresh + Clear & Re-allocate.
func _build_shop_stocked_view(facility, current_tier: int, town_id: String, shop_id: String) -> void:
	var max_slots: int = GameContext.get_shop_max_slots(town_id)
	var allocated_slots: int = GameContext.get_shop_allocated_slots(town_id)

	# Read-only allocation summary with icons
	var summary_hbox = HBoxContainer.new()
	summary_hbox.add_theme_constant_override("separation", 6)
	_facility_actions_container.add_child(summary_hbox)

	var stocked_prefix = Label.new()
	stocked_prefix.text = "Stocked:"
	stocked_prefix.add_theme_font_size_override("font_size", GameContext.fs(13))
	stocked_prefix.modulate = Color(0.7, 0.9, 0.7, 1)
	summary_hbox.add_child(stocked_prefix)

	for contrib_facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var alloc: int = GameContext.get_facility_slot_allocation(town_id, contrib_facility_id)
		if alloc <= 0:
			continue
		var facility_data = DataRegistry.get_facility(contrib_facility_id)
		var dname: String = facility_data.display_name if facility_data != null else contrib_facility_id.capitalize()

		# Facility icon (16x16)
		var icon_path: String = facility_data.icon_path if facility_data != null else ""
		if icon_path != "" and ResourceLoader.exists(icon_path):
			var icon_tex = ResourceLoader.load(icon_path) as Texture2D
			if icon_tex != null:
				var icon_rect = TextureRect.new()
				icon_rect.texture = icon_tex
				icon_rect.custom_minimum_size = Vector2(16, 16)
				icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				summary_hbox.add_child(icon_rect)

		var entry_label = Label.new()
		entry_label.text = "%d" % alloc
		entry_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		entry_label.modulate = Color(0.7, 0.9, 0.7, 1)
		summary_hbox.add_child(entry_label)

	var slots_suffix = Label.new()
	slots_suffix.text = "(%d/%d)" % [allocated_slots, max_slots]
	slots_suffix.add_theme_font_size_override("font_size", GameContext.fs(13))
	slots_suffix.modulate = Color(0.7, 0.9, 0.7, 1)
	summary_hbox.add_child(slots_suffix)

	# Action buttons row: Refresh + Clear & Re-allocate
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_facility_actions_container.add_child(btn_row)

	# Shop refresh button with tier-based limit
	var refresh_count_val: int = GameContext.get_shop_refresh_count(shop_id)
	var refresh_limit: int = GameContext.get_shop_refresh_limit(shop_id)
	var refresh_remaining: int = refresh_limit - refresh_count_val
	var refresh_cost: int = GameContext.get_shop_refresh_cost(shop_id)
	var refresh_btn = Button.new()
	if refresh_remaining > 0:
		refresh_btn.text = "Refresh (%d left) - %dg" % [refresh_remaining, refresh_cost]
	else:
		refresh_btn.text = "Refresh (0 left)"
	refresh_btn.custom_minimum_size = Vector2(160, 28)
	refresh_btn.disabled = refresh_remaining <= 0 or GameContext.get_run_gold() < refresh_cost
	refresh_btn.tooltip_text = "Re-roll shop inventory with new random items.\nKeeps your current facility allocation."
	refresh_btn.pressed.connect(_on_shop_refresh_pressed.bind(shop_id))
	btn_row.add_child(refresh_btn)

	var realloc_btn = Button.new()
	realloc_btn.text = "Re-allocate (%d left) - %dg" % [refresh_remaining, refresh_cost] if refresh_remaining > 0 else "Re-allocate (0 left)"
	realloc_btn.custom_minimum_size = Vector2(160, 28)
	realloc_btn.modulate = Color(0.8, 0.6, 0.5, 1)
	realloc_btn.disabled = refresh_remaining <= 0 or GameContext.get_run_gold() < refresh_cost
	realloc_btn.tooltip_text = "Clear current stock and change facility allocations.\nCosts one refresh."
	realloc_btn.pressed.connect(_on_clear_and_reallocate_pressed)
	btn_row.add_child(realloc_btn)

	var items_sep = HSeparator.new()
	_facility_actions_container.add_child(items_sep)

	# Get context for seeded RNG
	var region_id: String = GameContext.get_current_region_id()
	var town_tier: int = GameContext.get_town_tier(town_id)
	var restock_ver: int = GameContext.get_shop_restock_version(shop_id)
	var run_seed: int = GameContext.get_run_seed()

	# Get shop profile for town-unique inventory
	var shop_profile = facility.shop_profile
	var profile_id: String = shop_profile.get("profile_id", "default") if shop_profile else "default"

	# Use SeededRNG.shop_seed() with run_seed for per-playthrough variety
	var base_shop_seed: int = SeededRNG.shop_seed(region_id, town_id, restock_ver, run_seed)
	# Mix in facility tier so shop re-rolls on town upgrades
	var seed_str = "%s_%d_%d" % [shop_id, town_tier, base_shop_seed]
	var shop_seed_val: int = seed_str.hash()
	var shop_rng = RandomNumberGenerator.new()
	shop_rng.seed = shop_seed_val

	print("[ShopRNG] shop=%s town=%s profile=%s version=%d slots=%d/%d run_seed=%d" % [shop_id, town_id, profile_id, restock_ver, allocated_slots, max_slots, run_seed])

	# Facility-allocated equipment section (items based on saved allocations)
	var facility_items = _generate_facility_allocated_items(town_id, shop_rng)
	if facility_items.size() > 0:
		var equip_header = Label.new()
		equip_header.text = "-- Equipment for Sale --"
		equip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_header.modulate = Color(0.7, 0.7, 0.7, 1)
		_facility_actions_container.add_child(equip_header)

		for entry in facility_items:
			var slot_key: String = entry.get("slot_key", "")
			if slot_key != "" and GameContext.is_shop_slot_purchased(shop_id, slot_key):
				var empty_row = _create_empty_shop_slot_row()
				_facility_actions_container.add_child(empty_row)
			else:
				var row = _create_shop_row(entry, shop_id)
				_facility_actions_container.add_child(row)
	else:
		var no_recipes = Label.new()
		no_recipes.text = "(No items available - unlock recipes at facilities)"
		no_recipes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_recipes)


## Shop upgrade view: tier tabs + slot allocation + stash upgrades
func _build_shop_upgrade_view(facility, current_tier: int) -> void:
	var max_tier = facility.max_tier
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)
		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var selected_tier = _upgrade_tier_tab

	if selected_tier <= current_tier:
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Unlocked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)
		_build_shop_tier_benefits(facility, selected_tier, current_tier)

	elif selected_tier == current_tier + 1:
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

		var sep2 = HSeparator.new()
		_facility_actions_container.add_child(sep2)
		_build_shop_tier_benefits(facility, selected_tier, current_tier)

	else:
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)

## Display Shop tier benefits (real mechanical stats)
func _build_shop_tier_benefits(facility, tier: int, current_tier: int) -> void:
	var benefits: Array[String] = _get_tier_benefits(facility, tier)
	for benefit_text in benefits:
		var blabel = Label.new()
		blabel.text = benefit_text
		blabel.add_theme_font_size_override("font_size", GameContext.fs(14))
		blabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(blabel)


## Generate shop inventory from pool data using weighted random selection.
## Uses shop_profile for town-unique category rolls and weight multipliers.
## Returns array of: { "type": "item", ...item_data } or { "type": "locked", "category": cat, "reason": reason }
func _generate_pool_inventory(rng: RandomNumberGenerator, town_id: String, dungeon_id: String) -> Array:
	var result: Array = []

	# Get pool ID and shop rolls from FacilityData
	var pool_id = _current_facility.shop_pool_id
	var base_shop_rolls = _current_facility.shop_rolls
	var shop_profile = _current_facility.shop_profile

	# Extract profile settings (town-unique)
	var rolls_override: Dictionary = shop_profile.get("rolls_override", {}) if shop_profile else {}
	var category_weight_mult: Dictionary = shop_profile.get("category_weight_mult", {}) if shop_profile else {}

	if pool_id == "":
		print("[ShopRNG] No pool_id configured, using legacy shop_items")
		# Fallback to legacy shop_items_legacy
		var legacy_items = _current_facility.shop_items_legacy
		var facility_id = _current_facility.facility_id if _current_facility != null else ""
		return _filter_legacy_items(legacy_items, town_id, dungeon_id, facility_id)

	# Load pool JSON
	var pool_data = _load_shop_pool(pool_id)
	if pool_data.is_empty():
		print("[ShopRNG] Failed to load pool: %s" % pool_id)
		return result

	# Extract weight_by_tier from pool (for tier-based weight multipliers)
	var weight_by_tier: Dictionary = pool_data.get("weight_by_tier", {})

	# Determine which categories to process (union of base rolls and overrides)
	var categories_to_process: Array = []
	for cat in base_shop_rolls.keys():
		if cat not in categories_to_process:
			categories_to_process.append(cat)
	for cat in rolls_override.keys():
		if cat not in categories_to_process:
			categories_to_process.append(cat)

	# Process each category
	for category in categories_to_process:
		# Use rolls_override if present, otherwise base_shop_rolls
		var roll_count: int = 0
		if rolls_override.has(category):
			roll_count = int(rolls_override[category])
		elif base_shop_rolls.has(category):
			roll_count = int(base_shop_rolls[category])

		if roll_count <= 0:
			continue

		var category_pool = pool_data.get(category, [])
		if category_pool.size() == 0:
			print("[ShopRNG] category=%s candidates=0 picked=[] rolls=%d (empty pool)" % [category, roll_count])
			continue

		# Filter candidates by unlock/gates BEFORE selection, track gate reasons
		var filter_result = _filter_pool_candidates_with_reason(category_pool, town_id, dungeon_id)
		var candidates = filter_result.candidates
		var gate_reasons = filter_result.gate_reasons

		if candidates.size() == 0:
			# All items gated - add a "(Locked)" placeholder
			var reason = gate_reasons[0] if gate_reasons.size() > 0 else "No stock"
			print("[ShopRNG] category=%s candidates=0 picked=[] rolls=%d (all gated: %s)" % [category, roll_count, reason])
			result.append({"type": "locked", "category": category, "reason": reason})
			continue

		# Get category weight multiplier from shop profile (town-unique selection bias)
		var cat_weight_mult: float = category_weight_mult.get(category, 1.0) if category_weight_mult else 1.0

		# Pick items using weighted random with tier multipliers and category multiplier
		var picked = _weighted_pick_with_tier(rng, candidates, roll_count, weight_by_tier, cat_weight_mult)

		var picked_ids: Array = []
		for item in picked:
			picked_ids.append(item.get("item_id", "?"))
			# Mark as item type for UI rendering
			var item_copy = item.duplicate()
			item_copy["type"] = "item"
			result.append(item_copy)

		print("[ShopRNG] category=%s rolls=%d candidates=%d picked=%s" % [
			category, roll_count, candidates.size(), str(picked_ids)
		])

	return result


## Generate shop items from unlocked recipes.
## Quality is rolled based on the source facility's tier at time of unlock.
func _generate_recipe_shop_items() -> Array:
	var result: Array = []
	var unlocked_recipe_ids = GameContext.get_all_unlocked_recipes()

	for item_id in unlocked_recipe_ids:
		var recipe_data = GameContext.get_recipe_data(item_id)
		if recipe_data.is_empty():
			continue

		var template = DataRegistry.get_item_template(item_id)
		if template == null:
			continue

		# Only include equipment items (not consumables which are in the regular pool)
		if template.equip_slot == "":
			continue

		# Get facility tier from recipe data
		var facility_tier = recipe_data.get("facility_tier", 1)

		# Roll quality based on facility tier
		var quality_tier = GameContext.roll_quality_for_facility_tier(facility_tier)

		# Calculate price based on template value and quality
		var base_price = template.get_buy_value()
		var quality_mult = [1.0, 1.2, 1.5, 2.0]  # Price multiplier per quality
		var final_price = int(base_price * quality_mult[quality_tier])

		result.append({
			"type": "item",
			"item_id": item_id,
			"price_gold": final_price,
			"quality_tier": quality_tier,
			"source_facility": recipe_data.get("source_facility", ""),
			"from_recipe": true
		})

	# Sort by item name for consistent display
	result.sort_custom(func(a, b):
		var name_a = DataRegistry.get_item_template(a.get("item_id", ""))
		var name_b = DataRegistry.get_item_template(b.get("item_id", ""))
		var display_a = name_a.display_name if name_a else a.get("item_id", "")
		var display_b = name_b.display_name if name_b else b.get("item_id", "")
		return display_a < display_b
	)

	print("[ShopRecipes] generated %d items from unlocked recipes" % result.size())
	return result


## Load shop pool JSON file.
func _load_shop_pool(pool_id: String) -> Dictionary:
	var pool_path = "res://Data/Shops/Pools/%s.json" % pool_id
	if not FileAccess.file_exists(pool_path):
		push_warning("[ShopRNG] Pool file not found: %s" % pool_path)
		return {}

	var file = FileAccess.open(pool_path, FileAccess.READ)
	if file == null:
		push_warning("[ShopRNG] Failed to open pool file: %s" % pool_path)
		return {}

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_warning("[ShopRNG] Failed to parse pool JSON: %s" % pool_path)
		return {}

	var data = json.get_data()
	return data if data is Dictionary else {}


## Filter pool candidates by unlock groups and progression gating.
## Returns { candidates: Array, gate_reasons: Array } where gate_reasons are human-readable strings.
func _filter_pool_candidates_with_reason(pool: Array, town_id: String, dungeon_id: String) -> Dictionary:
	var candidates: Array = []
	var gate_reasons: Array = []

	for item in pool:
		var item_id = item.get("item_id", "")
		var requires_group = item.get("requires_unlock_group", "")
		var required_town_tier = item.get("required_town_tier", 1)
		var required_floor = item.get("required_dungeon_floor_unlocked", 1)

		# Check unlock group requirement
		if requires_group != "" and not GameContext.has_unlocked_group(requires_group):
			print("[Gate] item=%s reason=unlock_group required=%s" % [item_id, requires_group])
			gate_reasons.append("Unlock: %s" % requires_group)
			continue

		# Check town tier gating
		if required_town_tier > 1:
			if not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
				var have = GameContext.get_town_tier(town_id)
				print("[Gate] item=%s reason=town_tier required=%d have=%d" % [item_id, required_town_tier, have])
				gate_reasons.append("Town tier %d required" % required_town_tier)
				continue

		# Check dungeon floor gating
		if required_floor > 1:
			if not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
				var have = GameContext.get_unlocked_floor(dungeon_id)
				print("[Gate] item=%s reason=dungeon_floor required=%d have=%d dungeon=%s" % [item_id, required_floor, have, dungeon_id])
				gate_reasons.append("Floor %d required" % required_floor)
				continue

		candidates.append(item)

	return { "candidates": candidates, "gate_reasons": gate_reasons }


## Legacy filter (for backwards compat).
func _filter_pool_candidates(pool: Array, town_id: String, dungeon_id: String) -> Array:
	return _filter_pool_candidates_with_reason(pool, town_id, dungeon_id).candidates


## Weighted random pick with tier-based and category weight multipliers.
## effective_weight = base_weight * tier_mult * category_weight_mult
## No duplicates unless pool < count (then duplicates allowed).
func _weighted_pick_with_tier(rng: RandomNumberGenerator, candidates: Array, count: int, weight_by_tier: Dictionary, cat_weight_mult: float) -> Array:
	var picked: Array = []
	var pool = candidates.duplicate()

	for i in range(count):
		if pool.size() == 0:
			# Pool exhausted, allow duplicates from original candidates
			if candidates.size() > 0:
				pool = candidates.duplicate()
				print("[ShopRNG] Pool exhausted, allowing duplicate")
			else:
				break

		# Calculate total weight with tier and category multipliers
		var total_weight = 0.0
		for item in pool:
			total_weight += _get_effective_weight(item, weight_by_tier, cat_weight_mult)

		if total_weight <= 0:
			break

		# Roll weighted random
		var roll = rng.randf() * total_weight
		var cumulative = 0.0
		var selected_idx = -1

		for j in range(pool.size()):
			cumulative += _get_effective_weight(pool[j], weight_by_tier, cat_weight_mult)
			if roll <= cumulative:
				selected_idx = j
				break

		if selected_idx >= 0:
			picked.append(pool[selected_idx])
			pool.remove_at(selected_idx)

	return picked


## Calculate effective weight: base_weight * tier_mult * category_weight_mult
## tier can be int, float, or string in JSON - handle all robustly.
func _get_effective_weight(item: Dictionary, weight_by_tier: Dictionary, cat_weight_mult: float) -> float:
	var base_weight = float(item.get("weight", 10))

	# Get tier from item (default 1), handle int/float/string
	var tier_raw = item.get("tier", 1)
	var tier_str = str(int(tier_raw))  # Normalize to string key

	# Get tier multiplier from weight_by_tier (default 1.0)
	var tier_mult = 1.0
	if weight_by_tier.has(tier_str):
		tier_mult = float(weight_by_tier[tier_str])
	elif weight_by_tier.has(int(tier_raw)):  # Also try int key
		tier_mult = float(weight_by_tier[int(tier_raw)])

	return base_weight * tier_mult * cat_weight_mult


## Legacy weighted pick (for backwards compat).
func _weighted_pick(rng: RandomNumberGenerator, candidates: Array, count: int) -> Array:
	return _weighted_pick_with_tier(rng, candidates, count, {}, 1.0)


## Filter legacy shop items (fallback when no pool configured).
func _filter_legacy_items(items: Array, town_id: String, dungeon_id: String, facility_id: String = "") -> Array:
	var result: Array = []
	var facility_tier = 1
	if facility_id != "":
		facility_tier = GameContext.get_facility_tier(town_id, facility_id)

	for item in items:
		var item_id = item.get("item_id", "")
		var requires_group = item.get("requires_unlock_group", "")
		var required_town_tier = item.get("required_town_tier", 1)
		var required_floor = item.get("required_dungeon_floor_unlocked", 1)
		var required_facility_tier = item.get("required_facility_tier", 1)

		if requires_group != "" and not GameContext.has_unlocked_group(requires_group):
			continue
		if required_town_tier > 1 and not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
			continue
		if required_floor > 1 and not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
			continue
		if required_facility_tier > facility_tier:
			print("[Gate] item=%s reason=facility_tier required=%d have=%d" % [item_id, required_facility_tier, facility_tier])
			continue

		result.append(item)

	return result


## Handle shop refresh button press - spends gold and regenerates inventory.
func _on_shop_refresh_pressed(shop_id: String) -> void:
	var success = GameContext.spend_shop_refresh(shop_id)
	if success:
		GameContext.clear_shop_purchased_slots(shop_id)
	_refresh_facility_panel()


## Get total temp-allocated slots across all facilities.
func _get_temp_allocated_total() -> int:
	var total: int = 0
	for key in _temp_shop_allocations:
		total += _temp_shop_allocations[key]
	return total


## Temp allocation: increment a facility's slot count (unstocked state).
func _on_temp_slot_plus(facility_id: String) -> void:
	var town_id = GameContext.get_current_town_id()
	var max_slots: int = GameContext.get_shop_max_slots(town_id)
	if _get_temp_allocated_total() >= max_slots:
		return
	# Cap at recipe count — can't allocate more slots than unique recipes
	var fac_data = DataRegistry.get_facility(facility_id)
	var recipe_count: int
	if fac_data != null and fac_data.mixing_recipe_file != "":
		recipe_count = GameContext.get_facility_shop_recipes(facility_id).size()
	else:
		recipe_count = GameContext.get_facility_unlocked_recipes(facility_id).size()
	var current_alloc: int = _temp_shop_allocations.get(facility_id, 0)
	if recipe_count > 0 and current_alloc >= recipe_count:
		return
	_temp_shop_allocations[facility_id] = _temp_shop_allocations.get(facility_id, 0) + 1
	print("[Shop] temp_slot_plus facility=%s total=%d" % [facility_id, _get_temp_allocated_total()])
	_refresh_facility_panel()


## Temp allocation: decrement a facility's slot count (unstocked state).
func _on_temp_slot_minus(facility_id: String) -> void:
	var current: int = _temp_shop_allocations.get(facility_id, 0)
	if current <= 0:
		return
	_temp_shop_allocations[facility_id] = current - 1
	print("[Shop] temp_slot_minus facility=%s total=%d" % [facility_id, _get_temp_allocated_total()])
	_refresh_facility_panel()


## Commit temp allocations to GameContext, generate items.
func _on_stock_shop_pressed() -> void:
	var town_id = GameContext.get_current_town_id()
	var shop_id = _current_facility_id

	# Write temp allocations to GameContext
	for facility_id in _temp_shop_allocations:
		var slots: int = _temp_shop_allocations[facility_id]
		if slots > 0:
			GameContext.set_facility_slot_allocation(town_id, facility_id, slots)

	# Clear purchased slots for fresh stock (refresh count preserved for RNG seed)
	GameContext.clear_shop_purchased_slots(shop_id)
	GameContext.save_game()

	# Clear temp allocations
	_temp_shop_allocations = {}

	print("[Shop] Stocked shop=%s refresh=%d allocations=%s" % [shop_id, GameContext.get_shop_refresh_count(shop_id), GameContext.get_shop_slot_allocations(town_id)])
	UIAudio.play_sfx("facility_access")
	_refresh_facility_panel()


## Clear saved allocations and return to unstocked allocation state. Costs one refresh.
func _on_clear_and_reallocate_pressed() -> void:
	var town_id = GameContext.get_current_town_id()
	var shop_id = _current_facility_id

	# Spend a refresh (gold + increment count) to prevent bypass
	var success = GameContext.spend_shop_refresh(shop_id)
	if not success:
		_refresh_facility_panel()
		return

	# Clear all saved allocations for this town
	for facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		if not GameContext.shop_slot_allocations.has(town_id):
			break
		GameContext.shop_slot_allocations[town_id][facility_id] = 0

	# Clear purchased slots
	GameContext.clear_shop_purchased_slots(shop_id)
	GameContext.save_game()

	# Reset temp allocations
	_temp_shop_allocations = {}

	print("[Shop] Cleared allocations for re-allocation shop=%s refresh=%d" % [shop_id, GameContext.get_shop_refresh_count(shop_id)])
	_refresh_facility_panel()


## Handle shop sell button - opens sell items window.
func _on_shop_sell_pressed() -> void:
	_show_sell_window()


## Show sell items overlay (CanvasLayer pattern — Window.new() breaks in embedded scenes).
func _show_sell_window() -> void:
	if _sell_overlay != null and is_instance_valid(_sell_overlay):
		_sell_overlay.queue_free()

	_sell_overlay = CanvasLayer.new()
	_sell_overlay.layer = 10
	add_child(_sell_overlay)

	# Dark backdrop — click to close
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_sell_overlay()
	)
	_sell_overlay.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 400)
	var style = StyleBoxFlat.new()
	style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	style.set_border_width_all(2)
	style.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Sell Items"
	title.add_theme_font_size_override("font_size", GameContext.fs(18))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Gold display
	_sell_gold_label = Label.new()
	_sell_gold_label.text = "Current Gold: %d" % GameContext.get_run_gold()
	_sell_gold_label.modulate = Color(1, 0.9, 0.5, 1)
	vbox.add_child(_sell_gold_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Scroll container for items
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 300)
	vbox.add_child(scroll)

	_sell_items_container = VBoxContainer.new()
	_sell_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_items_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_sell_items_container)

	# Populate items
	_refresh_sell_overlay_items()

	# Close button at bottom
	var close_sep = HSeparator.new()
	vbox.add_child(close_sep)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.pressed.connect(_close_sell_overlay)
	vbox.add_child(close_btn)

	# Register with ESC-close stack
	UIAudio.register_closeable(_sell_overlay, _close_sell_overlay)


## Close the sell overlay and refresh the shop panel.
func _close_sell_overlay() -> void:
	if _sell_overlay != null and is_instance_valid(_sell_overlay):
		UIAudio.unregister_closeable(_sell_overlay)
		_sell_overlay.queue_free()
	_sell_overlay = null
	_sell_gold_label = null
	_sell_items_container = null
	_refresh_facility_panel()


## Refresh sell overlay item list after a sale.
func _refresh_sell_overlay_items() -> void:
	if _sell_items_container == null:
		return
	for child in _sell_items_container.get_children():
		child.queue_free()

	var sellable_items = _get_sellable_stash_items()
	if sellable_items.size() == 0:
		var no_items = Label.new()
		no_items.text = "(No items to sell)"
		no_items.modulate = Color(0.78, 0.78, 0.78, 1)
		_sell_items_container.add_child(no_items)
	else:
		for item in sellable_items:
			var row = _create_sell_overlay_row(item)
			_sell_items_container.add_child(row)


## Create a row for the sell overlay.
func _create_sell_overlay_row(item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var template_id: String = item.get("template_id", "")
	var qty: int = item.get("qty", 0)
	var quality_tier: int = item.get("quality_tier", 0)

	# Get display name (use pre-built from aggregation, fall back to template)
	var display_name: String = item.get("display_name", "")
	var template = DataRegistry.get_item_template(template_id)
	if display_name == "" and template != null:
		display_name = template.display_name
	if display_name == "":
		display_name = template_id

	# Quality prefix (only if not already in display_name from affix flow)
	var quality_prefix: String = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
	if quality_prefix != "" and not display_name.begins_with(quality_prefix):
		display_name = "%s %s" % [quality_prefix, display_name]

	# Calculate sell price
	var sell_price = 1
	if template != null:
		sell_price = template.get_sell_value()
		var quality_mult = [1.0, 1.1, 1.2, 1.35]
		sell_price = int(sell_price * quality_mult[quality_tier])

	# Item name and quantity
	var name_label = Label.new()
	name_label.text = "%s x%d" % [display_name, qty]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Quality color
	if quality_tier > 0:
		name_label.modulate = ItemInstance.QUALITY_COLORS[clampi(quality_tier, 0, 3)]
	row.add_child(name_label)

	# Price label
	var price_label = Label.new()
	price_label.text = "%dg ea" % sell_price
	price_label.modulate = Color(0.8, 0.8, 0.8, 1)
	row.add_child(price_label)

	# Sell 1 button
	var sell_one_btn = Button.new()
	sell_one_btn.text = "Sell 1"
	sell_one_btn.custom_minimum_size = Vector2(60, 26)
	sell_one_btn.pressed.connect(func():
		_do_sell_item(template_id, 1, quality_tier)
		if _sell_gold_label:
			_sell_gold_label.text = "Current Gold: %d" % GameContext.get_run_gold()
		_refresh_sell_overlay_items()
	)
	row.add_child(sell_one_btn)

	# Sell All button (if qty > 1)
	if qty > 1:
		var sell_all_btn = Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.custom_minimum_size = Vector2(70, 26)
		sell_all_btn.pressed.connect(func():
			_do_sell_item(template_id, qty, quality_tier)
			if _sell_gold_label:
				_sell_gold_label.text = "Current Gold: %d" % GameContext.get_run_gold()
			_refresh_sell_overlay_items()
		)
		row.add_child(sell_all_btn)

	return row


## Execute selling an item.
func _do_sell_item(template_id: String, qty: int, quality_tier: int) -> void:
	var template = DataRegistry.get_item_template(template_id)
	if template == null:
		return

	var sell_price: int = template.get_sell_value()
	# Books sell at 25% value (heavy discount)
	if "book" in template.tags:
		sell_price = int(sell_price * 0.25)
	var quality_mult: Array = [1.0, 1.1, 1.2, 1.35]
	sell_price = int(sell_price * quality_mult[clampi(quality_tier, 0, 3)])

	var gold_before: int = GameContext.get_run_gold()
	var removed: int = GameContext.remove_run_item_by_quality(template_id, quality_tier, qty)
	var total_gain: int = removed * sell_price
	GameContext.add_run_gold(total_gain)
	var gold_after: int = GameContext.get_run_gold()

	print("[Store] sell item=%s q%d qty=%d gain=%d gold_before=%d gold_after=%d" % [
		template_id, quality_tier, removed, total_gain, gold_before, gold_after])


## Generate equipment items based on facility slot allocations.
## Each allocated slot generates one item from that facility's unlocked recipes.
## Each facility gets its own seeded RNG to avoid cross-contamination when allocations change.
func _generate_facility_allocated_items(town_id: String, base_rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	var region_id: String = GameContext.get_current_region_id()
	var affix: Dictionary = DataRegistry.get_regional_affix(region_id)

	for facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var slots = GameContext.get_facility_slot_allocation(town_id, facility_id)
		if slots <= 0:
			continue

		# Get recipes for this facility — production facilities use discovered mixes
		var fac_data = DataRegistry.get_facility(facility_id)
		var recipes: Array
		if fac_data != null and fac_data.mixing_recipe_file != "":
			recipes = GameContext.get_facility_shop_recipes(facility_id)
		else:
			recipes = GameContext.get_facility_unlocked_recipes(facility_id)
		if recipes.is_empty():
			continue

		# Get current equipment facility tier for quality rolling and T3 price discount
		var current_equip_fac_tier: int = GameContext.get_facility_tier(town_id, facility_id)

		# Create a separate RNG for this facility so allocations don't affect other facilities
		var facility_seed = SeededRNG.derive_seed(facility_id, base_rng.seed)
		var facility_rng = RandomNumberGenerator.new()
		facility_rng.seed = facility_seed

		# Generate one item per allocated slot — each slot rolls independently
		for i in range(slots):
			var slot_key = "%s:%d" % [facility_id, i]

			# Each slot independently picks a recipe from the full pool
			var recipe_idx: int = facility_rng.randi() % recipes.size()
			var recipe_entry: Dictionary = recipes[recipe_idx]
			var item_id: String = recipe_entry.get("item_id", "")
			var upgrade_tier: int = int(recipe_entry.get("upgrade_tier", 1))
			var facility_tier: int = int(recipe_entry.get("facility_tier", 1))

			var template = DataRegistry.get_item_template(item_id)
			if template == null:
				continue

			# Roll quality based on current facility tier (seeded per facility)
			var quality_roll = facility_rng.randf() * 100.0
			var quality_tier = _roll_quality_seeded(quality_roll, current_equip_fac_tier)

			# Calculate price based on template value, quality, and affix
			var base_price = template.get_buy_value()
			var quality_mult = [1.0, 1.2, 1.5, 2.0]
			var affix_mult: float = 1.0 + (0.25 * (upgrade_tier - 1)) if upgrade_tier >= 2 else 1.0
			var final_price = int(base_price * quality_mult[quality_tier] * affix_mult)
			# T3+ equipment facility discount: 25% off
			if current_equip_fac_tier >= 3:
				final_price = int(final_price * 0.75)

			# Build affix_data for T2+ items
			var shop_affix: Dictionary = {}
			if upgrade_tier >= 2 and not affix.is_empty():
				shop_affix = {
					"source_region": region_id,
					"affix_id": region_id,
					"affix_stats": affix.get("stat_bonus", {}),
					"affix_prefix": affix.get("prefix", "")
				}

			result.append({
				"type": "item",
				"item_id": item_id,
				"price_gold": final_price,
				"quality_tier": quality_tier,
				"source_facility": facility_id,
				"slot_key": slot_key,
				"from_recipe": true,
				"upgrade_tier": upgrade_tier,
				"affix_data": shop_affix
			})

	# Sort by facility then item name for consistent display
	result.sort_custom(func(a, b):
		var fac_a = a.get("source_facility", "")
		var fac_b = b.get("source_facility", "")
		if fac_a != fac_b:
			return fac_a < fac_b
		var name_a = DataRegistry.get_item_template(a.get("item_id", ""))
		var name_b = DataRegistry.get_item_template(b.get("item_id", ""))
		var display_a = name_a.display_name if name_a else a.get("item_id", "")
		var display_b = name_b.display_name if name_b else b.get("item_id", "")
		return display_a < display_b
	)

	print("[ShopFacility] generated %d items from %d allocated slots" % [result.size(), GameContext.get_shop_allocated_slots(town_id)])
	return result


## Roll quality tier based on facility tier using a seeded roll value.
func _roll_quality_seeded(roll: float, facility_tier: int) -> int:
	match facility_tier:
		1:  # 100% Common
			return 0
		2:  # 75% Common, 20% Uncommon, 5% Rare
			if roll < 75.0: return 0
			elif roll < 95.0: return 1
			else: return 2
		3:  # Same as T2 (T3 benefit is price discount, not quality)
			if roll < 75.0: return 0
			elif roll < 95.0: return 1
			else: return 2
		4:  # 50% Common, 30% Uncommon, 15% Rare, 5% Epic
			if roll < 50.0: return 0
			elif roll < 80.0: return 1
			elif roll < 95.0: return 2
			else: return 3
		_:
			return 0  # Unknown tier = common


func _create_shop_row(shop_item: Dictionary, shop_id: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = shop_item.get("item_id", "")
	var price = shop_item.get("price_gold", 0)
	var quality_tier = int(shop_item.get("quality_tier", 0))
	var slot_key = shop_item.get("slot_key", "")
	var affix_data: Dictionary = shop_item.get("affix_data", {})
	var affix_prefix: String = affix_data.get("affix_prefix", "")

	# Get display name from template
	var display_name = item_id
	var template = DataRegistry.get_item_template(item_id) if DataRegistry.has_method("get_item_template") else null
	if template != null and template.display_name != "":
		display_name = template.display_name

	# Quality color from centralized constants
	var text_color: Color = Color.WHITE
	if quality_tier > 0:
		text_color = ItemInstance.QUALITY_COLORS[clampi(quality_tier, 0, 3)]

	# Build tooltip with item stats (include affix stats if present)
	var tooltip_text = _build_item_tooltip(template, quality_tier)
	if not affix_data.is_empty():
		var affix_stats: Dictionary = affix_data.get("affix_stats", {})
		if not affix_stats.is_empty():
			tooltip_text += "\nAffix: " + affix_prefix
			for stat_name in affix_stats:
				tooltip_text += "\n  +%d %s" % [affix_stats[stat_name], stat_name.capitalize()]

	# Item icon with quality border + name label
	if template != null:
		var icon_ctrl = template.create_bordered_icon(18, quality_tier)
		if icon_ctrl != null:
			row.add_child(icon_ctrl)

	# Build display name: [affix_prefix] [quality_prefix] base_name
	var name_label = Label.new()
	var quality_prefix: String = ""
	if quality_tier > 0:
		quality_prefix = ItemInstance.QUALITY_PREFIXES[clampi(quality_tier, 0, 3)]
	if affix_prefix != "":
		name_label.text = "%s %s%s" % [affix_prefix, quality_prefix, display_name]
	elif quality_prefix != "":
		name_label.text = "%s%s" % [quality_prefix, display_name]
	else:
		name_label.text = display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.modulate = text_color
	name_label.tooltip_text = tooltip_text
	name_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(name_label)

	# Compare button for equipment items (not bags/consumables/materials)
	if template != null and template.equip_slot != "" and template.equip_slot != "bag":
		var cmp_btn = Button.new()
		cmp_btn.text = "Compare"
		cmp_btn.custom_minimum_size = Vector2(70, 26)
		cmp_btn.tooltip_text = "Compare to party equipment"
		cmp_btn.pressed.connect(_on_shop_compare_pressed.bind(item_id, quality_tier, affix_data, price, shop_id, slot_key))
		row.add_child(cmp_btn)

	# Buy button with gold cost
	var can_afford = GameContext.get_run_gold() >= price
	var stash_full = not GameContext.can_add_to_stash(item_id)
	var btn = Button.new()
	btn.text = "%dg" % price
	btn.custom_minimum_size = Vector2(60, 26)
	btn.disabled = not can_afford or stash_full
	if stash_full and can_afford:
		btn.tooltip_text = "Stash full — sell items to make room"
	btn.pressed.connect(_on_shop_buy_pressed.bind(item_id, price, quality_tier, shop_id, slot_key, affix_data))
	row.add_child(btn)

	return row


## Create an empty slot row to show where a purchased item was.
func _create_empty_shop_slot_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var empty_label = Label.new()
	empty_label.text = "[Empty Slot]"
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_label.modulate = Color(0.65, 0.65, 0.65, 1)
	row.add_child(empty_label)

	# Placeholder for button alignment
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(60, 26)
	row.add_child(spacer)

	return row


## Build tooltip text showing item stats.
func _build_item_tooltip(template, quality_tier: int) -> String:
	if template == null:
		return ""

	var lines: Array[String] = []

	# Item name and type
	lines.append(template.display_name)
	if template.item_type != "":
		var type_str: String = template.item_type.capitalize()
		if template.item_subtype != "":
			type_str += " (%s)" % template.item_subtype.capitalize()
		lines.append(type_str)
	if template.description != "":
		lines.append(template.description)
	lines.append("")

	# Consumable effect (heal amount, buff, cure, etc.)
	var effect_label: String = template.get_effect_label()
	if effect_label != "":
		lines.append(effect_label)
		if template.is_refillable:
			lines.append("Refillable (cooldown: %d turns)" % template.use_cooldown)
		lines.append("")

	# Equipment slot
	var slot = template.equip_slot if template.equip_slot != "" else template.slot
	if slot != "":
		lines.append("Slot: %s" % slot.capitalize())

	# Quality multiplier
	var quality_mults = [1.0, 1.1, 1.2, 1.35]
	var quality_name = ItemInstance.QUALITY_NAMES[clampi(quality_tier, 0, 3)]
	var quality_mult = quality_mults[quality_tier] if quality_tier < quality_mults.size() else 1.0
	lines.append("Quality: %s (x%.2f stats)" % [quality_name, quality_mult])
	lines.append("")

	# Stats with quality scaling
	var base_stats = template.base_stats if template.base_stats != null else {}
	var stat_bonuses = template.stat_bonuses if template.stat_bonuses != null else {}

	# Combine base_stats and stat_bonuses (they often contain the same data)
	var all_stats = {}
	for key in base_stats.keys():
		all_stats[key] = base_stats[key]
	for key in stat_bonuses.keys():
		if not all_stats.has(key):
			all_stats[key] = stat_bonuses[key]

	if all_stats.size() > 0:
		lines.append("Stats:")
		for stat_name in all_stats.keys():
			var base_value = int(all_stats[stat_name])
			var scaled_value = int(base_value * quality_mult)
			lines.append("  +%d %s" % [scaled_value, stat_name.capitalize()])

	return "\n".join(lines)


func _on_shop_buy_pressed(item_id: String, price: int, quality_tier: int = 0, shop_id: String = "", slot_key: String = "", affix_data: Dictionary = {}) -> void:
	# Check stash capacity before purchasing
	if not GameContext.can_add_to_stash(item_id):
		print("[Store] buy item=%s BLOCKED — stash full (%d/%d slots)" % [item_id, GameContext.get_current_stash_count(), GameContext.get_max_stash_capacity()])
		UIAudio.play_sfx("error_insufficient")
		_refresh_facility_panel()
		return

	var had_gold = GameContext.get_run_gold()
	if had_gold < price:
		print("[Store] buy item=%s qty=1 cost=%d gold_before=%d gold_after=FAIL (insufficient)" % [item_id, price, had_gold])
		UIAudio.play_sfx("error_insufficient")
		return

	GameContext.spend_run_gold(price)
	UIAudio.play_sfx("item_buy")

	# Add item with quality tier and affix data
	if quality_tier > 0 or not affix_data.is_empty():
		GameContext._add_item_with_quality(item_id, quality_tier, affix_data)
	else:
		GameContext.add_run_item(item_id, 1)

	# Mark the slot as purchased so it shows as empty
	if shop_id != "" and slot_key != "":
		GameContext.mark_shop_slot_purchased(shop_id, slot_key)

	var affix_str: String = affix_data.get("affix_prefix", "") if not affix_data.is_empty() else ""
	print("[Store] buy item=%s qty=1 q=%d affix=%s cost=%d gold_before=%d gold_after=%d slot=%s" % [item_id, quality_tier, affix_str, price, had_gold, GameContext.get_run_gold(), slot_key])
	_refresh_facility_panel()


## Show a comparison panel for a shop item vs each party hero's equipped item in the same slot.
## Uses the same draggable/resizable facility panel pattern as other town panels.
func _on_shop_compare_pressed(item_id: String, quality_tier: int, affix_data: Dictionary, price: int = 0, shop_id: String = "", slot_key: String = "") -> void:
	# Close any existing compare panel first
	if _open_panels.has("shop_compare"):
		_on_close_facility_panel("shop_compare")

	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return
	var equip_slot: String = template.equip_slot
	if equip_slot == "" or equip_slot == "bag":
		return

	var region_bonus: float = GameContext.get_completed_region_count() * 0.1
	# Shop item stats (template + affix)
	var shop_stats: Dictionary = template.get_stat_bonuses_with_quality(quality_tier, region_bonus)
	var shop_affix_stats: Dictionary = affix_data.get("affix_stats", {}) if affix_data is Dictionary else {}
	for ak in shop_affix_stats:
		shop_stats[ak] = shop_stats.get(ak, 0) + int(shop_affix_stats[ak])

	# Build display name
	var affix_prefix: String = affix_data.get("affix_prefix", "") if affix_data is Dictionary else ""
	var quality_prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quality_tier, 0, 3)]
	var shop_display: String = ""
	if affix_prefix != "":
		shop_display = "%s %s%s" % [affix_prefix, quality_prefix, template.display_name]
	elif quality_prefix != "":
		shop_display = "%s%s" % [quality_prefix, template.display_name]
	else:
		shop_display = template.display_name

	# Build stat summary text
	var shop_stat_parts: Array = []
	for sk in CombatUnit.STAT_KEYS:
		var sv: int = int(shop_stats.get(sk, 0))
		if sv > 0:
			shop_stat_parts.append("%s +%d" % [CombatUnit.STAT_ABBREV.get(sk, sk), sv])
	var shop_stat_text: String = "  ".join(shop_stat_parts) if shop_stat_parts.size() > 0 else "(no stats)"

	# --- Create facility-style panel ---
	var panel = PanelContainer.new()
	panel.name = "FacilityPanel_shop_compare"
	var panel_size: Vector2 = _panel_sizes.get("shop_compare", Vector2(480, 500))
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	panel_size.x = mini(int(panel_size.x), int(vp_size.x * 0.85))
	panel_size.y = mini(int(panel_size.y), int(vp_size.y * 0.85))
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Theme
	if use_craftpix_skin:
		panel.theme = _CRAFTPIX_THEME
	else:
		panel.theme = preload("res://Themes/game_theme.tres")

	# Panel styling (solid background)
	var panel_body_style = StyleBoxFlat.new()
	panel_body_style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	panel_body_style.border_color = _region_palette.get("border", Color(0.35, 0.30, 0.22, 0.8))
	panel_body_style.set_border_width_all(1)
	panel_body_style.set_corner_radius_all(4)
	panel_body_style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", panel_body_style)

	# Stagger position
	var offset_idx: int = _open_panels.size()
	panel.position = Vector2(80 + offset_idx * 30, 40 + offset_idx * 30)

	# Main content VBox
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	panel.add_child(main_vbox)

	# --- Title bar (drag handle) ---
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = _region_palette.get("title_bar", Color(0.18, 0.22, 0.3, 0.9))
	title_style.content_margin_left = 8
	title_style.content_margin_top = 4
	title_style.content_margin_right = 4
	title_style.content_margin_bottom = 4
	title_style.set_corner_radius_all(2)

	var title_panel = PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", title_style)
	title_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(title_panel)

	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 4)
	title_panel.add_child(title_hbox)

	var title_label = Label.new()
	title_label.text = "Compare: %s" % shop_display
	title_label.add_theme_font_size_override("font_size", GameContext.fs(16))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(title_label)

	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % GameContext.get_run_gold()
	gold_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hbox.add_child(gold_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_on_close_facility_panel.bind("shop_compare"))
	title_hbox.add_child(close_btn)

	# Drag + resize input
	panel.gui_input.connect(_on_panel_gui_input.bind(panel, "shop_compare"))

	# --- Scroll content ---
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(content_vbox)

	# Slot + quality + stats header
	var slot_label = Label.new()
	var q_names: Array = ["Common", "Uncommon", "Rare", "Epic"]
	slot_label.text = "Slot: %s | %s (Q%d) | %dg" % [equip_slot.capitalize(), q_names[clampi(quality_tier, 0, 3)], quality_tier, price]
	slot_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	slot_label.modulate = Color(0.7, 0.7, 0.9)
	content_vbox.add_child(slot_label)

	var stats_label = Label.new()
	stats_label.text = shop_stat_text
	stats_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	stats_label.modulate = Color(0.9, 0.85, 0.7)
	content_vbox.add_child(stats_label)

	var sep = HSeparator.new()
	content_vbox.add_child(sep)

	# Per-hero comparison with Buy & Equip buttons
	var party: Array = GameContext.get_selected_party()
	var can_afford: bool = GameContext.get_run_gold() >= price
	if party.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(No heroes in party)"
		empty_label.modulate = Color(0.6, 0.6, 0.6)
		content_vbox.add_child(empty_label)
	else:
		for hero_id in party:
			var hero: Dictionary = GameContext.get_hero(hero_id)
			if hero.is_empty():
				continue
			var hero_name: String = hero.get("name", hero_id)
			var hero_class: String = hero.get("class_id", "").capitalize()

			var hero_vbox = VBoxContainer.new()
			hero_vbox.add_theme_constant_override("separation", 2)

			# Hero name + class row with Buy & Equip button
			var hero_row = HBoxContainer.new()
			hero_row.add_theme_constant_override("separation", 8)

			var hero_label = Label.new()
			hero_label.text = "%s (%s)" % [hero_name, hero_class]
			hero_label.add_theme_font_size_override("font_size", GameContext.fs(15))
			hero_label.modulate = Color(0.85, 0.9, 1.0)
			hero_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hero_row.add_child(hero_label)

			# Check weapon_types compatibility for weapons/offhand
			var can_equip: bool = true
			if equip_slot == "weapon":
				var class_data = DataRegistry.get_class_data(hero.get("class_id", ""))
				if class_data != null and class_data.weapon_types.size() > 0:
					if template.item_subtype not in class_data.weapon_types:
						can_equip = false

			var buy_equip_btn = Button.new()
			buy_equip_btn.text = "Buy & Equip (%dg)" % price
			buy_equip_btn.custom_minimum_size = Vector2(140, 26)
			buy_equip_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
			if not can_afford:
				buy_equip_btn.disabled = true
				buy_equip_btn.tooltip_text = "Not enough gold"
			elif not can_equip:
				buy_equip_btn.disabled = true
				buy_equip_btn.tooltip_text = "Cannot equip this weapon type"
			else:
				buy_equip_btn.pressed.connect(_on_shop_buy_and_equip.bind(
					hero_id, equip_slot, item_id, quality_tier, affix_data, price, shop_id, slot_key))
			hero_row.add_child(buy_equip_btn)
			hero_vbox.add_child(hero_row)

			# Currently equipped item in this slot
			var current_id: String = GameContext.get_hero_slot_item(hero_id, equip_slot)
			var current_quality: int = GameContext.get_hero_slot_quality(hero_id, equip_slot)
			var current_stats: Dictionary = {}

			var equip_label = Label.new()
			equip_label.add_theme_font_size_override("font_size", GameContext.fs(13))
			if current_id != "":
				var current_tpl = DataRegistry.get_item_template(current_id)
				if current_tpl != null:
					current_stats = current_tpl.get_stat_bonuses_with_quality(current_quality, region_bonus)
				var hero_equip: Dictionary = GameContext.get_hero_equipment(hero_id)
				var current_slot_data: Dictionary = hero_equip.get(equip_slot, {})
				var current_affix: Dictionary = current_slot_data.get("affix_stats", {})
				if current_affix is Dictionary:
					for cak in current_affix:
						current_stats[cak] = current_stats.get(cak, 0) + int(current_affix[cak])
				var current_bonus_lines: Array = current_slot_data.get("bonus_stat_lines", [])
				for line in current_bonus_lines:
					var line_stat: String = line.get("stat", "")
					var line_val: int = int(line.get("value", 0))
					if line_stat != "":
						current_stats[line_stat] = current_stats.get(line_stat, 0) + line_val

				var cur_prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(current_quality, 0, 3)]
				var cur_affix_prefix: String = current_slot_data.get("affix_prefix", "")
				var cur_display: String = ""
				if cur_affix_prefix != "":
					cur_display = "%s %s%s" % [cur_affix_prefix, cur_prefix, current_tpl.display_name if current_tpl else current_id]
				else:
					cur_display = "%s%s" % [cur_prefix, current_tpl.display_name if current_tpl else current_id]
				equip_label.text = "  Equipped: %s" % cur_display
				equip_label.modulate = Color(0.65, 0.65, 0.65)
			else:
				equip_label.text = "  Equipped: (empty)"
				equip_label.modulate = Color(0.5, 0.5, 0.5)
			hero_vbox.add_child(equip_label)

			# Delta comparison
			var compare_label = Label.new()
			compare_label.add_theme_font_size_override("font_size", GameContext.fs(14))
			var delta_parts: Array = []
			var total_delta: int = 0
			for sk in CombatUnit.STAT_KEYS:
				var new_val: int = int(shop_stats.get(sk, 0))
				var old_val: int = int(current_stats.get(sk, 0))
				var delta: int = new_val - old_val
				if delta != 0:
					var sign_str: String = "+" if delta > 0 else ""
					delta_parts.append("%s %s%d" % [CombatUnit.STAT_ABBREV.get(sk, sk), sign_str, delta])
				total_delta += delta

			if delta_parts.size() > 0:
				compare_label.text = "  %s" % "  ".join(delta_parts)
				if total_delta > 0:
					compare_label.modulate = Color(0.5, 1, 0.5)
				elif total_delta < 0:
					compare_label.modulate = Color(1, 0.5, 0.5)
				else:
					compare_label.modulate = Color(0.8, 0.8, 0.8)
			else:
				compare_label.text = "  (no stat change)"
				compare_label.modulate = Color(0.78, 0.78, 0.78)
			hero_vbox.add_child(compare_label)

			content_vbox.add_child(hero_vbox)

	# Add panel to facility overlay and register
	_facility_overlay.add_child(panel)
	var accent_overlay = _create_accent_overlay(panel, "shop_compare")
	_open_panels["shop_compare"] = {
		"panel": panel,
		"title_label": title_label,
		"gold_label": gold_label,
		"actions_container": content_vbox,
		"accent_overlay": accent_overlay,
	}
	UIAudio.register_closeable(panel, _on_close_facility_panel.bind("shop_compare"))


## Buy a shop item and immediately equip it on a hero. Old item returns to stash automatically.
func _on_shop_buy_and_equip(hero_id: String, slot: String, item_id: String, quality_tier: int, affix_data: Dictionary, price: int, shop_id: String, slot_key: String) -> void:
	# Check gold
	if GameContext.get_run_gold() < price:
		UIAudio.play_sfx("error_insufficient")
		return

	# Spend gold and add item to stash
	GameContext.spend_run_gold(price)
	UIAudio.play_sfx("item_buy")
	if quality_tier > 0 or not affix_data.is_empty():
		GameContext._add_item_with_quality(item_id, quality_tier, affix_data)
	else:
		GameContext.add_run_item(item_id, 1)

	# Mark shop slot as purchased
	if shop_id != "" and slot_key != "":
		GameContext.mark_shop_slot_purchased(shop_id, slot_key)

	# Equip (unequips old item to stash, removes new from stash)
	var equipped: bool = GameContext.equip_hero_item(hero_id, slot, item_id, quality_tier, affix_data)
	if equipped:
		print("[Shop] Buy & Equip item=%s q=%d hero=%s slot=%s cost=%d" % [item_id, quality_tier, hero_id, slot, price])
	else:
		print("[Shop] Buy & Equip FAILED equip step item=%s hero=%s slot=%s" % [item_id, hero_id, slot])

	# Close compare panel and refresh shop
	_on_close_facility_panel("shop_compare")
	_refresh_facility_panel()


## Get sellable items from run stash (excludes books for now).
func _get_sellable_stash_items() -> Array:
	var result: Array = []
	var aggregated: Dictionary = {}

	for item in GameContext.run_items:
		var template_id := ""
		var quality_tier := 0
		var display_name := ""
		var qty := 1

		if item is ItemInstance:
			template_id = item.template_id
			quality_tier = item.quality_tier
			display_name = item.display_name
			qty = item.quantity
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
			quality_tier = int(item.get("quality_tier", 0))
			var tpl = DataRegistry.get_item_template(template_id)
			if tpl != null:
				var prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quality_tier, 0, 3)]
				display_name = prefix + tpl.display_name
			else:
				display_name = template_id
		else:
			continue

		# Books are sellable at reduced price (handled in _do_sell_item)

		var key = "%s:%d" % [template_id, quality_tier]
		if aggregated.has(key):
			aggregated[key].qty += qty
		else:
			var category = _get_item_category(template_id)
			aggregated[key] = {
				"template_id": template_id,
				"quality_tier": quality_tier,
				"qty": qty,
				"display_name": display_name,
				"category": category
			}

	for key in aggregated.keys():
		result.append(aggregated[key])

	# Sort by category: materials first, then equipment, then consumables
	result.sort_custom(_sort_stash_items_by_category)

	return result


## Create a row for selling an item.
func _create_sell_item_row(item: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var template_id = item.template_id
	var qty = item.qty
	var quality_tier = item.quality_tier
	var display_name = item.display_name

	# Get sell price from template with quality multiplier
	var sell_price: int = 1  # Minimum fallback
	var base_price: int = 1
	var quality_mult: float = 1.0
	var tpl = DataRegistry.get_item_template(template_id)
	if tpl != null:
		base_price = tpl.base_value
		# Books sell at 25% value (heavy discount)
		if "book" in tpl.tags:
			base_price = int(base_price * 0.25)
		# Apply quality multiplier for equipment (same as ItemTemplate.QUALITY_MULTIPLIERS)
		if tpl.equip_slot != "" and quality_tier > 0:
			var quality_mults = [1.0, 1.1, 1.2, 1.35]
			var q_idx = clampi(quality_tier, 0, quality_mults.size() - 1)
			quality_mult = quality_mults[q_idx]
		sell_price = int(base_price * quality_mult)
		# Debug logging (rate-limited by only logging when creating UI row)
		if quality_tier > 0:
			print("[Economy] sell_price item=%s q=%d base=%d mult=%.2f final=%d" % [template_id, quality_tier, base_price, quality_mult, sell_price])

	# Quality prefix if applicable
	var q_prefix = ""
	if quality_tier > 0:
		q_prefix = "[Q%d] " % quality_tier

	# Item label
	var label = Label.new()
	label.text = "%s%s x%d" % [q_prefix, display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Price label
	var price_label = Label.new()
	price_label.text = "%dg ea" % sell_price
	price_label.modulate = Color(0.8, 0.8, 0.5, 1)
	row.add_child(price_label)

	# Sell 1 button
	var sell_btn = Button.new()
	sell_btn.text = "Sell 1"
	sell_btn.custom_minimum_size = Vector2(60, 24)
	sell_btn.pressed.connect(_on_sell_item_pressed.bind(template_id, 1, sell_price))
	row.add_child(sell_btn)

	# Sell All button (if qty > 1)
	if qty > 1:
		var sell_all_btn = Button.new()
		sell_all_btn.text = "Sell All"
		sell_all_btn.custom_minimum_size = Vector2(70, 24)
		sell_all_btn.pressed.connect(_on_sell_item_pressed.bind(template_id, qty, sell_price))
		row.add_child(sell_all_btn)

	return row


## Handle sell item button press.
func _on_sell_item_pressed(template_id: String, qty: int, unit_price: int) -> void:
	var gold_before = GameContext.get_run_gold()
	var total_gain = unit_price * qty

	# Remove items from stash
	var removed = GameContext.remove_run_item(template_id, qty)
	if removed == 0:
		print("[Store] sell item=%s qty=%d gain=0 gold_before=%d gold_after=FAIL (no items)" % [template_id, qty, gold_before])
		_refresh_facility_panel()
		return

	# Add gold
	GameContext.add_run_gold(total_gain)
	UIAudio.play_sfx("item_sell")
	var gold_after = GameContext.get_run_gold()

	print("[Store] sell item=%s qty=%d gain=%d gold_before=%d gold_after=%d" % [template_id, removed, total_gain, gold_before, gold_after])
	GameContext.save_game()
	_refresh_facility_panel()


func _create_stash_upgrade_row(upgrade: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var upgrade_id = upgrade.get("upgrade_id", "")
	var display_name = upgrade.get("display_name", upgrade_id)
	var price = upgrade.get("price_gold", 0)
	var bonus_value = upgrade.get("bonus_value", 0)
	var is_purchased = GameContext.has_housing_upgrade(upgrade_id)
	var can_afford = GameContext.get_run_gold() >= price

	# Upgrade label
	var label = Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_purchased:
		label.text = "%s (Owned)" % display_name
		label.modulate = Color(0.5, 1, 0.5, 1)
	else:
		label.text = "%s (%d gold)" % [display_name, price]
	row.add_child(label)

	# Purchase button
	if not is_purchased:
		var btn = Button.new()
		btn.text = "Buy"
		btn.custom_minimum_size = Vector2(60, 26)
		btn.disabled = not can_afford
		btn.pressed.connect(_on_stash_upgrade_pressed.bind(upgrade_id, price, bonus_value))
		row.add_child(btn)

	return row


func _on_stash_upgrade_pressed(upgrade_id: String, price: int, bonus_value: int) -> void:
	if GameContext.purchase_housing_upgrade(upgrade_id, price, "stash_capacity", bonus_value):
		print("[Shop] stash_upgrade=%s cost=%d bonus=%d success=true" % [upgrade_id, price, bonus_value])
	_refresh_facility_panel()


# ============================================================================
# EQUIPMENT FACILITY UI (Blacksmith, Huntsman, Enchanter - Per-Recipe Unlocking)
# ============================================================================

func _build_equipment_ui() -> void:
	if _current_facility == null:
		return

	var facility = _current_facility
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# NPC header: portrait + greeting + menu options
	var menu = [
		{"view": "recipes", "label": "Recipes"},
		{"view": "upgrade", "label": "Upgrade Facility"},
	]
	_build_npc_header(facility, menu, _equipment_view, _on_equipment_view_pressed)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Dispatch to selected view
	match _equipment_view:
		"recipes":
			_build_equipment_recipes_view(facility, current_tier)
		"upgrade":
			_build_equipment_upgrade_view(facility, current_tier)
		"repair":
			_build_equipment_repair_view(facility)

	print("[EquipmentUI] facility=%s tier=%d view=%s" % [facility_id, current_tier, _equipment_view])


## Generic NPC header: portrait (48x48) on left, greeting + menu options on right.
## menu_options: Array of {"view": String, "label": String}
## current_view: the currently selected view string (for highlighting)
## view_handler: Callable that takes a view string (e.g., _on_equipment_view_pressed)
func _build_npc_header(facility, menu_options: Array, current_view: String, view_handler: Callable) -> void:
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 10)
	_facility_actions_container.add_child(header_hbox)

	# Portrait — fixed 64x64 to prevent feedback loop with HBox height
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(64, 64)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if facility.keeper_portrait != "":
		var tex = load(facility.keeper_portrait)
		if tex != null:
			portrait_rect.texture = tex
	header_hbox.add_child(portrait_rect)

	# Right side: greeting + menu
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 4)
	header_hbox.add_child(right_vbox)

	# Greeting label (persisted across view switches, reset on panel open)
	if _facility_greeting == "":
		if facility.keeper_greetings.size() > 0:
			var idx = randi() % facility.keeper_greetings.size()
			_facility_greeting = facility.keeper_greetings[idx]
		else:
			_facility_greeting = "Welcome, ShopKeeper."

	var greeting_label = Label.new()
	greeting_label.text = "\"%s\"" % _facility_greeting
	greeting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greeting_label.add_theme_font_size_override("font_size", GameContext.fs(16))
	greeting_label.modulate = Color(1.0, 0.95, 0.8, 1)
	right_vbox.add_child(greeting_label)

	# Menu option buttons (styled as text-like items with > prefix)
	for opt in menu_options:
		var btn = Button.new()
		var is_selected: bool = (current_view == opt.view)
		btn.text = "> %s" % opt.label if is_selected else "  %s" % opt.label
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 24)
		btn.add_theme_font_size_override("font_size", GameContext.fs(15))
		if is_selected:
			_apply_selected_button_style(btn)
		elif _highlight_roster_tab and opt.view == "roster":
			btn.text = "  %s  *NEW*" % opt.label
			btn.modulate = Color(1.0, 0.85, 0.2, 1)  # gold highlight
		else:
			btn.modulate = Color(0.75, 0.75, 0.75, 1)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(view_handler.bind(opt.view))
		right_vbox.add_child(btn)


## Recipes view: type filter tabs + recipe list
func _build_equipment_recipes_view(facility, current_tier: int) -> void:
	var facility_id = facility.facility_id

	# Pre-compute which equipment types have visible recipes (non-tier-locked, current region)
	var available_types: Dictionary = {}  # equipment_type -> count
	var current_region: String = GameContext.get_current_region_id()
	for recipe in facility.crafting_recipes:
		var required_tier = recipe.get("required_tier", 1)
		if required_tier > current_tier:
			continue  # tier-locked recipes are hidden
		var recipe_region: String = recipe.get("region", "")
		if recipe_region != "" and recipe_region != current_region:
			continue  # wrong region
		var etype = recipe.get("equipment_type", "")
		available_types[etype] = available_types.get(etype, 0) + 1

	# Equipment type filter buttons
	var filter_row1 = HBoxContainer.new()
	filter_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row1.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row1)

	var filter_row2 = HBoxContainer.new()
	filter_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row2.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(filter_row2)

	var filters_row1 = ["all", "1h_weapon", "2h_weapon", "offhand"]
	var filters_row2 = ["helmet", "armor", "legs", "accessory", "backpack"]
	var filter_labels = {
		"all": "All",
		"1h_weapon": "1H Weps",
		"2h_weapon": "2H Weps",
		"offhand": "Off Hand",
		"helmet": "Helm",
		"armor": "Body",
		"legs": "Legs",
		"accessory": "Accessory",
		"backpack": "Backpack"
	}

	for f in filters_row1:
		var btn = Button.new()
		btn.text = filter_labels.get(f, f.capitalize())
		btn.custom_minimum_size = Vector2(70, 24)
		var has_recipes: bool = (f == "all" and available_types.size() > 0) or available_types.has(f)
		if _equipment_type_filter == f:
			_apply_selected_button_style(btn)
		elif not has_recipes:
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.7, 0.85)
		btn.pressed.connect(_on_equipment_filter_pressed.bind(f))
		filter_row1.add_child(btn)

	for f in filters_row2:
		var btn = Button.new()
		btn.text = filter_labels.get(f, f.capitalize())
		btn.custom_minimum_size = Vector2(70, 24)
		var has_recipes: bool = available_types.has(f)
		if _equipment_type_filter == f:
			_apply_selected_button_style(btn)
		elif not has_recipes:
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.7, 0.85)
		btn.pressed.connect(_on_equipment_filter_pressed.bind(f))
		filter_row2.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Get and filter recipes
	var recipes = _get_filtered_equipment_recipes(facility, current_tier, facility_id)

	# Recipe count
	var count_label = Label.new()
	count_label.text = "Showing %d recipes" % recipes.size()
	count_label.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(count_label)

	if recipes.size() == 0:
		var no_recipes = Label.new()
		no_recipes.text = "(No recipes match current filters)"
		no_recipes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_recipes)
	else:
		for recipe in recipes:
			var recipe_row = _create_equipment_recipe_row(recipe, facility_id, current_tier)
			_facility_actions_container.add_child(recipe_row)


## Upgrade view: tier tabs + cost/benefits for selected tier
func _build_equipment_upgrade_view(facility, current_tier: int) -> void:
	var max_tier = facility.max_tier
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			# Color coding: green for unlocked, normal for available, gray for locked
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)

		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Content for selected tier
	var selected_tier = _upgrade_tier_tab

	if selected_tier <= current_tier:
		# Already unlocked tier
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Unlocked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		# Show what this tier provides
		_build_tier_benefits_display(facility, selected_tier, current_tier)

	elif selected_tier == current_tier + 1:
		# Next tier — available for purchase
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		# Show cost
		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

		var sep2 = HSeparator.new()
		_facility_actions_container.add_child(sep2)

		# Show what it will unlock
		_build_tier_benefits_display(facility, selected_tier, current_tier)

	else:
		# Locked — requires earlier tier first
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)


## Display benefits/contents of a specific tier (services, recipes, slots)
func _build_tier_benefits_display(facility, tier: int, current_tier: int) -> void:
	# Show real mechanical benefits based on facility type
	var benefits: Array[String] = _get_tier_benefits(facility, tier)
	for benefit_text in benefits:
		var blabel = Label.new()
		blabel.text = benefit_text
		blabel.add_theme_font_size_override("font_size", GameContext.fs(14))
		blabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(blabel)

	# Recipes available at this tier (filtered by current region)
	var current_region: String = GameContext.get_current_region_id()
	var tier_recipes: Array = []
	for recipe in facility.crafting_recipes:
		if recipe.get("required_tier", 1) != tier:
			continue
		var recipe_region: String = recipe.get("region", "")
		if recipe_region != "" and recipe_region != current_region:
			continue
		tier_recipes.append(recipe)

	if tier_recipes.size() > 0:
		var recipe_header = Label.new()
		recipe_header.text = "Available Recipes (%d)" % tier_recipes.size()
		recipe_header.add_theme_font_size_override("font_size", GameContext.fs(14))
		recipe_header.modulate = Color(0.7, 0.85, 0.7, 1)
		_facility_actions_container.add_child(recipe_header)

		var grid = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 4)
		_facility_actions_container.add_child(grid)

		for recipe in tier_recipes:
			var output_id = recipe.get("output_id", "")
			var equipment_type = recipe.get("equipment_type", "")
			var output_template = DataRegistry.get_item_template(output_id)
			var output_name: String = output_id
			if output_template != null and output_template.display_name != "":
				output_name = output_template.display_name

			var type_str = _get_equipment_type_label(equipment_type)

			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			if output_template != null:
				var icon_rect = output_template.create_icon_rect(16)
				if icon_rect != null:
					row.add_child(icon_rect)

			var rlabel = Label.new()
			rlabel.text = "%s (%s)" % [output_name, type_str]
			rlabel.add_theme_font_size_override("font_size", GameContext.fs(14))
			if tier <= current_tier:
				var is_unlocked = GameContext.is_recipe_unlocked(output_id)
				rlabel.modulate = Color(0.5, 0.9, 0.5, 1) if is_unlocked else Color(0.8, 0.8, 0.8, 1)
			else:
				rlabel.modulate = Color(0.78, 0.78, 0.78, 1)
			row.add_child(rlabel)
			grid.add_child(row)


## Get real mechanical benefit descriptions for a facility tier.
func _get_tier_benefits(facility, tier: int) -> Array[String]:
	var benefits: Array[String] = []
	var ftype: String = facility.facility_type

	match ftype:
		"storage":
			var capacity: int = GameContext.STASH_BASE_CAPACITY + tier * GameContext.STASH_CAPACITY_PER_STORAGE_TIER
			benefits.append("Stash Capacity: %d items" % capacity)
		"inn":
			# Recruit level
			var recruit_lvl_data: Dictionary = facility.recruit_level_by_tier
			var recruit_lvl: int = recruit_lvl_data.get(str(tier), recruit_lvl_data.get(tier, 1))
			benefits.append("Recruit Level: %d" % recruit_lvl)
			# Party size
			var party_size: int = GameContext.PARTY_SIZE_BY_INN_TIER.get(tier, 4)
			benefits.append("Party Size: %d" % party_size)
			# Race/class access
			if tier >= 2:
				benefits.append("Races: All unlocked races available")
				benefits.append("Classes: Region-native only")
				benefits.append("Recruits start with equipment")
			else:
				benefits.append("Races: Region-native only")
				benefits.append("Classes: Region-native only")
		"training_hall":
			# Book slots
			var slots: int = facility.get_slots_for_tier(tier)
			if slots > 0:
				benefits.append("Book Slots: %d" % slots)
			# XP bonus
			var xp_pct: int = tier * 2
			benefits.append("XP Bonus: +%d%% (global, per hall)" % xp_pct)
			# Book discount
			if tier >= 3:
				benefits.append("Class Book Discount: 50%")
		"shop":
			# Shop item slots
			var shop_slots: int = GameContext.SHOP_TIER_MAX_SLOTS.get(tier, 4)
			benefits.append("Shop Slots: %d items" % shop_slots)
			# Refresh limit
			var refresh_limit: int = GameContext.SHOP_REFRESH_LIMIT_BY_TIER.get(tier, 1)
			benefits.append("Shop Refreshes: %d per visit" % refresh_limit)
			# Quality distribution
			match tier:
				1: benefits.append("Item Quality: Common only")
				2: benefits.append("Item Quality: Common, Uncommon & Rare")
				3: benefits.append("Item Quality: Common, Uncommon & Rare")
				4: benefits.append("Item Quality: up to Epic")
		"equipment":
			# Crafting slots
			var slots: int = facility.get_slots_for_tier(tier)
			if slots > 0:
				benefits.append("Crafting Slots: %d" % slots)
			# Quality distribution for shop items
			match tier:
				1: benefits.append("Shop Items: Common quality only")
				2: benefits.append("Shop Items: Common, Uncommon & Rare quality")
				3:
					benefits.append("Shop Items: Common, Uncommon & Rare quality")
					benefits.append("Recipe Discount: 25%")
				4: benefits.append("Shop Items: up to Epic quality")
		"production":
			# Mixing/crafting slots
			var slots: int = facility.get_slots_for_tier(tier)
			if slots > 0:
				benefits.append("Crafting Slots: %d" % slots)

	return benefits


## Repair view: placeholder for future implementation
func _build_equipment_repair_view(facility) -> void:
	var keeper_name: String = facility.keeper_name if facility.keeper_name != "" else "The keeper"

	var placeholder = Label.new()
	placeholder.text = "Repair is not yet implemented.\nComing in a future update!"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	placeholder.add_theme_font_size_override("font_size", GameContext.fs(15))
	placeholder.modulate = Color(0.78, 0.78, 0.78, 1)
	_facility_actions_container.add_child(placeholder)

	var flavor = Label.new()
	flavor.text = "\"%s looks at you expectantly, hammer in hand...\"" % keeper_name
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.add_theme_font_size_override("font_size", GameContext.fs(13))
	flavor.modulate = Color(0.72, 0.72, 0.6, 1)
	_facility_actions_container.add_child(flavor)


func _get_filtered_equipment_recipes(facility, current_tier: int, facility_id: String = "") -> Array:
	var all_recipes = facility.crafting_recipes
	var filtered: Array = []

	var current_region: String = GameContext.get_current_region_id()

	for recipe in all_recipes:
		var output_id = recipe.get("output_id", "")
		var required_tier = recipe.get("required_tier", 1)
		var equipment_type = recipe.get("equipment_type", "")
		var upgrade_tier: int = int(recipe.get("upgrade_tier", 1))
		var is_craft: bool = recipe.get("is_craft", false)

		# Region-specific recipes — skip if wrong region
		var recipe_region: String = recipe.get("region", "")
		if recipe_region != "" and recipe_region != current_region:
			continue

		# Check unlock state using compound key
		var is_unlocked: bool = GameContext.is_recipe_unlocked(output_id, upgrade_tier)
		var is_tier_locked: bool = required_tier > current_tier

		# Check if this recipe's output has been superseded by a higher-tier unlock
		var replaces: String = recipe.get("replaces", "")

		# Auto-unlock T3/T4 craft recipes for shop pool when facility tier is met
		if is_craft and upgrade_tier >= 3 and not is_unlocked and not is_tier_locked:
			GameContext.unlock_recipe(output_id, facility_id, current_tier, upgrade_tier, replaces)
			is_unlocked = true
		var is_superseded: bool = false
		if upgrade_tier <= 2 and not is_craft:
			# Check if a higher upgrade_tier recipe for this item is unlocked
			for check_tier in range(upgrade_tier + 1, 4):
				if GameContext.is_recipe_unlocked(output_id, check_tier):
					is_superseded = true
					break
			# Also check if another recipe replaces this output_id
			if not is_superseded:
				for other_recipe in all_recipes:
					if other_recipe.get("replaces", "") == output_id:
						var other_ut: int = int(other_recipe.get("upgrade_tier", 1))
						if GameContext.is_recipe_unlocked(other_recipe.get("output_id", ""), other_ut):
							is_superseded = true
							break

		# Check for default status
		var is_default: bool = is_unlocked and GameContext.is_default_recipe(output_id, upgrade_tier)

		# Filter by tab
		match _equipment_tab:
			"locked":
				if is_unlocked or is_superseded:
					continue
			"unlocked":
				if not is_unlocked and not is_superseded:
					continue
			# "all" shows everything

		# Filter by equipment type
		if _equipment_type_filter != "all":
			if equipment_type != _equipment_type_filter:
				continue

		# Sort priority: 0=default, 1=unlocked, 2=learnable, 3=superseded
		var sort_priority: int = 2
		if is_superseded:
			sort_priority = 3
		elif is_default:
			sort_priority = 0
		elif is_unlocked:
			sort_priority = 1
		elif is_tier_locked:
			continue  # Hide tier-locked recipes — they appear in the Upgrade view

		filtered.append({
			"recipe": recipe,
			"is_unlocked": is_unlocked,
			"is_tier_locked": is_tier_locked,
			"is_superseded": is_superseded,
			"sort_priority": sort_priority
		})

	filtered.sort_custom(func(a, b): return a.sort_priority < b.sort_priority)
	return filtered


func _create_equipment_recipe_row(recipe_data: Dictionary, facility_id: String, current_tier: int) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var recipe = recipe_data.get("recipe", {})
	var is_unlocked = recipe_data.get("is_unlocked", false)
	var is_tier_locked = recipe_data.get("is_tier_locked", false)
	var is_superseded = recipe_data.get("is_superseded", false)

	var output_id = recipe.get("output_id", "")
	var required_tier = recipe.get("required_tier", 1)
	var equipment_type = recipe.get("equipment_type", "")
	var unlock_cost = recipe.get("unlock_cost", [])
	var upgrade_tier: int = int(recipe.get("upgrade_tier", 1))
	var replaces: String = recipe.get("replaces", "")

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# For T2/T3 unlock recipes, show affix prefix in the name (NOT for T4 craft recipes)
	var is_craft: bool = recipe.get("is_craft", false)
	var region_id: String = GameContext.get_current_region_id()
	var affix: Dictionary = DataRegistry.get_regional_affix(region_id)
	var affix_prefix: String = affix.get("prefix", "") if upgrade_tier >= 2 and upgrade_tier <= 3 and not is_craft and not affix.is_empty() else ""
	if affix_prefix != "":
		output_name = "%s %s" % [affix_prefix, output_name]

	var type_str = _get_equipment_type_label(equipment_type)

	# Tier badge for T2/T3/T4
	var tier_badge: String = ""
	if upgrade_tier == 2:
		tier_badge = "[T2] "
	elif upgrade_tier == 3:
		tier_badge = "[T3] "
	elif upgrade_tier == 4:
		tier_badge = "[T4] "

	# Icon + name row with status
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)

	if output_template != null:
		var icon_rect = output_template.create_icon_rect(18)
		if icon_rect != null:
			name_row.add_child(icon_rect)

	var name_label = Label.new()
	var recipe_key: String = GameContext._recipe_key(output_id, upgrade_tier)
	if is_superseded:
		name_label.text = "[SUPERSEDED] %s%s (%s)" % [tier_badge, output_name, type_str]
		name_label.modulate = Color(0.65, 0.65, 0.65, 1)
		container.modulate = Color(0.7, 0.7, 0.7, 1)
	elif is_unlocked:
		var status: String = "[DEFAULT]" if GameContext.is_default_recipe(output_id, upgrade_tier) else "[UNLOCKED]"
		name_label.text = "%s %s%s (%s)" % [status, tier_badge, output_name, type_str]
		name_label.modulate = Color(0.5, 0.9, 0.5, 1)
	elif is_tier_locked:
		name_label.text = "[TIER %d] %s%s (%s)" % [required_tier, tier_badge, output_name, type_str]
		name_label.modulate = Color(0.7, 0.7, 0.7, 1)
		container.modulate = Color(0.78, 0.78, 0.78, 1)
	else:
		name_label.text = "%s%s (%s)" % [tier_badge, output_name, type_str]
	name_row.add_child(name_label)
	container.add_child(name_row)

	# Add tooltip with item stats + affix info
	if output_template != null:
		var tip: String = _build_equipment_item_tooltip(output_template)
		if affix_prefix != "":
			var affix_stats: Dictionary = affix.get("stat_bonus", {})
			tip += "\nAffix: %s" % affix_prefix
			for stat_name in affix_stats:
				tip += "\n  +%d %s" % [affix_stats[stat_name], stat_name.capitalize()]
		name_label.tooltip_text = tip
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP

	# Superseded: show what replaced it
	if is_superseded:
		var sup_label = Label.new()
		sup_label.text = "  Replaced by a higher-tier version"
		sup_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		sup_label.modulate = Color(0.65, 0.65, 0.65, 1)
		container.add_child(sup_label)
		return container

	# If unlocked, show availability message
	if is_unlocked:
		var unlocked_label = Label.new()
		if upgrade_tier >= 2 and affix_prefix != "":
			unlocked_label.text = "  %s version in General Store" % affix_prefix
		else:
			unlocked_label.text = "  Available in General Store"
		unlocked_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		unlocked_label.modulate = Color(0.6, 0.8, 0.6, 1)
		container.add_child(unlocked_label)
		if replaces != "":
			var rep_label = Label.new()
			var rep_tpl = DataRegistry.get_item_template(replaces)
			var rep_name: String = rep_tpl.display_name if rep_tpl != null else replaces
			rep_label.text = "  (replaces %s)" % rep_name
			rep_label.add_theme_font_size_override("font_size", GameContext.fs(12))
			rep_label.modulate = Color(0.7, 0.7, 0.7, 1)
			container.add_child(rep_label)
		# T3/T4 craft recipes: fall through to show craft button alongside store listing
		if not (is_craft and upgrade_tier >= 3):
			return container

	# If tier locked, show what tier is needed
	if is_tier_locked:
		var tier_label = Label.new()
		tier_label.text = "  Requires Tier %d facility" % required_tier
		tier_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		tier_label.modulate = Color(0.78, 0.78, 0.78, 1)
		container.add_child(tier_label)
		return container

	# T3/T4 craft recipes: show craft inputs and a Craft button
	if is_craft and upgrade_tier >= 3:
		var craft_inputs: Array = recipe.get("craft_inputs", [])
		var run_items_dict = GameContext.get_run_items_dict()
		var can_craft: bool = true
		var input_parts: Array = []

		for input_entry in craft_inputs:
			var item_id = input_entry.get("item_id", "")
			var qty_needed = input_entry.get("qty", 1)
			var qty_have = run_items_dict.get(item_id, 0)

			var item_name = item_id
			var item_template = DataRegistry.get_item_template(item_id)
			if item_template != null and item_template.display_name != "":
				item_name = item_template.display_name

			input_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
			if qty_have < qty_needed:
				can_craft = false

		var inputs_label = Label.new()
		inputs_label.text = "  Requires: %s" % ", ".join(input_parts)
		inputs_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		inputs_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_craft else Color(1, 0.5, 0.5, 1)
		container.add_child(inputs_label)

		var craft_btn = Button.new()
		craft_btn.custom_minimum_size = Vector2(120, 28)
		if can_craft:
			craft_btn.text = "Craft Item"
			craft_btn.disabled = false
			craft_btn.pressed.connect(_on_t4_craft_pressed.bind(output_id, craft_inputs, facility_id))
		else:
			craft_btn.text = "Need Materials"
			craft_btn.disabled = true
		container.add_child(craft_btn)
		return container

	# Show what this upgrade replaces
	if replaces != "":
		var rep_tpl = DataRegistry.get_item_template(replaces)
		var rep_name: String = rep_tpl.display_name if rep_tpl != null else replaces
		var replaces_label = Label.new()
		replaces_label.text = "  Replaces: %s" % rep_name
		replaces_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		replaces_label.modulate = Color(0.9, 0.7, 0.4, 1)
		container.add_child(replaces_label)

	# Show unlock cost
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var can_afford = true

	for cost_entry in unlock_cost:
		var item_id = cost_entry.get("item_id", "")
		var qty_needed = cost_entry.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "  Unlock cost: %s" % ", ".join(cost_parts)
	cost_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	container.add_child(cost_label)

	# Unlock button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 28)
	if can_afford:
		btn.text = "Upgrade Recipe" if upgrade_tier >= 2 else "Unlock Recipe"
		btn.disabled = false
		btn.pressed.connect(_on_equipment_unlock_pressed.bind(output_id, unlock_cost, facility_id, current_tier, upgrade_tier, replaces))
	else:
		btn.text = "Need Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


func _create_equipment_facility_upgrade_row(facility, current_tier: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var next_tier = current_tier + 1

	# Get upgrade cost — use centralized lookup that checks regional overrides first
	var upgrade_cost = GameContext.get_facility_upgrade_cost(facility.facility_id, next_tier)

	var gold_cost = int(upgrade_cost.get("gold", 0))
	var item_costs = upgrade_cost.get("items", [])

	# Cost display
	var cost_parts = []
	if gold_cost > 0:
		cost_parts.append("%dg" % gold_cost)

	var can_afford = GameContext.get_run_gold() >= gold_cost
	var run_items_dict = GameContext.get_run_items_dict()

	for item_cost in item_costs:
		var item_id = item_cost.get("item_id", "")
		var qty_needed = item_cost.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "Upgrade to Tier %d: %s" % [next_tier, ", ".join(cost_parts)]
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	row.add_child(cost_label)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(80, 26)
	upgrade_btn.disabled = not can_afford
	upgrade_btn.pressed.connect(_on_equipment_facility_upgrade_pressed.bind(facility.facility_id, next_tier, gold_cost, item_costs))
	row.add_child(upgrade_btn)

	return row


func _get_equipment_type_label(equipment_type: String) -> String:
	var labels = {
		"1h_weapon": "1H Weapon",
		"2h_weapon": "2H Weapon",
		"offhand": "Off Hand",
		"helmet": "Helmet",
		"armor": "Body Armor",
		"legs": "Legs",
		"accessory": "Accessory",
		"backpack": "Backpack"
	}
	return labels.get(equipment_type, equipment_type.capitalize())


func _build_equipment_item_tooltip(template) -> String:
	var lines = []
	lines.append(template.display_name)

	if template.description != "":
		lines.append(template.description)

	# Stats - use get_stat_bonuses_with_quality() for proper dictionary access
	var region_bonus: float = GameContext.get_completed_region_count() * 0.1
	var bonuses = template.get_stat_bonuses_with_quality(0, region_bonus)  # 0 = common quality
	if bonuses.get("attack", 0) > 0:
		lines.append("ATK: +%d" % bonuses.get("attack", 0))
	if bonuses.get("defense", 0) > 0:
		lines.append("DEF: +%d" % bonuses.get("defense", 0))
	if bonuses.get("health", 0) > 0:
		lines.append("HP: +%d" % bonuses.get("health", 0))
	if bonuses.get("speed", 0) > 0:
		lines.append("SPD: +%d" % bonuses.get("speed", 0))

	# Slot type - use modern equip_slot property
	if template.equip_slot != "":
		lines.append("Slot: %s" % template.equip_slot.capitalize())

	return "\n".join(lines)


## Build tooltip for an equipment icon slot in hero cards.
func _build_equipment_slot_tooltip(slot: String, item_id: String, quality: int, slot_data: Dictionary) -> String:
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return "%s: Unknown" % slot.capitalize()
	var prefix: String = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
	var lines: Array[String] = []
	lines.append("%s%s (Q%d)" % [prefix, tpl.display_name, quality])
	lines.append("Slot: %s" % slot.capitalize())
	var region_bonus: float = GameContext.get_completed_region_count() * 0.1
	var stats = tpl.get_stat_bonuses_with_quality(quality, region_bonus)
	var stat_parts: Array[String] = []
	for sk in CombatUnit.STAT_KEYS:
		if stats.get(sk, 0) > 0:
			stat_parts.append("%s +%d" % [CombatUnit.STAT_ABBREV.get(sk, sk), stats[sk]])
	if stat_parts.size() > 0:
		lines.append("  ".join(stat_parts))
	var affix_prefix: String = slot_data.get("affix_prefix", "")
	if affix_prefix != "":
		lines.append("Affix: %s" % affix_prefix)
	return "\n".join(lines)


## Create a gray empty equipment slot placeholder.
func _create_empty_equip_slot(abbrev: String, slot_size: int) -> PanelContainer:
	var empty_panel = PanelContainer.new()
	empty_panel.custom_minimum_size = Vector2(slot_size, slot_size)
	var empty_style = StyleBoxFlat.new()
	empty_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	empty_style.border_color = Color(0.4, 0.4, 0.4, 0.5)
	empty_style.set_border_width_all(1)
	empty_style.set_corner_radius_all(2)
	empty_panel.add_theme_stylebox_override("panel", empty_style)
	var empty_lbl = Label.new()
	empty_lbl.text = abbrev
	var font_sz: int = GameContext.fs(8) if slot_size <= 32 else GameContext.fs(10)
	empty_lbl.add_theme_font_size_override("font_size", font_sz)
	empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	empty_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
	empty_panel.add_child(empty_lbl)
	empty_panel.tooltip_text = "Empty %s slot" % abbrev
	empty_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return empty_panel


func _on_equipment_tab_pressed(tab: String) -> void:
	_equipment_tab = tab
	_refresh_facility_panel()


func _on_equipment_filter_pressed(filter: String) -> void:
	_equipment_type_filter = filter
	_refresh_facility_panel()


func _on_equipment_view_pressed(view: String) -> void:
	_equipment_view = view
	_refresh_facility_panel()


func _on_inn_view_pressed(view: String) -> void:
	_inn_view = view
	# Clear roster highlight when player visits the roster tab
	if view == "roster" and _highlight_roster_tab:
		_highlight_roster_tab = false
		GameContext.complete_tutorial("visited_roster_after_hire")
	_refresh_facility_panel()


func _on_shop_view_pressed(view: String) -> void:
	if view == "sell":
		_on_shop_sell_pressed()
		return
	_shop_view = view
	_refresh_facility_panel()


func _on_training_view_pressed(view: String) -> void:
	_training_view = view
	_refresh_facility_panel()


func _on_production_view_pressed(view: String, facility_id: String = "") -> void:
	if facility_id == "":
		facility_id = _current_facility_id
	_production_views[facility_id] = view
	# Switch focus to the correct facility panel if needed
	if facility_id != _current_facility_id and _open_panels.has(facility_id):
		_current_facility_id = facility_id
		var info = _open_panels[facility_id]
		_facility_actions_container = info.get("actions_container")
		_current_facility = DataRegistry.get_facility(facility_id)
	_refresh_facility_panel()


func _on_upgrade_tier_tab_pressed(tier: int) -> void:
	_upgrade_tier_tab = tier
	_refresh_facility_panel()


func _on_equipment_unlock_pressed(output_id: String, unlock_cost: Array, facility_id: String, facility_tier: int, upgrade_tier: int = 1, replaces: String = "") -> void:
	var success = GameContext.purchase_recipe_unlock(output_id, unlock_cost, facility_id, facility_tier, upgrade_tier, replaces)
	if success:
		UIAudio.play_sfx("unlock_purchase")
		print("[EquipmentUI] unlocked recipe=%s:t%d facility=%s fac_tier=%d replaces=%s" % [output_id, upgrade_tier, facility_id, facility_tier, replaces])
	else:
		UIAudio.play_sfx("error_insufficient")
		print("[EquipmentUI] unlock_failed recipe=%s:t%d" % [output_id, upgrade_tier])
	_refresh_facility_panel()


func _on_t4_craft_pressed(output_id: String, craft_inputs: Array, facility_id: String) -> void:
	# Verify all inputs available
	var run_items_dict = GameContext.get_run_items_dict()
	for input_entry in craft_inputs:
		var item_id = input_entry.get("item_id", "")
		var qty_needed = input_entry.get("qty", 1)
		if run_items_dict.get(item_id, 0) < qty_needed:
			print("[T4Craft] insufficient %s: have=%d need=%d" % [item_id, run_items_dict.get(item_id, 0), qty_needed])
			_refresh_facility_panel()
			return

	# Consume inputs
	for input_entry in craft_inputs:
		var item_id = input_entry.get("item_id", "")
		var qty_needed = input_entry.get("qty", 1)
		GameContext.remove_run_item(item_id, qty_needed)

	# Produce the T4 item as a quality-0 ItemInstance
	GameContext._add_item_with_quality(output_id, 0)
	print("[T4Craft] crafted %s at facility=%s" % [output_id, facility_id])
	GameContext.save_game()
	_refresh_facility_panel()


func _on_equipment_facility_upgrade_pressed(facility_id: String, new_tier: int, gold_cost: int, item_costs: Array) -> void:
	var town_id = GameContext.get_current_town_id()
	var tier_before = GameContext.get_facility_tier(town_id, facility_id)

	# Use the centralized upgrade_facility which handles validation, spending, and saving
	if GameContext.upgrade_facility(town_id, facility_id):
		UIAudio.play_sfx("facility_upgrade")
		var tier_after = GameContext.get_facility_tier(town_id, facility_id)
		print("[EquipmentUI] upgraded facility=%s tier=%d->%d gold_cost=%d" % [facility_id, tier_before, tier_after, gold_cost])
	else:
		UIAudio.play_sfx("error_insufficient")
		print("[EquipmentUI] upgrade_failed facility=%s tier=%d" % [facility_id, tier_before])

	_refresh_facility_panel()


func _create_crafting_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var output_id = recipe.get("output_id", "")
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Check if already unlocked
	var is_unlocked = GameContext.is_recipe_unlocked(output_id)

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Recipe name with unlock status
	var name_label = Label.new()
	if is_unlocked:
		var status = "[DEFAULT]" if GameContext.is_default_recipe(output_id) else "[UNLOCKED]"
		name_label.text = "Recipe: %s %s" % [output_name, status]
		name_label.modulate = Color(0.5, 0.9, 0.5, 1)  # Green for unlocked
	else:
		name_label.text = "Recipe: %s" % output_name
	container.add_child(name_label)

	# If already unlocked, show craft option (if recipe has inputs) or shop message
	if is_unlocked:
		if inputs.size() > 0:
			# Recipe has material inputs - show Craft button
			var run_items_dict = GameContext.get_run_items_dict()
			var can_craft = true
			var cost_parts = []

			for input_item in inputs:
				var item_id = input_item.get("item_id", "")
				var qty_needed = input_item.get("qty", 1)
				var qty_have = run_items_dict.get(item_id, 0)

				var item_name = item_id
				var item_template = DataRegistry.get_item_template(item_id)
				if item_template != null and item_template.display_name != "":
					item_name = item_template.display_name

				cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
				if qty_have < qty_needed:
					can_craft = false

			var cost_label = Label.new()
			cost_label.text = "  Craft cost: %s" % ", ".join(cost_parts)
			cost_label.add_theme_font_size_override("font_size", GameContext.fs(13))
			cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_craft else Color(1, 0.5, 0.5, 1)
			container.add_child(cost_label)

			var craft_btn = Button.new()
			craft_btn.custom_minimum_size = Vector2(120, 28)
			if can_craft:
				craft_btn.text = "Craft"
				craft_btn.disabled = false
				craft_btn.pressed.connect(_on_craft_recipe_pressed.bind(recipe))
			else:
				craft_btn.text = "Need Materials"
				craft_btn.disabled = true
			container.add_child(craft_btn)
		else:
			# No inputs - just show shop availability
			var unlocked_label = Label.new()
			unlocked_label.text = "  Available in General Store"
			unlocked_label.add_theme_font_size_override("font_size", GameContext.fs(13))
			unlocked_label.modulate = Color(0.6, 0.8, 0.6, 1)
			container.add_child(unlocked_label)
		return container

	# Cost display (materials from run stash)
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var can_afford = true

	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	cost_label.text = "  Materials: %s" % ", ".join(cost_parts)
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	container.add_child(cost_label)

	# Gold cost display (if any)
	if cost_gold > 0:
		var current_gold = GameContext.get_run_gold()
		var gold_label = Label.new()
		gold_label.text = "  Gold: %d / %d" % [current_gold, cost_gold]
		if current_gold < cost_gold:
			gold_label.modulate = Color(1, 0.5, 0.5, 1)
			can_afford = false
		else:
			gold_label.modulate = Color(0.8, 0.8, 0.8, 1)
		container.add_child(gold_label)

	# Unlock button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 28)
	if can_afford:
		btn.text = "Unlock"
		btn.disabled = false
		btn.pressed.connect(_on_unlock_recipe_pressed.bind(recipe))
	else:
		btn.text = "Missing Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


## Facilities v4: Create a grayed-out row for a locked recipe.
func _create_locked_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.modulate = Color(0.7, 0.7, 0.7, 1)  # Gray out

	var output_id = recipe.get("output_id", "")
	var required_tier = recipe.get("required_tier", 1)
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Locked header label
	var name_label = Label.new()
	name_label.text = "Locked (Tier %d): %s" % [required_tier, output_name]
	name_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1))
	container.add_child(name_label)

	# Cost display (grayed, for preview)
	var cost_parts = []
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name
		cost_parts.append("%s x%d" % [item_name, qty_needed])

	var cost_label = Label.new()
	var cost_text = "  Cost: %s" % ", ".join(cost_parts)
	if cost_gold > 0:
		cost_text += " + %dg" % cost_gold
	cost_label.text = cost_text
	cost_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	container.add_child(cost_label)

	return container


func _on_craft_recipe_pressed(recipe: Dictionary) -> void:
	var output_id = recipe.get("output_id", "")
	var output_qty = recipe.get("output_qty", 1)
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Verify gold cost
	if cost_gold > 0 and GameContext.get_run_gold() < cost_gold:
		print("[Blacksmith] craft_failed item=%s reason=insufficient_gold need=%d have=%d" % [output_id, cost_gold, GameContext.get_run_gold()])
		return

	# Verify materials and consume
	var run_items_dict = GameContext.get_run_items_dict()
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		if qty_have < qty_needed:
			print("[Blacksmith] craft_failed item=%s reason=missing_%s need=%d have=%d" % [output_id, item_id, qty_needed, qty_have])
			return

	# Consume gold (if any)
	if cost_gold > 0:
		GameContext.spend_run_gold(cost_gold)

	# Consume materials
	var consumed_parts = []
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		GameContext.remove_run_item(item_id, qty_needed)
		consumed_parts.append("%s=%d" % [item_id, qty_needed])

	# Add crafted item to stash
	GameContext.add_run_item(output_id, output_qty)

	print("[Blacksmith] craft item=%s qty=%d consumed=[%s] gold_spent=%d" % [output_id, output_qty, ", ".join(consumed_parts), cost_gold])

	# Refresh UI
	_refresh_facility_panel()


## Unlock a recipe so its item appears in the General Store.
func _on_unlock_recipe_pressed(recipe: Dictionary) -> void:
	var output_id = recipe.get("output_id", "")
	var inputs = recipe.get("inputs", [])
	var cost_gold = int(recipe.get("cost_gold", 0))

	# Check if already unlocked
	if GameContext.is_recipe_unlocked(output_id):
		print("[Recipe] Already unlocked: %s" % output_id)
		_refresh_facility_panel()
		return

	# Verify gold cost
	if cost_gold > 0 and GameContext.get_run_gold() < cost_gold:
		print("[Recipe] unlock_failed item=%s reason=insufficient_gold need=%d have=%d" % [output_id, cost_gold, GameContext.get_run_gold()])
		return

	# Verify materials
	var run_items_dict = GameContext.get_run_items_dict()
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		if qty_have < qty_needed:
			print("[Recipe] unlock_failed item=%s reason=missing_%s need=%d have=%d" % [output_id, item_id, qty_needed, qty_have])
			return

	# Consume gold (if any)
	if cost_gold > 0:
		GameContext.spend_run_gold(cost_gold)

	# Consume materials
	var consumed_parts = []
	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		GameContext.remove_run_item(item_id, qty_needed)
		consumed_parts.append("%s=%d" % [item_id, qty_needed])

	# Get facility info for recipe unlock
	var facility_id = _current_facility.facility_id if _current_facility != null else "unknown"
	var town_id = GameContext.get_current_town_id()
	var facility_tier = GameContext.get_facility_tier(town_id, facility_id)

	# Unlock the recipe
	GameContext.unlock_recipe(output_id, facility_id, facility_tier)

	print("[Recipe] unlocked item=%s facility=%s tier=%d consumed=[%s] gold_spent=%d" % [
		output_id, facility_id, facility_tier, ", ".join(consumed_parts), cost_gold])

	# Refresh UI
	_refresh_facility_panel()


func _create_unlock_row(unlock: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Get unlock group info
	var unlock_group = unlock.get("unlock_group", "")
	var is_unlocked = GameContext.has_unlocked_group(unlock_group)

	# Unlock label with status
	var name_label = Label.new()
	var display_label = unlock.get("label", "Unlock %s" % unlock_group)
	name_label.text = display_label
	if is_unlocked:
		name_label.modulate = Color(0.5, 1, 0.5, 1)
	container.add_child(name_label)

	# Cost display (from run stash materials)
	var costs = unlock.get("costs", [])
	var cost_parts = []
	var run_items_dict = GameContext.get_run_items_dict()
	var debug_have: Dictionary = {}
	for cost_item in costs:
		var item_id = cost_item.get("item_id", "")
		var qty_needed = cost_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		debug_have[item_id] = qty_have
		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name
		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])

	var cost_label = Label.new()
	cost_label.text = "  Cost: %s" % ", ".join(cost_parts) if cost_parts.size() > 0 else "  Cost: Free"
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1)
	container.add_child(cost_label)

	# Check if player can afford from run stash
	var can_afford = GameContext.can_afford_run_materials(costs)

	# Debug logging
	print("[UnlockDebug] unlock_group=%s cost=%s have=%s can_unlock=%s" % [unlock_group, str(costs), str(debug_have), str(can_afford)])

	# Unlock button with appropriate state
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 28)
	if is_unlocked:
		btn.text = "Unlocked"
		btn.disabled = true
		btn.modulate = Color(0.5, 1, 0.5, 1)
	elif can_afford:
		btn.text = "Unlock"
		btn.disabled = false
		btn.pressed.connect(_on_unlock_pressed.bind(unlock))
	else:
		btn.text = "Missing Materials"
		btn.disabled = true
	container.add_child(btn)

	return container


func _build_training_ui() -> void:
	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No training hall data)"
		no_data.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_data)
		return

	var facility = _current_facility
	var town_id = GameContext.get_current_town_id()
	var facility_id = facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# NPC header: portrait + greeting + menu options
	var menu = [
		{"view": "books", "label": "Class Books"},
		{"view": "assign", "label": "Assign Class"},
		{"view": "upgrade", "label": "Upgrade Hall"},
	]
	_build_npc_header(facility, menu, _training_view, _on_training_view_pressed)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Dispatch to selected view
	match _training_view:
		"books":
			_build_training_books_view(facility, current_tier)
		"assign":
			_build_training_assign_view(facility, current_tier)
		"upgrade":
			_build_training_upgrade_view(facility, current_tier)

	print("[TrainingUI] facility=%s tier=%d view=%s" % [facility_id, current_tier, _training_view])


## Training books view: books for sale + books owned in stash
func _build_training_books_view(facility, current_tier: int) -> void:
	# Gold display
	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Books for Sale
	var shop_header = Label.new()
	shop_header.text = "-- Books for Sale --"
	shop_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(shop_header)

	# Filter shop items by unlock groups + progression gating
	var all_shop_items = facility.shop_items if facility != null else []
	var unlocked_shop_items: Array = []
	var locked_count = 0
	var gated_count = 0
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	var dungeon_id = town.dungeon_id if town != null else ""
	var current_region = GameContext.get_current_region()

	for shop_item in all_shop_items:
		var item_id = shop_item.get("item_id", "")
		var requires_group = shop_item.get("requires_unlock_group", "")
		var required_town_tier = shop_item.get("required_town_tier", 1)
		var required_floor = shop_item.get("required_dungeon_floor_unlocked", 1)

		# Check class unlock_region for books (must be <= current_region)
		var class_id = GameContext.get_class_for_book(item_id)
		if class_id != "":
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data != null and class_data.unlock_region > current_region:
				gated_count += 1
				continue

		# Check facility tier requirement (Training Hall tier gating for books)
		var required_fac_tier = shop_item.get("required_facility_tier", 1)
		if required_fac_tier > current_tier:
			gated_count += 1
			continue

		# Check unlock group requirement (skip if none required)
		if requires_group != "" and not GameContext.has_unlocked_group(requires_group):
			locked_count += 1
			continue

		# Check town tier gating (optional - if > 1)
		if required_town_tier > 1:
			if not GameContext.meets_town_tier_requirement(town_id, required_town_tier):
				gated_count += 1
				continue

		# Check dungeon floor gating (optional - if > 1)
		if required_floor > 1:
			if not GameContext.meets_dungeon_floor_requirement(dungeon_id, required_floor):
				gated_count += 1
				continue

		unlocked_shop_items.append(shop_item)

	print("[TrainingHall] shown=%d locked=%d gated=%d total=%d tier=%d" % [unlocked_shop_items.size(), locked_count, gated_count, all_shop_items.size(), current_tier])

	# T3+ book discount: 50% off all books
	var book_discount: float = 1.0
	if current_tier >= 3:
		book_discount = 0.5
		var discount_label = Label.new()
		discount_label.text = "50%% Book Discount (Tier %d)" % current_tier
		discount_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		discount_label.modulate = Color(0.5, 1.0, 0.5, 1)
		_facility_actions_container.add_child(discount_label)

	# Global XP bonus display
	var xp_bonus: float = GameContext.get_global_training_xp_bonus()
	if xp_bonus > 0.0:
		var xp_label = Label.new()
		xp_label.text = "+%d%% Global XP Bonus" % int(xp_bonus * 100)
		xp_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		xp_label.modulate = Color(0.6, 0.85, 1.0, 1)
		_facility_actions_container.add_child(xp_label)

	if unlocked_shop_items.size() > 0:
		var book_grid = GridContainer.new()
		book_grid.columns = 2
		book_grid.add_theme_constant_override("h_separation", 8)
		book_grid.add_theme_constant_override("v_separation", 2)
		_facility_actions_container.add_child(book_grid)
		for shop_item in unlocked_shop_items:
			var discounted_item: Dictionary = shop_item.duplicate()
			if book_discount < 1.0:
				discounted_item["price_gold"] = int(shop_item.get("price_gold", 0) * book_discount)
			var row = _create_shop_row(discounted_item)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			book_grid.add_child(row)
	else:
		var no_items = Label.new()
		no_items.text = "(No books available for purchase)"
		no_items.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_items)

	# Separator + Books Owned section
	var sep1 = HSeparator.new()
	_facility_actions_container.add_child(sep1)

	var owned_header = Label.new()
	owned_header.text = "-- Books Owned --"
	owned_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	owned_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(owned_header)

	var stash_dict = GameContext.get_run_items_dict()
	var owned_books: Array = []
	for book_id in GameContext.BOOK_TO_CLASS_MAP.keys():
		var qty = stash_dict.get(book_id, 0)
		if qty > 0:
			owned_books.append({ "book_id": book_id, "qty": qty })

	if owned_books.size() == 0:
		var no_books = Label.new()
		no_books.text = "(No class books in stash)"
		no_books.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_books)
	else:
		var owned_grid = GridContainer.new()
		owned_grid.columns = 2
		owned_grid.add_theme_constant_override("h_separation", 8)
		owned_grid.add_theme_constant_override("v_separation", 2)
		_facility_actions_container.add_child(owned_grid)
		for book_data in owned_books:
			var tpl = DataRegistry.get_item_template(book_data.book_id)
			var dname: String = tpl.display_name if tpl != null and tpl.display_name != "" else book_data.book_id
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if tpl != null:
				var icon_rect = tpl.create_icon_rect(18)
				if icon_rect != null:
					row.add_child(icon_rect)
			var label = Label.new()
			label.text = "%s x%d" % [dname, book_data.qty]
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			owned_grid.add_child(row)


## Training assign view: hero selection + book assignment
func _build_training_assign_view(facility, current_tier: int) -> void:
	# Hero Roster (select a hero to assign class)
	var roster_header = Label.new()
	roster_header.text = "-- Select Hero --"
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roster_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(roster_header)

	var owned_heroes = GameContext.get_owned_heroes()
	if owned_heroes.size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "(No heroes recruited - visit the Inn first!)"
		no_heroes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_heroes)
	else:
		for hero in owned_heroes:
			var row = _create_training_hero_row(hero)
			_facility_actions_container.add_child(row)

	# Show selected hero indicator
	if _training_selected_hero_id != "":
		var selected_hero = GameContext.get_hero(_training_selected_hero_id)
		if not selected_hero.is_empty():
			var selected_label = Label.new()
			selected_label.text = "Selected: %s (%s %s)" % [
				selected_hero.get("name", "?"),
				selected_hero.get("race_id", "human").capitalize(),
				selected_hero.get("class_id", "none").capitalize()
			]
			selected_label.modulate = Color(0.5, 1, 0.5, 1)
			selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_facility_actions_container.add_child(selected_label)

	# Separator + Books Owned for assignment
	var sep1 = HSeparator.new()
	_facility_actions_container.add_child(sep1)

	var books_header = Label.new()
	books_header.text = "-- Assign Class Book --"
	books_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	books_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(books_header)

	var stash_dict = GameContext.get_run_items_dict()
	var owned_books: Array = []
	for book_id in GameContext.BOOK_TO_CLASS_MAP.keys():
		var qty = stash_dict.get(book_id, 0)
		if qty > 0:
			owned_books.append({ "book_id": book_id, "qty": qty })

	if owned_books.size() == 0:
		var no_books = Label.new()
		no_books.text = "(No books in stash - buy some from Class Books!)"
		no_books.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_books)
	else:
		for book_data in owned_books:
			var row = _create_book_assign_row(book_data.book_id, book_data.qty)
			_facility_actions_container.add_child(row)


## Training upgrade view: tier tabs with benefits
func _build_training_upgrade_view(facility, current_tier: int) -> void:
	var max_tier = facility.max_tier
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)
		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var selected_tier = _upgrade_tier_tab

	if selected_tier <= current_tier:
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Unlocked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)
		_build_training_tier_benefits(facility, selected_tier, current_tier)

	elif selected_tier == current_tier + 1:
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

		var sep2 = HSeparator.new()
		_facility_actions_container.add_child(sep2)
		_build_training_tier_benefits(facility, selected_tier, current_tier)

	else:
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)


## Display Training Hall tier benefits (real mechanical stats)
func _build_training_tier_benefits(facility, tier: int, current_tier: int) -> void:
	var benefits: Array[String] = _get_tier_benefits(facility, tier)
	for benefit_text in benefits:
		var blabel = Label.new()
		blabel.text = benefit_text
		blabel.add_theme_font_size_override("font_size", GameContext.fs(14))
		blabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(blabel)


## Create a hero row for Training Hall roster (Name + Race + Class + Select button)
func _create_training_hero_row(hero: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var hero_id = hero.get("hero_id", "")
	var hero_name = hero.get("name", hero_id)
	var race_id = hero.get("race_id", "human")
	var class_id = hero.get("class_id", "none")
	var is_selected = (hero_id == _training_selected_hero_id)

	# Name + Level + XP column
	var hero_level: int = int(hero.get("level", 1))
	var info_col = VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 0)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = "%s (%s %s Lv%d)" % [hero_name, race_id.capitalize(), class_id.capitalize(), hero_level]
	if is_selected:
		label.modulate = Color(0.6, 0.5, 0.3, 1)
	info_col.add_child(label)

	var hero_xp: int = int(hero.get("xp", 0))
	var is_max_level: bool = hero_level >= GameContext.MAX_HERO_LEVEL
	var xp_sub = Label.new()
	if is_max_level:
		xp_sub.text = "XP: MAX"
		xp_sub.modulate = Color(1.0, 0.85, 0.3, 0.8)
	else:
		var next_xp: int = GameContext.get_xp_for_level(hero_level + 1)
		xp_sub.text = format_xp_line(hero_xp, next_xp, false)
		xp_sub.modulate = Color(0.5, 0.8, 1.0, 0.8)
	xp_sub.add_theme_font_size_override("font_size", GameContext.fs(12))
	info_col.add_child(xp_sub)
	row.add_child(info_col)

	# Select button
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(80, 26)
	if is_selected:
		btn.text = "Selected"
		_apply_selected_button_style(btn)
	else:
		btn.text = "Select"
		btn.pressed.connect(_on_training_select_hero_pressed.bind(hero_id))
	row.add_child(btn)

	return row


## Create a book row for assigning class to selected hero
func _create_book_assign_row(book_id: String, qty: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var class_id = GameContext.get_class_for_book(book_id)

	# Get display name from item template
	var display_name = book_id
	var tpl = DataRegistry.get_item_template(book_id)
	if tpl != null and tpl.display_name != "":
		display_name = tpl.display_name

	# Label: book name x qty with icon
	if tpl != null:
		var icon_rect = tpl.create_icon_rect(18)
		if icon_rect != null:
			row.add_child(icon_rect)
	var label = Label.new()
	label.text = "%s x%d" % [display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Assign button - depends on selected hero state
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(120, 26)

	if _training_selected_hero_id == "":
		# No hero selected
		btn.text = "Select a hero"
		btn.disabled = true
		btn.modulate = Color(0.78, 0.78, 0.78, 1)
	else:
		# Hero selected - check if already has this class
		var selected_hero = GameContext.get_hero(_training_selected_hero_id)
		var hero_class = selected_hero.get("class_id", "none")

		if hero_class == class_id:
			btn.text = "Already %s" % class_id.capitalize()
			btn.disabled = true
			btn.modulate = Color(0.5, 1, 0.5, 1)
		elif hero_class == "none" or hero_class == "":
			btn.text = "Assign %s" % class_id.capitalize()
			btn.pressed.connect(_on_assign_book_pressed.bind(book_id))
		else:
			btn.text = "Change to %s" % class_id.capitalize()
			btn.pressed.connect(_on_assign_book_pressed.bind(book_id))

	row.add_child(btn)

	return row


func _on_training_select_hero_pressed(hero_id: String) -> void:
	_training_selected_hero_id = hero_id
	var hero = GameContext.get_hero(hero_id)
	print("[TrainingHall] selected hero=%s name=%s class=%s" % [
		hero_id, hero.get("name", "?"), hero.get("class_id", "none")
	])
	_refresh_facility_panel()


func _on_assign_book_pressed(book_id: String) -> void:
	if _training_selected_hero_id == "":
		print("[TrainingHall] assign failed - no hero selected")
		return

	var success = GameContext.assign_class_from_book(_training_selected_hero_id, book_id)
	# Logging is handled by GameContext.assign_class_from_book
	_refresh_facility_panel()


# ============================================================================
# HEROES SECTION (Main Town View - Minimal Party Summary + Visit Inn)
# ============================================================================

func _populate_heroes_section() -> void:
	# Clear existing dynamic content (immediate removal prevents ghost nodes)
	_clear_children_immediate(heroes_vbox)

	var party = GameContext.get_selected_party()
	var roster_size = GameContext.get_roster().size()

	# Party summary line
	var summary_label = Label.new()
	summary_label.text = "Party: %d / %d  |  Roster: %d" % [
		party.size(), GameContext.get_max_party_size(), roster_size
	]
	summary_label.modulate = Color(0.5, 1, 0.5, 1) if party.size() > 0 else Color(0.8, 0.8, 0.8, 1)
	heroes_vbox.add_child(summary_label)

	# Compact party member names
	if party.size() > 0:
		for hero_id in party:
			var hero = GameContext.get_hero(hero_id)
			if hero.is_empty():
				continue
			var hero_name = hero.get("name", hero_id)
			var class_id = hero.get("class_id", "")
			var cls_name = class_id.capitalize()
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data != null and class_data.display_name != "":
				cls_name = class_data.display_name
			var member_label = Label.new()
			member_label.text = "  %s (%s)" % [hero_name, cls_name]
			member_label.modulate = Color(0.6, 1, 0.6, 1)
			member_label.add_theme_font_size_override("font_size", GameContext.fs(15))
			heroes_vbox.add_child(member_label)
	else:
		var empty_label = Label.new()
		empty_label.text = "  (No party selected - visit Inn to recruit)"
		empty_label.modulate = Color(0.78, 0.78, 0.78, 1)
		heroes_vbox.add_child(empty_label)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	heroes_vbox.add_child(btn_row)

	# "Visit Inn" button to open Inn facility popup
	var inn_btn = Button.new()
	inn_btn.text = "Visit Inn (Recruit / Party)"
	inn_btn.custom_minimum_size = Vector2(200, 30)
	inn_btn.pressed.connect(_on_visit_inn_pressed)
	btn_row.add_child(inn_btn)

	# "Manage Bags" button to open hero bag management (only if party exists)
	if party.size() > 0:
		var bags_btn = Button.new()
		bags_btn.text = "Manage Hero Bags"
		bags_btn.custom_minimum_size = Vector2(150, 30)
		bags_btn.pressed.connect(_on_manage_bags_pressed)
		btn_row.add_child(bags_btn)

	# Hero party cards — always rendered, even when party is empty
	var bar_target: Control = party_bar_target if party_bar_target != null else heroes_vbox
	_build_hero_party_bar(party, bar_target)


## Refresh party bar when party composition changes (recruit, dismiss, etc.)
func _on_party_changed(_hero_ids: Array) -> void:
	_populate_heroes_section()


## Open the Inn facility popup from the main town view.
func _on_visit_inn_pressed() -> void:
	# Find the inn facility_id for this town
	var town_id = GameContext.get_current_town_id()
	var inn_id = ""
	if DataRegistry.has_method("get_facilities_for_town"):
		var facilities = DataRegistry.get_facilities_for_town(town_id)
		for fac in facilities:
			if fac.facility_type == "inn":
				inn_id = fac.facility_id
				break
	if inn_id == "":
		inn_id = "inn"  # Fallback to default inn ID
	_show_facility_panel(inn_id)


# ============================================================================
# HERO PARTY BAR (6 compact hero slots in a horizontal grid)
# ============================================================================

## Build 6 compact hero slots (filled + empty placeholders).
func _build_hero_party_bar(party: Array, target: Control) -> void:
	# Clear previous party bar content from the target (if it's the external container)
	if target != heroes_vbox:
		_clear_children_immediate(target)

	var bar_label = Label.new()
	bar_label.text = "Party Overview"
	bar_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	bar_label.modulate = Color(0.8, 0.9, 1.0, 1)
	target.add_child(bar_label)

	var grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	target.add_child(grid)

	# Filled hero slots
	for hero_id in party:
		var card = _create_party_card(hero_id)
		if card != null:
			grid.add_child(card)

	# Empty slots: fillable (up to max party) vs locked (decorative padding beyond max)
	var filled = party.size()
	var max_party = GameContext.get_max_party_size()
	for i in range(filled, 6):
		grid.add_child(_create_empty_party_slot(i < max_party))


## Create a compact party slot for a hero.
func _create_party_card(hero_id: String) -> PanelContainer:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return null

	var hero_name: String = hero.get("name", hero_id)
	var class_id: String = hero.get("class_id", "")
	var hero_level: int = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var cls_name: String = class_data.display_name if class_data != null and class_data.display_name != "" else class_id.capitalize()

	# Card container (region-tinted)
	var card = PanelContainer.new()
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.3, 0.5, 0.3, 0.6)
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 6
	card_style.content_margin_top = 4
	card_style.content_margin_right = 6
	card_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", card_style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = _build_hero_tooltip(hero_id)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var card_hbox = HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 4)
	card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(card_hbox)

	# Row selector (vertical F/M/B buttons on the left)
	var row_vbox = VBoxContainer.new()
	row_vbox.add_theme_constant_override("separation", 2)
	row_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row_names = ["F", "M", "B"]
	var row_tips = ["Front — Targeted first by melee", "Middle — Targeted after Front", "Back — Targeted last by melee"]
	var current_row: int = GameContext.get_hero_row(hero_id)
	for i in range(3):
		var rbtn = Button.new()
		rbtn.text = row_names[i]
		rbtn.add_theme_font_size_override("font_size", GameContext.fs(11))
		rbtn.custom_minimum_size = Vector2(22, 0)
		rbtn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rbtn.tooltip_text = row_tips[i]
		if i == current_row:
			_apply_selected_button_style(rbtn)
		else:
			rbtn.modulate = Color(1, 1, 1, 1)
		rbtn.pressed.connect(_on_party_card_row_changed.bind(i, hero_id))
		row_vbox.add_child(rbtn)
	card_hbox.add_child(row_vbox)

	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 2)
	card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_hbox.add_child(card_vbox)

	# Remove from party button (top-right X)
	var remove_row = HBoxContainer.new()
	remove_row.alignment = BoxContainer.ALIGNMENT_END
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.flat = true
	remove_btn.custom_minimum_size = Vector2(24, 24)
	remove_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	remove_btn.modulate = Color(1, 0.5, 0.5, 0.9)
	remove_btn.tooltip_text = "Remove from party"
	remove_btn.pressed.connect(func():
		GameContext.remove_from_party(hero_id)
		_populate_heroes_section()
	)
	remove_row.add_child(remove_btn)
	card_vbox.add_child(remove_row)

	# Portrait (28x28) with colored fallback
	var portrait_path: String = hero.get("portrait_path", "")
	var portrait_tex: Texture2D = null
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex != null:
			portrait_tex = tex

	if portrait_tex != null:
		var portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait_tex
		portrait_rect.custom_minimum_size = Vector2(28, 28)
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(portrait_rect)
	else:
		var fallback = ColorRect.new()
		fallback.custom_minimum_size = Vector2(28, 28)
		fallback.color = Color(0.3, 0.4, 0.3, 0.6)
		fallback.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(fallback)

	# Hero name (truncated)
	var name_lbl = Label.new()
	var display_name: String = hero_name if hero_name.length() <= 12 else hero_name.left(11) + "."
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.modulate = Color(0.6, 1, 0.6, 1)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(name_lbl)

	# Class + level
	var class_lbl = Label.new()
	class_lbl.text = "%s Lv%d" % [cls_name, hero_level]
	class_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
	class_lbl.modulate = Color(0.7, 0.7, 0.8, 1)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox.add_child(class_lbl)

	# HP bar (compact, within slot only)
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var max_hp: int = int(eff_stats.get("health", 80)) if not eff_stats.is_empty() else 80
	var current_hp: int = max_hp
	if GameContext.get_phase() != GameContext.GamePhase.TOWN:
		var hp_data = GameContext.get_hero_hp(hero_id)
		if not hp_data.is_empty():
			current_hp = int(hp_data.get("current", max_hp))

	var hp_bar = ProgressBar.new()
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(current_hp)
	hp_bar.custom_minimum_size = Vector2(0, 8)
	hp_bar.show_percentage = false
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.8, 0.3, 1) if current_hp >= max_hp else Color(0.8, 0.8, 0.3, 1) if current_hp > max_hp * 0.5 else Color(0.8, 0.3, 0.3, 1)
	fill_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 1)
	bg_style.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bg_style)
	card_vbox.add_child(hp_bar)

	# Stats line: A:25 D:6 S:22
	var atk: int = int(eff_stats.get("attack", 0))
	var def_val: int = int(eff_stats.get("defense", 0))
	var spd: int = int(eff_stats.get("speed", 0))

	var stat_lbl = Label.new()
	stat_lbl.text = "A:%d D:%d S:%d" % [atk, def_val, spd]
	stat_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
	stat_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	stat_lbl.tooltip_text = build_inn_stats_combined_tooltip(hero_id)
	card_vbox.add_child(stat_lbl)

	# XP progress (compact)
	var hero_xp: int = int(hero.get("xp", 0))
	var is_max_level: bool = hero_level >= GameContext.MAX_HERO_LEVEL
	var xp_lbl = Label.new()
	if is_max_level:
		xp_lbl.text = "XP: MAX"
		xp_lbl.modulate = Color(1.0, 0.85, 0.3, 1)
	else:
		var next_level_xp: int = GameContext.get_xp_for_level(hero_level + 1)
		xp_lbl.text = "XP: %d/%d" % [hero_xp, next_level_xp]
		xp_lbl.modulate = Color(0.6, 0.9, 1.0, 0.8)
	xp_lbl.add_theme_font_size_override("font_size", GameContext.fs(10))
	xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(xp_lbl)

	# Button row: Gear + Bag
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(btn_row)

	var gear_btn = Button.new()
	gear_btn.text = "Gear"
	gear_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
	gear_btn.custom_minimum_size = Vector2(0, 22)
	gear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_btn.pressed.connect(_on_manage_gear_pressed.bind(hero_id))
	btn_row.add_child(gear_btn)

	# Bag button (icon with consumable status border)
	var bag_btn = TextureButton.new()
	bag_btn.custom_minimum_size = Vector2(26, 22)
	var bag_icon_tex = load("res://Assets/_ArtPacks/RPGThings/PNG/Transperent/icons_30_32.png")
	if bag_icon_tex != null:
		bag_btn.texture_normal = bag_icon_tex
		bag_btn.ignore_texture_size = true
		bag_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bag_btn.pressed.connect(_on_party_card_bag_pressed.bind(hero_id))

	var bag_items = GameContext.get_hero_bag(hero_id)
	var has_consumable: bool = false
	for entry in bag_items:
		var tpl = DataRegistry.get_item_template(entry.get("item_id", ""))
		if tpl != null and tpl.item_type == "consumable":
			has_consumable = true
			break
	var bag_panel = PanelContainer.new()
	var bag_style = StyleBoxFlat.new()
	bag_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	bag_style.set_border_width_all(2)
	bag_style.border_color = Color(0.8, 0.2, 0.2, 1.0) if not has_consumable else Color(0.3, 0.5, 0.3, 0.6)
	bag_style.set_corner_radius_all(3)
	bag_panel.add_theme_stylebox_override("panel", bag_style)
	bag_panel.add_child(bag_btn)
	btn_row.add_child(bag_panel)

	return card


## Create an empty placeholder party slot.
## If is_fillable is true AND bench heroes exist, the slot is clickable.
func _create_empty_party_slot(is_fillable: bool = false) -> PanelContainer:
	var slot = PanelContainer.new()
	var slot_style = StyleBoxFlat.new()

	# Check if bench heroes exist for clickable slots
	var has_bench_heroes: bool = false
	if is_fillable:
		var owned = GameContext.get_owned_heroes()
		for hero in owned:
			if not GameContext.is_in_party(hero.get("hero_id", "")):
				has_bench_heroes = true
				break

	var is_clickable: bool = is_fillable and has_bench_heroes

	if is_clickable:
		slot_style.bg_color = Color(0.15, 0.20, 0.15, 0.5)
		slot_style.border_color = Color(0.3, 0.5, 0.3, 0.4)
	else:
		slot_style.bg_color = Color(0.12, 0.12, 0.15, 0.4)
		slot_style.border_color = Color(0.25, 0.25, 0.3, 0.3)

	slot_style.border_width_left = 1
	slot_style.border_width_top = 1
	slot_style.border_width_right = 1
	slot_style.border_width_bottom = 1
	slot_style.set_corner_radius_all(4)
	slot_style.content_margin_left = 6
	slot_style.content_margin_top = 4
	slot_style.content_margin_right = 6
	slot_style.content_margin_bottom = 4
	slot.add_theme_stylebox_override("panel", slot_style)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(0, 60)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if is_clickable:
		lbl.text = "+ Add Hero"
		lbl.modulate = Color(0.5, 0.9, 0.5, 0.9)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.tooltip_text = "Click to add a benched hero to the party"
		slot.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_bench_picker_overlay()
		)
	elif is_fillable:
		lbl.text = "Empty"
		lbl.modulate = Color(0.65, 0.65, 0.65, 0.8)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		lbl.text = ""
		lbl.modulate = Color(0.4, 0.4, 0.4, 0.4)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slot.add_child(lbl)
	return slot


# ============================================================================
# BENCH HERO PICKER (opened from empty party bar slots)
# ============================================================================

## Open a bench hero picker overlay so the player can add a benched hero to the party.
func _open_bench_picker_overlay() -> void:
	_close_bench_picker_overlay()

	var owned = GameContext.get_owned_heroes()
	var party = GameContext.get_selected_party()
	var bench_heroes: Array = []
	for hero in owned:
		if not GameContext.is_in_party(hero.get("hero_id", "")):
			bench_heroes.append(hero)

	if bench_heroes.is_empty():
		print("[PartyBar] No bench heroes to add")
		return

	_bench_picker_overlay = CanvasLayer.new()
	_bench_picker_overlay.layer = 10
	add_child(_bench_picker_overlay)

	# Dark backdrop (click to dismiss)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_bench_picker_overlay()
	)
	_bench_picker_overlay.add_child(backdrop)

	# Centered panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bench_picker_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	style.set_border_width_all(2)
	style.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp_h: int = int(get_viewport().get_visible_rect().size.y)
	scroll.custom_minimum_size = Vector2(0, mini(int(vp_h * 0.5), 500))
	panel.add_child(scroll)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Title
	var title = Label.new()
	title.text = "Add Hero to Party (%d / %d)" % [party.size(), GameContext.get_max_party_size()]
	title.add_theme_font_size_override("font_size", GameContext.fs(18))
	title.modulate = Color(0.5, 1, 0.5, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	var sep = HSeparator.new()
	content.add_child(sep)

	# Bench hero rows
	for hero in bench_heroes:
		var row = _create_bench_picker_row(hero)
		content.add_child(row)

	# Close button
	var sep2 = HSeparator.new()
	content.add_child(sep2)

	var close_btn = Button.new()
	close_btn.text = "Cancel"
	close_btn.custom_minimum_size = Vector2(120, 28)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_bench_picker_overlay)
	content.add_child(close_btn)

	# Register with ESC-close stack
	UIAudio.register_closeable(_bench_picker_overlay, _close_bench_picker_overlay)
	print("[PartyBar] Bench picker opened — %d bench heroes" % bench_heroes.size())


## Create a compact row for a bench hero in the bench picker overlay.
func _create_bench_picker_row(hero: Dictionary) -> PanelContainer:
	var hero_id: String = hero.get("hero_id", "")
	var race_id: String = hero.get("race_id", "human")
	var class_id: String = hero.get("class_id", "")
	var hero_name: String = hero.get("name", "Unknown")
	var hero_level: int = int(hero.get("level", 1))

	var race_name: String = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name: String = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	var row_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
	style.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)

	# Portrait
	var portrait_path: String = hero.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_tex = ResourceLoader.load(portrait_path) as Texture2D
		if portrait_tex != null:
			var portrait_rect = TextureRect.new()
			portrait_rect.texture = portrait_tex
			portrait_rect.custom_minimum_size = Vector2(36, 36)
			portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(portrait_rect)

	# Info column
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info)

	var name_label = Label.new()
	name_label.text = hero_name
	name_label.add_theme_font_size_override("font_size", GameContext.fs(16))
	info.add_child(name_label)

	var detail_label = Label.new()
	detail_label.text = "%s %s  Lv %d" % [race_name, cls_name, hero_level]
	detail_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	detail_label.modulate = Color(0.7, 0.7, 0.8, 1)
	info.add_child(detail_label)

	# Stats summary
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	if not eff_stats.is_empty():
		var stats_label = Label.new()
		stats_label.text = "HP:%d  ATK:%d  DEF:%d  SPD:%d" % [
			int(eff_stats.get("health", 0)),
			int(eff_stats.get("attack", 0)),
			int(eff_stats.get("defense", 0)),
			int(eff_stats.get("speed", 0))
		]
		stats_label.add_theme_font_size_override("font_size", GameContext.fs(12))
		stats_label.modulate = Color(0.6, 0.6, 0.7, 1)
		info.add_child(stats_label)

	# Add to Party button
	var add_btn = Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(70, 30)
	add_btn.pressed.connect(_on_bench_picker_add_pressed.bind(hero_id))
	hbox.add_child(add_btn)

	return row_panel


## Handle adding a hero from the bench picker overlay.
func _on_bench_picker_add_pressed(hero_id: String) -> void:
	var result = GameContext.add_to_party(hero_id)
	if result:
		print("[PartyBar] Added %s to party from bench picker" % hero_id)
	_close_bench_picker_overlay()


## Close the bench hero picker overlay.
func _close_bench_picker_overlay() -> void:
	if _bench_picker_overlay != null and is_instance_valid(_bench_picker_overlay):
		UIAudio.unregister_closeable(_bench_picker_overlay)
		_bench_picker_overlay.queue_free()
		_bench_picker_overlay = null


## Build a rich tooltip with full hero details (abilities, passives, equipment).
func _build_hero_tooltip(hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return ""

	var hero_name: String = hero.get("name", hero_id)
	var class_id: String = hero.get("class_id", "")
	var race_id: String = hero.get("race_id", "human")
	var hero_level: int = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)
	var cls_name: String = class_data.display_name if class_data != null and class_data.display_name != "" else class_id.capitalize()
	var race_name: String = race_data.display_name if race_data != null and race_data.display_name != "" else race_id.capitalize()

	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var max_hp: int = int(eff_stats.get("health", 80)) if not eff_stats.is_empty() else 80
	var atk: int = int(eff_stats.get("attack", 0))
	var def_val: int = int(eff_stats.get("defense", 0))
	var spd: int = int(eff_stats.get("speed", 0))

	var row_names = ["Front", "Middle", "Back"]
	var hero_row: int = GameContext.get_hero_row(hero_id)

	var lines: Array[String] = []
	lines.append("%s — %s %s Lv%d" % [hero_name, race_name, cls_name, hero_level])
	lines.append("Position: %s" % row_names[hero_row])
	lines.append("HP: %d | ATK: %d | DEF: %d | SPD: %d" % [max_hp, atk, def_val, spd])

	# XP progress
	var hero_xp: int = int(hero.get("xp", 0))
	var is_max_level: bool = hero_level >= GameContext.MAX_HERO_LEVEL
	if is_max_level:
		lines.append("XP: MAX LEVEL")
	else:
		var next_xp: int = GameContext.get_xp_for_level(hero_level + 1)
		lines.append("XP: %d / %d (%d to next)" % [hero_xp, next_xp, next_xp - hero_xp])

	# Abilities with level locks
	if class_data != null:
		var ability_ids = [class_data.ability_a_id, class_data.ability_b_id]
		var ability_slots = ["ability_a", "ability_b"]
		for i in range(ability_ids.size()):
			var aid = ability_ids[i]
			if aid == "":
				continue
			var ability = DataRegistry.get_ability(aid)
			var ab_name: String = ability.display_name if ability != null else aid
			var ab_unlocked: bool = GameContext.is_ability_slot_unlocked(ability_slots[i], hero_level)
			var lock_tag: String = ""
			if not ab_unlocked:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ability_slots[i], 1)
				lock_tag = " [Lv %d]" % req_lv
			lines.append("Ability: %s%s" % [ab_name, lock_tag])

		# Passives with level locks
		var passive_ids = [class_data.passive_a_id, class_data.passive_b_id]
		var passive_slots = ["passive_a", "passive_b"]
		for i in range(passive_ids.size()):
			var pid = passive_ids[i]
			if pid == "":
				continue
			var passive = DataRegistry.get_passive(pid)
			var ps_name: String = passive.display_name if passive != null else pid
			var ps_unlocked: bool = GameContext.is_ability_slot_unlocked(passive_slots[i], hero_level)
			var ps_lock_tag: String = ""
			if not ps_unlocked:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(passive_slots[i], 1)
				ps_lock_tag = " [Lv %d]" % req_lv
			lines.append("Passive: %s%s" % [ps_name, ps_lock_tag])

	# Equipment summary
	var equip = GameContext.get_hero_equipment(hero_id)
	var equip_lines: Array[String] = []
	for eslot in GameContext.EQUIPMENT_SLOTS:
		var slot_data = equip.get(eslot, {})
		var item_id: String = slot_data.get("id", "")
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				equip_lines.append("%s: %s" % [eslot.capitalize(), tpl.display_name])
	if equip_lines.size() > 0:
		lines.append("Equipment: " + ", ".join(equip_lines))

	return "\n".join(lines)


# ============================================================================
# HERO BAG MANAGEMENT (Town Consumable Transfer)
# ============================================================================

var _bag_management_window: Window = null

## Open the hero bag management popup to transfer consumables.
func _on_manage_bags_pressed() -> void:
	if _bag_management_window != null and is_instance_valid(_bag_management_window):
		_bag_management_window.queue_free()
		_bag_management_window = null

	_bag_management_window = Window.new()
	_bag_management_window.title = "Manage Hero Bags"
	_bag_management_window.size = Vector2i(600, 500)
	_bag_management_window.position = Vector2i(
		int((get_viewport().get_visible_rect().size.x - 600) / 2),
		int((get_viewport().get_visible_rect().size.y - 500) / 2)
	)
	_bag_management_window.transient = true
	_bag_management_window.exclusive = false
	_bag_management_window.close_requested.connect(_close_bag_management_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 10
	main_vbox.offset_top = 10
	main_vbox.offset_right = -10
	main_vbox.offset_bottom = -10
	main_vbox.add_theme_constant_override("separation", 12)
	_bag_management_window.add_child(main_vbox)

	_populate_bag_management_ui(main_vbox)

	add_child(_bag_management_window)
	_bag_management_window.popup_centered()
	print("[BagMgmt] opened")


func _close_bag_management_window() -> void:
	if _bag_management_window != null and is_instance_valid(_bag_management_window):
		_bag_management_window.queue_free()
		_bag_management_window = null
	print("[BagMgmt] closed")


func _populate_bag_management_ui(container: VBoxContainer) -> void:
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# --- Section 1: Shopkeeper Stash Consumables ---
	var stash_header = Label.new()
	stash_header.text = "-- Stash Consumables --"
	stash_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stash_header.modulate = Color(1, 0.9, 0.5, 1)
	container.add_child(stash_header)

	var run_items = GameContext.get_run_items_dict()
	var consumables_in_stash: Array = []

	for item_id in run_items.keys():
		var template = DataRegistry.get_item_template(item_id)
		if template != null and template.item_type == "consumable":
			consumables_in_stash.append({
				"item_id": item_id,
				"qty": run_items[item_id],
				"template": template
			})

	if consumables_in_stash.size() == 0:
		var no_items = Label.new()
		no_items.text = "(No consumables in stash)"
		no_items.modulate = Color(0.78, 0.78, 0.78, 1)
		container.add_child(no_items)
	else:
		for item_info in consumables_in_stash:
			var row = _create_stash_consumable_row(item_info, container)
			container.add_child(row)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	# --- Section 2: Party Hero Bags ---
	var party_header = Label.new()
	party_header.text = "-- Party Hero Bags --"
	party_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	party_header.modulate = Color(0.5, 1, 0.5, 1)
	container.add_child(party_header)

	var party = GameContext.get_selected_party()
	if party.size() == 0:
		var no_party = Label.new()
		no_party.text = "(No heroes in party)"
		no_party.modulate = Color(0.78, 0.78, 0.78, 1)
		container.add_child(no_party)
	else:
		for hero_id in party:
			var hero_section = _create_hero_bag_section(hero_id, container)
			container.add_child(hero_section)


func _create_stash_consumable_row(item_info: Dictionary, parent_container: VBoxContainer) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = item_info.get("item_id", "")
	var qty = item_info.get("qty", 0)
	var template = item_info.get("template")
	var display_name = template.display_name if template else item_id

	# Item label
	var label = Label.new()
	label.text = "%s x%d" % [display_name, qty]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# "Give to" dropdown for each hero in party
	var party = GameContext.get_selected_party()
	for hero_id in party:
		var hero_data = GameContext.get_hero(hero_id)
		var hero_name = hero_data.get("name", hero_id) if hero_data else hero_id

		var give_btn = Button.new()
		give_btn.text = "→ %s" % hero_name
		give_btn.custom_minimum_size = Vector2(90, 24)

		# Check if hero can receive item
		var can_add = GameContext.can_add_to_hero_bag(hero_id, item_id, 1)
		give_btn.disabled = not can_add
		if can_add:
			give_btn.pressed.connect(_on_give_to_hero_pressed.bind(item_id, hero_id, parent_container))

		row.add_child(give_btn)

	return row


func _create_hero_bag_section(hero_id: String, parent_container: VBoxContainer) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var hero_data = GameContext.get_hero(hero_id)
	var hero_name = hero_data.get("name", hero_id) if hero_data else hero_id
	var bag = GameContext.get_hero_bag(hero_id)
	var capacity = GameContext.get_hero_bag_capacity(hero_id)
	var used = bag.size()

	# Hero header with bag capacity
	var header = Label.new()
	header.text = "%s's Bag (%d/%d)" % [hero_name, used, capacity]
	header.modulate = Color(0.8, 0.8, 1, 1)
	section.add_child(header)

	if bag.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "  (Empty)"
		empty_label.modulate = Color(0.7, 0.7, 0.7, 1)
		section.add_child(empty_label)
	else:
		for entry in bag:
			var entry_row = _create_hero_bag_item_row(hero_id, entry, parent_container)
			section.add_child(entry_row)

	return section


func _create_hero_bag_item_row(hero_id: String, entry: Dictionary, parent_container: VBoxContainer) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var item_id = entry.get("item_id", "")
	var quality = entry.get("quality", 0)
	var template = DataRegistry.get_item_template(item_id)
	var display_name = template.display_name if template else item_id

	# Indent
	var indent = Label.new()
	indent.text = "  "
	row.add_child(indent)

	# Item name
	var label = Label.new()
	label.text = display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Return to stash button
	var return_btn = Button.new()
	return_btn.text = "Return to Stash"
	return_btn.custom_minimum_size = Vector2(110, 24)
	return_btn.pressed.connect(_on_return_to_stash_pressed.bind(hero_id, item_id, quality, parent_container))
	row.add_child(return_btn)

	return row


func _on_give_to_hero_pressed(item_id: String, hero_id: String, parent_container: VBoxContainer) -> void:
	var success = GameContext.move_item_stash_to_hero_bag(hero_id, item_id, 1)
	if success:
		print("[BagMgmt] transferred item=%s to hero=%s" % [item_id, hero_id])
		GameContext.save_game()
		_populate_bag_management_ui(parent_container)
	else:
		print("[BagMgmt] transfer_failed item=%s hero=%s" % [item_id, hero_id])


func _on_return_to_stash_pressed(hero_id: String, item_id: String, quality: int, parent_container: VBoxContainer) -> void:
	var success = GameContext.move_item_hero_bag_to_stash(hero_id, item_id, 1, quality)
	if success:
		print("[BagMgmt] returned item=%s from hero=%s to stash" % [item_id, hero_id])
		GameContext.save_game()
		_populate_bag_management_ui(parent_container)
	else:
		print("[BagMgmt] return_failed item=%s hero=%s" % [item_id, hero_id])


# ============================================================================
# INN UI (Hero Recruitment & Party Management)
# ============================================================================

func _build_inn_ui() -> void:
	if _current_facility == null:
		return

	var facility = _current_facility
	var town_id = GameContext.get_current_town_id()
	var facility_id = facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# NPC header: portrait + greeting + menu options
	var menu = [
		{"view": "recruit", "label": "Recruit Heroes"},
		{"view": "roster", "label": "Manage Roster"},
		{"view": "upgrade", "label": "Upgrade Inn"},
	]
	_build_npc_header(facility, menu, _inn_view, _on_inn_view_pressed)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Dispatch to selected view
	match _inn_view:
		"recruit":
			_build_inn_recruit_view(facility, current_tier)
		"roster":
			_build_inn_roster_view(facility, current_tier)
		"upgrade":
			_build_inn_upgrade_view(facility, current_tier)

	print("[Inn] facility=%s tier=%d view=%s phase=%s" % [facility_id, current_tier, _inn_view, str(GameContext.get_phase())])


## Soft-lock safety: if no heroes owned and gold too low to rebuild, grant recovery party.
## Triggers when: Region 1 only, 0 heroes AND gold < 150 (can't afford 2 recruits at ~70g each).
## Grants: 2 equipped heroes (Defender + Striker) + enough gold to recruit 2 more from Inn.
func _check_softlock_free_recruit() -> void:
	# Pity recovery only available in Region 1 (Thornhaven)
	# Forces bankrupt players in later regions to travel back to R1
	if GameContext.get_current_region() != 1:
		return
	var owned = GameContext.get_owned_heroes()
	if not owned.is_empty():
		return
	var gold = GameContext.get_run_gold()
	if gold >= 150:
		return  # Can afford at least 2 recruits at ~70g each — not a true soft-lock

	# Soft-lock detected — grant recovery party
	print("[SoftLock] No heroes and gold=%d < 150 — granting recovery party" % gold)

	# Grant enough gold for a full party of 4 (R1 recruits cost ~70g each)
	var recovery_gold: int = maxi(250 - gold, 0)
	if recovery_gold > 0:
		GameContext.add_run_gold(recovery_gold)
		print("[SoftLock] Granted %d recovery gold (total now %d)" % [recovery_gold, GameContext.get_run_gold()])

	# Grant 2 free equipped heroes (Defender + Striker with basic weapons)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("pity_%d" % Time.get_unix_time_from_system())
	var current_region = GameContext.get_current_region()

	var equip_def = GameContext.generate_recruit_equipment("defender", current_region, 1, rng)
	var hero1 = GameContext.recruit_hero("defender", 0, "human", 1, equip_def)
	if hero1 != "":
		GameContext.add_to_party(hero1)

	var equip_str = GameContext.generate_recruit_equipment("striker", current_region, 1, rng)
	var hero2 = GameContext.recruit_hero("striker", 0, "human", 1, equip_str)
	if hero2 != "":
		GameContext.add_to_party(hero2)

	var notice = Label.new()
	notice.text = "The Town Council has provided emergency volunteers and funds to rebuild your party!"
	notice.add_theme_font_size_override("font_size", GameContext.fs(15))
	notice.modulate = Color(0.4, 1.0, 0.5, 1)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facility_actions_container.add_child(notice)
	_facility_actions_container.add_child(HSeparator.new())


## Returns a town-scoped shop ID for Inn slot tracking (e.g. "town_thornhaven:inn").
## Each town's Inn tracks purchased slots independently.
func _get_inn_shop_id() -> String:
	return "%s:%s" % [GameContext.get_current_town_id(), _current_facility_id]


## Inn recruit view: available candidates to hire
func _build_inn_recruit_view(facility, current_tier: int) -> void:
	# Soft-lock safety: if no heroes and can't afford any, offer a free recruit
	_check_softlock_free_recruit()

	# Party + bench status bar
	var selected_party = GameContext.get_selected_party()
	var town_id: String = GameContext.get_current_town_id()
	var bench_count: int = GameContext.get_inn_bench_count(town_id)
	var bench_cap: int = GameContext.get_inn_bench_capacity(town_id)
	var party_full: bool = selected_party.size() >= GameContext.get_max_party_size()
	var bench_full: bool = bench_count >= bench_cap

	var party_label = Label.new()
	party_label.text = "Party: %d / %d  |  Bench: %d / %d" % [selected_party.size(), GameContext.get_max_party_size(), bench_count, bench_cap]
	if party_full and bench_full:
		party_label.modulate = Color(1.0, 0.5, 0.5, 1)
	elif selected_party.size() > 0:
		party_label.modulate = Color(0.5, 1, 0.5, 1)
	else:
		party_label.modulate = Color(0.8, 0.8, 0.8, 1)
	_facility_actions_container.add_child(party_label)

	if party_full and bench_full:
		var full_warn = Label.new()
		full_warn.text = "Inn bench full! Dismiss a hero or upgrade inn."
		full_warn.add_theme_font_size_override("font_size", GameContext.fs(12))
		full_warn.modulate = Color(1.0, 0.6, 0.4, 1)
		_facility_actions_container.add_child(full_warn)

	# Get recruit level from facility tier, with regional minimum floor
	var recruit_level = 1
	var level_by_tier = facility.recruit_level_by_tier
	if level_by_tier.has(str(current_tier)):
		recruit_level = int(level_by_tier[str(current_tier)])
	var region_str: String = str(GameContext.get_current_region())
	var regional_min: int = int(facility.regional_recruit_level_minimum.get(region_str, 1))
	recruit_level = maxi(recruit_level, regional_min)

	# Recruit slots scale with tier: T1=3, T2=4, T3=5, T4=6
	var max_candidates: int = 2 + current_tier

	var recruit_level_label = Label.new()
	recruit_level_label.text = "Recruit Level: %d  |  Slots: %d" % [recruit_level, max_candidates]
	recruit_level_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	recruit_level_label.modulate = Color(0.7, 0.85, 1.0, 1)
	_facility_actions_container.add_child(recruit_level_label)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Dynamic recruit candidates from DataRegistry (races + classes filtered by unlock_region)
	var current_region = GameContext.get_current_region()
	var candidates = _generate_inn_recruit_candidates(current_region, recruit_level, max_candidates, current_tier)
	var inn_id = _get_inn_shop_id()

	if candidates.size() == 0:
		var no_candidates = Label.new()
		no_candidates.text = "(No recruits available)"
		no_candidates.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_candidates)
	else:
		for i in range(candidates.size()):
			var candidate = candidates[i]
			var slot_key: String = "recruit_%d" % i
			if GameContext.is_shop_slot_purchased(inn_id, slot_key):
				var empty_row = _create_empty_recruit_slot_row()
				_facility_actions_container.add_child(empty_row)
			else:
				var row = _create_recruit_row(candidate, slot_key)
				_facility_actions_container.add_child(row)


## Create an empty slot row for a recruited hero slot.
func _create_empty_recruit_slot_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var empty_label = Label.new()
	empty_label.text = "[Recruited]"
	empty_label.modulate = Color(0.65, 0.65, 0.65, 1)
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(empty_label)
	return row


## Inn roster view: owned heroes with party management
func _build_inn_roster_view(facility, current_tier: int) -> void:
	# Permadeath warning
	var permadeath_warning = Label.new()
	permadeath_warning.text = "Heroes who fall in the dungeon are lost forever!"
	permadeath_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	permadeath_warning.add_theme_font_size_override("font_size", GameContext.fs(13))
	permadeath_warning.modulate = Color(1.0, 0.6, 0.4, 1)
	_facility_actions_container.add_child(permadeath_warning)

	var selected_party = GameContext.get_selected_party()
	var town_id: String = GameContext.get_current_town_id()

	# Filter to bench heroes at THIS inn only
	var bench_heroes: Array = GameContext.get_inn_bench_heroes(town_id)
	var bench_cap: int = GameContext.get_inn_bench_capacity(town_id)

	# Party + bench status bar
	var party_label = Label.new()
	party_label.text = "Bench: %d / %d  |  Party: %d / %d" % [bench_heroes.size(), bench_cap, selected_party.size(), GameContext.get_max_party_size()]
	party_label.modulate = Color(0.5, 1, 0.5, 1) if selected_party.size() > 0 else Color(0.8, 0.8, 0.8, 1)
	_facility_actions_container.add_child(party_label)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	if GameContext.get_owned_heroes().size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "(No heroes recruited yet)"
		no_heroes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_heroes)
	elif bench_heroes.size() == 0:
		var no_bench = Label.new()
		no_bench.text = "(No heroes benched at this inn)"
		no_bench.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_bench)
	else:
		for hero in bench_heroes:
			var row = _create_hero_row(hero, selected_party)
			_facility_actions_container.add_child(row)

	print("[Inn] roster: town=%s bench=%d/%d party=%d" % [town_id, bench_heroes.size(), bench_cap, selected_party.size()])


## Inn upgrade view: tier tabs with benefits and upgrade button
func _build_inn_upgrade_view(facility, current_tier: int) -> void:
	var max_tier = facility.max_tier
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)
		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var selected_tier = _upgrade_tier_tab

	if selected_tier <= current_tier:
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Unlocked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)
		_build_inn_tier_benefits(facility, selected_tier, current_tier)

	elif selected_tier == current_tier + 1:
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		# Cost + upgrade button (reuse equipment upgrade row pattern)
		var upgrade_row = _create_equipment_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

		var sep2 = HSeparator.new()
		_facility_actions_container.add_child(sep2)
		_build_inn_tier_benefits(facility, selected_tier, current_tier)

	else:
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)


## Display Inn tier benefits (real mechanical stats)
func _build_inn_tier_benefits(facility, tier: int, current_tier: int) -> void:
	var benefits: Array[String] = _get_tier_benefits(facility, tier)
	for benefit_text in benefits:
		var blabel = Label.new()
		blabel.text = benefit_text
		blabel.add_theme_font_size_override("font_size", GameContext.fs(14))
		blabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(blabel)


## Create a hero tile/card for the Inn UI.
## Displays: Name, Race, Class, Level, XP progress, and party controls.
func _create_hero_row(hero: Dictionary, selected_party: Array) -> PanelContainer:
	var hero_id = hero.get("hero_id", "")
	var race_id = hero.get("race_id", "human")
	var class_id = hero.get("class_id", "")
	var hero_name = hero.get("name", "Unknown")
	var hero_level = int(hero.get("level", 1))
	var hero_xp = int(hero.get("xp", 0))
	var in_party = hero_id in selected_party

	# Check if hero is dead (only matters outside town phase)
	var is_hero_dead = false
	if GameContext.get_phase() != GameContext.GamePhase.TOWN:
		var hp_check = GameContext.get_hero_hp(hero_id)
		if not hp_check.is_empty() and int(hp_check.get("current", 1)) <= 0:
			is_hero_dead = true

	# Get display names from DataRegistry with fallback
	var race_name = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	# Create tile container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)

	# Add subtle border style based on party status and death
	var style = StyleBoxFlat.new()
	if is_hero_dead:
		style.bg_color = Color(0.3, 0.1, 0.1, 1)  # Dark red background
		style.border_color = Color(0.6, 0.2, 0.2, 1)  # Red border
	elif in_party:
		style.bg_color = Color(0.1, 0.25, 0.1, 1)
		style.border_color = Color(0.3, 0.6, 0.3, 1)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 1)
		style.border_color = Color(0.3, 0.3, 0.3, 1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Main content HBox (info on left, buttons on right)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Hero portrait (left side)
	var portrait_path: String = hero.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_tex = ResourceLoader.load(portrait_path) as Texture2D
		if portrait_tex != null:
			var portrait_rect = TextureRect.new()
			portrait_rect.texture = portrait_tex
			portrait_rect.custom_minimum_size = Vector2(40, 40)
			portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(portrait_rect)

	# Info VBox (left side)
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name label (larger, bold-ish)
	var name_label = Label.new()
	name_label.text = hero_name
	name_label.add_theme_font_size_override("font_size", GameContext.fs(18))
	if in_party:
		name_label.modulate = Color(0.6, 1, 0.6, 1)
	info_vbox.add_child(name_label)

	# Race label (with tooltip showing description, stat mods, passive)
	var race_label = Label.new()
	race_label.text = "Race: %s" % race_name
	race_label.modulate = Color(0.8, 0.8, 0.8, 1)
	race_label.tooltip_text = build_race_tooltip(hero_id)
	race_label.mouse_filter = Control.MOUSE_FILTER_STOP
	info_vbox.add_child(race_label)

	# Class label (with tooltip showing description, abilities, passives)
	var class_label = Label.new()
	class_label.text = "Class: %s" % cls_name
	class_label.modulate = Color(0.8, 0.8, 0.8, 1)
	class_label.tooltip_text = build_class_tooltip(hero_id)
	class_label.mouse_filter = Control.MOUSE_FILTER_STOP
	info_vbox.add_child(class_label)

	# Level label (with tooltip showing XP progress and stat growth)
	var level_label = Label.new()
	level_label.text = "Lv: %d" % hero_level
	level_label.modulate = Color(0.7, 0.7, 0.9, 1)
	level_label.tooltip_text = build_level_tooltip(hero_id)
	level_label.mouse_filter = Control.MOUSE_FILTER_STOP
	info_vbox.add_child(level_label)

	# XP progress label — uses static format_xp_line() for testability
	var xp_label = Label.new()
	var is_max_level = hero_level >= GameContext.MAX_HERO_LEVEL
	if is_max_level:
		xp_label.text = format_xp_line(hero_xp, 0, true)
		xp_label.modulate = Color(1.0, 0.85, 0.3, 1)  # Gold color for max
	else:
		var next_level_xp = GameContext.get_xp_for_level(hero_level + 1)
		xp_label.text = format_xp_line(hero_xp, next_level_xp, false)
		xp_label.modulate = Color(0.5, 0.8, 1.0, 1)  # Cyan-blue (distinct from green HP)
	# GUARD: If format_xp_line returns wrong prefix, force-correct it
	if not xp_label.text.begins_with("XP:"):
		print("[InnUI] BUG xp_label wrong prefix: '%s' hero=%s  FORCING XP prefix" % [xp_label.text, hero_id])
		xp_label.text = "XP" + xp_label.text.substr(xp_label.text.find(":")) if ":" in xp_label.text else "XP: ???"
	info_vbox.add_child(xp_label)

	# NOTE: Only one HP label in Inn row; always authoritative.
	# In town phase, always show full HP (town reset clears hero_hp on entry).
	# In dungeon, show persisted HP from combat if available.
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var max_hp = int(eff_stats.get("health", 80)) if not eff_stats.is_empty() else 80
	var current_hp = max_hp
	if GameContext.get_phase() != GameContext.GamePhase.TOWN:
		var hp_data = GameContext.get_hero_hp(hero_id)
		if not hp_data.is_empty():
			current_hp = int(hp_data.get("current", max_hp))
	var hp_label = Label.new()
	hp_label.text = format_hp_line(current_hp, max_hp)
	hp_label.tooltip_text = build_inn_stat_tooltip("Health", hero_id)
	hp_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if current_hp >= max_hp:
		hp_label.modulate = Color(0.5, 1.0, 0.5, 1)  # Green = full
	elif current_hp > max_hp * 0.5:
		hp_label.modulate = Color(1.0, 0.9, 0.4, 1)  # Yellow = wounded
	else:
		hp_label.modulate = Color(1.0, 0.4, 0.4, 1)  # Red = critical
	info_vbox.add_child(hp_label)
	print("[InnUI] hero=%s xp_text='%s' hp_text='%s' phase=%s" % [hero_id, xp_label.text, hp_label.text, str(GameContext.get_phase())])

	# Combat stats summary (ATK/DEF/SPD with individual tooltips)
	var atk = int(eff_stats.get("attack", 0))
	var def = int(eff_stats.get("defense", 0))
	var spd = int(eff_stats.get("speed", 0))

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 4)

	var atk_label = Label.new()
	atk_label.text = "ATK: %d" % atk
	atk_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	atk_label.modulate = Color(1.0, 0.6, 0.6, 1)  # Red for attack
	atk_label.tooltip_text = build_inn_stat_tooltip("Attack", hero_id)
	atk_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(atk_label)

	var sep1 = Label.new()
	sep1.text = "|"
	sep1.add_theme_font_size_override("font_size", GameContext.fs(14))
	sep1.modulate = Color(0.78, 0.78, 0.78, 1)
	stats_hbox.add_child(sep1)

	var def_label = Label.new()
	def_label.text = "DEF: %d" % def
	def_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	def_label.modulate = Color(0.6, 0.8, 1.0, 1)  # Blue for defense
	def_label.tooltip_text = build_inn_stat_tooltip("Defense", hero_id)
	def_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(def_label)

	var sep2 = Label.new()
	sep2.text = "|"
	sep2.add_theme_font_size_override("font_size", GameContext.fs(14))
	sep2.modulate = Color(0.78, 0.78, 0.78, 1)
	stats_hbox.add_child(sep2)

	var spd_label = Label.new()
	spd_label.text = "SPD: %d" % spd
	spd_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	spd_label.modulate = Color(0.6, 1.0, 0.6, 1)  # Green for speed
	spd_label.tooltip_text = build_inn_stat_tooltip("Speed", hero_id)
	spd_label.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_hbox.add_child(spd_label)

	info_vbox.add_child(stats_hbox)

	# Equipment display — icon row (all 7 slots + bag)
	var equip = GameContext.get_hero_equipment(hero_id)
	var total_stats = { "health": 0, "attack": 0, "defense": 0, "speed": 0 }

	var slot_abbrevs = {
		"weapon": "WPN", "offhand": "OFF", "helmet": "HLM",
		"armor": "ARM", "legs": "LEG", "ring": "RNG", "amulet": "AMU"
	}

	var equip_hbox = HBoxContainer.new()
	equip_hbox.add_theme_constant_override("separation", 3)
	info_vbox.add_child(equip_hbox)

	for slot in GameContext.EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var item_id = slot_data.get("id", "")
		var quality = int(slot_data.get("quality", 0))
		var abbrev = slot_abbrevs.get(slot, slot.to_upper().left(3))

		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				var region_bonus: float = GameContext.get_completed_region_count() * 0.1
				var stats = tpl.get_stat_bonuses_with_quality(quality, region_bonus)
				for stat_key in stats:
					if total_stats.has(stat_key):
						total_stats[stat_key] += stats[stat_key]
				var slot_affix_stats = slot_data.get("affix_stats", {})
				if slot_affix_stats is Dictionary:
					for ak in slot_affix_stats:
						if total_stats.has(ak):
							total_stats[ak] += int(slot_affix_stats[ak])
				var icon_node = tpl.create_bordered_icon(32, quality)
				if icon_node != null:
					icon_node.tooltip_text = _build_equipment_slot_tooltip(slot, item_id, quality, slot_data)
					icon_node.mouse_filter = Control.MOUSE_FILTER_STOP
					equip_hbox.add_child(icon_node)
				else:
					equip_hbox.add_child(_create_empty_equip_slot(abbrev, 32))
			else:
				equip_hbox.add_child(_create_empty_equip_slot(abbrev, 32))
		else:
			equip_hbox.add_child(_create_empty_equip_slot(abbrev, 32))

	# Bag icon (8th slot)
	var bag_item_id = GameContext.get_hero_bag_item(hero_id)
	var bag_quality = GameContext.get_hero_bag_quality(hero_id)
	if bag_item_id != "":
		var bag_tpl = DataRegistry.get_item_template(bag_item_id)
		if bag_tpl != null:
			var bag_icon = bag_tpl.create_bordered_icon(32, bag_quality)
			if bag_icon != null:
				var bag_summary = GameContext.get_hero_bag_summary(hero_id)
				bag_icon.tooltip_text = "Bag: %s (Q%d)\n%s" % [bag_tpl.display_name, bag_quality, bag_summary]
				bag_icon.mouse_filter = Control.MOUSE_FILTER_STOP
				equip_hbox.add_child(bag_icon)
			else:
				equip_hbox.add_child(_create_empty_equip_slot("BAG", 32))
		else:
			equip_hbox.add_child(_create_empty_equip_slot("BAG", 32))
	else:
		equip_hbox.add_child(_create_empty_equip_slot("BAG", 32))

	# Gear Bonus summary line (totals from all 7 equipment slots)
	var gear_bonus_label = Label.new()
	if total_stats.health > 0 or total_stats.attack > 0 or total_stats.defense > 0 or total_stats.speed > 0:
		gear_bonus_label.text = "Gear: HP+%d ATK+%d DEF+%d SPD+%d" % [
			total_stats.health, total_stats.attack, total_stats.defense, total_stats.speed]
		gear_bonus_label.modulate = Color(0.6, 0.9, 0.6, 1)
	else:
		gear_bonus_label.text = "Gear: (none equipped)"
		gear_bonus_label.modulate = Color(0.7, 0.7, 0.7, 1)
	gear_bonus_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	info_vbox.add_child(gear_bonus_label)

	# Buttons VBox (right side)
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(btn_vbox)

	# Party button
	var party_btn = Button.new()
	party_btn.custom_minimum_size = Vector2(100, 28)
	if in_party:
		party_btn.text = "Remove"
		party_btn.pressed.connect(_on_remove_from_party_pressed.bind(hero_id))
	else:
		party_btn.text = "Add to Party"
		party_btn.disabled = selected_party.size() >= GameContext.get_max_party_size()
		party_btn.pressed.connect(_on_add_to_party_pressed.bind(hero_id))
	btn_vbox.add_child(party_btn)

	# Row selector and Manage Gear moved to Party Bar cards

	# Rename button
	var rename_btn = Button.new()
	rename_btn.custom_minimum_size = Vector2(100, 28)
	rename_btn.text = "Rename"
	rename_btn.pressed.connect(_on_rename_hero_pressed.bind(hero_id))
	btn_vbox.add_child(rename_btn)

	# Dismiss button (disabled if in party)
	var dismiss_btn = Button.new()
	dismiss_btn.custom_minimum_size = Vector2(100, 28)
	dismiss_btn.text = "Dismiss"
	dismiss_btn.disabled = in_party
	dismiss_btn.modulate = Color(1, 0.6, 0.6, 1) if not in_party else Color(0.7, 0.7, 0.7, 1)
	dismiss_btn.pressed.connect(_on_inn_dismiss_hero_pressed.bind(hero_id))
	btn_vbox.add_child(dismiss_btn)

	# --- DUP_HP sanity check + full label dump (debug only, non-fatal) ---
	var hp_count := 0
	var all_labels: Array[String] = []
	for child_node in info_vbox.get_children():
		if child_node is Label:
			var lbl := child_node as Label
			all_labels.append(lbl.text)
			if lbl.text.begins_with("HP:"):
				hp_count += 1
	if hp_count != 1:
		print("[InnUI] DUP_HP hero=%s count=%d all_labels=%s node=%s" % [hero_id, hp_count, str(all_labels), str(panel.get_path()) if panel.is_inside_tree() else "not_in_tree"])

	# Add DEAD overlay if hero is dead
	if is_hero_dead:
		var dead_label = Label.new()
		dead_label.text = "DEAD — Lost Forever"
		dead_label.add_theme_font_size_override("font_size", GameContext.fs(30))
		dead_label.modulate = Color(1.0, 0.3, 0.3, 0.9)
		dead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dead_label.set_anchors_preset(Control.PRESET_CENTER)
		dead_label.z_index = 10
		panel.add_child(dead_label)
		# Dim the content behind
		hbox.modulate = Color(0.7, 0.7, 0.7, 0.85)

	return panel


func _create_recruit_row(candidate: Dictionary, slot_key: String = "") -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var race_id = candidate.get("race_id", "human")  # Default to human for Region 1
	var class_id = candidate.get("class_id", "")
	var cost = candidate.get("cost_gold", 50)
	var level = candidate.get("level", 1)
	var can_afford = GameContext.get_run_gold() >= cost

	# Get display names from DataRegistry with fallback to capitalize()
	var race_name = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	# Race portrait (deterministic index from race+class so it stays stable across refreshes)
	if race_data != null and race_data.portraits.size() > 0:
		var p_idx: int = (race_id + class_id).hash() % race_data.portraits.size()
		if p_idx < 0:
			p_idx = -p_idx
		var p_path: String = race_data.portraits[p_idx]
		if ResourceLoader.exists(p_path):
			var p_tex = ResourceLoader.load(p_path) as Texture2D
			if p_tex != null:
				var p_rect = TextureRect.new()
				p_rect.texture = p_tex
				p_rect.custom_minimum_size = Vector2(32, 32)
				p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				p_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(p_rect)

	# Race + Class + Level label
	var label = Label.new()
	label.text = "%s %s Lv %d (%d gold)" % [race_name, cls_name, level, cost]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	# Show starting equipment if any (T2+ inn)
	var starting_equipment: Array = candidate.get("starting_equipment", [])
	if starting_equipment.size() > 0:
		var equip_names: Array = []
		for eq in starting_equipment:
			var eq_tpl = DataRegistry.get_item_template(eq.get("item_id", ""))
			if eq_tpl != null:
				var suffix: String = " (Bag)" if eq.get("slot", "") == "bag_item" else ""
				equip_names.append(eq_tpl.display_name + suffix)
		if equip_names.size() > 0:
			var equip_label = Label.new()
			equip_label.text = "+" + ", ".join(equip_names)
			equip_label.add_theme_font_size_override("font_size", GameContext.fs(12))
			equip_label.modulate = Color(0.6, 0.9, 0.6, 1)
			row.add_child(equip_label)

	# Recruit button — disabled if can't afford OR if party + bench are both full
	var recruit_town: String = GameContext.get_current_town_id()
	var recruit_party_full: bool = GameContext.get_selected_party().size() >= GameContext.get_max_party_size()
	var recruit_bench_full: bool = not GameContext.can_bench_at_inn(recruit_town)
	var btn = Button.new()
	btn.text = "Recruit"
	btn.custom_minimum_size = Vector2(80, 26)
	btn.disabled = not can_afford or (recruit_party_full and recruit_bench_full)
	btn.pressed.connect(_on_recruit_hero_pressed.bind(class_id, cost, race_id, level, slot_key, starting_equipment))
	row.add_child(btn)

	return row


func _on_add_to_party_pressed(hero_id: String) -> void:
	GameContext.add_to_party(hero_id)
	_refresh_facility_panel()


func _on_remove_from_party_pressed(hero_id: String) -> void:
	GameContext.remove_from_party(hero_id)
	_refresh_facility_panel()


## Handle hero row assignment change (3-Row Formation v1)
func _on_hero_row_changed(row_index: int, hero_id: String) -> void:
	GameContext.set_hero_row(hero_id, row_index)
	var row_names = ["Front", "Middle", "Back"]
	print("[Inn] Hero %s assigned to %s row" % [hero_id, row_names[row_index]])


## Handle hero row assignment change from party bar card.
func _on_party_card_row_changed(row_index: int, hero_id: String) -> void:
	GameContext.set_hero_row(hero_id, row_index)
	var row_names = ["Front", "Middle", "Back"]
	print("[PartyBar] Hero %s assigned to %s row" % [hero_id, row_names[row_index]])
	_populate_heroes_section()


func _on_equip_slot_pressed(hero_id: String, slot: String) -> void:
	# Show equip selection popup for this hero and slot
	_show_equip_selection_popup(hero_id, slot)


## Show popup to manage all 8 equipment slots for a hero.
func _on_manage_gear_pressed(hero_id: String) -> void:
	_close_manage_gear_overlay()
	_manage_gear_hero_id = hero_id
	_manage_gear_filter = "party"
	_open_manage_gear_overlay()


func _open_manage_gear_overlay() -> void:
	_manage_gear_overlay = CanvasLayer.new()
	_manage_gear_overlay.layer = 10
	add_child(_manage_gear_overlay)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_manage_gear_overlay()
	)
	_manage_gear_overlay.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_manage_gear_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	style.set_border_width_all(2)
	style.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Viewport-relative height: 70% of screen, capped at 700px
	var vp_h: int = int(get_viewport().get_visible_rect().size.y)
	scroll.custom_minimum_size = Vector2(0, mini(int(vp_h * 0.7), 700))
	panel.add_child(scroll)

	_manage_gear_content = VBoxContainer.new()
	_manage_gear_content.add_theme_constant_override("separation", 4)
	_manage_gear_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_manage_gear_content)

	# Register with ESC-close stack
	UIAudio.register_closeable(_manage_gear_overlay, _close_manage_gear_overlay)

	_build_manage_gear_content()

	# Tutorial: first time opening Manage Gear
	TutorialOverlay.try_show(self, "tutorial_manage_roster")


func _build_manage_gear_content() -> void:
	for child in _manage_gear_content.get_children():
		child.queue_free()

	# ---- Filter tab row: [Party] [Town1 (N)] [Town2 (N)] ... ----
	var filter_row = HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 4)
	_manage_gear_content.add_child(filter_row)

	# Party tab
	var party_tab = Button.new()
	party_tab.text = "Party"
	party_tab.custom_minimum_size = Vector2(60, 26)
	party_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _manage_gear_filter == "party":
		var tab_style = StyleBoxFlat.new()
		tab_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
		tab_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
		tab_style.set_border_width_all(2)
		tab_style.set_corner_radius_all(4)
		party_tab.add_theme_stylebox_override("normal", tab_style)
	party_tab.pressed.connect(func():
		_manage_gear_filter = "party"
		_manage_gear_hero_id = ""
		_build_manage_gear_content()
	)
	filter_row.add_child(party_tab)

	# Town bench tabs — show towns with bench heroes or current town
	var current_town: String = GameContext.get_current_town_id()
	var all_regions = DataRegistry.get_all_regions()
	for region in all_regions:
		if region == null:
			continue
		for town_id in region.town_ids:
			var bench_count: int = GameContext.get_inn_bench_count(town_id)
			if bench_count == 0 and town_id != current_town:
				continue
			var town_data = DataRegistry.get_town(town_id)
			var town_name: String = town_data.display_name if town_data != null else town_id
			var tab_btn = Button.new()
			tab_btn.text = "%s (%d)" % [town_name, bench_count]
			tab_btn.custom_minimum_size = Vector2(60, 26)
			tab_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if _manage_gear_filter == town_id:
				var tab_style = StyleBoxFlat.new()
				tab_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
				tab_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
				tab_style.set_border_width_all(2)
				tab_style.set_corner_radius_all(4)
				tab_btn.add_theme_stylebox_override("normal", tab_style)
			var bound_town: String = town_id
			tab_btn.pressed.connect(func():
				_manage_gear_filter = bound_town
				_manage_gear_hero_id = ""
				_build_manage_gear_content()
			)
			filter_row.add_child(tab_btn)

	# ---- Build hero list based on filter ----
	var roster: Array = []
	var hero_ids_in_filter: Array = []
	if _manage_gear_filter == "party":
		var party_ids: Array = GameContext.get_selected_party()
		for pid in party_ids:
			var hdata: Dictionary = GameContext.get_hero(pid)
			if not hdata.is_empty():
				roster.append(hdata)
				hero_ids_in_filter.append(pid)
	else:
		# Town bench filter
		var bench_heroes: Array = GameContext.get_inn_bench_heroes(_manage_gear_filter)
		for hdata in bench_heroes:
			roster.append(hdata)
			hero_ids_in_filter.append(hdata.get("hero_id", ""))

	if roster.is_empty():
		var empty_lbl = Label.new()
		if _manage_gear_filter == "party":
			empty_lbl.text = "(No heroes in party)"
		else:
			empty_lbl.text = "(No heroes benched at this inn)"
		empty_lbl.modulate = Color(0.78, 0.78, 0.78, 1)
		_manage_gear_content.add_child(empty_lbl)
		return

	var hero_id: String = _manage_gear_hero_id
	# If current hero is not in filtered list, default to first hero
	if hero_id == "" or hero_id not in hero_ids_in_filter:
		hero_id = hero_ids_in_filter[0]
		_manage_gear_hero_id = hero_id

	# ---- Hero selector row with portraits ----
	var hero_row = HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 6)
	_manage_gear_content.add_child(hero_row)

	for hero_data in roster:
		var hid: String = hero_data.get("hero_id", "")
		var is_selected: bool = (hid == hero_id)
		var hero_btn_vbox = VBoxContainer.new()
		hero_btn_vbox.add_theme_constant_override("separation", 2)

		var portrait_btn = Button.new()
		portrait_btn.custom_minimum_size = Vector2(44, 44)
		portrait_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var pp: String = hero_data.get("portrait_path", "")
		if pp != "" and ResourceLoader.exists(pp):
			var ptex = ResourceLoader.load(pp) as Texture2D
			if ptex:
				portrait_btn.icon = ptex
				portrait_btn.expand_icon = true
		else:
			portrait_btn.text = hid.left(2).to_upper()
		if is_selected:
			var sel_style = StyleBoxFlat.new()
			sel_style.bg_color = Color(0.1, 0.2, 0.15, 0.9)
			sel_style.border_color = Color(0.3, 0.8, 0.6, 0.9)
			sel_style.set_border_width_all(2)
			sel_style.set_corner_radius_all(4)
			portrait_btn.add_theme_stylebox_override("normal", sel_style)
		portrait_btn.pressed.connect(func():
			_manage_gear_hero_id = hid
			_build_manage_gear_content()
		)
		hero_btn_vbox.add_child(portrait_btn)

		var nlbl = Label.new()
		nlbl.text = hero_data.get("name", "?")
		nlbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		nlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nlbl.modulate = Color(0.5, 1.0, 0.8, 1) if is_selected else Color(0.7, 0.7, 0.7, 1)
		hero_btn_vbox.add_child(nlbl)
		hero_row.add_child(hero_btn_vbox)

	_manage_gear_content.add_child(HSeparator.new())

	# ---- Selected hero info ----
	var hero: Dictionary = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return

	var hero_name: String = hero.get("name", "Unknown")
	var race_id: String = hero.get("race_id", "human")
	var class_id: String = hero.get("class_id", "")
	var hero_level: int = int(hero.get("level", 1))
	var race_data = DataRegistry.get_race(race_id)
	var class_data = DataRegistry.get_class_data(class_id)
	var race_name: String = race_data.display_name if race_data and race_data.display_name != "" else race_id.capitalize()
	var cls_name: String = class_data.display_name if class_data and class_data.display_name != "" else class_id.capitalize()

	# Two-column: identity+stats | abilities+passives
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	_manage_gear_content.add_child(columns)

	# LEFT: Identity + Stats
	var left_col = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	var identity_hbox = HBoxContainer.new()
	identity_hbox.add_theme_constant_override("separation", 8)
	left_col.add_child(identity_hbox)

	var portrait_path: String = hero.get("portrait_path", "")
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var ptex = ResourceLoader.load(portrait_path) as Texture2D
		if ptex:
			var portrait_rect = TextureRect.new()
			portrait_rect.texture = ptex
			portrait_rect.custom_minimum_size = Vector2(64, 64)
			portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			identity_hbox.add_child(portrait_rect)

	var identity_vbox = VBoxContainer.new()
	identity_vbox.add_theme_constant_override("separation", 1)
	identity_hbox.add_child(identity_vbox)

	var name_header = Label.new()
	name_header.text = hero_name
	name_header.add_theme_font_size_override("font_size", GameContext.fs(18))
	name_header.modulate = Color(0.9, 0.8, 0.5, 1)
	identity_vbox.add_child(name_header)

	var race_lbl = Label.new()
	race_lbl.text = "%s  %s  Lv %d" % [race_name, cls_name, hero_level]
	race_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	race_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
	identity_vbox.add_child(race_lbl)

	# XP progress line
	var hero_xp: int = int(hero.get("xp", 0))
	var is_max_level: bool = hero_level >= GameContext.MAX_HERO_LEVEL
	var xp_lbl = Label.new()
	if is_max_level:
		xp_lbl.text = format_xp_line(hero_xp, 0, true)
		xp_lbl.modulate = Color(1.0, 0.85, 0.3, 1)
	else:
		var next_level_xp: int = GameContext.get_xp_for_level(hero_level + 1)
		xp_lbl.text = format_xp_line(hero_xp, next_level_xp, false)
		xp_lbl.modulate = Color(0.5, 0.8, 1.0, 1)
	xp_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
	xp_lbl.tooltip_text = build_level_tooltip(hero_id)
	xp_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	identity_vbox.add_child(xp_lbl)

	# Stats grid
	var eff_stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
	var stat_defs: Array = [
		{"key": "health", "label": "HP", "color": Color(0.4, 0.9, 0.4, 1)},
		{"key": "attack", "label": "ATK", "color": Color(0.9, 0.5, 0.4, 1)},
		{"key": "defense", "label": "DEF", "color": Color(0.5, 0.7, 0.9, 1)},
		{"key": "speed", "label": "SPD", "color": Color(0.9, 0.9, 0.4, 1)},
		{"key": "crit_chance", "label": "CRIT", "color": Color(1.0, 0.7, 0.3, 1)},
		{"key": "evasion", "label": "EVD", "color": Color(0.6, 0.9, 0.6, 1)},
		{"key": "resist", "label": "RES", "color": Color(0.7, 0.5, 0.9, 1)},
		{"key": "thorns", "label": "THN", "color": Color(0.8, 0.4, 0.4, 1)},
		{"key": "armor_penetration", "label": "PEN", "color": Color(0.9, 0.6, 0.5, 1)},
		{"key": "life_steal", "label": "LSTL", "color": Color(0.8, 0.3, 0.3, 1)},
	]
	var stat_descriptions: Dictionary = {
		"health": "HP (Hit Points)\nHero is defeated at 0 HP.\nRestored by healing effects and potions.",
		"attack": "ATK (Attack Power)\nDetermines physical damage dealt.\nDamage = max(1, ATK - target DEF)",
		"defense": "DEF (Defense)\nReduces incoming physical damage.\nDamage = max(1, attacker ATK - DEF)",
		"speed": "SPD (Speed)\nDetermines turn order each round.\nHigher speed acts first.\n10+ = 2 actions per turn\n20+ = 3 actions per turn",
		"crit_chance": "CRIT (Critical Hit Chance)\n% chance to deal 1.5x damage.\nCapped at 50%.",
		"evasion": "EVD (Evasion)\n% chance to dodge attacks.\nCapped at 50%.",
		"resist": "RES (Resistance)\nReduces fire, dark, and void damage.\nUses same soft-cap as defense.",
		"thorns": "THN (Thorns)\nFlat damage returned to physical attackers.\nBypasses defense (true damage).",
		"armor_penetration": "PEN (Armor Penetration)\nReduces target's effective defense.\nApplied before defense soft-cap.",
		"life_steal": "LSTL (Life Steal)\n% of damage dealt healed.\nOnly from direct attacks, not DOTs.",
	}

	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 2)
	left_col.add_child(stats_grid)

	# Core stats always shown; new stats only shown if > 0
	var mg_core_keys = ["health", "attack", "defense", "speed"]
	for sd in stat_defs:
		var val = int(eff_stats.get(sd.key, 0))
		if val == 0 and sd.key not in mg_core_keys:
			continue
		var stat_label = Label.new()
		stat_label.text = sd.label
		stat_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_label.modulate = sd.color
		stat_label.custom_minimum_size = Vector2(32, 0)
		stat_label.mouse_filter = Control.MOUSE_FILTER_STOP
		stat_label.tooltip_text = stat_descriptions.get(sd.key, sd.label)
		stats_grid.add_child(stat_label)

		var stat_val = Label.new()
		stat_val.text = str(val)
		stat_val.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_val.modulate = Color(0.9, 0.9, 0.9, 1)
		stat_val.tooltip_text = build_inn_stat_tooltip(sd.key.capitalize(), hero_id)
		stat_val.mouse_filter = Control.MOUSE_FILTER_STOP
		stats_grid.add_child(stat_val)

	# RIGHT: Abilities + Passives
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	var ab_header = Label.new()
	ab_header.text = "Abilities"
	ab_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	ab_header.modulate = Color(0.9, 0.8, 0.5, 1)
	right_col.add_child(ab_header)

	if class_data:
		for ab_info in [{"id": class_data.ability_a_id, "tag": "A", "slot": "ability_a"}, {"id": class_data.ability_b_id, "tag": "B", "slot": "ability_b"}]:
			if ab_info.id == "":
				continue
			var ability = DataRegistry.get_ability(ab_info.id)
			var ab_name: String = ability.display_name if ability else ab_info.id.replace("_", " ").capitalize()
			var ab_desc: String = ability.description if ability and ability.description != "" else ""
			var unlocked: bool = GameContext.is_ability_slot_unlocked(ab_info.slot, hero_level)
			var ab_lbl = Label.new()
			if unlocked:
				ab_lbl.text = "%s: %s" % [ab_info.tag, ab_name]
				ab_lbl.modulate = Color(0.8, 0.9, 1.0, 1)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ab_info.slot, 1)
				ab_lbl.text = "%s: %s (Lv %d)" % [ab_info.tag, ab_name, req_lv]
				ab_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
			ab_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			if ab_desc != "":
				ab_lbl.tooltip_text = ab_desc
				ab_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			right_col.add_child(ab_lbl)

	var ps_header = Label.new()
	ps_header.text = "Passives"
	ps_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	ps_header.modulate = Color(0.9, 0.8, 0.5, 1)
	right_col.add_child(ps_header)

	if class_data:
		for ps_info in [{"id": class_data.passive_a_id, "tag": "1", "slot": "passive_a"}, {"id": class_data.passive_b_id, "tag": "2", "slot": "passive_b"}]:
			if ps_info.id == "":
				continue
			var passive = DataRegistry.get_passive(ps_info.id)
			var ps_name: String = passive.display_name if passive else ps_info.id.replace("_", " ").capitalize()
			var ps_desc: String = passive.description if passive and passive.description != "" else ""
			var ps_unlocked: bool = GameContext.is_ability_slot_unlocked(ps_info.slot, hero_level)
			var ps_lbl = Label.new()
			if ps_unlocked:
				ps_lbl.text = "%s: %s" % [ps_info.tag, ps_name]
				ps_lbl.modulate = Color(0.7, 0.85, 0.7, 1)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ps_info.slot, 1)
				ps_lbl.text = "%s: %s (Lv %d)" % [ps_info.tag, ps_name, req_lv]
				ps_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
			ps_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			if ps_desc != "":
				ps_lbl.tooltip_text = ps_desc
				ps_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			right_col.add_child(ps_lbl)

	if race_data and race_data.racial_passive_id != "":
		var rp = DataRegistry.get_passive(race_data.racial_passive_id)
		var rp_name: String = rp.display_name if rp else race_data.racial_passive_id.replace("_", " ").capitalize()
		var rp_desc: String = rp.description if rp and rp.description != "" else ""
		var rp_lbl = Label.new()
		rp_lbl.text = "R: %s" % rp_name
		rp_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		rp_lbl.modulate = Color(0.7, 0.85, 0.7, 1)
		if rp_desc != "":
			rp_lbl.tooltip_text = rp_desc
			rp_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		right_col.add_child(rp_lbl)

	# ---- Equipment Section ----
	var sep1 = HSeparator.new()
	_manage_gear_content.add_child(sep1)

	var gear_header = Label.new()
	gear_header.text = "Equipment"
	gear_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	gear_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_manage_gear_content.add_child(gear_header)

	var equip: Dictionary = GameContext.get_hero_equipment(hero_id)
	var slot_names: Dictionary = {
		"weapon": "Weapon", "offhand": "Offhand", "helmet": "Helmet",
		"armor": "Armor", "legs": "Legs", "ring": "Ring", "amulet": "Amulet", "bag": "Bag"
	}

	for slot in GameContext.ALL_EQUIP_SLOTS:
		var slot_hbox = HBoxContainer.new()
		slot_hbox.add_theme_constant_override("separation", 6)
		_manage_gear_content.add_child(slot_hbox)

		var slot_label = Label.new()
		slot_label.text = "%s:" % slot_names.get(slot, slot.capitalize())
		slot_label.custom_minimum_size = Vector2(55, 0)
		slot_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		slot_label.modulate = Color(0.7, 0.7, 0.7, 1)
		slot_hbox.add_child(slot_label)

		var slot_data: Dictionary = equip.get(slot, {})
		var item_id: String = slot_data.get("id", "")
		var quality: int = int(slot_data.get("quality", 0))

		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl:
				var icon_node = tpl.create_bordered_icon(24, quality)
				if icon_node:
					icon_node.tooltip_text = _build_equipment_slot_tooltip(slot, item_id, quality, slot_data)
					icon_node.mouse_filter = Control.MOUSE_FILTER_STOP
					slot_hbox.add_child(icon_node)
				var prefix: String = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
				var affix_prefix: String = slot_data.get("affix_prefix", "")
				var full_name: String = ""
				if affix_prefix != "":
					full_name = "%s %s%s" % [affix_prefix, prefix, tpl.display_name]
				else:
					full_name = "%s%s" % [prefix, tpl.display_name]
				var item_lbl = Label.new()
				item_lbl.text = full_name
				item_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
				item_lbl.modulate = ItemInstance.QUALITY_COLORS[clampi(quality, 0, 3)]
				item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				item_lbl.tooltip_text = _build_equipment_slot_tooltip(slot, item_id, quality, slot_data)
				item_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
				slot_hbox.add_child(item_lbl)
			else:
				var unk_lbl = Label.new()
				unk_lbl.text = "(unknown)"
				unk_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
				unk_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
				unk_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				slot_hbox.add_child(unk_lbl)
		else:
			var empty_lbl = Label.new()
			empty_lbl.text = "(empty)"
			empty_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			empty_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
			empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_hbox.add_child(empty_lbl)

		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(50, 22)
		equip_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		var captured_slot: String = slot
		equip_btn.pressed.connect(func():
			_on_equip_slot_pressed(hero_id, captured_slot)
		)
		slot_hbox.add_child(equip_btn)

		if item_id != "":
			var unequip_btn = Button.new()
			unequip_btn.text = "X"
			unequip_btn.custom_minimum_size = Vector2(24, 22)
			unequip_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			unequip_btn.tooltip_text = "Unequip to stash"
			var captured_unequip_slot: String = slot
			unequip_btn.pressed.connect(func():
				GameContext.unequip_hero_item(hero_id, captured_unequip_slot)
				_build_manage_gear_content()
			)
			slot_hbox.add_child(unequip_btn)

	# ---- Bag Section ----
	var sep2 = HSeparator.new()
	_manage_gear_content.add_child(sep2)

	var bag_capacity: int = GameContext.get_hero_bag_capacity(hero_id)
	var bag_items: Array = GameContext.get_hero_bag(hero_id)
	var bag_header = Label.new()
	bag_header.text = "Bag (%d/%d)" % [bag_items.size(), bag_capacity]
	bag_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	bag_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_manage_gear_content.add_child(bag_header)

	for i in range(bag_items.size()):
		var entry: Dictionary = bag_items[i]
		var bag_item_id: String = entry.get("item_id", "")
		var bag_hbox = HBoxContainer.new()
		bag_hbox.add_theme_constant_override("separation", 6)
		_manage_gear_content.add_child(bag_hbox)

		var btpl = DataRegistry.get_item_template(bag_item_id)
		if btpl:
			var bicon = btpl.create_bordered_icon(20, 0)
			if bicon:
				bicon.mouse_filter = Control.MOUSE_FILTER_STOP
				bicon.tooltip_text = btpl.display_name
				bag_hbox.add_child(bicon)

		var bag_item_lbl = Label.new()
		bag_item_lbl.text = btpl.display_name if btpl else bag_item_id
		bag_item_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		bag_item_lbl.modulate = Color(0.7, 0.9, 0.7, 1)
		bag_item_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_hbox.add_child(bag_item_lbl)

		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(55, 22)
		remove_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		var captured_bag_id: String = bag_item_id
		remove_btn.pressed.connect(func():
			GameContext.move_item_hero_bag_to_stash(hero_id, captured_bag_id)
			_build_manage_gear_content()
		)
		bag_hbox.add_child(remove_btn)

	if bag_items.size() < bag_capacity:
		var add_btn = Button.new()
		add_btn.text = "Add Item to Bag"
		add_btn.custom_minimum_size = Vector2(120, 24)
		add_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		add_btn.pressed.connect(func():
			_close_manage_gear_overlay()
			_show_bag_item_selection(hero_id)
		)
		_manage_gear_content.add_child(add_btn)

	# ---- Close Button ----
	var sep3 = HSeparator.new()
	_manage_gear_content.add_child(sep3)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 28)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_manage_gear_overlay)
	_manage_gear_content.add_child(close_btn)


func _close_manage_gear_overlay() -> void:
	if _manage_gear_overlay != null and is_instance_valid(_manage_gear_overlay):
		UIAudio.unregister_closeable(_manage_gear_overlay)
		_manage_gear_overlay.queue_free()
		_manage_gear_overlay = null
		_manage_gear_content = null
		_refresh_facility_panel()


## Open bag select overlay from party bar — shows consumables from storage.
func _on_party_card_bag_pressed(hero_id: String) -> void:
	if _bag_select_overlay != null:
		_close_bag_select_overlay()
	_bag_select_hero_id = hero_id
	_bag_select_overlay = CanvasLayer.new()
	_bag_select_overlay.layer = 10
	add_child(_bag_select_overlay)

	# Backdrop — click to close
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_bag_select_overlay()
	)
	_bag_select_overlay.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bag_select_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	style.set_border_width_all(2)
	style.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var vp_h: int = int(get_viewport().get_visible_rect().size.y)
	scroll.custom_minimum_size = Vector2(0, mini(int(vp_h * 0.5), 400))
	panel.add_child(scroll)

	_bag_select_content = VBoxContainer.new()
	_bag_select_content.add_theme_constant_override("separation", 4)
	_bag_select_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_bag_select_content)

	UIAudio.register_closeable(_bag_select_overlay, _close_bag_select_overlay)
	_build_bag_select_content()


## Build/rebuild the consumable list inside the bag select overlay.
func _build_bag_select_content() -> void:
	for child in _bag_select_content.get_children():
		child.queue_free()

	var hero = GameContext.get_hero(_bag_select_hero_id)
	var hero_name: String = hero.get("name", _bag_select_hero_id) if hero != null else _bag_select_hero_id
	var bag = GameContext.get_hero_bag(_bag_select_hero_id)
	var cap = GameContext.get_hero_bag_capacity(_bag_select_hero_id)
	var bag_full: bool = bag.size() >= cap

	# Header
	var header = Label.new()
	header.text = "%s — Bag (%d/%d)" % [hero_name, bag.size(), cap]
	header.add_theme_font_size_override("font_size", GameContext.fs(16))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(1.0, 0.85, 0.4, 1)
	_bag_select_content.add_child(header)

	_bag_select_content.add_child(HSeparator.new())

	# Current bag contents (read-only display)
	if bag.size() > 0:
		for entry in bag:
			var tpl = DataRegistry.get_item_template(entry.get("item_id", ""))
			var dname: String = tpl.display_name if tpl != null else entry.get("item_id", "")
			var qty: int = int(entry.get("qty", 1))
			var item_lbl = Label.new()
			item_lbl.text = "  %s x%d" % [dname, qty]
			item_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			item_lbl.modulate = Color(0.6, 0.9, 0.6, 1)
			_bag_select_content.add_child(item_lbl)
		_bag_select_content.add_child(HSeparator.new())

	if bag_full:
		var full_lbl = Label.new()
		full_lbl.text = "Bag Full"
		full_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		full_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		full_lbl.modulate = Color(0.8, 0.3, 0.3, 1)
		_bag_select_content.add_child(full_lbl)
		return

	# Collect consumables from storage (run_items)
	var consumable_map: Dictionary = {}
	for inst in GameContext.run_items:
		var iid: String = inst.template_id if inst is ItemInstance else inst.get("item_id", inst.get("template_id", ""))
		if iid == "":
			continue
		var tpl = DataRegistry.get_item_template(iid)
		if tpl == null or tpl.item_type != "consumable":
			continue
		var q: int = int(inst.qty) if inst is ItemInstance else int(inst.get("qty", 1))
		consumable_map[iid] = consumable_map.get(iid, 0) + q

	if consumable_map.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No consumables in storage"
		empty_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		empty_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bag_select_content.add_child(empty_lbl)
		return

	# List each consumable with Equip button
	for item_id in consumable_map:
		var tpl = DataRegistry.get_item_template(item_id)
		var qty: int = consumable_map[item_id]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		_bag_select_content.add_child(hbox)

		var name_lbl = Label.new()
		name_lbl.text = "%s (x%d)" % [tpl.display_name, qty]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		hbox.add_child(name_lbl)

		var equip_btn = Button.new()
		equip_btn.text = "Equip"
		equip_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		equip_btn.custom_minimum_size = Vector2(60, 24)
		var captured_id: String = item_id
		equip_btn.pressed.connect(func():
			_on_bag_select_equip(captured_id)
		)
		hbox.add_child(equip_btn)


## Handle equip button press in bag select overlay.
func _on_bag_select_equip(item_id: String) -> void:
	var success: bool = GameContext.move_item_stash_to_hero_bag(_bag_select_hero_id, item_id)
	if not success:
		print("[BagSelect] Failed to move %s to hero %s bag" % [item_id, _bag_select_hero_id])
		return
	print("[BagSelect] Equipped %s to hero %s bag" % [item_id, _bag_select_hero_id])

	# Check if bag is now full → auto-close
	var bag = GameContext.get_hero_bag(_bag_select_hero_id)
	var cap = GameContext.get_hero_bag_capacity(_bag_select_hero_id)
	if bag.size() >= cap:
		_close_bag_select_overlay()
		_populate_heroes_section()
		return

	# Refresh list in-place (still room left)
	_build_bag_select_content()
	_populate_heroes_section()


## Close the bag select overlay.
func _close_bag_select_overlay() -> void:
	if _bag_select_overlay != null:
		UIAudio.unregister_closeable(_bag_select_overlay)
		_bag_select_overlay.queue_free()
		_bag_select_overlay = null
	_bag_select_hero_id = ""
	_bag_select_content = null
	_populate_heroes_section()


func _on_unequip_slot_pressed(hero_id: String, slot: String) -> void:
	GameContext.unequip_hero_item(hero_id, slot)
	_refresh_facility_panel()


## Show popup to select an item from stash to add to a hero's bag inventory.
func _show_bag_item_selection(hero_id: String) -> void:
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero != null else hero_id

	# Gather all stash items that could go in a bag
	var stash_items: Array = []
	for item_id in GameContext.player_items:
		var qty = GameContext.player_items[item_id]
		if qty <= 0:
			continue
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl == null:
			continue
		stash_items.append({"item_id": item_id, "qty": qty, "template": tpl})

	# Also check run_items (ItemInstance array)
	var run_item_map: Dictionary = {}
	for inst in GameContext.run_items:
		var iid = inst.template_id if inst is ItemInstance else inst.get("item_id", inst.get("template_id", ""))
		if iid == "":
			continue
		run_item_map[iid] = run_item_map.get(iid, 0) + 1
	for item_id in run_item_map:
		if GameContext.player_items.has(item_id) and GameContext.player_items[item_id] > 0:
			continue  # Already counted above
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl == null:
			continue
		stash_items.append({"item_id": item_id, "qty": run_item_map[item_id], "template": tpl})

	var popup = PopupPanel.new()
	popup.name = "BagItemSelectPopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	popup.add_child(vbox)

	var title = Label.new()
	title.text = "Add to %s's Bag" % hero_name
	title.add_theme_font_size_override("font_size", GameContext.fs(16))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	if stash_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(No items in stash)"
		empty_label.modulate = Color(0.7, 0.7, 0.7, 1)
		vbox.add_child(empty_label)
	else:
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(320, 250)
		vbox.add_child(scroll)
		var list_vbox = VBoxContainer.new()
		list_vbox.add_theme_constant_override("separation", 2)
		scroll.add_child(list_vbox)

		for entry in stash_items:
			var item_id = entry.item_id
			var tpl = entry.template
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			list_vbox.add_child(hbox)

			var name_label = Label.new()
			name_label.text = "%s (x%d)" % [tpl.display_name, entry.qty]
			name_label.custom_minimum_size = Vector2(180, 0)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(name_label)

			var type_label = Label.new()
			type_label.text = tpl.item_type
			type_label.custom_minimum_size = Vector2(70, 0)
			type_label.modulate = Color(0.78, 0.78, 0.78, 1)
			hbox.add_child(type_label)

			var add_btn = Button.new()
			add_btn.text = "Add"
			add_btn.custom_minimum_size = Vector2(50, 24)
			var captured_id = item_id
			add_btn.pressed.connect(func():
				GameContext.move_item_stash_to_hero_bag(hero_id, captured_id)
				popup.hide()
				popup.queue_free()
				_on_manage_gear_pressed(hero_id)
			)
			hbox.add_child(add_btn)

	var close_btn = Button.new()
	close_btn.text = "Back to Gear"
	close_btn.custom_minimum_size = Vector2(100, 28)
	close_btn.pressed.connect(func():
		popup.hide()
		popup.queue_free()
		_on_manage_gear_pressed(hero_id)
	)
	vbox.add_child(close_btn)

	add_child(popup)
	popup.popup_centered(Vector2(380, 350))


## Show popup to select an item from stash to equip in the given slot.
## Shows stat preview, compare vs currently equipped, and detailed tooltips.
func _show_equip_selection_popup(hero_id: String, slot: String) -> void:
	# Get compatible items from stash (use equip_slot field for validation)
	var compatible_items: Array = []

	for item in GameContext.run_items:
		var template: ItemTemplate = null
		var item_id: String = ""
		var quality_tier: int = 0
		var affix_data: Dictionary = {}

		if item is ItemInstance:
			item_id = item.template_id
			quality_tier = item.quality_tier
			template = DataRegistry.get_item_template(item_id)
			if item.affix_id != "":
				affix_data = {
					"source_region": item.source_region,
					"affix_id": item.affix_id,
					"affix_stats": item.affix_stats,
					"affix_prefix": item.affix_prefix
				}
		elif item is Dictionary:
			item_id = item.get("item_id", "")
			quality_tier = int(item.get("quality_tier", 0))
			template = DataRegistry.get_item_template(item_id)
			if item.get("affix_id", "") != "":
				affix_data = {
					"source_region": item.get("source_region", ""),
					"affix_id": item.get("affix_id", ""),
					"affix_stats": item.get("affix_stats", {}),
					"affix_prefix": item.get("affix_prefix", "")
				}

		# Use equip_slot field for proper slot validation
		if template != null and template.equip_slot == slot:
			compatible_items.append({
				"item_id": item_id,
				"quality_tier": quality_tier,
				"affix_data": affix_data,
				"template": template
			})

	# Aggregate compatible items by template+quality+affix (stack identical items)
	var eq_aggregated: Dictionary = {}
	for item_data in compatible_items:
		var aff_id: String = item_data.affix_data.get("affix_id", "") if item_data.affix_data is Dictionary else ""
		var agg_key: String = "%s:%d:%s" % [item_data.item_id, item_data.quality_tier, aff_id]
		if eq_aggregated.has(agg_key):
			eq_aggregated[agg_key].qty += 1
		else:
			eq_aggregated[agg_key] = { "data": item_data, "qty": 1 }
	var stacked_items: Array = []
	for agg_key in eq_aggregated.keys():
		stacked_items.append(eq_aggregated[agg_key])

	if stacked_items.is_empty():
		print("[Equip] No compatible %s items in stash for hero=%s" % [slot, hero_id])
		return

	# Get hero name for display
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id

	# Get currently equipped item info for comparison (generic for all slots)
	var current_id = GameContext.get_hero_slot_item(hero_id, slot)
	var current_quality = GameContext.get_hero_slot_quality(hero_id, slot)
	var current_stats: Dictionary = {}

	if current_id != "":
		var current_template = DataRegistry.get_item_template(current_id)
		if current_template != null:
			var region_bonus: float = GameContext.get_completed_region_count() * 0.1
			current_stats = current_template.get_stat_bonuses_with_quality(current_quality, region_bonus)

	# Create selection popup
	var popup = PopupPanel.new()
	popup.name = "EquipPopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popup.add_child(vbox)

	# Title with hero name and slot
	var title = Label.new()
	title.text = "Equip %s - %s" % [slot.capitalize(), hero_name]
	title.add_theme_font_size_override("font_size", GameContext.fs(18))
	title.modulate = Color(1, 0.9, 0.6)
	vbox.add_child(title)

	# Currently equipped section
	var current_label = Label.new()
	if current_id != "":
		var current_template = DataRegistry.get_item_template(current_id)
		var current_prefix = ItemInstance.QUALITY_PREFIXES[current_quality] if current_quality < ItemInstance.QUALITY_PREFIXES.size() else ""
		var current_name = current_prefix + (current_template.display_name if current_template else current_id)
		current_label.text = "Current: %s" % current_name
	else:
		current_label.text = "Current: None"
	current_label.modulate = Color(0.7, 0.7, 0.9)
	vbox.add_child(current_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Item buttons with stat preview and compare (stacked)
	for stack in stacked_items:
		var item_data = stack.data
		var stack_qty: int = stack.qty
		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 2)

		var btn = Button.new()
		var prefix: String = ItemInstance.QUALITY_PREFIXES[item_data.quality_tier] if item_data.quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
		var affix_prefix: String = item_data.affix_data.get("affix_prefix", "") if item_data.affix_data is Dictionary else ""
		var eq_region_bonus: float = GameContext.get_completed_region_count() * 0.1
		var item_stats: Dictionary = item_data.template.get_stat_bonuses_with_quality(item_data.quality_tier, eq_region_bonus)

		# Build stat text (include affix bonuses)
		var affix_stats: Dictionary = item_data.affix_data.get("affix_stats", {}) if item_data.affix_data is Dictionary else {}
		var stat_parts: Array = []
		for stat_key in ["health", "attack", "defense", "speed"]:
			var val: int = int(item_stats.get(stat_key, 0)) + int(affix_stats.get(stat_key, 0))
			if val > 0:
				var abbrev: Dictionary = {"health": "HP", "attack": "ATK", "defense": "DEF", "speed": "SPD"}
				stat_parts.append("%s+%d" % [abbrev.get(stat_key, stat_key), val])

		var stat_text: String = " ".join(stat_parts) if stat_parts.size() > 0 else "(no stats)"
		var full_name: String = ""
		if affix_prefix != "":
			full_name = "%s %s%s" % [affix_prefix, prefix, item_data.template.display_name]
		else:
			full_name = "%s%s" % [prefix, item_data.template.display_name]
		if stack_qty > 1:
			btn.text = "%s  [%s] (x%d)" % [full_name, stat_text, stack_qty]
		else:
			btn.text = "%s  [%s]" % [full_name, stat_text]
		btn.custom_minimum_size = Vector2(340, 32)
		btn.pressed.connect(_on_equip_item_selected.bind(hero_id, slot, item_data.item_id, item_data.quality_tier, item_data.affix_data, popup))

		# Build tooltip with full info (Items v5: include quality multiplier)
		const QUALITY_MULT := [1.0, 1.1, 1.2, 1.35]
		var q_tier: int = clampi(item_data.quality_tier, 0, 3)
		var mult: float = QUALITY_MULT[q_tier]
		var tooltip_lines: Array = [
			"Item: %s" % full_name,
			"ID: %s" % item_data.item_id,
			"Slot: %s" % item_data.template.equip_slot,
			"Quality: Q%d (x%.2f)" % [q_tier, mult],
			"Stats (final): %s" % stat_text
		]
		if affix_prefix != "":
			tooltip_lines.append("Affix: %s" % affix_prefix)
		if stack_qty > 1:
			tooltip_lines.append("In stash: x%d" % stack_qty)
		btn.tooltip_text = "\n".join(tooltip_lines)

		item_vbox.add_child(btn)

		# Compare line (delta stats)
		var compare_label = Label.new()
		var delta_parts: Array = []
		for stat_key in ["health", "attack", "defense", "speed"]:
			var new_val = item_stats.get(stat_key, 0)
			var old_val = current_stats.get(stat_key, 0)
			var delta = new_val - old_val
			if delta != 0:
				var abbrev = {"health": "HP", "attack": "ATK", "defense": "DEF", "speed": "SPD"}
				var sign_str = "+" if delta > 0 else ""
				delta_parts.append("Δ%s %s%d" % [abbrev.get(stat_key, stat_key), sign_str, delta])

		if delta_parts.size() > 0:
			compare_label.text = "  " + " ".join(delta_parts)
			# Color based on net positive/negative
			var total_delta = 0
			for stat_key in ["health", "attack", "defense", "speed"]:
				total_delta += item_stats.get(stat_key, 0) - current_stats.get(stat_key, 0)
			if total_delta > 0:
				compare_label.modulate = Color(0.5, 1, 0.5)  # Green for upgrade
			elif total_delta < 0:
				compare_label.modulate = Color(1, 0.5, 0.5)  # Red for downgrade
			else:
				compare_label.modulate = Color(0.8, 0.8, 0.8)  # Neutral
		else:
			compare_label.text = "  (no stat change)"
			compare_label.modulate = Color(0.78, 0.78, 0.78)

		compare_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		item_vbox.add_child(compare_label)

		vbox.add_child(item_vbox)

	# Separator before cancel
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(300, 32)
	cancel_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(cancel_btn)

	add_child(popup)
	popup.popup_centered()


func _on_equip_item_selected(hero_id: String, slot: String, item_id: String, quality_tier: int, affix_data: Dictionary, popup: PopupPanel) -> void:
	popup.queue_free()
	GameContext.equip_hero_item(hero_id, slot, item_id, quality_tier, affix_data)
	if _manage_gear_overlay != null and is_instance_valid(_manage_gear_overlay):
		_build_manage_gear_content()
	else:
		_refresh_facility_panel()


func _on_recruit_hero_pressed(class_id: String, cost: int, race_id: String = "human", level: int = 1, slot_key: String = "", starting_equipment: Array = []) -> void:
	var hero_id = GameContext.recruit_hero(class_id, cost, race_id, level, starting_equipment)
	if hero_id != "":
		UIAudio.play_sfx("hero_recruit")
		print("[Inn] recruited %s Lv %d hero_id=%s slot=%s" % [class_id, level, hero_id, slot_key])
		# Mark slot as purchased so it shows [Recruited] until refresh
		if slot_key != "" and _current_facility_id != "":
			GameContext.mark_shop_slot_purchased(_get_inn_shop_id(), slot_key)
			# Auto-restock: if all recruit slots are now purchased, refresh with new candidates
			_check_inn_auto_restock()
		# Highlight "Manage Roster" tab after first hire
		if not GameContext.has_completed_tutorial("visited_roster_after_hire"):
			_highlight_roster_tab = true
	_refresh_facility_panel()


## Auto-restock Inn when all recruit slots have been purchased.
## Clears purchased state and increments restock counter for seed variation.
func _check_inn_auto_restock() -> void:
	if _current_facility_id == "":
		return
	var town_id: String = GameContext.get_current_town_id()
	var current_tier: int = GameContext.get_facility_tier(town_id, _current_facility_id)
	var max_candidates: int = 2 + current_tier  # T1=3, T2=4, T3=5, T4=6

	# Check if all recruit slots are purchased
	var inn_shop_id: String = _get_inn_shop_id()
	for i in range(max_candidates):
		var slot_key: String = "recruit_%d" % i
		if not GameContext.is_shop_slot_purchased(inn_shop_id, slot_key):
			return  # Not all purchased yet

	# All slots purchased — clear them for restock
	if GameContext.shop_purchased_slots.has(inn_shop_id):
		GameContext.shop_purchased_slots[inn_shop_id] = []
	GameContext.inn_restock_counts[town_id] = GameContext.inn_restock_counts.get(town_id, 0) + 1
	var restock_num: int = GameContext.inn_restock_counts[town_id]
	print("[Inn] All %d recruit slots purchased — auto-restocked (restock #%d)" % [max_candidates, restock_num])


func _on_rename_hero_pressed(hero_id: String) -> void:
	# Build a rename popup with LineEdit, Confirm, Cancel
	var popup = PopupPanel.new()
	popup.name = "RenamePopup"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = "Rename Hero"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "New name (max 18 chars)"
	line_edit.max_length = 18
	line_edit.custom_minimum_size = Vector2(220, 30)
	# Pre-fill with current name
	var hero = GameContext.get_hero(hero_id)
	if not hero.is_empty():
		line_edit.text = hero.get("name", "")
	vbox.add_child(line_edit)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 28)
	btn_row.add_child(cancel_btn)

	# Wire buttons
	confirm_btn.pressed.connect(func():
		var new_name = line_edit.text
		GameContext.set_hero_name(hero_id, new_name)
		popup.queue_free()
		_refresh_facility_panel()
	)
	cancel_btn.pressed.connect(func():
		popup.queue_free()
	)

	add_child(popup)
	popup.popup_centered(Vector2i(280, 130))


func _on_inn_dismiss_hero_pressed(hero_id: String) -> void:
	if GameContext.is_in_party(hero_id):
		print("[Inn] cannot dismiss hero in party: %s" % hero_id)
		return

	# Check if hero has any equipped gear or bag items
	var has_gear: bool = false
	for slot in GameContext.ALL_EQUIP_SLOTS:
		if GameContext.get_hero_slot_item(hero_id, slot) != "":
			has_gear = true
			break
	if not has_gear:
		var bag = GameContext.get_hero_bag(hero_id)
		if bag.size() > 0:
			has_gear = true

	if has_gear:
		_show_dismiss_warning_overlay(hero_id)
	else:
		var hero = GameContext.get_hero(hero_id)
		var hname: String = hero.get("name", hero_id)
		GameContext.remove_hero_from_roster(hero_id)
		GameContext.add_run_gold(25)
		print("[Inn] dismissed %s (no gear), refunded 25g" % hname)
		_refresh_facility_panel()


## Compute total sell value of all gear on a hero (equipment + bag items).
func _compute_hero_gear_value(hero_id: String) -> int:
	var total: int = 0
	for slot in GameContext.ALL_EQUIP_SLOTS:
		var item_id = GameContext.get_hero_slot_item(hero_id, slot)
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				total += tpl.get_sell_value()
	for bag_item in GameContext.get_hero_bag(hero_id):
		var bag_id: String = bag_item.get("item_id", "")
		if bag_id != "":
			var tpl = DataRegistry.get_item_template(bag_id)
			if tpl != null:
				total += tpl.get_sell_value() * int(bag_item.get("qty", 1))
	return total


## Unequip all hero gear and move bag items to stash.
func _bank_hero_gear_to_stash(hero_id: String) -> void:
	for slot in GameContext.ALL_EQUIP_SLOTS:
		if GameContext.get_hero_slot_item(hero_id, slot) != "":
			GameContext.unequip_hero_item(hero_id, slot)
	var bag = GameContext.get_hero_bag(hero_id).duplicate()
	for bag_item in bag:
		var bag_id: String = bag_item.get("item_id", "")
		var qty: int = int(bag_item.get("qty", 1))
		var quality: int = int(bag_item.get("quality_tier", 0))
		if bag_id != "":
			GameContext.move_item_hero_bag_to_stash(hero_id, bag_id, qty, quality)


## Sell all hero gear for gold (unequip → remove from stash → add gold).
func _sell_hero_gear_for_gold(hero_id: String) -> int:
	var gold_earned: int = _compute_hero_gear_value(hero_id)
	for slot in GameContext.ALL_EQUIP_SLOTS:
		var item_id = GameContext.get_hero_slot_item(hero_id, slot)
		if item_id != "":
			GameContext.unequip_hero_item(hero_id, slot)
			GameContext.remove_run_item(item_id, 1)
	var bag = GameContext.get_hero_bag(hero_id).duplicate()
	for bag_item in bag:
		var bag_id: String = bag_item.get("item_id", "")
		var qty: int = int(bag_item.get("qty", 1))
		var quality: int = int(bag_item.get("quality_tier", 0))
		if bag_id != "":
			GameContext.move_item_hero_bag_to_stash(hero_id, bag_id, qty, quality)
			GameContext.remove_run_item(bag_id, qty)
	GameContext.add_run_gold(gold_earned)
	return gold_earned


## Close the dismiss warning overlay.
func _close_dismiss_warning_overlay() -> void:
	if _dismiss_warning_overlay != null and is_instance_valid(_dismiss_warning_overlay):
		UIAudio.unregister_closeable(_dismiss_warning_overlay)
		_dismiss_warning_overlay.queue_free()
		_dismiss_warning_overlay = null


## Show Crown Property warning overlay when dismissing a hero with gear.
func _show_dismiss_warning_overlay(hero_id: String) -> void:
	_close_dismiss_warning_overlay()

	var hero = GameContext.get_hero(hero_id)
	var hname: String = hero.get("name", hero_id)
	var gear_value: int = _compute_hero_gear_value(hero_id)

	# Build overlay (same pattern as manage gear overlay)
	_dismiss_warning_overlay = CanvasLayer.new()
	_dismiss_warning_overlay.layer = 10
	add_child(_dismiss_warning_overlay)

	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_dismiss_warning_overlay()
	)
	_dismiss_warning_overlay.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dismiss_warning_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = _region_palette.get("bg_dark", Color(0.14, 0.12, 0.10, 0.95))
	pstyle.set_border_width_all(2)
	pstyle.border_color = _region_palette.get("border", Color(0.55, 0.4, 0.25, 0.8))
	pstyle.set_corner_radius_all(8)
	pstyle.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", pstyle)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	# Title
	var title_lbl = Label.new()
	title_lbl.text = "Crown Property Notice"
	title_lbl.add_theme_font_size_override("font_size", GameContext.fs(18))
	title_lbl.modulate = Color(0.6, 0.5, 0.3, 1)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_lbl)

	var sep1 = HSeparator.new()
	content.add_child(sep1)

	# Body text (Mira's warning)
	var body_lbl = Label.new()
	body_lbl.text = "Hold on a moment — %s is still carrying gear that belongs to the shop. The Crown's ledger doesn't balance itself, and I can't let anyone walk out the door with supplies we haven't accounted for. Let's sort this out before we say our goodbyes." % hname
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
	body_lbl.modulate = Color(1.0, 0.95, 0.8, 1)
	content.add_child(body_lbl)

	var sep2 = HSeparator.new()
	content.add_child(sep2)

	# Buttons
	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 6)
	content.add_child(btn_vbox)

	# Bank gear button
	var bank_btn = Button.new()
	bank_btn.text = "Return Gear to Stash"
	bank_btn.custom_minimum_size = Vector2(0, 32)
	bank_btn.pressed.connect(func():
		_bank_hero_gear_to_stash(hero_id)
		GameContext.remove_hero_from_roster(hero_id)
		GameContext.add_run_gold(25)
		print("[Inn] %s dismissed — gear returned to stash, refunded 25g" % hname)
		_close_dismiss_warning_overlay()
		_refresh_facility_panel()
	)
	btn_vbox.add_child(bank_btn)

	# Sell gear button
	var sell_btn = Button.new()
	sell_btn.text = "Sell Gear (%d gold)" % gear_value
	sell_btn.custom_minimum_size = Vector2(0, 32)
	sell_btn.pressed.connect(func():
		var earned = _sell_hero_gear_for_gold(hero_id)
		GameContext.remove_hero_from_roster(hero_id)
		GameContext.add_run_gold(25)
		print("[Inn] %s dismissed — gear sold for %dg, refunded 25g" % [hname, earned])
		_close_dismiss_warning_overlay()
		_refresh_facility_panel()
	)
	btn_vbox.add_child(sell_btn)

	# Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Keep Them On"
	cancel_btn.custom_minimum_size = Vector2(0, 32)
	cancel_btn.modulate = Color(0.7, 0.7, 0.7, 1)
	cancel_btn.pressed.connect(func():
		_close_dismiss_warning_overlay()
	)
	btn_vbox.add_child(cancel_btn)

	# Register with ESC-close stack
	UIAudio.register_closeable(_dismiss_warning_overlay, _close_dismiss_warning_overlay)


## Generate recruit candidates from DataRegistry (races + classes filtered by unlock_region).
## Returns array of { race_id, class_id, cost_gold, level, starting_equipment } dictionaries.
## inn_tier controls race filtering: T1 = region-native only, T2+ = all unlocked.
## Classes are always region-locked (only current region's native classes).
func _generate_inn_recruit_candidates(current_region: int, recruit_level: int, max_candidates: int = 5, inn_tier: int = 1) -> Array:
	var candidates: Array = []

	# Get races filtered by inn tier
	var available_races: Array = []
	var available_classes: Array = []

	for race_data in DataRegistry.get_all_races():
		if inn_tier <= 1:
			# T1: Only races native to THIS region (exact match)
			if race_data.unlock_region == current_region:
				available_races.append(race_data.race_id)
		else:
			# T2+: All unlocked races (attracts heroes of all races)
			if race_data.unlock_region <= current_region:
				available_races.append(race_data.race_id)

	# Classes are always region-locked: only this region's native classes
	for class_data in DataRegistry.get_all_classes():
		if class_data.unlock_region == current_region:
			if class_data.is_legacy:
				continue
			available_classes.append(class_data.class_id)

	# If no data loaded, fallback to hardcoded defaults
	if available_races.is_empty():
		available_races = ["human", "elf", "dwarf"]
	if available_classes.is_empty():
		available_classes = ["defender", "striker", "warden"]

	# Regional base cost (scales with region to match economy progression)
	var region_cost: int = RECRUIT_BASE_COST_BY_REGION[clampi(current_region, 1, 7)]

	# Generate all race+class combinations as potential candidates
	var all_combinations: Array = []
	for race_id in available_races:
		for class_id in available_classes:
			all_combinations.append({
				"race_id": race_id,
				"class_id": class_id,
				"cost_gold": region_cost,
				"level": recruit_level
			})

	# For MVP: Show a subset of candidates (one per class, varying races)
	# Use seeded RNG for determinism based on town_id + restock counter
	var town_id = GameContext.get_current_town_id()
	if town_id == "":
		town_id = "default"
	var base_seed = GameContext.get_run_seed() if GameContext.get_run_seed() != 0 else 42
	var restock_count: int = GameContext.inn_restock_counts.get(town_id, 0)
	var recruit_seed = SeededRNG.derive_seed("inn_recruit:%s:%d" % [town_id, restock_count], base_seed)
	var rng = SeededRNG.create_rng(recruit_seed)

	# Shuffle combinations deterministically using seeded RNG (Fisher-Yates)
	for i in range(all_combinations.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var tmp = all_combinations[i]
		all_combinations[i] = all_combinations[j]
		all_combinations[j] = tmp

	# Select one candidate per class to ensure variety
	var selected_classes: Dictionary = {}
	for combo in all_combinations:
		var class_id = combo.get("class_id", "")
		if not selected_classes.has(class_id):
			# Generate starting equipment for T2+ inns
			combo["starting_equipment"] = GameContext.generate_recruit_equipment(class_id, current_region, inn_tier, rng)
			# Add equipment value surcharge to recruit cost
			var equip_value: int = 0
			for eq in combo["starting_equipment"]:
				var eq_tpl = DataRegistry.get_item_template(eq.get("item_id", ""))
				if eq_tpl != null:
					equip_value += eq_tpl.base_value
			combo["cost_gold"] = region_cost + equip_value
			candidates.append(combo)
			selected_classes[class_id] = true
		if candidates.size() >= max_candidates:
			break

	# If we have fewer than 3 candidates, just use what we have
	print("[Inn] pool races=%d classes=%d candidates=%d region=%d" % [
		available_races.size(), available_classes.size(), candidates.size(), current_region
	])

	# Validate data references for visible candidates (non-blocking warnings)
	_validate_candidate_data(candidates)

	return candidates


## Validate class/race data references for recruit candidates.
## Logs warnings for missing passive/ability IDs (non-blocking).
func _validate_candidate_data(candidates: Array) -> void:
	var validated_classes: Dictionary = {}
	var validated_races: Dictionary = {}

	for candidate in candidates:
		var class_id = candidate.get("class_id", "")
		var race_id = candidate.get("race_id", "")

		# Validate class (once per class_id)
		if class_id != "" and not validated_classes.has(class_id):
			validated_classes[class_id] = true
			var class_data = DataRegistry.get_class_data(class_id)
			if class_data == null:
				print("[DataWarn] missing class=%s" % class_id)
			else:
				# Check ability IDs (passive/ability registries may not exist yet)
				if class_data.ability_a_id != "" and not _ability_exists(class_data.ability_a_id):
					print("[DataWarn] class=%s missing ability=%s" % [class_id, class_data.ability_a_id])
				if class_data.ability_b_id != "" and not _ability_exists(class_data.ability_b_id):
					print("[DataWarn] class=%s missing ability=%s" % [class_id, class_data.ability_b_id])
				if class_data.passive_a_id != "" and not _passive_exists(class_data.passive_a_id):
					print("[DataWarn] class=%s missing passive=%s" % [class_id, class_data.passive_a_id])
				if class_data.passive_b_id != "" and not _passive_exists(class_data.passive_b_id):
					print("[DataWarn] class=%s missing passive=%s" % [class_id, class_data.passive_b_id])

		# Validate race (once per race_id)
		if race_id != "" and not validated_races.has(race_id):
			validated_races[race_id] = true
			var race_data = DataRegistry.get_race(race_id)
			if race_data == null:
				print("[DataWarn] missing race=%s" % race_id)
			elif race_data.racial_passive_id != "" and not _passive_exists(race_data.racial_passive_id):
				print("[DataWarn] race=%s missing passive=%s" % [race_id, race_data.racial_passive_id])


## Check if ability ID exists in registry. Returns true if found or if registry unavailable.
func _ability_exists(ability_id: String) -> bool:
	if ability_id == "":
		return true
	# Ability registry may not exist yet - allow placeholder
	if not DataRegistry.has_method("get_ability"):
		return true  # Can't validate, assume OK
	var ability = DataRegistry.get_ability(ability_id)
	return ability != null


## Check if passive ID exists in registry. Returns true if found or if registry unavailable.
func _passive_exists(passive_id: String) -> bool:
	if passive_id == "":
		return true
	# Passive registry may not exist yet - allow placeholder
	if not DataRegistry.has_method("get_passive"):
		return true  # Can't validate, assume OK
	var passive = DataRegistry.get_passive(passive_id)
	return passive != null


# ============================================================================
# PRODUCTION UI (Chef, Alchemist — Mixing Table System)
# ============================================================================

func _build_production_ui() -> void:
	print("[Production] opened")

	if _current_facility == null:
		var no_data = Label.new()
		no_data.text = "(No facility data)"
		no_data.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_data)
		return

	var facility = _current_facility
	var facility_id = facility.facility_id

	# Check facility lockout from alchemist mishaps
	if GameContext.locked_facilities.has(facility_id):
		var locked_label = Label.new()
		locked_label.text = "The %s is closed due to an incident.\nReturn to town to reopen." % facility.display_name
		locked_label.modulate = Color(1, 0.5, 0.5, 1)
		locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_facility_actions_container.add_child(locked_label)
		return

	# Check if facility has mixing recipes — if so, use mixing UI; otherwise fall back to legacy
	if facility.mixing_recipe_file != "":
		_build_mixing_production_ui()
	else:
		_build_legacy_production_ui()


## Legacy production UI for facilities without mixing_recipe_file (backward compat).
func _build_legacy_production_ui() -> void:
	var facility = _current_facility
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	var header = Label.new()
	header.text = "=== %s (Tier %d / %d) ===" % [facility.display_name, current_tier, facility.max_tier]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_facility_actions_container.add_child(header)

	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	if current_tier < facility.max_tier:
		var upgrade_row = _create_production_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

	_build_facility_unlocks_section()
	_build_crafting_recipes_section()


## Get per-facility mix slot state, initializing if needed.
func _get_mix_state(facility_id: String) -> Dictionary:
	if not _mix_slots.has(facility_id):
		_mix_slots[facility_id] = {"a": "", "b": "", "c": "", "picking": "", "result": ""}
	return _mix_slots[facility_id]


## Mixing-based production UI with NPC header, mixing table, and discovery log.
func _build_mixing_production_ui() -> void:
	var facility = _current_facility
	var facility_id = facility.facility_id
	var town_id = GameContext.get_current_town_id()
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	# NPC header with portrait + greeting + menu views
	var current_view: String = _production_views.get(facility_id, "mix")
	var menu: Array = [
		{"view": "mix", "label": "Mixing Table"},
		{"view": "log", "label": "Discovery Log"},
		{"view": "upgrade", "label": "Upgrade"},
	]
	_build_npc_header(facility, menu, current_view, _on_production_view_pressed.bind(facility_id))

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	match current_view:
		"mix":
			_build_mixing_table_view(facility, facility_id, town_id, current_tier)
		"log":
			_build_discovery_log_view(facility, facility_id, town_id, current_tier)
		"upgrade":
			_build_production_upgrade_view(facility, facility_id, town_id, current_tier)


## Mixing Table view — slot selection + mix button + result
func _build_mixing_table_view(facility, facility_id: String, town_id: String, current_tier: int) -> void:
	var ms: Dictionary = _get_mix_state(facility_id)
	var has_third_slot: bool = current_tier >= 3

	# Mishap warning (alchemist only)
	if facility_id == "alchemist" and GameContext.alchemist_mishap_streak > 0:
		var warn = Label.new()
		warn.text = "The lab feels unstable... (Mishap risk: %d%%)" % mini(GameContext.alchemist_mishap_streak * 10, 50)
		warn.modulate = Color(1.0, 0.7, 0.3, 0.9)
		warn.add_theme_font_size_override("font_size", GameContext.fs(13))
		_facility_actions_container.add_child(warn)

	# Gold display
	var gold_label = Label.new()
	gold_label.text = "Gold: %d" % GameContext.get_run_gold()
	gold_label.modulate = Color(1, 0.9, 0.5, 1)
	_facility_actions_container.add_child(gold_label)

	# Quality tier display
	var quality_text: String = "Quality: Common only"
	if current_tier >= 4:
		quality_text = "Quality: Common - Legendary"
	elif current_tier >= 2:
		quality_text = "Quality: Common - Rare"
	var quality_label = Label.new()
	quality_label.text = quality_text
	quality_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	quality_label.modulate = Color(0.7, 0.8, 1.0, 0.8)
	_facility_actions_container.add_child(quality_label)

	# --- Slot Row ---
	var slot_row = HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 6)
	_facility_actions_container.add_child(slot_row)

	_add_mix_slot_button(slot_row, "a", ms.get("a", ""), facility_id)
	var plus1 = Label.new()
	plus1.text = " + "
	slot_row.add_child(plus1)
	_add_mix_slot_button(slot_row, "b", ms.get("b", ""), facility_id)

	if has_third_slot:
		var plus2 = Label.new()
		plus2.text = " + "
		slot_row.add_child(plus2)
		_add_mix_slot_button(slot_row, "c", ms.get("c", ""), facility_id)

	var eq_label = Label.new()
	eq_label.text = "  =  ???"
	eq_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	slot_row.add_child(eq_label)

	var mix_btn = Button.new()
	mix_btn.text = "Mix!"
	mix_btn.custom_minimum_size = Vector2(80, 36)
	var slots_filled: bool = ms.get("a", "") != "" and ms.get("b", "") != ""
	mix_btn.disabled = not slots_filled
	mix_btn.pressed.connect(_on_mix_pressed)
	slot_row.add_child(mix_btn)

	# Clear button
	if ms.get("a", "") != "" or ms.get("b", "") != "" or ms.get("c", "") != "":
		var clear_btn = Button.new()
		clear_btn.text = "Clear"
		clear_btn.custom_minimum_size = Vector2(60, 36)
		clear_btn.pressed.connect(_on_mix_clear_pressed)
		slot_row.add_child(clear_btn)

	# Result message
	var result_text: String = ms.get("result", "")
	if result_text != "":
		var result_label = Label.new()
		result_label.text = result_text
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result_label.add_theme_font_size_override("font_size", GameContext.fs(15))
		if result_text.begins_with("Created:") or result_text.find("NEW DISCOVERY") >= 0:
			result_label.modulate = Color(0.4, 1.0, 0.6, 1)
		elif result_text.find("fizzled") >= 0 or result_text.find("didn't combine") >= 0:
			result_label.modulate = Color(1.0, 0.8, 0.4, 1)
		else:
			result_label.modulate = Color(1.0, 0.5, 0.4, 1)
		_facility_actions_container.add_child(result_label)

	# Item picker (if we're in picking mode)
	if ms.get("picking", "") != "":
		_build_item_picker_list(facility_id)


## Add a mix slot button to the row.
func _add_mix_slot_button(parent: HBoxContainer, slot: String, current_item: String, facility_id: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	if current_item != "":
		var tpl = DataRegistry.get_item_template(current_item)
		if tpl != null:
			btn.text = tpl.display_name.substr(0, 6)
			btn.tooltip_text = tpl.display_name
			var icon_rect = tpl.create_icon_rect(32)
			if icon_rect != null:
				btn.icon = icon_rect.texture if icon_rect is TextureRect else null
		else:
			btn.text = current_item.substr(0, 6)
	else:
		btn.text = "?"
		btn.modulate = Color(0.7, 0.7, 0.7, 0.6)
	btn.pressed.connect(_on_mix_slot_pressed.bind(slot, facility_id))
	parent.add_child(btn)


## Show item picker for a specific slot.
func _on_mix_slot_pressed(slot: String, facility_id: String = "") -> void:
	if facility_id == "":
		facility_id = _current_facility_id
	var ms: Dictionary = _get_mix_state(facility_id)
	if ms.get("picking", "") == slot:
		ms["picking"] = ""  # Toggle off
	else:
		ms["picking"] = slot
	# Switch focus to correct facility
	if facility_id != _current_facility_id and _open_panels.has(facility_id):
		_current_facility_id = facility_id
		var info = _open_panels[facility_id]
		_facility_actions_container = info.get("actions_container")
		_current_facility = DataRegistry.get_facility(facility_id)
	_refresh_facility_panel()


## Build the item picker list showing ingredient-type items from stash.
func _build_item_picker_list(facility_id: String) -> void:
	var ms: Dictionary = _get_mix_state(facility_id)
	var picking: String = ms.get("picking", "")

	var sep_node = HSeparator.new()
	_facility_actions_container.add_child(sep_node)

	var picker_header = Label.new()
	picker_header.text = "Select item for Slot %s:" % picking.to_upper()
	picker_header.modulate = Color(0.9, 0.8, 0.5, 1)
	picker_header.add_theme_font_size_override("font_size", GameContext.fs(14))
	_facility_actions_container.add_child(picker_header)

	# Get stash items
	var run_items_dict: Dictionary = GameContext.get_run_items_dict()

	# Calculate what's already committed to other slots
	var committed: Dictionary = {}
	for s in ["a", "b", "c"]:
		if s == picking:
			continue
		var item_in_slot: String = ms.get(s, "")
		if item_in_slot != "":
			committed[item_in_slot] = committed.get(item_in_slot, 0) + 1

	# Two-column grid for ingredient picker
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facility_actions_container.add_child(grid)

	var shown: int = 0
	for item_id in run_items_dict:
		var qty_have: int = run_items_dict[item_id]
		var qty_committed: int = committed.get(item_id, 0)
		var qty_available: int = qty_have - qty_committed
		if qty_available <= 0:
			continue

		# Filter: only show material and consumable types (no equipment, books)
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl == null:
			continue
		var item_type: String = tpl.item_type if tpl.item_type != null else ""
		if item_type != "material" and item_type != "consumable":
			continue
		# Skip books
		if tpl.tags is Array:
			var skip: bool = false
			for tag in tpl.tags:
				if tag == "book" or tag == "class_unlock":
					skip = true
					break
			if skip:
				continue

		var cell = HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var icon_rect = tpl.create_icon_rect(22)
		if icon_rect != null:
			cell.add_child(icon_rect)

		var name_label = Label.new()
		name_label.text = "%s (x%d)" % [tpl.display_name, qty_available]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		cell.add_child(name_label)

		var select_btn = Button.new()
		select_btn.text = "Select"
		select_btn.custom_minimum_size = Vector2(52, 22)
		select_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
		select_btn.pressed.connect(_on_item_picked.bind(item_id))
		cell.add_child(select_btn)

		grid.add_child(cell)
		shown += 1

	if shown == 0:
		grid.queue_free()
		var empty_label = Label.new()
		empty_label.text = "(No ingredients in stash)"
		empty_label.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(empty_label)


## Handle item selection from the picker.
func _on_item_picked(item_id: String) -> void:
	var facility_id: String = _current_facility_id
	var ms: Dictionary = _get_mix_state(facility_id)
	var picking: String = ms.get("picking", "")
	if picking != "":
		ms[picking] = item_id
	ms["picking"] = ""
	ms["result"] = ""
	_refresh_facility_panel()


## Handle the Mix button press.
func _on_mix_pressed() -> void:
	if _current_facility == null:
		return

	var facility_id: String = _current_facility.facility_id
	var town_id: String = GameContext.get_current_town_id()
	var current_tier: int = GameContext.get_facility_tier(town_id, facility_id)
	var ms: Dictionary = _get_mix_state(facility_id)
	var slot_a: String = ms.get("a", "")
	var slot_b: String = ms.get("b", "")
	var slot_c: String = ms.get("c", "")

	if slot_a == "" or slot_b == "":
		return

	# Look up recipe
	var recipe: Dictionary = DataRegistry.lookup_mix(facility_id, slot_a, slot_b, slot_c)

	# Check materials in stash before consuming
	var run_items_dict: Dictionary = GameContext.get_run_items_dict()
	var items_to_consume: Dictionary = {}
	for item_id in [slot_a, slot_b, slot_c]:
		if item_id == "":
			continue
		items_to_consume[item_id] = items_to_consume.get(item_id, 0) + 1

	for item_id in items_to_consume:
		var need: int = items_to_consume[item_id]
		var have: int = run_items_dict.get(item_id, 0)
		if have < need:
			ms["result"] = "Not enough %s (need %d, have %d)" % [item_id, need, have]
			_refresh_facility_panel()
			return

	# Consume materials (point of no return)
	for item_id in items_to_consume:
		GameContext.remove_run_item(item_id, items_to_consume[item_id])

	var consumed_str: String = ", ".join(items_to_consume.keys())
	print("[Mix] Consumed: %s at %s" % [consumed_str, facility_id])

	if recipe.size() > 0:
		# Success!
		var output_id: String = recipe.get("output_id", "")
		var output_qty: int = recipe.get("output_qty", 1)
		var was_new: bool = not GameContext.is_mix_discovered(facility_id, slot_a, slot_b, slot_c)

		GameContext.add_run_item(output_id, output_qty)
		GameContext.discover_mix(facility_id, slot_a, slot_b, slot_c)

		if facility_id == "alchemist":
			GameContext.alchemist_mishap_streak = 0

		var tpl = DataRegistry.get_item_template(output_id)
		var dname: String = tpl.display_name if tpl != null and tpl.display_name != "" else output_id
		if was_new:
			ms["result"] = "Created: %s x%d — NEW DISCOVERY!" % [dname, output_qty]
		else:
			ms["result"] = "Created: %s x%d" % [dname, output_qty]
		print("[Mix] Success: %s x%d new=%s" % [output_id, output_qty, was_new])
	else:
		# Failure — process mishap
		var mishap: Dictionary = GameContext.process_failed_mix(facility_id)
		ms["result"] = mishap.get("message", "The mix fizzled.")
		print("[Mix] Failed: %s" % mishap.get("type", "none"))

	ms["a"] = ""
	ms["b"] = ""
	ms["c"] = ""
	ms["picking"] = ""
	_refresh_facility_panel()


## Craft a discovered recipe directly from the discovery log.
func _on_discovery_craft_pressed(facility_id: String, recipe: Dictionary) -> void:
	var input_a: String = recipe.get("input_a", "")
	var input_b: String = recipe.get("input_b", "")
	var input_c: String = recipe.get("input_c", "")
	var output_id: String = recipe.get("output_id", "")
	var output_qty: int = recipe.get("output_qty", 1)

	# Check ingredients
	var run_items: Dictionary = GameContext.get_run_items_dict()
	var need: Dictionary = {}
	for iid in [input_a, input_b, input_c]:
		if iid != "":
			need[iid] = need.get(iid, 0) + 1
	for iid in need:
		if run_items.get(iid, 0) < need[iid]:
			var ms: Dictionary = _get_mix_state(facility_id)
			ms["result"] = "Not enough ingredients!"
			_refresh_facility_panel()
			return

	# Consume ingredients
	for iid in need:
		GameContext.remove_run_item(iid, need[iid])

	# Add output
	GameContext.add_run_item(output_id, output_qty)
	UIAudio.play_sfx("item_buy")

	var tpl = DataRegistry.get_item_template(output_id)
	var dname: String = tpl.display_name if tpl != null else output_id
	var ms: Dictionary = _get_mix_state(facility_id)
	ms["result"] = "Crafted: %s x%d" % [dname, output_qty]
	print("[Mix][DiscoveryCraft] %s x%d from %s" % [output_id, output_qty, facility_id])
	_refresh_facility_panel()


## Clear all mixing slots.
func _on_mix_clear_pressed() -> void:
	var facility_id: String = _current_facility_id
	var ms: Dictionary = _get_mix_state(facility_id)
	ms["a"] = ""
	ms["b"] = ""
	ms["c"] = ""
	ms["picking"] = ""
	ms["result"] = ""
	_refresh_facility_panel()


## Discovery Log view — shows found/total recipes.
func _build_discovery_log_view(facility, facility_id: String, town_id: String, current_tier: int) -> void:
	var all_recipes: Array = DataRegistry.get_mixing_recipes(facility_id)
	var total_available: int = all_recipes.size()
	var found: int = GameContext.get_discovered_mix_count(facility_id)

	var header = Label.new()
	header.text = "Discovered: %d / %d" % [found, total_available]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.modulate = Color(0.9, 0.85, 0.6, 1)
	_facility_actions_container.add_child(header)

	# Two-column layout for recipe list
	var columns_hbox = HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 12)
	_facility_actions_container.add_child(columns_hbox)
	var col_left = VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 3)
	columns_hbox.add_child(col_left)
	var col_right = VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 3)
	columns_hbox.add_child(col_right)

	var recipe_idx: int = 0
	for recipe in all_recipes:
		var input_a: String = recipe.get("input_a", "")
		var input_b: String = recipe.get("input_b", "")
		var input_c: String = recipe.get("input_c", "")
		var output_id: String = recipe.get("output_id", "")

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		if GameContext.is_mix_discovered(facility_id, input_a, input_b, input_c):
			var tpl_a = DataRegistry.get_item_template(input_a)
			var tpl_b = DataRegistry.get_item_template(input_b)
			var tpl_out = DataRegistry.get_item_template(output_id)
			var name_a: String = tpl_a.display_name if tpl_a != null else input_a
			var name_b: String = tpl_b.display_name if tpl_b != null else input_b
			var name_out: String = tpl_out.display_name if tpl_out != null else output_id
			var text: String = "%s + %s" % [name_a, name_b]
			if input_c != "":
				var tpl_c = DataRegistry.get_item_template(input_c)
				var name_c: String = tpl_c.display_name if tpl_c != null else input_c
				text += " + %s" % name_c
			text += " = %s" % name_out
			var label = Label.new()
			label.text = text
			label.add_theme_font_size_override("font_size", GameContext.fs(12))
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.modulate = Color(0.8, 1.0, 0.8, 1)
			row.add_child(label)

			# Craft button — check if ingredients available
			var run_items: Dictionary = GameContext.get_run_items_dict()
			var need: Dictionary = {}
			for iid in [input_a, input_b, input_c]:
				if iid != "":
					need[iid] = need.get(iid, 0) + 1
			var can_craft: bool = true
			for iid in need:
				if run_items.get(iid, 0) < need[iid]:
					can_craft = false
					break
			var craft_btn = Button.new()
			craft_btn.text = "Craft"
			craft_btn.custom_minimum_size = Vector2(50, 22)
			craft_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			craft_btn.disabled = not can_craft
			craft_btn.pressed.connect(_on_discovery_craft_pressed.bind(facility_id, recipe))
			row.add_child(craft_btn)
		else:
			var label = Label.new()
			if input_c != "":
				label.text = "??? + ??? + ??? = ???"
			else:
				label.text = "??? + ??? = ???"
			label.modulate = Color(0.7, 0.7, 0.7, 0.85)
			label.add_theme_font_size_override("font_size", GameContext.fs(12))
			row.add_child(label)

		# Alternate between left and right columns
		if recipe_idx % 2 == 0:
			col_left.add_child(row)
		else:
			col_right.add_child(row)
		recipe_idx += 1


## Upgrade view for mixing facilities — tier-tab style matching Training Hall.
func _build_production_upgrade_view(facility, facility_id: String, town_id: String, current_tier: int) -> void:
	var max_tier: int = facility.max_tier

	# Auto-select next available tier if not set
	if _upgrade_tier_tab == 0 or _upgrade_tier_tab > max_tier:
		_upgrade_tier_tab = mini(current_tier + 1, max_tier)

	# Tier tab buttons
	var tier_row = HBoxContainer.new()
	tier_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tier_row.add_theme_constant_override("separation", 4)
	_facility_actions_container.add_child(tier_row)

	for tier in range(1, max_tier + 1):
		var btn = Button.new()
		btn.text = "Tier %d" % tier
		btn.custom_minimum_size = Vector2(70, 26)
		if _upgrade_tier_tab == tier:
			_apply_selected_button_style(btn)
		else:
			if tier <= current_tier:
				btn.modulate = Color(0.5, 0.9, 0.5, 1)
			elif tier == current_tier + 1:
				btn.modulate = Color(1, 1, 1, 1)
			else:
				btn.modulate = Color(0.7, 0.7, 0.7, 1)
		btn.pressed.connect(_on_upgrade_tier_tab_pressed.bind(tier))
		tier_row.add_child(btn)

	var sep2 = HSeparator.new()
	_facility_actions_container.add_child(sep2)

	var selected_tier: int = _upgrade_tier_tab

	if selected_tier <= current_tier:
		var status_label = Label.new()
		status_label.text = "Current Tier" if selected_tier == current_tier else "Unlocked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.5, 0.9, 0.5, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)
		_build_production_tier_benefits(selected_tier)

	elif selected_tier == current_tier + 1:
		var status_label = Label.new()
		status_label.text = "Available for Upgrade"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(1.0, 0.85, 0.4, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var upgrade_row = _create_production_facility_upgrade_row(facility, current_tier)
		_facility_actions_container.add_child(upgrade_row)

		var sep3 = HSeparator.new()
		_facility_actions_container.add_child(sep3)
		_build_production_tier_benefits(selected_tier)

	else:
		var status_label = Label.new()
		status_label.text = "Locked"
		status_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		status_label.modulate = Color(0.7, 0.7, 0.7, 1)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(status_label)

		var lock_msg = Label.new()
		lock_msg.text = "Requires Tier %d first" % (selected_tier - 1)
		lock_msg.modulate = Color(0.78, 0.78, 0.78, 1)
		lock_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(lock_msg)

		_build_production_tier_benefits(selected_tier)

	# Unlocks section (if any)
	_build_facility_unlocks_section()


## Display mixing facility tier benefits.
func _build_production_tier_benefits(tier: int) -> void:
	var benefits: Array[String] = []
	match tier:
		1:
			benefits.append("2-slot mixing")
			benefits.append("Common quality only")
		2:
			benefits.append("2-slot mixing")
			benefits.append("Uncommon & Rare quality")
		3:
			benefits.append("3-slot mixing unlocked!")
			benefits.append("Uncommon & Rare quality")
		4:
			benefits.append("3-slot mixing")
			benefits.append("Epic & Legendary quality")

	for benefit in benefits:
		var lbl = Label.new()
		lbl.text = benefit
		lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		lbl.modulate = Color(0.7, 0.85, 1.0, 1)
		_facility_actions_container.add_child(lbl)


## Build the crafting recipes section for a production facility (legacy, non-mixing).
func _build_crafting_recipes_section() -> void:
	if _current_facility == null:
		return

	var crafting_recipes = _current_facility.crafting_recipes
	if crafting_recipes.size() == 0:
		return

	var town_id = GameContext.get_current_town_id()
	var facility_id = _current_facility.facility_id
	var current_tier = GameContext.get_facility_tier(town_id, facility_id)

	var current_region: String = GameContext.get_current_region_id()
	var available_recipes: Array = []
	var locked_recipes: Array = []
	for recipe in crafting_recipes:
		var recipe_region: String = recipe.get("region", "")
		if recipe_region != "" and recipe_region != current_region:
			continue  # wrong region
		var required_tier = recipe.get("required_tier", 1)
		if required_tier <= current_tier:
			available_recipes.append(recipe)
		else:
			locked_recipes.append(recipe)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var craft_header = Label.new()
	craft_header.text = "-- Recipes (Tier %d / %d) --" % [current_tier, _current_facility.max_tier]
	craft_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(craft_header)

	if available_recipes.size() == 0:
		var no_recipes = Label.new()
		no_recipes.text = "(No recipes available at this tier)"
		no_recipes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_recipes)
	else:
		for recipe in available_recipes:
			var recipe_row = _create_production_recipe_row(recipe)
			_facility_actions_container.add_child(recipe_row)

	for recipe in locked_recipes:
		var locked_row = _create_locked_recipe_row(recipe)
		_facility_actions_container.add_child(locked_row)

	print("[Production] tier=%d recipes_shown=%d recipes_locked=%d" % [current_tier, available_recipes.size(), locked_recipes.size()])


## Create the upgrade row for a production facility (Chef, Alchemist)
func _create_production_facility_upgrade_row(facility, current_tier: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var town_id = GameContext.get_current_town_id()
	var next_tier = current_tier + 1
	var tier_key = str(next_tier)

	# Get upgrade cost — use centralized lookup that checks regional overrides first
	var upgrade_cost = GameContext.get_facility_upgrade_cost(facility.facility_id, next_tier)

	var gold_cost = int(upgrade_cost.get("gold", 0))
	var item_costs = upgrade_cost.get("items", [])

	# Cost display
	var cost_parts = []
	if gold_cost > 0:
		cost_parts.append("%dg" % gold_cost)

	var can_afford = GameContext.get_run_gold() >= gold_cost
	var run_items_dict = GameContext.get_run_items_dict()

	for item_cost in item_costs:
		var item_id = item_cost.get("item_id", "")
		var qty_needed = item_cost.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_afford = false

	var cost_label = Label.new()
	var cost_text = ", ".join(cost_parts) if cost_parts.size() > 0 else "Free"
	cost_label.text = "Upgrade to Tier %d: %s" % [next_tier, cost_text]
	cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_afford else Color(1, 0.5, 0.5, 1)
	row.add_child(cost_label)

	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade"
	upgrade_btn.custom_minimum_size = Vector2(80, 26)
	upgrade_btn.disabled = not can_afford
	# Use the generic facility upgrade handler which calls GameContext.upgrade_facility()
	upgrade_btn.pressed.connect(_on_facility_upgrade_pressed.bind(town_id, facility.facility_id))
	row.add_child(upgrade_btn)

	return row


## Create a row for a production recipe (direct crafting, no unlock required)
func _create_production_recipe_row(recipe: Dictionary) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var output_id = recipe.get("output_id", "")
	var output_qty = recipe.get("output_qty", 1)
	var inputs = recipe.get("inputs", [])

	# Get output item info
	var output_template = DataRegistry.get_item_template(output_id)
	var output_name = output_id
	if output_template != null and output_template.display_name != "":
		output_name = output_template.display_name

	# Recipe name with icon
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	if output_template != null:
		var icon_rect = output_template.create_icon_rect(18)
		if icon_rect != null:
			name_row.add_child(icon_rect)
	var name_label = Label.new()
	name_label.text = "Recipe: %s" % output_name
	name_row.add_child(name_label)
	container.add_child(name_row)

	# Show material costs and craft button
	var run_items_dict = GameContext.get_run_items_dict()
	var can_craft = true
	var cost_parts = []

	for input_item in inputs:
		var item_id = input_item.get("item_id", "")
		var qty_needed = input_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)

		var item_name = item_id
		var item_template = DataRegistry.get_item_template(item_id)
		if item_template != null and item_template.display_name != "":
			item_name = item_template.display_name

		cost_parts.append("%s %d/%d" % [item_name, qty_have, qty_needed])
		if qty_have < qty_needed:
			can_craft = false

	if inputs.size() > 0:
		var cost_label = Label.new()
		cost_label.text = "  Materials: %s" % ", ".join(cost_parts)
		cost_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		cost_label.modulate = Color(0.8, 0.8, 0.8, 1) if can_craft else Color(1, 0.5, 0.5, 1)
		container.add_child(cost_label)

	var craft_btn = Button.new()
	craft_btn.custom_minimum_size = Vector2(120, 28)
	if can_craft:
		craft_btn.text = "Craft"
		craft_btn.disabled = false
		craft_btn.pressed.connect(_on_craft_recipe_pressed.bind(recipe))
	else:
		craft_btn.text = "Need Materials"
		craft_btn.disabled = true
	container.add_child(craft_btn)

	return container


## Build the unlocks section for a production facility.
## Shows available unlocks with purchase buttons.
func _build_facility_unlocks_section() -> void:
	if _current_facility == null or _current_facility_id == "":
		return

	var town_id = GameContext.get_current_town_id()
	var available_unlocks = GameContext.get_available_facility_unlocks(_current_facility_id, town_id)

	if available_unlocks.is_empty():
		return

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Header
	var unlock_header = Label.new()
	unlock_header.text = "-- Available Unlocks --"
	unlock_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_header.modulate = Color(0.9, 0.8, 0.5, 1)
	_facility_actions_container.add_child(unlock_header)

	# Each unlock as a row
	for unlock in available_unlocks:
		var unlock_id = unlock.get("id", "")
		var label_text = unlock.get("label", unlock_id)
		var costs = unlock.get("costs", [])

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_facility_actions_container.add_child(row)

		# Unlock label
		var unlock_label = Label.new()
		unlock_label.text = label_text
		unlock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(unlock_label)

		# Cost display
		var cost_parts: Array = []
		for cost in costs:
			var item_id = cost.get("item_id", "")
			var qty = cost.get("qty", 0)
			var tpl = DataRegistry.get_item_template(item_id)
			var item_name = tpl.display_name if tpl != null else item_id
			var have = GameContext.get_run_item_count(item_id)
			var color_code = "green" if have >= qty else "red"
			cost_parts.append("[color=%s]%s x%d[/color]" % [color_code, item_name, qty])

		var cost_label = RichTextLabel.new()
		cost_label.bbcode_enabled = true
		cost_label.fit_content = true
		cost_label.scroll_active = false
		cost_label.custom_minimum_size.x = 200
		cost_label.text = " | ".join(cost_parts) if cost_parts.size() > 0 else "(free)"
		row.add_child(cost_label)

		# Purchase button
		var can_afford = GameContext.can_afford_facility_unlock(unlock)
		var purchase_btn = Button.new()
		purchase_btn.text = "Purchase"
		purchase_btn.disabled = not can_afford
		purchase_btn.pressed.connect(_on_facility_unlock_purchase.bind(unlock_id))
		row.add_child(purchase_btn)


## Handler for facility unlock purchase button.
func _on_facility_unlock_purchase(unlock_id: String) -> void:
	if _current_facility_id == "":
		return

	var town_id = GameContext.get_current_town_id()
	var success = GameContext.purchase_facility_unlock(_current_facility_id, unlock_id, town_id)

	if success:
		print("[TownScene] Unlock purchased: %s" % unlock_id)
		# Refresh the facility panel to update UI
		_show_facility_panel(_current_facility_id)
	else:
		print("[TownScene] Unlock purchase failed: %s" % unlock_id)


func _build_dungeon_ui() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null or town.dungeon_id == "":
		var no_dungeon = Label.new()
		no_dungeon.text = "(No dungeon available)"
		no_dungeon.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_dungeon)
		return

	# NPC header (blank portrait for now — dungeon board)
	if _current_facility != null:
		var menu = [
			{"view": "enter", "label": "Dungeon Expeditions"},
			{"view": "dangers", "label": "Dangers & Insurance"},
		]
		_build_npc_header(_current_facility, menu, _dungeon_view, _on_dungeon_view_pressed)

		var header_sep = HSeparator.new()
		_facility_actions_container.add_child(header_sep)

	var dungeon_id = town.dungeon_id
	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4

	match _dungeon_view:
		"enter":
			_build_dungeon_enter_view(dungeon, dungeon_id, floor_count)
		"dangers":
			_build_dungeon_dangers_view()


func _on_dungeon_view_pressed(view: String) -> void:
	if not GameContext.has_completed_tutorial("dungeon_dangers_seen"):
		GameContext.complete_tutorial("dungeon_dangers_seen")
	_dungeon_view = view
	_refresh_facility_panel()


## Dungeon enter view: floor selection + enter/continue/exit
func _build_dungeon_enter_view(dungeon, dungeon_id: String, floor_count: int) -> void:
	var unlocked_floor = GameContext.get_unlocked_floor(dungeon_id)
	var selected_floor = GameContext.get_selected_start_floor(dungeon_id)

	# Floor selection buttons
	var floor_header = Label.new()
	floor_header.text = "Select Starting Floor:"
	_facility_actions_container.add_child(floor_header)

	var floor_row = HBoxContainer.new()
	floor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	floor_row.add_theme_constant_override("separation", 6)
	_facility_actions_container.add_child(floor_row)

	# Check boss floor gate (Floor 4+ requires 9+ total facility tiers)
	var town_id_for_gate: String = GameContext.get_current_town_id()
	var boss_gate: Dictionary = GameContext.can_challenge_boss(town_id_for_gate)

	for floor_num in range(1, floor_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(60, 28)

		# Boss floor gate: final floor requires facility tier investment
		var is_boss_floor: bool = (floor_num >= floor_count)
		var floor_gated: bool = is_boss_floor and not boss_gate.ready

		if floor_num <= unlocked_floor and not floor_gated:
			btn.text = "F%d" % floor_num
			if floor_num == selected_floor:
				btn.text += "*"
				_apply_selected_button_style(btn)
			else:
				btn.pressed.connect(_on_dungeon_floor_selected.bind(dungeon_id, floor_num))
		elif floor_gated and floor_num <= unlocked_floor:
			btn.text = "F%d" % floor_num
			btn.disabled = true
			btn.modulate = Color(0.7, 0.3, 0.3, 1)
			btn.tooltip_text = "Requires %d+ total facility tiers (%d/%d)" % [boss_gate.required, boss_gate.current, boss_gate.required]
		else:
			btn.text = "F%d" % floor_num
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.7, 1)

		floor_row.add_child(btn)

	# Floor info for selected floor
	if dungeon != null:
		var sep_info = HSeparator.new()
		_facility_actions_container.add_child(sep_info)
		_build_dungeon_floor_info(dungeon, selected_floor)

	# Separator
	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Check if currently in dungeon
	var current_dungeon = GameContext.get_current_dungeon_id()
	var in_this_dungeon = current_dungeon == dungeon_id

	# Warning if no party recruited
	var has_party: bool = GameContext.selected_party.size() > 0
	if not has_party:
		var warn = Label.new()
		warn.text = "Recruit heroes at the Inn first!"
		warn.modulate = Color(1, 0.6, 0.4, 1)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_facility_actions_container.add_child(warn)

	# Enter Dungeon button
	var enter_btn = Button.new()
	enter_btn.text = "Enter Dungeon"
	enter_btn.custom_minimum_size = Vector2(180, 32)
	enter_btn.disabled = current_dungeon != "" or not has_party
	enter_btn.pressed.connect(_on_dungeon_enter_pressed.bind(dungeon_id))
	_facility_actions_container.add_child(enter_btn)

	# Continue Run button (only if in this dungeon)
	if in_this_dungeon:
		var continue_btn = Button.new()
		continue_btn.text = "Continue Run (Floor %d)" % GameContext.get_current_floor()
		continue_btn.custom_minimum_size = Vector2(180, 32)
		continue_btn.pressed.connect(_on_dungeon_continue_pressed)
		_facility_actions_container.add_child(continue_btn)

		var exit_btn = Button.new()
		exit_btn.text = "Exit Dungeon"
		exit_btn.custom_minimum_size = Vector2(180, 32)
		exit_btn.pressed.connect(_on_dungeon_exit_pressed)
		_facility_actions_container.add_child(exit_btn)


## Show info about the selected dungeon floor: theme, monster levels, loot icons
func _build_dungeon_floor_info(dungeon, floor_num: int) -> void:
	var floor_idx = floor_num - 1

	# Floor theme
	if floor_idx < dungeon.floor_theme.size():
		var theme_label = Label.new()
		theme_label.text = "Floor %d: %s" % [floor_num, dungeon.floor_theme[floor_idx]]
		theme_label.add_theme_font_size_override("font_size", GameContext.fs(15))
		theme_label.modulate = Color(1.0, 0.85, 0.4, 1)
		_facility_actions_container.add_child(theme_label)

	# Collect all monster IDs for this floor (T1 only on floors 1-2)
	var monster_ids: Array[String] = []
	if floor_idx < 2 and floor_idx < dungeon.tier1_by_floor.size():
		for mid in dungeon.tier1_by_floor[floor_idx]:
			if mid not in monster_ids:
				monster_ids.append(mid)
	if floor_idx < dungeon.tier2_by_floor.size():
		for mid in dungeon.tier2_by_floor[floor_idx]:
			if mid not in monster_ids:
				monster_ids.append(mid)
	if floor_idx < dungeon.elite_by_floor.size():
		for mid in dungeon.elite_by_floor[floor_idx]:
			if mid not in monster_ids:
				monster_ids.append(mid)

	# Monster level range (from base_stats.health as proxy — tier 1 vs tier 2)
	var min_hp = 9999
	var max_hp = 0
	var loot_table_ids: Array[String] = []
	for mid in monster_ids:
		var monster = DataRegistry.get_monster(mid)
		if monster == null:
			continue
		var hp = int(monster.base_stats.get("health", 0))
		if hp < min_hp:
			min_hp = hp
		if hp > max_hp:
			max_hp = hp
		if monster.loot_table_id != "" and monster.loot_table_id not in loot_table_ids:
			loot_table_ids.append(monster.loot_table_id)

	# Include boss loot table on the final floor
	if floor_num == dungeon.floor_count:
		for bid in [dungeon.boss_id, dungeon.alt_boss_id]:
			if bid == "":
				continue
			var boss_monster = DataRegistry.get_monster(bid)
			if boss_monster != null and boss_monster.loot_table_id != "" and boss_monster.loot_table_id not in loot_table_ids:
				loot_table_ids.append(boss_monster.loot_table_id)

	# Monster info line
	if monster_ids.size() > 0:
		var monster_label = Label.new()
		monster_label.text = "Monsters: %d types  |  HP %d-%d" % [monster_ids.size(), min_hp, max_hp]
		monster_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		monster_label.modulate = Color(0.8, 0.7, 0.7, 1)
		_facility_actions_container.add_child(monster_label)

	# Collect unique loot item IDs from loot tables
	var loot_item_ids: Array[String] = []
	for lt_id in loot_table_ids:
		var lt = DataRegistry.get_loot_table(lt_id)
		if lt == null:
			continue
		for entry in lt.entries:
			var item_id: String = ""
			if entry is Dictionary:
				item_id = entry.get("item_id", "")
			if item_id != "" and item_id not in loot_item_ids:
				loot_item_ids.append(item_id)

	# Show loot icons in a row separated by "x" labels
	if loot_item_ids.size() > 0:
		var drops_label = Label.new()
		drops_label.text = "Possible Drops:"
		drops_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		drops_label.modulate = Color(0.7, 0.85, 0.7, 1)
		_facility_actions_container.add_child(drops_label)

		var icon_row = HBoxContainer.new()
		icon_row.add_theme_constant_override("separation", 2)
		_facility_actions_container.add_child(icon_row)

		var first = true
		for item_id in loot_item_ids:
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl == null:
				continue
			if not first:
				var x_label = Label.new()
				x_label.text = "x"
				x_label.add_theme_font_size_override("font_size", GameContext.fs(11))
				x_label.modulate = Color(0.7, 0.7, 0.7, 1)
				icon_row.add_child(x_label)
			var icon_rect = tpl.create_icon_rect(20)
			if icon_rect != null:
				icon_rect.tooltip_text = tpl.display_name
				icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
				icon_row.add_child(icon_rect)
			first = false


## Dungeon dangers & insurance info view
func _build_dungeon_dangers_view() -> void:
	var danger_header = Label.new()
	danger_header.text = "-- Dangers of the Dungeon --"
	danger_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger_header.modulate = Color(1.0, 0.6, 0.4, 1)
	_facility_actions_container.add_child(danger_header)

	var death_info = Label.new()
	death_info.text = "If a hero falls in battle, they are gone forever. Permadeath is real — choose your battles wisely and know when to retreat."
	death_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_info.add_theme_font_size_override("font_size", GameContext.fs(14))
	_facility_actions_container.add_child(death_info)

	var sep1 = HSeparator.new()
	_facility_actions_container.add_child(sep1)

	var extract_header = Label.new()
	extract_header.text = "-- Extraction --"
	extract_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extract_header.modulate = Color(0.5, 1, 0.5, 1)
	_facility_actions_container.add_child(extract_header)

	var extract_info = Label.new()
	extract_info.text = "You can extract from the dungeon between floors to bank your loot and keep your heroes safe. Loot is only banked on successful extraction — dying means losing everything carried."
	extract_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	extract_info.add_theme_font_size_override("font_size", GameContext.fs(14))
	_facility_actions_container.add_child(extract_info)

	var sep2 = HSeparator.new()
	_facility_actions_container.add_child(sep2)

	var insurance_header = Label.new()
	insurance_header.text = "-- Insurance (Coming Soon) --"
	insurance_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insurance_header.modulate = Color(0.7, 0.7, 0.7, 1)
	_facility_actions_container.add_child(insurance_header)

	var insurance_info = Label.new()
	insurance_info.text = "In the future, you will be able to purchase insurance policies for your heroes before entering the dungeon. Insurance can protect against permanent death or recover a portion of lost loot."
	insurance_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	insurance_info.add_theme_font_size_override("font_size", GameContext.fs(14))
	insurance_info.modulate = Color(0.78, 0.78, 0.78, 1)
	_facility_actions_container.add_child(insurance_info)


func _on_dungeon_floor_selected(dungeon_id: String, floor_num: int) -> void:
	if GameContext.set_selected_start_floor(dungeon_id, floor_num):
		print("[DungeonFacility] Selected start floor=%d for %s" % [floor_num, dungeon_id])
		_refresh_facility_panel()


func _on_dungeon_enter_pressed(dungeon_id: String) -> void:
	if GameContext.selected_party.size() == 0:
		print("[DungeonFacility] Enter BLOCKED - no heroes in party!")
		var error_label = Label.new()
		error_label.text = "Need at least 1 hero! Visit Inn to recruit."
		error_label.modulate = Color(1, 0.5, 0.5, 1)
		if _facility_actions_container != null:
			_facility_actions_container.add_child(error_label)
		return

	# Formation warning: all heroes in middle row
	if _check_formation_warning():
		var proceed: bool = await _show_formation_warning()
		if not proceed:
			return

	GameContext.enter_dungeon(dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Entering %s at floor %d" % [dungeon_id, GameContext.get_current_floor()])
	_close_all_panels()
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _on_dungeon_continue_pressed() -> void:
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	print("[DungeonFacility] Continuing run at floor %d" % GameContext.get_current_floor())
	_close_all_panels()
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _on_dungeon_exit_pressed() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	GameContext.exit_to_town()
	print("[DungeonFacility] Exited dungeon %s" % dungeon_id)
	_refresh_facility_panel()
	_refresh_ui()


# ============================================================================
# FACILITY ACTION HANDLERS
# ============================================================================

func _on_storage_deposit_pressed() -> void:
	# Deposit gold from player wallet to bank (run stash)
	if GameContext.spend_player_gold(10):
		GameContext.add_run_gold(10)
		print("[Storage] deposit gold=10 wallet->bank")
		_refresh_facility_panel()

func _on_storage_withdraw_pressed() -> void:
	# Withdraw gold from bank (run stash) to player wallet
	if GameContext.spend_run_gold(10):
		GameContext.add_player_gold(10)
		print("[Storage] withdraw gold=10 bank->wallet")
		_refresh_facility_panel()


func _on_unequip_weapon_pressed() -> void:
	GameContext.unequip_item("weapon")
	_refresh_facility_panel()


func _on_unequip_offhand_pressed() -> void:
	GameContext.unequip_item("offhand")
	_refresh_facility_panel()


func _on_equip_item_pressed(item_id: String, slot: String, quality: int, affix_data: Dictionary = {}) -> void:
	_equip_pending_item_id = item_id
	_equip_pending_slot = slot
	_equip_pending_quality = quality
	_equip_pending_affix_data = affix_data
	_equip_selected_hero_id = ""
	print("[Storage] Equip flow started: item=%s slot=%s q=%d affix=%s" % [item_id, slot, quality, affix_data.get("affix_id", "")])
	_refresh_facility_panel()


## Hero picker: which hero should equip this item?
func _build_equip_hero_picker_ui() -> void:
	var tpl = DataRegistry.get_item_template(_equip_pending_item_id)
	var item_name: String = tpl.display_name if tpl != null else _equip_pending_item_id

	# Header
	var header = Label.new()
	header.text = "Equip %s — Choose Hero" % item_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", GameContext.fs(17))
	header.modulate = Color(1.0, 0.85, 0.4, 1)
	_facility_actions_container.add_child(header)

	# Slot info
	var slot_label = Label.new()
	slot_label.text = "Slot: %s" % _equip_pending_slot.capitalize()
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.modulate = Color(0.7, 0.7, 0.8, 1)
	_facility_actions_container.add_child(slot_label)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Cancel button at top
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 28)
	cancel_btn.pressed.connect(_on_equip_cancelled)
	_facility_actions_container.add_child(cancel_btn)

	# All owned heroes — party members first, then bench heroes
	var party = GameContext.get_selected_party()
	var all_heroes = GameContext.get_owned_heroes()
	var ordered_heroes: Array = []
	for hid in party:
		ordered_heroes.append(hid)
	for hero_dict in all_heroes:
		var hid: String = hero_dict.get("hero_id", "") if hero_dict is Dictionary else str(hero_dict)
		if hid != "" and hid not in party:
			ordered_heroes.append(hid)

	if ordered_heroes.size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "No heroes recruited. Visit the Inn to recruit."
		no_heroes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_heroes)
		return

	var showing_bench = false
	for hero_id in ordered_heroes:
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue

		var is_in_party: bool = hero_id in party

		# Section divider when switching from party to bench heroes
		if not is_in_party and not showing_bench:
			showing_bench = true
			var bench_sep = HSeparator.new()
			_facility_actions_container.add_child(bench_sep)
			var bench_label = Label.new()
			bench_label.text = "Bench Heroes"
			bench_label.add_theme_font_size_override("font_size", GameContext.fs(14))
			bench_label.modulate = Color(0.78, 0.78, 0.78, 1)
			_facility_actions_container.add_child(bench_label)

		var hero_name = hero.get("name", hero_id)
		var class_id = hero.get("class_id", "")
		var race_id = hero.get("race_id", "human")
		var hero_level = int(hero.get("level", 1))
		var class_data = DataRegistry.get_class_data(class_id)
		var cls_name: String = class_data.display_name if class_data != null and class_data.display_name != "" else class_id.capitalize()

		# Card panel for each hero (region-tinted)
		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.3, 0.5, 0.3, 0.6) if is_in_party else Color(0.3, 0.3, 0.3, 0.4)
		card_style.set_corner_radius_all(4)
		card_style.content_margin_left = 8
		card_style.content_margin_top = 6
		card_style.content_margin_right = 8
		card_style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", card_style)
		_facility_actions_container.add_child(card)

		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 12)
		card.add_child(card_hbox)

		# Hero portrait
		var ep_portrait_path: String = hero.get("portrait_path", "")
		if ep_portrait_path != "" and ResourceLoader.exists(ep_portrait_path):
			var ep_tex = ResourceLoader.load(ep_portrait_path) as Texture2D
			if ep_tex != null:
				var ep_rect = TextureRect.new()
				ep_rect.texture = ep_tex
				ep_rect.custom_minimum_size = Vector2(36, 36)
				ep_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ep_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_hbox.add_child(ep_rect)

		# Left: hero info
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_vbox)

		var party_tag: String = " (Party)" if is_in_party else ""
		var name_lbl = Label.new()
		name_lbl.text = "%s — %s Lv%d%s" % [hero_name, cls_name, hero_level, party_tag]
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		name_lbl.modulate = Color(0.6, 1, 0.6, 1) if is_in_party else Color(0.7, 0.7, 0.7, 1)
		info_vbox.add_child(name_lbl)

		# Show current item in this slot
		var equip = GameContext.get_hero_equipment(hero_id)
		var slot_data = equip.get(_equip_pending_slot, {})
		var current_item_id = slot_data.get("id", "")
		var current_quality = int(slot_data.get("quality", 0))

		var current_lbl = Label.new()
		current_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		if current_item_id != "":
			var current_tpl = DataRegistry.get_item_template(current_item_id)
			var current_name: String = current_tpl.display_name if current_tpl != null else current_item_id
			var q_prefix: String = ItemInstance.QUALITY_PREFIXES[current_quality] if current_quality < ItemInstance.QUALITY_PREFIXES.size() and current_quality > 0 else ""
			current_lbl.text = "Current: %s%s" % [q_prefix, current_name]
			current_lbl.modulate = Color(0.8, 0.7, 0.5, 1)
		else:
			current_lbl.text = "Current: Empty"
			current_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		info_vbox.add_child(current_lbl)

		# Right: select button
		var select_btn = Button.new()
		select_btn.text = "Select"
		select_btn.custom_minimum_size = Vector2(80, 32)
		select_btn.pressed.connect(_on_equip_hero_selected.bind(hero_id))
		card_hbox.add_child(select_btn)


## Equipment comparison: show old vs new stats, confirm or cancel.
func _build_equip_comparison_ui() -> void:
	var tpl = DataRegistry.get_item_template(_equip_pending_item_id)
	var item_name: String = tpl.display_name if tpl != null else _equip_pending_item_id
	var hero = GameContext.get_hero(_equip_selected_hero_id)
	var hero_name: String = hero.get("name", _equip_selected_hero_id)

	# Header
	var header = Label.new()
	header.text = "Equip %s on %s" % [item_name, hero_name]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", GameContext.fs(17))
	header.modulate = Color(1.0, 0.85, 0.4, 1)
	_facility_actions_container.add_child(header)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	# Get current and new item stats
	var equip = GameContext.get_hero_equipment(_equip_selected_hero_id)
	var slot_data = equip.get(_equip_pending_slot, {})
	var old_item_id = slot_data.get("id", "")
	var old_quality = int(slot_data.get("quality", 0))

	var old_stats: Dictionary = {}
	var old_name: String = "Empty"
	if old_item_id != "":
		var old_tpl = DataRegistry.get_item_template(old_item_id)
		if old_tpl != null:
			old_name = old_tpl.display_name
			var q_prefix: String = ItemInstance.QUALITY_PREFIXES[old_quality] if old_quality < ItemInstance.QUALITY_PREFIXES.size() and old_quality > 0 else ""
			# Include old item's affix prefix in name
			var old_affix_prefix: String = slot_data.get("affix_prefix", "")
			if old_affix_prefix != "":
				old_name = "%s %s%s" % [old_affix_prefix, q_prefix, old_name]
			else:
				old_name = "%s%s" % [q_prefix, old_name]
			var cmp_region_bonus: float = GameContext.get_completed_region_count() * 0.1
			old_stats = old_tpl.get_stat_bonuses_with_quality(old_quality, cmp_region_bonus)
			# Include old item's affix stats in comparison
			var old_affix_stats: Dictionary = slot_data.get("affix_stats", {})
			if old_affix_stats is Dictionary:
				for ak in old_affix_stats:
					old_stats[ak] = int(old_stats.get(ak, 0)) + int(old_affix_stats[ak])

	var cmp_rb: float = GameContext.get_completed_region_count() * 0.1
	var new_stats: Dictionary = tpl.get_stat_bonuses_with_quality(_equip_pending_quality, cmp_rb) if tpl != null else {}
	# Include affix stats in comparison
	var pending_affix_stats: Dictionary = _equip_pending_affix_data.get("affix_stats", {})
	if pending_affix_stats is Dictionary:
		for ak in pending_affix_stats:
			new_stats[ak] = int(new_stats.get(ak, 0)) + int(pending_affix_stats[ak])
	var new_q_prefix: String = ItemInstance.QUALITY_PREFIXES[_equip_pending_quality] if _equip_pending_quality < ItemInstance.QUALITY_PREFIXES.size() and _equip_pending_quality > 0 else ""
	var affix_prefix_str: String = _equip_pending_affix_data.get("affix_prefix", "")
	var new_display: String = "%s%s" % [new_q_prefix, item_name]
	if affix_prefix_str != "":
		new_display = "%s %s" % [affix_prefix_str, new_display]

	# Comparison panel
	var comp_panel = PanelContainer.new()
	var comp_style = StyleBoxFlat.new()
	comp_style.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	comp_style.border_width_left = 1
	comp_style.border_width_top = 1
	comp_style.border_width_right = 1
	comp_style.border_width_bottom = 1
	comp_style.border_color = Color(0.4, 0.4, 0.5, 0.6)
	comp_style.set_corner_radius_all(4)
	comp_style.content_margin_left = 12
	comp_style.content_margin_top = 8
	comp_style.content_margin_right = 12
	comp_style.content_margin_bottom = 8
	comp_panel.add_theme_stylebox_override("panel", comp_style)
	_facility_actions_container.add_child(comp_panel)

	var comp_vbox = VBoxContainer.new()
	comp_vbox.add_theme_constant_override("separation", 4)
	comp_panel.add_child(comp_vbox)

	# Slot label
	var slot_lbl = Label.new()
	slot_lbl.text = "Slot: %s" % _equip_pending_slot.capitalize()
	slot_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	slot_lbl.modulate = Color(0.7, 0.7, 0.8, 1)
	comp_vbox.add_child(slot_lbl)

	# Current item
	var old_header = Label.new()
	old_header.text = "Current: %s" % old_name
	old_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	old_header.modulate = Color(0.8, 0.5, 0.5, 1) if old_item_id != "" else Color(0.7, 0.7, 0.7, 1)
	comp_vbox.add_child(old_header)

	# New item
	var new_header = Label.new()
	new_header.text = "New: %s" % new_display
	new_header.add_theme_font_size_override("font_size", GameContext.fs(15))
	new_header.modulate = Color(0.5, 0.8, 0.5, 1)
	comp_vbox.add_child(new_header)

	# Stat comparison
	var stat_sep = HSeparator.new()
	comp_vbox.add_child(stat_sep)

	var stat_keys = ["health", "attack", "defense", "speed"]
	var stat_labels = {"health": "HP", "attack": "ATK", "defense": "DEF", "speed": "SPD"}

	for stat_key in stat_keys:
		var old_val = int(old_stats.get(stat_key, 0))
		var new_val = int(new_stats.get(stat_key, 0))
		if old_val == 0 and new_val == 0:
			continue

		var delta = new_val - old_val
		var stat_row = HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 8)
		comp_vbox.add_child(stat_row)

		var stat_name_lbl = Label.new()
		stat_name_lbl.text = "%s:" % stat_labels[stat_key]
		stat_name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_name_lbl.custom_minimum_size = Vector2(40, 0)
		stat_row.add_child(stat_name_lbl)

		var old_val_lbl = Label.new()
		old_val_lbl.text = "%d" % old_val
		old_val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		old_val_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		old_val_lbl.custom_minimum_size = Vector2(30, 0)
		stat_row.add_child(old_val_lbl)

		var arrow_lbl = Label.new()
		arrow_lbl.text = "→"
		arrow_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		stat_row.add_child(arrow_lbl)

		var new_val_lbl = Label.new()
		new_val_lbl.text = "%d" % new_val
		new_val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		new_val_lbl.custom_minimum_size = Vector2(30, 0)
		stat_row.add_child(new_val_lbl)

		var delta_lbl = Label.new()
		delta_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		if delta > 0:
			delta_lbl.text = "(+%d)" % delta
			delta_lbl.modulate = Color(0.3, 1.0, 0.3, 1)
		elif delta < 0:
			delta_lbl.text = "(%d)" % delta
			delta_lbl.modulate = Color(1.0, 0.3, 0.3, 1)
		else:
			delta_lbl.text = "(0)"
			delta_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		stat_row.add_child(delta_lbl)

	# Bag capacity comparison (for backpack slot)
	if _equip_pending_slot == "bag":
		var old_bag_cap = 0
		if old_item_id != "":
			var old_bag_tpl = DataRegistry.get_item_template(old_item_id)
			if old_bag_tpl != null:
				old_bag_cap = old_bag_tpl.bag_capacity_bonus
		var new_bag_cap = tpl.bag_capacity_bonus if tpl != null else 0
		var bag_delta = new_bag_cap - old_bag_cap

		var bag_row = HBoxContainer.new()
		bag_row.add_theme_constant_override("separation", 8)
		comp_vbox.add_child(bag_row)

		var bag_name_lbl = Label.new()
		bag_name_lbl.text = "Bag Slots:"
		bag_name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		bag_name_lbl.custom_minimum_size = Vector2(70, 0)
		bag_row.add_child(bag_name_lbl)

		var bag_old_lbl = Label.new()
		bag_old_lbl.text = "+%d" % old_bag_cap
		bag_old_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		bag_old_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		bag_row.add_child(bag_old_lbl)

		var bag_arrow = Label.new()
		bag_arrow.text = "→"
		bag_arrow.add_theme_font_size_override("font_size", GameContext.fs(14))
		bag_row.add_child(bag_arrow)

		var bag_new_lbl = Label.new()
		bag_new_lbl.text = "+%d" % new_bag_cap
		bag_new_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		bag_row.add_child(bag_new_lbl)

		var bag_delta_lbl = Label.new()
		bag_delta_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		if bag_delta > 0:
			bag_delta_lbl.text = "(+%d)" % bag_delta
			bag_delta_lbl.modulate = Color(0.3, 1.0, 0.3, 1)
		elif bag_delta < 0:
			bag_delta_lbl.text = "(%d)" % bag_delta
			bag_delta_lbl.modulate = Color(1.0, 0.3, 0.3, 1)
		else:
			bag_delta_lbl.text = "(0)"
			bag_delta_lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		bag_row.add_child(bag_delta_lbl)

	# Buttons
	var btn_sep = HSeparator.new()
	_facility_actions_container.add_child(btn_sep)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_facility_actions_container.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm Equip"
	confirm_btn.custom_minimum_size = Vector2(120, 32)
	confirm_btn.pressed.connect(_on_equip_confirmed)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.pressed.connect(_on_equip_cancelled)
	btn_row.add_child(cancel_btn)


func _on_equip_hero_selected(hero_id: String) -> void:
	_equip_selected_hero_id = hero_id
	print("[Storage] Equip hero selected: %s" % hero_id)
	_refresh_facility_panel()


func _on_equip_confirmed() -> void:
	print("[Storage] Equip confirmed: hero=%s slot=%s item=%s q=%d affix=%s" % [
		_equip_selected_hero_id, _equip_pending_slot, _equip_pending_item_id, _equip_pending_quality, _equip_pending_affix_data.get("affix_id", "")])
	GameContext.equip_hero_item(_equip_selected_hero_id, _equip_pending_slot, _equip_pending_item_id, _equip_pending_quality, _equip_pending_affix_data)
	_equip_pending_item_id = ""
	_equip_pending_slot = ""
	_equip_pending_quality = 0
	_equip_pending_affix_data = {}
	_equip_selected_hero_id = ""
	_refresh_facility_panel()


func _on_equip_cancelled() -> void:
	print("[Storage] Equip cancelled")
	_equip_pending_item_id = ""
	_equip_pending_slot = ""
	_equip_pending_quality = 0
	_equip_pending_affix_data = {}
	_equip_selected_hero_id = ""
	_refresh_facility_panel()


# ============================================================================
# STORAGE: BAG TRANSFER FLOW (consumable → hero bag)
# ============================================================================

func _on_bag_transfer_pressed(item_id: String) -> void:
	_bag_transfer_pending_item_id = item_id
	print("[Storage] Bag transfer started: item=%s" % item_id)
	_refresh_facility_panel()


func _build_bag_transfer_hero_picker_ui() -> void:
	var tpl = DataRegistry.get_item_template(_bag_transfer_pending_item_id)
	var item_name: String = tpl.display_name if tpl != null else _bag_transfer_pending_item_id

	var header = Label.new()
	header.text = "Send %s to Bag — Choose Hero" % item_name
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", GameContext.fs(17))
	header.modulate = Color(1.0, 0.85, 0.4, 1)
	_facility_actions_container.add_child(header)

	var sep = HSeparator.new()
	_facility_actions_container.add_child(sep)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 28)
	cancel_btn.pressed.connect(_on_bag_transfer_cancelled)
	_facility_actions_container.add_child(cancel_btn)

	# All owned heroes — party first, then bench
	var party = GameContext.get_selected_party()
	var all_heroes = GameContext.get_owned_heroes()
	var ordered_heroes: Array = []
	for hid in party:
		ordered_heroes.append(hid)
	for hero_dict in all_heroes:
		var hid: String = hero_dict.get("hero_id", "") if hero_dict is Dictionary else str(hero_dict)
		if hid != "" and hid not in party:
			ordered_heroes.append(hid)

	if ordered_heroes.size() == 0:
		var no_heroes = Label.new()
		no_heroes.text = "No heroes recruited. Visit the Inn to recruit."
		no_heroes.modulate = Color(0.78, 0.78, 0.78, 1)
		_facility_actions_container.add_child(no_heroes)
		return

	var showing_bench = false
	for hero_id in ordered_heroes:
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue

		var is_in_party: bool = hero_id in party

		if not is_in_party and not showing_bench:
			showing_bench = true
			var bench_sep = HSeparator.new()
			_facility_actions_container.add_child(bench_sep)
			var bench_label = Label.new()
			bench_label.text = "Bench Heroes"
			bench_label.add_theme_font_size_override("font_size", GameContext.fs(14))
			bench_label.modulate = Color(0.78, 0.78, 0.78, 1)
			_facility_actions_container.add_child(bench_label)

		var hero_name = hero.get("name", hero_id)
		var class_id = hero.get("class_id", "")
		var hero_level = int(hero.get("level", 1))
		var class_data = DataRegistry.get_class_data(class_id)
		var cls_name: String = class_data.display_name if class_data != null and class_data.display_name != "" else class_id.capitalize()

		var bag_items = GameContext.get_hero_bag(hero_id)
		var bag_cap = GameContext.get_hero_bag_capacity(hero_id)
		var bag_used = bag_items.size()
		var bag_full: bool = bag_used >= bag_cap

		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = _region_palette.get("bg_medium", Color(0.15, 0.18, 0.22, 0.9))
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.3, 0.5, 0.3, 0.6) if is_in_party else Color(0.3, 0.3, 0.3, 0.4)
		card_style.set_corner_radius_all(4)
		card_style.content_margin_left = 8
		card_style.content_margin_top = 6
		card_style.content_margin_right = 8
		card_style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", card_style)
		_facility_actions_container.add_child(card)

		var card_hbox = HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 12)
		card.add_child(card_hbox)

		# Hero portrait
		var ep_portrait_path: String = hero.get("portrait_path", "")
		if ep_portrait_path != "" and ResourceLoader.exists(ep_portrait_path):
			var ep_tex = ResourceLoader.load(ep_portrait_path) as Texture2D
			if ep_tex != null:
				var ep_rect = TextureRect.new()
				ep_rect.texture = ep_tex
				ep_rect.custom_minimum_size = Vector2(36, 36)
				ep_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ep_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				card_hbox.add_child(ep_rect)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		card_hbox.add_child(info_vbox)

		var party_tag: String = " (Party)" if is_in_party else ""
		var name_lbl = Label.new()
		name_lbl.text = "%s — %s Lv%d%s" % [hero_name, cls_name, hero_level, party_tag]
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		name_lbl.modulate = Color(0.6, 1, 0.6, 1) if is_in_party else Color(0.7, 0.7, 0.7, 1)
		info_vbox.add_child(name_lbl)

		# Bag capacity indicator
		var bag_lbl = Label.new()
		bag_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		bag_lbl.text = "Bag: %d / %d" % [bag_used, bag_cap]
		bag_lbl.modulate = Color(1, 0.4, 0.4, 1) if bag_full else Color(0.7, 0.8, 0.7, 1)
		info_vbox.add_child(bag_lbl)

		# Select button (disabled if bag full)
		var select_btn = Button.new()
		if bag_full:
			select_btn.text = "Full"
			select_btn.disabled = true
		else:
			select_btn.text = "Select"
			select_btn.pressed.connect(_on_bag_transfer_hero_selected.bind(hero_id))
		select_btn.custom_minimum_size = Vector2(80, 32)
		card_hbox.add_child(select_btn)


func _on_bag_transfer_hero_selected(hero_id: String) -> void:
	var item_id = _bag_transfer_pending_item_id
	var success = GameContext.move_item_stash_to_hero_bag(hero_id, item_id, 1)
	if success:
		var hero = GameContext.get_hero(hero_id)
		var hero_name = hero.get("name", hero_id)
		print("[Storage] Bag transfer: item=%s -> hero=%s (%s)" % [item_id, hero_id, hero_name])
	else:
		print("[Storage] Bag transfer failed: item=%s hero=%s" % [item_id, hero_id])
	_bag_transfer_pending_item_id = ""
	_refresh_facility_panel()


func _on_bag_transfer_cancelled() -> void:
	print("[Storage] Bag transfer cancelled")
	_bag_transfer_pending_item_id = ""
	_refresh_facility_panel()


func _on_item_transfer_pressed(item_id: String, action: String) -> void:
	if action == "deposit":
		# Move from player inventory to run stash (bank)
		if GameContext.remove_player_item(item_id, 1):
			GameContext.add_run_item(item_id, 1)
			print("[Storage] transfer item=%s qty=1 wallet->bank" % item_id)
	else:  # withdraw
		# Move from run stash (bank) to player inventory
		if GameContext.remove_run_item(item_id, 1):
			GameContext.add_player_item(item_id, 1)
			print("[Storage] transfer item=%s qty=1 bank->wallet" % item_id)
	_refresh_facility_panel()


func _on_unlock_pressed(unlock: Dictionary) -> void:
	var unlock_group = unlock.get("unlock_group", "")
	if unlock_group == "":
		print("[Unlock] group=(empty) result=fail reason=no_group_id")
		return

	# Check if already unlocked
	if GameContext.has_unlocked_group(unlock_group):
		print("[Unlock] group=%s result=fail reason=already_unlocked" % unlock_group)
		return

	# Get costs and check affordability
	var costs = unlock.get("costs", [])
	if not GameContext.can_afford_run_materials(costs):
		print("[Unlock] group=%s result=fail reason=cannot_afford" % unlock_group)
		return

	# Spend materials from run stash
	if not GameContext.spend_run_materials(costs):
		print("[Unlock] group=%s result=fail reason=spend_failed" % unlock_group)
		return

	# Unlock the group
	GameContext.unlock_group(unlock_group)
	print("[Unlock] group=%s result=success" % unlock_group)
	_refresh_facility_panel()


func _on_facility_upgrade_pressed(town_id: String, facility_id: String) -> void:
	var tier_before = GameContext.get_facility_tier(town_id, facility_id)

	# Get upgrade cost for logging — use centralized lookup (regional overrides)
	var next_tier = tier_before + 1
	var cost_data = GameContext.get_facility_upgrade_cost(facility_id, next_tier)
	var cost_gold = int(cost_data.get("gold", 0))
	var cost_items = cost_data.get("items", [])
	var item_parts: Array = []
	for ic in cost_items:
		item_parts.append("%s=%d" % [ic.get("item_id", "?"), ic.get("qty", 0)])
	var cost_items_str: String = ", ".join(item_parts) if item_parts.size() > 0 else "none"

	if GameContext.upgrade_facility(town_id, facility_id):
		var tier_after = GameContext.get_facility_tier(town_id, facility_id)
		# Facilities v4: Log with standardized format
		print("[Facility] upgrade facility=%s town=%s tier_before=%d tier_after=%d cost_gold=%d cost_items=[%s]" % [
			facility_id, town_id, tier_before, tier_after, cost_gold, cost_items_str])
	else:
		print("[Facility] upgrade_failed facility=%s town=%s tier=%d" % [facility_id, town_id, tier_before])
	_refresh_facility_panel()


func _on_training_pressed(buff_type: String, cost: int) -> void:
	if GameContext.purchase_training_buff(buff_type, cost):
		print("[Training] Purchased %s buff for %d gold" % [buff_type, cost])
		_refresh_facility_panel()


func _refresh_facility_panel() -> void:
	# Re-get facility and rebuild the current panel's content
	if _current_facility_id == "" or not _open_panels.has(_current_facility_id):
		_refresh_ui()
		return

	# Ensure _facility_actions_container points to the right panel
	var info = _open_panels[_current_facility_id]
	_facility_actions_container = info.get("actions_container")

	var facility = DataRegistry.get_facility(_current_facility_id) if DataRegistry.has_method("get_facility") else null
	_current_facility = facility

	# Update title bar (tier + gold)
	if facility != null:
		var town_id = GameContext.get_current_town_id()
		var current_tier = GameContext.get_facility_tier(town_id, _current_facility_id)
		info["title_label"].text = "%s T%d" % [facility.display_name, current_tier]
	info["gold_label"].text = "Gold: %d" % GameContext.get_run_gold()

	if facility != null:
		_create_facility_actions(facility)

	# Only refresh gold/stash labels — NOT the heroes section (avoids flickering party cards)
	_update_location_labels()
	_update_button_states()
	_populate_stash_list()


# ============================================================================
# DEBUG HOTKEYS - Dungeon flow testing (kept for convenience)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Shift+F6: advance room only (for testing multi-room floors)
		if event.keycode == KEY_F6 and event.shift_pressed:
			_debug_advance_room()
			return

		match event.keycode:
			KEY_F5:
				_debug_enter_dungeon()
			KEY_F6:
				_debug_advance_floor()
			KEY_F7:
				_debug_exit_to_town()


func _debug_enter_dungeon() -> void:
	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null

	if town == null:
		print("[DEBUG] EnterDungeon FAILED - no town data for '%s'" % town_id)
		return

	if town.dungeon_id == "":
		print("[DEBUG] EnterDungeon FAILED - town '%s' has no dungeon_id" % town_id)
		return

	# Enter dungeon and set phase to COMBAT
	GameContext.enter_dungeon(town.dungeon_id)
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] EnterDungeon dungeon=%s floor=%d" % [
		GameContext.get_current_dungeon_id(),
		GameContext.get_current_floor()
	])

	# Route through boot
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _debug_advance_floor() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[DEBUG] AdvanceFloor FAILED - not in a dungeon")
		return

	# Advance floor and set phase to COMBAT
	GameContext.advance_floor()
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] AdvanceFloor floor=%d room=%d/%d" % [
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _debug_advance_room() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()

	if dungeon_id == "":
		print("[DEBUG] AdvanceRoom FAILED - not in a dungeon")
		return

	# Advance room and set phase to COMBAT
	GameContext.advance_room()
	GameContext.set_phase(GameContext.GamePhase.COMBAT)

	print("[DEBUG] AdvanceRoom floor=%d room=%d/%d" % [
		GameContext.get_current_floor(),
		GameContext.get_current_room_index() + 1,
		GameContext.get_rooms_per_floor()
	])

	# Route through boot
	get_tree().call_deferred("change_scene_to_file", BOOT_SCENE_PATH)


func _debug_exit_to_town() -> void:
	# Guard: only allow exit if actually in a dungeon
	if GameContext.get_current_dungeon_id() == "":
		print("[DEBUG] ExitToTown ignored (not in dungeon)")
		return

	# Exit to town (this sets phase to TOWN internally)
	GameContext.exit_to_town()

	print("[DEBUG] ExitToTown")

	# Refresh UI instead of reloading scene
	_refresh_ui()


## Static helper: format the XP progress line for a hero card.
## Used by _create_hero_row and tested by the headless suite.
static func format_xp_line(xp: int, next_level_xp: int, is_max_level: bool) -> String:
	if is_max_level:
		return "XP: MAX"
	return "XP: %d / %d" % [xp, next_level_xp]


## Static helper: format the HP line for a hero card.
static func format_hp_line(current_hp: int, max_hp: int) -> String:
	return "HP: %d / %d" % [current_hp, max_hp]


## Build a stat breakdown tooltip for Inn hero cards.
## Shows where each stat comes from: class base, race modifiers, gear bonuses.
static func build_inn_stat_tooltip(stat_name: String, hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return stat_name

	var class_id = hero.get("class_id", "")
	var race_id = hero.get("race_id", "human")
	var level = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)

	var stat_key = stat_name.to_lower()  # "attack", "defense", "speed"

	# Get class base at level
	var base_value = 0
	if class_data != null:
		var base_stats = class_data.get_stats_at_level(level)
		base_value = int(base_stats.get(stat_key, 0))

	# Get race modifier
	var race_bonus = 0
	var race_name = race_id.capitalize()
	if race_data != null:
		race_bonus = int(race_data.stat_modifiers.get(stat_key, 0))
		if race_data.display_name != "":
			race_name = race_data.display_name

	# Get gear bonus
	var eff_stats = GameContext.get_hero_effective_stats(hero_id)
	var gear_bonus_dict = eff_stats.get("gear_bonus", {})
	var gear_bonus = int(gear_bonus_dict.get(stat_key, 0))

	# Stat descriptions explaining gameplay impact
	var stat_descriptions: Dictionary = {
		"health": "HP (Hit Points)\nHero is defeated at 0 HP.\nRestored by healing effects and potions.",
		"attack": "ATK (Attack Power)\nDetermines physical damage dealt.\nDamage = max(1, ATK - target DEF)",
		"defense": "DEF (Defense)\nReduces incoming physical damage.\nDamage = max(1, attacker ATK - DEF)",
		"speed": "SPD (Speed)\nDetermines turn order each round.\nHigher speed acts first.\n10+ = 2 actions per turn\n20+ = 3 actions per turn",
	}

	# Build tooltip
	var parts: Array = []
	if stat_descriptions.has(stat_key):
		parts.append(stat_descriptions[stat_key])
	else:
		parts.append(stat_name)
	parts.append("")
	parts.append("Base (Lv %d): %d" % [level, base_value])

	if race_bonus != 0:
		if race_bonus > 0:
			parts.append("%s: +%d" % [race_name, race_bonus])
		else:
			parts.append("%s: %d" % [race_name, race_bonus])

	if gear_bonus != 0:
		if gear_bonus > 0:
			parts.append("Gear: +%d" % gear_bonus)
		else:
			parts.append("Gear: %d" % gear_bonus)

	var total = base_value + race_bonus + gear_bonus
	if race_bonus != 0 or gear_bonus != 0:
		parts.append("Total: %d" % total)

	return "\n".join(parts)


## Build a combined stat breakdown tooltip for all combat stats (ATK/DEF/SPD).
## Used for the single stats line in Inn hero cards.
static func build_inn_stats_combined_tooltip(hero_id: String) -> String:
	var sections: Array = []
	sections.append(build_inn_stat_tooltip("Attack", hero_id))
	sections.append("")
	sections.append(build_inn_stat_tooltip("Defense", hero_id))
	sections.append("")
	sections.append(build_inn_stat_tooltip("Speed", hero_id))
	return "\n".join(sections)


## Build a tooltip for the Race label in Inn hero cards.
## Shows race description, stat modifiers, racial passive, and XP rate.
static func build_race_tooltip(hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return "Race"

	var race_id = hero.get("race_id", "human")
	var race_data = DataRegistry.get_race(race_id)
	if race_data == null:
		return race_id.capitalize()

	var parts: Array = []
	parts.append(race_data.display_name if race_data.display_name != "" else race_id.capitalize())
	if race_data.description != "":
		parts.append(race_data.description)

	# Stat modifiers
	var mod_parts: Array = []
	var stat_keys = ["health", "attack", "defense", "speed"]
	var stat_labels = ["HP", "ATK", "DEF", "SPD"]
	for i in range(stat_keys.size()):
		var val = int(race_data.stat_modifiers.get(stat_keys[i], 0))
		if val != 0:
			var sign_str: String = "+" + str(val) if val > 0 else str(val)
			mod_parts.append("%s %s" % [stat_labels[i], sign_str])
	if mod_parts.size() > 0:
		parts.append("Stat Modifiers: %s" % ", ".join(mod_parts))
	else:
		parts.append("Stat Modifiers: None (balanced)")

	# Racial passive
	var passive_id = race_data.racial_passive_id
	if passive_id != "":
		var passive = DataRegistry.get_passive(passive_id)
		if passive != null:
			parts.append("")
			parts.append("Passive: %s" % passive.display_name)
			if passive.description != "":
				parts.append("  %s" % passive.description)
		else:
			parts.append("Passive: %s" % passive_id.capitalize().replace("_", " "))

	# XP rate
	var xp_mod = race_data.xp_modifier
	if xp_mod != 1.0:
		parts.append("XP Rate: %.1fx" % xp_mod)
	else:
		parts.append("XP Rate: 1.0x (standard)")

	return "\n".join(parts)


## Build a tooltip for the Class label in Inn hero cards.
## Shows class description, archetype, weapons, abilities, and passives.
static func build_class_tooltip(hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return "Class"

	var class_id = hero.get("class_id", "")
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data == null:
		return class_id.capitalize()

	var parts: Array = []
	var hero_level: int = int(hero.get("level", 1))

	# Header: name + archetype
	var cls_name: String = class_data.display_name if class_data.display_name != "" else class_id.capitalize()
	var archetype: String = class_data.archetype.capitalize() if class_data.archetype != "" else "Unknown"
	parts.append("%s (%s)" % [cls_name, archetype])

	# Description
	if class_data.description != "":
		parts.append(class_data.description)

	# Weapons
	if class_data.weapon_types.size() > 0:
		parts.append("Weapons: %s" % ", ".join(class_data.weapon_types))

	# Abilities
	var ability_ids = [class_data.ability_a_id, class_data.ability_b_id]
	var ability_labels = ["Ability A", "Ability B"]
	var ability_slots = ["ability_a", "ability_b"]
	for i in range(ability_ids.size()):
		var aid = ability_ids[i]
		if aid == "":
			continue
		var ability = DataRegistry.get_ability(aid)
		var ab_name: String = ability.display_name if ability != null else aid.capitalize().replace("_", " ")
		var unlocked: bool = GameContext.is_ability_slot_unlocked(ability_slots[i], hero_level)
		var lock_tag: String = ""
		if not unlocked:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(ability_slots[i], 1)
			lock_tag = " [Lv %d]" % req_lv
		parts.append("")
		parts.append("%s: %s%s" % [ability_labels[i], ab_name, lock_tag])
		if ability != null and ability.description != "":
			parts.append("  %s" % ability.description)

	# Passives
	var passive_ids = [class_data.passive_a_id, class_data.passive_b_id]
	var passive_labels = ["Passive A", "Passive B"]
	var passive_slots = ["passive_a", "passive_b"]
	for i in range(passive_ids.size()):
		var pid = passive_ids[i]
		if pid == "":
			continue
		var passive = DataRegistry.get_passive(pid)
		var ps_name: String = passive.display_name if passive != null else pid.capitalize().replace("_", " ")
		var ps_unlocked: bool = GameContext.is_ability_slot_unlocked(passive_slots[i], hero_level)
		var ps_lock_tag: String = ""
		if not ps_unlocked:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get(passive_slots[i], 1)
			ps_lock_tag = " [Lv %d]" % req_lv
		parts.append("")
		parts.append("%s: %s%s" % [passive_labels[i], ps_name, ps_lock_tag])
		if passive != null and passive.description != "":
			parts.append("  %s" % passive.description)

	return "\n".join(parts)


## Build a tooltip for the Level label in Inn hero cards.
## Shows XP progress and stat growth per level from class data.
static func build_level_tooltip(hero_id: String) -> String:
	var hero = GameContext.get_hero(hero_id)
	if hero.is_empty():
		return "Level"

	var level = int(hero.get("level", 1))
	var xp = int(hero.get("xp", 0))
	var class_id = hero.get("class_id", "")
	var class_data = DataRegistry.get_class_data(class_id)

	var parts: Array = []
	parts.append("Level %d" % level)

	# XP progress
	var is_max: bool = level >= GameContext.MAX_HERO_LEVEL
	if is_max:
		parts.append("XP: MAX LEVEL")
	else:
		var next_xp = GameContext.get_xp_for_level(level + 1)
		var remaining = next_xp - xp
		parts.append("XP: %d / %d (%d to next)" % [xp, next_xp, remaining])

	# Stat growth per level
	if class_data != null:
		var growth = class_data.stat_growth
		if not growth.is_empty():
			parts.append("")
			parts.append("Stat Growth Per Level:")
			var growth_parts: Array = []
			if int(growth.get("health", 0)) != 0:
				growth_parts.append("HP: +%d" % int(growth.get("health", 0)))
			if int(growth.get("attack", 0)) != 0:
				growth_parts.append("ATK: +%d" % int(growth.get("attack", 0)))
			if int(growth.get("defense", 0)) != 0:
				growth_parts.append("DEF: +%d" % int(growth.get("defense", 0)))
			if int(growth.get("speed", 0)) != 0:
				growth_parts.append("SPD: +%d" % int(growth.get("speed", 0)))
			if growth_parts.size() > 0:
				parts.append("  %s" % ", ".join(growth_parts))

	return "\n".join(parts)
