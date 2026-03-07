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
const SLOT_STYLE = preload("res://Themes/CraftPix/slot_inventory.tres")


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
var _stall_recovery_timer: float = 0.0  # Watchdog: detect hidden action panel during player input
var _scene_transition_pending: bool = false
var _loot_panel: Control = null  # Loot routing panel (CanvasLayer overlay)
var _loot_overlay: CanvasLayer = null  # CanvasLayer for loot popup
var _loot_result = null  # CombatResult reference for loot panel
var _defeat_panel: Control = null  # Defeat screen (shown when all heroes die)
var _victory_panel: CanvasLayer = null  # Campaign victory overlay
var _flee_dialog: CanvasLayer = null  # Flee from dungeon dialog

# Shopkeeper Bag Display (Feature J)
var _shopkeeper_bag_panel: PanelContainer = null
var _shopkeeper_bag_row: HBoxContainer = null
var _shopkeeper_bag_label: Label = null

# Hero Bag Display (active hero's bag shown in combat)
var _hero_bag_panel: PanelContainer = null
var _hero_bag_row: HBoxContainer = null
var _hero_bag_label: Label = null

# Bags wrapper (holds shopkeeper + hero bags side-by-side)
var _bags_hbox: HBoxContainer = null

# Swap system (Feature K: Insurance UI)
var _swap_source: Dictionary = {}  # {type: "shopkeeper", index: int}
var _swap_highlight_btn: Button = null  # Currently highlighted slot for swap

# Region color palette (populated in _ready)
var _region_palette: Dictionary = {}

# Loot panel selection state
var _loot_selected_index: int = -1  # Currently selected pending item index
var _loot_routing_bar: HBoxContainer = null  # Routing buttons row
# Loot panel grid refs for multi-zone D-pad navigation
var _loot_drops_grid: GridContainer = null
var _loot_shop_grid: GridContainer = null
var _loot_hero_grids: Array = []
var _loot_btn_row: HBoxContainer = null
var _loot_swap_mode: bool = false  # True when in swap mode for a hero bag
var _loot_swap_hero_id: String = ""  # Hero ID for active swap
var _loot_swap_acq_index: int = -1  # Pending acq index for swap
var _loot_confirm_overlay: CanvasLayer = null  # Confirmation overlay for slot replacement

# Hold-to-discard state
const DISCARD_HOLD_TIME := 1.5
var _loot_discard_btn: Button = null
var _loot_hold_container: Control = null
var _loot_hold_bar_fill: ColorRect = null
var _is_holding_discard: bool = false
var _discard_hold_time: float = 0.0

# Loot panel resize state
var _loot_resizing: bool = false
var _loot_resize_edge: int = 0  # bitmask: 1=left, 2=right, 4=top, 8=bottom
var _loot_resize_start_pos: Vector2 = Vector2.ZERO
var _loot_resize_start_size: Vector2 = Vector2.ZERO
var _loot_resize_start_panel_pos: Vector2 = Vector2.ZERO
# Loot panel drag state
var _loot_dragging: bool = false
var _loot_drag_offset: Vector2 = Vector2.ZERO

# XP summary state (captured before loot panel)
var _pending_xp_results: Dictionary = {}
var _pending_xp_amount: int = 0
const LOOT_RESIZE_MARGIN := 8
const LOOT_PANEL_MIN_SIZE := Vector2(460, 320)
const LOOT_PANEL_MAX_SIZE := Vector2(1100, 800)

# Status UI v1.6: Unit display references for targeted refresh
var _unit_displays: Dictionary = {}  # unit_id -> Control (unit display container)

# Status UI v1.7: Direct badge row mapping for efficient refresh (status + buff rows)
# Format: unit_id -> { "status_row": HBoxContainer, "buff_row": HBoxContainer }
var _unit_badge_rows: Dictionary = {}

# Status UI v1.6.4: Icon cache to avoid repeated ResourceLoader lookups
var _status_icon_cache: Dictionary = {}  # ui_icon_path (String) -> Texture2D|null

# Hero Card Improvements: HP label overlay, turn counter, stat labels
var _unit_hp_labels: Dictionary = {}  # unit_id -> Label (HP numbers inside ProgressBar)
var _unit_turn_labels: Dictionary = {}  # unit_id -> Label (turn counter for player units)
var _unit_stat_labels: Dictionary = {}  # unit_id -> { stat_key: Label } (ATK/DEF/SPD row)

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
var _active_pill_tween: Tween = null  # v2.1: Active pill border pulse
var _pinned_tooltip_panel: PanelContainer = null  # v2.1: Ctrl+Click pinned tooltip

# v2.0: Hero input highlight colors (brighter and more visible)
const HERO_INPUT_HIGHLIGHT_COLOR: Color = Color(1.0, 0.9, 0.2, 0.5)  # Bright golden yellow
const HERO_INPUT_HIGHLIGHT_PULSE_MIN: Color = Color(1.0, 0.85, 0.1, 0.35)  # Dimmer pulse
const HERO_INPUT_HIGHLIGHT_PULSE_MAX: Color = Color(1.0, 0.95, 0.3, 0.65)  # Brighter pulse
const NORMAL_HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.0, 0.25)  # Original subtle gold tint
const ACTIVE_HIGHLIGHT_COLOR: Color = Color(1.0, 0.6, 0.1, 0.45)  # v2.1: Enemy/auto turn highlight
const ACTIVE_PILL_BORDER_MIN: Color = Color(1.0, 0.80, 0.3, 0.85)
const ACTIVE_PILL_BORDER_MAX: Color = Color(1.0, 1.00, 0.9, 1.0)

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
	"crit": Color.HOT_PINK,
	"status_expire": Color(0.78, 0.78, 0.78, 1.0)  # Muted gray for expired statuses
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

var _action_panel: PanelContainer = null
var _btn_basic: Button = null
var _btn_ability_a: Button = null
var _btn_ability_b: Button = null
var _btn_pass: Button = null
var _btn_cancel: Button = null
var _action_label: Label = null  # Shows "Action 1/3:"
var _equip_row: HBoxContainer = null  # Row 2: equipment ability buttons
var _btn_equip_0: Button = null  # Equipment ability 0
var _btn_equip_1: Button = null  # Equipment ability 1

var _target_selection_active: bool = false
var _valid_target_ids: Array = []
var _target_highlights: Dictionary = {}  # unit_id -> ColorRect

var _btn_use_item: Button = null
var _item_select_overlay: CanvasLayer = null  # Consumable selection popup for Use Item
var _combat_consumable_picker: CanvasLayer = null  # Hero picker after selecting consumable
var _pending_combat_consumable_id: String = ""  # Item ID pending hero picker choice
var _pending_combat_consumable_hero_id: String = ""  # Source hero ID for pending consumable
var _consumable_popup: PopupMenu = null
var _stats_window: Window = null  # Floating stats window
var _stats_window_hero_id: String = ""  # Hero ID for stats window refresh
var _stats_window_vbox: VBoxContainer = null  # Reference for auto-update
var _inspect_overlay: CanvasLayer = null  # Right-click stat inspection overlay
var _inspect_unit_id: String = ""  # Unit being inspected
var _auto_step_pending: bool = false  # Guard against concurrent auto-steps
var _current_input_unit: CombatUnit = null  # Current unit awaiting player input (for tooltips)

# Auto mode deferred selection state
var _auto_pending_targets: Array = []  # Valid targets for deferred auto-selection


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


## Override PanelContainer theme on all grid cells so empty cells are transparent.
func _clear_cell_backgrounds() -> void:
	var transparent_style = StyleBoxFlat.new()
	transparent_style.bg_color = Color(0, 0, 0, 0)
	transparent_style.set_border_width_all(0)

	for team in ["party", "enemy"]:
		var grid_name = "PartyGrid" if team == "party" else "EnemyGrid"
		var row_prefix = "PartyRow" if team == "party" else "EnemyRow"
		for ui_row in range(GRID_ROWS):
			var row_node = battlefield.get_node_or_null("%s/%s_%d" % [grid_name, row_prefix, ui_row])
			if row_node == null:
				continue
			for ui_col in range(GRID_COLS):
				var cell = row_node.get_node_or_null("Cell_c%d" % ui_col) as PanelContainer
				if cell != null:
					cell.add_theme_stylebox_override("panel", transparent_style)


## Create an empty cell placeholder (subtle visual for empty cells).
func _create_empty_slot_placeholder() -> Control:
	var placeholder = ColorRect.new()
	placeholder.name = "EmptyPlaceholder"
	placeholder.color = Color(0.15, 0.13, 0.11, 0.2)  # Subtle warm tint
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

	# Populate region palette before UI building
	_region_palette = RegionTheme.get_palette_for_current_region()

	# Apply background art (falls back to region-tinted ColorRect if image not found)
	var region_num: int = GameContext.get_current_region()
	BackgroundManager.apply_background(self, "dungeon", "R%d" % region_num)

	# Theme root background and top bar per region (only if still ColorRect)
	var bg_node = get_node_or_null("Background")
	if bg_node and bg_node is ColorRect:
		var dark: Color = _region_palette.get("bg_dark", Color(0.10, 0.09, 0.08, 1))
		bg_node.color = Color(dark.r * 0.7, dark.g * 0.7, dark.b * 0.7, 1.0)
	var topbar_bg = get_node_or_null("TopBar/TopBarBG")
	if topbar_bg and topbar_bg is ColorRect:
		topbar_bg.color = _region_palette.get("title_bar", Color(0.15, 0.13, 0.11, 0.95))

	# Connect button signals
	step_button.pressed.connect(_on_step_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	auto_button.tooltip_text = "Auto-battle: heroes use basic attacks only. Abilities are not used and targeting may not be optimal."
	reset_button.pressed.connect(_on_reset_pressed)

	# Attack Line v1: Create overlay layer for action lines
	_create_attack_line_layer()

	# Make grid cells transparent so empty PanelContainers don't show themed rectangles
	_clear_cell_backgrounds()

	# Tutorial on first combat (non-blocking — spotlight turn order + action panel)
	var combat_tut_targets: Dictionary = {}
	if _timeline_panel != null:
		combat_tut_targets["turn_order"] = _timeline_panel
	if _action_panel != null:
		combat_tut_targets["action_panel"] = _action_panel
	TutorialOverlay.try_show(self, "tutorial_first_combat", combat_tut_targets)

	# Start initial encounter
	_start_encounter()


func _process(delta: float) -> void:
	# Hold-to-discard timer for loot panel
	if _is_holding_discard:
		_discard_hold_time += delta
		var ratio: float = clampf(_discard_hold_time / DISCARD_HOLD_TIME, 0.0, 1.0)
		if _loot_hold_bar_fill != null:
			_loot_hold_bar_fill.anchor_right = ratio
		if _discard_hold_time >= DISCARD_HOLD_TIME:
			_is_holding_discard = false
			_discard_hold_time = 0.0
			if _loot_hold_container != null:
				_loot_hold_container.visible = false
			_on_loot_discard_all()

	# Null safety: _combat_controller may be null during initialization or after queue_free
	if _combat_controller == null:
		return

	# Stall recovery: if awaiting player input but action panel is hidden and not in target
	# selection or auto mode, re-show panel after a brief delay to prevent combat lock
	if _combat_controller.is_awaiting_player_input() and not _is_auto_running and not _target_selection_active:
		if _action_panel != null and not _action_panel.visible and not _combat_controller.is_combat_over():
			_stall_recovery_timer += delta
			if _stall_recovery_timer >= 0.5:
				push_warning("[UI] Stall recovery: action panel hidden while awaiting input — force showing")
				_action_panel.visible = true
				_stall_recovery_timer = 0.0
		else:
			_stall_recovery_timer = 0.0
	else:
		_stall_recovery_timer = 0.0

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
		SceneTransition.fade_to("res://Game/Boot/game_boot.tscn")
		return

	# Clear previous state
	if _combat_controller != null:
		_combat_controller.queue_free()

	_is_auto_running = false
	_auto_timer = 0.0
	_auto_step_pending = false  # Reset auto-step guard
	_auto_pending_targets.clear()  # Clear any pending auto-selection targets
	_stop_hero_input_highlight()  # Ensure tween is stopped before encounter reset

	# Re-enable combat buttons for new encounter
	auto_button.text = "Auto"
	auto_button.disabled = false
	step_button.disabled = false

	# Clear log
	combat_log.clear()
	_log("[b]--- Combat Started ---[/b]")

	# SFX: Combat start sound + switch to combat BGM
	UIAudio.play_sfx("combat_start")
	var is_boss: bool = GameContext.is_boss_room() if GameContext.has_method("is_boss_room") else false
	UIAudio.play_bgm("combat_boss" if is_boss else "combat_normal")

	# Boss entry cutscene (first time only, flag-gated)
	if is_boss:
		var entry_player = BossCutsceneManager.try_show(self, "boss_entry")
		if entry_player != null:
			await entry_player.cutscene_finished

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
	TelemetryManager.hook_combat(_combat_controller)

	# v1.9B: Initialize timeline and log overlay UI
	_create_v19b_ui()

	# Player Actions v1: Create action panel
	_create_action_panel()

	# Feature J: Shopkeeper bag display (above action panel)
	_create_shopkeeper_bag_display()

	# Hero bag display (above shopkeeper bag, shows active hero's items)
	_create_hero_bag_display()

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
	# Side quest mini-dungeon: use SideQuestSystem enemy generation
	if SideQuestSystem.is_in_mini_dungeon():
		var md_state: Dictionary = GameContext.mini_dungeon_state
		var md_enemies: Array = SideQuestSystem.get_mini_dungeon_enemies(rng)
		return {
			"enemies": md_enemies,
			"dungeon_id": "",
			"floor": md_state.get("fight_index", 0) + 1,
			"floor_count": md_state.get("total_fights", 1),
			"is_boss": false,
			"boss_id": ""
		}

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

	# Boss floor: spawn boss only (supports alt_boss_id for randomized boss)
	if is_boss and dungeon.boss_id != "":
		var actual_boss: String = dungeon.boss_id
		var alt_boss: String = dungeon.alt_boss_id
		if alt_boss != "" and rng.randf() < 0.5:
			actual_boss = alt_boss
		print("[Encounter] dungeon=%s floor=%d/%d room=%d/%d enemies=[%s] boss=true elite=false" % [
			dungeon_id, floor_num, max_floor, room_idx + 1, rooms_per_floor, actual_boss
		])
		return {
			"enemies": [actual_boss],
			"dungeon_id": dungeon_id,
			"floor": floor_num,
			"floor_count": max_floor,
			"is_boss": true,
			"boss_id": actual_boss
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
	if floor_index < 2:  # T1 monsters only on floors 1-2 (index 0-1)
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

	# Scale enemy count and tier2 chance by floor depth
	var enemy_count: int = 2
	var tier2_chance: float = 20.0
	match floor_index:
		0:
			enemy_count = 2
			tier2_chance = 20.0
		1:
			enemy_count = rng.randi_range(2, 3)
			tier2_chance = 30.0
		2:
			enemy_count = 3
			tier2_chance = 100.0  # All T2 on floor 3
		3, _:
			enemy_count = rng.randi_range(3, 4)
			tier2_chance = 100.0  # All T2 on floor 4+

	var enemies: Array = []
	for i in range(enemy_count):
		var roll = rng.randf() * 100.0
		var pool = tier1_pool if roll >= tier2_chance else tier2_pool
		if pool.is_empty():
			pool = tier2_pool if tier2_pool.size() > 0 else (tier1_pool if tier1_pool.size() > 0 else ["goblin"])
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
	_unit_hp_labels.clear()  # Hero Card: Clear HP label references
	_unit_turn_labels.clear()  # Hero Card: Clear turn counter references
	_unit_stat_labels.clear()  # Hero Card: Clear stat label references

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
	# Compact portrait card: portrait (left) + name/HP/badges (right)
	var wrapper = MarginContainer.new()
	wrapper.name = "UnitWrapper_%s" % unit_data["id"]
	wrapper.add_theme_constant_override("margin_left", 3)
	wrapper.add_theme_constant_override("margin_right", 3)
	wrapper.add_theme_constant_override("margin_top", 3)
	wrapper.add_theme_constant_override("margin_bottom", 3)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.set_meta("unit_id", unit_data["id"])

	# Highlight frame (ColorRect behind content)
	var highlight_frame = ColorRect.new()
	highlight_frame.name = "HighlightFrame"
	highlight_frame.color = Color(1.0, 0.85, 0.0, 0.25)
	highlight_frame.visible = false
	highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	highlight_frame.offset_left = -3
	highlight_frame.offset_right = 3
	highlight_frame.offset_top = -3
	highlight_frame.offset_bottom = 3
	wrapper.add_child(highlight_frame)

	# Main layout: portrait left, info right
	var card_hbox = HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 6)
	card_hbox.name = "UnitContent_%s" % unit_data["id"]

	# Portrait (48x48) — also serves as click target for target selection + quick attack
	var portrait_rect = TextureRect.new()
	portrait_rect.name = "Portrait"
	portrait_rect.custom_minimum_size = Vector2(48, 48)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_rect.gui_input.connect(_on_unit_left_click_input.bind(unit_data["id"]))
	var portrait_path = unit_data.get("portrait_path", "")
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex != null:
			portrait_rect.texture = tex
	if not unit_data["is_alive"]:
		portrait_rect.modulate = Color(0.55, 0.55, 0.55, 1)
	card_hbox.add_child(portrait_rect)

	# Right side: name, class, HP bar, badges
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 1)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name label (enemies get attack type prefix + numbering)
	var display_name = unit_data["name"]
	if unit_data["team"] == "enemy":
		var uid = unit_data.get("id", "")
		var atk_type: String = unit_data.get("attack_type", "melee")
		var type_prefix: String = "R" if atk_type == "ranged" else "M"
		if uid.begins_with("enemy_"):
			var enemy_num = int(uid.replace("enemy_", "")) + 1
			display_name = "[%s] %s #%d" % [type_prefix, unit_data["name"], enemy_num]
		else:
			display_name = "[%s] %s" % [type_prefix, display_name]

	var name_label = Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	if unit_data["is_alive"]:
		name_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	info_vbox.add_child(name_label)

	# Class label (heroes only)
	if unit_data["team"] == "player" and unit_data.get("class_id", "") != "":
		var cls_name = unit_data["class_id"].capitalize()
		var cls_data = DataRegistry.get_class_data(unit_data["class_id"])
		if cls_data != null and cls_data.display_name != "":
			cls_name = cls_data.display_name
		var class_label = Label.new()
		class_label.text = cls_name
		class_label.add_theme_font_size_override("font_size", GameContext.fs(12))
		class_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		info_vbox.add_child(class_label)

	# D2: Turn counter (player units only)
	if unit_data["team"] == "player":
		var turn_label = Label.new()
		turn_label.name = "TurnCounter"
		turn_label.text = ""
		turn_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		turn_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6, 0.7))
		turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vbox.add_child(turn_label)
		_unit_turn_labels[unit_data["id"]] = turn_label

	# D3: Basic stats row - ATK/DEF/SPD with tooltips (all units)
	var stats_hbox = HBoxContainer.new()
	stats_hbox.name = "StatsRow"
	stats_hbox.add_theme_constant_override("separation", 8)
	var stat_defs: Array = [
		{"key": "attack", "label": "ATK", "color": Color(0.9, 0.6, 0.3)},
		{"key": "defense", "label": "DEF", "color": Color(0.4, 0.7, 0.9)},
		{"key": "speed", "label": "SPD", "color": Color(0.7, 0.9, 0.5)}
	]
	var unit_stat_labels: Dictionary = {}
	for stat_def in stat_defs:
		var stat_label = Label.new()
		var val: int = int(unit_data.get(stat_def.key, 0))
		stat_label.text = "%s:%d" % [stat_def.label, val]
		stat_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		stat_label.add_theme_color_override("font_color", stat_def.color)
		stat_label.mouse_filter = Control.MOUSE_FILTER_STOP
		stat_label.tooltip_text = _build_combat_card_stat_tooltip(stat_def.key, stat_def.label, unit_data)
		stats_hbox.add_child(stat_label)
		unit_stat_labels[stat_def.key] = stat_label
	info_vbox.add_child(stats_hbox)
	_unit_stat_labels[unit_data["id"]] = unit_stat_labels

	# Secondary stats row (enemies only, compact colored badges for non-zero stats)
	if unit_data["team"] == "enemy":
		var sec_stat_defs: Array = [
			{"key": "crit_chance", "label": "CRIT", "color": Color(1.0, 0.7, 0.3), "suffix": "%"},
			{"key": "evasion", "label": "EVD", "color": Color(0.6, 0.9, 0.6), "suffix": "%"},
			{"key": "resist", "label": "RES", "color": Color(0.7, 0.5, 0.9), "suffix": ""},
			{"key": "thorns", "label": "THN", "color": Color(0.8, 0.4, 0.4), "suffix": ""},
			{"key": "armor_penetration", "label": "PEN", "color": Color(0.9, 0.6, 0.5), "suffix": ""},
			{"key": "life_steal", "label": "LSTL", "color": Color(0.8, 0.3, 0.3), "suffix": "%"},
		]
		var has_secondary := false
		for sdef in sec_stat_defs:
			if int(unit_data.get(sdef.key, 0)) > 0:
				has_secondary = true
				break
		if has_secondary:
			var sec_hbox = HBoxContainer.new()
			sec_hbox.name = "SecondaryStatsRow"
			sec_hbox.add_theme_constant_override("separation", 6)
			for sdef in sec_stat_defs:
				var sval: int = int(unit_data.get(sdef.key, 0))
				if sval > 0:
					var slbl = Label.new()
					slbl.text = "%s:%d%s" % [sdef.label, sval, sdef.suffix]
					slbl.add_theme_font_size_override("font_size", GameContext.fs(10))
					slbl.add_theme_color_override("font_color", sdef.color)
					slbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
					sec_hbox.add_child(slbl)
			info_vbox.add_child(sec_hbox)

	# HP bar (ProgressBar with custom styling)
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 14
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.max_value = unit_data["max_hp"]
	hp_bar.value = unit_data["hp"]
	hp_bar.show_percentage = false
	hp_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	hp_bar.tooltip_text = _build_hp_tooltip(unit_data)

	# Style: dark background
	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	hp_bg.corner_radius_top_left = 2
	hp_bg.corner_radius_top_right = 2
	hp_bg.corner_radius_bottom_left = 2
	hp_bg.corner_radius_bottom_right = 2
	hp_bg.content_margin_left = 0
	hp_bg.content_margin_right = 0
	hp_bg.content_margin_top = 0
	hp_bg.content_margin_bottom = 0
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	# Style: colored fill based on HP percentage
	var hp_pct: float = float(unit_data["hp"]) / float(unit_data["max_hp"]) if unit_data["max_hp"] > 0 else 0.0
	var fill_color: Color = Color(0.2, 0.75, 0.2) if hp_pct > 0.5 else (Color(0.85, 0.65, 0.1) if hp_pct > 0.25 else Color(0.85, 0.2, 0.2))
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = fill_color
	hp_fill.corner_radius_top_left = 2
	hp_fill.corner_radius_top_right = 2
	hp_fill.corner_radius_bottom_left = 2
	hp_fill.corner_radius_bottom_right = 2
	hp_fill.content_margin_left = 0
	hp_fill.content_margin_right = 0
	hp_fill.content_margin_top = 0
	hp_fill.content_margin_bottom = 0
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	info_vbox.add_child(hp_bar)

	# D1: HP numbers label inside HP bar
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	var shield_val: int = int(unit_data.get("shield_hp", 0))
	if shield_val > 0:
		hp_label.text = "%d/%d +%d" % [int(unit_data["hp"]), int(unit_data["max_hp"]), shield_val]
	else:
		hp_label.text = "%d/%d" % [int(unit_data["hp"]), int(unit_data["max_hp"])]
	hp_label.add_theme_font_size_override("font_size", GameContext.fs(11))
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(hp_label)
	_unit_hp_labels[unit_data["id"]] = hp_label

	# Shield bar (thin cyan bar below HP bar, visible when shielded)
	var shield_bar_val: int = int(unit_data.get("shield_hp", 0))
	if shield_bar_val > 0:
		var shield_bar = ProgressBar.new()
		shield_bar.custom_minimum_size.y = 3
		shield_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shield_bar.show_percentage = false
		shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shield_bar.max_value = maxi(1, int(unit_data.get("max_hp", 100)))
		shield_bar.value = shield_bar_val
		var s_bg = StyleBoxFlat.new()
		s_bg.bg_color = Color(0.12, 0.12, 0.12, 0.5)
		s_bg.corner_radius_top_left = 1
		s_bg.corner_radius_top_right = 1
		s_bg.corner_radius_bottom_left = 1
		s_bg.corner_radius_bottom_right = 1
		shield_bar.add_theme_stylebox_override("background", s_bg)
		var s_fill = StyleBoxFlat.new()
		s_fill.bg_color = Color(0.3, 0.7, 1.0, 0.9)
		s_fill.corner_radius_top_left = 1
		s_fill.corner_radius_top_right = 1
		s_fill.corner_radius_bottom_left = 1
		s_fill.corner_radius_bottom_right = 1
		shield_bar.add_theme_stylebox_override("fill", s_fill)
		info_vbox.add_child(shield_bar)

	# Status badge row (pooled)
	var unit_id = unit_data["id"]
	var status_badge_row = HBoxContainer.new()
	status_badge_row.name = "StatusBadgeRow"
	status_badge_row.add_theme_constant_override("separation", 3)
	_populate_status_badges(status_badge_row, unit_data.get("active_statuses_v1", []), unit_id)
	info_vbox.add_child(status_badge_row)

	# Buff badge row (pooled)
	var buff_badge_row = HBoxContainer.new()
	buff_badge_row.name = "BuffBadgeRow"
	buff_badge_row.add_theme_constant_override("separation", 3)
	_populate_buff_badges(buff_badge_row, unit_data.get("active_buffs_v1", []), unit_id)
	info_vbox.add_child(buff_badge_row)

	# Register badge rows for live updates
	_unit_badge_rows[unit_data["id"]] = {
		"status_row": status_badge_row,
		"buff_row": buff_badge_row
	}

	# Inspect button — small "i" button for stat inspection overlay
	var inspect_btn = Button.new()
	inspect_btn.name = "InspectBtn"
	inspect_btn.text = "i"
	inspect_btn.add_theme_font_size_override("font_size", GameContext.fs(11))
	inspect_btn.custom_minimum_size = Vector2(22, 0)
	inspect_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspect_btn.tooltip_text = "Inspect unit stats"
	inspect_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	inspect_btn.pressed.connect(_show_stat_inspection.bind(unit_data["id"]))
	card_hbox.add_child(inspect_btn)

	card_hbox.add_child(info_vbox)

	wrapper.add_child(card_hbox)

	return wrapper


