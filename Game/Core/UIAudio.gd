## UIAudio.gd
## Lightweight autoload that adds click/hover sounds to all Button nodes,
## manages background music playback with region-specific tracks,
## and provides a global pause/options menu with jukebox.
## Uses SceneTree.node_added to attach sounds automatically.
extends Node

# UI SFX
var _click_sound: AudioStream = null
var _hover_sound: AudioStream = null
var _player: AudioStreamPlayer = null

# Background Music
var _bgm_player: AudioStreamPlayer = null
var _bgm_tracks: Dictionary = {}  # filename -> AudioStream
var _bgm_track_files: Array[String] = []  # ordered list of filenames
var _current_track_file: String = ""  # currently playing track filename

# Pause/Options Menu
var _pause_overlay: CanvasLayer = null
var _bgm_slider: HSlider = null
var _sfx_slider: HSlider = null
var _bgm_value_label: Label = null
var _sfx_value_label: Label = null

const BGM_DIR = "res://Assets/Audio/BGM/"
const BGM_DEFAULT_VOLUME_DB = -20.0  # ~25% perceived loudness (10% linear amplitude)
const SFX_DEFAULT_VOLUME_DB = -6.0

# Region-to-track mapping
const REGION_BGM: Dictionary = {
	"region_1": "Deep smooth.mp3",
	"region_2": "hmmmmm mayybeee.mp3",
	"region_3": "Broken Memories.mp3",
	"region_4": "AHHHH SHIT.mp3",
	"region_5": "Galaxy Party.mp3",
	"region_6": "The Xperience.mp3",
	"region_7": "Fuck if i know.mp3",
}

# Display names for jukebox (thematic per region)
const BGM_DISPLAY_NAMES: Dictionary = {
	"Deep smooth.mp3": "Forest Haven Theme",
	"hmmmmm mayybeee.mp3": "Fungalmire Theme",
	"Broken Memories.mp3": "Sunken Strand Theme",
	"AHHHH SHIT.mp3": "Ashen Horizons Theme",
	"Galaxy Party.mp3": "Starfall Expanse Theme",
	"The Xperience.mp3": "Necropolis Theme",
	"Fuck if i know.mp3": "Final Realm Theme",
}


func _ready() -> void:
	# Keep processing while tree is paused (for ESC menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_click_sound = _load_audio("res://Assets/Audio/UI/Kenney/Audio/click3.ogg")
	_hover_sound = _load_audio("res://Assets/Audio/UI/Kenney/Audio/rollover1.ogg")

	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = SFX_DEFAULT_VOLUME_DB
	add_child(_player)

	get_tree().node_added.connect(_on_node_added)
	print("[UIAudio] Initialized — auto-wiring button sounds")

	# Background music setup
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = BGM_DEFAULT_VOLUME_DB
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	_load_bgm_tracks()
	# Play region-appropriate track on startup
	if _bgm_tracks.size() > 0:
		var region_id: String = ""
		if Engine.has_singleton("GameContext"):
			region_id = GameContext.get_current_region_id()
		if region_id == "":
			region_id = "region_1"
		play_region_bgm(region_id)


func _load_audio(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path) as AudioStream
	print("[UIAudio] Audio not found: %s" % path)
	return null


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(_play_click)


func _play_click() -> void:
	if _click_sound != null and is_instance_valid(_player):
		_player.stream = _click_sound
		_player.play()


# ============================================================================
# GLOBAL ESC HANDLER
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _pause_overlay != null:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


# ============================================================================
# BACKGROUND MUSIC — Region-Based
# ============================================================================

