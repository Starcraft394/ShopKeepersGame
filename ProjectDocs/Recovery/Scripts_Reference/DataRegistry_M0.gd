## DataRegistry.gd
## Autoload singleton that loads and caches all static data tables.
## This is the SINGLE SOURCE OF TRUTH for game data lookups.
##
## Source: GDD Sections 14, 32.1, 41.3, 41.4
## Per MODULE_OWNERSHIP_MAP.md: DataRegistry is read-only lookup only.
## It must NOT mutate Economy, Town, Combat, or any other module.
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal data_loaded()
signal data_load_failed(error: String)
signal validation_error(type: String, id: String, message: String)

# ============================================================================
# DATA CACHES (Private)
# ============================================================================

var _classes: Dictionary = {}  # class_id -> ClassData
var _races: Dictionary = {}  # race_id -> RaceData
var _item_templates: Dictionary = {}  # template_id -> ItemTemplate
var _passives: Dictionary = {}  # passive_id -> PassiveData
var _monsters: Dictionary = {}  # monster_id -> MonsterData
var _status_effects: Dictionary = {}  # effect_id -> StatusEffectData
var _abilities: Dictionary = {}  # ability_id -> AbilityData
var _regions: Dictionary = {}  # region_id -> RegionData
var _facilities: Dictionary = {}  # facility_id -> FacilityData

var _is_loaded: bool = false
var _load_errors: Array[String] = []

# ============================================================================
# CONFIGURATION
# ============================================================================

const DATA_BASE_PATH = "res://Data/"
const DEBUG_MODE = true  # Set to false for release builds

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_all_data()


## Reload all data from disk (dev mode only)
func reload_all_data() -> bool:
	if not DEBUG_MODE:
		push_warning("DataRegistry.reload_all_data() called in release mode - ignored")
		return false

	_clear_all_caches()
	_load_all_data()
	return _is_loaded


func _clear_all_caches() -> void:
	_classes.clear()
	_races.clear()
	_item_templates.clear()
	_passives.clear()
	_monsters.clear()
	_status_effects.clear()
	_abilities.clear()
	_regions.clear()
	_facilities.clear()
	_is_loaded = false
	_load_errors.clear()


func _load_all_data() -> void:
	print("[DataRegistry] Loading all data...")

	_load_classes()
	_load_races()
	_load_item_templates()
	_load_passives()
	_load_monsters()
	_load_status_effects()
	_load_abilities()
	_load_regions()
	_load_facilities()

	_is_loaded = _load_errors.is_empty()

	if _is_loaded:
		print("[DataRegistry] All data loaded successfully!")
		print_registry_summary()
		data_loaded.emit()
	else:
		var error_msg = "Data loading failed with %d errors" % _load_errors.size()
		push_error("[DataRegistry] " + error_msg)
		for err in _load_errors:
			push_error("  - " + err)
		data_load_failed.emit(error_msg)

# ============================================================================
# DATA LOADING (Private)
# ============================================================================

func _load_classes() -> void:
	_load_data_folder("Classes", _classes, func(data): return ClassData.from_dict(data), "class_id")


func _load_races() -> void:
	_load_data_folder("Races", _races, func(data): return RaceData.from_dict(data), "race_id")


func _load_item_templates() -> void:
	_load_data_folder("Items/Templates", _item_templates, func(data): return ItemTemplate.from_dict(data), "template_id")


func _load_passives() -> void:
	_load_data_folder("Passives", _passives, func(data): return PassiveData.from_dict(data), "passive_id")


func _load_monsters() -> void:
	_load_data_folder("Monsters", _monsters, func(data): return MonsterData.from_dict(data), "monster_id")


func _load_status_effects() -> void:
	_load_data_folder("StatusEffects", _status_effects, func(data): return StatusEffectData.from_dict(data), "effect_id")


