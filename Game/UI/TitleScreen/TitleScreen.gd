## TitleScreen.gd
## Game title screen with New Game, Load Game, Options, Exit.
## Manages 4 save slots with metadata display.
extends Control

const INTRO_CUTSCENE_PATH := "res://Game/UI/Cutscene/IntroCutscene.tscn"
const TOWN_HUB_PATH := "res://Game/UI/TownHub/TownHubScene.tscn"
const BG_PATH := "res://Assets/Backgrounds/Cutscene/title_screen.png"

var _slot_overlay: CanvasLayer = null
var _slot_mode: String = ""  # "new" or "load"


func _ready() -> void:
	_build_ui()
	UIAudio.play_bgm("title_screen")
	print("[TitleScreen] Title screen loaded")


func _build_ui() -> void:
	# Background
	var fallback_bg = ColorRect.new()
	fallback_bg.set_anchors_preset(PRESET_FULL_RECT)
	fallback_bg.color = Color(0.03, 0.02, 0.05)
	add_child(fallback_bg)

	if ResourceLoader.exists(BG_PATH):
		var bg_tex = ResourceLoader.load(BG_PATH) as Texture2D
		if bg_tex != null:
			var bg_rect = TextureRect.new()
			bg_rect.set_anchors_preset(PRESET_FULL_RECT)
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg_rect.texture = bg_tex
			add_child(bg_rect)

	# Dark vignette overlay for readability
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	vignette.color = Color(0, 0, 0, 0.35)
	add_child(vignette)

	# Title area (upper center)
	var title_vbox = VBoxContainer.new()
	title_vbox.set_anchors_preset(PRESET_CENTER_TOP)
	title_vbox.grow_horizontal = GROW_DIRECTION_BOTH
	title_vbox.offset_top = 80
	title_vbox.offset_left = -200
	title_vbox.offset_right = 200
	title_vbox.add_theme_constant_override("separation", 4)
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(title_vbox)

	var title_lbl = Label.new()
	title_lbl.text = "Shops & Shadows"
	title_lbl.add_theme_font_size_override("font_size", GameContext.fs(32))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(title_lbl)

	var subtitle_lbl = Label.new()
	subtitle_lbl.text = "A Shopkeeper's Tale"
	subtitle_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	subtitle_lbl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6, 0.8))
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(subtitle_lbl)

	# Menu buttons (center of screen)
	var menu_center = CenterContainer.new()
	menu_center.set_anchors_preset(PRESET_FULL_RECT)
	menu_center.offset_top = 60  # Shift slightly below center
	add_child(menu_center)

	var menu_vbox = VBoxContainer.new()
	menu_vbox.add_theme_constant_override("separation", 12)
	menu_center.add_child(menu_vbox)

	var btn_new = _make_menu_button("New Game", Color(0.9, 0.85, 0.7))
	btn_new.pressed.connect(_on_new_game)
	menu_vbox.add_child(btn_new)

	var btn_load = _make_menu_button("Load Game", Color(0.7, 0.8, 0.9))
	btn_load.pressed.connect(_on_load_game)
	menu_vbox.add_child(btn_load)

	var btn_options = _make_menu_button("Options", Color(0.75, 0.75, 0.75))
	btn_options.pressed.connect(_on_options)
	menu_vbox.add_child(btn_options)

	var btn_exit = _make_menu_button("Exit", Color(0.8, 0.6, 0.6))
	btn_exit.pressed.connect(_on_exit)
	menu_vbox.add_child(btn_exit)

	# --- Feedback Links ---
	var feedback_row = HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 8)
	feedback_row.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_child(feedback_row)

	var btn_bug = Button.new()
	btn_bug.text = "Report Bug"
	btn_bug.custom_minimum_size = Vector2(104, 32)
	btn_bug.focus_mode = Control.FOCUS_ALL
	btn_bug.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_bug.modulate = Color(1.0, 0.8, 0.6)
	btn_bug.pressed.connect(func():
		OS.shell_open("https://github.com/Starcraft394/ShopKeepersGame/issues/new/choose")
	)
	feedback_row.add_child(btn_bug)

	var btn_community = Button.new()
	btn_community.text = "Community"
	btn_community.custom_minimum_size = Vector2(104, 32)
	btn_community.focus_mode = Control.FOCUS_ALL
	btn_community.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_community.modulate = Color(0.7, 0.8, 1.0)
	btn_community.pressed.connect(func():
		OS.shell_open("https://github.com/Starcraft394/ShopKeepersGame/discussions")
	)
	feedback_row.add_child(btn_community)

	var btn_credits = Button.new()
	btn_credits.text = "Credits"
	btn_credits.custom_minimum_size = Vector2(78, 32)
	btn_credits.focus_mode = Control.FOCUS_ALL
	btn_credits.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_credits.modulate = Color(0.8, 0.75, 0.9)
	btn_credits.pressed.connect(func():
		CreditsOverlay.show(self)
	)
	feedback_row.add_child(btn_credits)

	# Grab focus on first button for gamepad navigation
	btn_new.call_deferred("grab_focus")

	# Version label (bottom-right)
	var version_lbl = Label.new()
	version_lbl.text = "v0.3-alpha  Playtest Build"
	version_lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
	version_lbl.modulate = Color(0.5, 0.5, 0.5, 0.6)
	version_lbl.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	version_lbl.offset_left = -200
	version_lbl.offset_top = -24
	version_lbl.offset_right = -12
	version_lbl.offset_bottom = -8
	version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version_lbl)


