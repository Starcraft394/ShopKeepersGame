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
# Grid Formation v1: Two side-by-side grids (Party left, Enemy right) with depth as columns
@onready var battlefield: HBoxContainer = $MainContent/Battlefield
@onready var stash_label: Label = $MainContent/StashLabel
@onready var combat_log: RichTextLabel = $BottomPanel/CombatLog
@onready var step_button: Button = $BottomPanel/ButtonRow/StepButton
@onready var auto_button: Button = $BottomPanel/ButtonRow/AutoButton
@onready var reset_button: Button = $BottomPanel/ButtonRow/ResetButton
@onready var dungeon_progress_label: Label = $DungeonProgressLabel
@onready var main_content: VBoxContainer = $MainContent  # v2: Now VBoxContainer

# ============================================================================
# STATE
# ============================================================================

var _combat_controller: Node = null
var _is_auto_running: bool = false
var _auto_timer: float = 0.0
var _auto_delay: float = 0.5  # Seconds between auto steps
var _scene_transition_pending: bool = false
var _loot_panel: Control = null  # Loot routing panel (shown after victory with drops)
var _loot_result = null  # CombatResult reference for loot panel
var _defeat_panel: Control = null  # Defeat screen (shown when all heroes die)

# Swap popup for full bags - allows replacing existing items
var _swap_popup: Window = null
var _swap_pending_acq_index: int = -1
var _swap_pending_hero_id: String = ""
var _swap_pending_item_id: String = ""

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
var _hero_input_highlight_active: bool = false  # v2.0: Track if hero input highlight is active
var _hero_input_pulse_tween: Tween = null  # v2.0: Tween for pulsing animation

# v2.0: Hero input highlight colors (brighter and more visible)
const HERO_INPUT_HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.2, 0.5)  # Bright golden yellow
const HERO_INPUT_HIGHLIGHT_PULSE_MIN: Color = Color(1.0, 0.85, 0.1, 0.35)  # Dimmer pulse
const HERO_INPUT_HIGHLIGHT_PULSE_MAX: Color = Color(1.0, 0.95, 0.3, 0.65)  # Brighter pulse
const NORMAL_HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.0, 0.25)  # Original subtle gold tint

# Pop text pooling
var _pop_text_pool: Array = []  # Pool of Label nodes
var _active_pop_timers: Array = []  # v2.1: Track active pop text timers to stop on refresh
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
# ATTACK LINE v1: Visual action intent line
# ============================================================================

var _attack_line_layer: Control = null
var _attack_line: Line2D = null
const ATTACK_LINE_FADE_IN: float = 0.05
const ATTACK_LINE_HOLD: float = 0.15
const ATTACK_LINE_FADE_OUT: float = 0.10
const ATTACK_LINE_WIDTH: float = 3.0
const ATTACK_LINE_COLOR: Color = Color(1.0, 0.8, 0.2, 0.9)  # Golden yellow
const ATTACK_LINE_HEAL_COLOR: Color = Color(0.2, 1.0, 0.4, 0.9)  # Green for heals

# ============================================================================
# PLAYER ACTIONS v1: Action Selection + Target Mode
# ============================================================================

var _action_panel: HBoxContainer = null
var _btn_basic: Button = null
var _btn_ability_a: Button = null
var _btn_ability_b: Button = null
var _btn_pass: Button = null
var _btn_cancel: Button = null
var _action_label: Label = null  # Shows "Action 1/3:"

var _target_selection_active: bool = false
var _valid_target_ids: Array = []
var _target_highlights: Dictionary = {}  # unit_id -> ColorRect

var _consumable_popup: PopupMenu = null
var _stats_window: Window = null  # Floating stats window
var _stats_window_hero_id: String = ""  # Hero ID for stats window refresh
var _stats_window_vbox: VBoxContainer = null  # Reference for auto-update
var _auto_step_pending: bool = false  # Guard against concurrent auto-steps
var _current_input_unit: CombatUnit = null  # Current unit awaiting player input (for tooltips)

# Auto mode deferred selection state
var _auto_pending_targets: Array = []  # Valid targets for deferred auto-selection

# DEV TOOL: Monster buff tracking
var _monster_buff_percent: int = 0  # Cumulative buff percentage (0, 25, 50, 75, ...)
var _monster_buff_btn: Button = null  # Reference to dev button for updating text

# ============================================================================
# GRID FORMATION v1: Two Side-by-Side Grids with Depth as Columns
# ============================================================================
# Layout: [Party: Back|Mid|Front] || [Enemy: Front|Mid|Back]
# pos.y (0=Front,1=Mid,2=Back) maps to UI COLUMNS (depth left-to-right)
# pos.x (0..3) maps to UI ROWS (slot positions top-to-bottom)

const GRID_COLS: int = 3   # Depth columns per side (Back/Mid/Front)
const GRID_ROWS: int = 4   # Slot rows per side (pos.x 0..3)


## Map gameplay row (pos.y = depth) to UI column index.
## Party: Back=col0, Mid=col1, Front=col2 (Front nearest center seam)
## Enemy: Front=col0, Mid=col1, Back=col2 (Front nearest center seam)
func _map_ui_col(team: String, pos_y: int) -> int:
	if team == "party":
		return 2 - pos_y  # pos_y 0(Front)->col2, 1(Mid)->col1, 2(Back)->col0
	else:
		return pos_y  # pos_y 0(Front)->col0, 1(Mid)->col1, 2(Back)->col2


## Get a cell container by team, UI row, and UI column.
## team: "party" or "enemy"
## ui_row: 0-3 (maps from pos.x)
## ui_col: 0-2 (maps from pos.y via _map_ui_col)
func _get_cell(team: String, ui_row: int, ui_col: int) -> PanelContainer:
	var row_clamped = clampi(ui_row, 0, GRID_ROWS - 1)
	var col_clamped = clampi(ui_col, 0, GRID_COLS - 1)
	var grid_name = "PartyGrid" if team == "party" else "EnemyGrid"
	var row_prefix = "PartyRow" if team == "party" else "EnemyRow"
	var row_name = "%s_%d" % [row_prefix, row_clamped]
	var cell_name = "Cell_c%d" % col_clamped
	return battlefield.get_node("%s/%s/%s" % [grid_name, row_name, cell_name]) as PanelContainer


## Clear all cell contents (but not the cells themselves) for one team.
func _clear_team_slots(team: String) -> void:
	var grid_name = "PartyGrid" if team == "party" else "EnemyGrid"
	var row_prefix = "PartyRow" if team == "party" else "EnemyRow"
	for ui_row in range(GRID_ROWS):
		var row_node = battlefield.get_node_or_null("%s/%s_%d" % [grid_name, row_prefix, ui_row])
		if row_node == null:
			continue
		for ui_col in range(GRID_COLS):
			var cell = row_node.get_node_or_null("Cell_c%d" % ui_col) as PanelContainer
			if cell == null:
				continue
			for child in cell.get_children():
				child.queue_free()


## Create an empty cell placeholder (subtle visual for empty cells).
func _create_empty_slot_placeholder() -> Control:
	var placeholder = ColorRect.new()
	placeholder.name = "EmptyPlaceholder"
	placeholder.color = Color(0.2, 0.2, 0.25, 0.3)  # Subtle dark tint
	placeholder.custom_minimum_size = Vector2(0, 60)  # Minimal height to show cell exists
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
	return placeholder


# ============================================================================
# ATTACK LINE v1: Visual Action Intent Line
# ============================================================================

## Create the attack line overlay layer (called once in _ready).
func _create_attack_line_layer() -> void:
	_attack_line_layer = Control.new()
	_attack_line_layer.name = "AttackLineLayer"
	_attack_line_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_attack_line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_attack_line_layer)
	# Move below tooltips/popups but above battlefield
	move_child(_attack_line_layer, get_child_count() - 2)


## Get the global center position of a unit display.
func _get_unit_display_center(unit_id: String) -> Vector2:
	if not _unit_displays.has(unit_id):
		return Vector2.ZERO
	var display = _unit_displays[unit_id]
	if not is_instance_valid(display):
		return Vector2.ZERO
	var global_rect = display.get_global_rect()
	return global_rect.get_center()


## Show an attack/ability line from actor to target with animation.
func _show_attack_line(actor_id: String, target_id: String, is_heal: bool = false) -> void:
	if actor_id == "" or target_id == "":
		return
	if actor_id == target_id:
		return  # Self-target, no line needed

	var start_pos = _get_unit_display_center(actor_id)
	var end_pos = _get_unit_display_center(target_id)

	if start_pos == Vector2.ZERO or end_pos == Vector2.ZERO:
		return

	# Convert global coordinates to local coordinates relative to attack line layer
	# Control nodes don't have to_local(); subtract global_position manually
	var layer_origin = _attack_line_layer.global_position
	start_pos -= layer_origin
	end_pos -= layer_origin

	# Create Line2D
	var line = Line2D.new()
	line.name = "AttackLine"
	line.width = ATTACK_LINE_WIDTH
	line.default_color = ATTACK_LINE_HEAL_COLOR if is_heal else ATTACK_LINE_COLOR
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.modulate.a = 0.0  # Start invisible
	_attack_line_layer.add_child(line)

	# Animate: fade in -> hold -> fade out -> free
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 1.0, ATTACK_LINE_FADE_IN)
	tween.tween_interval(ATTACK_LINE_HOLD)
	tween.tween_property(line, "modulate:a", 0.0, ATTACK_LINE_FADE_OUT)
	tween.tween_callback(line.queue_free)


# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	print("[CombatScene] Initializing...")

	# Connect button signals
	step_button.pressed.connect(_on_step_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	# Attack Line v1: Create overlay layer for action lines
	_create_attack_line_layer()

	# DEV TOOL: Add monster buff button
	_monster_buff_btn = Button.new()
	_monster_buff_btn.text = "Buff Monsters"
	_monster_buff_btn.custom_minimum_size = Vector2(110, 0)
	_monster_buff_btn.pressed.connect(_on_monster_buff_pressed)
	$BottomPanel/ButtonRow.add_child(_monster_buff_btn)

	# Start initial encounter
	_start_encounter()


func _process(delta: float) -> void:
	# Null safety: _combat_controller may be null during initialization or after queue_free
	if _combat_controller == null:
		return
	if _is_auto_running and not _combat_controller.is_combat_over():
		# Don't step if already waiting for player input (auto-selection handles this via signals)
		if _combat_controller.is_awaiting_player_input():
			return
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

	# Guard: Abort if no party members (prevents crash)
	if GameContext.selected_party.size() == 0:
		print("[CombatScene] ERROR: No party members! Returning to town.")
		_log("[color=red]ERROR: No heroes in party! Returning to town...[/color]")
		GameContext.exit_dungeon()
		GameContext.set_phase(GameContext.GamePhase.TOWN)
		get_tree().change_scene_to_file("res://Game/Boot/game_boot.tscn")
		return

	# Clear previous state
	if _combat_controller != null:
		_combat_controller.queue_free()

	_is_auto_running = false
	_auto_timer = 0.0
	_auto_step_pending = false  # Reset auto-step guard
	_auto_pending_targets.clear()  # Clear any pending auto-selection targets
	_stop_hero_input_highlight()  # Ensure tween is stopped before encounter reset

	# DEV TOOL: Reset monster buff on new encounter
	_monster_buff_percent = 0
	_update_monster_buff_button()

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
	_combat_controller.player_input_required.connect(_on_player_input_required)  # Player Actions v1
	_combat_controller.target_selection_required.connect(_on_target_selection_required)  # Player Actions v1
	_combat_controller.multi_action_update.connect(_on_multi_action_update)  # Player Actions v1
	_combat_controller.combat_continue_ready.connect(_on_combat_continue_ready)  # Player Actions v1.1: Auto-flow

	# v1.9B: Initialize timeline and log overlay UI
	_create_v19b_ui()

	# Player Actions v1: Create action panel
	_create_action_panel()

	# Hide Step button - using player action buttons instead
	step_button.visible = false

	# Get RNG with per-room unique seed for enemy variety
	var run_seed = GameContext.get_run_seed() if GameContext.is_run_active() else 12345
	var dungeon_id = GameContext.get_current_dungeon_id()
	var floor_num = GameContext.get_current_floor()
	var room_idx = GameContext.get_current_room_index()
	var region_id = GameContext.get_current_region_id()

	# Use encounter_seed to get unique seed per room (deterministic but varies per location)
	var encounter_derived_seed = SeededRNG.encounter_seed(region_id, dungeon_id, floor_num, room_idx, run_seed)
	var rng = SeededRNG.create_rng(encounter_derived_seed)
	print("[Combat] RNG seed: run=%d derived=%d (region=%s dungeon=%s floor=%d room=%d)" % [
		run_seed, encounter_derived_seed, region_id, dungeon_id, floor_num, room_idx
	])

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

	# Start first turn (will show action buttons if player turn, or auto-act if enemy)
	call_deferred("_step_turn")


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

	# Guard: Don't step if already awaiting player input
	# (Auto mode handles this via signal handlers, not _step_turn)
	if _combat_controller.is_awaiting_player_input():
		print("[UI] _step_turn skipped - already awaiting player input")
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
	# v2.0 Fix: Stop hero input highlight tween BEFORE clearing displays
	# The tween animates a node in _unit_displays which will be freed
	_stop_hero_input_highlight()

	# v2.1 Fix: Stop all active pop text timers BEFORE clearing displays
	# This prevents lambda capture freed errors when timers reference freed nodes
	_stop_all_pop_timers()

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
	# Grid Formation v1: Clear party cells
	_clear_team_slots("party")

	# Build lookup: "pos_y,pos_x" -> unit_data
	# pos_y = depth (0=Front,1=Mid,2=Back), pos_x = slot position (0..3)
	var occupied_cells: Dictionary = {}
	for unit_data in units:
		var pos = unit_data.get("pos", {})
		var pos_y = clampi(pos.get("y", 1), 0, 2)
		var pos_x = clampi(pos.get("x", 0), 0, GRID_ROWS - 1)
		var key = "%d,%d" % [pos_y, pos_x]
		if occupied_cells.has(key):
			push_warning("[CombatScene] Duplicate party cell %s: %s overwrites %s" % [
				key, unit_data.get("id", "?"), occupied_cells[key].get("id", "?")])
		occupied_cells[key] = unit_data

	# Fill all cells: unit display if occupied, placeholder if empty
	# UI row = pos.x (slot position), UI col = mapped from pos.y (depth)
	for pos_y in range(3):  # depth: Front/Mid/Back
		for pos_x in range(GRID_ROWS):  # slot row
			var ui_row = pos_x
			var ui_col = _map_ui_col("party", pos_y)
			var cell = _get_cell("party", ui_row, ui_col)
			if cell == null:
				continue

			var key = "%d,%d" % [pos_y, pos_x]
			if occupied_cells.has(key):
				var unit_data = occupied_cells[key]
				var display = _create_unit_display(unit_data)
				cell.add_child(display)
				_unit_displays[unit_data["id"]] = display
			else:
				cell.add_child(_create_empty_slot_placeholder())

	# Hero Loadout v1: Shopkeeper Bag summary (update existing label in scene)
	var stash = GameContext.get_run_stash_detailed_summary()
	stash_label.text = format_shopkeeper_bag(stash)


func _refresh_enemy_panel(units: Array) -> void:
	# Grid Formation v1: Clear enemy cells
	_clear_team_slots("enemy")

	# Build lookup: "pos_y,pos_x" -> unit_data
	var occupied_cells: Dictionary = {}
	for unit_data in units:
		var pos = unit_data.get("pos", {})
		var pos_y = clampi(pos.get("y", 1), 0, 2)
		var pos_x = clampi(pos.get("x", 0), 0, GRID_ROWS - 1)
		var key = "%d,%d" % [pos_y, pos_x]
		if occupied_cells.has(key):
			push_warning("[CombatScene] Duplicate enemy cell %s: %s overwrites %s" % [
				key, unit_data.get("id", "?"), occupied_cells[key].get("id", "?")])
		occupied_cells[key] = unit_data

	# Fill all cells: unit display if occupied, placeholder if empty
	# UI row = pos.x (slot position), UI col = mapped from pos.y (depth)
	for pos_y in range(3):  # depth: Front/Mid/Back
		for pos_x in range(GRID_ROWS):  # slot row
			var ui_row = pos_x
			var ui_col = _map_ui_col("enemy", pos_y)
			var cell = _get_cell("enemy", ui_row, ui_col)
			if cell == null:
				continue

			var key = "%d,%d" % [pos_y, pos_x]
			if occupied_cells.has(key):
				var unit_data = occupied_cells[key]
				var display = _create_unit_display(unit_data)
				cell.add_child(display)
				_unit_displays[unit_data["id"]] = display
			else:
				cell.add_child(_create_empty_slot_placeholder())


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

	# Name + Class line with row indicator (3-Row Formation v1)
	var name_label = Label.new()
	var alive_color = Color.WHITE if unit_data["is_alive"] else Color.GRAY
	var dead_text = " [DEAD]" if not unit_data["is_alive"] else ""
	var class_suffix = ""
	var display_name = unit_data["name"]

	# Row indicator: [F]=Front, [M]=Middle, [B]=Back
	var row_indicator = ""
	var pos = unit_data.get("pos", {})
	var row_y = pos.get("y", 1)  # Default to middle
	match row_y:
		0: row_indicator = " [F]"
		1: row_indicator = " [M]"
		2: row_indicator = " [B]"

	if unit_data["team"] == "player" and unit_data.get("class_id", "") != "":
		var cls_name = unit_data["class_id"].capitalize()
		var cls_data = DataRegistry.get_class_data(unit_data["class_id"])
		if cls_data != null and cls_data.display_name != "":
			cls_name = cls_data.display_name
		class_suffix = " (%s)" % cls_name
	elif unit_data["team"] == "enemy":
		# Add number to enemy name for differentiation (e.g., "Goblin #1")
		var unit_id = unit_data.get("id", "")
		if unit_id.begins_with("enemy_"):
			var enemy_num = int(unit_id.replace("enemy_", "")) + 1  # Convert to 1-based
			display_name = "%s #%d" % [unit_data["name"], enemy_num]

	name_label.text = "%s%s%s%s" % [display_name, class_suffix, row_indicator, dead_text]
	name_label.add_theme_color_override("font_color", alive_color)
	container.add_child(name_label)

	# HP bar with tooltip for player units
	var hp_container = HBoxContainer.new()
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [unit_data["hp"], unit_data["max_hp"]]
	hp_label.add_theme_font_size_override("font_size", 12)
	# Add HP tooltip for player units showing health breakdown
	if unit_data.get("team", "") == "player":
		hp_label.tooltip_text = _build_stat_breakdown_tooltip("Health", unit_data.get("max_hp", 0), unit_data.get("max_hp", 0), unit_data.get("active_buffs_v1", []), unit_data)
		hp_label.mouse_filter = Control.MOUSE_FILTER_STOP
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

	# Stat line showing ATK, DEF, SPD for player units (with buff breakdown tooltips)
	if unit_data["team"] == "player":
		var stat_line = HBoxContainer.new()
		stat_line.add_theme_constant_override("separation", 8)
		var buffs = unit_data.get("active_buffs_v1", [])

		var atk_label = Label.new()
		atk_label.text = "ATK: %d" % unit_data.get("attack", 0)
		atk_label.add_theme_font_size_override("font_size", 11)
		atk_label.add_theme_color_override("font_color", Color.SALMON)
		atk_label.mouse_filter = Control.MOUSE_FILTER_STOP
		atk_label.tooltip_text = _build_stat_breakdown_tooltip("Attack", unit_data.get("base_attack", 0), unit_data.get("attack", 0), buffs, unit_data)
		stat_line.add_child(atk_label)

		var sep1 = Label.new()
		sep1.text = "|"
		sep1.add_theme_font_size_override("font_size", 11)
		sep1.add_theme_color_override("font_color", Color.DIM_GRAY)
		stat_line.add_child(sep1)

		var def_label = Label.new()
		def_label.text = "DEF: %d" % unit_data.get("defense", 0)
		def_label.add_theme_font_size_override("font_size", 11)
		def_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		def_label.mouse_filter = Control.MOUSE_FILTER_STOP
		def_label.tooltip_text = _build_stat_breakdown_tooltip("Defense", unit_data.get("base_defense", 0), unit_data.get("defense", 0), buffs, unit_data)
		stat_line.add_child(def_label)

		var sep2 = Label.new()
		sep2.text = "|"
		sep2.add_theme_font_size_override("font_size", 11)
		sep2.add_theme_color_override("font_color", Color.DIM_GRAY)
		stat_line.add_child(sep2)

		var spd_label = Label.new()
		spd_label.text = "SPD: %d" % unit_data.get("speed", 0)
		spd_label.add_theme_font_size_override("font_size", 11)
		spd_label.add_theme_color_override("font_color", Color.YELLOW)
		spd_label.mouse_filter = Control.MOUSE_FILTER_STOP
		spd_label.tooltip_text = _build_stat_breakdown_tooltip("Speed", unit_data.get("base_speed", 0), unit_data.get("speed", 0), buffs, unit_data)
		stat_line.add_child(spd_label)

		container.add_child(stat_line)

	# Stat line showing ATK, DEF, SPD for enemy units (with buff breakdown tooltips)
	elif unit_data["team"] == "enemy":
		var stat_line = HBoxContainer.new()
		stat_line.add_theme_constant_override("separation", 8)
		var buffs = unit_data.get("active_buffs_v1", [])

		var atk_label = Label.new()
		atk_label.text = "ATK: %d" % unit_data.get("attack", 0)
		atk_label.add_theme_font_size_override("font_size", 11)
		atk_label.add_theme_color_override("font_color", Color.SALMON)
		atk_label.mouse_filter = Control.MOUSE_FILTER_STOP
		atk_label.tooltip_text = _build_stat_breakdown_tooltip("Attack", unit_data.get("base_attack", 0), unit_data.get("attack", 0), buffs, unit_data)
		stat_line.add_child(atk_label)

		var sep1 = Label.new()
		sep1.text = "|"
		sep1.add_theme_font_size_override("font_size", 11)
		sep1.add_theme_color_override("font_color", Color.DIM_GRAY)
		stat_line.add_child(sep1)

		var def_label = Label.new()
		def_label.text = "DEF: %d" % unit_data.get("defense", 0)
		def_label.add_theme_font_size_override("font_size", 11)
		def_label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
		def_label.mouse_filter = Control.MOUSE_FILTER_STOP
		def_label.tooltip_text = _build_stat_breakdown_tooltip("Defense", unit_data.get("base_defense", 0), unit_data.get("defense", 0), buffs, unit_data)
		stat_line.add_child(def_label)

		var sep2 = Label.new()
		sep2.text = "|"
		sep2.add_theme_font_size_override("font_size", 11)
		sep2.add_theme_color_override("font_color", Color.DIM_GRAY)
		stat_line.add_child(sep2)

		var spd_label = Label.new()
		spd_label.text = "SPD: %d" % unit_data.get("speed", 0)
		spd_label.add_theme_font_size_override("font_size", 11)
		spd_label.add_theme_color_override("font_color", Color.YELLOW)
		spd_label.mouse_filter = Control.MOUSE_FILTER_STOP
		spd_label.tooltip_text = _build_stat_breakdown_tooltip("Speed", unit_data.get("base_speed", 0), unit_data.get("speed", 0), buffs, unit_data)
		stat_line.add_child(spd_label)

		container.add_child(stat_line)

	# Player Actions v1.3: Abilities and Passives display (replaces equipment)
	if unit_data["team"] == "player":
		var hero_id = unit_data.get("source_id", unit_data["id"])

		# Abilities row
		var abilities_row = HBoxContainer.new()
		abilities_row.add_theme_constant_override("separation", 8)

		# Ability A
		var ability_a_id = unit_data.get("ability_a_id", "")
		if ability_a_id != "":
			var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
			var a_label = Label.new()
			var a_name = ability_a.display_name if ability_a else ability_a_id.replace("_", " ").capitalize()
			a_label.text = "[A] %s" % a_name
			a_label.add_theme_font_size_override("font_size", 11)
			a_label.add_theme_color_override("font_color", Color.CYAN)
			a_label.mouse_filter = Control.MOUSE_FILTER_STOP
			# Build tooltip with description, status effects, and cooldown
			var a_tooltip = _build_static_ability_tooltip(ability_a, a_name)
			a_label.tooltip_text = a_tooltip
			abilities_row.add_child(a_label)

		# Ability B
		var ability_b_id = unit_data.get("ability_b_id", "")
		if ability_b_id != "":
			var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
			var b_label = Label.new()
			var b_name = ability_b.display_name if ability_b else ability_b_id.replace("_", " ").capitalize()
			b_label.text = "[B] %s" % b_name
			b_label.add_theme_font_size_override("font_size", 11)
			b_label.add_theme_color_override("font_color", Color.CYAN)
			b_label.mouse_filter = Control.MOUSE_FILTER_STOP
			# Build tooltip with description, status effects, and cooldown
			var b_tooltip = _build_static_ability_tooltip(ability_b, b_name)
			b_label.tooltip_text = b_tooltip
			abilities_row.add_child(b_label)

		container.add_child(abilities_row)

		# Passives row
		var passives_row = HBoxContainer.new()
		passives_row.add_theme_constant_override("separation", 8)

		var passive_a_id = unit_data.get("passive_a_id", "")
		var passive_b_id = unit_data.get("passive_b_id", "")

		# Get hero level for tooltip formula calculation
		var hero_level = 1
		if GameContext.has_method("get_hero_effective_stats"):
			var stats = GameContext.get_hero_effective_stats(hero_id)
			hero_level = stats.get("level", 1)

		if passive_a_id != "":
			var passive_a = DataRegistry.get_passive(passive_a_id) if DataRegistry.has_method("get_passive") else null
			var pa_label = Label.new()
			var pa_name = passive_a.display_name if passive_a else passive_a_id.replace("_", " ").capitalize()
			pa_label.text = "[P] %s" % pa_name
			pa_label.add_theme_font_size_override("font_size", 10)
			pa_label.add_theme_color_override("font_color", Color.MEDIUM_PURPLE)
			pa_label.mouse_filter = Control.MOUSE_FILTER_STOP
			var pa_tooltip = pa_name
			if passive_a and passive_a.description != "":
				var desc = _resolve_formula_in_description(passive_a.description, hero_level)
				pa_tooltip += "\n%s" % desc
			pa_label.tooltip_text = pa_tooltip
			passives_row.add_child(pa_label)

		if passive_b_id != "":
			var passive_b = DataRegistry.get_passive(passive_b_id) if DataRegistry.has_method("get_passive") else null
			var pb_label = Label.new()
			var pb_name = passive_b.display_name if passive_b else passive_b_id.replace("_", " ").capitalize()
			pb_label.text = "[P] %s" % pb_name
			pb_label.add_theme_font_size_override("font_size", 10)
			pb_label.add_theme_color_override("font_color", Color.MEDIUM_PURPLE)
			pb_label.mouse_filter = Control.MOUSE_FILTER_STOP
			var pb_tooltip = pb_name
			if passive_b and passive_b.description != "":
				var desc = _resolve_formula_in_description(passive_b.description, hero_level)
				pb_tooltip += "\n%s" % desc
			pb_label.tooltip_text = pb_tooltip
			passives_row.add_child(pb_label)

		if passive_a_id != "" or passive_b_id != "":
			container.add_child(passives_row)

		# Hero bag line (with right-click for consumable use)
		var bag_summary = GameContext.get_hero_bag_summary(hero_id)
		var bag_label = Label.new()
		bag_label.name = "BagLabel"
		bag_label.text = "BAG: %s" % bag_summary
		bag_label.add_theme_font_size_override("font_size", 10)
		bag_label.add_theme_color_override("font_color", Color.SANDY_BROWN if "empty" not in bag_summary else Color.DIM_GRAY)
		bag_label.mouse_filter = Control.MOUSE_FILTER_STOP
		bag_label.gui_input.connect(_on_bag_right_clicked.bind(hero_id))
		bag_label.tooltip_text = "Right-click to use consumable"
		container.add_child(bag_label)

		# Stats button (opens floating stats window with full details)
		var stats_btn = Button.new()
		stats_btn.text = "Hero Info"
		stats_btn.custom_minimum_size = Vector2(60, 24)
		stats_btn.pressed.connect(_on_stats_button_pressed.bind(hero_id, unit_data))
		stats_btn.tooltip_text = "View full stats, equipment, and abilities"
		container.add_child(stats_btn)

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
## Enhanced v2.0: Detailed tooltips with descriptions and damage info
func _build_badge_tooltip(snapshot: Dictionary, kind: String) -> String:
	if kind == "status":
		var status_id = snapshot.get("id", "unknown")
		var ui_name = snapshot.get("ui_name", "")
		var stacks = snapshot.get("stacks", 1)
		var remaining = snapshot.get("remaining_rounds", 0)
		var tags = snapshot.get("tags", [])

		var display_name = ui_name if ui_name != "" else status_id.capitalize()

		# Start with name
		var tooltip_parts: Array = [display_name]

		# Get detailed info from status registry
		var status_data = DataRegistry.get_status_effect(status_id) if DataRegistry.has_method("get_status_effect") else null
		if status_data != null:
			# Add description
			if status_data.description != "":
				tooltip_parts.append(status_data.description)

			# Add damage info for DoT effects
			if "dot" in tags or status_data.category == "dot":
				var base_dmg = status_data.base_value
				var per_stack = status_data.value_per_stack
				var total_dmg = base_dmg + (per_stack * (stacks - 1)) if stacks > 1 else base_dmg
				if total_dmg > 0:
					tooltip_parts.append("Damage: %d per turn" % total_dmg)
					if stacks > 1 and per_stack > 0:
						tooltip_parts.append("  (Base: %d + %d per stack)" % [base_dmg, per_stack])

			# Add stun/control info
			if "control" in tags or status_data.category == "control":
				tooltip_parts.append("Effect: Cannot act while active")

		# Add stacks and duration
		tooltip_parts.append("Stacks: %d | Turns remaining: %d" % [stacks, remaining])

		# Add cleansable info if status data available
		if status_data != null and status_data.is_cleansable:
			tooltip_parts.append("(Can be cleansed)")

		return "\n".join(tooltip_parts)
	else:  # buff
		var source = snapshot.get("source", "unknown")
		var ui_name = snapshot.get("ui_name", source.capitalize())
		var stats = snapshot.get("stats", {})
		var remaining = snapshot.get("remaining_rounds", 0)
		var buff_tags = snapshot.get("buff_tags", [])

		# Start with name
		var tooltip_parts: Array = [ui_name]

		# Add stat bonuses in readable format
		var stats_str = _format_buff_stats_for_tooltip(stats)
		if stats_str != "none":
			tooltip_parts.append("Bonuses: %s" % stats_str)

		# Add duration
		tooltip_parts.append("Turns remaining: %d" % remaining)

		return "\n".join(tooltip_parts)


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
		# Hide duration for permanent buffs (999+)
		if remaining >= 999:
			return ui_short
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


## Hero Loadout v1: Format a single equipment slot line for combat UI.
## slot_code: "WPN", "OFF", "ARM", "HELM", "RING", "AMU"
## Returns e.g. "WPN: Q1 Iron Dagger" or "ARM: (empty)"
static func format_equipment_line(slot_code: String, item_id: String, quality: int) -> String:
	if item_id == "":
		return "%s: (empty)" % slot_code

	var display_name = item_id.replace("_", " ").capitalize()
	var template = DataRegistry.get_item_template(item_id)
	if template != null and template.display_name != "":
		display_name = template.display_name

	return "%s: Q%d %s" % [slot_code, quality, display_name]


## Hero Loadout v1: Format bag summary for combat UI.
## entries: Array of { "item_id", "qty" }; cap: max capacity.
## Returns e.g. "0/3 (empty)" or "2/3 Potion x1, Herb x1"
static func format_bag_summary(entries: Array, cap: int) -> String:
	if entries.is_empty():
		return "%d/%d (empty)" % [0, cap]

	# v1.2: Count stacks (entries), not total qty
	var used := entries.size()
	var parts: Array[String] = []
	for entry in entries:
		var qty = int(entry.get("qty", 1))
		var item_id = entry.get("item_id", "")
		var name = item_id.replace("_", " ").capitalize()
		var tpl = DataRegistry.get_item_template(item_id)
		if tpl != null and tpl.display_name != "":
			name = tpl.display_name
		parts.append("%s x%d" % [name, qty])
	return "%d/%d %s" % [used, cap, ", ".join(parts)]


## Hero Loadout v1: Format the Shopkeeper Bag (shared run stash) summary.
## stash: Dictionary from GameContext.get_run_stash_detailed_summary().
static func format_shopkeeper_bag(stash: Dictionary) -> String:
	return "SHOPKEEPER BAG: Gold %d | Items %d | Gear %d | Mats %d | Cons %d" % [
		stash.get("gold", 0),
		stash.get("total_items", 0),
		stash.get("gear_count", 0),
		stash.get("mat_count", 0),
		stash.get("cons_count", 0)
	]


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
## Filters out passive/permanent buffs (remaining_rounds >= 999) since they don't need badges.
func _populate_buff_badges(badge_row: HBoxContainer, buffs: Array, unit_id: String = "") -> void:
	# Filter out permanent/passive buffs - they don't need badge display
	var filtered_buffs: Array = []
	for buff in buffs:
		var remaining = buff.get("remaining_rounds", 0)
		var tags = buff.get("buff_tags", [])
		# Skip passive buffs (permanent combat effects)
		if remaining >= 999 or "passive" in tags:
			continue
		filtered_buffs.append(buff)
	_populate_badges_unified(badge_row, filtered_buffs, "buff", unit_id)


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

	# Clear pending auto-selection state when toggling auto mode
	_auto_pending_targets.clear()

	print("[UI] Auto mode toggled: %s" % ("ON" if _is_auto_running else "OFF"))

	# CRITICAL: If auto mode is turned ON while already waiting for player input,
	# immediately trigger auto-selection (the signal already fired)
	if _is_auto_running and _combat_controller != null and _combat_controller.is_awaiting_player_input():
		print("[UI] Auto mode turned ON while awaiting input - triggering auto-select")
		# Hide action panel since we're auto-selecting
		if _action_panel != null:
			_action_panel.visible = false
		# Trigger auto-selection
		call_deferred("_auto_select_action")


func _on_reset_pressed() -> void:
	_start_encounter()


## DEV TOOL: Buff all monsters by 25% each click
func _on_monster_buff_pressed() -> void:
	if _combat_controller == null:
		return

	# Apply 25% buff (multiplier = 1.25)
	_combat_controller.buff_all_enemies(1.25)
	_monster_buff_percent += 25

	# Update button text to show current buff level
	_update_monster_buff_button()

	# Refresh enemy display to show new stats
	_refresh_all_panels()

	_log("[color=orange][DEV] Monsters buffed to +%d%%[/color]" % _monster_buff_percent)


func _update_monster_buff_button() -> void:
	if _monster_buff_btn == null:
		return
	if _monster_buff_percent == 0:
		_monster_buff_btn.text = "Buff Monsters"
	else:
		_monster_buff_btn.text = "Buff +%d%%" % _monster_buff_percent


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

	# Show loot panel if there are pending acquisitions to route
	if _result != null and _result.is_victory and GameContext.has_pending_acquisition():
		_loot_result = _result
		_show_loot_panel()
	elif _result != null and not _result.is_victory:
		# DEFEAT — show defeat screen before returning to town
		_show_defeat_panel()
	else:
		# No pending loot — auto-resolve anything leftover and transition
		GameContext.resolve_all_to_stash()
		_do_combat_transition()


## Transition to boot scene after combat ends.
func _do_combat_transition() -> void:
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
# LOOT PANEL — Route items to stash or hero bags
# ============================================================================

## Show the loot routing panel after combat victory.
## v1.2: Manual-only routing (no auto-assign, no stash during dungeon, no remember prefs).
func _show_loot_panel() -> void:
	# Remove old panel if exists
	if _loot_panel != null:
		_loot_panel.queue_free()
		_loot_panel = null

	var pending = GameContext.get_all_pending_acquisitions()

	# Create full-screen overlay
	_loot_panel = PanelContainer.new()
	_loot_panel.name = "LootPanel"
	_loot_panel.anchor_right = 1.0
	_loot_panel.anchor_bottom = 1.0
	_loot_panel.offset_left = 0
	_loot_panel.offset_right = 0
	_loot_panel.offset_top = 0
	_loot_panel.offset_bottom = 0
	_loot_panel.focus_mode = Control.FOCUS_ALL

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_loot_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "LootVBox"
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	var gold_earned = _loot_result.gold_earned if _loot_result != null else 0
	title.text = "COMBAT LOOT  (+%d gold)" % gold_earned
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1, 0.9, 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# v1.2: Instruction text
	var inst_lbl = Label.new()
	inst_lbl.text = "Assign each item to a hero bag or shopkeeper bag. Keys: B=Shop Bag, 1-4=Hero"
	inst_lbl.add_theme_font_size_override("font_size", 11)
	inst_lbl.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(inst_lbl)

	# Pending acquisition items
	if pending.is_empty():
		var no_loot = Label.new()
		no_loot.text = "All items assigned."
		no_loot.modulate = Color(0.6, 0.9, 0.6)
		vbox.add_child(no_loot)
	else:
		for i in range(pending.size()):
			var acq = pending[i]
			var item_id = acq.get("item_id", "")
			var qty = int(acq.get("qty", 1))
			var quality = int(acq.get("quality", 0))
			var tpl = DataRegistry.get_item_template(item_id)
			var display_name = item_id.replace("_", " ").capitalize()
			if tpl != null and tpl.display_name != "":
				display_name = tpl.display_name

			var item_hbox = HBoxContainer.new()
			item_hbox.add_theme_constant_override("separation", 8)

			# Item icon (if available)
			if tpl != null:
				var icon_rect = tpl.create_icon_rect(20)
				if icon_rect != null:
					item_hbox.add_child(icon_rect)

			# Item label
			var item_label = Label.new()
			item_label.text = "%s x%d (Q%d)" % [display_name, qty, quality]
			item_label.add_theme_font_size_override("font_size", 14)
			item_label.custom_minimum_size = Vector2(200, 0)
			item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			item_hbox.add_child(item_label)

			# v1.2: NO "To Stash" button during dungeon (stash is banked)

			# [To Shop Bag] button — v1.3: ALL item types allowed
			var shop_btn = Button.new()
			shop_btn.text = "To Shop Bag"
			shop_btn.custom_minimum_size = Vector2(100, 28)
			var shop_used = GameContext.shopkeeper_bag.size()
			var shop_cap = GameContext.get_shopkeeper_bag_capacity()
			# v1.3: Check if 1 item can be added (no stacking)
			if not GameContext.can_add_to_shopkeeper_bag(item_id, 1, quality):
				shop_btn.disabled = true
				shop_btn.tooltip_text = "Shop bag full (%d/%d)" % [shop_used, shop_cap]
			else:
				shop_btn.pressed.connect(_on_loot_to_shop_bag.bind(i))
			item_hbox.add_child(shop_btn)

			# [To HeroName (used/cap)] buttons — one per party hero
			# v1.3: ALL item types allowed in hero bags
			for hero_id in GameContext.selected_party:
				var hero = GameContext.get_hero(hero_id)
				var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id
				if hero_name.length() > 8:
					hero_name = hero_name.substr(0, 7) + "."
				# Show bag capacity in button text
				var bag_used = GameContext.get_hero_bag(hero_id).size()
				var bag_cap = GameContext.get_hero_bag_capacity(hero_id)
				var hero_btn = Button.new()
				hero_btn.custom_minimum_size = Vector2(110, 28)
				# v1.4: If bag is full, enable swap mode instead of disabling
				if not GameContext.can_add_to_hero_bag(hero_id, item_id, 1):
					hero_btn.text = "Swap %s (%d/%d)" % [hero_name, bag_used, bag_cap]
					hero_btn.modulate = Color(1.0, 0.8, 0.6)  # Orange tint for swap
					hero_btn.tooltip_text = "Replace an item in %s's bag" % hero_name
					hero_btn.pressed.connect(_on_loot_swap_request.bind(i, hero_id, item_id))
				else:
					hero_btn.text = "To %s (%d/%d)" % [hero_name, bag_used, bag_cap]
					hero_btn.pressed.connect(_on_loot_to_hero.bind(i, hero_id))
				item_hbox.add_child(hero_btn)

			vbox.add_child(item_hbox)

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Hero bag summaries
	var bag_title = Label.new()
	bag_title.text = "Hero Bags:"
	bag_title.add_theme_font_size_override("font_size", 14)
	bag_title.modulate = Color(0.9, 0.7, 0.5)
	vbox.add_child(bag_title)

	for hero_id in GameContext.selected_party:
		var hero = GameContext.get_hero(hero_id)
		var hero_name = hero.get("name", hero_id) if not hero.is_empty() else hero_id
		var bag_summary = GameContext.get_hero_bag_summary(hero_id)
		var bag_lbl = Label.new()
		bag_lbl.text = "  %s: %s" % [hero_name, bag_summary]
		bag_lbl.add_theme_font_size_override("font_size", 12)
		bag_lbl.modulate = Color(0.8, 0.8, 0.6)
		vbox.add_child(bag_lbl)

	# Shopkeeper bag summary
	var shop_bag_lbl = Label.new()
	shop_bag_lbl.text = "  Shopkeeper Bag: %s" % GameContext.get_shopkeeper_bag_summary()
	shop_bag_lbl.add_theme_font_size_override("font_size", 12)
	shop_bag_lbl.modulate = Color(0.7, 0.9, 0.7)
	vbox.add_child(shop_bag_lbl)

	# Stash summary (banked, view only)
	var stash_lbl = Label.new()
	stash_lbl.text = "  Stash (banked): %d items, %d gold" % [GameContext.run_items.size(), GameContext.run_gold]
	stash_lbl.add_theme_font_size_override("font_size", 12)
	stash_lbl.modulate = Color(0.5, 0.5, 0.7)
	vbox.add_child(stash_lbl)

	# Separator
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# v1.2: Block Continue if pending items remain
	if not pending.is_empty():
		var block_lbl = Label.new()
		block_lbl.text = "Assign all items before continuing."
		block_lbl.add_theme_font_size_override("font_size", 12)
		block_lbl.modulate = Color(1.0, 0.6, 0.4)
		vbox.add_child(block_lbl)

		# Discard button (explicit user action)
		var discard_btn = Button.new()
		discard_btn.text = "Discard Remaining"
		discard_btn.custom_minimum_size = Vector2(160, 32)
		discard_btn.modulate = Color(1.0, 0.7, 0.7)
		discard_btn.pressed.connect(_on_loot_discard_all)
		vbox.add_child(discard_btn)

	# Continue button (disabled if pending items remain)
	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(200, 36)
	continue_btn.pressed.connect(_on_loot_continue)
	if not pending.is_empty():
		continue_btn.disabled = true
		continue_btn.tooltip_text = "Assign all items first"
	vbox.add_child(continue_btn)

	add_child(_loot_panel)
	_loot_panel.grab_focus()
	print("[LootPanel] Showing %d pending acquisitions" % pending.size())


## Refresh the loot panel after an item is routed.
func _refresh_loot_panel() -> void:
	_show_loot_panel()


## Route a pending acquisition to the shopkeeper bag.
func _on_loot_to_shop_bag(acq_index: int) -> void:
	GameContext.resolve_acquisition_at(acq_index, "shop_bag")
	_refresh_loot_panel()


## Route a pending acquisition to a hero's bag.
func _on_loot_to_hero(acq_index: int, hero_id: String) -> void:
	var ok = GameContext.resolve_acquisition_at(acq_index, "hero_bag", hero_id)
	if not ok:
		print("[LootPanel] Failed to route to hero=%s (rejected)" % hero_id)
	_refresh_loot_panel()


## v1.4: Request swap when hero bag is full - shows popup to choose which item to replace
func _on_loot_swap_request(acq_index: int, hero_id: String, new_item_id: String) -> void:
	_swap_pending_acq_index = acq_index
	_swap_pending_hero_id = hero_id
	_swap_pending_item_id = new_item_id

	# Close existing popup if any
	if _swap_popup != null and is_instance_valid(_swap_popup):
		_swap_popup.queue_free()

	# Get hero info
	var hero = GameContext.get_hero(hero_id)
	var hero_name = hero.get("name", hero_id) if hero else hero_id
	var bag = GameContext.get_hero_bag(hero_id)

	# Get new item info
	var new_template = DataRegistry.get_item_template(new_item_id)
	var new_item_name = new_template.display_name if new_template else new_item_id

	# Create popup window
	_swap_popup = Window.new()
	_swap_popup.title = "Replace Item in %s's Bag" % hero_name
	_swap_popup.size = Vector2i(350, 300)
	_swap_popup.transient = true
	_swap_popup.exclusive = true
	_swap_popup.close_requested.connect(_on_swap_popup_closed)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 8)
	_swap_popup.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "Adding: %s" % new_item_name
	header.modulate = Color(0.5, 1, 0.5)
	vbox.add_child(header)

	var instruction = Label.new()
	instruction.text = "Choose an item to replace:"
	vbox.add_child(instruction)

	# Warning that replaced item will be discarded
	var warning = Label.new()
	warning.text = "WARNING: Replaced item will be DISCARDED!"
	warning.modulate = Color(1.0, 0.4, 0.4)  # Red warning
	warning.add_theme_font_size_override("font_size", 11)
	vbox.add_child(warning)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# List current bag items with replace buttons
	for i in range(bag.size()):
		var entry = bag[i]
		var item_id = entry.get("item_id", "")
		var template = DataRegistry.get_item_template(item_id)
		var item_name = template.display_name if template else item_id

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var label = Label.new()
		label.text = item_name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var replace_btn = Button.new()
		replace_btn.text = "Replace"
		replace_btn.custom_minimum_size = Vector2(80, 26)
		replace_btn.pressed.connect(_on_swap_item_selected.bind(i, item_id))
		row.add_child(replace_btn)

		vbox.add_child(row)

	# Cancel button
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 30)
	cancel_btn.pressed.connect(_on_swap_popup_closed)
	vbox.add_child(cancel_btn)

	add_child(_swap_popup)
	_swap_popup.popup_centered()
	print("[LootPanel] Swap popup opened for hero=%s new_item=%s" % [hero_id, new_item_id])


