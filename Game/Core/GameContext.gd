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

# DEPRECATED (v1.2): Loot routing preference - kept for save compatibility only, not used.
# Manual-only routing now; no auto-assign or remember preference.
var loot_pref: Dictionary = {}

# ============================================================================
# GROUP UNLOCKS (persistent, controls what Shop can sell)
# ============================================================================

# Tracks which unlock_groups have been unlocked for purchase in shops
# { "group_id": true, ... }
var unlocked_groups: Dictionary = {}

# Tracks which tutorials have been shown to the player
# { "tutorial_id": true, ... }
var completed_tutorials: Dictionary = {}

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

# Default recipes unlocked on fresh save (basic starter items)
const DEFAULT_UNLOCKED_RECIPES: Dictionary = {
	"healing_tonic": { "source_facility": "alchemist", "facility_tier": 1, "upgrade_tier": 1, "output_id": "healing_tonic" },
	"rusty_sword:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "rusty_sword" },
	"wooden_shield:t1": { "source_facility": "blacksmith", "facility_tier": 1, "upgrade_tier": 1, "output_id": "wooden_shield" }
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
	"book_mender": "warden",  # Legacy: mender renamed to warden
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

# Tracks refresh count per shop: "shop_id" -> refresh_count (int)
# Used to change shop inventory deterministically on refresh
var shop_refresh_counts: Dictionary = {}

# ============================================================================
# SHOP SLOT ALLOCATION (General Store v2 - Facility-based slots)
# ============================================================================

# Tracks slot allocation per town: { "town_id": { "blacksmith": 2, "leatherworker": 1, ... } }
# Slots determine how many items from each facility appear in the General Store.
var shop_slot_allocations: Dictionary = {}

# Tracks purchased shop slots per shop: { "shop_id": ["facility_id:slot_idx", ...] }
# Used to show empty slots after purchase instead of regenerating items.
var shop_purchased_slots: Dictionary = {}

# Shop tier constants: max total slots available based on shop tier
const SHOP_TIER_MAX_SLOTS: Dictionary = {
	1: 4,   # Tier 1: 4 total slots
	2: 6,   # Tier 2: 6 total slots
	3: 8    # Tier 3: 8 total slots
}

# Facilities that can contribute items to the General Store
const SHOP_CONTRIBUTING_FACILITIES: Array[String] = ["blacksmith", "huntsman", "enchanter", "alchemist"]

# ============================================================================
# PERSISTENCE CONSTANTS
# ============================================================================

const SAVE_FILE_PATH = "user://savegame.json"

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
	_current_town_id = "town_thornhaven"
	_selected_floor_index = 1
	_party_hero_ids = []
	_run_id = ""
	_run_seed = 0
	_run_active = false
	current_region = 1

	# Load saved game data (floor unlocks, selected floors, etc.)
	load_game()


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


## Check if the player can challenge the dungeon boss in a given town.
## Requires at least half of the T4-capable facilities to be at Tier 4.
## Returns { "ready": bool, "current": int, "required": int }
func can_challenge_boss(town_id: String) -> Dictionary:
	var town_data = DataRegistry.get_town(town_id)
	if town_data == null:
		return {"ready": true, "current": 0, "required": 0}

	var t4_capable: int = 0
	var at_t4: int = 0

	for fac_id in town_data.facility_ids:
		var max_tier: int = get_facility_max_tier(fac_id)
		if max_tier >= 4:
			t4_capable += 1
			if get_facility_tier(town_id, fac_id) >= 4:
				at_t4 += 1

	var required: int = ceili(t4_capable / 2.0)
	return {"ready": at_t4 >= required, "current": at_t4, "required": required}


## Strip all equipment and bag items from a hero (used on flee).
func strip_hero_gear(hero_id: String) -> void:
	if hero_equipment.has(hero_id):
		hero_equipment.erase(hero_id)
		print("[Flee] Stripped equipment from hero=%s" % hero_id)
	if hero_bags.has(hero_id):
		hero_bags.erase(hero_id)
		print("[Flee] Stripped bag from hero=%s" % hero_id)


## Strip gear from all surviving heroes in the selected party (used on flee).
## Dead heroes are excluded (they'll be removed by permadeath).
func strip_surviving_heroes_gear() -> void:
	var stripped: int = 0
	for hero_id in selected_party:
		var hp_data = get_hero_hp(hero_id)
		var current_hp: int = int(hp_data.get("current", 1))
		if current_hp > 0:
			strip_hero_gear(hero_id)
			stripped += 1
	print("[Flee] Stripped gear from %d surviving heroes" % stripped)
	save_game()


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


## Add item to run stash.
func add_run_item(item_id: String, qty: int = 1) -> void:
	if item_id == "" or qty <= 0:
		return
	for i in range(qty):
		run_items.append({ "item_id": item_id, "qty": 1 })
	print("[RunStash] +%d %s => %d items total" % [qty, item_id, run_items.size()])


## Remove item from run stash. Returns true if successful.
## Handles both ItemInstance (removes lowest quality first) and Dictionary items.
func remove_run_item(template_id: String, qty: int = 1) -> bool:
	if template_id == "" or qty <= 0:
		return true

	var removed = 0

	# First pass: collect matching ItemInstances sorted by quality (lowest first)
	var instance_indices: Array = []
	for i in range(run_items.size()):
		var item = run_items[i]
		if item is ItemInstance and item.template_id == template_id:
			instance_indices.append({ "index": i, "quality": item.quality_tier, "qty": item.quantity })

	# Sort by quality tier ascending (lowest quality first)
	instance_indices.sort_custom(func(a, b): return a.quality < b.quality)

	# Remove from ItemInstances first (lowest quality)
	var indices_to_remove: Array = []
	for entry in instance_indices:
		if removed >= qty:
			break
		indices_to_remove.append(entry.index)
		removed += entry.qty

	# Remove collected indices in reverse order to preserve indices
	indices_to_remove.sort()
	indices_to_remove.reverse()
	for idx in indices_to_remove:
		if removed > qty:
			# We removed too many from a multi-qty ItemInstance, but for now treat as 1 each
			pass
		run_items.remove_at(idx)

	# Second pass: remove Dictionary items if still needed
	if removed < qty:
		var i = 0
		while i < run_items.size() and removed < qty:
			var item = run_items[i]
			if item is Dictionary and item.get("item_id", "") == template_id:
				run_items.remove_at(i)
				removed += 1
			else:
				i += 1

	if removed < qty:
		print("[RunStash] Wanted to remove %d %s but only found %d" % [qty, template_id, removed])
		return false

	print("[RunStash] -%d %s => %d items total" % [removed, template_id, run_items.size()])
	return true


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
	add_player_item("herb", 5)
	add_player_item("wood_bundle", 3)
	add_player_item("iron_scrap", 3)
	add_player_gold(50)
	print("[Facility][Debug] Gave test items: herb x5, wood x3, iron_scrap x3, +50 gold")


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
## Returns an array of ability_id strings (max 2).
func get_hero_equipment_ability_ids(hero_id: String) -> Array:
	var ids: Array = []
	var equip = get_hero_equipment(hero_id)
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var eid = slot_data.get("id", "")
		if eid != "":
			var template = DataRegistry.get_item_template(eid)
			if template != null and template.ability_id != "":
				ids.append(template.ability_id)
	return ids


## Equip an item from run stash into the given slot for a specific hero.
## Returns true if successful, false if item cannot be equipped.
## Removes item from run stash on success.
func equip_hero_item(hero_id: String, slot: String, item_id: String) -> bool:
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

	# Find quality tier and affix data of item being equipped (first match)
	var quality_tier = 0
	var equip_affix_data: Dictionary = {}
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
			break

	# Remove from run stash
	if not remove_run_item(item_id, 1):
		print("[Equip] hero=%s slot=%s item=%s failed reason=stash_remove_failed" % [hero_id, slot, item_id])
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
	var result = { "health": 0, "attack": 0, "defense": 0, "speed": 0 }
	var region_bonus: float = get_completed_region_count() * 0.1

	var equip = get_hero_equipment(hero_id)

	# Iterate over all 7 equipment slots (not bag - it doesn't give combat stats)
	for slot in EQUIPMENT_SLOTS:
		var slot_data = equip.get(slot, {})
		var item_id = slot_data.get("id", "")
		var quality = int(slot_data.get("quality", 0))
		if item_id != "":
			var template = DataRegistry.get_item_template(item_id)
			if template != null:
				var bonuses = template.get_stat_bonuses_with_quality(quality, region_bonus)
				for stat_key in bonuses:
					if result.has(stat_key):
						result[stat_key] += bonuses[stat_key]
			# Add affix stat bonuses (G7)
			var affix_stats_val = slot_data.get("affix_stats", {})
			if affix_stats_val is Dictionary:
				for affix_key in affix_stats_val:
					if result.has(affix_key):
						result[affix_key] += int(affix_stats_val[affix_key])

	return result


## DEPRECATED: Legacy _get_equipment_stat_bonuses (for backwards compatibility)
func _get_equipment_stat_bonuses() -> Dictionary:
	var result = { "health": 0, "attack": 0, "defense": 0, "speed": 0 }
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
## v1.3: ALL item types allowed. NO STACKING — each slot holds exactly 1 item.
func can_add_to_hero_bag(hero_id: String, item_id: String, _qty: int = 1) -> bool:
	if hero_id == "" or item_id == "":
		return false
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return false
	# v1.3: No category restriction — ALL items allowed
	# v1.3: No stacking — each item needs its own slot
	var bag = get_hero_bag(hero_id)
	var used = bag.size()
	var cap = get_hero_bag_capacity(hero_id)
	return used < cap

## Add a single item to a hero's bag. Returns true if successful.
## v1.3: ALL item types allowed. NO STACKING — always creates new entry with qty=1.
## v2: Optional affix_data dict with keys: source_region, affix_id, affix_stats, affix_prefix
func add_item_to_hero_bag(hero_id: String, item_id: String, qty: int = 1, quality: int = 0, affix_data: Dictionary = {}) -> bool:
	# v1.3: Add each unit as separate entry (no stacking in dungeon bags)
	for _i in range(qty):
		if not can_add_to_hero_bag(hero_id, item_id, 1):
			return false
		# Ensure bag array exists
		if not hero_bags.has(hero_id):
			hero_bags[hero_id] = []
		# v1.3: Always append new entry (no merging)
		var entry: Dictionary = { "item_id": item_id, "qty": 1, "quality_tier": quality }
		if affix_data.get("affix_id", "") != "":
			entry["source_region"] = affix_data.get("source_region", "")
			entry["affix_id"] = affix_data.get("affix_id", "")
			entry["affix_stats"] = affix_data.get("affix_stats", {})
			entry["affix_prefix"] = affix_data.get("affix_prefix", "")
		hero_bags[hero_id].append(entry)
		var used = _get_hero_bag_used(hero_id)
		var cap = get_hero_bag_capacity(hero_id)
		print("[HeroBag] +1 %s hero=%s bag=%d/%d" % [item_id, hero_id, used, cap])
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
		# In town: route to run_items (banked stash) — stash CAN stack
		var stash_entry: Dictionary = {"item_id": item_id, "qty": qty, "quality_tier": quality}
		if affix_data.get("affix_id", "") != "":
			stash_entry["source_region"] = affix_data.get("source_region", "")
			stash_entry["affix_id"] = affix_data.get("affix_id", "")
			stash_entry["affix_stats"] = affix_data.get("affix_stats", {})
			stash_entry["affix_prefix"] = affix_data.get("affix_prefix", "")
		run_items.append(stash_entry)
		_pending_acquisitions.remove_at(index)
		print("[Acquire] resolved to=stash item=%s qty=%d q=%d" % [item_id, qty, quality])
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
## Allowed: consumables + materials. NOT gear/equipment.
## Capacity measured by stacks (each unique item_id+quality = 1 stack).
## Check if an item can be added to the shopkeeper bag.
## v1.3: ALL item types allowed. NO STACKING — each slot holds exactly 1 item.
func can_add_to_shopkeeper_bag(item_id: String, _qty: int = 1, _quality: int = 0) -> bool:
	if item_id == "":
		return false
	var tpl = DataRegistry.get_item_template(item_id)
	if tpl == null:
		return false
	# v1.3: No category restriction — ALL items allowed
	# v1.3: No stacking — each item needs its own slot
	return _get_shopkeeper_bag_stacks() < get_shopkeeper_bag_capacity()

## Add a single item to the shopkeeper bag.
## v1.3: ALL item types allowed. NO STACKING — always creates new entry with qty=1.
## v2: Optional affix_data dict with keys: source_region, affix_id, affix_stats, affix_prefix
func add_item_to_shopkeeper_bag(item_id: String, qty: int = 1, quality: int = 0, source: String = "loot", affix_data: Dictionary = {}) -> bool:
	# v1.3: Add each unit as separate entry (no stacking in dungeon bags)
	for _i in range(qty):
		if not can_add_to_shopkeeper_bag(item_id, 1, quality):
			print("[ShopBag] reject item=%s reason=full" % item_id)
			return false
		# v1.3: Always append new entry (no merging)
		var entry: Dictionary = {"item_id": item_id, "qty": 1, "quality_tier": quality}
		if affix_data.get("affix_id", "") != "":
			entry["source_region"] = affix_data.get("source_region", "")
			entry["affix_id"] = affix_data.get("affix_id", "")
			entry["affix_stats"] = affix_data.get("affix_stats", {})
			entry["affix_prefix"] = affix_data.get("affix_prefix", "")
		shopkeeper_bag.append(entry)
		print("[ShopBag] add item=%s qty=1 q=%d slots=%d/%d source=%s" % [item_id, quality, _get_shopkeeper_bag_stacks(), get_shopkeeper_bag_capacity(), source])
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


## Recruit a new hero of the given class. Costs run stash gold.
## Returns the new hero's ID on success, empty string on failure.
## Optional race_id defaults to "human", optional level defaults to 1.
func recruit_hero(class_id: String, cost_gold: int, race_id: String = "human", level: int = 1) -> String:
	if class_id == "":
		print("[Inn] recruit failed reason=no_class_id")
		return ""

	if run_gold < cost_gold:
		print("[Inn] recruit failed class=%s cost=%d reason=insufficient_gold have=%d" % [class_id, cost_gold, run_gold])
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
		"name": "Hero #%d" % _hero_id_counter,
		"level": level,
		"xp": 0,
		"portrait_path": _pick_race_portrait(race_id)
	}
	owned_heroes.append(hero)

	print("[Inn] recruit class=%s race=%s level=%d xp=0 cost=%d success=true hero_id=%s" % [class_id, race_id, level, cost_gold, hero_id])
	save_game()
	return hero_id


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

	selected_party.append(hero_id)
	print("[Inn] add_to_party hero=%s party=%s" % [hero_id, str(selected_party)])
	party_changed.emit(selected_party)
	save_game()
	return true


