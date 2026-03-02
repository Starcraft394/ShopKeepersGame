extends Control

# ============================================================================
# TOWN HUB — Building sprite overlay with transparent background
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

# Building sprite mapping: facility_id → sprite filename (without extension)
const BUILDING_SPRITES: Dictionary = {
	"blacksmith": "building_blacksmith",
	"enchanter": "building_enchanter",
	"huntsman": "building_huntsman",
	"chef": "building_chef",
	"alchemist": "building_alchemist",
	"inn": "building_inn",
	"storage": "building_storage",
	"training_hall": "building_training",
}

# Fallback: facility_type → sprite filename
const BUILDING_SPRITES_BY_TYPE: Dictionary = {
	"dungeon": "building_dungeon",
	"shop": "building_shop",
	"inn": "building_inn",
	"storage": "building_storage",
	"training_hall": "building_training",
	"blacksmith": "building_blacksmith",
	"enchanter": "building_enchanter",
	"huntsman": "building_huntsman",
	"chef": "building_chef",
	"alchemist": "building_alchemist",
}

const BUILDING_SPRITE_PATH := "res://Assets/Backgrounds/"

## Resolve building sprite path, preferring region-specific variant.
## Checks Assets/Backgrounds/Buildings/R{N}/{sprite_key}.png first,
## falls back to Assets/Backgrounds/{sprite_key}.png (R1 base).
func _resolve_building_sprite_path(sprite_key: String) -> String:
	var region_num: int = GameContext.current_region
	if region_num >= 2 and region_num <= 7:
		var regional_path: String = "res://Assets/Backgrounds/Buildings/R%d/%s.png" % [region_num, sprite_key]
		if ResourceLoader.exists(regional_path):
			return regional_path
	return BUILDING_SPRITE_PATH + sprite_key + ".png"

## Preferred display order for facility buildings (by facility_id or facility_type).
## Row 1 = first 5, Row 2 = next 5.  Facilities not listed here append at the end.
const FACILITY_DISPLAY_ORDER: Array = [
	"blacksmith", "inn", "dungeon", "shop", "storage",
	"huntsman", "enchanter", "chef", "alchemist", "training_hall",
]

## Height of the dark backing panel behind the party bar (px).
## Buildings and background stop above this zone.
const PARTY_BAR_ZONE_HEIGHT := 200

## Base building dimensions (at sf=1, before scaling).
const BASE_BUILDING_SIZE := 140.0
const BASE_SHADOW_W := 112.0
const BASE_SHADOW_H := 14.0
const BASE_SHADOW_OX := 14.0
const BASE_SHADOW_OY := 136.0
const BASE_WRAPPER_H := 148.0
const BASE_GRID_TOP := 42.0   # Clears the town header panel
const BASE_GRID_BOTTOM_EXTRA := 8.0
const BASE_ROW_SEP := 8
const BASE_COL_SEP := 12
const BASE_BLD_LABEL_FS := 12
const BASE_HEADER_FS := 17

## Total space the 2×5 building layout needs at sf=1 (used to compute scale factor).
## Width:  5 buildings * 140 + 4 gaps * 12 = 748
## Height: header(42) + 2 rows * ~166 (wrapper+sep+label) + row_gap(8) + bottom(8) = 390
const BASE_LAYOUT_W := 748.0
const BASE_LAYOUT_H := 390.0

@onready var _nav_vbox: VBoxContainer = %NavVBox
@onready var _nav_header_label: Label = %NavHeaderLabel
@onready var _content_area: Control = %ContentArea

var _town_scene_instance: Control = null
var _content_layout: VBoxContainer = null
var _building_spacer: Control = null
var _building_overlay: Control = null
var _party_bar_vbox: VBoxContainer = null
var _nav_facility_buttons: Array[Button] = []
var _nav_travel_buttons: Array[Button] = []
var _icon_cache: Dictionary = {}  # icon_path → Texture2D
var _pending_restore_focus_index: int = -1

# ---- LAYOUT EDITOR (dev tool — remove after finalizing) ----
var _layout_edit_mode: bool = false
var _layout_btn: Button = null
var _layout_print_btn: Button = null
var _dev_tools_overlay: CanvasLayer = null
var _layout_data: Dictionary = {}       # facility_id -> { "position": Vector2, "size": Vector2 }
var _layout_wrappers: Dictionary = {}   # facility_id -> Control node
var _layout_hud_labels: Dictionary = {} # facility_id -> Label node
var _layout_dragging_id: String = ""
var _layout_drag_offset: Vector2 = Vector2.ZERO
const LAYOUT_SCALE_STEP := 8
const LAYOUT_MIN_SIZE := 60
const LAYOUT_MAX_SIZE := 400
var _resize_timer: SceneTreeTimer = null


## Returns a uniform scale factor so the 2×5 building grid fits the background area.
## Computed from viewport size using the same offsets as _constrain_background(),
## so buildings always match the visible background bounds at any window size.
func _building_scale() -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	# Background area matches _constrain_background() offsets:
	# width  = viewport_w - 188(left) - 16(right) = viewport_w - 204
	# height = viewport_h - 16(top) - 16(bottom) - PARTY_BAR_ZONE_HEIGHT
	var area_w: float = maxf(100, vp.x - 204)
	var area_h: float = maxf(100, vp.y - 32 - PARTY_BAR_ZONE_HEIGHT)
	var sx: float = area_w / BASE_LAYOUT_W
	var sy: float = area_h / BASE_LAYOUT_H
	return maxf(0.5, minf(sx, sy))


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
	print("[TownHub] Scene loaded — building overlay active")

	# Apply background art (graceful fallback to ColorRect if not found)
	var town_id: String = GameContext.get_current_town_id()
	BackgroundManager.apply_background(self, "town", "%s_T1" % town_id)

	# Apply town entry reset (heal survivors, remove dead heroes, refresh shops).
	# This MUST run before embedding TownScene because the boot router changes
	# the phase from TOWN to TOWN_HUB, which causes TownScene's own phase check
	# to skip the reset.  Covers the defeat→town path.
	GameContext.apply_town_entry_reset()

	_embed_town_scene()
	_build_nav_rail()
	_build_building_overlay()
	_setup_background_zones()
	GameContext.location_changed.connect(_on_location_changed)
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Show overlays sequentially — each must finish before the next starts,
	# otherwise multiple dialogs/tutorials stack on screen simultaneously.
	await _check_campaign_dialogs()
	await _check_campaign_quest_completion()
	await _check_campaign_quest_start()
	await _check_first_launch_guidance()
	await _check_telemetry_consent()
	await _check_side_quest_completion()
	await _check_side_quest_offer()
	await _check_facilities_overview()
	_check_region_unlock_notification()
	_register_focus_zones()


