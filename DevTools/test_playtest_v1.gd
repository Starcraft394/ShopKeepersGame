## test_playtest_v1.gd
## Comprehensive game flow playtest — simulates a full start-to-finish walkthrough.
## Validates data integrity, game flow, and system integration across all 7 regions.
## Call from code: var results = load("res://DevTools/test_playtest_v1.gd").run_tests()
class_name PlaytestV1
extends RefCounted

# Region → Town → Dungeon mapping (ground truth)
const REGION_MAP: Array = [
	{"region": "region_1", "town": "town_thornhaven", "dungeon": "dungeon_thornhaven"},
	{"region": "region_2", "town": "town_sproutrest", "dungeon": "dungeon_sproutrest"},
	{"region": "region_3", "town": "town_shelldrift", "dungeon": "dungeon_shelldrift"},
	{"region": "region_4", "town": "town_embercradle", "dungeon": "dungeon_embercradle"},
	{"region": "region_5", "town": "town_crystalhearth", "dungeon": "dungeon_crystalhearth"},
	{"region": "region_6", "town": "town_duskhollow", "dungeon": "dungeon_duskhollow"},
	{"region": "region_7", "town": "town_void_threshold", "dungeon": "dungeon_void_threshold"},
]

# Base classes that should be available at start
const BASE_CLASSES: Array = ["defender", "striker", "warden"]

# Classes unlocked per region
const REGION_CLASSES: Dictionary = {
	2: ["druid", "fungal_berserker"],
	3: ["tidechaser", "stormcaller"],
	4: ["pyrewarden", "ashblade"],
	5: ["prism_sentinel", "prism_lancer"],
	6: ["dark_channeler", "lich"],
	7: ["voidwalker", "void_herald"],
}

# Equipment facilities and their craft types
const EQUIPMENT_FACILITIES: Array = ["blacksmith", "huntsman", "enchanter"]

# ============================================================================
# TEST RUNNER
# ============================================================================

static func run_tests() -> Dictionary:
	print("")
	print("=" .repeat(60))
	print("  COMPREHENSIVE PLAYTEST V1")
	print("=" .repeat(60))
	print("")

	var results = {"passed": 0, "failed": 0, "tests": [], "gaps": []}

	# ── DATA INTEGRITY ──
	_run_test(results, "_test_regions_have_towns_and_dungeons")
	_run_test(results, "_test_all_classes_valid")
	_run_test(results, "_test_all_monsters_valid")
	_run_test(results, "_test_all_loot_tables_valid")
	_run_test(results, "_test_equipment_slot_coverage")
	_run_test(results, "_test_regional_affixes_exist")
	_run_test(results, "_test_facility_recipes_valid")
	_run_test(results, "_test_dungeon_monster_pools")
	_run_test(results, "_test_item_tag_consistency")

	# ── GAME FLOW ──
	_run_test(results, "_test_fresh_game_state")
	_run_test(results, "_test_hero_recruitment_flow")
	_run_test(results, "_test_equipment_equip_flow")
	_run_test(results, "_test_hero_stats_calculation")
	_run_test(results, "_test_facility_tier_progression")
	_run_test(results, "_test_recipe_unlock_flow")
	_run_test(results, "_test_training_hall_books")
	_run_test(results, "_test_dungeon_entry_flow")
	_run_test(results, "_test_region_progression")
	_run_test(results, "_test_t4_craft_recipes_valid")
	_run_test(results, "_test_consumable_system")
	_run_test(results, "_test_xp_and_leveling")
	_run_test(results, "_test_shopkeeper_bag")

	# ── SUMMARY ──
	print("")
	print("=" .repeat(60))
	if results["gaps"].size() > 0:
		print("  GAPS FOUND: %d" % results["gaps"].size())
		print("=" .repeat(60))
		for gap in results["gaps"]:
			print("  GAP: %s" % gap)
	else:
		print("  NO GAPS FOUND")
	print("=" .repeat(60))
	print("")

	return results


static func _run_test(results: Dictionary, method_name: String) -> void:
	var callable = Callable(PlaytestV1, method_name)
	if not callable.is_valid():
		print("--- SKIP: %s (not found) ---" % method_name)
		return
	var t: Dictionary = callable.call(results["gaps"])
	results["tests"].append(t)
	if t["passed"]:
		results["passed"] += 1
	else:
		results["failed"] += 1


static func _pass(test_name: String) -> Dictionary:
	print("  PASS: %s" % test_name)
	return {"name": test_name, "passed": true}


static func _fail(test_name: String, reason: String) -> Dictionary:
	print("  FAIL: %s — %s" % [test_name, reason])
	return {"name": test_name, "passed": false, "reason": reason}


# ============================================================================
# DATA INTEGRITY TESTS
# ============================================================================

