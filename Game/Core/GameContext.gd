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
	DUNGEON_CAMP,
	ROOM_EVENT,
	REWARDS,
	RETURN_TO_TOWN,
	TOWN_HUB
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
var _dungeon_save_lock: bool = false

# Current region (numeric, 1-7, persisted)
var current_region: int = 1

# Region completion tracking (region_id -> true)
var completed_regions: Dictionary = {}

# Pending region unlock notification (set on boss defeat, consumed by TownHub UI)
var _pending_region_unlock: String = ""

# Run tracking (integrated with SeededRNG - Tier 0.4)
var _run_id: String = ""
var _run_seed: int = 0
var _run_active: bool = false
var _run_counter: int = 0  # Incremented each run for unique IDs

var _initialized: bool = false

# Run stash (rewards collected during run - banked/permanent)
var run_gold: int = 400  # Starting gold (town council investment)
var run_items: Array = []  # Array of ItemInstance

# Dungeon stash (provisional rewards - lost on flee, committed on extract)
var dungeon_gold: int = 0
var dungeon_items: Array = []  # Array of ItemInstance

# Dungeon run progression
var current_dungeon_id: String = ""
var current_floor: int = 0
var current_room_index: int = 0  # 0-based room index within floor
var rooms_per_floor: int = 1     # Default 1; can be raised for multi-room floors

# Room type tracking (valid types: "combat", "elite", "event")
var current_room_type: String = "combat"

# Elite flag: true if current combat room is an elite encounter
var current_room_is_elite: bool = false

# 2-Choice room system: stores the two room choices at camp
# Keys: "choice_a" (always combat), "choice_b" (event or elite)
# Each choice: { "type": "combat"|"event", "is_elite": bool, "display": String }
var pending_room_choices: Dictionary = {}

# The selected choice to consume when entering next room
var pending_selected_choice: Dictionary = {}

# Room event payload (used for non-combat room routing)
var current_room_payload: Dictionary = {}

# Track if last room was an event (to prevent consecutive events)
var _last_room_was_event: bool = false

# ============================================================================
# PLAYER INVENTORY (persistent between runs, used in town)
# ============================================================================

var player_gold: int = 400  # Starting gold
var player_items: Dictionary = {}  # item_id -> qty

# ============================================================================
# NEW GAME PLUS (NG+) — Persistent across cycles
# ============================================================================

# Current NG+ cycle: 0 = first playthrough, 1 = NG+1, up to 8 (true ending)
var ng_plus_cycle: int = 0

# Accumulated permanent stat bonus for heroes (stacking +5% per cycle from NG+4 onward)
var ng_plus_perm_stat_bonus: float = 0.0

# Abilities the player has seen used in combat (persists across NG+ cycles)
# { "ability_id": true }
var seen_abilities: Dictionary = {}

# ============================================================================
# SIDE QUEST SYSTEM
# ============================================================================

# Active side quests (max 3 — one per type: kill, resupply, mini_dungeon)
var active_side_quests: Array = []

# Campaign quest system (linear, one active at a time)
var active_campaign_quest: CampaignQuestData = null
var completed_campaign_quests: Array = []  # Array of quest_id strings

# Flag set when exiting dungeon to town — triggers side quest offer check
var returned_from_dungeon: bool = false

# Counter for unique quest IDs
var _side_quest_counter: int = 0

# Mini-dungeon runtime state (NOT saved — reset on scene change or defeat)
# Keys: active (bool), quest_id (String), fight_index (int), total_fights (int),
#        region_id (String), is_final_fight (bool)
var mini_dungeon_state: Dictionary = {}

# Max carry-over heroes per cycle (cycle 0→1 = 1 hero, 1→2 = 2, 2→3 = 3, 3→4 = 4, 4+ = all)
func get_ng_carry_limit() -> int:
	if ng_plus_cycle >= 4:
		return owned_heroes.size()
	return mini(ng_plus_cycle + 1, owned_heroes.size())

# NG+ difficulty multipliers by cycle
const NG_DIFFICULTY_MULT: Array[Dictionary] = [
	{"hp": 1.00, "atk": 1.00, "def": 1.00, "spd": 1.00},  # Cycle 0
	{"hp": 1.15, "atk": 1.10, "def": 1.10, "spd": 1.05},  # Cycle 1
	{"hp": 1.30, "atk": 1.20, "def": 1.20, "spd": 1.08},  # Cycle 2
	{"hp": 1.50, "atk": 1.30, "def": 1.30, "spd": 1.10},  # Cycle 3
	{"hp": 1.70, "atk": 1.40, "def": 1.40, "spd": 1.12},  # Cycle 4
	{"hp": 1.90, "atk": 1.50, "def": 1.50, "spd": 1.14},  # Cycle 5
	{"hp": 2.10, "atk": 1.60, "def": 1.60, "spd": 1.16},  # Cycle 6
	{"hp": 2.30, "atk": 1.70, "def": 1.70, "spd": 1.18},  # Cycle 7
	{"hp": 2.50, "atk": 1.80, "def": 1.80, "spd": 1.20},  # Cycle 8
]

## Get NG+ difficulty multipliers for current cycle.
func get_ng_difficulty_multipliers() -> Dictionary:
	var idx: int = clampi(ng_plus_cycle, 0, NG_DIFFICULTY_MULT.size() - 1)
	return NG_DIFFICULTY_MULT[idx]

## Mark an ability as seen (called from CombatController after ability execution).
func mark_ability_seen(ability_id: String) -> void:
	if ability_id != "" and ability_id != "basic_attack" and not seen_abilities.has(ability_id):
		seen_abilities[ability_id] = true
		print("[NG+] Ability seen: %s (total=%d)" % [ability_id, seen_abilities.size()])

## Check if an ability has been seen.
func has_seen_ability(ability_id: String) -> bool:
	return seen_abilities.get(ability_id, false)

## Infuse an equipment item with an ability. Replaces any existing infusion.
func infuse_item_ability(hero_id: String, slot: String, ability_id: String) -> bool:
	if not has_seen_ability(ability_id):
		print("[NG+] Infusion rejected: ability %s not seen" % ability_id)
		return false
	var equip = get_hero_equipment(hero_id)
	if not equip.has(slot):
		print("[NG+] Infusion rejected: hero %s has no item in slot %s" % [hero_id, slot])
		return false
	var slot_data: Dictionary = equip[slot]
	if slot_data.get("id", "") == "":
		print("[NG+] Infusion rejected: slot %s is empty" % slot)
		return false
	slot_data["infused_ability_id"] = ability_id
	hero_equipment[hero_id][slot] = slot_data
	print("[NG+] Infused hero=%s slot=%s ability=%s" % [hero_id, slot, ability_id])
	save_game()
	return true

## Start a New Game Plus cycle. Carries over selected heroes and resets world.
func start_new_game_plus(selected_hero_ids: Array) -> void:
	var carry_limit: int = get_ng_carry_limit()
	var to_carry: Array = []
	for hid in selected_hero_ids:
		if to_carry.size() >= carry_limit:
			break
		var hero = get_hero(hid)
		if not hero.is_empty():
			to_carry.append(hero.duplicate(true))

	print("[NG+] Starting cycle %d → %d, carrying %d heroes" % [ng_plus_cycle, ng_plus_cycle + 1, to_carry.size()])

	# Increment cycle
	ng_plus_cycle += 1

	# Apply perm stat bonus from cycle 5+ (0-indexed cycle 4)
	if ng_plus_cycle >= 5:
		ng_plus_perm_stat_bonus += 0.05
		print("[NG+] Perm stat bonus now %.0f%%" % (ng_plus_perm_stat_bonus * 100))

	# Collect equipment from carried heroes → run_items (stash)
	var carry_equipment: Array = []
	for hero in to_carry:
		var hid: String = hero.get("hero_id", "")
		if hero_equipment.has(hid):
			var equip: Dictionary = hero_equipment[hid]
			for slot in ALL_EQUIP_SLOTS:
				var slot_data: Dictionary = equip.get(slot, {})
				var item_id: String = slot_data.get("id", "")
				if item_id != "":
					var item_entry: Dictionary = {
						"item_id": item_id,
						"qty": 1,
						"quality_tier": int(slot_data.get("quality", 0))
					}
					if slot_data.has("affix_id"):
						item_entry["affix_id"] = slot_data["affix_id"]
						item_entry["affix_stats"] = slot_data.get("affix_stats", {})
						item_entry["affix_prefix"] = slot_data.get("affix_prefix", "")
					if slot_data.has("infused_ability_id"):
						item_entry["infused_ability_id"] = slot_data["infused_ability_id"]
					# Preserve NG+ bonus stat lines
					var carry_bonus_lines: Array = slot_data.get("bonus_stat_lines", [])
					if carry_bonus_lines.size() > 0:
						item_entry["bonus_stat_lines"] = carry_bonus_lines
					carry_equipment.append(item_entry)
			hero_equipment.erase(hid)

	# Add non-carried heroes to dead_heroes as "left behind"
	for hero in owned_heroes:
		var hid: String = hero.get("hero_id", "")
		var is_carried: bool = false
		for ch in to_carry:
			if ch.get("hero_id", "") == hid:
				is_carried = true
				break
		if not is_carried:
			dead_heroes.append({
				"hero_id": hid,
				"name": hero.get("name", "Unknown"),
				"race_id": hero.get("race_id", "human"),
				"class_id": hero.get("class_id", ""),
				"level": int(hero.get("level", 1)),
				"cause": "ng_plus_left_behind",
				"ng_cycle_of_death": ng_plus_cycle - 1,
				"timestamp": Time.get_unix_time_from_system()
			})

	# Gold carry: 25% of run_gold, capped at 500
	var carry_gold: int = mini(int(run_gold * 0.25), 500)

	# Preserve knowledge
	var keep_learned_classes: Dictionary = learned_classes.duplicate()
	var keep_discovered_mixes: Dictionary = discovered_mixes.duplicate()
	var keep_seen_abilities: Dictionary = seen_abilities.duplicate()
	var keep_campaign_flags: Dictionary = {}
	for flag_key in campaign_flags:
		# Carry story_* flags for lore continuity and shown_* flags to prevent base dialog re-trigger
		if flag_key.begins_with("story_") or flag_key.begins_with("shown_"):
			keep_campaign_flags[flag_key] = campaign_flags[flag_key]
	var keep_dead_heroes: Array = dead_heroes.duplicate(true)
	var keep_hero_id_counter: int = _hero_id_counter
	var keep_ng_cycle: int = ng_plus_cycle
	var keep_perm_bonus: float = ng_plus_perm_stat_bonus
	var keep_text_size: int = text_size
	var keep_auto_loot: bool = auto_loot
	var keep_tester: bool = tester_mode
	var keep_window_scale: int = window_scale
	var keep_telemetry_consent: bool = telemetry_consent

	# === WORLD RESET (mirrors reset_save_game structure) ===
	player_gold = 400
	player_items = {}
	next_run_bonus_max_hp = 0
	next_run_trained = false
	pending_combat_modifier = {}
	pending_combat_statuses.clear()
	equipped_weapon_id = ""
	equipped_weapon_quality = 0
	equipped_offhand_id = ""
	equipped_offhand_quality = 0
	hero_equipment = {}
	hero_bags = {}
	_gear_logged_heroes.clear()
	shopkeeper_bag = []
	hero_hp = {}
	hero_statuses = {}
	_combat_consumables_used = {}
	loot_pref = {}
	unlocked_groups = {}
	unlocked_item_ids = {}
	unlocked_recipes = {}
	completed_tutorials = {}
	campaign_flags = {}
	discovered_mixes = {}
	alchemist_mishap_streak = 0
	locked_facilities = {}
	inn_lockout = false
	unlocked_dungeon_floors = {}
	selected_start_floors = {}
	facility_tiers = {}
	learned_classes = {}
	town_tiers = {}
	owned_heroes = []
	selected_party = []
	_hero_id_counter = 0
	housing_upgrades = {}
	bonus_stash_capacity = 0
	shop_refresh_counts = {}
	shop_restock_version = {}
	active_side_quests = []
	returned_from_dungeon = false
	mini_dungeon_state = {}
	# NG+: Reset active quest but carry completed quest history
	active_campaign_quest = null
	# completed_campaign_quests preserved across NG+ cycles
	shop_purchased_slots = {}
	shop_slot_allocations = {}
	inn_restock_counts = {}
	run_gold = 400
	run_items = []
	dungeon_gold = 0
	dungeon_items = []
	current_dungeon_id = ""
	current_floor = 0
	current_room_index = 0
	rooms_per_floor = 1
	current_room_type = "combat"
	current_room_is_elite = false
	pending_room_choices = {}
	pending_selected_choice = {}
	current_room_payload = {}
	_last_room_was_event = false
	_run_id = ""
	_run_seed = 0
	_run_active = false
	_run_counter = 0
	_current_phase = GamePhase.TOWN
	_current_region_id = "region_1"
	_current_town_id = "town_thornhaven"
	_selected_floor_index = 1
	_party_hero_ids = []
	current_region = 1
	completed_regions = {}
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1
	hero_row_assignments = {}
	hero_grid_placements = {}
	dead_heroes = []

	# === RESTORE CARRY-OVER DATA ===
	ng_plus_cycle = keep_ng_cycle
	ng_plus_perm_stat_bonus = keep_perm_bonus
	seen_abilities = keep_seen_abilities
	learned_classes = keep_learned_classes
	discovered_mixes = keep_discovered_mixes
	campaign_flags = keep_campaign_flags
	dead_heroes = keep_dead_heroes
	_hero_id_counter = keep_hero_id_counter
	text_size = keep_text_size
	auto_loot = keep_auto_loot
	tester_mode = keep_tester
	window_scale = keep_window_scale
	telemetry_consent = keep_telemetry_consent
	run_gold = carry_gold

	# Restore carried heroes — bench all at Thornhaven for the new cycle
	owned_heroes = to_carry
	for hero in owned_heroes:
		hero["home_town_id"] = "town_thornhaven"
	# Restore carried equipment into stash
	for item_entry in carry_equipment:
		run_items.append(item_entry)

	save_game()
	print("[NG+] Cycle %d started. Heroes=%d, Gold=%d, Equipment in stash=%d" % [
		ng_plus_cycle, owned_heroes.size(), run_gold, carry_equipment.size()])

# ============================================================================
# SIDE QUEST CRUD API
# ============================================================================

## Get the next unique side quest ID.
func _next_side_quest_id(region_id: String, quest_type: String) -> String:
	_side_quest_counter += 1
	return "sq_%s_%s_%d" % [region_id, quest_type, _side_quest_counter]

## Get active side quest by type. Returns null if none active for that type.
func get_active_quest_by_type(quest_type: String):
	for q in active_side_quests:
		if q is SideQuestData and q.quest_type == quest_type:
			return q
	return null

## Get active side quest by ID. Returns null if not found.
func get_side_quest(quest_id: String):
	for q in active_side_quests:
		if q is SideQuestData and q.quest_id == quest_id:
			return q
	return null

## Add a side quest to active list (enforces 1 per type).
func add_side_quest(quest: SideQuestData) -> bool:
	if get_active_quest_by_type(quest.quest_type) != null:
		print("[SideQuest] Already have active %s quest — rejecting" % quest.quest_type)
		return false
	active_side_quests.append(quest)
	print("[SideQuest] Added: %s (%s in %s)" % [quest.quest_id, quest.quest_type, quest.region_id])
	save_game()
	return true

## Remove a side quest by ID.
func remove_side_quest(quest_id: String) -> void:
	for i in range(active_side_quests.size() - 1, -1, -1):
		var q = active_side_quests[i]
		if q is SideQuestData and q.quest_id == quest_id:
			active_side_quests.remove_at(i)
			print("[SideQuest] Removed: %s" % quest_id)
			break
	save_game()

## Get all active side quests.
func get_active_side_quests() -> Array:
	return active_side_quests

# ============================================================================
# CHALLENGE LEVEL (session-only playtest tool — NOT saved)
# ============================================================================

var challenge_level: int = 0
const MAX_CHALLENGE := 10

# ============================================================================
# NG+ EQUIPMENT STAT LINE PROGRESSION
# ============================================================================
# Bonus stat lines added to equipment drops based on region completions + NG+ cycle.
# Stat pool by slot type for bonus line generation.

const STAT_LINE_POOL_WEAPON: Array[String] = ["attack", "speed", "crit_chance", "armor_penetration"]
const STAT_LINE_POOL_ARMOR: Array[String] = ["defense", "health", "resist", "thorns"]
const STAT_LINE_POOL_OFFHAND: Array[String] = ["defense", "health", "speed", "evasion"]
const STAT_LINE_POOL_ACCESSORY: Array[String] = ["crit_chance", "evasion", "speed", "life_steal"]

# Value ranges per bonus stat line (min, max)
const STAT_LINE_VALUES: Dictionary = {
	"health": [3, 5], "attack": [1, 2], "defense": [1, 2], "speed": [1, 1],
	"crit_chance": [2, 3], "evasion": [1, 2], "resist": [1, 2],
	"thorns": [1, 2], "armor_penetration": [1, 2], "life_steal": [1, 1]
}

## Generate bonus stat lines for an equipment drop.
## region_completions: number of completed regions in current cycle.
## rng: RandomNumberGenerator for deterministic generation.
## equip_slot: the item's equip_slot ("weapon", "armor", "helmet", "legs", "offhand", "ring", "amulet")
func generate_bonus_stat_lines(equip_slot: String, region_completions: int, rng: RandomNumberGenerator) -> Array:
	# Total bonus lines = region lines + NG+ cycle lines (capped at cycle 3 for line additions)
	var ng_cycle_lines: int = mini(ng_plus_cycle, 3)  # NG+1-3: +1 line per cycle
	var total_lines: int = region_completions + ng_cycle_lines
	if total_lines <= 0:
		return []

	# Pick stat pool based on slot
	var pool: Array[String]
	match equip_slot:
		"weapon":
			pool = STAT_LINE_POOL_WEAPON
		"armor", "helmet", "legs":
			pool = STAT_LINE_POOL_ARMOR
		"offhand":
			pool = STAT_LINE_POOL_OFFHAND
		"ring", "amulet":
			pool = STAT_LINE_POOL_ACCESSORY
		_:
			pool = STAT_LINE_POOL_WEAPON  # Fallback

	var lines: Array = []
	for i in range(total_lines):
		var stat: String = pool[rng.randi() % pool.size()]
		var val_range: Array = STAT_LINE_VALUES.get(stat, [1, 1])
		var val: int = val_range[0]
		if val_range[1] > val_range[0]:
			val += rng.randi() % (val_range[1] - val_range[0] + 1)
		lines.append({"stat": stat, "value": val})
	return lines

## Get the NG+4-8 base stat multiplier for equipment.
## Returns 1.0 for cycles 0-3; 1.10 for cycle 4, 1.20 for cycle 5, etc.
func get_ng_base_stat_multiplier() -> float:
	if ng_plus_cycle <= 3:
		return 1.0
	return 1.0 + (ng_plus_cycle - 3) * 0.10

# ============================================================================
# TRAINING BUFFS (apply to NEXT dungeon run only, then clear)
# ============================================================================

var next_run_bonus_max_hp: int = 0
var next_run_trained: bool = false

# ============================================================================
# PENDING COMBAT MODIFIER (from events, applies to NEXT combat only)
# ============================================================================

var pending_combat_modifier: Dictionary = {}  # Empty = none
# Structure: { "id": String, "label": String, optional fields like:
#   "bonus_gold": int, "enemy_spd_bonus": int, "player_start_damage": int }

# Pending status effects from events (applied at next combat start, then cleared)
var pending_combat_statuses: Array = []
# Structure: [{ "status_id": String, "duration": int, "target": "random_hero"|"party" }]

# ============================================================================
# EQUIPMENT SLOTS (per-hero, persistent, applies stat bonuses in combat)
# ============================================================================

# Valid equipment slots: 7 equipment + 1 utility (bag)
const EQUIPMENT_SLOTS: Array[String] = ["weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet"]
const ALL_EQUIP_SLOTS: Array[String] = ["weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet", "bag"]

# Per-hero equipment: { hero_id: { "weapon": {"id": "", "quality": 0}, ... } }
var hero_equipment: Dictionary = {}

# DEPRECATED: Legacy global equipment (kept for save migration only)
var equipped_weapon_id: String = ""
var equipped_offhand_id: String = ""
var equipped_weapon_quality: int = 0
var equipped_offhand_quality: int = 0

# Track which heroes have had gear logged this combat spawn (avoid spam)
var _gear_logged_heroes: Dictionary = {}

# Per-hero bag (small personal inventory for consumables in combat, display-only for now)
# Structure: { hero_id: Array[ { "item_id": String, "qty": int } ] }
var hero_bags: Dictionary = {}
const DEFAULT_HERO_BAG_CAPACITY: int = 1  # v1.2: base=1, backpack adds bonus

# Shopkeeper bag (shared town-level container for consumables + materials)
# Array of { "item_id": String, "qty": int, "quality_tier": int }
var shopkeeper_bag: Array = []
const SHOPKEEPER_BAG_CAPACITY_DEFAULT: int = 6  # Max stacks
const SHOPKEEPER_SAFE_SLOTS: int = 3  # First N slots are insured (survive flee/wipe)

# Stacking limits — materials stack higher than equipment/consumables
const BAG_MATERIAL_STACK_MAX: int = 20       # Materials per slot in hero/shopkeeper bags
const STASH_MATERIAL_STACK_MAX: int = 100    # Materials per slot in run stash
const STASH_DEFAULT_STACK_MAX: int = 20      # Equipment/consumables per slot in run stash

# DEPRECATED (v1.2): Loot routing preference - kept for save compatibility only, not used.
# Manual-only routing now; no auto-assign or remember preference.
var loot_pref: Dictionary = {}

# Gameplay option: auto-deposit loot to shopkeeper bag → hero bags → stash
var auto_loot: bool = false
# Tester mode: enables dev/debug buttons in release builds
var tester_mode: bool = false
# Text size: 0=Small, 1=Medium (default), 2=Large
var text_size: int = 1

# Window scale: 1=960x540, 2=1920x1080, 3=2880x1620, 0=fullscreen
var window_scale: int = 1
# Telemetry consent: player opted in to local play data collection
var telemetry_consent: bool = false

# UI preferences (persisted across sessions)
var loot_panel_size: Vector2 = Vector2(620, 600)


## Returns font size adjusted for text_size setting: Small=-2, Medium=0, Large=+2
func fs(base: int) -> int:
	return base + (text_size - 1) * 2


const WINDOW_SCALES: Dictionary = {
	1: Vector2i(960, 540),
	2: Vector2i(1920, 1080),
	3: Vector2i(2880, 1620),
}

## Apply the current window_scale setting to the display.
func apply_window_scale() -> void:
	if window_scale == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = WINDOW_SCALES.get(window_scale, Vector2i(960, 540))
		DisplayServer.window_set_size(size)
		# Center window on screen
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var pos: Vector2i = (screen_size - size) / 2
		DisplayServer.window_set_position(pos)


## Get the per-slot stack limit for an item in hero/shopkeeper bags.
## Materials stack to BAG_MATERIAL_STACK_MAX; everything else is 1 per slot.
func get_bag_stack_limit(item_id: String) -> int:
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl != null and tpl.item_type == "material":
		return BAG_MATERIAL_STACK_MAX
	return 1


## Get the per-slot stack limit for an item in the run stash.
## Materials stack to STASH_MATERIAL_STACK_MAX; everything else to STASH_DEFAULT_STACK_MAX.
func get_stash_stack_limit(item_id: String) -> int:
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl != null and tpl.item_type == "material":
		return STASH_MATERIAL_STACK_MAX
	return STASH_DEFAULT_STACK_MAX


func apply_text_size_to_theme() -> void:
	var t: Theme = preload("res://Themes/CraftPix/craftpix_ui_tinted.tres")
	t.default_font_size = fs(17)
	t.set_font_size("font_size", "Button", fs(17))
	t.set_font_size("font_size", "Label", fs(17))
	t.set_font_size("font_size", "LineEdit", fs(17))
	t.set_font_size("normal_font_size", "RichTextLabel", fs(16))
	t.set_font_size("font_size", "TooltipLabel", fs(15))

# ============================================================================
# GROUP UNLOCKS (persistent, controls what Shop can sell)
# ============================================================================

# Tracks which unlock_groups have been unlocked for purchase in shops
# { "group_id": true, ... }
var unlocked_groups: Dictionary = {}

# Tracks which tutorials have been shown to the player
# { "tutorial_id": true, ... }
var completed_tutorials: Dictionary = {}

# Tracks campaign/story progression flags
# { "story_r1_arrived": true, "shown_r1_first_arrival": true, ... }
var campaign_flags: Dictionary = {}

# Default unlock groups given on fresh save (so shop isn't empty)
const DEFAULT_UNLOCK_GROUPS: Array[String] = ["consumables_t1", "weapons_t1", "materials_t1"]

# Migration map: old item_id unlocks -> new group unlocks
const ITEM_TO_GROUP_MAP: Dictionary = {
	"healing_tonic": "consumables_t1",
	"antidote": "consumables_t1",
	"stamina_draught": "consumables_t1",
	"rusty_sword": "weapons_t1",
	"iron_dagger": "weapons_t1",
	"rusty_shield": "offhands_t1"
}

# Legacy: keep for backwards compat during migration
var unlocked_item_ids: Dictionary = {}
const DEFAULT_UNLOCKS: Array[String] = ["healing_tonic", "rusty_sword"]

# ============================================================================
# RECIPE UNLOCKS (controls what items appear in General Store)
# ============================================================================

# Tracks which recipes have been unlocked at which facility.
# Key format: "item_id:t{upgrade_tier}" (e.g. "rusty_sword:t1", "rusty_sword:t2")
# Legacy keys without ":t" suffix are treated as upgrade_tier 1.
# Structure: { "key": { "source_facility": "blacksmith", "facility_tier": 2, "upgrade_tier": 1, "output_id": "rusty_sword" } }
# upgrade_tier: 1=plain, 2=regional affix, 3=better base+affix
# When an item is in this dict, it can appear in the General Store.
var unlocked_recipes: Dictionary = {}

# Default recipes unlocked on fresh save — all T1 items across 5 facilities.
# Category rules: Metals/Melee→Blacksmith, Wood/Range/Leather→Huntsman,
# Cloth/Magic→Enchanter, Potions→Alchemist, Food→Chef.
const DEFAULT_UNLOCKED_RECIPES: Dictionary = {
	# --- Blacksmith (Metals/Melee) — 6 items ---
	"rusty_sword:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "rusty_sword" },
	"wooden_mace:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "wooden_mace" },
	"wooden_shield:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "wooden_shield" },
	"bone_dagger:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "bone_dagger" },
	"padded_mail:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "padded_mail" },
	"padded_coif:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "padded_coif" },
	# --- Huntsman (Wood/Range/Leather) — 5 items ---
	"hunting_bow:t1": { "source_facility": "huntsman", "facility_tier": 1, "upgrade_tier": 1, "output_id": "hunting_bow" },
	"leather_vest:t1": { "source_facility": "huntsman", "facility_tier": 1, "upgrade_tier": 1, "output_id": "leather_vest" },
	"tanned_leather_hood:t1": { "source_facility": "huntsman", "facility_tier": 1, "upgrade_tier": 1, "output_id": "tanned_leather_hood" },
	"tanned_leather_greaves:t1": { "source_facility": "huntsman", "facility_tier": 1, "upgrade_tier": 1, "output_id": "tanned_leather_greaves" },
	"small_backpack:t1": { "source_facility": "huntsman", "facility_tier": 1, "upgrade_tier": 1, "output_id": "small_backpack" },
	# --- Enchanter (Cloth/Magic) — 9 items ---
	"oak_staff:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "oak_staff" },
	"apprentice_focus:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "apprentice_focus" },
	"simple_ring:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "simple_ring" },
	"lucky_charm:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "lucky_charm" },
	"copper_band:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "copper_band" },
	"bone_charm:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "bone_charm" },
	"cloth_robe:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "cloth_robe" },
	"cloth_cap:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "cloth_cap" },
	"cloth_leggings:t1": { "source_facility": "enchanter", "facility_tier": 1, "upgrade_tier": 1, "output_id": "cloth_leggings" },
	# --- Alchemist (Potions) — 3 items ---
	"healing_tonic:t1": { "source_facility": "alchemist", "facility_tier": 1, "upgrade_tier": 1, "output_id": "healing_tonic" },
	"minor_healing_tonic:t1": { "source_facility": "alchemist", "facility_tier": 1, "upgrade_tier": 1, "output_id": "minor_healing_tonic" },
	"antidote:t1": { "source_facility": "alchemist", "facility_tier": 1, "upgrade_tier": 1, "output_id": "antidote" },
	# --- Chef (Food) — 5 items ---
	"cooked_meat:t1": { "source_facility": "chef", "facility_tier": 1, "upgrade_tier": 1, "output_id": "cooked_meat" },
	"trail_rations:t1": { "source_facility": "chef", "facility_tier": 1, "upgrade_tier": 1, "output_id": "trail_rations" },
	"mushroom_stew:t1": { "source_facility": "chef", "facility_tier": 1, "upgrade_tier": 1, "output_id": "mushroom_stew" },
	"berry_tart:t1": { "source_facility": "chef", "facility_tier": 1, "upgrade_tier": 1, "output_id": "berry_tart" },
	"minor_stamina_snack:t1": { "source_facility": "chef", "facility_tier": 1, "upgrade_tier": 1, "output_id": "minor_stamina_snack" },
}

# ============================================================================
# MIXING SYSTEM (discovery-based crafting for Chef & Alchemist)
# ============================================================================

# Tracks discovered mixing combinations permanently.
# Key: "facility_id:sorted_item_pair" (e.g., "alchemist:bat_wing:herb_sprig"), Value: true
var discovered_mixes: Dictionary = {}

# Alchemist mishap escalation: increments on each failed mix at alchemist
var alchemist_mishap_streak: int = 0

# Facility lockouts from alchemist mishaps (cleared on town return)
# { facility_id: true } — locked facilities cannot be opened
var locked_facilities: Dictionary = {}

# Inn lockout from alchemist mishaps (cleared on town return)
var inn_lockout: bool = false

# ============================================================================
# DUNGEON FLOOR UNLOCK & START FLOOR SELECTION
# ============================================================================

# Tracks highest unlocked floor per dungeon (dungeon_id -> max unlocked floor)
# Floor 1 is always unlocked by default.
var unlocked_dungeon_floors: Dictionary = {}

# Tracks selected start floor per dungeon (dungeon_id -> selected floor)
var selected_start_floors: Dictionary = {}

# ============================================================================
# FACILITY TIERS (persistent, controls unlock recipe visibility)
# ============================================================================

# Tracks facility tier per town+facility: "town_id:facility_id" -> tier (int)
# Default tier is 1 if not stored.
var facility_tiers: Dictionary = {}

# ============================================================================
# LEARNED CLASSES (persistent, from consuming class books)
# ============================================================================

# Tracks which classes have been learned: { "class_id": true, ... }
var learned_classes: Dictionary = {}

# Map book item_id to class_id
const BOOK_TO_CLASS_MAP: Dictionary = {
	# Region 1 classes
	"book_defender": "defender",
	"book_striker": "striker",
	"book_warden": "warden",
	# Region 2 classes
	"book_druid": "druid",
	"book_fungal_berserker": "fungal_berserker",
	# Region 3 classes
	"book_tidechaser": "tidechaser",
	"book_stormcaller": "stormcaller",
	# Region 4 classes
	"book_pyrewarden": "pyrewarden",
	"book_ashblade": "ashblade",
	# Region 5 classes
	"book_prism_sentinel": "prism_sentinel",
	"book_prism_lancer": "prism_lancer",
	# Region 6 classes
	"book_dark_channeler": "dark_channeler",
	"book_lich": "lich",
	# Region 7 classes
	"book_voidwalker": "voidwalker",
	"book_void_herald": "void_herald"
}

# ============================================================================
# TOWN TIERS (persistent, controls progression gating)
# ============================================================================

# Tracks town tier per town_id: "town_id" -> tier (int)
# Default tier is 1 if not stored.
var town_tiers: Dictionary = {}

# ============================================================================
# HERO RECRUITMENT & PARTY (persistent)
# ============================================================================

# Owned heroes: Array of { "hero_id": String, "class_id": String, "race_id": String, "name": String, "level": int, "xp": int }
var owned_heroes: Array = []

# Selected party for dungeon runs: Array of hero_id strings (max 2 for MVP)
var selected_party: Array = []

# Party size per Inn tier (base 4 for all tiers — no scaling for now)
const PARTY_SIZE_BY_INN_TIER: Dictionary = {1: 4, 2: 4, 3: 4, 4: 4}

# Bench capacity per Inn tier (max heroes benched at each inn)
const BENCH_CAP_BY_INN_TIER: Dictionary = {1: 3, 2: 5, 3: 7, 4: 10}

# ============================================================================
# HERO ROW ASSIGNMENTS (3-Row Formation v1)
# ============================================================================
# Tracks which row each hero is assigned to in combat.
# Key: hero_id, Value: int (0=Front, 1=Middle, 2=Back)
# Default is Middle (1) for all heroes.
var hero_row_assignments: Dictionary = {}


## Get hero's assigned combat row. Returns 1 (Middle) if not explicitly set.
func get_hero_row(hero_id: String) -> int:
	return hero_row_assignments.get(hero_id, 1)  # Default: Middle


## Set hero's combat row assignment. Clamped to valid range 0-2.
func set_hero_row(hero_id: String, row: int) -> void:
	hero_row_assignments[hero_id] = clampi(row, 0, 2)


# ============================================================================
# HERO GRID PLACEMENTS (Placement Memory — Grid Combat v1)
# ============================================================================
# Tracks last confirmed grid position for each hero across combats.
# Key: hero_id (String), Value: {"x": int, "y": int}
var hero_grid_placements: Dictionary = {}


