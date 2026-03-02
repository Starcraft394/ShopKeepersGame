## UIAudio.gd
## Lightweight autoload that adds click/hover sounds to all Button nodes,
## manages background music playback with region-specific tracks,
## provides SFX playback via a pooled player system,
## and provides a global pause/options menu.
## Uses SceneTree.node_added to attach sounds automatically.
extends Node

# UI SFX
var _click_sound: AudioStream = null
var _hover_sound: AudioStream = null
var _player: AudioStreamPlayer = null

# SFX Player Pool (for overlapping sounds)
const SFX_POOL_SIZE = 4
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _sfx_cache: Dictionary = {}  # slot_name -> AudioStream

# Background Music
var _bgm_player: AudioStreamPlayer = null
var _bgm_tracks: Dictionary = {}  # key -> AudioStream
var _bgm_track_keys: Array[String] = []  # ordered list of track keys
var _current_track_key: String = ""  # currently playing track key

# Closeable Stack — LIFO overlay close system for ESC key
var _closeable_stack: Array = []  # [{node: Node, close: Callable}]

# Pause/Options Menu
var _pause_overlay: CanvasLayer = null
var _bgm_slider: HSlider = null
var _sfx_slider: HSlider = null
var _bgm_value_label: Label = null
var _sfx_value_label: Label = null

const BGM_DIR = "res://Assets/Audio/BGM/"
const SFX_DIR = "res://Assets/Audio/SFX/"
const BGM_DEFAULT_VOLUME_DB = -20.0  # ~25% perceived loudness (10% linear amplitude)
const SFX_DEFAULT_VOLUME_DB = -6.0

# Region-to-track mapping (new organized BGM)
const REGION_BGM: Dictionary = {
	"region_1": "Region/bgm_region_1_forest_haven.mp3",
	"region_2": "Region/bgm_region_2_fungalmire.mp3",
	"region_3": "Region/bgm_region_3_sunken_strand.mp3",
	"region_4": "Region/bgm_region_4_ashen_horizons.mp3",
	"region_5": "Region/bgm_region_5_starfall_expanse.mp3",
	"region_6": "Region/bgm_region_6_necropolis.mp3",
	"region_7": "Region/bgm_region_7_final_realm.mp3",
}

# Scene BGM keys (not region-specific)
const SCENE_BGM: Dictionary = {
	"town": "Region/bgm_town.wav",
	"shop": "Region/bgm_shop.wav",
	"dungeon_camp": "Region/bgm_dungeon_camp.wav",
	"combat_normal": "Combat/bgm_combat_normal.wav",
	"combat_boss": "Combat/bgm_combat_boss.wav",
	"stinger_victory": "Stingers/stinger_victory.wav",
	"stinger_defeat": "Stingers/stinger_defeat.wav",
	"title_screen": "Cutscene/bgm_title_screen.mp3",
	"intro_cutscene": "Cutscene/bgm_intro_cutscene.mp3",
}

# Display names for jukebox (thematic per region)
const BGM_DISPLAY_NAMES: Dictionary = {
	"Region/bgm_region_1_forest_haven.mp3": "Forest Haven Theme",
	"Region/bgm_region_2_fungalmire.mp3": "Fungalmire Theme",
	"Region/bgm_region_3_sunken_strand.mp3": "Sunken Strand Theme",
	"Region/bgm_region_4_ashen_horizons.mp3": "Ashen Horizons Theme",
	"Region/bgm_region_5_starfall_expanse.mp3": "Starfall Expanse Theme",
	"Region/bgm_region_6_necropolis.mp3": "Necropolis Theme",
	"Region/bgm_region_7_final_realm.mp3": "Final Realm Theme",
	"Region/bgm_town.wav": "Town Theme",
	"Region/bgm_shop.wav": "Shop Theme",
	"Region/bgm_dungeon_camp.wav": "Dungeon Camp Theme",
	"Combat/bgm_combat_normal.wav": "Combat Theme",
	"Combat/bgm_combat_boss.wav": "Boss Battle Theme",
	"Cutscene/bgm_title_screen.mp3": "Deceitful Castle (Title)",
	"Cutscene/bgm_intro_cutscene.mp3": "Ancient Ruins (Intro)",
}