## Build a rich tooltip for a compact unit card showing all stats, abilities, etc.
func _build_unit_card_tooltip(unit_data: Dictionary) -> String:
	var lines: Array = []
	var display_name = unit_data["name"]

	# Name + class + level
	if unit_data["team"] == "player":
		var cls_name = ""
		if unit_data.get("class_id", "") != "":
			var cls_data = DataRegistry.get_class_data(unit_data["class_id"])
			cls_name = cls_data.display_name if cls_data != null and cls_data.display_name != "" else unit_data["class_id"].capitalize()

		var hero_id = unit_data.get("source_id", unit_data["id"])
		var hero_level = 1
		if GameContext.has_method("get_hero_effective_stats"):
			var stats = GameContext.get_hero_effective_stats(hero_id)
			hero_level = stats.get("level", 1)

		lines.append("%s (%s) Lv%d" % [display_name, cls_name, hero_level])
	else:
		var uid = unit_data.get("id", "")
		if uid.begins_with("enemy_"):
			var enemy_num = int(uid.replace("enemy_", "")) + 1
			display_name = "%s #%d" % [unit_data["name"], enemy_num]
		lines.append(display_name)

	# HP
	lines.append("HP: %d/%d" % [unit_data["hp"], unit_data["max_hp"]])

	# Stats
	var atk = unit_data.get("attack", 0)
	var base_atk = unit_data.get("base_attack", 0)
	var def_val = unit_data.get("defense", 0)
	var base_def = unit_data.get("base_defense", 0)
	var spd = unit_data.get("speed", 0)
	var base_spd = unit_data.get("base_speed", 0)

	var atk_str = "ATK: %d" % atk
	if atk != base_atk:
		atk_str += " (%+d)" % (atk - base_atk)
	var def_str = "DEF: %d" % def_val
	if def_val != base_def:
		def_str += " (%+d)" % (def_val - base_def)
	var spd_str = "SPD: %d" % spd
	if spd != base_spd:
		spd_str += " (%+d)" % (spd - base_spd)
	lines.append("%s | %s | %s" % [atk_str, def_str, spd_str])

	# New combat stats (only show if > 0)
	var extra_stat_parts: Array[String] = []
	var crit_val = int(unit_data.get("crit_chance", 0))
	if crit_val > 0: extra_stat_parts.append("CRIT:%d%%" % crit_val)
	var evd_val = int(unit_data.get("evasion", 0))
	if evd_val > 0: extra_stat_parts.append("EVD:%d%%" % evd_val)
	var res_val = int(unit_data.get("resist", 0))
	if res_val > 0: extra_stat_parts.append("RES:%d" % res_val)
	var thn_val = int(unit_data.get("thorns", 0))
	if thn_val > 0: extra_stat_parts.append("THN:%d" % thn_val)
	var pen_val = int(unit_data.get("armor_penetration", 0))
	if pen_val > 0: extra_stat_parts.append("PEN:%d" % pen_val)
	var ls_val = int(unit_data.get("life_steal", 0))
	if ls_val > 0: extra_stat_parts.append("LSTL:%d%%" % ls_val)
	if not extra_stat_parts.is_empty():
		lines.append(" | ".join(extra_stat_parts))

	# Abilities (all units)
	var tt_is_hero: bool = unit_data["team"] == "player"
	var tt_hero_level := 1
	if tt_is_hero:
		var tt_hero_id: String = unit_data.get("source_id", unit_data["id"])
		if GameContext.has_method("get_hero_effective_stats"):
			var tt_stats = GameContext.get_hero_effective_stats(tt_hero_id)
			tt_hero_level = tt_stats.get("level", 1)

	var ability_a_id = unit_data.get("ability_a_id", "")
	if ability_a_id != "":
		var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
		var a_name = ability_a.display_name if ability_a else ability_a_id.replace("_", " ").capitalize()
		if tt_is_hero:
			if GameContext.is_ability_slot_unlocked("ability_a", tt_hero_level):
				var cd_a = unit_data.get("ability_a_cooldown", 0)
				var cd_str = " (CD: %d)" % cd_a if cd_a > 0 else " (Ready)"
				lines.append("[A] %s%s" % [a_name, cd_str])
				var a_desc: String = ability_a.description if ability_a else ""
				if a_desc != "":
					lines.append("  %s" % a_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_a", 5)
				lines.append("[A] %s (Lv %d)" % [a_name, req_lv])
		else:
			var cd_a = unit_data.get("ability_a_cooldown", 0)
			var cd_str = " (CD: %d)" % cd_a if cd_a > 0 else " (Ready)"
			lines.append("[A] %s%s" % [a_name, cd_str])
			var a_desc: String = ability_a.description if ability_a else ""
			if a_desc != "":
				lines.append("  %s" % a_desc)

	var ability_b_id = unit_data.get("ability_b_id", "")
	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name = ability_b.display_name if ability_b else ability_b_id.replace("_", " ").capitalize()
		if tt_is_hero:
			if GameContext.is_ability_slot_unlocked("ability_b", tt_hero_level):
				var cd_b = unit_data.get("ability_b_cooldown", 0)
				var cd_str = " (CD: %d)" % cd_b if cd_b > 0 else " (Ready)"
				lines.append("[B] %s%s" % [b_name, cd_str])
				var b_desc: String = ability_b.description if ability_b else ""
				if b_desc != "":
					lines.append("  %s" % b_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_b", 25)
				lines.append("[B] %s (Lv %d)" % [b_name, req_lv])
		else:
			var cd_b = unit_data.get("ability_b_cooldown", 0)
			var cd_str = " (CD: %d)" % cd_b if cd_b > 0 else " (Ready)"
			lines.append("[B] %s%s" % [b_name, cd_str])
			var b_desc: String = ability_b.description if ability_b else ""
			if b_desc != "":
				lines.append("  %s" % b_desc)

	# Passives (all units)
	var passive_a_id = unit_data.get("passive_a_id", "")
	if passive_a_id != "":
		var passive_a = DataRegistry.get_passive(passive_a_id) if DataRegistry.has_method("get_passive") else null
		var pa_name = passive_a.display_name if passive_a else passive_a_id.replace("_", " ").capitalize()
		if tt_is_hero:
			if GameContext.is_ability_slot_unlocked("passive_a", tt_hero_level):
				lines.append("[P] %s" % pa_name)
				var pa_desc: String = passive_a.description if passive_a else ""
				if pa_desc != "":
					lines.append("  %s" % pa_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_a", 15)
				lines.append("[P] %s (Lv %d)" % [pa_name, req_lv])
		else:
			lines.append("[P] %s" % pa_name)
			var pa_desc: String = passive_a.description if passive_a else ""
			if pa_desc != "":
				lines.append("  %s" % pa_desc)

	var passive_b_id = unit_data.get("passive_b_id", "")
	if passive_b_id != "":
		var passive_b = DataRegistry.get_passive(passive_b_id) if DataRegistry.has_method("get_passive") else null
		var pb_name = passive_b.display_name if passive_b else passive_b_id.replace("_", " ").capitalize()
		if tt_is_hero:
			if GameContext.is_ability_slot_unlocked("passive_b", tt_hero_level):
				lines.append("[P] %s" % pb_name)
				var pb_desc: String = passive_b.description if passive_b else ""
				if pb_desc != "":
					lines.append("  %s" % pb_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_b", 40)
				lines.append("[P] %s (Lv %d)" % [pb_name, req_lv])
		else:
			lines.append("[P] %s" % pb_name)
			var pb_desc: String = passive_b.description if passive_b else ""
			if pb_desc != "":
				lines.append("  %s" % pb_desc)

	# Bag (heroes only)
	if tt_is_hero:
		var hero_id = unit_data.get("source_id", unit_data["id"])
		var bag_summary = GameContext.get_hero_bag_summary(hero_id)
		lines.append("BAG: %s" % bag_summary)

	if not unit_data["is_alive"]:
		lines.append("[DEAD]")

	lines.append("")
	lines.append("Ctrl+Click to pin")
	return "\n".join(lines)


## Build a tooltip for a single combat stat (ATK/DEF/SPD) on the hero card stats row.
func _build_hp_tooltip(unit_data: Dictionary) -> String:
	var lines: Array = []
	lines.append("HP (Hit Points)")
	lines.append("Hero is defeated at 0 HP.")
	lines.append("Restored by healing effects and potions.")
	lines.append("")

	var max_hp: int = int(unit_data.get("max_hp", 0))
	var cur_hp: int = int(unit_data.get("hp", 0))
	var base_hp: int = int(unit_data.get("base_hp", max_hp))
	var bonus: int = max_hp - base_hp

	lines.append("Current: %d / %d" % [cur_hp, max_hp])
	lines.append("Base: %d" % base_hp)
	if bonus != 0:
		lines.append("Bonuses: %+d" % bonus)
	var shield_val: int = int(unit_data.get("shield_hp", 0))
	if shield_val > 0:
		var shield_rounds: int = int(unit_data.get("shield_remaining_rounds", 0))
		lines.append("")
		lines.append("Shield: %d HP (%d rounds remaining)" % [shield_val, shield_rounds])
		lines.append("Absorbs damage before HP is reduced.")
	return "\n".join(lines)


func _build_combat_card_stat_tooltip(stat_key: String, stat_display: String, unit_data: Dictionary) -> String:
	var descriptions: Dictionary = {
		"attack": "ATK (Attack Power)\nDetermines physical damage dealt.\nDamage = max(1, ATK - target DEF)",
		"defense": "DEF (Defense)\nReduces incoming physical damage.\nDamage = max(1, attacker ATK - DEF)",
		"speed": "SPD (Speed)\nDetermines turn order each round.\nHigher speed acts first.\n10+ = 2 actions, 20+ = 3 actions"
	}
	var lines: Array = []
	lines.append(descriptions.get(stat_key, stat_display))
	lines.append("")

	var eff_val: int = int(unit_data.get(stat_key, 0))
	var base_val: int = int(unit_data.get("base_" + stat_key, 0))
	var bonus: int = eff_val - base_val

	lines.append("Base: %d" % base_val)
	if bonus != 0:
		lines.append("Bonuses: %+d" % bonus)
	lines.append("Total: %d" % eff_val)

	return "\n".join(lines)


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
		container.mouse_filter = Control.MOUSE_FILTER_PASS

		var icon_rect = TextureRect.new()
		icon_rect.texture = icon_texture
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(16, 16)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(icon_rect)

		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", GameContext.fs(12))
		label.add_theme_color_override("font_color", badge_color)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(label)

		container.tooltip_text = tooltip
		badge = container
	else:
		# Text-only badge (fallback)
		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", GameContext.fs(12))
		label.add_theme_color_override("font_color", badge_color)
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_PASS
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
		label.add_theme_font_size_override("font_size", GameContext.fs(12))
		label.add_theme_color_override("font_color", badge_color)
		container.add_child(label)
		container.tooltip_text = tooltip
		badge = container
	else:
		var label = Label.new()
		label.text = badge_text
		label.add_theme_font_size_override("font_size", GameContext.fs(12))
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

	var cl: int = GameContext.challenge_level
	if cl > 0:
		top_bar.text = "Round %d | Turn: %s | Challenge: %d" % [turn_info["round"], unit_name, cl]
	else:
		top_bar.text = "Round %d | Current Turn: %s" % [turn_info["round"], unit_name]


func _update_dungeon_progress_label() -> void:
	# Mini-dungeon: show fight progress instead of dungeon progress
	if SideQuestSystem.is_in_mini_dungeon():
		var md_state: Dictionary = GameContext.mini_dungeon_state
		var fight: int = md_state.get("fight_index", 0) + 1
		var total: int = md_state.get("total_fights", 1)
		var final_tag: String = " [FINAL]" if md_state.get("is_final_fight", false) else ""
		dungeon_progress_label.text = "Mini-Dungeon | Fight %d/%d%s" % [fight, total, final_tag]
		return

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
	if _combat_controller == null or _combat_controller.is_combat_over():
		return
	_step_turn()


func _on_auto_pressed() -> void:
	if _combat_controller == null or _combat_controller.is_combat_over():
		return
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


func _on_combat_ended(_result) -> void:
	_is_auto_running = false
	auto_button.text = "Auto"
	auto_button.disabled = true
	step_button.disabled = true
	_dismiss_pinned_tooltip()

	# v1.9A: Clear active unit highlight
	_set_active_unit("")

	# D2: Clear turn counter labels on combat end
	for uid in _unit_turn_labels.keys():
		var lbl = _unit_turn_labels[uid]
		if lbl != null and is_instance_valid(lbl):
			lbl.text = ""

	# v1.8: Emit sanity report at encounter end
	_emit_sanity_report_if_needed()

	# Diagnostic: trace loot popup conditions
	print("[CombatEnd] _result=%s is_null=%s" % [str(_result), str(_result == null)])
	if _result != null:
		print("[CombatEnd] outcome=%s is_victory=%s gold=%d items_dropped=%d" % [
			_result.get_outcome_string(),
			str(_result.is_victory),
			_result.gold_earned,
			_result.items_dropped.size()
		])
	print("[CombatEnd] pending_acquisitions=%d has_pending=%s" % [
		GameContext.get_all_pending_acquisitions().size(),
		str(GameContext.has_pending_acquisition())
	])

	# Award XP on victory (region-scaled: normal/elite/boss)
	if _result != null and _result.is_victory:
		var source: String = "combat_normal"
		if _result.is_boss_encounter:
			source = "combat_boss"
		elif GameContext.is_current_room_elite():
			source = "combat_elite"

		var xp_amount: int = GameContext.get_combat_xp(source)
		_pending_xp_results = GameContext.grant_party_xp(xp_amount, source)
		_pending_xp_amount = xp_amount

		# Side quest: track kills for active kill quests
		if _combat_controller != null:
			var defeated: Array = _combat_controller.get_defeated_enemy_ids()
			for enemy_id in defeated:
				SideQuestSystem.check_kill_progress(enemy_id)

	# Show loot panel on ANY victory (even with zero item drops, to display gold earned)
	var show_loot: bool = _result != null and _result.is_victory
	var show_defeat: bool = _result != null and not _result.is_victory
	print("[CombatEnd] show_loot=%s show_defeat=%s pending=%d gold=%d" % [
		str(show_loot), str(show_defeat),
		GameContext.get_all_pending_acquisitions().size(),
		_result.gold_earned if _result != null else 0])

	# SFX: Victory or defeat stinger
	if show_loot:
		UIAudio.play_sfx("extraction_success")
	elif show_defeat:
		UIAudio.play_sfx("dungeon_enter")  # somber defeat sting

	if show_loot:
		_loot_result = _result
		_show_loot_panel()
	elif show_defeat:
		# Boss defeat cutscene (repeatable, no flag gate)
		if _result != null and _result.is_boss_encounter:
			var defeat_player = BossCutsceneManager.try_show(self, "boss_defeat")
			if defeat_player != null:
				await defeat_player.cutscene_finished
		# DEFEAT — show defeat screen before returning to town
		_show_defeat_panel()
	else:
		# Draw or null result — auto-resolve and transition
		print("[CombatEnd] No result or draw — auto-resolving to stash and transitioning")
		GameContext.resolve_all_to_stash()
		_do_combat_transition()


## Transition to boot scene after combat ends.
func _do_combat_transition() -> void:
	if not _scene_transition_pending:
		_scene_transition_pending = true

		# Mini-dungeon: chain to next fight or return to town
		if SideQuestSystem.is_in_mini_dungeon():
			var has_more: bool = SideQuestSystem.advance_mini_dungeon()
			if has_more:
				print("[Flow] Mini-dungeon: advancing to next fight")
				await get_tree().create_timer(1.0).timeout
				_scene_transition_pending = false
				_start_encounter()
				return
			else:
				# All fights done — return to town
				print("[Flow] Mini-dungeon complete — returning to town")
				GameContext.set_phase(GameContext.GamePhase.TOWN_HUB)
				await get_tree().create_timer(1.5).timeout
				SceneTransition.fade_to("res://Game/Boot/game_boot.tscn")
				return

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
		SceneTransition.fade_to("res://Game/Boot/game_boot.tscn")


# ============================================================================
# LOOT PANEL — Route items to stash or hero bags
# ============================================================================

## Get XP progress within current level for a hero.
func _get_xp_progress(hero_id: String) -> Dictionary:
	return GameContext.get_hero_xp_progress(hero_id)


## Returns "+" if any entry in the bag has material stack room remaining.
func _bag_stack_room_indicator(bag: Array) -> String:
	for entry in bag:
		var eid: String = entry.get("item_id", "") if entry is Dictionary else entry.template_id if entry is ItemInstance else ""
		var stack_limit: int = GameContext.get_bag_stack_limit(eid)
		if stack_limit > 1:
			var eq: int = int(entry.get("qty", 1)) if entry is Dictionary else entry.quantity if entry is ItemInstance else 1
			if eq < stack_limit:
				return "+"
	return ""


## Show the loot routing panel as a CanvasLayer popup overlay.
## v2: Visual slot-based overlay with icon grids instead of text lists.
func _show_loot_panel() -> void:
	# Reset discard hold state (panel may be rebuilt via _refresh_loot_panel)
	_is_holding_discard = false
	_discard_hold_time = 0.0
	_loot_discard_btn = null
	_loot_hold_container = null
	_loot_hold_bar_fill = null

	print("[LootPanel] _show_loot_panel() ENTERED — pending=%d" % GameContext.get_all_pending_acquisitions().size())
	UIAudio.play_sfx("loot_appear")

	# Hide dead hero unit displays at end of battle
	for uid in _unit_displays.keys():
		var display = _unit_displays[uid]
		if _combat_controller != null:
			var cunit: CombatUnit = _combat_controller.get_unit_by_id(uid)
			if cunit != null and cunit.team == CombatUnit.Team.PLAYER and not cunit.is_alive:
				display.visible = false
				print("[LootPanel] Hiding dead hero display: %s (%s)" % [uid, cunit.display_name])

	# Auto-Loot: deposit all items automatically if enabled
	if GameContext.auto_loot:
		_auto_deposit_all_loot()
		if not GameContext.has_pending_acquisition():
			print("[LootPanel] Auto-Loot deposited everything — skipping loot panel")
			_do_combat_transition()
			return

	# Remove old overlay if exists
	if _loot_overlay != null and is_instance_valid(_loot_overlay):
		_loot_overlay.queue_free()
		_loot_overlay = null
		_loot_panel = null
		_loot_routing_bar = null
		_loot_drops_grid = null
		_loot_shop_grid = null
		_loot_hero_grids.clear()
		_loot_btn_row = null

	# Preserve swap state across panel rebuilds (set by _on_loot_swap_request)
	# Only clear swap state when NOT already in swap mode (i.e. fresh open)
	if not _loot_swap_mode:
		_loot_swap_hero_id = ""
		_loot_swap_acq_index = -1

	var pending = GameContext.get_all_pending_acquisitions()

	# CanvasLayer popup (layer 10) — stays above combat scene
	_loot_overlay = CanvasLayer.new()
	_loot_overlay.layer = 10
	add_child(_loot_overlay)

	# Dark backdrop — full-screen anchors with zero offsets for CanvasLayer children
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.set_offsets_preset(Control.PRESET_FULL_RECT)
	_loot_overlay.add_child(backdrop)

	# Popup panel — manually centered (no CenterContainer so resize can reposition)
	var panel_size: Vector2 = GameContext.loot_panel_size
	panel_size.x = clampf(panel_size.x, LOOT_PANEL_MIN_SIZE.x, LOOT_PANEL_MAX_SIZE.x)
	panel_size.y = clampf(panel_size.y, LOOT_PANEL_MIN_SIZE.y, LOOT_PANEL_MAX_SIZE.y)
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_pos: Vector2 = (viewport_size - panel_size) * 0.5

	_loot_panel = PanelContainer.new()
	_loot_panel.name = "LootPopup"
	_loot_panel.custom_minimum_size = panel_size
	_loot_panel.size = panel_size
	_loot_panel.position = panel_pos
	_loot_panel.focus_mode = Control.FOCUS_ALL
	_loot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_loot_panel.gui_input.connect(_on_loot_panel_gui_input)
	_loot_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(_region_palette.get("ui_tint", Color.WHITE)))
	_loot_overlay.add_child(_loot_panel)
	TutorialOverlay.try_show(self, "tutorial_loot_routing")

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.add_theme_constant_override("scroll_deadzone", 0)
	scroll.follow_focus = true
	_loot_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "LootVBox"
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Title ──
	var gold_earned = _loot_result.gold_earned if _loot_result != null else 0
	var title = Label.new()
	title.text = "COMBAT LOOT  (+%d gold)" % gold_earned
	title.add_theme_font_size_override("font_size", GameContext.fs(20))
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ── XP Summary ──
	if _pending_xp_amount > 0:
		var xp_header = Label.new()
		xp_header.text = "+%d XP" % _pending_xp_amount
		xp_header.add_theme_font_size_override("font_size", GameContext.fs(16))
		xp_header.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		xp_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(xp_header)

		for hero_id in GameContext.selected_party:
			# Skip dead heroes — they don't earn XP
			var hp_data = GameContext.get_hero_hp(hero_id)
			if not hp_data.is_empty() and int(hp_data.get("current", 1)) <= 0:
				continue

			var hero = GameContext.get_hero(hero_id)
			if hero.is_empty():
				continue
			var hero_name: String = hero.get("name", hero_id)
			var hero_level: int = int(hero.get("level", 1))
			var levels_gained: int = _pending_xp_results.get(hero_id, 0)
			var xp_progress: Dictionary = _get_xp_progress(hero_id)

			var hero_row = HBoxContainer.new()
			hero_row.add_theme_constant_override("separation", 8)
			vbox.add_child(hero_row)

			# Name + Level
			var name_lbl = Label.new()
			name_lbl.text = "%s  Lv%d" % [hero_name, hero_level]
			name_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
			name_lbl.custom_minimum_size = Vector2(120, 0)
			hero_row.add_child(name_lbl)

			# XP text (before progress bar)
			var xp_lbl = Label.new()
			xp_lbl.text = "%d/%d XP" % [xp_progress.current, xp_progress.needed]
			xp_lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
			xp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
			hero_row.add_child(xp_lbl)

			# XP progress bar
			var bar = ProgressBar.new()
			bar.custom_minimum_size = Vector2(140, 14)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.min_value = 0
			bar.max_value = xp_progress.needed
			bar.value = xp_progress.current
			bar.show_percentage = false
			var bar_bg_style = StyleBoxFlat.new()
			bar_bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
			bar_bg_style.corner_radius_top_left = 2
			bar_bg_style.corner_radius_top_right = 2
			bar_bg_style.corner_radius_bottom_left = 2
			bar_bg_style.corner_radius_bottom_right = 2
			bar.add_theme_stylebox_override("background", bar_bg_style)
			var bar_fill_style = StyleBoxFlat.new()
			bar_fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.9)
			bar_fill_style.corner_radius_top_left = 2
			bar_fill_style.corner_radius_top_right = 2
			bar_fill_style.corner_radius_bottom_left = 2
			bar_fill_style.corner_radius_bottom_right = 2
			bar.add_theme_stylebox_override("fill", bar_fill_style)
			hero_row.add_child(bar)

			# Level up badge (at end)
			if levels_gained > 0:
				var lvl_up = Label.new()
				lvl_up.text = "LEVEL UP!"
				lvl_up.add_theme_font_size_override("font_size", GameContext.fs(13))
				lvl_up.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				hero_row.add_child(lvl_up)

		var xp_sep = HSeparator.new()
		xp_sep.modulate = Color(0.55, 0.4, 0.25, 0.5)
		vbox.add_child(xp_sep)

	# ── Drops grid (48x48 icon slots) ──
	_loot_hero_grids.clear()
	if not pending.is_empty():
		var drops_label = Label.new()
		drops_label.text = "Drops:"
		drops_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		drops_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.55))
		vbox.add_child(drops_label)

		var drops_grid = GridContainer.new()
		drops_grid.columns = 8
		drops_grid.add_theme_constant_override("h_separation", 4)
		drops_grid.add_theme_constant_override("v_separation", 4)
		vbox.add_child(drops_grid)
		_loot_drops_grid = drops_grid

		for i in range(pending.size()):
			var slot = _create_loot_item_slot(pending[i], i)
			drops_grid.add_child(slot)
	else:
		var done_lbl = Label.new()
		# Distinguish "no items ever dropped" from "all items assigned"
		var had_items: bool = _loot_result != null and _loot_result.items_dropped.size() > 0
		done_lbl.text = "All items assigned!" if had_items else "No items dropped."
		done_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		done_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5) if had_items else Color(0.7, 0.65, 0.55))
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(done_lbl)

	# ── Routing bar (appears when a slot is selected) ──
	_loot_routing_bar = HBoxContainer.new()
	_loot_routing_bar.name = "RoutingBar"
	_loot_routing_bar.add_theme_constant_override("separation", 6)
	_loot_routing_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_loot_routing_bar)
	_update_routing_bar()

	# ── Separator ──
	var sep1 = HSeparator.new()
	sep1.modulate = Color(0.55, 0.4, 0.25, 0.5)
	vbox.add_child(sep1)

	# ── Shop Bag visual grid ──
	var shop_used = GameContext.shopkeeper_bag.size()
	var shop_cap = GameContext.get_shopkeeper_bag_capacity()
	var shop_header = Label.new()
	shop_header.text = "Shop Bag (%d/%d%s):" % [shop_used, shop_cap, _bag_stack_room_indicator(GameContext.shopkeeper_bag)]
	shop_header.add_theme_font_size_override("font_size", GameContext.fs(14))
	shop_header.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6))
	vbox.add_child(shop_header)

	var shop_grid = GridContainer.new()
	shop_grid.columns = 10
	shop_grid.add_theme_constant_override("h_separation", 3)
	shop_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(shop_grid)
	_loot_shop_grid = shop_grid

	var is_shop_swap: bool = _loot_swap_mode and _loot_swap_hero_id == "__shop__"
	for j in range(shop_cap):
		if j < GameContext.shopkeeper_bag.size():
			var entry = GameContext.shopkeeper_bag[j]
			shop_grid.add_child(_create_bag_slot(entry, 32, is_shop_swap, "__shop__", j))
		else:
			shop_grid.add_child(_create_empty_bag_slot(32, "__shop__", j))

	# ── Hero Bag visual grids (skip dead heroes) ──
	for hero_id in GameContext.selected_party:
		var hp_check = GameContext.get_hero_hp(hero_id)
		if not hp_check.is_empty() and int(hp_check.get("current", 1)) <= 0:
			continue
		var hero = GameContext.get_hero(hero_id)
		var hero_name: String = hero.get("name", hero_id) if not hero.is_empty() else hero_id
		var bag = GameContext.get_hero_bag(hero_id)
		var bag_cap = GameContext.get_hero_bag_capacity(hero_id)

		var hero_row = HBoxContainer.new()
		hero_row.add_theme_constant_override("separation", 8)
		vbox.add_child(hero_row)

		var hero_lbl = Label.new()
		hero_lbl.text = "%s (%d/%d%s):" % [hero_name, bag.size(), bag_cap, _bag_stack_room_indicator(bag)]
		hero_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		hero_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55))
		hero_lbl.custom_minimum_size = Vector2(120, 0)
		hero_row.add_child(hero_lbl)

		var hero_grid = GridContainer.new()
		hero_grid.columns = 5
		hero_grid.add_theme_constant_override("h_separation", 3)
		hero_grid.add_theme_constant_override("v_separation", 3)
		hero_row.add_child(hero_grid)
		_loot_hero_grids.append(hero_grid)

		for j in range(bag_cap):
			if j < bag.size():
				var entry = bag[j]
				var is_swap_target: bool = _loot_swap_mode and _loot_swap_hero_id == hero_id
				var bag_slot = _create_bag_slot(entry, 32, is_swap_target, hero_id, j)
				hero_grid.add_child(bag_slot)
			else:
				hero_grid.add_child(_create_empty_bag_slot(32, hero_id, j))

	# ── Swap mode warning ──
	if _loot_swap_mode:
		var swap_warn = Label.new()
		if _loot_swap_hero_id == "__shop__":
			swap_warn.text = "Click a slot in Shop Bag to replace it (displaced item returns to loot)"
		else:
			var swap_hero = GameContext.get_hero(_loot_swap_hero_id)
			var swap_hero_name: String = swap_hero.get("name", _loot_swap_hero_id) if not swap_hero.is_empty() else _loot_swap_hero_id
			swap_warn.text = "Click a slot in %s's bag to replace it (item will be DISCARDED)" % swap_hero_name
		swap_warn.add_theme_font_size_override("font_size", GameContext.fs(13))
		swap_warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		swap_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(swap_warn)

		var cancel_swap_btn = Button.new()
		cancel_swap_btn.text = "Cancel Swap"
		cancel_swap_btn.custom_minimum_size = Vector2(120, 28)
		cancel_swap_btn.pressed.connect(_on_swap_cancel)
		vbox.add_child(cancel_swap_btn)

	# ── Separator ──
	var sep2 = HSeparator.new()
	sep2.modulate = Color(0.55, 0.4, 0.25, 0.5)
	vbox.add_child(sep2)

	# ── Bottom buttons ──
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	_loot_btn_row = btn_row

	if not pending.is_empty():
		_loot_discard_btn = Button.new()
		_loot_discard_btn.text = "Discard All"
		_loot_discard_btn.custom_minimum_size = Vector2(120, 32)
		_loot_discard_btn.modulate = Color(1.0, 0.7, 0.7)
		_loot_discard_btn.button_down.connect(_on_discard_hold_start)
		_loot_discard_btn.button_up.connect(_on_discard_hold_cancel)
		btn_row.add_child(_loot_discard_btn)

		# Hold-to-discard indicator (below the button row, visible immediately)
		_loot_hold_container = Control.new()
		_loot_hold_container.visible = true
		_loot_hold_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_loot_hold_container.custom_minimum_size = Vector2(200, 30)
		var hold_vbox = VBoxContainer.new()
		hold_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		_loot_hold_container.add_child(hold_vbox)
		var hold_label := Label.new()
		hold_label.text = "Hold to Discard"
		hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hold_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		hold_label.modulate = Color(1.0, 0.7, 0.6, 0.9)
		hold_vbox.add_child(hold_label)
		var hold_bar_bg := ColorRect.new()
		hold_bar_bg.custom_minimum_size = Vector2(160, 8)
		hold_bar_bg.color = Color(0.2, 0.2, 0.2, 0.7)
		hold_vbox.add_child(hold_bar_bg)
		_loot_hold_bar_fill = ColorRect.new()
		_loot_hold_bar_fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		_loot_hold_bar_fill.anchor_right = 0.0
		_loot_hold_bar_fill.color = Color(1.0, 0.5, 0.4, 0.9)
		hold_bar_bg.add_child(_loot_hold_bar_fill)
		vbox.add_child(_loot_hold_container)

		var all_shop_btn = Button.new()
		all_shop_btn.text = "Deposit All"
		all_shop_btn.custom_minimum_size = Vector2(140, 32)
		all_shop_btn.tooltip_text = "Shop bag first, then hero bags (%s)" % InputManager.get_glyph("loot_deposit")
		# Disable only if NO pending item can fit (stacking-aware)
		var any_space: bool = false
		for acq in pending:
			if any_space:
				break
			var aid: String = acq.get("item_id", "")
			var aq: int = int(acq.get("quality", 0))
			if GameContext.can_add_to_shopkeeper_bag(aid, 1, aq):
				any_space = true
				break
			for pid in GameContext.selected_party:
				if GameContext.can_add_to_hero_bag(pid, aid, 1):
					any_space = true
					break
		if not any_space:
			all_shop_btn.disabled = true
			all_shop_btn.tooltip_text = "All bags full"
		all_shop_btn.pressed.connect(_on_loot_deposit_all)
		btn_row.add_child(all_shop_btn)

	var continue_btn = Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(140, 32)
	continue_btn.focus_mode = Control.FOCUS_ALL
	continue_btn.pressed.connect(_on_loot_continue)
	if not pending.is_empty():
		continue_btn.disabled = true
		continue_btn.tooltip_text = "Assign all items first"
	btn_row.add_child(continue_btn)

	_loot_panel.grab_focus()
	# Register loot panel as a focus zone for controller navigation
	call_deferred("_register_loot_zones")
	print("[LootPanel] Showing %d pending acquisitions (visual popup)" % pending.size())


