## HeroSpriteAnimator.gd
## Drives a TextureRect by swapping its .texture property each frame tick.
## Used instead of AnimatedSprite2D because the combat UI is Control-based.
## Supports named animations with looping/one-shot behavior and auto-return to idle.
class_name HeroSpriteAnimator
extends RefCounted

var _sprite_frames: SpriteFrames = null
var _current_animation: String = "idle"
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = true
var _oneshot_callback: Callable = Callable()

# The TextureRect this animator drives
var _target: TextureRect = null


func _init(sprite_frames: SpriteFrames, target: TextureRect) -> void:
	_sprite_frames = sprite_frames
	_target = target
	play("idle")


## Play a named animation. One-shot animations auto-return to idle when finished.
## Optional callback fires when a one-shot animation completes.
func play(anim_name: String, on_finished: Callable = Callable()) -> void:
	if _sprite_frames == null or not _sprite_frames.has_animation(anim_name):
		return
	_current_animation = anim_name
	_current_frame = 0
	_elapsed = 0.0
	_playing = true
	_oneshot_callback = on_finished
	_apply_frame()


## Advance the animation by delta seconds. Call from _process().
func advance(delta: float) -> void:
	if not _playing or _sprite_frames == null:
		return
	if _target == null or not is_instance_valid(_target):
		_playing = false
		return

	var fps: float = _sprite_frames.get_animation_speed(_current_animation)
	if fps <= 0:
		return

	_elapsed += delta
	var frame_duration: float = 1.0 / fps

	if _elapsed >= frame_duration:
		_elapsed -= frame_duration
		_current_frame += 1
		var frame_count: int = _sprite_frames.get_frame_count(_current_animation)

		if _current_frame >= frame_count:
			if _sprite_frames.get_animation_loop(_current_animation):
				_current_frame = 0
			else:
				_current_frame = frame_count - 1
				_playing = false
				if _oneshot_callback.is_valid():
					_oneshot_callback.call()
					_oneshot_callback = Callable()
				# Return to idle after one-shot completes
				play("idle")
				return

		_apply_frame()


## Get the current animation name.
func get_current_animation() -> String:
	return _current_animation


## Apply the current frame texture to the target TextureRect.
func _apply_frame() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var frame_count: int = _sprite_frames.get_frame_count(_current_animation)
	if _current_frame < 0 or _current_frame >= frame_count:
		return
	var tex = _sprite_frames.get_frame_texture(_current_animation, _current_frame)
	if tex != null:
		_target.texture = tex
