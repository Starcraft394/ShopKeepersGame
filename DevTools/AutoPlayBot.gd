extends Node
## AutoPlayBot — Automated playthrough bot for visual playtesting.
## Activated ONLY when launched with: godot -- --autoplay R1-R3
## Zero overhead when --autoplay flag is absent.

# ============================================================================
# CONSTANTS
# ============================================================================

const BOOT_SCENE := "res://Game/Boot/game_boot.tscn"
const TOWN_HUB_SCENE := "res://Game/UI/TownHub/TownHubScene.tscn"

## Region → town → dungeon mapping
const REGION_DATA := {
	"region_1": {"town": "town_thornhaven", "dungeon": "dungeon_thornhaven"},
	"region_2": {"town": "town_sproutrest", "dungeon": "dungeon_sproutrest"},
	"region_3": {"town": "town_shelldrift", "dungeon": "dungeon_shelldrift"},
	"region_4": {"town": "town_embercradle", "dungeon": "dungeon_embercradle"},
	"region_5": {"town": "town_crystalhearth", "dungeon": "dungeon_crystalhearth"},
	"region_6": {"town": "town_duskhollow", "dungeon": "dungeon_duskhollow"},
	"region_7": {"town": "town_void_threshold", "dungeon": "dungeon_void_threshold"},
}

## Recruit priority: 1 tank, 1 healer, 2 DPS
const TANK_CLASSES := ["defender", "pyrewarden", "prism_sentinel"]
const HEALER_CLASSES := ["druid", "tidechaser", "dark_channeler", "warden"]
const DPS_CLASSES := ["striker", "stormcaller", "ashblade", "fungal_berserker", "prism_lancer", "lich", "void_herald"]

## Watchdog: if no _log() call for this many seconds, bot is stuck
const WATCHDOG_TIMEOUT_SEC := 60.0

## Action delay: seconds between visible actions (facility upgrades, shop buys, etc.)
## Set > 0 to slow down for visual observation.
const ACTION_DELAY_SEC := 0.3

## Floor mastery: consecutive clean runs (no hero deaths) needed to advance start floor
const FLOOR_MASTERY_THRESHOLD := 3

## Per-region leveling tiers: heroes train on lower floors before advancing
## Format: {region_num: {min_level_threshold: training_floor}}
const REGION_LEVELING_TIERS: Dictionary = {
	1: {5: 1, 10: 2},    # R1: Lv<5→F1, Lv<10→F2
	2: {10: 1, 15: 2},   # R2: Lv<10→F1, Lv<15→F2
	3: {15: 1, 20: 2},   # R3
	4: {20: 1, 25: 2},   # R4
	5: {25: 1, 30: 2},   # R5
	6: {30: 1, 35: 2},   # R6
	7: {35: 1, 40: 2},   # R7
}

## Facility upgrade priority: inn moved up for better recruits on hero loss
const FACILITY_UPGRADE_PRIORITY: Array = [
	"chef", "alchemist", "training_hall",
	"inn", "blacksmith", "storage",
	"shop", "huntsman", "enchanter"
]

## All tutorial IDs to pre-skip
const ALL_TUTORIALS := [
	"tutorial_welcome", "tutorial_first_combat", "tutorial_first_camp",
	"tutorial_first_dungeon", "tutorial_first_event", "tutorial_first_extraction",
	"tutorial_abilities", "tutorial_equipment_facilities", "tutorial_facilities_overview",
	"tutorial_flee", "tutorial_manage_roster", "tutorial_ng_plus", "tutorial_party_bar",
	"tutorial_production", "tutorial_region_progression", "tutorial_shop",
	"tutorial_side_quests", "tutorial_storage", "tutorial_training_hall",
]

# ============================================================================
# STATE
# ============================================================================

var _active: bool = false
var _region_chunk: String = ""  # e.g. "R1-R3"
var _start_region: int = 1
var _end_region: int = 7
var _current_target_region: int = 1
var _max_ng_cycles: int = 1  # Stop after this many NG+ cycles (0 = no NG+, 1 = complete NG+1)
var _town_visits: int = 0
var _handling_phase: bool = false
var _combat_connected: bool = false
var _combat_ended_handled: bool = false  # Guard against double combat_ended signal
var _action_log: Array = []  # Ring buffer of last 50 actions
var _last_action_ms: int = 0  # Time.get_ticks_msec() of last _log() call
var _overlay_check_timer: float = 0.0  # Periodic check for flee dialog / stuck overlays
var _combat_last_signal_ms: int = 0  # Last time a combat signal fired
var _stall_recovery_fails: int = 0  # Consecutive failed stall recoveries
var _floor_clean_runs: Dictionary = {}  # Floor mastery: {floor_num: consecutive_clean_count}
const COMBAT_STALL_SEC := 8.0  # If no combat signal for this long, try to unstick
const MAX_STALL_RECOVERIES := 3  # After this many fails, force-leave combat (~24s total)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if not "--autoplay" in args:
		return
	_active = true
	var idx = args.find("--autoplay")
	if idx + 1 < args.size():
		_region_chunk = args[idx + 1]
	_parse_region_chunk()
	_log("Bot activated — chunk=%s (R%d-R%d)" % [_region_chunk, _start_region, _end_region])
	GameContext.current_save_slot = -1  # Isolate from player saves
	GameContext.phase_changed.connect(_on_phase_changed)
	call_deferred("_start_bot")


func _process(delta: float) -> void:
	if not _active or _last_action_ms == 0:
		return
	var elapsed_sec: float = (Time.get_ticks_msec() - _last_action_ms) / 1000.0
	if elapsed_sec > WATCHDOG_TIMEOUT_SEC:
		_report_stuck()
		return
	# FIX 9: Periodic overlay check (flee dialog, defeat panel) every 3 seconds
	_overlay_check_timer += delta
	if _overlay_check_timer >= 3.0:
		_overlay_check_timer = 0.0
		_check_for_overlays()


func _parse_region_chunk() -> void:
	var chunk = _region_chunk.to_upper().strip_edges()
	if chunk == "":
		chunk = "R1-R7"
	# Handle NG+ prefix: "NG1-R1-R3" → strip NG prefix
	if chunk.begins_with("NG"):
		var ng_parts = chunk.split("-", false, 1)
		if ng_parts.size() > 1:
			chunk = ng_parts[1]
	var parts = chunk.replace("R", "").split("-")
	if parts.size() >= 1:
		_start_region = int(parts[0])
	if parts.size() >= 2:
		_end_region = int(parts[1])
	else:
		_end_region = _start_region
	_start_region = clampi(_start_region, 1, 7)
	_end_region = clampi(_end_region, _start_region, 7)
	_current_target_region = _start_region


func _start_bot() -> void:
	# Resume from existing save if available, otherwise start fresh
	var save_path: String = GameContext.get_save_path(-1)
	if FileAccess.file_exists(save_path):
		GameContext.current_save_slot = -1
		GameContext.load_game()
		# Determine current region from saved state
		_current_target_region = clampi(GameContext.current_region, _start_region, _end_region)
		_log("Resumed from save — R%d, gold=%d, heroes=%d" % [
			_current_target_region, GameContext.run_gold, GameContext.owned_heroes.size()])
	else:
		_log("Starting new game (isolated save slot -1)")
		GameContext.start_new_game(-1)

	# FIX 1: Pre-skip ALL overlays before any scenes load
	_skip_all_overlays()

	# Navigate to current region
	var region_key = "region_%d" % _current_target_region
	var data = REGION_DATA.get(region_key, REGION_DATA["region_1"])
	GameContext.set_location(region_key, data["town"])

	# FIX 8: Block _on_phase_changed BEFORE set_phase to prevent double-handling
	_handling_phase = true
	GameContext.set_phase(GameContext.GamePhase.TOWN_HUB)
	await _wait_frames(3)
	PlaytestCapture.capture("title_start")
	SceneTransition.fade_to(TOWN_HUB_SCENE)

	# Wait for scene transition, then handle town hub directly
	await get_tree().create_timer(2.0).timeout
	await _wait_frames(10)
	await _handle_town_hub()
	# _handling_phase is released inside _enter_dungeon() before set_phase(COMBAT)


## FIX 1: Pre-complete all tutorials and campaign dialogs so they never appear.
func _skip_all_overlays() -> void:
	# Mark all tutorials as completed
	for tutorial_id in ALL_TUTORIALS:
		GameContext.complete_tutorial(tutorial_id)
	_log("Pre-skipped %d tutorials" % ALL_TUTORIALS.size())

	# Mark all campaign dialogs as shown
	var dialog_count: int = 0
	for region_num in range(1, 8):
		var region_id = "region_%d" % region_num
		if DataRegistry.has_method("get_campaign_dialogs_for_region"):
			var dialogs = DataRegistry.get_campaign_dialogs_for_region(region_id)
			for dialog in dialogs:
				var dialog_id: String = ""
				if dialog is Dictionary:
					dialog_id = dialog.get("id", "")
				elif "id" in dialog:
					dialog_id = dialog.id
				if dialog_id != "":
					GameContext.set_campaign_flag("shown_" + dialog_id)
					dialog_count += 1
	_log("Pre-skipped %d campaign dialogs" % dialog_count)

	# Skip intro cutscene + telemetry consent (opt in for bot data collection)
	GameContext.set_campaign_flag("shown_intro_cutscene")
	GameContext.set_campaign_flag("shown_telemetry_consent_v1")
	GameContext.telemetry_consent = true

	# Pre-skip all boss cutscenes (entry + victory for each region)
	for r in range(1, 8):
		GameContext.set_campaign_flag("shown_boss_entry_r%d" % r)
		GameContext.set_campaign_flag("shown_boss_victory_r%d" % r)
	_log("Pre-skipped boss cutscenes for R1-R7")

# ============================================================================
# PHASE ROUTER — only catches scene-initiated transitions
# ============================================================================

func _on_phase_changed(_old_phase: int, new_phase: int) -> void:
	if not _active:
		return
	if _handling_phase:
		_log("Phase change to %s ignored — handler active" % GameContext.get_phase_name())
		return
	# TOWN phase is transient — boot scene converts it to TOWN_HUB.
	# Don't block here or the TOWN_HUB phase change will be missed.
	if new_phase == GameContext.GamePhase.TOWN:
		_log("Phase changed → TOWN (transient, waiting for TOWN_HUB)")
		return
	_handling_phase = true
	# Wait for scene transition + UI building
	await get_tree().create_timer(1.5).timeout
	await _wait_frames(10)
	_log("Phase changed → %s" % GameContext.get_phase_name())
	match new_phase:
		GameContext.GamePhase.TOWN_HUB:
			await _handle_town_hub()
		GameContext.GamePhase.COMBAT:
			await _handle_combat()
		GameContext.GamePhase.DUNGEON_CAMP:
			await _handle_dungeon_camp()
		GameContext.GamePhase.ROOM_EVENT:
			await _handle_room_event()
		_:
			_log("Unhandled phase: %s" % GameContext.get_phase_name())
	_handling_phase = false

# ============================================================================
# TOWN HUB HANDLER
# ============================================================================

func _handle_town_hub() -> void:
	_town_visits += 1
	var town_id = GameContext.get_current_town_id()
	_log("Town hub visit #%d — %s (gold: %d)" % [_town_visits, town_id, GameContext.get_run_gold()])
	PlaytestCapture.capture("town_overview")
	await _wait_frames(10)

	# 1. RECRUIT HEROES (if party < 4)
	await _recruit_heroes()
	await _wait_frames(5)

	# 2. ASSIGN FORMATION based on class role
	_assign_formation()

	# 3. BANK BAGS TO STASH (hero bags + shopkeeper bag → stash)
	_bank_bags_to_stash()

	# 4. UPGRADE FACILITIES — spend gold + stash materials to reach 9 tiers
	_upgrade_facilities()

	# 4.5 CRAFT HEALING CONSUMABLES from stash materials (before shopping)
	#     Reduces heal_gap so shop slots can focus on gear
	_craft_healing_consumables()

	# 4.6 CRAFT COMBAT BUFFS (DEF, ATK, SPD potions) at alchemist T2+
	_craft_combat_buffs()

	# 4.7 CRAFT EQUIPMENT at blacksmith/huntsman/enchanter from stash materials
	_craft_equipment()

	# 5. EQUIP + DISTRIBUTE from stash (banked dungeon loot + crafted items) before shopping
	#    This way the shop allocation sees accurate hero state
	_equip_heroes_from_stash()
	_distribute_consumables_to_bags()
	_distribute_buff_consumables_to_bags()

	# 6. SHOP: allocate slots, generate items, buy upgrades + consumables
	#    Allocation now checks hero bags/equipment post-stash distribution (incl. crafted heals)
	_shop_buy_upgrades()

	# 7. EQUIP + DISTRIBUTE again to pick up newly purchased shop items
	_equip_heroes_from_stash()
	_distribute_consumables_to_bags()
	_distribute_buff_consumables_to_bags()

	# 8. SCREENSHOT party state
	PlaytestCapture.capture("town_party_ready")
	await _wait_frames(3)

	# 9. CHECK REGION PROGRESS — should we travel or end?
	if _should_travel_to_next_region():
		await _travel_to_next_region()
		return
	var current_region_key = "region_%d" % _current_target_region
	if GameContext.is_region_completed(current_region_key) and _current_target_region >= _end_region:
		_end_run("chunk_complete")
		return

	# 10. ENTER DUNGEON (phase handler catches COMBAT)
	await _enter_dungeon()