# SFX Registry: slot_name -> file path relative to SFX_DIR
const SFX_REGISTRY: Dictionary = {
	# Combat — Melee attacks
	"attack_melee_sword": "Combat/Melee/sword_attack_01.wav",
	"attack_melee_axe": "Combat/Melee/axe_attack_01.wav",
	"attack_melee_mace": "Combat/Melee/mace_attack_01.wav",
	"attack_melee_dagger": "Combat/Melee/dagger_attack_01.wav",
	"attack_generic": "Combat/Melee/attack_generic.wav",
	# Combat — Ranged
	"attack_ranged_bow": "Combat/Ranged/bow_attack_01.wav",
	# Combat — Impact
	"hit_damage": "Combat/Impact/hit_damage.wav",
	"hit_critical": "Combat/Impact/hit_critical.wav",
	"block": "Combat/Impact/block.wav",
	"miss": "Combat/Impact/miss.wav",
	"death_hero": "Combat/Impact/death_hero.wav",
	"death_enemy": "Combat/Impact/death_enemy.wav",
	"combat_start": "Combat/Impact/combat_start.wav",
	# Combat — Magic
	"spell_generic": "Combat/Magic/spell_generic.mp3",
	"spell_fire": "Combat/Magic/spell_fire.mp3",
	"spell_ice": "Combat/Magic/spell_ice.mp3",
	"spell_lightning": "Combat/Magic/spell_lightning.mp3",
	"spell_nature": "Combat/Magic/spell_nature.mp3",
	"spell_void": "Combat/Magic/spell_void.mp3",
	"spell_shadow": "Combat/Magic/spell_shadow.mp3",
	"spell_water": "Combat/Magic/spell_water.mp3",
	"spell_earth": "Combat/Magic/spell_earth.mp3",
	"spell_wind": "Combat/Magic/spell_wind.mp3",
	"spell_doom": "Combat/Magic/spell_doom.mp3",
	# Combat — Status
	"heal": "Combat/Status/heal.mp3",
	"buff_apply": "Combat/Status/buff_apply.mp3",
	"debuff_apply": "Combat/Status/debuff_apply.mp3",
	"stun_applied": "Combat/Status/stun_applied.mp3",
	"status_tick": "Combat/Status/status_tick.mp3",
	"status_expire": "Combat/Status/status_expire.mp3",
	"consumable_use": "Combat/Status/consumable_use.mp3",
	"passive_trigger": "Combat/Status/passive_trigger.mp3",
	# Town
	"gold_gain": "Town/gold_gain.wav",
	"gold_spend": "Town/gold_spend.wav",
	"hero_recruit": "Town/hero_recruit.wav",
	"hero_dismiss": "Town/hero_dismiss.wav",
	"facility_access": "Town/facility_access.wav",
	"facility_upgrade": "Town/facility_upgrade.wav",
	"unlock_purchase": "Town/unlock_purchase.wav",
	"travel_region": "Town/travel_region.wav",
	"error_insufficient": "Town/error_insufficient.mp3",
	# Inventory
	"item_pickup": "Inventory/item_pickup.wav",
	"equip_weapon": "Inventory/equip_weapon.wav",
	"equip_armor": "Inventory/equip_armor.wav",
	"equip_accessory": "Inventory/equip_accessory.wav",
	"equip_bag": "Inventory/equip_bag.wav",
	"unequip": "Inventory/unequip.wav",
	"consume_potion": "Inventory/consume_potion.mp3",
	"consume_food": "Inventory/consume_food.wav",
	"item_buy": "Inventory/item_buy.wav",
	"item_sell": "Inventory/item_sell.wav",
	"item_select": "Inventory/item_select.wav",
	# Events / Dungeon
	"event_trigger": "Events/event_trigger.mp3",
	"event_choice": "Events/event_choice.mp3",
	"event_outcome_good": "Events/event_outcome_good.wav",
	"event_outcome_bad": "Events/event_outcome_bad.mp3",
	"event_outcome_neutral": "Events/event_outcome_neutral.mp3",
	"room_choice": "Events/room_choice.mp3",
	"extraction": "Events/extraction.wav",
	"descend_floor": "Events/descend_floor.wav",
	"camp_arrive": "Events/camp_arrive.wav",
	# Loot
	"loot_appear": "Loot/loot_appear.wav",
	"loot_assign": "Loot/loot_assign.wav",
	"loot_discard": "Loot/loot_discard.wav",
	# Stingers (SFX dir)
	"dungeon_enter": "Stingers/dungeon_enter.wav",
	"extraction_success": "Stingers/extraction_success.wav",
	"level_up": "Stingers/level_up.mp3",
}