## Remove a hero from the party.
func remove_from_party(hero_id: String) -> bool:
	var idx = selected_party.find(hero_id)
	if idx == -1:
		return false
	selected_party.remove_at(idx)
	print("[Inn] remove_from_party hero=%s party=%s" % [hero_id, str(selected_party)])
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
		"name": "Hero #%d" % _hero_id_counter,
		"level": level,
		"xp": 0,
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

## Get XP required to reach a target level.
func get_xp_for_level(target_level: int) -> int:
	if target_level < 1 or target_level > MAX_HERO_LEVEL:
		return 0
	return XP_THRESHOLDS[target_level - 1]

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

			# Apply race XP modifier
			var race_id = hero.get("race_id", "human")
			var race_data = DataRegistry.get_race(race_id)
			var xp_modifier: float = 1.0
			if race_data != null:
				xp_modifier = race_data.xp_modifier

			var modified_xp = int(xp_amount * xp_modifier)
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
			else:
				print("[XP] hero=%s gained=%d (mod=%.2f) total_xp=%d level=%d (no level up)" % [
					hero_id, modified_xp, xp_modifier, new_xp, old_level
				])

			save_game()
			return levels_gained

	print("[XP] hero=%s not found" % hero_id)
	return 0

## Grant XP to all heroes in the selected party with race modifier applied.
## source: describes XP source (e.g. "combat_normal", "combat_elite", "event")
## Returns dictionary of hero_id -> levels_gained.
func grant_party_xp(xp_amount: int, source: String = "unknown") -> Dictionary:
	var result: Dictionary = {}
	print("[XP] party_gain source=%s base=%d party=%d" % [source, xp_amount, selected_party.size()])

	for hero_id in selected_party:
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

	return {
		"health": health,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"level": level,
		"class_id": class_id,
		"race_id": race_id,
		"name": hero_name,
		"gear_bonus": gear_bonus,
		"equip_ability_ids": equip_abilities
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

## Get shop refresh count for a specific shop.
func get_shop_refresh_count(shop_id: String) -> int:
	return shop_refresh_counts.get(shop_id, 0)


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


## Spend gold and refresh the shop inventory.
## Returns true if successful, false if insufficient gold.
func spend_shop_refresh(shop_id: String) -> bool:
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

	# Increment refresh count
	var current = get_shop_refresh_count(shop_id)
	var new_count = current + 1
	shop_refresh_counts[shop_id] = new_count

	print("[ShopRNG] refresh_pressed shop=%s cost=%d success=true gold_before=%d gold_after=%d" % [
		shop_id, cost, gold_before, gold_after
	])

	save_game()
	return true


## Increment shop refresh count to change inventory (legacy - use spend_shop_refresh instead).
func increment_shop_refresh(shop_id: String) -> int:
	var current = get_shop_refresh_count(shop_id)
	var new_count = current + 1
	shop_refresh_counts[shop_id] = new_count
	# Clear purchased slots on refresh since new items are generated
	shop_purchased_slots[shop_id] = []
	print("[ShopRNG] refresh_pressed shop=%s new_refresh=%d (legacy call)" % [shop_id, new_count])
	save_game()
	return new_count


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
	var shop_tier = get_facility_tier(town_id, "shop_thornhaven")  # General Store facility ID
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
	return template.use_effect in ["heal", "heal_small", "heal_large"]

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
		"heal", "heal_small", "heal_large":
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
## Clamps to 1..4 (dungeons have 4 floors max).
func unlock_floor(dungeon_id: String, floor_num: int) -> void:
	if dungeon_id == "":
		return
	floor_num = clampi(floor_num, 1, 4)
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
	return result


## Save game data to user://savegame.json.
## Saves: unlocked_dungeon_floors, selected_start_floors, equipment, unlocked_groups, facility_tiers, town_tiers, heroes, housing
func save_game() -> void:
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
		"housing_upgrades": housing_upgrades,
		"bonus_stash_capacity": bonus_stash_capacity,
		"shop_refresh_counts": shop_refresh_counts,
		"shop_purchased_slots": shop_purchased_slots,
		"shop_slot_allocations": shop_slot_allocations,
		# Player gold (town persistent)
		"player_gold": player_gold,
		# Run stash (banked gold persists across sessions)
		"run_gold": run_gold,
		"run_items": _serialize_run_items(run_items),
		# Shopkeeper bag (v5)
		"shopkeeper_bag": shopkeeper_bag,
		# Loot routing preferences (v5)
		"loot_pref": loot_pref,
		# Region progression
		"current_region": current_region,
		"completed_tutorials": completed_tutorials,
		"completed_regions": completed_regions,
		"region_id": _current_region_id,
		"town_id": _current_town_id,
		# Dead heroes (Permadeath / Book of the Dead)
		"dead_heroes": dead_heroes,
		# Mixing system (discovery + mishaps)
		"discovered_mixes": discovered_mixes,
		"alchemist_mishap_streak": alchemist_mishap_streak,
		"locked_facilities": locked_facilities,
		"inn_lockout": inn_lockout
	}

	print("[Save] run_items serialized count=%d" % run_items.size())

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		var err = FileAccess.get_open_error()
		push_warning("[GameContext] Failed to open save file for writing: %s (error %d)" % [SAVE_FILE_PATH, err])
		return

	var json_str = JSON.stringify(save_data, "\t")
	file.store_string(json_str)
	file.close()
	print("[GameContext] Game saved to %s" % SAVE_FILE_PATH)