# ============================================================================
# FIX 2: FORMATION ASSIGNMENT
# ============================================================================

func _assign_formation() -> void:
	for hero_id in GameContext.get_selected_party():
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue
		var class_id: String = hero.get("class_id", "")
		var row: int = 1  # Middle (DPS default)
		if class_id in TANK_CLASSES:
			row = 0  # Front
		elif class_id in HEALER_CLASSES:
			row = 2  # Back
		GameContext.set_hero_row(hero_id, row)
		_log("Formation: %s (%s) → row %d (%s)" % [hero_id, class_id, row, ["Front", "Middle", "Back"][row]])

# ============================================================================
# FACILITY UPGRADES — unlock boss floor (requires 9+ total tiers)
# ============================================================================

func _upgrade_facilities() -> void:
	var town_id: String = GameContext.get_current_town_id()
	var total_tiers: int = GameContext.get_total_facility_tiers(town_id)
	var all_maxed: bool = _all_facilities_maxed(town_id)
	_log("Facility tiers: %d (all maxed: %s)" % [total_tiers, str(all_maxed)])

	if all_maxed:
		return  # All facilities at T4, nothing to upgrade

	# Keep a recruit reserve so we can replace dead heroes
	var recruit_reserve: int = _get_recruit_reserve()
	# Budget: spend at most half of available gold (above reserve) on upgrades
	var upgrade_budget: int = maxi(GameContext.get_run_gold() - recruit_reserve, 0) / 2
	var spent: int = 0
	var upgraded: int = 0

	for facility_id in FACILITY_UPGRADE_PRIORITY:
		if not GameContext.can_upgrade_facility(town_id, facility_id):
			continue
		var current_tier: int = GameContext.get_facility_tier(town_id, facility_id)
		var cost: Dictionary = GameContext.get_facility_upgrade_cost(facility_id, current_tier + 1)
		var gold_cost: int = cost.get("gold", 0)
		if spent + gold_cost > upgrade_budget:
			continue  # Would exceed budget
		if GameContext.upgrade_facility(town_id, facility_id):
			var new_tier: int = GameContext.get_facility_tier(town_id, facility_id)
			_log("Upgraded %s to T%d (%dg)" % [facility_id, new_tier, gold_cost])
			spent += gold_cost
			upgraded += 1
			await _action_delay()

	if upgraded > 0:
		var new_total: int = GameContext.get_total_facility_tiers(town_id)
		_log("Upgraded %d facilities (%dg spent) — total tiers now %d" % [
			upgraded, spent, new_total])
	elif not all_maxed:
		# Log what's blocking the next upgrade
		for facility_id in FACILITY_UPGRADE_PRIORITY:
			var current_tier: int = GameContext.get_facility_tier(town_id, facility_id)
			var max_tier: int = GameContext.get_facility_max_tier(facility_id)
			if current_tier >= max_tier:
				continue
			var cost: Dictionary = GameContext.get_facility_upgrade_cost(facility_id, current_tier + 1)
			var gold_cost: int = cost.get("gold", 0)
			var items_cost: Array = cost.get("items", [])
			if gold_cost > upgrade_budget:
				continue  # Over budget
			if items_cost.size() > 0:
				var missing: Array = []
				for req in items_cost:
					var have: int = GameContext.get_run_item_count(req.get("item_id", ""))
					var need: int = int(req.get("qty", 0))
					if have < need:
						missing.append("%s (%d/%d)" % [req.get("item_id", "?"), have, need])
				if missing.size() > 0:
					_log("Next upgrade: %s T%d needs %dg + %s" % [
						facility_id, current_tier + 1, gold_cost, ", ".join(missing)])
					break
		_log("No affordable facility upgrades (budget: %dg, gold: %dg)" % [upgrade_budget, GameContext.get_run_gold()])


## Check if all facilities in this town are at max tier.
func _all_facilities_maxed(town_id: String) -> bool:
	for facility_id in FACILITY_UPGRADE_PRIORITY:
		var current_tier: int = GameContext.get_facility_tier(town_id, facility_id)
		var max_tier: int = GameContext.get_facility_max_tier(facility_id)
		if current_tier < max_tier:
			return false
	return true


# ============================================================================
# RECRUIT HEROES
# ============================================================================

## Region-aware class filtering: native classes first, then inherited from earlier regions
func _get_available_classes_for_role(role: String) -> Array:
	var region: int = _current_target_region
	var role_list: Array = []
	match role:
		"tank": role_list = TANK_CLASSES
		"healer": role_list = HEALER_CLASSES
		"dps": role_list = DPS_CLASSES

	var native: Array = []     # unlock_region == current region
	var inherited: Array = []  # unlock_region < current region (sorted by region DESC = strongest first)
	for class_id in role_list:
		var cd = DataRegistry.get_class_data(class_id)
		if cd == null or cd.is_legacy:
			continue
		if cd.unlock_region == region:
			native.append(class_id)
		elif cd.unlock_region < region:
			# Insert sorted by unlock_region DESC (strongest first)
			var inserted: bool = false
			for i in range(inherited.size()):
				var other_cd = DataRegistry.get_class_data(inherited[i])
				if other_cd != null and cd.unlock_region > other_cd.unlock_region:
					inherited.insert(i, class_id)
					inserted = true
					break
			if not inserted:
				inherited.append(class_id)
	return native + inherited  # Native first, then strongest available


## Ideal race for each class role (best synergy pairings)
const ROLE_RACE_PREFERENCE: Dictionary = {
	"tank": ["dragonkin", "dwarf", "undead", "crystalborn"],  # Tanky races
	"healer": ["mossfolk", "tidelings", "human"],             # Regen/SPD/XP races
	"dps": ["human", "elf", "dragonkin", "voidwalkers"],      # XP/SPD/ATK races
}

## Pick a race for a recruit, preferring role-optimal races available at this region.
func _pick_recruit_race(role: String = "") -> String:
	var region: int = _current_target_region
	var available: Array = []
	for rd in DataRegistry.get_all_races():
		if rd.unlock_region <= region:
			available.append(rd.race_id)
	if available.is_empty():
		return "human"
	# Try role-optimal race first
	var prefs: Array = ROLE_RACE_PREFERENCE.get(role, [])
	for pref_race in prefs:
		if pref_race in available:
			return pref_race
	# Fallback: prefer native race (highest unlock_region)
	var best_race: String = available[0]
	var best_region: int = 0
	for rd in DataRegistry.get_all_races():
		if rd.race_id in available and rd.unlock_region > best_region:
			best_region = rd.unlock_region
			best_race = rd.race_id
	return best_race


func _recruit_heroes() -> void:
	# First: add benched heroes at current town to party (e.g. carried heroes from NG+)
	var town_id: String = GameContext.get_current_town_id()
	var bench_heroes: Array = GameContext.get_inn_bench_heroes(town_id)
	for bench_hero in bench_heroes:
		if GameContext.get_selected_party().size() >= 4:
			break
		var hid: String = bench_hero.get("hero_id", "")
		if hid != "" and hid not in GameContext.get_selected_party():
			GameContext.add_to_party(hid)
			_log("Added benched hero to party: %s (Lv%d, %s)" % [
				hid, int(bench_hero.get("level", 1)), bench_hero.get("class_id", "?")])

	var party = GameContext.get_selected_party()
	if party.size() >= 4:
		_log("Party full (%d/4) — skip recruiting" % party.size())
		return

	var needed = 4 - party.size()
	_log("Recruiting %d heroes in R%d (gold: %d)" % [needed, _current_target_region, GameContext.run_gold])

	var roles_needed: Array = _get_roles_needed()
	var recruit_cost: int = _get_regional_recruit_cost()
	var recruit_level: int = _get_regional_recruit_level()

	for role in roles_needed:
		if GameContext.run_gold < recruit_cost:
			_log("Not enough gold (%d) to recruit — stopping" % GameContext.run_gold)
			break
		var class_list: Array = _get_available_classes_for_role(role)

		var recruited = false
		for class_id in class_list:
			var race_id: String = _pick_recruit_race(role)
			var hero_id = GameContext.recruit_hero(class_id, recruit_cost, race_id, recruit_level)
			if hero_id != "":
				GameContext.add_to_party(hero_id)
				_log("Recruited %s (%s, Lv%d, %s) — added to party" % [class_id, race_id, recruit_level, hero_id])
				recruited = true
				break
		if not recruited:
			var fallback: Array = _get_available_classes_for_role("tank") + \
				_get_available_classes_for_role("healer") + _get_available_classes_for_role("dps")
			for fallback_class in fallback:
				var race_id: String = _pick_recruit_race("dps")
				var hero_id = GameContext.recruit_hero(fallback_class, recruit_cost, race_id, recruit_level)
				if hero_id != "":
					GameContext.add_to_party(hero_id)
					_log("Recruited %s (fallback, Lv%d, %s) — %s" % [fallback_class, recruit_level, race_id, hero_id])
					break

	PlaytestCapture.capture("inn_recruited")


## Get regional recruit level from inn.json regional_recruit_level_minimum.
func _get_regional_recruit_level() -> int:
	var recruit_level: int = 1
	var inn_data = DataRegistry.get_facility("inn") if DataRegistry.has_method("get_facility") else null
	if inn_data != null and inn_data.get("regional_recruit_level_minimum") != null:
		recruit_level = int(inn_data.regional_recruit_level_minimum.get(str(_current_target_region), 1))
	# Also check inn tier level
	var town_id: String = GameContext.get_current_town_id()
	var inn_tier: int = GameContext.get_facility_tier(town_id, "inn")
	if inn_data != null and inn_data.get("recruit_level_by_tier") != null:
		var tier_level: int = int(inn_data.recruit_level_by_tier.get(str(inn_tier), 1))
		recruit_level = maxi(recruit_level, tier_level)
	return recruit_level


## Get regional recruit cost (mirrors TownScene.RECRUIT_BASE_COST_BY_REGION).
func _get_regional_recruit_cost() -> int:
	var costs: Array = [0, 50, 75, 100, 140, 185, 240, 310]
	return costs[clampi(_current_target_region, 1, 7)]


func _get_roles_needed() -> Array:
	var party = GameContext.get_selected_party()
	var has_tank: bool = false
	var healer_count: int = 0
	var dps_count: int = 0

	for hero_id in party:
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue
		var class_id: String = hero.get("class_id", "")
		if class_id in TANK_CLASSES:
			has_tank = true
		elif class_id in HEALER_CLASSES:
			healer_count += 1
		else:
			dps_count += 1

	# R5+: target 2 healers for sustain against burst damage
	var target_healers: int = 2 if _current_target_region >= 5 else 1
	var roles: Array = []
	if not has_tank:
		roles.append("tank")
	while healer_count < target_healers:
		roles.append("healer")
		healer_count += 1
	var filled: int = (1 if has_tank else 0) + healer_count + dps_count
	while roles.size() + filled < 4:
		roles.append("dps")
	return roles

# ============================================================================
# EQUIP HEROES FROM STASH — all 7 slots with stat comparison
# ============================================================================

const EQUIP_SLOTS := ["bag", "weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet"]

func _equip_heroes_from_stash() -> void:
	var party = GameContext.get_selected_party()
	if party.is_empty():
		return
	if GameContext.run_items.is_empty():
		_log("Stash empty — nothing to equip")
		return
	_log("Equipping heroes from stash (%d items)" % GameContext.run_items.size())

	for hero_id in party:
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue
		var class_id: String = hero.get("class_id", "")
		var class_data = null
		if DataRegistry.has_method("get_class_data"):
			class_data = DataRegistry.get_class_data(class_id)

		for slot in EQUIP_SLOTS:
			var current_score: int = _get_equipped_score(hero_id, slot)
			var best_score: int = current_score
			var best_item_id: String = ""
			var best_quality: int = 0
			var best_affix: Dictionary = {}

			# Scan stash for best item for this slot
			for item in GameContext.run_items:
				var item_id: String = _get_item_id(item)
				if item_id == "":
					continue
				var template = DataRegistry.get_item_template(item_id)
				if template == null:
					continue
				if _get_template_field(template, "equip_slot") != slot:
					continue
				# Weapon restriction check
				if slot == "weapon" and class_data != null:
					var weapon_types: Array = []
					if "weapon_types" in class_data:
						weapon_types = class_data.weapon_types
					if weapon_types.size() > 0 and _get_template_field(template, "item_subtype") not in weapon_types:
						continue
				# Extract quality + affix from stash item
				var q: int = _get_item_quality(item)
				var affix: Dictionary = _get_item_affix_stats(item)
				var score: int = _calc_item_score(template, q, affix)
				if score > best_score:
					best_score = score
					best_item_id = item_id
					best_quality = q
					best_affix = _get_item_affix_data(item)

			if best_item_id != "" and best_score > current_score:
				if GameContext.equip_hero_item(hero_id, slot, best_item_id, best_quality, best_affix):
					_log("Equipped %s: %s in %s (score %d→%d)" % [hero_id, best_item_id, slot, current_score, best_score])
					await _action_delay()

	# Consumable distribution is done separately after all heroes are equipped