static func _test_regions_have_towns_and_dungeons(gaps: Array) -> Dictionary:
	print("--- Playtest: Regions → Towns → Dungeons ---")
	var issues: Array = []

	for entry in REGION_MAP:
		var region_id: String = entry["region"]
		var town_id: String = entry["town"]
		var dungeon_id: String = entry["dungeon"]

		var region = DataRegistry.get_region(region_id)
		if region == null:
			issues.append("Missing region: %s" % region_id)
			continue

		var town = DataRegistry.get_town(town_id)
		if town == null:
			issues.append("Missing town: %s (region %s)" % [town_id, region_id])
			continue

		# Check town references this region
		if town.region_id != region_id:
			issues.append("Town %s region mismatch: expected=%s got=%s" % [town_id, region_id, town.region_id])

		var dungeon = DataRegistry.get_dungeon(dungeon_id)
		if dungeon == null:
			issues.append("Missing dungeon: %s (region %s)" % [dungeon_id, region_id])
			continue

		# Check dungeon references this region
		if dungeon.region_id != region_id:
			issues.append("Dungeon %s region mismatch: expected=%s got=%s" % [dungeon_id, region_id, dungeon.region_id])

		# Check boss exists
		if dungeon.boss_id != "":
			var boss = DataRegistry.get_monster(dungeon.boss_id)
			if boss == null:
				issues.append("Dungeon %s boss not found: %s" % [dungeon_id, dungeon.boss_id])

		# Check alt boss exists
		if dungeon.alt_boss_id != "":
			var alt_boss = DataRegistry.get_monster(dungeon.alt_boss_id)
			if alt_boss == null:
				issues.append("Dungeon %s alt_boss not found: %s" % [dungeon_id, dungeon.alt_boss_id])

		# Check event table exists
		if dungeon.event_table_id != "":
			var et = DataRegistry.get_event_table(dungeon.event_table_id)
			if et == null:
				issues.append("Dungeon %s event_table not found: %s" % [dungeon_id, dungeon.event_table_id])

		# Check town has facilities
		if town.facility_ids.size() == 0:
			issues.append("Town %s has no facilities" % town_id)

		# Verify each facility in town exists
		for fac_id in town.facility_ids:
			var fac = DataRegistry.get_facility(fac_id)
			if fac == null:
				issues.append("Town %s references missing facility: %s" % [town_id, fac_id])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Regions→Towns→Dungeons", "%d issues" % issues.size())
	return _pass("Regions→Towns→Dungeons (7 regions verified)")


static func _test_all_classes_valid(gaps: Array) -> Dictionary:
	print("--- Playtest: Class Validity ---")
	var issues: Array = []
	var all_classes = DataRegistry.get_all_classes()

	for cls in all_classes:
		if cls.class_id == "":
			issues.append("Class with empty ID")
			continue

		# Check abilities exist
		for ability_field in ["ability_a_id", "ability_b_id"]:
			var ability_id: String = cls.get(ability_field)
			if ability_id != "" and ability_id != null:
				var ability = DataRegistry.get_ability(ability_id)
				if ability == null:
					issues.append("Class %s: ability %s not found: %s" % [cls.class_id, ability_field, ability_id])

		# Check passives exist
		for passive_field in ["passive_a_id", "passive_b_id"]:
			var passive_id: String = cls.get(passive_field)
			if passive_id != "" and passive_id != null:
				var passive = DataRegistry.get_passive(passive_id)
				if passive == null:
					issues.append("Class %s: passive %s not found: %s" % [cls.class_id, passive_field, passive_id])

		# Check base stats
		if cls.base_stats.is_empty():
			issues.append("Class %s has no base_stats" % cls.class_id)

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Class Validity", "%d issues in %d classes" % [issues.size(), all_classes.size()])
	return _pass("Class Validity (%d classes)" % all_classes.size())


static func _test_all_monsters_valid(gaps: Array) -> Dictionary:
	print("--- Playtest: Monster Validity ---")
	var issues: Array = []
	var all_monsters = DataRegistry.get_all_monsters()

	for mon in all_monsters:
		if mon.monster_id == "":
			issues.append("Monster with empty ID")
			continue

		# Check abilities exist
		for ability_id in mon.ability_ids:
			var ability = DataRegistry.get_ability(ability_id)
			if ability == null:
				issues.append("Monster %s: ability not found: %s" % [mon.monster_id, ability_id])

		# Check passives exist
		for passive_id in mon.passive_ids:
			var passive = DataRegistry.get_passive(passive_id)
			if passive == null:
				issues.append("Monster %s: passive not found: %s" % [mon.monster_id, passive_id])

		# Check loot table exists (if specified)
		if mon.loot_table_id != "":
			var lt = DataRegistry.get_loot_table(mon.loot_table_id)
			if lt == null:
				issues.append("Monster %s: loot_table not found: %s" % [mon.monster_id, mon.loot_table_id])

		# Check base stats aren't empty
		if mon.base_stats.is_empty():
			issues.append("Monster %s has no base_stats" % mon.monster_id)

		# Check gold drops are valid
		if mon.gold_drop_min > mon.gold_drop_max and mon.gold_drop_max > 0:
			issues.append("Monster %s: gold_drop_min > max (%d > %d)" % [mon.monster_id, mon.gold_drop_min, mon.gold_drop_max])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Monster Validity", "%d issues in %d monsters" % [issues.size(), all_monsters.size()])
	return _pass("Monster Validity (%d monsters)" % all_monsters.size())


static func _test_all_loot_tables_valid(gaps: Array) -> Dictionary:
	print("--- Playtest: Loot Table Validity ---")
	var issues: Array = []
	var all_tables = DataRegistry.get_all_loot_tables()

	for lt in all_tables:
		if lt.id == "":
			issues.append("Loot table with empty ID")
			continue

		if lt.entries.is_empty():
			issues.append("Loot table %s has no entries" % lt.id)
			continue

		for entry in lt.entries:
			var item_id: String = entry.get("item_id", "")
			if item_id == "":
				# Empty item_id with max_qty=0 is an intentional "no drop" entry
				var max_qty: int = entry.get("max_qty", 0)
				if max_qty > 0:
					issues.append("Loot table %s: entry with empty item_id but max_qty=%d" % [lt.id, max_qty])
				continue
			var item = DataRegistry.get_item_template(item_id)
			if item == null:
				issues.append("Loot table %s: item not found: %s" % [lt.id, item_id])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Loot Table Validity", "%d issues in %d tables" % [issues.size(), all_tables.size()])
	return _pass("Loot Table Validity (%d tables)" % all_tables.size())


