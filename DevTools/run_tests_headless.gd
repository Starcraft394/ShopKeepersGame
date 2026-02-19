## run_tests_headless.gd
## Headless test runner that extends SceneTree for proper Godot execution.
## Manually initializes autoloads before running tests.
##
## Usage: godot --headless --path <project> --script res://DevTools/run_tests_headless.gd --quit
extends SceneTree


func _initialize() -> void:
	print("")
	print("=" .repeat(60))
	print("  HEADLESS TEST RUNNER")
	print("=" .repeat(60))
	print("")

	# ========================================================================
	# STEP 1: Initialize autoloads
	# Godot may have already created autoload nodes from project.godot.
	# We need to ensure they are initialized (data loaded) before running tests.
	# ========================================================================
	print("[TestRunner] Initializing autoloads...")

	# Check if DataRegistry already exists (from project.godot autoload)
	var data_registry = root.get_node_or_null("DataRegistry")
	if data_registry == null:
		# Create and register DataRegistry if not present
		var data_registry_script = load("res://Game/Core/DataRegistry.gd")
		if data_registry_script == null:
			print("[Tests] ERROR: Failed to load DataRegistry.gd")
			quit(1)
			return
		data_registry = data_registry_script.new()
		data_registry.name = "DataRegistry"
		root.add_child(data_registry)
		print("[TestRunner] Created new DataRegistry")
	else:
		print("[TestRunner] Using existing DataRegistry (autoload)")

	# Force data loading immediately (don't wait for _ready)
	if data_registry.has_method("_load_all_data"):
		data_registry._load_all_data()
	print("[TestRunner] DataRegistry data loaded (id=%d)" % data_registry.get_instance_id())

	# Check if SeededRng already exists
	var seeded_rng = root.get_node_or_null("SeededRng")
	if seeded_rng == null:
		var seeded_rng_script = load("res://Game/Core/SeededRNG.gd")
		if seeded_rng_script == null:
			print("[Tests] ERROR: Failed to load SeededRNG.gd")
			quit(1)
			return
		seeded_rng = seeded_rng_script.new()
		seeded_rng.name = "SeededRng"
		root.add_child(seeded_rng)
		print("[TestRunner] Created new SeededRng")
	else:
		print("[TestRunner] Using existing SeededRng (autoload)")

	# Check if GameContext already exists
	var game_context = root.get_node_or_null("GameContext")
	if game_context == null:
		var game_context_script = load("res://Game/Core/GameContext.gd")
		if game_context_script == null:
			print("[Tests] ERROR: Failed to load GameContext.gd")
			quit(1)
			return
		game_context = game_context_script.new()
		game_context.name = "GameContext"
		root.add_child(game_context)
		print("[TestRunner] Created new GameContext")
	else:
		print("[TestRunner] Using existing GameContext (autoload)")

	print("[TestRunner] All autoloads ready")
	print("")

	# ========================================================================
	# STEP 2: Load and run test suites
	# ========================================================================
	var all_passed: int = 0
	var all_failed: int = 0

	# --- Suite 1: Ability Execution Tests ---
	var test_script = load("res://DevTools/test_ability_execution_v1.gd")
	if test_script == null:
		print("[Tests] ERROR: Failed to load test_ability_execution_v1.gd")
		quit(1)
		return

	var results: Dictionary = {}

	if test_script.has_method("run_tests"):
		results = test_script.run_tests()
	else:
		var instance = test_script.new()
		if instance == null:
			print("[Tests] ERROR: Failed to instantiate test suite")
			quit(1)
			return

		if instance.has_method("run_tests"):
			results = instance.run_tests()
		else:
			print("[Tests] ERROR: Test suite has no run_tests() method")
			quit(1)
			return

	if results is Dictionary:
		all_passed += results.get("passed", 0)
		all_failed += results.get("failed", 0)

	# --- Suite 2: Comprehensive Playtest ---
	var playtest_script = load("res://DevTools/test_playtest_v1.gd")
	if playtest_script != null:
		var playtest_results: Dictionary = {}
		if playtest_script.has_method("run_tests"):
			playtest_results = playtest_script.run_tests()
		else:
			var pt_instance = playtest_script.new()
			if pt_instance != null and pt_instance.has_method("run_tests"):
				playtest_results = pt_instance.run_tests()
		if playtest_results is Dictionary:
			all_passed += playtest_results.get("passed", 0)
			all_failed += playtest_results.get("failed", 0)
	else:
		print("[Tests] WARNING: Playtest suite not found (skipping)")

	# ========================================================================
	# STEP 3: Print summary and exit
	# ========================================================================
	var total = all_passed + all_failed

	print("")
	print("=" .repeat(60))
	print("  HEADLESS TEST SUMMARY")
	print("=" .repeat(60))
	print("TEST RESULTS: %d passed, %d failed" % [all_passed, all_failed])

	if all_failed > 0:
		print("[Tests] RESULT: FAILED")
		print("=" .repeat(60))
		quit(1)
	else:
		print("[Tests] RESULT: PASSED")
		print("=" .repeat(60))
		quit(0)