## Get hero's last saved grid position. Returns null if no saved position.
func get_hero_grid_placement(hero_id: String):
	return hero_grid_placements.get(hero_id)


## Save a hero's grid position after placement confirmation.
func set_hero_grid_placement(hero_id: String, pos: Vector2i) -> void:
	hero_grid_placements[hero_id] = {"x": pos.x, "y": pos.y}


# Counter for generating unique hero IDs
var _hero_id_counter: int = 0

# ============================================================================
# HERO HP PERSISTENCE (Health Persistence v1)
# ============================================================================
# Tracks hero HP between combats during dungeon run.
# Key: hero_id, Value: { "current": int, "max": int }
# Cleared/reset on town entry.
var hero_hp: Dictionary = {}

# ============================================================================
# DEAD HEROES TRACKING (Permadeath / Book of the Dead)
# ============================================================================
# Tracks heroes who have died in dungeons. Used for:
# 1. Removing dead heroes from roster on town return
# 2. Future "Book of the Dead" memorial feature
# Array of hero data snapshots: [{ hero_id, name, race_id, class_id, level, cause, timestamp }]
# Persisted to save file. Cleared on reset_save_game.
var dead_heroes: Array = []

# ============================================================================
# HERO STATUS PERSISTENCE (Consumables v2)
# ============================================================================
# Tracks hero statuses (DOT, debuffs) between combats during dungeon run.
# Key: hero_id, Value: Array of status dicts [{ "id": String, "stacks": int, "remaining_rounds": int }]
# Cleared/reset on town entry.
var hero_statuses: Dictionary = {}

# ============================================================================
# CONSUMABLE USAGE TRACKING (Consumables v1)
# ============================================================================
# Tracks which heroes have used a consumable this combat.
# Reset at start of each combat.
var _combat_consumables_used: Dictionary = {}  # hero_id -> true

# Tracks whether any hero has died during the current dungeon run.
# Used to show the camp flee button (flee only available after a hero falls).
var _hero_died_this_run: bool = false

func set_hero_died_this_run(value: bool) -> void:
	_hero_died_this_run = value
	if value:
		print("[GameContext] Hero died this run — camp flee now available")

func has_hero_died_this_run() -> bool:
	return _hero_died_this_run

# ============================================================================
# TRAINING SLOTS — Heroes placed in training earn XP during dungeon runs
# ============================================================================

## town_id → Array of hero_ids in training at that town's Training Hall
var training_slots: Dictionary = {}

const TRAINING_SLOTS_BY_TIER: Dictionary = {1: 2, 2: 3, 3: 3, 4: 4}
const TRAINING_XP_RATE_BY_TIER: Dictionary = {1: 0.50, 2: 0.50, 3: 0.60, 4: 0.75}

## Get number of training slots available at a town based on Training Hall tier.
func get_training_slot_count(town_id: String) -> int:
	var tier: int = get_facility_tier(town_id, "training_hall")
	if tier <= 0:
		return 0
	return TRAINING_SLOTS_BY_TIER.get(tier, 2)

## Get array of hero_ids currently in training at a specific town.
func get_training_heroes(town_id: String) -> Array:
	return training_slots.get(town_id, [])

## Assign a hero to a training slot at a specific town.
func assign_hero_to_training(hero_id: String, town_id: String) -> bool:
	if hero_id == "" or town_id == "":
		return false
	# Must not be in party
	if is_in_party(hero_id):
		print("[Training] Cannot train party member: %s" % hero_id)
		return false
	# Must not already be training somewhere
	if is_hero_in_training(hero_id):
		print("[Training] Hero already in training: %s" % hero_id)
		return false
	# Check slot capacity
	var current: Array = training_slots.get(town_id, [])
	var max_slots: int = get_training_slot_count(town_id)
	if current.size() >= max_slots:
		print("[Training] No slots available at %s (%d/%d)" % [town_id, current.size(), max_slots])
		return false
	# Assign
	if not training_slots.has(town_id):
		training_slots[town_id] = []
	training_slots[town_id].append(hero_id)
	print("[Training] Assigned hero=%s to training at %s (%d/%d)" % [hero_id, town_id, training_slots[town_id].size(), max_slots])
	save_game()
	return true

## Remove a hero from training (any town).
func remove_hero_from_training(hero_id: String) -> void:
	for town_id in training_slots.keys():
		var heroes: Array = training_slots[town_id]
		if hero_id in heroes:
			heroes.erase(hero_id)
			training_slots[town_id] = heroes
			print("[Training] Removed hero=%s from training at %s" % [hero_id, town_id])
			save_game()
			return

## Check if a hero is currently in training at any town.
func is_hero_in_training(hero_id: String) -> bool:
	for town_id in training_slots.keys():
		if hero_id in training_slots[town_id]:
			return true
	return false

## Get the training XP rate for a specific town based on Training Hall tier.
func get_training_xp_rate(town_id: String) -> float:
	var tier: int = get_facility_tier(town_id, "training_hall")
	if tier <= 0:
		return 0.0
	return TRAINING_XP_RATE_BY_TIER.get(tier, 0.50)

## Grant XP to heroes in training slots. Each town grants XP at its tier's rate.
func grant_training_heroes_xp(xp_amount: int) -> Dictionary:
	var result: Dictionary = {}
	if xp_amount <= 0:
		return result
	for town_id in training_slots.keys():
		var rate: float = get_training_xp_rate(town_id)
		if rate <= 0.0:
			continue
		var training_xp: int = int(ceil(xp_amount * rate))
		for hero_id in training_slots[town_id]:
			var levels: int = grant_hero_xp(hero_id, training_xp)
			if levels > 0:
				print("[XP] training hero=%s at %s gained %d%% XP (%d base), leveled up %d times" % [hero_id, town_id, int(rate * 100), training_xp, levels])
			result[hero_id] = levels
	return result

# ============================================================================
# HERO LEVELING CONSTANTS (per GDD Section 33.3)
# ============================================================================

# Max hero level (55 levels across 7 regions, RuneScape-style XP curve)
const MAX_HERO_LEVEL: int = 55

# XP required to reach each level (index = level - 1, so index 0 = level 1)
# Exponential curve: floor(8 + 7*(L-1) + 3.2*(L-1)^1.7)
# Total XP to 55: ~68,613
const XP_THRESHOLDS: Array[int] = [
	0, 18, 50, 99, 168, 260, 377, 521, 694, 899,           # L1-L10
	1137, 1410, 1720, 2069, 2459, 2891, 3367, 3889, 4458, 5076,  # L11-L20
	5745, 6466, 7240, 8069, 8955, 9899, 10902, 11966, 13093, 14284, # L21-L30
	15540, 16862, 18252, 19711, 21241, 22843, 24518, 26267, 28092, 29994, # L31-L40
	31974, 34034, 36175, 38398, 40704, 43095, 45572, 48135, 50787, 53528, # L41-L50
	56359, 59282, 62298, 65408, 68613  # L51-L55
]

# Ability/Passive unlock thresholds by slot
const ABILITY_UNLOCK_LEVELS: Dictionary = {
	"ability_a": 5,
	"passive_a": 15,
	"ability_b": 25,
	"passive_b": 40,
}

# Base XP award per normal combat encounter by region
const REGION_XP_BASE: Dictionary = {
	1: 15, 2: 28, 3: 45, 4: 70, 5: 100, 6: 140, 7: 190
}

# ============================================================================
# STASH UPGRADES (persistent, purchased from General Store)
# ============================================================================

# Tracks purchased stash upgrades: { "upgrade_id": true }
# Legacy name "housing_upgrades" kept for save compatibility
var housing_upgrades: Dictionary = {}

# Bonus stash capacity from purchased upgrades
var bonus_stash_capacity: int = 0

# ============================================================================
# SHOP REFRESH COUNTERS (controls deterministic inventory generation)
# ============================================================================

# Tracks manual refresh uses per shop: "shop_id" -> uses (int)
# Reset on dungeon return so player gets fresh allowance each visit
var shop_refresh_counts: Dictionary = {}

# Monotonically increasing restock version per shop: "shop_id" -> version (int)
# Used as seed component for deterministic inventory generation
var shop_restock_version: Dictionary = {}

# ============================================================================
# SHOP SLOT ALLOCATION (General Store v2 - Facility-based slots)
# ============================================================================

# Tracks slot allocation per town: { "town_id": { "blacksmith": 2, "leatherworker": 1, ... } }
# Slots determine how many items from each facility appear in the General Store.
var shop_slot_allocations: Dictionary = {}

# Tracks purchased shop slots per shop: { "shop_id": ["facility_id:slot_idx", ...] }
# Used to show empty slots after purchase instead of regenerating items.
var shop_purchased_slots: Dictionary = {}

# Tracks Inn restock count per town: { "town_id": restock_count }
# Persisted so recruit seeds vary across auto-restocks even after scene reload.
var inn_restock_counts: Dictionary = {}

# Shop tier constants: max total slots available based on shop tier
const SHOP_TIER_MAX_SLOTS: Dictionary = {
	1: 4,   # Tier 1: 4 total slots
	2: 6,   # Tier 2: 6 total slots
	3: 8,   # Tier 3: 8 total slots
	4: 10   # Tier 4: 10 total slots
}

# Facilities that can contribute items to the General Store
const SHOP_CONTRIBUTING_FACILITIES: Array[String] = ["blacksmith", "huntsman", "enchanter", "alchemist", "chef"]

# Stash capacity constants
const STASH_BASE_CAPACITY: int = 30
const STASH_CAPACITY_PER_STORAGE_TIER: int = 5

# ============================================================================
# PERSISTENCE CONSTANTS
# ============================================================================

const SAVE_SLOT_COUNT := 4
var current_save_slot: int = -1  # -1 = no slot selected (title screen)

## Cached save directory path (computed once on first access).
var _save_dir_cache: String = ""


## Get the base directory for save files.
## Exported builds: saves/ folder next to the .exe for easy player access.
## Editor: Godot's user:// directory (AppData).
func _get_save_dir() -> String:
	if _save_dir_cache != "":
		return _save_dir_cache
	if OS.has_feature("editor"):
		_save_dir_cache = "user://"
	else:
		_save_dir_cache = OS.get_executable_path().get_base_dir().path_join("saves")
		if not DirAccess.dir_exists_absolute(_save_dir_cache):
			DirAccess.make_dir_recursive_absolute(_save_dir_cache)
			print("[GameContext] Created save directory: %s" % _save_dir_cache)
	print("[GameContext] Save directory: %s" % _save_dir_cache)
	return _save_dir_cache


## Get the legacy single-file save path (migration fallback).
func _get_legacy_save_path() -> String:
	return _get_save_dir().path_join("savegame.json")


## Get the slots metadata file path.
func _get_slots_meta_path() -> String:
	return _get_save_dir().path_join("slots_metadata.json")


## Get the save file path for a given slot (or current slot if -1).
func get_save_path(slot: int = -1) -> String:
	var s: int = slot if slot >= 0 else current_save_slot
	if s < 0 or s >= SAVE_SLOT_COUNT:
		return _get_legacy_save_path()
	return _get_save_dir().path_join("savegame_slot_%d.json" % s)


## Check if a save slot has an existing save file.
func slot_has_save(slot: int) -> bool:
	if slot < 0 or slot >= SAVE_SLOT_COUNT:
		return false
	return FileAccess.file_exists(get_save_path(slot))


## Load metadata for all save slots (lightweight summary for title screen).
func load_slot_metadata() -> Array:
	var slots: Array = []
	if FileAccess.file_exists(_get_slots_meta_path()):
		var file = FileAccess.open(_get_slots_meta_path(), FileAccess.READ)
		if file != null:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data: Dictionary = json.get_data()
				slots = data.get("slots", [])
			file.close()
	# Ensure we always return exactly SAVE_SLOT_COUNT entries
	while slots.size() < SAVE_SLOT_COUNT:
		slots.append({"exists": false})
	return slots


## Save metadata for all save slots.
func save_slot_metadata() -> void:
	var slots: Array = load_slot_metadata()
	# Update the current slot's metadata
	if current_save_slot >= 0 and current_save_slot < SAVE_SLOT_COUNT:
		slots[current_save_slot] = {
			"exists": true,
			"region": current_region,
			"heroes": owned_heroes.size(),
			"gold": run_gold,
			"ng_cycle": ng_plus_cycle,
			"play_date": Time.get_date_string_from_system(),
		}
	var file = FileAccess.open(_get_slots_meta_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"slots": slots}, "\t"))
		file.close()


## Select a save slot and load its data.
func select_slot(slot: int) -> void:
	current_save_slot = slot
	print("[GameContext] Selected save slot %d (%s)" % [slot, get_save_path(slot)])
	load_game()


## Start a new game in the given save slot.
func start_new_game(slot: int) -> void:
	# Delete old save if it exists
	var path: String = get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	current_save_slot = slot
	# Reset all state to defaults (same as reset_save_game but targeted)
	_reset_all_state_to_defaults()
	auto_discover_base_recipes()
	save_game()
	print("[GameContext] New game started in slot %d" % slot)


## Delete a specific save slot.
func delete_slot(slot: int) -> void:
	var path: String = get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	# Update metadata
	var slots: Array = load_slot_metadata()
	if slot >= 0 and slot < slots.size():
		slots[slot] = {"exists": false}
	var file = FileAccess.open(_get_slots_meta_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"slots": slots}, "\t"))
		file.close()
	print("[GameContext] Deleted save slot %d" % slot)


## Migrate legacy single-file save to slot 0 if needed.
func migrate_legacy_save() -> void:
	if FileAccess.file_exists(_get_legacy_save_path()) and not FileAccess.file_exists(get_save_path(0)):
		# Copy legacy save to slot 0
		var file = FileAccess.open(_get_legacy_save_path(), FileAccess.READ)
		if file != null:
			var content: String = file.get_as_text()
			file.close()
			var slot_file = FileAccess.open(get_save_path(0), FileAccess.WRITE)
			if slot_file != null:
				slot_file.store_string(content)
				slot_file.close()
				# Update metadata for slot 0
				current_save_slot = 0
				load_game()
				save_slot_metadata()
				current_save_slot = -1  # Reset to no slot (title screen will pick)
				print("[GameContext] Migrated legacy save to slot 0")


## On first exported run, copy existing user:// saves to portable saves/ folder.
func _migrate_user_saves_to_portable() -> void:
	if OS.has_feature("editor"):
		return
	var portable_dir: String = _get_save_dir()
	# Already migrated if portable dir has metadata
	if FileAccess.file_exists(portable_dir.path_join("slots_metadata.json")):
		return
	# Nothing to migrate if user:// has no saves
	if not FileAccess.file_exists("user://slots_metadata.json"):
		return
	print("[GameContext] Migrating saves from user:// to %s" % portable_dir)
	var files_to_copy: Array = ["slots_metadata.json", "savegame.json"]
	for i in range(SAVE_SLOT_COUNT):
		files_to_copy.append("savegame_slot_%d.json" % i)
	for fname in files_to_copy:
		var src: String = "user://" + fname
		if FileAccess.file_exists(src):
			var file = FileAccess.open(src, FileAccess.READ)
			if file != null:
				var content: String = file.get_as_text()
				file.close()
				var out = FileAccess.open(portable_dir.path_join(fname), FileAccess.WRITE)
				if out != null:
					out.store_string(content)
					out.close()
					print("[GameContext]   Copied %s" % fname)


## Reset all runtime state to defaults (used by start_new_game and reset_save_game).
func _reset_all_state_to_defaults() -> void:
	player_gold = 400
	player_items = {}
	next_run_bonus_max_hp = 0
	next_run_trained = false
	pending_combat_modifier = {}
	pending_combat_statuses.clear()
	equipped_weapon_id = ""
	equipped_weapon_quality = 0
	equipped_offhand_id = ""
	equipped_offhand_quality = 0
	hero_equipment = {}
	hero_bags = {}
	_gear_logged_heroes.clear()
	shopkeeper_bag = []
	hero_hp = {}
	hero_statuses = {}
	_combat_consumables_used = {}
	dead_heroes = []
	loot_pref = {}
	unlocked_groups = {}
	unlocked_item_ids = {}
	unlocked_recipes = {}
	completed_tutorials = {}
	campaign_flags = {}
	ng_plus_cycle = 0
	ng_plus_perm_stat_bonus = 0.0
	seen_abilities = {}
	active_side_quests = []
	training_slots = {}
	returned_from_dungeon = false
	_side_quest_counter = 0
	mini_dungeon_state = {}
	active_campaign_quest = null
	completed_campaign_quests = []
	discovered_mixes = {}
	alchemist_mishap_streak = 0
	locked_facilities = {}
	inn_lockout = false
	unlocked_dungeon_floors = {}
	selected_start_floors = {}
	facility_tiers = {}
	learned_classes = {}
	town_tiers = {}
	owned_heroes = []
	selected_party = []
	_hero_id_counter = 0
	housing_upgrades = {}
	bonus_stash_capacity = 0
	shop_refresh_counts = {}
	shop_restock_version = {}
	shop_purchased_slots = {}
	shop_slot_allocations = {}
	inn_restock_counts = {}
	run_gold = 400
	run_items = []
	dungeon_gold = 0
	dungeon_items = []
	current_dungeon_id = ""
	current_floor = 0
	current_room_index = 0
	rooms_per_floor = 1
	current_room_type = "combat"
	current_room_is_elite = false
	pending_room_choices = {}
	pending_selected_choice = {}
	current_room_payload = {}
	_last_room_was_event = false
	_run_id = ""
	_run_seed = 0
	_run_active = false
	_run_counter = 0
	_current_phase = GamePhase.TOWN
	_current_region_id = "region_1"
	_current_town_id = "town_thornhaven"
	_selected_floor_index = 1
	_party_hero_ids = []
	current_region = 1
	completed_regions = {}
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1
	hero_row_assignments = {}
	hero_grid_placements = {}
	auto_loot = false

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
	# Phase stays as BOOT (default) until TitleScreen or in-game transition sets it
	_current_region_id = "region_1"
	_current_town_id = "town_thornhaven"
	_selected_floor_index = 1
	_party_hero_ids = []
	_run_id = ""
	_run_seed = 0
	_run_active = false
	current_region = 1

	# Copy user:// saves to portable saves/ folder on first exported run
	_migrate_user_saves_to_portable()
	# Migrate legacy single-file save to slot 0 if needed
	migrate_legacy_save()

	# Load saved game data (floor unlocks, selected floors, etc.)
	# Note: With the new title screen, load_game() uses the legacy fallback path
	# when current_save_slot == -1. The title screen will call select_slot() later.
	load_game()
	apply_text_size_to_theme()
	apply_window_scale()
	# Ensure run_seed is non-zero even before first dungeon entry
	# (existing saves restore _run_seed via load_game; fresh games need one now for shop RNG)
	if _run_seed == 0:
		_run_seed = SeededRNG.generate_random_seed()


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

	# Clear facility lockouts when returning to town
	if new_phase == GamePhase.TOWN or new_phase == GamePhase.TOWN_HUB:
		clear_facility_lockouts()

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


## Get the current region number (1-7).
func get_current_region() -> int:
	return current_region


## Set the current region number. Clamped to 1-7, persisted immediately.
func set_current_region(region: int) -> void:
	var old_region = current_region
	current_region = clampi(region, 1, 7)
	if old_region != current_region:
		print("[Region] set region=%d" % current_region)
		save_game()


## Mark a region as completed (boss defeated). Idempotent.
## Also looks up the NEXT region and stores it as a pending unlock notification.
func mark_region_completed(region_id: String) -> void:
	if not completed_regions.has(region_id):
		completed_regions[region_id] = true
		print("[Region] Completed: %s (total=%d)" % [region_id, completed_regions.size()])
		# Find the next region that is now unlocked by this completion
		var all_regions: Array = DataRegistry.get_all_regions() if DataRegistry.has_method("get_all_regions") else []
		for r in all_regions:
			if r.requires_region_id == region_id:
				_pending_region_unlock = r.region_id
				print("[Region] Next region unlocked: %s" % r.region_id)
				break
		save_game()


## Get the number of completed regions (for scaling formulas).
func get_completed_region_count() -> int:
	return completed_regions.size()


## Check if a specific region has been completed.
func is_region_completed(region_id: String) -> bool:
	return completed_regions.get(region_id, false)


## Get the pending region unlock ID (for UI notification). Returns "" if none.
func get_pending_region_unlock() -> String:
	return _pending_region_unlock


## Clear the pending region unlock after UI has shown the notification.
func clear_pending_region_unlock() -> void:
	_pending_region_unlock = ""


## Check if a region is unlocked (previous region's boss defeated).
## Region 1 is always unlocked.
func is_region_unlocked(region_id: String) -> bool:
	var region_data: RegionData = DataRegistry.get_region(region_id) if DataRegistry.has_method("get_region") else null
	if region_data == null:
		return false
	var req: String = region_data.requires_region_id
	if req == "":
		return true  # R1 has no prerequisite
	return is_region_completed(req)


## Get the sum of all facility tiers for a town.
func get_total_facility_tiers(town_id: String) -> int:
	var total: int = 0
	for key in facility_tiers.keys():
		if key.begins_with(town_id + ":"):
			total += int(facility_tiers[key])
	return total

## Boss floor gate removed — bosses are now gated by difficulty, not facility tiers.
## Kept constant for reference / potential future use.
const BOSS_FLOOR_TIER_REQUIREMENT: int = 0

## Check if the player can enter the boss floor.
## Gate removed — always returns ready=true. Bosses are naturally hard enough.
## Returns { "ready": bool, "current": int, "required": int }
func can_challenge_boss(town_id: String) -> Dictionary:
	var current: int = get_total_facility_tiers(town_id)
	return {"ready": true, "current": current, "required": 0}


## Strip all equipment and bag items from a hero (used on flee).
func strip_hero_gear(hero_id: String) -> void:
	if hero_equipment.has(hero_id):
		hero_equipment.erase(hero_id)
		print("[Flee] Stripped equipment from hero=%s" % hero_id)
	if hero_bags.has(hero_id):
		hero_bags.erase(hero_id)
		print("[Flee] Stripped bag from hero=%s" % hero_id)


## Strip non-starter equipment from all surviving heroes (used on flee).
## Starter gear = tier 1, quality 0 (common) items — these are kept.
## Dead heroes are excluded (they'll be removed by permadeath).
func strip_heroes_except_starter() -> void:
	var stripped: int = 0
	for hero_id in selected_party:
		var hero: Dictionary = get_hero(hero_id)
		if hero.is_empty():
			continue
		var hp_data: Dictionary = get_hero_hp(hero_id)
		if int(hp_data.get("current", 1)) <= 0:
			continue  # Dead heroes handled by permadeath

		var equip: Dictionary = get_hero_equipment(hero_id)
		for slot in ALL_EQUIP_SLOTS:
			var slot_data: Dictionary = equip.get(slot, {})
			var item_id: String = slot_data.get("id", "")
			if item_id == "":
				continue  # Empty slot
			var quality: int = int(slot_data.get("quality", 0))
			# Starter gear = tier 1, quality 0 — keep these
			if quality == 0:
				var tpl = DataRegistry.get_item_template(item_id)
				if tpl != null and int(tpl.tier) <= 1:
					continue  # Starter gear — keep
			# Strip non-starter equipment (lost, not returned to stash)
			hero_equipment[hero_id][slot] = {"id": "", "quality": 0}
			stripped += 1

		# Clear hero bag (bag items lost on flee)
		if hero_bags.has(hero_id):
			hero_bags[hero_id] = []

	print("[Flee] Stripped %d non-starter equipment pieces from surviving heroes" % stripped)


func get_current_town_id() -> String:
	return _current_town_id


## Get max party size based on current town's Inn tier.
func get_max_party_size() -> int:
	var inn_tier = get_facility_tier(_current_town_id, "inn")
	return PARTY_SIZE_BY_INN_TIER.get(inn_tier, 2)


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

	# Sync the integer current_region from the string region_id
	var region_num = int(region_id.replace("region_", ""))
	if region_num >= 1 and region_num <= 7:
		set_current_region(region_num)

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

	# Party size limit based on Inn tier
	var max_size = get_max_party_size()
	if _party_hero_ids.size() >= max_size:
		push_warning("[GameContext] Party full (max %d heroes)" % max_size)
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
# PUBLIC API - RUN STASH
# ============================================================================

func add_rewards(gold: int, items: Array) -> void:
	# Route to dungeon stash if in dungeon, otherwise to run stash
	if current_dungeon_id != "":
		add_dungeon_rewards(gold, items)
	else:
		run_gold += maxi(gold, 0)
		for it in items:
			run_items.append(it)


func clear_run_stash() -> void:
	run_gold = 0
	run_items.clear()


func get_run_stash_summary() -> Dictionary:
	return { "gold": run_gold, "items_count": run_items.size() }


## Get run gold amount.
func get_run_gold() -> int:
	return run_gold


## Add gold to run stash.
func add_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	run_gold += amount
	print("[RunStash] +%d gold => %d total" % [amount, run_gold])


## Spend gold from run stash. Returns true if successful.
func spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_gold < amount:
		print("[RunStash] Cannot spend %d gold (only have %d)" % [amount, run_gold])
		return false
	run_gold -= amount
	print("[RunStash] -%d gold => %d remaining" % [amount, run_gold])
	return true


## Calculate gold cost for crafting an item at an equipment facility.
## Returns base_value * 2 (same as shop buy price). 0 for unknown items.
func get_craft_gold_cost(item_id: String) -> int:
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return 0
	return tpl.base_value * 2


## Get run items as Dictionary (template_id -> qty).
## Handles both ItemInstance objects (dungeon loot) and Dictionary items (shop purchases).
## Sums quantities across all quality tiers for ItemInstance.
func get_run_items_dict() -> Dictionary:
	var result: Dictionary = {}
	for item in run_items:
		var template_id = ""
		var qty = 1
		if item is ItemInstance:
			template_id = item.template_id
			qty = item.quantity
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
		if template_id != "":
			result[template_id] = result.get(template_id, 0) + qty
	return result


## Get dungeon stash items as aggregated dictionary { item_id: qty }.
func get_dungeon_items_dict() -> Dictionary:
	var result: Dictionary = {}
	for item in dungeon_items:
		var template_id = ""
		var qty = 1
		if item is ItemInstance:
			template_id = item.template_id
			qty = item.quantity
		elif item is Dictionary:
			template_id = item.get("item_id", "")
			qty = item.get("qty", 1)
		if template_id != "":
			result[template_id] = result.get(template_id, 0) + qty
	return result


## Get count of a specific item in run stash (all qualities combined).
func get_run_item_count(template_id: String) -> int:
	if template_id == "":
		return 0
	var count = 0
	for item in run_items:
		if item is ItemInstance:
			if item.template_id == template_id:
				count += item.quantity
		elif item is Dictionary:
			if item.get("item_id", "") == template_id:
				count += item.get("qty", 1)
	return count


## Get maximum stash capacity based on all Storage facility tiers across regions.
func get_max_stash_capacity() -> int:
	var total: int = STASH_BASE_CAPACITY
	for key in facility_tiers.keys():
		if key.ends_with(":storage"):
			total += facility_tiers[key] * STASH_CAPACITY_PER_STORAGE_TIER
	return total + bonus_stash_capacity

## Get current stash slot count (each entry = 1 slot).
## v1.4: Slot-based capacity — entries count, not distinct IDs.
func get_current_stash_count() -> int:
	return run_items.size()

## Check if stash has room for an item. Checks existing stack room first, then free slots.
## v1.4: Slot-based model — items merge into existing stacks before needing new slots.
func can_add_to_stash(item_id: String = "") -> bool:
	if item_id != "":
		var stack_limit: int = get_stash_stack_limit(item_id)
		for item in run_items:
			var tid: String = ""
			if item is ItemInstance:
				tid = item.template_id
			elif item is Dictionary:
				tid = item.get("item_id", "")
			if tid == item_id:
				var current_qty: int = 0
				if item is ItemInstance:
					current_qty = item.quantity
				elif item is Dictionary:
					current_qty = int(item.get("qty", 1))
				if current_qty < stack_limit:
					return true
	return run_items.size() < get_max_stash_capacity()

## Add item to run stash with stacking. Returns false if stash is full.
## v1.4: Merges into existing stacks (matching item_id + quality_tier) up to stack limit.
##        Overflows into new slots. Materials cap at 100, others at 20 per slot.
func add_run_item(item_id: String, qty: int = 1, quality: int = 0) -> bool:
	if item_id == "" or qty <= 0:
		return false
	var stack_limit: int = get_stash_stack_limit(item_id)
	var remaining: int = qty

	# Phase 1: Merge into existing stacks (matching item_id + quality_tier)
	for item in run_items:
		if remaining <= 0:
			break
		if item is Dictionary and item.get("item_id", "") == item_id and int(item.get("quality_tier", 0)) == quality:
			var current: int = int(item.get("qty", 1))
			var space: int = stack_limit - current
			if space > 0:
				var add_amt: int = mini(remaining, space)
				item["qty"] = current + add_amt
				remaining -= add_amt
		elif item is ItemInstance and item.template_id == item_id and item.quality_tier == quality:
			var current: int = item.quantity
			var space: int = stack_limit - current
			if space > 0:
				var add_amt: int = mini(remaining, space)
				item.quantity = current + add_amt
				remaining -= add_amt

	# Phase 2: Overflow into new slots
	while remaining > 0:
		if run_items.size() >= get_max_stash_capacity():
			print("[RunStash] FULL: cannot add remaining %d %s (slots=%d max=%d)" % [remaining, item_id, run_items.size(), get_max_stash_capacity()])
			return false
		var add_amt: int = mini(remaining, stack_limit)
		run_items.append({"item_id": item_id, "qty": add_amt, "quality_tier": quality})
		remaining -= add_amt

	print("[RunStash] +%d %s => %d/%d slots" % [qty, item_id, run_items.size(), get_max_stash_capacity()])
	return true


## Remove item from run stash. Returns true if successful.
## v1.4: Decrements qty from stacked entries. Removes entry when qty reaches 0.
## Handles both ItemInstance (lowest quality first) and Dictionary items.
func remove_run_item(template_id: String, qty: int = 1) -> bool:
	if template_id == "" or qty <= 0:
		return true

	var remaining: int = qty

	# First pass: decrement from ItemInstances sorted by quality (lowest first)
	var instance_indices: Array = []
	for i in range(run_items.size()):
		var item = run_items[i]
		if item is ItemInstance and item.template_id == template_id:
			instance_indices.append({"index": i, "quality": item.quality_tier})
	instance_indices.sort_custom(func(a, b): return a.quality < b.quality)

	var indices_to_remove: Array = []
	for entry in instance_indices:
		if remaining <= 0:
			break
		var idx: int = entry.index
		var item = run_items[idx]
		var item_qty: int = item.quantity
		if item_qty <= remaining:
			indices_to_remove.append(idx)
			remaining -= item_qty
		else:
			item.quantity -= remaining
			remaining = 0

	# Second pass: decrement from Dictionary items if still needed
	if remaining > 0:
		for i in range(run_items.size()):
			if remaining <= 0:
				break
			var item = run_items[i]
			if item is Dictionary and item.get("item_id", "") == template_id:
				var item_qty: int = int(item.get("qty", 1))
				if item_qty <= remaining:
					if i not in indices_to_remove:
						indices_to_remove.append(i)
					remaining -= item_qty
				else:
					item["qty"] = item_qty - remaining
					remaining = 0

	# Remove depleted entries in reverse order
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for idx in indices_to_remove:
		run_items.remove_at(idx)

	var removed: int = qty - remaining
	if remaining > 0:
		print("[RunStash] Wanted to remove %d %s but only found %d" % [qty, template_id, removed])
		return false

	print("[RunStash] -%d %s => %d slots total" % [removed, template_id, run_items.size()])
	return true


## Remove items matching BOTH template_id AND quality_tier from run stash.
## v1.4: Decrements qty from stacked entries. Returns the number actually removed.
func remove_run_item_by_quality(template_id: String, quality_tier: int, qty: int = 1) -> int:
	if template_id == "" or qty <= 0:
		return 0

	var remaining: int = qty
	var indices_to_remove: Array = []

	for i in range(run_items.size()):
		if remaining <= 0:
			break
		var item = run_items[i]
		if item is ItemInstance and item.template_id == template_id and item.quality_tier == quality_tier:
			var item_qty: int = item.quantity
			if item_qty <= remaining:
				indices_to_remove.append(i)
				remaining -= item_qty
			else:
				item.quantity -= remaining
				remaining = 0
		elif item is Dictionary and item.get("item_id", "") == template_id:
			var item_quality: int = int(item.get("quality_tier", 0))
			if item_quality == quality_tier:
				var item_qty: int = int(item.get("qty", 1))
				if item_qty <= remaining:
					indices_to_remove.append(i)
					remaining -= item_qty
				else:
					item["qty"] = item_qty - remaining
					remaining = 0

	# Remove depleted entries in reverse order
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for idx in indices_to_remove:
		run_items.remove_at(idx)

	var removed: int = qty - remaining
	if removed > 0:
		print("[RunStash] -%d %s (q%d) => %d slots total" % [removed, template_id, quality_tier, run_items.size()])
	return removed


# ============================================================================
# PUBLIC API - PLAYER INVENTORY (Town persistent storage)
# ============================================================================

## Get player gold.
func get_player_gold() -> int:
	return player_gold


## Add gold to player inventory.
func add_player_gold(amount: int) -> void:
	if amount <= 0:
		return
	player_gold += amount
	print("[Facility][Inventory] +%d gold => %d total" % [amount, player_gold])


## Spend gold from player inventory. Returns true if successful.
func spend_player_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if player_gold < amount:
		print("[Facility][Inventory] Cannot spend %d gold (only have %d)" % [amount, player_gold])
		return false
	player_gold -= amount
	print("[Facility][Inventory] -%d gold => %d remaining" % [amount, player_gold])
	return true


## Get player items as Dictionary (item_id -> qty).
func get_player_items() -> Dictionary:
	return player_items.duplicate()