func _make_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", GameContext.fs(16))
	btn.custom_minimum_size = Vector2(220, 40)
	btn.modulate = color
	btn.focus_mode = Control.FOCUS_ALL
	return btn


# ============================================================================
# MENU HANDLERS
# ============================================================================

func _on_new_game() -> void:
	_open_slot_picker("new")


func _on_load_game() -> void:
	_open_slot_picker("load")


func _on_options() -> void:
	# Reuse UIAudio's pause menu (it has volume + text size controls)
	if UIAudio.has_method("_open_pause_menu"):
		UIAudio._open_pause_menu()
	else:
		# Fallback: toggle pause overlay manually
		UIAudio._toggle_pause_menu()


func _on_exit() -> void:
	get_tree().quit()


# ============================================================================
# SAVE SLOT PICKER
# ============================================================================

func _open_slot_picker(mode: String) -> void:
	if _slot_overlay != null:
		return
	_slot_mode = mode

	_slot_overlay = CanvasLayer.new()
	_slot_overlay.layer = 10

	# Backdrop
	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_slot_picker()
	)
	_slot_overlay.add_child(backdrop)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_overlay.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.10, 0.97)
	style.border_color = Color(0.75, 0.6, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title_text: String = "New Game — Select Slot" if mode == "new" else "Load Game — Select Slot"
	var title_lbl = Label.new()
	title_lbl.text = title_text
	title_lbl.add_theme_font_size_override("font_size", GameContext.fs(16))
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep = HSeparator.new()
	sep.modulate = Color(0.55, 0.4, 0.25, 0.5)
	vbox.add_child(sep)

	# Load slot metadata
	var slots: Array = GameContext.load_slot_metadata()

	# Build slot rows
	for i in GameContext.SAVE_SLOT_COUNT:
		var slot_data: Dictionary = slots[i] if i < slots.size() else {"exists": false}
		var has_save: bool = slot_data.get("exists", false)
		# Also check file existence (metadata might be stale)
		if not has_save:
			has_save = GameContext.slot_has_save(i)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		# Slot info label
		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		if has_save:
			var region_num: int = slot_data.get("region", 1)
			var hero_count: int = slot_data.get("heroes", 0)
			var gold: int = slot_data.get("gold", 0)
			var ng_cycle: int = slot_data.get("ng_cycle", 0)
			var date_str: String = slot_data.get("play_date", "")
			var ng_text: String = " (NG+%d)" % ng_cycle if ng_cycle > 0 else ""
			info_lbl.text = "Slot %d: Region %d — %d Heroes — %dg%s" % [i + 1, region_num, hero_count, gold, ng_text]
			if date_str != "":
				info_lbl.text += "\n" + date_str
			info_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75, 1))
		else:
			info_lbl.text = "Slot %d: Empty" % (i + 1)
			info_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		row.add_child(info_lbl)

		# Action button
		if mode == "new":
			var action_btn = Button.new()
			action_btn.focus_mode = Control.FOCUS_ALL
			action_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
			action_btn.custom_minimum_size = Vector2(90, 32)
			if has_save:
				action_btn.text = "Overwrite"
				action_btn.modulate = Color(1.0, 0.7, 0.5)
			else:
				action_btn.text = "Start"
				action_btn.modulate = Color(0.7, 1.0, 0.7)
			var slot_idx: int = i
			action_btn.pressed.connect(func(): _on_slot_selected_new(slot_idx, has_save))
			row.add_child(action_btn)
		else:  # load
			var load_btn = Button.new()
			load_btn.focus_mode = Control.FOCUS_ALL
			load_btn.text = "Load"
			load_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
			load_btn.custom_minimum_size = Vector2(90, 32)
			load_btn.disabled = not has_save
			if has_save:
				load_btn.modulate = Color(0.7, 0.85, 1.0)
			else:
				load_btn.modulate = Color(0.4, 0.4, 0.4)
			var slot_idx: int = i
			load_btn.pressed.connect(func(): _on_slot_selected_load(slot_idx))
			row.add_child(load_btn)

		# Delete button (only if save exists)
		if has_save:
			var del_btn = Button.new()
			del_btn.text = "X"
			del_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			del_btn.custom_minimum_size = Vector2(32, 32)
			del_btn.modulate = Color(1.0, 0.5, 0.5)
			del_btn.tooltip_text = "Delete save"
			var slot_idx: int = i
			del_btn.pressed.connect(func():
				GameContext.delete_slot(slot_idx)
				_close_slot_picker()
				_open_slot_picker(_slot_mode)  # Refresh
			)
			row.add_child(del_btn)

	# Back button
	var back_btn = Button.new()
	back_btn.focus_mode = Control.FOCUS_ALL
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	back_btn.custom_minimum_size = Vector2(120, 34)
	back_btn.pressed.connect(_close_slot_picker)
	vbox.add_child(back_btn)
	back_btn.call_deferred("grab_focus")

	add_child(_slot_overlay)
	UIAudio.register_closeable(_slot_overlay, _close_slot_picker)