func _ready() -> void:
	# Keep processing while tree is paused (for ESC menu)
	process_mode = Node.PROCESS_MODE_ALWAYS

	_click_sound = _load_audio("res://Assets/Audio/UI/Kenney/Audio/click3.ogg")
	_hover_sound = _load_audio("res://Assets/Audio/UI/Kenney/Audio/rollover1.ogg")

	# UI click player (dedicated, not pooled)
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = SFX_DEFAULT_VOLUME_DB
	add_child(_player)

	# SFX player pool for overlapping game sounds
	for i in SFX_POOL_SIZE:
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = SFX_DEFAULT_VOLUME_DB
		add_child(p)
		_sfx_pool.append(p)

	get_tree().node_added.connect(_on_node_added)
	print("[UIAudio] Initialized — auto-wiring button sounds, SFX pool size=%d" % SFX_POOL_SIZE)

	# Background music setup
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = BGM_DEFAULT_VOLUME_DB
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	_load_bgm_tracks()
	# Play region-appropriate track on startup (skip if no save slot selected — title screen)
	if _bgm_tracks.size() > 0:
		if GameContext.current_save_slot < 0:
			print("[UIAudio] Skipping auto-play — no save slot selected (title screen)")
		else:
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
# CLOSEABLE STACK — Register overlays for ESC-to-close (LIFO)
# ============================================================================

## Register an overlay node so ESC closes it before showing the pause menu.
## Later registrations close first (LIFO). The close_fn callable is invoked on ESC.
func register_closeable(node: Node, close_fn: Callable) -> void:
	# Avoid duplicates
	for entry in _closeable_stack:
		if entry["node"] == node:
			return
	_closeable_stack.append({"node": node, "close": close_fn})


## Unregister an overlay node (call when the overlay closes itself).
func unregister_closeable(node: Node) -> void:
	for i in range(_closeable_stack.size() - 1, -1, -1):
		if _closeable_stack[i]["node"] == node:
			_closeable_stack.remove_at(i)
			return


## Returns true if there are any closeable overlays registered.
func has_closeables() -> bool:
	# Prune stale entries first
	_prune_stale_closeables()
	return _closeable_stack.size() > 0


## Remove entries whose nodes have been freed.
func _prune_stale_closeables() -> void:
	for i in range(_closeable_stack.size() - 1, -1, -1):
		if not is_instance_valid(_closeable_stack[i]["node"]):
			_closeable_stack.remove_at(i)


# ============================================================================
# GLOBAL ESC HANDLER
# ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Prune stale entries (nodes freed without unregister)
		_prune_stale_closeables()
		if _closeable_stack.size() > 0:
			# Pop the topmost closeable and invoke its close callable
			var top = _closeable_stack.pop_back()
			if is_instance_valid(top["node"]):
				top["close"].call()
		elif _pause_overlay != null:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()


# ============================================================================
# BACKGROUND MUSIC — Region-Based
# ============================================================================

func _load_bgm_tracks() -> void:
	# Collect all BGM track keys from region + scene dictionaries
	_bgm_track_keys = []
	for region_key in REGION_BGM:
		var track_key: String = REGION_BGM[region_key]
		if track_key not in _bgm_track_keys:
			_bgm_track_keys.append(track_key)
	for scene_key in SCENE_BGM:
		var track_key: String = SCENE_BGM[scene_key]
		if track_key not in _bgm_track_keys:
			_bgm_track_keys.append(track_key)

	for track_key in _bgm_track_keys:
		var track = _load_audio(BGM_DIR + track_key)
		if track != null:
			_bgm_tracks[track_key] = track
			print("[UIAudio] Loaded BGM: %s" % track_key)

	print("[UIAudio] Loaded %d BGM tracks" % _bgm_tracks.size())


