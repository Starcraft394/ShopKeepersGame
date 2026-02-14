## game_boot.gd
## Minimal startup scene that validates autoloads and data, then transitions.
## Source: M4 Boot System
## Updated: Hardened autoload validation with dynamic detection
extends Control

# Debug: Force location for testing (set to true to enable)
const DEBUG_FORCE_LOCATION := false
const DEBUG_REGION_ID := "region_1"
const DEBUG_TOWN_ID := "town_greenroot"

# Debug: Force TownHub MVP UI on startup (set false to resume normal TOWN flow)
const DEBUG_FORCE_TOWN_HUB := true

# ============================================================================
# CONFIGURATION
# ============================================================================

## Scene paths for phase-based routing
const TOWN_SCENE_PATH: String = "res://Game/UI/Town/TownScene.tscn"
const COMBAT_SCENE_PATH: String = "res://Game/UI/Combat/CombatScene.tscn"
const DUNGEON_CAMP_SCENE_PATH: String = "res://Game/UI/Dungeon/DungeonCampScene.tscn"
const ROOM_EVENT_SCENE_PATH: String = "res://Game/UI/Rooms/RoomEventScene.tscn"
const TOWN_HUB_SCENE_PATH: String = "res://Game/UI/TownHub/TownHubScene.tscn"

## Fallback scene paths to try if primary scenes don't exist.
const FALLBACK_SCENES: Array[String] = [
	"res://Game/UI/Combat/CombatScene.tscn",
	"res://Game/UI/Main.tscn",
	"res://Game/UI/MainMenu.tscn",
]

## Required autoloads (must exist for boot to succeed)
const REQUIRED_AUTOLOADS: Array[String] = [
	"DataRegistry",
	"GameContext",
]

## Optional autoloads with name variants (check any of these names)
const RNG_AUTOLOAD_VARIANTS: Array[String] = [
	"SeededRng",
	"SeededRNG",
	"seededrng",
]

# Cached reference to found RNG autoload name
var _rng_autoload_name: String = ""

# ============================================================================
# BOOT SEQUENCE
# ============================================================================

func _ready() -> void:
	_run_boot_sequence()


func _run_boot_sequence() -> void:
	print("")
	print("========================================")
	print("[BOOT] Starting...")
	print("[BOOT] Godot %s" % Engine.get_version_info().string)
	print("========================================")

	var boot_ok = true

	# Step 1: List all registered autoloads (for debugging)
	_print_registered_autoloads()

	# Step 2: Validate required autoloads
	if not _validate_autoloads():
		print("")
		print("========================================")
		print("[BOOT][ERROR] Required autoloads missing!")
		print("[BOOT] Game cannot proceed.")
		print("========================================")
		return  # Early exit - don't continue

	# Step 3: Validate data loading
	boot_ok = _validate_data() and boot_ok

	# Step 4: Validate GameContext
	boot_ok = _validate_game_context() and boot_ok

	# Final status
	print("")
	if boot_ok:
		print("========================================")
		print("[BOOT] All checks passed!")
		# Show load stats for key data types
		var stats = DataRegistry.get_load_stats()
		if stats.has("Monsters"):
			var m = stats["Monsters"]
			print("[BOOT] Monsters: seen=%d ok=%d bad=%d" % [m["seen"], m["ok"], m["bad"]])
			if m["bad"] > 0 and m["examples"].size() > 0:
				print("[BOOT] Monsters examples: %s" % ", ".join(m["examples"].slice(0, 5)))
		if stats.has("LootTables"):
			var lt = stats["LootTables"]
			print("[BOOT] LootTables: seen=%d ok=%d bad=%d" % [lt["seen"], lt["ok"], lt["bad"]])
			if lt["bad"] > 0 and lt["examples"].size() > 0:
				print("[BOOT] LootTables examples: %s" % ", ".join(lt["examples"].slice(0, 5)))
		print("[RunStash] Summary: ", GameContext.get_run_stash_summary())
		print("========================================")
		print("")
		if DEBUG_FORCE_LOCATION and GameContext.has_method("set_location"):
			GameContext.set_location(DEBUG_REGION_ID, DEBUG_TOWN_ID)
			print("[BOOT][DEBUG] Forced location: %s/%s" % [DEBUG_REGION_ID, DEBUG_TOWN_ID])
		if DEBUG_FORCE_TOWN_HUB:
			var current_phase = GameContext.get_phase()
			# Only redirect TOWN → TOWN_HUB; let COMBAT and other phases route normally
			if current_phase == GameContext.GamePhase.TOWN or current_phase == GameContext.GamePhase.TOWN_HUB:
				GameContext.set_phase(GameContext.GamePhase.TOWN_HUB)
				print("[BOOT][DEBUG] Forced phase: TOWN_HUB (CraftPix MVP UI)")
			else:
				print("[BOOT][DEBUG] DEBUG_FORCE_TOWN_HUB active but phase=%s — routing normally" % GameContext.GamePhase.keys()[current_phase])
		_transition_to_next_scene()
	else:
		print("========================================")
		print("[BOOT][ERROR] Boot sequence failed!")
		print("[BOOT] Game will not proceed.")
		print("========================================")
		# Don't crash - just stop here