## Handle item selection in swap popup - replace the selected item (old item is DISCARDED)
func _on_swap_item_selected(bag_index: int, old_item_id: String) -> void:
	var hero_id = _swap_pending_hero_id
	var acq_index = _swap_pending_acq_index

	# Remove and DISCARD the old item from hero bag (no stash loophole)
	var success = GameContext.remove_item_from_hero_bag(hero_id, old_item_id, 1, 0)
	if success:
		print("[LootPanel] DISCARDED old_item=%s from hero=%s" % [old_item_id, hero_id])

		# Now add the new item
		var ok = GameContext.resolve_acquisition_at(acq_index, "hero_bag", hero_id)
		if ok:
			print("[LootPanel] Swap complete: added new item to hero=%s" % hero_id)
		else:
			print("[LootPanel] Swap failed: couldn't add new item")
	else:
		print("[LootPanel] Swap failed: couldn't remove old item")

	_on_swap_popup_closed()
	_refresh_loot_panel()


## Close the swap popup
func _on_swap_popup_closed() -> void:
	if _swap_popup != null and is_instance_valid(_swap_popup):
		_swap_popup.queue_free()
		_swap_popup = null
	_swap_pending_acq_index = -1
	_swap_pending_hero_id = ""
	_swap_pending_item_id = ""