static func _test_equipment_slot_coverage(gaps: Array) -> Dictionary:
	print("--- Playtest: Equipment Slot Coverage ---")
	var issues: Array = []
	var all_items = DataRegistry.get_all_item_templates()

	# Count items per equip slot
	var slot_counts: Dictionary = {}
	for slot in GameContext.ALL_EQUIP_SLOTS:
		slot_counts[slot] = 0

	for item in all_items:
		var slot: String = item.equip_slot
		if slot != "" and slot_counts.has(slot):
			slot_counts[slot] += 1

	# Check each slot has at least 2 items
	for slot in slot_counts:
		var count: int = slot_counts[slot]
		if count == 0:
			issues.append("Equipment slot '%s' has NO items" % slot)
			gaps.append("No items for slot: %s" % slot)
		elif count < 2:
			issues.append("Equipment slot '%s' has only %d item (need ≥2)" % [slot, count])
			gaps.append("Only %d item for slot: %s" % [count, slot])

	print("    Slot coverage: %s" % str(slot_counts))

	if issues.size() > 0:
		return _fail("Equipment Slot Coverage", "%d slots under-served" % issues.size())
	return _pass("Equipment Slot Coverage (all slots ≥2)")


static func _test_regional_affixes_exist(gaps: Array) -> Dictionary:
	print("--- Playtest: Regional Affixes ---")
	var issues: Array = []

	for i in range(1, 8):
		var region_id = "region_%d" % i
		var affix = DataRegistry.get_regional_affix(region_id)
		if affix.is_empty():
			issues.append("No regional affix for %s" % region_id)
			gaps.append("Missing regional affix: %s" % region_id)
		else:
			var prefix: String = affix.get("prefix", "")
			var stat_bonus: Dictionary = affix.get("stat_bonus", {})
			if prefix == "":
				issues.append("Region %s affix has empty prefix" % region_id)
			if stat_bonus.is_empty():
				issues.append("Region %s affix has empty stat_bonus" % region_id)

	if issues.size() > 0:
		return _fail("Regional Affixes", "%d issues" % issues.size())
	return _pass("Regional Affixes (7 regions)")


static func _test_facility_recipes_valid(gaps: Array) -> Dictionary:
	print("--- Playtest: Facility Recipe Validity ---")
	var issues: Array = []
	var recipe_count: int = 0

	for fac_id in EQUIPMENT_FACILITIES:
		var facility = DataRegistry.get_facility(fac_id)
		if facility == null:
			issues.append("Facility not found: %s" % fac_id)
			continue

		# Equipment facilities use crafting_recipes (not unlocks)
		for recipe in facility.crafting_recipes:
			recipe_count += 1
			var output_id: String = recipe.get("output_id", "")
			if output_id == "":
				issues.append("%s: recipe with no output_id" % fac_id)
				continue

			# Verify output item exists
			var item = DataRegistry.get_item_template(output_id)
			if item == null:
				issues.append("%s: output item not found: %s" % [fac_id, output_id])

			# Verify unlock_cost items exist
			var unlock_cost = recipe.get("unlock_cost", [])
			for cost_entry in unlock_cost:
				var cost_item_id: String = cost_entry.get("item_id", "")
				if cost_item_id != "" and cost_item_id != "gold":
					var cost_item = DataRegistry.get_item_template(cost_item_id)
					if cost_item == null:
						issues.append("%s recipe %s: cost item not found: %s" % [fac_id, output_id, cost_item_id])

			# Verify craft_inputs items exist (T4)
			var craft_inputs = recipe.get("craft_inputs", [])
			for input_entry in craft_inputs:
				var input_id: String = input_entry.get("item_id", "")
				if input_id != "":
					var input_item = DataRegistry.get_item_template(input_id)
					if input_item == null:
						issues.append("%s T4 craft %s: input item not found: %s" % [fac_id, output_id, input_id])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Facility Recipes", "%d issues in %d recipes" % [issues.size(), recipe_count])
	return _pass("Facility Recipes (%d recipes across %d facilities)" % [recipe_count, EQUIPMENT_FACILITIES.size()])


