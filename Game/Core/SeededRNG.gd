## SeededRNG.gd
## Autoload singleton providing deterministic random number generation.
## Given the same seed + inputs, produces identical results across sessions.
##
## Source: MVP_Scope.md, MVP_Milestones.md (M0), Tier 0.4
class_name SeededRNG
extends Node

# ============================================================================
# CONSTANTS
# ============================================================================

# Prime multipliers for stable hashing (FNV-1a inspired)
const HASH_PRIME: int = 16777619
const HASH_OFFSET: int = 2166136261

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[SeededRNG] Initialized.")


# ============================================================================
# SEED DERIVATION
# ============================================================================

## Derive a deterministic seed from a string key and base seed.
## Stable across sessions, platforms, and Godot versions.
static func derive_seed(key: String, base_seed: int) -> int:
	# FNV-1a hash variant for stability
	var hash_value: int = HASH_OFFSET ^ base_seed

	for i in range(key.length()):
		var char_code = key.unicode_at(i)
		hash_value = hash_value ^ char_code
		hash_value = (hash_value * HASH_PRIME) & 0x7FFFFFFF  # Keep positive 31-bit

	return hash_value


## Get derived seed for a dungeon floor.
static func floor_seed(region_id: String, town_id: String, floor_index: int, base_seed: int) -> int:
	var key = "floor:%s:%s:%d" % [region_id, town_id, floor_index]
	return derive_seed(key, base_seed)


## Get derived seed for shop generation.
static func shop_seed(region_id: String, town_id: String, refresh_count: int, base_seed: int) -> int:
	var key = "shop:%s:%s:%d" % [region_id, town_id, refresh_count]
	return derive_seed(key, base_seed)


## Get derived seed for a specific encounter.
static func encounter_seed(region_id: String, town_id: String, floor_index: int, room_index: int, base_seed: int) -> int:
	var key = "encounter:%s:%s:%d:%d" % [region_id, town_id, floor_index, room_index]
	return derive_seed(key, base_seed)


## Get derived seed for loot generation.
static func loot_seed(region_id: String, floor_index: int, room_index: int, base_seed: int) -> int:
	var key = "loot:%s:%d:%d" % [region_id, floor_index, room_index]
	return derive_seed(key, base_seed)


## Get derived seed for item generation.
static func item_seed(context: String, index: int, base_seed: int) -> int:
	var key = "item:%s:%d" % [context, index]
	return derive_seed(key, base_seed)


# ============================================================================
# RNG STREAM CREATION
# ============================================================================