# ============================================================================
# AUTOLOAD DETECTION
# ============================================================================

## Print all registered autoloads from ProjectSettings for debugging.
func _print_registered_autoloads() -> void:
	print("")
	print("[BOOT] Registered autoloads:")

	# Get autoload dictionary from project settings
	var autoload_dict = _get_autoload_settings()

	if autoload_dict.is_empty():
		print("[BOOT]   (none found in ProjectSettings)")
		print("[BOOT]   Checking scene tree directly...")
		_print_root_children()
		return

	for autoload_name in autoload_dict.keys():
		var path = autoload_dict[autoload_name]
		# Check if actually loaded in tree
		var node = get_node_or_null("/root/" + autoload_name)
		var status = "LOADED" if node != null else "NOT IN TREE"
		print("[BOOT]   %s -> %s [%s]" % [autoload_name, path, status])


## Get autoload settings dictionary.
func _get_autoload_settings() -> Dictionary:
	var result: Dictionary = {}

	# Try to read from ProjectSettings
	if ProjectSettings.has_setting("autoload"):
		var autoloads = ProjectSettings.get_setting("autoload")
		if autoloads is Dictionary:
			result = autoloads

	return result


## Print direct children of /root for debugging.
func _print_root_children() -> void:
	var root = get_tree().root
	for child in root.get_children():
		print("[BOOT]   /root/%s" % child.name)


# ============================================================================
# VALIDATION STEPS
# ============================================================================

func _validate_autoloads() -> bool:
	print("")
	print("[BOOT] Validating required autoloads...")
	var all_ok = true

	# Check required autoloads
	for autoload_name in REQUIRED_AUTOLOADS:
		if _has_autoload(autoload_name):
			print("[BOOT]   %s: OK" % autoload_name)
		else:
			print("[BOOT][ERROR]   %s: NOT FOUND" % autoload_name)
			all_ok = false

	# Check RNG autoload (accept any variant name)
	var rng_found = false
	for variant in RNG_AUTOLOAD_VARIANTS:
		if _has_autoload(variant):
			_rng_autoload_name = variant
			print("[BOOT]   SeededRNG (as '%s'): OK" % variant)
			rng_found = true
			break

	if not rng_found:
		print("[BOOT][ERROR]   SeededRNG: NOT FOUND (checked: %s)" % ", ".join(RNG_AUTOLOAD_VARIANTS))
		all_ok = false

	return all_ok


func _has_autoload(autoload_name: String) -> bool:
	# Try to get the autoload from the scene tree
	var autoload = get_node_or_null("/root/" + autoload_name)
	return autoload != null


func _validate_data() -> bool:
	print("")
	print("[BOOT] Validating data registry...")

	# Get DataRegistry autoload
	var registry = get_node_or_null("/root/DataRegistry")
	if registry == null:
		print("[BOOT][ERROR]   Cannot access DataRegistry")
		return false

	# Check if data loaded successfully
	if not registry.is_data_loaded():
		print("[BOOT][ERROR]   Data loading failed!")
		if registry.has_method("get_load_errors"):
			var errors = registry.get_load_errors()
			for err in errors:
				print("[BOOT][ERROR]     - %s" % err)
		return false

	print("[BOOT]   Data loaded: OK")

	# Print summary counts
	if registry.has_method("get_summary_counts"):
		var counts = registry.get_summary_counts()
		print("[BOOT]   Classes:        %d" % counts.get("classes", 0))
		print("[BOOT]   Races:          %d" % counts.get("races", 0))
		print("[BOOT]   Item Templates: %d" % counts.get("item_templates", 0))
		print("[BOOT]   Abilities:      %d" % counts.get("abilities", 0))
		print("[BOOT]   Passives:       %d" % counts.get("passives", 0))
		print("[BOOT]   Status Effects: %d" % counts.get("status_effects", 0))
		print("[BOOT]   Monsters:       %d" % counts.get("monsters", 0))
		print("[BOOT]   Regions:        %d" % counts.get("regions", 0))
		print("[BOOT]   Facilities:     %d" % counts.get("facilities", 0))
		print("[BOOT]   Total entries:  %d" % counts.get("total", 0))

		# Warn if no data loaded (but don't fail - might be intentional during dev)
		if counts.get("total", 0) == 0:
			print("[BOOT][WARN]   No data entries loaded - is Data/ folder populated?")
	else:
		print("[BOOT][WARN]   get_summary_counts() not available")

	return true


