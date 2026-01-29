## convert_icons.gd
## Converts selected game-icons.net SVGs to 32x32 PNGs.
## Run with: godot --headless --script res://DevTools/convert_icons.gd --quit
extends SceneTree

# External library location (moved outside res:// to prevent Godot import bloat)
# See Docs/Icons/GAME_ICONS_LIBRARY_LOCATION.md for details
const DEFAULT_BASE_PATH = "C:/Users/rober/OneDrive/ShopKeepers External/GameIcons/extracted/icons/ffffff/000000/1x1"
var BASE_PATH: String

# Final selections based on manual review of search results
const SELECTIONS = {
	# Status icons
	"icon_status_stunned": {
		"svg": "delapouite/knocked-out-stars.svg",
		"author": "Delapouite",
		"dest": "res://Assets/Icons/Status/icon_status_stunned.png"
	},
	"icon_status_poisoned": {
		"svg": "sbed/poison.svg",
		"author": "Sbed",
		"dest": "res://Assets/Icons/Status/icon_status_poisoned.png"
	},
	"icon_status_bleeding": {
		"svg": "lorc/bleeding-wound.svg",
		"author": "Lorc",
		"dest": "res://Assets/Icons/Status/icon_status_bleeding.png"
	},
	"icon_status_doom": {
		"svg": "lorc/death-zone.svg",
		"author": "Lorc",
		"dest": "res://Assets/Icons/Status/icon_status_doom.png"
	},
	"icon_status_burn": {
		"svg": "carl-olsen/flame.svg",
		"author": "Carl Olsen",
		"dest": "res://Assets/Icons/Status/icon_status_burn.png"
	},
	# Buff icons
	"icon_buff_shadowstep": {
		"svg": "lorc/hood.svg",
		"author": "Lorc",
		"dest": "res://Assets/Icons/Buffs/icon_buff_shadowstep.png"
	},
	"icon_buff_barkskin_blessing": {
		"svg": "delapouite/oak-leaf.svg",
		"author": "Delapouite",
		"dest": "res://Assets/Icons/Buffs/icon_buff_barkskin_blessing.png"
	},
	"icon_buff_fortify": {
		"svg": "delapouite/viking-shield.svg",
		"author": "Delapouite",
		"dest": "res://Assets/Icons/Buffs/icon_buff_fortify.png"
	}
}

func _init() -> void:
	# Check for environment variable override
	var env_path = OS.get_environment("GAMEICONS_DIR")
	if env_path != "":
		BASE_PATH = env_path + "/icons/ffffff/000000/1x1"
		print("[IconConverter] Using GAMEICONS_DIR: %s" % env_path)
	else:
		BASE_PATH = DEFAULT_BASE_PATH

	print("[IconConverter] Starting SVG to PNG conversion...")
	print("[IconConverter] Target size: 32x32")

	var success_count = 0
	var fail_count = 0

	for icon_id in SELECTIONS:
		var config = SELECTIONS[icon_id]
		var svg_path = BASE_PATH + "/" + config["svg"]
		var dest_path = config["dest"]
		var author = config["author"]

		print("\n[IconConverter] Converting: %s" % icon_id)
		print("  Source: %s" % svg_path)
		print("  Dest: %s" % dest_path)
		print("  Author: %s" % author)

		if _convert_svg_to_png(svg_path, dest_path):
			print("  Result: SUCCESS")
			success_count += 1
		else:
			print("  Result: FAILED")
			fail_count += 1

	print("\n[IconConverter] Conversion complete: %d success, %d failed" % [success_count, fail_count])

	# Print attribution summary
	print("\n" + "=".repeat(60))
	print("  ATTRIBUTION SUMMARY (for GAME_ICONS_ATTRIBUTION.md)")
	print("=".repeat(60))
	for icon_id in SELECTIONS:
		var config = SELECTIONS[icon_id]
		var svg_name = config["svg"].get_file()
		print("| %s | %s | %s | CC BY 3.0 |" % [
			icon_id + ".png",
			svg_name,
			config["author"]
		])
	print("=".repeat(60))

	quit()


func _convert_svg_to_png(svg_path: String, dest_path: String) -> bool:
	# Check if SVG file exists
	if not FileAccess.file_exists(svg_path):
		print("  ERROR: SVG file not found: %s" % svg_path)
		return false

	# Load SVG as text and create an Image
	var svg_file = FileAccess.open(svg_path, FileAccess.READ)
	if svg_file == null:
		print("  ERROR: Cannot open SVG file")
		return false

	var svg_content = svg_file.get_as_text()
	svg_file.close()

	# Create image from SVG using Godot's built-in SVG support
	var img = Image.new()

	# Try to load SVG data
	var err = img.load_svg_from_string(svg_content, 1.0)  # scale = 1.0
	if err != OK:
		print("  ERROR: Failed to load SVG (error %d)" % err)
		return false

	# Resize to 32x32
	img.resize(32, 32, Image.INTERPOLATE_LANCZOS)

	# Save as PNG
	var global_dest = ProjectSettings.globalize_path(dest_path)
	err = img.save_png(global_dest)
	if err != OK:
		print("  ERROR: Failed to save PNG (error %d)" % err)
		return false

	return true
