## CombatScene.gd
## Minimal combat UI for M1 visualization.
## Displays party, enemies, combat log, and provides step/auto controls.
##
## Source: M2 UI requirements
## Updated: M2.1 Hardening Pass - Uses clean API only
extends Control

# ============================================================================
# PRELOADS
# ============================================================================

const CombatControllerScript = preload("res://Game/Combat/CombatController.gd")

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var top_bar: Label = $TopBar
@onready var party_panel: VBoxContainer = $MainContent/PartyPanel/UnitList
@onready var enemy_panel: VBoxContainer = $MainContent/EnemyPanel/UnitList
@onready var combat_log: RichTextLabel = $BottomPanel/CombatLog
@onready var step_button: Button = $BottomPanel/ButtonRow/StepButton
@onready var auto_button: Button = $BottomPanel/ButtonRow/AutoButton
@onready var reset_button: Button = $BottomPanel/ButtonRow/ResetButton
@onready var stun_button: Button = $BottomPanel/DemoButtons/StunButton
@onready var doom_button: Button = $BottomPanel/DemoButtons/DoomButton
@onready var dungeon_progress_label: Label = $DungeonProgressLabel
@onready var main_content: HBoxContainer = $MainContent  # v1.9C: Reference for layout adjustment

# ============================================================================
# STATE
# ============================================================================

var _combat_controller: Node = null
var _is_auto_running: bool = false
var _auto_timer: float = 0.0
var _auto_delay: float = 0.5  # Seconds between auto steps
var _scene_transition_pending: bool = false

# Status UI v1.6: Unit display references for targeted refresh
var _unit_displays: Dictionary = {}  # unit_id -> Control (unit display container)

# Status UI v1.7: Direct badge row mapping for efficient refresh (status + buff rows)
# Format: unit_id -> { "status_row": HBoxContainer, "buff_row": HBoxContainer }
var _unit_badge_rows: Dictionary = {}

# Status UI v1.6.4: Icon cache to avoid repeated ResourceLoader lookups
var _status_icon_cache: Dictionary = {}  # ui_icon_path (String) -> Texture2D|null

# ============================================================================
# STATUS UI v1.8: Badge Pooling + Sanity Tracking
# ============================================================================

# Badge pool: reuse badge nodes instead of creating/freeing on every refresh
# Structure: { unit_id: { "status": [Control], "buff": [Control] } }
var _badge_pool: Dictionary = {}

# Sanity tracking: aggregate issues per encounter, emit once
var _sanity_issues: Dictionary = {
	"missing_rows": {},      # unit_id -> count
	"unknown_units": {},     # unit_id -> count
	"bad_icons": {},         # icon_path -> count
	"unknown_ids": {}        # status/buff id -> count
}
var _sanity_report_emitted: bool = false
var _encounter_id: int = 0  # Incremented on each new encounter

# ============================================================================
# STATUS UI v1.9A: COMBAT READABILITY PACK
# ============================================================================

# Active unit highlighting
var _active_unit_id: String = ""
var _highlight_log_emitted: bool = false  # v1.9B.1: Rate-limit debug logs

# Pop text pooling
var _pop_text_pool: Array = []  # Pool of Label nodes
const POP_TEXT_DURATION: float = 1.2  # Seconds to display
const POP_TEXT_RISE: float = 30.0  # Pixels to rise during animation

# Pop text colors by kind
const POP_TEXT_COLORS: Dictionary = {
	"damage": Color.RED,
	"heal": Color.LIME_GREEN,
	"dot": Color.ORANGE_RED,
	"status_apply": Color.YELLOW,
	"status_stack": Color.GOLD,
	"buff_apply": Color.CYAN,
	"miss": Color.GRAY,
	"crit": Color.HOT_PINK
}

# Cast callout styling
const CAST_CALLOUT_DURATION: float = 1.0  # Seconds to display

# ============================================================================
# STATUS UI v1.9B: TURN TIMELINE + INTENT + LOG OVERLAY
# ============================================================================

# Turn timeline
var _timeline_panel: PanelContainer = null  # v1.9B.1: Outer panel with background
var _timeline_container: HBoxContainer = null
const TIMELINE_UNIT_COUNT: int = 6

# Intent display
var _current_intent_label: Label = null