## Add item to player inventory.
func add_player_item(item_id: String, qty: int = 1) -> void:
	if item_id == "" or qty <= 0:
		return
	player_items[item_id] = player_items.get(item_id, 0) + qty
	print("[Facility][Inventory] +%d %s => %d total" % [qty, item_id, player_items[item_id]])


## Remove item from player inventory. Returns true if successful.
func remove_player_item(item_id: String, qty: int = 1) -> bool:
	if item_id == "" or qty <= 0:
		return true
	var current = player_items.get(item_id, 0)
	if current < qty:
		print("[Facility][Inventory] Cannot remove %d %s (only have %d)" % [qty, item_id, current])
		return false
	player_items[item_id] = current - qty
	if player_items[item_id] <= 0:
		player_items.erase(item_id)
	print("[Facility][Inventory] -%d %s => %d remaining" % [qty, item_id, player_items.get(item_id, 0)])
	return true


## Check if player has item.
func has_player_item(item_id: String, qty: int = 1) -> bool:
	return player_items.get(item_id, 0) >= qty


## Debug: Give test items to player.
func debug_give_test_items() -> void:
	add_player_item("herb_sprig", 5)
	add_player_item("wood_bundle", 3)
	add_player_item("iron_scrap", 3)
	add_player_gold(50)
	print("[Facility][Debug] Gave test items: herb_sprig x5, wood x3, iron_scrap x3, +50 gold")


# ============================================================================
# PUBLIC API - TRAINING BUFFS
# ============================================================================

## Purchase training buff (costs gold from run stash).
func purchase_training_buff(buff_type: String, cost: int) -> bool:
	if not spend_run_gold(cost):
		print("[Training] Cannot afford training (cost %d, have %d)" % [cost, run_gold])
		return false

	match buff_type:
		"max_hp":
			next_run_bonus_max_hp += 10
			next_run_trained = true
			print("[Training] Purchased +10 Max HP buff for next run (total bonus: %d)" % next_run_bonus_max_hp)
		_:
			print("[Training] Unknown buff type: %s" % buff_type)
			return false

	return true


## Get training buff status.
func get_training_status() -> Dictionary:
	return {
		"trained": next_run_trained,
		"bonus_max_hp": next_run_bonus_max_hp
	}


## Apply and clear training buffs (called when entering dungeon).
func apply_and_clear_training_buffs() -> Dictionary:
	var applied = {
		"bonus_max_hp": next_run_bonus_max_hp
	}
	if next_run_trained:
		print("[Training] Applying training buffs: +%d Max HP" % next_run_bonus_max_hp)
	next_run_bonus_max_hp = 0
	next_run_trained = false
	return applied


# ============================================================================
# PUBLIC API - PENDING COMBAT MODIFIER
# ============================================================================

## Set a pending combat modifier (from event choice).
func set_pending_combat_modifier(mod: Dictionary) -> void:
	pending_combat_modifier = mod.duplicate()
	var mod_id = mod.get("id", "unknown")
	var mod_label = mod.get("label", "")
	print("[Modifier] Set pending modifier: %s (%s)" % [mod_id, mod_label])


## Check if there's a pending combat modifier.
func has_pending_combat_modifier() -> bool:
	return not pending_combat_modifier.is_empty()


## Consume and return the pending combat modifier, then clear it.
func consume_pending_combat_modifier() -> Dictionary:
	if pending_combat_modifier.is_empty():
		return {}
	var mod = pending_combat_modifier.duplicate()
	pending_combat_modifier = {}
	var mod_id = mod.get("id", "unknown")
	print("[Modifier] Consumed modifier: %s" % mod_id)
	return mod


## Add a pending combat status (from event, applied at next combat start).
func add_pending_combat_status(status_id: String, duration: int, target: String = "random_hero") -> void:
	pending_combat_statuses.append({
		"status_id": status_id,
		"duration": duration,
		"target": target,
	})
	print("[Modifier] Queued pending status: %s (%d turns, target=%s)" % [status_id, duration, target])


## Check if there are pending combat statuses.
func has_pending_combat_statuses() -> bool:
	return not pending_combat_statuses.is_empty()


## Consume and return all pending combat statuses, then clear.
func consume_pending_combat_statuses() -> Array:
	if pending_combat_statuses.is_empty():
		return []
	var statuses = pending_combat_statuses.duplicate(true)
	pending_combat_statuses.clear()
	print("[Modifier] Consumed %d pending statuses" % statuses.size())
	return statuses


# ============================================================================
# PUBLIC API - EQUIPMENT (Per-Hero Weapon + Offhand slots)
# ============================================================================

## Create empty equipment dictionary with all 8 slots.
func _create_empty_equipment() -> Dictionary:
	return {
		"weapon": {"id": "", "quality": 0},
		"offhand": {"id": "", "quality": 0},
		"helmet": {"id": "", "quality": 0},
		"armor": {"id": "", "quality": 0},
		"legs": {"id": "", "quality": 0},
		"ring": {"id": "", "quality": 0},
		"amulet": {"id": "", "quality": 0},
		"bag": {"id": "", "quality": 0}
	}


## Get hero equipment data. Returns dict with all 8 slots.
func get_hero_equipment(hero_id: String) -> Dictionary:
	if hero_id == "" or not hero_equipment.has(hero_id):
		return _create_empty_equipment()
	var equip = hero_equipment[hero_id]
	# Ensure all slots exist (forward-compat for old saves)
	for slot in ALL_EQUIP_SLOTS:
		if not equip.has(slot):
			equip[slot] = {"id": "", "quality": 0}
	return equip


## Get equipped weapon item_id for a hero (empty if none).
func get_hero_weapon(hero_id: String) -> String:
	var equip = get_hero_equipment(hero_id)
	return equip.weapon.get("id", "")


## Get equipped offhand item_id for a hero (empty if none).
func get_hero_offhand(hero_id: String) -> String:
	var equip = get_hero_equipment(hero_id)
	return equip.offhand.get("id", "")


## Get hero weapon quality tier (0-3).
func get_hero_weapon_quality(hero_id: String) -> int:
	var equip = get_hero_equipment(hero_id)
	return int(equip.weapon.get("quality", 0))


## Get hero offhand quality tier (0-3).
func get_hero_offhand_quality(hero_id: String) -> int:
	var equip = get_hero_equipment(hero_id)
	return int(equip.offhand.get("quality", 0))


## Get equipped bag item_id for a hero (empty if none).
func get_hero_bag_item(hero_id: String) -> String:
	var equip = get_hero_equipment(hero_id)
	return equip.bag.get("id", "")


## Get hero bag quality tier (0-3).
func get_hero_bag_quality(hero_id: String) -> int:
	var equip = get_hero_equipment(hero_id)
	return int(equip.bag.get("quality", 0))


## Generic getter for any equipment slot item_id.
func get_hero_slot_item(hero_id: String, slot: String) -> String:
	var equip = get_hero_equipment(hero_id)
	if equip.has(slot):
		return equip[slot].get("id", "")
	return ""


## Generic getter for any equipment slot quality.
func get_hero_slot_quality(hero_id: String, slot: String) -> int:
	var equip = get_hero_equipment(hero_id)
	if equip.has(slot):
		return int(equip[slot].get("quality", 0))
	return 0


## Get equipped helmet item_id for a hero (empty if none).
func get_hero_helmet(hero_id: String) -> String:
	return get_hero_slot_item(hero_id, "helmet")


## Get equipped armor item_id for a hero (empty if none).
func get_hero_armor(hero_id: String) -> String:
	return get_hero_slot_item(hero_id, "armor")


## Get equipped legs item_id for a hero (empty if none).
func get_hero_legs(hero_id: String) -> String:
	return get_hero_slot_item(hero_id, "legs")


## Get equipped ring item_id for a hero (empty if none).
func get_hero_ring(hero_id: String) -> String:
	return get_hero_slot_item(hero_id, "ring")


## Get equipped amulet item_id for a hero (empty if none).
func get_hero_amulet(hero_id: String) -> String:
	return get_hero_slot_item(hero_id, "amulet")


## DEPRECATED: Legacy global getters (for backwards compatibility during migration)
func get_equipped_weapon() -> String:
	return equipped_weapon_id

func get_equipped_offhand() -> String:
	return equipped_offhand_id


## Check if item exists in run stash (banked inventory).
func has_run_item(item_id: String) -> bool:
	if item_id == "":
		return false
	for item in run_items:
		if item is Dictionary and item.get("item_id", "") == item_id:
			return true
		if item is ItemInstance and item.template_id == item_id:
			return true
	return false


## Check if an item can be equipped in the given slot.
## Valid slots: weapon, offhand, helmet, armor, legs, ring, amulet, bag
## Checks: item exists in run stash AND item template has matching equip_slot.
func is_item_equippable(slot: String, item_id: String) -> bool:
	if item_id == "" or slot == "":
		return false
	if slot not in ALL_EQUIP_SLOTS:
		return false
	if not has_run_item(item_id):
		return false
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return false
	return template.equip_slot == slot


## Get specific reason why an item cannot be equipped.
## Returns: "ok", "no_item", "invalid_slot", "not_in_stash", "no_template", "slot_mismatch", "not_equippable"
func get_equip_rejection_reason(slot: String, item_id: String) -> String:
	if item_id == "" or slot == "":
		return "no_item"
	if slot not in ALL_EQUIP_SLOTS:
		return "invalid_slot"
	if not has_run_item(item_id):
		return "not_in_stash"
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return "no_template"
	if template.equip_slot == "":
		return "not_equippable"
	if template.equip_slot != slot:
		return "slot_mismatch"
	return "ok"


## Count how many equipped items grant an ability_id for this hero.
## Used to enforce the max 2 equipment abilities limit.
func count_equipped_ability_items(hero_id: String) -> int:
	var count: int = 0
	var equip = get_hero_equipment(hero_id)
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var eid = slot_data.get("id", "")
		if eid != "":
			var template = DataRegistry.get_item_template(eid)
			if template != null and (template.ability_id != "" or template.passive_id != ""):
				count += 1
	return count


## Get the ability IDs granted by a hero's equipped items.
## Returns an array of ability_id strings.
## Checks infused_ability_id first (NG+ infusion), falls back to template ability_id.
func get_hero_equipment_ability_ids(hero_id: String) -> Array:
	var ids: Array = []
	var equip = get_hero_equipment(hero_id)
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var eid = slot_data.get("id", "")
		if eid != "":
			# NG+ infusion takes priority over template ability
			var infused: String = slot_data.get("infused_ability_id", "")
			if infused != "":
				ids.append(infused)
			else:
				var template = DataRegistry.get_item_template(eid)
				if template != null and template.ability_id != "":
					ids.append(template.ability_id)
	return ids


## Collect all combat_tag_effects from a hero's equipped items.
## Returns Array of Dicts, each with original effect fields + "item_id" for attribution.
func get_hero_combat_tag_effects(hero_id: String) -> Array:
	var effects: Array = []
	var equip = get_hero_equipment(hero_id)
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var eid = slot_data.get("id", "")
		if eid != "":
			var template = DataRegistry.get_item_template(eid)
			if template != null and not template.combat_tag_effect.is_empty():
				var effect = template.combat_tag_effect.duplicate()
				effect["item_id"] = eid
				effects.append(effect)
	return effects


## Equip an item from run stash into the given slot for a specific hero.
## Returns true if successful, false if item cannot be equipped.
## Removes item from run stash on success.
func equip_hero_item(hero_id: String, slot: String, item_id: String, target_quality: int = -1, target_affix: Dictionary = {}) -> bool:
	if hero_id == "":
		print("[Equip] rejected hero=%s slot=%s item=%s reason=no_hero_id" % [hero_id, slot, item_id])
		return false

	var rejection_reason = get_equip_rejection_reason(slot, item_id)
	if rejection_reason != "ok":
		var template = DataRegistry.get_item_template(item_id)
		var item_slot = template.equip_slot if template != null else ""
		print("[Equip] rejected hero=%s slot=%s item=%s item_slot=%s reason=%s" % [hero_id, slot, item_id, item_slot, rejection_reason])
		return false

	# T4 special item limit: max 3 equipped items with ability_id or passive_id per hero
	var new_template = DataRegistry.get_item_template(item_id)
	if new_template != null and (new_template.ability_id != "" or new_template.passive_id != ""):
		# Check if the item being replaced in this slot also has a special (it won't count against limit)
		var current_slot_data = get_hero_equipment(hero_id).get(slot, {})
		var current_item_id = current_slot_data.get("id", "")
		var current_has_special: bool = false
		if current_item_id != "":
			var current_tpl = DataRegistry.get_item_template(current_item_id)
			if current_tpl != null and (current_tpl.ability_id != "" or current_tpl.passive_id != ""):
				current_has_special = true
		var ability_count: int = count_equipped_ability_items(hero_id)
		# If current slot item has special, it will be unequipped first, so it doesn't count
		if current_has_special:
			ability_count -= 1
		if ability_count >= 3:
			print("[Equip] rejected hero=%s slot=%s item=%s reason=max_t4_items (count=%d)" % [hero_id, slot, item_id, ability_count])
			return false

	# Unequip current item in slot first (returns it to stash)
	unequip_hero_item(hero_id, slot)

	# Resolve quality tier and affix data for the item being equipped.
	# If target_quality was specified by the UI, search for that specific variant.
	# Otherwise fall back to first match (legacy behavior).
	var quality_tier: int = 0
	var equip_affix_data: Dictionary = {}

	if target_quality >= 0:
		# UI told us exactly which variant — use it directly
		quality_tier = target_quality
		equip_affix_data = target_affix
	else:
		# Legacy path: find first matching item in stash
		for item in run_items:
			if item is ItemInstance and item.template_id == item_id:
				quality_tier = item.quality_tier
				if item.affix_id != "":
					equip_affix_data = {
						"source_region": item.source_region,
						"affix_id": item.affix_id,
						"affix_stats": item.affix_stats,
						"affix_prefix": item.affix_prefix
					}
				if item.bonus_stat_lines.size() > 0:
					equip_affix_data["bonus_stat_lines"] = item.bonus_stat_lines
				break
			elif item is Dictionary and item.get("item_id", "") == item_id:
				quality_tier = int(item.get("quality_tier", 0))
				if item.get("affix_id", "") != "":
					equip_affix_data = {
						"source_region": item.get("source_region", ""),
						"affix_id": item.get("affix_id", ""),
						"affix_stats": item.get("affix_stats", {}),
						"affix_prefix": item.get("affix_prefix", "")
					}
				var legacy_bonus_lines: Array = item.get("bonus_stat_lines", [])
				if legacy_bonus_lines.size() > 0:
					equip_affix_data["bonus_stat_lines"] = legacy_bonus_lines
				break

	# Remove from run stash (quality-specific when we know the quality)
	var removed: bool = false
	if target_quality >= 0:
		removed = remove_run_item_by_quality(item_id, quality_tier, 1) > 0
	else:
		removed = remove_run_item(item_id, 1)
	if not removed:
		print("[Equip] hero=%s slot=%s item=%s q=%d failed reason=stash_remove_failed" % [hero_id, slot, item_id, quality_tier])
		return false

	# Ensure hero has equipment entry with all slots
	if not hero_equipment.has(hero_id):
		hero_equipment[hero_id] = _create_empty_equipment()

	# Equip with quality tracking (generic for all slots)
	if slot in ALL_EQUIP_SLOTS:
		var slot_entry: Dictionary = {"id": item_id, "quality": quality_tier}
		if equip_affix_data.get("affix_id", "") != "":
			slot_entry["source_region"] = equip_affix_data.get("source_region", "")
			slot_entry["affix_id"] = equip_affix_data.get("affix_id", "")
			slot_entry["affix_stats"] = equip_affix_data.get("affix_stats", {})
			slot_entry["affix_prefix"] = equip_affix_data.get("affix_prefix", "")
		# NG+ bonus stat lines
		var equip_bonus_lines: Array = equip_affix_data.get("bonus_stat_lines", [])
		if equip_bonus_lines.size() > 0:
			slot_entry["bonus_stat_lines"] = equip_bonus_lines
		hero_equipment[hero_id][slot] = slot_entry

	print("[Equip] hero=%s slot=%s item=%s q=%d from_stash=true" % [hero_id, slot, item_id, quality_tier])
	save_game()
	return true


## Unequip the item in the given slot for a specific hero, returning it to run stash.
func unequip_hero_item(hero_id: String, slot: String) -> void:
	if hero_id == "" or slot not in ALL_EQUIP_SLOTS:
		return

	if not hero_equipment.has(hero_id):
		return

	# Generic slot handling for all 8 slots
	var slot_data = hero_equipment[hero_id].get(slot, {})
	var item_id = slot_data.get("id", "")
	var quality_tier = int(slot_data.get("quality", 0))
	# Extract affix data before clearing slot
	var unequip_affix: Dictionary = {}
	if slot_data.get("affix_id", "") != "":
		unequip_affix = {
			"source_region": slot_data.get("source_region", ""),
			"affix_id": slot_data.get("affix_id", ""),
			"affix_stats": slot_data.get("affix_stats", {}),
			"affix_prefix": slot_data.get("affix_prefix", "")
		}
	# Preserve NG+ bonus stat lines
	var unequip_bonus_lines: Array = slot_data.get("bonus_stat_lines", [])
	if unequip_bonus_lines.size() > 0:
		unequip_affix["bonus_stat_lines"] = unequip_bonus_lines
	hero_equipment[hero_id][slot] = {"id": "", "quality": 0}

	if item_id != "":
		# Return item to stash with same quality + affix data
		_add_item_with_quality(item_id, quality_tier, unequip_affix)
		print("[Equip] hero=%s slot=%s item=%s q=%d to_stash=true" % [hero_id, slot, item_id, quality_tier])
		save_game()


## Helper to add an item to stash with specific quality tier.
func _add_item_with_quality(item_id: String, quality_tier: int, affix_data: Dictionary = {}) -> void:
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl != null:
		var instance = ItemInstance.new()
		instance.template_id = item_id
		instance.quality_tier = quality_tier
		instance.quantity = 1
		# Restore affix data if present
		if affix_data.get("affix_id", "") != "":
			instance.source_region = affix_data.get("source_region", "")
			instance.affix_id = affix_data.get("affix_id", "")
			instance.affix_stats = affix_data.get("affix_stats", {})
			instance.affix_prefix = affix_data.get("affix_prefix", "")
		# Restore NG+ bonus stat lines
		var restore_bonus_lines: Array = affix_data.get("bonus_stat_lines", [])
		if restore_bonus_lines.size() > 0:
			instance.bonus_stat_lines = restore_bonus_lines
		# Build display name: [affix_prefix] [quality_prefix] template_name
		var prefix = ItemInstance.QUALITY_PREFIXES[quality_tier] if quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
		var base_name: String = prefix + tpl.display_name
		if instance.affix_prefix != "":
			instance.display_name = instance.affix_prefix + " " + base_name
		else:
			instance.display_name = base_name
		run_items.append(instance)
	else:
		# Fallback to dictionary format
		run_items.append({"item_id": item_id, "qty": 1})


## DEPRECATED: Legacy equip (for backwards compatibility)
func equip_item(slot: String, item_id: String) -> bool:
	# Legacy: equip to first party member if no hero specified
	var party = get_selected_party()
	if party.size() > 0:
		return equip_hero_item(party[0], slot, item_id)
	return false


## DEPRECATED: Legacy unequip (for backwards compatibility)
func unequip_item(slot: String) -> void:
	# Legacy: unequip from first party member
	var party = get_selected_party()
	if party.size() > 0:
		unequip_hero_item(party[0], slot)


## Get equipment summary for a specific hero.
func get_hero_equipment_summary(hero_id: String) -> Dictionary:
	var equip = get_hero_equipment(hero_id)
	return {
		"weapon_id": equip.weapon.get("id", ""),
		"weapon_quality": int(equip.weapon.get("quality", 0)),
		"offhand_id": equip.offhand.get("id", ""),
		"offhand_quality": int(equip.offhand.get("quality", 0)),
		"bag_id": equip.bag.get("id", ""),
		"bag_quality": int(equip.bag.get("quality", 0))
	}


## DEPRECATED: Legacy get_equipment_summary (for backwards compatibility)
func get_equipment_summary() -> Dictionary:
	return {
		"weapon_id": equipped_weapon_id,
		"weapon_quality": equipped_weapon_quality,
		"offhand_id": equipped_offhand_id,
		"offhand_quality": equipped_offhand_quality
	}


## Get combined stat bonuses from equipped weapon and offhand for a specific hero.
## Applies quality tier multipliers and region scaling to equipment stats.
func _get_hero_equipment_stat_bonuses(hero_id: String) -> Dictionary:
	var result = { "health": 0, "attack": 0, "defense": 0, "speed": 0,
		"crit_chance": 0, "evasion": 0, "resist": 0, "thorns": 0, "armor_penetration": 0, "life_steal": 0 }
	var region_bonus: float = get_completed_region_count() * 0.1

	var equip = get_hero_equipment(hero_id)

	# Iterate over all 7 equipment slots + bag for combat stats
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var item_id = slot_data.get("id", "")
		var quality = int(slot_data.get("quality", 0))
		if item_id != "":
			var template = DataRegistry.get_item_template(item_id)
			if template != null:
				var bonuses = template.get_stat_bonuses_with_quality(quality, region_bonus)
				# NG+4-8: apply base stat multiplier to template bonuses
				var ng_mult: float = get_ng_base_stat_multiplier()
				if ng_mult > 1.0:
					for bk in bonuses:
						if bonuses[bk] > 0:
							bonuses[bk] = maxi(int(bonuses[bk] * ng_mult), bonuses[bk] + 1)
				for stat_key in bonuses:
					if result.has(stat_key):
						result[stat_key] += bonuses[stat_key]
			# Add affix stat bonuses (G7)
			var affix_stats_val = slot_data.get("affix_stats", {})
			if affix_stats_val is Dictionary:
				for affix_key in affix_stats_val:
					if result.has(affix_key):
						result[affix_key] += int(affix_stats_val[affix_key])
			# NG+ bonus stat lines (generated at drop time)
			var bonus_lines: Array = slot_data.get("bonus_stat_lines", [])
			for line in bonus_lines:
				var line_stat: String = line.get("stat", "")
				var line_val: int = int(line.get("value", 0))
				if line_stat != "" and result.has(line_stat):
					result[line_stat] += line_val

	# Bag slot: backpacks with base_stats also contribute combat bonuses
	var bag_data = equip.get("bag", {})
	var bag_id = bag_data.get("id", "")
	if bag_id != "":
		var bag_tpl = DataRegistry.get_item_template(bag_id)
		if bag_tpl != null and bag_tpl.base_stats.size() > 0:
			var bag_quality = int(bag_data.get("quality", 0))
			var bag_bonuses = bag_tpl.get_stat_bonuses_with_quality(bag_quality, region_bonus)
			for stat_key in bag_bonuses:
				if result.has(stat_key):
					result[stat_key] += bag_bonuses[stat_key]

	return result


## DEPRECATED: Legacy _get_equipment_stat_bonuses (for backwards compatibility)
func _get_equipment_stat_bonuses() -> Dictionary:
	var result = { "health": 0, "attack": 0, "defense": 0, "speed": 0,
		"crit_chance": 0, "evasion": 0, "resist": 0, "thorns": 0, "armor_penetration": 0, "life_steal": 0 }
	var region_bonus: float = get_completed_region_count() * 0.1

	# Weapon bonuses
	if equipped_weapon_id != "":
		var weapon_template = DataRegistry.get_item_template(equipped_weapon_id)
		if weapon_template != null:
			var bonuses = weapon_template.get_stat_bonuses_with_quality(equipped_weapon_quality, region_bonus)
			for stat_key in bonuses:
				if result.has(stat_key):
					result[stat_key] += bonuses[stat_key]

	# Offhand bonuses
	if equipped_offhand_id != "":
		var offhand_template = DataRegistry.get_item_template(equipped_offhand_id)
		if offhand_template != null:
			var bonuses = offhand_template.get_stat_bonuses_with_quality(equipped_offhand_quality, region_bonus)
			for stat_key in bonuses:
				if result.has(stat_key):
					result[stat_key] += bonuses[stat_key]

	return result


# ============================================================================
# HERO BAGS (per-hero small consumable inventory, display-only scaffolding)
# ============================================================================

## Get the bag contents for a hero. Returns Array of { "item_id": String, "qty": int }.
func get_hero_bag(hero_id: String) -> Array:
	if hero_bags.has(hero_id):
		return hero_bags[hero_id]
	return []

## Get the bag capacity for a hero (base + equipped backpack bonus).
func get_hero_bag_capacity(hero_id: String) -> int:
	var bonus := 0
	var bag_item_id = get_hero_bag_item(hero_id)
	if bag_item_id != "":
		var tpl = DataRegistry.get_item_template(bag_item_id)
		if tpl != null:
			bonus = tpl.bag_capacity_bonus
			# Quality adds +1 capacity per quality tier (Q0=+0, Q1=+1, Q2=+2, Q3=+3)
			var quality = get_hero_bag_quality(hero_id)
			bonus += quality
	return DEFAULT_HERO_BAG_CAPACITY + bonus

## Get a human-readable bag summary string for display.
## v1.2: Capacity measured by stacks. Returns e.g. "0/1 (empty)" or "2/3 Potion x1, Herb x1"
func get_hero_bag_summary(hero_id: String) -> String:
	var bag = get_hero_bag(hero_id)
	var cap = get_hero_bag_capacity(hero_id)
	var used := bag.size()  # v1.2: Count stacks, not total qty
	var parts: Array[String] = []
	for entry in bag:
		var qty = int(entry.get("qty", 1))
		var item_id = entry.get("item_id", "")
		var name = item_id.replace("_", " ").capitalize()
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl != null and tpl.display_name != "":
			name = tpl.display_name
		parts.append("%s x%d" % [name, qty])
	if parts.is_empty():
		return "%d/%d (empty)" % [used, cap]
	return "%d/%d %s" % [used, cap, ", ".join(parts)]


## Clear gear logging tracking (call when starting new combat).
func clear_gear_logging() -> void:
	_gear_logged_heroes.clear()


# ============================================================================
# HERO BAGS - Item Transfer (consumables only)
# ============================================================================

## Get the total number of items currently in a hero's bag.
func _get_hero_bag_used(hero_id: String) -> int:
	# v1.2: Capacity is measured by STACKS (entries), not total qty
	var bag = get_hero_bag(hero_id)
	return bag.size()

## Check if an item can be added to a hero's bag.
## v1.4: Materials can stack (merge into existing entry). Others need a free slot.
func can_add_to_hero_bag(hero_id: String, item_id: String, _qty: int = 1) -> bool:
	if hero_id == "" or item_id == "":
		return false
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return false
	var bag = get_hero_bag(hero_id)
	# v1.4: Materials can merge into an existing stack if room
	var stack_limit: int = get_bag_stack_limit(item_id)
	if stack_limit > 1:
		for entry in bag:
			if entry.get("item_id", "") == item_id and int(entry.get("qty", 1)) < stack_limit:
				return true
	# Need a free slot
	return bag.size() < get_hero_bag_capacity(hero_id)

## Add item(s) to a hero's bag. Returns true if all added successfully.
## v1.4: Materials merge into existing stacks (up to BAG_MATERIAL_STACK_MAX per slot).
##        Equipment/consumables always create new entries with qty=1.
func add_item_to_hero_bag(hero_id: String, item_id: String, qty: int = 1, quality: int = 0, affix_data: Dictionary = {}) -> bool:
	if not hero_bags.has(hero_id):
		hero_bags[hero_id] = []
	var bag: Array = hero_bags[hero_id]
	var stack_limit: int = get_bag_stack_limit(item_id)
	var remaining: int = qty

	if stack_limit > 1:
		# v1.4: Materials — merge into existing stacks first
		for entry in bag:
			if remaining <= 0:
				break
			if entry.get("item_id", "") == item_id:
				var current: int = int(entry.get("qty", 1))
				var space: int = stack_limit - current
				if space > 0:
					var add_amt: int = mini(remaining, space)
					entry["qty"] = current + add_amt
					remaining -= add_amt
		# Overflow into new slots
		while remaining > 0:
			if bag.size() >= get_hero_bag_capacity(hero_id):
				print("[HeroBag] FULL: cannot add remaining %d %s hero=%s" % [remaining, item_id, hero_id])
				return false
			var add_amt: int = mini(remaining, stack_limit)
			bag.append({"item_id": item_id, "qty": add_amt, "quality_tier": quality})
			remaining -= add_amt
	else:
		# Non-materials: each unit = separate entry with qty=1
		for _i in range(qty):
			if bag.size() >= get_hero_bag_capacity(hero_id):
				return false
			var entry: Dictionary = {"item_id": item_id, "qty": 1, "quality_tier": quality}
			if affix_data.get("affix_id", "") != "":
				entry["source_region"] = affix_data.get("source_region", "")
				entry["affix_id"] = affix_data.get("affix_id", "")
				entry["affix_stats"] = affix_data.get("affix_stats", {})
				entry["affix_prefix"] = affix_data.get("affix_prefix", "")
			# NG+ bonus stat lines
			var bag_bonus_lines: Array = affix_data.get("bonus_stat_lines", [])
			if bag_bonus_lines.size() > 0:
				entry["bonus_stat_lines"] = bag_bonus_lines
			bag.append(entry)

	var used = _get_hero_bag_used(hero_id)
	var cap = get_hero_bag_capacity(hero_id)
	print("[HeroBag] +%d %s hero=%s bag=%d/%d" % [qty, item_id, hero_id, used, cap])
	return true

## Remove item(s) from a hero's bag. Returns true if successful.
func remove_item_from_hero_bag(hero_id: String, item_id: String, qty: int = 1, _quality: int = 0) -> bool:
	if hero_id == "" or item_id == "" or qty <= 0:
		return false
	if not hero_bags.has(hero_id):
		return false
	var bag: Array = hero_bags[hero_id]
	for i in range(bag.size()):
		if bag[i].get("item_id", "") == item_id:
			var current_qty = int(bag[i].get("qty", 1))
			if current_qty < qty:
				return false
			elif current_qty == qty:
				bag.remove_at(i)
			else:
				bag[i]["qty"] = current_qty - qty
			var used = _get_hero_bag_used(hero_id)
			var cap = get_hero_bag_capacity(hero_id)
			print("[HeroBag] -%d %s hero=%s bag=%d/%d" % [qty, item_id, hero_id, used, cap])
			return true
	return false

## Move item from run stash to hero bag.
## v1.3: All item types allowed (no category restriction).
## Returns true if successful.
func move_item_stash_to_hero_bag(hero_id: String, item_id: String, qty: int = 1) -> bool:
	# v1.3: No category restriction — all items allowed in hero bags
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		print("[HeroBag] REJECT stash->bag item=%s reason=unknown_item" % item_id)
		return false
	# Check stash has enough
	var stash_count = get_run_item_count(item_id)
	if stash_count < qty:
		print("[HeroBag] REJECT stash->bag item=%s reason=insufficient_stash (%d<%d)" % [item_id, stash_count, qty])
		return false
	# Check hero bag capacity
	if not can_add_to_hero_bag(hero_id, item_id, qty):
		print("[HeroBag] REJECT stash->bag item=%s hero=%s reason=bag_full" % [item_id, hero_id])
		return false
	# Execute transfer
	var removed = remove_run_item(item_id, qty)
	if not removed:
		return false
	var added = add_item_to_hero_bag(hero_id, item_id, qty)
	if not added:
		# Rollback: put items back in stash
		add_run_item(item_id, qty)
		return false
	print("[HeroBag] TRANSFER stash->bag hero=%s item=%s qty=%d" % [hero_id, item_id, qty])
	save_game()
	return true

## Move item from hero bag to run stash.
## Returns true if successful.
func move_item_hero_bag_to_stash(hero_id: String, item_id: String, qty: int = 1, quality: int = 0) -> bool:
	if not remove_item_from_hero_bag(hero_id, item_id, qty, quality):
		return false
	add_run_item(item_id, qty)
	print("[HeroBag] TRANSFER bag->stash hero=%s item=%s qty=%d" % [hero_id, item_id, qty])
	save_game()
	return true


# ============================================================================
# PENDING ACQUISITIONS — Loot Recipient Routing
# ============================================================================

## Pending acquisitions waiting for player recipient choice.
## Each entry: { "item_id": String, "qty": int, "quality": int, "source": String }
var _pending_acquisitions: Array = []

## Queue an item for recipient routing. Does NOT add to any stash yet.
## v2: Optional affix_data dict with keys: source_region, affix_id, affix_stats, affix_prefix
func acquire_item_with_recipient(item_id: String, qty: int, quality: int = 0, source: String = "loot", affix_data: Dictionary = {}) -> void:
	if item_id == "" or qty <= 0:
		return
	var entry: Dictionary = {
		"item_id": item_id,
		"qty": qty,
		"quality": quality,
		"source": source
	}
	if affix_data.get("affix_id", "") != "":
		entry["affix_data"] = affix_data
	_pending_acquisitions.append(entry)
	print("[Acquire] pending item=%s qty=%d q=%d source=%s" % [item_id, qty, quality, source])

## Check if there are any pending acquisitions.
func has_pending_acquisition() -> bool:
	return not _pending_acquisitions.is_empty()

## Get the first pending acquisition (or empty dict).
func get_pending_acquisition() -> Dictionary:
	if _pending_acquisitions.is_empty():
		return {}
	return _pending_acquisitions[0]

## Get all pending acquisitions.
func get_all_pending_acquisitions() -> Array:
	return _pending_acquisitions

