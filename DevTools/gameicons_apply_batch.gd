## gameicons_apply_batch.gd
## Batch applies game-icons.net SVGs to project as 32x32 PNGs.
## Reads external library location from GAMEICONS_DIR environment variable.
## Run with: godot --headless --script res://DevTools/gameicons_apply_batch.gd --quit
extends SceneTree

# Target definitions: id -> {keywords, dest, category}
const TARGETS = {
	# Status icons
	"stunned": {
		"keywords": ["stun", "stunned", "dizzy", "stars", "knockout", "ko", "knocked"],
		"dest": "res://Assets/Icons/Status/icon_status_stunned.png",
		"category": "status"
	},
	"poisoned": {
		"keywords": ["poison", "toxic", "venom", "skull", "biohazard", "potion"],
		"dest": "res://Assets/Icons/Status/icon_status_poisoned.png",
		"category": "status"
	},
	"bleeding": {
		"keywords": ["bleed", "bleeding", "blood", "wound", "cut", "dripping"],
		"dest": "res://Assets/Icons/Status/icon_status_bleeding.png",
		"category": "status"
	},
	"doom": {
		"keywords": ["doom", "skull", "death", "reaper", "curse", "omen", "hex"],
		"dest": "res://Assets/Icons/Status/icon_status_doom.png",
		"category": "status"
	},
	"burn": {
		"keywords": ["burn", "fire", "flame", "heat", "ember", "blaze", "inferno"],
		"dest": "res://Assets/Icons/Status/icon_status_burn.png",
		"category": "status"
	},
	# Buff icons
	"shadowstep": {
		"keywords": ["shadow", "hood", "stealth", "cloak", "ninja", "rogue", "dash"],
		"dest": "res://Assets/Icons/Buffs/icon_buff_shadowstep.png",
		"category": "buff"
	},
	"barkskin_blessing": {
		"keywords": ["bark", "leaf", "oak", "nature", "tree", "wood", "shell"],
		"dest": "res://Assets/Icons/Buffs/icon_buff_barkskin_blessing.png",
		"category": "buff"
	},
	"fortify": {
		"keywords": ["fortify", "shield", "tower", "wall", "castle", "defense", "guard", "bulwark"],
		"dest": "res://Assets/Icons/Buffs/icon_buff_fortify.png",
		"category": "buff"
	}
}

# Complexity penalty words (prefer simpler icons)
const COMPLEX_WORDS = ["detailed", "scene", "full", "body", "person", "human", "portrait"]

# Preferred authors (large consistent icon sets)
const PREFERRED_AUTHORS = ["lorc", "delapouite", "carl-olsen", "sbed"]

var _svg_index: Array = []  # Array of {path, name, author, keywords}
var _results: Dictionary = {}  # id -> {selected, alternates, success, error}
var _lib_root: String = ""


func _init() -> void:
	print("=" .repeat(70))
	print("  GAME-ICONS BATCH APPLY v1")
	print("=" .repeat(70))

	# Step 1: Validate GAMEICONS_DIR
	if not _validate_library_path():
		print("\n[FATAL] Cannot proceed without valid GAMEICONS_DIR")
		quit(1)
		return

	# Step 2: Build SVG index
	print("\n[Step 2] Building SVG index...")
	var icons_path = _lib_root + "/extracted/icons/ffffff/000000/1x1"
	_build_svg_index(icons_path)
	print("[Index] Found %d SVG files" % _svg_index.size())

	if _svg_index.size() == 0:
		print("[FATAL] No SVG files found in: %s" % icons_path)
		quit(1)
		return

	# Step 3: Select and convert each target
	print("\n[Step 3] Processing targets...")
	var success_count = 0
	var fail_count = 0

	for target_id in TARGETS:
		var target = TARGETS[target_id]
		print("\n--- %s ---" % target_id.to_upper())

		var result = _process_target(target_id, target)
		_results[target_id] = result

		if result["success"]:
			success_count += 1
			print("  [OK] %s -> %s" % [result["selected"]["name"], target["dest"]])
		else:
			fail_count += 1
			print("  [FAIL] %s" % result["error"])

	# Step 4: Update attribution file
	print("\n[Step 4] Updating attribution...")
	_update_attribution_file()

	# Step 5: Write mapping report
	print("\n[Step 5] Writing mapping report...")
	_write_mapping_report()

	# Final summary
	print("\n" + "=" .repeat(70))
	print("  BATCH APPLY COMPLETE")
	print("=" .repeat(70))
	print("  Success: %d" % success_count)
	print("  Failed:  %d" % fail_count)
	print("=" .repeat(70))

	if fail_count > 0:
		quit(1)
	else:
		quit(0)