## Reset save game (DEV TOOL ONLY).
## Deletes save file and resets all runtime state to fresh defaults.
## Use for testing saves, migrations, hero systems, etc.
func reset_save_game() -> void:
	print("[Dev] Reset save requested")
	print("[Dev] PRE-RESET: unlocked_groups=%s" % str(unlocked_groups))
	print("[Dev] PRE-RESET: owned_heroes=%d, player_gold=%d" % [owned_heroes.size(), player_gold])

	# Step 1: Delete save file if it exists
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var err = DirAccess.remove_absolute(SAVE_FILE_PATH)
		if err == OK:
			print("[Dev] Deleted %s" % SAVE_FILE_PATH)
		else:
			push_warning("[Dev] Failed to delete save file (error %d)" % err)

	# Step 2: Clear all persistent state
	print("[Dev] Reinitializing GameContext defaults")

	# Player inventory
	player_gold = 400  # Starting gold
	player_items = {}

	# Training buffs
	next_run_bonus_max_hp = 0
	next_run_trained = false

	# Combat modifier
	pending_combat_modifier = {}

	# Equipment (legacy global + per-hero)
	equipped_weapon_id = ""
	equipped_weapon_quality = 0
	equipped_offhand_id = ""
	equipped_offhand_quality = 0
	hero_equipment = {}
	hero_bags = {}
	_gear_logged_heroes.clear()

	# Shopkeeper bag (shared consumables + materials)
	shopkeeper_bag = []

	# Hero combat state (HP, statuses between combats)
	hero_hp = {}
	hero_statuses = {}
	_combat_consumables_used = {}

	# Dead heroes (Permadeath / Book of the Dead)
	dead_heroes = []

	# Deprecated but still exists in save format
	loot_pref = {}

	# Unlock groups and recipes
	unlocked_groups = {}
	unlocked_item_ids = {}
	unlocked_recipes = {}

	# Tutorials
	completed_tutorials = {}

	# Mixing system
	discovered_mixes = {}
	alchemist_mishap_streak = 0
	locked_facilities = {}
	inn_lockout = false

	# Dungeon floor unlocks
	unlocked_dungeon_floors = {}
	selected_start_floors = {}

	# Facility tiers
	facility_tiers = {}

	# Learned classes (legacy)
	learned_classes = {}

	# Town tiers
	town_tiers = {}

	# Heroes
	owned_heroes = []
	selected_party = []
	_hero_id_counter = 0

	# Stash upgrades
	housing_upgrades = {}
	bonus_stash_capacity = 0

	# Shop refresh counts
	shop_refresh_counts = {}

	# Shop purchased slots (empty slots after purchase)
	shop_purchased_slots = {}

	# Shop slot allocations
	shop_slot_allocations = {}

	# Run stash
	run_gold = 400  # Starting gold (town council investment)
	run_items = []

	# Dungeon stash
	dungeon_gold = 0
	dungeon_items = []

	# Dungeon progression
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

	# Run tracking
	_run_id = ""
	_run_seed = 0
	_run_active = false
	_run_counter = 0

	# Phase/location (reset to town)
	_current_phase = GamePhase.TOWN
	_current_region_id = "region_1"
	_current_town_id = "town_thornhaven"
	_selected_floor_index = 1
	_party_hero_ids = []
	current_region = 1
	completed_regions = {}

	# Reward tracking
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1

	# Save the fresh state to disk immediately
	save_game()

	# Log the final state to prove reset worked
	print("[Dev] Save reset complete unlocked_groups=%s facility_tiers=%s town_tiers=%s shop_refresh_counts=%s" % [unlocked_groups, facility_tiers, town_tiers, shop_refresh_counts])
	print("[Dev] Cleared: shopkeeper_bag=%d items, unlocked_recipes=%d, hero_hp=%d, hero_statuses=%d, dead_heroes=%d" % [shopkeeper_bag.size(), unlocked_recipes.size(), hero_hp.size(), hero_statuses.size(), dead_heroes.size()])
	print("[Dev] DEFAULT_UNLOCK_GROUPS (always checked via is_group_unlocked): %s" % str(DEFAULT_UNLOCK_GROUPS))