## Resolve a pending acquisition at a given index.
## recipient_type: "stash", "hero_bag", or "shop_bag"
## Returns true if resolved (partial or full), false if rejected (stays pending).
## v1.2: Stash is BANKED during dungeon — only available when phase is TOWN.
## v1.3: hero_bag and shop_bag move only 1 item per call (no stacking in dungeon bags).
func resolve_acquisition_at(index: int, recipient_type: String, hero_id: String = "") -> bool:
	if index < 0 or index >= _pending_acquisitions.size():
		return false
	var acq = _pending_acquisitions[index]
	var item_id = acq.get("item_id", "")
	var qty = int(acq.get("qty", 1))
	var quality = int(acq.get("quality", 0))
	var affix_data: Dictionary = acq.get("affix_data", {})

	if recipient_type == "stash":
		# v1.2: Stash is banked (locked) unless in TOWN phase
		if _current_phase != GamePhase.TOWN:
			print("[Acquire] reject to=stash item=%s reason=banked_stash_locked (phase=%s)" % [item_id, get_phase_name()])
			return false
		# v1.4: Use add_run_item() for proper stacking
		if not can_add_to_stash(item_id):
			print("[Acquire] reject to=stash item=%s reason=stash_full (%d/%d slots)" % [item_id, get_current_stash_count(), get_max_stash_capacity()])
			return false
		add_run_item(item_id, qty, quality)
		_pending_acquisitions.remove_at(index)
		print("[Acquire] resolved to=stash item=%s qty=%d q=%d (%d/%d)" % [item_id, qty, quality, get_current_stash_count(), get_max_stash_capacity()])
		return true

	elif recipient_type == "hero_bag":
		if hero_id == "":
			return false
		# v1.3: No category restriction — ALL items allowed
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl == null:
			print("[Acquire] reject to=hero_bag hero=%s item=%s reason=unknown_item" % [hero_id, item_id])
			return false
		# v1.3: Move only 1 item at a time (no stacking in bags)
		if not can_add_to_hero_bag(hero_id, item_id, 1):
			print("[Acquire] reject to=hero_bag hero=%s item=%s reason=bag_full" % [hero_id, item_id])
			return false
		# Add single item to hero bag
		add_item_to_hero_bag(hero_id, item_id, 1, quality, affix_data)
		# Decrease pending qty or remove if exhausted
		if qty <= 1:
			_pending_acquisitions.remove_at(index)
		else:
			acq["qty"] = qty - 1
		print("[Acquire] resolved to=hero_bag hero=%s item=%s qty=1 q=%d (pending_remaining=%d)" % [hero_id, item_id, quality, max(0, qty - 1)])
		return true

	elif recipient_type == "shop_bag":
		# v1.3: No category restriction — ALL items allowed
		# v1.3: Move only 1 item at a time (no stacking in bags)
		if not can_add_to_shopkeeper_bag(item_id, 1, quality):
			print("[Acquire] reject to=shop_bag item=%s reason=full" % item_id)
			return false
		add_item_to_shopkeeper_bag(item_id, 1, quality, "combat", affix_data)
		# Decrease pending qty or remove if exhausted
		if qty <= 1:
			_pending_acquisitions.remove_at(index)
		else:
			acq["qty"] = qty - 1
		print("[Acquire] resolved to=shop_bag item=%s qty=1 q=%d (pending_remaining=%d)" % [item_id, quality, max(0, qty - 1)])
		return true

	return false

## Convenience: resolve the first pending acquisition.
func resolve_pending_acquisition(recipient_type: String, hero_id: String = "") -> bool:
	return resolve_acquisition_at(0, recipient_type, hero_id)

## Resolve all pending acquisitions to stash (headless/fallback).
func resolve_all_to_stash() -> void:
	while has_pending_acquisition():
		resolve_pending_acquisition("stash")

## Clear all pending acquisitions without resolving.
func clear_pending_acquisitions() -> void:
	_pending_acquisitions.clear()


# ============================================================================
# PUBLIC API - SHOPKEEPER BAG
# ============================================================================

## Get the shopkeeper bag contents.
func get_shopkeeper_bag() -> Array:
	return shopkeeper_bag

## Get the shopkeeper bag capacity (max stacks).
func get_shopkeeper_bag_capacity() -> int:
	return SHOPKEEPER_BAG_CAPACITY_DEFAULT

## Count current stacks in the shopkeeper bag.
func _get_shopkeeper_bag_stacks() -> int:
	return shopkeeper_bag.size()

## Get a human-readable summary of the shopkeeper bag.
func get_shopkeeper_bag_summary() -> String:
	var stacks = _get_shopkeeper_bag_stacks()
	var cap = get_shopkeeper_bag_capacity()
	if shopkeeper_bag.is_empty():
		return "%d/%d stacks (empty)" % [stacks, cap]
	var parts: Array[String] = []
	for entry in shopkeeper_bag:
		var item_id = entry.get("item_id", "")
		var qty = int(entry.get("qty", 1))
		var name = item_id.replace("_", " ").capitalize()
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl != null and tpl.display_name != "":
			name = tpl.display_name
		parts.append("%s x%d" % [name, qty])
	return "%d/%d stacks %s" % [stacks, cap, ", ".join(parts)]

## Check if an item can be added to the shopkeeper bag.
## v1.4: Materials can merge into existing stacks. Others need a free slot.
func can_add_to_shopkeeper_bag(item_id: String, _qty: int = 1, _quality: int = 0) -> bool:
	if item_id == "":
		return false
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return false
	# v1.4: Materials can merge into an existing stack if room
	var stack_limit: int = get_bag_stack_limit(item_id)
	if stack_limit > 1:
		for entry in shopkeeper_bag:
			if entry.get("item_id", "") == item_id and int(entry.get("qty", 1)) < stack_limit:
				return true
	return _get_shopkeeper_bag_stacks() < get_shopkeeper_bag_capacity()

## Add item(s) to the shopkeeper bag. Returns true if all added successfully.
## v1.4: Materials merge into existing stacks (up to BAG_MATERIAL_STACK_MAX per slot).
##        Equipment/consumables always create new entries with qty=1.
func add_item_to_shopkeeper_bag(item_id: String, qty: int = 1, quality: int = 0, source: String = "loot", affix_data: Dictionary = {}) -> bool:
	var stack_limit: int = get_bag_stack_limit(item_id)
	var remaining: int = qty
	var cap: int = get_shopkeeper_bag_capacity()

	if stack_limit > 1:
		# v1.4: Materials — merge into existing stacks first
		for entry in shopkeeper_bag:
			if remaining <= 0:
				break
			if entry.get("item_id", "") == item_id:
				var current: int = int(entry.get("qty", 1))
				var space: int = stack_limit - current
				if space > 0:
					var add_amt: int = mini(remaining, space)
					entry["qty"] = current + add_amt
					remaining -= add_amt
		# Overflow into new slots
		while remaining > 0:
			if shopkeeper_bag.size() >= cap:
				print("[ShopBag] FULL: cannot add remaining %d %s" % [remaining, item_id])
				return false
			var add_amt: int = mini(remaining, stack_limit)
			shopkeeper_bag.append({"item_id": item_id, "qty": add_amt, "quality_tier": quality})
			remaining -= add_amt
	else:
		# Non-materials: each unit = separate entry with qty=1
		for _i in range(qty):
			if shopkeeper_bag.size() >= cap:
				print("[ShopBag] reject item=%s reason=full" % item_id)
				return false
			var entry: Dictionary = {"item_id": item_id, "qty": 1, "quality_tier": quality}
			if affix_data.get("affix_id", "") != "":
				entry["source_region"] = affix_data.get("source_region", "")
				entry["affix_id"] = affix_data.get("affix_id", "")
				entry["affix_stats"] = affix_data.get("affix_stats", {})
				entry["affix_prefix"] = affix_data.get("affix_prefix", "")
			shopkeeper_bag.append(entry)

	print("[ShopBag] +%d %s q=%d slots=%d/%d source=%s" % [qty, item_id, quality, _get_shopkeeper_bag_stacks(), cap, source])
	return true


# ============================================================================
# DEPRECATED API - LOOT PREFERENCES + AUTO-ROUTING (v1.2: removed, manual only)
# ============================================================================
# These functions are kept as stubs for API compatibility but do nothing.
# Loot routing is now manual-only in v1.2.

## DEPRECATED: Set loot routing preferences (no-op in v1.2).
func set_loot_pref(_pref_dict: Dictionary) -> void:
	pass  # No-op: manual routing only

## DEPRECATED: Get loot routing preferences (returns empty in v1.2).
func get_loot_pref() -> Dictionary:
	return {}

## DEPRECATED: Auto-route pending acquisition (always returns false in v1.2).
func resolve_pending_acquisition_auto(_party_hero_ids: Array) -> bool:
	return false  # No-op: manual routing only


# ============================================================================
# PUBLIC API - GROUP UNLOCKS
# ============================================================================

## Check if a group is unlocked.
func has_unlocked_group(group_id: String) -> bool:
	if group_id == "":
		return false
	# Default groups are always unlocked
	if group_id in DEFAULT_UNLOCK_GROUPS:
		return true
	return unlocked_groups.get(group_id, false)


## Unlock a group for purchase in shops.
func unlock_group(group_id: String) -> void:
	if group_id == "":
		return
	if has_unlocked_group(group_id):
		print("[Unlock] Group already unlocked: %s" % group_id)
		return
	unlocked_groups[group_id] = true
	print("[Unlock] Unlocked group=%s" % group_id)
	save_game()


## Get all unlocked group IDs as an array (including defaults).
func get_unlocked_groups() -> Array:
	var result: Array = []
	for g in DEFAULT_UNLOCK_GROUPS:
		if g not in result:
			result.append(g)
	for g in unlocked_groups.keys():
		if unlocked_groups[g] and g not in result:
			result.append(g)
	return result


# ============================================================================
# PUBLIC API - TUTORIAL TRACKING
# ============================================================================

func has_completed_tutorial(tutorial_id: String) -> bool:
	return completed_tutorials.get(tutorial_id, false)

func complete_tutorial(tutorial_id: String) -> void:
	if has_completed_tutorial(tutorial_id):
		return
	completed_tutorials[tutorial_id] = true
	print("[Tutorial] Completed: %s" % tutorial_id)
	save_game()

func reset_tutorials() -> void:
	completed_tutorials = {}
	print("[Tutorial] All tutorials reset")
	save_game()


# ============================================================================
# CAMPAIGN FLAGS
# ============================================================================

func has_campaign_flag(flag_id: String) -> bool:
	return campaign_flags.get(flag_id, false)


func set_campaign_flag(flag_id: String) -> void:
	if has_campaign_flag(flag_id):
		return
	campaign_flags[flag_id] = true
	print("[Campaign] Flag set: %s (total=%d)" % [flag_id, campaign_flags.size()])


func clear_campaign_flags() -> void:
	campaign_flags = {}
	print("[Campaign] All flags cleared")


## Check if the player has completed their first dungeon floor ever.
func has_completed_first_floor() -> bool:
	return completed_tutorials.get("first_floor_completed", false)


## Mark first floor as completed (called on first extract after floor completion).
func mark_first_floor_completed() -> void:
	if not has_completed_first_floor():
		completed_tutorials["first_floor_completed"] = true
		print("[GameContext] First floor completion marked")
		save_game()


# ============================================================================
# PUBLIC API - RECIPE UNLOCKS (Shop Item Generation)
# ============================================================================

## Build recipe key from item_id and upgrade_tier. Format: "item_id:t{tier}"
## For non-equipment items (consumables etc.), uses plain item_id as key.
static func _recipe_key(item_id: String, upgrade_tier: int = 0) -> String:
	if upgrade_tier > 0:
		return "%s:t%d" % [item_id, upgrade_tier]
	return item_id

## Check if an item is a default (starter) recipe.
static func is_default_recipe(item_id: String, upgrade_tier: int = 1) -> bool:
	var key: String = _recipe_key(item_id, upgrade_tier)
	return DEFAULT_UNLOCKED_RECIPES.has(key)

## Check if a specific recipe tier is unlocked.
## If upgrade_tier == 0, checks if ANY tier of this item is unlocked.
func is_recipe_unlocked(item_id: String, upgrade_tier: int = 0) -> bool:
	if item_id == "":
		return false
	if upgrade_tier > 0:
		var key = _recipe_key(item_id, upgrade_tier)
		return DEFAULT_UNLOCKED_RECIPES.has(key) or unlocked_recipes.has(key)
	# upgrade_tier == 0: check any tier (legacy + new format)
	if DEFAULT_UNLOCKED_RECIPES.has(item_id) or unlocked_recipes.has(item_id):
		return true
	# Check keyed versions t1-t3
	for t in range(1, 4):
		var key = _recipe_key(item_id, t)
		if DEFAULT_UNLOCKED_RECIPES.has(key) or unlocked_recipes.has(key):
			return true
	return false

## Get the highest unlocked upgrade_tier for an item. Returns 0 if not unlocked.
func get_recipe_upgrade_tier(item_id: String) -> int:
	var highest: int = 0
	# Check legacy plain key
	if DEFAULT_UNLOCKED_RECIPES.has(item_id) or unlocked_recipes.has(item_id):
		var data: Dictionary = unlocked_recipes.get(item_id, DEFAULT_UNLOCKED_RECIPES.get(item_id, {}))
		highest = maxi(highest, int(data.get("upgrade_tier", 1)))
	# Check keyed versions t1-t3
	for t in range(1, 4):
		var key = _recipe_key(item_id, t)
		if DEFAULT_UNLOCKED_RECIPES.has(key) or unlocked_recipes.has(key):
			highest = maxi(highest, t)
	return highest

## Unlock a recipe so its item appears in the General Store.
func unlock_recipe(item_id: String, source_facility: String, facility_tier: int = 1, upgrade_tier: int = 1, replaces: String = "") -> void:
	if item_id == "":
		return
	var key = _recipe_key(item_id, upgrade_tier)
	if DEFAULT_UNLOCKED_RECIPES.has(key) or unlocked_recipes.has(key):
		print("[Recipe] Already unlocked: %s" % key)
		return
	var data: Dictionary = {
		"source_facility": source_facility,
		"facility_tier": facility_tier,
		"upgrade_tier": upgrade_tier,
		"output_id": item_id
	}
	if replaces != "":
		data["replaces"] = replaces
	unlocked_recipes[key] = data
	print("[Recipe] Unlocked key=%s item=%s source=%s fac_tier=%d upgrade_tier=%d" % [key, item_id, source_facility, facility_tier, upgrade_tier])
	save_game()


## Get recipe unlock data for an item. Returns empty dict if not unlocked.
## If upgrade_tier > 0, gets the specific tier data.
func get_recipe_data(item_id: String, upgrade_tier: int = 0) -> Dictionary:
	if upgrade_tier > 0:
		var key = _recipe_key(item_id, upgrade_tier)
		if DEFAULT_UNLOCKED_RECIPES.has(key):
			return DEFAULT_UNLOCKED_RECIPES[key]
		return unlocked_recipes.get(key, {})
	# Legacy: try plain key first, then keyed
	if DEFAULT_UNLOCKED_RECIPES.has(item_id):
		return DEFAULT_UNLOCKED_RECIPES[item_id]
	if unlocked_recipes.has(item_id):
		return unlocked_recipes[item_id]
	# Check highest tier
	for t in range(3, 0, -1):
		var key = _recipe_key(item_id, t)
		if DEFAULT_UNLOCKED_RECIPES.has(key):
			return DEFAULT_UNLOCKED_RECIPES[key]
		if unlocked_recipes.has(key):
			return unlocked_recipes[key]
	return {}


## Get all unlocked recipe item IDs (for shop generation).
func get_all_unlocked_recipes() -> Array:
	var result: Array = []
	for key in DEFAULT_UNLOCKED_RECIPES.keys():
		var data: Dictionary = DEFAULT_UNLOCKED_RECIPES[key]
		var oid: String = data.get("output_id", key.split(":")[0])
		if oid not in result:
			result.append(oid)
	for key in unlocked_recipes.keys():
		var data: Dictionary = unlocked_recipes[key]
		var oid: String = data.get("output_id", key.split(":")[0])
		if oid not in result:
			result.append(oid)
	return result


## Check if player can afford a recipe unlock cost.
## unlock_cost: Array of { item_id, qty } from facility recipe data.
func can_afford_recipe_unlock(unlock_cost: Array) -> bool:
	for cost_entry in unlock_cost:
		var item_id = cost_entry.get("item_id", "")
		var qty_needed = cost_entry.get("qty", 0)
		if item_id == "" or qty_needed <= 0:
			continue
		var qty_have = get_run_item_count(item_id)
		if qty_have < qty_needed:
			return false
	return true


## Purchase/unlock a recipe by spending materials from run stash.
## Returns true if successful, false if not enough materials or already unlocked.
func purchase_recipe_unlock(output_id: String, unlock_cost: Array, source_facility: String, facility_tier: int = 1, upgrade_tier: int = 1, replaces: String = "") -> bool:
	# Already unlocked?
	if is_recipe_unlocked(output_id, upgrade_tier):
		print("[Recipe] Already unlocked: %s:t%d" % [output_id, upgrade_tier])
		return false

	# Check affordability
	if not can_afford_recipe_unlock(unlock_cost):
		print("[Recipe] Cannot afford unlock for: %s:t%d" % [output_id, upgrade_tier])
		return false

	# Spend materials
	for cost_entry in unlock_cost:
		var item_id = cost_entry.get("item_id", "")
		var qty = cost_entry.get("qty", 0)
		if item_id != "" and qty > 0:
			remove_run_item(item_id, qty)

	# Unlock the recipe
	unlock_recipe(output_id, source_facility, facility_tier, upgrade_tier, replaces)
	print("[Recipe] Purchased unlock for %s:t%d at %s (fac_tier %d)" % [output_id, upgrade_tier, source_facility, facility_tier])
	return true


## Roll quality tier based on facility tier.
## Returns: 0=Common, 1=Uncommon, 2=Rare, 3=Epic
func roll_quality_for_facility_tier(facility_tier: int) -> int:
	var roll = randf() * 100.0
	match facility_tier:
		1:  # 85% Common, 14% Uncommon, 1% Rare, 0% Epic
			if roll < 85.0: return 0
			elif roll < 99.0: return 1
			else: return 2
		2:  # 55% Common, 30% Uncommon, 10% Rare, 5% Epic
			if roll < 55.0: return 0
			elif roll < 85.0: return 1
			elif roll < 95.0: return 2
			else: return 3
		3:  # 35% Common, 40% Uncommon, 15% Rare, 10% Epic
			if roll < 35.0: return 0
			elif roll < 75.0: return 1
			elif roll < 90.0: return 2
			else: return 3
		_:
			return 0  # Unknown tier = common


# ============================================================================
# PUBLIC API - MIXING SYSTEM (Discovery & Mishaps)
# ============================================================================

## Build a canonical key for a mixing item pair/triple (order-independent).
static func mix_key(item_a: String, item_b: String, item_c: String = "") -> String:
	var parts: Array = [item_a, item_b]
	if item_c != "":
		parts.append(item_c)
	parts.sort()
	return ":".join(parts)


## Record a discovered mix for a facility. Saves immediately.
func discover_mix(facility_id: String, item_a: String, item_b: String, item_c: String = "") -> void:
	var key: String = facility_id + ":" + mix_key(item_a, item_b, item_c)
	if not discovered_mixes.has(key):
		discovered_mixes[key] = true
		print("[Mix] Discovered: %s at %s" % [mix_key(item_a, item_b, item_c), facility_id])
		save_game()


## Check if a mix has been discovered at a facility.
func is_mix_discovered(facility_id: String, item_a: String, item_b: String, item_c: String = "") -> bool:
	var key: String = facility_id + ":" + mix_key(item_a, item_b, item_c)
	return discovered_mixes.has(key)


## Count how many mixes have been discovered at a facility.
func get_discovered_mix_count(facility_id: String) -> int:
	var count: int = 0
	var prefix: String = facility_id + ":"
	for key in discovered_mixes:
		if key.begins_with(prefix):
			count += 1
	return count


## Auto-discover base mixing recipes for alchemist and chef.
## Only reads from the base recipe files (mixing_alchemist.json / mixing_chef.json),
## NOT regional files (mixing_*_r2.json etc.), to avoid leaking regional items.
## Called on new game and as a migration step during load_game().
func auto_discover_base_recipes() -> void:
	for facility_id in ["alchemist", "chef"]:
		var file_path: String = "res://Data/Recipes/mixing_%s.json" % facility_id
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			continue
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err != OK or not (json.data is Dictionary):
			continue
		var recipes: Array = json.data.get("recipes", [])
		for recipe in recipes:
			if recipe.get("required_tier", 1) > 1:
				continue
			var ia: String = recipe.get("input_a", "")
			var ib: String = recipe.get("input_b", "")
			var ic: String = recipe.get("input_c", "")
			if not is_mix_discovered(facility_id, ia, ib, ic):
				discovered_mixes[facility_id + ":" + mix_key(ia, ib, ic)] = true
	print("[Mix] Base recipes auto-discovered: alchemist=%d, chef=%d" % [
		get_discovered_mix_count("alchemist"), get_discovered_mix_count("chef")])


## Get the shop recipe pool for a production facility.
## Merges static DEFAULT_UNLOCKED_RECIPES with discovered mixing recipes.
func get_facility_shop_recipes(facility_id: String) -> Array:
	var base: Array = get_facility_unlocked_recipes(facility_id)
	var seen: Dictionary = {}
	for entry in base:
		seen[entry.item_id] = true

	var all_recipes: Array = DataRegistry.get_mixing_recipes(facility_id)
	for recipe in all_recipes:
		var ia: String = recipe.get("input_a", "")
		var ib: String = recipe.get("input_b", "")
		var ic: String = recipe.get("input_c", "")
		if not is_mix_discovered(facility_id, ia, ib, ic):
			continue
		var output_id: String = recipe.get("output_id", "")
		if output_id == "" or seen.has(output_id):
			continue
		seen[output_id] = true
		base.append({"item_id": output_id, "upgrade_tier": 1, "facility_tier": 1})
	return base


## Process a failed mix at a facility. Returns a result dictionary.
## Only the alchemist has mishap consequences; chef just loses materials.
func process_failed_mix(facility_id: String) -> Dictionary:
	if facility_id != "alchemist":
		return {"type": "none", "message": "The ingredients didn't combine into anything useful."}

	alchemist_mishap_streak += 1
	var mishap_chance: int = mini(alchemist_mishap_streak * 10, 50)
	var roll: int = randi() % 100

	if roll >= mishap_chance:
		save_game()
		return {"type": "none", "message": "The mix fizzled. The lab feels unstable... (Risk: %d%%)" % mishap_chance}

	# Bad event triggered — reset streak
	alchemist_mishap_streak = 0

	var event_roll: int = randi() % 100
	var result: Dictionary = {}

	if event_roll < 30:
		var destroyed: String = _destroy_random_equipment()
		result = {"type": "equipment_destroyed", "message": "Corrosive splash! %s was destroyed!" % destroyed}
	elif event_roll < 60:
		locked_facilities["alchemist"] = true
		result = {"type": "facility_locked", "message": "Toxic fumes! The Alchemist lab is sealed until you return to town."}
	elif event_roll < 80:
		inn_lockout = true
		result = {"type": "inn_locked", "message": "Noxious gas spread to town! No recruits available until you return."}
	else:
		locked_facilities["chef"] = true
		result = {"type": "chef_locked", "message": "Kitchen contaminated! The Chef is closed until you return to town."}

	print("[Mix] Mishap at alchemist: %s" % result.type)
	save_game()
	return result


## Destroy a random equipped item on a random hero. Returns description of what was destroyed.
func _destroy_random_equipment() -> String:
	var hero_ids: Array = selected_party.duplicate()
	if hero_ids.is_empty():
		for hero in owned_heroes:
			hero_ids.append(hero.get("hero_id", ""))
	hero_ids.shuffle()

	for hero_id in hero_ids:
		if not hero_equipment.has(hero_id):
			continue
		var equip: Dictionary = hero_equipment[hero_id]
		var filled_slots: Array = []
		for slot in EQUIPMENT_SLOTS:
			if equip.has(slot) and equip[slot] is Dictionary:
				var item_id: String = equip[slot].get("id", "")
				if item_id != "":
					filled_slots.append(slot)
		if filled_slots.is_empty():
			continue
		filled_slots.shuffle()
		var target_slot: String = filled_slots[0]
		var destroyed_id: String = equip[target_slot].get("id", "unknown")
		var tpl = DataRegistry.get_item_template(destroyed_id)
		var destroyed_name: String = tpl.display_name if tpl != null and tpl.display_name != "" else destroyed_id
		equip[target_slot] = {"id": "", "quality": 0}
		print("[Mix] Equipment destroyed: hero=%s slot=%s item=%s" % [hero_id, target_slot, destroyed_id])
		return "%s's %s" % [hero_id, destroyed_name]

	return "nothing (no equipment found)"


## Clear all facility lockouts and mishap state. Called on town return.
func clear_facility_lockouts() -> void:
	locked_facilities.clear()
	inn_lockout = false
	alchemist_mishap_streak = 0
	print("[Mix] Facility lockouts cleared on town return")


# ============================================================================
# FACILITY UNLOCK PURCHASE API (v1)
# ============================================================================

## Get available unlocks for a facility (not yet purchased, tier requirement met).
## Returns array of unlock dictionaries from facility JSON.
func get_available_facility_unlocks(facility_id: String, town_id: String = "") -> Array:
	var facility = DataRegistry.get_facility(facility_id)
	if facility == null:
		return []

	# Get current facility tier
	var current_tier = 1
	if town_id != "":
		current_tier = get_facility_tier(town_id, facility_id)

	# Get unlocks array from facility data (property, not dict)
	var unlocks_data = facility.unlocks if facility.unlocks != null else []
	if unlocks_data.is_empty():
		return []

	var available: Array = []
	for unlock in unlocks_data:
		var unlock_id = unlock.get("id", "")
		var unlock_group = unlock.get("unlock_group", "")
		var required_tier = unlock.get("required_tier", 1)

		# Skip if already unlocked
		if has_unlocked_group(unlock_group):
			continue

		# Skip if tier requirement not met
		if current_tier < required_tier:
			continue

		available.append(unlock)

	return available


## Check if player can afford an unlock's costs.
## Returns true if all material costs are in run_items.
func can_afford_facility_unlock(unlock: Dictionary) -> bool:
	var costs = unlock.get("costs", [])
	for cost in costs:
		var item_id = cost.get("item_id", "")
		var qty_needed = cost.get("qty", 0)
		if item_id == "" or qty_needed <= 0:
			continue
		var have = get_run_item_count(item_id)
		if have < qty_needed:
			return false
	return true


## Purchase a facility unlock by deducting costs and unlocking the group.
## Returns true if successful.
func purchase_facility_unlock(facility_id: String, unlock_id: String, town_id: String = "") -> bool:
	var facility = DataRegistry.get_facility(facility_id)
	if facility == null:
		print("[FacilityUnlock] purchase failed facility=%s reason=not_found" % facility_id)
		return false

	# Find the unlock entry (facility.unlocks is a property, not dict key)
	var unlocks_data = facility.unlocks if facility.unlocks != null else []
	var unlock: Dictionary = {}
	for u in unlocks_data:
		if u.get("id", "") == unlock_id:
			unlock = u
			break

	if unlock.is_empty():
		print("[FacilityUnlock] purchase failed facility=%s unlock=%s reason=unlock_not_found" % [facility_id, unlock_id])
		return false

	var unlock_group = unlock.get("unlock_group", "")
	var required_tier = unlock.get("required_tier", 1)
	var costs = unlock.get("costs", [])

	# Check if already unlocked
	if has_unlocked_group(unlock_group):
		print("[FacilityUnlock] purchase failed unlock=%s reason=already_unlocked" % unlock_id)
		return false

	# Check tier requirement
	var current_tier = 1
	if town_id != "":
		current_tier = get_facility_tier(town_id, facility_id)
	if current_tier < required_tier:
		print("[FacilityUnlock] purchase failed unlock=%s reason=tier_too_low (have=%d need=%d)" % [unlock_id, current_tier, required_tier])
		return false

	# Check if can afford all costs
	if not can_afford_facility_unlock(unlock):
		print("[FacilityUnlock] purchase failed unlock=%s reason=insufficient_materials" % unlock_id)
		return false

	# Deduct costs
	for cost in costs:
		var item_id = cost.get("item_id", "")
		var qty = cost.get("qty", 0)
		if item_id != "" and qty > 0:
			remove_run_item(item_id, qty)
			print("[FacilityUnlock] deducted item=%s qty=%d" % [item_id, qty])

	# Unlock the group
	unlock_group(unlock_group)
	print("[FacilityUnlock] SUCCESS facility=%s unlock=%s group=%s" % [facility_id, unlock_id, unlock_group])

	return true


# ============================================================================
# LEARNED CLASSES API
# ============================================================================

## Check if a class has been learned.
func has_learned_class(class_id: String) -> bool:
	if class_id == "":
		return false
	return learned_classes.get(class_id, false)


## Get all learned class IDs as an array.
func get_learned_classes() -> Array:
	var result: Array = []
	for c in learned_classes.keys():
		if learned_classes[c]:
			result.append(c)
	return result


## Learn a class from a book item. Consumes the book from run stash.
## Returns true if successful.
func learn_class_from_book(book_item_id: String) -> bool:
	# Check book is valid
	if not BOOK_TO_CLASS_MAP.has(book_item_id):
		print("[Training] learn failed book=%s reason=invalid_book_id" % book_item_id)
		return false

	var class_id = BOOK_TO_CLASS_MAP[book_item_id]

	# Check if already learned
	if has_learned_class(class_id):
		print("[Training] learn failed book=%s class=%s reason=already_learned" % [book_item_id, class_id])
		return false

	# Check if book exists in run stash
	var stash_dict = get_run_items_dict()
	if stash_dict.get(book_item_id, 0) < 1:
		print("[Training] learn failed book=%s class=%s reason=no_book_in_stash" % [book_item_id, class_id])
		return false

	# Consume book from run stash
	if not remove_run_item(book_item_id, 1):
		print("[Training] learn failed book=%s class=%s reason=remove_failed" % [book_item_id, class_id])
		return false

	# Learn the class
	learned_classes[class_id] = true
	print("[Training] learned_class=%s from_book=%s" % [class_id, book_item_id])
	save_game()
	return true


## Get the class ID for a given book item ID.
func get_class_for_book(book_item_id: String) -> String:
	return BOOK_TO_CLASS_MAP.get(book_item_id, "")


# ============================================================================
# TOWN TIERS API
# ============================================================================

## Get the tier for a town. Default is 1.
func get_town_tier(town_id: String) -> int:
	if town_id == "":
		return 1
	return town_tiers.get(town_id, 1)


## Set the tier for a town. Persists immediately.
func set_town_tier(town_id: String, tier: int) -> void:
	if town_id == "":
		return
	tier = maxi(tier, 1)  # Minimum tier is 1
	var old_tier = town_tiers.get(town_id, 1)
	if old_tier != tier:
		town_tiers[town_id] = tier
		print("[TownTier] %s tier %d -> %d" % [town_id, old_tier, tier])
		save_game()


## Check if a required town tier is met for gating.
## If required_tier <= 0 or 1, always returns true (no gating).
func meets_town_tier_requirement(town_id: String, required_tier: int) -> bool:
	if required_tier <= 1:
		return true  # No gating for tier 1 or below
	return get_town_tier(town_id) >= required_tier


## Check if a required dungeon floor is unlocked for gating.
## If required_floor <= 0 or 1, always returns true (no gating).
func meets_dungeon_floor_requirement(dungeon_id: String, required_floor: int) -> bool:
	if required_floor <= 1:
		return true  # No gating for floor 1 or below
	return get_unlocked_floor(dungeon_id) >= required_floor


# ============================================================================
# HERO RECRUITMENT & PARTY API
# ============================================================================

## Get all owned heroes.
func get_owned_heroes() -> Array:
	return owned_heroes.duplicate()


## Check if a hero is owned by ID.
func is_hero_owned(hero_id: String) -> bool:
	for hero in owned_heroes:
		if hero.get("hero_id", "") == hero_id:
			return true
	return false


## Check if a hero of a specific class is owned.
func has_hero_of_class(class_id: String) -> bool:
	for hero in owned_heroes:
		if hero.get("class_id", "") == class_id:
			return true
	return false


## Generate starting equipment for a recruit based on inn tier and region.
## R1: class-specific item (Striker=weapon, Defender=shield, Warden=healing tonic).
## R2+: random equipment slot (no consumables).
## T2+: 50% chance of a second armor/offhand item on top.
## Returns array of { item_id, slot, quality_tier } dictionaries.
func generate_recruit_equipment(class_id: String, current_region: int, inn_tier: int, rng: RandomNumberGenerator) -> Array:
	if inn_tier < 1:
		return []

	var class_data = DataRegistry.get_class_data(class_id)
	if class_data == null:
		return []

	var quality_tier: int = 0  # T1-T3: common
	if inn_tier >= 4:
		quality_tier = 1  # T4: uncommon

	var result: Array = []

	# --- First item: R1 = class-specific, R2+ = random slot ---
	if current_region == 1:
		result = _generate_r1_recruit_item(class_data, quality_tier, rng)
	else:
		result = _generate_random_slot_recruit_item(class_data, current_region, quality_tier, rng)

	# --- T2+ bonus: 50% chance of a second armor/offhand item ---
	if inn_tier >= 2:
		var filled_slots: Dictionary = {}
		for eq in result:
			filled_slots[eq.get("slot", "")] = true
		var eligible_armor: Array = _collect_eligible_armor(current_region)
		# Filter out items whose slot is already filled
		var available: Array = []
		for tpl in eligible_armor:
			if not filled_slots.has(tpl.equip_slot):
				available.append(tpl)
		if available.size() > 0 and rng.randf() < 0.5:
			var idx: int = rng.randi() % available.size()
			var tpl = available[idx]
			result.append({"item_id": tpl.template_id, "slot": tpl.equip_slot, "quality_tier": quality_tier})

	return result