# Log overlay (last N events)
var _log_overlay_container: VBoxContainer = null
var _log_ring_buffer: Array = []  # Ring buffer of log strings
const LOG_OVERLAY_MAX_ENTRIES: int = 8
var _last_dot_unit: String = ""  # Track last DOT unit for combining
var _last_dot_count: int = 0

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[CombatScene] Initializing...")

	# Connect button signals
	step_button.pressed.connect(_on_step_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	stun_button.pressed.connect(demo_apply_stun)
	doom_button.pressed.connect(demo_apply_doom)

	# Start initial encounter
	_start_encounter()


func _process(delta: float) -> void:
	if _is_auto_running and not _combat_controller.is_combat_over():
		_auto_timer += delta
		if _auto_timer >= _auto_delay:
			_auto_timer = 0.0
			_step_turn()


# ============================================================================
# ENCOUNTER SETUP
# ============================================================================

func _start_encounter() -> void:
	_update_dungeon_progress_label()
	print("[CombatScene] Starting new encounter...")

	# Clear previous state
	if _combat_controller != null:
		_combat_controller.queue_free()

	_is_auto_running = false
	_auto_timer = 0.0

	# Update auto button text
	auto_button.text = "Auto"

	# Clear log
	combat_log.clear()
	_log("[b]--- Combat Started ---[/b]")

	# Consume any pending combat modifier from events (one-time use)
	var combat_mod = GameContext.consume_pending_combat_modifier()
	if not combat_mod.is_empty():
		var mod_label = combat_mod.get("label", combat_mod.get("id", "unknown"))
		_log("[color=cyan][Modifier Active: %s][/color]" % mod_label)

	# Create combat controller
	_combat_controller = CombatControllerScript.new()
	add_child(_combat_controller)

	# Connect signals
	_combat_controller.combat_ended.connect(_on_combat_ended)
	_combat_controller.status_changed.connect(_on_status_changed)  # Status UI v1.6
	_combat_controller.all_statuses_ticked.connect(_on_all_statuses_ticked)  # Status UI v1.6
	_combat_controller.turn_started.connect(_on_turn_started)  # v1.9A: Active unit highlight
	_combat_controller.action_performed.connect(_on_action_performed)  # v1.9A: Pop text + cast callout
	_combat_controller.intent_decided.connect(_on_intent_decided)  # v1.9B: Intent surface

	# v1.9B: Initialize timeline and log overlay UI
	_create_v19b_ui()

	# Get RNG from context
	var run_seed = GameContext.get_run_seed() if GameContext.is_run_active() else 12345
	var rng = SeededRNG.create_rng(run_seed)

	# Get selected party from GameContext (recruited heroes)
	var hero_ids = GameContext.get_selected_party()
	if hero_ids.size() == 0:
		# Fallback to legacy hardcoded heroes if no party selected
		hero_ids = ["hero_1", "hero_2"]
		_log("[color=gray](No party selected - using default heroes)[/color]")
	else:
		# Log spawned heroes from selected party
		var hero_names: Array = []
		for hero_id in hero_ids:
			var hero = GameContext.get_hero(hero_id)
			var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id
			var hero_class = hero.get("class_id", "unknown") if not hero.is_empty() else "unknown"
			hero_names.append("%s (%s)" % [hero_name, hero_class])
		print("[Combat] Spawning party: %s" % str(hero_names))

	var encounter_data = _select_floor_enemies(rng)
	var enemy_ids = encounter_data["enemies"]
	_combat_controller.initialize_combat(hero_ids, enemy_ids, rng, combat_mod)

	# Log modifier effects in UI
	_log_combat_modifier(combat_mod)

	# Pass encounter snapshot to CombatController for reward calculation
	_combat_controller.set_encounter_context(
		encounter_data["dungeon_id"],
		encounter_data["floor"],
		encounter_data["floor_count"],
		encounter_data["is_boss"],
		encounter_data["boss_id"]
	)

	var snapshot = _combat_controller.get_units_snapshot()
	_log("Party: %d heroes vs %d enemies" % [
		snapshot["player"].size(),
		snapshot["enemy"].size()
	])
	_log("Turn order established (Round 1)")

	# Refresh UI
	_refresh_all_panels()
	_update_top_bar()


## Log combat modifier effects to the UI combat log.
## Actual modifier application happens in CombatController.initialize_combat().
func _log_combat_modifier(mod: Dictionary) -> void:
	if mod.is_empty():
		return

	# Log player speed bonus
	var player_spd_bonus = mod.get("player_spd_bonus", 0)
	if player_spd_bonus != 0:
		_log("[color=green]Party has +%d speed this combat[/color]" % player_spd_bonus)

	# Log enemy speed bonus
	var enemy_spd_bonus = mod.get("enemy_spd_bonus", 0)
	if enemy_spd_bonus != 0:
		_log("[color=orange]Enemies have +%d speed this combat[/color]" % enemy_spd_bonus)

	# Log player start damage
	var player_start_damage = mod.get("player_start_damage", 0)
	if player_start_damage > 0:
		_log("[color=red]Party takes %d damage from trap![/color]" % player_start_damage)

	# Log bonus gold
	var bonus_gold = mod.get("bonus_gold", 0)
	if bonus_gold > 0:
		_log("[color=yellow]+%d bonus gold from modifier[/color]" % bonus_gold)


## Select enemies based on current dungeon floor using per-floor pools.
## Returns Dictionary with: enemies, dungeon_id, floor, floor_count, is_boss, boss_id
func _select_floor_enemies(rng: RandomNumberGenerator) -> Dictionary:
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var rooms_per_floor = GameContext.get_rooms_per_floor()
	var is_elite = GameContext.is_current_room_elite()

	# Fallback if not in a dungeon
	if dungeon_id == "" or floor_num <= 0:
		print("[Encounter] dungeon= floor=0/0 room=0/1 enemies=[goblin, goblin] boss=false elite=false (fallback)")
		return {
			"enemies": ["goblin", "goblin"],
			"dungeon_id": "",
			"floor": 0,
			"floor_count": 4,
			"is_boss": false,
			"boss_id": ""
		}

	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	if dungeon == null:
		print("[Encounter] dungeon=%s floor=%d/? room=%d/%d enemies=[goblin, goblin] boss=false elite=%s (no data)" % [
			dungeon_id, floor_num, room_idx + 1, rooms_per_floor, str(is_elite)
		])
		return {
			"enemies": ["goblin", "goblin"],
			"dungeon_id": dungeon_id,
			"floor": floor_num,
			"floor_count": 4,
			"is_boss": false,
			"boss_id": ""
		}

	var max_floor = dungeon.floor_count if dungeon.floor_count > 0 else 4
	var floor_index = clampi(floor_num - 1, 0, max_floor - 1)
	# Boss: final floor AND last room on that floor
	var is_boss = (floor_num >= max_floor) and GameContext.is_last_room_on_floor()

	# Boss floor: spawn boss only
	if is_boss and dungeon.boss_id != "":
		print("[Encounter] dungeon=%s floor=%d/%d room=%d/%d enemies=[%s] boss=true elite=false" % [
			dungeon_id, floor_num, max_floor, room_idx + 1, rooms_per_floor, dungeon.boss_id
		])
		return {
			"enemies": [dungeon.boss_id],
			"dungeon_id": dungeon_id,
			"floor": floor_num,
			"floor_count": max_floor,
			"is_boss": true,
			"boss_id": dungeon.boss_id
		}

	# ELITE ENCOUNTER: Use elite pool exclusively
	if is_elite:
		var elite_pool: Array = []
		if floor_index < dungeon.elite_by_floor.size() and dungeon.elite_by_floor[floor_index].size() > 0:
			elite_pool = dungeon.elite_by_floor[floor_index]
		else:
			for m_id in dungeon.elite_monster_ids:
				elite_pool.append(m_id)

		# Elite encounter: spawn 1-2 elite monsters
		var enemies: Array = []
		if elite_pool.size() > 0:
			var count = rng.randi_range(1, 2)  # Elite encounters can have 1-2 elites
			for i in range(count):
				var idx = rng.randi_range(0, elite_pool.size() - 1)
				enemies.append(elite_pool[idx])
		else:
			# Fallback to tier2 if no elites defined
			enemies = ["goblin"]

		print("[Encounter] dungeon=%s floor=%d/%d room=%d/%d enemies=%s boss=false elite=true" % [
			dungeon_id, floor_num, max_floor, room_idx + 1, rooms_per_floor, str(enemies)
		])
		return {
			"enemies": enemies,
			"dungeon_id": dungeon_id,
			"floor": floor_num,
			"floor_count": max_floor,
			"is_boss": false,
			"boss_id": ""
		}

	# NORMAL COMBAT: Get floor-specific pools with fallback to global pools
	var tier1_pool: Array = []
	if floor_index < dungeon.tier1_by_floor.size() and dungeon.tier1_by_floor[floor_index].size() > 0:
		tier1_pool = dungeon.tier1_by_floor[floor_index]
	else:
		for m_id in dungeon.tier1_monster_ids:
			tier1_pool.append(m_id)

	var tier2_pool: Array = []
	if floor_index < dungeon.tier2_by_floor.size() and dungeon.tier2_by_floor[floor_index].size() > 0:
		tier2_pool = dungeon.tier2_by_floor[floor_index]
	else:
		for m_id in dungeon.tier2_monster_ids:
			tier2_pool.append(m_id)

	# Select 2 enemies: 70% tier1, 30% tier2
	var enemies: Array = []
	for i in range(2):
		var roll = rng.randf() * 100.0
		var pool = tier1_pool if roll < 70.0 else tier2_pool
		if pool.is_empty():
			pool = tier1_pool if tier1_pool.size() > 0 else ["goblin"]
		var idx = rng.randi_range(0, pool.size() - 1)
		enemies.append(pool[idx])

	print("[Encounter] dungeon=%s floor=%d/%d room=%d/%d enemies=%s boss=false elite=false" % [
		dungeon_id, floor_num, max_floor, room_idx + 1, rooms_per_floor, str(enemies)
	])
	return {
		"enemies": enemies,
		"dungeon_id": dungeon_id,
		"floor": floor_num,
		"floor_count": max_floor,
		"is_boss": false,
		"boss_id": ""
	}


# ============================================================================
# TURN STEPPING
# ============================================================================

func _step_turn() -> void:
	if _combat_controller.is_combat_over():
		_log("[color=gray]Combat has ended.[/color]")
		return

	# Get turn info before stepping
	var turn_info = _combat_controller.get_turn_info()

	# Check if starting new round
	if turn_info["is_round_complete"]:
		_log("\n[b]--- Round %d ---[/b]" % (turn_info["round"] + 1))

	# Log whose turn it is
	_log("\n[color=yellow]%s's turn[/color]" % turn_info["current_actor_name"])

	# Step one turn and get actions
	var actions = _combat_controller.step_one_turn()

	# Log all actions
	for action in actions:
		_log_action(action)

	# Check if combat ended
	if _combat_controller.is_combat_over():
		var result = _combat_controller.get_result()
		if result != null and result.is_victory:
			_log("\n[b][color=green]*** VICTORY! ***[/color][/b]")
		else:
			_log("\n[b][color=red]*** DEFEAT ***[/color][/b]")
		_is_auto_running = false
		auto_button.text = "Auto"

	# Refresh UI
	_refresh_all_panels()
	_update_top_bar()


func _log_action(action: CombatAction) -> void:
	match action.action_type:
		CombatAction.ActionType.BASIC_ATTACK:
			_log("  Attacks %s for %d damage" % [action.target_name, action.damage_dealt])
		CombatAction.ActionType.WEAPON_ABILITY:
			_log("  [color=cyan]WEAPON ABILITY![/color] → %s for [b]%d[/b] damage" % [
				action.target_name, action.damage_dealt])
		CombatAction.ActionType.SKIP:
			_log("  [color=orange]STUNNED - Cannot act![/color]")
		CombatAction.ActionType.DOOM_TRIGGER:
			_log("  [color=purple]DOOM TRIGGERS for %d damage![/color]" % action.damage_dealt)
		CombatAction.ActionType.DEATH:
			_log("  [color=red]%s defeated![/color]" % action.actor_name)
		_:
			_log("  %s" % action.message)


# ============================================================================
# UI REFRESH
# ============================================================================

func _refresh_all_panels() -> void:
	var snapshot = _combat_controller.get_units_snapshot()
	_unit_displays.clear()  # Status UI v1.6: Clear display references
	_unit_badge_rows.clear()  # Status UI v1.7: Clear badge row references (both status and buff)
	_status_icon_cache.clear()  # Status UI v1.6.4: Reset icon cache

	# Status UI v1.8: Clear badge pools on full panel refresh (free all pooled nodes)
	_clear_badge_pools()

	# Status UI v1.8: Emit sanity report for previous encounter if issues existed
	_emit_sanity_report_if_needed()

	# Status UI v1.8: Reset sanity tracking for new encounter
	_encounter_id += 1
	_sanity_issues = {
		"missing_rows": {},
		"unknown_units": {},
		"bad_icons": {},
		"unknown_ids": {}
	}
	_sanity_report_emitted = false

	_refresh_party_panel(snapshot["player"])
	_refresh_enemy_panel(snapshot["enemy"])


func _refresh_party_panel(units: Array) -> void:
	# Clear existing
	for child in party_panel.get_children():
		child.queue_free()

	# Add unit displays
	for unit_data in units:
		var display = _create_unit_display(unit_data)
		party_panel.add_child(display)
		_unit_displays[unit_data["id"]] = display  # Status UI v1.6: Store reference


func _refresh_enemy_panel(units: Array) -> void:
	# Clear existing
	for child in enemy_panel.get_children():
		child.queue_free()

	# Add unit displays
	for unit_data in units:
		var display = _create_unit_display(unit_data)
		enemy_panel.add_child(display)
		_unit_displays[unit_data["id"]] = display  # Status UI v1.6: Store reference


func _create_unit_display(unit_data: Dictionary) -> Control:
	# v1.9B.1: Wrap in a MarginContainer for robust highlight support
	var wrapper = MarginContainer.new()
	wrapper.name = "UnitWrapper_%s" % unit_data["id"]
	wrapper.add_theme_constant_override("margin_left", 4)
	wrapper.add_theme_constant_override("margin_right", 4)
	wrapper.add_theme_constant_override("margin_top", 4)
	wrapper.add_theme_constant_override("margin_bottom", 4)

	# v1.9B.1: Highlight frame (ColorRect behind content)
	var highlight_frame = ColorRect.new()
	highlight_frame.name = "HighlightFrame"
	highlight_frame.color = Color(1.0, 0.85, 0.0, 0.25)  # Gold tint
	highlight_frame.visible = false
	highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position it to fill the wrapper
	highlight_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight_frame.offset_left = -4
	highlight_frame.offset_right = 4
	highlight_frame.offset_top = -4
	highlight_frame.offset_bottom = 4
	wrapper.add_child(highlight_frame)

	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.name = "UnitContent_%s" % unit_data["id"]

	# Name + Class line
	var name_label = Label.new()
	var alive_color = Color.WHITE if unit_data["is_alive"] else Color.GRAY
	var dead_text = " [DEAD]" if not unit_data["is_alive"] else ""
	var class_suffix = ""
	if unit_data["team"] == "player" and unit_data.get("class_id", "") != "":
		var cls_name = unit_data["class_id"].capitalize()
		var cls_data = DataRegistry.get_class_data(unit_data["class_id"])
		if cls_data != null and cls_data.display_name != "":
			cls_name = cls_data.display_name
		class_suffix = " (%s)" % cls_name
	name_label.text = "%s%s%s" % [unit_data["name"], class_suffix, dead_text]
	name_label.add_theme_color_override("font_color", alive_color)
	container.add_child(name_label)

	# HP bar
	var hp_container = HBoxContainer.new()
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [unit_data["hp"], unit_data["max_hp"]]
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_container.add_child(hp_label)

	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(80, 12)
	hp_bar.max_value = unit_data["max_hp"]
	hp_bar.value = unit_data["hp"]
	hp_bar.show_percentage = false
	hp_container.add_child(hp_bar)
	container.add_child(hp_container)

	# Status UI v1.8: Per-unit status badge row (CombatScene-owned, direct lookup, pooled)
	var unit_id = unit_data["id"]
	var status_badge_row = HBoxContainer.new()
	status_badge_row.name = "StatusBadgeRow"
	status_badge_row.add_theme_constant_override("separation", 4)
	_populate_status_badges(status_badge_row, unit_data.get("active_statuses_v1", []), unit_id)
	container.add_child(status_badge_row)

	# Status UI v1.8: Per-unit buff badge row (pooled)
	var buff_badge_row = HBoxContainer.new()
	buff_badge_row.name = "BuffBadgeRow"
	buff_badge_row.add_theme_constant_override("separation", 4)
	_populate_buff_badges(buff_badge_row, unit_data.get("active_buffs_v1", []), unit_id)
	container.add_child(buff_badge_row)

	# Status UI v1.7: Register both rows in dictionary
	_unit_badge_rows[unit_data["id"]] = {
		"status_row": status_badge_row,
		"buff_row": buff_badge_row
	}

	# Cooldown line (only for player units with weapon ability)
	if unit_data["team"] == "player" and unit_data["weapon_max_cooldown"] > 0:
		var cd_label = Label.new()
		if unit_data["weapon_cooldown"] > 0:
			cd_label.text = "Weapon CD: %d" % unit_data["weapon_cooldown"]
			cd_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			cd_label.text = "Weapon: READY"
			cd_label.add_theme_color_override("font_color", Color.GREEN)
		cd_label.add_theme_font_size_override("font_size", 11)
		container.add_child(cd_label)

	# Items v5: Equipment display for player heroes (use source_id for per-hero equipment)
	if unit_data["team"] == "player":
		var hero_id = unit_data.get("source_id", unit_data["id"])
		var equip_summary = GameContext.get_hero_equipment_summary(hero_id)

		# Weapon line
		var wpn_label = Label.new()
		wpn_label.text = format_gear_slot_label("weapon", equip_summary["weapon_id"], equip_summary["weapon_quality"])
		wpn_label.add_theme_font_size_override("font_size", 10)
		wpn_label.add_theme_color_override("font_color", Color.LIGHT_STEEL_BLUE if equip_summary["weapon_id"] != "" else Color.DIM_GRAY)
		container.add_child(wpn_label)

		# Offhand line
		var off_label = Label.new()
		off_label.text = format_gear_slot_label("offhand", equip_summary["offhand_id"], equip_summary["offhand_quality"])
		off_label.add_theme_font_size_override("font_size", 10)
		off_label.add_theme_color_override("font_color", Color.LIGHT_STEEL_BLUE if equip_summary["offhand_id"] != "" else Color.DIM_GRAY)
		container.add_child(off_label)

		# Gear stat summary line (optional - only if bonuses exist)
		var gear_bonuses = GameContext._get_hero_equipment_stat_bonuses(hero_id)
		var gear_summary = format_gear_stat_summary(gear_bonuses)
		if gear_summary != "":
			var gear_label = Label.new()
			gear_label.text = gear_summary
			gear_label.add_theme_font_size_override("font_size", 10)
			gear_label.add_theme_color_override("font_color", Color.PALE_GREEN)
			container.add_child(gear_label)

	# [DEBUG PANEL] Legacy statuses from StatusRuntime (stun, doom)
	var status_label = Label.new()
	status_label.name = "LegacyStatusDebug"
	status_label.add_theme_font_size_override("font_size", 10)
	var status_parts = []

	for status in unit_data["statuses"]:
		if status["id"] == "stun":
			status_parts.append("[STUN:%d]" % status["duration"])
		elif status["id"] == "doom":
			status_parts.append("[DOOM:%d|t=%d]" % [status["stacks"], status["countdown"]])

	if status_parts.size() > 0:
		status_label.text = "(dbg) " + " ".join(status_parts)
		status_label.add_theme_color_override("font_color", Color.DIM_GRAY)
	else:
		status_label.text = ""

	container.add_child(status_label)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	# v1.9B.1: Add content to wrapper and return wrapper
	wrapper.add_child(container)
	return wrapper


# ============================================================================
# STATUS UI v1.8: UNIFIED BADGE PIPELINE
# ============================================================================

## v1.8: Clear all badge pools and free pooled nodes.
## Called on full panel refresh or encounter end.
func _clear_badge_pools() -> void:
	for unit_id in _badge_pool.keys():
		var unit_pools = _badge_pool[unit_id]
		if unit_pools is Dictionary:
			for kind in ["status", "buff"]:
				if unit_pools.has(kind) and unit_pools[kind] is Array:
					for badge in unit_pools[kind]:
						if is_instance_valid(badge):
							badge.queue_free()
	_badge_pool.clear()


## v1.8: Track a sanity issue for aggregated reporting.
## category: "missing_rows", "unknown_units", "bad_icons", "unknown_ids"
func _track_sanity_issue(category: String, key: String) -> void:
	if not _sanity_issues.has(category):
		_sanity_issues[category] = {}
	if not _sanity_issues[category].has(key):
		_sanity_issues[category][key] = 0
	_sanity_issues[category][key] += 1


## v1.8: Emit aggregated sanity report once per encounter (if issues exist).
func _emit_sanity_report_if_needed() -> void:
	if _sanity_report_emitted:
		return

	var missing_rows = _sanity_issues.get("missing_rows", {}).size()
	var unknown_units = _sanity_issues.get("unknown_units", {}).size()
	var bad_icons = _sanity_issues.get("bad_icons", {}).size()
	var unknown_ids = _sanity_issues.get("unknown_ids", {}).size()

	var total_issues = missing_rows + unknown_units + bad_icons + unknown_ids
	if total_issues == 0:
		return

	# Emit summary line
	print("[UI-SANITY] encounter=%d missing_rows=%d unknown_units=%d bad_icons=%d unknown_ids=%d" % [
		_encounter_id, missing_rows, unknown_units, bad_icons, unknown_ids
	])

	# Emit detail lines only if counts > 0 (limited to first 5 per category)
	if missing_rows > 0:
		var keys = _sanity_issues["missing_rows"].keys().slice(0, 5)
		print("  missing_rows: %s%s" % [str(keys), "..." if missing_rows > 5 else ""])
	if unknown_units > 0:
		var keys = _sanity_issues["unknown_units"].keys().slice(0, 5)
		print("  unknown_units: %s%s" % [str(keys), "..." if unknown_units > 5 else ""])
	if bad_icons > 0:
		var keys = _sanity_issues["bad_icons"].keys().slice(0, 5)
		print("  bad_icons: %s%s" % [str(keys), "..." if bad_icons > 5 else ""])
	if unknown_ids > 0:
		var keys = _sanity_issues["unknown_ids"].keys().slice(0, 5)
		print("  unknown_ids: %s%s" % [str(keys), "..." if unknown_ids > 5 else ""])

	_sanity_report_emitted = true


## v1.8: Build tooltip string for badge (unified for status and buff).
## kind: "status" or "buff"
func _build_badge_tooltip(snapshot: Dictionary, kind: String) -> String:
	if kind == "status":
		var status_id = snapshot.get("id", "unknown")
		var ui_name = snapshot.get("ui_name", "")
		var stacks = snapshot.get("stacks", 1)
		var remaining = snapshot.get("remaining_rounds", 0)
		var tags = snapshot.get("tags", [])

		var display_name = ui_name if ui_name != "" else status_id.capitalize()
		var tags_str = ", ".join(tags) if tags.size() > 0 else "none"

		return "%s (%s)\nStacks: %d  Rounds: %d\nTags: %s" % [
			display_name, status_id, stacks, remaining, tags_str
		]
	else:  # buff
		var source = snapshot.get("source", "unknown")
		var ui_name = snapshot.get("ui_name", source.capitalize())
		var stats = snapshot.get("stats", {})
		var remaining = snapshot.get("remaining_rounds", 0)
		var buff_tags = snapshot.get("buff_tags", [])

		var stats_str = _format_buff_stats_for_tooltip(stats)
		var tooltip = "%s (%s)\nStats: %s\nRounds: %d" % [ui_name, source, stats_str, remaining]

		# Include tags if present
		if buff_tags.size() > 0:
			tooltip += "\nTags: %s" % ", ".join(buff_tags)

		return tooltip


## v1.8: Format badge label text (unified for status and buff).
## kind: "status" or "buff"
func _format_badge_text(snapshot: Dictionary, kind: String) -> String:
	if kind == "status":
		var short = snapshot.get("ui_short", "???")
		var stacks = snapshot.get("stacks", 1)
		var remaining = snapshot.get("remaining_rounds", 0)

		if stacks > 1:
			return "%s x%d (%d)" % [short, stacks, remaining]
		else:
			return "%s (%d)" % [short, remaining]
	else:  # buff
		var ui_short = snapshot.get("ui_short", "BUFF")
		var remaining = snapshot.get("remaining_rounds", 0)
		return "%s (%d)" % [ui_short, remaining]


## v1.8: Determine badge color based on type and tags.
func _get_badge_color(snapshot: Dictionary, kind: String) -> Color:
	if kind == "status":
		var tags = snapshot.get("tags", [])
		if "control" in tags:
			return Color.CYAN
		elif "dot" in tags:
			return Color.ORANGE_RED
		return Color.YELLOW
	else:  # buff
		return Color.LIME_GREEN


## v1.8: Create or update a badge control (unified for status and buff).
## If existing_badge is provided and valid, updates it in-place for pooling.
## Returns the badge Control.
func _create_or_update_badge(snapshot: Dictionary, kind: String, existing_badge: Control = null) -> Control:
	var tooltip = _build_badge_tooltip(snapshot, kind)
	var badge_text = _format_badge_text(snapshot, kind)
	var badge_color = _get_badge_color(snapshot, kind)

	# Get icon path
	var ui_icon = snapshot.get("ui_icon", "")
	var icon_texture: Texture2D = _resolve_status_icon(ui_icon)

	# Track bad icon paths (v1.8 sanity)
	if ui_icon != "" and icon_texture == null:
		_track_sanity_issue("bad_icons", ui_icon)

	# Track unknown IDs (missing ui_short is a sign of unknown id)
	if kind == "status" and snapshot.get("ui_short", "") == "":
		_track_sanity_issue("unknown_ids", snapshot.get("id", "unknown"))
	elif kind == "buff" and snapshot.get("ui_short", "") == "" and snapshot.get("ui_name", "") == "":
		_track_sanity_issue("unknown_ids", snapshot.get("source", "unknown"))

	# Try to reuse existing badge if compatible structure
	if existing_badge != null and is_instance_valid(existing_badge):
		if icon_texture != null and existing_badge is HBoxContainer:
			# Update existing icon+text badge
			var children = existing_badge.get_children()
			if children.size() >= 2:
				if children[0] is TextureRect:
					children[0].texture = icon_texture
				if children[1] is Label:
					children[1].text = badge_text
					children[1].add_theme_color_override("font_color", badge_color)
				existing_badge.tooltip_text = tooltip
				existing_badge.visible = true
				return existing_badge
		elif icon_texture == null and existing_badge is Label:
			# Update existing text-only badge
			existing_badge.text = badge_text
			existing_badge.add_theme_color_override("font_color", badge_color)
			existing_badge.tooltip_text = tooltip
			existing_badge.visible = true
			return existing_badge

	# Create new badge
	var badge: Control
	if icon_texture != null:
		# Icon + text badge
		var container = HBoxContainer.new()
		container.add_theme_constant_override("separation", 2)

		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		container.add_child(icon_rect)

		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", badge_color)
		container.add_child(label)

		container.tooltip_text = tooltip
		badge = container
	else:
		# Text-only badge (fallback)
		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", badge_color)
		label.tooltip_text = tooltip
		badge = label

	return badge


## v1.8: Get or create badge pool for a unit/kind combo.
func _get_badge_pool(unit_id: String, kind: String) -> Array:
	if not _badge_pool.has(unit_id):
		_badge_pool[unit_id] = {"status": [], "buff": []}
	if not _badge_pool[unit_id].has(kind):
		_badge_pool[unit_id][kind] = []
	return _badge_pool[unit_id][kind]


## v1.8: Unified badge population with pooling support.
## Populates badge_row with badges from snapshots, reusing pooled badges when possible.
## kind: "status" or "buff"
## unit_id: used for pool lookup
func _populate_badges_unified(badge_row: HBoxContainer, snapshots: Array, kind: String, unit_id: String) -> void:
	var pool = _get_badge_pool(unit_id, kind)
	var needed_count = snapshots.size()
	var existing_count = badge_row.get_child_count()

	# Process each snapshot
	for i in range(needed_count):
		var snapshot = snapshots[i]
		var badge: Control

		if i < existing_count:
			# Reuse existing child badge
			var existing = badge_row.get_child(i)
			badge = _create_or_update_badge(snapshot, kind, existing)
			if badge != existing:
				# Structure incompatible, need to replace
				existing.visible = false
				pool.append(existing)  # Return to pool
				badge_row.remove_child(existing)
				badge_row.add_child(badge)
				badge_row.move_child(badge, i)
		elif pool.size() > 0:
			# Pull from pool
			var pooled = pool.pop_back()
			badge = _create_or_update_badge(snapshot, kind, pooled)
			if badge != pooled:
				# Structure incompatible
				pooled.queue_free()
			badge_row.add_child(badge)
		else:
			# Create new badge
			badge = _create_or_update_badge(snapshot, kind, null)
			badge_row.add_child(badge)

	# Hide/return excess badges to pool (don't queue_free - pooling!)
	while badge_row.get_child_count() > needed_count:
		var excess = badge_row.get_child(badge_row.get_child_count() - 1)
		excess.visible = false
		badge_row.remove_child(excess)
		pool.append(excess)


## v1.8: Populate status badges (wrapper for unified pipeline).
func _populate_status_badges(badge_row: HBoxContainer, statuses: Array, unit_id: String = "") -> void:
	_populate_badges_unified(badge_row, statuses, "status", unit_id)


## Status UI v1.6.4: Resolve icon texture from path using cache.
## Returns Texture2D if valid, null otherwise. Caches result for efficiency.
func _resolve_status_icon(ui_icon: String) -> Texture2D:
	# Empty path → null immediately (no cache entry needed)
	if ui_icon == "":
		return null

	# Check cache first
	if _status_icon_cache.has(ui_icon):
		return _status_icon_cache[ui_icon]

	# One-time safe lookup
	var texture: Texture2D = null
	if ResourceLoader.exists(ui_icon):
		var loaded = ResourceLoader.load(ui_icon)
		if loaded is Texture2D:
			texture = loaded

	# Cache result (Texture2D or null) so subsequent lookups are free
	_status_icon_cache[ui_icon] = texture
	return texture


## Items v5: Static helper to format gear slot label for combat UI.
## Returns "WPN: Q1 Iron Sword" or "WPN: none" depending on item.
## Can be tested without scene instantiation.
static func format_gear_slot_label(slot: String, item_id: String, quality: int) -> String:
	var prefix = "WPN" if slot == "weapon" else "OFF"
	if item_id == "":
		return "%s: none" % prefix

	# Get display name from template
	var display_name = item_id.replace("_", " ").capitalize()  # Fallback
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.display_name != "":
		display_name = template.display_name

	return "%s: Q%d %s" % [prefix, quality, display_name]


## Items v5: Format combined gear stat bonus summary for combat UI.
## Returns "Gear: ATK+5 DEF+3" or empty string if no bonuses.
static func format_gear_stat_summary(bonuses: Dictionary) -> String:
	if bonuses.is_empty():
		return ""

	var parts: Array = []
	# Order: HP, ATK, DEF, SPD
	if bonuses.get("health", 0) != 0:
		parts.append("HP+%d" % bonuses["health"])
	if bonuses.get("attack", 0) != 0:
		parts.append("ATK+%d" % bonuses["attack"])
	if bonuses.get("defense", 0) != 0:
		parts.append("DEF+%d" % bonuses["defense"])
	if bonuses.get("speed", 0) != 0:
		parts.append("SPD+%d" % bonuses["speed"])

	if parts.is_empty():
		return ""
	return "Gear: %s" % " ".join(parts)


## Hero Recruit v2.1: Format combat display string for a hero (for testability).
## Returns "Name (Class)" string from unit_data dict.
static func format_hero_combat_label(hero_name: String, class_id: String) -> String:
	if class_id == "":
		return hero_name
	var cls_name = class_id.capitalize()
	var registry = Engine.get_singleton("DataRegistry") if Engine.has_singleton("DataRegistry") else null
	if registry == null:
		# Fallback: try to get from autoload tree
		var tree = Engine.get_main_loop()
		if tree != null and tree is SceneTree:
			var root = tree.root
			if root != null:
				registry = root.get_node_or_null("DataRegistry")
	if registry != null and registry.has_method("get_class_data"):
		var cls_data = registry.get_class_data(class_id)
		if cls_data != null and cls_data.display_name != "":
			cls_name = cls_data.display_name
	return "%s (%s)" % [hero_name, cls_name]


## Status UI v1.7.1: Format buff stats dictionary as human-readable string.
## Maps: attack→ATK, defense→DEF, speed→SPD, health→HP
## Ordering: HP, ATK, DEF, SPD (only include present keys)
## Returns e.g. "ATK +4, SPD +3" or "HP +10, DEF +5"
static func _format_buff_stats_for_tooltip(stats: Dictionary) -> String:
	if stats.is_empty():
		return "none"

	# Stat key mapping and display order
	const STAT_MAP: Dictionary = {
		"health": "HP",
		"attack": "ATK",
		"defense": "DEF",
		"speed": "SPD"
	}
	const STAT_ORDER: Array = ["health", "attack", "defense", "speed"]

	var parts: Array = []
	for key in STAT_ORDER:
		if stats.has(key):
			var value = stats[key]
			var display_key = STAT_MAP.get(key, key.to_upper())
			# Format: "ATK +4" (include sign for positive values)
			if value >= 0:
				parts.append("%s +%d" % [display_key, value])
			else:
				parts.append("%s %d" % [display_key, value])

	# Handle any unknown keys not in STAT_ORDER (append at end, alphabetically)
	var extra_keys: Array = []
	for key in stats.keys():
		if key not in STAT_ORDER:
			extra_keys.append(key)
	extra_keys.sort()
	for key in extra_keys:
		var value = stats[key]
		var display_key = key.to_upper()
		if value >= 0:
			parts.append("%s +%d" % [display_key, value])
		else:
			parts.append("%s %d" % [display_key, value])

	return ", ".join(parts) if parts.size() > 0 else "none"


## v1.8: Populate buff badges (wrapper for unified pipeline).
func _populate_buff_badges(badge_row: HBoxContainer, buffs: Array, unit_id: String = "") -> void:
	_populate_badges_unified(badge_row, buffs, "buff", unit_id)


## Status UI v1.6.3: Static helper to create badge from snapshot dict (for testing).
## Can be called without full scene context.
static func create_status_badge_from_snapshot(status: Dictionary) -> Control:
	var status_id = status.get("id", "unknown")
	var ui_name = status.get("ui_name", "")
	var short = status.get("ui_short", "???")
	var stacks = status.get("stacks", 1)
	var remaining = status.get("remaining_rounds", 0)
	var tags = status.get("tags", [])
	var ui_icon = status.get("ui_icon", "")

	var display_name = ui_name if ui_name != "" else status_id.capitalize()
	var tags_str = ", ".join(tags) if tags.size() > 0 else "none"
	var tooltip = "%s (%s)\nStacks: %d  Rounds: %d\nTags: %s" % [
		display_name, status_id, stacks, remaining, tags_str
	]

	var badge_text: String
	if stacks > 1:
		badge_text = "%s x%d (%d)" % [short, stacks, remaining]
	else:
		badge_text = "%s (%d)" % [short, remaining]

	var badge_color = Color.YELLOW
	if "control" in tags:
		badge_color = Color.CYAN
	elif "dot" in tags:
		badge_color = Color.ORANGE_RED

	# Try icon load (safe fallback)
	var icon_texture: Texture2D = null
	if ui_icon != "" and ResourceLoader.exists(ui_icon):
		var loaded = ResourceLoader.load(ui_icon)
		if loaded is Texture2D:
			icon_texture = loaded

	var badge: Control
	if icon_texture != null:
		var container = HBoxContainer.new()
		container.add_theme_constant_override("separation", 2)
		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		container.add_child(icon_rect)
		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", badge_color)
		container.add_child(label)
		container.tooltip_text = tooltip
		badge = container
	else:
		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", badge_color)
		label.tooltip_text = tooltip
		badge = label

	return badge


## v1.8: Refresh status badges for a specific unit by ID (uses pooling).
## Called when status changes occur (apply/stack/tick/expire).
## Uses direct badge row lookup for efficiency. Tracks sanity issues.
func refresh_unit_status_badges(unit_id: String) -> void:
	# Sanity check - missing badge rows
	if not _unit_badge_rows.has(unit_id):
		_track_sanity_issue("missing_rows", unit_id)
		return

	var rows = _unit_badge_rows[unit_id]
	if not rows is Dictionary or not rows.has("status_row"):
		_track_sanity_issue("missing_rows", unit_id)
		return

	var status_row = rows["status_row"]
	if status_row == null or not is_instance_valid(status_row):
		_track_sanity_issue("missing_rows", unit_id)
		_unit_badge_rows.erase(unit_id)  # Cleanup stale reference
		return

	# Get updated status snapshot from controller (efficient accessor)
	var status_snapshot = _combat_controller.get_unit_status_snapshot_sorted(unit_id)
	_populate_status_badges(status_row, status_snapshot, unit_id)


## v1.8: Refresh all unit status badges (after round tick, uses pooling).
## Iterates over direct badge row mappings for efficiency.
func refresh_all_status_badges() -> void:
	var stale_ids: Array = []

	for unit_id in _unit_badge_rows.keys():
		var rows = _unit_badge_rows[unit_id]
		if not rows is Dictionary or not rows.has("status_row"):
			_track_sanity_issue("missing_rows", unit_id)
			stale_ids.append(unit_id)
			continue

		var status_row = rows["status_row"]
		if status_row == null or not is_instance_valid(status_row):
			_track_sanity_issue("missing_rows", unit_id)
			stale_ids.append(unit_id)
			continue

		var status_snapshot = _combat_controller.get_unit_status_snapshot_sorted(unit_id)
		_populate_status_badges(status_row, status_snapshot, unit_id)

	# Cleanup stale references
	for stale_id in stale_ids:
		_unit_badge_rows.erase(stale_id)


## v1.8: Refresh buff badges for a specific unit by ID (uses pooling).
## Called when buff changes occur (apply/tick/expire).
## Uses direct badge row lookup for efficiency. Tracks sanity issues.
func refresh_unit_buff_badges(unit_id: String) -> void:
	# Sanity check - missing badge rows
	if not _unit_badge_rows.has(unit_id):
		_track_sanity_issue("missing_rows", unit_id)
		return

	var rows = _unit_badge_rows[unit_id]
	if not rows is Dictionary or not rows.has("buff_row"):
		_track_sanity_issue("missing_rows", unit_id)
		return

	var buff_row = rows["buff_row"]
	if buff_row == null or not is_instance_valid(buff_row):
		_track_sanity_issue("missing_rows", unit_id)
		_unit_badge_rows.erase(unit_id)  # Cleanup stale reference
		return

	# Get updated buff snapshot from controller (efficient accessor)
	var buff_snapshot = _combat_controller.get_unit_buff_snapshot_sorted(unit_id)
	_populate_buff_badges(buff_row, buff_snapshot, unit_id)


## v1.8: Refresh all unit buff badges (after round tick, uses pooling).
## Iterates over direct badge row mappings for efficiency.
func refresh_all_buff_badges() -> void:
	var stale_ids: Array = []

	for unit_id in _unit_badge_rows.keys():
		var rows = _unit_badge_rows[unit_id]
		if not rows is Dictionary or not rows.has("buff_row"):
			_track_sanity_issue("missing_rows", unit_id)
			stale_ids.append(unit_id)
			continue

		var buff_row = rows["buff_row"]
		if buff_row == null or not is_instance_valid(buff_row):
			_track_sanity_issue("missing_rows", unit_id)
			stale_ids.append(unit_id)
			continue

		var buff_snapshot = _combat_controller.get_unit_buff_snapshot_sorted(unit_id)
		_populate_buff_badges(buff_row, buff_snapshot, unit_id)

	# Cleanup stale references (only if not already handled)
	for stale_id in stale_ids:
		if _unit_badge_rows.has(stale_id):
			_unit_badge_rows.erase(stale_id)


func _update_top_bar() -> void:
	if _combat_controller.is_combat_over():
		top_bar.text = "Combat Ended"
		return

	var turn_info = _combat_controller.get_turn_info()
	var unit_name = turn_info["current_actor_name"] if turn_info["current_actor_name"] != "" else "---"

	top_bar.text = "Round %d | Current Turn: %s" % [turn_info["round"], unit_name]


func _update_dungeon_progress_label() -> void:
	var dungeon_id = GameContext.get_current_dungeon_id()
	if dungeon_id == "":
		dungeon_progress_label.text = "Dungeon | Floor 0/0 | Room 0/0"
		return

	# Get dungeon display name
	var dungeon_name = dungeon_id
	if DataRegistry.has_method("get_dungeon"):
		var dungeon = DataRegistry.get_dungeon(dungeon_id)
		if dungeon != null and dungeon.display_name != "":
			dungeon_name = dungeon.display_name

	var floor_num = GameContext.get_current_floor()
	var dungeon = DataRegistry.get_dungeon(dungeon_id) if DataRegistry.has_method("get_dungeon") else null
	var floor_count = dungeon.floor_count if dungeon != null else 4
	var room_idx = GameContext.get_current_room_index() + 1
	var rooms_per_floor = GameContext.get_rooms_per_floor()

	dungeon_progress_label.text = "%s | Floor %d/%d | Room %d/%d" % [
		dungeon_name, floor_num, floor_count, room_idx, rooms_per_floor
	]


func _log(message: String) -> void:
	combat_log.append_text(message + "\n")


# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_step_pressed() -> void:
	_step_turn()


func _on_auto_pressed() -> void:
	_is_auto_running = not _is_auto_running
	auto_button.text = "Stop" if _is_auto_running else "Auto"
	_auto_timer = 0.0


func _on_reset_pressed() -> void:
	_start_encounter()


func _on_combat_ended(_result) -> void:
	_is_auto_running = false
	auto_button.text = "Auto"

	# v1.9A: Clear active unit highlight
	_set_active_unit("")

	# v1.8: Emit sanity report at encounter end
	_emit_sanity_report_if_needed()

	# Award XP on victory (boss=120, elite=75, normal=50)
	if _result != null and _result.is_victory:
		var xp_amount: int = 50  # Normal encounter
		var source: String = "combat_normal"

		if _result.is_boss_encounter:
			xp_amount = 120
			source = "combat_boss"
		elif GameContext.is_current_room_elite():
			xp_amount = 75
			source = "combat_elite"

		GameContext.grant_party_xp(xp_amount, source)

	# Transition to boot scene (guarded)
	if not _scene_transition_pending:
		_scene_transition_pending = true

		# Set phase for proper boot routing: DUNGEON_CAMP if still in dungeon, TOWN otherwise
		if GameContext.get_current_dungeon_id() != "":
			GameContext.enter_dungeon_camp()
		else:
			GameContext.set_phase(GameContext.GamePhase.TOWN)

		print("[Flow] Combat ended -> routing (phase=%s dungeon=%s floor=%d)" % [
			GameContext.get_phase_name(),
			GameContext.get_current_dungeon_id() if GameContext.get_current_dungeon_id() != "" else "none",
			GameContext.get_current_floor()
		])

		# Small delay so player sees result
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://Game/Boot/game_boot.tscn")


# ============================================================================
# SMOKE TEST
# ============================================================================

## Run UI smoke test - steps 10 turns and prints results.
func run_smoke_test_ui() -> bool:
	print("\n" + "=".repeat(50))
	print("    CombatScene UI SMOKE TEST")
	print("=".repeat(50) + "\n")

	var passed = true

	# Reset encounter
	_start_encounter()

	# Step 10 turns
	print("Stepping 10 turns...")
	for i in range(10):
		if _combat_controller.is_combat_over():
			print("  Combat ended at turn %d" % (i + 1))
			break
		_step_turn()

	# Print final state using clean API
	var turn_info = _combat_controller.get_turn_info()
	var snapshot = _combat_controller.get_units_snapshot()

	print("\nFinal State:")
	print("  Round: %d" % turn_info["round"])
	print("  Combat Over: %s" % str(_combat_controller.is_combat_over()))

	print("\nParty Status:")
	for unit in snapshot["player"]:
		print("  %s: HP %d/%d, Alive: %s" % [
			unit["name"], unit["hp"], unit["max_hp"], str(unit["is_alive"])])

	print("\nEnemy Status:")
	for unit in snapshot["enemy"]:
		print("  %s: HP %d/%d, Alive: %s" % [
			unit["name"], unit["hp"], unit["max_hp"], str(unit["is_alive"])])

	# Verify some turns were processed
	if turn_info["round"] >= 1:
		print("\n[PASS] Combat rounds processed")
	else:
		print("\n[FAIL] No rounds processed")
		passed = false

	print("\n" + "=".repeat(50))
	print("  UI SMOKE TEST %s" % ("PASSED" if passed else "FAILED"))
	print("=".repeat(50) + "\n")

	return passed


# ============================================================================
# DEBUG HOTKEYS - Dungeon progression testing (TEMP)
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5, KEY_F6, KEY_F7:
				# Guard: block dungeon state changes during active combat
				if _combat_controller != null and not _combat_controller.is_combat_over():
					print("[DEBUG] Hotkey ignored during combat")
					return
		match event.keycode:
			KEY_F5:
				# Enter dungeon from current town
				var town_id = GameContext.get_current_town_id()
				var town = DataRegistry.get_town(town_id)
				if town != null and town.dungeon_id != "":
					GameContext.enter_dungeon(town.dungeon_id)
					print("[DEBUG] EnterDungeon %s floor=%d" % [town.dungeon_id, GameContext.get_current_floor()])
				else:
					print("[DEBUG] EnterDungeon FAILED - no town or dungeon_id")
			KEY_F6:
				# Advance floor
				GameContext.advance_floor()
				print("[DEBUG] AdvanceFloor floor=%d" % GameContext.get_current_floor())
			KEY_F7:
				# Exit to town
				GameContext.exit_to_town()
				print("[DEBUG] ExitToTown")


# ============================================================================
# DEMO BUTTONS - Apply status effects for testing
# ============================================================================

## Apply stun to first enemy for demonstration.
func demo_apply_stun() -> void:
	var snapshot = _combat_controller.get_units_snapshot()
	if snapshot["enemy"].size() > 0:
		var enemy_id = snapshot["enemy"][0]["id"]
		var enemy_name = snapshot["enemy"][0]["name"]
		_combat_controller.apply_status_to_unit(enemy_id, "stun", 2)
		_log("[color=orange]DEMO: Applied STUN(2) to %s[/color]" % enemy_name)
		_refresh_all_panels()


## Apply doom to first enemy for demonstration.
func demo_apply_doom() -> void:
	var snapshot = _combat_controller.get_units_snapshot()
	if snapshot["enemy"].size() > 0:
		var enemy_id = snapshot["enemy"][0]["id"]
		var enemy_name = snapshot["enemy"][0]["name"]
		_combat_controller.apply_status_to_unit(enemy_id, "doom", 3)
		_log("[color=purple]DEMO: Applied DOOM(3) to %s[/color]" % enemy_name)
		_refresh_all_panels()


# ============================================================================
# STATUS UI v1.8 - Signal Handlers
# ============================================================================

## Handle status change on a specific unit (apply/stack/refresh).
## v1.8: Uses unified badge pipeline with pooling.
func _on_status_changed(unit_id: String) -> void:
	refresh_unit_status_badges(unit_id)
	refresh_unit_buff_badges(unit_id)  # Also refresh buffs (may change at same time)


## Handle all statuses ticked at round start.
## v1.8: Uses unified badge pipeline with pooling.
func _on_all_statuses_ticked() -> void:
	refresh_all_status_badges()
	refresh_all_buff_badges()  # Also refresh buffs (tick at round start too)


# ============================================================================
# STATUS UI v1.9A - Combat Readability Pack
# ============================================================================

## v1.9A: Set the active (currently acting) unit, updating visual highlight.
## Pass empty string to clear highlight.
func _set_active_unit(unit_id: String) -> void:
	# Remove highlight from previous active unit
	if _active_unit_id != "" and _unit_displays.has(_active_unit_id):
		var prev_display = _unit_displays[_active_unit_id]
		if is_instance_valid(prev_display):
			_remove_active_highlight(prev_display)

	_active_unit_id = unit_id

	# Add highlight to new active unit
	if unit_id != "" and _unit_displays.has(unit_id):
		var display = _unit_displays[unit_id]
		if is_instance_valid(display):
			_apply_active_highlight(display)


## v1.9B.1: Apply visual highlight to a unit display wrapper.
## Uses the HighlightFrame ColorRect created in _create_unit_display().
func _apply_active_highlight(display: Control) -> void:
	var highlight = display.get_node_or_null("HighlightFrame")
	if highlight != null:
		highlight.visible = true
		# v1.9B.1: Rate-limited debug log
		if not _highlight_log_emitted:
			print("[UI] highlight_set unit_id=%s node_ok=true" % display.name)
			_highlight_log_emitted = true
	else:
		# v1.9B.1: Fallback - create highlight if missing (shouldn't happen)
		print("[UI-WARN] highlight_missing unit_id=%s" % display.name)
		var fallback_highlight = ColorRect.new()
		fallback_highlight.name = "HighlightFrame"
		fallback_highlight.color = Color(1.0, 0.85, 0.0, 0.25)
		fallback_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		display.add_child(fallback_highlight)
		display.move_child(fallback_highlight, 0)


## v1.9B.1: Remove visual highlight from a unit display wrapper.
func _remove_active_highlight(display: Control) -> void:
	var highlight = display.get_node_or_null("HighlightFrame")
	if highlight != null:
		highlight.visible = false


## v1.9A: Show floating pop text near a unit.
## kind: "damage", "heal", "dot", "status_apply", "status_stack", "buff_apply", "miss", "crit"
func _show_pop_text(unit_id: String, text: String, kind: String) -> void:
	if not _unit_displays.has(unit_id):
		return

	var display = _unit_displays[unit_id]
	if not is_instance_valid(display):
		return

	# Get or create pop text label
	var label: Label
	if _pop_text_pool.size() > 0:
		label = _pop_text_pool.pop_back()
		if not is_instance_valid(label):
			label = _create_pop_text_label()
	else:
		label = _create_pop_text_label()

	# Configure label
	label.text = text
	var color = POP_TEXT_COLORS.get(kind, Color.WHITE)
	label.add_theme_color_override("font_color", color)

	# Position relative to unit display (top-right area)
	label.position = Vector2(display.size.x - 40, -10)
	label.modulate.a = 1.0
	label.visible = true

	# Add to display container
	display.add_child(label)

	# Animate: rise and fade out
	_animate_pop_text(label, display)


## v1.9A: Create a new pop text label.
func _create_pop_text_label() -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 100  # Render above other UI
	return label


## v1.9A: Animate pop text rising and fading, then return to pool.
func _animate_pop_text(label: Label, parent: Control) -> void:
	var start_pos = label.position
	var elapsed: float = 0.0

	# Use a timer for animation (avoid async issues)
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	timer.one_shot = false
	add_child(timer)

	timer.timeout.connect(func():
		elapsed += timer.wait_time
		var progress = elapsed / POP_TEXT_DURATION

		if progress >= 1.0 or not is_instance_valid(label):
			timer.stop()
			timer.queue_free()
			if is_instance_valid(label):
				label.visible = false
				if label.get_parent() != null:
					label.get_parent().remove_child(label)
				_pop_text_pool.append(label)
			return

		# Rise and fade
		label.position = start_pos + Vector2(0, -POP_TEXT_RISE * progress)
		label.modulate.a = 1.0 - (progress * progress)  # Quadratic fade for smoother look
	)

	timer.start()


## v1.9A: Show ability cast callout near unit.
func _show_cast_callout(unit_id: String, ability_name: String) -> void:
	if ability_name == "" or not _unit_displays.has(unit_id):
		return

	var display = _unit_displays[unit_id]
	if not is_instance_valid(display):
		return

	# Create callout label
	var label = Label.new()
	label.text = ability_name + "!"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.CYAN)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(display.size.x / 2 - 40, -25)
	label.z_index = 101

	display.add_child(label)

	# Fade out after duration
	var timer = Timer.new()
	timer.wait_time = CAST_CALLOUT_DURATION
	timer.one_shot = true
	add_child(timer)

	timer.timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
		timer.queue_free()
	)

	timer.start()


