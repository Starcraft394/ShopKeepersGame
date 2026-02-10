## DebugLog.gd
## Simple file-based debug logging system.
## Writes all debug output to a timestamped file for post-test review.
class_name DebugLog
extends RefCounted

static var _instance: DebugLog = null
static var _log_file: FileAccess = null
static var _log_path: String = ""
static var _enabled: bool = true

## Get or create the singleton instance
static func get_instance() -> DebugLog:
	if _instance == null:
		_instance = DebugLog.new()
		_instance._initialize()
	return _instance


## Initialize the log file
func _initialize() -> void:
	if not _enabled:
		return

	# Create log directory if needed
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("debug_logs"):
		dir.make_dir("debug_logs")

	# Create timestamped log file
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_log_path = "user://debug_logs/combat_log_%s.txt" % timestamp
	_log_file = FileAccess.open(_log_path, FileAccess.WRITE)

	if _log_file:
		_log_file.store_line("=== DEBUG LOG STARTED: %s ===" % Time.get_datetime_string_from_system())
		_log_file.store_line("Log file: %s" % _log_path)
		_log_file.store_line("=" .repeat(60))
		_log_file.store_line("")
		print("[DebugLog] Logging to: %s" % _log_path)
	else:
		push_error("[DebugLog] Failed to create log file at %s" % _log_path)


## Log a message to the debug file
static func write(message: String, category: String = "INFO") -> void:
	var inst = get_instance()
	if _log_file == null or not _enabled:
		return

	var timestamp = Time.get_time_string_from_system()
	var formatted = "[%s] [%s] %s" % [timestamp, category, message]
	_log_file.store_line(formatted)
	_log_file.flush()  # Ensure it's written immediately


## Log with category shortcuts
static func combat(message: String) -> void:
	write(message, "COMBAT")

static func ui(message: String) -> void:
	write(message, "UI")

static func error(message: String) -> void:
	write(message, "ERROR")

static func warn(message: String) -> void:
	write(message, "WARN")


## Close the log file (call on game exit)
static func close() -> void:
	if _log_file:
		_log_file.store_line("")
		_log_file.store_line("=== DEBUG LOG ENDED: %s ===" % Time.get_datetime_string_from_system())
		_log_file.close()
		_log_file = null
		print("[DebugLog] Log file closed: %s" % _log_path)


## Get the current log file path
static func get_log_path() -> String:
	return _log_path


## Convenience: Print to both console and log file
static func print_log(message: String, category: String = "INFO") -> void:
	print("[%s] %s" % [category, message])
	write(message, category)