## R1 class-specific starting item based on archetype.
func _generate_r1_recruit_item(class_data, quality_tier: int, rng: RandomNumberGenerator) -> Array:
	var archetype: String = class_data.archetype if class_data.archetype != null else ""

	match archetype:
		"vanguard":
			return [{"item_id": "wooden_shield", "slot": "offhand", "quality_tier": quality_tier}]
		"warden":
			return [{"item_id": "healing_tonic", "slot": "bag_item", "quality_tier": 0}]
		_:  # "striker" and any fallback (dps, healer, etc.)
			var weapon_id: String = _pick_recruit_weapon(class_data, 1, rng)
			if weapon_id != "":
				return [{"item_id": weapon_id, "slot": "weapon", "quality_tier": quality_tier}]
			return []


## R2+ random equipment slot: pick a random equip_slot, then a random item in it.
func _generate_random_slot_recruit_item(class_data, current_region: int, quality_tier: int, rng: RandomNumberGenerator) -> Array:
	var weapon_types: Array = []
	for wt in class_data.weapon_types:
		weapon_types.append(wt)

	var slot_pools: Dictionary = {}  # equip_slot -> Array[template]
	for template in DataRegistry.get_all_item_templates():
		if template.equip_slot == "" or template.equip_slot == "bag":
			continue
		if template.item_type == "consumable":
			continue
		if template.tier > 2:
			continue
		var region_match: bool = false
		for tag in template.tags:
			if tag == "region_1" or tag == "region_%d" % current_region:
				region_match = true
				break
		if not region_match:
			continue
		if template.equip_slot == "weapon" and not (template.item_subtype in weapon_types):
			continue
		if not slot_pools.has(template.equip_slot):
			slot_pools[template.equip_slot] = []
		slot_pools[template.equip_slot].append(template)

	var available_slots: Array = slot_pools.keys()
	if available_slots.is_empty():
		return []
	var slot_idx: int = rng.randi() % available_slots.size()
	var chosen_slot: String = available_slots[slot_idx]
	var pool: Array = slot_pools[chosen_slot]
	var item_idx: int = rng.randi() % pool.size()
	var chosen = pool[item_idx]
	return [{"item_id": chosen.template_id, "slot": chosen_slot, "quality_tier": quality_tier}]


## Collect eligible armor/offhand/helmet/legs items for the T2+ bonus.
func _collect_eligible_armor(current_region: int) -> Array:
	var result: Array = []
	for template in DataRegistry.get_all_item_templates():
		if template.equip_slot == "" or template.item_type == "consumable":
			continue
		if template.tier > 2:
			continue
		if template.equip_slot not in ["armor", "offhand", "helmet", "legs"]:
			continue
		var region_match: bool = false
		for tag in template.tags:
			if tag == "region_1" or tag == "region_%d" % current_region:
				region_match = true
				break
		if not region_match:
			continue
		result.append(template)
	return result


## Pick a random weapon matching a class's weapon_types from base + current region.
func _pick_recruit_weapon(class_data, current_region: int, rng: RandomNumberGenerator) -> String:
	var weapon_types: Array = []
	for wt in class_data.weapon_types:
		weapon_types.append(wt)
	var eligible: Array = []
	for template in DataRegistry.get_all_item_templates():
		if template.equip_slot != "weapon":
			continue
		if template.tier > 2:
			continue
		if not (template.item_subtype in weapon_types):
			continue
		var region_match: bool = false
		for tag in template.tags:
			if tag == "region_1" or tag == "region_%d" % current_region:
				region_match = true
				break
		if not region_match:
			continue
		eligible.append(template)
	if eligible.is_empty():
		return ""
	return eligible[rng.randi() % eligible.size()].template_id

## Recruit a new hero of the given class. Costs run stash gold.
## Returns the new hero's ID on success, empty string on failure.
## Optional race_id defaults to "human", optional level defaults to 1.
## Optional starting_equipment assigns items directly to hero equipment slots.
func recruit_hero(class_id: String, cost_gold: int, race_id: String = "human", level: int = 1, starting_equipment: Array = []) -> String:
	if class_id == "":
		print("[Inn] recruit failed reason=no_class_id")
		return ""

	if run_gold < cost_gold:
		print("[Inn] recruit failed class=%s cost=%d reason=insufficient_gold have=%d" % [class_id, cost_gold, run_gold])
		return ""

	# Block recruit if party full AND bench at this inn is full
	var party_full: bool = selected_party.size() >= get_max_party_size()
	var bench_full: bool = not can_bench_at_inn(_current_town_id)
	if party_full and bench_full:
		print("[Inn] recruit failed class=%s reason=party_and_bench_full town=%s bench=%d/%d" % [class_id, _current_town_id, get_inn_bench_count(_current_town_id), get_inn_bench_capacity(_current_town_id)])
		return ""

	# Spend gold from run stash
	if not spend_run_gold(cost_gold):
		return ""

	# Generate unique hero ID
	_hero_id_counter += 1
	var hero_id = "hero_%s_%d" % [class_id, _hero_id_counter]

	# Create hero entry with race_id, level, and xp
	# Name is class-agnostic so class reassignment doesn't cause confusion
	var hero = {
		"hero_id": hero_id,
		"class_id": class_id,
		"race_id": race_id,
		"gender": _pick_gender(),
		"name": "Hero #%d" % _hero_id_counter,
		"level": level,
		"xp": XP_THRESHOLDS[mini(level - 1, XP_THRESHOLDS.size() - 1)] if level > 1 else 0,
		"portrait_path": _pick_race_portrait(race_id),
		"home_town_id": _current_town_id
	}
	owned_heroes.append(hero)

	# Assign starting equipment if provided
	if starting_equipment.size() > 0:
		if not hero_equipment.has(hero_id):
			hero_equipment[hero_id] = _create_empty_equipment()
		for equip_entry in starting_equipment:
			var item_id: String = equip_entry.get("item_id", "")
			var slot: String = equip_entry.get("slot", "")
			var eq_quality: int = int(equip_entry.get("quality_tier", 0))
			if item_id == "":
				continue
			if slot == "bag_item":
				add_item_to_hero_bag(hero_id, item_id, 1)
				print("[Inn] starting_bag_item hero=%s item=%s" % [hero_id, item_id])
			elif slot != "":
				hero_equipment[hero_id][slot] = {"id": item_id, "quality": eq_quality}
				print("[Inn] starting_equip hero=%s slot=%s item=%s q=%d" % [hero_id, slot, item_id, eq_quality])

	print("[Inn] recruit class=%s race=%s level=%d xp=0 cost=%d equip=%d success=true hero_id=%s" % [class_id, race_id, level, cost_gold, starting_equipment.size(), hero_id])
	if is_inside_tree():
		var tm = get_node_or_null("/root/TelemetryManager")
		if tm != null:
			tm.log_hero_recruited(class_id, race_id, level)
	save_game()
	return hero_id


## Pick a random gender for a new hero (50/50).
func _pick_gender() -> String:
	return "m" if randi() % 2 == 0 else "f"


## Pick a random portrait from a race's portrait pool.
func _pick_race_portrait(race_id: String) -> String:
	if not DataRegistry.has_method("get_race"):
		return ""
	var race = DataRegistry.get_race(race_id)
	if race == null or race.portraits.size() == 0:
		return ""
	var idx: int = randi() % race.portraits.size()
	return race.portraits[idx]


## Get the selected party for dungeon runs.
func get_selected_party() -> Array:
	return selected_party.duplicate()


## Set the selected party. Validates hero ownership and max size.
func set_selected_party(hero_ids: Array) -> bool:
	var valid_ids: Array = []
	for hero_id in hero_ids:
		if is_hero_owned(hero_id) and hero_id not in valid_ids:
			valid_ids.append(hero_id)
		if valid_ids.size() >= get_max_party_size():
			break

	selected_party = valid_ids
	print("[Inn] party=%s" % str(selected_party))
	party_changed.emit(selected_party)
	save_game()
	return true


## Add a hero to the party if not already in and space available.
func add_to_party(hero_id: String) -> bool:
	if not is_hero_owned(hero_id):
		print("[Inn] add_to_party failed hero=%s reason=not_owned" % hero_id)
		return false
	if hero_id in selected_party:
		print("[Inn] add_to_party failed hero=%s reason=already_in_party" % hero_id)
		return false
	if selected_party.size() >= get_max_party_size():
		print("[Inn] add_to_party failed hero=%s reason=party_full" % hero_id)
		return false

	# Remove from training if they were training
	if is_hero_in_training(hero_id):
		remove_hero_from_training(hero_id)
	selected_party.append(hero_id)
	print("[Inn] add_to_party hero=%s party=%s" % [hero_id, str(selected_party)])
	party_changed.emit(selected_party)
	save_game()
	return true


## Swap two heroes' positions in the party by index. Returns true if successful.
func swap_party_positions(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= selected_party.size():
		return false
	if idx_b < 0 or idx_b >= selected_party.size():
		return false
	if idx_a == idx_b:
		return false
	var tmp = selected_party[idx_a]
	selected_party[idx_a] = selected_party[idx_b]
	selected_party[idx_b] = tmp
	print("[Party] swap %d<->%d party=%s" % [idx_a, idx_b, str(selected_party)])
	party_changed.emit(selected_party)
	return true


## Remove a hero from the party. Benches them at the current town's inn.
func remove_from_party(hero_id: String) -> bool:
	var idx = selected_party.find(hero_id)
	if idx == -1:
		return false
	selected_party.remove_at(idx)
	# Bench hero at current town's inn
	var hero = get_hero(hero_id)
	if not hero.is_empty():
		hero["home_town_id"] = _current_town_id
	print("[Inn] remove_from_party hero=%s town=%s party=%s" % [hero_id, _current_town_id, str(selected_party)])
	party_changed.emit(selected_party)
	save_game()
	return true


## Get hero data by ID.
func get_hero(hero_id: String) -> Dictionary:
	for hero in owned_heroes:
		if hero.get("hero_id", "") == hero_id:
			return hero
	return {}


## Get hero data by ID (alias for get_hero).
func get_hero_by_id(hero_id: String) -> Dictionary:
	return get_hero(hero_id)


# ============================================================================
# HERO RECRUIT v2 API (Town-facing roster & party helpers)
# ============================================================================

## Get the hero roster (alias for get_owned_heroes).
func get_roster() -> Array:
	return owned_heroes.duplicate()


## Check if a hero is currently in the selected party.
func is_in_party(hero_id: String) -> bool:
	return hero_id in selected_party


## Get heroes benched at a specific town's inn (non-party heroes with matching home_town_id).
func get_inn_bench_heroes(town_id: String) -> Array:
	var result: Array = []
	for hero in owned_heroes:
		if hero.get("home_town_id", "") == town_id and not is_in_party(hero.get("hero_id", "")):
			result.append(hero)
	return result


## Get bench count at a specific town's inn.
func get_inn_bench_count(town_id: String) -> int:
	return get_inn_bench_heroes(town_id).size()


## Get bench capacity for a town's inn based on facility tier.
func get_inn_bench_capacity(town_id: String) -> int:
	var tier: int = get_facility_tier(town_id, "inn")
	return BENCH_CAP_BY_INN_TIER.get(tier, 3)


## Check if there is room to bench a hero at this town's inn.
func can_bench_at_inn(town_id: String) -> bool:
	return get_inn_bench_count(town_id) < get_inn_bench_capacity(town_id)


## Add a hero definition to the roster.
func add_hero_to_roster(hero_def: Dictionary) -> void:
	if hero_def.is_empty() or hero_def.get("hero_id", "") == "":
		return
	owned_heroes.append(hero_def)
	var hero_id = hero_def.get("hero_id", "?")
	var hero_name = hero_def.get("name", hero_id)
	var archetype = hero_def.get("class_id", "?")
	print("[Recruit] add hero=%s name=%s archetype=%s" % [hero_id, hero_name, archetype])
	save_game()


## Remove a hero from the roster. Returns false if hero is in party.
func remove_hero_from_roster(hero_id: String) -> bool:
	if is_in_party(hero_id):
		print("[Recruit] dismiss failed hero=%s reason=in_party" % hero_id)
		return false
	for i in range(owned_heroes.size()):
		if owned_heroes[i].get("hero_id", "") == hero_id:
			owned_heroes.remove_at(i)
			print("[Recruit] dismiss hero=%s" % hero_id)
			save_game()
			return true
	return false


## Factory: Create a hero definition with a new unique ID.
## Does NOT add to roster or spend gold. Caller must add via add_hero_to_roster().
func recruit_new_hero(archetype_id: String, race_id: String = "human", level: int = 1) -> Dictionary:
	_hero_id_counter += 1
	var hero_id = "hero_%s_%d" % [archetype_id, _hero_id_counter]
	return {
		"hero_id": hero_id,
		"class_id": archetype_id,
		"race_id": race_id,
		"gender": _pick_gender(),
		"name": "Hero #%d" % _hero_id_counter,
		"level": level,
		"xp": XP_THRESHOLDS[mini(level - 1, XP_THRESHOLDS.size() - 1)] if level > 1 else 0,
		"portrait_path": _pick_race_portrait(race_id)
	}


## Get hero definition by ID (safe, returns empty dict if not found).
func get_hero_def(hero_id: String) -> Dictionary:
	return get_hero(hero_id)


## Get display name for a hero. Falls back to hero_id if not found.
func get_hero_display_name(hero_id: String) -> String:
	var hero = get_hero(hero_id)
	if hero.is_empty():
		return hero_id
	return hero.get("name", hero_id)


## Set a hero's display name. Trims whitespace, caps at 18 chars.
## Empty string resets to default "Hero #N" format.
func set_hero_name(hero_id: String, new_name: String) -> bool:
	var cleaned = new_name.strip_edges().left(18)
	for i in range(owned_heroes.size()):
		if owned_heroes[i].get("hero_id", "") == hero_id:
			if cleaned == "":
				# Reset to default name
				var counter_part = hero_id.split("_")
				var num = counter_part[-1] if counter_part.size() > 0 else str(i + 1)
				cleaned = "Hero #%s" % num
			owned_heroes[i]["name"] = cleaned
			print("[Recruit] rename hero=%s name=%s" % [hero_id, cleaned])
			save_game()
			return true
	return false


# ============================================================================
# HERO LEVELING SYSTEM (per GDD Section 33.3)
# ============================================================================

## Get global XP bonus multiplier from all Training Hall tiers across all regions.
## Each Training Hall tier contributes +2% XP globally.
# ============================================================================
# CHALLENGE LEVEL API (session-only — not saved)
# ============================================================================

func increment_challenge() -> void:
	challenge_level = mini(challenge_level + 1, MAX_CHALLENGE)
	print("[Challenge] Level increased to %d" % challenge_level)

func reset_challenge() -> void:
	challenge_level = 0
	print("[Challenge] Level reset to 0")

func get_hp_multiplier() -> float:
	return 1.0 + challenge_level * 0.12

func get_damage_multiplier() -> float:
	return 1.0 + challenge_level * 0.08

func get_gold_multiplier() -> float:
	return 1.0 + challenge_level * 0.05

func boss_bonus_enabled() -> bool:
	return challenge_level >= 5


func get_global_training_xp_bonus() -> float:
	var total_tiers: int = 0
	for key in facility_tiers.keys():
		if key.ends_with(":training_hall"):
			total_tiers += facility_tiers[key]
	return total_tiers * 0.02

## Get XP required to reach a target level.
func get_xp_for_level(target_level: int) -> int:
	if target_level < 1 or target_level > MAX_HERO_LEVEL:
		return 0
	return XP_THRESHOLDS[target_level - 1]


## Check if a hero's level meets the requirement for a given ability/passive slot.
## slot: "ability_a", "passive_a", "ability_b", or "passive_b"
static func is_ability_slot_unlocked(slot: String, hero_level: int) -> bool:
	var req: int = ABILITY_UNLOCK_LEVELS.get(slot, 1)
	return hero_level >= req

## Get XP award for a combat encounter, scaled by current region.
## encounter_type: "combat_normal", "combat_elite", or "combat_boss"
func get_combat_xp(encounter_type: String) -> int:
	var region: int = get_current_region()
	var base: int = REGION_XP_BASE.get(region, 15)
	match encounter_type:
		"combat_elite":
			return int(base * 1.5)
		"combat_boss":
			return int(base * 2.5)
		_:
			return base

## Get level from total XP.
func get_level_from_xp(total_xp: int) -> int:
	for lvl in range(MAX_HERO_LEVEL, 0, -1):
		if total_xp >= XP_THRESHOLDS[lvl - 1]:
			return lvl
	return 1

## Grant XP to a hero. Handles level-ups automatically.
## Returns number of levels gained.
func grant_hero_xp(hero_id: String, xp_amount: int) -> int:
	if xp_amount <= 0:
		return 0

	# Find hero
	for i in range(owned_heroes.size()):
		var hero = owned_heroes[i]
		if hero.get("hero_id", "") == hero_id:
			var old_level = int(hero.get("level", 1))
			var old_xp = int(hero.get("xp", 0))

			# Apply race XP modifier + global training bonus
			var race_id = hero.get("race_id", "human")
			var race_data = DataRegistry.get_race(race_id)
			var xp_modifier: float = 1.0
			if race_data != null:
				xp_modifier = race_data.xp_modifier
			var training_bonus: float = get_global_training_xp_bonus()

			var modified_xp = int(xp_amount * xp_modifier * (1.0 + training_bonus))
			var new_xp = old_xp + modified_xp
			owned_heroes[i]["xp"] = new_xp

			# Calculate new level
			var new_level = get_level_from_xp(new_xp)
			if new_level > MAX_HERO_LEVEL:
				new_level = MAX_HERO_LEVEL

			var levels_gained = new_level - old_level
			if levels_gained > 0:
				owned_heroes[i]["level"] = new_level
				var hero_name = hero.get("name", hero_id)
				print("[XP] hero=%s name=%s gained=%d (mod=%.2f) total_xp=%d old_level=%d new_level=%d levels_gained=%d" % [
					hero_id, hero_name, modified_xp, xp_modifier, new_xp, old_level, new_level, levels_gained
				])
				if is_inside_tree():
					var tm = get_node_or_null("/root/TelemetryManager")
					if tm != null:
						tm.log_hero_levelup(hero.get("class_id", "unknown"), hero.get("race_id", "unknown"), new_level)
			else:
				print("[XP] hero=%s gained=%d (mod=%.2f) total_xp=%d level=%d (no level up)" % [
					hero_id, modified_xp, xp_modifier, new_xp, old_level
				])

			save_game()
			return maxi(levels_gained, 0)

	print("[XP] hero=%s not found" % hero_id)
	return 0

## Grant XP to all heroes in the selected party with race modifier applied.
## source: describes XP source (e.g. "combat_normal", "combat_elite", "event")
## Returns dictionary of hero_id -> levels_gained.
func grant_party_xp(xp_amount: int, source: String = "unknown") -> Dictionary:
	var result: Dictionary = {}
	print("[XP] party_gain source=%s base=%d party=%d" % [source, xp_amount, selected_party.size()])

	for hero_id in selected_party:
		# Skip dead heroes — they don't earn XP
		var hp_data = get_hero_hp(hero_id)
		if not hp_data.is_empty() and int(hp_data.get("current", 0)) <= 0:
			print("[XP] hero=%s SKIPPED (dead)" % hero_id)
			continue

		var hero = get_hero(hero_id)
		if hero.is_empty():
			continue

		# Pass raw xp_amount — grant_hero_xp applies race modifier internally
		var levels = grant_hero_xp(hero_id, xp_amount)
		result[hero_id] = levels

		# Get updated hero data for logging
		var updated_hero = get_hero(hero_id)
		var total_xp = updated_hero.get("xp", 0)
		var level = updated_hero.get("level", 1)
		var hero_name = hero.get("name", hero_id)

		print("[XP] hero=%s name=%s gained_base=%d total=%d level=%d" % [
			hero_id, hero_name, xp_amount, total_xp, level
		])

	# Also grant 25% XP to resting (non-party, non-training) heroes
	var resting_result: Dictionary = grant_resting_heroes_xp(xp_amount)
	for rid in resting_result:
		result["resting_" + rid] = resting_result[rid]

	# Also grant training XP to heroes in training slots (50-75% based on tier)
	var training_result: Dictionary = grant_training_heroes_xp(xp_amount)
	for tid in training_result:
		result["training_" + tid] = training_result[tid]

	return result

## Grant 25% XP to heroes resting at inns (not in party, not in training).
func grant_resting_heroes_xp(xp_amount: int) -> Dictionary:
	var result: Dictionary = {}
	if xp_amount <= 0:
		return result
	var resting_xp: int = int(ceil(xp_amount * 0.25))
	for hero in owned_heroes:
		var hero_id: String = hero.get("hero_id", "")
		if hero_id == "":
			continue
		# Skip heroes in the active party
		if is_in_party(hero_id):
			continue
		# Skip heroes in training (they get higher XP separately)
		if is_hero_in_training(hero_id):
			continue
		# Must have a home_town_id (benched at an inn)
		var home_town: String = hero.get("home_town_id", "")
		if home_town == "":
			continue
		var levels: int = grant_hero_xp(hero_id, resting_xp)
		if levels > 0:
			print("[XP] resting hero=%s gained 25%% XP (%d base), leveled up %d times" % [hero_id, resting_xp, levels])
		result[hero_id] = levels
	return result

## Get hero's current stats (class base + growth * (level-1) + race modifiers).
func get_hero_stats(hero_id: String) -> Dictionary:
	var hero = get_hero(hero_id)
	if hero.is_empty():
		return {}

	var class_id = hero.get("class_id", "")
	var race_id = hero.get("race_id", "human")
	var level = int(hero.get("level", 1))

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)

	if class_data == null:
		return {}

	# Get stats at level (base + growth)
	var stats = class_data.get_stats_at_level(level)

	# Apply race modifiers
	if race_data != null:
		stats = race_data.apply_modifiers(stats)

	return stats


## Get hero's effective stats for combat with full metadata.
## Returns: { health, attack, defense, speed, level, class_id, race_id, name }
## This is the single source of truth for combat stat calculation.
func get_hero_effective_stats(hero_id: String) -> Dictionary:
	var hero = get_hero(hero_id)
	if hero.is_empty():
		return {}

	var class_id = hero.get("class_id", "")
	var race_id = hero.get("race_id", "human")
	var level = int(hero.get("level", 1))
	var hero_name = hero.get("name", hero_id)

	var class_data = DataRegistry.get_class_data(class_id)
	var race_data = DataRegistry.get_race(race_id)

	# Fallback stats if class not found
	var health: int = 80
	var attack: int = 12
	var defense: int = 8
	var speed: int = 10

	if class_data != null:
		# Get level-scaled stats (base + growth * (level - 1))
		var base_stats = class_data.get_stats_at_level(level)
		health = int(base_stats.get("health", 80))
		attack = int(base_stats.get("attack", 12))
		defense = int(base_stats.get("defense", 8))
		speed = int(base_stats.get("speed", 10))

	# Apply race modifiers (flat additive)
	if race_data != null:
		health += int(race_data.stat_modifiers.get("health", 0))
		attack += int(race_data.stat_modifiers.get("attack", 0))
		defense += int(race_data.stat_modifiers.get("defense", 0))
		speed += int(race_data.stat_modifiers.get("speed", 0))

	# v3: Apply per-hero equipment stat bonuses
	var gear_bonus = _get_hero_equipment_stat_bonuses(hero_id)
	health += gear_bonus.get("health", 0)
	attack += gear_bonus.get("attack", 0)
	defense += gear_bonus.get("defense", 0)
	speed += gear_bonus.get("speed", 0)

	# NG+ permanent stat bonus (stacking +5% per cycle from NG+4 onward)
	if ng_plus_perm_stat_bonus > 0.0:
		health = int(health * (1.0 + ng_plus_perm_stat_bonus))
		attack = int(attack * (1.0 + ng_plus_perm_stat_bonus))
		defense = int(defense * (1.0 + ng_plus_perm_stat_bonus))
		speed = int(speed * (1.0 + ng_plus_perm_stat_bonus))

	# New equipment stats (gear-only, no class/race base)
	var crit_chance: int = gear_bonus.get("crit_chance", 0)
	var evasion_val: int = gear_bonus.get("evasion", 0)
	var resist_val: int = gear_bonus.get("resist", 0)
	var thorns_val: int = gear_bonus.get("thorns", 0)
	var armor_penetration_val: int = gear_bonus.get("armor_penetration", 0)
	var life_steal_val: int = gear_bonus.get("life_steal", 0)

	# Log gear bonuses once per hero per combat spawn
	if not _gear_logged_heroes.has(hero_id):
		var equipped_slots: Array[String] = []
		for slot in EQUIPMENT_SLOTS:
			var item_id = get_hero_slot_item(hero_id, slot)
			if item_id != "":
				equipped_slots.append("%s=%s" % [slot, item_id])
		var bag_str = get_hero_bag_item(hero_id)
		if bag_str != "":
			equipped_slots.append("bag=%s" % bag_str)
		var gear_str = ", ".join(equipped_slots) if equipped_slots.size() > 0 else "none"
		print("[HeroGear] hero=%s gear=[%s] bonus={HP:+%d ATK:+%d DEF:+%d SPD:+%d}" % [
			hero_id, gear_str,
			gear_bonus.get("health", 0), gear_bonus.get("attack", 0),
			gear_bonus.get("defense", 0), gear_bonus.get("speed", 0)
		])
		_gear_logged_heroes[hero_id] = true

	# v6: Collect equipment ability IDs from T4 gear
	var equip_abilities: Array = get_hero_equipment_ability_ids(hero_id)

	# v7: Collect combat tag effects from T4 gear
	var tag_effects: Array = get_hero_combat_tag_effects(hero_id)

	return {
		"health": health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"crit_chance": crit_chance,
		"evasion": evasion_val,
		"resist": resist_val,
		"thorns": thorns_val,
		"armor_penetration": armor_penetration_val,
		"life_steal": life_steal_val,
		"level": level,
		"class_id": class_id,
		"race_id": race_id,
		"name": hero_name,
		"gear_bonus": gear_bonus,
		"equip_ability_ids": equip_abilities,
		"combat_tag_effects": tag_effects
	}


## Get XP needed to reach next level for a hero.
func get_hero_xp_to_next_level(hero_id: String) -> int:
	var hero = get_hero(hero_id)
	if hero.is_empty():
		return 0

	var level = int(hero.get("level", 1))
	var xp = int(hero.get("xp", 0))

	if level >= MAX_HERO_LEVEL:
		return 0  # Already max level

	var next_level_xp = get_xp_for_level(level + 1)
	return max(0, next_level_xp - xp)


## Get XP progress within current level for a hero.
## Returns { "current": xp_in_level, "needed": xp_for_level, "level": level, "is_max": bool }
## Used by all UI scenes for XP progress bars and text.
func get_hero_xp_progress(hero_id: String) -> Dictionary:
	var hero = get_hero(hero_id)
	if hero.is_empty():
		return {"current": 0, "needed": 100, "level": 1, "is_max": false}
	var xp: int = int(hero.get("xp", 0))
	var level: int = int(hero.get("level", 1))
	if level >= MAX_HERO_LEVEL:
		return {"current": 0, "needed": 1, "level": level, "is_max": true}
	var current_threshold: int = XP_THRESHOLDS[mini(level - 1, XP_THRESHOLDS.size() - 1)]
	var next_threshold: int = XP_THRESHOLDS[mini(level, XP_THRESHOLDS.size() - 1)]
	var xp_in_level: int = maxi(xp - current_threshold, 0)
	var xp_for_level: int = next_threshold - current_threshold
	if xp_for_level <= 0:
		xp_for_level = 1
	return {"current": xp_in_level, "needed": xp_for_level, "level": level, "is_max": false}


## Assign a class directly to a hero. Overwrites existing class.
## Returns true if successful.
func assign_class_to_hero(hero_id: String, class_id: String) -> bool:
	if hero_id == "" or class_id == "":
		print("[Training] assign hero=%s class=%s success=false reason=invalid_params" % [hero_id, class_id])
		return false

	# Find hero in owned_heroes
	for i in range(owned_heroes.size()):
		var hero = owned_heroes[i]
		if hero.get("hero_id", "") == hero_id:
			var old_class = hero.get("class_id", "none")
			var hero_name = hero.get("name", hero_id)
			var race_id = hero.get("race_id", "human")

			# Update class_id
			owned_heroes[i]["class_id"] = class_id

			print("[Training] assign hero=%s name=%s race=%s old_class=%s new_class=%s success=true" % [
				hero_id, hero_name, race_id, old_class, class_id
			])
			save_game()
			return true

	print("[Training] assign hero=%s class=%s success=false reason=hero_not_found" % [hero_id, class_id])
	return false


## Assign a class to a hero using a book item. Consumes the book from run stash.
## Allows overwriting existing class (no penalty).
## Returns true if successful.
func assign_class_from_book(hero_id: String, book_item_id: String) -> bool:
	# Validate book
	if not BOOK_TO_CLASS_MAP.has(book_item_id):
		print("[TrainingHall] apply_book_failed hero=%s book=%s reason=invalid_book_id" % [hero_id, book_item_id])
		return false

	var class_id = BOOK_TO_CLASS_MAP[book_item_id]

	# Validate hero exists
	var hero = get_hero(hero_id)
	if hero.is_empty():
		print("[TrainingHall] apply_book_failed hero=%s book=%s reason=hero_not_found" % [hero_id, book_item_id])
		return false

	var hero_name = hero.get("name", hero_id)
	var race_id = hero.get("race_id", "human")
	var old_class = hero.get("class_id", "none")

	# Check if hero already has this class (optional: allow re-assign or skip)
	if old_class == class_id:
		print("[TrainingHall] apply_book_failed hero=%s book=%s reason=already_has_class" % [hero_id, book_item_id])
		return false

	# Check if book exists in run stash
	var stash_dict = get_run_items_dict()
	if stash_dict.get(book_item_id, 0) < 1:
		print("[TrainingHall] apply_book_failed hero=%s book=%s reason=no_book_in_stash" % [hero_id, book_item_id])
		return false

	# Consume book from run stash
	if not remove_run_item(book_item_id, 1):
		print("[TrainingHall] apply_book_failed hero=%s book=%s reason=remove_failed" % [hero_id, book_item_id])
		return false

	# Assign the class
	if not assign_class_to_hero(hero_id, class_id):
		# Refund book if assignment failed (shouldn't happen)
		add_run_item(book_item_id, 1)
		return false

	print("[TrainingHall] apply_book hero=%s old_class=%s new_class=%s book=%s" % [
		hero_id, old_class, class_id, book_item_id
	])
	return true


# ============================================================================
# STASH UPGRADES API (purchased from General Store)
# ============================================================================

## Check if a stash upgrade is purchased (legacy name kept for compat).
func has_housing_upgrade(upgrade_id: String) -> bool:
	return housing_upgrades.get(upgrade_id, false)


## Purchase a stash upgrade. Costs run stash gold.
## Legacy function name kept for compatibility.
func purchase_housing_upgrade(upgrade_id: String, cost_gold: int, bonus_type: String, bonus_value: int) -> bool:
	if has_housing_upgrade(upgrade_id):
		print("[StashUpgrade] upgrade=%s result=fail reason=already_purchased" % upgrade_id)
		return false

	if run_gold < cost_gold:
		print("[StashUpgrade] upgrade=%s cost=%d result=fail reason=insufficient_gold have=%d" % [upgrade_id, cost_gold, run_gold])
		return false

	if not spend_run_gold(cost_gold):
		return false

	housing_upgrades[upgrade_id] = true

	# Apply bonus (only stash_capacity supported now)
	if bonus_type == "stash_capacity":
		bonus_stash_capacity += bonus_value

	print("[StashUpgrade] upgrade=%s cost=%d bonus=%s+%d result=success" % [upgrade_id, cost_gold, bonus_type, bonus_value])
	save_game()
	return true


## Get current stash bonus summary.
func get_housing_bonuses() -> Dictionary:
	return {
		"stash_capacity": bonus_stash_capacity
	}


# ============================================================================
# SHOP REFRESH API
# ============================================================================

## Refresh cost constants
const SHOP_REFRESH_BASE_COST: int = 5
const SHOP_REFRESH_SCALE_COST: int = 5
const SHOP_REFRESH_MAX_COST: int = 50

## Shop refresh limit by tier: max rerolls allowed per shop visit
const SHOP_REFRESH_LIMIT_BY_TIER: Dictionary = {
	1: 1,
	2: 2,
	3: 3,
	4: 4
}

## Get shop manual refresh uses for a specific shop (resets each town visit).
func get_shop_refresh_count(shop_id: String) -> int:
	return shop_refresh_counts.get(shop_id, 0)

## Get shop restock version (monotonically increasing, used for seed generation).
func get_shop_restock_version(shop_id: String) -> int:
	return shop_restock_version.get(shop_id, 0)

## Get the gold cost to refresh a shop.
## Cost formula: base + scale * refresh_count, capped at max.
## First refresh costs 5g, second 10g, third 15g, etc., capped at 50g.
func get_shop_refresh_cost(shop_id: String) -> int:
	var refresh_count = get_shop_refresh_count(shop_id)
	# Cost for NEXT refresh (after clicking)
	var next_refresh = refresh_count + 1
	var cost = SHOP_REFRESH_BASE_COST + SHOP_REFRESH_SCALE_COST * (next_refresh - 1)
	return mini(cost, SHOP_REFRESH_MAX_COST)


## Check if player can afford to refresh the shop.
func can_afford_shop_refresh(shop_id: String) -> bool:
	var cost = get_shop_refresh_cost(shop_id)
	return get_run_gold() >= cost

## Get maximum refresh limit for a shop based on its facility tier.
func get_shop_refresh_limit(shop_id: String) -> int:
	var town_id = get_current_town_id()
	var shop_tier: int = get_facility_tier(town_id, shop_id)
	return SHOP_REFRESH_LIMIT_BY_TIER.get(shop_tier, 1)

## Check if shop has refreshes remaining within tier limit.
func has_shop_refreshes_remaining(shop_id: String) -> bool:
	return get_shop_refresh_count(shop_id) < get_shop_refresh_limit(shop_id)