## Create a new RandomNumberGenerator with the given seed.
static func create_rng(seed_value: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Get an RNG configured for a specific floor.
func get_rng_for_floor(region_id: String, town_id: String, floor_index: int, base_seed: int) -> RandomNumberGenerator:
	var seed_val = floor_seed(region_id, town_id, floor_index, base_seed)
	return create_rng(seed_val)


## Get an RNG configured for shop generation.
func get_rng_for_shop(region_id: String, town_id: String, refresh_count: int, base_seed: int) -> RandomNumberGenerator:
	var seed_val = shop_seed(region_id, town_id, refresh_count, base_seed)
	return create_rng(seed_val)


## Get an RNG configured for a specific encounter.
func get_rng_for_encounter(region_id: String, town_id: String, floor_index: int, room_index: int, base_seed: int) -> RandomNumberGenerator:
	var seed_val = encounter_seed(region_id, town_id, floor_index, room_index, base_seed)
	return create_rng(seed_val)


## Get an RNG configured for loot generation.
func get_rng_for_loot(region_id: String, floor_index: int, room_index: int, base_seed: int) -> RandomNumberGenerator:
	var seed_val = loot_seed(region_id, floor_index, room_index, base_seed)
	return create_rng(seed_val)


# ============================================================================
# CONVENIENCE FUNCTIONS
# ============================================================================

## Generate random integer in range [min_val, max_val] inclusive.
func rand_int(min_val: int, max_val: int, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(min_val, max_val)


## Generate random float in range [0.0, 1.0).
func randf(rng: RandomNumberGenerator) -> float:
	return rng.randf()


## Generate random float in range [min_val, max_val].
func randf_range(min_val: float, max_val: float, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(min_val, max_val)


## Roll a percentage chance. Returns true if roll succeeds.
## pct should be 0-100 (e.g., 25 for 25% chance).
static func roll_chance(pct: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() * 100.0 < pct


## Choose from an array of weighted entries.
## entries: Array of Dictionaries with "value" and "weight" keys.
## Returns the chosen value, or null if entries is empty.
static func choose_weighted(entries: Array, rng: RandomNumberGenerator) -> Variant:
	if entries.is_empty():
		return null

	# Calculate total weight
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.get("weight", 1.0)

	if total_weight <= 0.0:
		return entries[0].get("value")

	# Roll and find selection
	var roll = rng.randf() * total_weight
	var cumulative: float = 0.0

	for entry in entries:
		cumulative += entry.get("weight", 1.0)
		if roll < cumulative:
			return entry.get("value")

	# Fallback (shouldn't reach here)
	return entries[entries.size() - 1].get("value")


## Shuffle an array in place using Fisher-Yates algorithm.
func shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


## Pick N random elements from an array (without replacement).
func pick_n(arr: Array, n: int, rng: RandomNumberGenerator) -> Array:
	if n >= arr.size():
		return arr.duplicate()

	var copy = arr.duplicate()
	shuffle_array(copy, rng)
	return copy.slice(0, n)


# ============================================================================
# UTILITY
# ============================================================================

## Generate a new random seed from system time.
## Use this only for initial run seed generation.
static func generate_random_seed() -> int:
	return int(Time.get_unix_time_from_system() * 1000) & 0x7FFFFFFF


# ============================================================================
# DEBUG & SMOKE TEST
# ============================================================================

## Run smoke test to verify Tier 0.4 requirements.
## Call via: SeededRNG.run_smoke_test()
static func run_smoke_test() -> bool:
	print("\n========================================")
	print("    SeededRNG Tier 0.4 SMOKE TEST")
	print("========================================\n")

	var passed = true
	var total_checks = 0
	var passed_checks = 0

	var test_seed = 12345

	# Check 1: Same seed + same key => same derived seed
	total_checks += 1
	var derived_1 = derive_seed("test_key", test_seed)
	var derived_2 = derive_seed("test_key", test_seed)
	if derived_1 == derived_2:
		print("[PASS] Same seed + same key => same derived seed (%d)" % derived_1)
		passed_checks += 1
	else:
		print("[FAIL] Derived seeds don't match: %d vs %d" % [derived_1, derived_2])
		passed = false

	# Check 2: Different key => different derived seed
	total_checks += 1
	var derived_3 = derive_seed("different_key", test_seed)
	if derived_1 != derived_3:
		print("[PASS] Different key => different derived seed (%d vs %d)" % [derived_1, derived_3])
		passed_checks += 1
	else:
		print("[FAIL] Different keys produced same seed")
		passed = false

	# Check 3: Different base seed => different derived seed
	total_checks += 1
	var derived_4 = derive_seed("test_key", 54321)
	if derived_1 != derived_4:
		print("[PASS] Different base seed => different derived seed (%d vs %d)" % [derived_1, derived_4])
		passed_checks += 1
	else:
		print("[FAIL] Different base seeds produced same derived seed")
		passed = false

	# Check 4: Two RNG streams with same seed produce identical sequences
	total_checks += 1
	var rng_a = create_rng(derived_1)
	var rng_b = create_rng(derived_1)
	var sequence_a = []
	var sequence_b = []
	for i in range(5):
		sequence_a.append(rng_a.randi())
		sequence_b.append(rng_b.randi())
	if sequence_a == sequence_b:
		print("[PASS] Identical seeds => identical sequences: %s" % str(sequence_a))
		passed_checks += 1
	else:
		print("[FAIL] Sequences don't match")
		print("  A: %s" % str(sequence_a))
		print("  B: %s" % str(sequence_b))
		passed = false

	# Check 5: Weighted choice is deterministic
	total_checks += 1
	var weighted_entries = [
		{"value": "common", "weight": 70.0},
		{"value": "uncommon", "weight": 20.0},
		{"value": "rare", "weight": 10.0}
	]
	var rng_c = create_rng(test_seed)
	var rng_d = create_rng(test_seed)
	var choices_c = []
	var choices_d = []
	for i in range(5):
		choices_c.append(choose_weighted(weighted_entries, rng_c))
		choices_d.append(choose_weighted(weighted_entries, rng_d))
	if choices_c == choices_d:
		print("[PASS] Weighted choice is deterministic: %s" % str(choices_c))
		passed_checks += 1
	else:
		print("[FAIL] Weighted choices don't match")
		print("  C: %s" % str(choices_c))
		print("  D: %s" % str(choices_d))
		passed = false

	# Check 6: Floor seed derivation works
	total_checks += 1
	var floor_seed_1 = floor_seed("region_1", "town_1", 1, test_seed)
	var floor_seed_2 = floor_seed("region_1", "town_1", 1, test_seed)
	var floor_seed_3 = floor_seed("region_1", "town_1", 2, test_seed)
	if floor_seed_1 == floor_seed_2 and floor_seed_1 != floor_seed_3:
		print("[PASS] Floor seed derivation: F1=%d, F2=%d (different floor)" % [floor_seed_1, floor_seed_3])
		passed_checks += 1
	else:
		print("[FAIL] Floor seed derivation failed")
		passed = false

	# Check 7: Shop seed derivation works
	total_checks += 1
	var shop_seed_1 = shop_seed("region_1", "town_1", 0, test_seed)
	var shop_seed_2 = shop_seed("region_1", "town_1", 1, test_seed)
	if shop_seed_1 != shop_seed_2:
		print("[PASS] Shop seed changes with refresh: %d vs %d" % [shop_seed_1, shop_seed_2])
		passed_checks += 1
	else:
		print("[FAIL] Shop seed didn't change with refresh count")
		passed = false

	# Check 8: roll_chance is deterministic
	total_checks += 1
	var rng_e = create_rng(test_seed)
	var rng_f = create_rng(test_seed)
	var rolls_e = []
	var rolls_f = []
	for i in range(10):
		rolls_e.append(roll_chance(50.0, rng_e))
		rolls_f.append(roll_chance(50.0, rng_f))
	if rolls_e == rolls_f:
		print("[PASS] roll_chance is deterministic: %s" % str(rolls_e))
		passed_checks += 1
	else:
		print("[FAIL] roll_chance not deterministic")
		passed = false

	# Final result
	print("\n========================================")
	if passed:
		print("  SMOKE TEST PASSED (%d/%d checks)" % [passed_checks, total_checks])
	else:
		print("  SMOKE TEST FAILED (%d/%d checks)" % [passed_checks, total_checks])
	print("========================================\n")

	return passed
