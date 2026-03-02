## CutscenePlayer.gd
## Generic data-driven cutscene engine (CanvasLayer).
## Loads panels from JSON or direct injection, displays full-screen backgrounds
## with cross-fade, text, skip/continue, and emits cutscene_finished on close.
## Caller handles all post-cutscene logic (flags, scene transitions, etc.).
class_name CutscenePlayer
extends CanvasLayer

signal cutscene_finished

# ============================================================================
# CONFIGURATION
# ============================================================================

const TEXT_PANEL_STYLE_BG := Color(0.04, 0.03, 0.06, 0.88)
const TEXT_PANEL_BORDER := Color(0.75, 0.6, 0.3, 0.6)
const SPEAKER_COLOR := Color(1.0, 0.85, 0.4, 1)
const TEXT_COLOR := Color(0.92, 0.90, 0.85, 1)
const TITLE_COLOR := Color(1.0, 0.85, 0.4, 1)
const DEFAULT_BG_COLOR := Color(0.02, 0.02, 0.04)

# Skip visible from this panel index onward (0-based)
const SKIP_VISIBLE_FROM := 2
const HOLD_SKIP_TIME := 1.5

# ============================================================================
# STATE
# ============================================================================

var _panels: Array = []
var _current_panel: int = 0
var _bgm_key: String = ""

# UI nodes
var _root: Control = null
var _fallback_bg: ColorRect = null
var _bg_rect: TextureRect = null
var _text_panel: PanelContainer = null
var _speaker_label: Label = null
var _text_label: RichTextLabel = null
var _title_label: Label = null
var _progress_label: Label = null
var _skip_btn: Button = null
var _continue_btn: Button = null

# Text for the final panel button
var _final_button_text: String = "Close"

# Whether to show skip from the beginning (for short cutscenes)
var _always_show_skip: bool = false

# Hold-to-skip state
var _is_holding_accept: bool = false
var _hold_time: float = 0.0
var _back_btn: Button = null
var _controls_row: HBoxContainer = null
var _hold_container: Control = null
var _hold_bar_fill: ColorRect = null


# ============================================================================
# PUBLIC API
# ============================================================================

## Load panels from a JSON file. Optionally filter by a trigger_type field.
func load_from_json(path: String, trigger_type: String = "") -> bool:
	if not FileAccess.file_exists(path):
		push_warning("[CutscenePlayer] Data file not found: %s" % path)
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[CutscenePlayer] JSON parse error: %s" % json.get_error_message())
		file.close()
		return false
	file.close()
	var data: Dictionary = json.get_data()

	# If there are cutscenes array (boss cutscene format), find the matching trigger
	if data.has("cutscenes"):
		for cutscene in data["cutscenes"]:
			if trigger_type != "" and cutscene.get("trigger_type", "") != trigger_type:
				continue
			_panels = cutscene.get("panels", [])
			_bgm_key = cutscene.get("bgm", "")
			return _panels.size() > 0
		return false

	# Simple format: { "panels": [...] }
	_panels = data.get("panels", [])
	_bgm_key = data.get("bgm", "")
	return _panels.size() > 0


## Load panels directly from an array.
func load_panels(panels_array: Array, bgm_key: String = "") -> bool:
	_panels = panels_array
	_bgm_key = bgm_key
	return _panels.size() > 0


## Set text for the final panel's continue button (default: "Close").
func set_final_button_text(text: String) -> void:
	_final_button_text = text


## Force skip button visible from the start.
func set_always_show_skip(val: bool) -> void:
	_always_show_skip = val


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	layer = 10
	if _panels.is_empty():
		push_warning("[CutscenePlayer] No panels loaded — closing immediately")
		_close()
		return
	_build_ui()
	if _bgm_key != "":
		UIAudio.play_bgm(_bgm_key)
	_display_panel(0)
	# Fade in
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.25)
	print("[CutscenePlayer] Started (%d panels)" % _panels.size())


# ============================================================================
# UI BUILDING
# ============================================================================