## Show campaign story dialogs triggered by entering town.
func _check_campaign_dialogs() -> void:
	# Region first arrival
	var overlay = CampaignDialog.try_show(self, "region_first_arrival")
	if overlay != null:
		await overlay.dialog_finished
	# Herald visits (flag-gated)
	overlay = CampaignDialog.try_show(self, "herald_visit")
	if overlay != null:
		await overlay.dialog_finished
	# Keeper story beats (flag-gated, fire on town entry)
	overlay = CampaignDialog.try_show(self, "keeper_story")
	if overlay != null:
		await overlay.dialog_finished


## Check if the active campaign quest is complete and show completion overlay.
func _check_campaign_quest_completion() -> void:
	if CampaignQuestSystem.on_town_return():
		print("[TownHub] Campaign quest objectives met — showing completion")
		var overlay = CampaignQuestSystem.show_completion_overlay(self)
		if overlay != null:
			await overlay.dialog_finished
		CampaignQuestSystem.complete_quest()


## Auto-assign the first available campaign quest if none is active.
func _check_campaign_quest_start() -> void:
	if GameContext.active_campaign_quest != null:
		return
	var next_id: String = CampaignQuestSystem.get_next_available_quest_id()
	if next_id != "":
		CampaignQuestSystem.start_quest(next_id)


## Check if any active side quests are complete and show reward overlay.
func _check_side_quest_completion() -> void:
	# Copy array to avoid modification during iteration
	var quests: Array = GameContext.get_active_side_quests().duplicate()
	for quest in quests:
		if quest is SideQuestData and quest.check_completion():
			print("[TownHub] Side quest complete: %s" % quest.quest_id)
			var overlay = SideQuestSystem.show_quest_complete(self, quest)
			if overlay != null:
				await overlay.reward_collected


## Roll for a new side quest offer on dungeon return.
func _check_side_quest_offer() -> void:
	if not GameContext.returned_from_dungeon:
		return
	GameContext.returned_from_dungeon = false  # Consume the flag

	var region_id: String = GameContext.get_current_region_id()
	var quest = SideQuestSystem.try_generate_quest(region_id)
	if quest != null:
		# Tutorial: explain side quests on first offer
		var tut_overlay = TutorialOverlay.try_show(self, "tutorial_side_quests")
		if tut_overlay != null:
			await tut_overlay.tutorial_finished
		print("[TownHub] Offering side quest: %s" % quest.quest_id)
		var overlay = SideQuestSystem.show_quest_offer(self, quest)
		if overlay != null:
			await overlay.quest_resolved


# ============================================================================
# EMBED TOWN SCENE (hidden — only CanvasLayer popups render)
# ============================================================================

func _embed_town_scene() -> void:
	_town_scene_instance = TOWN_SCENE.instantiate()
	_town_scene_instance.use_craftpix_skin = true
	_town_scene_instance.visible = false  # Hidden — only facility popups (CanvasLayer) show

	# Layout VBox fills content area: building overlay expands, party bar auto-sizes
	_content_layout = VBoxContainer.new()
	_content_layout.name = "ContentLayout"
	_content_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content_layout.add_theme_constant_override("separation", 0)
	_content_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_area.add_child(_content_layout)

	# Spacer takes all remaining vertical space — buildings live inside it
	_building_spacer = Control.new()
	_building_spacer.name = "BuildingSpacer"
	_building_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_building_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_layout.add_child(_building_spacer)

	# Party bar auto-sizes to content at bottom
	_party_bar_vbox = VBoxContainer.new()
	_party_bar_vbox.name = "PartyBarVBox"
	_party_bar_vbox.add_theme_constant_override("separation", 6)
	_party_bar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_bar_vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	_content_layout.add_child(_party_bar_vbox)

	_town_scene_instance.party_bar_target = _party_bar_vbox
	_content_area.add_child(_town_scene_instance)
	_town_scene_instance.facility_panel_opened.connect(_on_facility_zone_opened)
	_town_scene_instance.facility_panel_closed.connect(_on_facility_zone_closed)
	_town_scene_instance.facility_panel_refreshed.connect(_on_facility_panel_refreshed)

	print("[TownHub] Embedded TownScene (hidden, popups via CanvasLayer)")


# ============================================================================
# BACKGROUND ZONES — Background stops above party bar
# ============================================================================

## Constrain the background image to the playable area only.
## Left: after NavRail. Top: after margin. Right: before margin. Bottom: above party bar.
func _setup_background_zones() -> void:
	# Dark backing behind the party bar area (full width)
	var backing = ColorRect.new()
	backing.name = "PartyBarBacking"
	backing.color = Color(0.08, 0.08, 0.12, 1.0)
	backing.anchor_left = 0.0
	backing.anchor_right = 1.0
	backing.anchor_top = 1.0
	backing.anchor_bottom = 1.0
	backing.offset_top = -PARTY_BAR_ZONE_HEIGHT
	backing.offset_bottom = 0
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Insert after Background (index 0) but before MainLayout
	add_child(backing)
	move_child(backing, 1)

	# Constrain background to playable area (content area minus party bar zone)
	# 16px margin + 160px NavRail + 12px HBox separation = 188px from left
	_constrain_background()


