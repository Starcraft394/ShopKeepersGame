class_name CampaignDialog
extends RefCounted
## Campaign dialog overlay system.
## Usage: var overlay = CampaignDialog.try_show(self, "region_first_arrival")
##        if overlay != null: await overlay.dialog_finished


## Query all dialogs matching a trigger for the current region.
## Returns Array of CampaignDialogData that pass flag checks and haven't been shown.
static func get_pending_dialogs(trigger: String, region_id: String = "", floor_num: int = -1) -> Array:
	if region_id == "":
		region_id = GameContext.get_current_region_id()
	var all_dialogs: Array = DataRegistry.get_campaign_dialogs_for_region(region_id)
	var result: Array = []
	for dialog in all_dialogs:
		if dialog.trigger != trigger:
			continue
		# NG+ cycle gate: skip if current cycle is below dialog's minimum
		if dialog.min_ng_cycle > GameContext.ng_plus_cycle:
			continue
		# Already shown?
		if GameContext.has_campaign_flag("shown_" + dialog.id):
			continue
		# Flag prerequisite check
		if dialog.flag_required != "" and not GameContext.has_campaign_flag(dialog.flag_required):
			continue
		# Floor check for dungeon_camp_story
		if trigger == "dungeon_camp_story" and floor_num >= 0:
			var dialog_floor: int = dialog.dungeon_floor
			if dialog_floor == -1:
				# -1 means the camp immediately before the boss fight
				var dungeon_id: String = GameContext.get_current_dungeon_id()
				var dungeon_data = DataRegistry.get_dungeon(dungeon_id)
				var total_floors: int = dungeon_data.floor_count if dungeon_data != null else 4
				if floor_num != total_floors:
					continue
				# Must also be the camp where next room is the boss
				var choices: Dictionary = GameContext.get_pending_room_choices()
				var is_boss_next: bool = false
				for c in choices.get("choices", []):
					if c.get("forced_boss", false):
						is_boss_next = true
						break
				if not is_boss_next:
					continue
			elif dialog_floor != floor_num:
				continue
		result.append(dialog)
	return result


## Try to show campaign dialogs for a trigger. Returns the overlay node or null.
## Caller can: var overlay = CampaignDialog.try_show(self, "region_first_arrival")
##             if overlay != null: await overlay.dialog_finished
static func try_show(caller: Node, trigger: String, region_id: String = "", floor_num: int = -1) -> Node:
	var pending: Array = get_pending_dialogs(trigger, region_id, floor_num)
	if pending.is_empty():
		return null
	var panel := _CampaignPanel.new(pending)
	caller.add_child(panel)
	return panel


# ==========================================================================
# INNER CLASS: Campaign dialog panel overlay
# ==========================================================================

