class_name TutorialOverlay
extends RefCounted
## Reusable tutorial overlay system.
## Usage: var overlay = TutorialOverlay.try_show(self, "tutorial_welcome")
##        if overlay != null: await overlay.tutorial_finished


## Try to show a tutorial. Returns the overlay node (or null if already completed/not found).
## Caller can await overlay.tutorial_finished to wait for dismissal.
static func try_show(caller: Node, tutorial_id: String) -> Node:
	if GameContext.has_completed_tutorial(tutorial_id):
		return null
	var path: String = "res://Data/Tutorials/%s.json" % tutorial_id
	if not FileAccess.file_exists(path):
		push_warning("[Tutorial] File not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[Tutorial] Cannot open: %s" % path)
		return null
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[Tutorial] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return null
	var data: Dictionary = json.data
	if not data.has("steps") or not data.steps is Array or data.steps.is_empty():
		push_warning("[Tutorial] No steps in %s" % path)
		return null
	var overlay := _TutorialPanel.new(tutorial_id, data.steps)
	caller.add_child(overlay)
	return overlay


# ==========================================================================
# INNER CLASS: Tutorial panel overlay
# ==========================================================================

class _TutorialPanel extends CanvasLayer:
	signal tutorial_finished

	const BG_COLOR := Color(0.08, 0.08, 0.15, 0.97)
	const BORDER_COLOR := Color(0.75, 0.6, 0.3, 0.9)
	const SPEAKER_COLOR := Color(1.0, 0.85, 0.4, 1.0)
	const TITLE_COLOR := Color(0.95, 0.9, 0.8, 1.0)
	const BODY_COLOR := Color(0.85, 0.8, 0.7, 1.0)
	const SKIP_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const STEP_COLOR := Color(0.5, 0.5, 0.5, 0.6)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.5)
	const PANEL_WIDTH := 520
	const PORTRAIT_SIZE := 80

	var _tutorial_id: String
	var _steps: Array
	var _current_step: int = 0
	var _portrait_cache: Dictionary = {}

	var _speaker_label: Label
	var _title_label: Label
	var _body_label: RichTextLabel
	var _portrait_rect: TextureRect
	var _step_label: Label
	var _continue_btn: Button

	func _init(tutorial_id: String, steps: Array) -> void:
		_tutorial_id = tutorial_id
		_steps = steps
		layer = 10
		print("[Tutorial] Showing: %s (%d steps)" % [tutorial_id, steps.size()])

	func _ready() -> void:
		_build_ui()
		_display_step(0)
		# Fade in
		var root: Control = get_child(0)
		root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(root, "modulate:a", 1.0, 0.25)

	func _build_ui() -> void:
		# Root control to hold everything
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(root)

		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.color = BACKDROP_COLOR
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(backdrop)

		# Center container
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(center)

		# Panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		panel.add_theme_stylebox_override("panel", _create_panel_style())
		center.add_child(panel)

		# Margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		panel.add_child(margin)

		# Main VBox
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		margin.add_child(vbox)

		# Content row: portrait + text
		var content_row := HBoxContainer.new()
		content_row.add_theme_constant_override("separation", 16)
		vbox.add_child(content_row)

		# Portrait
		_portrait_rect = TextureRect.new()
		_portrait_rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
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

		# Title
		_title_label = Label.new()
		_title_label.add_theme_font_size_override("font_size", 18)
		_title_label.add_theme_color_override("font_color", TITLE_COLOR)
		text_col.add_child(_title_label)

		# Body
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.custom_minimum_size = Vector2(0, 60)
		_body_label.add_theme_font_size_override("normal_font_size", 14)
		_body_label.add_theme_color_override("default_color", BODY_COLOR)
		text_col.add_child(_body_label)

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		vbox.add_child(sep)

		# Button row
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 12)
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(btn_row)

		# Step counter
		_step_label = Label.new()
		_step_label.add_theme_font_size_override("font_size", 12)
		_step_label.add_theme_color_override("font_color", STEP_COLOR)
		_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(_step_label)

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

	func _display_step(index: int) -> void:
		_current_step = index
		var step: Dictionary = _steps[index]

		_speaker_label.text = step.get("speaker", "")
		_title_label.text = step.get("title", "")
		_body_label.text = step.get("body", "")

		# Step counter
		if _steps.size() > 1:
			_step_label.text = "%d / %d" % [index + 1, _steps.size()]
		else:
			_step_label.text = ""

		# Button text
		var is_last: bool = (index == _steps.size() - 1)
		var default_text: String = "Got it!" if is_last else "Continue"
		_continue_btn.text = step.get("button_text", default_text)

		# Portrait
		var portrait_path: String = step.get("portrait", "")
		if portrait_path != "" and not _portrait_cache.has(portrait_path):
			if ResourceLoader.exists(portrait_path):
				_portrait_cache[portrait_path] = load(portrait_path)
			else:
				push_warning("[Tutorial] Portrait not found: %s" % portrait_path)
				_portrait_cache[portrait_path] = null
		var tex = _portrait_cache.get(portrait_path)
		if tex != null:
			_portrait_rect.texture = tex
			_portrait_rect.visible = true
		else:
			_portrait_rect.visible = (portrait_path != "")

	func _on_continue_pressed() -> void:
		if _current_step < _steps.size() - 1:
			_display_step(_current_step + 1)
		else:
			_close()

	func _on_skip_pressed() -> void:
		_close()

	func _close() -> void:
		GameContext.complete_tutorial(_tutorial_id)
		tutorial_finished.emit()
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
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		return style