func _constrain_background() -> void:
	var bg = get_node_or_null("Background")
	if bg == null:
		return
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 188    # 16 margin + 160 NavRail + 12 separation
	bg.offset_top = 16      # Top margin
	bg.offset_right = -16   # Right margin
	bg.offset_bottom = -(16 + PARTY_BAR_ZONE_HEIGHT)  # Bottom margin + party bar


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
		btn.focus_mode = Control.FOCUS_ALL
		btn.modulate = nav_tint
		btn.pressed.connect(_on_facility_clicked.bind(facility_id))
		_nav_vbox.add_child(btn)
		_nav_facility_buttons.append(btn)

	# Quests button — opens quest log overlay
	var btn_quests = Button.new()
	btn_quests.text = "Quests"
	btn_quests.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quests.focus_mode = Control.FOCUS_ALL
	btn_quests.modulate = Color(0.7, 0.85, 1.0)
	btn_quests.pressed.connect(_on_quests_pressed)
	btn_quests.name = "QuestsBtn"
	_nav_vbox.add_child(btn_quests)

	# Guides button — opens guides overlay
	var btn_guides = Button.new()
	btn_guides.text = "Guides"
	btn_guides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_guides.focus_mode = Control.FOCUS_ALL
	btn_guides.modulate = Color(0.85, 0.75, 1.0)
	btn_guides.pressed.connect(_on_guides_pressed)
	btn_guides.name = "GuidesBtn"
	_nav_vbox.add_child(btn_guides)

	# Region navigation section
	var all_regions: Array = DataRegistry.get_all_regions() if DataRegistry.has_method("get_all_regions") else []
	if all_regions.size() > 1:
		all_regions.sort_custom(func(a, b): return a.region_index < b.region_index)
		var region_label = Label.new()
		region_label.text = "— Regions —"
		region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		region_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		region_label.modulate = Color(0.7, 0.7, 0.7)
		region_label.name = "RegionLabel"
		_nav_vbox.add_child(region_label)

		var current_region_id: String = GameContext.get_current_region_id() if GameContext.has_method("get_current_region_id") else "region_1"
		for region in all_regions:
			var rbtn = Button.new()
			var region_color: Color = Color.from_string(region.theme_color, Color.WHITE)
			rbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rbtn.focus_mode = Control.FOCUS_ALL

			var is_unlocked: bool = GameContext.is_region_unlocked(region.region_id)
			if not is_unlocked:
				rbtn.text = region.display_name + " [Locked]"
				rbtn.disabled = true
				rbtn.modulate = Color(0.6, 0.6, 0.6)
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
		travel_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		travel_label.modulate = Color(0.7, 0.7, 0.7)
		travel_label.name = "TravelLabel"
		_nav_vbox.add_child(travel_label)

		for tid in towns:
			var t = DataRegistry.get_town(tid) if DataRegistry.has_method("get_town") else null
			var t_name = t.display_name if t else tid
			var btn = Button.new()
			btn.text = t_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_ALL
			if tid == town_id:
				btn.disabled = true
			btn.pressed.connect(_on_travel_pressed.bind(tid))
			_nav_vbox.add_child(btn)
			_nav_travel_buttons.append(btn)

	# New Cycle button (NG+ — visible after defeating R7 boss)
	if NGPlusTransition.can_start_new_cycle():
		var btn_new_cycle = Button.new()
		var cycle_num: int = GameContext.ng_plus_cycle + 1
		btn_new_cycle.text = "New Cycle (%d)" % cycle_num
		btn_new_cycle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_new_cycle.focus_mode = Control.FOCUS_ALL
		btn_new_cycle.modulate = Color(1.0, 0.82, 0.35)
		btn_new_cycle.pressed.connect(_on_new_cycle_pressed)
		btn_new_cycle.name = "NewCycle"
		btn_new_cycle.tooltip_text = "Begin NG+ Cycle %d — carry heroes and start over with increased difficulty" % cycle_num
		_nav_vbox.add_child(btn_new_cycle)

	# Options button (opens pause/settings menu)
	var btn_options = Button.new()
	btn_options.text = "Options"
	btn_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_options.focus_mode = Control.FOCUS_ALL
	btn_options.modulate = Color(0.8, 0.8, 1.0)
	btn_options.pressed.connect(_on_options_pressed)
	btn_options.name = "Options"
	_nav_vbox.add_child(btn_options)

	# Challenge Level button (playtest tool — session only)
	var btn_challenge = Button.new()
	btn_challenge.text = "Challenge: %d" % GameContext.challenge_level
	btn_challenge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_challenge.focus_mode = Control.FOCUS_ALL
	btn_challenge.modulate = Color(1.0, 0.7, 0.3)
	btn_challenge.pressed.connect(_on_challenge_pressed.bind(btn_challenge))
	btn_challenge.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			GameContext.reset_challenge()
			btn_challenge.text = "Challenge: %d" % GameContext.challenge_level
			_update_challenge_tooltip(btn_challenge)
			get_viewport().set_input_as_handled()
	)
	btn_challenge.name = "Challenge"
	btn_challenge.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_challenge_tooltip(btn_challenge)
	_nav_vbox.add_child(btn_challenge)

	# Save & Exit button
	var btn_save_exit = Button.new()
	btn_save_exit.text = "Save & Exit"
	btn_save_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_exit.focus_mode = Control.FOCUS_ALL
	btn_save_exit.modulate = Color(0.6, 1.0, 0.6)
	btn_save_exit.pressed.connect(_on_save_and_exit)
	btn_save_exit.name = "SaveExit"
	_nav_vbox.add_child(btn_save_exit)

	# Dev Tools — single button opens popup with all dev functions
	if OS.is_debug_build() or GameContext.tester_mode:
		var btn_dev = Button.new()
		btn_dev.text = "Dev Tools"
		btn_dev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_dev.focus_mode = Control.FOCUS_ALL
		btn_dev.modulate = Color(0.7, 0.85, 1.0)
		btn_dev.pressed.connect(_open_dev_tools_popup)
		btn_dev.name = "DevToolsBtn"
		_nav_vbox.add_child(btn_dev)

	# Grab focus on first facility button for gamepad navigation
	if _nav_facility_buttons.size() > 0:
		_nav_facility_buttons[0].call_deferred("grab_focus")


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


## Show one-time telemetry consent dialog.
func _check_telemetry_consent() -> void:
	if GameContext.has_campaign_flag("shown_telemetry_consent_v1"):
		return
	GameContext.set_campaign_flag("shown_telemetry_consent_v1")

	var overlay := CanvasLayer.new()
	overlay.layer = 11

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.10, 0.97)
	style.border_color = Color(0.75, 0.6, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(400, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Help Us Improve!"
	title_lbl.add_theme_font_size_override("font_size", GameContext.fs(16))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	sep.modulate = Color(0.55, 0.4, 0.25, 0.5)
	vbox.add_child(sep)

	var body_lbl := Label.new()
	body_lbl.text = "Would you like to enable play data collection? All data stays on your computer as local files. You can change this anytime in the pause menu."
	body_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
	body_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7, 1))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_yes := Button.new()
	btn_yes.text = "Yes, Enable"
	btn_yes.custom_minimum_size = Vector2(130, 36)
	btn_yes.focus_mode = Control.FOCUS_ALL
	btn_yes.add_theme_font_size_override("font_size", GameContext.fs(14))
	btn_yes.modulate = Color(0.7, 1.0, 0.7)
	btn_row.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "No Thanks"
	btn_no.custom_minimum_size = Vector2(130, 36)
	btn_no.focus_mode = Control.FOCUS_ALL
	btn_no.add_theme_font_size_override("font_size", GameContext.fs(14))
	btn_no.modulate = Color(0.7, 0.7, 0.7)
	btn_row.add_child(btn_no)

	add_child(overlay)
	btn_yes.call_deferred("grab_focus")

	# Wait for player choice (use Array — lambdas capture primitives by value, not reference)
	var state: Array = [false]
	btn_yes.pressed.connect(func():
		GameContext.telemetry_consent = true
		GameContext.save_game()
		state[0] = true
		print("[TownHub] Telemetry consent: ENABLED")
	)
	btn_no.pressed.connect(func():
		state[0] = true
		print("[TownHub] Telemetry consent: declined")
	)

	while not state[0]:
		await get_tree().process_frame

	overlay.queue_free()


