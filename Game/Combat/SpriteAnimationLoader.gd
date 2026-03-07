## SpriteAnimationLoader.gd
## Static utility that builds SpriteFrames programmatically from a folder of frame PNGs.
## Follows the naming convention: {AnimName}{FrameNumber}.png (e.g., Idle1.png, Attack3.png)
## Caches loaded SpriteFrames by folder path to avoid redundant loading.
class_name SpriteAnimationLoader
extends RefCounted

# Animation definitions: name -> {prefix, max_frames, fps, loop}
const ANIMATION_DEFS: Dictionary = {
	"idle":   {"prefix": "Idle",   "max_frames": 8, "fps": 6.0, "loop": true},
	"attack": {"prefix": "Attack", "max_frames": 8, "fps": 10.0, "loop": false},
	"cast":   {"prefix": "Cast",   "max_frames": 8, "fps": 10.0, "loop": false},
	"hit":    {"prefix": "Hit",    "max_frames": 8, "fps": 10.0, "loop": false},
	"death":  {"prefix": "Death",  "max_frames": 8, "fps": 8.0,  "loop": false},
	"walk":   {"prefix": "Walk",   "max_frames": 8, "fps": 8.0,  "loop": true},
}

# Cache: folder_path -> SpriteFrames
static var _cache: Dictionary = {}


## Load or retrieve cached SpriteFrames for the given sprite folder path.
## Returns null if the folder has no valid animation frames.
static func load_sprite_frames(folder_path: String) -> SpriteFrames:
	if _cache.has(folder_path):
		return _cache[folder_path]

	var frames = SpriteFrames.new()
	# Remove the default animation that SpriteFrames creates
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var any_frames_loaded: bool = false

	for anim_name in ANIMATION_DEFS:
		var def: Dictionary = ANIMATION_DEFS[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, def["fps"])
		frames.set_animation_loop(anim_name, def["loop"])

		var frame_idx: int = 1
		while frame_idx <= def["max_frames"]:
			var path: String = "%s/%s%d.png" % [folder_path, def["prefix"], frame_idx]
			if ResourceLoader.exists(path):
				var tex = load(path)
				if tex != null:
					frames.add_frame(anim_name, tex)
					any_frames_loaded = true
			else:
				break  # No more frames for this animation
			frame_idx += 1

	if not any_frames_loaded:
		return null

	_cache[folder_path] = frames
	return frames


## Clear the cache (useful for testing or hot-reload).
static func clear_cache() -> void:
	_cache.clear()
