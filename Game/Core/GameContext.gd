## GameContext.gd
## Autoload singleton that holds the authoritative game state.
## This is the central coordinator for game phase and location tracking.
##
## Source: MVP_Scope.md, MVP_Milestones.md (M0), Tier 0.3 + 0.4
extends Node

# ============================================================================
# ENUMS
# ============================================================================

enum GamePhase {
	BOOT,
	TOWN,
	DUNGEON_SELECT,
	COMBAT,
	REWARDS,
	RETURN_TO_TOWN
}

# ============================================================================
# SIGNALS
# ============================================================================

signal phase_changed(old_phase: GamePhase, new_phase: GamePhase)
signal location_changed(region_id: String, town_id: String)
signal party_changed(hero_ids: Array)
signal floor_selected(floor_index: int)
signal run_started(run_id: String, run_seed: int)
signal run_ended(run_id: String)

# ============================================================================
# STATE (Private - access via API)
# ============================================================================

var _current_phase: GamePhase = GamePhase.BOOT
var _current_region_id: String = ""
var _current_town_id: String = ""
var _selected_floor_index: int = 1
var _party_hero_ids: Array[String] = []

# Run tracking (integrated with SeededRNG - Tier 0.4)
var _run_id: String = ""
var _run_seed: int = 0
var _run_active: bool = false
var _run_counter: int = 0  # Incremented each run for unique IDs

var _initialized: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[GameContext] Initializing...")

	# Wait for DataRegistry to be ready
	if not DataRegistry.is_data_loaded():
		await DataRegistry.data_loaded

	_initialize_default_state()
	_initialized = true
	print("[GameContext] Initialization complete. Phase: %s" % _phase_to_string(_current_phase))


func _initialize_default_state() -> void:
	# Set initial state per MVP scope
	_current_phase = GamePhase.TOWN
	_current_region_id = "region_1"
	_current_town_id = "greenroot_village"  # Placeholder - town data not yet defined
	_selected_floor_index = 1
	_party_hero_ids = []
	_run_id = ""
	_run_seed = 0
	_run_active = false


# ============================================================================
# PUBLIC API - PHASE MANAGEMENT
# ============================================================================

func get_phase() -> GamePhase:
	return _current_phase


func get_phase_name() -> String:
	return _phase_to_string(_current_phase)


func set_phase(new_phase: GamePhase) -> bool:
	if new_phase == _current_phase:
		return true

	var old_phase = _current_phase
	_current_phase = new_phase

	print("[GameContext] Phase: %s -> %s" % [_phase_to_string(old_phase), _phase_to_string(new_phase)])
	phase_changed.emit(old_phase, new_phase)
	return true


func is_phase(phase: GamePhase) -> bool:
	return _current_phase == phase


# ============================================================================
# PUBLIC API - LOCATION MANAGEMENT
# ============================================================================

func get_location() -> Dictionary:
	return {
		"region_id": _current_region_id,
		"town_id": _current_town_id
	}


func get_current_region_id() -> String:
	return _current_region_id


func get_current_town_id() -> String:
	return _current_town_id


func set_location(region_id: String, town_id: String) -> bool:
	# Validate region if DataRegistry has region data
	if region_id != "" and DataRegistry.get_region(region_id) == null:
		push_warning("[GameContext] Region '%s' not found in DataRegistry. Allowing placeholder." % region_id)

	# Town validation not yet implemented (town data structure pending)
	if town_id != "":
		print("[GameContext] Town '%s' set (town data validation not yet implemented)" % town_id)

	var changed = (_current_region_id != region_id or _current_town_id != town_id)
	_current_region_id = region_id
	_current_town_id = town_id

	if changed:
		print("[GameContext] Location: region='%s', town='%s'" % [region_id, town_id])
		location_changed.emit(region_id, town_id)

	return true


# ============================================================================
# PUBLIC API - FLOOR SELECTION
# ============================================================================

func get_selected_floor() -> int:
	return _selected_floor_index


func set_selected_floor(floor_index: int) -> bool:
	if floor_index < 1:
		push_warning("[GameContext] Invalid floor index: %d (must be >= 1)" % floor_index)
		return false

	# MVP only has Floor 1, but allow setting for future expansion
	if floor_index > 1:
		print("[GameContext] Floor %d selected (MVP only supports Floor 1)" % floor_index)

	_selected_floor_index = floor_index
	floor_selected.emit(floor_index)
	return true