func _load_bgm_tracks() -> void:
	# Hardcoded track list for export reliability (DirAccess won't list res:// in .pck)
	_bgm_track_files = [
		"AHHHH SHIT.mp3",
		"Broken Memories.mp3",
		"Deep smooth.mp3",
		"Fuck if i know.mp3",
		"Galaxy Party.mp3",
		"hmmmmm mayybeee.mp3",
		"The Xperience.mp3",
	]

	for file_name in _bgm_track_files:
		var track = _load_audio(BGM_DIR + file_name)
		if track != null:
			_bgm_tracks[file_name] = track
			print("[UIAudio] Loaded BGM: %s" % file_name)

	print("[UIAudio] Loaded %d BGM tracks" % _bgm_tracks.size())


## Play the BGM track assigned to a region. Loops the track.
## If the same track is already playing, does nothing.
func play_region_bgm(region_id: String) -> void:
	var track_file: String = REGION_BGM.get(region_id, "")
	if track_file == "":
		# Fallback to region_1 track
		track_file = REGION_BGM.get("region_1", "")
	if track_file == "" or not _bgm_tracks.has(track_file):
		return
	if track_file == _current_track_file and _bgm_player.playing:
		return  # Already playing this track

	_play_track(track_file)
	var dname: String = BGM_DISPLAY_NAMES.get(track_file, track_file)
	print("[UIAudio] Playing region BGM: %s (%s)" % [region_id, dname])


## Play a specific track by filename. Loops it.
func _play_track(track_file: String) -> void:
	if not _bgm_tracks.has(track_file):
		return
	_current_track_file = track_file
	_bgm_player.stream = _bgm_tracks[track_file]
	_bgm_player.play()


## When a track finishes, replay it (looping behavior).
func _on_bgm_finished() -> void:
	if _current_track_file != "" and _bgm_tracks.has(_current_track_file):
		_bgm_player.stream = _bgm_tracks[_current_track_file]
		_bgm_player.play()


## Get the display name of the currently playing track.
func get_current_track_display_name() -> String:
	return BGM_DISPLAY_NAMES.get(_current_track_file, _current_track_file)


## Set BGM volume (0.0 = silent, 1.0 = full volume).
func set_bgm_volume(percent: float) -> void:
	if _bgm_player == null:
		return
	if percent <= 0.0:
		_bgm_player.volume_db = -80.0
	else:
		_bgm_player.volume_db = linear_to_db(percent)


## Get current BGM volume as a 0-1 percentage.
func get_bgm_volume() -> float:
	if _bgm_player == null:
		return 0.0
	return db_to_linear(_bgm_player.volume_db)


## Set SFX volume (0.0 = silent, 1.0 = full volume).
func set_sfx_volume(percent: float) -> void:
	if _player == null:
		return
	if percent <= 0.0:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(percent)


## Get current SFX volume as a 0-1 percentage.
func get_sfx_volume() -> float:
	if _player == null:
		return 0.0
	return db_to_linear(_player.volume_db)


# ============================================================================
# PAUSE / OPTIONS MENU (CanvasLayer overlay)
# ============================================================================

## Open the pause menu. Can be called from ESC or from UI buttons.
func show_options_menu() -> void:
	_open_pause_menu()