## Distribute healing consumables fairly: each hero gets 1 healing item before extras.
func _distribute_consumables_to_bags() -> void:
	var party = GameContext.get_selected_party()
	var distributed: int = 0
	for hero_id in party:
		# Check bag has room (used slots < capacity)
		var bag_used: int = GameContext.get_hero_bag(hero_id).size()
		var bag_cap: int = GameContext.get_hero_bag_capacity(hero_id)
		if bag_used >= bag_cap:
			continue
		# Check if hero already has a healing consumable
		var has_heal: bool = false
		for entry in GameContext.get_hero_bag(hero_id):
			var t = DataRegistry.get_item_template(entry.get("item_id", ""))
			if t != null and t.item_type == "consumable" and _is_heal_effect(t):
				has_heal = true
				break
		if has_heal:
			continue
		# Find and move a healing consumable from stash
		for item in GameContext.run_items.duplicate():
			var item_id: String = _get_item_id(item)
			if item_id == "":
				continue
			var template = DataRegistry.get_item_template(item_id)
			if template == null or template.item_type != "consumable":
				continue
			if not _is_heal_effect(template):
				continue
			if GameContext.move_item_stash_to_hero_bag(hero_id, item_id, 1):
				_log("Gave %s a %s" % [hero_id, item_id])
				distributed += 1
				break
	if distributed > 0:
		_log("Distributed %d healing consumables to hero bags" % distributed)
	else:
		_log("No healing consumables to distribute (stash has %d items)" % GameContext.run_items.size())


func _is_heal_effect(template) -> bool:
	var eff: String = _get_template_field(template, "use_effect")
	return eff in ["heal", "hot_heal", "heal_small", "heal_large", "heal_and_buff",
		"heal_and_buff_all", "heal_and_cure", "heal_and_regen", "heal_shield", "heal_regen_cleanse"]


func _is_buff_effect(template) -> bool:
	var eff: String = _get_template_field(template, "use_effect")
	return eff.begins_with("buff_")


## Distribute buff consumables to hero bags (1 per hero) for camp/combat use.
func _distribute_buff_consumables_to_bags() -> void:
	var party = GameContext.get_selected_party()
	var distributed: int = 0
	for hero_id in party:
		var bag_used: int = GameContext.get_hero_bag(hero_id).size()
		var bag_cap: int = GameContext.get_hero_bag_capacity(hero_id)
		if bag_used >= bag_cap:
			continue
		# Check if hero already has a buff consumable
		var has_buff: bool = false
		for entry in GameContext.get_hero_bag(hero_id):
			var t = DataRegistry.get_item_template(entry.get("item_id", ""))
			if t != null and t.item_type == "consumable" and _is_buff_effect(t):
				has_buff = true
				break
		if has_buff:
			continue
		# Find and move a buff consumable from stash
		for item in GameContext.run_items.duplicate():
			var item_id: String = _get_item_id(item)
			if item_id == "":
				continue
			var template = DataRegistry.get_item_template(item_id)
			if template == null or template.item_type != "consumable":
				continue
			if not _is_buff_effect(template):
				continue
			if GameContext.move_item_stash_to_hero_bag(hero_id, item_id, 1):
				_log("Gave %s a buff: %s" % [hero_id, item_id])
				distributed += 1
				break
	if distributed > 0:
		_log("Distributed %d buff consumables to hero bags" % distributed)


func _get_item_qty(item) -> int:
	if item is Dictionary:
		return int(item.get("qty", 1))
	if "qty" in item:
		return int(item.qty)
	return 1

# ============================================================================
# PRE-SHOP CRAFTING — mix healing consumables before allocating shop slots
# ============================================================================

## Craft healing consumables from stash materials at Chef/Alchemist.
## Called before shop allocation to reduce heal_gap and free slots for gear.
func _craft_healing_consumables() -> void:
	var town_id: String = GameContext.get_current_town_id()
	var crafted_total: int = 0

	for facility_id in ["chef", "alchemist"]:
		var tier: int = GameContext.get_facility_tier(town_id, facility_id)
		if tier < 1:
			continue
		var recipes: Array = DataRegistry.get_mixing_recipes(facility_id)

		# Filter to heal recipes within current facility tier
		var heal_recipes: Array = []
		for recipe in recipes:
			if recipe.get("required_tier", 1) > tier:
				continue
			var output_id: String = recipe.get("output_id", "")
			var tpl = DataRegistry.get_item_template(output_id)
			if tpl != null and tpl.item_type == "consumable" and _is_heal_effect(tpl):
				heal_recipes.append(recipe)

		# Try to craft each heal recipe while ingredients are available
		for recipe in heal_recipes:
			var max_crafts: int = 3  # Cap per recipe per town visit
			for _i in range(max_crafts):
				var stash: Dictionary = GameContext.get_run_items_dict()
				var inputs: Dictionary = {}
				for key in ["input_a", "input_b", "input_c"]:
					var iid: String = recipe.get(key, "")
					if iid != "":
						inputs[iid] = inputs.get(iid, 0) + 1

				# Check all ingredients available
				var can_craft: bool = true
				for iid in inputs:
					if stash.get(iid, 0) < inputs[iid]:
						can_craft = false
						break
				if not can_craft:
					break

				# Consume ingredients and produce output
				for iid in inputs:
					GameContext.remove_run_item(iid, inputs[iid])
				var output_id: String = recipe.get("output_id", "")
				var output_qty: int = recipe.get("output_qty", 1)
				GameContext.add_run_item(output_id, output_qty)
				crafted_total += output_qty

				var tpl = DataRegistry.get_item_template(output_id)
				var dname: String = tpl.display_name if tpl != null else output_id
				_log("Crafted %s x%d at %s" % [dname, output_qty, facility_id])

	if crafted_total > 0:
		_log("Pre-shop crafting: %d healing consumables crafted" % crafted_total)
	else:
		_log("No craftable healing recipes (missing ingredients or facilities)")


## Craft combat buff consumables (DEF, ATK, SPD potions) at alchemist.
func _craft_combat_buffs() -> void:
	var town_id: String = GameContext.get_current_town_id()
	var tier: int = GameContext.get_facility_tier(town_id, "alchemist")
	if tier < 2:
		return  # Need T2 alchemist for buff recipes
	var recipes: Array = DataRegistry.get_mixing_recipes("alchemist")
	var crafted: int = 0
	for recipe in recipes:
		if recipe.get("required_tier", 1) > tier:
			continue
		var output_id: String = recipe.get("output_id", "")
		var tpl = DataRegistry.get_item_template(output_id)
		if tpl == null or tpl.item_type != "consumable":
			continue
		var eff: String = _get_template_field(tpl, "use_effect")
		if not eff.begins_with("buff_"):
			continue
		# Craft 1 of each buff type
		var stash: Dictionary = GameContext.get_run_items_dict()
		var inputs: Dictionary = {}
		for key in ["input_a", "input_b", "input_c"]:
			var iid: String = recipe.get(key, "")
			if iid != "":
				inputs[iid] = inputs.get(iid, 0) + 1
		var can_craft: bool = true
		for iid in inputs:
			if stash.get(iid, 0) < inputs[iid]:
				can_craft = false
				break
		if not can_craft:
			continue
		for iid in inputs:
			GameContext.remove_run_item(iid, inputs[iid])
		var output_qty: int = recipe.get("output_qty", 1)
		GameContext.add_run_item(output_id, output_qty)
		crafted += output_qty
		var dname: String = tpl.display_name if tpl != null else output_id
		_log("Crafted buff: %s x%d" % [dname, output_qty])
	if crafted > 0:
		_log("Combat buffs crafted: %d items" % crafted)


## Craft equipment at blacksmith/huntsman/enchanter for heroes missing gear.
## Priority: weapon > armor > offhand (weapon boosts kill speed → less incoming damage).
func _craft_equipment() -> void:
	var town_id: String = GameContext.get_current_town_id()
	var party = GameContext.get_selected_party()
	if party.is_empty():
		return

	# Collect which equip slots the party needs
	var needs: Array = []  # [{hero_id, slot, class_data}]
	var slot_priority: Array = ["weapon", "armor", "offhand", "helmet", "legs", "ring", "amulet"]
	for hero_id in party:
		var hero = GameContext.get_hero(hero_id)
		if hero.is_empty():
			continue
		var equipment: Dictionary = GameContext.get_hero_equipment(hero_id)
		var cd = DataRegistry.get_class_data(hero.get("class_id", ""))
		for slot in slot_priority:
			var slot_data: Dictionary = equipment.get(slot, {})
			if slot_data.get("id", "") == "":
				needs.append({"hero_id": hero_id, "slot": slot, "class_data": cd})

	if needs.is_empty():
		return

	var crafted_total: int = 0
	var equipment_facilities: Array = ["blacksmith", "huntsman", "enchanter"]

	for facility_id in equipment_facilities:
		var facility = DataRegistry.get_facility(facility_id)
		if facility == null:
			continue
		var tier: int = GameContext.get_facility_tier(town_id, facility_id)
		if tier < 1:
			continue

		for recipe in facility.crafting_recipes:
			if recipe.get("required_tier", 1) > tier:
				continue
			var output_id: String = recipe.get("output_id", "")
			var tpl = DataRegistry.get_item_template(output_id)
			if tpl == null or tpl.item_type != "equipment":
				continue

			var equip_slot: String = _get_template_field(tpl, "equip_slot")
			if equip_slot == "":
				continue

			# Check if any hero needs this slot and can use this item
			var matched_need: Dictionary = {}
			for need in needs:
				if need["slot"] != equip_slot:
					continue
				# Weapon restriction check
				if equip_slot == "weapon" and need["class_data"] != null:
					var weapon_types: Array = []
					if "weapon_types" in need["class_data"]:
						weapon_types = need["class_data"].weapon_types
					if weapon_types.size() > 0 and _get_template_field(tpl, "item_subtype") not in weapon_types:
						continue
				matched_need = need
				break

			if matched_need.is_empty():
				continue

			# Check ingredients
			var craft_inputs: Array = recipe.get("craft_inputs", [])
			var stash: Dictionary = GameContext.get_run_items_dict()
			var can_craft: bool = true
			for input_item in craft_inputs:
				var iid: String = input_item.get("item_id", "")
				var qty: int = int(input_item.get("qty", 1))
				if stash.get(iid, 0) < qty:
					can_craft = false
					break
			if not can_craft:
				continue

			# Consume ingredients and add crafted item to stash
			for input_item in craft_inputs:
				var iid: String = input_item.get("item_id", "")
				var qty: int = int(input_item.get("qty", 1))
				GameContext.remove_run_item(iid, qty)
			GameContext.add_run_item(output_id, 1)
			crafted_total += 1
			var dname: String = tpl.display_name if tpl != null else output_id
			_log("Crafted equipment: %s for %s slot" % [dname, equip_slot])

			# Remove this need so we don't craft duplicates for the same hero+slot
			needs.erase(matched_need)
			if needs.is_empty():
				break
		if needs.is_empty():
			break

	if crafted_total > 0:
		_log("Equipment crafting: %d items crafted" % crafted_total)


# ============================================================================
# SHOP PURCHASING — allocate slots, generate items, buy upgrades
# ============================================================================

## Smart shop allocation — checks hero needs before deciding.
## Heroes need heals → alchemist/chef priority. Heroes have heals → gear priority.
func _allocate_shop_slots() -> void:
	var town_id: String = GameContext.get_current_town_id()
	var max_slots: int = GameContext.get_shop_max_slots(town_id)
	var current_allocated: int = GameContext.get_shop_allocated_slots(town_id)
	if current_allocated > 0:
		_log("Shop already allocated (%d slots)" % current_allocated)
		return

	# Check how many heroes need healing consumables
	var party = GameContext.get_selected_party()
	var heroes_needing_heal: int = 0
	for hero_id in party:
		var has_heal: bool = false
		for entry in GameContext.get_hero_bag(hero_id):
			var t = DataRegistry.get_item_template(entry.get("item_id", ""))
			if t != null and t.item_type == "consumable" and _is_heal_effect(t):
				has_heal = true
				break
		if not has_heal:
			heroes_needing_heal += 1

	# Also check stash for healing consumables available to distribute
	var stash_heals: int = 0
	for item in GameContext.run_items:
		var item_id: String = _get_item_id(item)
		if item_id == "":
			continue
		var t = DataRegistry.get_item_template(item_id)
		if t != null and t.item_type == "consumable" and _is_heal_effect(t):
			stash_heals += _get_item_qty(item)

	# How many heroes still need a heal after stash distribution?
	var heal_gap: int = maxi(heroes_needing_heal - stash_heals, 0)

	var allocs: Dictionary = {}
	if heal_gap >= 2:
		# Multiple heroes need heals — consumable-heavy with bags
		_log("Heal gap=%d (%d need, %d in stash) — consumable priority" % [heal_gap, heroes_needing_heal, stash_heals])
		match max_slots:
			1: allocs = {"chef": 1}
			2: allocs = {"chef": 1, "alchemist": 1}
			3: allocs = {"chef": 1, "alchemist": 1, "huntsman": 1}
			_:
				allocs = {"chef": 1, "alchemist": 1, "blacksmith": 1, "huntsman": 1}
				var remaining: int = max_slots - 4
				if remaining >= 1:
					allocs["chef"] += 1
					remaining -= 1
				if remaining >= 1:
					allocs["enchanter"] = 1
					remaining -= 1
				if remaining >= 1:
					allocs["blacksmith"] += remaining
	elif heal_gap == 1:
		# Just 1 hero short — 1 chef slot (82% heal rate), rest gear + bags
		_log("Heal gap=1 — 1 chef slot, rest gear")
		match max_slots:
			1: allocs = {"chef": 1}
			2: allocs = {"chef": 1, "blacksmith": 1}
			3: allocs = {"chef": 1, "blacksmith": 1, "huntsman": 1}
			_:
				allocs = {"chef": 1, "blacksmith": 1, "huntsman": 1, "enchanter": 1}
				var remaining: int = max_slots - 4
				if remaining >= 1:
					allocs["blacksmith"] += 1
					remaining -= 1
				if remaining >= 1:
					allocs["huntsman"] += 1
					remaining -= 1
				if remaining >= 1:
					allocs["alchemist"] = remaining
	else:
		# All heroes have heals — full gear + bags
		_log("All heroes have consumables — full gear")
		match max_slots:
			1: allocs = {"blacksmith": 1}
			2: allocs = {"blacksmith": 1, "huntsman": 1}
			3: allocs = {"blacksmith": 1, "huntsman": 1, "enchanter": 1}
			_:
				allocs = {"blacksmith": 1, "huntsman": 1, "enchanter": 1, "alchemist": 1}
				var remaining: int = max_slots - 4
				if remaining >= 1:
					allocs["blacksmith"] += 1
					remaining -= 1
				if remaining >= 1:
					allocs["huntsman"] += 1
					remaining -= 1
				if remaining >= 1:
					allocs["chef"] = remaining

	# Set allocations directly (avoid save_game side effects)
	if not GameContext.shop_slot_allocations.has(town_id):
		GameContext.shop_slot_allocations[town_id] = {}
	for facility_id in allocs:
		GameContext.shop_slot_allocations[town_id][facility_id] = allocs[facility_id]
	_log("Allocated shop: %s (total %d/%d)" % [str(allocs), max_slots, max_slots])