## v1.9A: Handle turn started signal - update active unit highlight.
func _on_turn_started(unit: CombatUnit) -> void:
	if unit != null:
		_set_active_unit(unit.unit_id)
	# v1.9B: Also refresh timeline and clear intent
	_on_turn_started_v19b(unit)


## v1.9A: Handle action performed signal - show pop text and cast callouts.
func _on_action_performed(action: CombatAction) -> void:
	if action == null:
		return

	# Damage pop text (on target)
	if action.damage_dealt > 0:
		var kind = "damage"
		if action.was_critical:
			kind = "crit"
		_show_pop_text(action.target_id, "-%d" % action.damage_dealt, kind)

	# Healing pop text (on target)
	if action.healing_done > 0:
		_show_pop_text(action.target_id, "+%d" % action.healing_done, "heal")

	# Cast callout for class/weapon abilities
	if action.action_type == CombatAction.ActionType.CLASS_ABILITY or \
	   action.action_type == CombatAction.ActionType.WEAPON_ABILITY:
		var ability_name = _get_ability_display_name(action.ability_id)
		if ability_name != "":
			_show_cast_callout(action.actor_id, ability_name)

	# Status apply pop text (if action applied status)
	if action.status_applied != "":
		var status_text = action.status_applied.capitalize()
		_show_pop_text(action.target_id, status_text, "status_apply")

	# v1.9B: Also add to log overlay
	_on_action_performed_v19b(action)