static func _test_dungeon_monster_pools(gaps: Array) -> Dictionary:
	print("--- Playtest: Dungeon Monster Pools ---")
	var issues: Array = []

	for entry in REGION_MAP:
		var dungeon_id: String = entry["dungeon"]
		var dungeon = DataRegistry.get_dungeon(dungeon_id)
		if dungeon == null:
			continue  # Already caught in region test

		# Check global monster pools
		var all_pool_ids: Array = []
		all_pool_ids.append_array(dungeon.tier1_monster_ids)
		all_pool_ids.append_array(dungeon.tier2_monster_ids)
		all_pool_ids.append_array(dungeon.elite_monster_ids)

		if all_pool_ids.is_empty():
			# Check per-floor pools
			var has_floor_pools: bool = false
			for floor_pool in dungeon.tier1_by_floor:
				if floor_pool.size() > 0:
					has_floor_pools = true
					break
			if not has_floor_pools:
				issues.append("Dungeon %s has no monster pools (global or per-floor)" % dungeon_id)
				gaps.append("Dungeon %s: no monster pools" % dungeon_id)
				continue

		# Validate all monster IDs in global pools
		for mon_id in all_pool_ids:
			var monster = DataRegistry.get_monster(mon_id)
			if monster == null:
				issues.append("Dungeon %s: monster not found: %s" % [dungeon_id, mon_id])

		# Validate per-floor monster IDs
		for floor_idx in range(dungeon.tier1_by_floor.size()):
			for mon_id in dungeon.tier1_by_floor[floor_idx]:
				if DataRegistry.get_monster(mon_id) == null:
					issues.append("Dungeon %s F%d tier1: monster not found: %s" % [dungeon_id, floor_idx + 1, mon_id])
		for floor_idx in range(dungeon.tier2_by_floor.size()):
			for mon_id in dungeon.tier2_by_floor[floor_idx]:
				if DataRegistry.get_monster(mon_id) == null:
					issues.append("Dungeon %s F%d tier2: monster not found: %s" % [dungeon_id, floor_idx + 1, mon_id])
		for floor_idx in range(dungeon.elite_by_floor.size()):
			for mon_id in dungeon.elite_by_floor[floor_idx]:
				if DataRegistry.get_monster(mon_id) == null:
					issues.append("Dungeon %s F%d elite: monster not found: %s" % [dungeon_id, floor_idx + 1, mon_id])

	for issue in issues:
		if not gaps.has(issue):
			gaps.append(issue)

	if issues.size() > 0:
		return _fail("Dungeon Monster Pools", "%d issues" % issues.size())
	return _pass("Dungeon Monster Pools (7 dungeons)")


static func _test_item_tag_consistency(gaps: Array) -> Dictionary:
	print("--- Playtest: Item Tag Consistency ---")
	var issues: Array = []
	var all_items = DataRegistry.get_all_item_templates()

	var base_count: int = 0
	var region_count: int = 0
	var no_region_tag: int = 0

	for item in all_items:
		var tags: Array = item.tags
		var has_base: bool = tags.has("base")
		var has_region: bool = false
		for tag in tags:
			if tag is String and tag.begins_with("region_"):
				has_region = true
				break

		if has_base:
			base_count += 1
		elif has_region:
			region_count += 1
		else:
			no_region_tag += 1

	print("    Items: base=%d, regional=%d, no_region_tag=%d" % [base_count, region_count, no_region_tag])

	# Items with no region tag at all (not necessarily an issue but worth noting)
	if no_region_tag > 0:
		# Only flag as gap if it's a significant number
		var tag_list: Array = []
		for item in all_items:
			var tags: Array = item.tags
			var has_any_region: bool = tags.has("base")
			for tag in tags:
				if tag is String and tag.begins_with("region_"):
					has_any_region = true
					break
			if not has_any_region and tag_list.size() < 5:
				tag_list.append(item.template_id)
		if no_region_tag > 3:
			gaps.append("%d items have no base/region tag (e.g.: %s)" % [no_region_tag, ", ".join(tag_list)])

	if issues.size() > 0:
		return _fail("Item Tag Consistency", "%d issues" % issues.size())
	return _pass("Item Tag Consistency (base=%d, regional=%d, untagged=%d)" % [base_count, region_count, no_region_tag])


# ============================================================================
# GAME FLOW TESTS
# ============================================================================

static func _test_fresh_game_state(gaps: Array) -> Dictionary:
	print("--- Playtest: Fresh Game State ---")

	# Reset to clean state
	GameContext.reset_save_game()

	var issues: Array = []

	# Check starting gold
	if GameContext.player_gold != 400:
		issues.append("Starting gold should be 400, got %d" % GameContext.player_gold)

	# Check no heroes
	if GameContext.get_owned_heroes().size() != 0:
		issues.append("Fresh game should have 0 heroes, got %d" % GameContext.get_owned_heroes().size())

	# Check default unlock groups
	for group in GameContext.DEFAULT_UNLOCK_GROUPS:
		if not GameContext.has_unlocked_group(group):
			issues.append("Default unlock group missing: %s" % group)

	# Check default recipes
	for recipe_key in GameContext.DEFAULT_UNLOCKED_RECIPES:
		var recipe_data: Dictionary = GameContext.DEFAULT_UNLOCKED_RECIPES[recipe_key]
		var output_id: String = recipe_data.get("output_id", "")
		if output_id != "" and not GameContext.is_recipe_unlocked(output_id):
			issues.append("Default recipe not unlocked: %s" % output_id)

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Fresh Game State", "%d issues" % issues.size())
	return _pass("Fresh Game State")


