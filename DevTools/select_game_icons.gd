## select_game_icons.gd
## Scans game-icons.net SVG bundle and selects best matches for each target icon.
## Run with: godot --headless --script res://DevTools/select_game_icons.gd --quit
extends SceneTree

# Target definitions: id -> keyword list
const TARGETS = {
	"stunned": ["stun", "stunned", "daze", "dizzy", "stars", "impact", "hammer", "knockout", "ko", "unconscious"],
	"poisoned": ["poison", "toxic", "venom", "skull", "biohazard", "flask", "droplet", "potion", "death-juice"],
	"bleeding": ["bleed", "bleeding", "blood", "drop", "wound", "cut", "bandage", "dripping"],
	"doom": ["doom", "curse", "skull", "omen", "hex", "death", "reaper", "hourglass", "timer"],
	"burn": ["burn", "fire", "flame", "heat", "ember", "inferno", "blaze", "hot"],
	"shadowstep": ["shadow", "stealth", "cloak", "ninja", "footprint", "dash", "step", "hood", "rogue"],
	"barkskin_blessing": ["bark", "tree", "leaf", "wood", "shield", "armor", "oak", "nature", "shell"],
	"fortify": ["fortify", "shield", "tower", "wall", "castle", "defense", "guard", "protect", "bulwark"]
}

# Complexity penalty words
const COMPLEX_WORDS = ["detailed", "scene", "full", "body", "person", "human", "portrait"]

# External library location (moved outside res:// to prevent Godot import bloat)
# See Docs/Icons/GAME_ICONS_LIBRARY_LOCATION.md for details
const DEFAULT_BASE_PATH = "C:/Users/rober/OneDrive/ShopKeepers External/GameIcons/extracted/icons/ffffff/000000/1x1"

var _svg_index: Array = []  # Array of {path, name, author, keywords}
var _author_counts: Dictionary = {}  # author -> count in top results

func _init() -> void:
	print("[IconSelector] Starting icon selection...")

	# Check for environment variable override
	var env_path = OS.get_environment("GAMEICONS_DIR")
	var base_path: String
	if env_path != "":
		base_path = env_path + "/icons/ffffff/000000/1x1"
		print("[IconSelector] Using GAMEICONS_DIR: %s" % env_path)
	else:
		base_path = DEFAULT_BASE_PATH

	# Build index
	_build_svg_index(base_path)
	print("[IconSelector] Indexed %d SVG files" % _svg_index.size())

	# Select best matches
	var selections: Dictionary = {}
	var alternates: Dictionary = {}

	for target_id in TARGETS:
		var keywords = TARGETS[target_id]
		var result = _select_best_icon(target_id, keywords)
		selections[target_id] = result["best"]
		alternates[target_id] = result["alternates"]

	# Print selection report
	_print_selection_report(selections, alternates)

	quit()


func _build_svg_index(base_path: String) -> void:
	var dir = DirAccess.open(base_path)
	if dir == null:
		print("[IconSelector] ERROR: Cannot open base path: %s" % base_path)
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
	# Split by dash, underscore, space
	var parts = name.replace("-", " ").replace("_", " ").split(" ")
	var keywords: Array = []
	for part in parts:
		var clean = part.strip_edges().to_lower()
		if clean.length() > 1:
			keywords.append(clean)
	return keywords


func _select_best_icon(target_id: String, search_keywords: Array) -> Dictionary:
	var scores: Array = []  # Array of {entry, score}

	for entry in _svg_index:
		var score = _score_entry(entry, search_keywords)
		if score > 0:
			scores.append({"entry": entry, "score": score})

	# Sort by score descending
	scores.sort_custom(func(a, b): return a["score"] > b["score"])

	# Get top 6 (best + 5 alternates)
	var best = null
	var alternates: Array = []

	for i in range(mini(6, scores.size())):
		if i == 0:
			best = scores[i]
		else:
			alternates.append(scores[i])

	return {"best": best, "alternates": alternates}


func _score_entry(entry: Dictionary, search_keywords: Array) -> int:
	var score = 0
	var icon_name = entry["name"].to_lower()
	var icon_keywords = entry["keywords"]

	# Keyword matching
	for kw in search_keywords:
		# Exact word match in icon name
		if kw in icon_keywords:
			score += 10
		# Partial match (keyword contained in icon name)
		elif icon_name.contains(kw):
			score += 5
		# Icon keyword contains search keyword
		else:
			for ik in icon_keywords:
				if ik.contains(kw) or kw.contains(ik):
					score += 2
					break

	# Simplicity bonus: shorter names tend to be simpler icons
	if icon_name.length() < 15:
		score += 3
	elif icon_name.length() > 25:
		score -= 2

	# Complexity penalty
	for cw in COMPLEX_WORDS:
		if icon_name.contains(cw):
			score -= 5

	# Author consistency bonus (prefer lorc and delapouite - large consistent sets)
	if entry["author"] in ["lorc", "delapouite"]:
		score += 2

	return score


func _print_selection_report(selections: Dictionary, alternates: Dictionary) -> void:
	print("\n" + "=".repeat(70))
	print("  ICON SELECTION REPORT")
	print("=".repeat(70))

	for target_id in TARGETS:
		var best = selections[target_id]
		var alts = alternates[target_id]

		print("\n--- %s ---" % target_id.to_upper())
		if best != null:
			print("  SELECTED: %s (score: %d)" % [best["entry"]["name"], best["score"]])
			print("    Path: %s" % best["entry"]["path"])
			print("    Author: %s" % best["entry"]["author"])
		else:
			print("  SELECTED: NONE (no matches)")

		if alts.size() > 0:
			print("  ALTERNATES:")
			for i in range(alts.size()):
				var alt = alts[i]
				print("    %d. %s (score: %d) by %s" % [
					i + 1, alt["entry"]["name"], alt["score"], alt["entry"]["author"]
				])

	print("\n" + "=".repeat(70))
