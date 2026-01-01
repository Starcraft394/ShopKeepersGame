## game_boot.gd
## Minimal startup scene that validates autoloads and data, then transitions.
## Source: M4 Boot System
## Updated: Hardened autoload validation with dynamic detection
extends Control

# ============================================================================
# CONFIGURATION
# ============================================================================

## Path to the next scene after successful boot.
@export var next_scene_path: String = "res://Game/UI/Combat/CombatScene.tscn"

## Fallback scene paths to try if next_scene_path doesn't exist.
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
		print("========================================")
		print("")
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
		print("[BOOT]   Party size: %d" % state.get("party_size", 0))
		print("[BOOT]   Run active: %s" % str(state.get("run_active", false)))

	return true


# ============================================================================
# SCENE TRANSITION
# ============================================================================

func _transition_to_next_scene() -> void:
	var target_scene = _find_valid_scene()

	if target_scene == "":
		print("[BOOT][ERROR] No valid scene found to transition to!")
		print("[BOOT] Checked paths:")
		print("[BOOT]   - %s" % next_scene_path)
		for fallback in FALLBACK_SCENES:
			print("[BOOT]   - %s" % fallback)
		return

	print("[BOOT] Transitioning to: %s" % target_scene)

	# Small delay to ensure logs are visible
	await get_tree().create_timer(0.1).timeout

	var error = get_tree().change_scene_to_file(target_scene)
	if error != OK:
		print("[BOOT][ERROR] Failed to change scene: error code %d" % error)


func _find_valid_scene() -> String:
	# Try the configured next_scene_path first
	if FileAccess.file_exists(next_scene_path):
		return next_scene_path

	# Try fallback scenes
	for fallback in FALLBACK_SCENES:
		if FileAccess.file_exists(fallback):
			return fallback

	return ""