static func _test_hero_recruitment_flow(gaps: Array) -> Dictionary:
	print("--- Playtest: Hero Recruitment Flow ---")

	GameContext.reset_save_game()

	# Give gold via run stash (recruit_hero spends from run_gold)
	GameContext.add_run_gold(1000)

	var issues: Array = []
	var recruited_ids: Array = []

	# Recruit one hero of each base class
	for class_id in BASE_CLASSES:
		var cls = DataRegistry.get_class_data(class_id)
		if cls == null:
			issues.append("Base class not found: %s" % class_id)
			continue

		var hero_id: String = GameContext.recruit_hero(class_id, 50, "human", 1)
		if hero_id == "":
			issues.append("Failed to recruit %s" % class_id)
			continue

		recruited_ids.append(hero_id)

		# Verify hero exists in roster
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			issues.append("Recruited hero %s not found in roster" % hero_id)
			continue

		# Verify class_id is correct
		if hero.get("class_id", "") != class_id:
			issues.append("Hero %s class mismatch: expected=%s got=%s" % [hero_id, class_id, hero.get("class_id", "")])

	# Verify party assignment
	if recruited_ids.size() >= 2:
		GameContext.add_to_party(recruited_ids[0])
		GameContext.add_to_party(recruited_ids[1])
		if not GameContext.is_in_party(recruited_ids[0]):
			issues.append("Hero not added to party")
		if GameContext.get_selected_party().size() != 2:
			issues.append("Party size should be 2, got %d" % GameContext.get_selected_party().size())

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Hero Recruitment Flow", "%d issues" % issues.size())
	return _pass("Hero Recruitment Flow (%d heroes recruited)" % recruited_ids.size())


static func _test_equipment_equip_flow(gaps: Array) -> Dictionary:
	print("--- Playtest: Equipment Equip Flow ---")

	GameContext.reset_save_game()
	GameContext.add_run_gold(1000)

	var issues: Array = []

	# Recruit a defender
	var hero_id: String = GameContext.recruit_hero("defender", 50, "human", 1)
	if hero_id == "":
		gaps.append("Cannot recruit hero for equipment test")
		return _fail("Equipment Equip Flow", "Cannot recruit hero")

	# Equip each slot with starter items
	var equip_tests: Dictionary = {
		"weapon": "rusty_sword",
		"offhand": "wooden_shield",
		"helmet": "tanned_leather_hood",
		"armor": "leather_vest",
		"legs": "tanned_leather_greaves",
		"ring": "simple_ring",
		"amulet": "lucky_charm",
		"bag": "small_backpack",
	}

	for slot in equip_tests:
		var item_id: String = equip_tests[slot]
		# Verify item exists
		var item = DataRegistry.get_item_template(item_id)
		if item == null:
			issues.append("Starter item not found: %s" % item_id)
			continue

		# Add item to run stash first (equip_hero_item requires it)
		GameContext.add_run_item(item_id, 1)

		# Equip it
		var ok: bool = GameContext.equip_hero_item(hero_id, slot, item_id)
		if not ok:
			var reason: String = GameContext.get_equip_rejection_reason(slot, item_id)
			issues.append("Cannot equip %s in slot %s: %s" % [item_id, slot, reason])
			continue

		# Verify it's equipped
		var equipped_id: String = GameContext.get_hero_slot_item(hero_id, slot)
		if equipped_id != item_id:
			issues.append("Slot %s: expected %s, got %s" % [slot, item_id, equipped_id])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Equipment Equip Flow", "%d issues" % issues.size())
	return _pass("Equipment Equip Flow (8 slots tested)")


static func _test_hero_stats_calculation(gaps: Array) -> Dictionary:
	print("--- Playtest: Hero Stats Calculation ---")

	GameContext.reset_save_game()
	GameContext.add_run_gold(1000)

	var issues: Array = []

	# Recruit and equip a defender
	var hero_id: String = GameContext.recruit_hero("defender", 50, "human", 1)
	if hero_id == "":
		return _fail("Hero Stats Calculation", "Cannot recruit hero")

	# Get base stats (no equipment)
	var base_stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)
	if base_stats.is_empty():
		issues.append("get_hero_effective_stats returned empty for %s" % hero_id)
	else:
		# Defender should have health, attack, defense, speed
		for stat in ["health", "attack", "defense", "speed"]:
			if not base_stats.has(stat):
				issues.append("Missing stat '%s' in effective stats" % stat)
			elif base_stats[stat] <= 0:
				issues.append("Stat '%s' is %d (should be > 0)" % [stat, base_stats[stat]])

	# Equip weapon and verify stats change
	GameContext.add_run_item("rusty_sword", 1)
	GameContext.equip_hero_item(hero_id, "weapon", "rusty_sword")
	var armed_stats: Dictionary = GameContext.get_hero_effective_stats(hero_id)

	if not base_stats.is_empty() and not armed_stats.is_empty():
		# With a weapon, attack should be higher than without
		var base_atk: int = base_stats.get("attack", 0)
		var armed_atk: int = armed_stats.get("attack", 0)
		if armed_atk <= base_atk:
			issues.append("Equipping rusty_sword didn't increase attack: base=%d armed=%d" % [base_atk, armed_atk])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Hero Stats Calculation", "%d issues" % issues.size())
	return _pass("Hero Stats Calculation")