## Generate shop items using same seeded RNG as TownScene._generate_facility_allocated_items().
func _generate_shop_items() -> Array:
	var town_id: String = GameContext.get_current_town_id()
	var shop_id: String = town_id.replace("town_", "shop_")
	var region_id: String = GameContext.get_current_region_id()
	var town_tier: int = GameContext.get_town_tier(town_id)
	var restock_ver: int = GameContext.get_shop_restock_version(shop_id)
	var run_seed: int = GameContext.get_run_seed()
	var affix: Dictionary = {}
	if DataRegistry.has_method("get_regional_affix"):
		affix = DataRegistry.get_regional_affix(region_id)

	var base_shop_seed: int = SeededRNG.shop_seed(region_id, town_id, restock_ver, run_seed)
	var seed_str = "%s_%d_%d" % [shop_id, town_tier, base_shop_seed]
	var shop_rng = RandomNumberGenerator.new()
	shop_rng.seed = seed_str.hash()

	var result: Array = []
	for facility_id in GameContext.SHOP_CONTRIBUTING_FACILITIES:
		var slots: int = GameContext.get_facility_slot_allocation(town_id, facility_id)
		if slots <= 0:
			continue
		var fac_data = null
		if DataRegistry.has_method("get_facility"):
			fac_data = DataRegistry.get_facility(facility_id)
		var recipes: Array = []
		if fac_data != null and "mixing_recipe_file" in fac_data and fac_data.mixing_recipe_file != "":
			recipes = GameContext.get_facility_shop_recipes(facility_id)
		else:
			recipes = GameContext.get_facility_unlocked_recipes(facility_id)
		if recipes.is_empty():
			continue
		var current_fac_tier: int = GameContext.get_facility_tier(town_id, facility_id)
		var facility_seed: int = SeededRNG.derive_seed(facility_id, shop_rng.seed)
		var facility_rng = RandomNumberGenerator.new()
		facility_rng.seed = facility_seed
		for i in range(slots):
			var slot_key = "%s:%d" % [facility_id, i]
			if GameContext.is_shop_slot_purchased(shop_id, slot_key):
				# Still consume RNG to keep determinism
				facility_rng.randi()
				facility_rng.randf()
				continue
			var recipe_idx: int = facility_rng.randi() % recipes.size()
			var recipe_entry: Dictionary = recipes[recipe_idx]
			var item_id: String = recipe_entry.get("item_id", "")
			var upgrade_tier: int = int(recipe_entry.get("upgrade_tier", 1))
			var template = DataRegistry.get_item_template(item_id)
			if template == null:
				facility_rng.randf()  # Consume quality roll to stay in sync
				continue
			var quality_roll = facility_rng.randf() * 100.0
			var quality_tier: int = _roll_shop_quality(quality_roll, current_fac_tier)
			var base_price: int = template.get_buy_value()
			var quality_mult: Array = [1.0, 1.2, 1.5, 2.0]
			var affix_mult: float = 1.0
			if upgrade_tier >= 2:
				affix_mult = 1.0 + (0.25 * (upgrade_tier - 1))
			var final_price: int = int(base_price * quality_mult[quality_tier] * affix_mult)
			if current_fac_tier >= 3:
				final_price = int(final_price * 0.75)
			var shop_affix: Dictionary = {}
			if upgrade_tier >= 2 and not affix.is_empty():
				shop_affix = {
					"source_region": region_id, "affix_id": region_id,
					"affix_stats": affix.get("stat_bonus", {}),
					"affix_prefix": affix.get("prefix", "")
				}
			result.append({
				"item_id": item_id, "price_gold": final_price,
				"quality_tier": quality_tier, "slot_key": slot_key,
				"affix_data": shop_affix, "upgrade_tier": upgrade_tier,
			})
	_log("Generated %d shop items" % result.size())
	return result


func _roll_shop_quality(roll: float, facility_tier: int) -> int:
	match facility_tier:
		1: return 0
		2, 3:
			if roll < 75.0: return 0
			elif roll < 95.0: return 1
			else: return 2
		4:
			if roll < 50.0: return 0
			elif roll < 80.0: return 1
			elif roll < 95.0: return 2
			else: return 3
		_: return 0


## Buy equipment upgrades and consumables from generated shop items.
func _shop_buy_upgrades() -> void:
	_allocate_shop_slots()
	var shop_items: Array = _generate_shop_items()
	if shop_items.is_empty():
		_log("No shop items available")
		return

	var town_id: String = GameContext.get_current_town_id()
	var shop_id: String = town_id.replace("town_", "shop_")
	var party = GameContext.get_selected_party()
	var bought: int = 0

	for shop_item in shop_items:
		var item_id: String = shop_item["item_id"]
		var price: int = shop_item["price_gold"]
		var quality: int = shop_item["quality_tier"]
		var affix_data: Dictionary = shop_item["affix_data"]
		var slot_key: String = shop_item["slot_key"]

		var template = DataRegistry.get_item_template(item_id)
		if template == null:
			continue
		var equip_slot: String = _get_template_field(template, "equip_slot")
		var item_type: String = _get_template_field(template, "item_type")

		# Skip if can't afford or would dip below recruit reserve
		var recruit_reserve: int = _get_recruit_reserve()
		if GameContext.get_run_gold() < price:
			continue
		if GameContext.get_run_gold() - price < recruit_reserve:
			continue

		# Equipment: buy only if it's an upgrade for any hero
		if equip_slot != "":
			var affix_stats: Dictionary = affix_data.get("affix_stats", {})
			var item_score: int = _calc_item_score(template, quality, affix_stats)
			var is_upgrade: bool = false
			for hero_id in party:
				var hero = GameContext.get_hero(hero_id)
				if hero.is_empty():
					continue
				# Weapon class restriction
				if equip_slot == "weapon":
					var class_id: String = hero.get("class_id", "")
					var class_data = null
					if DataRegistry.has_method("get_class_data"):
						class_data = DataRegistry.get_class_data(class_id)
					if class_data != null:
						var weapon_types: Array = []
						if "weapon_types" in class_data:
							weapon_types = class_data.weapon_types
						if weapon_types.size() > 0 and _get_template_field(template, "item_subtype") not in weapon_types:
							continue
				var current_score: int = _get_equipped_score(hero_id, equip_slot)
				if item_score > current_score:
					is_upgrade = true
					break
			if not is_upgrade:
				continue

		# Consumable: buy healing items — ensure each hero can have 1+ in bag
		elif item_type == "consumable":
			var use_effect: String = _get_template_field(template, "use_effect")
			if use_effect not in ["heal", "hot_heal", "heal_and_buff", "heal_and_buff_all",
					"heal_and_cure", "heal_and_regen", "heal_shield", "heal_regen_cleanse",
					"cure_poison", "cure_all", "cure_stun", "cure_bleeding", "cleanse"]:
				continue
			var stash_count: int = GameContext.get_run_item_count(item_id)
			if stash_count >= party.size():
				continue
		else:
			continue  # Skip materials etc.

		# Purchase: spend gold + add to stash
		GameContext.spend_run_gold(price)
		if quality > 0 or not affix_data.is_empty():
			GameContext._add_item_with_quality(item_id, quality, affix_data)
		else:
			GameContext.add_run_item(item_id, 1)
		GameContext.mark_shop_slot_purchased(shop_id, slot_key)
		bought += 1
		_log("Bought %s (q%d) for %dg — %dg remaining" % [item_id, quality, price, GameContext.get_run_gold()])
		await _action_delay()

	_log("Shop: bought %d items, %dg remaining" % [bought, GameContext.get_run_gold()])

# ============================================================================
# BANK BAGS TO STASH — move loot from bags to stash on town return
# ============================================================================

func _bank_bags_to_stash() -> void:
	# Bank shopkeeper bag
	if GameContext.shopkeeper_bag.size() > 0:
		GameContext.bank_shopkeeper_bag_to_stash()
		_log("Banked shopkeeper bag to stash")
	# Bank hero bags to stash so equip logic can see everything
	for hero_id in GameContext.get_selected_party():
		var bag: Array = GameContext.get_hero_bag(hero_id)
		for entry in bag.duplicate():
			var item_id: String = entry.get("item_id", "")
			var qty: int = int(entry.get("qty", 1))
			if item_id != "":
				GameContext.move_item_hero_bag_to_stash(hero_id, item_id, qty)
	_log("Banked all bags to stash (%d stash items)" % GameContext.run_items.size())

# ============================================================================
# BASE MATERIAL FARMING — detect when facility upgrades need F1 drops
# ============================================================================

const BASE_MATERIALS := ["wood_bundle", "herb_sprig", "iron_scrap", "wolf_pelt",
	"bone_fragment", "spider_silk", "raw_meat", "forest_mushroom", "wild_berries"]

## Returns true if any facility upgrade is ONLY blocked on base materials (from lt_base_materials).
func _needs_base_materials_for_upgrades() -> bool:
	var town_id: String = GameContext.get_current_town_id()
	if _all_facilities_maxed(town_id):
		return false
	# Once we've mastered F2, stop farming and push forward to the boss
	# We'll still pick up materials along the way on deeper floors
	var region_key: String = "region_%d" % _current_target_region
	var dungeon_id: String = REGION_DATA.get(region_key, {}).get("dungeon", "")
	var mastered_floor: int = GameContext.get_selected_start_floor(dungeon_id)
	if mastered_floor >= 2:
		return false
	for facility_id in FACILITY_UPGRADE_PRIORITY:
		var current_tier: int = GameContext.get_facility_tier(town_id, facility_id)
		var max_tier: int = GameContext.get_facility_max_tier(facility_id)
		if current_tier >= max_tier:
			continue
		var cost: Dictionary = GameContext.get_facility_upgrade_cost(facility_id, current_tier + 1)
		var gold_cost: int = cost.get("gold", 0)
		if gold_cost > GameContext.get_run_gold() / 2:
			continue
		var items_cost: Array = cost.get("items", [])
		var needs_base: bool = false
		var has_non_base_gap: bool = false
		for req in items_cost:
			var item_id: String = req.get("item_id", "")
			var need: int = int(req.get("qty", 0))
			var have: int = GameContext.get_run_item_count(item_id)
			if have < need:
				if item_id in BASE_MATERIALS:
					needs_base = true
				else:
					has_non_base_gap = true
		if needs_base and not has_non_base_gap:
			return true
	return false

# ============================================================================
# ENTER DUNGEON — FIX 4: Direct handoff to combat
# ============================================================================