func _close_slot_picker() -> void:
	if _slot_overlay != null and is_instance_valid(_slot_overlay):
		UIAudio.unregister_closeable(_slot_overlay)
		_slot_overlay.queue_free()
		_slot_overlay = null


func _on_slot_selected_new(slot: int, has_existing: bool) -> void:
	_close_slot_picker()
	GameContext.start_new_game(slot)
	# Check if intro cutscene should play
	if not GameContext.has_campaign_flag("shown_intro_cutscene") and ResourceLoader.exists(INTRO_CUTSCENE_PATH):
		print("[TitleScreen] New game slot %d — routing to intro cutscene" % slot)
		SceneTransition.fade_to(INTRO_CUTSCENE_PATH)
	else:
		print("[TitleScreen] New game slot %d — routing to TownHub" % slot)
		SceneTransition.fade_to(TOWN_HUB_PATH)


func _on_slot_selected_load(slot: int) -> void:
	_close_slot_picker()
	GameContext.select_slot(slot)
	# Route based on saved phase
	_route_to_saved_phase()


func _route_to_saved_phase() -> void:
	var phase: int = GameContext.get_phase()
	var target: String = ""
	match phase:
		GameContext.GamePhase.COMBAT:
			target = "res://Game/UI/Combat/CombatScene.tscn"
		GameContext.GamePhase.DUNGEON_CAMP:
			target = "res://Game/UI/Dungeon/DungeonCampScene.tscn"
		GameContext.GamePhase.ROOM_EVENT:
			target = "res://Game/UI/Rooms/RoomEventScene.tscn"
		_:
			target = TOWN_HUB_PATH
	if not ResourceLoader.exists(target):
		target = TOWN_HUB_PATH
	print("[TitleScreen] Loading slot %d — phase=%s → %s" % [GameContext.current_save_slot, GameContext.GamePhase.keys()[phase], target])
	SceneTransition.fade_to(target)


func _exit_tree() -> void:
	InputManager.clear_zones()