## Show facilities overview tutorial after first dungeon extraction.
func _check_facilities_overview() -> void:
	if not GameContext.has_completed_tutorial("tutorial_first_extraction"):
		return
	var fov_tut_targets: Dictionary = {}
	if _nav_vbox != null:
		fov_tut_targets["nav_rail"] = _nav_vbox
	var overlay = TutorialOverlay.try_show(self, "tutorial_facilities_overview", fov_tut_targets)
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
	label.add_theme_font_size_override("font_size", GameContext.fs(18))
	label.modulate = Color(1, 0.9, 0.4, 1)
	panel.add_child(label)
	# Auto-dismiss after 4 seconds
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(func(): canvas.queue_free())
	print("[TownHub] Showing region unlock notification: %s" % region_name)

	# Tutorial: first time unlocking a new region (delay so banner shows first)
	get_tree().create_timer(1.0).timeout.connect(func():
		TutorialOverlay.try_show(self, "tutorial_region_progression")
	)


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
# BUILDING OVERLAY — Clickable building sprites over background
# ============================================================================

func _build_building_overlay() -> void:
	# Remove old overlay if rebuilding
	if _building_overlay != null and is_instance_valid(_building_overlay):
		_building_overlay.queue_free()
		_building_overlay = null

	# Clear edit-mode node references (data persists for re-entry)
	_layout_wrappers.clear()
	_layout_hud_labels.clear()
	_layout_dragging_id = ""

	var town_id = GameContext.get_current_town_id()
	var town = DataRegistry.get_town(town_id) if DataRegistry.has_method("get_town") else null
	if town == null:
		return

	# Container for all building buttons — lives inside BuildingSpacer
	# so it is automatically constrained to the area above the party bar
	_building_overlay = Control.new()
	_building_overlay.name = "BuildingOverlay"
	_building_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_building_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building_spacer.add_child(_building_overlay)

	# Town name header — semi-transparent floating panel at top center
	_create_town_header(town)

	# Branch: edit mode (free positioning) vs normal mode (HBox/VBox grid)
	if _layout_edit_mode:
		_place_building_buttons_edit_mode(town)
	else:
		_place_building_buttons(town)

	print("[TownHub] Building overlay built: %d buildings (edit=%s)" % [town.facility_ids.size(), _layout_edit_mode])


func _create_town_header(town) -> void:
	var sf: float = _building_scale()
	var palette: Dictionary = RegionTheme.get_palette_for_current_region()

	var header_panel = PanelContainer.new()
	header_panel.name = "TownHeader"
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = palette.get("title_bar", Color(0.18, 0.22, 0.3, 0.85))
	header_style.content_margin_left = 16 * sf
	header_style.content_margin_top = 4 * sf
	header_style.content_margin_right = 16 * sf
	header_style.content_margin_bottom = 4 * sf
	header_style.set_corner_radius_all(int(6 * sf))
	header_style.border_color = palette.get("border", Color(0.4, 0.5, 0.4, 0.6))
	header_style.set_border_width_all(1)
	header_panel.add_theme_stylebox_override("panel", header_style)

	# Anchor to top-center of overlay
	header_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	header_panel.offset_top = 8 * sf
	header_panel.offset_left = -120 * sf
	header_panel.offset_right = 120 * sf
	header_panel.offset_bottom = 42 * sf

	var header_label = Label.new()
	var header_text: String = town.display_name
	if GameContext.ng_plus_cycle > 0:
		header_text += "  [NG+%d]" % GameContext.ng_plus_cycle
	header_label.text = header_text
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_label.add_theme_font_size_override("font_size", GameContext.fs(int(BASE_HEADER_FS * sf)))
	header_panel.add_child(header_label)

	_building_overlay.add_child(header_panel)


func _place_building_buttons(town) -> void:
	# Sort facilities into preferred display order
	var ordered: Array = _sort_facilities_for_display(town.facility_ids)
	var count: int = ordered.size()
	if count == 0:
		return

	var sf: float = _building_scale()

	# Layout: 2 rows, split facilities evenly
	var cols: int = ceili(count / 2.0)
	var row1_count: int = cols
	var row2_count: int = count - cols

	# Grid container: constrained to background area (not full spacer).
	# anchor_bottom=0 so offset_bottom is an absolute y-position from parent top,
	# matching the background's visible bottom edge.
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bg_area_h: float = maxf(100, vp.y - 32 - PARTY_BAR_ZONE_HEIGHT)

	var grid_anchor = Control.new()
	grid_anchor.name = "BuildingGrid"
	grid_anchor.anchor_left = 0.0
	grid_anchor.anchor_right = 1.0
	grid_anchor.anchor_top = 0.0
	grid_anchor.anchor_bottom = 0.0
	grid_anchor.offset_top = BASE_GRID_TOP * sf
	grid_anchor.offset_bottom = bg_area_h - (BASE_GRID_BOTTOM_EXTRA * sf)
	grid_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building_overlay.add_child(grid_anchor)

	# Bottom-align rows so buildings are grounded on the landscape
	var vbox = VBoxContainer.new()
	vbox.name = "RowsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", int(BASE_ROW_SEP * sf))
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_anchor.add_child(vbox)

	# Row 1
	var row1 = HBoxContainer.new()
	row1.name = "Row1"
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", int(BASE_COL_SEP * sf))
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row1)

	for i in range(row1_count):
		var fid: String = ordered[i]
		var facility = DataRegistry.get_facility(fid) if DataRegistry.has_method("get_facility") else null
		var btn_container = _create_building_button(fid, facility, sf)
		row1.add_child(btn_container)

	# Row 2
	if row2_count > 0:
		var row2 = HBoxContainer.new()
		row2.name = "Row2"
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_theme_constant_override("separation", int(BASE_COL_SEP * sf))
		row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(row2)

		for i in range(row1_count, count):
			var fid: String = ordered[i]
			var facility = DataRegistry.get_facility(fid) if DataRegistry.has_method("get_facility") else null
			var btn_container = _create_building_button(fid, facility, sf)
			row2.add_child(btn_container)


## Sort facility IDs into the preferred display order.
## Matches by facility_id first, then by facility_type.  Unmatched facilities append at end.
func _sort_facilities_for_display(facility_ids: Array) -> Array:
	var ordered: Array = []
	var remaining: Array = facility_ids.duplicate()

	for preferred_key in FACILITY_DISPLAY_ORDER:
		for fid in remaining:
			# Match by exact facility_id
			if fid == preferred_key:
				ordered.append(fid)
				remaining.erase(fid)
				break
			# Match by facility_type (e.g. "dungeon" matches "dungeon_thornhaven")
			var facility = DataRegistry.get_facility(fid) if DataRegistry.has_method("get_facility") else null
			if facility != null and facility.facility_type == preferred_key:
				ordered.append(fid)
				remaining.erase(fid)
				break
			# Match by prefix (e.g. "shop" matches "shop_thornhaven")
			if fid.begins_with(preferred_key + "_") or fid.begins_with(preferred_key):
				ordered.append(fid)
				remaining.erase(fid)
				break

	# Append any unmatched facilities at end
	ordered.append_array(remaining)
	return ordered