func _validate_game_context() -> bool:
	print("")
	print("[BOOT] Validating GameContext...")

	var context = get_node_or_null("/root/GameContext")
	if context == null:
		print("[BOOT][ERROR]   Cannot access GameContext")
		return false

	# Check if initialized
	if context.has_method("is_initialized"):
		if context.is_initialized():
			print("[BOOT]   GameContext initialized: OK")
		else:
			print("[BOOT][WARN]   GameContext not yet initialized (normal at boot)")
	else:
		print("[BOOT][WARN]   is_initialized() not available")

	# Print current state summary
	if context.has_method("get_state_summary"):
		var state = context.get_state_summary()
		print("[BOOT]   Phase: %s" % state.get("phase", "unknown"))
		print("[BOOT]   Location: %s/%s" % [state.get("region_id", "none"), state.get("town_id", "none")])
		print("[BOOT]   Dungeon: %s" % [state.get("dungeon_id", "") if state.get("dungeon_id", "") != "" else "none"])
		print("[BOOT]   Floor: %d" % state.get("floor", 0))
		print("[BOOT]   Room: %d/%d" % [state.get("room_index", 0) + 1, state.get("rooms_per_floor", 1)])
		print("[BOOT]   Party size: %d" % state.get("party_size", 0))
		print("[BOOT]   Run active: %s" % str(state.get("run_active", false)))

	return true


# ============================================================================
# SCENE TRANSITION
# ============================================================================

func _transition_to_next_scene() -> void:
	var routing_info = _determine_route()
	var target_scene = routing_info["scene"]
	var phase = routing_info["phase"]
	var dungeon_id = routing_info["dungeon_id"]
	var floor_num = routing_info["floor"]

	if target_scene == "":
		print("[BOOT][ERROR] No valid scene found to transition to!")
		print("[BOOT] Checked paths:")
		print("[BOOT]   - %s" % TOWN_SCENE_PATH)
		print("[BOOT]   - %s" % COMBAT_SCENE_PATH)
		for fallback in FALLBACK_SCENES:
			print("[BOOT]   - %s" % fallback)
		return

	print("[BOOT] Routing -> %s (phase=%s dungeon=%s floor=%d)" % [
		target_scene, phase, dungeon_id if dungeon_id != "" else "none", floor_num
	])

	# Small delay to ensure logs are visible
	await get_tree().create_timer(0.1).timeout

	var error = get_tree().change_scene_to_file(target_scene)
	if error != OK:
		print("[BOOT][ERROR] Failed to change scene: error code %d" % error)


## Determine which scene to route to based on GameContext phase.
func _determine_route() -> Dictionary:
	var context = get_node_or_null("/root/GameContext")
	var phase = "unknown"
	var dungeon_id = ""
	var floor_num = 0

	if context != null:
		# Get state info
		if context.has_method("get_state_summary"):
			var state = context.get_state_summary()
			phase = state.get("phase", "unknown")
			dungeon_id = state.get("dungeon_id", "")
			floor_num = state.get("floor", 0)
		elif context.has_method("get_phase_name"):
			phase = context.get_phase_name()
		if context.has_method("get_current_dungeon_id"):
			dungeon_id = context.get_current_dungeon_id()
		if context.has_method("get_current_floor"):
			floor_num = context.get_current_floor()

	# Route based on phase
	var target_scene = ""

	# COMBAT phase -> CombatScene
	if phase == "COMBAT":
		if FileAccess.file_exists(COMBAT_SCENE_PATH):
			target_scene = COMBAT_SCENE_PATH

	# DUNGEON_CAMP phase -> DungeonCampScene
	elif phase == "DUNGEON_CAMP":
		if FileAccess.file_exists(DUNGEON_CAMP_SCENE_PATH):
			target_scene = DUNGEON_CAMP_SCENE_PATH

	# ROOM_EVENT phase -> RoomEventScene (non-combat rooms)
	elif phase == "ROOM_EVENT":
		if FileAccess.file_exists(ROOM_EVENT_SCENE_PATH):
			target_scene = ROOM_EVENT_SCENE_PATH

	# TOWN_HUB phase -> TownHubScene (CraftPix MVP UI)
	elif phase == "TOWN_HUB":
		if FileAccess.file_exists(TOWN_HUB_SCENE_PATH):
			target_scene = TOWN_HUB_SCENE_PATH

	# TOWN or DUNGEON_SELECT -> TownScene
	elif phase in ["TOWN", "DUNGEON_SELECT", "BOOT", "REWARDS", "RETURN_TO_TOWN"]:
		if FileAccess.file_exists(TOWN_SCENE_PATH):
			target_scene = TOWN_SCENE_PATH

	# Unknown phase: fallback logic based on dungeon state
	else:
		# If in a dungeon (dungeon_id set), might need CombatScene
		# Otherwise default to TownScene
		if FileAccess.file_exists(TOWN_SCENE_PATH):
			target_scene = TOWN_SCENE_PATH

	# Final fallback if primary choice doesn't exist
	if target_scene == "":
		for fallback in FALLBACK_SCENES:
			if FileAccess.file_exists(fallback):
				target_scene = fallback
				break

	return {
		"scene": target_scene,
		"phase": phase,
		"dungeon_id": dungeon_id,
		"floor": floor_num
	}
