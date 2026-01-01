## DataRegistry.gd
## Autoload singleton that loads and caches all static data tables.
## This is the SINGLE SOURCE OF TRUTH for game data lookups.
##
## Source: MVP_Scope.md, MVP_Milestones.md (M0), GDD Section 14
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal data_loaded()
signal data_load_failed(error: String)

# ============================================================================
# DATA CACHES (Private)
# ============================================================================

var _classes: Dictionary = {}          # id -> ClassData
var _races: Dictionary = {}            # id -> RaceData
var _item_templates: Dictionary = {}   # id -> ItemTemplate
var _abilities: Dictionary = {}        # id -> AbilityData
var _passives: Dictionary = {}         # id -> PassiveData (M4)
var _status_effects: Dictionary = {}   # id -> StatusEffectData
var _monsters: Dictionary = {}         # id -> MonsterData
var _regions: Dictionary = {}          # id -> RegionData
var _facilities: Dictionary = {}       # id -> FacilityData

var _is_loaded: bool = false
var _load_errors: Array[String] = []

# ============================================================================
# CONFIGURATION
# ============================================================================

const DATA_BASE_PATH = "res://Data/"

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_all_data()


func _load_all_data() -> void:
	print("[DataRegistry] Loading all data...")
	_load_errors.clear()

	_load_folder("Classes", _classes, ClassData)
	_load_folder("Races", _races, RaceData)
	_load_folder("Items/Templates", _item_templates, ItemTemplate)
	_load_folder("Abilities", _abilities, AbilityData)
	_load_folder("Passives", _passives, PassiveData)  # M4
	_load_folder("StatusEffects", _status_effects, StatusEffectData)
	_load_folder("Monsters", _monsters, MonsterData)
	_load_folder("Regions", _regions, RegionData)
	_load_folder("Facilities", _facilities, FacilityData)

	_is_loaded = true

	if _load_errors.is_empty():
		print("[DataRegistry] All data loaded successfully!")
	else:
		push_warning("[DataRegistry] Data loaded with %d warnings" % _load_errors.size())
		for err in _load_errors:
			push_warning("  - " + err)

	_print_summary()
	data_loaded.emit()


func _load_folder(folder_name: String, cache: Dictionary, data_class: Variant) -> void:
	var folder_path = DATA_BASE_PATH + folder_name
	var dir = DirAccess.open(folder_path)

	if dir == null:
		var error = "Cannot open folder: " + folder_path
		_load_errors.append(error)
		push_warning("[DataRegistry] " + error)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = folder_path + "/" + file_name
			_load_json_file(file_path, cache, data_class, folder_name)
		file_name = dir.get_next()

	dir.list_dir_end()