# ============================================================================
# PUBLIC API - PARTY MANAGEMENT
# ============================================================================

func get_party() -> Array[String]:
	return _party_hero_ids.duplicate()


func set_party(hero_ids: Array) -> bool:
	_party_hero_ids.clear()
	for id in hero_ids:
		_party_hero_ids.append(str(id))

	print("[GameContext] Party set: %s" % str(_party_hero_ids))
	party_changed.emit(_party_hero_ids)
	return true


func add_hero_to_party(hero_id: String) -> bool:
	if hero_id in _party_hero_ids:
		push_warning("[GameContext] Hero '%s' already in party" % hero_id)
		return false

	# MVP party size is 3
	if _party_hero_ids.size() >= 3:
		push_warning("[GameContext] Party full (max 3 heroes)")
		return false

	_party_hero_ids.append(hero_id)
	party_changed.emit(_party_hero_ids)
	return true


func remove_hero_from_party(hero_id: String) -> bool:
	var index = _party_hero_ids.find(hero_id)
	if index == -1:
		push_warning("[GameContext] Hero '%s' not in party" % hero_id)
		return false

	_party_hero_ids.remove_at(index)
	party_changed.emit(_party_hero_ids)
	return true


func get_party_size() -> int:
	return _party_hero_ids.size()


# ============================================================================
# PUBLIC API - RUN MANAGEMENT (Tier 0.4 Integration)
# ============================================================================

## Start a new run with optional seed.
## If seed is -1, generates a random seed from system time.
## Once started, the seed is deterministic for the entire run.
func start_new_run(optional_seed: int = -1) -> void:
	# End any existing run
	if _run_active:
		end_run()

	# Generate or use provided seed
	if optional_seed == -1:
		_run_seed = SeededRNG.generate_random_seed()
	else:
		_run_seed = optional_seed

	# Generate unique run ID
	_run_counter += 1
	_run_id = "run_%d_%d" % [int(Time.get_unix_time_from_system()), _run_counter]

	_run_active = true

	print("[GameContext] Run started: id='%s', seed=%d" % [_run_id, _run_seed])
	run_started.emit(_run_id, _run_seed)


## End the current run.
func end_run() -> void:
	if not _run_active:
		return

	var ended_run_id = _run_id
	_run_active = false
	_run_id = ""
	_run_seed = 0

	print("[GameContext] Run ended: id='%s'" % ended_run_id)
	run_ended.emit(ended_run_id)


## Check if a run is currently active.
func is_run_active() -> bool:
	return _run_active


## Get the current run ID.
func get_run_id() -> String:
	return _run_id


## Get the current run seed.
func get_run_seed() -> int:
	return _run_seed


## Legacy method for compatibility - use start_new_run() instead.
func set_run_info(run_id: String, seed_val: int) -> void:
	_run_id = run_id
	_run_seed = seed_val
	_run_active = true
	print("[GameContext] Run info set (legacy): id='%s', seed=%d" % [run_id, seed_val])


## Legacy method for compatibility - use end_run() instead.
func clear_run_info() -> void:
	end_run()


# ============================================================================
# PUBLIC API - QUERIES
# ============================================================================

func is_initialized() -> bool:
	return _initialized


func get_state_summary() -> Dictionary:
	return {
		"phase": _phase_to_string(_current_phase),
		"region_id": _current_region_id,
		"town_id": _current_town_id,
		"selected_floor": _selected_floor_index,
		"party_size": _party_hero_ids.size(),
		"party_hero_ids": _party_hero_ids.duplicate(),
		"run_id": _run_id,
		"run_seed": _run_seed,
		"run_active": _run_active,
		"initialized": _initialized
	}


# ============================================================================
# DEBUG & SMOKE TEST
# ============================================================================

func _phase_to_string(phase: GamePhase) -> String:
	match phase:
		GamePhase.BOOT: return "BOOT"
		GamePhase.TOWN: return "TOWN"
		GamePhase.DUNGEON_SELECT: return "DUNGEON_SELECT"
		GamePhase.COMBAT: return "COMBAT"
		GamePhase.REWARDS: return "REWARDS"
		GamePhase.RETURN_TO_TOWN: return "RETURN_TO_TOWN"
		_: return "UNKNOWN"