func _create_building_button(facility_id: String, facility, sf: float) -> VBoxContainer:
	var container = VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_END
	container.add_theme_constant_override("separation", int(2 * sf))

	# Resolve building sprite texture
	var sprite_key: String = ""
	if BUILDING_SPRITES.has(facility_id):
		sprite_key = BUILDING_SPRITES[facility_id]
	elif facility != null and BUILDING_SPRITES_BY_TYPE.has(facility.facility_type):
		sprite_key = BUILDING_SPRITES_BY_TYPE[facility.facility_type]

	var tex: Texture2D = null
	if sprite_key != "":
		tex = _load_icon(_resolve_building_sprite_path(sprite_key))

	var bld: float = BASE_BUILDING_SIZE * sf

	# Wrapper for building sprite
	var sprite_wrapper = Control.new()
	sprite_wrapper.name = "SpriteWrapper"
	sprite_wrapper.custom_minimum_size = Vector2(bld, bld)
	sprite_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# TextureButton with the building sprite
	var btn = TextureButton.new()
	btn.name = "Btn_" + facility_id
	btn.position = Vector2.ZERO
	btn.size = Vector2(bld, bld)
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.ignore_texture_size = true
	# Suppress inherited Button theme background (dark StyleBox shows through padding)
	var empty_style = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)
	if tex != null:
		btn.texture_normal = tex
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.pressed.connect(_on_facility_clicked.bind(facility_id))
	# Hover effects
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.3, 1.3, 1.3))
	btn.mouse_exited.connect(func(): btn.modulate = Color(1.0, 1.0, 1.0))
	sprite_wrapper.add_child(btn)

	container.add_child(sprite_wrapper)

	# Label below with shadow for readability on backgrounds
	var label = Label.new()
	label.text = _get_nav_label(facility_id, facility)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", GameContext.fs(int(BASE_BLD_LABEL_FS * sf)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	container.add_child(label)

	return container


# ============================================================================
# LAYOUT EDITOR — Dev tool for visual building placement (remove after finalizing)
# ============================================================================

func _on_toggle_layout_edit() -> void:
	_layout_edit_mode = not _layout_edit_mode
	if _layout_btn and is_instance_valid(_layout_btn):
		_layout_btn.text = "Edit Layout: ON" if _layout_edit_mode else "Edit Layout: OFF"
		_layout_btn.modulate = Color(0.4, 1.0, 0.4) if _layout_edit_mode else Color(0.8, 1.0, 0.8)
	if _layout_print_btn and is_instance_valid(_layout_print_btn):
		_layout_print_btn.visible = _layout_edit_mode
	_build_building_overlay()
	print("[TownHub] Layout edit mode: %s" % ("ON" if _layout_edit_mode else "OFF"))


func _place_building_buttons_edit_mode(town) -> void:
	var facility_ids: Array = town.facility_ids
	var count: int = facility_ids.size()
	if count == 0:
		return

	var sf: float = _building_scale()

	# Calculate default positions in a 2-row grid if no saved data (design-space coords)
	var cols: int = ceili(count / 2.0)
	# Use design-resolution content area for default positions
	var design_area_w: float = _content_area.size.x / sf
	var col_spacing: float = design_area_w / (cols + 1)

	for i in range(count):
		var fid: String = facility_ids[i]
		var facility = DataRegistry.get_facility(fid) if DataRegistry.has_method("get_facility") else null

		if not _layout_data.has(fid):
			var row: int = 0 if i < cols else 1
			var col: int = i if i < cols else (i - cols)
			var row_count: int = cols if row == 0 else (count - cols)
			var row_spacing: float = design_area_w / (row_count + 1)
			_layout_data[fid] = {
				"position": Vector2(
					row_spacing * (col + 1) - 70,
					80 + row * 180
				),
				"size": Vector2(140, 140)
			}

		var data: Dictionary = _layout_data[fid]
		var wrapper: Control = _create_edit_mode_building(fid, facility, data, sf)
		_building_overlay.add_child(wrapper)
		_layout_wrappers[fid] = wrapper


func _create_edit_mode_building(facility_id: String, facility, data: Dictionary, sf: float) -> Control:
	# data stores design-space coords; multiply by sf for screen placement
	var bld_size: Vector2 = data["size"] * sf
	var bld_pos: Vector2 = data["position"] * sf

	var wrapper = Control.new()
	wrapper.name = "Edit_" + facility_id
	wrapper.position = bld_pos
	wrapper.size = Vector2(bld_size.x, bld_size.y + 28 * sf)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Green border outline (2px larger on each side)
	var border = ColorRect.new()
	border.name = "Border"
	border.color = Color(0.2, 0.9, 0.2, 0.5)
	border.position = Vector2(-2 * sf, -2 * sf)
	border.size = Vector2(bld_size.x + 4 * sf, bld_size.y + 4 * sf)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(border)

	# Drop shadow at building base
	var shadow = ColorRect.new()
	shadow.name = "Shadow"
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.size = Vector2(bld_size.x * 0.8, 14 * sf)
	shadow.position = Vector2(bld_size.x * 0.1, bld_size.y - 4 * sf)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(shadow)

	# Resolve building sprite
	var sprite_key: String = ""
	if BUILDING_SPRITES.has(facility_id):
		sprite_key = BUILDING_SPRITES[facility_id]
	elif facility != null and BUILDING_SPRITES_BY_TYPE.has(facility.facility_type):
		sprite_key = BUILDING_SPRITES_BY_TYPE[facility.facility_type]
	var tex: Texture2D = null
	if sprite_key != "":
		tex = _load_icon(_resolve_building_sprite_path(sprite_key))

	var btn = TextureButton.new()
	btn.name = "Btn_" + facility_id
	btn.position = Vector2.ZERO
	btn.size = bld_size
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.ignore_texture_size = true
	if tex != null:
		btn.texture_normal = tex
	btn.mouse_default_cursor_shape = Control.CURSOR_MOVE
	btn.gui_input.connect(_on_layout_building_input.bind(facility_id, wrapper))
	wrapper.add_child(btn)

	# Name label
	var name_label = Label.new()
	name_label.text = _get_nav_label(facility_id, facility)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", GameContext.fs(int(11 * sf)))
	name_label.position = Vector2(0, bld_size.y + 2 * sf)
	name_label.size = Vector2(bld_size.x, 20 * sf)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	wrapper.add_child(name_label)

	# HUD label (yellow, shows design-space size @ position)
	var hud_label = Label.new()
	hud_label.name = "HUD"
	hud_label.text = _format_layout_hud(data["size"], data["position"])
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", GameContext.fs(int(9 * sf)))
	hud_label.add_theme_color_override("font_color", Color(1, 1, 0.6))
	hud_label.add_theme_constant_override("shadow_offset_x", 1)
	hud_label.add_theme_constant_override("shadow_offset_y", 1)
	hud_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	hud_label.position = Vector2(0, -18 * sf)
	hud_label.size = Vector2(bld_size.x, 16 * sf)
	hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(hud_label)
	_layout_hud_labels[facility_id] = hud_label

	return wrapper