func _load_json_file(file_path: String, cache: Dictionary, data_class: Variant, type_name: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error = "Cannot open file: " + file_path
		_load_errors.append(error)
		push_warning("[DataRegistry] " + error)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		var error = "JSON parse error in %s: %s" % [file_path, json.get_error_message()]
		_load_errors.append(error)
		push_warning("[DataRegistry] " + error)
		return

	var data = json.get_data()

	if data is Dictionary:
		_process_entry(data, cache, data_class, type_name, file_path)
	elif data is Array:
		for entry in data:
			if entry is Dictionary:
				_process_entry(entry, cache, data_class, type_name, file_path)


func _process_entry(data: Dictionary, cache: Dictionary, data_class: Variant, type_name: String, file_path: String) -> void:
	if not data.has("id"):
		var error = "Missing 'id' field in %s" % file_path
		_load_errors.append(error)
		push_warning("[DataRegistry] " + error)
		return

	var id = data["id"]
	var instance = data_class.from_dict(data)

	if instance.is_valid():
		cache[id] = instance
		print("[DataRegistry] Loaded %s: %s" % [type_name, id])
	else:
		var error = "Invalid data for '%s' in %s" % [id, file_path]
		_load_errors.append(error)
		push_warning("[DataRegistry] " + error)


# ============================================================================
# PUBLIC API - LOOKUPS
# ============================================================================

func get_class_data(id: String) -> ClassData:
	return _classes.get(id, null)


func get_race(id: String) -> RaceData:
	return _races.get(id, null)


func get_item_template(id: String) -> ItemTemplate:
	return _item_templates.get(id, null)


func get_ability(id: String) -> AbilityData:
	return _abilities.get(id, null)


func get_passive(id: String) -> PassiveData:
	return _passives.get(id, null)


func get_status_effect(id: String) -> StatusEffectData:
	return _status_effects.get(id, null)


func get_monster(id: String) -> MonsterData:
	return _monsters.get(id, null)


func get_region(id: String) -> RegionData:
	return _regions.get(id, null)


func get_facility(id: String) -> FacilityData:
	return _facilities.get(id, null)


# ============================================================================
# PUBLIC API - QUERIES
# ============================================================================

func get_all_classes() -> Array:
	return _classes.values()


func get_all_races() -> Array:
	return _races.values()


func get_all_item_templates() -> Array:
	return _item_templates.values()


func get_all_abilities() -> Array:
	return _abilities.values()


func get_all_passives() -> Array:
	return _passives.values()


func get_all_status_effects() -> Array:
	return _status_effects.values()


func get_all_monsters() -> Array:
	return _monsters.values()


func get_all_regions() -> Array:
	return _regions.values()


func get_all_facilities() -> Array:
	return _facilities.values()


func is_data_loaded() -> bool:
	return _is_loaded


## Get summary counts for all loaded data categories.
## Used by GameBoot for startup validation.
func get_summary_counts() -> Dictionary:
	return {
		"classes": _classes.size(),
		"races": _races.size(),
		"item_templates": _item_templates.size(),
		"abilities": _abilities.size(),
		"passives": _passives.size(),
		"status_effects": _status_effects.size(),
		"monsters": _monsters.size(),
		"regions": _regions.size(),
		"facilities": _facilities.size(),
		"total": _classes.size() + _races.size() + _item_templates.size() + _abilities.size() + _passives.size() + _status_effects.size() + _monsters.size() + _regions.size() + _facilities.size()
	}


## Get list of load errors (if any).
func get_load_errors() -> Array[String]:
	return _load_errors


# ============================================================================
# DEBUG & SMOKE TEST
# ============================================================================

func _print_summary() -> void:
	print("=== DataRegistry Summary ===")
	print("  Classes:        %d" % _classes.size())
	print("  Races:          %d" % _races.size())
	print("  Item Templates: %d" % _item_templates.size())
	print("  Abilities:      %d" % _abilities.size())
	print("  Passives:       %d" % _passives.size())
	print("  Status Effects: %d" % _status_effects.size())
	print("  Monsters:       %d" % _monsters.size())
	print("  Regions:        %d" % _regions.size())
	print("  Facilities:     %d" % _facilities.size())
	print("============================")


## Run smoke test to verify M0 requirements.
## Call via: DataRegistry.run_smoke_test()
func run_smoke_test() -> bool:
	print("\n========================================")
	print("    DataRegistry M0 SMOKE TEST")
	print("========================================\n")

	var passed = true
	var total_checks = 0
	var passed_checks = 0

	# Check data loaded
	total_checks += 1
	if _is_loaded:
		print("[PASS] Data loaded successfully")
		passed_checks += 1
	else:
		print("[FAIL] Data not loaded")
		passed = false

	# Print counts per category
	print("\n--- Data Counts ---")
	print("  Classes:        %d" % _classes.size())
	print("  Races:          %d" % _races.size())
	print("  Item Templates: %d" % _item_templates.size())
	print("  Abilities:      %d" % _abilities.size())
	print("  Passives:       %d" % _passives.size())
	print("  Status Effects: %d" % _status_effects.size())
	print("  Monsters:       %d" % _monsters.size())
	print("  Regions:        %d" % _regions.size())
	print("  Facilities:     %d" % _facilities.size())

	# Test required IDs from M0 spec
	print("\n--- Required ID Checks ---")

	var required_checks = [
		["Class", "defender", get_class_data("defender")],
		["Class", "striker", get_class_data("striker")],
		["Race", "human", get_race("human")],
		["ItemTemplate", "basic_sword", get_item_template("basic_sword")],
		["Ability", "basic_attack", get_ability("basic_attack")],
		["Ability", "def_shield_bash", get_ability("def_shield_bash")],
		["Ability", "str_precise_strike", get_ability("str_precise_strike")],
		["Passive", "def_iron_skin", get_passive("def_iron_skin")],
		["Passive", "str_killer_instinct", get_passive("str_killer_instinct")],
		["StatusEffect", "burn", get_status_effect("burn")],
		["StatusEffect", "stun", get_status_effect("stun")],
		["Monster", "goblin", get_monster("goblin")],
		["Region", "region_1", get_region("region_1")],
		["Facility", "blacksmith", get_facility("blacksmith")],
	]

	for check in required_checks:
		total_checks += 1
		var type_name = check[0]
		var id = check[1]
		var result = check[2]

		if result != null:
			print("[PASS] %s '%s' found" % [type_name, id])
			passed_checks += 1
		else:
			print("[FAIL] %s '%s' NOT FOUND" % [type_name, id])
			passed = false

	# Final result
	print("\n========================================")
	if passed:
		print("  SMOKE TEST PASSED (%d/%d checks)" % [passed_checks, total_checks])
	else:
		print("  SMOKE TEST FAILED (%d/%d checks)" % [passed_checks, total_checks])
	print("========================================\n")

	return passed
