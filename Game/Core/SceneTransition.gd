## SceneTransition.gd
## Lightweight fade-to-black scene transition autoload.
## Usage: SceneTransition.fade_to("res://Game/UI/TownHub/TownHubScene.tscn")
extends CanvasLayer

const DEFAULT_DURATION := 0.3

var _color_rect: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS

	_color_rect = ColorRect.new()
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_color_rect)


## Fade out to black, change scene, then fade back in.
func fade_to(scene_path: String, duration: float = DEFAULT_DURATION) -> void:
	if _transitioning:
		# Already transitioning — fall back to direct change
		get_tree().call_deferred("change_scene_to_file", scene_path)
		return
	_transitioning = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fade out
	var fade_out := create_tween()
	fade_out.tween_property(_color_rect, "color:a", 1.0, duration)
	await fade_out.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Wait one frame for scene to load
	await get_tree().process_frame

	# Fade in
	var fade_in := create_tween()
	fade_in.tween_property(_color_rect, "color:a", 0.0, duration)
	await fade_in.finished

	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