func _validate_library_path() -> bool:
	print("\n[Step 1] Validating GAMEICONS_DIR...")

	_lib_root = OS.get_environment("GAMEICONS_DIR")

	if _lib_root == "":
		print("[ERROR] GAMEICONS_DIR environment variable is not set.")
		print("[INFO] Set it to the game-icons library root, e.g.:")
		print("       $env:GAMEICONS_DIR = 'C:\\Users\\rober\\OneDrive\\ShopKeepers External\\GameIcons'")
		return false

	print("[ENV] GAMEICONS_DIR = %s" % _lib_root)

	# Check root exists
	if not DirAccess.dir_exists_absolute(_lib_root):
		print("[ERROR] Directory does not exist: %s" % _lib_root)
		return false

	# Check expected structure
	var expected_path = _lib_root + "/extracted/icons/ffffff/000000/1x1"
	if not DirAccess.dir_exists_absolute(expected_path):
		print("[ERROR] Expected folder structure not found: %s" % expected_path)
		print("[INFO] Expected: <GAMEICONS_DIR>/extracted/icons/ffffff/000000/1x1/")
		return false

	print("[OK] Library structure validated")
	return true


func _build_svg_index(base_path: String) -> void:
	var dir = DirAccess.open(base_path)
	if dir == null:
		print("[ERROR] Cannot open: %s" % base_path)
		return

	# Iterate author folders
	dir.list_dir_begin()
	var author = dir.get_next()
	while author != "":
		if dir.current_is_dir() and not author.begins_with("."):
			_scan_author_folder(base_path + "/" + author, author)
		author = dir.get_next()
	dir.list_dir_end()


func _scan_author_folder(folder_path: String, author: String) -> void:
	var dir = DirAccess.open(folder_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".svg"):
			var icon_name = file.replace(".svg", "")
			var keywords = _extract_keywords(icon_name)
			_svg_index.append({
				"path": folder_path + "/" + file,
				"name": icon_name,
				"author": author,
				"keywords": keywords
			})
		file = dir.get_next()
	dir.list_dir_end()


func _extract_keywords(name: String) -> Array:
	var parts = name.replace("-", " ").replace("_", " ").split(" ")
	var keywords: Array = []
	for part in parts:
		var clean = part.strip_edges().to_lower()
		if clean.length() > 1:
			keywords.append(clean)
	return keywords


func _process_target(target_id: String, target: Dictionary) -> Dictionary:
	var result = {
		"selected": null,
		"alternates": [],
		"success": false,
		"error": ""
	}

	# Score all SVGs
	var scores: Array = []
	for entry in _svg_index:
		var score = _score_entry(entry, target["keywords"])
		if score > 0:
			scores.append({"entry": entry, "score": score})

	# Sort by score descending
	scores.sort_custom(func(a, b): return a["score"] > b["score"])

	if scores.size() == 0:
		result["error"] = "No matching SVGs found"
		return result

	# Get best and alternates
	result["selected"] = scores[0]["entry"]
	result["selected"]["score"] = scores[0]["score"]

	for i in range(1, mini(6, scores.size())):
		var alt = scores[i]["entry"].duplicate()
		alt["score"] = scores[i]["score"]
		result["alternates"].append(alt)

	# Convert SVG to PNG
	var svg_path = result["selected"]["path"]
	var dest_path = target["dest"]

	if _convert_svg_to_png(svg_path, dest_path):
		result["success"] = true
	else:
		result["error"] = "SVG conversion failed"

	return result