func _enter_dungeon() -> void:
	var party = GameContext.get_selected_party()
	if party.size() < 1:
		_log("Cannot enter dungeon — no heroes! Ending run.")
		_end_run("no_heroes")
		return

	var region_key = "region_%d" % _current_target_region
	var data = REGION_DATA.get(region_key, {})
	var dungeon_id: String = data.get("dungeon", "")
	if dungeon_id == "":
		_log("No dungeon for %s — ending run" % region_key)
		_end_run("no_dungeon")
		return

	# Base material farming: if facility upgrades are blocked on F1-only materials, farm F1
	var mastered_floor: int = GameContext.get_selected_start_floor(dungeon_id)
	var min_lvl: int = _get_min_party_level()
	var farm_base: bool = _needs_base_materials_for_upgrades()

	if farm_base:
		_log("Base materials needed for facility upgrades — farming F1 (mastered F%d preserved)" % mastered_floor)
		GameContext.set_selected_start_floor(dungeon_id, 1)
		PlaytestCapture.capture("dungeon_enter")
		GameContext.enter_dungeon(dungeon_id)
		GameContext.set_selected_start_floor(dungeon_id, mastered_floor)
	else:
		# Region-scaled leveling: check if heroes need training on a lower floor
		var leveling_tiers: Dictionary = REGION_LEVELING_TIERS.get(
			_current_target_region, {5: 1, 10: 2})
		var train_floor: int = 0  # 0 = no training needed
		for threshold in leveling_tiers:
			var floor_num: int = leveling_tiers[threshold]
			if min_lvl < threshold and mastered_floor > floor_num:
				if train_floor == 0 or floor_num < train_floor:
					train_floor = floor_num  # Pick lowest eligible training floor (F1)

		if train_floor > 0 and train_floor >= mastered_floor - 1:
			_log("Recruit leveling: min Lv%d — F%d run (mastered F%d preserved)" % [
				min_lvl, train_floor, mastered_floor])
			GameContext.set_selected_start_floor(dungeon_id, train_floor)
			PlaytestCapture.capture("dungeon_enter")
			GameContext.enter_dungeon(dungeon_id)
			GameContext.set_selected_start_floor(dungeon_id, mastered_floor)
		else:
			if mastered_floor > 1:
				_log("All heroes Lv%d+ — resuming at mastered F%d" % [min_lvl, mastered_floor])
			_log("Entering dungeon: %s (party=%d, gold=%d, F%d)" % [
				dungeon_id, party.size(), GameContext.run_gold, mastered_floor])
			PlaytestCapture.capture("dungeon_enter")
			GameContext.enter_dungeon(dungeon_id)

	# FIX v5: Release phase lock BEFORE setting phase so _on_phase_changed catches COMBAT.
	# This prevents the nested-coroutine stall on 2nd+ dungeon runs.
	_handling_phase = false

	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	# _on_phase_changed(COMBAT) fires synchronously here and starts its 1.5s timer

	await _wait_frames(3)
	SceneTransition.fade_to(BOOT_SCENE)
	# Phase handler's 1.5s + 10 frames wait covers the scene transition
	# DO NOT call _handle_combat() here — phase handler does it

# ============================================================================
# COMBAT HANDLER
# ============================================================================

func _handle_combat() -> void:
	_combat_ended_handled = false  # Reset guard for this combat
	_log("Combat phase — finding controller")
	PlaytestCapture.capture("combat_start")

	var scene = get_tree().current_scene
	if scene == null:
		_log("WARNING: No current scene in combat phase")
		return

	# Find _combat_controller on scene — retry if not ready
	var controller = _get_combat_controller(scene)
	if controller == null:
		for retry in range(5):
			await _wait_frames(20)
			scene = get_tree().current_scene
			if scene != null:
				controller = _get_combat_controller(scene)
			if controller != null:
				break
			_log("Retry %d: waiting for combat controller..." % (retry + 1))
	if controller == null:
		_log("WARNING: Could not find _combat_controller on scene")
		return

	_log("Connected to combat controller")
	_combat_connected = true
	_combat_last_signal_ms = Time.get_ticks_msec()
	_stall_recovery_fails = 0

	# Phase 8: Auto-confirm placement phase (keep default formation)
	if controller.has_method("is_placement_phase") and controller.is_placement_phase():
		_log("Placement phase — auto-confirming default formation")
		await _action_delay()
		controller.confirm_placement()

	# Connect signals (check not already connected)
	if not controller.player_input_required.is_connected(_on_player_input_required):
		controller.player_input_required.connect(_on_player_input_required)
	if not controller.target_selection_required.is_connected(_on_target_selection_required):
		controller.target_selection_required.connect(_on_target_selection_required)
	if not controller.combat_ended.is_connected(_on_combat_ended):
		controller.combat_ended.connect(_on_combat_ended)

	# If combat already emitted player_input_required before we connected,
	# re-trigger it via cancel_player_action (which re-emits the signal)
	if controller.has_method("is_awaiting_player_input") and controller.is_awaiting_player_input():
		_log("Combat already awaiting input — re-triggering signal")
		controller.cancel_player_action()


func _on_player_input_required(unit, available_actions: Array) -> void:
	if not _active:
		return
	_combat_last_signal_ms = Time.get_ticks_msec()

	var controller = _get_combat_controller(get_tree().current_scene)
	if controller == null:
		return

	# Try consumable first — heal lowest-HP ally if below 50%
	if _try_use_consumable(unit, controller):
		return  # Consumable submitted, don't submit a normal action

	# Role-aware ability selection
	var unit_name: String = unit.unit_name if "unit_name" in unit else str(unit)
	var class_id: String = unit.class_id if "class_id" in unit else ""
	var role: String = "dps"
	if class_id in TANK_CLASSES:
		role = "tank"
	elif class_id in HEALER_CLASSES:
		role = "healer"

	var lowest_ally_pct: float = _get_lowest_ally_hp_pct(controller)
	var chosen_type: String = _pick_ability_for_role(role, available_actions, lowest_ally_pct)
	_log("Player input: %s (%s) → %s (ally HP %.0f%%)" % [unit_name, role, chosen_type, lowest_ally_pct * 100])
	await _action_delay()
	if not is_instance_valid(controller):
		return
	controller.submit_player_action(chosen_type)


## Try to use a healing consumable on the lowest-HP ally (below 65%).
## Searches ALL party heroes' bags — any hero can use any bag's consumable on their turn.
## Returns true if consumable was submitted (skips normal action).
func _try_use_consumable(unit, controller) -> bool:
	var hero_id: String = unit.unit_id if "unit_id" in unit else ""
	if hero_id == "" or not hero_id.begins_with("hero_"):
		return false

	# Find lowest HP% alive player unit
	var lowest_unit = null
	var lowest_pct: float = 1.0
	if "_player_units" in controller:
		for pu in controller._player_units:
			if not pu.is_alive:
				continue
			var pct: float = float(pu.current_health) / float(pu.max_health) if pu.max_health > 0 else 1.0
			if pct < lowest_pct:
				lowest_pct = pct
				lowest_unit = pu

	# Scale heal threshold: R4=85%, R5+=90% (enemies can kill from 80% in 1-2 actions)
	var heal_threshold: float = 0.80
	if _current_target_region == 4:
		heal_threshold = 0.85
	elif _current_target_region >= 5:
		heal_threshold = 0.90
	if lowest_unit == null or lowest_pct >= heal_threshold:
		return false

	# Search ALL party heroes' bags for a healing consumable (not just acting hero's bag).
	# submit_consumable_use() tracks usage per bag owner (1 per hero per combat).
	var heal_item_id: String = ""
	var source_hero: String = ""
	for party_hero_id in GameContext.get_selected_party():
		if not GameContext.can_hero_use_consumable(party_hero_id):
			continue  # This bag owner already used their consumable this combat
		var info: Dictionary = GameContext.find_healing_consumable(party_hero_id)
		if not info.is_empty() and info.get("source", "") == "hero_bag":
			heal_item_id = info["item_id"]
			source_hero = party_hero_id
			break

	if heal_item_id == "":
		return false

	# Use it on the lowest-HP ally — submit_consumable_use needs persistent source_id, not combat unit_id
	var target_id: String = lowest_unit.source_id if "source_id" in lowest_unit else ""
	if target_id == "":
		return false

	controller.submit_consumable_use(heal_item_id, target_id, false, source_hero)
	_log("Used %s on %s (HP %.0f%%, from %s's bag)" % [heal_item_id, target_id, lowest_pct * 100, source_hero])
	return true


## Get lowest HP% among alive player units.
func _get_lowest_ally_hp_pct(controller) -> float:
	var lowest: float = 1.0
	if controller != null and "_player_units" in controller:
		for pu in controller._player_units:
			if not pu.is_alive:
				continue
			var pct: float = float(pu.current_health) / float(pu.max_health) if pu.max_health > 0 else 1.0
			if pct < lowest:
				lowest = pct
	return lowest


## Role-aware ability picker: healers heal when needed, tanks buff, DPS damage.
func _pick_ability_for_role(role: String, available_actions: Array, lowest_ally_pct: float) -> String:
	# Classify each enabled ability by effect_type
	var heals: Array = []   # action types that heal allies
	var buffs: Array = []   # action types that buff self/allies
	var damage: Array = []  # action types that damage enemies
	var drains: Array = []  # damage_and_heal (life_drain)

	for action in available_actions:
		if not action.get("enabled", false):
			continue
		var atype: String = action.get("type", "")
		if atype == "pass" or atype == "move":
			continue  # Never select pass or move — bot doesn't handle tile selection
		if atype == "basic":
			damage.append(atype)
			continue
		var ability = action.get("ability", null)
		if ability == null:
			damage.append(atype)
			continue
		var eff: String = ability.effect_type if "effect_type" in ability else "damage"
		match eff:
			"heal":
				heals.append(atype)
			"buff":
				buffs.append(atype)
			"damage_and_heal":
				drains.append(atype)
			_:
				damage.append(atype)

	match role:
		"healer":
			# Heal when any ally is below 70% HP
			if lowest_ally_pct < 0.70:
				if heals.size() > 0:
					return heals[0]
				if drains.size() > 0:
					return drains[0]  # life_drain: damages + heals
			# Nobody hurt — deal damage instead of wasting heals
			if drains.size() > 0:
				return drains[0]
			if damage.size() > 0:
				# Prefer ability damage over basic
				for d in damage:
					if d != "basic":
						return d
				return damage[0]
			# Fallback: heal anyway (better than nothing)
			if heals.size() > 0:
				return heals[0]
		"tank":
			# Use self-buff abilities (flame_guard, prism_barrier) when available
			if buffs.size() > 0:
				return buffs[0]
			# Otherwise deal damage
			if damage.size() > 0:
				for d in damage:
					if d != "basic":
						return d
				return damage[0]
		"dps", _:
			# DPS: damage abilities first, then drains, then basic
			if damage.size() > 0:
				for d in damage:
					if d != "basic":
						return d
			if drains.size() > 0:
				return drains[0]
			if damage.size() > 0:
				return damage[0]
	return "basic"


## FIX 3: valid_targets are Dictionaries {unit_id, name, is_ally}, NOT CombatUnit objects.
## Now handles ally-targeting abilities (heals, buffs) by picking lowest-HP ally.
func _on_target_selection_required(unit, valid_targets: Array, action_type: String, ability) -> void:
	if not _active or valid_targets.is_empty():
		return
	_combat_last_signal_ms = Time.get_ticks_msec()

	var target_id: String = ""

	# Single entry: AoE or self-target — just use it
	if valid_targets.size() == 1:
		target_id = valid_targets[0].get("unit_id", "")
	else:
		# Detect ally-targeting abilities (heals, buffs)
		var is_ally_ability: bool = false
		if ability != null:
			var target_team: String = ability.target_team if "target_team" in ability else "enemy"
			if target_team in ["ally", "self"]:
				is_ally_ability = true

		if is_ally_ability:
			target_id = _pick_ally_target(valid_targets)
		else:
			target_id = _pick_enemy_target(valid_targets)

	if target_id != "":
		_log("Target selected: %s" % target_id)
		await _action_delay()
		if not is_inside_tree():
			return
		var controller = _get_combat_controller(get_tree().current_scene)
		if controller and is_instance_valid(controller):
			controller.submit_player_target(target_id)


## Pick the lowest-HP ally from valid_targets for heal/buff abilities.
func _pick_ally_target(valid_targets: Array) -> String:
	var controller = _get_combat_controller(get_tree().current_scene)
	var best_id: String = ""
	var lowest_pct: float = 2.0
	for t in valid_targets:
		if not t.get("is_ally", false):
			continue
		var tid: String = t.get("unit_id", "")
		if controller != null and "_player_units" in controller:
			for pu in controller._player_units:
				if pu.unit_id == tid and pu.is_alive:
					var pct: float = float(pu.current_health) / float(pu.max_health) if pu.max_health > 0 else 1.0
					if pct < lowest_pct:
						lowest_pct = pct
						best_id = tid
					break
	# Fallback: first ally entry
	if best_id == "":
		for t in valid_targets:
			if t.get("is_ally", false):
				best_id = t.get("unit_id", "")
				break
	# Last resort: first entry
	if best_id == "":
		best_id = valid_targets[0].get("unit_id", "")
	return best_id


## Pick the best enemy target — focus-fire low-HP enemies and mages.
func _pick_enemy_target(valid_targets: Array) -> String:
	var controller = _get_combat_controller(get_tree().current_scene)
	var best_id: String = ""
	var best_score: int = -1
	for t in valid_targets:
		if t.get("is_ally", true):
			continue
		var tid: String = t.get("unit_id", "")
		var score: int = 0
		if controller != null and "_enemy_units" in controller:
			for eu in controller._enemy_units:
				if eu.unit_id == tid and eu.is_alive:
					var hp_pct: float = float(eu.current_health) / float(eu.max_health) if eu.max_health > 0 else 1.0
					score += int((1.0 - hp_pct) * 100)
					if eu.attack_type == "magical" or ("combat_role" in eu and eu.combat_role == "mage"):
						score += 50
					break
		if score > best_score:
			best_score = score
			best_id = tid
	# Fallback to first non-ally
	if best_id == "":
		for t in valid_targets:
			if not t.get("is_ally", true):
				best_id = t.get("unit_id", "")
				break
	if best_id == "":
		best_id = valid_targets[0].get("unit_id", "")
	return best_id


