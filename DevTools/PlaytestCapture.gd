extends Node
## PlaytestCapture — Screenshot capture utility + state logging for autoplay bot.
## Shared by AutoPlayBot (automatic) and F9 hotkey (manual).
## Max 60 screenshots per run to stay within Claude Code's processing limit.

const MAX_SCREENSHOTS := 60

var _step_count: int = 0
var _run_id: String = ""
var _run_dir: String = ""
var _state_log: Array = []
var _is_autoplay: bool = false

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	if "--autoplay" in args:
		_is_autoplay = true
		_init_run()

func _init_run() -> void:
	var dt = Time.get_datetime_dict_from_system()
	_run_id = "%04d%02d%02d_%02d%02d%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	_run_dir = "user://playtest_screenshots/" + _run_id
	DirAccess.make_dir_recursive_absolute(_run_dir)
	print("[PlaytestCapture] Run started: %s" % _run_id)
	print("[PlaytestCapture] Screenshots dir: %s" % _run_dir)

func get_screenshots_remaining() -> int:
	return MAX_SCREENSHOTS - _step_count

func capture(label: String = "") -> void:
	if _step_count >= MAX_SCREENSHOTS:
		return
	_step_count += 1
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	if img == null:
		print("[PlaytestCapture] WARNING: viewport image is null, skipping capture")
		_step_count -= 1
		return
	var phase_name: String = "UNKNOWN"
	if GameContext:
		phase_name = GameContext.get_phase_name()
	var safe_label: String = label.replace(" ", "_").replace("/", "_").replace("\\", "_")
	var filename: String = "%03d_%s_%s.png" % [_step_count, phase_name, safe_label]
	var err = img.save_png(_run_dir.path_join(filename))
	if err != OK:
		print("[PlaytestCapture] ERROR: Failed to save %s (error %d)" % [filename, err])
		_step_count -= 1
		return
	print("[PlaytestCapture] [%d/%d] %s" % [_step_count, MAX_SCREENSHOTS, filename])
	_log_state(filename)

func manual_capture() -> void:
	if _run_dir == "":
		_init_run()
	capture("manual")

func _log_state(filename: String) -> void:
	var entry: Dictionary = {
		"step": _step_count,
		"file": filename,
		"phase": GameContext.get_phase_name() if GameContext else "UNKNOWN",
		"gold": GameContext.run_gold if GameContext else 0,
		"heroes": GameContext.selected_party.size() if GameContext else 0,
		"town": GameContext._current_town_id if GameContext else "",
		"floor": GameContext.get_current_floor() if GameContext else 0,
	}
	_state_log.append(entry)
	var f = FileAccess.open(_run_dir.path_join("state_log.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"run_id": _run_id, "screenshots": _state_log}, "\t"))
		f.close()

func get_run_dir() -> String:
	return _run_dir