## Spend gold and manually refresh the shop inventory.
## Increments both refresh uses (for limit) and restock version (for seed).
## Returns true if successful, false if insufficient gold or limit reached.
func spend_shop_refresh(shop_id: String) -> bool:
	# Check refresh limit
	if not has_shop_refreshes_remaining(shop_id):
		print("[ShopRNG] refresh_blocked shop=%s reason=limit_reached count=%d limit=%d" % [
			shop_id, get_shop_refresh_count(shop_id), get_shop_refresh_limit(shop_id)])
		return false

	var cost = get_shop_refresh_cost(shop_id)
	var gold_before = get_run_gold()

	if gold_before < cost:
		print("[ShopRNG] refresh_pressed shop=%s cost=%d success=false gold_before=%d gold_after=%d (insufficient)" % [
			shop_id, cost, gold_before, gold_before
		])
		return false

	# Spend gold from run stash
	spend_run_gold(cost)
	var gold_after = get_run_gold()

	# Increment manual refresh uses (for tier limit tracking)
	shop_refresh_counts[shop_id] = get_shop_refresh_count(shop_id) + 1
	# Increment restock version (for seed change)
	shop_restock_version[shop_id] = get_shop_restock_version(shop_id) + 1

	print("[ShopRNG] refresh shop=%s cost=%d gold=%d->%d uses=%d/%d version=%d" % [
		shop_id, cost, gold_before, gold_after,
		get_shop_refresh_count(shop_id), get_shop_refresh_limit(shop_id),
		get_shop_restock_version(shop_id)])

	save_game()
	return true


## Restock shop on dungeon return: new inventory + fresh refresh allowance.
## Increments restock version (new seed), clears purchases, resets manual refresh uses.
## Also clears slot allocations so player re-chooses what to stock each visit.
func restock_shop(shop_id: String) -> void:
	shop_restock_version[shop_id] = get_shop_restock_version(shop_id) + 1
	shop_purchased_slots[shop_id] = []
	shop_refresh_counts[shop_id] = 0
	# Clear allocations so shop opens in allocation view each visit
	var town_id: String = shop_id.replace("shop_", "town_")
	if shop_slot_allocations.has(town_id):
		for facility_id in shop_slot_allocations[town_id]:
			shop_slot_allocations[town_id][facility_id] = 0
	print("[ShopRNG] restock shop=%s version=%d (refresh uses + allocations reset)" % [shop_id, get_shop_restock_version(shop_id)])


## Mark a shop slot as purchased (shows empty slot instead of item)
func mark_shop_slot_purchased(shop_id: String, slot_key: String) -> void:
	if not shop_purchased_slots.has(shop_id):
		shop_purchased_slots[shop_id] = []
	if slot_key not in shop_purchased_slots[shop_id]:
		shop_purchased_slots[shop_id].append(slot_key)
	print("[Shop] Slot purchased shop=%s slot=%s" % [shop_id, slot_key])


## Check if a shop slot has been purchased
func is_shop_slot_purchased(shop_id: String, slot_key: String) -> bool:
	if not shop_purchased_slots.has(shop_id):
		return false
	return slot_key in shop_purchased_slots[shop_id]


## Clear purchased slots for a shop (called on refresh)
func clear_shop_purchased_slots(shop_id: String) -> void:
	shop_purchased_slots[shop_id] = []


# ============================================================================
# SHOP SLOT ALLOCATION API (General Store v2)
# ============================================================================

## Get max shop slots for current town based on General Store tier.
func get_shop_max_slots(town_id: String) -> int:
	var shop_id: String = town_id.replace("town_", "shop_")
	var shop_tier = get_facility_tier(town_id, shop_id)
	return SHOP_TIER_MAX_SLOTS.get(shop_tier, SHOP_TIER_MAX_SLOTS[1])


## Get total slots currently allocated across all facilities.
func get_shop_allocated_slots(town_id: String) -> int:
	var allocations = shop_slot_allocations.get(town_id, {})
	var total = 0
	for facility_id in allocations.keys():
		total += int(allocations[facility_id])
	return total


## Get slot allocation for a specific facility.
func get_facility_slot_allocation(town_id: String, facility_id: String) -> int:
	var allocations = shop_slot_allocations.get(town_id, {})
	return int(allocations.get(facility_id, 0))


## Set slot allocation for a specific facility.
## Returns true if successful, false if would exceed max slots.
func set_facility_slot_allocation(town_id: String, facility_id: String, slots: int) -> bool:
	slots = max(0, slots)  # Can't be negative

	# Get current allocation and calculate new total
	var current = get_facility_slot_allocation(town_id, facility_id)
	var allocated = get_shop_allocated_slots(town_id)
	var max_slots = get_shop_max_slots(town_id)
	var new_total = allocated - current + slots

	if new_total > max_slots:
		print("[ShopSlots] set_allocation failed: town=%s facility=%s slots=%d would_exceed_max=%d/%d" % [
			town_id, facility_id, slots, new_total, max_slots])
		return false

	# Ensure town dict exists
	if not shop_slot_allocations.has(town_id):
		shop_slot_allocations[town_id] = {}

	shop_slot_allocations[town_id][facility_id] = slots
	print("[ShopSlots] set_allocation: town=%s facility=%s slots=%d total=%d/%d" % [
		town_id, facility_id, slots, new_total, max_slots])
	save_game()
	return true


## Increment slot allocation for a facility by 1. Returns true if successful.
func increment_facility_slots(town_id: String, facility_id: String) -> bool:
	var current = get_facility_slot_allocation(town_id, facility_id)
	return set_facility_slot_allocation(town_id, facility_id, current + 1)


## Decrement slot allocation for a facility by 1. Returns true if successful.
## Blocked if purchased items would be lost (slots are locked after purchase).
func decrement_facility_slots(town_id: String, facility_id: String) -> bool:
	var current = get_facility_slot_allocation(town_id, facility_id)
	if current <= 0:
		return false
	# Prevent deallocating below the number of purchased slots
	var purchased = _count_purchased_slots_for_facility(town_id, facility_id)
	if current <= purchased:
		print("[ShopSlots] decrement blocked: town=%s facility=%s slots=%d purchased=%d" % [
			town_id, facility_id, current, purchased])
		return false
	return set_facility_slot_allocation(town_id, facility_id, current - 1)


## Count how many shop slots for a contributing facility have been purchased.
func _count_purchased_slots_for_facility(town_id: String, facility_id: String) -> int:
	var town = DataRegistry.get_town(town_id)
	if town == null:
		return 0
	var shop_id: String = ""
	for fid in town.facility_ids:
		var fac = DataRegistry.get_facility(fid)
		if fac != null and fac.facility_type == "shop":
			shop_id = fid
			break
	if shop_id == "" or not shop_purchased_slots.has(shop_id):
		return 0
	var count: int = 0
	var prefix: String = facility_id + ":"
	for slot_key in shop_purchased_slots[shop_id]:
		if slot_key.begins_with(prefix):
			count += 1
	return count


## Get all slot allocations for a town.
func get_shop_slot_allocations(town_id: String) -> Dictionary:
	return shop_slot_allocations.get(town_id, {}).duplicate()


## Get unlocked recipes for a specific facility — effective shop list.
## Returns array of dictionaries with upgrade_tier and replacement resolved:
##   { "item_id": "rusty_sword", "upgrade_tier": 2, "facility_tier": 1 }
## Items that have been replaced by higher-tier unlocks are excluded.
func get_facility_unlocked_recipes(facility_id: String) -> Array:
	# Collect all unlocked entries for this facility
	var all_entries: Array = []
	var _collect = func(source: Dictionary) -> void:
		for key in source.keys():
			var data: Dictionary = source[key]
			if data.get("source_facility", "") != facility_id:
				continue
			var oid: String = data.get("output_id", key.split(":")[0])
			all_entries.append({
				"item_id": oid,
				"upgrade_tier": int(data.get("upgrade_tier", 1)),
				"facility_tier": int(data.get("facility_tier", 1)),
				"replaces": data.get("replaces", "")
			})
	_collect.call(DEFAULT_UNLOCKED_RECIPES)
	_collect.call(unlocked_recipes)

	# Per item_id keep only the highest upgrade_tier
	var best: Dictionary = {}  # item_id -> entry dict
	for entry in all_entries:
		var oid: String = entry.item_id
		if not best.has(oid) or entry.upgrade_tier > best[oid].upgrade_tier:
			best[oid] = entry

	# Build replacement set: if iron_sword(t3) replaces rusty_sword, remove rusty_sword
	var replaced_set: Dictionary = {}
	for oid in best.keys():
		var rep: String = best[oid].get("replaces", "")
		if rep != "":
			replaced_set[rep] = true

	# Return effective list (excluding replaced items)
	var result: Array = []
	for oid in best.keys():
		if replaced_set.has(oid):
			continue
		result.append(best[oid])
	return result


## Find all recipes that use a specific material/item.
## Returns array of { facility_name, recipe_name, output_id } dictionaries.
func get_recipes_using_material(material_id: String) -> Array:
	var result: Array = []
	var all_facilities = DataRegistry.get_all_facilities()

	for facility in all_facilities:
		if facility == null:
			continue
		var facility_name = facility.display_name

		for recipe in facility.crafting_recipes:
			var inputs = recipe.get("inputs", [])
			for input_item in inputs:
				if input_item.get("item_id", "") == material_id:
					var output_id = recipe.get("output_id", "")
					var output_tpl = DataRegistry.get_item_template(output_id)
					var recipe_name = output_tpl.display_name if output_tpl else output_id
					result.append({
						"facility_name": facility_name,
						"recipe_name": recipe_name,
						"output_id": output_id
					})
					break  # Don't add same recipe twice if material appears multiple times

	return result


# ============================================================================
# TOWN RESET (Auto-heal on return to town)
# ============================================================================

## Apply town reset: heal all heroes and clear status effects.
## Called automatically when exiting dungeon (extract or flee).
## Also called by TownScene on entry to ensure heroes are always healed in town.
## Health Persistence v1: Actually restores all hero HP to max.
## Permadeath: Removes dead heroes permanently before healing survivors.
## Safe to call multiple times (idempotent — no-ops if already cleared).
func apply_town_entry_reset() -> void:
	var party_size = selected_party.size()
	var hero_count = owned_heroes.size()

	# PERMADEATH: Process dead heroes BEFORE clearing HP tracking
	# This removes heroes who died in dungeon from roster permanently
	var dead_count = _process_dead_heroes()
	if dead_count > 0:
		print("[Permadeath] %d hero(es) permanently lost" % dead_count)
		save_game()  # Persist roster changes immediately

	# Health Persistence v1: Clear hero HP tracking (all heroes heal to full)
	var healed_count = hero_hp.size()
	hero_hp.clear()

	# Consumables v2: Clear hero status persistence (all DOT/debuffs removed)
	var status_count = hero_statuses.size()
	hero_statuses.clear()

	# Clear consumable usage tracking
	_combat_consumables_used.clear()

	# Clear shop purchased slots so Inn/shops refresh with new stock
	var shop_count = shop_purchased_slots.size()
	shop_purchased_slots.clear()

	print("[HP] town_heal healed=%d heroes party=%d total=%d dead=%d" % [healed_count, party_size, hero_count, dead_count])
	print("[TownReset] cleared_status=true cleared_consumables=true cleared_hero_statuses=%d cleared_shops=%d" % [status_count, shop_count])


# ============================================================================
# HERO HP PERSISTENCE (Health Persistence v1)
# ============================================================================

## Get hero's current HP. Returns { "current": int, "max": int } or empty if not tracked.
func get_hero_hp(hero_id: String) -> Dictionary:
	if hero_hp.has(hero_id):
		return hero_hp[hero_id]
	return {}

## Set hero's current HP after combat. Used by CombatController.
func set_hero_hp(hero_id: String, current: int, max_hp: int) -> void:
	hero_hp[hero_id] = { "current": current, "max": max_hp }

## Check if hero has persisted HP (has fought this dungeon run).
func has_hero_hp(hero_id: String) -> bool:
	return hero_hp.has(hero_id)

## Get hero's current HP ratio (0.0 to 1.0). Returns 1.0 if not tracked.
func get_hero_hp_ratio(hero_id: String) -> float:
	if not hero_hp.has(hero_id):
		return 1.0
	var hp_data = hero_hp[hero_id]
	if hp_data.get("max", 0) <= 0:
		return 1.0
	return float(hp_data.get("current", 0)) / float(hp_data.get("max", 1))


# ============================================================================
# DEAD HEROES TRACKING (Permadeath)
# ============================================================================

## Record a hero's death. Called when hero HP reaches 0 in combat.
## Stores a snapshot for Book of the Dead and marks for removal on town return.
func record_hero_death(hero_id: String, cause: String = "combat") -> void:
	# Find hero data
	var hero_data: Dictionary = {}
	for hero in owned_heroes:
		if hero.get("hero_id", "") == hero_id:
			hero_data = hero.duplicate()
			break

	if hero_data.is_empty():
		print("[Permadeath] hero_id=%s not found in roster" % hero_id)
		return

	# Create death record for Book of the Dead
	var death_record = {
		"hero_id": hero_id,
		"name": hero_data.get("name", "Unknown"),
		"race_id": hero_data.get("race_id", ""),
		"class_id": hero_data.get("class_id", ""),
		"level": hero_data.get("level", 1),
		"cause": cause,
		"timestamp": Time.get_unix_time_from_system()
	}
	dead_heroes.append(death_record)
	print("[Permadeath] Recorded death: %s (Lv%d %s) - cause=%s" % [
		death_record.name, death_record.level, death_record.class_id, cause])

## Check if a hero is marked as dead (pending removal on town return).
func is_hero_dead(hero_id: String) -> bool:
	for record in dead_heroes:
		if record.get("hero_id", "") == hero_id:
			return true
	# Also check HP tracking - if current HP <= 0, they're dead
	var hp_data = get_hero_hp(hero_id)
	if not hp_data.is_empty() and int(hp_data.get("current", 1)) <= 0:
		return true
	return false

## Get all dead hero records (for Book of the Dead UI).
func get_dead_heroes() -> Array:
	return dead_heroes.duplicate()

## Process dead heroes on town return - removes them from roster permanently.
## Called by apply_town_entry_reset().
func _process_dead_heroes() -> int:
	var removed_count = 0
	var heroes_to_remove: Array = []

	# Check hero_hp for any heroes at 0 HP that weren't recorded yet
	for hero_id in hero_hp.keys():
		var hp_data = hero_hp[hero_id]
		if int(hp_data.get("current", 1)) <= 0:
			# Record death if not already recorded
			var already_recorded = false
			for record in dead_heroes:
				if record.get("hero_id", "") == hero_id:
					already_recorded = true
					break
			if not already_recorded:
				record_hero_death(hero_id, "combat")

	# Collect hero IDs to remove
	for record in dead_heroes:
		var hero_id = record.get("hero_id", "")
		if hero_id != "" and hero_id not in heroes_to_remove:
			heroes_to_remove.append(hero_id)

	# Remove dead heroes from roster and party
	var party_changed_flag := false
	for hero_id in heroes_to_remove:
		# Remove from both party arrays
		if hero_id in selected_party:
			selected_party.erase(hero_id)
			party_changed_flag = true
			print("[Permadeath] Removed %s from selected_party" % hero_id)
		if hero_id in _party_hero_ids:
			_party_hero_ids.erase(hero_id)
			party_changed_flag = true
			print("[Permadeath] Removed %s from _party_hero_ids" % hero_id)

		# Remove from roster
		for i in range(owned_heroes.size() - 1, -1, -1):
			if owned_heroes[i].get("hero_id", "") == hero_id:
				var hero_name = owned_heroes[i].get("name", "Unknown")
				owned_heroes.remove_at(i)
				removed_count += 1
				print("[Permadeath] %s has been permanently removed from roster" % hero_name)
				break

		# Clean up equipment and bags
		hero_equipment.erase(hero_id)
		hero_bags.erase(hero_id)
		hero_hp.erase(hero_id)

	# Emit party_changed so UI updates (party bar, Inn, etc.)
	if party_changed_flag:
		party_changed.emit(_party_hero_ids)

	return removed_count


# ============================================================================
# HERO STATUS PERSISTENCE (Consumables v2)
# ============================================================================

## Get hero's persisted statuses. Returns Array of status dicts or empty.
func get_hero_statuses(hero_id: String) -> Array:
	if hero_statuses.has(hero_id):
		return hero_statuses[hero_id]
	return []

## Set hero's persisted statuses. Used by CombatController after combat.
func set_hero_statuses(hero_id: String, statuses: Array) -> void:
	if statuses.is_empty():
		hero_statuses.erase(hero_id)
	else:
		hero_statuses[hero_id] = statuses.duplicate(true)

## Check if hero has any persisted statuses.
func has_hero_statuses(hero_id: String) -> bool:
	return hero_statuses.has(hero_id) and not hero_statuses[hero_id].is_empty()

## Remove specific status from hero (used by cleanse consumables).
## Returns array of removed status IDs.
func remove_hero_status(hero_id: String, status_id: String) -> Array:
	if not hero_statuses.has(hero_id):
		return []
	var removed: Array = []
	var new_statuses: Array = []
	for status in hero_statuses[hero_id]:
		if status.get("id", "") == status_id:
			removed.append(status_id)
		else:
			new_statuses.append(status)
	if new_statuses.is_empty():
		hero_statuses.erase(hero_id)
	else:
		hero_statuses[hero_id] = new_statuses
	return removed

## Remove all DOT statuses from hero (poisoned, bleeding, etc.).
## Returns array of removed status IDs.
func remove_hero_dot_statuses(hero_id: String) -> Array:
	if not hero_statuses.has(hero_id):
		return []
	var dot_ids: Array[String] = ["poisoned", "bleeding"]
	var removed: Array = []
	var new_statuses: Array = []
	for status in hero_statuses[hero_id]:
		var sid = status.get("id", "")
		if sid in dot_ids:
			removed.append(sid)
		else:
			new_statuses.append(status)
	if new_statuses.is_empty():
		hero_statuses.erase(hero_id)
	else:
		hero_statuses[hero_id] = new_statuses
	return removed


# ============================================================================
# CONSUMABLES v1 - Combat Usage
# ============================================================================

## Reset consumable usage tracking at combat start.
func reset_combat_consumables() -> void:
	_combat_consumables_used.clear()

## Check if a hero can use a consumable this combat.
func can_hero_use_consumable(hero_id: String) -> bool:
	return not _combat_consumables_used.has(hero_id)

## Mark a hero as having used their consumable this combat.
func mark_consumable_used(hero_id: String) -> void:
	_combat_consumables_used[hero_id] = true

## Find a healing consumable. Priority: hero_bag > dungeon > run stash.
## Returns { "item_id": String, "use_value": int, "source": "hero_bag"|"dungeon"|"run", "hero_id": String } or empty.
func find_healing_consumable(hero_id: String = "") -> Dictionary:
	# Check hero bag first (if hero_id provided)
	if hero_id != "":
		for entry in get_hero_bag(hero_id):
			var eid = entry.get("item_id", "")
			if eid == "":
				continue
			var template = DataRegistry.get_item_template(eid)
			if template != null and _is_healing_consumable(template):
				return { "item_id": eid, "use_value": template.use_value, "source": "hero_bag", "hero_id": hero_id }

	# Check dungeon stash (when in dungeon)
	if current_dungeon_id != "":
		for item in dungeon_items:
			var item_id = ""
			if item is ItemInstance:
				item_id = item.template_id
			elif item is Dictionary:
				item_id = item.get("item_id", item.get("template_id", ""))
			if item_id == "":
				continue
			var template = DataRegistry.get_item_template(item_id)
			if template != null and _is_healing_consumable(template):
				return { "item_id": item_id, "use_value": template.use_value, "source": "dungeon" }

	# Check run stash
	for item in run_items:
		var item_id = ""
		if item is ItemInstance:
			item_id = item.template_id
		elif item is Dictionary:
			item_id = item.get("item_id", item.get("template_id", ""))
		if item_id == "":
			continue
		var template = DataRegistry.get_item_template(item_id)
		if template != null and _is_healing_consumable(template):
			return { "item_id": item_id, "use_value": template.use_value, "source": "run" }

	return {}

## Find a cleanse consumable (removes DOT or stun). Priority: hero_bag > dungeon > run.
## Returns { "item_id": String, "use_effect": String, "source": "hero_bag"|"dungeon"|"run", "hero_id": String } or empty.
func find_cleanse_consumable(for_effect: String, hero_id: String = "") -> Dictionary:
	# Map effect type to consumable use_effect
	var target_effects: Array = []
	if for_effect == "dot":
		target_effects = ["cure_poison", "cure_bleeding", "cleanse_dot"]
	elif for_effect == "stun":
		target_effects = ["remove_stun", "cure_stun"]

	if target_effects.is_empty():
		return {}

	# Check hero bag first (if hero_id provided)
	if hero_id != "":
		for entry in get_hero_bag(hero_id):
			var eid = entry.get("item_id", "")
			if eid == "":
				continue
			var template = DataRegistry.get_item_template(eid)
			if template != null and template.use_effect in target_effects:
				return { "item_id": eid, "use_effect": template.use_effect, "source": "hero_bag", "hero_id": hero_id }

	# Check dungeon stash first
	if current_dungeon_id != "":
		for item in dungeon_items:
			var item_id = _get_item_id_from_entry(item)
			if item_id == "":
				continue
			var template = DataRegistry.get_item_template(item_id)
			if template != null and template.use_effect in target_effects:
				return { "item_id": item_id, "use_effect": template.use_effect, "source": "dungeon" }

	# Check run stash
	for item in run_items:
		var item_id = _get_item_id_from_entry(item)
		if item_id == "":
			continue
		var template = DataRegistry.get_item_template(item_id)
		if template != null and template.use_effect in target_effects:
			return { "item_id": item_id, "use_effect": template.use_effect, "source": "run" }

	return {}

## Helper: Check if template is a healing consumable.
func _is_healing_consumable(template: ItemTemplate) -> bool:
	if template.item_type != "consumable":
		return false
	return template.use_effect in ["heal", "heal_small", "heal_large", "heal_and_buff", "heal_and_buff_all", "heal_and_cure", "heal_and_regen", "heal_shield", "hot_heal"]

## Helper: Extract item_id from stash entry (ItemInstance or Dictionary).
func _get_item_id_from_entry(item) -> String:
	if item is ItemInstance:
		return item.template_id
	elif item is Dictionary:
		return item.get("item_id", item.get("template_id", ""))
	return ""

## Consume 1 quantity of item from stash or hero bag.
## Returns true if consumed, false if not found.
## source: "dungeon", "run", or "hero_bag" (requires hero_id).
func consume_stash_item(item_id: String, source: String, hero_id: String = "") -> bool:
	if source == "hero_bag" and hero_id != "":
		var ok = remove_item_from_hero_bag(hero_id, item_id, 1)
		if ok:
			print("[Consumable] removed item=%s source=hero_bag hero=%s" % [item_id, hero_id])
		return ok
	elif source == "dungeon":
		return _consume_from_dungeon_stash(item_id)
	elif source == "run":
		return _consume_from_run_stash(item_id)
	elif source == "shopkeeper_bag":
		return _consume_from_shopkeeper_bag(item_id)
	return false

## Consume from dungeon stash.
func _consume_from_dungeon_stash(item_id: String) -> bool:
	for i in range(dungeon_items.size()):
		var item = dungeon_items[i]
		var entry_id = _get_item_id_from_entry(item)
		if entry_id == item_id:
			if item is ItemInstance:
				if item.quantity > 1:
					item.quantity -= 1
				else:
					dungeon_items.remove_at(i)
			else:
				dungeon_items.remove_at(i)
			print("[Consumable] removed item=%s source=dungeon remaining=%d" % [item_id, dungeon_items.size()])
			return true
	return false

## Consume from run stash.
func _consume_from_run_stash(item_id: String) -> bool:
	for i in range(run_items.size()):
		var item = run_items[i]
		var entry_id = _get_item_id_from_entry(item)
		if entry_id == item_id:
			if item is ItemInstance:
				if item.quantity > 1:
					item.quantity -= 1
				else:
					run_items.remove_at(i)
			else:
				run_items.remove_at(i)
			print("[Consumable] removed item=%s source=run remaining=%d" % [item_id, run_items.size()])
			return true
	return false

## Consume from shopkeeper bag.
func _consume_from_shopkeeper_bag(item_id: String) -> bool:
	for i in range(shopkeeper_bag.size()):
		var entry = shopkeeper_bag[i]
		var entry_id: String = entry.get("item_id", "")
		if entry_id == item_id:
			shopkeeper_bag.remove_at(i)
			print("[Consumable] removed item=%s source=shopkeeper_bag remaining=%d" % [item_id, shopkeeper_bag.size()])
			return true
	return false


# ============================================================================
# CONSUMABLES v2 - Camp Use (Manual Use in Dungeon Camp)
# ============================================================================

## Use a consumable on a hero in camp. Data-driven by template use_effect/use_value.
## Returns { "success": bool, "effect": String, "detail": String } for UI feedback.
## source_hero_id: when source="hero_bag", specifies which hero's bag to consume from.
##   If empty, defaults to hero_id (target hero = source hero, backward compatible).
func use_consumable_on_hero(item_id: String, hero_id: String, source: String = "dungeon", source_hero_id: String = "") -> Dictionary:
	# Get template for effect data
	var template = DataRegistry.get_item_template(item_id)
	if template == null:
		return { "success": false, "effect": "error", "detail": "Unknown item" }

	var use_effect = template.use_effect
	var use_value = template.use_value

	# Determine which hero's bag to consume from (for hero_bag source)
	var consume_hero: String = source_hero_id if source_hero_id != "" else hero_id

	# Get qty before consuming
	var qty_before = _count_item_in_stash(item_id, source)

	# Apply effect based on use_effect string
	var result: Dictionary = {}
	match use_effect:
		"heal", "heal_small", "heal_large", "heal_and_buff", "heal_and_buff_all", "heal_and_cure", "heal_and_regen", "heal_shield", "hot_heal":
			result = _apply_camp_heal(hero_id, use_value)
		"cure_poison":
			result = _apply_camp_cleanse(hero_id, ["poisoned"])
		"cure_bleeding":
			result = _apply_camp_cleanse(hero_id, ["bleeding"])
		"cleanse", "cure_all":
			result = _apply_camp_cleanse(hero_id, ["poisoned", "bleeding"])
		_:
			return { "success": false, "effect": use_effect, "detail": "Unsupported effect" }

	if not result.get("success", false):
		return result

	# Consume the item from the appropriate source
	var consumed = consume_stash_item(item_id, source, consume_hero)
	if not consumed:
		return { "success": false, "effect": use_effect, "detail": "Failed to consume item" }

	var qty_after = _count_item_in_stash(item_id, source)

	# Log the use
	print("[Consumable] use hero=%s item=%s effect=%s source=%s qty_before=%d qty_after=%d" % [
		hero_id, item_id, use_effect, source, qty_before, qty_after])

	result["qty_before"] = qty_before
	result["qty_after"] = qty_after
	return result


## Apply heal effect in camp context. Updates HP persistence.
func _apply_camp_heal(hero_id: String, heal_amount: int) -> Dictionary:
	# Get hero's current HP (from persistence or calculate max)
	var hp_data = get_hero_hp(hero_id)
	var current_hp: int
	var max_hp: int

	if hp_data.is_empty():
		# Hero hasn't fought yet this run - get max HP from effective stats
		var stats = get_hero_effective_stats(hero_id)
		if stats.is_empty():
			return { "success": false, "effect": "heal", "detail": "Unknown hero" }
		max_hp = int(stats.get("health", 100))
		current_hp = max_hp  # Full HP if not tracked
	else:
		current_hp = hp_data.get("current", 100)
		max_hp = hp_data.get("max", 100)

	var hp_before = current_hp
	var new_hp = mini(current_hp + heal_amount, max_hp)  # Clamp to max (no overheal)
	var actual_heal = new_hp - hp_before

	# Persist the new HP
	set_hero_hp(hero_id, new_hp, max_hp)

	print("[Consumable] heal hero=%s hp_before=%d hp_after=%d max=%d amount=%d" % [
		hero_id, hp_before, new_hp, max_hp, actual_heal])

	return { "success": true, "effect": "heal", "detail": "+%d HP" % actual_heal,
		"hp_before": hp_before, "hp_after": new_hp, "max_hp": max_hp, "amount": actual_heal }


## Apply cleanse effect in camp context. Updates status persistence.
func _apply_camp_cleanse(hero_id: String, status_ids: Array) -> Dictionary:
	var removed: Array = []

	for status_id in status_ids:
		var r = remove_hero_status(hero_id, status_id)
		removed.append_array(r)

	print("[Consumable] cleanse hero=%s removed=%s" % [hero_id, str(removed)])

	return { "success": true, "effect": "cleanse", "detail": "Removed %d" % removed.size(),
		"removed": removed }


## Count items in stash by item_id.
func _count_item_in_stash(item_id: String, source: String) -> int:
	if source == "shopkeeper_bag":
		var count = 0
		for entry in shopkeeper_bag:
			if entry.get("item_id", "") == item_id:
				count += int(entry.get("qty", 1))
		return count
	var stash = dungeon_items if source == "dungeon" else run_items
	var count = 0
	for item in stash:
		var entry_id = _get_item_id_from_entry(item)
		if entry_id == item_id:
			if item is ItemInstance:
				count += item.quantity
			else:
				count += 1
	return count


## Get list of consumables available in dungeon stash for camp UI.
## Returns Array of { "item_id": String, "display_name": String, "qty": int, "use_effect": String, "use_value": int }
func get_camp_consumables() -> Array:
	var result: Array = []
	var counted: Dictionary = {}  # item_id -> qty

	for item in dungeon_items:
		var item_id = _get_item_id_from_entry(item)
		if item_id == "":
			continue
		var template = DataRegistry.get_item_template(item_id)
		if template == null or template.item_type != "consumable":
			continue
		if template.use_effect == "":
			continue  # Not a usable consumable

		if not counted.has(item_id):
			counted[item_id] = 0
		if item is ItemInstance:
			counted[item_id] += item.quantity
		else:
			counted[item_id] += 1

	for item_id in counted.keys():
		var template = DataRegistry.get_item_template(item_id)
		if template != null:
			result.append({
				"item_id": item_id,
				"display_name": template.display_name,
				"qty": counted[item_id],
				"use_effect": template.use_effect,
				"use_value": template.use_value
			})

	return result


# ============================================================================
# STASH SUMMARY HELPERS (Items v6)
# ============================================================================

## Get detailed stash summary for UI display.
## Returns { gold, total_items, unique_items, gear_count, mat_count, cons_count, book_count }
func get_run_stash_detailed_summary() -> Dictionary:
	var summary = { "gold": run_gold, "total_items": 0, "unique_items": 0,
					"gear_count": 0, "mat_count": 0, "cons_count": 0, "book_count": 0 }
	var unique_ids: Dictionary = {}

	for item in run_items:
		var item_id = _get_item_id_from_entry(item)
		var qty = 1
		if item is ItemInstance:
			qty = item.quantity
		elif item is Dictionary:
			qty = item.get("qty", 1)

		summary["total_items"] += qty
		if not unique_ids.has(item_id):
			unique_ids[item_id] = true
			summary["unique_items"] += 1

		var template = DataRegistry.get_item_template(item_id)
		if template != null:
			if template.equip_slot != "":
				summary["gear_count"] += qty
			elif template.item_type == "consumable":
				summary["cons_count"] += qty
			elif template.item_type == "material" or template.category == "material":
				summary["mat_count"] += qty
			elif "book" in item_id or template.category == "book":
				summary["book_count"] += qty

	return summary

## Get detailed dungeon stash summary.
func get_dungeon_stash_detailed_summary() -> Dictionary:
	var summary = { "gold": dungeon_gold, "total_items": 0, "unique_items": 0,
					"gear_count": 0, "mat_count": 0, "cons_count": 0, "book_count": 0 }
	var unique_ids: Dictionary = {}

	for item in dungeon_items:
		var item_id = _get_item_id_from_entry(item)
		var qty = 1
		if item is ItemInstance:
			qty = item.quantity
		elif item is Dictionary:
			qty = item.get("qty", 1)

		summary["total_items"] += qty
		if not unique_ids.has(item_id):
			unique_ids[item_id] = true
			summary["unique_items"] += 1

		var template = DataRegistry.get_item_template(item_id)
		if template != null:
			if template.equip_slot != "":
				summary["gear_count"] += qty
			elif template.item_type == "consumable":
				summary["cons_count"] += qty
			elif template.item_type == "material" or template.category == "material":
				summary["mat_count"] += qty
			elif "book" in item_id or template.category == "book":
				summary["book_count"] += qty

	return summary


## Check if an item is available (its required group is unlocked).
## Used by shop filtering. If item has no requires_unlock_group, returns false (locked).
func is_item_available(requires_group: String) -> bool:
	if requires_group == "":
		return false  # Items must have a group requirement
	return has_unlocked_group(requires_group)


# Legacy compatibility - redirect to group system
func is_item_unlocked(item_id: String) -> bool:
	# Map old item_id to group for backwards compat
	var group = ITEM_TO_GROUP_MAP.get(item_id, "")
	if group != "":
		return has_unlocked_group(group)
	return false


## Check if player can afford materials from run stash.
## cost: Array of { "item_id": String, "qty": int }
func can_afford_run_materials(cost: Array) -> bool:
	var run_items_dict = get_run_items_dict()
	var can_afford = true
	var debug_have: Dictionary = {}
	for cost_item in cost:
		var item_id = cost_item.get("item_id", "")
		var qty_needed = cost_item.get("qty", 1)
		var qty_have = run_items_dict.get(item_id, 0)
		debug_have[item_id] = qty_have
		if qty_have < qty_needed:
			can_afford = false
	print("[UnlockDebug] can_afford_run_materials cost=%s have=%s result=%s" % [str(cost), str(debug_have), str(can_afford)])
	return can_afford