func _build_ui() -> void:
	# Root control catches all input
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Fallback background color
	_fallback_bg = ColorRect.new()
	_fallback_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallback_bg.color = DEFAULT_BG_COLOR
	_root.add_child(_fallback_bg)

	# Background texture
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.modulate = Color(1, 1, 1, 0)
	_root.add_child(_bg_rect)

	# Title card label (centered, hidden)
	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_CENTER)
	_title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", GameContext.fs(28))
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.visible = false
	_root.add_child(_title_label)

	# Text panel (bottom of screen)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 0.63
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 60)
	margin.add_theme_constant_override("margin_top", 12)
	_root.add_child(margin)

	_text_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = TEXT_PANEL_STYLE_BG
	style.set_border_width_all(1)
	style.border_color = TEXT_PANEL_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	_text_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_text_panel)

	var text_vbox = VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 8)
	_text_panel.add_child(text_vbox)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	_speaker_label.add_theme_color_override("font_color", SPEAKER_COLOR)
	text_vbox.add_child(_speaker_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", GameContext.fs(15))
	_text_label.add_theme_color_override("default_color", TEXT_COLOR)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_vbox.add_child(_text_label)

	# Bottom controls bar
	_controls_row = HBoxContainer.new()
	_controls_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controls_row.anchor_left = 0.0
	_controls_row.anchor_top = 1.0
	_controls_row.anchor_right = 1.0
	_controls_row.anchor_bottom = 1.0
	_controls_row.offset_top = -44
	_controls_row.offset_left = 80
	_controls_row.offset_right = -80
	_controls_row.offset_bottom = -12
	_controls_row.add_theme_constant_override("separation", 12)
	_controls_row.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_controls_row)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", GameContext.fs(12))
	_progress_label.modulate = Color(0.6, 0.6, 0.6, 1)
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_row.add_child(_progress_label)

	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
	_back_btn.modulate = Color(0.7, 0.7, 0.7, 1)
	_back_btn.visible = false
	_back_btn.pressed.connect(_on_back_pressed)
	_back_btn.focus_mode = Control.FOCUS_ALL
	_controls_row.add_child(_back_btn)

	_skip_btn = Button.new()
	_skip_btn.text = "Skip"
	_skip_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
	_skip_btn.modulate = Color(0.7, 0.7, 0.7, 1)
	_skip_btn.visible = _always_show_skip
	_skip_btn.pressed.connect(_on_skip_pressed)
	_skip_btn.focus_mode = Control.FOCUS_ALL
	_controls_row.add_child(_skip_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.focus_mode = Control.FOCUS_ALL
	_continue_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
	_continue_btn.pressed.connect(_on_continue_pressed)
	_controls_row.add_child(_continue_btn)
	_continue_btn.call_deferred("grab_focus")

	# Hold-to-skip indicator (in controls row, hidden until skip is available)
	_hold_container = VBoxContainer.new()
	_hold_container.visible = false
	_hold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hold_container.custom_minimum_size = Vector2(168, 0)
	_hold_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_row.add_child(_hold_container)

	var hold_label := Label.new()
	hold_label.text = "Hold to Skip"
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


# ============================================================================
# PANEL DISPLAY
# ============================================================================

func _display_panel(index: int) -> void:
	_current_panel = index
	if index < 0 or index >= _panels.size():
		_close()
		return

	var panel: Dictionary = _panels[index]
	var is_title_card: bool = panel.get("title_card", false)
	var bg_path: String = panel.get("background", "")

	# Update fallback background color from panel data
	var fc: Array = panel.get("fallback_color", [])
	if fc.size() >= 3:
		_fallback_bg.color = Color(fc[0], fc[1], fc[2])

	# Load and cross-fade background
	var new_tex: Texture2D = null
	if bg_path != "" and ResourceLoader.exists(bg_path):
		new_tex = ResourceLoader.load(bg_path) as Texture2D

	if new_tex != null:
		var tween := create_tween()
		tween.tween_property(_bg_rect, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func():
			_bg_rect.texture = new_tex
		)
		tween.tween_property(_bg_rect, "modulate:a", 1.0, 0.4)
	else:
		_bg_rect.modulate.a = 0.0

	# Title card vs normal panel
	if is_title_card:
		_text_panel.visible = false
		_title_label.visible = true
		_title_label.text = panel.get("text", "")
		_title_label.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_title_label, "modulate:a", 1.0, 0.8)
	else:
		_text_panel.visible = true
		_title_label.visible = false
		var speaker: String = panel.get("speaker", "")
		_speaker_label.text = speaker
		_speaker_label.visible = (speaker != "")
		_text_label.text = panel.get("text", "")
		_text_panel.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_property(_text_panel, "modulate:a", 1.0, 0.3)

	# Progress counter
	_progress_label.text = "%d / %d" % [index + 1, _panels.size()]

	# Skip button visibility
	_skip_btn.visible = _always_show_skip or (index >= SKIP_VISIBLE_FROM)
	_back_btn.visible = (index > 0)

	# Hold indicator visibility (matches skip button)
	if _hold_container != null:
		_hold_container.visible = _always_show_skip or (index >= SKIP_VISIBLE_FROM)
		if _hold_bar_fill != null:
			_hold_bar_fill.anchor_right = 0.0
	_is_holding_accept = false
	_hold_time = 0.0

	# Continue button text
	var is_last: bool = (index == _panels.size() - 1)
	_continue_btn.text = _final_button_text if is_last else "Continue"


# ============================================================================
# INPUT
# ============================================================================

func _on_continue_pressed() -> void:
	if _current_panel < _panels.size() - 1:
		_display_panel(_current_panel + 1)
	else:
		_close()


func _on_back_pressed() -> void:
	if _current_panel > 0:
		_display_panel(_current_panel - 1)


func _on_skip_pressed() -> void:
	_close()


func _process(delta: float) -> void:
	if not _is_holding_accept:
		return
	_hold_time += delta
	var ratio: float = clampf(_hold_time / HOLD_SKIP_TIME, 0.0, 1.0)
	if _hold_bar_fill != null:
		_hold_bar_fill.anchor_right = ratio
	if _hold_time >= HOLD_SKIP_TIME:
		_is_holding_accept = false
		_hold_time = 0.0
		_on_skip_pressed()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_is_holding_accept = true
		_hold_time = 0.0
		if _hold_container != null:
			_hold_container.visible = true
			if _hold_bar_fill != null:
				_hold_bar_fill.anchor_right = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_released("ui_accept"):
		if _is_holding_accept:
			_is_holding_accept = false
			if _hold_time < HOLD_SKIP_TIME:
				_on_continue_pressed()
			if _hold_bar_fill != null:
				_hold_bar_fill.anchor_right = 0.0
			_hold_time = 0.0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _close() -> void:
	_is_holding_accept = false
	cutscene_finished.emit()
	queue_free()


func _exit_tree() -> void:
	InputManager.clear_zones()