## v1.9A: Get display name for an ability from registry.
func _get_ability_display_name(ability_id: String) -> String:
	if ability_id == "":
		return ""
	# Try to get from DataRegistry
	if DataRegistry.has_method("get_ability"):
		var ability = DataRegistry.get_ability(ability_id)
		if ability != null and ability.display_name != "":
			return ability.display_name
	# Fallback: format the ID nicely
	return ability_id.replace("_", " ").capitalize()


# ============================================================================
# STATUS UI v1.9B - Turn Timeline + Intent + Log Overlay
# ============================================================================

# v1.9D: Log overlay pin mode state
var _log_overlay_pinned: bool = false
var _log_overlay_panel: PanelContainer = null
var _log_pin_button: Button = null

## v1.9D: Create the v1.9B UI elements (timeline, intent, log overlay).
## Uses dynamic positioning based on top bar height instead of magic constants.
func _create_v19b_ui() -> void:
	# Clean up existing if present
	if _timeline_panel != null and is_instance_valid(_timeline_panel):
		_timeline_panel.queue_free()
	if _current_intent_label != null and is_instance_valid(_current_intent_label):
		_current_intent_label.queue_free()
	if _log_overlay_panel != null and is_instance_valid(_log_overlay_panel):
		_log_overlay_panel.queue_free()
	elif _log_overlay_container != null and is_instance_valid(_log_overlay_container):
		_log_overlay_container.queue_free()

	# Reset log buffer
	_log_ring_buffer.clear()
	_last_dot_unit = ""
	_last_dot_count = 0

	# v1.9B.1: Reset highlight log flag
	_highlight_log_emitted = false

	# v1.9D: Dynamic timeline positioning (no magic TIMELINE_TOP constant)
	const TIMELINE_HEIGHT: int = 32
	const TIMELINE_MARGIN: int = 5

	# Compute timeline top from actual UI element heights
	var top_bar_h: float = top_bar.get_combined_minimum_size().y if top_bar != null else 40.0
	var dungeon_label_h: float = 0.0
	if dungeon_progress_label != null and dungeon_progress_label.visible:
		dungeon_label_h = dungeon_progress_label.get_combined_minimum_size().y
	var timeline_top: float = top_bar_h + dungeon_label_h + TIMELINE_MARGIN

	# v1.9D: Push MainContent down dynamically
	if main_content != null:
		main_content.offset_top = timeline_top + TIMELINE_HEIGHT + TIMELINE_MARGIN

	# Create timeline panel with dynamic positioning
	_timeline_panel = PanelContainer.new()
	_timeline_panel.name = "TurnTimelinePanel"
	_timeline_panel.anchor_left = 0.0
	_timeline_panel.anchor_right = 1.0
	_timeline_panel.anchor_top = 0.0
	_timeline_panel.anchor_bottom = 0.0
	_timeline_panel.offset_left = 10
	_timeline_panel.offset_right = -10
	_timeline_panel.offset_top = timeline_top
	_timeline_panel.offset_bottom = timeline_top + TIMELINE_HEIGHT
	_timeline_panel.custom_minimum_size = Vector2(0, TIMELINE_HEIGHT)
	_timeline_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Style the panel background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	panel_style.border_color = Color(0.35, 0.35, 0.45, 1.0)
	panel_style.border_width_bottom = 1
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 4
	panel_style.content_margin_bottom = 4
	_timeline_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_timeline_panel)

	# Create timeline HBox inside panel
	_timeline_container = HBoxContainer.new()
	_timeline_container.name = "TurnTimelineContent"
	_timeline_container.add_theme_constant_override("separation", 8)
	_timeline_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_timeline_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_panel.add_child(_timeline_container)

	# v1.9C: Intent label placed inside timeline panel (right side)
	_current_intent_label = Label.new()
	_current_intent_label.name = "IntentLabel"
	_current_intent_label.add_theme_font_size_override("font_size", 12)
	_current_intent_label.add_theme_color_override("font_color", Color.LIGHT_CORAL)
	_current_intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_current_intent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_current_intent_label.text = ""
	_timeline_container.add_child(_current_intent_label)

	# v1.9D: Create log overlay with background panel
	_log_overlay_panel = PanelContainer.new()
	_log_overlay_panel.name = "LogOverlayPanel"
	_log_overlay_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_log_overlay_panel.offset_left = -260
	_log_overlay_panel.offset_top = -240
	_log_overlay_panel.offset_right = -10
	_log_overlay_panel.offset_bottom = -205
	_log_overlay_panel.custom_minimum_size = Vector2(250, 0)

	# Style log overlay background
	var log_style = StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	log_style.border_color = Color(0.25, 0.25, 0.35, 0.6)
	log_style.set_border_width_all(1)
	log_style.set_corner_radius_all(4)
	log_style.content_margin_left = 8
	log_style.content_margin_right = 8
	log_style.content_margin_top = 6
	log_style.content_margin_bottom = 6
	_log_overlay_panel.add_theme_stylebox_override("panel", log_style)
	add_child(_log_overlay_panel)

	# Inner VBox for log content + pin button row
	var log_inner_vbox = VBoxContainer.new()
	log_inner_vbox.add_theme_constant_override("separation", 4)
	_log_overlay_panel.add_child(log_inner_vbox)

	# Header row with title and pin button
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	log_inner_vbox.add_child(header_row)

	var log_title = Label.new()
	log_title.text = "Log"
	log_title.add_theme_font_size_override("font_size", 10)
	log_title.add_theme_color_override("font_color", Color.DIM_GRAY)
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(log_title)

	# v1.9D: Pin toggle button
	_log_pin_button = Button.new()
	_log_pin_button.text = "Pin"
	_log_pin_button.toggle_mode = true
	_log_pin_button.custom_minimum_size = Vector2(40, 18)
	_log_pin_button.add_theme_font_size_override("font_size", 9)
	_log_pin_button.toggled.connect(_on_log_pin_toggled)
	header_row.add_child(_log_pin_button)

	# Log entries container
	_log_overlay_container = VBoxContainer.new()
	_log_overlay_container.name = "LogOverlayEntries"
	_log_overlay_container.add_theme_constant_override("separation", 2)
	log_inner_vbox.add_child(_log_overlay_container)

	# Initial timeline refresh
	_refresh_timeline()