func _score_entry(entry: Dictionary, search_keywords: Array) -> int:
	var score = 0
	var icon_name = entry["name"].to_lower()
	var icon_keywords = entry["keywords"]

	# Keyword matching
	for kw in search_keywords:
		# Exact word match
		if kw in icon_keywords:
			score += 10
		# Partial match in icon name
		elif icon_name.contains(kw):
			score += 5
		# Icon keyword contains search keyword
		else:
			for ik in icon_keywords:
				if ik.contains(kw) or kw.contains(ik):
					score += 2
					break

	# Simplicity bonus
	if icon_name.length() < 15:
		score += 3
	elif icon_name.length() > 25:
		score -= 2

	# Complexity penalty
	for cw in COMPLEX_WORDS:
		if icon_name.contains(cw):
			score -= 5

	# Preferred author bonus
	if entry["author"] in PREFERRED_AUTHORS:
		score += 2

	return score


func _convert_svg_to_png(svg_path: String, dest_path: String) -> bool:
	# Check SVG exists
	if not FileAccess.file_exists(svg_path):
		print("  [ERROR] SVG not found: %s" % svg_path)
		return false

	# Load SVG content
	var svg_file = FileAccess.open(svg_path, FileAccess.READ)
	if svg_file == null:
		print("  [ERROR] Cannot open SVG: %s" % svg_path)
		return false

	var svg_content = svg_file.get_as_text()
	svg_file.close()

	# Convert SVG to Image
	var img = Image.new()
	var err = img.load_svg_from_string(svg_content, 1.0)
	if err != OK:
		print("  [ERROR] SVG load failed (code %d)" % err)
		return false

	# Resize to 32x32
	img.resize(32, 32, Image.INTERPOLATE_LANCZOS)

	# Save PNG
	var global_dest = ProjectSettings.globalize_path(dest_path)
	err = img.save_png(global_dest)
	if err != OK:
		print("  [ERROR] PNG save failed (code %d)" % err)
		return false

	return true


