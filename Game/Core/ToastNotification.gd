## ToastNotification.gd
## Lightweight toast notification system for player feedback.
## Shows auto-fading messages at top-center of screen.
## Usage: ToastNotification.show_toast("Stash is full!", "error")
extends CanvasLayer

const MAX_VISIBLE: int = 3
const FADE_DURATION: float = 0.5
const DISPLAY_DURATION: float = 2.5
const TOAST_HEIGHT: int = 32
const TOAST_GAP: int = 4

var _toast_container: VBoxContainer = null
var _active_toasts: Array = []


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	_toast_container = VBoxContainer.new()
	_toast_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_container.offset_top = 8
	_toast_container.offset_left = -200
	_toast_container.offset_right = 200
	_toast_container.add_theme_constant_override("separation", TOAST_GAP)
	_toast_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_container)


## Show a toast message. Type: "error", "info", "success"
func show_toast(message: String, type: String = "error") -> void:
	# Enforce max visible — remove oldest if needed
	while _active_toasts.size() >= MAX_VISIBLE:
		var oldest: PanelContainer = _active_toasts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(0, TOAST_HEIGHT)

	# Style based on type
	var bg_color: Color
	var text_color: Color
	match type:
		"error":
			bg_color = Color(0.35, 0.12, 0.08, 0.92)
			text_color = Color(1.0, 0.75, 0.55)
		"success":
			bg_color = Color(0.08, 0.30, 0.12, 0.92)
			text_color = Color(0.6, 1.0, 0.7)
		"info":
			bg_color = Color(0.08, 0.18, 0.28, 0.92)
			text_color = Color(0.6, 0.85, 1.0)
		_:
			bg_color = Color(0.15, 0.12, 0.10, 0.92)
			text_color = Color(0.9, 0.85, 0.75)

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = text_color * Color(1, 1, 1, 0.4)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", GameContext.fs(13))
	label.add_theme_color_override("font_color", text_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_toast_container.add_child(panel)
	_active_toasts.append(panel)

	# Auto-fade and remove after display duration
	var tween: Tween = create_tween()
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(panel, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func():
		_active_toasts.erase(panel)
		if is_instance_valid(panel):
			panel.queue_free()
	)

	print("[Toast] %s: %s" % [type, message])