## Load game data from user://savegame.json.
## If file doesn't exist, uses defaults (no error).
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[GameContext] No save file found, using defaults")
		_ensure_default_unlocks()
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		var err = FileAccess.get_open_error()
		push_warning("[GameContext] Failed to open save file for reading: %s (error %d)" % [SAVE_FILE_PATH, err])
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_warning("[GameContext] Failed to parse save file: %s (error %d at line %d)" % [
			SAVE_FILE_PATH, parse_result, json.get_error_line()
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
		# Tutorials
		if save_data.has("completed_tutorials") and save_data.completed_tutorials is Dictionary:
			completed_tutorials = save_data.completed_tutorials
		# Mixing system
		var discovered_val = save_data.get("discovered_mixes", {})
		discovered_mixes = discovered_val if discovered_val is Dictionary else {}
		alchemist_mishap_streak = int(save_data.get("alchemist_mishap_streak", 0))
		var locked_val = save_data.get("locked_facilities", {})
		locked_facilities = locked_val if locked_val is Dictionary else {}
		inn_lockout = bool(save_data.get("inn_lockout", false))
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
			# Migration: strip unknown keys from hero dicts (e.g., stale "gold" field)
			var _HERO_ALLOWED_KEYS = ["hero_id", "class_id", "race_id", "name", "level", "xp", "portrait_path"]
			for hero in owned_heroes:
				var keys_to_remove: Array = []
				for key in hero.keys():
					if key not in _HERO_ALLOWED_KEYS:
						keys_to_remove.append(key)
				for key in keys_to_remove:
					hero.erase(key)
					print("[Migration] hero %s: stripped unknown key '%s'" % [hero.get("hero_id", "?"), key])
		if save_data.has("selected_party") and save_data.selected_party is Array:
			selected_party = save_data.selected_party
		if save_data.has("hero_id_counter"):
			_hero_id_counter = int(save_data.hero_id_counter)
		# Load hero row assignments (3-Row Formation v1)
		# Missing = empty dict; get_hero_row() returns 1 (Middle) for any missing hero
		if save_data.has("hero_row_assignments") and save_data.hero_row_assignments is Dictionary:
			hero_row_assignments = save_data.hero_row_assignments
		# Load stash upgrades (legacy name "housing_upgrades" kept for compat)
		if save_data.has("housing_upgrades") and save_data.housing_upgrades is Dictionary:
			housing_upgrades = save_data.housing_upgrades
		if save_data.has("bonus_stash_capacity"):
			bonus_stash_capacity = int(save_data.bonus_stash_capacity)
		# Migration: bonus_starting_gold removed - old saves safely ignored
		# Load shop refresh counts
		if save_data.has("shop_refresh_counts") and save_data.shop_refresh_counts is Dictionary:
			shop_refresh_counts = save_data.shop_refresh_counts
		# Load shop purchased slots (empty slots after purchase)
		if save_data.has("shop_purchased_slots") and save_data.shop_purchased_slots is Dictionary:
			shop_purchased_slots = save_data.shop_purchased_slots
		# Load shop slot allocations
		if save_data.has("shop_slot_allocations") and save_data.shop_slot_allocations is Dictionary:
			shop_slot_allocations = save_data.shop_slot_allocations
		# Load player gold (town persistent)
		if save_data.has("player_gold"):
			player_gold = int(save_data.player_gold)
		# Load run stash (banked gold persists across sessions)
		if save_data.has("run_gold"):
			run_gold = int(save_data.run_gold)
		if save_data.has("run_items") and save_data.run_items is Array:
			run_items = _deserialize_run_items(save_data.run_items)
		# Load shopkeeper bag (v5, safe default = empty)
		if save_data.has("shopkeeper_bag") and save_data.shopkeeper_bag is Array:
			shopkeeper_bag = save_data.shopkeeper_bag
		# Load loot routing preferences (v5, safe default = keep current)
		if save_data.has("loot_pref") and save_data.loot_pref is Dictionary:
			for key in save_data.loot_pref:
				loot_pref[key] = save_data.loot_pref[key]
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
			SAVE_FILE_PATH, str(unlocked_dungeon_floors), unlocked_groups.size(),
			facility_tiers.size(), learned_classes.size(), town_tiers.size(), owned_heroes.size(), selected_party.size(), hero_equipment.size(), shop_refresh_counts.size(), run_gold, run_items.size(), current_region, dead_heroes.size()
		])
	else:
		push_warning("[GameContext] Save file data is not a Dictionary")

	# Ensure default unlocks exist and migrate legacy item unlocks to groups
	_ensure_default_unlocks()


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
		run_items.append(it)
	clear_dungeon_stash()
	print("[Extract] Committed dungeon stash to run stash. RunGold=%d RunItems=%d (+%d gold, +%d items)" % [
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
		var item_id = entry.get("item_id", "")
		var qty = int(entry.get("qty", 1))
		var quality = int(entry.get("quality_tier", 0))
		moved_qty += qty
		run_items.append({"item_id": item_id, "qty": qty, "quality_tier": quality})
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
		run_items.append({"item_id": item_id, "qty": qty, "quality_tier": quality})
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
			var item_id = entry.get("item_id", "")
			var template = DataRegistry.get_item_template(item_id)

			# Only keep consumables in hero bags - move everything else to stash
			if template == null or template.item_type != "consumable":
				var qty = int(entry.get("qty", 1))
				var quality = int(entry.get("quality", 0))
				run_items.append({"item_id": item_id, "qty": qty, "quality_tier": quality})
				items_to_remove.append(i)
				total_moved += 1
				print("[Extract] hero=%s banked material=%s to stash" % [hero_id, item_id])

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
	current_dungeon_id = dungeon_id

	# Use selected start floor (defaults to 1 if not set)
	var start_floor = get_selected_start_floor(dungeon_id)
	current_floor = start_floor
	current_room_index = 0
	_rewarded_dungeon_id = ""
	_rewarded_floor = -1

	# Clear dungeon stash for fresh run
	clear_dungeon_stash()

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
	set_phase(GamePhase.TOWN)

	# v1.2: Bank shopkeeper bag to stash on extract
	bank_shopkeeper_bag_to_stash()

	# v1.3: Bank non-consumables from hero bags to stash (only consumables stay)
	bank_hero_materials_to_stash()

	# TownReset: heal all heroes and clear status effects
	apply_town_entry_reset()

	# Refresh shop inventory on dungeon return
	var shop_id = _current_town_id.replace("town_", "shop_")
	increment_shop_refresh(shop_id)
	print("[GameContext] Shop inventory refreshed on dungeon return (shop_id=%s)" % shop_id)

	# Save to persist cleared shopkeeper bag and hero bag changes
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
# 2-CHOICE ROOM SYSTEM
# ============================================================================

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


## Roll what Choice B should be (event or elite combat).
## Returns: { "type": "combat"|"event", "is_elite": bool, "is_boss": bool, "display": String }
func roll_choice_b(rng: RandomNumberGenerator) -> Dictionary:
	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var event_weight = 0.65
	var elite_weight = 0.35

	if dungeon != null:
		event_weight = dungeon.choice_b_event_weight if dungeon.choice_b_event_weight > 0 else 0.65
		elite_weight = dungeon.choice_b_elite_weight if dungeon.choice_b_elite_weight > 0 else 0.35

	# Normalize weights
	var total = event_weight + elite_weight
	if total <= 0:
		total = 1.0
	var event_chance = event_weight / total

	var roll = rng.randf()
	if roll < event_chance:
		return { "type": "event", "is_elite": false, "is_boss": false, "display": "Event" }
	else:
		return { "type": "combat", "is_elite": true, "is_boss": false, "display": "Elite Combat" }


## Generate both room choices for camp display.
## Choices are for the NEXT room (current_room_index + 1).
## Rules:
##   - If not in dungeon -> return empty
##   - If currently on last room of floor -> set "descend" mode (no room choices)
##   - Choice A: ALWAYS labeled "Combat", but includes forced_elite/forced_boss flags
##   - Choice B: Event or Elite (weighted roll), disabled when next is last/boss room
##   - No 2 events in a row: if _last_room_was_event, force B = Elite
##   - Last room of floor: forced_elite=true (actual encounter is Elite)
##   - Final floor + last room: forced_boss=true (Boss overrides Elite)
func generate_pending_room_choices(rng: RandomNumberGenerator) -> void:
	# Not in dungeon -> return empty
	if current_dungeon_id == "":
		pending_room_choices = {}
		return

	var dungeon = DataRegistry.get_dungeon(current_dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4

	# If currently on last room of floor -> no room choices, show descend
	if is_last_room_on_floor():
		var is_final_floor = current_floor >= floor_count
		pending_room_choices = {
			"mode": "descend",
			"is_final_floor": is_final_floor
		}
		print("[Choices] End of floor %d/%d - descend mode (final=%s)" % [
			current_floor, floor_count, str(is_final_floor)
		])
		return

	# Calculate what the NEXT room will be
	var next_room_index = current_room_index + 1
	var next_is_last_room_on_floor = (next_room_index >= rooms_per_floor - 1)
	var next_is_boss_room = (current_floor >= floor_count) and next_is_last_room_on_floor

	# Determine forced flags for Choice A
	var forced_elite = false
	var forced_boss = false
	if next_is_boss_room:
		forced_boss = true  # Boss overrides elite
	elif next_is_last_room_on_floor:
		forced_elite = true  # Last room of floor is elite

	# Choice A: ALWAYS labeled "Combat", but may force elite/boss encounter
	var choice_a = {
		"type": "combat",
		"is_elite": false,
		"is_boss": false,
		"forced_elite": forced_elite,
		"forced_boss": forced_boss,
		"display": "Combat"
	}

	# Choice B: Depends on next room position and event history
	var choice_b: Dictionary
	if next_is_boss_room or next_is_last_room_on_floor:
		# Next room is forced (Boss or Elite) -> B is disabled, mirrors A's actual encounter
		choice_b = {
			"type": "combat",
			"is_elite": false,
			"is_boss": false,
			"forced_elite": forced_elite,
			"forced_boss": forced_boss,
			"display": "Boss" if forced_boss else "Elite Combat",
			"disabled": true
		}
	elif _last_room_was_event:
		# No consecutive events -> force Elite for B
		choice_b = {
			"type": "combat",
			"is_elite": true,
			"is_boss": false,
			"forced_elite": false,
			"forced_boss": false,
			"display": "Elite Combat"
		}
	else:
		# Normal: roll between Event and Elite
		choice_b = roll_choice_b(rng)
		choice_b["forced_elite"] = false
		choice_b["forced_boss"] = false

	pending_room_choices = {
		"mode": "choose",
		"choice_a": choice_a,
		"choice_b": choice_b
	}

	var actual_a = "Boss" if forced_boss else ("Elite" if forced_elite else "Normal")
	print("[Choices] next_room=%d/%d floor=%d/%d A=%s(actual:%s) B=%s%s%s" % [
		next_room_index + 1, rooms_per_floor, current_floor, floor_count,
		choice_a.display, actual_a, choice_b.display,
		" (B disabled)" if choice_b.get("disabled", false) else "",
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
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN
				if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_WINDOWED
			)