func _on_combat_ended(result) -> void:
	if not _active:
		return
	if _combat_ended_handled:
		_log("Double combat_ended signal — ignoring")
		return
	_combat_ended_handled = true
	_combat_last_signal_ms = Time.get_ticks_msec()
	_combat_connected = false

	var is_victory: bool = false
	if "is_victory" in result:
		is_victory = result.is_victory
	_log("Combat ended — %s" % ("VICTORY" if is_victory else "DEFEAT"))
	PlaytestCapture.capture("combat_end_%s" % ("victory" if is_victory else "defeat"))

	if is_victory:
		# FIX A: Route loot to hero bags → shopkeeper bag → discard
		_route_pending_loot()
		# Dismiss flee dialog if still open (hero died but we won anyway)
		_find_and_click_button("Continue Fighting")
		# Wait for loot panel, then force-click exact "Continue" (not "Continue Fighting")
		await get_tree().create_timer(2.0).timeout
		for attempt in range(5):
			if _force_click_button("Continue"):
				break
			await get_tree().create_timer(0.5).timeout
	else:
		# FIX 11: Defeat — click "Return to Town" on defeat panel
		_log("Defeat — waiting for defeat panel")
		await get_tree().create_timer(2.0).timeout
		for attempt in range(5):
			if _find_and_click_button("Return to Town"):
				_log("Clicked Return to Town (defeat)")
				break
			await get_tree().create_timer(0.5).timeout
	# CombatScene handles phase transition → DUNGEON_CAMP or TOWN_HUB
	# Caught by _on_phase_changed (since _handling_phase is false)


## FIX A: Deposit-all loot routing — mirrors CombatScene._on_loot_deposit_all().
## Shop bag first, then hero bags. Stash is LOCKED during dungeon.
## Materials routed FIRST (stack 20/slot) so they don't get discarded when equipment fills bags.
func _route_pending_loot() -> void:
	var routed_shop: int = 0
	var routed_hero: int = 0

	# Build set of heroes who already have a healing consumable in their bag
	var heroes_with_heal: Dictionary = {}
	for hero_id in GameContext.selected_party:
		for entry in GameContext.get_hero_bag(hero_id):
			var t = DataRegistry.get_item_template(entry.get("item_id", ""))
			if t != null and t.item_type == "consumable" and _is_heal_effect(t):
				heroes_with_heal[hero_id] = true
				break

	# Pass 1: Healing consumables → hero bags (heroes without a heal get priority)
	var placed_any: bool = true
	while placed_any:
		placed_any = false
		var pending = GameContext.get_all_pending_acquisitions()
		var i: int = pending.size() - 1
		while i >= 0:
			var acq = pending[i]
			var item_id: String = acq.get("item_id", "")
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl == null or tpl.item_type != "consumable" or not _is_heal_effect(tpl):
				i -= 1
				continue
			# Find a hero without a heal who has bag space
			var hero_placed: bool = false
			for hero_id in GameContext.selected_party:
				if heroes_with_heal.has(hero_id):
					continue
				if GameContext.can_add_to_hero_bag(hero_id, item_id, 1):
					GameContext.resolve_acquisition_at(i, "hero_bag", hero_id)
					routed_hero += 1
					heroes_with_heal[hero_id] = true
					placed_any = true
					hero_placed = true
					break
			if hero_placed:
				pending = GameContext.get_all_pending_acquisitions()
				i = mini(i, pending.size()) - 1
				continue
			i -= 1

	# Pass 2-3: Materials first (they stack efficiently), then everything else
	for pass_idx in 2:
		var is_material_pass: bool = (pass_idx == 0)
		placed_any = true
		while placed_any:
			placed_any = false
			var pending = GameContext.get_all_pending_acquisitions()
			var i: int = pending.size() - 1
			while i >= 0:
				var acq = pending[i]
				var item_id: String = acq.get("item_id", "")
				var quality: int = int(acq.get("quality", 0))
				var tpl = DataRegistry.get_item_template(item_id)
				var is_mat: bool = (tpl != null and tpl.item_type == "material")
				if is_material_pass != is_mat:
					i -= 1
					continue
				# Shop bag first
				if GameContext.can_add_to_shopkeeper_bag(item_id, 1, quality):
					GameContext.resolve_acquisition_at(i, "shop_bag")
					routed_shop += 1
					placed_any = true
					pending = GameContext.get_all_pending_acquisitions()
					i = mini(i, pending.size()) - 1
					continue
				# Then hero bags
				var hero_placed: bool = false
				for hero_id in GameContext.selected_party:
					if GameContext.can_add_to_hero_bag(hero_id, item_id, 1):
						GameContext.resolve_acquisition_at(i, "hero_bag", hero_id)
						routed_hero += 1
						placed_any = true
						hero_placed = true
						break
				if hero_placed:
					pending = GameContext.get_all_pending_acquisitions()
					i = mini(i, pending.size()) - 1
					continue
				i -= 1
	# Discard anything that couldn't fit
	if GameContext.has_pending_acquisition():
		var remaining = GameContext.get_all_pending_acquisitions().size()
		_log("Bags full — discarding %d remaining items" % remaining)
		GameContext.clear_pending_acquisitions()
	_log("Loot deposited: %d to shop bag, %d to hero bags" % [routed_shop, routed_hero])

# ============================================================================
# DUNGEON CAMP HANDLER — FIX 6 (v2: API-driven room selection)
# ============================================================================

func _handle_dungeon_camp() -> void:
	var floor_num: int = GameContext.get_current_floor()
	var room_idx: int = GameContext.get_current_room_index()
	_log("Dungeon camp — floor %d, room %d" % [floor_num, room_idx])
	PlaytestCapture.capture("dungeon_camp")

	# Wait for camp scene to build and generate room choices
	await get_tree().create_timer(1.5).timeout

	# Use healing consumables on damaged heroes before proceeding
	_use_camp_consumables()
	# Use a buff consumable for the next combat (R4+)
	_use_camp_buff_consumable()

	# HP-based mid-dungeon extraction — threshold scales with region burst damage
	var avg_hp: float = _get_avg_party_hp_pct()
	var extract_threshold: float = _get_extraction_hp_threshold()
	if avg_hp < extract_threshold:
		_log("Party HP critical (%.0f%%) — extracting mid-dungeon" % (avg_hp * 100))
		_do_bot_extract()
		await get_tree().create_timer(3.0).timeout
		await _wait_frames(10)
		await _handle_next_phase()
		return

	# Check if we should extract (region done or chunk complete)
	if _should_extract():
		_do_bot_extract()
		await get_tree().create_timer(3.0).timeout
		await _wait_frames(10)
		await _handle_next_phase()
		return

	# Read room choices from GameContext (populated by camp scene's _ready)
	var room_data: Dictionary = GameContext.get_pending_room_choices()
	var mode: String = room_data.get("mode", "")

	if mode == "descend":
		# End of floor — descend or extract
		_handle_camp_descend()
		await get_tree().create_timer(3.0).timeout
		await _wait_frames(10)
		await _handle_next_phase()
		return

	if mode == "choose":
		# Normal room choice — pick via GameContext API (bypasses button handler issues)
		var choices: Array = room_data.get("choices", [])
		var picked: Dictionary = _pick_best_room_choice(choices)
		if not picked.is_empty():
			GameContext.set_next_room_choice(picked)
			GameContext.advance_room()
			GameContext.consume_next_room_choice()
			var room_type: String = GameContext.get_current_room_type()
			_log("Selected room: %s (type=%s)" % [picked.get("display", "?"), room_type])
			await _action_delay()
			if room_type == "event":
				GameContext.prepare_room_event_payload()
				GameContext.set_phase(GameContext.GamePhase.ROOM_EVENT)
			else:
				GameContext.set_phase(GameContext.GamePhase.COMBAT)
			SceneTransition.fade_to(BOOT_SCENE)
			await get_tree().create_timer(3.0).timeout
			await _wait_frames(10)
			await _handle_next_phase()
			return

	# Fallback: no room choices available — try clicking buttons directly
	_log("No room choices from API (mode=%s) — trying buttons" % mode)
	var clicked: bool = false
	for attempt in range(5):
		if _find_and_click_button("Descend"):
			_log("Descending to next floor (button)")
			clicked = true
			break
		if _find_and_click_button("Extract"):
			_log("Extracting (button fallback)")
			clicked = true
			break
		if _find_and_click_button("A:"):
			_log("Picked Choice A (button)")
			clicked = true
			break
		_log("Camp fallback attempt %d: no buttons found, waiting..." % (attempt + 1))
		await get_tree().create_timer(1.0).timeout

	if clicked:
		await get_tree().create_timer(3.0).timeout
		await _wait_frames(10)
		await _handle_next_phase()
	else:
		_log("WARNING: No camp choices available after 5 fallback attempts")


## Pick best room choice — prefer combat for consistent dungeon progression.
func _pick_best_room_choice(choices: Array) -> Dictionary:
	# Priority: normal combat > event > elite > forced boss/elite
	for c in choices:
		if c.get("type") == "combat" and not c.get("is_elite", false) and not c.get("forced_boss", false):
			return c
	# Accept event or elite if no normal combat
	for c in choices:
		return c
	return {}


## Use a buff consumable at camp to set a pending combat modifier for the next fight.
## Only activates at R4+ where buffs are needed to survive burst damage.
func _use_camp_buff_consumable() -> void:
	if _current_target_region < 4:
		return
	if GameContext.has_pending_combat_modifier():
		return  # Already have a modifier queued
	# Search hero bags for a buff consumable
	for hero_id in GameContext.get_selected_party():
		for entry in GameContext.get_hero_bag(hero_id):
			var item_id: String = entry.get("item_id", "")
			var template = DataRegistry.get_item_template(item_id)
			if template == null or template.item_type != "consumable":
				continue
			if not _is_buff_effect(template):
				continue
			# Map use_effect to a combat modifier
			var eff: String = _get_template_field(template, "use_effect")
			var val: int = int(_get_template_field(template, "use_value")) if _get_template_field(template, "use_value") != "" else 5
			var mod: Dictionary = {"id": item_id, "label": template.display_name}
			match eff:
				"buff_defense":
					mod["player_def_bonus"] = val
				"buff_speed":
					mod["player_spd_bonus"] = val
				"buff_evasion", "buff_evasion_and_stealth":
					mod["player_eva_bonus"] = val
				"buff_attack", "buff_attack_burning":
					# No direct ATK modifier in combat system — use DEF as fallback
					mod["player_def_bonus"] = val
				"buff_attack_and_speed":
					mod["player_spd_bonus"] = val
				"buff_def_atk_immunity":
					mod["player_def_bonus"] = val
				_:
					mod["player_def_bonus"] = val  # Generic fallback
			GameContext.set_pending_combat_modifier(mod)
			# Consume from hero bag
			GameContext.consume_stash_item(item_id, "hero_bag", hero_id)
			_log("Camp buff: %s from %s's bag → %s" % [item_id, hero_id, str(mod)])
			return


## Use healing consumables on damaged heroes at camp before proceeding.
func _use_camp_consumables() -> void:
	for hero_id in GameContext.get_selected_party():
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		if hp_data.is_empty():
			continue  # Not tracked yet (full HP)
		var current: int = hp_data.get("current", 1)
		var max_hp: int = hp_data.get("max", 1)
		var pct: float = float(current) / float(max_hp) if max_hp > 0 else 1.0
		if pct >= 0.90:
			continue  # Near full HP — save consumables
		# Search for healing consumable: hero bag → other heroes' bags → dungeon stash
		var info: Dictionary = GameContext.find_healing_consumable(hero_id)
		if info.is_empty():
			for other_id in GameContext.get_selected_party():
				if other_id == hero_id:
					continue
				info = GameContext.find_healing_consumable(other_id)
				if not info.is_empty():
					break
		if not info.is_empty():
			var source: String = info.get("source", "hero_bag")
			var source_hero: String = info.get("hero_id", hero_id)
			GameContext.use_consumable_on_hero(info["item_id"], hero_id, source, source_hero)
			_log("Camp heal: %s on %s (was %.0f%%)" % [info["item_id"], hero_id, pct * 100])