## Create a 48x48 clickable icon slot for a pending loot item.
func _create_loot_item_slot(acq: Dictionary, index: int) -> Control:
	var item_id: String = acq.get("item_id", "")
	var quality: int = int(acq.get("quality", 0))
	var tpl = DataRegistry.get_item_template(item_id)
	var display_name: String = item_id.replace("_", " ").capitalize()
	if tpl != null and tpl.display_name != "":
		display_name = tpl.display_name

	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(52, 52)
	var slot_style: StyleBoxFlat
	if index == _loot_selected_index:
		# Selected: gold highlight border
		slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.2, 0.18, 0.12, 0.9)
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.border_color = Color(1.0, 0.85, 0.3)
		slot_style.corner_radius_top_left = 3
		slot_style.corner_radius_top_right = 3
		slot_style.corner_radius_bottom_left = 3
		slot_style.corner_radius_bottom_right = 3
		slot_style.content_margin_left = 2.0
		slot_style.content_margin_top = 2.0
		slot_style.content_margin_right = 2.0
		slot_style.content_margin_bottom = 2.0
	else:
		slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.13, 0.1, 0.8)
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.4, 0.35, 0.25, 0.6)
		slot_style.corner_radius_top_left = 3
		slot_style.corner_radius_top_right = 3
		slot_style.corner_radius_bottom_left = 3
		slot_style.corner_radius_bottom_right = 3
		slot_style.content_margin_left = 2.0
		slot_style.content_margin_top = 2.0
		slot_style.content_margin_right = 2.0
		slot_style.content_margin_bottom = 2.0
	slot.add_theme_stylebox_override("panel", slot_style)

	# Item icon
	if tpl != null:
		var icon_ctrl = tpl.create_bordered_icon(40, quality)
		if icon_ctrl != null:
			slot.add_child(icon_ctrl)

	# Qty label overlay for stacked items (materials)
	var loot_qty: int = int(acq.get("qty", 1))
	if loot_qty > 1:
		var qty_label = Label.new()
		qty_label.text = "x%d" % loot_qty
		qty_label.add_theme_font_size_override("font_size", 10)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		qty_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		qty_label.add_theme_constant_override("shadow_offset_x", 1)
		qty_label.add_theme_constant_override("shadow_offset_y", 1)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(qty_label)

	# Tooltip with item info
	var loot_affix_data: Dictionary = acq.get("affix_data", {})
	var loot_affix_prefix: String = loot_affix_data.get("affix_prefix", "")
	var loot_display: String = display_name
	if loot_affix_prefix != "":
		loot_display = loot_affix_prefix + " " + display_name
	var tip_parts: Array[String] = [loot_display]
	if quality > 0:
		tip_parts[0] = "%s %s" % [ItemInstance.QUALITY_NAMES[clampi(quality, 0, 3)], loot_display]
	if tpl != null:
		if tpl.item_type != "":
			tip_parts.append("Type: %s" % tpl.item_type)
		var region_bonus: float = GameContext.get_completed_region_count() * 0.1
		var stats = tpl.get_stat_bonuses_with_quality(quality, region_bonus)
		for stat_key in stats:
			tip_parts.append("%s: +%s" % [stat_key, str(stats[stat_key])])
		# Show affix bonus if present
		if loot_affix_prefix != "":
			var loot_affix_stats: Dictionary = loot_affix_data.get("affix_stats", {})
			if loot_affix_stats is Dictionary and not loot_affix_stats.is_empty():
				var affix_parts: Array[String] = []
				for ak in loot_affix_stats:
					affix_parts.append("+%d %s" % [int(loot_affix_stats[ak]), ak.to_upper().left(3)])
				tip_parts.append("Affix: %s (%s)" % [loot_affix_prefix, ", ".join(affix_parts)])
			var loot_affix_desc: String = DataRegistry.get_regional_affix(loot_affix_data.get("affix_id", "")).get("description", "")
			if loot_affix_desc != "":
				tip_parts.append(loot_affix_desc)
		# Show consumable effect
		var effect_label: String = tpl.get_effect_label()
		if effect_label != "":
			tip_parts.append(effect_label)
	if loot_qty > 1:
		tip_parts[0] += " x%d" % loot_qty
	slot.tooltip_text = "\n".join(tip_parts)

	# Click handler — select this slot (also focusable for D-pad navigation)
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.anchor_right = 1.0
	click_btn.anchor_bottom = 1.0
	click_btn.modulate = Color(1, 1, 1, 0)  # Invisible overlay button
	click_btn.focus_mode = Control.FOCUS_ALL
	# Focus style: gold border visible when D-pad selects this slot
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1.0, 0.85, 0.3, 0.2)
	focus_style.border_color = Color(1.0, 0.85, 0.3, 0.9)
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(3)
	click_btn.add_theme_stylebox_override("focus", focus_style)
	click_btn.pressed.connect(_on_loot_slot_clicked.bind(index))
	slot.add_child(click_btn)

	return slot


## Create a 32x32 mini-slot showing a bag item with icon.
func _create_bag_slot(entry: Dictionary, slot_size: int = 32, is_swap_target: bool = false, hero_id: String = "", bag_index: int = -1) -> Control:
	var item_id: String = entry.get("item_id", "")
	var quality: int = int(entry.get("quality_tier", 0))
	var tpl = DataRegistry.get_item_template(item_id)
	var display_name: String = item_id.replace("_", " ").capitalize()
	if tpl != null and tpl.display_name != "":
		display_name = tpl.display_name

	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(slot_size + 4, slot_size + 4)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.8)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0

	# Highlight clickable slots when a loot item is selected
	var is_clickable: bool = _loot_selected_index >= 0 and bag_index >= 0
	if is_swap_target or is_clickable:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.8, 0.7, 0.3, 0.8) if is_clickable else Color(1.0, 0.5, 0.3, 0.9)
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.35, 0.3, 0.2, 0.5)
	slot.add_theme_stylebox_override("panel", style)

	# Icon
	if tpl != null:
		var icon_ctrl = tpl.create_bordered_icon(slot_size - 8, quality)
		if icon_ctrl != null:
			slot.add_child(icon_ctrl)

	# Qty label overlay for stacked items (materials)
	var entry_qty: int = int(entry.get("qty", 1))
	if entry_qty > 1:
		var qty_label = Label.new()
		qty_label.text = "x%d" % entry_qty
		qty_label.add_theme_font_size_override("font_size", 10)
		qty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		qty_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		qty_label.add_theme_constant_override("shadow_offset_x", 1)
		qty_label.add_theme_constant_override("shadow_offset_y", 1)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(qty_label)

	# Tooltip
	var tip: String = display_name
	if quality > 0:
		tip = "%s %s" % [ItemInstance.QUALITY_NAMES[clampi(quality, 0, 3)], display_name]
	if entry_qty > 1:
		tip += " x%d" % entry_qty
	slot.tooltip_text = tip

	# Always add focusable button overlay for D-pad navigation
	if bag_index >= 0:
		var click_btn = Button.new()
		click_btn.flat = true
		click_btn.anchor_right = 1.0
		click_btn.anchor_bottom = 1.0
		click_btn.modulate = Color(1, 1, 1, 0)
		click_btn.focus_mode = Control.FOCUS_ALL
		var btn_focus_style := StyleBoxFlat.new()
		if is_swap_target:
			btn_focus_style.bg_color = Color(1.0, 0.5, 0.3, 0.2)
			btn_focus_style.border_color = Color(1.0, 0.5, 0.3, 0.9)
		elif is_clickable:
			btn_focus_style.bg_color = Color(0.4, 0.8, 0.4, 0.2)
			btn_focus_style.border_color = Color(0.4, 0.8, 0.4, 0.9)
		else:
			btn_focus_style.bg_color = Color(0.6, 0.55, 0.4, 0.15)
			btn_focus_style.border_color = Color(0.6, 0.55, 0.4, 0.6)
		btn_focus_style.set_border_width_all(2)
		btn_focus_style.set_corner_radius_all(2)
		click_btn.add_theme_stylebox_override("focus", btn_focus_style)
		if is_clickable:
			click_btn.pressed.connect(_on_loot_direct_place.bind(hero_id, bag_index, item_id))
		elif is_swap_target:
			click_btn.pressed.connect(_on_swap_bag_slot_clicked.bind(hero_id, bag_index, item_id))
		slot.add_child(click_btn)

	return slot


## Create an empty bag slot (dim placeholder).
func _create_empty_bag_slot(slot_size: int = 32, hero_id: String = "", bag_index: int = -1) -> Control:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(slot_size + 4, slot_size + 4)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.3)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2

	# Highlight empty slots as clickable targets when a loot item is selected
	var is_clickable: bool = _loot_selected_index >= 0 and bag_index >= 0
	if is_clickable:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.8, 0.4, 0.7)
	else:
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.3, 0.25, 0.18, 0.3)
	slot.add_theme_stylebox_override("panel", style)

	# Always add focusable button overlay for D-pad navigation
	if bag_index >= 0:
		var click_btn = Button.new()
		click_btn.flat = true
		click_btn.anchor_right = 1.0
		click_btn.anchor_bottom = 1.0
		click_btn.modulate = Color(1, 1, 1, 0)
		click_btn.focus_mode = Control.FOCUS_ALL
		var empty_focus_style := StyleBoxFlat.new()
		if is_clickable:
			empty_focus_style.bg_color = Color(0.4, 0.8, 0.4, 0.2)
			empty_focus_style.border_color = Color(0.4, 0.8, 0.4, 0.9)
		else:
			empty_focus_style.bg_color = Color(0.6, 0.55, 0.4, 0.1)
			empty_focus_style.border_color = Color(0.6, 0.55, 0.4, 0.4)
		empty_focus_style.set_border_width_all(2)
		empty_focus_style.set_corner_radius_all(2)
		click_btn.add_theme_stylebox_override("focus", empty_focus_style)
		if is_clickable:
			click_btn.pressed.connect(_on_loot_direct_place.bind(hero_id, bag_index, ""))
		slot.add_child(click_btn)

	return slot


## Update routing bar to reflect currently selected loot slot.
func _update_routing_bar() -> void:
	if _loot_routing_bar == null:
		return
	# Clear existing children
	for child in _loot_routing_bar.get_children():
		child.queue_free()

	var pending = GameContext.get_all_pending_acquisitions()
	if pending.is_empty() or _loot_selected_index < 0 or _loot_selected_index >= pending.size():
		var hint = Label.new()
		if pending.is_empty():
			hint.text = ""
		elif InputManager.active_device == "gamepad":
			hint.text = "Navigate to an item with D-pad, press A to select"
		else:
			hint.text = "Click an item above to assign it  (or press 1-4)"
			hint.add_theme_font_size_override("font_size", GameContext.fs(13))
			hint.add_theme_color_override("font_color", Color(0.78, 0.78, 0.68))
		_loot_routing_bar.add_child(hint)
		return

	var acq = pending[_loot_selected_index]
	var item_id: String = acq.get("item_id", "")
	var tpl = DataRegistry.get_item_template(item_id)
	var display_name: String = item_id.replace("_", " ").capitalize()
	if tpl != null and tpl.display_name != "":
		display_name = tpl.display_name

	# Instruction text instead of hero/shop buttons — click bag slots directly
	var instruct = Label.new()
	if InputManager.active_device == "gamepad":
		instruct.text = "Navigate to a bag slot and press A to place %s" % display_name
	else:
		instruct.text = "Click a bag slot below to place %s  (or 1-4 for Heroes)" % display_name
	instruct.add_theme_font_size_override("font_size", GameContext.fs(13))
	instruct.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_loot_routing_bar.add_child(instruct)


