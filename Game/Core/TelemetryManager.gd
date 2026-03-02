## TelemetryManager.gd
## Local-only playtest telemetry. Logs gameplay events to JSON files in user://telemetry/.
## All data stays on the player's machine. Requires opt-in consent via GameContext.telemetry_consent.
extends Node

const TELEMETRY_VERSION := "1.0"
const GAME_VERSION := "v0.3"
const TELEMETRY_DIR := "user://telemetry"

# Session state
var _session_id: String = ""
var _session_start_time: float = 0.0
var _events: Array = []
var _combat_start_ms: int = 0
var _flushed: bool = false
var _max_floor_reached: int = 0


func _ready() -> void:
	_session_start_time = Time.get_unix_time_from_system()
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	_session_id = "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

	# Connect to GameContext signals
	GameContext.run_started.connect(_on_run_started)
	GameContext.run_ended.connect(_on_run_ended)
	GameContext.phase_changed.connect(_on_phase_changed)

	_log_event({
		"type": "session_start",
		"slot": GameContext.current_save_slot,
		"ng_cycle": GameContext.ng_plus_cycle,
	})
	print("[TelemetryManager] Session %s started (consent=%s)" % [_session_id, str(GameContext.telemetry_consent)])


func _exit_tree() -> void:
	var duration: float = Time.get_unix_time_from_system() - _session_start_time
	_log_event({
		"type": "session_end",
		"duration_seconds": int(duration),
	})
	_flush()


# ============================================================================
# PUBLIC API
# ============================================================================

## Called by CombatScene after signal wiring to hook combat telemetry.
func hook_combat(controller: Node) -> void:
	if not GameContext.telemetry_consent:
		return
	_combat_start_ms = Time.get_ticks_msec()
	if controller.has_signal("combat_ended"):
		controller.combat_ended.connect(_on_combat_ended, CONNECT_ONE_SHOT)


## Log a facility upgrade event. Called from GameContext.upgrade_facility().
func log_facility_upgrade(facility_id: String, new_tier: int) -> void:
	_log_event({
		"type": "facility_upgrade",
		"facility_id": facility_id,
		"new_tier": new_tier,
		"region": GameContext.get_current_region_id(),
	})


## Log a hero recruitment event. Called from GameContext.recruit_hero().
func log_hero_recruited(class_id: String, race_id: String, level: int) -> void:
	_log_event({
		"type": "hero_recruited",
		"hero_class": class_id,
		"hero_race": race_id,
		"hero_level": level,
		"region": GameContext.get_current_region_id(),
	})


## Log a hero level-up event. Called from GameContext.grant_hero_xp().
func log_hero_levelup(class_id: String, race_id: String, new_level: int) -> void:
	_log_event({
		"type": "hero_levelup",
		"hero_class": class_id,
		"hero_race": race_id,
		"new_level": new_level,
		"region": GameContext.get_current_region_id(),
	})


## Log an event encounter. Called from RoomEventScene after outcome resolved.
func log_event_encounter(event_id: String, choice_index: int, outcome_index: int) -> void:
	_log_event({
		"type": "event_encounter",
		"event_id": event_id,
		"choice_index": choice_index,
		"outcome_index": outcome_index,
		"region": GameContext.get_current_region_id(),
		"floor": GameContext.get_current_floor(),
	})


# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_run_started(run_id: String, _run_seed: int) -> void:
	_max_floor_reached = 0

	# Gather party class info
	var party_classes: Array = []
	for hero_id in GameContext.selected_party:
		var hero: Dictionary = GameContext.get_hero(hero_id)
		if hero.size() > 0:
			party_classes.append(hero.get("class_id", "unknown"))

	_log_event({
		"type": "run_start",
		"run_id": run_id,
		"region": GameContext.get_current_region_id(),
		"party_size": GameContext.selected_party.size(),
		"party": party_classes,
	})


func _on_run_ended(run_id: String) -> void:
	_log_event({
		"type": "run_end",
		"run_id": run_id,
		"region": GameContext.get_current_region_id(),
		"floors_cleared": _max_floor_reached,
	})
	_flush()


func _on_phase_changed(old_phase: GameContext.GamePhase, new_phase: GameContext.GamePhase) -> void:
	# Track max floor reached (capture before exit_to_town resets it)
	if new_phase == GameContext.GamePhase.COMBAT:
		_max_floor_reached = maxi(_max_floor_reached, GameContext.get_current_floor())

	_log_event({
		"type": "phase_change",
		"old_phase": GameContext.GamePhase.keys()[old_phase],
		"new_phase": GameContext.GamePhase.keys()[new_phase],
		"region": GameContext.get_current_region_id(),
		"floor": GameContext.get_current_floor(),
	})
	# Flush when returning to town
	if new_phase == GameContext.GamePhase.TOWN:
		_flush()


func _on_combat_ended(result: CombatResult) -> void:
	var duration_ms: int = Time.get_ticks_msec() - _combat_start_ms
	var is_boss: bool = result.is_boss_encounter if result != null else false

	var event_data: Dictionary = {
		"type": "combat_end",
		"region": GameContext.get_current_region_id(),
		"floor": GameContext.get_current_floor(),
		"room_type": GameContext.get_current_room_type(),
		"outcome": result.get_outcome_string() if result != null else "UNKNOWN",
		"rounds": result.total_rounds if result != null else 0,
		"turns": result.total_turns if result != null else 0,
		"fallen": result.fallen_heroes.size() if result != null else 0,
		"boss": is_boss,
		"dmg_dealt": result.total_damage_dealt_by_players if result != null else 0,
		"dmg_taken": result.total_damage_dealt_by_enemies if result != null else 0,
		"duration_ms": duration_ms,
	}
	_log_event(event_data)

	# Log individual hero deaths for death-location analysis
	if result != null and result.fallen_heroes.size() > 0:
		for hero_id in result.fallen_heroes:
			var hero: Dictionary = GameContext.get_hero(hero_id)
			if hero.size() > 0:
				_log_event({
					"type": "hero_death",
					"hero_class": hero.get("class_id", "unknown"),
					"hero_level": hero.get("level", 1),
					"region": GameContext.get_current_region_id(),
					"floor": GameContext.get_current_floor(),
					"boss": is_boss,
				})


# ============================================================================
# INTERNAL
# ============================================================================

func _log_event(data: Dictionary) -> void:
	if not GameContext.telemetry_consent:
		return
	data["ts"] = int(Time.get_unix_time_from_system())
	_events.append(data)


func _get_session_file_path() -> String:
	return TELEMETRY_DIR.path_join("session_%s.json" % _session_id)


func _flush() -> void:
	if not GameContext.telemetry_consent:
		return
	if _events.is_empty():
		return

	# Ensure directory exists
	if not DirAccess.dir_exists_absolute(TELEMETRY_DIR):
		DirAccess.make_dir_recursive_absolute(TELEMETRY_DIR)

	var session_data: Dictionary = {
		"version": TELEMETRY_VERSION,
		"game_version": GAME_VERSION,
		"session_id": _session_id,
		"events": _events,
	}

	var json_str: String = JSON.stringify(session_data, "\t")
	var file_path: String = _get_session_file_path()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file != null:
		file.store_string(json_str)
		file.close()
		if not _flushed:
			print("[TelemetryManager] First flush → %s (%d events)" % [file_path, _events.size()])
			_flushed = true
	else:
		push_warning("[TelemetryManager] Failed to write telemetry file: %s" % file_path)
