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

# ============================================================================
# STATE
# ============================================================================

var _combat_controller: Node = null
var _is_auto_running: bool = false
var _auto_timer: float = 0.0
var _auto_delay: float = 0.5  # Seconds between auto steps

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

	# Create combat controller
	_combat_controller = CombatControllerScript.new()
	add_child(_combat_controller)

	# Connect signals
	_combat_controller.combat_ended.connect(_on_combat_ended)

	# Get RNG from context
	var run_seed = GameContext.get_run_seed() if GameContext.is_run_active() else 12345
	var rng = SeededRNG.create_rng(run_seed)

	# Initialize combat using clean API
	var hero_ids = ["hero_1", "hero_2"]
	var enemy_ids = ["goblin", "goblin"]
	_combat_controller.initialize_combat(hero_ids, enemy_ids, rng)

	var snapshot = _combat_controller.get_units_snapshot()
	_log("Party: %d heroes vs %d enemies" % [
		snapshot["player"].size(),
		snapshot["enemy"].size()
	])
	_log("Turn order established (Round 1)")

	# Refresh UI
	_refresh_all_panels()
	_update_top_bar()


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


func _refresh_enemy_panel(units: Array) -> void:
	# Clear existing
	for child in enemy_panel.get_children():
		child.queue_free()

	# Add unit displays
	for unit_data in units:
		var display = _create_unit_display(unit_data)
		enemy_panel.add_child(display)


func _create_unit_display(unit_data: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	# Name + HP line
	var name_label = Label.new()
	var alive_color = "white" if unit_data["is_alive"] else "gray"
	var dead_text = " [DEAD]" if not unit_data["is_alive"] else ""
	name_label.text = "%s%s" % [unit_data["name"], dead_text]
	name_label.add_theme_color_override("font_color", Color.html(alive_color))
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

	# Status line
	var status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	var status_parts = []

	for status in unit_data["statuses"]:
		if status["id"] == "stun":
			status_parts.append("[STUN:%d]" % status["duration"])
		elif status["id"] == "doom":
			status_parts.append("[DOOM:%d|t=%d]" % [status["stacks"], status["countdown"]])

	if status_parts.size() > 0:
		status_label.text = " ".join(status_parts)
		status_label.add_theme_color_override("font_color", Color.MAGENTA)
	else:
		status_label.text = ""

	container.add_child(status_label)

	# Separator
	var sep = HSeparator.new()
	container.add_child(sep)

	return container


func _update_top_bar() -> void:
	if _combat_controller.is_combat_over():
		top_bar.text = "Combat Ended"
		return

	var turn_info = _combat_controller.get_turn_info()
	var unit_name = turn_info["current_actor_name"] if turn_info["current_actor_name"] != "" else "---"

	top_bar.text = "Round %d | Current Turn: %s" % [turn_info["round"], unit_name]


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