## Handle clicking a loot drop slot — select it for routing.
func _on_loot_slot_clicked(index: int) -> void:
	if _loot_swap_mode:
		_loot_swap_mode = false
		_loot_swap_hero_id = ""
		_loot_swap_acq_index = -1
	_loot_selected_index = index
	_refresh_loot_panel()


## Refresh the loot panel after an item is routed.
func _refresh_loot_panel() -> void:
	_show_loot_panel()


## Route a pending acquisition to the shopkeeper bag.
func _on_loot_to_shop_bag(acq_index: int) -> void:
	GameContext.resolve_acquisition_at(acq_index, "shop_bag")
	UIAudio.play_sfx("loot_assign")
	_loot_selected_index = -1
	_refresh_loot_panel()
	_refresh_shopkeeper_bag_display()


## Route a pending acquisition to a hero's bag.
func _on_loot_to_hero(acq_index: int, hero_id: String) -> void:
	var ok = GameContext.resolve_acquisition_at(acq_index, "hero_bag", hero_id)
	if not ok:
		print("[LootPanel] Failed to route to hero=%s (rejected)" % hero_id)
	else:
		UIAudio.play_sfx("loot_assign")
	_loot_selected_index = -1
	_refresh_loot_panel()


## Enter swap mode for a hero bag (bag is full, need to pick a slot to replace).
func _on_loot_swap_request(acq_index: int, hero_id: String) -> void:
	_loot_swap_mode = true
	_loot_swap_hero_id = hero_id
	_loot_swap_acq_index = acq_index
	print("[LootPanel] Entering swap mode for hero=%s acq=%d" % [hero_id, acq_index])
	_refresh_loot_panel()


## Handle clicking a bag slot during swap mode — replace the item.
func _on_swap_bag_slot_clicked(hero_id: String, bag_index: int, old_item_id: String) -> void:
	var acq_index = _loot_swap_acq_index

	if hero_id == "__shop__":
		# Shop bag swap: displaced item returns to pending
		if bag_index >= 0 and bag_index < GameContext.shopkeeper_bag.size():
			var displaced: Dictionary = GameContext.shopkeeper_bag[bag_index].duplicate()
			GameContext.shopkeeper_bag.remove_at(bag_index)
			var ok = GameContext.resolve_acquisition_at(acq_index, "shop_bag")
			if ok:
				# Return displaced item to pending acquisitions
				var d_quality: int = int(displaced.get("quality_tier", 0))
				var d_affix: Dictionary = {}
				if displaced.get("affix_id", "") != "":
					d_affix = {"affix_id": displaced.get("affix_id", ""), "affix_stats": displaced.get("affix_stats", {}), "affix_prefix": displaced.get("affix_prefix", ""), "source_region": displaced.get("source_region", "")}
				GameContext.acquire_item_with_recipient(displaced.get("item_id", ""), int(displaced.get("qty", 1)), d_quality, "swap", d_affix)
				print("[LootPanel] Shop swap: replaced slot %d, displaced %s returned to pending" % [bag_index, old_item_id])
			else:
				# Restore displaced item on failure
				GameContext.shopkeeper_bag.insert(bag_index, displaced)
				print("[LootPanel] Shop swap failed: couldn't add new item")
	else:
		# Hero bag swap: discard old item
		var success = GameContext.remove_item_from_hero_bag(hero_id, old_item_id, 1, 0)
		if success:
			print("[LootPanel] DISCARDED old_item=%s from hero=%s" % [old_item_id, hero_id])
			var ok = GameContext.resolve_acquisition_at(acq_index, "hero_bag", hero_id)
			if ok:
				print("[LootPanel] Swap complete: added new item to hero=%s" % hero_id)
			else:
				print("[LootPanel] Swap failed: couldn't add new item")
		else:
			print("[LootPanel] Swap failed: couldn't remove old item")

	_loot_swap_mode = false
	_loot_swap_hero_id = ""
	_loot_swap_acq_index = -1
	_loot_selected_index = -1
	_refresh_loot_panel()


## Enter swap mode for shopkeeper bag (bag is full, need to pick a slot to replace).
func _on_loot_shop_swap_request(acq_index: int) -> void:
	_loot_swap_mode = true
	_loot_swap_hero_id = "__shop__"
	_loot_swap_acq_index = acq_index
	print("[LootPanel] Entering swap mode for shop_bag acq=%d" % acq_index)
	_refresh_loot_panel()


## Cancel swap mode.
func _on_swap_cancel() -> void:
	_loot_swap_mode = false
	_loot_swap_hero_id = ""
	_loot_swap_acq_index = -1
	_refresh_loot_panel()


## Direct placement: click a bag slot to place the selected loot item.
## If slot is empty: place directly. If occupied: show confirmation.
func _on_loot_direct_place(owner_id: String, slot_index: int, existing_item_id: String) -> void:
	if _loot_selected_index < 0:
		return
	var pending = GameContext.get_all_pending_acquisitions()
	if _loot_selected_index >= pending.size():
		return

	var acq = pending[_loot_selected_index]
	var new_item_id: String = acq.get("item_id", "")
	var new_tpl = DataRegistry.get_item_template(new_item_id)
	var new_name: String = new_tpl.display_name if new_tpl != null else new_item_id

	# Empty slot — place directly without confirmation
	if existing_item_id == "":
		_execute_loot_direct_place(owner_id, slot_index, "")
		return

	# Occupied slot — show confirmation
	var old_tpl = DataRegistry.get_item_template(existing_item_id)
	var old_name: String = old_tpl.display_name if old_tpl != null else existing_item_id

	var warning: String = ""
	if owner_id == "__shop__":
		warning = "Replace %s with %s?\n(Displaced item returns to loot)" % [old_name, new_name]
	else:
		var hero = GameContext.get_hero(owner_id)
		var hero_name: String = hero.get("name", owner_id) if not hero.is_empty() else owner_id
		warning = "Replace %s in %s's bag with %s?\n(Displaced item returns to loot)" % [old_name, hero_name, new_name]

	_show_loot_confirm_overlay(warning, owner_id, slot_index, existing_item_id)


## Show a confirmation overlay for loot slot replacement.
func _show_loot_confirm_overlay(message: String, owner_id: String, slot_index: int, old_item_id: String) -> void:
	_close_loot_confirm_overlay()

	_loot_confirm_overlay = CanvasLayer.new()
	_loot_confirm_overlay.layer = 11
	add_child(_loot_confirm_overlay)

	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_loot_confirm_overlay.add_child(root)

	var backdrop = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 100)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var msg_label = Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(90, 30)
	confirm_btn.pressed.connect(_on_loot_confirm_replace.bind(owner_id, slot_index, old_item_id))
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(90, 30)
	cancel_btn.pressed.connect(_close_loot_confirm_overlay)
	btn_row.add_child(cancel_btn)


## Execute confirmed loot slot replacement.
func _on_loot_confirm_replace(owner_id: String, slot_index: int, old_item_id: String) -> void:
	_close_loot_confirm_overlay()
	_execute_loot_direct_place(owner_id, slot_index, old_item_id)


## Extract affix data from a bag entry dict for re-queuing to pending.
func _extract_bag_affix(entry: Dictionary) -> Dictionary:
	if entry.get("affix_id", "") != "":
		return {"affix_id": entry.get("affix_id", ""), "affix_stats": entry.get("affix_stats", {}), "affix_prefix": entry.get("affix_prefix", ""), "source_region": entry.get("source_region", "")}
	return {}

## Build a bag entry dict from a pending acquisition entry.
func _build_bag_entry_from_acq(acq: Dictionary, place_qty: int) -> Dictionary:
	var entry: Dictionary = {"item_id": acq.get("item_id", ""), "qty": place_qty, "quality_tier": int(acq.get("quality", 0))}
	var affix: Dictionary = acq.get("affix_data", {})
	if affix.get("affix_id", "") != "":
		entry["affix_id"] = affix.get("affix_id", "")
		entry["affix_stats"] = affix.get("affix_stats", {})
		entry["affix_prefix"] = affix.get("affix_prefix", "")
		entry["source_region"] = affix.get("source_region", "")
	return entry

## Execute loot direct placement into a bag slot.
## Swap: displaced item returns to pending loot. Full stack placed at once.
func _execute_loot_direct_place(owner_id: String, slot_index: int, old_item_id: String) -> void:
	if _loot_selected_index < 0:
		return
	var acq_index: int = _loot_selected_index
	var pending = GameContext.get_all_pending_acquisitions()
	if acq_index >= pending.size():
		return
	var acq: Dictionary = pending[acq_index]
	var new_item_id: String = acq.get("item_id", "")
	var new_qty: int = int(acq.get("qty", 1))
	var stack_limit: int = GameContext.get_bag_stack_limit(new_item_id)
	var place_qty: int = mini(new_qty, stack_limit)

	if old_item_id != "":
		# ── Occupied slot — TRUE SWAP: displaced goes to pending, new takes slot ──
		if owner_id == "__shop__":
			if slot_index >= 0 and slot_index < GameContext.shopkeeper_bag.size():
				var displaced: Dictionary = GameContext.shopkeeper_bag[slot_index].duplicate()
				GameContext.shopkeeper_bag[slot_index] = _build_bag_entry_from_acq(acq, place_qty)
				# Update or remove pending
				if new_qty <= place_qty:
					pending.remove_at(acq_index)
				else:
					acq["qty"] = new_qty - place_qty
				# Re-queue displaced item to pending
				GameContext.acquire_item_with_recipient(displaced.get("item_id", ""), int(displaced.get("qty", 1)), int(displaced.get("quality_tier", 0)), "swap", _extract_bag_affix(displaced))
				print("[LootPanel] Swap: shop slot %d, placed %dx %s, displaced %s" % [slot_index, place_qty, new_item_id, displaced.get("item_id", "")])
			else:
				print("[LootPanel] Swap failed: invalid shop slot %d" % slot_index)
		else:
			var bag: Array = GameContext.hero_bags.get(owner_id, [])
			if slot_index >= 0 and slot_index < bag.size():
				var displaced: Dictionary = bag[slot_index].duplicate()
				bag[slot_index] = _build_bag_entry_from_acq(acq, place_qty)
				# Update or remove pending
				if new_qty <= place_qty:
					pending.remove_at(acq_index)
				else:
					acq["qty"] = new_qty - place_qty
				# Re-queue displaced item to pending
				GameContext.acquire_item_with_recipient(displaced.get("item_id", ""), int(displaced.get("qty", 1)), int(displaced.get("quality_tier", 0)), "swap", _extract_bag_affix(displaced))
				print("[LootPanel] Swap: hero=%s slot %d, placed %dx %s, displaced %s" % [owner_id, slot_index, place_qty, new_item_id, displaced.get("item_id", "")])
			else:
				print("[LootPanel] Swap failed: invalid hero bag slot %d for %s" % [slot_index, owner_id])
	else:
		# ── Empty slot — place full stack directly ──
		if owner_id == "__shop__":
			var ok = GameContext.add_item_to_shopkeeper_bag(new_item_id, place_qty, int(acq.get("quality", 0)), "combat", acq.get("affix_data", {}))
			if ok:
				if new_qty <= place_qty:
					pending.remove_at(acq_index)
				else:
					acq["qty"] = new_qty - place_qty
				print("[LootPanel] Placed %dx %s into empty shop slot" % [place_qty, new_item_id])
		else:
			var ok = GameContext.add_item_to_hero_bag(owner_id, new_item_id, place_qty, int(acq.get("quality", 0)), acq.get("affix_data", {}))
			if ok:
				if new_qty <= place_qty:
					pending.remove_at(acq_index)
				else:
					acq["qty"] = new_qty - place_qty
				print("[LootPanel] Placed %dx %s into empty hero=%s slot" % [place_qty, new_item_id, owner_id])

	UIAudio.play_sfx("loot_assign")
	_loot_selected_index = -1
	_refresh_loot_panel()
	_refresh_shopkeeper_bag_display()


## Close the loot confirmation overlay.
func _close_loot_confirm_overlay() -> void:
	if _loot_confirm_overlay != null and is_instance_valid(_loot_confirm_overlay):
		_loot_confirm_overlay.queue_free()
		_loot_confirm_overlay = null


func _on_discard_hold_start() -> void:
	_is_holding_discard = true
	_discard_hold_time = 0.0
	if _loot_hold_container != null:
		_loot_hold_container.visible = true
	if _loot_hold_bar_fill != null:
		_loot_hold_bar_fill.anchor_right = 0.0

func _on_discard_hold_cancel() -> void:
	_is_holding_discard = false
	_discard_hold_time = 0.0
	if _loot_hold_bar_fill != null:
		_loot_hold_bar_fill.anchor_right = 0.0


## v1.2: Discard all remaining pending items (explicit user action).
## SFX: loot_discard is played once for the whole batch.
func _on_loot_discard_all() -> void:
	var pending = GameContext.get_all_pending_acquisitions()
	for acq in pending:
		var item_id = acq.get("item_id", "")
		var qty = int(acq.get("qty", 1))
		var quality = int(acq.get("quality", 0))
		print("[Loot] discard item=%s qty=%d q=%d" % [item_id, qty, quality])
	GameContext.clear_pending_acquisitions()
	UIAudio.play_sfx("loot_discard")
	_loot_selected_index = -1
	_refresh_loot_panel()


## Route all pending items: shop bag first, then overflow to hero bags.
## Multi-pass: skips un-routable items so fitting items still get deposited.
func _on_loot_deposit_all() -> void:
	var routed_shop: int = 0
	var routed_hero: int = 0
	var placed_any: bool = true
	while placed_any:
		placed_any = false
		var pending = GameContext.get_all_pending_acquisitions()
		var i: int = pending.size() - 1
		while i >= 0:
			var acq = pending[i]
			var item_id: String = acq.get("item_id", "")
			var quality: int = int(acq.get("quality", 0))
			# Try shop bag first
			if GameContext.can_add_to_shopkeeper_bag(item_id, 1, quality):
				GameContext.resolve_acquisition_at(i, "shop_bag")
				routed_shop += 1
				placed_any = true
				pending = GameContext.get_all_pending_acquisitions()
				i = mini(i, pending.size()) - 1
				continue
			# Try hero bags
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
			i -= 1  # skip this item, try next
	print("[LootPanel] Deposit All: %d to shop, %d to heroes" % [routed_shop, routed_hero])
	_loot_selected_index = -1
	_refresh_loot_panel()
	_refresh_shopkeeper_bag_display()


## Detect which edge(s) the mouse is near on the loot panel. Returns bitmask: 1=left, 2=right, 4=top, 8=bottom.
func _detect_loot_resize_edge(local_pos: Vector2, panel_size: Vector2) -> int:
	var edge: int = 0
	if local_pos.x < LOOT_RESIZE_MARGIN:
		edge |= 1
	elif local_pos.x > panel_size.x - LOOT_RESIZE_MARGIN:
		edge |= 2
	if local_pos.y < LOOT_RESIZE_MARGIN:
		edge |= 4
	elif local_pos.y > panel_size.y - LOOT_RESIZE_MARGIN:
		edge |= 8
	return edge

## Map edge bitmask to cursor shape for loot panel resize.
func _loot_cursor_for_edge(edge: int) -> Control.CursorShape:
	match edge:
		5, 10:  # top+left or bottom+right
			return Control.CURSOR_FDIAGSIZE
		6, 9:  # top+right or bottom+left
			return Control.CURSOR_BDIAGSIZE
		1, 2:  # left or right
			return Control.CURSOR_HSIZE
		4, 8:  # top or bottom
			return Control.CURSOR_VSIZE
		_:
			return Control.CURSOR_ARROW

## Handle gui_input on the loot panel for edge-resize and drag-to-move.
func _on_loot_panel_gui_input(event: InputEvent) -> void:
	if _loot_panel == null or not is_instance_valid(_loot_panel):
		return
	var local_pos: Vector2 = _loot_panel.get_local_mouse_position()
	var edge: int = _detect_loot_resize_edge(local_pos, _loot_panel.size)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if edge != 0:
				_loot_resizing = true
				_loot_resize_edge = edge
				_loot_resize_start_pos = event.global_position
				_loot_resize_start_size = _loot_panel.size
				_loot_resize_start_panel_pos = _loot_panel.position
			else:
				# Click inside panel (not on edge) — start drag
				_loot_dragging = true
				_loot_drag_offset = event.global_position - _loot_panel.position
		else:
			if _loot_resizing:
				GameContext.loot_panel_size = _loot_panel.size
				GameContext.save_game()
				_loot_resizing = false
				_loot_resize_edge = 0
			if _loot_dragging:
				_loot_dragging = false

	elif event is InputEventMouseMotion:
		if _loot_resizing:
			_handle_loot_resize_motion(event.global_position)
		elif _loot_dragging:
			_loot_panel.position = event.global_position - _loot_drag_offset
		else:
			# Hover — update cursor on edges
			if edge != 0:
				_loot_panel.mouse_default_cursor_shape = _loot_cursor_for_edge(edge)
			else:
				_loot_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE

## Apply resize delta based on edge bitmask for loot panel.
func _handle_loot_resize_motion(global_pos: Vector2) -> void:
	var delta: Vector2 = global_pos - _loot_resize_start_pos
	var new_size: Vector2 = _loot_resize_start_size
	var new_pos: Vector2 = _loot_resize_start_panel_pos

	if _loot_resize_edge & 2:
		new_size.x = _loot_resize_start_size.x + delta.x
	if _loot_resize_edge & 1:
		new_size.x = _loot_resize_start_size.x - delta.x
		new_pos.x = _loot_resize_start_panel_pos.x + delta.x
	if _loot_resize_edge & 8:
		new_size.y = _loot_resize_start_size.y + delta.y
	if _loot_resize_edge & 4:
		new_size.y = _loot_resize_start_size.y - delta.y
		new_pos.y = _loot_resize_start_panel_pos.y + delta.y

	new_size.x = clampf(new_size.x, LOOT_PANEL_MIN_SIZE.x, LOOT_PANEL_MAX_SIZE.x)
	new_size.y = clampf(new_size.y, LOOT_PANEL_MIN_SIZE.y, LOOT_PANEL_MAX_SIZE.y)

	if _loot_resize_edge & 1:
		new_pos.x = _loot_resize_start_panel_pos.x + (_loot_resize_start_size.x - new_size.x)
	if _loot_resize_edge & 4:
		new_pos.y = _loot_resize_start_panel_pos.y + (_loot_resize_start_size.y - new_size.y)

	_loot_panel.custom_minimum_size = new_size
	_loot_panel.size = new_size
	_loot_panel.position = new_pos


## Auto-deposit all loot: shopkeeper bag first, then hero bags.
## Multi-pass: skips un-routable items so fitting items still get deposited.
func _auto_deposit_all_loot() -> void:
	var routed_shop: int = 0
	var routed_hero: int = 0
	var placed_any: bool = true
	while placed_any:
		placed_any = false
		var pending = GameContext.get_all_pending_acquisitions()
		var i: int = pending.size() - 1
		while i >= 0:
			var acq = pending[i]
			var item_id: String = acq.get("item_id", "")
			var quality: int = int(acq.get("quality", 0))
			# Try shop bag first
			if GameContext.can_add_to_shopkeeper_bag(item_id, 1, quality):
				GameContext.resolve_acquisition_at(i, "shop_bag")
				routed_shop += 1
				placed_any = true
				pending = GameContext.get_all_pending_acquisitions()
				i = mini(i, pending.size()) - 1
				continue
			# Try hero bags
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
			i -= 1  # skip this item, try next
	var remaining: int = GameContext.get_all_pending_acquisitions().size()
	print("[AutoLoot] Deposited: %d to shop bag, %d to hero bags, %d remaining" % [routed_shop, routed_hero, remaining])


## Continue after loot routing — only allowed when no pending items remain.
func _on_loot_continue() -> void:
	if GameContext.has_pending_acquisition():
		print("[LootPanel] Continue blocked: %d items still pending" % GameContext.get_all_pending_acquisitions().size())
		return
	if _loot_overlay != null and is_instance_valid(_loot_overlay):
		_loot_overlay.queue_free()
		_loot_overlay = null
		_loot_panel = null

	# Boss victory cutscene (fires after loot, before campaign dialog)
	if _loot_result != null and _loot_result.is_boss_encounter and _loot_result.is_victory:
		var victory_player = BossCutsceneManager.try_show(self, "boss_victory")
		if victory_player != null:
			await victory_player.cutscene_finished

	# Campaign dialog: boss_first_kill (fires after loot + cutscene, before transition)
	if _loot_result != null and _loot_result.is_boss_encounter and _loot_result.is_victory:
		var campaign_overlay = CampaignDialog.try_show(self, "boss_first_kill")
		if campaign_overlay != null:
			await campaign_overlay.dialog_finished

	# Campaign victory: show victory panel before transitioning
	if _loot_result != null and _loot_result.is_campaign_victory:
		_show_victory_panel()
		return

	_do_combat_transition()


## Keyboard shortcuts for loot panel (B=shop bag, 1-4=hero, click to select).
func _loot_panel_input(event: InputEvent) -> void:
	if _loot_panel == null or not is_instance_valid(_loot_panel):
		return
	if not GameContext.has_pending_acquisition():
		return
	# Auto-select first item if none selected
	var idx: int = _loot_selected_index if _loot_selected_index >= 0 else 0
	var pending = GameContext.get_all_pending_acquisitions()
	if idx >= pending.size():
		return
	# Shop Bag
	if event.is_action_pressed("loot_shop_bag"):
		GameContext.resolve_acquisition_at(idx, "shop_bag")
		_loot_selected_index = -1
		_refresh_loot_panel()
		get_viewport().set_input_as_handled()
	# Hero 1..4
	elif event.is_action_pressed("loot_hero_1"):
		_loot_route_to_hero(0, idx, pending)
	elif event.is_action_pressed("loot_hero_2"):
		_loot_route_to_hero(1, idx, pending)
	elif event.is_action_pressed("loot_hero_3"):
		_loot_route_to_hero(2, idx, pending)
	elif event.is_action_pressed("loot_hero_4"):
		_loot_route_to_hero(3, idx, pending)
	# Deposit All
	elif event.is_action_pressed("loot_deposit") and not _loot_swap_mode:
		_on_loot_deposit_all()
		get_viewport().set_input_as_handled()
	# Cancel swap mode
	elif event.is_action_pressed("ui_cancel") and _loot_swap_mode:
		_on_swap_cancel()
		get_viewport().set_input_as_handled()


func _loot_route_to_hero(hero_idx: int, idx: int, pending: Array) -> void:
	if hero_idx < GameContext.selected_party.size():
		var hid = GameContext.selected_party[hero_idx]
		if GameContext.can_add_to_hero_bag(hid, pending[idx].get("item_id", ""), 1):
			GameContext.resolve_acquisition_at(idx, "hero_bag", hid)
			_loot_selected_index = -1
			_refresh_loot_panel()
			get_viewport().set_input_as_handled()
		else:
			# Enter swap mode
			_loot_swap_mode = true
			_loot_swap_hero_id = hid
			_loot_swap_acq_index = idx
			_refresh_loot_panel()
			get_viewport().set_input_as_handled()


# ============================================================================
# FLEE DIALOG — Offered when a hero dies in combat
# ============================================================================