## Spend materials from run stash. Returns true if successful.
## cost: Array of { "item_id": String, "qty": int }
func spend_run_materials(cost: Array) -> bool:
	var before_counts: Dictionary = {}
	for cost_item in cost:
		var item_id = cost_item.get("item_id", "")
		before_counts[item_id] = get_run_item_count(item_id)

	if not can_afford_run_materials(cost):
		print("[UnlockDebug] spend_run_materials FAILED - cannot afford cost=%s before=%s" % [str(cost), str(before_counts)])
		return false

	for cost_item in cost:
		var item_id = cost_item.get("item_id", "")
		var qty = cost_item.get("qty", 1)
		remove_run_item(item_id, qty)

	var after_counts: Dictionary = {}
	for cost_item in cost:
		var item_id = cost_item.get("item_id", "")
		after_counts[item_id] = get_run_item_count(item_id)

	print("[UnlockDebug] spend_run_materials SUCCESS cost=%s before=%s after=%s" % [str(cost), str(before_counts), str(after_counts)])
	return true


## Initialize default unlock groups (fresh save) and migrate old item unlocks.
func _ensure_default_unlocks() -> void:
	# Migrate old item-based unlocks to group-based
	if not unlocked_item_ids.is_empty():
		print("[Unlock] Migrating old item unlocks to groups...")
		for item_id in unlocked_item_ids.keys():
			var group = ITEM_TO_GROUP_MAP.get(item_id, "")
			if group != "" and not unlocked_groups.get(group, false):
				unlocked_groups[group] = true
				print("[Unlock] Migrated %s -> %s" % [item_id, group])
		unlocked_item_ids.clear()  # Clear legacy data after migration

	# Ensure default groups are marked (for clarity, though has_unlocked_group handles this)
	if unlocked_groups.is_empty():
		print("[Unlock] Initialized with default unlock groups: %s" % str(DEFAULT_UNLOCK_GROUPS))


# ============================================================================
# PUBLIC API - FACILITY TIERS
# ============================================================================

## Get facility tier for a town+facility. Default is 1.
func get_facility_tier(town_id: String, facility_id: String) -> int:
	if town_id == "" or facility_id == "":
		return 1
	var key = "%s:%s" % [town_id, facility_id]
	return facility_tiers.get(key, 1)


## Get max tier for a facility from its data.
func get_facility_max_tier(facility_id: String) -> int:
	var facility = DataRegistry.get_facility(facility_id)
	if facility == null:
		return 1
	return facility.max_tier if facility.max_tier > 0 else 1


## Check if facility can be upgraded (tier < max_tier and can afford).
func can_upgrade_facility(town_id: String, facility_id: String) -> bool:
	var current_tier = get_facility_tier(town_id, facility_id)
	var max_tier = get_facility_max_tier(facility_id)
	if current_tier >= max_tier:
		return false
	var cost = get_facility_upgrade_cost(facility_id, current_tier + 1)
	return can_afford_facility_upgrade(cost)


## Get upgrade cost for a facility to reach a target tier.
## Checks regional_upgrade_costs for current region first, falls back to base upgrade_costs.
## Returns { "gold": int, "items": [{"item_id": str, "qty": int}, ...] }
func get_facility_upgrade_cost(facility_id: String, target_tier: int) -> Dictionary:
	var facility = DataRegistry.get_facility(facility_id)
	if facility == null:
		return { "gold": 0, "items": [] }

	var tier_key = str(target_tier)
	var region_key = str(current_region)

	# Check regional override first
	var cost_entry = null
	if facility.regional_upgrade_costs.has(region_key):
		var region_costs = facility.regional_upgrade_costs[region_key]
		if region_costs is Dictionary and region_costs.has(tier_key):
			cost_entry = region_costs[tier_key]

	# Fall back to base upgrade_costs
	if cost_entry == null:
		var base_costs = facility.upgrade_costs
		if base_costs.has(tier_key):
			cost_entry = base_costs[tier_key]

	if cost_entry is Dictionary:
		return {
			"gold": cost_entry.get("gold", 0),
			"items": cost_entry.get("items", [])
		}

	return { "gold": 0, "items": [] }


## Check if player can afford facility upgrade from run stash.
func can_afford_facility_upgrade(cost: Dictionary) -> bool:
	var gold_needed = cost.get("gold", 0)
	if gold_needed > 0 and run_gold < gold_needed:
		return false
	var items_needed = cost.get("items", [])
	return can_afford_run_materials(items_needed)


## Upgrade facility tier. Spends run stash resources. Returns true on success.
func upgrade_facility(town_id: String, facility_id: String) -> bool:
	var current_tier = get_facility_tier(town_id, facility_id)
	var max_tier = get_facility_max_tier(facility_id)
	var next_tier = current_tier + 1

	if current_tier >= max_tier:
		print("[FacilityTier] Cannot upgrade %s:%s - already at max tier %d" % [town_id, facility_id, max_tier])
		return false

	var cost = get_facility_upgrade_cost(facility_id, next_tier)
	if not can_afford_facility_upgrade(cost):
		print("[FacilityTier] Cannot upgrade %s:%s - cannot afford cost" % [town_id, facility_id])
		return false

	# Spend gold
	var gold_cost = cost.get("gold", 0)
	if gold_cost > 0:
		if not spend_run_gold(gold_cost):
			print("[FacilityTier] Failed to spend %d gold for %s:%s" % [gold_cost, town_id, facility_id])
			return false

	# Spend items
	var items_cost = cost.get("items", [])
	if items_cost.size() > 0:
		if not spend_run_materials(items_cost):
			print("[FacilityTier] Failed to spend materials for %s:%s" % [town_id, facility_id])
			# Refund gold if items failed
			if gold_cost > 0:
				add_run_gold(gold_cost)
			return false

	# Apply upgrade
	var key = "%s:%s" % [town_id, facility_id]
	facility_tiers[key] = next_tier
	print("[FacilityTier] Upgraded %s:%s to tier %d" % [town_id, facility_id, next_tier])
	if is_inside_tree():
		var tm = get_node_or_null("/root/TelemetryManager")
		if tm != null:
			tm.log_facility_upgrade(facility_id, next_tier)
	save_game()
	return true


# ============================================================================
# PUBLIC API - FLOOR UNLOCK & START FLOOR SELECTION
# ============================================================================

## Get the highest unlocked floor for a dungeon. Floor 1 is always unlocked.
func get_unlocked_floor(dungeon_id: String) -> int:
	if dungeon_id == "":
		return 1
	return unlocked_dungeon_floors.get(dungeon_id, 1)


## Unlock a floor for a dungeon. Only updates if floor > current unlocked.
## Clamps to 1..floor_count (R1-R4=4, R5-R6=5, R7=6).
func unlock_floor(dungeon_id: String, floor_num: int) -> void:
	if dungeon_id == "":
		return
	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var max_floor: int = dungeon.floor_count if dungeon != null else 6
	floor_num = clampi(floor_num, 1, max_floor)
	var current_unlocked = unlocked_dungeon_floors.get(dungeon_id, 1)
	if floor_num > current_unlocked:
		unlocked_dungeon_floors[dungeon_id] = floor_num
		print("[Unlock] dungeon=%s unlocked_floor=%d" % [dungeon_id, floor_num])
		save_game()


## Get the selected start floor for a dungeon. Defaults to 1.
func get_selected_start_floor(dungeon_id: String) -> int:
	if dungeon_id == "":
		return 1
	return selected_start_floors.get(dungeon_id, 1)


## Set the selected start floor for a dungeon. Only allowed if floor <= unlocked.
## Returns true if set successfully, false if floor is locked.
func set_selected_start_floor(dungeon_id: String, floor_num: int) -> bool:
	if dungeon_id == "":
		return false
	floor_num = clampi(floor_num, 1, 4)
	var unlocked = get_unlocked_floor(dungeon_id)
	if floor_num > unlocked:
		print("[FloorSelect] Cannot select floor %d (only unlocked up to %d)" % [floor_num, unlocked])
		return false
	selected_start_floors[dungeon_id] = floor_num
	print("[FloorSelect] dungeon=%s selected_floor=%d" % [dungeon_id, floor_num])
	save_game()
	return true


# ============================================================================
# PERSISTENCE - SAVE/LOAD
# ============================================================================

## Serialize run_items array to JSON-safe dictionaries.
## Handles both ItemInstance objects (dungeon loot) and legacy dict items (shop purchases).
## Note: display_name is NOT saved - rebuilt from template_id + quality_tier at load time.
func _serialize_run_items(items: Array) -> Array:
	var result: Array = []
	for item in items:
		if item is ItemInstance:
			var entry: Dictionary = {
				"type": "instance",
				"template_id": item.template_id,
				"qty": item.quantity,
				"quality_tier": item.quality_tier
			}
			# Save affix fields if present
			if item.affix_id != "":
				entry["source_region"] = item.source_region
				entry["affix_id"] = item.affix_id
				entry["affix_stats"] = item.affix_stats
				entry["affix_prefix"] = item.affix_prefix
			# Save NG+ bonus stat lines
			if item.bonus_stat_lines.size() > 0:
				entry["bonus_stat_lines"] = item.bonus_stat_lines
			result.append(entry)
		elif item is Dictionary:
			var entry: Dictionary = {
				"type": "dict",
				"item_id": item.get("item_id", ""),
				"qty": item.get("qty", 1),
				"quality_tier": item.get("quality_tier", 0)
			}
			# Preserve affix fields from dicts too
			if item.get("affix_id", "") != "":
				entry["source_region"] = item.get("source_region", "")
				entry["affix_id"] = item.get("affix_id", "")
				entry["affix_stats"] = item.get("affix_stats", {})
				entry["affix_prefix"] = item.get("affix_prefix", "")
			# Preserve NG+ bonus stat lines
			var ser_bonus_lines: Array = item.get("bonus_stat_lines", [])
			if ser_bonus_lines.size() > 0:
				entry["bonus_stat_lines"] = ser_bonus_lines
			result.append(entry)
	return result


## Deserialize run_items from saved data back to runtime objects.
## Restores ItemInstance objects from "instance" type, keeps dict items as-is.
func _deserialize_run_items(items_data: Array) -> Array:
	var result: Array = []
	var instance_count = 0
	var dict_count = 0

	for data in items_data:
		if not data is Dictionary:
			continue

		var item_type = data.get("type", "")

		if item_type == "instance":
			# Restore as ItemInstance
			var instance = ItemInstance.new()
			instance.template_id = data.get("template_id", "")
			instance.quantity = data.get("qty", 1)
			instance.quality_tier = data.get("quality_tier", 0)
			# Restore affix fields
			instance.source_region = data.get("source_region", "")
			instance.affix_id = data.get("affix_id", "")
			var affix_stats_val = data.get("affix_stats", {})
			instance.affix_stats = affix_stats_val if affix_stats_val is Dictionary else {}
			instance.affix_prefix = data.get("affix_prefix", "")
			# Restore NG+ bonus stat lines
			var deser_bonus_lines: Array = data.get("bonus_stat_lines", [])
			if deser_bonus_lines.size() > 0:
				instance.bonus_stat_lines = deser_bonus_lines
			# Always rebuild display_name from template (avoids stale names)
			if instance.template_id != "":
				var tpl = DataRegistry.get_item_template(instance.template_id)
				if tpl != null:
					var prefix = ItemInstance.QUALITY_PREFIXES[instance.quality_tier] if instance.quality_tier < ItemInstance.QUALITY_PREFIXES.size() else ""
					var base_name: String = prefix + tpl.display_name
					if instance.affix_prefix != "":
						instance.display_name = instance.affix_prefix + " " + base_name
					else:
						instance.display_name = base_name
				else:
					instance.display_name = instance.template_id  # Fallback if template missing
			result.append(instance)
			instance_count += 1
		elif item_type == "dict":
			# Keep as dictionary item
			var dict_entry: Dictionary = {
				"item_id": data.get("item_id", ""),
				"qty": data.get("qty", 1),
				"quality_tier": data.get("quality_tier", 0)
			}
			# Restore affix fields for dicts
			if data.get("affix_id", "") != "":
				dict_entry["source_region"] = data.get("source_region", "")
				dict_entry["affix_id"] = data.get("affix_id", "")
				dict_entry["affix_stats"] = data.get("affix_stats", {})
				dict_entry["affix_prefix"] = data.get("affix_prefix", "")
			# Restore NG+ bonus stat lines for dicts
			var deser_dict_bonus: Array = data.get("bonus_stat_lines", [])
			if deser_dict_bonus.size() > 0:
				dict_entry["bonus_stat_lines"] = deser_dict_bonus
			result.append(dict_entry)
			dict_count += 1
		else:
			# Legacy format without type field - assume dict
			if data.has("item_id"):
				result.append({
					"item_id": data.get("item_id", ""),
					"qty": data.get("qty", 1),
					"quality_tier": data.get("quality_tier", 0)
				})
				dict_count += 1

	print("[Load] run_items deserialized count=%d instances=%d dicts=%d" % [result.size(), instance_count, dict_count])

	# v1.4 Migration: Consolidate fragmented entries into proper stacks.
	# Old saves have many qty=1 entries for the same item. Merge them.
	var consolidated: Array = []
	for item in result:
		var item_id: String = ""
		var item_qty: int = 1
		var item_quality: int = 0
		var item_affix: String = ""
		if item is ItemInstance:
			item_id = item.template_id
			item_qty = item.quantity
			item_quality = item.quality_tier
			item_affix = item.affix_id if item.affix_id != "" else ""
		elif item is Dictionary:
			item_id = item.get("item_id", "")
			item_qty = int(item.get("qty", 1))
			item_quality = int(item.get("quality_tier", 0))
			item_affix = str(item.get("affix_id", ""))

		if item_id == "":
			continue

		var stack_limit: int = get_stash_stack_limit(item_id)
		var merged: bool = false

		# Try to merge into an existing consolidated entry
		for existing in consolidated:
			if existing is Dictionary and existing.get("item_id", "") == item_id and int(existing.get("quality_tier", 0)) == item_quality and str(existing.get("affix_id", "")) == item_affix:
				var current: int = int(existing.get("qty", 1))
				var space: int = stack_limit - current
				if space >= item_qty:
					existing["qty"] = current + item_qty
					merged = true
					break
				elif space > 0:
					existing["qty"] = stack_limit
					item_qty -= space
					# Remaining will be added as new entry below

		if not merged:
			# Preserve ItemInstance objects as-is if they fit within a single stack
			if item is ItemInstance and item_qty <= stack_limit:
				item.quantity = item_qty
				consolidated.append(item)
				item_qty = 0
			else:
				# Convert to dict for overflow / dict entries
				while item_qty > 0:
					var add_amt: int = mini(item_qty, stack_limit)
					var new_entry: Dictionary = {"item_id": item_id, "qty": add_amt, "quality_tier": item_quality}
					if item_affix != "":
						if item is Dictionary:
							new_entry["source_region"] = item.get("source_region", "")
							new_entry["affix_id"] = item.get("affix_id", "")
							new_entry["affix_stats"] = item.get("affix_stats", {})
							new_entry["affix_prefix"] = item.get("affix_prefix", "")
						elif item is ItemInstance:
							new_entry["source_region"] = item.source_region
							new_entry["affix_id"] = item.affix_id
							new_entry["affix_stats"] = item.affix_stats
							new_entry["affix_prefix"] = item.affix_prefix
					consolidated.append(new_entry)
					item_qty -= add_amt

	if consolidated.size() != result.size():
		print("[Load] run_items consolidated: %d entries -> %d stacks" % [result.size(), consolidated.size()])
	return consolidated


## Save game data to user://savegame.json.
## Saves: unlocked_dungeon_floors, selected_start_floors, equipment, unlocked_groups, facility_tiers, town_tiers, heroes, housing
## Serialize active side quests for save.
func _serialize_side_quests() -> Array:
	var result: Array = []
	for q in active_side_quests:
		if q is SideQuestData:
			result.append(q.to_dict())
	return result

## Deserialize side quests from save data.
func _deserialize_side_quests(data: Array) -> Array:
	var result: Array = []
	for entry in data:
		if entry is Dictionary:
			result.append(SideQuestData.from_dict(entry))
	return result


func save_game() -> void:
	if _dungeon_save_lock:
		print("[Save] BLOCKED — dungeon save lock active (mid-dungeon)")
		return
	var save_data = {
		"unlocked_dungeon_floors": unlocked_dungeon_floors,
		"selected_start_floors": selected_start_floors,
		# Legacy global equipment (kept for migration compatibility)
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_weapon_quality": equipped_weapon_quality,
		"equipped_offhand_id": equipped_offhand_id,
		"equipped_offhand_quality": equipped_offhand_quality,
		# Per-hero equipment (v3)
		"hero_equipment": hero_equipment,
		# Per-hero bags (v4 scaffolding)
		"hero_bags": hero_bags,
		"unlocked_groups": unlocked_groups,
		"unlocked_recipes": unlocked_recipes,
		"facility_tiers": facility_tiers,
		"learned_classes": learned_classes,
		"town_tiers": town_tiers,
		"owned_heroes": owned_heroes,
		"selected_party": selected_party,
		"hero_id_counter": _hero_id_counter,
		"hero_row_assignments": hero_row_assignments,
		"hero_grid_placements": hero_grid_placements,
		"housing_upgrades": housing_upgrades,
		"bonus_stash_capacity": bonus_stash_capacity,
		"shop_refresh_counts": shop_refresh_counts,
		"shop_restock_version": shop_restock_version,
		"shop_purchased_slots": shop_purchased_slots,
		"shop_slot_allocations": shop_slot_allocations,
		"inn_restock_counts": inn_restock_counts,
		# Player gold (town persistent)
		"player_gold": player_gold,
		# Run stash (banked gold persists across sessions)
		"run_gold": run_gold,
		"run_items": _serialize_run_items(run_items),
		"run_seed": _run_seed,
		"run_id": _run_id,
		"run_active": _run_active,
		# Shopkeeper bag (v5)
		"shopkeeper_bag": shopkeeper_bag,
		# Loot routing preferences (v5)
		"loot_pref": loot_pref,
		"auto_loot": auto_loot,
		"tester_mode": tester_mode,
		"text_size": text_size,
		"window_scale": window_scale,
		"telemetry_consent": telemetry_consent,
		"loot_panel_size": [loot_panel_size.x, loot_panel_size.y],
		# Region progression
		"current_region": current_region,
		"completed_tutorials": completed_tutorials,
		"campaign_flags": campaign_flags,
		"completed_regions": completed_regions,
		"region_id": _current_region_id,
		"town_id": _current_town_id,
		# Dead heroes (Permadeath / Book of the Dead)
		"dead_heroes": dead_heroes,
		# Mixing system (discovery + mishaps)
		"discovered_mixes": discovered_mixes,
		"alchemist_mishap_streak": alchemist_mishap_streak,
		"locked_facilities": locked_facilities,
		"inn_lockout": inn_lockout,
		# NG+ state
		"ng_plus_cycle": ng_plus_cycle,
		"ng_plus_perm_stat_bonus": ng_plus_perm_stat_bonus,
		"seen_abilities": seen_abilities,
		# Training slots
		"training_slots": training_slots,
		# Side quests
		"active_side_quests": _serialize_side_quests(),
		"side_quest_counter": _side_quest_counter,
		# Campaign quests
		"active_campaign_quest": active_campaign_quest.to_dict() if active_campaign_quest != null else null,
		"completed_campaign_quests": completed_campaign_quests.duplicate()
	}

	print("[Save] run_items serialized count=%d" % run_items.size())

	var save_path: String = get_save_path()
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		var err = FileAccess.get_open_error()
		push_warning("[GameContext] Failed to open save file for writing: %s (error %d)" % [save_path, err])
		return

	var json_str = JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.close()
	print("[GameContext] Game saved to %s" % save_path)
	# Update slot metadata
	save_slot_metadata()


## Reset save game (DEV TOOL ONLY).
## Deletes save file and resets all runtime state to fresh defaults.
## Use for testing saves, migrations, hero systems, etc.
func reset_save_game() -> void:
	print("[Dev] Reset save requested")
	print("[Dev] PRE-RESET: unlocked_groups=%s" % str(unlocked_groups))
	print("[Dev] PRE-RESET: owned_heroes=%d, player_gold=%d" % [owned_heroes.size(), player_gold])

	# Step 1: Delete save file if it exists
	var save_path: String = get_save_path()
	if FileAccess.file_exists(save_path):
		var err = DirAccess.remove_absolute(save_path)
		if err == OK:
			print("[Dev] Deleted %s" % save_path)
		else:
			push_warning("[Dev] Failed to delete save file (error %d)" % err)

	# Step 2: Clear all persistent state via shared helper
	print("[Dev] Reinitializing GameContext defaults")
	_reset_all_state_to_defaults()

	# Auto-discover base T1 recipes for fresh game
	auto_discover_base_recipes()

	# Save the fresh state to disk immediately
	save_game()

	# Log the final state to prove reset worked
	print("[Dev] Save reset complete unlocked_groups=%s facility_tiers=%s town_tiers=%s shop_refresh_counts=%s" % [unlocked_groups, facility_tiers, town_tiers, shop_refresh_counts])
	print("[Dev] Cleared: shopkeeper_bag=%d items, unlocked_recipes=%d, hero_hp=%d, hero_statuses=%d, dead_heroes=%d" % [shopkeeper_bag.size(), unlocked_recipes.size(), hero_hp.size(), hero_statuses.size(), dead_heroes.size()])
	print("[Dev] DEFAULT_UNLOCK_GROUPS (always checked via is_group_unlocked): %s" % str(DEFAULT_UNLOCK_GROUPS))


## Load game data from the current save slot file.
## If file doesn't exist, uses defaults (no error).
func load_game() -> void:
	var save_path: String = get_save_path()
	if not FileAccess.file_exists(save_path):
		print("[GameContext] No save file found at %s, using defaults" % save_path)
		_ensure_default_unlocks()
		auto_discover_base_recipes()
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		push_warning("[GameContext] Failed to open save file for reading: %s (error %d)" % [save_path, err])
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_warning("[GameContext] Failed to parse save file: %s (error %d at line %d)" % [
			save_path, parse_result, json.get_error_line()
		])
		return

	var save_data = json.get_data()
	if save_data is Dictionary:
		if save_data.has("unlocked_dungeon_floors") and save_data.unlocked_dungeon_floors is Dictionary:
			unlocked_dungeon_floors = save_data.unlocked_dungeon_floors
		if save_data.has("selected_start_floors") and save_data.selected_start_floors is Dictionary:
			selected_start_floors = save_data.selected_start_floors
		if save_data.has("equipped_weapon_id") and save_data.equipped_weapon_id is String:
			equipped_weapon_id = save_data.equipped_weapon_id
		if save_data.has("equipped_weapon_quality"):
			equipped_weapon_quality = int(save_data.equipped_weapon_quality)
		if save_data.has("equipped_offhand_id") and save_data.equipped_offhand_id is String:
			equipped_offhand_id = save_data.equipped_offhand_id
		if save_data.has("equipped_offhand_quality"):
			equipped_offhand_quality = int(save_data.equipped_offhand_quality)
		# Load per-hero equipment (v3)
		if save_data.has("hero_equipment") and save_data.hero_equipment is Dictionary:
			hero_equipment = save_data.hero_equipment
		# Load per-hero bags (v4 scaffolding, safe default = empty)
		if save_data.has("hero_bags") and save_data.hero_bags is Dictionary:
			hero_bags = save_data.hero_bags
		# Migration: convert legacy global equipment to per-hero equipment
		# If hero_equipment is empty but legacy equipment exists, assign to first party member
		if hero_equipment.is_empty() and (equipped_weapon_id != "" or equipped_offhand_id != ""):
			if selected_party.size() > 0:
				var first_hero_id = selected_party[0]
				hero_equipment[first_hero_id] = {
					"weapon": {"id": equipped_weapon_id, "quality": equipped_weapon_quality},
					"offhand": {"id": equipped_offhand_id, "quality": equipped_offhand_quality}
				}
				print("[Migration] legacy equipment -> hero=%s weapon=%s offhand=%s" % [first_hero_id, equipped_weapon_id, equipped_offhand_id])
				# Clear legacy equipment after migration
				equipped_weapon_id = ""
				equipped_weapon_quality = 0
				equipped_offhand_id = ""
				equipped_offhand_quality = 0
		# Load new group-based unlocks
		if save_data.has("unlocked_groups") and save_data.unlocked_groups is Dictionary:
			unlocked_groups = save_data.unlocked_groups
		# Load legacy item-based unlocks for migration
		if save_data.has("unlocked_item_ids") and save_data.unlocked_item_ids is Dictionary:
			unlocked_item_ids = save_data.unlocked_item_ids
		# Load recipe unlocks (shop item generation)
		if save_data.has("unlocked_recipes") and save_data.unlocked_recipes is Dictionary:
			unlocked_recipes = save_data.unlocked_recipes
			# Migrate plain recipe keys to :t1 format
			var _keys_to_migrate: Array = []
			for key in unlocked_recipes:
				if ":" not in key:
					_keys_to_migrate.append(key)
			for key in _keys_to_migrate:
				var _mdata: Dictionary = unlocked_recipes[key]
				var new_key: String = "%s:t1" % key
				if not unlocked_recipes.has(new_key):
					unlocked_recipes[new_key] = _mdata
				unlocked_recipes.erase(key)
		# Tutorials
		if save_data.has("completed_tutorials") and save_data.completed_tutorials is Dictionary:
			completed_tutorials = save_data.completed_tutorials
		if save_data.has("campaign_flags") and save_data.campaign_flags is Dictionary:
			campaign_flags = save_data.campaign_flags
		# Mixing system
		var discovered_val = save_data.get("discovered_mixes", {})
		discovered_mixes = discovered_val if discovered_val is Dictionary else {}
		alchemist_mishap_streak = int(save_data.get("alchemist_mishap_streak", 0))
		var locked_val = save_data.get("locked_facilities", {})
		locked_facilities = locked_val if locked_val is Dictionary else {}
		inn_lockout = bool(save_data.get("inn_lockout", false))
		# NG+ state
		if save_data.has("ng_plus_cycle"):
			ng_plus_cycle = int(save_data.ng_plus_cycle)
		if save_data.has("ng_plus_perm_stat_bonus"):
			ng_plus_perm_stat_bonus = float(save_data.ng_plus_perm_stat_bonus)
		if save_data.has("seen_abilities") and save_data.seen_abilities is Dictionary:
			seen_abilities = save_data.seen_abilities
		# Side quests
		if save_data.has("active_side_quests") and save_data.active_side_quests is Array:
			active_side_quests = _deserialize_side_quests(save_data.active_side_quests)
		if save_data.has("side_quest_counter"):
			_side_quest_counter = int(save_data.side_quest_counter)
		# Training slots
		var ts_data = save_data.get("training_slots", {})
		training_slots = ts_data if ts_data is Dictionary else {}
		# Campaign quests
		var acq_data = save_data.get("active_campaign_quest", null)
		if acq_data != null and acq_data is Dictionary:
			active_campaign_quest = CampaignQuestData.from_dict(acq_data)
		else:
			active_campaign_quest = null
		var ccq_data = save_data.get("completed_campaign_quests", [])
		completed_campaign_quests = ccq_data.duplicate() if ccq_data is Array else []
		if save_data.has("facility_tiers") and save_data.facility_tiers is Dictionary:
			facility_tiers = save_data.facility_tiers
			# Migration: Greenroot/Timberfall → Thornhaven consolidation
			var ft_migrated: Dictionary = {}
			for key in facility_tiers:
				var new_key: String = key
				if key.begins_with("town_greenroot:"):
					new_key = "town_thornhaven:" + key.substr("town_greenroot:".length())
				elif key.begins_with("town_timberfall:"):
					new_key = "town_thornhaven:" + key.substr("town_timberfall:".length())
				if ft_migrated.has(new_key):
					ft_migrated[new_key] = max(ft_migrated[new_key], facility_tiers[key])
				else:
					ft_migrated[new_key] = facility_tiers[key]
			if ft_migrated.size() != facility_tiers.size():
				print("[Migration] facility_tiers: consolidated %d keys → %d keys" % [facility_tiers.size(), ft_migrated.size()])
				facility_tiers = ft_migrated
		if save_data.has("learned_classes") and save_data.learned_classes is Dictionary:
			learned_classes = save_data.learned_classes
			# Migration: mender -> warden
			if learned_classes.has("mender"):
				learned_classes["warden"] = true
				learned_classes.erase("mender")
				print("[Migration] learned_classes: mender -> warden")
		if save_data.has("town_tiers") and save_data.town_tiers is Dictionary:
			town_tiers = save_data.town_tiers
			# Migration: Greenroot/Timberfall → Thornhaven consolidation
			var tt_migrated: Dictionary = {}
			for key in town_tiers:
				var new_key: String = key
				if key == "town_greenroot" or key == "town_timberfall":
					new_key = "town_thornhaven"
				if tt_migrated.has(new_key):
					tt_migrated[new_key] = max(tt_migrated[new_key], town_tiers[key])
				else:
					tt_migrated[new_key] = town_tiers[key]
			if tt_migrated.size() != town_tiers.size():
				print("[Migration] town_tiers: consolidated %d keys → %d keys" % [town_tiers.size(), tt_migrated.size()])
				town_tiers = tt_migrated
		# Load hero/party data
		if save_data.has("owned_heroes") and save_data.owned_heroes is Array:
			owned_heroes = save_data.owned_heroes
			# Migration: add race_id to heroes that don't have it (default: human)
			for hero in owned_heroes:
				if not hero.has("race_id") or hero.get("race_id", "") == "":
					hero["race_id"] = "human"
					print("[Migration] hero %s: added race_id=human" % hero.get("hero_id", "?"))
				# Migration: add portrait_path to heroes that don't have it
				if not hero.has("portrait_path") or hero.get("portrait_path", "") == "":
					hero["portrait_path"] = _pick_race_portrait(hero.get("race_id", "human"))
					print("[Migration] hero %s: assigned portrait" % hero.get("hero_id", "?"))
			# Migration: mender -> warden in hero class_ids
			for hero in owned_heroes:
				if hero.get("class_id", "") == "mender":
					hero["class_id"] = "warden"
					print("[Migration] hero %s class_id: mender -> warden" % hero.get("hero_id", "?"))
			# Migration: convert class-based names to neutral "Hero #X" format
			# Detects patterns like "Defender #1", "Striker #2", "Warden #3", "Mender #4"
			var class_name_pattern = RegEx.new()
			class_name_pattern.compile("^(Defender|Striker|Warden|Mender) #(\\d+)$")
			for hero in owned_heroes:
				var hero_name = hero.get("name", "")
				var match_result = class_name_pattern.search(hero_name)
				if match_result:
					var hero_num = match_result.get_string(2)
					var old_name = hero_name
					hero["name"] = "Hero #%s" % hero_num
					print("[Migration] hero %s name: '%s' -> '%s'" % [hero.get("hero_id", "?"), old_name, hero["name"]])
			# Migration: add level to heroes that don't have it (default: 1)
			for hero in owned_heroes:
				if not hero.has("level"):
					hero["level"] = 1
					print("[Migration] hero %s: added level=1" % hero.get("hero_id", "?"))
			# Migration: add xp to heroes that don't have it (default: 0)
			for hero in owned_heroes:
				if not hero.has("xp"):
					hero["xp"] = 0
					print("[Migration] hero %s: added xp=0" % hero.get("hero_id", "?"))
			# Migration: fix heroes with xp below their level threshold (recruited at level>1 with xp=0)
			for hero in owned_heroes:
				var hlvl: int = int(hero.get("level", 1))
				var hxp: int = int(hero.get("xp", 0))
				if hlvl > 1:
					var min_xp: int = XP_THRESHOLDS[mini(hlvl - 1, XP_THRESHOLDS.size() - 1)]
					if hxp < min_xp:
						hero["xp"] = min_xp
						print("[Migration] hero %s: xp %d -> %d (level %d minimum)" % [hero.get("hero_id", "?"), hxp, min_xp, hlvl])
			# Migration: add gender to heroes that don't have it (default: "m")
			for hero in owned_heroes:
				if not hero.has("gender"):
					hero["gender"] = "m"
					print("[Migration] hero %s: added gender=m" % hero.get("hero_id", "?"))
			# Migration: strip unknown keys from hero dicts (e.g., stale "gold" field)
			var _HERO_ALLOWED_KEYS = ["hero_id", "class_id", "race_id", "gender", "name", "level", "xp", "portrait_path", "home_town_id"]
			for hero in owned_heroes:
				var keys_to_remove: Array = []
				for key in hero.keys():
					if key not in _HERO_ALLOWED_KEYS:
						keys_to_remove.append(key)
				for key in keys_to_remove:
					hero.erase(key)
					print("[Migration] hero %s: stripped unknown key '%s'" % [hero.get("hero_id", "?"), key])
			# Migration: add home_town_id to heroes that don't have it (default: town_thornhaven)
			for hero in owned_heroes:
				if not hero.has("home_town_id") or hero.get("home_town_id", "") == "":
					hero["home_town_id"] = "town_thornhaven"
					print("[Migration] hero %s: added home_town_id=town_thornhaven" % hero.get("hero_id", "?"))
		if save_data.has("selected_party") and save_data.selected_party is Array:
			selected_party = save_data.selected_party
		if save_data.has("hero_id_counter"):
			_hero_id_counter = int(save_data.hero_id_counter)
		# Load hero row assignments (3-Row Formation v1)
		# Missing = empty dict; get_hero_row() returns 1 (Middle) for any missing hero
		if save_data.has("hero_row_assignments") and save_data.hero_row_assignments is Dictionary:
			hero_row_assignments = save_data.hero_row_assignments
		if save_data.has("hero_grid_placements") and save_data.hero_grid_placements is Dictionary:
			hero_grid_placements = save_data.hero_grid_placements
		# Load stash upgrades (legacy name "housing_upgrades" kept for compat)
		if save_data.has("housing_upgrades") and save_data.housing_upgrades is Dictionary:
			housing_upgrades = save_data.housing_upgrades
		if save_data.has("bonus_stash_capacity"):
			bonus_stash_capacity = int(save_data.bonus_stash_capacity)
		# Migration: bonus_starting_gold removed - old saves safely ignored
		# Load shop refresh counts + restock version
		if save_data.has("shop_refresh_counts") and save_data.shop_refresh_counts is Dictionary:
			shop_refresh_counts = save_data.shop_refresh_counts
		if save_data.has("shop_restock_version") and save_data.shop_restock_version is Dictionary:
			shop_restock_version = save_data.shop_restock_version
		# Load shop purchased slots (empty slots after purchase)
		if save_data.has("shop_purchased_slots") and save_data.shop_purchased_slots is Dictionary:
			shop_purchased_slots = save_data.shop_purchased_slots
		# Load shop slot allocations
		if save_data.has("shop_slot_allocations") and save_data.shop_slot_allocations is Dictionary:
			shop_slot_allocations = save_data.shop_slot_allocations
		# Load Inn restock counts per town
		if save_data.has("inn_restock_counts") and save_data.inn_restock_counts is Dictionary:
			inn_restock_counts = save_data.inn_restock_counts
		# Load player gold (town persistent)
		if save_data.has("player_gold"):
			player_gold = int(save_data.player_gold)
		# Load run stash (banked gold persists across sessions)
		if save_data.has("run_gold"):
			run_gold = int(save_data.run_gold)
		if save_data.has("run_items") and save_data.run_items is Array:
			run_items = _deserialize_run_items(save_data.run_items)
		# Restore run seed/state so mid-dungeon saves get correct event RNG
		if save_data.has("run_seed"):
			_run_seed = int(save_data.run_seed)
		if save_data.has("run_id"):
			_run_id = str(save_data.run_id)
		if save_data.has("run_active"):
			_run_active = bool(save_data.run_active)
		# Load shopkeeper bag (v5, safe default = empty)
		if save_data.has("shopkeeper_bag") and save_data.shopkeeper_bag is Array:
			shopkeeper_bag = save_data.shopkeeper_bag
		# Load loot routing preferences (v5, safe default = keep current)
		if save_data.has("loot_pref") and save_data.loot_pref is Dictionary:
			for key in save_data.loot_pref:
				loot_pref[key] = save_data.loot_pref[key]
		# Auto-loot gameplay option
		if save_data.has("auto_loot"):
			auto_loot = bool(save_data.auto_loot)
		if save_data.has("tester_mode"):
			tester_mode = bool(save_data.tester_mode)
		if save_data.has("text_size"):
			text_size = clampi(int(save_data.text_size), 0, 2)
		if save_data.has("window_scale"):
			window_scale = clampi(int(save_data.window_scale), 0, 3)
		if save_data.has("telemetry_consent"):
			telemetry_consent = bool(save_data.telemetry_consent)
		if save_data.has("loot_panel_size") and save_data.loot_panel_size is Array and save_data.loot_panel_size.size() == 2:
			loot_panel_size = Vector2(float(save_data.loot_panel_size[0]), float(save_data.loot_panel_size[1]))
		# Load region progression
		if save_data.has("current_region"):
			current_region = clampi(int(save_data.current_region), 1, 7)
		if save_data.has("completed_regions") and save_data.completed_regions is Dictionary:
			completed_regions = save_data.completed_regions
		# Restore location strings (region_id + town_id)
		if save_data.has("region_id") and save_data.region_id is String and save_data.region_id != "":
			_current_region_id = save_data.region_id
		else:
			_current_region_id = "region_%d" % current_region
		if save_data.has("town_id") and save_data.town_id is String and save_data.town_id != "":
			_current_town_id = save_data.town_id
		# Load dead heroes (Permadeath / Book of the Dead)
		if save_data.has("dead_heroes") and save_data.dead_heroes is Array:
			dead_heroes = save_data.dead_heroes
		print("[GameContext] Game loaded from %s (floors=%s groups=%d fac_tiers=%d classes=%d town_tiers=%d heroes=%d party=%d hero_gear=%d shop_refreshes=%d run_gold=%d run_items=%d region=%d dead=%d)" % [
			save_path, str(unlocked_dungeon_floors), unlocked_groups.size(),
			facility_tiers.size(), learned_classes.size(), town_tiers.size(), owned_heroes.size(), selected_party.size(), hero_equipment.size(), shop_refresh_counts.size(), run_gold, run_items.size(), current_region, dead_heroes.size()
		])
	else:
		push_warning("[GameContext] Save file data is not a Dictionary")

	# Ensure default unlocks exist and migrate legacy item unlocks to groups
	_ensure_default_unlocks()
	# Auto-discover base T1 mixing recipes (migration for existing saves)
	auto_discover_base_recipes()