## End of floor: track mastery, descend to boss floor when ready, otherwise extract.
func _handle_camp_descend() -> void:
	var current_floor: int = GameContext.get_current_floor()
	var dungeon_id: String = GameContext.get_current_dungeon_id()

	# Unlock floors (mirrors DungeonCampScene.gd:294-295 which the bot bypasses)
	GameContext.unlock_floor(dungeon_id, current_floor)
	GameContext.unlock_floor(dungeon_id, current_floor + 1)

	# First floor completion: mark milestone
	if not GameContext.has_completed_first_floor():
		_log("First floor completion — extracting to unlock progression")
		_do_bot_extract()
		return

	# Track whether this was a clean run (no hero deaths)
	var was_clean: bool = not GameContext.has_hero_died_this_run()
	if was_clean:
		var prev: int = _floor_clean_runs.get(current_floor, 0)
		_floor_clean_runs[current_floor] = prev + 1
		_log("Floor %d CLEAN run #%d/%d" % [current_floor, prev + 1, FLOOR_MASTERY_THRESHOLD])
	else:
		_floor_clean_runs[current_floor] = 0
		_log("Floor %d had hero death — resetting clean count" % current_floor)

	# Get dungeon info for floor/boss checks
	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count: int = dungeon.floor_count if dungeon != null else 4
	var next_floor: int = current_floor + 1
	var next_is_boss: bool = (next_floor >= floor_count)

	# Check if floor is mastered → advance start floor for next run
	var clean_count: int = _floor_clean_runs.get(current_floor, 0)
	if clean_count >= FLOOR_MASTERY_THRESHOLD:
		var unlocked: int = GameContext.get_unlocked_floor(dungeon_id)
		if next_floor <= unlocked:
			var current_start: int = GameContext.get_selected_start_floor(dungeon_id)
			if next_floor > current_start:
				GameContext.set_selected_start_floor(dungeon_id, next_floor)
				_log("Floor %d MASTERED (%d clean runs) — next run starts at F%d" % [
					current_floor, clean_count, next_floor])
			else:
				_log("Floor %d mastered but start already at F%d — no change" % [
					current_floor, current_start])

	# Descend instead of extracting when deeper floors remain (5+ floor dungeons)
	if next_floor <= floor_count and clean_count >= FLOOR_MASTERY_THRESHOLD:
		# HP safety check — don't descend damaged (scales with region)
		var avg_hp_pct: float = _get_avg_party_hp_pct()
		var descent_threshold: float = _get_extraction_hp_threshold() + 0.10
		if avg_hp_pct < descent_threshold:
			_log("HP too low to descend (%.0f%% avg) — extracting to heal" % (avg_hp_pct * 100))
			_do_bot_extract()
			return
		_log("Descending to F%d (floor %d mastered, %d/%d floors, HP %.0f%%%s)" % [
			next_floor, current_floor, next_floor, floor_count, avg_hp_pct * 100,
			" — BOSS" if next_is_boss else ""])
		GameContext.advance_floor()
		GameContext.set_phase(GameContext.GamePhase.COMBAT)
		SceneTransition.fade_to(BOOT_SCENE)
		return

	_log("Floor %d done — extracting to heal/bank/regear" % current_floor)
	_do_bot_extract()


## Get gold to reserve for recruiting replacement heroes (scaled by region).
## R5+ reserves for 6 recruits instead of 4 to handle higher death rates.
func _get_recruit_reserve() -> int:
	const RECRUIT_COST_BY_REGION: Array = [0, 50, 75, 100, 140, 185, 240, 310]
	var cost: int = RECRUIT_COST_BY_REGION[mini(_current_target_region, 7)]
	var reserve_count: int = 6 if _current_target_region >= 5 else 4
	return reserve_count * cost


## Get the lowest level among all party heroes.
func _get_min_party_level() -> int:
	var min_level: int = 99
	for hero_id in GameContext.get_selected_party():
		var hero: Dictionary = GameContext.get_hero(hero_id)
		var lvl: int = int(hero.get("level", 1))
		if lvl < min_level:
			min_level = lvl
	return min_level if min_level < 99 else 1


## Get average HP percentage across all living party heroes.
func _get_avg_party_hp_pct() -> float:
	var total_pct: float = 0.0
	var count: int = 0
	for hero_id in GameContext.get_selected_party():
		var hp_data: Dictionary = GameContext.get_hero_hp(hero_id)
		if hp_data.is_empty():
			total_pct += 1.0  # Full HP if not tracked yet
		else:
			var current: int = hp_data.get("current", 1)
			var max_hp: int = hp_data.get("max", 1)
			total_pct += float(current) / float(max_hp) if max_hp > 0 else 1.0
		count += 1
	return total_pct / float(count) if count > 0 else 1.0


## Get HP% threshold for mid-dungeon extraction — scales with region burst damage.
func _get_extraction_hp_threshold() -> float:
	match _current_target_region:
		1, 2, 3: return 0.50
		4: return 0.55
		5: return 0.60
		6: return 0.65
		_: return 0.70  # R7+


## Extract from dungeon via GameContext API (bypasses button click).
func _do_bot_extract() -> void:
	_log("Extracting from dungeon (API)")
	if not GameContext.has_completed_first_floor():
		GameContext.mark_first_floor_completed()
	GameContext.commit_dungeon_stash_to_run()
	GameContext.exit_to_town()
	SceneTransition.fade_to(BOOT_SCENE)

# ============================================================================
# ROOM EVENT HANDLER — FIX 7
# ============================================================================

func _handle_room_event() -> void:
	_log("Room event")
	await get_tree().create_timer(1.0).timeout
	PlaytestCapture.capture("event_text")

	# Find and click first enabled choice button (text "1:", "2:", "3:", "4:")
	var clicked = false
	for attempt in range(5):
		for i in range(1, 5):
			if _find_and_click_button("%d:" % i):
				_log("Picked event choice %d" % i)
				clicked = true
				break
		if clicked:
			break
		await get_tree().create_timer(0.5).timeout

	if not clicked:
		_log("WARNING: No event choice buttons found")
		return

	# Wait for outcome display
	await get_tree().create_timer(2.0).timeout
	PlaytestCapture.capture("event_outcome")

	# Click return button — could be "Return to Camp" or "Prepare for Battle!"
	await get_tree().create_timer(1.0).timeout
	var return_clicked = false
	for attempt in range(5):
		if _find_and_click_button("Return to Camp"):
			return_clicked = true
			break
		if _find_and_click_button("Prepare for Battle"):
			return_clicked = true
			break
		await get_tree().create_timer(0.5).timeout

	if not return_clicked:
		_log("WARNING: No return button found in event")
		return

	# Direct handoff: return button triggers transition → wait → handle next phase
	await get_tree().create_timer(3.0).timeout
	await _wait_frames(10)
	await _handle_next_phase()

# ============================================================================
# REGION PROGRESSION
# ============================================================================

func _should_travel_to_next_region() -> bool:
	var current_region_key = "region_%d" % _current_target_region
	if GameContext.is_region_completed(current_region_key):
		if _current_target_region >= _end_region:
			return false  # Chunk complete — caught by next check (don't increment!)
		_current_target_region += 1
		return true
	return false


## FIX 4: Direct handoff after scene transition
func _travel_to_next_region() -> void:
	# Snapshot save before traveling — lets us resume from this point
	_snapshot_save("post_R%d" % (_current_target_region - 1))

	var region_key = "region_%d" % _current_target_region
	var data = REGION_DATA.get(region_key, {})
	if data.is_empty():
		_end_run("no_region_data")
		return
	_log("Traveling to %s (%s)" % [region_key, data["town"]])
	GameContext.set_location(region_key, data["town"])
	# Snapshot on arrival — clean starting point for the new region
	_snapshot_save("start_R%d" % _current_target_region)
	GameContext.set_phase(GameContext.GamePhase.TOWN_HUB)
	await _wait_frames(3)
	SceneTransition.fade_to(TOWN_HUB_SCENE)
	# Wait for scene transition, then handle town hub directly
	await get_tree().create_timer(3.0).timeout
	await _wait_frames(10)
	_log("Scene loaded — entering town hub handler")
	await _handle_town_hub()


func _should_extract() -> bool:
	var region_key = "region_%d" % _current_target_region
	if GameContext.is_region_completed(region_key):
		return true
	if _current_target_region > _end_region:
		return true
	return false

# ============================================================================
# DIRECT HANDOFF — handle whatever phase we're now in
# ============================================================================

func _handle_next_phase() -> void:
	var phase: int = GameContext._current_phase
	_log("Direct handoff → %s" % GameContext.get_phase_name())
	match phase:
		GameContext.GamePhase.COMBAT:
			await _handle_combat()
		GameContext.GamePhase.DUNGEON_CAMP:
			await _handle_dungeon_camp()
		GameContext.GamePhase.ROOM_EVENT:
			await _handle_room_event()
		GameContext.GamePhase.TOWN, GameContext.GamePhase.TOWN_HUB:
			await _handle_town_hub()
		_:
			_log("Unhandled phase in handoff: %s" % GameContext.get_phase_name())

# ============================================================================
# SAVE SNAPSHOTS — preserve state at key milestones for resuming
# ============================================================================