func _show_flee_dialog(fallen_name: String) -> void:
	if _flee_dialog != null:
		return

	_flee_dialog = CanvasLayer.new()
	_flee_dialog.layer = 10

	var backdrop = ColorRect.new()
	backdrop.color = Color(0.1, 0.05, 0.05, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flee_dialog.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flee_dialog.add_child(center)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(Color(0.8, 0.5, 0.4, 1)))
	panel.custom_minimum_size = Vector2(450, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "%s has fallen!" % fallen_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameContext.fs(22))
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	vbox.add_child(title)

	# Description
	var desc = Label.new()
	desc.text = "Flee the dungeon to save your remaining heroes?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", GameContext.fs(16))
	desc.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	vbox.add_child(desc)

	# Consequences
	var consequences = Label.new()
	consequences.text = "If you flee:\n  - Equipment above starter gear (tier 1 common) will be lost\n  - Hero bag items will be lost\n  - First 3 shopkeeper bag slots saved (insurance)\n  - Remaining shopkeeper bag items are lost\n  - Dungeon progress and unbanked loot are lost\n  - Gold and XP earned are kept\n\nIf you continue:\n  - Fight on with remaining heroes\n  - Total party wipe = permadeath for all"
	consequences.add_theme_font_size_override("font_size", GameContext.fs(14))
	consequences.add_theme_color_override("font_color", Color(0.65, 0.6, 0.55))
	consequences.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(consequences)

	# Buttons
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var flee_btn = Button.new()
	flee_btn.text = "Flee"
	flee_btn.custom_minimum_size = Vector2(140, 36)
	flee_btn.focus_mode = Control.FOCUS_ALL
	flee_btn.pressed.connect(_on_flee_confirmed)
	btn_row.add_child(flee_btn)

	var fight_btn = Button.new()
	fight_btn.text = "Continue Fighting"
	fight_btn.custom_minimum_size = Vector2(180, 36)
	fight_btn.focus_mode = Control.FOCUS_ALL
	fight_btn.pressed.connect(_on_flee_declined)
	btn_row.add_child(fight_btn)
	fight_btn.call_deferred("grab_focus")

	add_child(_flee_dialog)
	print("[Flee] Dialog shown — %s has fallen" % fallen_name)


func _on_flee_confirmed() -> void:
	print("[Flee] Player chose to flee")

	# Close dialog
	if _flee_dialog != null:
		_flee_dialog.queue_free()
		_flee_dialog = null

	# Cancel mini-dungeon on flee (quest remains active for retry)
	SideQuestSystem.cancel_mini_dungeon()

	# Clear pending acquisitions (unrouted loot lost)
	GameContext.clear_pending_acquisitions()

	# FIX: Persist hero HP so dead heroes are properly recorded on town entry.
	# Without this, _process_dead_heroes() won't see 0 HP heroes (resurrection bug).
	if _combat_controller != null:
		_combat_controller._persist_hero_hp()

	# Flee to town: clears dungeon stash, strips non-starter gear, banks insurance
	GameContext.flee_to_town()

	_do_combat_transition()


func _on_flee_declined() -> void:
	print("[Flee] Player chose to continue fighting")

	if _flee_dialog != null:
		_flee_dialog.queue_free()
		_flee_dialog = null

	# Restore auto-running (paused when flee dialog was shown)
	_is_auto_running = true

	# If the controller is awaiting input for a dead unit, force-pass that turn
	if _combat_controller != null and _combat_controller.is_awaiting_player_input():
		var input_unit = _combat_controller.get_input_unit()
		if input_unit != null and not input_unit.is_alive:
			print("[Flee] Input unit %s is dead — forcing pass" % input_unit.display_name)
			_combat_controller.submit_pass_action()
			return
		# Living unit awaiting input — show action panel
		_ensure_action_panel_visible()
	elif _combat_controller != null and not _combat_controller.is_combat_over():
		_auto_step_combat()


# ============================================================================
# CAMPAIGN VICTORY PANEL — Show when R7 boss is defeated
# ============================================================================

func _show_victory_panel() -> void:
	if _victory_panel != null:
		return

	_victory_panel = CanvasLayer.new()
	_victory_panel.layer = 10

	# Dark gold backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.15, 0.12, 0.05, 0.9)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_panel.add_child(backdrop)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_victory_panel.add_child(center)

	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(Color(0.9, 0.8, 0.5, 1)))
	panel.custom_minimum_size = Vector2(500, 300)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "CAMPAIGN COMPLETE!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameContext.fs(30))
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "You have defeated the Void Threshold and saved the realm!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", GameContext.fs(16))
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.75, 0.5))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	# Stats summary
	var stats_label = Label.new()
	var regions_done: int = GameContext.get_completed_region_count()
	var hero_count: int = GameContext.owned_heroes.size()
	stats_label.text = "Regions Conquered: %d/7\nHeroes in Roster: %d" % [regions_done, hero_count]
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	stats_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	vbox.add_child(stats_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Continue button
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var continue_btn = Button.new()
	continue_btn.text = "Return to Town"
	continue_btn.custom_minimum_size = Vector2(200, 40)
	continue_btn.focus_mode = Control.FOCUS_ALL
	continue_btn.pressed.connect(_on_victory_continue)
	btn_row.add_child(continue_btn)
	continue_btn.call_deferred("grab_focus")

	add_child(_victory_panel)
	print("[Victory] Campaign complete panel shown!")


func _on_victory_continue() -> void:
	if _victory_panel != null:
		_victory_panel.queue_free()
		_victory_panel = null
	_do_combat_transition()


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
	_defeat_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(Color(0.7, 0.3, 0.3, 1)))

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	_defeat_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.name = "DefeatVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "DEFEAT"
	title.add_theme_font_size_override("font_size", GameContext.fs(34))
	title.modulate = Color(1.0, 0.3, 0.3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Your party has fallen..."
	subtitle.add_theme_font_size_override("font_size", GameContext.fs(16))
	subtitle.modulate = Color(0.8, 0.6, 0.6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# Section: Heroes Lost
	var heroes_header = Label.new()
	heroes_header.text = "— Heroes Lost Forever —"
	heroes_header.add_theme_font_size_override("font_size", GameContext.fs(20))
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
	saved_header.add_theme_font_size_override("font_size", GameContext.fs(18))
	saved_header.modulate = Color(0.5, 0.8, 0.5)
	saved_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(saved_header)

	var shop_bag = GameContext.shopkeeper_bag
	if shop_bag.is_empty():
		var no_items = Label.new()
		no_items.text = "(No items in shopkeeper bag)"
		no_items.modulate = Color(0.78, 0.78, 0.78)
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
	continue_btn.focus_mode = Control.FOCUS_ALL
	continue_btn.pressed.connect(_on_defeat_continue)
	btn_row.add_child(continue_btn)
	continue_btn.call_deferred("grab_focus")

	add_child(_defeat_panel)
	print("[Defeat] Panel shown - lost_heroes=%d saved_items=%d" % [lost_heroes.size(), shop_bag.size()])


## Create a panel showing a lost hero and their equipment.
func _create_lost_hero_panel(hero_id: String) -> PanelContainer:
	var panel = PanelContainer.new()

	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(Color(0.7, 0.4, 0.4, 1)))

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
	name_label.add_theme_font_size_override("font_size", GameContext.fs(18))
	name_label.modulate = Color(1.0, 0.7, 0.7)
	vbox.add_child(name_label)

	# Equipment lost
	var equip_header = Label.new()
	equip_header.text = "Equipment Lost:"
	equip_header.add_theme_font_size_override("font_size", GameContext.fs(14))
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
			equip_label.add_theme_font_size_override("font_size", GameContext.fs(13))
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
		bag_label.add_theme_font_size_override("font_size", GameContext.fs(13))
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
			content_label.add_theme_font_size_override("font_size", GameContext.fs(12))
			content_label.modulate = Color(0.7, 0.5, 0.4)
			vbox.add_child(content_label)

	if not has_equipment:
		var no_equip = Label.new()
		no_equip.text = "  (No equipment)"
		no_equip.add_theme_font_size_override("font_size", GameContext.fs(13))
		no_equip.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(no_equip)

	return panel


## Continue from defeat screen — return to town.
func _on_defeat_continue() -> void:
	if _defeat_panel != null:
		_defeat_panel.queue_free()
		_defeat_panel = null

	# Cancel mini-dungeon on defeat (quest remains active for retry)
	SideQuestSystem.cancel_mini_dungeon()

	# Clear any pending acquisitions (dungeon loot is lost on defeat)
	GameContext.clear_pending_acquisitions()

	# Clear dungeon stash (provisional rewards lost)
	GameContext.clear_dungeon_stash()

	# Insurance: bank only safe shopkeeper bag slots before exit
	GameContext.bank_safe_shopkeeper_slots_only()

	# Proper town exit: processes dead heroes, banks bags, heals survivors, saves
	GameContext.exit_to_town()

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
	# Cancel shopkeeper bag swap on Escape / B button
	if not _swap_source.is_empty() and event.is_action_pressed("ui_cancel"):
		_clear_swap_highlight()
		get_viewport().set_input_as_handled()
		return

	# Loot panel shortcuts (intercept first)
	if _loot_panel != null and is_instance_valid(_loot_panel):
		_loot_panel_input(event)
		if get_viewport().is_input_handled():
			return

	# Auto battle toggle
	if event.is_action_pressed("combat_auto"):
		_on_auto_pressed()
		get_viewport().set_input_as_handled()
		return

	# Ability hotkeys: combat actions + pass + cancel
	if _combat_controller != null and _combat_controller.is_awaiting_player_input():
		if _target_selection_active:
			# In target selection: B/Escape cancels
			if event.is_action_pressed("ui_cancel"):
				_on_cancel_pressed()
				get_viewport().set_input_as_handled()
				return
			# In target selection: A/Enter confirms focused target
			if event.is_action_pressed("ui_accept"):
				var focused: Control = get_viewport().gui_get_focus_owner()
				if focused != null and focused.has_meta("unit_id"):
					var uid: String = focused.get_meta("unit_id")
					if uid in _valid_target_ids:
						print("[UI] Controller confirm target: %s" % uid)
						_exit_target_selection_mode()
						_action_panel.visible = false
						_combat_controller.submit_player_target(uid)
						get_viewport().set_input_as_handled()
						return
		else:
			# In action selection: gamepad/keyboard select abilities
			if event.is_action_pressed("combat_action_1"):
				if _btn_basic != null and _btn_basic.visible and not _btn_basic.disabled:
					_on_basic_attack_pressed()
					get_viewport().set_input_as_handled()
					return
			elif event.is_action_pressed("combat_action_2"):
				if _btn_ability_a != null and _btn_ability_a.visible and not _btn_ability_a.disabled:
					_on_ability_a_pressed()
					get_viewport().set_input_as_handled()
					return
			elif event.is_action_pressed("combat_action_3"):
				if _btn_ability_b != null and _btn_ability_b.visible and not _btn_ability_b.disabled:
					_on_ability_b_pressed()
					get_viewport().set_input_as_handled()
					return
			elif event.is_action_pressed("combat_action_4"):
				if _btn_equip_0 != null and _btn_equip_0.visible and not _btn_equip_0.disabled:
					_on_equip_ability_0_pressed()
					get_viewport().set_input_as_handled()
					return
			elif event.is_action_pressed("combat_action_5"):
				if _btn_equip_1 != null and _btn_equip_1.visible and not _btn_equip_1.disabled:
					_on_equip_ability_1_pressed()
					get_viewport().set_input_as_handled()
					return
			elif event.is_action_pressed("combat_pass"):
				if _btn_pass != null and _btn_pass.visible and not _btn_pass.disabled:
					_on_pass_pressed()
					get_viewport().set_input_as_handled()
					return

	# Gamepad inspect: Y button on focused unit portrait → stat overlay
	if event.is_action_pressed("gp_inspect"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_meta("unit_id"):
			var uid: String = focused.get_meta("unit_id")
			_show_stat_inspection(uid)
			get_viewport().set_input_as_handled()
			return

	# Gamepad use_item: X button on focused hero bag slot → consumable use
	if event.is_action_pressed("use_item"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused != null and focused.has_meta("bag_item_id") and focused.has_meta("bag_hero_id"):
			var iid: String = focused.get_meta("bag_item_id")
			var hid: String = focused.get_meta("bag_hero_id")
			var tmpl = DataRegistry.get_item_template(iid)
			if tmpl != null and tmpl.item_type == "consumable":
				if GameContext.can_hero_use_consumable(hid):
					_show_combat_consumable_hero_picker(iid, hid)
					get_viewport().set_input_as_handled()
					return

	# Debug hotkeys (keyboard only)
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
## Status UI v2: Shows pop-text for expired statuses.
func _on_all_statuses_ticked() -> void:
	# Show expiry pop-text for statuses that just expired
	for unit_id in _combat_controller.last_expired_statuses:
		var expired_ids: Array = _combat_controller.last_expired_statuses[unit_id]
		for status_id in expired_ids:
			var status_data = DataRegistry.get_status_effect(status_id)
			var dname: String = status_id.capitalize()
			if status_data:
				dname = status_data.ui_name if status_data.ui_name != "" else status_data.display_name
			_show_pop_text(unit_id, dname + " expired", "status_expire")
	refresh_all_status_badges()
	refresh_all_buff_badges()  # Also refresh buffs (tick at round start too)
	_refresh_all_panels()  # Update HP labels and death state after DOT damage


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
		highlight.color = ACTIVE_HIGHLIGHT_COLOR
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
	label.add_theme_font_size_override("font_size", GameContext.fs(16))
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
	label.add_theme_font_size_override("font_size", GameContext.fs(14))
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
## SFX: Determine and play the appropriate sound for a combat action.
func _play_action_sfx(action: CombatAction) -> void:
	match action.action_type:
		CombatAction.ActionType.BASIC_ATTACK:
			# Determine melee/ranged from actor's attack_type
			var actor: CombatUnit = _combat_controller.get_unit_by_id(action.actor_id) if _combat_controller else null
			var attack_type: String = actor.attack_type if actor != null else "melee"
			if attack_type == "ranged":
				UIAudio.play_sfx("attack_ranged_bow")
			else:
				UIAudio.play_sfx("attack_generic")
			# Impact sound
			if action.damage_dealt > 0:
				if action.was_critical:
					UIAudio.play_sfx("hit_critical")
				else:
					UIAudio.play_sfx("hit_damage")
		CombatAction.ActionType.WEAPON_ABILITY, CombatAction.ActionType.CLASS_ABILITY, CombatAction.ActionType.EQUIPMENT_ABILITY:
			# Spell/ability — play generic spell cast
			if action.healing_done > 0 and action.damage_dealt == 0:
				UIAudio.play_sfx("heal")
			else:
				UIAudio.play_sfx("spell_generic")
				if action.damage_dealt > 0:
					UIAudio.play_sfx("hit_damage")
		CombatAction.ActionType.BUFF:
			UIAudio.play_sfx("buff_apply")
		CombatAction.ActionType.SKIP:
			UIAudio.play_sfx("stun_applied")
		CombatAction.ActionType.DOOM_TRIGGER:
			UIAudio.play_sfx("spell_doom")
		CombatAction.ActionType.DEATH:
			# Determine if hero or enemy died
			var unit: CombatUnit = _combat_controller.get_unit_by_id(action.actor_id) if _combat_controller else null
			if unit != null and unit.team == CombatUnit.Team.PLAYER:
				UIAudio.play_sfx("death_hero")
			else:
				UIAudio.play_sfx("death_enemy")
		CombatAction.ActionType.ITEM_USE:
			UIAudio.play_sfx("consumable_use")

	# Status application sound (additional, on top of action sound)
	if action.status_applied != "":
		var status_id: String = action.status_applied
		if status_id in ["stun", "blinded"]:
			UIAudio.play_sfx("stun_applied")
		elif status_id in ["burning", "poisoned", "bleeding", "shocked", "doom"]:
			UIAudio.play_sfx("debuff_apply")
		elif status_id in ["regenerating", "reflecting", "taunting"]:
			UIAudio.play_sfx("buff_apply")


func _on_action_performed(action: CombatAction) -> void:
	if action == null:
		return

	# SFX: Play sound based on action type
	_play_action_sfx(action)

	# Attack Line v1: Draw visual line from actor to target
	if action.target_id != "" and action.actor_id != "":
		var is_heal = action.healing_done > 0 and action.damage_dealt == 0
		_show_attack_line(action.actor_id, action.target_id, is_heal)

	# Evade pop text (on the unit who evaded the attack)
	if action.was_evaded:
		_show_pop_text(action.target_id, "EVADE", "miss")

	# Damage pop text (on target)
	if action.damage_dealt > 0:
		var kind = "damage"
		if action.was_critical:
			kind = "crit"
		_show_pop_text(action.target_id, "-%d" % action.damage_dealt, kind)
		# Backline tutorial — first time a back-row hero takes damage
		if action.target_id.begins_with("hero_") and _combat_controller != null:
			var target_unit = _combat_controller.get_unit_by_id(action.target_id)
			if target_unit != null and target_unit.is_back_row():
				TutorialOverlay.try_show(self, "tutorial_backline_targeting")

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

	# Tag effect BUFF pop text (buff_stat / reduce_cooldown — no damage/heal/status)
	if action.action_type == CombatAction.ActionType.BUFF and \
	   action.damage_dealt == 0 and action.healing_done == 0 and action.status_applied == "" and \
	   action.message != "":
		_show_pop_text(action.target_id, action.message, "buff_apply")

	# v1.9B: Also add to log overlay
	_on_action_performed_v19b(action)

	# CRITICAL: Refresh HP displays after any action
	_refresh_all_panels()

	# v1.3: Refresh stats window if open (shows updated buffs/HP)
	_refresh_stats_window()

	# Flee trigger: when a player hero dies, offer flee option
	if action.action_type == CombatAction.ActionType.DEATH:
		if action.actor_id.begins_with("hero_"):
			# Track hero death for camp flee button availability
			GameContext.set_hero_died_this_run(true)
			if _flee_dialog == null:
				# Pause auto-stepping
				_is_auto_running = false
				# Show flee tutorial on first hero death
				var tut = TutorialOverlay.try_show(self, "tutorial_flee")
				if tut != null:
					await tut.tutorial_finished
				_show_flee_dialog(action.actor_name)


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
	const TIMELINE_HEIGHT: int = 44
	const TIMELINE_MARGIN: int = 5

	# Position timeline below the dungeon progress label using its actual layout offset
	var timeline_top: float = 65.0
	if dungeon_progress_label != null and dungeon_progress_label.visible:
		timeline_top = dungeon_progress_label.offset_bottom + TIMELINE_MARGIN
	elif top_bar != null:
		timeline_top = top_bar.offset_bottom + TIMELINE_MARGIN

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
	_timeline_panel.offset_left = 80
	_timeline_panel.offset_right = -80
	_timeline_panel.offset_top = timeline_top
	_timeline_panel.offset_bottom = timeline_top + TIMELINE_HEIGHT
	_timeline_panel.custom_minimum_size = Vector2(0, TIMELINE_HEIGHT)
	_timeline_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Style the panel background (region-tinted)
	_timeline_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(_region_palette.get("ui_tint", Color.WHITE)))
	add_child(_timeline_panel)

	# Create timeline HBox inside panel
	_timeline_container = HBoxContainer.new()
	_timeline_container.name = "TurnTimelineContent"
	_timeline_container.add_theme_constant_override("separation", 4)
	_timeline_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_timeline_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline_panel.add_child(_timeline_container)

	# v1.9C: Intent label placed inside timeline panel (right side)
	_current_intent_label = Label.new()
	_current_intent_label.name = "IntentLabel"
	_current_intent_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	_current_intent_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.5, 0.9))
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

	# Style log overlay background (RPG UI Pack)
	_log_overlay_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(_region_palette.get("ui_tint", Color.WHITE)))
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
	log_title.add_theme_font_size_override("font_size", GameContext.fs(12))
	log_title.add_theme_color_override("font_color", Color.DIM_GRAY)
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(log_title)

	# v1.9D: Pin toggle button
	_log_pin_button = Button.new()
	_log_pin_button.text = "Pin"
	_log_pin_button.toggle_mode = true
	_log_pin_button.custom_minimum_size = Vector2(40, 18)
	_log_pin_button.add_theme_font_size_override("font_size", GameContext.fs(11))
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


## Refresh the turn timeline UI with portrait-based entries.
func _refresh_timeline() -> void:
	if _timeline_container == null or not is_instance_valid(_timeline_container):
		return

	_stop_active_pill_pulse()
	_dismiss_pinned_tooltip()

	# Clear existing children EXCEPT the intent label (last child)
	var children = _timeline_container.get_children()
	for i in range(children.size() - 1):  # Skip last child (intent label)
		children[i].queue_free()

	# Get reordered timeline: upcoming first, then acted (moved to end)
	var timeline = _combat_controller.get_reordered_timeline_snapshot()

	# Build portrait lookup for target indicators
	var portrait_by_unit_id: Dictionary = {}
	for entry in timeline:
		portrait_by_unit_id[entry["unit_id"]] = entry.get("portrait_path", "")

	var insert_idx = 0
	var separator_inserted: bool = false
	for entry in timeline:
		# Insert separator between upcoming and acted sections
		if entry.get("has_acted", false) and not separator_inserted:
			var sep = _create_timeline_separator()
			_timeline_container.add_child(sep)
			_timeline_container.move_child(sep, insert_idx)
			insert_idx += 1
			separator_inserted = true
		var pill = _create_timeline_pill(entry, portrait_by_unit_id)
		_timeline_container.add_child(pill)
		_timeline_container.move_child(pill, insert_idx)
		insert_idx += 1

	# Start pulsing on the active pill
	for child in _timeline_container.get_children():
		if child.has_meta("is_active_pill"):
			_start_active_pill_pulse(child.get_meta("pill_style_ref"))
			break


