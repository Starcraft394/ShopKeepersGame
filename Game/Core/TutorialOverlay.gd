class_name TutorialOverlay
extends RefCounted
## Reusable tutorial overlay system with optional spotlight highlighting.
## Usage: var overlay = TutorialOverlay.try_show(self, "tutorial_welcome")
##        if overlay != null: await overlay.tutorial_finished
## Spotlight: TutorialOverlay.try_show(self, "tutorial_shop", {"facility_panel": panel_node})


## Try to show a tutorial. Returns the overlay node (or null if already completed/not found).
## Caller can await overlay.tutorial_finished to wait for dismissal.
## targets: optional Dictionary mapping highlight keys (from JSON) to Control nodes.
static func try_show(caller: Node, tutorial_id: String, targets: Dictionary = {}) -> Node:
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
	var overlay := _TutorialPanel.new(tutorial_id, data.steps, targets)
	caller.add_child(overlay)
	return overlay


# ==========================================================================
# INNER CLASS: Tutorial panel overlay with spotlight support
# ==========================================================================

class _TutorialPanel extends CanvasLayer:
	signal tutorial_finished

	# Panel styling
	const BG_COLOR := Color(0.08, 0.08, 0.15, 0.97)
	const BORDER_COLOR := Color(0.75, 0.6, 0.3, 0.9)
	const SPEAKER_COLOR := Color(1.0, 0.85, 0.4, 1.0)
	const TITLE_COLOR := Color(0.95, 0.9, 0.8, 1.0)
	const BODY_COLOR := Color(0.85, 0.8, 0.7, 1.0)
	const SKIP_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const STEP_COLOR := Color(0.5, 0.5, 0.5, 0.6)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.5)
	const PANEL_WIDTH := 400
	const PORTRAIT_SIZE := 64

	# Spotlight styling
	const SPOTLIGHT_DIM := Color(0.0, 0.0, 0.0, 0.65)
	const SPOTLIGHT_PAD := 8.0
	const PANEL_GAP := 24.0

	# State
	var _tutorial_id: String
	var _steps: Array
	var _current_step: int = 0
	var _portrait_cache: Dictionary = {}
	var _targets: Dictionary = {}

	# Hold-to-close on last step
	const HOLD_CLOSE_TIME := 1.5
	var _is_holding_accept: bool = false
	var _hold_time: float = 0.0

	# UI references
	var _root: Control = null
	var _backdrop: ColorRect = null
	var _dark_rects: Array[ColorRect] = []
	var _highlight_border: PanelContainer = null
	var _highlight_tween: Tween = null
	var _panel: PanelContainer = null
	var _speaker_label: Label
	var _title_label: Label
	var _body_label: RichTextLabel
	var _portrait_rect: TextureRect
	var _step_label: Label
	var _back_btn: Button
	var _skip_btn: Button
	var _continue_btn: Button
	var _hold_container: Control = null
	var _hold_bar_fill: ColorRect = null

	func _init(tutorial_id: String, steps: Array, targets: Dictionary = {}) -> void:
		_tutorial_id = tutorial_id
		_steps = steps
		_targets = targets
		layer = 11
		print("[Tutorial] Showing: %s (%d steps)" % [tutorial_id, steps.size()])

	func _ready() -> void:
		_build_ui()
		_display_step(0)
		# Listen for device changes to swap hold/continue on last step
		InputManager.input_device_changed.connect(_on_device_changed)
		UIAudio.register_closeable(self, _close)
		# Fade in
		_root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, 0.25)

	func _build_ui() -> void:
		# Root control to hold everything
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_root)

		# Full-screen backdrop (for centered / no-target mode)
		_backdrop = ColorRect.new()
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backdrop.color = BACKDROP_COLOR
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(_backdrop)

		# 4 dark rects for spotlight mode (initially hidden)
		for i in 4:
			var r := ColorRect.new()
			r.color = SPOTLIGHT_DIM
			r.mouse_filter = Control.MOUSE_FILTER_STOP
			r.visible = false
			_root.add_child(r)
			_dark_rects.append(r)

		# Highlight border around target (gold frame, initially hidden)
		_highlight_border = PanelContainer.new()
		_highlight_border.add_theme_stylebox_override("panel", _create_highlight_style())
		_highlight_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_highlight_border.visible = false
		_root.add_child(_highlight_border)

		# Tutorial dialog panel (positioned dynamically — no CenterContainer)
		_panel = PanelContainer.new()
		_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		_panel.add_theme_stylebox_override("panel", _create_panel_style())
		_root.add_child(_panel)

		# Margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		_panel.add_child(margin)

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
		_speaker_label.add_theme_font_size_override("font_size", GameContext.fs(15))
		_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
		text_col.add_child(_speaker_label)

		# Title
		_title_label = Label.new()
		_title_label.add_theme_font_size_override("font_size", GameContext.fs(20))
		_title_label.add_theme_color_override("font_color", TITLE_COLOR)
		text_col.add_child(_title_label)

		# Body
		_body_label = RichTextLabel.new()
		_body_label.bbcode_enabled = false
		_body_label.fit_content = true
		_body_label.scroll_active = false
		_body_label.add_theme_font_size_override("normal_font_size", GameContext.fs(14))
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
		_step_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		_step_label.add_theme_color_override("font_color", STEP_COLOR)
		_step_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_row.add_child(_step_label)

		# Back button
		_back_btn = Button.new()
		_back_btn.text = "Back"
		_back_btn.flat = true
		_back_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		_back_btn.add_theme_color_override("font_color", SKIP_COLOR)
		_back_btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7, 1.0))
		_back_btn.focus_mode = Control.FOCUS_ALL
		_back_btn.pressed.connect(_on_back_pressed)
		btn_row.add_child(_back_btn)

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

		# Hold-to-close indicator (in button row, hidden until last step)
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

	# ---- Step display ----

	func _display_step(index: int) -> void:
		_current_step = index
		var step: Dictionary = _steps[index]

		# Reset hold state on any step change
		_is_holding_accept = false
		_hold_time = 0.0
		if _hold_container != null:
			_hold_container.visible = false

		_speaker_label.text = step.get("speaker", "")
		_title_label.text = step.get("title", "")
		_body_label.text = step.get("body", "")

		# Step counter and back button visibility
		if _steps.size() > 1:
			_step_label.text = "%d / %d" % [index + 1, _steps.size()]
			_back_btn.visible = true
			_back_btn.disabled = (index == 0)
		else:
			_step_label.text = ""
			_back_btn.visible = false

		# Last step: show hold indicator (gamepad) or Continue button (KBM)
		var is_last: bool = (index == _steps.size() - 1)
		if is_last:
			if _skip_btn != null:
				_skip_btn.visible = false
			_update_last_step_ui()
		else:
			_continue_btn.visible = true
			if _skip_btn != null:
				_skip_btn.visible = true
			if _hold_container != null:
				_hold_container.visible = false

		# Button text (for non-last steps)
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

		# Update spotlight (deferred so panel layout resolves before positioning)
		call_deferred("_update_spotlight", step)

	# ---- Spotlight system ----

	func _update_spotlight(step: Dictionary) -> void:
		var highlight_key: String = step.get("highlight", "")
		var target: Control = null
		if highlight_key != "" and _targets.has(highlight_key):
			target = _targets[highlight_key]
		if target != null and is_instance_valid(target) and target.is_inside_tree():
			print("[Tutorial] Spotlight ON: key=%s target=%s rect=%s" % [highlight_key, target.name, target.get_global_rect()])
			_show_spotlight(target)
		else:
			var reason: String = "no highlight key" if highlight_key == "" else (
				"key not in targets" if not _targets.has(highlight_key) else (
				"target null" if target == null else (
				"target invalid" if not is_instance_valid(target) else "not in tree")))
			print("[Tutorial] Centered fallback: key='%s' reason=%s targets=%s" % [highlight_key, reason, _targets.keys()])
			_show_centered()

	func _show_centered() -> void:
		_backdrop.visible = true
		for r in _dark_rects:
			r.visible = false
		_highlight_border.visible = false
		if _highlight_tween != null:
			_highlight_tween.kill()
			_highlight_tween = null
		# Center panel in viewport
		_panel.reset_size()
		var vp := get_viewport().get_visible_rect().size
		_panel.position = Vector2((vp.x - _panel.size.x) / 2, (vp.y - _panel.size.y) / 2)

	func _show_spotlight(target: Control) -> void:
		_backdrop.visible = false
		var rect := target.get_global_rect()
		var pad := SPOTLIGHT_PAD
		var vp := get_viewport().get_visible_rect().size

		# Top: full width, y=0 to target top
		_dark_rects[0].visible = true
		_dark_rects[0].position = Vector2.ZERO
		_dark_rects[0].size = Vector2(vp.x, maxf(0, rect.position.y - pad))

		# Bottom: full width, target bottom to viewport bottom
		var bot_y := rect.position.y + rect.size.y + pad
		_dark_rects[1].visible = true
		_dark_rects[1].position = Vector2(0, bot_y)
		_dark_rects[1].size = Vector2(vp.x, maxf(0, vp.y - bot_y))

		# Left: target height band, x=0 to target left
		_dark_rects[2].visible = true
		_dark_rects[2].position = Vector2(0, rect.position.y - pad)
		_dark_rects[2].size = Vector2(maxf(0, rect.position.x - pad), rect.size.y + pad * 2)

		# Right: target height band, target right to viewport right
		var right_x := rect.position.x + rect.size.x + pad
		_dark_rects[3].visible = true
		_dark_rects[3].position = Vector2(right_x, rect.position.y - pad)
		_dark_rects[3].size = Vector2(maxf(0, vp.x - right_x), rect.size.y + pad * 2)

		# Highlight border
		_highlight_border.visible = true
		_highlight_border.position = rect.position - Vector2(pad, pad)
		_highlight_border.size = rect.size + Vector2(pad * 2, pad * 2)

		# Pulse animation on highlight border
		if _highlight_tween != null:
			_highlight_tween.kill()
		_highlight_tween = create_tween().set_loops()
		_highlight_tween.tween_property(_highlight_border, "modulate:a", 0.6, 0.8)
		_highlight_tween.tween_property(_highlight_border, "modulate:a", 1.0, 0.8)

		# Position dialog panel near target
		_panel.reset_size()
		_position_panel_near(rect, vp)

	func _position_panel_near(target_rect: Rect2, vp: Vector2) -> void:
		var gap := PANEL_GAP
		var ps := _panel.size
		var pos := Vector2.ZERO

		# Try right of target
		if target_rect.end.x + gap + PANEL_WIDTH < vp.x:
			pos = Vector2(target_rect.end.x + gap,
				target_rect.get_center().y - ps.y / 2)
		# Try left of target
		elif target_rect.position.x - gap - PANEL_WIDTH > 0:
			pos = Vector2(target_rect.position.x - gap - PANEL_WIDTH,
				target_rect.get_center().y - ps.y / 2)
		# Try below target
		elif target_rect.end.y + gap + ps.y < vp.y:
			pos = Vector2((vp.x - PANEL_WIDTH) / 2, target_rect.end.y + gap)
		# Above target (fallback)
		else:
			pos = Vector2((vp.x - PANEL_WIDTH) / 2,
				target_rect.position.y - gap - ps.y)

		# Clamp to viewport bounds with margin
		pos = pos.clamp(Vector2(8, 8), vp - ps - Vector2(8, 8))
		_panel.position = pos

	# ---- Device-aware last step UI ----

	func _update_last_step_ui() -> void:
		var is_last: bool = (_current_step == _steps.size() - 1)
		if not is_last:
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
		_update_last_step_ui()

	# ---- Callbacks ----

	func _on_continue_pressed() -> void:
		var is_last: bool = (_current_step == _steps.size() - 1)
		if is_last:
			if InputManager.active_device != "gamepad":
				_close()
			return
		if _current_step < _steps.size() - 1:
			_display_step(_current_step + 1)

	func _on_back_pressed() -> void:
		if _current_step > 0:
			_display_step(_current_step - 1)

	func _on_skip_pressed() -> void:
		var is_last: bool = (_current_step == _steps.size() - 1)
		if is_last and InputManager.active_device == "gamepad":
			return  # Must use hold-to-close on last step (gamepad only)
		_close()

	func _close() -> void:
		_is_holding_accept = false
		UIAudio.unregister_closeable(self)
		if InputManager.input_device_changed.is_connected(_on_device_changed):
			InputManager.input_device_changed.disconnect(_on_device_changed)
		if _highlight_tween != null:
			_highlight_tween.kill()
		GameContext.complete_tutorial(_tutorial_id)
		tutorial_finished.emit()
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
		var is_last: bool = (_current_step == _steps.size() - 1)

		if event.is_action_pressed("ui_accept"):
			if is_last:
				if InputManager.active_device == "gamepad":
					# Start hold-to-close (gamepad only)
					_is_holding_accept = true
					_hold_time = 0.0
					if _hold_container != null:
						_hold_container.visible = true
						if _hold_bar_fill != null:
							_hold_bar_fill.anchor_right = 0.0
				else:
					# KBM: instant close on last step
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
				# Keep container visible on last step as instruction
				if _current_step != _steps.size() - 1 and _hold_container != null:
					_hold_container.visible = false
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()

	# ---- Style helpers ----

	static func _create_panel_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = BORDER_COLOR
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 8
		return style

	static func _create_highlight_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(1.0, 0.85, 0.4, 0.9)
		style.set_border_width_all(3)
		style.set_corner_radius_all(6)
		style.shadow_color = Color(1.0, 0.85, 0.4, 0.3)
		style.shadow_size = 6
		return style