func _on_layout_building_input(event: InputEvent, facility_id: String, wrapper: Control) -> void:
	if not _layout_edit_mode:
		return

	var sf: float = _building_scale()

	# Drag (left mouse button)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_layout_dragging_id = facility_id
			_layout_drag_offset = event.global_position - wrapper.global_position
			wrapper.get_parent().move_child(wrapper, -1)
		else:
			if _layout_dragging_id == facility_id:
				_layout_dragging_id = ""
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _layout_dragging_id == facility_id:
			var new_screen_pos: Vector2 = event.global_position - _layout_drag_offset - _building_overlay.global_position
			wrapper.position = new_screen_pos
			# Store in design-space (divide by sf)
			_layout_data[facility_id]["position"] = new_screen_pos / sf
			_update_layout_hud(facility_id)
			get_viewport().set_input_as_handled()

	# Resize (scroll wheel) — delta is in design-space pixels
	elif event is InputEventMouseButton and event.pressed:
		var delta: int = 0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			delta = LAYOUT_SCALE_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			delta = -LAYOUT_SCALE_STEP

		if delta != 0:
			var current_size: Vector2 = _layout_data[facility_id]["size"]
			var new_val: float = clampf(current_size.x + delta, LAYOUT_MIN_SIZE, LAYOUT_MAX_SIZE)
			_layout_data[facility_id]["size"] = Vector2(new_val, new_val)
			_rebuild_edit_building(facility_id)
			get_viewport().set_input_as_handled()


func _rebuild_edit_building(facility_id: String) -> void:
	var old_wrapper = _layout_wrappers.get(facility_id)
	if old_wrapper != null and is_instance_valid(old_wrapper):
		old_wrapper.queue_free()
	var facility = DataRegistry.get_facility(facility_id) if DataRegistry.has_method("get_facility") else null
	var data: Dictionary = _layout_data[facility_id]
	var sf: float = _building_scale()
	var new_wrapper: Control = _create_edit_mode_building(facility_id, facility, data, sf)
	_building_overlay.add_child(new_wrapper)
	_layout_wrappers[facility_id] = new_wrapper


func _update_layout_hud(facility_id: String) -> void:
	var hud = _layout_hud_labels.get(facility_id)
	if hud == null or not is_instance_valid(hud):
		return
	var data: Dictionary = _layout_data[facility_id]
	hud.text = _format_layout_hud(data["size"], data["position"])


func _format_layout_hud(bld_size: Vector2, bld_pos: Vector2) -> String:
	return "%dx%d @ %d,%d" % [int(bld_size.x), int(bld_size.y), int(bld_pos.x), int(bld_pos.y)]


func _on_print_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bg_area: Vector2 = _content_area.size - Vector2(0, PARTY_BAR_ZONE_HEIGHT)
	var text: String = "=== BUILDING LAYOUT ===\n"
	text += "Town: %s\n" % GameContext.get_current_town_id()
	text += "Viewport: %dx%d\n" % [int(viewport_size.x), int(viewport_size.y)]
	text += "Content area: %dx%d\n" % [int(_content_area.size.x), int(_content_area.size.y)]
	text += "Background area: %dx%d\n\n" % [int(bg_area.x), int(bg_area.y)]
	for facility_id in _layout_data:
		var data: Dictionary = _layout_data[facility_id]
		var pos: Vector2 = data["position"]
		var sz: Vector2 = data["size"]
		text += '  "%s": { "x": %d, "y": %d, "w": %d, "h": %d },\n' % [
			facility_id, int(pos.x), int(pos.y), int(sz.x), int(sz.y)
		]
	text += "\n=== END LAYOUT ==="
	print(text)
	_show_layout_overlay(text)


func _show_layout_overlay(text: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	# Dark backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(backdrop)
	# Centered panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	center.add_child(panel)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	# Title
	var title = Label.new()
	title.text = "Building Layout Data"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameContext.fs(16))
	vbox.add_child(title)
	# Scrollable text
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	vbox.add_child(scroll)
	var rtl = RichTextLabel.new()
	rtl.text = text
	rtl.bbcode_enabled = false
	rtl.selection_enabled = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", GameContext.fs(12))
	scroll.add_child(rtl)
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(func(): canvas.queue_free())
	vbox.add_child(close_btn)


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
	print("[TownHub] Travelling to region %s -> %s" % [region_id, target_town])
	_known_towns.clear()
	if _town_scene_instance and _town_scene_instance.has_method("switch_town"):
		_town_scene_instance.switch_town(target_town)


func _on_viewport_resized() -> void:
	if _resize_timer != null:
		return  # Already pending
	_resize_timer = get_tree().create_timer(0.15)
	_resize_timer.timeout.connect(func():
		_resize_timer = null
		_build_building_overlay()
		_constrain_background()
	)


func _on_location_changed(_region_id: String, _town_id: String) -> void:
	print("[TownHub] Location changed — rebuilding nav rail + building overlay")
	_build_nav_rail()

	# Update background for new town and re-constrain to playable area
	BackgroundManager.apply_background(self, "town", "%s_T1" % _town_id)
	_constrain_background()

	# Defer overlay rebuild so queue_free from old overlay completes first
	call_deferred("_build_building_overlay")


func _on_quests_pressed() -> void:
	print("[TownHub] Quests pressed — opening quest log")
	var overlay = SideQuestSystem.show_quest_log(self)
	if overlay != null:
		await overlay.quest_log_closed


func _on_guides_pressed() -> void:
	print("[TownHub] Guides pressed — opening guides overlay")
	var overlay = GuidesOverlay.show(self)
	if overlay != null:
		await overlay.guides_closed


func _on_new_cycle_pressed() -> void:
	print("[TownHub] New Cycle pressed — opening NG+ transition")
	# Tutorial: explain NG+ mechanics on first cycle
	var tut_overlay = TutorialOverlay.try_show(self, "tutorial_ng_plus")
	if tut_overlay != null:
		await tut_overlay.tutorial_finished
	var overlay = NGPlusTransition.show(self)
	if overlay != null:
		await overlay.transition_complete


func _on_options_pressed() -> void:
	var ui_audio = get_node_or_null("/root/UIAudio")
	if ui_audio and ui_audio.has_method("show_options_menu"):
		ui_audio.show_options_menu()