## v1.2: Discard all remaining pending items (explicit user action).
func _on_loot_discard_all() -> void:
	var pending = GameContext.get_all_pending_acquisitions()
	for acq in pending:
		var item_id = acq.get("item_id", "")
		var qty = int(acq.get("qty", 1))
		var quality = int(acq.get("quality", 0))
		print("[Loot] discard item=%s qty=%d q=%d" % [item_id, qty, quality])
	GameContext.clear_pending_acquisitions()
	_refresh_loot_panel()


## Continue after loot routing — only allowed when no pending items remain.
func _on_loot_continue() -> void:
	# v1.2: Do NOT auto-resolve to stash; Continue is blocked if pending remain
	if GameContext.has_pending_acquisition():
		print("[LootPanel] Continue blocked: %d items still pending" % GameContext.get_all_pending_acquisitions().size())
		return
	if _loot_panel != null:
		_loot_panel.queue_free()
		_loot_panel = null
	_do_combat_transition()


## Keyboard shortcuts for loot panel (v1.2: only B and 1-4, no S for stash).
func _loot_panel_input(event: InputEvent) -> void:
	if _loot_panel == null or not is_instance_valid(_loot_panel):
		return
	if not GameContext.has_pending_acquisition():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode = event.keycode
		# B = To Shop Bag (first pending)
		if keycode == KEY_B:
			GameContext.resolve_acquisition_at(0, "shop_bag")
			_refresh_loot_panel()
			get_viewport().set_input_as_handled()
		# 1..4 = To Hero by party index
		elif keycode >= KEY_1 and keycode <= KEY_4:
			var hero_idx = keycode - KEY_1
			if hero_idx < GameContext.selected_party.size():
				var hid = GameContext.selected_party[hero_idx]
				GameContext.resolve_acquisition_at(0, "hero_bag", hid)
				_refresh_loot_panel()
				get_viewport().set_input_as_handled()


# ============================================================================
# DEFEAT PANEL — Show losses when all heroes die
# ============================================================================

## Show the defeat screen with lost heroes and their equipment.
func _show_defeat_panel() -> void:
	# Remove old panel if exists
	if _defeat_panel != null:
		_defeat_panel.queue_free()
		_defeat_panel = null

	# Create full-screen overlay
	_defeat_panel = PanelContainer.new()
	_defeat_panel.name = "DefeatPanel"
	_defeat_panel.anchor_right = 1.0
	_defeat_panel.anchor_bottom = 1.0
	_defeat_panel.offset_left = 0
	_defeat_panel.offset_right = 0
	_defeat_panel.offset_top = 0
	_defeat_panel.offset_bottom = 0

	# Dark red background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	style.set_content_margin_all(20)
	_defeat_panel.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_defeat_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "DefeatVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEFEAT"
	title.add_theme_font_size_override("font_size", 32)
	title.modulate = Color(1.0, 0.3, 0.3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Your party has fallen..."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.modulate = Color(0.8, 0.6, 0.6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Section: Heroes Lost
	var heroes_header = Label.new()
	heroes_header.text = "— Heroes Lost Forever —"
	heroes_header.add_theme_font_size_override("font_size", 18)
	heroes_header.modulate = Color(1.0, 0.5, 0.5)
	heroes_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(heroes_header)

	# Get party heroes who died (HP <= 0)
	var lost_heroes: Array = []
	for hero_id in GameContext.selected_party:
		var hp_data = GameContext.get_hero_hp(hero_id)
		if not hp_data.is_empty() and int(hp_data.get("current", 1)) <= 0:
			lost_heroes.append(hero_id)

	if lost_heroes.is_empty():
		var no_loss = Label.new()
		no_loss.text = "(No permanent losses)"
		no_loss.modulate = Color(0.6, 0.8, 0.6)
		no_loss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_loss)
	else:
		for hero_id in lost_heroes:
			var hero_panel = _create_lost_hero_panel(hero_id)
			vbox.add_child(hero_panel)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Section: Items Saved (Shopkeeper Bag)
	var saved_header = Label.new()
	saved_header.text = "— Items Saved (Shop Bag) —"
	saved_header.add_theme_font_size_override("font_size", 16)
	saved_header.modulate = Color(0.5, 0.8, 0.5)
	saved_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(saved_header)

	var shop_bag = GameContext.shopkeeper_bag
	if shop_bag.is_empty():
		var no_items = Label.new()
		no_items.text = "(No items in shopkeeper bag)"
		no_items.modulate = Color(0.6, 0.6, 0.6)
		no_items.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_items)
	else:
		for entry in shop_bag:
			var item_id = entry.get("item_id", "")
			var qty = int(entry.get("qty", 1))
			var quality = int(entry.get("quality", 0))
			var tpl = DataRegistry.get_item_template(item_id)
			var display_name = tpl.display_name if tpl != null else item_id.replace("_", " ").capitalize()

			var item_label = Label.new()
			item_label.text = "  • %s x%d (Q%d)" % [display_name, qty, quality]
			item_label.modulate = Color(0.7, 0.9, 0.7)
			vbox.add_child(item_label)

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# Continue button
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var continue_btn = Button.new()
	continue_btn.text = "Return to Town"
	continue_btn.custom_minimum_size = Vector2(200, 40)
	continue_btn.pressed.connect(_on_defeat_continue)
	btn_row.add_child(continue_btn)

	add_child(_defeat_panel)
	print("[Defeat] Panel shown - lost_heroes=%d saved_items=%d" % [lost_heroes.size(), shop_bag.size()])