## Play the BGM track assigned to a region. Loops the track.
## If the same track is already playing, does nothing.
func play_region_bgm(region_id: String) -> void:
	var active_bgm: Dictionary = REGION_BGM
	var track_key: String = active_bgm.get(region_id, "")
	if track_key == "":
		# Fallback to region_1 track
		track_key = active_bgm.get("region_1", "")
	if track_key == "" or not _bgm_tracks.has(track_key):
		return
	if track_key == _current_track_key and _bgm_player.playing:
		return  # Already playing this track

	_play_track(track_key)
	var dname: String = _get_display_name(track_key)
	print("[UIAudio] Playing region BGM: %s (%s)" % [region_id, dname])


## Play a scene-specific BGM by scene key (e.g., "town", "combat_normal", "combat_boss").
## If the same track is already playing, does nothing.
func play_bgm(scene_key: String) -> void:
	var track_key: String = SCENE_BGM.get(scene_key, "")
	if track_key == "" or not _bgm_tracks.has(track_key):
		print("[UIAudio] Unknown BGM scene key: %s" % scene_key)
		return
	if track_key == _current_track_key and _bgm_player.playing:
		return
	_play_track(track_key)
	var dname: String = _get_display_name(track_key)
	print("[UIAudio] Playing BGM: %s (%s)" % [scene_key, dname])


## Play a specific track by key. Loops it.
func _play_track(track_key: String) -> void:
	if not _bgm_tracks.has(track_key):
		return
	_current_track_key = track_key
	_bgm_player.stream = _bgm_tracks[track_key]
	_bgm_player.play()


## When a track finishes, replay it (looping behavior).
func _on_bgm_finished() -> void:
	if _current_track_key != "" and _bgm_tracks.has(_current_track_key):
		_bgm_player.stream = _bgm_tracks[_current_track_key]
		_bgm_player.play()


## Get display name for a track key.
func _get_display_name(track_key: String) -> String:
	return BGM_DISPLAY_NAMES.get(track_key, track_key)


## Get the display name of the currently playing track.
func get_current_track_display_name() -> String:
	return _get_display_name(_current_track_key)


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
	var vol_db: float = -80.0
	if percent > 0.0:
		vol_db = linear_to_db(percent)
	if _player != null:
		_player.volume_db = vol_db
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.volume_db = vol_db


## Get current SFX volume as a 0-1 percentage.
func get_sfx_volume() -> float:
	if _player == null:
		return 0.0
	return db_to_linear(_player.volume_db)


# ============================================================================
# SFX PLAYBACK — Pooled
# ============================================================================