## v1.9D: Handle pin button toggle.
func _on_log_pin_toggled(button_pressed: bool) -> void:
	_log_overlay_pinned = button_pressed
	if _log_pin_button != null:
		_log_pin_button.text = "Unpin" if button_pressed else "Pin"
	# When pinned, keep at full opacity; when unpinned, older entries fade


## v1.9D: Refresh the turn timeline UI with pill-style entries.
func _refresh_timeline() -> void:
	if _timeline_container == null or not is_instance_valid(_timeline_container):
		return

	# Clear existing children EXCEPT the intent label (last child)
	var children = _timeline_container.get_children()
	for i in range(children.size() - 1):  # Skip last child (intent label)
		children[i].queue_free()

	# Add "Next:" label (compact header)
	var header_label = Label.new()
	header_label.text = "Next:"
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	_timeline_container.add_child(header_label)
	_timeline_container.move_child(header_label, 0)

	# Get timeline snapshot
	var timeline = _combat_controller.get_turn_timeline_snapshot(TIMELINE_UNIT_COUNT)

	var insert_idx = 1  # After header
	for entry in timeline:
		# v1.9D: Create pill container for each unit
		var pill = _create_timeline_pill(entry)
		_timeline_container.add_child(pill)
		_timeline_container.move_child(pill, insert_idx)
		insert_idx += 1