## Create a panel showing a lost hero and their equipment.
func _create_lost_hero_panel(hero_id: String) -> PanelContainer:
	var panel = PanelContainer.new()

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	style.border_color = Color(0.5, 0.2, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Get hero data
	var hero_data: Dictionary = {}
	for hero in GameContext.owned_heroes:
		if hero.get("hero_id", "") == hero_id:
			hero_data = hero
			break

	var hero_name = hero_data.get("name", "Unknown Hero")
	var race_id = hero_data.get("race_id", "")
	var class_id = hero_data.get("class_id", "")
	var level = int(hero_data.get("level", 1))

	# Get display names
	var race_name = race_id.capitalize()
	var race_data = DataRegistry.get_race(race_id)
	if race_data != null and race_data.display_name != "":
		race_name = race_data.display_name

	var cls_name = class_id.capitalize()
	var class_data = DataRegistry.get_class_data(class_id)
	if class_data != null and class_data.display_name != "":
		cls_name = class_data.display_name

	# Hero name and info
	var name_label = Label.new()
	name_label.text = "%s — Lv%d %s %s" % [hero_name, level, race_name, cls_name]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.modulate = Color(1.0, 0.7, 0.7)
	vbox.add_child(name_label)

	# Equipment lost
	var equip_header = Label.new()
	equip_header.text = "Equipment Lost:"
	equip_header.add_theme_font_size_override("font_size", 12)
	equip_header.modulate = Color(0.8, 0.6, 0.6)
	vbox.add_child(equip_header)

	var equipment = GameContext.get_hero_equipment(hero_id)
	var has_equipment = false

	for slot in GameContext.EQUIPMENT_SLOTS:
		var slot_data = equipment.get(slot, {})
		var item_id = slot_data.get("id", "")
		if item_id != "":
			has_equipment = true
			var quality = int(slot_data.get("quality", 0))
			var tpl = DataRegistry.get_item_template(item_id)
			var display_name = tpl.display_name if tpl != null else item_id.replace("_", " ").capitalize()
			var prefix = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""

			var equip_label = Label.new()
			equip_label.text = "  • %s: Q%d %s%s" % [slot.capitalize(), quality, prefix, display_name]
			equip_label.add_theme_font_size_override("font_size", 11)
			equip_label.modulate = Color(0.9, 0.6, 0.5)
			vbox.add_child(equip_label)

	# Check hero bag too
	var bag_item_id = GameContext.get_hero_bag_item(hero_id)
	if bag_item_id != "":
		has_equipment = true
		var bag_quality = GameContext.get_hero_bag_quality(hero_id)
		var bag_tpl = DataRegistry.get_item_template(bag_item_id)
		var bag_name = bag_tpl.display_name if bag_tpl != null else bag_item_id
		var prefix = ItemInstance.QUALITY_PREFIXES[bag_quality] if bag_quality < ItemInstance.QUALITY_PREFIXES.size() else ""

		var bag_label = Label.new()
		bag_label.text = "  • Bag: Q%d %s%s" % [bag_quality, prefix, bag_name]
		bag_label.add_theme_font_size_override("font_size", 11)
		bag_label.modulate = Color(0.9, 0.6, 0.5)
		vbox.add_child(bag_label)

		# Show bag contents
		var bag_contents = GameContext.get_hero_bag(hero_id)
		for entry in bag_contents:
			var entry_id = entry.get("item_id", "")
			var entry_qty = int(entry.get("qty", 1))
			var entry_tpl = DataRegistry.get_item_template(entry_id)
			var entry_name = entry_tpl.display_name if entry_tpl != null else entry_id

			var content_label = Label.new()
			content_label.text = "      └ %s x%d" % [entry_name, entry_qty]
			content_label.add_theme_font_size_override("font_size", 10)
			content_label.modulate = Color(0.7, 0.5, 0.4)
			vbox.add_child(content_label)

	if not has_equipment:
		var no_equip = Label.new()
		no_equip.text = "  (No equipment)"
		no_equip.add_theme_font_size_override("font_size", 11)
		no_equip.modulate = Color(0.5, 0.5, 0.5)
		vbox.add_child(no_equip)

	return panel


## Continue from defeat screen — return to town.
func _on_defeat_continue() -> void:
	if _defeat_panel != null:
		_defeat_panel.queue_free()
		_defeat_panel = null

	# Clear any pending acquisitions (dungeon loot is lost on defeat)
	GameContext.clear_pending_acquisitions()

	# Clear dungeon stash (provisional rewards lost)
	GameContext.clear_dungeon_stash()

	# Exit dungeon and return to town (defeat = lose dungeon progress)
	# Clear dungeon state so _do_combat_transition goes to TOWN not DUNGEON_CAMP
	GameContext.current_dungeon_id = ""
	GameContext.current_floor = 0
	GameContext.current_room_index = 0
	GameContext.set_phase(GameContext.GamePhase.TOWN)

	_do_combat_transition()


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
	# Loot panel keyboard shortcuts (intercept first)
	if _loot_panel != null and is_instance_valid(_loot_panel):
		_loot_panel_input(event)
		if event is InputEventKey and get_viewport().is_input_handled():
			return

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

# ============================================================================
# STATUS UI v1.8 - Signal Handlers
# ============================================================================

## Handle status change on a specific unit (apply/stack/refresh).
## v1.8: Uses unified badge pipeline with pooling.
func _on_status_changed(unit_id: String) -> void:
	refresh_unit_status_badges(unit_id)
	refresh_unit_buff_badges(unit_id)  # Also refresh buffs (may change at same time)
	_refresh_stats_window()  # v1.3: Update stats window if open


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
		# v2.0: Also reset highlight color to normal when removed
		highlight.color = NORMAL_HIGHLIGHT_COLOR

	# v2.0: Stop hero input highlight if active
	_stop_hero_input_highlight()


## v2.0: Apply enhanced hero input highlight with pulsing animation.
## This creates a brighter, more visible highlight for the hero awaiting player input.
func _apply_hero_input_highlight(unit_id: String) -> void:
	if not _unit_displays.has(unit_id):
		return

	var display = _unit_displays[unit_id]
	if not is_instance_valid(display):
		return

	var highlight = display.get_node_or_null("HighlightFrame")
	if highlight == null:
		return

	# Set initial bright color and make visible
	highlight.color = HERO_INPUT_HIGHLIGHT_COLOR
	highlight.visible = true
	_hero_input_highlight_active = true

	# Start pulsing animation
	_start_hero_input_pulse(highlight)

	print("[UI] Hero input highlight applied to %s" % unit_id)


## v2.0: Start pulsing animation on the highlight frame.
func _start_hero_input_pulse(highlight: ColorRect) -> void:
	# Stop any existing pulse tween
	if _hero_input_pulse_tween != null and _hero_input_pulse_tween.is_valid():
		_hero_input_pulse_tween.kill()

	# Create new tween for pulsing effect
	_hero_input_pulse_tween = create_tween()
	_hero_input_pulse_tween.set_loops()  # Loop forever until stopped

	# Pulse from dim to bright and back (0.6 second per direction = 1.2 second full cycle)
	_hero_input_pulse_tween.tween_property(highlight, "color", HERO_INPUT_HIGHLIGHT_PULSE_MAX, 0.6)
	_hero_input_pulse_tween.tween_property(highlight, "color", HERO_INPUT_HIGHLIGHT_PULSE_MIN, 0.6)


## v2.0: Stop hero input highlight and reset to normal state.
## v2.0 Fix: Always kill tween if it exists, even if _hero_input_highlight_active is false
## This prevents crashes when nodes are freed while tween is running.
func _stop_hero_input_highlight() -> void:
	# Always stop pulsing animation if tween exists (prevents crash on node free)
	if _hero_input_pulse_tween != null:
		if _hero_input_pulse_tween.is_valid():
			_hero_input_pulse_tween.kill()
		_hero_input_pulse_tween = null

	_hero_input_highlight_active = false


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


## v2.1: Stop and free all active pop text timers.
## Called before refreshing panels to prevent lambda capture freed errors.
func _stop_all_pop_timers() -> void:
	for timer in _active_pop_timers:
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_active_pop_timers.clear()


## v1.9A: Animate pop text rising and fading, then return to pool.
func _animate_pop_text(label: Label, parent: Control) -> void:
	var start_pos = label.position
	var elapsed: float = 0.0

	# Use a timer for animation (avoid async issues)
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60fps
	timer.one_shot = false
	add_child(timer)
	_active_pop_timers.append(timer)  # v2.1: Track timer for cleanup

	timer.timeout.connect(func():
		elapsed += timer.wait_time
		var progress = elapsed / POP_TEXT_DURATION

		if progress >= 1.0 or not is_instance_valid(label):
			timer.stop()
			_active_pop_timers.erase(timer)  # v2.1: Remove from tracking
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
	_active_pop_timers.append(timer)  # v2.1: Track timer for cleanup

	timer.timeout.connect(func():
		if is_instance_valid(label):
			label.queue_free()
		_active_pop_timers.erase(timer)  # v2.1: Remove from tracking
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

	# Attack Line v1: Draw visual line from actor to target
	if action.target_id != "" and action.actor_id != "":
		var is_heal = action.healing_done > 0 and action.damage_dealt == 0
		_show_attack_line(action.actor_id, action.target_id, is_heal)

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

	# CRITICAL: Refresh HP displays after any action
	_refresh_all_panels()

	# v1.3: Refresh stats window if open (shows updated buffs/HP)
	_refresh_stats_window()


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


# ============================================================================
# PLAYER ACTIONS v1: Action Selection UI
# ============================================================================

## Create the action panel with buttons for Basic Attack, Ability A, Ability B.
func _create_action_panel() -> void:
	if _action_panel != null:
		_action_panel.queue_free()

	_action_panel = HBoxContainer.new()
	_action_panel.name = "ActionPanel"
	_action_panel.add_theme_constant_override("separation", 10)
	_action_panel.visible = false

	_action_label = Label.new()
	_action_label.text = "Choose Action:"
	_action_label.add_theme_color_override("font_color", Color.CYAN)
	_action_panel.add_child(_action_label)

	_btn_basic = Button.new()
	_btn_basic.text = "Basic Attack"
	_btn_basic.custom_minimum_size = Vector2(120, 32)
	_btn_basic.pressed.connect(_on_basic_attack_pressed)
	_action_panel.add_child(_btn_basic)

	_btn_ability_a = Button.new()
	_btn_ability_a.custom_minimum_size = Vector2(150, 32)
	_btn_ability_a.pressed.connect(_on_ability_a_pressed)
	_action_panel.add_child(_btn_ability_a)

	_btn_ability_b = Button.new()
	_btn_ability_b.custom_minimum_size = Vector2(150, 32)
	_btn_ability_b.pressed.connect(_on_ability_b_pressed)
	_action_panel.add_child(_btn_ability_b)

	_btn_pass = Button.new()
	_btn_pass.text = "Pass"
	_btn_pass.custom_minimum_size = Vector2(80, 32)
	_btn_pass.pressed.connect(_on_pass_pressed)
	_action_panel.add_child(_btn_pass)

	_btn_cancel = Button.new()
	_btn_cancel.text = "Cancel"
	_btn_cancel.custom_minimum_size = Vector2(80, 32)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_btn_cancel.visible = false
	_action_panel.add_child(_btn_cancel)

	# Add to bottom panel
	$BottomPanel.add_child(_action_panel)


## Handle player_input_required signal - show action buttons.
func _on_player_input_required(unit: CombatUnit, available_actions: Array) -> void:
	print("[UI] player_input_required received for %s, auto_running=%s" % [unit.display_name, str(_is_auto_running)])
	_exit_target_selection_mode()

	# Store the current input unit for tooltip calculations
	_current_input_unit = unit

	# Auto mode: automatically select basic attack for player units
	# Use call_deferred to let the current signal complete first, preventing state issues
	if _is_auto_running:
		print("[UI] Auto mode: deferring auto-select basic attack for %s" % unit.display_name)
		call_deferred("_auto_select_action")
		return

	# Validate action panel exists
	if _action_panel == null:
		print("[UI] ERROR: _action_panel is null!")
		return

	_action_panel.visible = true
	_btn_cancel.visible = false

	# Reset button visibility
	_btn_ability_a.visible = false
	_btn_ability_b.visible = false
	_btn_pass.visible = false

	# Update button states from available actions
	for action_info in available_actions:
		match action_info.type:
			"basic":
				_btn_basic.disabled = false
				_btn_basic.tooltip_text = _build_action_tooltip(unit, null, "basic")
			"ability_a":
				_btn_ability_a.text = action_info.name
				if action_info.cooldown > 0:
					_btn_ability_a.text += " (CD:%d)" % action_info.cooldown
				_btn_ability_a.disabled = not action_info.enabled
				_btn_ability_a.visible = true
				_btn_ability_a.tooltip_text = _build_action_tooltip(unit, action_info.get("ability"), "ability_a")
			"ability_b":
				_btn_ability_b.text = action_info.name
				if action_info.cooldown > 0:
					_btn_ability_b.text += " (CD:%d)" % action_info.cooldown
				_btn_ability_b.disabled = not action_info.enabled
				_btn_ability_b.visible = true
				_btn_ability_b.tooltip_text = _build_action_tooltip(unit, action_info.get("ability"), "ability_b")
			"pass":
				_btn_pass.visible = true
				_btn_pass.tooltip_text = "Skip remaining actions and end turn."

	_log("[color=cyan]%s's turn - choose an action[/color]" % unit.display_name)
	print("[UI] Action panel shown, awaiting player input")

	# v2.0: Apply enhanced hero input highlight
	_apply_hero_input_highlight(unit.unit_id)


## Build tooltip text for an action button.
## Shows ability description and calculated damage based on current hero stats.
## Enhanced v2.0: Detailed tooltips with status effects, armor piercing, and mechanics
func _build_action_tooltip(unit: CombatUnit, ability: AbilityData, action_type: String) -> String:
	if action_type == "basic":
		# Basic attack: show effective attack as damage
		var eff_atk = unit.get_effective_attack()
		return "Attack an enemy.\nDamage: %d (reduced by target DEF)" % eff_atk

	if ability == null:
		return ""

	var tooltip_parts: Array = []

	# Add description if available
	if ability.description != "":
		tooltip_parts.append(ability.description)

	tooltip_parts.append("")  # Blank line separator

	# Add damage info if ability deals damage
	if ability.effect_type == "damage" or ability.effect_type == "damage_and_heal":
		var damage = _calculate_ability_damage_for_tooltip(unit, ability)
		var damage_text = "Damage: %d" % damage
		if ability.hit_count > 1:
			damage_text = "Damage: %d x%d hits" % [damage, ability.hit_count]
			damage_text += " (Total: %d)" % (damage * ability.hit_count)
		tooltip_parts.append(damage_text)

		# Show armor piercing info
		if ability.armor_piercing:
			tooltip_parts.append("  [Armor Piercing - ignores DEF]")
		else:
			tooltip_parts.append("  (Reduced by target DEF)")

	# Add heal info if ability heals
	if ability.effect_type == "heal" or ability.effect_type == "damage_and_heal":
		if ability.base_heal > 0:
			tooltip_parts.append("Heal: %d HP" % ability.base_heal)

	# Add buff info if ability buffs
	if ability.effect_type == "buff" and ability.buff_stats.size() > 0:
		var buff_text = "Buff: "
		var buff_parts: Array = []
		for stat in ability.buff_stats.keys():
			buff_parts.append("+%d %s" % [ability.buff_stats[stat], stat.capitalize()])
		buff_text += ", ".join(buff_parts)
		if ability.buff_duration > 0:
			buff_text += " (%d turns)" % ability.buff_duration
		tooltip_parts.append(buff_text)

	# Add self-buff info
	if ability.self_buff.size() > 0:
		var stat = ability.self_buff.get("stat", "")
		var value = ability.self_buff.get("value", 0)
		var duration = ability.self_buff.get("duration", 0)
		if stat != "" and value != 0:
			tooltip_parts.append("Self: +%d %s (%d turns)" % [value, stat.capitalize(), duration])

	# Add self-debuff info
	if ability.self_debuff.size() > 0:
		var stat = ability.self_debuff.get("stat", "")
		var value = ability.self_debuff.get("value", 0)
		var duration = ability.self_debuff.get("duration", 0)
		if stat != "" and value != 0:
			tooltip_parts.append("Self: %d %s (%d turns)" % [value, stat.capitalize(), duration])

	# Add enemy debuff info
	if ability.enemy_debuff.size() > 0:
		var stat = ability.enemy_debuff.get("stat", "")
		var value = ability.enemy_debuff.get("value", 0)
		var duration = ability.enemy_debuff.get("duration", 0)
		if stat != "" and value != 0:
			tooltip_parts.append("Enemy: %d %s (%d turns)" % [value, stat.capitalize(), duration])

	# Add status effect info with detailed description
	if ability.applies_status_id != "":
		var status_text = _build_status_effect_tooltip_text(ability.applies_status_id, ability.status_stacks, ability.status_chance, ability.applies_status_duration)
		if status_text != "":
			tooltip_parts.append(status_text)

	# Add shield info
	if ability.shield_value > 0:
		tooltip_parts.append("Shield: %d HP (%d turns)" % [ability.shield_value, ability.shield_duration])

	# Add cleanse info
	if ability.cleanses_debuffs > 0:
		tooltip_parts.append("Cleanses: %d debuff(s)" % ability.cleanses_debuffs)

	# Add reflect info
	if ability.reflect_percent > 0:
		tooltip_parts.append("Reflects: %d%% damage taken" % ability.reflect_percent)

	# Add self-damage cost
	if ability.self_damage > 0:
		tooltip_parts.append("HP Cost: %d" % ability.self_damage)

	# Add cooldown info if ability has cooldown
	if ability.cooldown > 0:
		tooltip_parts.append("")
		tooltip_parts.append("Cooldown: %d turns" % ability.cooldown)

	return "\n".join(tooltip_parts)


## Build tooltip text for a status effect applied by an ability.
## Returns formatted string with status name, description, damage, duration, and stacking info.
## Enhanced v2.1: More detailed info with duration override support
func _build_status_effect_tooltip_text(status_id: String, stacks: int, chance: float, duration_override: int = 0) -> String:
	var status_data = DataRegistry.get_status_effect(status_id) if DataRegistry.has_method("get_status_effect") else null

	var parts: Array = []

	# Chance prefix
	var chance_text = ""
	if chance < 1.0:
		chance_text = "%d%% chance: " % int(chance * 100)

	if status_data != null:
		# Status name
		var status_name = status_data.display_name if status_data.display_name != "" else status_id.capitalize()
		parts.append("%sApplies %s" % [chance_text, status_name])

		# Description
		if status_data.description != "":
			parts.append("  %s" % status_data.description)

		# Determine actual duration (ability override takes precedence)
		var actual_duration = duration_override if duration_override > 0 else status_data.base_duration

		# Damage info for DoTs - show formula breakdown
		if status_data.category == "dot" or "dot" in status_data.tags:
			var base_dmg = status_data.base_value
			var per_stack = status_data.value_per_stack
			var actual_stacks = maxi(1, stacks)
			var total_dmg = base_dmg + (per_stack * (actual_stacks - 1)) if actual_stacks > 1 else base_dmg
			if total_dmg > 0:
				var dmg_text = "  Damage: %d/turn" % total_dmg
				if per_stack > 0 and actual_stacks > 1:
					dmg_text += " (%d base + %d per stack)" % [base_dmg, per_stack]
				parts.append(dmg_text)

		# Healing info for HoTs
		if status_data.category == "buff" and "hot" in status_data.tags:
			var base_heal = status_data.base_value
			var per_stack = status_data.value_per_stack
			var actual_stacks = maxi(1, stacks)
			var total_heal = base_heal + (per_stack * (actual_stacks - 1)) if actual_stacks > 1 else base_heal
			if total_heal > 0:
				parts.append("  Heals: %d HP/turn" % total_heal)

		# Control info
		if status_data.category == "control":
			parts.append("  Effect: Cannot act while active")

		# Taunt info
		if "taunt" in status_data.tags:
			parts.append("  Effect: Forces enemies to attack this unit")

		# Evasion info
		if "evasion" in status_data.tags and status_data.base_value > 0:
			parts.append("  Effect: %d%% chance to dodge attacks" % status_data.base_value)

		# Reflect info
		if "reflect" in status_data.tags and status_data.base_value > 0:
			parts.append("  Effect: Reflects %d%% damage to attackers" % status_data.base_value)

		# Blind info
		if "blind" in status_data.tags and status_data.base_value > 0:
			parts.append("  Effect: %d%% chance to miss attacks" % status_data.base_value)

		# Duration and stacking info
		var info_parts: Array = []
		if actual_duration > 0:
			info_parts.append("%d turns" % actual_duration)
		if stacks > 1:
			info_parts.append("%d stacks" % stacks)
		if status_data.stacking_mode == "intensity" and status_data.max_stacks > 1:
			info_parts.append("max %d stacks" % status_data.max_stacks)
		if info_parts.size() > 0:
			parts.append("  (%s)" % ", ".join(info_parts))
	else:
		# Fallback for unknown status - provide basic info
		parts.append("%sApplies %s" % [chance_text, status_id.replace("_", " ").capitalize()])
		var info_parts: Array = []
		if duration_override > 0:
			info_parts.append("%d turns" % duration_override)
		if stacks > 1:
			info_parts.append("%d stacks" % stacks)
		if info_parts.size() > 0:
			parts.append("  (%s)" % ", ".join(info_parts))

	return "\n".join(parts)


## Calculate damage for an ability (mirrors CombatController._calculate_ability_damage).
func _calculate_ability_damage_for_tooltip(unit: CombatUnit, ability: AbilityData) -> int:
	var base = ability.base_damage
	var scaling = ability.attack_scaling
	var eff_atk = unit.get_effective_attack()
	var total = int(base + (eff_atk * scaling))
	return maxi(1, total)


## Build tooltip for static ability display on hero cards (without live damage calc).
## Shows description, status effects, special mechanics, and cooldown.
func _build_static_ability_tooltip(ability: AbilityData, fallback_name: String) -> String:
	if ability == null:
		return fallback_name

	var parts: Array = [ability.display_name if ability.display_name != "" else fallback_name]

	# Add description
	if ability.description != "":
		parts.append(ability.description)

	# Add damage info (without live calculation, show base damage + scaling)
	if ability.effect_type == "damage" or ability.effect_type == "damage_and_heal":
		var dmg_text = "Base Damage: %d" % ability.base_damage
		if ability.attack_scaling != 1.0:
			dmg_text += " (+%.0f%% ATK)" % (ability.attack_scaling * 100)
		if ability.hit_count > 1:
			dmg_text += " x%d hits" % ability.hit_count
		parts.append(dmg_text)

	# Add heal info
	if (ability.effect_type == "heal" or ability.effect_type == "damage_and_heal") and ability.base_heal > 0:
		parts.append("Heal: %d HP" % ability.base_heal)

	# Add buff info
	if ability.buff_stats.size() > 0:
		var buff_parts: Array = []
		for stat in ability.buff_stats.keys():
			buff_parts.append("+%d %s" % [ability.buff_stats[stat], stat.capitalize()])
		var buff_text = "Buff: %s" % ", ".join(buff_parts)
		if ability.buff_duration > 0:
			buff_text += " (%d turns)" % ability.buff_duration
		parts.append(buff_text)

	# Add status effect info
	if ability.applies_status_id != "":
		var status_text = _build_status_effect_tooltip_text(ability.applies_status_id, ability.status_stacks, ability.status_chance, ability.applies_status_duration)
		if status_text != "":
			parts.append(status_text)

	# Add special mechanics
	if ability.armor_piercing:
		parts.append("[Armor Piercing]")
	if ability.shield_value > 0:
		parts.append("Shield: %d HP (%d turns)" % [ability.shield_value, ability.shield_duration])
	if ability.cleanses_debuffs > 0:
		parts.append("Cleanses: %d debuff(s)" % ability.cleanses_debuffs)

	# Add cooldown
	if ability.cooldown > 0:
		parts.append("Cooldown: %d turns" % ability.cooldown)

	return "\n".join(parts)


## Resolve formulas in passive/ability descriptions by calculating actual values.
## Replaces patterns like "(2 + level/2)" or "(1 + hero level/2)" with calculated numbers.
## Example: "(2 + level/2)" with level=4 becomes "4"
func _resolve_formula_in_description(description: String, level: int) -> String:
	var result = description

	# Pattern: (X + level/Y) or (X + hero level/Y)
	# We'll use simple string matching since GDScript regex is limited
	var patterns = [
		{"search": "(1 + level/2)", "base": 1, "divisor": 2},
		{"search": "(2 + level/2)", "base": 2, "divisor": 2},
		{"search": "(3 + level/2)", "base": 3, "divisor": 2},
		{"search": "(1 + hero level/2)", "base": 1, "divisor": 2},
		{"search": "(2 + hero level/2)", "base": 2, "divisor": 2},
		{"search": "(3 + hero level/2)", "base": 3, "divisor": 2},
		{"search": "(1 + level/3)", "base": 1, "divisor": 3},
		{"search": "(2 + level/3)", "base": 2, "divisor": 3},
	]

	for pattern in patterns:
		if result.contains(pattern["search"]):
			var calculated = pattern["base"] + int(level / pattern["divisor"])
			result = result.replace(pattern["search"], str(calculated))

	return result


## Build a tooltip showing stat breakdown with base value and all buff sources.
## stat_name: "Health", "Attack", "Defense", or "Speed"
## effective_value: the unit's current stat including buffs
## buffs: array of buff snapshots from unit_data["active_buffs_v1"]
## unit_data: full unit snapshot dictionary for looking up hero/class/race info
func _build_stat_breakdown_tooltip(stat_name: String, base_value: int, effective_value: int, buffs: Array, unit_data: Dictionary = {}) -> String:
	var stat_key = stat_name.to_lower()  # "health", "attack", "defense", "speed"
	var parts: Array = [stat_name]

	# For player units, show detailed breakdown (class base + race + gear)
	var is_player = unit_data.get("team", "") == "player"
	var hero_id = unit_data.get("source_id", "")
	var class_id = unit_data.get("class_id", "")

	if is_player and hero_id != "":
		var hero = GameContext.get_hero(hero_id)
		var level = int(hero.get("level", 1))
		var race_id = hero.get("race_id", "human")

		# Get class base at level
		var class_base = 0
		var class_data = DataRegistry.get_class_data(class_id)
		if class_data != null:
			var base_stats = class_data.get_stats_at_level(level)
			class_base = int(base_stats.get(stat_key, 0))

		# Get race modifier and name
		var race_bonus = 0
		var race_name = race_id.capitalize()
		var race_data = DataRegistry.get_race(race_id)
		if race_data != null:
			race_bonus = int(race_data.stat_modifiers.get(stat_key, 0))
			if race_data.display_name != "":
				race_name = race_data.display_name

		# Get gear bonus
		var eff_stats = GameContext.get_hero_effective_stats(hero_id)
		var gear_bonus_dict = eff_stats.get("gear_bonus", {})
		var gear_bonus = int(gear_bonus_dict.get(stat_key, 0))

		# Build detailed breakdown
		parts.append("Base (Lv %d): %d" % [level, class_base])

		if race_bonus != 0:
			if race_bonus > 0:
				parts.append("%s: +%d" % [race_name, race_bonus])
			else:
				parts.append("%s: %d" % [race_name, race_bonus])

		if gear_bonus != 0:
			if gear_bonus > 0:
				parts.append("Gear: +%d" % gear_bonus)
			else:
				parts.append("Gear: %d" % gear_bonus)
	else:
		# For enemies or when hero data unavailable, show simple base
		parts.append("Base: %d" % base_value)

	# Find all buffs that affect this stat
	var buff_total = 0
	for buff in buffs:
		var stats = buff.get("stats", {})
		if stats.has(stat_key):
			var bonus = int(stats[stat_key])
			buff_total += bonus
			var source_name = buff.get("ui_name", buff.get("source", "Unknown"))
			var remaining = buff.get("remaining_rounds", 0)
			# Format duration - hide for permanent/passive buffs (999+)
			var duration_str = ""
			if remaining < 999:
				duration_str = " (%d turns)" % remaining
			if bonus >= 0:
				parts.append("%s: +%d%s" % [source_name, bonus, duration_str])
			else:
				parts.append("%s: %d%s" % [source_name, bonus, duration_str])

	# Handle edge case where base != effective but no tracked buffs (enemies only)
	if not is_player and buff_total == 0 and base_value != effective_value:
		var diff = effective_value - base_value
		if diff > 0:
			parts.append("Other bonuses: +%d" % diff)
		else:
			parts.append("Other modifiers: %d" % diff)

	# Show total
	parts.append("Total: %d" % effective_value)

	return "\n".join(parts)


## Handle target_selection_required signal - enter target mode.
func _on_target_selection_required(unit: CombatUnit, valid_targets: Array, action_type: String, ability) -> void:
	print("[UI] _on_target_selection_required: action=%s targets=%d auto_running=%s" % [action_type, valid_targets.size(), str(_is_auto_running)])

	# Check for AoE auto-execute (no target needed) - use deferred to prevent state issues
	if valid_targets.size() == 1 and valid_targets[0].unit_id == "aoe":
		print("[UI] Auto-executing AoE action (deferred)")
		_auto_pending_targets = [{"unit_id": "aoe"}]
		call_deferred("_auto_select_target")
		if _action_panel != null:
			_action_panel.visible = false
		return

	# Auto mode: automatically select first valid target - use deferred to let signal complete
	if _is_auto_running and valid_targets.size() > 0:
		print("[UI] Auto mode: deferring auto-select target %s" % valid_targets[0].unit_id)
		_auto_pending_targets = valid_targets.duplicate()
		call_deferred("_auto_select_target")
		if _action_panel != null:
			_action_panel.visible = false
		return

	# Handle edge case: no valid targets
	if valid_targets.size() == 0:
		print("[UI] WARNING: No valid targets available!")
		_log("[color=red]No valid targets![/color]")
		# Cancel back to action selection
		if _combat_controller != null:
			_combat_controller.cancel_player_action()
		return

	print("[UI] Entering target selection mode")
	_enter_target_selection_mode(valid_targets)
	_btn_cancel.visible = true

	var target_type = "enemy"
	if valid_targets.size() > 0 and valid_targets[0].get("is_ally", false):
		target_type = "ally"
	_log("[color=yellow]Click on a %s to target[/color]" % target_type)


## Handle multi_action_update signal - update action label.
func _on_multi_action_update(unit: CombatUnit, remaining: int, total: int) -> void:
	if _action_label != null:
		var action_num = total - remaining + 1
		_action_label.text = "Action %d/%d:" % [action_num, total]


## Enter target selection mode - highlight valid targets with hover effects.
## v2.1: Subtle initial highlight, brighter on hover for clear target indication
func _enter_target_selection_mode(valid_targets: Array) -> void:
	_target_selection_active = true
	_valid_target_ids.clear()

	for target_info in valid_targets:
		_valid_target_ids.append(target_info.unit_id)

	# Highlight valid targets, gray out invalid
	for unit_id in _unit_displays.keys():
		var display = _unit_displays[unit_id]
		if unit_id in _valid_target_ids:
			# Create highlight overlay if needed
			var highlight = display.get_node_or_null("TargetHighlight")
			if highlight == null:
				highlight = ColorRect.new()
				highlight.name = "TargetHighlight"
				highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
				highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
				display.add_child(highlight)
				display.move_child(highlight, 0)
			# Subtle initial highlight - indicates valid target
			highlight.color = Color(0.2, 0.8, 0.2, 0.15)  # Subtle green tint
			highlight.visible = true
			_target_highlights[unit_id] = highlight

			# Make clickable and hoverable
			display.mouse_filter = Control.MOUSE_FILTER_STOP

			# Disconnect old handlers to prevent duplicates
			for connection in display.gui_input.get_connections():
				if connection.callable.get_method() == "_on_unit_clicked":
					display.gui_input.disconnect(connection.callable)
			for connection in display.mouse_entered.get_connections():
				if connection.callable.get_method() == "_on_target_mouse_entered":
					display.mouse_entered.disconnect(connection.callable)
			for connection in display.mouse_exited.get_connections():
				if connection.callable.get_method() == "_on_target_mouse_exited":
					display.mouse_exited.disconnect(connection.callable)

			# Connect click and hover handlers
			display.gui_input.connect(_on_unit_clicked.bind(unit_id))
			display.mouse_entered.connect(_on_target_mouse_entered.bind(unit_id))
			display.mouse_exited.connect(_on_target_mouse_exited.bind(unit_id))
		else:
			# Gray out non-valid targets
			display.modulate = Color(0.5, 0.5, 0.5)


## Handle mouse entering a valid target during target selection.
func _on_target_mouse_entered(unit_id: String) -> void:
	if not _target_selection_active or unit_id not in _valid_target_ids:
		return
	# Brighten the highlight for the hovered target
	var highlight = _target_highlights.get(unit_id)
	if highlight:
		highlight.color = Color(0.4, 1.0, 0.4, 0.4)  # Brighter green on hover


## Handle mouse exiting a valid target during target selection.
func _on_target_mouse_exited(unit_id: String) -> void:
	if not _target_selection_active or unit_id not in _valid_target_ids:
		return
	# Return to subtle highlight
	var highlight = _target_highlights.get(unit_id)
	if highlight:
		highlight.color = Color(0.2, 0.8, 0.2, 0.15)  # Subtle green again


## Exit target selection mode - restore normal display.
func _exit_target_selection_mode() -> void:
	_target_selection_active = false
	_valid_target_ids.clear()

	for unit_id in _unit_displays.keys():
		var display = _unit_displays[unit_id]
		display.modulate = Color.WHITE
		display.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Disconnect all target selection handlers to prevent accumulation
		for connection in display.gui_input.get_connections():
			if connection.callable.get_method() == "_on_unit_clicked":
				display.gui_input.disconnect(connection.callable)
		for connection in display.mouse_entered.get_connections():
			if connection.callable.get_method() == "_on_target_mouse_entered":
				display.mouse_entered.disconnect(connection.callable)
		for connection in display.mouse_exited.get_connections():
			if connection.callable.get_method() == "_on_target_mouse_exited":
				display.mouse_exited.disconnect(connection.callable)

		# Hide highlight
		var highlight = display.get_node_or_null("TargetHighlight")
		if highlight:
			highlight.visible = false

	_target_highlights.clear()


## Handle click on unit display during target selection.
func _on_unit_clicked(event: InputEvent, unit_id: String) -> void:
	print("[UI] _on_unit_clicked: unit_id=%s target_selection_active=%s" % [unit_id, str(_target_selection_active)])
	if not _target_selection_active:
		print("[UI] Click ignored - not in target selection mode")
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[UI] Left click detected on %s, valid_target_ids=%s" % [unit_id, str(_valid_target_ids)])
		if unit_id in _valid_target_ids:
			print("[UI] Valid target clicked - submitting to controller")
			_exit_target_selection_mode()
			_action_panel.visible = false
			_combat_controller.submit_player_target(unit_id)
		else:
			print("[UI] Click on invalid target - ignoring")


## Handle Basic Attack button press.
func _on_basic_attack_pressed() -> void:
	print("[UI] Basic Attack button pressed")
	_combat_controller.submit_player_action("basic")


## Handle Ability A button press.
func _on_ability_a_pressed() -> void:
	print("[UI] Ability A button pressed")
	_combat_controller.submit_player_action("ability_a")


## Handle Ability B button press.
func _on_ability_b_pressed() -> void:
	print("[UI] Ability B button pressed")
	_combat_controller.submit_player_action("ability_b")


## Handle Pass button press - skip remaining actions.
func _on_pass_pressed() -> void:
	_action_panel.visible = false
	_combat_controller.submit_pass_action()


## Handle Cancel button press - return to action selection.
func _on_cancel_pressed() -> void:
	_exit_target_selection_mode()
	_combat_controller.cancel_player_action()


# ============================================================================
# AUTO MODE v2.0: Deferred Action/Target Selection
# ============================================================================

## Auto mode: deferred action selection to prevent state issues from synchronous signal handling.
func _auto_select_action() -> void:
	print("[UI] _auto_select_action called, auto_running=%s, controller=%s" % [
		str(_is_auto_running), "valid" if _combat_controller != null else "null"])

	# Guard: check if auto mode was disabled while deferred call was pending
	if not _is_auto_running:
		print("[UI] _auto_select_action: auto mode disabled, skipping")
		return

	# Guard: check if combat controller is valid
	if _combat_controller == null:
		print("[UI] _auto_select_action: combat controller null, skipping")
		return

	# Guard: check if still awaiting player input
	if not _combat_controller.is_awaiting_player_input():
		print("[UI] _auto_select_action: not awaiting player input, skipping")
		return

	print("[UI] _auto_select_action: submitting basic attack")
	_combat_controller.submit_player_action("basic")


## Auto mode: deferred target selection to prevent state issues from synchronous signal handling.
func _auto_select_target() -> void:
	print("[UI] _auto_select_target called, pending_targets=%d, auto_running=%s" % [
		_auto_pending_targets.size(), str(_is_auto_running)])

	# Guard: check if we have pending targets
	if _auto_pending_targets.size() == 0:
		print("[UI] _auto_select_target: no pending targets, skipping")
		return

	# Guard: check if combat controller is valid
	if _combat_controller == null:
		print("[UI] _auto_select_target: combat controller null, skipping")
		_auto_pending_targets.clear()
		return

	# Guard: check if still awaiting player input (for non-AoE)
	var target_id = _auto_pending_targets[0].get("unit_id", "")
	if target_id != "aoe" and not _combat_controller.is_awaiting_player_input():
		print("[UI] _auto_select_target: not awaiting player input, skipping")
		_auto_pending_targets.clear()
		return

	print("[UI] _auto_select_target: submitting target %s" % target_id)
	_combat_controller.submit_player_target(target_id)
	_auto_pending_targets.clear()


# ============================================================================
# PLAYER ACTIONS v1: Consumable Right-Click Menu
# ============================================================================

## Handle right-click on hero bag label.
func _on_bag_right_clicked(event: InputEvent, hero_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_consumable_menu(hero_id, event.global_position)


## Show popup menu with consumables from hero bag.
func _show_consumable_menu(hero_id: String, pos: Vector2) -> void:
	var bag = GameContext.get_hero_bag(hero_id)
	if bag.is_empty():
		_log("[color=gray]No items in bag[/color]")
		return

	# Only show menu if it's this hero's turn and awaiting input
	if not _combat_controller.is_awaiting_player_input():
		_log("[color=gray]Can only use items during your turn[/color]")
		return

	# Filter to only consumable items
	var consumables: Array = []
	for i in range(bag.size()):
		var entry = bag[i]
		var item_id = entry.get("item_id", "")
		var template = DataRegistry.get_item_template(item_id)
		if template != null and template.item_type == "consumable":
			consumables.append({"index": i, "item_id": item_id, "template": template})

	if consumables.is_empty():
		_log("[color=gray]No consumables in bag[/color]")
		return

	# Clean up old popup
	if _consumable_popup != null:
		_consumable_popup.queue_free()

	_consumable_popup = PopupMenu.new()
	add_child(_consumable_popup)

	var can_use = GameContext.can_hero_use_consumable(hero_id)

	for entry in consumables:
		var item_name = entry.template.display_name if entry.template else entry.item_id
		_consumable_popup.add_item("Use %s" % item_name, entry.index)

		# Disable if already used consumable this combat
		if not can_use:
			_consumable_popup.set_item_disabled(_consumable_popup.get_item_count() - 1, true)

	if not can_use:
		_consumable_popup.add_separator()
		_consumable_popup.add_item("(Already used item this combat)", -1)
		_consumable_popup.set_item_disabled(_consumable_popup.get_item_count() - 1, true)

	_consumable_popup.id_pressed.connect(_on_consumable_selected.bind(hero_id, bag))
	_consumable_popup.popup(Rect2i(Vector2i(pos), Vector2i.ZERO))


## Handle selection from consumable popup menu.
func _on_consumable_selected(idx: int, hero_id: String, bag: Array) -> void:
	if idx < 0 or idx >= bag.size():
		return

	var item_id = bag[idx].get("item_id", "")
	_combat_controller.submit_consumable_use(item_id, hero_id)

	if _consumable_popup != null:
		_consumable_popup.queue_free()
		_consumable_popup = null


# ============================================================================
# PLAYER ACTIONS v1.1: Auto-Flow Combat
# ============================================================================

## Handle combat_continue_ready signal - advance to next turn.
## Player control comes from action selection, not from stepping.
func _on_combat_continue_ready() -> void:
	print("[UI] _on_combat_continue_ready called, _auto_step_pending=%s" % str(_auto_step_pending))
	# Guard against concurrent auto-steps (race condition from rapid signals)
	if _auto_step_pending:
		print("[UI] Skipping - auto_step already pending")
		return
	_auto_step_pending = true

	# Use a short delay for visual pacing
	await get_tree().create_timer(0.3).timeout
	_auto_step_pending = false
	_auto_step_combat()


## Auto-step combat (called when ready to continue).
func _auto_step_combat() -> void:
	print("[UI] _auto_step_combat called")
	if _combat_controller == null:
		print("[UI] Skipping - _combat_controller is null")
		return
	if _scene_transition_pending:
		print("[UI] Skipping - scene transition pending")
		return

	# Check if waiting for player input
	if _combat_controller.is_awaiting_player_input():
		print("[UI] Skipping auto-step - awaiting player input")
		return

	# Refresh UI before stepping
	_refresh_all_panels()
	_update_top_bar()

	# Step combat
	print("[UI] Calling step_one_turn()")
	_combat_controller.step_one_turn()


# ============================================================================
# PLAYER ACTIONS v1.3: Stats Window (Floating, Non-Modal, Auto-Update)
# ============================================================================

## Handle Stats button press - show floating stats window.
func _on_stats_button_pressed(hero_id: String, unit_data: Dictionary) -> void:
	DebugLog.ui("Stats button pressed for hero_id=%s source_id=%s unit_id=%s" % [
		hero_id, unit_data.get("source_id", "?"), unit_data.get("id", "?")])
	# Close existing window if open
	if _stats_window != null and is_instance_valid(_stats_window):
		_stats_window.queue_free()
		_stats_window = null

	# Store hero ID for refresh
	_stats_window_hero_id = hero_id

	# Create floating window
	_stats_window = Window.new()
	_stats_window.title = "%s - Stats" % unit_data.get("name", hero_id)
	_stats_window.size = Vector2i(340, 500)
	_stats_window.position = Vector2i(100, 100)
	_stats_window.unresizable = false
	_stats_window.exclusive = false  # Non-modal - allows interaction with combat
	_stats_window.always_on_top = true  # Stay in foreground
	_stats_window.transient = true  # Associated with main window

	# Close when window is closed
	_stats_window.close_requested.connect(_on_stats_window_closed)

	# Create content container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_window.add_child(scroll)

	_stats_window_vbox = VBoxContainer.new()
	_stats_window_vbox.name = "StatsVBox"
	_stats_window_vbox.add_theme_constant_override("separation", 4)
	_stats_window_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stats_window_vbox)

	# Populate initial content
	_populate_stats_window(hero_id)

	# Show window
	add_child(_stats_window)
	_stats_window.popup_centered()

	print("[UI] Stats window opened for hero=%s" % hero_id)


## Populate or refresh the stats window content.
func _populate_stats_window(hero_id: String) -> void:
	if _stats_window_vbox == null or not is_instance_valid(_stats_window_vbox):
		return

	# Clear existing content
	for child in _stats_window_vbox.get_children():
		child.queue_free()

	var vbox = _stats_window_vbox

	# Get hero data from GameContext
	var hero_data = GameContext.get_hero(hero_id)
	var class_id = hero_data.get("class_id", "") if not hero_data.is_empty() else ""
	var race_id = hero_data.get("race_id", "human") if not hero_data.is_empty() else "human"
	var hero_name = hero_data.get("name", hero_id) if not hero_data.is_empty() else hero_id

	# Get class and race display names
	var cls_display_name = class_id.capitalize()
	if class_id != "" and DataRegistry.has_method("get_class_data"):
		var cls = DataRegistry.get_class_data(class_id)
		if cls != null and cls.display_name != "":
			cls_display_name = cls.display_name

	var race_display_name = race_id.capitalize()
	var race_data: RaceData = null
	if DataRegistry.has_method("get_race"):
		race_data = DataRegistry.get_race(race_id)
		if race_data != null and race_data.display_name != "":
			race_display_name = race_data.display_name

	# === HERO NAME AND CLASS ===
	var name_label = Label.new()
	name_label.text = "%s (%s %s)" % [hero_name, race_display_name, cls_display_name]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(name_label)

	# === LEVEL AND XP ===
	var hero_level = hero_data.get("level", 1) if not hero_data.is_empty() else 1
	var hero_xp = hero_data.get("xp", 0) if not hero_data.is_empty() else 0
	var xp_for_next = GameContext.get_xp_for_level(hero_level + 1) if GameContext.has_method("get_xp_for_level") else 100
	var level_label = Label.new()
	level_label.text = "Level %d  |  XP: %d / %d" % [hero_level, hero_xp, xp_for_next]
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(level_label)

	vbox.add_child(HSeparator.new())

	# === COMBAT STATS (effective) ===
	var stats_title = Label.new()
	stats_title.text = "Combat Stats (Effective)"
	stats_title.add_theme_font_size_override("font_size", 14)
	stats_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(stats_title)

	# Use safe dictionary method to avoid RefCounted property access issues
	var combat_stats = _combat_controller.get_unit_combat_stats(hero_id) if _combat_controller else {}
	if combat_stats.get("valid", false):
		# Use .get() for all dictionary access for maximum safety
		var hp = combat_stats.get("current_hp", 0)
		var max_hp = combat_stats.get("max_hp", 1)
		var attack = combat_stats.get("attack", 0)
		var defense = combat_stats.get("defense", 0)
		var speed = combat_stats.get("speed", 0)
		_add_stat_line(vbox, "HP", "%d / %d" % [hp, max_hp], Color.LIGHT_GREEN)
		_add_stat_line(vbox, "Attack", str(attack), Color.SALMON)
		_add_stat_line(vbox, "Defense", str(defense), Color.LIGHT_BLUE)
		_add_stat_line(vbox, "Speed", str(speed), Color.YELLOW)

		# Actions per turn based on speed (Speed 0-9: 1, 10-19: 2, 20+: 3)
		var eff_speed = speed
		var actions = 1
		if eff_speed >= 20:
			actions = 3
		elif eff_speed >= 10:
			actions = 2
		_add_stat_line(vbox, "Actions/Turn", str(actions), Color.CYAN)
	else:
		# Combat unit not available (combat may have ended or unit not found)
		var no_stats = Label.new()
		no_stats.text = "(Combat stats unavailable)"
		no_stats.modulate = Color.DIM_GRAY
		vbox.add_child(no_stats)

	vbox.add_child(HSeparator.new())

	# === EQUIPMENT ===
	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(equip_title)

	# Get equipment from GameContext (the authoritative source)
	var equipment = GameContext.get_hero_equipment(hero_id)
	var slots = ["weapon", "offhand", "helmet", "armor", "legs", "ring", "amulet"]
	var slot_names = {"weapon": "WPN", "offhand": "OFF", "helmet": "HELM", "armor": "ARM", "legs": "LEG", "ring": "RING", "amulet": "AMU"}

	for slot in slots:
		var slot_data = equipment.get(slot, {})
		var item_id = slot_data.get("id", "") if slot_data is Dictionary else ""
		var quality = int(slot_data.get("quality", 0)) if slot_data is Dictionary else 0
		var slot_code = slot_names.get(slot, slot.to_upper())
		var slot_text = "(empty)"
		var slot_tooltip = ""
		if item_id != "":
			var tpl = DataRegistry.get_item_template(item_id)
			if tpl != null:
				var prefix = ItemInstance.QUALITY_PREFIXES[quality] if quality < ItemInstance.QUALITY_PREFIXES.size() else ""
				slot_text = "Q%d %s%s" % [quality, prefix, tpl.display_name]
				slot_tooltip = _build_combat_item_tooltip(tpl, quality)
			else:
				slot_text = item_id
		_add_stat_line_with_tooltip(vbox, slot_code, slot_text, Color.SANDY_BROWN if item_id != "" else Color.DIM_GRAY, slot_tooltip)

	# === GEAR BONUSES (green +X format) ===
	var gear_bonuses = GameContext._get_hero_equipment_stat_bonuses(hero_id)
	var has_bonuses = gear_bonuses.get("health", 0) != 0 or gear_bonuses.get("attack", 0) != 0 or gear_bonuses.get("defense", 0) != 0 or gear_bonuses.get("speed", 0) != 0

	if has_bonuses:
		vbox.add_child(HSeparator.new())
		var bonus_title = Label.new()
		bonus_title.text = "Gear Bonuses"
		bonus_title.add_theme_font_size_override("font_size", 14)
		bonus_title.add_theme_color_override("font_color", Color.GOLD)
		vbox.add_child(bonus_title)

		if gear_bonuses.get("health", 0) != 0:
			_add_stat_line(vbox, "HP", "+%d" % gear_bonuses["health"], Color.LIME_GREEN)
		if gear_bonuses.get("attack", 0) != 0:
			_add_stat_line(vbox, "Attack", "+%d" % gear_bonuses["attack"], Color.LIME_GREEN)
		if gear_bonuses.get("defense", 0) != 0:
			_add_stat_line(vbox, "Defense", "+%d" % gear_bonuses["defense"], Color.LIME_GREEN)
		if gear_bonuses.get("speed", 0) != 0:
			_add_stat_line(vbox, "Speed", "+%d" % gear_bonuses["speed"], Color.LIME_GREEN)

	vbox.add_child(HSeparator.new())

	# === ABILITIES ===
	var ability_title = Label.new()
	ability_title.text = "Abilities"
	ability_title.add_theme_font_size_override("font_size", 14)
	ability_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(ability_title)

	# Get class data for abilities
	var cls_data = DataRegistry.get_class_data(class_id) if class_id != "" and DataRegistry.has_method("get_class_data") else null
	var ability_a_id = cls_data.ability_a_id if cls_data else ""
	var ability_b_id = cls_data.ability_b_id if cls_data else ""

	var has_abilities = false
	if ability_a_id != "":
		var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
		var a_name = ability_a.display_name if ability_a else ability_a_id
		var a_desc = ability_a.description if ability_a else ""
		var a_cd = "CD: %d" % (ability_a.cooldown if ability_a else 0)
		_add_ability_line(vbox, "[A] %s" % a_name, a_desc, a_cd)
		has_abilities = true

	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name = ability_b.display_name if ability_b else ability_b_id
		var b_desc = ability_b.description if ability_b else ""
		var b_cd = "CD: %d" % (ability_b.cooldown if ability_b else 0)
		_add_ability_line(vbox, "[B] %s" % b_name, b_desc, b_cd)
		has_abilities = true

	if not has_abilities:
		var none_lbl = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		vbox.add_child(none_lbl)

	vbox.add_child(HSeparator.new())

	# === PASSIVES (Class + Race) ===
	var passive_title = Label.new()
	passive_title.text = "Passives"
	passive_title.add_theme_font_size_override("font_size", 14)
	passive_title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(passive_title)

	var has_passives = false

	# Class passives
	var passive_a_id = cls_data.passive_a_id if cls_data else ""
	var passive_b_id = cls_data.passive_b_id if cls_data else ""

	if passive_a_id != "":
		var p_data = DataRegistry.get_passive(passive_a_id) if DataRegistry.has_method("get_passive") else null
		var p_name = p_data.display_name if p_data else passive_a_id
		var p_desc = p_data.description if p_data else ""
		_add_ability_line(vbox, "[Class] %s" % p_name, p_desc, "")
		has_passives = true

	if passive_b_id != "":
		var p_data = DataRegistry.get_passive(passive_b_id) if DataRegistry.has_method("get_passive") else null
		var p_name = p_data.display_name if p_data else passive_b_id
		var p_desc = p_data.description if p_data else ""
		_add_ability_line(vbox, "[Class] %s" % p_name, p_desc, "")
		has_passives = true

	# Race passive
	if race_data != null and race_data.racial_passive_id != "":
		var rp_data = DataRegistry.get_passive(race_data.racial_passive_id) if DataRegistry.has_method("get_passive") else null
		var rp_name = rp_data.display_name if rp_data else race_data.racial_passive_id
		var rp_desc = rp_data.description if rp_data else ""
		_add_ability_line(vbox, "[Race] %s" % rp_name, rp_desc, "")
		has_passives = true

	if not has_passives:
		var none_lbl = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		vbox.add_child(none_lbl)


## Refresh the stats window if open (called after buffs/actions).
func _refresh_stats_window() -> void:
	if _stats_window == null or not is_instance_valid(_stats_window):
		return
	if _stats_window_hero_id == "":
		return
	_populate_stats_window(_stats_window_hero_id)


## Helper: Add a stat line to the stats window.
func _add_stat_line(container: VBoxContainer, stat_name: String, value: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Helper: Add a stat line with tooltip support (for equipment).
func _add_stat_line_with_tooltip(container: VBoxContainer, stat_name: String, value: String, color: Color, tooltip: String = "") -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var name_lbl = Label.new()
	name_lbl.text = stat_name + ":"
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", color)
	if tooltip != "":
		val_lbl.tooltip_text = tooltip
		val_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	hbox.add_child(val_lbl)

	container.add_child(hbox)


## Build tooltip text for equipment items in combat.
func _build_combat_item_tooltip(template, quality_tier: int) -> String:
	if template == null:
		return ""

	var lines: Array[String] = []

	lines.append(template.display_name)
	if template.description != "":
		lines.append(template.description)
	lines.append("")

	# Quality multiplier
	var quality_names = ["Common", "Uncommon", "Rare", "Epic"]
	var quality_mults = [1.0, 1.1, 1.2, 1.35]
	var quality_name = quality_names[quality_tier] if quality_tier < quality_names.size() else "Common"
	var quality_mult = quality_mults[quality_tier] if quality_tier < quality_mults.size() else 1.0
	if quality_tier > 0:
		lines.append("Quality: %s (x%.2f stats)" % [quality_name, quality_mult])
		lines.append("")

	# Stats with quality scaling
	var base_stats = template.base_stats if template.base_stats != null else {}
	var stat_bonuses = template.stat_bonuses if template.stat_bonuses != null else {}

	var all_stats = {}
	for key in base_stats.keys():
		all_stats[key] = base_stats[key]
	for key in stat_bonuses.keys():
		if not all_stats.has(key):
			all_stats[key] = stat_bonuses[key]

	if all_stats.size() > 0:
		lines.append("Stats:")
		for stat_name in all_stats.keys():
			var base_value = int(all_stats[stat_name])
			var scaled_value = int(base_value * quality_mult)
			lines.append("  +%d %s" % [scaled_value, stat_name.capitalize()])

	return "\n".join(lines)


## Helper: Add an ability line with name, description, and cooldown.
func _add_ability_line(container: VBoxContainer, ability_name: String, desc: String, cd: String) -> void:
	var ability_vbox = VBoxContainer.new()
	ability_vbox.add_theme_constant_override("separation", 2)

	var name_hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = ability_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_hbox.add_child(name_lbl)

	if cd != "":
		var cd_lbl = Label.new()
		cd_lbl.text = "  [%s]" % cd
		cd_lbl.add_theme_font_size_override("font_size", 10)
		cd_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		name_hbox.add_child(cd_lbl)

	ability_vbox.add_child(name_hbox)

	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color.LIGHT_GRAY)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(280, 0)
		ability_vbox.add_child(desc_lbl)

	container.add_child(ability_vbox)


## Handle stats window close request.
func _on_stats_window_closed() -> void:
	if _stats_window != null and is_instance_valid(_stats_window):
		_stats_window.queue_free()
		_stats_window = null
	print("[UI] Stats window closed")