## Play a sound effect by slot name (e.g., "attack_melee_sword", "gold_gain").
## Uses a round-robin pool to allow overlapping sounds.
func play_sfx(slot_name: String) -> void:
	if not SFX_REGISTRY.has(slot_name):
		return

	# Lazy-load and cache the audio stream
	if not _sfx_cache.has(slot_name):
		var stream = _load_audio(SFX_DIR + SFX_REGISTRY[slot_name])
		if stream == null:
			return
		_sfx_cache[slot_name] = stream

	var stream: AudioStream = _sfx_cache[slot_name]
	if stream == null:
		return

	# Round-robin through the pool
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.play()


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
	title.add_theme_font_size_override("font_size", GameContext.fs(22))
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.82))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# --- Music Volume ---
	var bgm_label = Label.new()
	bgm_label.text = "Music Volume"
	bgm_label.add_theme_font_size_override("font_size", GameContext.fs(15))
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
	_bgm_slider.focus_mode = Control.FOCUS_ALL
	_bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	bgm_row.add_child(_bgm_slider)

	_bgm_value_label = Label.new()
	_bgm_value_label.text = "%d%%" % roundi(get_bgm_volume() * 100)
	_bgm_value_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	_bgm_value_label.custom_minimum_size.x = 40
	bgm_row.add_child(_bgm_value_label)

	# --- SFX Volume ---
	var sfx_label = Label.new()
	sfx_label.text = "SFX Volume"
	sfx_label.add_theme_font_size_override("font_size", GameContext.fs(15))
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
	_sfx_slider.focus_mode = Control.FOCUS_ALL
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	sfx_row.add_child(_sfx_slider)

	_sfx_value_label = Label.new()
	_sfx_value_label.text = "%d%%" % roundi(get_sfx_volume() * 100)
	_sfx_value_label.add_theme_font_size_override("font_size", GameContext.fs(14))
	_sfx_value_label.custom_minimum_size.x = 40
	sfx_row.add_child(_sfx_value_label)

	# --- Display ---
	var display_sep = HSeparator.new()
	vbox.add_child(display_sep)

	var ts_row = HBoxContainer.new()
	ts_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ts_row)

	var ts_label = Label.new()
	ts_label.text = "Text Size:"
	ts_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	ts_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	ts_row.add_child(ts_label)

	var size_names: Array = ["S", "M", "L"]
	for i in 3:
		var btn = Button.new()
		btn.text = size_names[i]
		btn.custom_minimum_size = Vector2(40, 28)
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		if i == GameContext.text_size:
			btn.disabled = true
			btn.modulate = Color(0.5, 1.0, 0.8, 1)
		else:
			var idx: int = i
			btn.pressed.connect(func():
				GameContext.text_size = idx
				GameContext.apply_text_size_to_theme()
				GameContext.save_game()
				print("[Options] Text size -> %s" % size_names[idx])
				var was_paused = get_tree().paused
				_close_pause_menu()
				get_tree().paused = was_paused
				_open_pause_menu()
			)
		ts_row.add_child(btn)

	# --- Window Size ---
	var ws_row = HBoxContainer.new()
	ws_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ws_row)

	var ws_label = Label.new()
	ws_label.text = "Window:"
	ws_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	ws_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	ws_row.add_child(ws_label)

	var scale_names: Array = ["1x", "2x", "3x", "Full"]
	var scale_values: Array = [1, 2, 3, 0]
	for i in 4:
		var ws_btn = Button.new()
		ws_btn.text = scale_names[i]
		ws_btn.custom_minimum_size = Vector2(44, 28)
		ws_btn.focus_mode = Control.FOCUS_ALL
		ws_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		if scale_values[i] == GameContext.window_scale:
			ws_btn.disabled = true
			ws_btn.modulate = Color(0.5, 1.0, 0.8, 1)
		else:
			var scale_val: int = scale_values[i]
			ws_btn.pressed.connect(func():
				GameContext.window_scale = scale_val
				GameContext.apply_window_scale()
				GameContext.save_game()
				print("[Options] Window scale -> %s" % scale_names[scale_values.find(scale_val)])
				var was_paused = get_tree().paused
				_close_pause_menu()
				get_tree().paused = was_paused
				_open_pause_menu()
			)
		ws_row.add_child(ws_btn)

	# --- Telemetry Toggle ---
	var telem_row = HBoxContainer.new()
	telem_row.add_theme_constant_override("separation", 8)
	vbox.add_child(telem_row)
	var telem_lbl = Label.new()
	telem_lbl.text = "Telemetry:"
	telem_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
	telem_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	telem_row.add_child(telem_lbl)
	var telem_names: Array = ["On", "Off"]
	var telem_values: Array = [true, false]
	for ti in 2:
		var t_btn = Button.new()
		t_btn.text = telem_names[ti]
		t_btn.custom_minimum_size = Vector2(44, 28)
		t_btn.focus_mode = Control.FOCUS_ALL
		t_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		if telem_values[ti] == GameContext.telemetry_consent:
			t_btn.disabled = true
			t_btn.modulate = Color(0.5, 1.0, 0.8, 1)
		else:
			t_btn.modulate = Color(0.7, 0.7, 0.7, 1)
			var t_val: bool = telem_values[ti]
			t_btn.pressed.connect(func():
				GameContext.telemetry_consent = t_val
				GameContext.save_game()
				print("[Options] Telemetry %s" % ("ON" if t_val else "OFF"))
				var was_paused = get_tree().paused
				_close_pause_menu()
				get_tree().paused = was_paused
				_open_pause_menu()
			)
		telem_row.add_child(t_btn)

	var display_sep2 = HSeparator.new()
	vbox.add_child(display_sep2)

	# --- Gameplay Options ---
	var gameplay_label = Label.new()
	gameplay_label.text = "Gameplay"
	gameplay_label.add_theme_font_size_override("font_size", GameContext.fs(15))
	gameplay_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(gameplay_label)

	var auto_loot_check = CheckButton.new()
	auto_loot_check.focus_mode = Control.FOCUS_ALL
	auto_loot_check.text = "Auto-Loot"
	auto_loot_check.tooltip_text = "Automatically deposit combat loot into Shopkeeper Bag, then Hero Bags.\nDisable to manually route each item."
	auto_loot_check.button_pressed = GameContext.auto_loot
	auto_loot_check.toggled.connect(func(on: bool):
		GameContext.auto_loot = on
		GameContext.save_game()
		print("[Options] Auto-Loot %s" % ("ON" if on else "OFF"))
	)
	vbox.add_child(auto_loot_check)

	var tester_check = CheckButton.new()
	tester_check.focus_mode = Control.FOCUS_ALL
	tester_check.text = "Tester Mode"
	tester_check.tooltip_text = "Show dev/debug buttons (e.g. +100 Gold) in town screens."
	tester_check.button_pressed = GameContext.tester_mode
	tester_check.toggled.connect(func(on: bool):
		GameContext.tester_mode = on
		GameContext.save_game()
		print("[Options] Tester Mode %s" % ("ON" if on else "OFF"))
	)
	vbox.add_child(tester_check)

	var sep_gameplay = HSeparator.new()
	vbox.add_child(sep_gameplay)

	# --- Buttons ---
	var btn_resume = Button.new()
	btn_resume.text = "Resume"
	btn_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_resume.focus_mode = Control.FOCUS_ALL
	btn_resume.pressed.connect(_close_pause_menu)
	vbox.add_child(btn_resume)

	var btn_save_quit = Button.new()
	btn_save_quit.text = "Save & Exit"
	btn_save_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save_quit.focus_mode = Control.FOCUS_ALL
	btn_save_quit.modulate = Color(0.6, 1.0, 0.6)
	btn_save_quit.pressed.connect(_on_pause_save_quit)
	vbox.add_child(btn_save_quit)

	# --- Feedback Links ---
	var feedback_row = HBoxContainer.new()
	feedback_row.add_theme_constant_override("separation", 8)
	feedback_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(feedback_row)

	var btn_bug = Button.new()
	btn_bug.text = "Report Bug"
	btn_bug.custom_minimum_size = Vector2(104, 30)
	btn_bug.focus_mode = Control.FOCUS_ALL
	btn_bug.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_bug.modulate = Color(1.0, 0.8, 0.6)
	btn_bug.pressed.connect(func():
		OS.shell_open("https://github.com/Starcraft394/ShopKeepersGame/issues/new/choose")
	)
	feedback_row.add_child(btn_bug)

	var btn_community = Button.new()
	btn_community.text = "Community"
	btn_community.custom_minimum_size = Vector2(104, 30)
	btn_community.focus_mode = Control.FOCUS_ALL
	btn_community.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_community.modulate = Color(0.7, 0.8, 1.0)
	btn_community.pressed.connect(func():
		OS.shell_open("https://github.com/Starcraft394/ShopKeepersGame/discussions")
	)
	feedback_row.add_child(btn_community)

	var btn_credits = Button.new()
	btn_credits.text = "Credits"
	btn_credits.custom_minimum_size = Vector2(78, 30)
	btn_credits.focus_mode = Control.FOCUS_ALL
	btn_credits.add_theme_font_size_override("font_size", GameContext.fs(12))
	btn_credits.modulate = Color(0.8, 0.75, 0.9)
	btn_credits.pressed.connect(func():
		CreditsOverlay.show(get_tree().root)
	)
	feedback_row.add_child(btn_credits)

	btn_resume.call_deferred("grab_focus")

	# Hint
	var hint = Label.new()
	hint.text = "Press %s to resume" % InputManager.get_glyph("ui_cancel")
	hint.add_theme_font_size_override("font_size", GameContext.fs(12))
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
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


func _on_pause_save_quit() -> void:
	_close_pause_menu()
	GameContext.save_game()
	SceneTransition.fade_to("res://Game/UI/TitleScreen/TitleScreen.tscn")
