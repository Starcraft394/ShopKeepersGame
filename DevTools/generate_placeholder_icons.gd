## generate_placeholder_icons.gd
## Generates 32x32 placeholder status and buff icons with colored backgrounds and text.
## Run with: godot --headless --script res://DevTools/generate_placeholder_icons.gd --quit
extends SceneTree

const ICON_SIZE = 32

# Status icons: id -> {color, text}
const STATUS_ICONS = {
	"stunned": {"color": Color(0.2, 0.6, 0.9), "text": "STN"},
	"poisoned": {"color": Color(0.4, 0.8, 0.2), "text": "PSN"},
	"bleeding": {"color": Color(0.9, 0.2, 0.2), "text": "BLD"},
	"doom": {"color": Color(0.5, 0.1, 0.5), "text": "DM"},
	"burn": {"color": Color(1.0, 0.5, 0.1), "text": "BRN"},
}

# Buff icons: id -> {color, text}
const BUFF_ICONS = {
	"shadowstep": {"color": Color(0.3, 0.3, 0.5), "text": "SHD"},
	"barkskin_blessing": {"color": Color(0.4, 0.6, 0.3), "text": "DEF"},
	"fortify": {"color": Color(0.5, 0.5, 0.6), "text": "FRT"},
}

func _init() -> void:
	print("[IconGen] Starting placeholder icon generation...")

	# Generate status icons
	for status_id in STATUS_ICONS:
		var config = STATUS_ICONS[status_id]
		var path = "res://Assets/Icons/Status/icon_status_%s.png" % status_id
		_generate_icon(path, config.color, config.text)

	# Generate buff icons
	for buff_id in BUFF_ICONS:
		var config = BUFF_ICONS[buff_id]
		var path = "res://Assets/Icons/Buffs/icon_buff_%s.png" % buff_id
		_generate_icon(path, config.color, config.text)

	print("[IconGen] Done! Generated %d status icons and %d buff icons." % [
		STATUS_ICONS.size(), BUFF_ICONS.size()
	])
	quit()


func _generate_icon(path: String, bg_color: Color, text: String) -> void:
	var img = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)

	# Fill background with color
	img.fill(bg_color)

	# Add a darker border (2px)
	var border_color = bg_color.darkened(0.3)
	for x in range(ICON_SIZE):
		for y in range(ICON_SIZE):
			if x < 2 or x >= ICON_SIZE - 2 or y < 2 or y >= ICON_SIZE - 2:
				img.set_pixel(x, y, border_color)

	# Add corner rounding (crude approximation)
	var transparent = Color(0, 0, 0, 0)
	for corner in [[0,0], [0,ICON_SIZE-1], [ICON_SIZE-1,0], [ICON_SIZE-1,ICON_SIZE-1]]:
		img.set_pixel(corner[0], corner[1], transparent)

	# Save the image
	var global_path = ProjectSettings.globalize_path(path)
	var err = img.save_png(global_path)
	if err == OK:
		print("[IconGen] Created: %s (%s)" % [path, text])
	else:
		print("[IconGen] FAILED: %s (error %d)" % [path, err])