## Create a portrait-based timeline entry for a unit.
## Shows portrait with team-colored border. Active unit gets pulse + name.
func _create_timeline_pill(entry: Dictionary, portrait_map: Dictionary = {}) -> PanelContainer:
	var is_active = entry["is_current"]
	var is_player = entry["team"] == "P"
	var has_acted: bool = entry.get("has_acted", false)
	var pill_size: int = 48 if is_active else 36

	var pill = PanelContainer.new()
	pill.custom_minimum_size = Vector2(pill_size, 0)

	# Determine border color based on team and active state
	var border_color: Color
	var bg_color: Color
	var border_width: int = 1

	if is_active:
		bg_color = Color(0.30, 0.25, 0.10, 0.95)
		border_color = Color(1.0, 0.85, 0.4, 0.9)
		border_width = 3
	elif has_acted:
		# Dimmed style for units that already acted this round
		bg_color = Color(0.10, 0.10, 0.10, 0.6)
		border_color = Color(0.3, 0.3, 0.3, 0.4)
	elif is_player:
		bg_color = Color(0.12, 0.18, 0.14, 0.85)
		border_color = Color(0.3, 0.55, 0.35, 0.7)
	else:
		bg_color = Color(0.20, 0.12, 0.11, 0.85)
		border_color = Color(0.55, 0.3, 0.28, 0.7)

	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = bg_color
	pill_style.border_color = border_color
	pill_style.set_border_width_all(border_width)
	pill_style.set_corner_radius_all(3)
	pill_style.content_margin_left = 2
	pill_style.content_margin_right = 2
	pill_style.content_margin_top = 1
	pill_style.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", pill_style)

	# VBox: portrait on top, indicators below
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	# Portrait (36x36 for active, 28x28 for others)
	var portrait_size: int = 36 if is_active else 28
	var portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(portrait_size, portrait_size)
	portrait_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var portrait_path = entry.get("portrait_path", "")
	if portrait_path != "":
		var tex = load(portrait_path)
		if tex != null:
			portrait_rect.texture = tex

	vbox.add_child(portrait_rect)

	# Active indicator: arrow + name
	if is_active:
		var arrow = Label.new()
		arrow.text = "▶"
		arrow.add_theme_font_size_override("font_size", GameContext.fs(9))
		arrow.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 0.9))
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(arrow)
		var unit_name: String = entry.get("name", "")
		if unit_name.length() > 8:
			unit_name = unit_name.substr(0, 7) + "."
		var name_label = Label.new()
		name_label.text = unit_name
		name_label.add_theme_font_size_override("font_size", GameContext.fs(8))
		name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 0.95))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
		# Store style ref for pulse tween
		pill.set_meta("is_active_pill", true)
		pill.set_meta("pill_style_ref", pill_style)

	# Target indicator: show who this enemy plans to attack
	var intent = entry.get("intent", {})
	if not is_player and not has_acted and not is_active:
		var target_id: String = intent.get("target_id", "")
		if target_id != "":
			var target_portrait: String = portrait_map.get(target_id, "")
			var target_hbox = HBoxContainer.new()
			target_hbox.add_theme_constant_override("separation", 1)
			target_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			var arrow_lbl = Label.new()
			arrow_lbl.text = "→"
			arrow_lbl.add_theme_font_size_override("font_size", GameContext.fs(8))
			arrow_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4, 0.9))
			target_hbox.add_child(arrow_lbl)
			if target_portrait != "" and ResourceLoader.exists(target_portrait):
				var target_tex = load(target_portrait) as Texture2D
				if target_tex != null:
					var target_rect = TextureRect.new()
					target_rect.custom_minimum_size = Vector2(12, 12)
					target_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					target_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					target_rect.texture = target_tex
					target_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
					target_hbox.add_child(target_rect)
			else:
				var target_name: String = intent.get("target_name", "?")
				var letter = Label.new()
				letter.text = target_name.substr(0, 1).to_upper() if target_name != "" else "?"
				letter.add_theme_font_size_override("font_size", GameContext.fs(8))
				letter.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 0.9))
				target_hbox.add_child(letter)
			vbox.add_child(target_hbox)

	pill.add_child(vbox)

	# Rich tooltip with intent preview
	pill.tooltip_text = _build_timeline_tooltip(entry, intent)
	pill.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed:
			_show_pinned_tooltip(pill.tooltip_text, pill)
			get_viewport().set_input_as_handled()
	)

	return pill


## Create a thin gold separator bar between upcoming and already-acted units in the timeline.
func _create_timeline_separator() -> PanelContainer:
	var sep = PanelContainer.new()
	sep.custom_minimum_size = Vector2(4, 32)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.85, 0.4, 0.6)
	style.set_corner_radius_all(1)
	sep.add_theme_stylebox_override("panel", style)
	sep.tooltip_text = "Turn order divider"
	return sep


## Start border color pulse on the active turn pill.
func _start_active_pill_pulse(pill_style: StyleBoxFlat) -> void:
	_stop_active_pill_pulse()
	_active_pill_tween = create_tween()
	_active_pill_tween.set_loops()
	_active_pill_tween.tween_method(
		func(c: Color):
			if is_instance_valid(pill_style):
				pill_style.border_color = c,
		ACTIVE_PILL_BORDER_MIN, ACTIVE_PILL_BORDER_MAX, 0.5
	)
	_active_pill_tween.tween_method(
		func(c: Color):
			if is_instance_valid(pill_style):
				pill_style.border_color = c,
		ACTIVE_PILL_BORDER_MAX, ACTIVE_PILL_BORDER_MIN, 0.5
	)


## Stop and clean up active pill pulse tween.
func _stop_active_pill_pulse() -> void:
	if _active_pill_tween != null:
		if _active_pill_tween.is_valid():
			_active_pill_tween.kill()
		_active_pill_tween = null


## Show a pinned tooltip panel near the source control.
func _show_pinned_tooltip(text: String, source_control: Control) -> void:
	_dismiss_pinned_tooltip()
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.8, 0.7, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	var content_label = Label.new()
	# Strip the "Ctrl+Click to pin" hint from pinned view
	var display_text: String = text.replace("\n\nCtrl+Click to pin", "")
	content_label.text = display_text
	content_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	content_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.custom_minimum_size.x = 280
	vbox.add_child(content_label)
	var hint_label = Label.new()
	hint_label.text = "Ctrl+Click to close"
	hint_label.add_theme_font_size_override("font_size", GameContext.fs(10))
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(hint_label)
	panel.add_child(vbox)
	panel.z_index = 50
	# Position above the source control
	var src_pos: Vector2 = source_control.global_position
	panel.position = Vector2(src_pos.x, maxf(src_pos.y - 200, 10))
	add_child(panel)
	_pinned_tooltip_panel = panel
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.ctrl_pressed:
			_dismiss_pinned_tooltip()
			get_viewport().set_input_as_handled()
	)


## Dismiss the pinned tooltip panel if it exists.
func _dismiss_pinned_tooltip() -> void:
	if _pinned_tooltip_panel != null and is_instance_valid(_pinned_tooltip_panel):
		_pinned_tooltip_panel.queue_free()
	_pinned_tooltip_panel = null


## Build a multi-line tooltip for a timeline pill showing unit info and predicted intent.
func _build_timeline_tooltip(entry: Dictionary, intent: Dictionary) -> String:
	var lines: Array = []
	var team_label: String = "Player" if entry["team"] == "P" else "Enemy"
	lines.append("%s (%s)" % [entry["name"], team_label])
	lines.append("SPD: %d" % entry["speed"])

	if intent.is_empty():
		return "\n".join(lines)

	lines.append("───────────")

	if intent.get("is_stunned", false):
		lines.append("Stunned - will skip turn")
		return "\n".join(lines)

	var action_type: String = intent.get("action_type", "")

	if action_type == "player":
		var abilities = intent.get("ready_abilities", [])
		if abilities.size() > 0:
			lines.append("Abilities:")
			for ab in abilities:
				var status: String = "ready" if ab.get("ready", false) else "%d cd" % ab.get("cooldown", 0)
				lines.append("  %s (%s)" % [ab.get("name", "?"), status])
				var ab_desc: String = ab.get("desc", "")
				if ab_desc != "":
					lines.append("    \"%s\"" % ab_desc)
		else:
			lines.append("Basic Attack")
	elif action_type == "tactical":
		var abilities = intent.get("ready_abilities", [])
		lines.append("May use:")
		for ab in abilities:
			lines.append("  %s" % ab.get("name", "?"))
			var ab_desc: String = ab.get("desc", "")
			if ab_desc != "":
				lines.append("    \"%s\"" % ab_desc)
		var tac_target: String = intent.get("target_name", "")
		if tac_target != "":
			lines.append("Target: %s" % tac_target)
	else:
		# Deterministic enemy prediction
		var ability_name: String = intent.get("ability_name", "Attack")
		lines.append("Next: %s" % ability_name)
		var desc: String = intent.get("ability_desc", "")
		if desc != "":
			lines.append("  \"%s\"" % desc)
		var target: String = intent.get("target_name", "")
		if target != "":
			lines.append("Target: %s" % target)

	lines.append("")
	lines.append("Ctrl+Click to pin")
	return "\n".join(lines)


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
		label.add_theme_font_size_override("font_size", GameContext.fs(12))

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
		CombatAction.ActionType.BUFF:
			if action.message != "":
				log_entry = action.message

	if log_entry != "":
		_add_to_log_overlay(log_entry)

	# Also refresh timeline (unit may have died)
	_refresh_timeline()


# ============================================================================
# PLAYER ACTIONS v1: Action Selection UI
# ============================================================================

## Create the action panel with buttons for Basic Attack, Ability A, Ability B.
## Uses a PanelContainer wrapper with a highlighted background so it stands out.
## Two-row layout: Row 1 = class actions, Row 2 = equipment abilities (hidden if none).
func _create_action_panel() -> void:
	if _action_panel != null:
		_action_panel.queue_free()

	# Outer PanelContainer with highlighted background
	_action_panel = PanelContainer.new()
	_action_panel.name = "ActionPanel"
	_action_panel.visible = false
	_action_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(_region_palette.get("ui_tint", Color.WHITE)))

	# VBox to hold two rows
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_action_panel.add_child(vbox)

	# Row 1: Class actions (Basic Attack, Ability A, Ability B, Pass, Cancel)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_action_label = Label.new()
	_action_label.text = "Choose Action:"
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 0.9))
	_action_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	hbox.add_child(_action_label)

	_btn_basic = Button.new()
	_btn_basic.text = "Basic Attack"
	_btn_basic.custom_minimum_size = Vector2(120, 34)
	_btn_basic.focus_mode = Control.FOCUS_ALL
	_btn_basic.pressed.connect(_on_basic_attack_pressed)
	hbox.add_child(_btn_basic)

	_btn_ability_a = Button.new()
	_btn_ability_a.custom_minimum_size = Vector2(150, 34)
	_btn_ability_a.focus_mode = Control.FOCUS_ALL
	_btn_ability_a.pressed.connect(_on_ability_a_pressed)
	hbox.add_child(_btn_ability_a)

	_btn_ability_b = Button.new()
	_btn_ability_b.custom_minimum_size = Vector2(150, 34)
	_btn_ability_b.focus_mode = Control.FOCUS_ALL
	_btn_ability_b.pressed.connect(_on_ability_b_pressed)
	hbox.add_child(_btn_ability_b)

	_btn_use_item = Button.new()
	_btn_use_item.text = "Use Item"
	_btn_use_item.custom_minimum_size = Vector2(100, 34)
	_btn_use_item.pressed.connect(_on_use_item_pressed)
	_btn_use_item.visible = false
	hbox.add_child(_btn_use_item)

	_btn_pass = Button.new()
	_btn_pass.text = "Pass"
	_btn_pass.custom_minimum_size = Vector2(80, 34)
	_btn_pass.focus_mode = Control.FOCUS_ALL
	_btn_pass.pressed.connect(_on_pass_pressed)
	hbox.add_child(_btn_pass)

	_btn_cancel = Button.new()
	_btn_cancel.text = "Cancel"
	_btn_cancel.custom_minimum_size = Vector2(80, 34)
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	_btn_cancel.visible = false
	hbox.add_child(_btn_cancel)

	# Row 2: Equipment abilities (hidden by default, shown only when hero has T4 gear)
	_equip_row = HBoxContainer.new()
	_equip_row.add_theme_constant_override("separation", 8)
	_equip_row.visible = false
	vbox.add_child(_equip_row)

	var equip_label = Label.new()
	equip_label.text = "Equipment:"
	equip_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.9))
	equip_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	_equip_row.add_child(equip_label)

	_btn_equip_0 = Button.new()
	_btn_equip_0.custom_minimum_size = Vector2(150, 34)
	_btn_equip_0.focus_mode = Control.FOCUS_ALL
	_btn_equip_0.pressed.connect(_on_equip_ability_0_pressed)
	_btn_equip_0.visible = false
	_equip_row.add_child(_btn_equip_0)

	_btn_equip_1 = Button.new()
	_btn_equip_1.custom_minimum_size = Vector2(150, 34)
	_btn_equip_1.focus_mode = Control.FOCUS_ALL
	_btn_equip_1.pressed.connect(_on_equip_ability_1_pressed)
	_btn_equip_1.visible = false
	_equip_row.add_child(_btn_equip_1)

	# Add to bottom panel — insert BEFORE ButtonRow so it renders above standard buttons
	var button_row = $BottomPanel/ButtonRow
	$BottomPanel.add_child(_action_panel)
	$BottomPanel.move_child(_action_panel, button_row.get_index())


## Handle player_input_required signal - show action buttons.
func _on_player_input_required(unit: CombatUnit, available_actions: Array) -> void:
	print("[UI] player_input_required received for %s, auto_running=%s" % [unit.display_name, str(_is_auto_running)])
	_exit_target_selection_mode()

	# Store the current input unit for tooltip calculations
	_current_input_unit = unit

	# Refresh hero bag display for the active hero
	_refresh_hero_bag_display(unit.source_id)

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
	_btn_use_item.visible = false
	_equip_row.visible = false
	_btn_equip_0.visible = false
	_btn_equip_1.visible = false

	# Use Item button: show if hero has consumables in bag
	var active_hero_id: String = unit.source_id
	var hero_bag: Array = GameContext.get_hero_bag(active_hero_id)
	var has_consumables: bool = false
	for bag_entry in hero_bag:
		var tmpl = DataRegistry.get_item_template(bag_entry.get("item_id", ""))
		if tmpl != null and tmpl.item_type == "consumable":
			has_consumables = true
			break
	if has_consumables:
		var can_use: bool = GameContext.can_hero_use_consumable(active_hero_id)
		_btn_use_item.visible = true
		_btn_use_item.disabled = not can_use
		_btn_use_item.tooltip_text = "Use a consumable from bag (free action)" if can_use else "Already used an item this combat"

	# Update button states from available actions
	for action_info in available_actions:
		var atype: String = action_info.type
		if atype == "basic":
			_btn_basic.text = "[1] Attack"
			_btn_basic.disabled = false
			_btn_basic.tooltip_text = _build_action_tooltip(unit, null, "basic")
		elif atype == "ability_a":
			_btn_ability_a.text = "[2] %s" % action_info.name
			if action_info.cooldown > 0:
				_btn_ability_a.text += " (CD:%d)" % action_info.cooldown
			_btn_ability_a.disabled = not action_info.enabled
			_btn_ability_a.visible = true
			_btn_ability_a.tooltip_text = _build_action_tooltip(unit, action_info.get("ability"), "ability_a")
		elif atype == "ability_b":
			_btn_ability_b.text = "[3] %s" % action_info.name
			if action_info.cooldown > 0:
				_btn_ability_b.text += " (CD:%d)" % action_info.cooldown
			_btn_ability_b.disabled = not action_info.enabled
			_btn_ability_b.visible = true
			_btn_ability_b.tooltip_text = _build_action_tooltip(unit, action_info.get("ability"), "ability_b")
		elif atype == "pass":
			_btn_pass.text = "[P] Pass"
			_btn_pass.visible = true
			_btn_pass.tooltip_text = "Skip remaining actions and end turn."
		elif atype.begins_with("equip_ability_"):
			_equip_row.visible = true
			var eq_idx: int = int(action_info.get("equip_index", 0))
			var btn: Button = _btn_equip_0 if eq_idx == 0 else _btn_equip_1
			btn.text = "[%d] %s" % [eq_idx + 4, action_info.name]
			if action_info.cooldown > 0:
				btn.text += " (CD:%d)" % action_info.cooldown
			btn.disabled = not action_info.enabled
			btn.visible = true
			btn.tooltip_text = _build_action_tooltip(unit, action_info.get("ability"), atype)

	# Show locked abilities as disabled buttons with level requirement
	if not _btn_ability_a.visible and unit.ability_a_id != "":
		var locked_ab = DataRegistry.get_ability(unit.ability_a_id)
		var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_a", 5)
		_btn_ability_a.text = "[2] %s (Lv %d)" % [locked_ab.display_name if locked_ab else unit.ability_a_id, req_lv]
		_btn_ability_a.disabled = true
		_btn_ability_a.visible = true
		_btn_ability_a.tooltip_text = "Unlocks at hero level %d" % req_lv

	if not _btn_ability_b.visible and unit.ability_b_id != "":
		var locked_ab = DataRegistry.get_ability(unit.ability_b_id)
		var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_b", 25)
		_btn_ability_b.text = "[3] %s (Lv %d)" % [locked_ab.display_name if locked_ab else unit.ability_b_id, req_lv]
		_btn_ability_b.disabled = true
		_btn_ability_b.visible = true
		_btn_ability_b.tooltip_text = "Unlocks at hero level %d" % req_lv

	_log("[color=#ffcc66]%s's turn - choose an action[/color]" % unit.display_name)
	print("[UI] Action panel shown, awaiting player input")

	# Grab focus on basic attack for gamepad navigation
	if _btn_basic != null and _btn_basic.visible and not _btn_basic.disabled:
		_btn_basic.call_deferred("grab_focus")

	# Register focus zones for controller navigation (action buttons + hero bag)
	_register_action_zones()

	# Tutorial: first time a hero has an unlocked ability (spotlight action panel)
	if _btn_ability_a.visible and not _btn_ability_a.disabled:
		var ability_tut_targets: Dictionary = {}
		if _action_panel != null:
			ability_tut_targets["action_panel"] = _action_panel
		TutorialOverlay.try_show(self, "tutorial_abilities", ability_tut_targets)

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
		# Auto mode: pass the turn instead of canceling (cancel loops back infinitely)
		if _is_auto_running and _combat_controller != null:
			print("[UI] Auto mode: no targets, auto-passing turn")
			_combat_controller.submit_pass_action()
			return
		_log("[color=red]No valid targets![/color]")
		# Cancel back to action selection
		if _combat_controller != null:
			_combat_controller.cancel_player_action()
		_ensure_action_panel_visible()
		return

	print("[UI] Entering target selection mode")
	_enter_target_selection_mode(valid_targets)
	_btn_cancel.visible = true

	var target_type = "enemy"
	if valid_targets.size() > 0 and valid_targets[0].get("is_ally", false):
		target_type = "ally"
	_log("[color=yellow]Click on a %s to target[/color]" % target_type)


## Handle multi_action_update signal - update action label and hero card turn counter.
func _on_multi_action_update(unit: CombatUnit, remaining: int, total: int) -> void:
	if _action_label != null:
		var action_num = total - remaining + 1
		_action_label.text = "Action %d/%d:" % [action_num, total]

	# D2: Update hero card turn counter
	var turn_lbl = _unit_turn_labels.get(unit.unit_id)
	if turn_lbl != null and is_instance_valid(turn_lbl):
		var action_num_tc: int = total - remaining + 1
		turn_lbl.text = "Turn %d/%d" % [action_num_tc, total]


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

			# Connect click and hover handlers to Portrait for target selection
			var portrait = display.find_child("Portrait", true, false)
			if portrait:
				# Disconnect old target handlers to prevent duplicates
				for connection in portrait.gui_input.get_connections():
					if connection.callable.get_method() == "_on_unit_clicked":
						portrait.gui_input.disconnect(connection.callable)
				for connection in portrait.mouse_entered.get_connections():
					if connection.callable.get_method() == "_on_target_mouse_entered":
						portrait.mouse_entered.disconnect(connection.callable)
				for connection in portrait.mouse_exited.get_connections():
					if connection.callable.get_method() == "_on_target_mouse_exited":
						portrait.mouse_exited.disconnect(connection.callable)

				portrait.gui_input.connect(_on_unit_clicked.bind(unit_id))
				portrait.mouse_entered.connect(_on_target_mouse_entered.bind(unit_id))
				portrait.mouse_exited.connect(_on_target_mouse_exited.bind(unit_id))
		else:
			# Gray out non-valid targets
			display.modulate = Color(0.7, 0.7, 0.7)

	# Disable InspectBtn focus so wrapper gets direct D-pad focus
	for unit_id in _valid_target_ids:
		var d: Control = _unit_displays.get(unit_id)
		if d:
			var ibtn = d.find_child("InspectBtn", true, false)
			if ibtn:
				ibtn.focus_mode = Control.FOCUS_NONE
			# Connect focus-based highlight for D-pad navigation
			for conn in d.focus_entered.get_connections():
				if conn.callable.get_method() == "_on_target_focus_entered":
					d.focus_entered.disconnect(conn.callable)
			for conn in d.focus_exited.get_connections():
				if conn.callable.get_method() == "_on_target_focus_exited":
					d.focus_exited.disconnect(conn.callable)
			d.focus_entered.connect(_on_target_focus_entered.bind(unit_id))
			d.focus_exited.connect(_on_target_focus_exited.bind(unit_id))

	# Register target zone for controller D-pad navigation
	_register_target_zones()


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


## Handle D-pad focus entering a valid target during target selection.
func _on_target_focus_entered(unit_id: String) -> void:
	if not _target_selection_active or unit_id not in _valid_target_ids:
		return
	var highlight = _target_highlights.get(unit_id)
	if highlight:
		highlight.color = Color(0.4, 1.0, 0.4, 0.4)  # Brighter green on focus


## Handle D-pad focus exiting a valid target during target selection.
func _on_target_focus_exited(unit_id: String) -> void:
	if not _target_selection_active or unit_id not in _valid_target_ids:
		return
	var highlight = _target_highlights.get(unit_id)
	if highlight:
		highlight.color = Color(0.2, 0.8, 0.2, 0.15)  # Subtle green


## Exit target selection mode - restore normal display.
func _exit_target_selection_mode() -> void:
	_target_selection_active = false
	_valid_target_ids.clear()

	for unit_id in _unit_displays.keys():
		var display = _unit_displays[unit_id]
		display.modulate = Color.WHITE

		# Disconnect target selection handlers from Portrait
		var portrait = display.find_child("Portrait", true, false)
		if portrait:
			for connection in portrait.gui_input.get_connections():
				if connection.callable.get_method() == "_on_unit_clicked":
					portrait.gui_input.disconnect(connection.callable)
			for connection in portrait.mouse_entered.get_connections():
				if connection.callable.get_method() == "_on_target_mouse_entered":
					portrait.mouse_entered.disconnect(connection.callable)
			for connection in portrait.mouse_exited.get_connections():
				if connection.callable.get_method() == "_on_target_mouse_exited":
					portrait.mouse_exited.disconnect(connection.callable)

		# Disconnect focus-based highlight handlers
		for conn in display.focus_entered.get_connections():
			if conn.callable.get_method() == "_on_target_focus_entered":
				display.focus_entered.disconnect(conn.callable)
		for conn in display.focus_exited.get_connections():
			if conn.callable.get_method() == "_on_target_focus_exited":
				display.focus_exited.disconnect(conn.callable)

		# Restore InspectBtn focus
		var inspect_btn = display.find_child("InspectBtn", true, false)
		if inspect_btn:
			inspect_btn.focus_mode = Control.FOCUS_ALL

		# Hide highlight
		var highlight = display.get_node_or_null("TargetHighlight")
		if highlight:
			highlight.visible = false

	_target_highlights.clear()

	# Remove focus_mode from unit displays and clear target zones
	_clear_target_focus()

	# Defensive re-show: ensure action panel is visible if still awaiting player input
	_ensure_action_panel_visible()


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


## Defensive helper: re-show action panel if the combat controller is still waiting for player input.
## Call this after any overlay close, cancel, or action completion that might leave the panel hidden.
func _ensure_action_panel_visible() -> void:
	if _action_panel != null and _combat_controller != null and _combat_controller.is_awaiting_player_input():
		_action_panel.visible = true


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


## Handle Equipment Ability 0 button press.
func _on_equip_ability_0_pressed() -> void:
	print("[UI] Equipment Ability 0 button pressed")
	_combat_controller.submit_player_action("equip_ability_0")


## Handle Equipment Ability 1 button press.
func _on_equip_ability_1_pressed() -> void:
	print("[UI] Equipment Ability 1 button pressed")
	_combat_controller.submit_player_action("equip_ability_1")


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

	# Safety: if all enemies are dead, pass instead of attacking (prevents infinite loop)
	if _combat_controller._turn_queue.is_team_wiped(CombatUnit.Team.ENEMY):
		print("[UI] _auto_select_action: all enemies dead, auto-passing")
		_combat_controller.submit_pass_action()
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
# UNIT DISPLAY INPUT — Unified Click Handler
# ============================================================================