func _update_attribution_file() -> void:
	var path = "res://Docs/Attribution/GAME_ICONS_ATTRIBUTION.md"
	var global_path = ProjectSettings.globalize_path(path)

	# Build attribution content
	var content = """# Game-icons.net Per-Icon Attribution

This document tracks attribution for each icon sourced from [game-icons.net](https://game-icons.net).

**License**: Creative Commons Attribution 3.0 Unported (CC BY 3.0)
**License URL**: https://creativecommons.org/licenses/by/3.0/

---

## How to Add Attribution

When downloading a new icon from game-icons.net:
1. Note the icon's title (shown on the icon page)
2. Note the author name (shown below the icon)
3. Note the author's profile URL if available
4. Add a row to the appropriate table below

---

## Status Effect Icons

| Filename | Icon Title | Author | Author URL | License |
|----------|------------|--------|------------|---------|
"""

	# Add status icons
	for target_id in TARGETS:
		var target = TARGETS[target_id]
		if target["category"] != "status":
			continue
		var result = _results.get(target_id, {})
		if result.get("success", false):
			var sel = result["selected"]
			var author_url = _get_author_url(sel["author"])
			content += "| `icon_status_%s.png` | %s | %s | %s | CC BY 3.0 |\n" % [
				target_id, sel["name"].replace("-", " ").capitalize(),
				sel["author"].capitalize(), author_url
			]

	content += """
---

## Buff Icons

| Filename | Icon Title | Author | Author URL | License |
|----------|------------|--------|------------|---------|
"""

	# Add buff icons
	for target_id in TARGETS:
		var target = TARGETS[target_id]
		if target["category"] != "buff":
			continue
		var result = _results.get(target_id, {})
		if result.get("success", false):
			var sel = result["selected"]
			var author_url = _get_author_url(sel["author"])
			content += "| `icon_buff_%s.png` | %s | %s | %s | CC BY 3.0 |\n" % [
				target_id, sel["name"].replace("-", " ").capitalize(),
				sel["author"].capitalize(), author_url
			]

	content += """
---

## Attribution Format for Credits

When displaying credits in-game or in documentation, use:

> Status and buff icons from game-icons.net (CC BY 3.0):
"""

	# Group by author
	var by_author: Dictionary = {}
	for target_id in _results:
		var result = _results[target_id]
		if result.get("success", false):
			var author = result["selected"]["author"]
			if not by_author.has(author):
				by_author[author] = []
			by_author[author].append(result["selected"]["name"].replace("-", " ").capitalize())

	for author in by_author:
		var icons = by_author[author]
		content += "> - \"%s\" by %s\n" % ["\", \"".join(icons), author.capitalize()]

	content += """
---

## Notes

- All icons converted from SVG to 32x32 PNG with transparent background
- Original SVGs stored externally (see Docs/Icons/GAME_ICONS_LIBRARY_LOCATION.md)
- The license requires attribution - do not skip this step
- Generated by: DevTools/gameicons_apply_batch.gd
"""

	# Write file
	var file = FileAccess.open(global_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("[OK] Attribution file updated: %s" % path)
	else:
		print("[WARN] Could not write attribution file")


func _get_author_url(author: String) -> String:
	match author.to_lower():
		"delapouite":
			return "https://delapouite.com"
		"lorc":
			return "http://lorcblog.blogspot.com"
		"sbed":
			return "http://opengameart.org/content/95-game-icons"
		"carl-olsen":
			return "https://twitter.com/unstoppableCarl"
		_:
			return "https://game-icons.net"


func _write_mapping_report() -> void:
	var path = "res://Docs/Icons/STATUS_ICON_MAPPING.md"
	var global_path = ProjectSettings.globalize_path(path)

	var content = """# Status & Buff Icon Mapping

This document shows which game-icons.net SVGs were selected for each icon target.

**Generated by**: `DevTools/gameicons_apply_batch.gd`
**Library**: External (see `GAME_ICONS_LIBRARY_LOCATION.md`)

---

## Status Icons

"""

	# Status icons section
	for target_id in TARGETS:
		var target = TARGETS[target_id]
		if target["category"] != "status":
			continue
		content += _format_mapping_entry(target_id, target)

	content += """
---

## Buff Icons

"""

	# Buff icons section
	for target_id in TARGETS:
		var target = TARGETS[target_id]
		if target["category"] != "buff":
			continue
		content += _format_mapping_entry(target_id, target)

	content += """
---

## Notes

- Icons selected by keyword scoring algorithm
- Preference given to simpler icons from established authors (Lorc, Delapouite)
- To override a selection, manually run `convert_icons.gd` with custom SELECTIONS
"""

	# Write file
	var file = FileAccess.open(global_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("[OK] Mapping report updated: %s" % path)
	else:
		print("[WARN] Could not write mapping report")


func _format_mapping_entry(target_id: String, target: Dictionary) -> String:
	var result = _results.get(target_id, {})
	var text = "### %s\n\n" % target_id

	if result.get("success", false):
		var sel = result["selected"]
		text += "- **Selected**: `%s` (score: %d)\n" % [sel["name"], sel.get("score", 0)]
		text += "- **Author**: %s\n" % sel["author"]
		text += "- **Dest**: `%s`\n" % target["dest"]
		text += "- **Keywords**: %s\n" % ", ".join(target["keywords"])

		if result["alternates"].size() > 0:
			text += "- **Alternates**:\n"
			for i in range(result["alternates"].size()):
				var alt = result["alternates"][i]
				text += "  %d. `%s` (score: %d) by %s\n" % [i + 1, alt["name"], alt.get("score", 0), alt["author"]]
	else:
		text += "- **Status**: FAILED\n"
		text += "- **Error**: %s\n" % result.get("error", "Unknown")

	text += "\n"
	return text