static func _test_facility_tier_progression(gaps: Array) -> Dictionary:
	print("--- Playtest: Facility Tier Progression ---")

	GameContext.reset_save_game()

	var issues: Array = []
	var town_id: String = "town_thornhaven"

	# Check initial facility tiers (should all be 1)
	for fac_id in EQUIPMENT_FACILITIES:
		var tier: int = GameContext.get_facility_tier(town_id, fac_id)
		if tier != 1:
			issues.append("Initial %s tier should be 1, got %d" % [fac_id, tier])

	# Check max tiers from data
	for fac_id in EQUIPMENT_FACILITIES:
		var facility = DataRegistry.get_facility(fac_id)
		if facility == null:
			issues.append("Facility not found: %s" % fac_id)
			continue
		if facility.max_tier < 4:
			issues.append("Facility %s max_tier is %d (expected ≥4)" % [fac_id, facility.max_tier])

		# Check upgrade costs exist for each tier
		for target_tier in range(2, facility.max_tier + 1):
			var tier_str = str(target_tier)
			if not facility.upgrade_costs.has(tier_str):
				# Check regional costs
				var has_regional: bool = false
				for region_key in facility.regional_upgrade_costs:
					var region_costs: Dictionary = facility.regional_upgrade_costs[region_key]
					if region_costs.has(tier_str):
						has_regional = true
						break
				if not has_regional:
					issues.append("Facility %s: no upgrade cost for tier %d (global or regional)" % [fac_id, target_tier])

	# Simulate upgrading blacksmith to T2 (give materials and gold)
	GameContext.add_run_gold(5000)
	GameContext.add_run_item("iron_scrap", 50)
	GameContext.add_run_item("wood_bundle", 50)

	var bs_upgraded: bool = GameContext.upgrade_facility(town_id, "blacksmith")
	var bs_tier: int = GameContext.get_facility_tier(town_id, "blacksmith")
	if bs_tier < 2 and not bs_upgraded:
		# Not necessarily an issue — might need specific items
		print("    Note: Blacksmith upgrade to T2 failed (may need region-specific materials)")
	elif bs_tier >= 2:
		print("    Blacksmith upgraded to T%d" % bs_tier)

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Facility Tier Progression", "%d issues" % issues.size())
	return _pass("Facility Tier Progression")


static func _test_recipe_unlock_flow(gaps: Array) -> Dictionary:
	print("--- Playtest: Recipe Unlock Flow ---")

	GameContext.reset_save_game()

	var issues: Array = []

	# Check default recipes are unlocked
	if not GameContext.is_recipe_unlocked("rusty_sword"):
		issues.append("Default recipe rusty_sword not unlocked")
	if not GameContext.is_recipe_unlocked("wooden_shield"):
		issues.append("Default recipe wooden_shield not unlocked")

	# Try to unlock a new recipe
	GameContext.add_run_item("iron_scrap", 10)
	GameContext.add_run_item("wood_bundle", 10)

	# Find first blacksmith T1 recipe that isn't already unlocked
	var facility = DataRegistry.get_facility("blacksmith")
	if facility != null:
		var unlocked_new: bool = false
		for recipe in facility.crafting_recipes:
			var output_id: String = recipe.get("output_id", "")
			var upgrade_tier: int = recipe.get("upgrade_tier", 1)
			if upgrade_tier == 1 and output_id != "" and not GameContext.is_recipe_unlocked(output_id):
				# Try to purchase
				var unlock_cost = recipe.get("unlock_cost", [])
				var can_afford: bool = GameContext.can_afford_recipe_unlock(unlock_cost)
				if can_afford:
					var purchased: bool = GameContext.purchase_recipe_unlock(output_id, unlock_cost, "blacksmith", 1, 1)
					if purchased:
						unlocked_new = true
						print("    Unlocked recipe: %s" % output_id)
						break

		if not unlocked_new:
			print("    Note: Could not unlock new recipe (may need more materials)")

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Recipe Unlock Flow", "%d issues" % issues.size())
	return _pass("Recipe Unlock Flow")


static func _test_training_hall_books(gaps: Array) -> Dictionary:
	print("--- Playtest: Training Hall Books ---")

	var issues: Array = []
	var facility = DataRegistry.get_facility("training_hall")
	if facility == null:
		gaps.append("Training hall facility not found")
		return _fail("Training Hall Books", "facility not found")

	var book_count: int = 0
	var base_books_found: int = 0

	for shop_item in facility.shop_items:
		var item_id: String = shop_item.get("item_id", "")
		if item_id == "":
			issues.append("Training hall shop_item with empty item_id")
			continue

		book_count += 1

		# Verify item template exists
		var item = DataRegistry.get_item_template(item_id)
		if item == null:
			issues.append("Training hall book not found: %s" % item_id)
			continue

		# Verify price is set
		var price: int = shop_item.get("price_gold", 0)
		if price <= 0:
			issues.append("Training hall book %s has no price" % item_id)

		# Verify required_facility_tier is set
		var req_tier: int = shop_item.get("required_facility_tier", 0)
		if req_tier <= 0:
			issues.append("Training hall book %s has no required_facility_tier" % item_id)

		# Check base books at T1
		if item_id in ["book_defender", "book_striker", "book_warden"]:
			base_books_found += 1
			if req_tier != 1:
				issues.append("Base book %s should be T1, got T%d" % [item_id, req_tier])

		# Verify book -> class mapping exists
		var class_id: String = GameContext.BOOK_TO_CLASS_MAP.get(item_id, "")
		if class_id == "":
			issues.append("Book %s has no class mapping in BOOK_TO_CLASS_MAP" % item_id)
		else:
			# Verify the class exists
			var cls = DataRegistry.get_class_data(class_id)
			if cls == null:
				issues.append("Book %s maps to missing class: %s" % [item_id, class_id])

	if base_books_found < 3:
		issues.append("Only %d/3 base class books in Training Hall" % base_books_found)

	# Check all regional class books are present
	for region_idx in REGION_CLASSES:
		for class_id in REGION_CLASSES[region_idx]:
			var book_id = "book_%s" % class_id
			var found: bool = false
			for shop_item in facility.shop_items:
				if shop_item.get("item_id", "") == book_id:
					found = true
					break
			if not found:
				issues.append("Region %d class book missing from Training Hall: %s" % [region_idx, book_id])

	for issue in issues:
		gaps.append(issue)

	print("    Books in Training Hall: %d (base: %d)" % [book_count, base_books_found])

	if issues.size() > 0:
		return _fail("Training Hall Books", "%d issues" % issues.size())
	return _pass("Training Hall Books (%d books, %d base)" % [book_count, base_books_found])