# ============================================================================
# PUBLIC API - DUNGEON STASH (Provisional Rewards)
# ============================================================================

## Add rewards to dungeon stash (provisional - not yet banked).
func add_dungeon_rewards(gold: int, items: Array) -> void:
	var old_gold = dungeon_gold
	var old_count = dungeon_items.size()
	dungeon_gold += maxi(gold, 0)
	for it in items:
		dungeon_items.append(it)
	print("[DungeonStash] +Gold=%d +Items=%d => Gold=%d Items=%d" % [
		maxi(gold, 0), items.size(), dungeon_gold, dungeon_items.size()
	])


## Clear dungeon stash (used on flee - rewards lost).
func clear_dungeon_stash() -> void:
	dungeon_gold = 0
	dungeon_items.clear()


## Commit dungeon stash to run stash (used on extract - rewards banked).
func commit_dungeon_stash_to_run() -> void:
	var commit_gold = dungeon_gold
	var commit_items = dungeon_items.size()
	run_gold += dungeon_gold
	for it in dungeon_items:
		var item_id: String = ""
		var qty: int = 1
		var quality: int = 0
		if it is Dictionary:
			item_id = it.get("item_id", "")
			qty = int(it.get("qty", 1))
			quality = int(it.get("quality_tier", 0))
		elif it is ItemInstance:
			item_id = it.template_id
			qty = it.quantity
			quality = it.quality_tier
		if item_id != "":
			add_run_item(item_id, qty, quality)
	clear_dungeon_stash()
	print("[Extract] Committed dungeon stash to run stash. RunGold=%d RunSlots=%d (+%d gold, +%d items)" % [
		run_gold, run_items.size(), commit_gold, commit_items
	])


## v1.2: Bank shopkeeper bag contents to run stash on extract.
## Called when successfully returning to town from dungeon.
func bank_shopkeeper_bag_to_stash() -> void:
	if shopkeeper_bag.is_empty():
		return
	var moved_stacks = shopkeeper_bag.size()
	var moved_qty = 0
	for entry in shopkeeper_bag:
		var item_id: String = entry.get("item_id", "")
		var qty: int = int(entry.get("qty", 1))
		var quality: int = int(entry.get("quality_tier", 0))
		moved_qty += qty
		add_run_item(item_id, qty, quality)
	shopkeeper_bag.clear()
	print("[Extract] bank_shop_bag moved_stacks=%d moved_qty=%d to_stash=true" % [moved_stacks, moved_qty])


## v2.0: Bank only the safe (insured) slots of the shopkeeper bag.
## Called on flee or full party wipe — only first SHOPKEEPER_SAFE_SLOTS survive.
func bank_safe_shopkeeper_slots_only() -> void:
	if shopkeeper_bag.is_empty():
		return
	var safe_count: int = mini(SHOPKEEPER_SAFE_SLOTS, shopkeeper_bag.size())
	var saved: int = 0
	var lost: int = shopkeeper_bag.size() - safe_count
	for i in range(safe_count):
		var entry: Dictionary = shopkeeper_bag[i]
		var item_id: String = entry.get("item_id", "")
		var qty: int = int(entry.get("qty", 1))
		var quality: int = int(entry.get("quality_tier", 0))
		add_run_item(item_id, qty, quality)
		saved += 1
	shopkeeper_bag.clear()
	print("[Insurance] Saved %d safe items, lost %d unsafe items" % [saved, lost])


## Swap two items in the shopkeeper bag by index.
func swap_shopkeeper_bag_items(idx_a: int, idx_b: int) -> bool:
	if idx_a < 0 or idx_a >= shopkeeper_bag.size():
		return false
	if idx_b < 0 or idx_b >= shopkeeper_bag.size():
		return false
	if idx_a == idx_b:
		return false
	var temp: Dictionary = shopkeeper_bag[idx_a]
	shopkeeper_bag[idx_a] = shopkeeper_bag[idx_b]
	shopkeeper_bag[idx_b] = temp
	print("[ShopBag] Swapped slot %d <-> %d" % [idx_a, idx_b])
	return true


## Move an item from hero bag to shopkeeper bag.
func move_item_hero_to_shopkeeper(hero_id: String, hero_bag_idx: int) -> bool:
	if not hero_bags.has(hero_id):
		return false
	var bag: Array = hero_bags[hero_id]
	if hero_bag_idx < 0 or hero_bag_idx >= bag.size():
		return false
	if shopkeeper_bag.size() >= SHOPKEEPER_BAG_CAPACITY_DEFAULT:
		return false
	var entry: Dictionary = bag[hero_bag_idx]
	shopkeeper_bag.append(entry.duplicate())
	bag.remove_at(hero_bag_idx)
	print("[ShopBag] Moved item from hero=%s idx=%d to shopkeeper bag" % [hero_id, hero_bag_idx])
	return true


## Move an item from shopkeeper bag to hero bag.
func move_item_shopkeeper_to_hero(shop_idx: int, hero_id: String) -> bool:
	if shop_idx < 0 or shop_idx >= shopkeeper_bag.size():
		return false
	if not hero_bags.has(hero_id):
		hero_bags[hero_id] = []
	var bag: Array = hero_bags[hero_id]
	var hero_data: Dictionary = get_hero(hero_id)
	var capacity: int = get_hero_bag_capacity(hero_id) if has_method("get_hero_bag_capacity") else DEFAULT_HERO_BAG_CAPACITY
	if bag.size() >= capacity:
		return false
	var entry: Dictionary = shopkeeper_bag[shop_idx]
	bag.append(entry.duplicate())
	shopkeeper_bag.remove_at(shop_idx)
	print("[ShopBag] Moved item from shopkeeper idx=%d to hero=%s" % [shop_idx, hero_id])
	return true


## v1.3: Bank non-consumable items from hero bags to run stash on town return.
## Only consumables should stay in hero bags between dungeon runs.
func bank_hero_materials_to_stash() -> void:
	var total_moved = 0
	for hero_id in selected_party:
		if not hero_bags.has(hero_id):
			continue
		var bag: Array = hero_bags[hero_id]
		var items_to_remove: Array = []

		for i in range(bag.size()):
			var entry = bag[i]
			var item_id: String = entry.get("item_id", "")
			var template = DataRegistry.get_item_template(item_id)

			# Only keep consumables in hero bags - move everything else to stash
			if template == null or template.item_type != "consumable":
				var qty: int = int(entry.get("qty", 1))
				var quality: int = int(entry.get("quality_tier", entry.get("quality", 0)))
				add_run_item(item_id, qty, quality)
				items_to_remove.append(i)
				total_moved += 1
				print("[Extract] hero=%s banked material=%s qty=%d to stash" % [hero_id, item_id, qty])

		# Remove items in reverse order to preserve indices
		for i in range(items_to_remove.size() - 1, -1, -1):
			bag.remove_at(items_to_remove[i])

	if total_moved > 0:
		print("[Extract] bank_hero_materials total_moved=%d to_stash=true" % total_moved)


## Get dungeon stash summary.
func get_dungeon_stash_summary() -> Dictionary:
	return { "gold": dungeon_gold, "items_count": dungeon_items.size() }


## Add gold to dungeon stash (event reward).
func add_dungeon_gold(amount: int) -> void:
	if amount <= 0:
		return
	dungeon_gold += amount
	print("[DungeonStash] +%d gold => %d total" % [amount, dungeon_gold])


## Remove gold from dungeon stash (event cost/penalty).
## Returns actual amount removed (may be less if not enough gold).
func remove_dungeon_gold(amount: int) -> int:
	if amount <= 0:
		return 0
	var actual = mini(amount, dungeon_gold)
	dungeon_gold -= actual
	print("[DungeonStash] -%d gold => %d total" % [actual, dungeon_gold])
	return actual


## Add item to dungeon stash by item_id.
## Creates a simple item drop dictionary for now.
func add_dungeon_item(item_id: String, qty: int = 1) -> void:
	if item_id == "" or qty <= 0:
		return
	for i in range(qty):
		dungeon_items.append({ "item_id": item_id, "qty": 1 })
	print("[DungeonStash] +%d %s => %d items total" % [qty, item_id, dungeon_items.size()])


## Remove item from dungeon stash by item_id.
## Returns actual quantity removed.
func remove_dungeon_item_by_id(item_id: String, qty: int = 1) -> int:
	if item_id == "" or qty <= 0:
		return 0
	var removed = 0
	var i = 0
	while i < dungeon_items.size() and removed < qty:
		var item = dungeon_items[i]
		if item is Dictionary and item.get("item_id", "") == item_id:
			dungeon_items.remove_at(i)
			removed += 1
		else:
			i += 1
	if removed > 0:
		print("[DungeonStash] -%d %s => %d items total" % [removed, item_id, dungeon_items.size()])
	return removed


## Remove item from dungeon stash by tag (checks item template tags).
## Returns actual quantity removed.
func remove_dungeon_item_by_tag(tag: String, qty: int = 1) -> int:
	if tag == "" or qty <= 0:
		return 0
	var removed = 0
	var i = 0
	while i < dungeon_items.size() and removed < qty:
		var item = dungeon_items[i]
		if item is Dictionary:
			var item_id = item.get("item_id", "")
			var template = DataRegistry.get_item_template(item_id) if item_id != "" else null
			if template != null and template.tags.has(tag):
				dungeon_items.remove_at(i)
				removed += 1
				continue
		i += 1
	if removed > 0:
		print("[DungeonStash] -%d (tag:%s) => %d items total" % [removed, tag, dungeon_items.size()])
	return removed


## Check if dungeon stash has enough gold.
func has_dungeon_gold(amount: int) -> bool:
	return dungeon_gold >= amount


## Check if dungeon stash has item by id.
func has_dungeon_item(item_id: String, qty: int = 1) -> bool:
	if item_id == "" or qty <= 0:
		return false
	var count = 0
	for item in dungeon_items:
		if item is Dictionary and item.get("item_id", "") == item_id:
			count += 1
			if count >= qty:
				return true
	return false


## Check if dungeon stash has item by tag.
func has_dungeon_item_by_tag(tag: String, qty: int = 1) -> bool:
	if tag == "" or qty <= 0:
		return false
	var count = 0
	for item in dungeon_items:
		if item is Dictionary:
			var item_id = item.get("item_id", "")
			var template = DataRegistry.get_item_template(item_id) if item_id != "" else null
			if template != null and template.tags.has(tag):
				count += 1
				if count >= qty:
					return true
	return false


# ============================================================================
# PUBLIC API - DUNGEON PROGRESSION
# ============================================================================

func enter_dungeon(dungeon_id: String) -> void:
	# Start a new run with a fresh random seed (ensures events differ each entry)
	start_new_run()

	_dungeon_save_lock = true
	current_dungeon_id = dungeon_id

	# Use selected start floor (defaults to 1 if not set)
	var start_floor = get_selected_start_floor(dungeon_id)
	current_floor = start_floor
	current_room_index = 0
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1

	# Clear dungeon stash for fresh run
	clear_dungeon_stash()

	# Reset hero death tracking for flee availability
	_hero_died_this_run = false

	# Reset room choice state
	current_room_is_elite = false
	pending_room_choices = {}
	pending_selected_choice = {}
	_last_room_was_event = false

	# Apply and clear training buffs from town
	var training = apply_and_clear_training_buffs()
	if training.bonus_max_hp > 0:
		print("[GameContext] Training bonus active: +%d Max HP" % training.bonus_max_hp)

	# Generate dynamic rooms_per_floor using seeded RNG
	var rng = SeededRng.get_dungeon_rng()
	rooms_per_floor = generate_rooms_per_floor(rng)

	# Room 1 is always normal combat (no choice needed)
	current_room_type = "combat"
	current_room_is_elite = false

	set_phase(GamePhase.DUNGEON_SELECT)
	print("[GameContext] Entered dungeon: %s (start_floor=%d room %d/%d type=%s)" % [
		dungeon_id, current_floor, current_room_index + 1, rooms_per_floor, current_room_type
	])


func advance_floor() -> void:
	if current_dungeon_id == "":
		push_warning("[GameContext] Cannot advance floor: not in a dungeon")
		return
	current_floor += 1
	current_room_index = 0  # Reset room to first room of new floor

	# Clamp to dungeon floor count if available
	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	if dungeon != null and dungeon.floor_count > 0:
		current_floor = mini(current_floor, dungeon.floor_count)

	# Regenerate rooms_per_floor for the new floor
	var rng = SeededRng.get_dungeon_rng()
	rooms_per_floor = generate_rooms_per_floor(rng)

	# Reset room choice state - Room 1 is always combat
	current_room_type = "combat"
	current_room_is_elite = false
	pending_room_choices = {}
	pending_selected_choice = {}
	_last_room_was_event = false

	print("[GameContext] Advanced to floor %d (room %d/%d type=%s)" % [
		current_floor, current_room_index + 1, rooms_per_floor, current_room_type
	])


func exit_to_town() -> void:
	var old_dungeon = current_dungeon_id
	current_dungeon_id = ""
	current_floor = 0
	current_room_index = 0
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1
	_last_room_was_event = false
	_hero_died_this_run = false
	returned_from_dungeon = true  # Side quest trigger flag
	set_phase(GamePhase.TOWN)

	# v1.2: Bank shopkeeper bag to stash on extract
	bank_shopkeeper_bag_to_stash()

	# v1.3: Bank non-consumables from hero bags to stash (only consumables stay)
	bank_hero_materials_to_stash()

	# TownReset: heal all heroes and clear status effects
	apply_town_entry_reset()

	# Restock shop on dungeon return: new inventory + fresh refresh allowance
	var shop_id = _current_town_id.replace("town_", "shop_")
	restock_shop(shop_id)
	print("[GameContext] Shop restocked on dungeon return (shop_id=%s)" % shop_id)

	# Unlock saves and persist town-return state
	_dungeon_save_lock = false
	save_game()

	print("[GameContext] Exited dungeon '%s', returned to town" % old_dungeon)


func enter_dungeon_camp() -> void:
	set_phase(GamePhase.DUNGEON_CAMP)
	print("[GameContext] Entered dungeon camp (floor %d)" % current_floor)


func flee_to_town() -> void:
	var lost_gold = dungeon_gold
	var lost_items = dungeon_items.size()
	print("[Flee] Dungeon stash lost. RunGold unchanged=%d (lost %d gold, %d items)" % [
		run_gold, lost_gold, lost_items
	])
	clear_dungeon_stash()

	# Strip non-starter equipment from surviving heroes (T1 common kept)
	strip_heroes_except_starter()

	# Insurance: bank only safe slots before exit clears the rest
	bank_safe_shopkeeper_slots_only()

	print("[GameContext] Fleeing from dungeon '%s' floor %d" % [current_dungeon_id, current_floor])

	# Note: exit_to_town() will call apply_town_entry_reset()
	exit_to_town()


func descend_and_start_next_floor() -> void:
	advance_floor()
	set_phase(GamePhase.COMBAT)
	print("[GameContext] Descending to floor %d, starting combat" % current_floor)


func get_current_dungeon_id() -> String:
	return current_dungeon_id


func get_current_floor() -> int:
	return current_floor


func get_current_room_index() -> int:
	return current_room_index


func get_rooms_per_floor() -> int:
	return rooms_per_floor


func advance_room() -> void:
	if current_dungeon_id == "":
		push_warning("[GameContext] Cannot advance room: not in a dungeon")
		return
	if current_room_index < rooms_per_floor - 1:
		current_room_index += 1
		# Refresh room type for new room
		refresh_room_type()
		print("[GameContext] Advanced to room %d/%d (floor %d type=%s)" % [
			current_room_index + 1, rooms_per_floor, current_floor, current_room_type
		])
	else:
		print("[GameContext] Already at last room on floor %d" % current_floor)


func is_last_room_on_floor() -> bool:
	return current_room_index >= rooms_per_floor - 1


func is_boss_room() -> bool:
	# Boss room: on final floor AND on last room of that floor
	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4
	return current_floor >= floor_count and is_last_room_on_floor()


# ============================================================================
# ROOM TYPE MANAGEMENT
# ============================================================================

func get_current_room_type() -> String:
	return current_room_type


func refresh_room_type() -> void:
	# Default to combat if not in dungeon
	if current_dungeon_id == "":
		current_room_type = "combat"
		return

	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	if dungeon == null:
		current_room_type = "combat"
		return

	# Convert 1-based floor to 0-based index
	var floor_idx = current_floor - 1

	# Validate array bounds
	if floor_idx < 0 or floor_idx >= dungeon.room_types_by_floor.size():
		current_room_type = "combat"
		return

	var floor_rooms = dungeon.room_types_by_floor[floor_idx]
	if current_room_index < 0 or current_room_index >= floor_rooms.size():
		current_room_type = "combat"
		return

	current_room_type = floor_rooms[current_room_index]

	# Validate room type is known
	var valid_types = ["combat", "elite", "event", "treasure", "shrine"]
	if current_room_type not in valid_types:
		push_warning("[GameContext] Unknown room type '%s', defaulting to combat" % current_room_type)
		current_room_type = "combat"


func get_room_type_display_name(room_type: String) -> String:
	match room_type:
		"combat": return "Fight"
		"elite": return "Hard Fight"
		"event": return "Choice"
		"treasure": return "Loot"
		"shrine": return "Buff"
		_: return room_type.capitalize()


func is_combat_room_type() -> bool:
	return current_room_type == "combat" or current_room_type == "elite"


func prepare_room_event_payload() -> void:
	current_room_payload = {
		"type": current_room_type,
		"dungeon_id": current_dungeon_id,
		"floor": current_floor,
		"room": current_room_index + 1  # 1-based for display
	}


# ============================================================================
# ROOM CHOICE SYSTEM (1-3 independent options per room)
# ============================================================================

# Per-floor event and elite independent roll chances.
# Key = floor number (1-indexed). Floors beyond max key use the max key's values.
const FLOOR_ROOM_CHANCES: Dictionary = {
	1: {"event": 0.50, "elite": 0.25},
	2: {"event": 0.40, "elite": 0.30},
	3: {"event": 0.30, "elite": 0.35},
	4: {"event": 0.25, "elite": 0.40},
}


## Get event/elite chances for a floor, clamping to max defined floor.
func _get_floor_chances(floor_num: int) -> Dictionary:
	var max_key: int = 4
	var clamped: int = clampi(floor_num, 1, max_key)
	return FLOOR_ROOM_CHANCES.get(clamped, {"event": 0.25, "elite": 0.40})


## Generate dynamic rooms_per_floor using dungeon's min/max.
## Called when entering dungeon.
func generate_rooms_per_floor(rng: RandomNumberGenerator) -> int:
	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	if dungeon == null:
		return 3  # Default fallback

	var min_r = dungeon.min_rooms_per_floor if dungeon.min_rooms_per_floor > 0 else 3
	var max_r = dungeon.max_rooms_per_floor if dungeon.max_rooms_per_floor > 0 else 5
	max_r = maxi(max_r, min_r)  # Ensure max >= min

	if min_r == max_r:
		return min_r

	return rng.randi_range(min_r, max_r)


## Roll independent room choices for the current floor.
## Returns an Array of choice Dictionaries: always includes Combat,
## plus Event and/or Elite if their independent rolls succeed.
func _roll_room_choices(rng: RandomNumberGenerator, floor_num: int) -> Array:
	var choices: Array = []

	# Combat is ALWAYS present
	choices.append({
		"type": "combat",
		"is_elite": false,
		"is_boss": false,
		"forced_elite": false,
		"forced_boss": false,
		"display": "Combat"
	})

	var chances: Dictionary = _get_floor_chances(floor_num)

	# Independent event roll (skip if last room was event — no consecutive events)
	if not _last_room_was_event:
		var event_roll: float = rng.randf()
		if event_roll < chances.get("event", 0.0):
			choices.append({
				"type": "event",
				"is_elite": false,
				"is_boss": false,
				"forced_elite": false,
				"forced_boss": false,
				"display": "Event"
			})

	# Independent elite roll
	var elite_roll: float = rng.randf()
	if elite_roll < chances.get("elite", 0.0):
		choices.append({
			"type": "combat",
			"is_elite": true,
			"is_boss": false,
			"forced_elite": false,
			"forced_boss": false,
			"display": "Elite Combat"
		})

	return choices


## Generate room choices for camp display.
## Choices are for the NEXT room (current_room_index + 1).
## Rules:
##   - If not in dungeon -> return empty
##   - If currently on last room of floor -> set "descend" mode (no room choices)
##   - Combat always present as an option
##   - Event and Elite are independent rolls per floor (FLOOR_ROOM_CHANCES)
##   - No 2 events in a row: if _last_room_was_event, skip event roll
##   - Last room of non-final floor: normal rolls (same as any other room)
##   - Final floor + last room: forced_boss=true (only one option)
func generate_pending_room_choices(rng: RandomNumberGenerator) -> void:
	# Not in dungeon -> return empty
	if current_dungeon_id == "":
		pending_room_choices = {}
		return

	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count: int = dungeon.floor_count if dungeon != null else 4

	# If currently on last room of floor -> no room choices, show descend
	if is_last_room_on_floor():
		var is_final_floor: bool = current_floor >= floor_count
		pending_room_choices = {
			"mode": "descend",
			"is_final_floor": is_final_floor
		}
		print("[Choices] End of floor %d/%d - descend mode (final=%s)" % [
			current_floor, floor_count, str(is_final_floor)
		])
		return

	# Calculate what the NEXT room will be
	var next_room_index: int = current_room_index + 1
	var next_is_last_room_on_floor: bool = (next_room_index >= rooms_per_floor - 1)
	var next_is_boss_room: bool = (current_floor >= floor_count) and next_is_last_room_on_floor

	# Forced scenarios: single-option rooms
	if next_is_boss_room:
		pending_room_choices = {
			"mode": "choose",
			"choices": [{
				"type": "combat",
				"is_elite": false,
				"is_boss": false,
				"forced_elite": false,
				"forced_boss": true,
				"display": "Boss"
			}]
		}
		print("[Choices] next_room=%d/%d floor=%d/%d -> FORCED BOSS" % [
			next_room_index + 1, rooms_per_floor, current_floor, floor_count
		])
		return

	# Normal room: independent rolls for event and elite
	var choices: Array = _roll_room_choices(rng, current_floor)

	pending_room_choices = {
		"mode": "choose",
		"choices": choices
	}

	var displays: Array = []
	for c in choices:
		displays.append(c.get("display", "?"))
	print("[Choices] next_room=%d/%d floor=%d/%d options=[%s]%s" % [
		next_room_index + 1, rooms_per_floor, current_floor, floor_count,
		", ".join(displays),
		" (no-event-streak)" if _last_room_was_event else ""
	])


## Get the current pending room choices for UI display.
func get_pending_room_choices() -> Dictionary:
	return pending_room_choices


## Set which choice the player selected.
func set_next_room_choice(choice: Dictionary) -> void:
	pending_selected_choice = choice.duplicate()
	print("[GameContext] Player selected: %s (elite=%s forced_elite=%s forced_boss=%s)" % [
		choice.get("display", "?"),
		str(choice.get("is_elite", false)),
		str(choice.get("forced_elite", false)),
		str(choice.get("forced_boss", false))
	])


## Consume the selected choice and apply to current room state.
## Returns the choice that was consumed.
func consume_next_room_choice() -> Dictionary:
	var choice = pending_selected_choice.duplicate()
	if choice.is_empty():
		# Default to combat if no choice set
		choice = { "type": "combat", "is_elite": false, "is_boss": false, "display": "Combat" }

	# Apply to current room state
	current_room_type = choice.get("type", "combat")

	# Elite status: either explicit is_elite=true OR forced_elite=true
	# Boss takes priority: if forced_boss, treat as boss encounter (not elite)
	var is_forced_boss = choice.get("forced_boss", false)
	var is_forced_elite = choice.get("forced_elite", false)
	var is_explicit_elite = choice.get("is_elite", false)

	# Boss overrides elite; otherwise elite if explicit or forced
	if is_forced_boss:
		current_room_is_elite = false  # Boss is not "elite", it's boss
	else:
		current_room_is_elite = is_explicit_elite or is_forced_elite

	# Track if this room is an event (for no-consecutive-events rule)
	_last_room_was_event = (current_room_type == "event")

	# Clear pending
	pending_selected_choice = {}
	pending_room_choices = {}

	print("[GameContext] Consumed room choice: type=%s elite=%s forced_elite=%s forced_boss=%s last_was_event=%s" % [
		current_room_type,
		str(current_room_is_elite),
		str(is_forced_elite),
		str(is_forced_boss),
		str(_last_room_was_event)
	])
	return choice


## Check if we're on Room 1 (first room, no choice - always combat).
func is_first_room_of_floor() -> bool:
	return current_room_index == 0


## Get current room elite status.
func is_current_room_elite() -> bool:
	return current_room_is_elite


# Floor-scoped guard to prevent duplicate rewards on same floor
var _rewarded_dungeon_id: String = ""
var _rewarded_floor: int = -1

# RNG for deterministic reward rolls (set by CombatController)
var _reward_rng: RandomNumberGenerator = null


func set_reward_rng(rng: RandomNumberGenerator) -> void:
	_reward_rng = rng


func apply_dungeon_floor_reward() -> void:
	# Only apply if in a dungeon run
	if current_dungeon_id == "" or current_floor <= 0:
		return
	# Guard: already rewarded this floor in this dungeon
	if _rewarded_dungeon_id == current_dungeon_id and _rewarded_floor == current_floor:
		return

	# Mark as rewarded
	_rewarded_dungeon_id = current_dungeon_id
	_rewarded_floor = current_floor

	# Determine if boss floor
	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var max_floor = dungeon.floor_count if dungeon != null else 4
	var is_boss = current_floor >= max_floor

	# Calculate bonus gold - goes to dungeon stash (provisional)
	var bonus_gold = 25 if is_boss else (5 * current_floor)
	dungeon_gold += bonus_gold

	# Boss loot bonus: 1 extra roll from boss monster's loot table
	var bonus_items = 0
	if is_boss and dungeon != null and _reward_rng != null:
		var boss_monster = DataRegistry.get_monster(dungeon.boss_id) if dungeon.boss_id != "" else null
		if boss_monster != null and boss_monster.loot_table_id != "":
			var loot_table = DataRegistry.get_loot_table(boss_monster.loot_table_id)
			if loot_table != null:
				var loot = SeededRNG.roll_loot_table(loot_table, _reward_rng)
				for drop in loot:
					if drop.get("item_id", "") != "":
						dungeon_items.append(drop)
						bonus_items += 1

	print("[DungeonReward] floor=%d/%d boss=%s bonus_gold=%d bonus_items=%d (to dungeon stash)" % [
		current_floor, max_floor, str(is_boss), bonus_gold, bonus_items
	])


## Apply dungeon floor reward using SNAPSHOT values from encounter start.
## This prevents mid-combat floor changes from affecting boss reward eligibility.
func apply_dungeon_floor_reward_snapshot(
	snap_dungeon_id: String,
	snap_floor: int,
	snap_floor_count: int,
	snap_is_boss: bool,
	snap_boss_id: String,
	rng: RandomNumberGenerator
) -> void:
	# Only apply if in a valid dungeon encounter
	if snap_dungeon_id == "" or snap_floor <= 0:
		return
	# Guard: already rewarded this floor in this dungeon
	if _rewarded_dungeon_id == snap_dungeon_id and _rewarded_floor == snap_floor:
		return

	# Mark as rewarded using snapshot values
	_rewarded_dungeon_id = snap_dungeon_id
	_rewarded_floor = snap_floor

	# Calculate bonus gold using snapshot - goes to dungeon stash (provisional)
	var bonus_gold = 25 if snap_is_boss else (5 * snap_floor)
	dungeon_gold += bonus_gold

	# Boss loot bonus: only if encounter was actually a boss encounter
	var bonus_items = 0
	if snap_is_boss and snap_boss_id != "" and rng != null:
		var boss_monster = DataRegistry.get_monster(snap_boss_id)
		if boss_monster != null and boss_monster.loot_table_id != "":
			var loot_table = DataRegistry.get_loot_table(boss_monster.loot_table_id)
			if loot_table != null:
				var loot = SeededRNG.roll_loot_table(loot_table, rng)
				for drop in loot:
					if drop.get("item_id", "") != "":
						dungeon_items.append(drop)
						bonus_items += 1

	print("[DungeonReward] floor=%d/%d boss=%s bonus_gold=%d bonus_items=%d (to dungeon stash)" % [
		snap_floor, snap_floor_count, str(snap_is_boss), bonus_gold, bonus_items
	])


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
		"dungeon_id": current_dungeon_id,
		"floor": current_floor,
		"room_index": current_room_index,
		"rooms_per_floor": rooms_per_floor,
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
		GamePhase.DUNGEON_CAMP: return "DUNGEON_CAMP"
		GamePhase.ROOM_EVENT: return "ROOM_EVENT"
		GamePhase.REWARDS: return "REWARDS"
		GamePhase.RETURN_TO_TOWN: return "RETURN_TO_TOWN"
		GamePhase.TOWN_HUB: return "TOWN_HUB"
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
	set_location("region_1", "town_thornhaven")
	if _current_region_id == "region_1" and _current_town_id == "town_thornhaven":
		print("[PASS] Location set: region_1 / town_thornhaven")
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


# ============================================================================
# GLOBAL INPUT (Fullscreen Toggle)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
				window_scale = 0
			else:
				window_scale = 1
			apply_window_scale()
			save_game()