func _on_challenge_pressed(btn: Button) -> void:
	GameContext.increment_challenge()
	btn.text = "Challenge: %d" % GameContext.challenge_level
	_update_challenge_tooltip(btn)


func _update_challenge_tooltip(btn: Button) -> void:
	var cl: int = GameContext.challenge_level
	var lines: Array = []
	lines.append("Difficulty Modifier (resets each session)")
	lines.append("")
	lines.append("Click to increase | Shift+Click to reset")
	lines.append("")
	if cl == 0:
		lines.append("No modifiers active.")
	else:
		var hp_pct: int = int(cl * 12)
		var dmg_pct: int = int(cl * 8)
		var gold_pct: int = int(cl * 5)
		lines.append("Current (Level %d):" % cl)
		lines.append("  Monster HP: +%d%%" % hp_pct)
		lines.append("  Monster Damage: +%d%%" % dmg_pct)
		lines.append("  Gold Rewards: +%d%%" % gold_pct)
	lines.append("")
	if cl >= 5:
		lines.append("Level 5+ Bonus: Extra boss loot roll (ACTIVE)")
	else:
		lines.append("Level 5+: ???")
	btn.tooltip_text = "\n".join(lines)


func _on_save_and_exit() -> void:
	print("[TownHub] Save & Exit pressed")
	GameContext.save_game()
	get_tree().quit()


func _on_dev_reset_save() -> void:
	print("[TownHub] DEV: Reset Save pressed")
	if GameContext.has_method("reset_save_game"):
		GameContext.reset_save_game()
	SceneTransition.fade_to("res://Game/Boot/game_boot.tscn")


func _on_dev_add_gold() -> void:
	print("[TownHub] DEV: +100 Gold pressed")
	GameContext.add_run_gold(100)
	GameContext.save_game()
	print("[TownHub] Added 100 gold. New total: %d" % GameContext.get_run_gold())


func _on_dev_unlock_regions() -> void:
	var all_regions: Array = DataRegistry.get_all_regions() if DataRegistry.has_method("get_all_regions") else []
	for region in all_regions:
		if not GameContext.completed_regions.has(region.region_id):
			GameContext.completed_regions[region.region_id] = true
	GameContext.save_game()
	# Rebuild nav rail to enable region buttons
	_build_nav_rail()
	print("[TownHub] DEV: All %d regions unlocked" % all_regions.size())


func _on_dev_add_base_materials() -> void:
	var base_mats: Array = [
		"iron_scrap", "wood_bundle", "herb_sprig", "forest_mushroom",
		"wild_berries", "raw_meat", "slime_gel", "bone_fragment",
		"spider_fang", "bat_wing", "spider_silk", "boar_tusk", "wolf_pelt"
	]
	for mat_id in base_mats:
		GameContext.add_run_item(mat_id, 100)
	GameContext.save_game()
	print("[TownHub] DEV: +100 of each base material (13 types) added to stash")


func _on_dev_clear_stash() -> void:
	if GameContext.has_method("clear_run_stash"):
		GameContext.clear_run_stash()
		GameContext.save_game()
		print("[TownHub] DEV: Stash cleared")