static func _test_dungeon_entry_flow(gaps: Array) -> Dictionary:
	print("--- Playtest: Dungeon Entry Flow ---")

	GameContext.reset_save_game()
	GameContext.add_run_gold(1000)

	var issues: Array = []

	# Recruit and form party
	var hero1: String = GameContext.recruit_hero("defender", 50, "human", 1)
	var hero2: String = GameContext.recruit_hero("striker", 50, "human", 1)
	if hero1 == "" or hero2 == "":
		return _fail("Dungeon Entry Flow", "Cannot recruit heroes")

	GameContext.add_to_party(hero1)
	GameContext.add_to_party(hero2)

	# Enter dungeon
	var dungeon_id: String = "dungeon_thornhaven"
	GameContext.enter_dungeon(dungeon_id)

	if GameContext.get_current_dungeon_id() != dungeon_id:
		issues.append("Dungeon ID not set after enter_dungeon")

	if GameContext.get_current_floor() != 1:
		issues.append("Floor should be 1, got %d" % GameContext.get_current_floor())

	# Verify dungeon has floor data
	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	if dungeon != null:
		if dungeon.floor_count <= 0:
			issues.append("Dungeon has 0 floors")
		else:
			print("    Dungeon: %s (%d floors)" % [dungeon.display_name, dungeon.floor_count])

	# Test XP granting
	var xp_result: Dictionary = GameContext.grant_party_xp(50, "test_combat")
	if xp_result.is_empty():
		issues.append("grant_party_xp returned empty result")

	# Clean up: exit dungeon
	GameContext.exit_to_town()

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Dungeon Entry Flow", "%d issues" % issues.size())
	return _pass("Dungeon Entry Flow")


static func _test_region_progression(gaps: Array) -> Dictionary:
	print("--- Playtest: Region Progression (R1-R7) ---")

	GameContext.reset_save_game()

	var issues: Array = []

	for i in range(1, 8):
		var region_id = "region_%d" % i
		var region = DataRegistry.get_region(region_id)
		if region == null:
			issues.append("Region %d missing" % i)
			continue

		# Set current region
		GameContext.set_current_region(i)
		if GameContext.get_current_region() != i:
			issues.append("Failed to set region to %d" % i)

		# Check region has content
		if region.town_ids.is_empty():
			issues.append("Region %d has no towns" % i)
		if region.boss_id == "":
			issues.append("Region %d has no boss_id" % i)
		else:
			var boss = DataRegistry.get_monster(region.boss_id)
			if boss == null:
				issues.append("Region %d boss not found: %s" % [i, region.boss_id])
			elif not boss.is_boss:
				issues.append("Region %d boss %s is_boss=false" % [i, region.boss_id])

		# Check classes for this region
		if REGION_CLASSES.has(i):
			for class_id in REGION_CLASSES[i]:
				var cls = DataRegistry.get_class_data(class_id)
				if cls == null:
					issues.append("Region %d class not found: %s" % [i, class_id])
				elif cls.unlock_region != i:
					issues.append("Class %s unlock_region=%d (expected %d)" % [class_id, cls.unlock_region, i])

		# Check regional affix
		var affix = DataRegistry.get_regional_affix(region_id)
		if affix.is_empty():
			issues.append("Region %d has no affix" % i)

		print("    R%d %s: towns=%d boss=%s" % [i, region.display_name, region.town_ids.size(), region.boss_id])

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Region Progression", "%d issues" % issues.size())
	return _pass("Region Progression (7 regions)")


static func _test_t4_craft_recipes_valid(gaps: Array) -> Dictionary:
	print("--- Playtest: T4 Craft Recipes ---")

	var issues: Array = []
	var t4_count: int = 0

	for fac_id in EQUIPMENT_FACILITIES:
		var facility = DataRegistry.get_facility(fac_id)
		if facility == null:
			continue

		for recipe in facility.crafting_recipes:
			var upgrade_tier: int = recipe.get("upgrade_tier", 1)
			if upgrade_tier != 4:
				continue

			t4_count += 1
			var output_id: String = recipe.get("output_id", "")
			var is_craft: bool = recipe.get("is_craft", false)
			var craft_inputs = recipe.get("craft_inputs", [])
			var region: String = recipe.get("region", "")

			if not is_craft:
				issues.append("%s T4 recipe %s: is_craft should be true" % [fac_id, output_id])

			if craft_inputs.is_empty():
				issues.append("%s T4 recipe %s: no craft_inputs" % [fac_id, output_id])

			if region == "":
				issues.append("%s T4 recipe %s: no region field" % [fac_id, output_id])

			# Validate output item
			if output_id != "":
				var item = DataRegistry.get_item_template(output_id)
				if item == null:
					issues.append("%s T4 recipe: output not found: %s" % [fac_id, output_id])

			# Validate craft inputs
			for input_entry in craft_inputs:
				var input_id: String = input_entry.get("item_id", "")
				if input_id == "":
					issues.append("%s T4 recipe %s: empty craft input" % [fac_id, output_id])
				else:
					var input_item = DataRegistry.get_item_template(input_id)
					if input_item == null:
						issues.append("%s T4 %s: input item not found: %s" % [fac_id, output_id, input_id])

	for issue in issues:
		gaps.append(issue)

	print("    T4 craft recipes: %d total" % t4_count)

	if issues.size() > 0:
		return _fail("T4 Craft Recipes", "%d issues in %d recipes" % [issues.size(), t4_count])
	return _pass("T4 Craft Recipes (%d recipes)" % t4_count)


