extends Node
## BackgroundManager — Autoload that swaps ColorRect backgrounds for TextureRect
## when a matching background image exists in Assets/Backgrounds/.
##
## Usage from any scene's _ready():
##   BackgroundManager.apply_background(self, "town", "town_thornhaven_T1")
##   BackgroundManager.apply_background(self, "dungeon", "R1")
##   BackgroundManager.apply_background(self, "shop", "interior")
##   BackgroundManager.apply_background(self, "event", "R1")
##
## If no image exists, the original ColorRect stays visible (graceful fallback).

const BG_BASE_PATH := "res://Assets/Backgrounds/"

## Apply a background image to the scene's Background node.
## scene_root: the scene's root Control node (must have a child named "Background")
## scene_type: "town", "dungeon", "event", "shop", "building"
## location_key: identifier like "town_thornhaven_T1", "R1", "interior"
func apply_background(scene_root: Control, scene_type: String, location_key: String) -> void:
	var bg_node = scene_root.get_node_or_null("Background")
	if not bg_node:
		return

	var path := _resolve_path(scene_type, location_key)
	if not ResourceLoader.exists(path):
		return

	var texture: Texture2D = load(path)
	if not texture:
		return

	if bg_node is TextureRect:
		bg_node.texture = texture
		return

	if bg_node is ColorRect:
		var tex_rect := TextureRect.new()
		tex_rect.name = "Background"
		tex_rect.texture = texture
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var parent := bg_node.get_parent()
		var idx := bg_node.get_index()
		parent.remove_child(bg_node)
		bg_node.queue_free()
		parent.add_child(tex_rect)
		parent.move_child(tex_rect, idx)
		tex_rect.owner = scene_root
		print("[BackgroundManager] %s -> %s" % [scene_root.name, path])


func _resolve_path(scene_type: String, location_key: String) -> String:
	match scene_type:
		"town":
			return BG_BASE_PATH + "town_%s.png" % location_key if not location_key.begins_with("town_") else BG_BASE_PATH + "%s.png" % location_key
		"dungeon":
			return BG_BASE_PATH + "dungeon_%s.png" % location_key if not location_key.begins_with("dungeon_") else BG_BASE_PATH + "%s.png" % location_key
		"event":
			return BG_BASE_PATH + "event_%s.png" % location_key if not location_key.begins_with("event_") else BG_BASE_PATH + "%s.png" % location_key
		"shop":
			return BG_BASE_PATH + "shop_%s.png" % location_key if not location_key.begins_with("shop_") else BG_BASE_PATH + "%s.png" % location_key
		"building":
			return BG_BASE_PATH + "building_%s.png" % location_key if not location_key.begins_with("building_") else BG_BASE_PATH + "%s.png" % location_key
		_:
			return BG_BASE_PATH + "%s.png" % location_key