## Open the Dev Tools popup overlay (facility-styled panel).
func _open_dev_tools_popup() -> void:
	if _dev_tools_overlay != null:
		return

	_dev_tools_overlay = CanvasLayer.new()
	_dev_tools_overlay.layer = 10

	# Backdrop — click to close
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_dev_tools_popup()
	)
	_dev_tools_overlay.add_child(backdrop)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev_tools_overlay.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.97)
	style.border_color = Color(0.55, 0.4, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title bar
	var title_row = HBoxContainer.new()
	vbox.add_child(title_row)

	var title_lbl = Label.new()
	title_lbl.text = "Dev Tools"
	title_lbl.add_theme_font_size_override("font_size", GameContext.fs(16))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(_close_dev_tools_popup)
	title_row.add_child(close_btn)

	var sep = HSeparator.new()
	sep.modulate = Color(0.55, 0.4, 0.25, 0.5)
	vbox.add_child(sep)

	# Button factory
	var _make_dev_btn = func(text: String, color: Color, handler: Callable) -> Button:
		var btn = Button.new()
		btn.text = text
		btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		btn.custom_minimum_size = Vector2(280, 34)
		btn.modulate = color
		btn.pressed.connect(func():
			handler.call()
			_close_dev_tools_popup()
		)
		return btn

	vbox.add_child(_make_dev_btn.call("+100 Gold", Color(1, 0.9, 0.5, 1), _on_dev_add_gold))
	vbox.add_child(_make_dev_btn.call("+100 Base Materials", Color(0.5, 0.9, 0.5, 1), _on_dev_add_base_materials))
	vbox.add_child(_make_dev_btn.call("Unlock Regions", Color(0.6, 0.8, 1.0, 1), _on_dev_unlock_regions))
	vbox.add_child(_make_dev_btn.call("Clear Stash", Color(0.8, 0.8, 0.8, 1), _on_dev_clear_stash))
	vbox.add_child(_make_dev_btn.call("Reset Save", Color(1, 0.5, 0.5, 1), _on_dev_reset_save))

	# Layout editor buttons (kept separate — toggle doesn't close popup)
	var sep2 = HSeparator.new()
	sep2.modulate = Color(0.55, 0.4, 0.25, 0.3)
	vbox.add_child(sep2)

	_layout_btn = Button.new()
	_layout_btn.text = "Edit Layout: ON" if _layout_edit_mode else "Edit Layout: OFF"
	_layout_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	_layout_btn.custom_minimum_size = Vector2(280, 34)
	_layout_btn.modulate = Color(0.4, 1.0, 0.4) if _layout_edit_mode else Color(0.8, 1.0, 0.8)
	_layout_btn.pressed.connect(func():
		_on_toggle_layout_edit()
		# Update button text/color in-place
		if _layout_btn and is_instance_valid(_layout_btn):
			_layout_btn.text = "Edit Layout: ON" if _layout_edit_mode else "Edit Layout: OFF"
			_layout_btn.modulate = Color(0.4, 1.0, 0.4) if _layout_edit_mode else Color(0.8, 1.0, 0.8)
		if _layout_print_btn and is_instance_valid(_layout_print_btn):
			_layout_print_btn.visible = _layout_edit_mode
	)
	vbox.add_child(_layout_btn)

	_layout_print_btn = Button.new()
	_layout_print_btn.text = "Print Layout"
	_layout_print_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	_layout_print_btn.custom_minimum_size = Vector2(280, 34)
	_layout_print_btn.modulate = Color(0.8, 1.0, 0.8)
	_layout_print_btn.pressed.connect(func():
		_on_print_layout()
		_close_dev_tools_popup()
	)
	_layout_print_btn.visible = _layout_edit_mode
	vbox.add_child(_layout_print_btn)

	# Hotkey hint
	var hint = Label.new()
	hint.text = "F5=Enter  F6=AdvFloor  Shift+F6=AdvRoom  F7=Exit"
	hint.add_theme_font_size_override("font_size", GameContext.fs(11))
	hint.modulate = Color(0.6, 0.6, 0.6, 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	add_child(_dev_tools_overlay)
	UIAudio.register_closeable(_dev_tools_overlay, _close_dev_tools_popup)
	print("[TownHub] Dev Tools popup opened")


## Close the Dev Tools popup overlay.
func _close_dev_tools_popup() -> void:
	if _dev_tools_overlay != null and is_instance_valid(_dev_tools_overlay):
		UIAudio.unregister_closeable(_dev_tools_overlay)
		_dev_tools_overlay.queue_free()
		_dev_tools_overlay = null
		# Clear refs to popup-hosted layout buttons (they're gone now)
		_layout_btn = null
		_layout_print_btn = null


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


# ============================================================================
# FOCUS ZONES (Controller support)
# ============================================================================

func _register_focus_zones() -> void:
	InputManager.clear_zones()

	# Nav Rail: PanelContainer is 3 levels above NavVBox
	var nav_rail_panel: Control = _nav_vbox.get_parent().get_parent().get_parent()
	var nav_controls: Array = InputManager.collect_focusable(nav_rail_panel)

	# Party Bar: each hero card is its own zone for reliable D-pad navigation
	var card_zone_ids: Array = _register_party_card_zones()

	# Nav rail neighbors — down to first party card (if any)
	var nav_neighbors: Dictionary = {}
	if not card_zone_ids.is_empty():
		nav_neighbors["down"] = card_zone_ids[0]
	InputManager.register_zone("nav_rail", nav_rail_panel, nav_controls, nav_neighbors)

	# Set region border color
	var palette: Dictionary = RegionTheme.get_palette_for_current_region()
	InputManager.set_zone_border_color(palette.get("border", Color(0.55, 0.4, 0.25, 0.8)))

	# Activate nav_rail as default zone
	InputManager.set_active_zone("nav_rail")


## Register each hero card in the party bar as its own zone.
## Returns array of registered zone IDs (e.g. ["party_card_0", "party_card_1", ...]).
func _register_party_card_zones() -> Array:
	if _party_bar_vbox == null:
		return []

	# Find the GridContainer inside party bar (second child after label)
	var grid: GridContainer = null
	for child in _party_bar_vbox.get_children():
		if child is GridContainer:
			grid = child
			break
	if grid == null:
		return []

	var card_zone_ids: Array = []
	for i in range(grid.get_child_count()):
		var card: Control = grid.get_child(i)
		var controls: Array = InputManager.collect_focusable(card)
		if controls.is_empty():
			continue  # Skip empty/locked slots
		var zone_id: String = "party_card_%d" % card_zone_ids.size()
		card_zone_ids.append(zone_id)
		InputManager.register_zone(zone_id, card, controls, {})

	# Set left/right neighbors between cards, up neighbor to nav_rail
	for i in range(card_zone_ids.size()):
		var neighbors: Dictionary = {"up": "nav_rail"}
		if i > 0:
			neighbors["left"] = card_zone_ids[i - 1]
		if i < card_zone_ids.size() - 1:
			neighbors["right"] = card_zone_ids[i + 1]
		InputManager.update_zone_neighbors(card_zone_ids[i], neighbors)

	return card_zone_ids


func _on_facility_zone_opened(_facility_id: String, _panel_node: Control) -> void:
	_pending_restore_focus_index = -1
	call_deferred("_reregister_facility_zones")


func _on_facility_zone_closed(_facility_id: String) -> void:
	_pending_restore_focus_index = -1
	# If compare panel closed, restore focus to source shop item + 1
	if _facility_id == "shop_compare" and _town_scene_instance and _town_scene_instance._compare_source_focus_index >= 0:
		_pending_restore_focus_index = _town_scene_instance._compare_source_focus_index + 1
		_town_scene_instance._compare_source_focus_index = -1
	call_deferred("_reregister_facility_zones")


func _on_facility_panel_refreshed(_facility_id: String, prev_focus_index: int) -> void:
	_pending_restore_focus_index = prev_focus_index
	call_deferred("_reregister_facility_zones")


## Re-register focus zones for all open facility panels.
## Each panel gets its own zone with left/right/up/down neighbors for controller navigation.
func _reregister_facility_zones() -> void:
	if _town_scene_instance == null:
		return

	# Consume pending restore index
	var restore_index: int = _pending_restore_focus_index
	_pending_restore_focus_index = -1

	# Unregister all existing facility zones
	for key in InputManager._zones.keys():
		if key.begins_with("facility"):
			InputManager.unregister_zone(key)

	var panel_ids: Array = _town_scene_instance._open_panels.keys()
	if panel_ids.is_empty():
		# No panels open — restore original nav (down to first party card)
		var first_card: String = "party_card_0" if InputManager._zones.has("party_card_0") else ""
		var restore_neighbors: Dictionary = {}
		if first_card != "":
			restore_neighbors["down"] = first_card
		InputManager.update_zone_neighbors("nav_rail", restore_neighbors)
		InputManager.set_active_zone("nav_rail")
		return

	var total: int = panel_ids.size()

	# Register each panel as its own zone (linear left/right chain)
	for i in range(total):
		var fid: String = panel_ids[i]
		var info: Dictionary = _town_scene_instance._open_panels[fid]
		var panel: Control = info.get("panel")
		if panel == null or not is_instance_valid(panel):
			continue

		var zone_id: String = "facility_%d" % i
		var controls: Array = InputManager.collect_focusable(panel)

		# Build neighbors (linear chain: nav_rail ← facility_0 ↔ facility_1 ↔ ...)
		var neighbors: Dictionary = {}
		if i == 0:
			neighbors["left"] = "nav_rail"
		else:
			neighbors["left"] = "facility_%d" % (i - 1)
		if i < total - 1:
			neighbors["right"] = "facility_%d" % (i + 1)

		InputManager.register_zone(zone_id, panel, controls, neighbors)

	# Nav rail right now points to first facility zone, down to first party card
	var first_card: String = "party_card_0" if InputManager._zones.has("party_card_0") else ""
	var nav_fac_neighbors: Dictionary = {"right": "facility_0"}
	if first_card != "":
		nav_fac_neighbors["down"] = first_card
	InputManager.update_zone_neighbors("nav_rail", nav_fac_neighbors)
	# Activate the most recently opened panel, restoring focus index if available
	var last_zone: String = "facility_%d" % (total - 1)
	if restore_index >= 0:
		InputManager.set_active_zone_at_index(last_zone, restore_index)
	else:
		InputManager.set_active_zone(last_zone)


func _exit_tree() -> void:
	InputManager.clear_zones()