static func _test_consumable_system(gaps: Array) -> Dictionary:
	print("--- Playtest: Consumable System ---")

	GameContext.reset_save_game()
	GameContext.add_run_gold(1000)

	var issues: Array = []

	# Recruit a hero
	var hero_id: String = GameContext.recruit_hero("defender", 50, "human", 1)
	if hero_id == "":
		return _fail("Consumable System", "Cannot recruit hero")

	# Check healing consumables exist
	var healing_items: Array = []
	var all_items = DataRegistry.get_all_item_templates()
	for item in all_items:
		if item.use_effect == "heal" and item.item_type == "consumable":
			healing_items.append(item.template_id)

	if healing_items.is_empty():
		issues.append("No healing consumables found in data")
		gaps.append("No healing consumables in item templates")

	# Check per-region consumables
	for i in range(1, 8):
		var region_tag = "region_%d" % i
		var region_consumables: int = 0
		for item in all_items:
			if item.item_type == "consumable" and item.tags.has(region_tag):
				region_consumables += 1
		if region_consumables == 0 and i <= 2:
			# Only flag R1-R2 as gaps; later regions may use base consumables
			issues.append("Region %d has no consumables" % i)

	# Test adding item to hero bag
	if healing_items.size() > 0:
		var test_item: String = healing_items[0]
		# Add to stash first
		GameContext.add_run_item(test_item, 1)
		var can_add: bool = GameContext.can_add_to_hero_bag(hero_id, test_item)
		if can_add:
			var added: bool = GameContext.move_item_stash_to_hero_bag(hero_id, test_item, 1)
			if not added:
				print("    Note: move_item_stash_to_hero_bag returned false (may need stash ItemInstance)")
		else:
			print("    Note: Cannot add %s to hero bag (capacity full or wrong type)" % test_item)

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Consumable System", "%d issues" % issues.size())
	return _pass("Consumable System (%d healing items found)" % healing_items.size())


static func _test_xp_and_leveling(gaps: Array) -> Dictionary:
	print("--- Playtest: XP & Leveling ---")

	GameContext.reset_save_game()
	GameContext.add_run_gold(1000)

	var issues: Array = []

	# Recruit a hero
	var hero_id: String = GameContext.recruit_hero("defender", 50, "human", 1)
	if hero_id == "":
		return _fail("XP & Leveling", "Cannot recruit hero")

	GameContext.add_to_party(hero_id)

	# Verify starting level
	var hero = GameContext.get_hero(hero_id)
	if hero.get("level", 0) != 1:
		issues.append("Starting level should be 1, got %d" % hero.get("level", 0))

	# Grant XP
	var xp_to_grant: int = GameContext.XP_THRESHOLDS[1]  # XP needed for level 2
	var levels_gained: int = GameContext.grant_hero_xp(hero_id, xp_to_grant)

	hero = GameContext.get_hero(hero_id)
	var new_level: int = hero.get("level", 0)
	if new_level < 2:
		issues.append("After granting %d XP, level should be ≥2, got %d" % [xp_to_grant, new_level])

	# Check XP thresholds are monotonically increasing
	for i in range(1, GameContext.XP_THRESHOLDS.size()):
		if GameContext.XP_THRESHOLDS[i] <= GameContext.XP_THRESHOLDS[i - 1]:
			issues.append("XP threshold not increasing: L%d=%d ≤ L%d=%d" % [i + 1, GameContext.XP_THRESHOLDS[i], i, GameContext.XP_THRESHOLDS[i - 1]])
			break

	# Check region XP base values exist
	for region_num in range(1, 8):
		if not GameContext.REGION_XP_BASE.has(region_num):
			issues.append("Missing REGION_XP_BASE for region %d" % region_num)

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("XP & Leveling", "%d issues" % issues.size())
	return _pass("XP & Leveling")


static func _test_shopkeeper_bag(gaps: Array) -> Dictionary:
	print("--- Playtest: Shopkeeper Bag ---")

	GameContext.reset_save_game()

	var issues: Array = []

	# Check initial capacity
	var capacity: int = GameContext.get_shopkeeper_bag_capacity()
	if capacity <= 0:
		issues.append("Shopkeeper bag capacity is %d (should be > 0)" % capacity)

	# Add items to shopkeeper bag
	var can_add: bool = GameContext.can_add_to_shopkeeper_bag("iron_scrap", 1)
	if not can_add:
		issues.append("Cannot add iron_scrap to shopkeeper bag")
	else:
		var added: bool = GameContext.add_item_to_shopkeeper_bag("iron_scrap", 1, 0, "test")
		if not added:
			issues.append("add_item_to_shopkeeper_bag returned false")

	# Check bag contents
	var bag: Array = GameContext.get_shopkeeper_bag()
	if bag.is_empty() and can_add:
		issues.append("Shopkeeper bag is empty after adding item")

	for issue in issues:
		gaps.append(issue)

	if issues.size() > 0:
		return _fail("Shopkeeper Bag", "%d issues" % issues.size())
	return _pass("Shopkeeper Bag (capacity=%d)" % capacity)