func _open_pause_menu() -> void:
	if _pause_overlay != null:
		return

	get_tree().paused = true

	_pause_overlay = CanvasLayer.new()
	_pause_overlay.layer = 20
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	# Backdrop
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.add_child(backdrop)

	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_overlay.add_child(center)

	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# Content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Menu"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# --- Music Volume ---
	var bgm_label = Label.new()
	bgm_label.text = "Music Volume"
	bgm_label.add_theme_font_size_override("font_size", 13)
	bgm_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(bgm_label)

	var bgm_row = HBoxContainer.new()
	bgm_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bgm_row)

	_bgm_slider = HSlider.new()
	_bgm_slider.min_value = 0.0
	_bgm_slider.max_value = 1.0
	_bgm_slider.step = 0.05
	_bgm_slider.value = get_bgm_volume()
	_bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgm_slider.custom_minimum_size.x = 200
	_bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	bgm_row.add_child(_bgm_slider)

	_bgm_value_label = Label.new()
	_bgm_value_label.text = "%d%%" % roundi(get_bgm_volume() * 100)
	_bgm_value_label.add_theme_font_size_override("font_size", 12)
	_bgm_value_label.custom_minimum_size.x = 40
	bgm_row.add_child(_bgm_value_label)

	# --- SFX Volume ---
	var sfx_label = Label.new()
	sfx_label.text = "SFX Volume"
	sfx_label.add_theme_font_size_override("font_size", 13)
	sfx_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(sfx_label)

	var sfx_row = HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sfx_row)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value = get_sfx_volume()
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.custom_minimum_size.x = 200
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	sfx_row.add_child(_sfx_slider)

	_sfx_value_label = Label.new()
	_sfx_value_label.text = "%d%%" % roundi(get_sfx_volume() * 100)
	_sfx_value_label.add_theme_font_size_override("font_size", 12)
	_sfx_value_label.custom_minimum_size.x = 40
	sfx_row.add_child(_sfx_value_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# --- Jukebox: Music Selection ---
	var jukebox_label = Label.new()
	jukebox_label.text = "Music Selection"
	jukebox_label.add_theme_font_size_override("font_size", 13)
	jukebox_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(jukebox_label)

	var now_playing = Label.new()
	now_playing.text = "Now Playing: %s" % get_current_track_display_name()
	now_playing.add_theme_font_size_override("font_size", 11)
	now_playing.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7, 1))
	now_playing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(now_playing)

	# Track buttons in region order
	for region_idx in range(1, 8):
		var region_key: String = "region_%d" % region_idx
		var track_file: String = REGION_BGM.get(region_key, "")
		if track_file == "" or not _bgm_tracks.has(track_file):
			continue

		var dname: String = BGM_DISPLAY_NAMES.get(track_file, track_file)
		var track_btn = Button.new()
		track_btn.text = dname
		track_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track_btn.custom_minimum_size = Vector2(0, 26)
		track_btn.add_theme_font_size_override("font_size", 11)

		if track_file == _current_track_file:
			track_btn.disabled = true
			track_btn.modulate = Color(0.5, 1.0, 0.8, 1)
		else:
			track_btn.pressed.connect(_on_jukebox_track_pressed.bind(track_file))

		vbox.add_child(track_btn)

	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# --- Buttons ---
	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_resume.pressed.connect(_close_pause_menu)
	vbox.add_child(btn_resume)

	var btn_save_quit = Button.new()
	btn_save_quit.text = "Save & Quit"
	btn_save_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_quit.modulate = Color(0.6, 1.0, 0.6)
	btn_save_quit.pressed.connect(_on_pause_save_quit)
	vbox.add_child(btn_save_quit)

	# Hint
	var hint = Label.new()
	hint.text = "Press ESC to resume"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	print("[UIAudio] Pause menu opened")


func _close_pause_menu() -> void:
	if _pause_overlay != null:
		_pause_overlay.queue_free()
		_pause_overlay = null
		_bgm_slider = null
		_sfx_slider = null
		_bgm_value_label = null
		_sfx_value_label = null
	get_tree().paused = false
	print("[UIAudio] Pause menu closed")


func _on_bgm_slider_changed(value: float) -> void:
	set_bgm_volume(value)
	if _bgm_value_label:
		_bgm_value_label.text = "%d%%" % roundi(value * 100)


func _on_sfx_slider_changed(value: float) -> void:
	set_sfx_volume(value)
	if _sfx_value_label:
		_sfx_value_label.text = "%d%%" % roundi(value * 100)


## Handle jukebox track selection from pause menu.
func _on_jukebox_track_pressed(track_file: String) -> void:
	_play_track(track_file)
	# Rebuild the pause menu to update button states
	var was_paused = get_tree().paused
	_close_pause_menu()
	get_tree().paused = was_paused
	_open_pause_menu()


func _on_pause_save_quit() -> void:
	_close_pause_menu()
	GameContext.save_game()
	get_tree().quit()