## Copy the current save file to a snapshot for easy resume.
func _snapshot_save(label: String) -> void:
	GameContext.save_game()
	var src: String = GameContext.get_save_path(-1)
	if not FileAccess.file_exists(src):
		_log("Snapshot skipped — no save file at %s" % src)
		return
	var dir: String = src.get_base_dir()
	var dst: String = dir.path_join("bot_snapshot_%s.json" % label)
	var file = FileAccess.open(src, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()
	var out = FileAccess.open(dst, FileAccess.WRITE)
	if out != null:
		out.store_string(content)
		out.close()
		_log("Snapshot saved: %s" % dst)

# ============================================================================
# END RUN
# ============================================================================

func _end_run(reason: String) -> void:
	_log("Run complete — reason: %s" % reason)
	_snapshot_save("game_complete_R%d_ng%d" % [_current_target_region, GameContext.ng_plus_cycle])
	_log("Screenshots: %d/%d" % [PlaytestCapture._step_count, PlaytestCapture.MAX_SCREENSHOTS])
	PlaytestCapture.capture("run_complete")
	_write_report(reason)

	# Check if we should transition to NG+ (only after completing ALL regions, not just the chunk)
	if reason == "chunk_complete" and _end_region >= 7 and GameContext.ng_plus_cycle < _max_ng_cycles:
		_start_ng_plus()
		return

	_active = false
	_log("Bot stopped (cycle %d). Window closing in 60 seconds..." % GameContext.ng_plus_cycle)
	await get_tree().create_timer(60.0).timeout
	get_tree().quit()


## Trigger NG+ transition: select best heroes, reset world, continue bot.
func _start_ng_plus() -> void:
	var current_cycle: int = GameContext.ng_plus_cycle
	var carry_limit: int = GameContext.get_ng_carry_limit()
	_log("=== NG+ TRANSITION: Cycle %d → %d (carry %d heroes) ===" % [
		current_cycle, current_cycle + 1, carry_limit])

	# Select highest-level heroes to carry
	var heroes_by_level: Array = []
	for hero in GameContext.owned_heroes:
		heroes_by_level.append(hero)
	heroes_by_level.sort_custom(func(a, b): return int(a.get("level", 1)) > int(b.get("level", 1)))

	var carry_ids: Array = []
	for i in range(mini(carry_limit, heroes_by_level.size())):
		var hid: String = heroes_by_level[i].get("hero_id", "")
		carry_ids.append(hid)
		_log("Carrying hero: %s (Lv%d, %s)" % [
			hid, int(heroes_by_level[i].get("level", 1)),
			heroes_by_level[i].get("class_id", "?")])

	# Execute NG+ transition
	GameContext.start_new_game_plus(carry_ids)
	_log("NG+ cycle %d started. Gold=%d, Heroes=%d" % [
		GameContext.ng_plus_cycle, GameContext.run_gold, GameContext.owned_heroes.size()])

	# Reset bot state for new cycle
	_current_target_region = 1
	_floor_clean_runs = {}
	_town_visits = 0
	_handling_phase = false
	_combat_connected = false
	_stall_recovery_fails = 0
	_combat_last_signal_ms = 0

	# Re-skip tutorials (completed_tutorials reset by NG+)
	_skip_all_overlays()

	# Set location to Thornhaven and continue the main loop
	GameContext.set_location("region_1", "town_thornhaven")
	GameContext.set_phase(GameContext.GamePhase.TOWN)

	_snapshot_save("ng_plus_cycle_%d_start" % GameContext.ng_plus_cycle)
	_log("Bot continuing from Thornhaven in NG+ cycle %d" % GameContext.ng_plus_cycle)

	# Scene transition — _on_phase_changed will catch TOWN_HUB and resume the bot loop
	SceneTransition.fade_to(BOOT_SCENE)

# ============================================================================
# UTILITIES
# ============================================================================

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


## Visible-action delay — slows the bot so humans can observe decisions.
func _action_delay() -> void:
	if ACTION_DELAY_SEC > 0 and is_inside_tree():
		await get_tree().create_timer(ACTION_DELAY_SEC).timeout


## Periodic check for flee dialog (hero fallen), defeat panel, and combat stalls.
## Called from _process() every 3 seconds.
func _check_for_overlays() -> void:
	# Flee dialog: hero death mid-fight — flee if alive < 3 or tank died
	if _combat_connected:
		var flee_btn: Button = _find_button_by_text("Flee")
		var continue_btn: Button = _find_button_by_text("Continue Fighting")
		if flee_btn != null and continue_btn != null:
			var should_flee: bool = false
			var flee_reason: String = ""
			var scene = get_tree().current_scene
			if scene != null:
				var controller = _get_combat_controller(scene)
				if controller != null and "_player_units" in controller:
					var alive_count: int = 0
					var tank_died: bool = false
					for unit in controller._player_units:
						if unit.is_alive:
							alive_count += 1
						else:
							var cid: String = unit.class_id if "class_id" in unit else ""
							if cid in TANK_CLASSES:
								tank_died = true
					if alive_count < 3:
						should_flee = true
						flee_reason = "only %d alive" % alive_count
					elif tank_died:
						should_flee = true
						flee_reason = "tank died"
					else:
						# HP-based flee: if surviving heroes are critically low
						var avg_pct: float = 0.0
						var checked: int = 0
						for u in controller._player_units:
							if u.is_alive:
								var hp_pct: float = float(u.current_health) / float(u.max_health) if u.max_health > 0 else 1.0
								avg_pct += hp_pct
								checked += 1
						if checked > 0:
							avg_pct /= float(checked)
							if avg_pct < 0.25:
								should_flee = true
								flee_reason = "avg HP %.0f%%" % (avg_pct * 100)
			if should_flee:
				flee_btn.pressed.emit()
				_log("Auto-clicked Flee — %s" % flee_reason)
				_combat_connected = false
			else:
				continue_btn.pressed.emit()
				_log("Continue fighting — 3+ heroes alive, tank OK")
			return

	# Defeat panel: "Return to Town" button (total party wipe, only during combat)
	if _combat_connected:
		if _find_and_click_button("Return to Town"):
			_log("Auto-clicked Return to Town — defeat")
			_combat_connected = false
			return

	# Combat stall recovery: if no combat signal for COMBAT_STALL_SEC, try to unstick
	if _combat_connected and _combat_last_signal_ms > 0:
		var stall_sec: float = (Time.get_ticks_msec() - _combat_last_signal_ms) / 1000.0
		if stall_sec >= COMBAT_STALL_SEC:
			# Try clicking any visible overlay buttons
			if _force_click_button("Continue"):
				_log("Stall recovery: force-clicked Continue")
				_combat_last_signal_ms = Time.get_ticks_msec()
				_stall_recovery_fails = 0
				return
			if _find_and_click_button("Dismiss"):
				_log("Stall recovery: clicked Dismiss")
				_combat_last_signal_ms = Time.get_ticks_msec()
				_stall_recovery_fails = 0
				return
			if _find_and_click_button("OK"):
				_log("Stall recovery: clicked OK")
				_combat_last_signal_ms = Time.get_ticks_msec()
				_stall_recovery_fails = 0
				return
			if _find_and_click_button("Flee"):
				_log("Stall recovery: clicked Flee")
				_combat_last_signal_ms = Time.get_ticks_msec()
				_stall_recovery_fails = 0
				return
			# Try re-triggering combat input
			var scene = get_tree().current_scene
			if scene != null:
				var controller = _get_combat_controller(scene)
				if controller != null:
					if controller.has_method("is_awaiting_player_input") and controller.is_awaiting_player_input():
						_log("Stall recovery: combat awaiting input — re-triggering")
						controller.cancel_player_action()
						_combat_last_signal_ms = Time.get_ticks_msec()
						_stall_recovery_fails = 0
						return
			# Nothing worked — count consecutive failures
			_stall_recovery_fails += 1
			if _stall_recovery_fails >= MAX_STALL_RECOVERIES:
				_log("STUCK in combat after %d recovery attempts — force-fleeing to town" % _stall_recovery_fails)
				_stall_recovery_fails = 0
				_combat_connected = false
				_combat_last_signal_ms = 0
				# Use game's flee mechanism for clean dungeon exit + scene transition
				GameContext.flee_to_town()
				SceneTransition.fade_to(BOOT_SCENE)
				return
			# Don't call _log() — let watchdog timer keep counting down
			print("[AutoPlayBot] Stall recovery: no buttons found (%d/%d)" % [_stall_recovery_fails, MAX_STALL_RECOVERIES])
			_combat_last_signal_ms = Time.get_ticks_msec()

	# Stuck recovery: bot is idle but a combat controller exists on scene
	# This catches cases where _handle_combat() never ran (phase handler nesting edge case)
	if not _combat_connected and _last_action_ms > 0:
		var idle_sec: float = (Time.get_ticks_msec() - _last_action_ms) / 1000.0
		if idle_sec >= 20.0:
			var scene = get_tree().current_scene
			if scene != null:
				var controller = _get_combat_controller(scene)
				if controller != null:
					_log("Stuck recovery: found combat controller after %.0fs idle" % idle_sec)
					_handle_combat()


## FIX 10: Like _find_and_click_button but ignores disabled state.
## Used for loot Continue button (disabled by UI but items already resolved).
## Like _find_and_click_button but uses EXACT text match and ignores disabled state.
## Used for loot Continue button (avoids matching "Continue Fighting" from flee dialog).
func _force_click_button(exact_text: String) -> bool:
	var match_text: String = exact_text.strip_edges()
	var scene = get_tree().current_scene
	if scene != null:
		for btn in _find_all_buttons(scene):
			if btn.visible and btn.text.strip_edges() == match_text:
				btn.disabled = false
				_log("Force-clicking button: '%s'" % btn.text)
				btn.pressed.emit()
				return true
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			for btn in _find_all_buttons(child):
				if btn.visible and btn.text.strip_edges() == match_text:
					btn.disabled = false
					_log("Force-clicking button (overlay): '%s'" % btn.text)
					btn.pressed.emit()
					return true
	return false


## FIX 5: Search BOTH current scene AND CanvasLayer overlays on /root
## Find a visible button by exact text match (does not click it).
func _find_button_by_text(text_match: String) -> Button:
	var text_lower: String = text_match.to_lower()
	var scene = get_tree().current_scene
	if scene != null:
		for btn in _find_all_buttons(scene):
			if btn.visible and not btn.disabled:
				if text_lower in btn.text.to_lower():
					return btn
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			for btn in _find_all_buttons(child):
				if btn.visible and not btn.disabled:
					if text_lower in btn.text.to_lower():
						return btn
	return null


func _find_and_click_button(text_contains: String) -> bool:
	var text_lower: String = text_contains.to_lower()
	# Search current scene
	var scene = get_tree().current_scene
	if scene != null:
		for btn in _find_all_buttons(scene):
			if btn.visible and not btn.disabled:
				if text_lower in btn.text.to_lower():
					_log("Clicking button: '%s'" % btn.text)
					btn.pressed.emit()
					return true
	# Search CanvasLayer children of /root (loot panel, facility overlays)
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			for btn in _find_all_buttons(child):
				if btn.visible and not btn.disabled:
					if text_lower in btn.text.to_lower():
						_log("Clicking button (overlay): '%s'" % btn.text)
						btn.pressed.emit()
						return true
	return false


## Search everywhere — current scene + all root CanvasLayers
func _find_all_buttons_everywhere() -> Array:
	var result: Array = []
	var scene = get_tree().current_scene
	if scene != null:
		result.append_array(_find_all_buttons(scene))
	for child in get_tree().root.get_children():
		if child is CanvasLayer:
			result.append_array(_find_all_buttons(child))
	return result


func _find_all_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_all_buttons(child))
	return result


# ============================================================================
# ITEM HELPERS — accessor + stat comparison
# ============================================================================

func _get_item_quality(item) -> int:
	if item is Dictionary:
		return int(item.get("quality_tier", 0))
	if "quality_tier" in item:
		return int(item.quality_tier)
	return 0


func _get_item_affix_stats(item) -> Dictionary:
	if item is Dictionary:
		return item.get("affix_stats", {})
	if "affix_stats" in item:
		return item.affix_stats
	return {}


func _get_item_affix_data(item) -> Dictionary:
	var result: Dictionary = {}
	if item is Dictionary:
		if item.get("affix_id", "") != "":
			result["source_region"] = item.get("source_region", "")
			result["affix_id"] = item.get("affix_id", "")
			result["affix_stats"] = item.get("affix_stats", {})
			result["affix_prefix"] = item.get("affix_prefix", "")
	elif "affix_id" in item and item.affix_id != "":
		result["source_region"] = item.source_region if "source_region" in item else ""
		result["affix_id"] = item.affix_id
		result["affix_stats"] = item.affix_stats if "affix_stats" in item else {}
		result["affix_prefix"] = item.affix_prefix if "affix_prefix" in item else ""
	return result


## Calculate a weighted stat score for an item (used for equipment comparison).
func _calc_item_score(template, quality: int, affix_stats: Dictionary) -> int:
	var region_bonus: float = GameContext.get_completed_region_count() * 0.1 if GameContext.has_method("get_completed_region_count") else 0.0
	var stats: Dictionary = {}
	if template != null and template.has_method("get_stat_bonuses_with_quality"):
		stats = template.get_stat_bonuses_with_quality(quality, region_bonus)
	for key in affix_stats:
		stats[key] = stats.get(key, 0) + int(affix_stats[key])
	var score: int = 0
	score += stats.get("attack", 0) * 2
	score += stats.get("health", 0)
	score += stats.get("defense", 0) * 2
	score += stats.get("speed", 0) * 2
	score += stats.get("crit_chance", 0) * 2
	score += stats.get("evasion", 0)
	# Resist weight scales up at R4+ where magical damage dominates
	var resist_weight: int = 1 if _current_target_region <= 3 else 3
	score += stats.get("resist", 0) * resist_weight
	score += stats.get("armor_penetration", 0)
	score += stats.get("life_steal", 0)
	score += stats.get("thorns", 0)
	# Bag capacity bonus — backpacks are high-value for loot collection
	if template != null and "bag_capacity_bonus" in template:
		score += int(template.bag_capacity_bonus) * 5
	return score


## Get the stat score of the item currently equipped in a hero's slot.
func _get_equipped_score(hero_id: String, slot: String) -> int:
	var equipment: Dictionary = GameContext.get_hero_equipment(hero_id)
	var slot_data: Dictionary = equipment.get(slot, {})
	var item_id: String = slot_data.get("id", "")
	if item_id == "":
		return 0
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return 0
	var quality: int = int(slot_data.get("quality", 0))
	var affix_stats: Dictionary = slot_data.get("affix_stats", {})
	return _calc_item_score(template, quality, affix_stats)


func _get_item_id(item) -> String:
	if item is Dictionary:
		var iid: String = item.get("item_id", "")
		if iid == "":
			iid = item.get("template_id", "")
		return iid
	if "template_id" in item:
		return item.template_id
	return ""


func _get_template_field(template, field_name: String) -> String:
	if template is Dictionary:
		return template.get(field_name, "")
	if field_name in template:
		return str(template.get(field_name))
	return ""


func _get_combat_controller(scene) -> Node:
	if scene == null:
		return null
	if "_combat_controller" in scene:
		return scene._combat_controller
	return null


func _log(message: String) -> void:
	var now_ms: int = Time.get_ticks_msec()
	_last_action_ms = now_ms
	print("[AutoPlayBot] %s" % message)
	_action_log.append({"time_ms": now_ms, "msg": message})
	if _action_log.size() > 50:
		_action_log.pop_front()


func _report_stuck() -> void:
	_active = false  # Prevent re-entry
	_log("STUCK — no progress for %.0f seconds" % WATCHDOG_TIMEOUT_SEC)
	_write_report("stuck")
	PlaytestCapture.capture("stuck_final")
	_log("Window closing in 60 seconds...")
	await get_tree().create_timer(60.0).timeout
	get_tree().quit()


func _write_report(reason: String) -> void:
	var report: Dictionary = {
		"reason": reason,
		"timestamp": Time.get_datetime_string_from_system(),
		"region_chunk": _region_chunk,
		"target_region": _current_target_region,
		"phase": GameContext.get_phase_name() if GameContext else "UNKNOWN",
		"town": GameContext._current_town_id if GameContext else "",
		"floor": GameContext.get_current_floor() if GameContext else 0,
		"room": GameContext.get_current_room_index() if GameContext else 0,
		"gold": GameContext.run_gold if GameContext else 0,
		"stash_items": GameContext.run_items.size() if GameContext else 0,
		"shopkeeper_bag": GameContext.shopkeeper_bag.size() if GameContext else 0,
		"party_size": GameContext.selected_party.size() if GameContext else 0,
		"town_visits": _town_visits,
		"combat_connected": _combat_connected,
		"handling_phase": _handling_phase,
		"screenshots_taken": PlaytestCapture._step_count if PlaytestCapture else 0,
		"last_actions": _action_log,
	}

	# Write JSON report to screenshot directory
	var dir: String = PlaytestCapture.get_run_dir() if PlaytestCapture and PlaytestCapture.get_run_dir() != "" else "user://"
	var path: String = dir.path_join("bot_report.json")
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		f.close()

	# Print summary to console so it's visible in terminal output
	print("")
	print("============================================================")
	print("[AutoPlayBot] BOT REPORT — %s" % reason.to_upper())
	print("============================================================")
	print("  Timestamp:      %s" % report["timestamp"])
	print("  Phase:          %s" % report["phase"])
	print("  Town:           %s" % report["town"])
	print("  Floor/Room:     %d / %d" % [report["floor"], report["room"]])
	print("  Gold:           %d" % report["gold"])
	print("  Stash items:    %d" % report["stash_items"])
	print("  Shopkeeper bag: %d" % report["shopkeeper_bag"])
	print("  Party size:     %d" % report["party_size"])
	print("  Target region:  R%d" % report["target_region"])
	print("  Town visits:    %d" % report["town_visits"])
	print("  Combat conn:    %s" % str(report["combat_connected"]))
	print("  Handler active: %s" % str(report["handling_phase"]))
	print("  Screenshots:    %d" % report["screenshots_taken"])
	print("------------------------------------------------------------")
	print("  Last actions:")
	var entries: Array = report["last_actions"]
	var start_idx: int = maxi(0, entries.size() - 20)
	for i in range(start_idx, entries.size()):
		var entry: Dictionary = entries[i]
		print("    [%dms] %s" % [entry.get("time_ms", 0), entry.get("msg", "")])
	print("------------------------------------------------------------")
	print("  Report saved: %s" % path)
	print("============================================================")