## v1.9D: Create a styled pill container for a timeline entry.
## Returns PanelContainer with styled background and unit label.
func _create_timeline_pill(entry: Dictionary) -> PanelContainer:
	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(0, 22)

	# Determine colors based on team and active state
	var bg_color: Color
	var text_color: Color
	var border_color: Color

	if entry["is_current"]:
		# Active unit: gold/amber highlight
		bg_color = Color(0.35, 0.30, 0.10, 0.95)
		text_color = Color.GOLD
		border_color = Color(0.7, 0.6, 0.2, 1.0)
	elif entry["team"] == "P":
		# Player team: green-ish
		bg_color = Color(0.12, 0.22, 0.15, 0.9)
		text_color = Color.LIGHT_GREEN
		border_color = Color(0.25, 0.45, 0.30, 0.8)
	else:
		# Enemy team: coral-ish
		bg_color = Color(0.25, 0.12, 0.12, 0.9)
		text_color = Color.LIGHT_CORAL
		border_color = Color(0.45, 0.25, 0.25, 0.8)

	# Style the pill
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = bg_color
	pill_style.border_color = border_color
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(10)  # Rounded pill shape
	pill_style.content_margin_left = 8
	pill_style.content_margin_right = 8
	pill_style.content_margin_top = 2
	pill_style.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", pill_style)

	# Create label inside pill
	var name_short = entry["name"]
	if name_short.length() > 9:
		name_short = name_short.substr(0, 7) + ".."

	var unit_label = Label.new()
	# Show arrow for current, team letter otherwise
	if entry["is_current"]:
		unit_label.text = "▶ %s" % name_short
	else:
		unit_label.text = "%s" % name_short
	unit_label.add_theme_font_size_override("font_size", 11)
	unit_label.add_theme_color_override("font_color", text_color)
	unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(unit_label)

	# Tooltip with full info
	pill.tooltip_text = "%s | SPD: %d | %s" % [
		entry["name"],
		entry["speed"],
		"PLAYER" if entry["team"] == "P" else "ENEMY"
	]

	return pill


