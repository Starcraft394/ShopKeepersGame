## gameicons_search.gd
## Search tool to find matching icons in the game-icons.net library.
## Run with: godot --headless --script res://DevTools/gameicons_search.gd -- "query" --quit
## Example: godot --headless --script res://DevTools/gameicons_search.gd -- "fire flame burn" --quit
extends SceneTree

const COMPLEX_WORDS = ["detailed", "scene", "full", "body", "person", "human", "portrait"]
const PREFERRED_AUTHORS = ["lorc", "delapouite", "carl-olsen", "sbed"]

var _svg_index: Array = []


func _init() -> void:
	print("=" .repeat(60))
	print("  GAME-ICONS SEARCH TOOL")
	print("=" .repeat(60))

	# Get query from command line args
	var args = OS.get_cmdline_user_args()
	var query = ""

	if args.size() > 0:
		query = " ".join(args)
	else:
		# Try regular args (after --)
		var all_args = OS.get_cmdline_args()
		for i in range(all_args.size()):
			if all_args[i] == "--" and i + 1 < all_args.size():
				query = all_args[i + 1]
				break

	if query == "":
		print("\n[ERROR] No search query provided.")
		print("[USAGE] godot --headless --script res://DevTools/gameicons_search.gd -- \"fire flame burn\" --quit")
		quit(1)
		return

	print("\n[Query] \"%s\"" % query)

	# Validate library
	var lib_root = OS.get_environment("GAMEICONS_DIR")
	if lib_root == "":
		print("\n[ERROR] GAMEICONS_DIR environment variable not set.")
		quit(1)
		return

	var icons_path = lib_root + "/extracted/icons/ffffff/000000/1x1"
	if not DirAccess.dir_exists_absolute(icons_path):
		print("\n[ERROR] Icons path not found: %s" % icons_path)
		quit(1)
		return

	# Build index
	print("[Index] Scanning SVG library...")
	_build_svg_index(icons_path)
	print("[Index] Found %d SVG files" % _svg_index.size())

	# Parse query into keywords
	var keywords = _parse_query(query)
	print("[Keywords] %s" % str(keywords))

	# Score and rank
	var scores: Array = []
	for entry in _svg_index:
		var score = _score_entry(entry, keywords)
		if score > 0:
			scores.append({"entry": entry, "score": score})

	scores.sort_custom(func(a, b): return a["score"] > b["score"])

	# Print results
	print("\n" + "-" .repeat(60))
	print("  TOP 15 MATCHES")
	print("-" .repeat(60))

	var count = mini(15, scores.size())
	if count == 0:
		print("  No matches found.")
	else:
		for i in range(count):
			var item = scores[i]
			var entry = item["entry"]
			print("%2d. [%3d] %-30s by %-12s" % [
				i + 1,
				item["score"],
				entry["name"],
				entry["author"]
			])
			print("         %s" % entry["path"])

	print("-" .repeat(60))
	print("Total matches: %d" % scores.size())
	quit(0)


func _parse_query(query: String) -> Array:
	var parts = query.replace("-", " ").replace("_", " ").replace(",", " ").split(" ")
	var keywords: Array = []
	for part in parts:
		var clean = part.strip_edges().to_lower()
		if clean.length() > 1:
			keywords.append(clean)
	return keywords


func _build_svg_index(base_path: String) -> void:
	var dir = DirAccess.open(base_path)
	if dir == null:
		return

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


func _score_entry(entry: Dictionary, search_keywords: Array) -> int:
	var score = 0
	var icon_name = entry["name"].to_lower()
	var icon_keywords = entry["keywords"]

	for kw in search_keywords:
		if kw in icon_keywords:
			score += 10
		elif icon_name.contains(kw):
			score += 5
		else:
			for ik in icon_keywords:
				if ik.contains(kw) or kw.contains(ik):
					score += 2
					break

	if icon_name.length() < 15:
		score += 3
	elif icon_name.length() > 25:
		score -= 2

	for cw in COMPLEX_WORDS:
		if icon_name.contains(cw):
			score -= 5

	if entry["author"] in PREFERRED_AUTHORS:
		score += 2

	return score