class _CampaignPanel extends CanvasLayer:
	signal dialog_finished

	# Story-themed colours (distinct from tutorial blue)
	const BG_COLOR := Color(0.06, 0.05, 0.1, 0.97)
	const BORDER_COLOR := Color(0.85, 0.65, 0.25, 0.9)
	const SPEAKER_COLOR := Color(1.0, 0.82, 0.35, 1.0)
	const BODY_COLOR := Color(0.9, 0.85, 0.75, 1.0)
	const SKIP_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
	const PANEL_WIDTH := 560
	const PORTRAIT_SIZE := 96
	const PORTRAIT_SIZE_SMALL := 64

	# Queue state
	var _dialog_queue: Array = []
	var _current_dialog_idx: int = 0
	var _current_line_idx: int = 0
	var _portrait_cache: Dictionary = {}

	# Hold-to-close on last line of last dialog
	const HOLD_CLOSE_TIME := 1.5
	var _is_holding_accept: bool = false
	var _hold_time: float = 0.0

	# UI nodes
	var _root: Control
	var _backdrop: ColorRect
	var _panel_container: PanelContainer
	var _center: CenterContainer
	var _speaker_label: Label
	var _body_label: RichTextLabel
	var _portrait_rect: TextureRect
	var _continue_btn: Button
	var _skip_btn: Button
	var _indicator_label: Label
	var _hold_container: Control = null
	var _hold_bar_fill: ColorRect = null

	func _init(dialogs: Array) -> void:
		_dialog_queue = dialogs
		layer = 10
		var ids: Array = []
		for d in dialogs:
			ids.append(d.id)
		print("[Campaign] Showing %d dialog(s): %s" % [dialogs.size(), ", ".join(ids)])

	func _ready() -> void:
		_build_ui()
		_display_current()
		# Listen for device changes to swap hold/continue on final page
		InputManager.input_device_changed.connect(_on_device_changed)
		UIAudio.register_closeable(self, _close)
		# Fade in
		_root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, 0.25)

	func _build_ui() -> void:
		var current_dialog = _dialog_queue[0]
		var dtype: String = current_dialog.display_type

		# Root control
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_root)

		# Backdrop
		_backdrop = ColorRect.new()
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backdrop.color = BACKDROP_COLOR
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(_backdrop)

		if dtype == "portrait_text_box":
			_build_bottom_layout(current_dialog)
		else:
			_build_centered_layout(current_dialog)

	func _build_centered_layout(_dialog) -> void:
		var is_event: bool = _dialog.display_type == "event_popup"

		# Center container
		_center = CenterContainer.new()
		_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(_center)

		# Panel
		_panel_container = PanelContainer.new()
		_panel_container.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		_panel_container.add_theme_stylebox_override("panel", _create_panel_style())
		_center.add_child(_panel_container)

		# Margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_theme_constant_override("margin_top", 20)
		margin.add_theme_constant_override("margin_bottom", 20)
		_panel_container.add_child(margin)

		# Main VBox
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		margin.add_child(vbox)

		# Content row: portrait + text
		var content_row := HBoxContainer.new()
		content_row.add_theme_constant_override("separation", 16)
		vbox.add_child(content_row)

		# Portrait (hidden for event_popup)
		_portrait_rect = TextureRect.new()
		_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait_rect.visible = not is_event
		content_row.add_child(_portrait_rect)

		# Text column
		var text_col := VBoxContainer.new()
		text_col.add_theme_constant_override("separation", 6)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_row.add_child(text_col)

		# Speaker name
		_speaker_label = Label.new()
		_speaker_label.add_theme_font_size_override("font_size", GameContext.fs(16))
		_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
		text_col.add_child(_speaker_label)

		# Body text
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.custom_minimum_size = Vector2(0, 60)
		_body_label.add_theme_font_size_override("normal_font_size", GameContext.fs(17))
		_body_label.add_theme_color_override("default_color", BODY_COLOR)
		text_col.add_child(_body_label)

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		vbox.add_child(sep)

		# Button row
		_build_button_row(vbox)

	func _build_bottom_layout(_dialog) -> void:
		# Bottom-anchored panel for portrait_text_box
		var bottom := Control.new()
		bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bottom.offset_top = -180
		_root.add_child(bottom)

		# Panel
		_panel_container = PanelContainer.new()
		_panel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel_container.add_theme_stylebox_override("panel", _create_panel_style())
		bottom.add_child(_panel_container)

		# Margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		_panel_container.add_child(margin)

		# Main VBox
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		# Content row
		var content_row := HBoxContainer.new()
		content_row.add_theme_constant_override("separation", 12)
		vbox.add_child(content_row)

		# Portrait (smaller for bottom bar)
		_portrait_rect = TextureRect.new()
		_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE_SMALL, PORTRAIT_SIZE_SMALL)
		_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		content_row.add_child(_portrait_rect)

		# Text column
		var text_col := VBoxContainer.new()
		text_col.add_theme_constant_override("separation", 4)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_row.add_child(text_col)

		# Speaker name
		_speaker_label = Label.new()
		_speaker_label.add_theme_font_size_override("font_size", GameContext.fs(15))
		_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
		text_col.add_child(_speaker_label)

		# Body text
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.custom_minimum_size = Vector2(0, 40)
		_body_label.add_theme_font_size_override("normal_font_size", GameContext.fs(16))
		_body_label.add_theme_color_override("default_color", BODY_COLOR)
		text_col.add_child(_body_label)

		# Button row
		_build_button_row(vbox)

	func _build_button_row(parent: VBoxContainer) -> void:
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 12)
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		parent.add_child(btn_row)

		# Line indicator
		_indicator_label = Label.new()
		_indicator_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		_indicator_label.add_theme_color_override("font_color", SKIP_COLOR)
		_indicator_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(_indicator_label)

		# Skip button
		_skip_btn = Button.new()
		_skip_btn.text = "Skip"
		_skip_btn.flat = true
		_skip_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		_skip_btn.add_theme_color_override("font_color", SKIP_COLOR)
		_skip_btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7, 1.0))
		_skip_btn.focus_mode = Control.FOCUS_ALL
		_skip_btn.pressed.connect(_on_skip_pressed)
		btn_row.add_child(_skip_btn)

		# Continue button
		_continue_btn = Button.new()
		_continue_btn.add_theme_font_size_override("font_size", GameContext.fs(17))
		_continue_btn.focus_mode = Control.FOCUS_ALL
		_continue_btn.pressed.connect(_on_continue_pressed)
		btn_row.add_child(_continue_btn)
		_continue_btn.call_deferred("grab_focus")

		# Hold-to-close indicator (in button row, hidden until final page)
		_hold_container = VBoxContainer.new()
		_hold_container.visible = false
		_hold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hold_container.custom_minimum_size = Vector2(168, 0)
		_hold_container.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_child(_hold_container)

		var hold_label := Label.new()
		hold_label.text = "Hold to Close"
		hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		hold_label.modulate = Color(0.8, 0.75, 0.6, 0.9)
		_hold_container.add_child(hold_label)

		var hold_bar_bg := ColorRect.new()
		hold_bar_bg.custom_minimum_size = Vector2(160, 8)
		hold_bar_bg.color = Color(0.2, 0.2, 0.2, 0.7)
		_hold_container.add_child(hold_bar_bg)

		_hold_bar_fill = ColorRect.new()
		_hold_bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_hold_bar_fill.anchor_right = 0.0
		_hold_bar_fill.color = Color(1.0, 0.85, 0.4, 0.9)
		hold_bar_bg.add_child(_hold_bar_fill)

	func _display_current() -> void:
		if _current_dialog_idx >= _dialog_queue.size():
			_close()
			return

		# Reset hold state on any step change
		_is_holding_accept = false
		_hold_time = 0.0
		if _hold_container != null:
			_hold_container.visible = false

		var dialog = _dialog_queue[_current_dialog_idx]
		var line_idx: int = _current_line_idx

		# Speaker
		_speaker_label.text = dialog.speaker_name if dialog.speaker_name != "" else ""

		# Body text (current line)
		if line_idx < dialog.lines.size():
			_body_label.text = dialog.lines[line_idx]
		else:
			_body_label.text = ""

		# Portrait
		var portrait_path: String = dialog.speaker_portrait
		if portrait_path != "" and not _portrait_cache.has(portrait_path):
			if ResourceLoader.exists(portrait_path):
				_portrait_cache[portrait_path] = load(portrait_path)
			else:
				push_warning("[Campaign] Portrait not found: %s" % portrait_path)
				_portrait_cache[portrait_path] = null
		var tex = _portrait_cache.get(portrait_path)
		if tex != null:
			_portrait_rect.texture = tex
			_portrait_rect.visible = true
		else:
			_portrait_rect.visible = (portrait_path != "" and dialog.display_type != "event_popup")

		# Last-page detection
		var is_last_line: bool = (line_idx >= dialog.lines.size() - 1)
		var is_last_dialog: bool = (_current_dialog_idx >= _dialog_queue.size() - 1)
		var is_final: bool = is_last_line and is_last_dialog

		# Last page: show hold indicator (gamepad) or Continue button (KBM)
		if is_final:
			if _skip_btn != null:
				_skip_btn.visible = false
			_update_final_page_ui()
		else:
			_continue_btn.visible = true
			if _skip_btn != null:
				_skip_btn.visible = true
			if _hold_container != null:
				_hold_container.visible = false

		# Button text (for non-last pages)
		_continue_btn.text = "Close" if is_final else "Continue"

		# Indicator (lines remaining in this dialog)
		var total_lines: int = dialog.lines.size()
		if total_lines > 1:
			_indicator_label.text = "%d / %d" % [line_idx + 1, total_lines]
		else:
			_indicator_label.text = ""

	# ---- Device-aware final page UI ----

	func _is_on_final_page() -> bool:
		if _current_dialog_idx >= _dialog_queue.size():
			return false
		var dialog = _dialog_queue[_current_dialog_idx]
		return (_current_line_idx >= dialog.lines.size() - 1) and (_current_dialog_idx >= _dialog_queue.size() - 1)

	func _update_final_page_ui() -> void:
		if not _is_on_final_page():
			return
		var use_hold: bool = (InputManager.active_device == "gamepad")
		if use_hold:
			_continue_btn.visible = false
			if _hold_container != null:
				_hold_container.visible = true
				if _hold_bar_fill != null:
					_hold_bar_fill.anchor_right = 0.0
		else:
			_continue_btn.visible = true
			_continue_btn.text = "Close"
			_continue_btn.call_deferred("grab_focus")
			if _hold_container != null:
				_hold_container.visible = false
			_is_holding_accept = false
			_hold_time = 0.0

	func _on_device_changed(_device_type: String) -> void:
		_update_final_page_ui()

	func _on_continue_pressed() -> void:
		var dialog = _dialog_queue[_current_dialog_idx]
		var is_last_line: bool = (_current_line_idx >= dialog.lines.size() - 1)
		var is_last_dialog: bool = (_current_dialog_idx >= _dialog_queue.size() - 1)
		if is_last_line and is_last_dialog:
			if InputManager.active_device != "gamepad":
				_close()
			return
		if _current_line_idx < dialog.lines.size() - 1:
			_current_line_idx += 1
			_display_current()
		else:
			_mark_dialog_shown(dialog)
			_current_dialog_idx += 1
			_current_line_idx = 0
			_display_current()

	func _on_skip_pressed() -> void:
		var is_last_dialog: bool = (_current_dialog_idx >= _dialog_queue.size() - 1)
		if is_last_dialog and InputManager.active_device == "gamepad":
			return  # Must use hold-to-close on last dialog (gamepad only)
		var dialog = _dialog_queue[_current_dialog_idx]
		_mark_dialog_shown(dialog)
		_current_dialog_idx += 1
		_current_line_idx = 0
		if _current_dialog_idx >= _dialog_queue.size():
			_close()
		else:
			_display_current()

	func _on_back_line() -> void:
		if _current_line_idx > 0:
			_current_line_idx -= 1
			_display_current()
		elif _current_dialog_idx > 0:
			_current_dialog_idx -= 1
			var prev_dialog = _dialog_queue[_current_dialog_idx]
			_current_line_idx = prev_dialog.lines.size() - 1
			_display_current()

	func _mark_dialog_shown(dialog) -> void:
		GameContext.set_campaign_flag("shown_" + dialog.id)
		if dialog.flag_set != "":
			GameContext.set_campaign_flag(dialog.flag_set)

	func _close() -> void:
		_is_holding_accept = false
		UIAudio.unregister_closeable(self)
		if InputManager.input_device_changed.is_connected(_on_device_changed):
			InputManager.input_device_changed.disconnect(_on_device_changed)
		# Mark all remaining dialogs as shown before closing
		for i in range(_current_dialog_idx, _dialog_queue.size()):
			_mark_dialog_shown(_dialog_queue[i])
		GameContext.save_game()
		dialog_finished.emit()
		queue_free()

	func _process(delta: float) -> void:
		if not _is_holding_accept:
			return
		_hold_time += delta
		var ratio: float = clampf(_hold_time / HOLD_CLOSE_TIME, 0.0, 1.0)
		if _hold_bar_fill != null:
			_hold_bar_fill.anchor_right = ratio
		if _hold_time >= HOLD_CLOSE_TIME:
			_is_holding_accept = false
			_hold_time = 0.0
			if _hold_container != null:
				_hold_container.visible = false
			_close()

	func _input(event: InputEvent) -> void:
		var dialog = _dialog_queue[_current_dialog_idx] if _current_dialog_idx < _dialog_queue.size() else null
		if dialog == null:
			return
		var is_last_line: bool = (_current_line_idx >= dialog.lines.size() - 1)
		var is_last_dialog: bool = (_current_dialog_idx >= _dialog_queue.size() - 1)
		var is_final: bool = is_last_line and is_last_dialog

		if event.is_action_pressed("ui_accept"):
			if is_final:
				if InputManager.active_device == "gamepad":
					# Start hold-to-close (gamepad only)
					_is_holding_accept = true
					_hold_time = 0.0
					if _hold_container != null:
						_hold_container.visible = true
						if _hold_bar_fill != null:
							_hold_bar_fill.anchor_right = 0.0
				else:
					# KBM: instant close on final page
					_close()
			else:
				_on_continue_pressed()
			get_viewport().set_input_as_handled()
		elif event.is_action_released("ui_accept"):
			if _is_holding_accept:
				_is_holding_accept = false
				_hold_time = 0.0
				if _hold_bar_fill != null:
					_hold_bar_fill.anchor_right = 0.0
				# Keep container visible on final page as instruction
				var d = _dialog_queue[_current_dialog_idx] if _current_dialog_idx < _dialog_queue.size() else null
				var still_final: bool = false
				if d != null:
					still_final = (_current_line_idx >= d.lines.size() - 1) and (_current_dialog_idx >= _dialog_queue.size() - 1)
				if not still_final and _hold_container != null:
					_hold_container.visible = false
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_on_back_line()
			get_viewport().set_input_as_handled()

	static func _create_panel_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = BORDER_COLOR
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 10
		return style