func _load_abilities() -> void:
	_load_data_folder("Abilities", _abilities, func(data): return AbilityData.from_dict(data), "ability_id")


func _load_regions() -> void:
	_load_data_folder("Regions", _regions, func(data): return RegionData.from_dict(data), "region_id")


func _load_facilities() -> void:
	_load_data_folder("Facilities", _facilities, func(data): return FacilityData.from_dict(data), "facility_id")


## Generic data folder loader
func _load_data_folder(folder_name: String, cache: Dictionary, factory: Callable, id_field: String) -> void:
	var folder_path = DATA_BASE_PATH + folder_name
	var dir = DirAccess.open(folder_path)

	if dir == null:
		var error = "Cannot open data folder: " + folder_path
		_load_errors.append(error)
		if DEBUG_MODE:
			push_warning("[DataRegistry] " + error)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path = folder_path + "/" + file_name
			_load_json_file(file_path, cache, factory, id_field, folder_name)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single JSON file into the cache
func _load_json_file(file_path: String, cache: Dictionary, factory: Callable, id_field: String, type_name: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error = "Cannot open file: " + file_path
		_load_errors.append(error)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		var error = "JSON parse error in %s: %s" % [file_path, json.get_error_message()]
		_load_errors.append(error)
		validation_error.emit(type_name, file_path, error)
		return

	var data = json.get_data()

	if data is Dictionary:
		_process_data_entry(data, cache, factory, id_field, type_name, file_path)
	elif data is Array:
		for entry in data:
			if entry is Dictionary:
				_process_data_entry(entry, cache, factory, id_field, type_name, file_path)


func _process_data_entry(data: Dictionary, cache: Dictionary, factory: Callable, id_field: String, type_name: String, file_path: String) -> void:
	if not data.has(id_field):
		var error = "Missing '%s' in %s" % [id_field, file_path]
		_load_errors.append(error)
		validation_error.emit(type_name, file_path, error)
		return

	var id = data[id_field]
	var instance = factory.call(data)

	if instance.is_valid():
		cache[id] = instance
	else:
		var error = "Invalid data for '%s' in %s" % [id, file_path]
		_load_errors.append(error)
		validation_error.emit(type_name, id, error)

# ============================================================================
# CLASS LOOKUPS
# ============================================================================

func get_class_data(class_id: String) -> ClassData:
	return _classes.get(class_id, null)


func get_all_classes() -> Array[ClassData]:
	var result: Array[ClassData] = []
	for data in _classes.values():
		result.append(data)
	return result


func class_exists(class_id: String) -> bool:
	return _classes.has(class_id)

# ============================================================================
# RACE LOOKUPS
# ============================================================================

func get_race_data(race_id: String) -> RaceData:
	return _races.get(race_id, null)


func get_all_races() -> Array[RaceData]:
	var result: Array[RaceData] = []
	for data in _races.values():
		result.append(data)
	return result


func race_exists(race_id: String) -> bool:
	return _races.has(race_id)

# ============================================================================
# ITEM TEMPLATE LOOKUPS
# ============================================================================

func get_item_template(template_id: String) -> ItemTemplate:
	return _item_templates.get(template_id, null)


func get_all_item_templates() -> Array[ItemTemplate]:
	var result: Array[ItemTemplate] = []
	for data in _item_templates.values():
		result.append(data)
	return result


func get_templates_by_type(item_type: String) -> Array[ItemTemplate]:
	var result: Array[ItemTemplate] = []
	for template in _item_templates.values():
		if template.item_type == item_type:
			result.append(template)
	return result


func get_templates_by_tier(tier: int) -> Array[ItemTemplate]:
	var result: Array[ItemTemplate] = []
	for template in _item_templates.values():
		if template.tier == tier:
			result.append(template)
	return result


func template_exists(template_id: String) -> bool:
	return _item_templates.has(template_id)

# ============================================================================
# PASSIVE LOOKUPS
# ============================================================================

func get_passive(passive_id: String) -> PassiveData:
	return _passives.get(passive_id, null)


func get_all_passives() -> Array[PassiveData]:
	var result: Array[PassiveData] = []
	for data in _passives.values():
		result.append(data)
	return result


func get_passives_by_category(category: String) -> Array[PassiveData]:
	var result: Array[PassiveData] = []
	for passive in _passives.values():
		if passive.category == category:
			result.append(passive)
	return result


func passive_exists(passive_id: String) -> bool:
	return _passives.has(passive_id)

# ============================================================================
# MONSTER LOOKUPS
# ============================================================================

func get_monster(monster_id: String) -> MonsterData:
	return _monsters.get(monster_id, null)


func get_all_monsters() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for data in _monsters.values():
		result.append(data)
	return result


func get_monsters_by_region(region_id: String) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for monster in _monsters.values():
		if monster.region_id == region_id:
			result.append(monster)
	return result


func get_monsters_by_family(family: String) -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for monster in _monsters.values():
		if monster.family == family:
			result.append(monster)
	return result


func monster_exists(monster_id: String) -> bool:
	return _monsters.has(monster_id)

# ============================================================================
# STATUS EFFECT LOOKUPS (Registry-First Enforcement per GDD 41.7)
# ============================================================================

func get_status_effect(effect_id: String) -> StatusEffectData:
	return _status_effects.get(effect_id, null)


func get_all_status_effects() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for data in _status_effects.values():
		result.append(data)
	return result


func status_effect_exists(effect_id: String) -> bool:
	return _status_effects.has(effect_id)


## Validate that a status effect exists in the registry.
## Per GDD 41.7: No status may be applied unless it exists here.
## Returns false + logs warning if invalid.
func validate_status_effect(effect_id: String) -> bool:
	if status_effect_exists(effect_id):
		return true

	var warning = "Status effect '%s' not found in registry (GDD 41.7 violation)" % effect_id
	if DEBUG_MODE:
		push_error("[DataRegistry] " + warning)
	else:
		push_warning("[DataRegistry] " + warning)

	return false

# ============================================================================
# ABILITY LOOKUPS
# ============================================================================

func get_ability(ability_id: String) -> AbilityData:
	return _abilities.get(ability_id, null)


func get_all_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for data in _abilities.values():
		result.append(data)
	return result


func get_abilities_by_class(class_id: String) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability in _abilities.values():
		if ability.source_class_id == class_id:
			result.append(ability)
	return result


func ability_exists(ability_id: String) -> bool:
	return _abilities.has(ability_id)

# ============================================================================
# REGION LOOKUPS
# ============================================================================

func get_region(region_id: String) -> RegionData:
	return _regions.get(region_id, null)


func get_all_regions() -> Array[RegionData]:
	var result: Array[RegionData] = []
	for data in _regions.values():
		result.append(data)
	return result


func region_exists(region_id: String) -> bool:
	return _regions.has(region_id)

# ============================================================================
# FACILITY LOOKUPS
# ============================================================================

func get_facility(facility_id: String) -> FacilityData:
	return _facilities.get(facility_id, null)


func get_all_facilities() -> Array[FacilityData]:
	var result: Array[FacilityData] = []
	for data in _facilities.values():
		result.append(data)
	return result


func facility_exists(facility_id: String) -> bool:
	return _facilities.has(facility_id)

# ============================================================================
# UTILITY & DEBUG
# ============================================================================

func is_data_loaded() -> bool:
	return _is_loaded


func get_load_stats() -> Dictionary:
	return {
		"classes": _classes.size(),
		"races": _races.size(),
		"item_templates": _item_templates.size(),
		"passives": _passives.size(),
		"monsters": _monsters.size(),
		"status_effects": _status_effects.size(),
		"abilities": _abilities.size(),
		"regions": _regions.size(),
		"facilities": _facilities.size(),
		"errors": _load_errors.size()
	}


func print_registry_summary() -> void:
	var stats = get_load_stats()
	print("=== DataRegistry Summary ===")
	print("  Classes:        %d" % stats.classes)
	print("  Races:          %d" % stats.races)
	print("  Item Templates: %d" % stats.item_templates)
	print("  Passives:       %d" % stats.passives)
	print("  Monsters:       %d" % stats.monsters)
	print("  Status Effects: %d" % stats.status_effects)
	print("  Abilities:      %d" % stats.abilities)
	print("  Regions:        %d" % stats.regions)
	print("  Facilities:     %d" % stats.facilities)
	print("  Load Errors:    %d" % stats.errors)
	print("============================")


## Quick smoke test to verify DataRegistry is working.
## Call from console or test scene to verify loading.
func run_smoke_test() -> bool:
	print("\n=== DataRegistry Smoke Test ===")
	var passed = true

	# Check data loaded
	if not _is_loaded:
		print("  FAIL: Data not loaded")
		return false
	print("  PASS: Data loaded successfully")

	# Check minimum viable data set
	var checks = [
		["warrior", class_exists("warrior"), "Class 'warrior'"],
		["human", race_exists("human"), "Race 'human'"],
		["basic_sword", template_exists("basic_sword"), "Item template 'basic_sword'"],
		["goblin", monster_exists("goblin"), "Monster 'goblin'"],
		["burn", status_effect_exists("burn"), "Status effect 'burn'"],
		["stun", status_effect_exists("stun"), "Status effect 'stun'"],
		["basic_attack", ability_exists("basic_attack"), "Ability 'basic_attack'"],
		["region_1", region_exists("region_1"), "Region 'region_1'"],
		["blacksmith", facility_exists("blacksmith"), "Facility 'blacksmith'"],
	]

	for check in checks:
		if check[1]:
			print("  PASS: %s exists" % check[2])
		else:
			print("  FAIL: %s NOT FOUND" % check[2])
			passed = false

	# Cross-reference validation
	var xref_errors = validate_all_data()
	if xref_errors.is_empty():
		print("  PASS: All cross-references valid")
	else:
		print("  FAIL: %d cross-reference errors" % xref_errors.size())
		passed = false

	print("=== Smoke Test %s ===" % ("PASSED" if passed else "FAILED"))
	return passed


func validate_all_data() -> Array[String]:
	var errors: Array[String] = []

	# Validate class ability references
	for class_data in _classes.values():
		if class_data.ability_a_id != "" and not ability_exists(class_data.ability_a_id):
			errors.append("Class '%s' references missing ability '%s'" % [class_data.class_id, class_data.ability_a_id])
		if class_data.ability_b_id != "" and not ability_exists(class_data.ability_b_id):
			errors.append("Class '%s' references missing ability '%s'" % [class_data.class_id, class_data.ability_b_id])
		if class_data.passive_a_id != "" and not passive_exists(class_data.passive_a_id):
			errors.append("Class '%s' references missing passive '%s'" % [class_data.class_id, class_data.passive_a_id])
		if class_data.passive_b_id != "" and not passive_exists(class_data.passive_b_id):
			errors.append("Class '%s' references missing passive '%s'" % [class_data.class_id, class_data.passive_b_id])

	# Validate monster ability references
	for monster in _monsters.values():
		for ability_id in monster.ability_ids:
			if not ability_exists(ability_id):
				errors.append("Monster '%s' references missing ability '%s'" % [monster.monster_id, ability_id])

	# Validate region boss references
	for region in _regions.values():
		if region.boss_id != "" and not monster_exists(region.boss_id):
			errors.append("Region '%s' references missing boss '%s'" % [region.region_id, region.boss_id])

	if errors.is_empty():
		print("[DataRegistry] All cross-references valid!")
	else:
		for err in errors:
			push_warning("[DataRegistry] " + err)

	return errors