func print_state() -> void:
	var summary = get_state_summary()
	print("=== GameContext State ===")
	print("  Phase:          %s" % summary.phase)
	print("  Region:         %s" % summary.region_id)
	print("  Town:           %s" % summary.town_id)
	print("  Selected Floor: %d" % summary.selected_floor)
	print("  Party Size:     %d" % summary.party_size)
	print("  Party Heroes:   %s" % str(summary.party_hero_ids))
	print("  Run ID:         %s" % summary.run_id)
	print("  Run Seed:       %d" % summary.run_seed)
	print("  Run Active:     %s" % str(summary.run_active))
	print("  Initialized:    %s" % str(summary.initialized))
	print("=========================")


## Run smoke test to verify Tier 0.3 + 0.4 requirements.
## Call via: GameContext.run_smoke_test()
func run_smoke_test() -> bool:
	print("\n========================================")
	print("  GameContext Tier 0.3+0.4 SMOKE TEST")
	print("========================================\n")

	var passed = true
	var total_checks = 0
	var passed_checks = 0

	# Check 1: DataRegistry is present and loaded
	total_checks += 1
	if DataRegistry != null and DataRegistry.is_data_loaded():
		print("[PASS] DataRegistry present and loaded")
		passed_checks += 1
	else:
		print("[FAIL] DataRegistry not available or not loaded")
		passed = false

	# Check 2: GameContext initialized
	total_checks += 1
	if _initialized:
		print("[PASS] GameContext initialized")
		passed_checks += 1
	else:
		print("[FAIL] GameContext not initialized")
		passed = false

	# Check 3: Set location to region_1 + placeholder town
	total_checks += 1
	set_location("region_1", "greenroot_village")
	if _current_region_id == "region_1" and _current_town_id == "greenroot_village":
		print("[PASS] Location set: region_1 / greenroot_village")
		passed_checks += 1
	else:
		print("[FAIL] Location not set correctly")
		passed = false

	# Check 4: Set phase to TOWN
	total_checks += 1
	set_phase(GamePhase.TOWN)
	if _current_phase == GamePhase.TOWN:
		print("[PASS] Phase set: TOWN")
		passed_checks += 1
	else:
		print("[FAIL] Phase not set correctly")
		passed = false

	# Check 5: Set floor index to 1
	total_checks += 1
	set_selected_floor(1)
	if _selected_floor_index == 1:
		print("[PASS] Selected floor: 1")
		passed_checks += 1
	else:
		print("[FAIL] Floor index not set correctly")
		passed = false

	# Check 6: Party management works
	total_checks += 1
	set_party(["hero_1", "hero_2", "hero_3"])
	if _party_hero_ids.size() == 3:
		print("[PASS] Party set: 3 heroes")
		passed_checks += 1
	else:
		print("[FAIL] Party not set correctly")
		passed = false

	# Check 7: Start new run with fixed seed (Tier 0.4)
	total_checks += 1
	start_new_run(12345)
	if _run_active and _run_seed == 12345 and _run_id != "":
		print("[PASS] Run started: id='%s', seed=%d" % [_run_id, _run_seed])
		passed_checks += 1
	else:
		print("[FAIL] Run not started correctly")
		passed = false

	# Check 8: SeededRNG smoke test passes (Tier 0.4)
	total_checks += 1
	print("\n--- Running SeededRNG Smoke Test ---")
	var rng_passed = SeededRNG.run_smoke_test()
	if rng_passed:
		print("[PASS] SeededRNG smoke test passed")
		passed_checks += 1
	else:
		print("[FAIL] SeededRNG smoke test failed")
		passed = false

	# Print current state summary
	print("\n--- Current State ---")
	print_state()

	# End run for cleanup
	end_run()

	# Final result
	print("\n========================================")
	if passed:
		print("  SMOKE TEST PASSED (%d/%d checks)" % [passed_checks, total_checks])
	else:
		print("  SMOKE TEST FAILED (%d/%d checks)" % [passed_checks, total_checks])
	print("========================================\n")

	return passed