## v1.9B: Handle intent decided signal - show intent in timeline area.
func _on_intent_decided(actor_id: String, action_type: String, ability_id: String, target_id: String) -> void:
	if _current_intent_label == null or not is_instance_valid(_current_intent_label):
		return

	# Get actor and target names
	var actor_name = _get_unit_short_name(actor_id)
	var target_name = _get_unit_short_name(target_id) if target_id != "" else "?"

	# Build intent string (compact format for timeline row)
	var intent_text = ""
	if ability_id != "":
		var ability_name = _get_ability_display_name(ability_id)
		intent_text = "%s → %s" % [ability_name, target_name]
	elif action_type == "weapon":
		intent_text = "Weapon → %s" % target_name
	elif action_type == "basic":
		intent_text = "Attack → %s" % target_name
	else:
		intent_text = "%s → %s" % [action_type, target_name]

	_current_intent_label.text = intent_text

	# Also add to log overlay (with actor name for context)
	_add_to_log_overlay("%s: %s" % [actor_name, intent_text])


## v1.9B: Get short name for a unit from display cache.
func _get_unit_short_name(unit_id: String) -> String:
	if unit_id == "":
		return "?"
	# Try to get from combat controller snapshot
	if _combat_controller != null:
		var unit = _combat_controller.get_unit_by_id(unit_id)
		if unit != null:
			var name = unit.display_name
			if name.length() > 12:
				return name.substr(0, 10) + ".."
			return name
	return unit_id