## Left-click input handler for Portrait — quick basic attack on enemies.
func _on_unit_left_click_input(event: InputEvent, unit_id: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_unit_left_clicked(unit_id)


## Handle left-click on a unit display: quick basic attack on enemies.
func _on_unit_left_clicked(unit_id: String) -> void:
	# If in target selection mode, let the existing system handle it
	if _target_selection_active:
		return
	# Quick basic attack: only on enemies while awaiting player input
	if _combat_controller == null:
		return
	if not unit_id.begins_with("enemy_"):
		return
	# Hide panel BEFORE submit — submit may synchronously show it for the next hero
	if _action_panel != null:
		_action_panel.visible = false
	if _combat_controller.submit_basic_attack_on_target(unit_id):
		print("[UI] Quick basic attack on %s" % unit_id)
	else:
		# Submit failed (invalid target) — restore panel
		_ensure_action_panel_visible()


# ============================================================================
# STAT INSPECTION — Inspect Button Popup (CanvasLayer overlay)
# ============================================================================


## Show a stat inspection overlay for any unit (hero or enemy).
func _show_stat_inspection(unit_id: String) -> void:
	_close_stat_inspection()

	var snapshot = _combat_controller.get_units_snapshot()
	var unit_data: Dictionary = {}
	for u in snapshot["player"] + snapshot["enemy"]:
		if u["id"] == unit_id:
			unit_data = u
			break
	if unit_data.is_empty():
		return

	_inspect_unit_id = unit_id

	# CanvasLayer overlay (layer 10) — works in all scene contexts
	_inspect_overlay = CanvasLayer.new()
	_inspect_overlay.layer = 10

	# Semi-transparent backdrop (click to close)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_inspect_backdrop_input)
	_inspect_overlay.add_child(backdrop)

	# Center the panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspect_overlay.add_child(center)

	# Panel container
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(_region_palette.get("ui_tint", Color.WHITE)))
	center.add_child(panel)

	# Content
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_build_stat_inspection_content(vbox, unit_data)

	add_child(_inspect_overlay)
	UIAudio.register_closeable(_inspect_overlay, _close_stat_inspection)
	print("[UI] Stat inspection opened for %s" % unit_id)


## Build the stat inspection panel content.
func _build_stat_inspection_content(vbox: VBoxContainer, unit_data: Dictionary) -> void:
	var display_name: String = unit_data["name"]
	var is_hero: bool = unit_data["team"] == "player"

	# --- Header ---
	if is_hero:
		var cls_name := ""
		if unit_data.get("class_id", "") != "":
			var cls_data = DataRegistry.get_class_data(unit_data["class_id"])
			cls_name = cls_data.display_name if cls_data != null and cls_data.display_name != "" else unit_data["class_id"].capitalize()
		var hero_id: String = unit_data.get("source_id", unit_data["id"])
		var hero_level := 1
		if GameContext.has_method("get_hero_effective_stats"):
			var stats = GameContext.get_hero_effective_stats(hero_id)
			hero_level = stats.get("level", 1)
		_add_inspect_header(vbox, "%s — %s Lv%d" % [display_name, cls_name, hero_level])
		# XP progress (heroes only)
		var xp_prog: Dictionary = GameContext.get_hero_xp_progress(hero_id)
		var xp_lbl = Label.new()
		if xp_prog.is_max:
			xp_lbl.text = "XP: MAX LEVEL"
			xp_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			xp_lbl.text = "XP: %d / %d" % [xp_prog.current, xp_prog.needed]
			xp_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		xp_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(xp_lbl)
	else:
		var uid: String = unit_data.get("id", "")
		if uid.begins_with("enemy_"):
			var enemy_num: int = int(uid.replace("enemy_", "")) + 1
			display_name = "%s #%d" % [unit_data["name"], enemy_num]
		var inspect_atk_type: String = unit_data.get("attack_type", "melee")
		var inspect_type_label: String = "Ranged" if inspect_atk_type == "ranged" else "Melee"
		_add_inspect_header(vbox, "%s (%s)" % [display_name, inspect_type_label])

	_add_inspect_separator(vbox)

	# --- HP ---
	var hp_pct: float = float(unit_data["hp"]) / float(unit_data["max_hp"]) if unit_data["max_hp"] > 0 else 0.0
	var hp_color: Color = Color(0.2, 0.8, 0.2) if hp_pct > 0.5 else (Color(0.9, 0.7, 0.1) if hp_pct > 0.25 else Color(0.9, 0.2, 0.2))
	_add_inspect_stat(vbox, "HP", "%d / %d" % [unit_data["hp"], unit_data["max_hp"]], hp_color,
		"Current health. Reaching 0 means death.")

	_add_inspect_separator(vbox)

	# --- Core Stats ---
	var atk: int = unit_data.get("attack", 0)
	var base_atk: int = unit_data.get("base_attack", 0)
	var def_val: int = unit_data.get("defense", 0)
	var base_def: int = unit_data.get("base_defense", 0)
	var spd: int = unit_data.get("speed", 0)
	var base_spd: int = unit_data.get("base_speed", 0)

	var atk_label: String = "%d" % atk
	if atk != base_atk:
		atk_label += "  (base %d, %+d)" % [base_atk, atk - base_atk]
	_add_inspect_stat(vbox, "ATK", atk_label, Color(0.9, 0.6, 0.3),
		"Attack power. Determines physical damage dealt by basic attacks and many abilities.")

	var def_label: String = "%d" % def_val
	if def_val != base_def:
		def_label += "  (base %d, %+d)" % [base_def, def_val - base_def]
	_add_inspect_stat(vbox, "DEF", def_label, Color(0.4, 0.7, 0.9),
		"Defense. Reduces incoming physical damage. Damage = max(1, ATK - DEF).")

	var spd_label: String = "%d" % spd
	if spd != base_spd:
		spd_label += "  (base %d, %+d)" % [base_spd, spd - base_spd]
	_add_inspect_stat(vbox, "SPD", spd_label, Color(0.7, 0.9, 0.5),
		"Speed. Determines turn order each round. Higher speed acts first.")

	# --- New Stats (only show if > 0) ---
	var inspect_new_stats = [
		{"key": "crit_chance", "label": "CRIT", "color": Color(1.0, 0.7, 0.3), "suffix": "%", "desc": "Critical hit chance. % to deal 1.5x damage. Capped at 50%."},
		{"key": "evasion", "label": "EVD", "color": Color(0.6, 0.9, 0.6), "suffix": "%", "desc": "Evasion. % chance to dodge incoming attacks. Capped at 50%."},
		{"key": "resist", "label": "RES", "color": Color(0.7, 0.5, 0.9), "suffix": "", "desc": "Resistance. Reduces fire, dark, and void damage using defense soft-cap."},
		{"key": "thorns", "label": "THN", "color": Color(0.8, 0.4, 0.4), "suffix": "", "desc": "Thorns. Flat damage returned to physical attackers (true damage)."},
		{"key": "armor_penetration", "label": "PEN", "color": Color(0.9, 0.6, 0.5), "suffix": "", "desc": "Armor penetration. Reduces target's defense before soft-cap."},
		{"key": "life_steal", "label": "LSTL", "color": Color(0.8, 0.3, 0.3), "suffix": "%", "desc": "Life steal. % of direct damage dealt healed."},
	]
	for ins in inspect_new_stats:
		var ins_val = int(unit_data.get(ins.key, 0))
		if ins_val > 0:
			_add_inspect_stat(vbox, ins.label, "%d%s" % [ins_val, ins.suffix], ins.color, ins.desc)

	# --- Abilities (all units) ---
	var inspect_hero_id: String = unit_data.get("source_id", unit_data["id"])
	var inspect_hero_level := 1
	if is_hero and GameContext.has_method("get_hero_effective_stats"):
		var h_stats = GameContext.get_hero_effective_stats(inspect_hero_id)
		inspect_hero_level = h_stats.get("level", 1)

	var ability_a_id: String = unit_data.get("ability_a_id", "")
	var ability_b_id: String = unit_data.get("ability_b_id", "")
	if ability_a_id != "" or ability_b_id != "":
		_add_inspect_separator(vbox)
		_add_inspect_section_label(vbox, "Abilities")

	if ability_a_id != "":
		var ability_a = DataRegistry.get_ability(ability_a_id) if DataRegistry.has_method("get_ability") else null
		var a_name: String = ability_a.display_name if ability_a else ability_a_id.replace("_", " ").capitalize()
		var a_desc: String = ability_a.description if ability_a != null else ""
		if is_hero:
			if GameContext.is_ability_slot_unlocked("ability_a", inspect_hero_level):
				var cd_a: int = unit_data.get("ability_a_cooldown", 0)
				var cd_str: String = "CD: %d" % cd_a if cd_a > 0 else "Ready"
				_add_inspect_ability(vbox, a_name, cd_str, a_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_a", 5)
				_add_inspect_ability(vbox, a_name, "Lv %d" % req_lv, a_desc)
		else:
			var cd_a: int = unit_data.get("ability_a_cooldown", 0)
			var cd_str: String = "CD: %d" % cd_a if cd_a > 0 else "Ready"
			_add_inspect_ability(vbox, a_name, cd_str, a_desc)

	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name: String = ability_b.display_name if ability_b else ability_b_id.replace("_", " ").capitalize()
		var b_desc: String = ability_b.description if ability_b != null else ""
		if is_hero:
			if GameContext.is_ability_slot_unlocked("ability_b", inspect_hero_level):
				var cd_b: int = unit_data.get("ability_b_cooldown", 0)
				var cd_str: String = "CD: %d" % cd_b if cd_b > 0 else "Ready"
				_add_inspect_ability(vbox, b_name, cd_str, b_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_b", 25)
				_add_inspect_ability(vbox, b_name, "Lv %d" % req_lv, b_desc)
		else:
			var cd_b: int = unit_data.get("ability_b_cooldown", 0)
			var cd_str: String = "CD: %d" % cd_b if cd_b > 0 else "Ready"
			_add_inspect_ability(vbox, b_name, cd_str, b_desc)

	# --- Passives (all units) ---
	var passive_a_id: String = unit_data.get("passive_a_id", "")
	var passive_b_id: String = unit_data.get("passive_b_id", "")
	if passive_a_id != "" or passive_b_id != "":
		_add_inspect_separator(vbox)
		_add_inspect_section_label(vbox, "Passives")

	if passive_a_id != "":
		var passive_a = DataRegistry.get_passive(passive_a_id) if DataRegistry.has_method("get_passive") else null
		var pa_name: String = passive_a.display_name if passive_a else passive_a_id.replace("_", " ").capitalize()
		var pa_desc: String = passive_a.description if passive_a != null else ""
		if is_hero:
			if GameContext.is_ability_slot_unlocked("passive_a", inspect_hero_level):
				_add_inspect_passive(vbox, pa_name, pa_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_a", 15)
				_add_inspect_passive(vbox, "%s (Lv %d)" % [pa_name, req_lv], pa_desc)
		else:
			_add_inspect_passive(vbox, pa_name, pa_desc)

	if passive_b_id != "":
		var passive_b = DataRegistry.get_passive(passive_b_id) if DataRegistry.has_method("get_passive") else null
		var pb_name: String = passive_b.display_name if passive_b else passive_b_id.replace("_", " ").capitalize()
		var pb_desc: String = passive_b.description if passive_b != null else ""
		if is_hero:
			if GameContext.is_ability_slot_unlocked("passive_b", inspect_hero_level):
				_add_inspect_passive(vbox, pb_name, pb_desc)
			else:
				var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_b", 40)
				_add_inspect_passive(vbox, "%s (Lv %d)" % [pb_name, req_lv], pb_desc)
		else:
			_add_inspect_passive(vbox, pb_name, pb_desc)

	# --- Active Statuses (enhanced with descriptions + damage info) ---
	var statuses: Array = unit_data.get("active_statuses_v1", [])
	if statuses.size() > 0:
		_add_inspect_separator(vbox)
		_add_inspect_section_label(vbox, "Status Effects")
		for s in statuses:
			var s_id: String = s.get("id", "?")
			var s_name: String = s.get("ui_name", s_id.capitalize())
			if s_name == "":
				s_name = s_id.capitalize()
			var s_dur: int = s.get("remaining_rounds", 0)
			var s_stacks: int = s.get("stacks", 1)
			var s_tags: Array = s.get("tags", [])
			var dur_text: String = "%d turns" % s_dur
			if s_stacks > 1:
				dur_text += " (x%d)" % s_stacks
			_add_inspect_status_line(vbox, s_name, dur_text, Color(0.9, 0.5, 0.5))

			# Enhanced: description + damage info from DataRegistry
			var status_data = DataRegistry.get_status_effect(s_id) if DataRegistry.has_method("get_status_effect") else null
			if status_data != null:
				if status_data.description != "":
					_add_inspect_detail_line(vbox, status_data.description, Color(0.75, 0.65, 0.6))
				if "dot" in s_tags or status_data.category == "dot":
					var base_dmg: int = status_data.base_value
					var per_stack: int = status_data.value_per_stack
					var total_dmg: int = base_dmg + (per_stack * (s_stacks - 1)) if s_stacks > 1 else base_dmg
					if total_dmg > 0:
						_add_inspect_detail_line(vbox, "  Damage: %d/turn" % total_dmg, Color(0.9, 0.6, 0.5))
				if "control" in s_tags or status_data.category == "control":
					_add_inspect_detail_line(vbox, "  Cannot act while active", Color(0.9, 0.6, 0.5))
				if status_data.is_cleansable:
					_add_inspect_detail_line(vbox, "  (Cleansable)", Color(0.7, 0.7, 0.6))

	# --- Active Buffs (enhanced with descriptions) ---
	var buffs: Array = unit_data.get("active_buffs_v1", [])
	if buffs.size() > 0:
		_add_inspect_separator(vbox)
		_add_inspect_section_label(vbox, "Buffs")
		for b in buffs:
			var b_name: String = b.get("ui_name", b.get("source", "?").capitalize())
			if b_name == "":
				b_name = b.get("source", "?").capitalize()
			var b_dur: int = b.get("remaining_rounds", 0)
			var b_stats: Dictionary = b.get("stats", {})
			var stat_parts: Array = []
			for stat_key in b_stats.keys():
				stat_parts.append("%+d %s" % [int(b_stats[stat_key]), stat_key.to_upper().substr(0, 3)])
			var detail: String = ", ".join(stat_parts)
			var dur_text: String = "%d turns" % b_dur
			if detail != "":
				dur_text = "%s | %s" % [detail, dur_text]
			_add_inspect_status_line(vbox, b_name, dur_text, Color(0.5, 0.8, 0.5))

	# --- Close hint ---
	_add_inspect_separator(vbox)
	var hint = Label.new()
	hint.text = "Click outside or press Escape to close"
	hint.add_theme_font_size_override("font_size", GameContext.fs(12))
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


## Stat inspection: add header label.
func _add_inspect_header(vbox: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", GameContext.fs(18))
	lbl.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)


## Stat inspection: add separator line.
func _add_inspect_separator(vbox: VBoxContainer) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)


## Stat inspection: add stat row with tooltip.
func _add_inspect_stat(vbox: VBoxContainer, stat_name: String, value_text: String, color: Color, tooltip: String) -> void:
	var hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
	name_lbl.add_theme_color_override("font_color", color)
	name_lbl.custom_minimum_size.x = 50
	name_lbl.tooltip_text = tooltip
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	val_lbl.tooltip_text = tooltip
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(val_lbl)
	vbox.add_child(hbox)


## Stat inspection: add section label (Abilities, Passives, etc.).
func _add_inspect_section_label(vbox: VBoxContainer, text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(lbl)


## Stat inspection: add ability entry.
func _add_inspect_ability(vbox: VBoxContainer, ability_name: String, cd_text: String, description: String) -> void:
	var hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = ability_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	hbox.add_child(name_lbl)

	var cd_lbl = Label.new()
	cd_lbl.text = "  [%s]" % cd_text
	cd_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
	cd_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	hbox.add_child(cd_lbl)
	vbox.add_child(hbox)

	if description != "":
		var desc_lbl = Label.new()
		desc_lbl.text = "  %s" % description
		desc_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_lbl)


## Stat inspection: add passive entry.
func _add_inspect_passive(vbox: VBoxContainer, passive_name: String, description: String) -> void:
	var name_lbl = Label.new()
	name_lbl.text = passive_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(name_lbl)

	if description != "":
		var desc_lbl = Label.new()
		desc_lbl.text = "  %s" % description
		desc_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(desc_lbl)


## Stat inspection: add status/buff line.
func _add_inspect_status_line(vbox: VBoxContainer, status_name: String, duration_text: String, color: Color) -> void:
	var hbox = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = status_name
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.add_theme_color_override("font_color", color)
	hbox.add_child(name_lbl)

	var dur_lbl = Label.new()
	dur_lbl.text = "  (%s)" % duration_text
	dur_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
	dur_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	hbox.add_child(dur_lbl)
	vbox.add_child(hbox)


## Stat inspection: add a smaller detail/description line.
func _add_inspect_detail_line(vbox: VBoxContainer, text: String, color: Color) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)


## Close the stat inspection overlay.
func _close_stat_inspection() -> void:
	if _inspect_overlay != null and is_instance_valid(_inspect_overlay):
		UIAudio.unregister_closeable(_inspect_overlay)
		_inspect_overlay.queue_free()
		_inspect_overlay = null
		_inspect_unit_id = ""
	_ensure_action_panel_visible()


## Handle click on backdrop to close inspection.
func _on_inspect_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_stat_inspection()


# ============================================================================
# PLAYER ACTIONS v1.5: Use Item Button (Free Action)
# ============================================================================

## Handle "Use Item" button press — show consumable selection overlay.
func _on_use_item_pressed() -> void:
	if _current_input_unit == null:
		return
	var hero_id: String = _current_input_unit.source_id
	var bag: Array = GameContext.get_hero_bag(hero_id)
	if bag.is_empty():
		return

	# Gather consumables
	var consumables: Array = []
	for i in range(bag.size()):
		var entry = bag[i]
		var item_id: String = entry.get("item_id", "")
		var tmpl = DataRegistry.get_item_template(item_id)
		if tmpl != null and tmpl.item_type == "consumable":
			consumables.append({"index": i, "item_id": item_id, "template": tmpl})

	if consumables.is_empty():
		_log("[color=gray]No consumables in bag[/color]")
		return

	_show_item_select_overlay(hero_id, consumables)


## Show item selection overlay as CanvasLayer popup.
func _show_item_select_overlay(hero_id: String, consumables: Array) -> void:
	# Clean up existing
	if _item_select_overlay != null and is_instance_valid(_item_select_overlay):
		_item_select_overlay.queue_free()
		_item_select_overlay = null

	_item_select_overlay = CanvasLayer.new()
	_item_select_overlay.layer = 11
	add_child(_item_select_overlay)

	# Backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.4)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.set_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_item_select_backdrop_input)
	_item_select_overlay.add_child(backdrop)

	# Center
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	_item_select_overlay.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(_region_palette.get("ui_tint", Color.WHITE)))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "Use Item (Free Action)"
	header.add_theme_font_size_override("font_size", GameContext.fs(18))
	header.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Item buttons with effect descriptions
	for entry in consumables:
		var item_btn = Button.new()
		var btn_name: String = entry.template.display_name if entry.template else entry.item_id
		var effect_text: String = ""
		if entry.template and entry.template.use_effect != "":
			effect_text = entry.template.get_effect_label()
		if effect_text != "":
			item_btn.text = "%s — %s" % [btn_name, effect_text]
			item_btn.tooltip_text = effect_text
		else:
			item_btn.text = btn_name
		item_btn.custom_minimum_size = Vector2(0, 32)
		item_btn.pressed.connect(_on_item_select_chosen.bind(entry.item_id, hero_id))
		vbox.add_child(item_btn)

	# Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 28)
	cancel_btn.flat = true
	cancel_btn.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	cancel_btn.pressed.connect(_close_item_select_overlay)
	vbox.add_child(cancel_btn)


## Handle selecting a consumable from the Use Item overlay.
## Instead of immediately submitting, show a hero picker to choose the target.
func _on_item_select_chosen(item_id: String, hero_id: String) -> void:
	_close_item_select_overlay()
	_pending_combat_consumable_id = item_id
	_pending_combat_consumable_hero_id = hero_id
	_show_combat_consumable_hero_picker(item_id, hero_id)


## Close the item selection overlay.
func _close_item_select_overlay() -> void:
	if _item_select_overlay != null and is_instance_valid(_item_select_overlay):
		_item_select_overlay.queue_free()
		_item_select_overlay = null


## Handle click on backdrop to close item selection.
func _on_item_select_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_item_select_overlay()
		_ensure_action_panel_visible()


# ============================================================================
# COMBAT CONSUMABLE HERO PICKER
# ============================================================================

## Show hero picker overlay for choosing which hero receives the consumable effect.
func _show_combat_consumable_hero_picker(item_id: String, source_hero_id: String) -> void:
	_close_combat_consumable_picker()

	var template = DataRegistry.get_item_template(item_id)
	var item_name: String = template.display_name if template else item_id

	_combat_consumable_picker = CanvasLayer.new()
	_combat_consumable_picker.layer = 11
	add_child(_combat_consumable_picker)

	# Root control for input blocking
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_consumable_picker.add_child(root)

	# Dark backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.set_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_combat_consumable_picker_backdrop)
	root.add_child(backdrop)

	# Centered panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_modal(_region_palette.get("ui_tint", Color.WHITE)))
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Use %s on:" % item_name
	title.add_theme_font_size_override("font_size", GameContext.fs(17))
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Show effect description below title
	if template != null and template.use_effect != "":
		var effect_lbl = Label.new()
		effect_lbl.text = template.get_effect_label()
		effect_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		effect_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(effect_lbl)

	vbox.add_child(HSeparator.new())

	# Hero buttons - show all alive party heroes with HP (read from live CombatUnit)
	var party: Array = GameContext.get_selected_party()
	for pid in party:
		var hero: Dictionary = GameContext.get_hero(pid)
		if hero.is_empty():
			continue
		var current_hp: int = 0
		var max_hp: int = 0
		var unit: CombatUnit = _combat_controller.get_unit_by_source_id(pid)
		if unit != null:
			current_hp = unit.current_health
			max_hp = unit.max_health
		else:
			var hp_data: Dictionary = GameContext.get_hero_hp(pid)
			current_hp = int(hp_data.get("current", 1))
			max_hp = int(hp_data.get("max", 1))
		if current_hp <= 0:
			continue  # Skip dead heroes

		var hero_name: String = hero.get("name", pid)
		var btn = Button.new()
		btn.text = "%s  (%d/%d HP)" % [hero_name, current_hp, max_hp]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.pressed.connect(_on_combat_consumable_hero_chosen.bind(item_id, pid, source_hero_id))
		vbox.add_child(btn)

	# Cancel button
	vbox.add_child(HSeparator.new())
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 28)
	cancel_btn.flat = true
	cancel_btn.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	cancel_btn.pressed.connect(_on_combat_consumable_picker_cancel)
	vbox.add_child(cancel_btn)


## Handle hero selection from the combat consumable picker.
func _on_combat_consumable_hero_chosen(item_id: String, target_hero_id: String, source_hero_id: String) -> void:
	_close_combat_consumable_picker()
	_combat_controller.submit_consumable_use(item_id, target_hero_id, true, source_hero_id)  # true = free action
	# Refresh hero bag display since item was consumed
	_refresh_hero_bag_display(source_hero_id)
	_ensure_action_panel_visible()


## Cancel the combat consumable hero picker and re-show the action panel.
func _on_combat_consumable_picker_cancel() -> void:
	_close_combat_consumable_picker()
	_ensure_action_panel_visible()


## Close the combat consumable hero picker overlay.
func _close_combat_consumable_picker() -> void:
	if _combat_consumable_picker != null and is_instance_valid(_combat_consumable_picker):
		_combat_consumable_picker.queue_free()
		_combat_consumable_picker = null


