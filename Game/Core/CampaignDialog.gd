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
				# -1 means final floor before boss
				var dungeon_id: String = GameContext.get_current_dungeon_id()
				var dungeon_data = DataRegistry.get_dungeon(dungeon_id)
				var total_floors: int = dungeon_data.floor_count if dungeon_data != null else 4
				if floor_num != total_floors:
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

	# UI nodes
	var _root: Control
	var _backdrop: ColorRect
	var _panel_container: PanelContainer
	var _center: CenterContainer
	var _speaker_label: Label
	var _body_label: RichTextLabel
	var _portrait_rect: TextureRect
	var _continue_btn: Button
	var _indicator_label: Label

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
		_speaker_label.add_theme_font_size_override("font_size", 14)
		_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
		text_col.add_child(_speaker_label)

		# Body text
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.custom_minimum_size = Vector2(0, 60)
		_body_label.add_theme_font_size_override("normal_font_size", 15)
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
		_speaker_label.add_theme_font_size_override("font_size", 13)
		_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
		text_col.add_child(_speaker_label)

		# Body text
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.custom_minimum_size = Vector2(0, 40)
		_body_label.add_theme_font_size_override("normal_font_size", 14)
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
		_indicator_label.add_theme_font_size_override("font_size", 12)
		_indicator_label.add_theme_color_override("font_color", SKIP_COLOR)
		_indicator_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(_indicator_label)

		# Skip button
		var skip_btn := Button.new()
		skip_btn.text = "Skip"
		skip_btn.flat = true
		skip_btn.add_theme_font_size_override("font_size", 12)
		skip_btn.add_theme_color_override("font_color", SKIP_COLOR)
		skip_btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7, 1.0))
		skip_btn.pressed.connect(_on_skip_pressed)
		btn_row.add_child(skip_btn)

		# Continue button
		_continue_btn = Button.new()
		_continue_btn.add_theme_font_size_override("font_size", 15)
		_continue_btn.pressed.connect(_on_continue_pressed)
		btn_row.add_child(_continue_btn)

	func _display_current() -> void:
		if _current_dialog_idx >= _dialog_queue.size():
			_close()
			return
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

		# Button text
		var is_last_line: bool = (line_idx >= dialog.lines.size() - 1)
		var is_last_dialog: bool = (_current_dialog_idx >= _dialog_queue.size() - 1)
		if is_last_line and is_last_dialog:
			_continue_btn.text = "Close"
		else:
			_continue_btn.text = "Continue"

		# Indicator (lines remaining in this dialog)
		var total_lines: int = dialog.lines.size()
		if total_lines > 1:
			_indicator_label.text = "%d / %d" % [line_idx + 1, total_lines]
		else:
			_indicator_label.text = ""

	func _on_continue_pressed() -> void:
		var dialog = _dialog_queue[_current_dialog_idx]
		if _current_line_idx < dialog.lines.size() - 1:
			# Advance to next line
			_current_line_idx += 1
			_display_current()
		else:
			# Mark this dialog as shown and advance to next dialog
			_mark_dialog_shown(dialog)
			_current_dialog_idx += 1
			_current_line_idx = 0
			_display_current()

	func _on_skip_pressed() -> void:
		# Mark current dialog as shown, advance to next
		var dialog = _dialog_queue[_current_dialog_idx]
		_mark_dialog_shown(dialog)
		_current_dialog_idx += 1
		_current_line_idx = 0
		if _current_dialog_idx >= _dialog_queue.size():
			_close()
		else:
			_display_current()

	func _mark_dialog_shown(dialog) -> void:
		GameContext.set_campaign_flag("shown_" + dialog.id)
		if dialog.flag_set != "":
			GameContext.set_campaign_flag(dialog.flag_set)

	func _close() -> void:
		GameContext.save_game()
		dialog_finished.emit()
		queue_free()

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				_on_continue_pressed()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE:
				_on_skip_pressed()
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