## v1.9B: Add entry to log overlay (ring buffer, last 8).
func _add_to_log_overlay(text: String) -> void:
	# Rate limit: combine repeated DOT ticks
	if text.find("tick") != -1:
		var dot_match = text.find("PSN") != -1 or text.find("BLD") != -1
		if dot_match and _last_dot_unit != "" and text.find(_last_dot_unit) != -1:
			_last_dot_count += 1
			# Update last entry instead of adding new
			if _log_ring_buffer.size() > 0:
				_log_ring_buffer[_log_ring_buffer.size() - 1] = "%s (x%d)" % [text, _last_dot_count]
				_refresh_log_overlay()
				return
		else:
			_last_dot_unit = text.get_slice(" ", 0)
			_last_dot_count = 1

	# Add to ring buffer
	_log_ring_buffer.append(text)
	while _log_ring_buffer.size() > LOG_OVERLAY_MAX_ENTRIES:
		_log_ring_buffer.pop_front()

	_refresh_log_overlay()


## v1.9D: Refresh the log overlay display (respects pin mode).
func _refresh_log_overlay() -> void:
	if _log_overlay_container == null or not is_instance_valid(_log_overlay_container):
		return

	# Clear existing
	for child in _log_overlay_container.get_children():
		child.queue_free()

	# Add entries (older = more faded, unless pinned)
	var count = _log_ring_buffer.size()
	for i in range(count):
		var entry = _log_ring_buffer[i]
		var label = Label.new()
		label.text = entry
		label.add_theme_font_size_override("font_size", 10)

		# v1.9D: Pin mode keeps all entries at full opacity
		if _log_overlay_pinned:
			label.modulate.a = 1.0
		else:
			# Fade older entries (index 0 = oldest)
			var age_factor = float(i) / float(maxi(count, 1))
			var alpha = 0.4 + (age_factor * 0.6)  # Older = 0.4, newest = 1.0
			label.modulate.a = alpha

		# Color based on content
		if entry.find("→") != -1:
			label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		elif entry.find("took") != -1 or entry.find("-") != -1:
			label.add_theme_color_override("font_color", Color.SALMON)
		elif entry.find("+") != -1 or entry.find("heal") != -1:
			label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		else:
			label.add_theme_color_override("font_color", Color.WHITE)

		_log_overlay_container.add_child(label)


## v1.9B: Update turn started handler to also refresh timeline.
func _on_turn_started_v19b(unit: CombatUnit) -> void:
	# Refresh timeline when turn changes
	_refresh_timeline()

	# Clear intent when new turn starts
	if _current_intent_label != null and is_instance_valid(_current_intent_label):
		_current_intent_label.text = ""


## v1.9B: Hook action_performed to add to log overlay.
func _on_action_performed_v19b(action: CombatAction) -> void:
	if action == null:
		return

	var log_entry = ""

	match action.action_type:
		CombatAction.ActionType.BASIC_ATTACK:
			log_entry = "%s → %s -%d" % [action.actor_name, action.target_name, action.damage_dealt]
		CombatAction.ActionType.WEAPON_ABILITY, CombatAction.ActionType.CLASS_ABILITY:
			var ability_name = _get_ability_display_name(action.ability_id)
			if action.damage_dealt > 0:
				log_entry = "%s %s! -%d" % [action.actor_name, ability_name, action.damage_dealt]
			elif action.healing_done > 0:
				log_entry = "%s %s! +%d" % [action.actor_name, ability_name, action.healing_done]
			else:
				log_entry = "%s used %s" % [action.actor_name, ability_name]
		CombatAction.ActionType.SKIP:
			log_entry = "%s STUNNED" % action.actor_name
		CombatAction.ActionType.DEATH:
			log_entry = "%s defeated!" % action.actor_name
		CombatAction.ActionType.DOOM_TRIGGER:
			log_entry = "DOOM! %s -%d" % [action.target_name, action.damage_dealt]

	if log_entry != "":
		_add_to_log_overlay(log_entry)

	# Also refresh timeline (unit may have died)
	_refresh_timeline()