## Handle backdrop click to dismiss the combat consumable hero picker.
func _on_combat_consumable_picker_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_combat_consumable_picker_cancel()


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

	_ensure_action_panel_visible()


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
	# Pause combat while flee dialog is shown
	if _flee_dialog != null:
		print("[UI] Skipping - flee dialog open")
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
	scroll.follow_focus = true
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
	name_label.add_theme_font_size_override("font_size", GameContext.fs(18))
	name_label.add_theme_color_override("font_color", Color.CYAN)
	vbox.add_child(name_label)

	# === LEVEL AND XP ===
	var hero_level = hero_data.get("level", 1) if not hero_data.is_empty() else 1
	var hero_xp = hero_data.get("xp", 0) if not hero_data.is_empty() else 0
	var xp_for_next = GameContext.get_xp_for_level(hero_level + 1) if GameContext.has_method("get_xp_for_level") else 100
	var level_label = Label.new()
	level_label.text = "Level %d  |  XP: %d / %d" % [hero_level, hero_xp, xp_for_next]
	level_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	level_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(level_label)

	vbox.add_child(HSeparator.new())

	# === COMBAT STATS (effective) ===
	var stats_title = Label.new()
	stats_title.text = "Combat Stats (Effective)"
	stats_title.add_theme_font_size_override("font_size", GameContext.fs(16))
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

	var equip_sep = HSeparator.new()
	equip_sep.add_theme_constant_override("separation", 4)
	vbox.add_child(equip_sep)

	# === EQUIPMENT ===
	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", GameContext.fs(16))
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
		var bonus_sep = HSeparator.new()
		bonus_sep.add_theme_constant_override("separation", 4)
		vbox.add_child(bonus_sep)
		var bonus_title = Label.new()
		bonus_title.text = "Gear Bonuses"
		bonus_title.add_theme_font_size_override("font_size", GameContext.fs(16))
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

	var ability_sep = HSeparator.new()
	ability_sep.add_theme_constant_override("separation", 4)
	vbox.add_child(ability_sep)

	# === ABILITIES ===
	var ability_title = Label.new()
	ability_title.text = "Abilities"
	ability_title.add_theme_font_size_override("font_size", GameContext.fs(16))
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
		if GameContext.is_ability_slot_unlocked("ability_a", hero_level):
			var a_cd = "CD: %d" % (ability_a.cooldown if ability_a else 0)
			_add_ability_line(vbox, "[A] %s" % a_name, a_desc, a_cd)
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_a", 5)
			_add_ability_line(vbox, "[A] %s (Lv %d)" % [a_name, req_lv], a_desc, "Locked")
		has_abilities = true

	if ability_b_id != "":
		var ability_b = DataRegistry.get_ability(ability_b_id) if DataRegistry.has_method("get_ability") else null
		var b_name = ability_b.display_name if ability_b else ability_b_id
		var b_desc = ability_b.description if ability_b else ""
		if GameContext.is_ability_slot_unlocked("ability_b", hero_level):
			var b_cd = "CD: %d" % (ability_b.cooldown if ability_b else 0)
			_add_ability_line(vbox, "[B] %s" % b_name, b_desc, b_cd)
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("ability_b", 25)
			_add_ability_line(vbox, "[B] %s (Lv %d)" % [b_name, req_lv], b_desc, "Locked")
		has_abilities = true

	if not has_abilities:
		var none_lbl = Label.new()
		none_lbl.text = "(none)"
		none_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		vbox.add_child(none_lbl)

	var passive_sep = HSeparator.new()
	passive_sep.add_theme_constant_override("separation", 4)
	vbox.add_child(passive_sep)

	# === PASSIVES (Class + Race) ===
	var passive_title = Label.new()
	passive_title.text = "Passives"
	passive_title.add_theme_font_size_override("font_size", GameContext.fs(16))
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
		if GameContext.is_ability_slot_unlocked("passive_a", hero_level):
			_add_ability_line(vbox, "[Class] %s" % p_name, p_desc, "")
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_a", 15)
			_add_ability_line(vbox, "[Class] %s (Lv %d)" % [p_name, req_lv], p_desc, "Locked")
		has_passives = true

	if passive_b_id != "":
		var p_data = DataRegistry.get_passive(passive_b_id) if DataRegistry.has_method("get_passive") else null
		var p_name = p_data.display_name if p_data else passive_b_id
		var p_desc = p_data.description if p_data else ""
		if GameContext.is_ability_slot_unlocked("passive_b", hero_level):
			_add_ability_line(vbox, "[Class] %s" % p_name, p_desc, "")
		else:
			var req_lv: int = GameContext.ABILITY_UNLOCK_LEVELS.get("passive_b", 40)
			_add_ability_line(vbox, "[Class] %s (Lv %d)" % [p_name, req_lv], p_desc, "Locked")
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
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
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
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	hbox.add_child(name_lbl)

	var val_lbl = Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
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
	name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_hbox.add_child(name_lbl)

	if cd != "":
		var cd_lbl = Label.new()
		cd_lbl.text = "  [%s]" % cd
		cd_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		cd_lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		name_hbox.add_child(cd_lbl)

	ability_vbox.add_child(name_hbox)

	if desc != "":
		var desc_lbl = Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
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


# ============================================================================
# FEATURE J: SHOPKEEPER BAG DISPLAY IN COMBAT
# ============================================================================

## Create the shopkeeper bag display panel and insert it above the action panel
## in the BottomPanel.
func _create_shopkeeper_bag_display() -> void:
	if _shopkeeper_bag_panel != null:
		_shopkeeper_bag_panel.queue_free()

	_shopkeeper_bag_panel = PanelContainer.new()
	_shopkeeper_bag_panel.name = "ShopkeeperBagPanel"

	# Warm brown styling
	_shopkeeper_bag_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(Color(0.8, 0.65, 0.45, 1)))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_shopkeeper_bag_panel.add_child(vbox)

	# Header label
	_shopkeeper_bag_label = Label.new()
	_shopkeeper_bag_label.text = "Shopkeeper Bag (0/6)"
	_shopkeeper_bag_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	_shopkeeper_bag_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.55, 0.9))
	vbox.add_child(_shopkeeper_bag_label)

	# Slot row
	_shopkeeper_bag_row = HBoxContainer.new()
	_shopkeeper_bag_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_shopkeeper_bag_row)

	# Create bags wrapper HBoxContainer to hold shopkeeper + hero bags side-by-side
	_bags_hbox = HBoxContainer.new()
	_bags_hbox.name = "BagsRow"
	_bags_hbox.add_theme_constant_override("separation", 8)
	_bags_hbox.add_child(_shopkeeper_bag_panel)

	# Insert wrapper into BottomPanel above action panel
	if _action_panel != null:
		var parent_node = _action_panel.get_parent()
		if parent_node != null:
			parent_node.add_child(_bags_hbox)
			parent_node.move_child(_bags_hbox, _action_panel.get_index())
	else:
		$BottomPanel.add_child(_bags_hbox)
		var button_row = $BottomPanel/ButtonRow
		$BottomPanel.move_child(_bags_hbox, button_row.get_index())

	# Initial population
	_refresh_shopkeeper_bag_display()
	print("[UI] Shopkeeper bag display created")


## Refresh the shopkeeper bag slot buttons to reflect current state.
func _refresh_shopkeeper_bag_display() -> void:
	if _shopkeeper_bag_row == null:
		return
	for child in _shopkeeper_bag_row.get_children():
		child.queue_free()

	var bag: Array = GameContext.get_shopkeeper_bag()
	var cap: int = GameContext.SHOPKEEPER_BAG_CAPACITY_DEFAULT
	var safe: int = GameContext.SHOPKEEPER_SAFE_SLOTS
	_shopkeeper_bag_label.text = "Shopkeeper Bag (%d/%d)" % [bag.size(), cap]

	for i in range(cap):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		var is_safe: bool = i < safe

		if i < bag.size():
			var entry: Dictionary = bag[i]
			var item_id: String = entry.get("item_id", "")
			var qty: int = int(entry.get("qty", 1))
			var template = DataRegistry.get_item_template(item_id)
			if template:
				var icon_tex = template.get_icon_texture()
				if icon_tex != null:
					btn.icon = icon_tex
					btn.expand_icon = true
				else:
					btn.text = item_id.substr(0, 3)
				var safe_label: String = "[SAFE] " if is_safe else ""
				btn.tooltip_text = "%s%s" % [safe_label, template.display_name]
				if qty > 1:
					btn.tooltip_text += " x%d" % qty
			else:
				btn.text = "?"

			# Connect swap click for filled slots only
			btn.pressed.connect(_on_shopkeeper_bag_swap_click.bind(i, btn))
			# Enable drag-and-drop reordering
			btn.set_drag_forwarding(
				_bag_slot_get_drag.bind(i, btn),
				_bag_slot_can_drop,
				_bag_slot_drop.bind(i)
			)
		else:
			btn.text = ""
			if is_safe:
				btn.tooltip_text = "Safe Slot (empty)"
			else:
				btn.tooltip_text = "Unsafe Slot (empty)"
			# Empty slots can accept drops but not initiate drags
			btn.set_drag_forwarding(
				_bag_slot_get_drag_empty,
				_bag_slot_can_drop,
				_bag_slot_drop.bind(i)
			)

		# Apply safe/unsafe styling
		if is_safe:
			var safe_style = StyleBoxFlat.new()
			safe_style.bg_color = Color(0.1, 0.25, 0.1, 0.9)
			safe_style.border_color = Color(0.3, 0.7, 0.3, 0.6)
			safe_style.set_border_width_all(1)
			safe_style.set_corner_radius_all(2)
			btn.add_theme_stylebox_override("normal", safe_style)
			# Also style disabled state for empty safe slots
			var safe_disabled = safe_style.duplicate()
			safe_disabled.bg_color = Color(0.08, 0.15, 0.08, 0.5)
			safe_disabled.border_color = Color(0.2, 0.5, 0.2, 0.3)
			btn.add_theme_stylebox_override("disabled", safe_disabled)

		_shopkeeper_bag_row.add_child(btn)


# ============================================================================
# FEATURE K: SWAP SYSTEM (Combat — Shopkeeper Bag Internal Swaps)
# ============================================================================

## Handle click on a shopkeeper bag slot for swap.
func _on_shopkeeper_bag_swap_click(index: int, btn: Button) -> void:
	if _swap_source.is_empty():
		# Start swap
		_swap_source = {"type": "shopkeeper", "index": index}
		_highlight_swap_slot(btn)
	elif _swap_source.get("type") == "shopkeeper" and _swap_source.get("index") == index:
		# Cancel: clicked same slot
		_clear_swap_highlight()
	else:
		# Perform swap
		var src = _swap_source
		_clear_swap_highlight()
		if src.get("type") == "shopkeeper":
			GameContext.swap_shopkeeper_bag_items(src.index, index)
			_refresh_shopkeeper_bag_display()
			print("[UI] Swapped shopkeeper bag slots %d <-> %d" % [src.index, index])


## Highlight a slot button as selected for swap.
func _highlight_swap_slot(btn: Button) -> void:
	if _swap_highlight_btn != null and is_instance_valid(_swap_highlight_btn):
		_clear_swap_highlight()
	_swap_highlight_btn = btn
	var highlight_style = StyleBoxFlat.new()
	highlight_style.bg_color = Color(0.3, 0.3, 0.1, 0.8)
	highlight_style.border_color = Color(1.0, 0.85, 0.0, 0.9)
	highlight_style.set_border_width_all(2)
	highlight_style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", highlight_style)


## Clear swap selection and remove highlight.
func _clear_swap_highlight() -> void:
	_swap_source = {}
	if _swap_highlight_btn != null and is_instance_valid(_swap_highlight_btn):
		_swap_highlight_btn.remove_theme_stylebox_override("normal")
	_swap_highlight_btn = null


# --- Drag-and-drop handlers for shopkeeper bag reordering ---

## Creates drag data + preview for a filled bag slot.
func _bag_slot_get_drag(at_pos: Vector2, index: int, origin_btn: Button) -> Variant:
	var bag: Array = GameContext.get_shopkeeper_bag()
	if index >= bag.size():
		return null
	var entry: Dictionary = bag[index]
	var item_id: String = entry.get("item_id", "")
	var template = DataRegistry.get_item_template(item_id)
	# Build a small drag preview icon
	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if template:
		var tex = template.get_icon_texture()
		if tex:
			preview.texture = tex
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return {"type": "shopkeeper_bag", "index": index}


## Empty slots return null — they cannot initiate a drag.
func _bag_slot_get_drag_empty(at_pos: Vector2) -> Variant:
	return null


## Accept drops only from other shopkeeper bag slots.
func _bag_slot_can_drop(at_pos: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") == "shopkeeper_bag":
		return true
	return false


## Perform the swap when an item is dropped onto this slot.
func _bag_slot_drop(at_pos: Vector2, data, target_index: int) -> void:
	if not (data is Dictionary and data.get("type") == "shopkeeper_bag"):
		return
	var src_index: int = int(data.get("index", -1))
	if src_index < 0 or src_index == target_index:
		return
	GameContext.swap_shopkeeper_bag_items(src_index, target_index)
	_refresh_shopkeeper_bag_display()
	print("[UI] Drag-swapped shopkeeper bag slots %d <-> %d" % [src_index, target_index])


# ============================================================================
# HERO BAG DISPLAY IN COMBAT
# ============================================================================

## Create the hero bag display panel and insert it above the shopkeeper bag.
func _create_hero_bag_display() -> void:
	if _hero_bag_panel != null:
		_hero_bag_panel.queue_free()

	_hero_bag_panel = PanelContainer.new()
	_hero_bag_panel.name = "HeroBagPanel"

	_hero_bag_panel.add_theme_stylebox_override("panel", RPGPackStyles.panel_main(Color(0.5, 0.65, 0.8, 1)))

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_hero_bag_panel.add_child(vbox)

	_hero_bag_label = Label.new()
	_hero_bag_label.text = "Hero Bag"
	_hero_bag_label.add_theme_font_size_override("font_size", GameContext.fs(13))
	_hero_bag_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9, 0.9))
	vbox.add_child(_hero_bag_label)

	_hero_bag_row = HBoxContainer.new()
	_hero_bag_row.add_theme_constant_override("separation", 4)
	vbox.add_child(_hero_bag_row)

	# Add to bags wrapper (right of shopkeeper bag)
	if _bags_hbox != null:
		_bags_hbox.add_child(_hero_bag_panel)

	_hero_bag_panel.visible = false  # Hidden until a hero's turn starts


## Refresh the hero bag display for the given hero.
func _refresh_hero_bag_display(hero_id: String) -> void:
	if _hero_bag_row == null:
		return
	for child in _hero_bag_row.get_children():
		child.queue_free()

	if hero_id.is_empty():
		_hero_bag_panel.visible = false
		return

	var bag: Array = GameContext.get_hero_bag(hero_id)
	var cap: int = GameContext.get_hero_bag_capacity(hero_id)
	var hero: Dictionary = GameContext.get_hero(hero_id)
	var hero_name: String = hero.get("name", hero_id)

	_hero_bag_label.text = "%s's Bag (%d/%d)" % [hero_name, bag.size(), cap]

	if bag.is_empty():
		_hero_bag_panel.visible = false
		return

	_hero_bag_panel.visible = true

	for i in range(bag.size()):
		var entry: Dictionary = bag[i]
		var item_id: String = entry.get("item_id", "")
		var qty: int = int(entry.get("qty", 1))
		var tmpl = DataRegistry.get_item_template(item_id)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.focus_mode = Control.FOCUS_ALL
		btn.set_meta("bag_item_id", item_id)
		btn.set_meta("bag_hero_id", hero_id)

		if tmpl != null:
			var icon_path: String = tmpl.icon_path
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var tex = load(icon_path)
				if tex != null:
					btn.icon = tex
					btn.expand_icon = true
			btn.tooltip_text = "%s%s" % [tmpl.display_name, (" x%d" % qty if qty > 1 else "")]
			if tmpl.item_type == "consumable":
				btn.tooltip_text += "\nRight-click / %s to use" % InputManager.get_glyph("use_item")
		else:
			btn.text = item_id.left(3)
			btn.tooltip_text = item_id

		# Right-click handler for consumables
		btn.gui_input.connect(_on_hero_bag_slot_input.bind(hero_id, item_id, i))
		_hero_bag_row.add_child(btn)


## Handle right-click on a hero bag slot in combat — use consumable via hero picker.
func _on_hero_bag_slot_input(event: InputEvent, hero_id: String, item_id: String, slot_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var tmpl = DataRegistry.get_item_template(item_id)
	if tmpl == null or tmpl.item_type != "consumable":
		return
	if not GameContext.can_hero_use_consumable(hero_id):
		_log("[color=gray]%s already used an item this combat[/color]" % GameContext.get_hero(hero_id).get("name", hero_id))
		return
	_show_combat_consumable_hero_picker(item_id, hero_id)


# ============================================================================
# FOCUS ZONES (Controller support)
# ============================================================================

func _register_action_zones() -> void:
	InputManager.clear_zones()
	if _action_panel == null:
		return
	var action_controls: Array = InputManager.collect_focusable(_action_panel)
	var bag_controls: Array = InputManager.collect_focusable(_hero_bag_panel) if _hero_bag_panel != null else []
	InputManager.register_zone("action_buttons", _action_panel, action_controls, {
		"down": "hero_bag"
	})
	if _hero_bag_panel != null and bag_controls.size() > 0:
		InputManager.register_zone("hero_bag", _hero_bag_panel, bag_controls, {
			"up": "action_buttons"
		})
	InputManager.set_active_zone("action_buttons")


func _register_target_zones() -> void:
	InputManager.clear_zones()
	var target_controls: Array = []
	for unit_id in _valid_target_ids:
		var display: Control = _unit_displays.get(unit_id)
		if display and is_instance_valid(display):
			display.focus_mode = Control.FOCUS_ALL
			target_controls.append(display)
	if target_controls.size() > 0:
		InputManager.register_zone("targets", battlefield, target_controls, {})
		InputManager.set_active_zone("targets")
		target_controls[0].call_deferred("grab_focus")


func _clear_target_focus() -> void:
	for unit_id in _unit_displays.keys():
		var display: Control = _unit_displays[unit_id]
		if display and is_instance_valid(display):
			display.focus_mode = Control.FOCUS_NONE
	InputManager.clear_zones()


## Collect all loot panel focusable buttons into a virtual grid and wire focus neighbors
## so D-pad flows seamlessly across drops, bag slots, and bottom buttons.
func _wire_loot_focus_grid() -> void:
	var grid: Array = []  # Array of rows, each row is Array of Controls

	# Drops grid rows
	if _loot_drops_grid and is_instance_valid(_loot_drops_grid):
		var drop_btns: Array = InputManager.collect_focusable(_loot_drops_grid)
		var cols: int = _loot_drops_grid.columns
		var row: Array = []
		for btn in drop_btns:
			row.append(btn)
			if row.size() >= cols:
				grid.append(row)
				row = []
		if not row.is_empty():
			grid.append(row)

	# Shop bag grid rows
	if _loot_shop_grid and is_instance_valid(_loot_shop_grid):
		var shop_btns: Array = InputManager.collect_focusable(_loot_shop_grid)
		var cols: int = _loot_shop_grid.columns
		var row: Array = []
		for btn in shop_btns:
			row.append(btn)
			if row.size() >= cols:
				grid.append(row)
				row = []
		if not row.is_empty():
			grid.append(row)

	# Hero bag grid rows — each hero's grid is one row
	for hero_grid in _loot_hero_grids:
		if hero_grid == null or not is_instance_valid(hero_grid):
			continue
		var hero_btns: Array = InputManager.collect_focusable(hero_grid)
		if not hero_btns.is_empty():
			grid.append(hero_btns)

	# Bottom button row
	if _loot_btn_row and is_instance_valid(_loot_btn_row):
		var btn_ctrls: Array = InputManager.collect_focusable(_loot_btn_row)
		if not btn_ctrls.is_empty():
			grid.append(btn_ctrls)

	if grid.size() > 0:
		InputManager.wire_focus_grid(grid)


func _register_loot_zones() -> void:
	InputManager.clear_zones()
	if _loot_panel == null:
		return

	var has_drops: bool = _loot_drops_grid != null and is_instance_valid(_loot_drops_grid)
	var has_shop: bool = _loot_shop_grid != null and is_instance_valid(_loot_shop_grid)
	var has_heroes: bool = not _loot_hero_grids.is_empty()
	var has_buttons: bool = _loot_btn_row != null and is_instance_valid(_loot_btn_row)

	# Register drop items zone
	if has_drops:
		var drop_controls: Array = InputManager.collect_focusable(_loot_drops_grid)
		if drop_controls.size() > 0:
			var down_zone: String = "loot_shop_bag" if has_shop else ("loot_hero_bags" if has_heroes else "loot_buttons")
			InputManager.register_zone("loot_drops", _loot_drops_grid, drop_controls, {"down": down_zone})

	# Register shop bag zone
	if has_shop:
		var shop_controls: Array = InputManager.collect_focusable(_loot_shop_grid)
		if shop_controls.size() > 0:
			var up_zone: String = "loot_drops" if has_drops else ""
			var down_zone: String = "loot_hero_bags" if has_heroes else ("loot_buttons" if has_buttons else "")
			InputManager.register_zone("loot_shop_bag", _loot_shop_grid, shop_controls, {"up": up_zone, "down": down_zone})

	# Register hero bag zones (all combined into one zone)
	if has_heroes:
		var all_hero_controls: Array = []
		for hero_grid in _loot_hero_grids:
			if hero_grid != null and is_instance_valid(hero_grid):
				all_hero_controls.append_array(InputManager.collect_focusable(hero_grid))
		if all_hero_controls.size() > 0:
			var hero_container: Control = _loot_hero_grids[0].get_parent() if _loot_hero_grids.size() > 0 else _loot_panel
			var up_zone: String = "loot_shop_bag" if has_shop else ("loot_drops" if has_drops else "")
			var down_zone: String = "loot_buttons" if has_buttons else ""
			InputManager.register_zone("loot_hero_bags", hero_container, all_hero_controls, {"up": up_zone, "down": down_zone})

	# Register bottom buttons zone
	if has_buttons:
		var btn_controls: Array = InputManager.collect_focusable(_loot_btn_row)
		if btn_controls.size() > 0:
			var up_zone: String = "loot_hero_bags" if has_heroes else ("loot_shop_bag" if has_shop else ("loot_drops" if has_drops else ""))
			InputManager.register_zone("loot_buttons", _loot_btn_row, btn_controls, {"up": up_zone})

	# Wire cross-zone D-pad focus so D-pad flows through all slots seamlessly
	_wire_loot_focus_grid()

	# Set initial focus zone
	if _loot_selected_index >= 0:
		# Item selected — focus on first bag slot for placement
		if InputManager._zones.has("loot_shop_bag"):
			InputManager.set_active_zone("loot_shop_bag")
		elif InputManager._zones.has("loot_hero_bags"):
			InputManager.set_active_zone("loot_hero_bags")
		elif InputManager._zones.has("loot_buttons"):
			InputManager.set_active_zone("loot_buttons")
	elif InputManager._zones.has("loot_drops"):
		InputManager.set_active_zone("loot_drops")
	elif InputManager._zones.has("loot_buttons"):
		InputManager.set_active_zone("loot_buttons")

	var palette: Dictionary = _region_palette
	InputManager.set_zone_border_color(palette.get("border", Color(0.55, 0.4, 0.25, 0.8)))


func _exit_tree() -> void:
	InputManager.clear_zones()
