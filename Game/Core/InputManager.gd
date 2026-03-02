## InputManager — Central input abstraction for gamepad + keyboard support.
## Autoload singleton. Registers all InputMap actions with dual bindings,
## detects active input device, provides glyph lookup for UI hints.
extends Node

signal input_device_changed(device_type: String)
signal zone_changed(zone_id: String)

## "keyboard" or "gamepad" — tracks which device the player last used
var active_device: String = "keyboard"

## Dead zone threshold for analog stick input
const STICK_DEADZONE := 0.4

## Virtual cursor settings
const CURSOR_SPEED := 600.0        # pixels/sec at full stick tilt
const CURSOR_DEADZONE := 0.15      # right stick dead zone
const RT_PRESS_THRESHOLD := 0.5    # trigger axis value to count as "pressed"
const RT_RELEASE_THRESHOLD := 0.3  # trigger axis value to count as "released"
const LT_PRESS_THRESHOLD := 0.5    # left trigger press threshold
const LT_RELEASE_THRESHOLD := 0.3  # left trigger release threshold
const HOLD_THRESHOLD := 0.15       # seconds before press becomes hold (for drag)

## Focus zone settings
const ZONE_STICK_COOLDOWN := 0.3   # 300ms between zone switches
const ZONE_STICK_THRESHOLD := 0.7  # Higher threshold for intentional push

## Virtual cursor state
var _cursor_canvas: CanvasLayer = null
var _virtual_cursor: TextureRect = null
var _cursor_position: Vector2 = Vector2.ZERO
var _cursor_visible: bool = false
var _rt_was_pressed: bool = false
var _lt_was_pressed: bool = false
var _a_was_pressed: bool = false
## Hold-to-drag state: 0=IDLE, 1=PENDING (waiting for threshold), 2=HOLDING (mouse pressed)
var _hold_state: int = 0
var _hold_start_time: float = 0.0
var _hold_source: String = ""  # "lt" or "a" — which button initiated the hold
var _warp_frame: int = -10  # Engine frame of last warp/synthetic event (suppresses mouse events for 2 frames)
## When true, right stick moves a facility panel instead of the virtual cursor
var panel_move_override: bool = false

## Focus zone state
var _zones: Dictionary = {}         # zone_id → { "controls": Array, "container": Control, "neighbors": Dictionary }
var _active_zone_id: String = ""
var _zone_stick_cooldown: float = 0.0
var _zone_border_panel: PanelContainer = null
var _zone_border_canvas: CanvasLayer = null
var _zone_border_color: Color = Color(1.0, 0.85, 0.3, 0.9)

# ============================================================================
# ACTION DEFINITIONS
# ============================================================================

## Returns the full action definitions array. Built at runtime to avoid const
## initialization issues with nested dictionaries containing engine constants.
static func _get_action_defs() -> Array:
	return [
		# --- Universal ---
		{ "action": "gp_pause", "keys": [], "buttons": [JOY_BUTTON_START] },
		{ "action": "gp_inspect", "keys": [KEY_I], "buttons": [JOY_BUTTON_Y] },
		{ "action": "gp_tab_left", "keys": [], "buttons": [JOY_BUTTON_LEFT_SHOULDER] },
		{ "action": "gp_tab_right", "keys": [], "buttons": [JOY_BUTTON_RIGHT_SHOULDER] },

		# --- Combat actions ---
		{ "action": "combat_action_1", "keys": [KEY_1], "buttons": [JOY_BUTTON_X] },
		{ "action": "combat_action_2", "keys": [KEY_2], "buttons": [JOY_BUTTON_Y] },
		{ "action": "combat_action_3", "keys": [KEY_3], "buttons": [JOY_BUTTON_LEFT_SHOULDER] },
		{ "action": "combat_action_4", "keys": [KEY_4], "buttons": [JOY_BUTTON_RIGHT_SHOULDER] },
		{ "action": "combat_action_5", "keys": [KEY_5], "buttons": [], "axes": [{ "axis": JOY_AXIS_TRIGGER_LEFT, "value": 0.5 }] },
		{ "action": "combat_pass", "keys": [KEY_P], "buttons": [JOY_BUTTON_BACK] },
		{ "action": "combat_auto", "keys": [KEY_ALT], "buttons": [JOY_BUTTON_RIGHT_STICK] },

		# --- Loot panel (keyboard only — D-pad reserved for navigation) ---
		{ "action": "loot_hero_1", "keys": [KEY_1], "buttons": [] },
		{ "action": "loot_hero_2", "keys": [KEY_2], "buttons": [] },
		{ "action": "loot_hero_3", "keys": [KEY_3], "buttons": [] },
		{ "action": "loot_hero_4", "keys": [KEY_4], "buttons": [] },
		{ "action": "loot_shop_bag", "keys": [KEY_B], "buttons": [JOY_BUTTON_X] },
		{ "action": "loot_deposit", "keys": [KEY_D], "buttons": [JOY_BUTTON_Y] },

		# --- Dungeon / events ---
		{ "action": "choice_1", "keys": [KEY_1, KEY_A], "buttons": [] },
		{ "action": "choice_2", "keys": [KEY_2, KEY_B], "buttons": [] },
		{ "action": "choice_3", "keys": [KEY_3, KEY_C], "buttons": [] },
		{ "action": "choice_4", "keys": [KEY_4], "buttons": [] },
		{ "action": "camp_extract", "keys": [KEY_E], "buttons": [JOY_BUTTON_BACK] },

		# --- Inventory / bag interactions ---
		{ "action": "use_item", "keys": [KEY_R], "buttons": [JOY_BUTTON_X] },
		{ "action": "swap_item", "keys": [KEY_S], "buttons": [JOY_BUTTON_Y] },
	]

# --- Glyph mappings per device ---
const _KEYBOARD_GLYPHS: Dictionary = {
	"ui_accept": "Enter", "ui_cancel": "Esc",
	"ui_up": "Up", "ui_down": "Down", "ui_left": "Left", "ui_right": "Right",
	"gp_pause": "Esc", "gp_inspect": "I", "gp_tab_left": "", "gp_tab_right": "",
	"combat_action_1": "1", "combat_action_2": "2", "combat_action_3": "3",
	"combat_action_4": "4", "combat_action_5": "5",
	"combat_pass": "P", "combat_auto": "Alt",
	"loot_hero_1": "1", "loot_hero_2": "2", "loot_hero_3": "3", "loot_hero_4": "4",
	"loot_shop_bag": "B", "loot_deposit": "D",
	"choice_1": "1", "choice_2": "2", "choice_3": "3", "choice_4": "4",
	"camp_extract": "E",
	"use_item": "R", "swap_item": "S",
}

const _GAMEPAD_GLYPHS: Dictionary = {
	"ui_accept": "A", "ui_cancel": "B",
	"ui_up": "D-Up", "ui_down": "D-Down", "ui_left": "D-Left", "ui_right": "D-Right",
	"gp_pause": "Start", "gp_inspect": "Y", "gp_tab_left": "LB", "gp_tab_right": "RB",
	"combat_action_1": "X", "combat_action_2": "Y", "combat_action_3": "LB",
	"combat_action_4": "RB", "combat_action_5": "LT",
	"combat_pass": "Select", "combat_auto": "R3",
	"loot_hero_1": "1", "loot_hero_2": "2", "loot_hero_3": "3", "loot_hero_4": "4",
	"loot_shop_bag": "X", "loot_deposit": "Y",
	"choice_1": "A", "choice_2": "X", "choice_3": "Y", "choice_4": "B",
	"camp_extract": "Select",
	"use_item": "X", "swap_item": "Y",
}


# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	_add_gamepad_to_builtin_actions()
	# Log connected controllers
	var pads = Input.get_connected_joypads()
	if pads.size() > 0:
		for pad_id in pads:
			print("[InputManager] Controller %d: %s" % [pad_id, Input.get_joy_name(pad_id)])
	else:
		print("[InputManager] No controllers detected")
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_setup_virtual_cursor()


func _setup_virtual_cursor() -> void:
	_cursor_canvas = CanvasLayer.new()
	_cursor_canvas.layer = 20  # Above everything
	add_child(_cursor_canvas)

	_virtual_cursor = TextureRect.new()
	_virtual_cursor.texture = _create_cursor_texture()
	_virtual_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_virtual_cursor.visible = false
	_virtual_cursor.stretch_mode = TextureRect.STRETCH_KEEP
	_virtual_cursor.size = Vector2(16, 18)
	_virtual_cursor.pivot_offset = Vector2.ZERO
	_cursor_canvas.add_child(_virtual_cursor)

	_cursor_position = get_viewport().get_visible_rect().size / 2.0


func _create_cursor_texture() -> ImageTexture:
	# Generate a classic arrow cursor (16x18) procedurally — no external asset needed
	var img := Image.create(16, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var outline := Color(0.1, 0.1, 0.1, 1.0)
	var fill := Color(1.0, 1.0, 1.0, 1.0)
	# Each row: 0=transparent, 1=outline, 2=fill
	var rows: Array = [
		[1],
		[1, 2, 1],
		[1, 2, 2, 1],
		[1, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1],
		[1, 2, 2, 2, 2, 2, 1],
		[1, 2, 2, 1, 1, 2, 2, 1],
		[1, 2, 1, 0, 1, 2, 2, 1],
		[1, 1, 0, 0, 0, 1, 2, 2, 1],
		[1, 0, 0, 0, 0, 1, 2, 2, 1],
		[0, 0, 0, 0, 0, 0, 1, 2, 1],
		[0, 0, 0, 0, 0, 0, 0, 1, 1],
	]
	for y in range(rows.size()):
		for x in range(rows[y].size()):
			if rows[y][x] == 1:
				img.set_pixel(x, y, outline)
			elif rows[y][x] == 2:
				img.set_pixel(x, y, fill)
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if _zone_stick_cooldown > 0.0:
		_zone_stick_cooldown -= delta

	# Hold-to-drag: check if pending hold has crossed threshold
	if _hold_state == 1:  # PENDING
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _hold_start_time
		if elapsed >= HOLD_THRESHOLD:
			_hold_state = 2  # HOLDING
			_send_synthetic_press(MOUSE_BUTTON_LEFT)

	if not _cursor_visible:
		return

	# Skip virtual cursor when a facility panel is being moved via gamepad
	if panel_move_override:
		return

	# Read right stick
	var stick_x: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var stick_y: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_vec := Vector2(stick_x, stick_y)

	if stick_vec.length() < CURSOR_DEADZONE:
		return

	# Deadzone remapping + squared curve for precision at low tilt, speed at edges
	var magnitude: float = (stick_vec.length() - CURSOR_DEADZONE) / (1.0 - CURSOR_DEADZONE)
	magnitude = magnitude * magnitude  # Squared curve
	var move_vec: Vector2 = stick_vec.normalized() * magnitude * CURSOR_SPEED * delta
	_cursor_position += move_vec

	# Clamp to viewport
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_cursor_position = _cursor_position.clamp(Vector2.ZERO, vp_size - Vector2(1, 1))

	# Update visual position + warp hardware mouse to match
	_virtual_cursor.position = _cursor_position
	_warp_frame = Engine.get_process_frames()
	Input.warp_mouse(_cursor_position)


func _show_virtual_cursor() -> void:
	if _cursor_visible:
		return
	_cursor_visible = true
	if _virtual_cursor != null:
		_virtual_cursor.visible = true
	# Hide hardware cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	print("[InputManager] Virtual cursor shown")


func _hide_virtual_cursor() -> void:
	if not _cursor_visible:
		return
	_cursor_visible = false
	_rt_was_pressed = false  # Reset trigger state
	_lt_was_pressed = false
	_a_was_pressed = false
	# Clean up any active hold state
	if _hold_state == 2:
		_send_synthetic_release(MOUSE_BUTTON_LEFT)
	_hold_state = 0
	_hold_source = ""
	if _virtual_cursor != null:
		_virtual_cursor.visible = false
	# Restore hardware cursor
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("[InputManager] Virtual cursor hidden")


func _send_synthetic_click(button_idx: MouseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button_idx
	press.pressed = true
	press.position = _cursor_position
	press.global_position = _cursor_position
	_warp_frame = Engine.get_process_frames()
	get_viewport().push_input(press)

	# Schedule release after a short delay
	get_tree().create_timer(0.05).timeout.connect(func():
		if not _cursor_visible:
			return  # Don't send release after device switch
		var release := InputEventMouseButton.new()
		release.button_index = button_idx
		release.pressed = false
		release.position = _cursor_position
		release.global_position = _cursor_position
		_warp_frame = Engine.get_process_frames()
		get_viewport().push_input(release)
	)


## Send a synthetic mouse button PRESS only (no scheduled release).
## Used when entering hold state for drag operations.
func _send_synthetic_press(button_idx: MouseButton) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button_idx
	press.pressed = true
	press.position = _cursor_position
	press.global_position = _cursor_position
	_warp_frame = Engine.get_process_frames()
	get_viewport().push_input(press)


## Send a synthetic mouse button RELEASE only.
## Used when exiting hold state after drag operations.
func _send_synthetic_release(button_idx: MouseButton) -> void:
	var release := InputEventMouseButton.new()
	release.button_index = button_idx
	release.pressed = false
	release.position = _cursor_position
	release.global_position = _cursor_position
	_warp_frame = Engine.get_process_frames()
	get_viewport().push_input(release)


## Send a synthetic ui_accept press+release to activate the focused control.
## Used when LT is pressed while a D-pad-focused button exists.
func _send_synthetic_accept() -> void:
	var press := InputEventAction.new()
	press.action = "ui_accept"
	press.pressed = true
	press.strength = 1.0
	get_viewport().push_input(press)
	get_tree().create_timer(0.05).timeout.connect(func():
		var release := InputEventAction.new()
		release.action = "ui_accept"
		release.pressed = false
		release.strength = 0.0
		get_viewport().push_input(release)
	)


func _register_actions() -> void:
	var defs: Array = _get_action_defs()
	var registered_count: int = 0
	for def in defs:
		var action_name: String = def["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		# Keyboard bindings
		var keys: Array = def.get("keys", [])
		for key_code in keys:
			var ev := InputEventKey.new()
			ev.keycode = key_code
			InputMap.action_add_event(action_name, ev)

		# Gamepad button bindings
		var buttons: Array = def.get("buttons", [])
		for btn in buttons:
			var ev := InputEventJoypadButton.new()
			ev.button_index = btn
			InputMap.action_add_event(action_name, ev)

		# Gamepad axis-as-button bindings (triggers)
		var axes: Array = def.get("axes", [])
		for ax in axes:
			var ev := InputEventJoypadMotion.new()
			ev.axis = ax["axis"]
			ev.axis_value = ax["value"]
			InputMap.action_add_event(action_name, ev)

		registered_count += 1

	print("[InputManager] Registered %d custom actions" % registered_count)


## Add gamepad bindings to Godot's built-in ui_* actions so D-pad and A/B work
func _add_gamepad_to_builtin_actions() -> void:
	# ui_accept — A button
	var ev_a := InputEventJoypadButton.new()
	ev_a.button_index = JOY_BUTTON_A
	if not _action_has_joy_button("ui_accept", JOY_BUTTON_A):
		InputMap.action_add_event("ui_accept", ev_a)

	# ui_cancel — B button
	var ev_b := InputEventJoypadButton.new()
	ev_b.button_index = JOY_BUTTON_B
	if not _action_has_joy_button("ui_cancel", JOY_BUTTON_B):
		InputMap.action_add_event("ui_cancel", ev_b)

	# D-pad navigation
	var dpad_map: Dictionary = {
		"ui_up": JOY_BUTTON_DPAD_UP,
		"ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_left": JOY_BUTTON_DPAD_LEFT,
		"ui_right": JOY_BUTTON_DPAD_RIGHT,
	}
	for action_name in dpad_map:
		var btn_idx: int = dpad_map[action_name]
		if not _action_has_joy_button(action_name, btn_idx):
			var ev := InputEventJoypadButton.new()
			ev.button_index = btn_idx
			InputMap.action_add_event(action_name, ev)

	# Strip left stick axis from ui_* so it only triggers zone switching
	_strip_stick_from_ui_actions()


## Remove joypad axis (left stick) events from ui_* directional actions.
## Godot 4 defaults map left stick to ui_up/down/left/right — we want D-pad only.
func _strip_stick_from_ui_actions() -> void:
	for action_name in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		var to_remove: Array = []
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventJoypadMotion:
				to_remove.append(ev)
		for ev in to_remove:
			InputMap.action_erase_event(action_name, ev)


func _action_has_joy_button(action_name: String, btn_idx: int) -> bool:
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton and ev.button_index == btn_idx:
			return true
	return false


# ============================================================================
# DEVICE DETECTION
# ============================================================================

func _input(event: InputEvent) -> void:
	# Skip synthetic mouse events from warp_mouse() and push_input() to avoid device flip-flop
	if (event is InputEventMouseMotion or event is InputEventMouseButton):
		if Engine.get_process_frames() - _warp_frame <= 1:
			return

	# --- Device detection ---
	var new_device: String = active_device
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		new_device = "keyboard"
	elif event is InputEventJoypadButton:
		new_device = "gamepad"
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > STICK_DEADZONE:
			new_device = "gamepad"

	# Handle device switch: show/hide virtual cursor + zone border
	if new_device != active_device:
		if new_device == "gamepad":
			_show_virtual_cursor()
			if _zones.size() > 0:
				_update_zone_border()
		else:
			_hide_virtual_cursor()
			if _zone_border_panel != null and is_instance_valid(_zone_border_panel):
				_zone_border_panel.visible = false
		active_device = new_device
		input_device_changed.emit(active_device)
		print("[InputManager] Device switched to: %s" % active_device)

	# --- Virtual cursor synthetic clicks ---
	if _cursor_visible:
		var focused: Control = get_viewport().gui_get_focus_owner()
		# A button → hold-to-drag or tap-click (skip when D-pad focus active; ui_accept handles it)
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
			if event.pressed and not _a_was_pressed:
				_a_was_pressed = true
				if focused == null and _hold_state == 0:
					_hold_state = 1  # PENDING
					_hold_start_time = Time.get_ticks_msec() / 1000.0
					_hold_source = "a"
					get_viewport().set_input_as_handled()
			elif not event.pressed and _a_was_pressed:
				_a_was_pressed = false
				if _hold_source == "a":
					if _hold_state == 1:
						# Released before threshold → normal tap click
						_hold_state = 0
						_hold_source = ""
						_send_synthetic_click(MOUSE_BUTTON_LEFT)
						get_viewport().set_input_as_handled()
					elif _hold_state == 2:
						# Released after hold → send mouse release (end drag)
						_hold_state = 0
						_hold_source = ""
						_send_synthetic_release(MOUSE_BUTTON_LEFT)
						get_viewport().set_input_as_handled()
		# RT (right trigger) → right click
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			if event.axis_value > RT_PRESS_THRESHOLD and not _rt_was_pressed:
				_rt_was_pressed = true
				_send_synthetic_click(MOUSE_BUTTON_RIGHT)
				get_viewport().set_input_as_handled()
			elif event.axis_value < RT_RELEASE_THRESHOLD:
				_rt_was_pressed = false
		# LT (left trigger) → hold-to-drag or tap-click (or ui_accept when D-pad focus active)
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
			if event.axis_value > LT_PRESS_THRESHOLD and not _lt_was_pressed:
				_lt_was_pressed = true
				if focused != null:
					# D-pad focus active: immediate accept (no hold behavior)
					_send_synthetic_accept()
				elif _hold_state == 0:
					_hold_state = 1  # PENDING
					_hold_start_time = Time.get_ticks_msec() / 1000.0
					_hold_source = "lt"
				get_viewport().set_input_as_handled()
			elif event.axis_value < LT_RELEASE_THRESHOLD and _lt_was_pressed:
				_lt_was_pressed = false
				if _hold_source == "lt":
					if _hold_state == 1:
						# Released before threshold → normal tap click
						_hold_state = 0
						_hold_source = ""
						_send_synthetic_click(MOUSE_BUTTON_LEFT)
					elif _hold_state == 2:
						# Released after hold → send mouse release (end drag)
						_hold_state = 0
						_hold_source = ""
						_send_synthetic_release(MOUSE_BUTTON_LEFT)

	# D-pad focus recovery: if nothing is focused, grab first focusable control
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
								   JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if get_viewport().gui_get_focus_owner() == null:
				_recover_focus()

	# Left stick zone switching (only when zones are registered)
	if _zones.size() > 0 and event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
			if absf(event.axis_value) > ZONE_STICK_THRESHOLD and _zone_stick_cooldown <= 0.0:
				var direction: String = ""
				if event.axis == JOY_AXIS_LEFT_X:
					direction = "right" if event.axis_value > 0 else "left"
				else:
					direction = "down" if event.axis_value > 0 else "up"
				_try_zone_switch(direction)


func _recover_focus() -> void:
	# If zones are registered, focus the active zone's first control
	if _zones.size() > 0 and _active_zone_id != "":
		_focus_zone(_active_zone_id)
		return
	# Fallback: find first focusable in scene tree
	var root: Node = get_tree().current_scene
	if root == null:
		return
	var target: Control = _find_first_focusable(root)
	if target != null:
		target.grab_focus()
		print("[InputManager] Focus recovered on: %s" % target.name)


func _find_first_focusable(node: Node) -> Control:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found: Control = _find_first_focusable(child)
		if found != null:
			return found
	return null


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		print("[InputManager] Controller %d connected: %s" % [device, Input.get_joy_name(device)])
	else:
		print("[InputManager] Controller %d disconnected" % device)


# ============================================================================
# FOCUS ZONE SYSTEM
# ============================================================================

## Register a focus zone. neighbors maps direction strings to zone_ids.
## e.g. register_zone("nav_rail", panel, [btn1, btn2], {"right": "buildings"})
func register_zone(zone_id: String, container: Control, controls: Array, neighbors: Dictionary) -> void:
	_zones[zone_id] = { "controls": controls, "container": container, "neighbors": neighbors }
	if _active_zone_id == "" and controls.size() > 0:
		_active_zone_id = zone_id
	print("[InputManager] Zone registered: %s (%d controls)" % [zone_id, controls.size()])


func unregister_zone(zone_id: String) -> void:
	_zones.erase(zone_id)
	if _active_zone_id == zone_id:
		_active_zone_id = _zones.keys()[0] if _zones.size() > 0 else ""
	_update_zone_border()


func clear_zones() -> void:
	_zones.clear()
	_active_zone_id = ""
	if _zone_border_panel != null and is_instance_valid(_zone_border_panel):
		_zone_border_panel.queue_free()
		_zone_border_panel = null


func set_active_zone(zone_id: String) -> void:
	if not _zones.has(zone_id):
		return
	_active_zone_id = zone_id
	_focus_zone(zone_id)
	_update_zone_border()
	zone_changed.emit(zone_id)


func get_active_zone_id() -> String:
	return _active_zone_id


func update_zone_neighbors(zone_id: String, neighbors: Dictionary) -> void:
	if _zones.has(zone_id):
		_zones[zone_id]["neighbors"] = neighbors


func set_zone_border_color(color: Color) -> void:
	_zone_border_color = color
	_update_zone_border()


func _try_zone_switch(direction: String) -> void:
	if _active_zone_id == "" or not _zones.has(_active_zone_id):
		return
	var neighbors: Dictionary = _zones[_active_zone_id].get("neighbors", {})
	var target_zone: String = neighbors.get(direction, "")
	if target_zone == "" or not _zones.has(target_zone):
		return
	_zone_stick_cooldown = ZONE_STICK_COOLDOWN
	_active_zone_id = target_zone
	_focus_zone(target_zone)
	_update_zone_border()
	zone_changed.emit(target_zone)
	print("[InputManager] Zone switched: %s → %s" % [direction, target_zone])


func _focus_zone(zone_id: String) -> void:
	if not _zones.has(zone_id):
		return
	var controls: Array = _zones[zone_id].get("controls", [])
	for c in controls:
		if c is Control and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
			c.grab_focus()
			call_deferred("_ensure_focused_visible")
			return


## Recursively collect all focusable controls under a node. Shared utility for zone registration.
func collect_focusable(node: Node) -> Array:
	var result: Array = []
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		result.append(node)
	for child in node.get_children():
		result.append_array(collect_focusable(child))
	return result


## Returns the index of the currently focused control within a zone's controls array.
## Returns -1 if nothing is focused or the focused control is not in the zone.
func get_focused_index_in_zone(zone_id: String) -> int:
	if not _zones.has(zone_id):
		return -1
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		return -1
	var controls: Array = _zones[zone_id].get("controls", [])
	for i in range(controls.size()):
		if controls[i] == focused:
			return i
	return -1


## Focus a specific index in a zone's controls array.
## If index is past the end, scans forward then backward for the nearest focusable control.
func focus_zone_at_index(zone_id: String, index: int) -> void:
	if not _zones.has(zone_id):
		return
	var controls: Array = _zones[zone_id].get("controls", [])
	if controls.is_empty():
		return
	if index < 0:
		index = 0
	# Try at/after index (next available below)
	for i in range(index, controls.size()):
		var c = controls[i]
		if c is Control and is_instance_valid(c) and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
			c.grab_focus()
			call_deferred("_ensure_focused_visible")
			return
	# Scan backward (last available above)
	for i in range(mini(index, controls.size()) - 1, -1, -1):
		var c = controls[i]
		if c is Control and is_instance_valid(c) and c.focus_mode != Control.FOCUS_NONE and c.is_visible_in_tree():
			c.grab_focus()
			call_deferred("_ensure_focused_visible")
			return


## Like set_active_zone() but restores focus to a specific index instead of first control.
func set_active_zone_at_index(zone_id: String, index: int) -> void:
	if not _zones.has(zone_id):
		return
	_active_zone_id = zone_id
	focus_zone_at_index(zone_id, index)
	_update_zone_border()
	zone_changed.emit(zone_id)


func _update_zone_border() -> void:
	# Remove old border
	if _zone_border_panel != null and is_instance_valid(_zone_border_panel):
		_zone_border_panel.queue_free()
		_zone_border_panel = null

	if _active_zone_id == "" or not _zones.has(_active_zone_id):
		return
	if active_device != "gamepad":
		return

	var container: Control = _zones[_active_zone_id].get("container")
	if container == null or not is_instance_valid(container):
		return

	# Create border canvas if needed
	if _zone_border_canvas == null:
		_zone_border_canvas = CanvasLayer.new()
		_zone_border_canvas.layer = 5  # Above game content, below popups (layer 10)
		add_child(_zone_border_canvas)
	# Facility panels render on CanvasLayer 10 — border must be above them
	_zone_border_canvas.layer = 11 if _active_zone_id.begins_with("facility") else 5

	var border := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # Transparent fill
	style.border_color = _zone_border_color
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	border.add_theme_stylebox_override("panel", style)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Match container's global rect
	var rect: Rect2 = container.get_global_rect()
	border.position = rect.position
	border.size = rect.size

	_zone_border_canvas.add_child(border)
	_zone_border_panel = border


## Wire focus_neighbor_* properties for a 2D grid of controls.
## grid: Array of rows, each row an Array of Controls (null entries skipped).
## bottom_controls: optional Array of Controls below the grid.
## Handles LEFT/RIGHT within a row and UP/DOWN between rows (same column).
static func wire_focus_grid(grid: Array, bottom_controls: Array = []) -> void:
	for r in range(grid.size()):
		var row: Array = grid[r]
		for c in range(row.size()):
			var ctrl = row[c]
			if ctrl == null or not is_instance_valid(ctrl):
				continue
			# LEFT neighbor: previous non-null in same row
			for lc in range(c - 1, -1, -1):
				if row[lc] != null and is_instance_valid(row[lc]):
					ctrl.focus_neighbor_left = ctrl.get_path_to(row[lc])
					break
			# RIGHT neighbor: next non-null in same row
			for rc in range(c + 1, row.size()):
				if row[rc] != null and is_instance_valid(row[rc]):
					ctrl.focus_neighbor_right = ctrl.get_path_to(row[rc])
					break
			# UP neighbor: same column in previous row
			for ur in range(r - 1, -1, -1):
				if c < grid[ur].size() and grid[ur][c] != null and is_instance_valid(grid[ur][c]):
					ctrl.focus_neighbor_top = ctrl.get_path_to(grid[ur][c])
					break
			# DOWN neighbor: same column in next row
			for dr in range(r + 1, grid.size()):
				if c < grid[dr].size() and grid[dr][c] != null and is_instance_valid(grid[dr][c]):
					ctrl.focus_neighbor_bottom = ctrl.get_path_to(grid[dr][c])
					break
	# Wire bottom_controls to last grid row
	if bottom_controls.is_empty() or grid.is_empty():
		return
	var last_row: Array = grid[grid.size() - 1]
	# Bottom controls get UP → first non-null in last row
	for bc in bottom_controls:
		if bc == null or not is_instance_valid(bc):
			continue
		for lrc in range(last_row.size()):
			if last_row[lrc] != null and is_instance_valid(last_row[lrc]):
				bc.focus_neighbor_top = bc.get_path_to(last_row[lrc])
				break
	# Last row controls get DOWN → first non-null bottom control
	for lrc in range(last_row.size()):
		var ctrl = last_row[lrc]
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		for bc in bottom_controls:
			if bc != null and is_instance_valid(bc):
				ctrl.focus_neighbor_bottom = ctrl.get_path_to(bc)
				break


# ============================================================================
# GLYPH LOOKUP
# ============================================================================

## Returns the display string for an action based on active device.
## e.g. get_glyph("combat_action_1") → "1" (keyboard) or "X" (gamepad)
func get_glyph(action_name: String) -> String:
	if active_device == "gamepad":
		return _GAMEPAD_GLYPHS.get(action_name, "?")
	return _KEYBOARD_GLYPHS.get(action_name, "?")


## Returns true if a gamepad is currently connected
func is_gamepad_connected() -> bool:
	return Input.get_connected_joypads().size() > 0


# ============================================================================
# TOOLTIP INFO PANEL (Y button on focused element)
# ============================================================================

var _tooltip_panel: PanelContainer = null

func _unhandled_input(event: InputEvent) -> void:
	# F9 → manual screenshot capture (PlaytestCapture)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		var capture = get_node_or_null("/root/PlaytestCapture")
		if capture:
			capture.manual_capture()
		get_viewport().set_input_as_handled()
		return

	# Y button / I key → show tooltip for focused element
	if event.is_action_pressed("gp_inspect"):
		_toggle_tooltip_panel()
		get_viewport().set_input_as_handled()

	# After D-pad focus navigation, scroll to keep focused item visible
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		call_deferred("_ensure_focused_visible")


## Scroll parent ScrollContainer to keep focused control visible after D-pad navigation.
func _ensure_focused_visible() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		return
	var node: Node = focused.get_parent()
	while node != null:
		if node is ScrollContainer:
			node.ensure_control_visible(focused)
			return
		node = node.get_parent()


func _toggle_tooltip_panel() -> void:
	# If tooltip panel is visible, close it
	if _tooltip_panel != null and is_instance_valid(_tooltip_panel):
		_tooltip_panel.queue_free()
		_tooltip_panel = null
		return

	# Find focused control and its tooltip
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null or focused.tooltip_text.strip_edges() == "":
		return

	# Create tooltip popup
	var canvas := CanvasLayer.new()
	canvas.layer = 15

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(200, 0)
	# Max width
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)

	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(280, 0)
	label.text = focused.tooltip_text

	margin.add_child(label)
	panel.add_child(margin)

	# Position near the focused element
	var focus_rect = focused.get_global_rect()
	var vp_size = get_viewport().get_visible_rect().size
	# Place above the focused element, centered
	var panel_x = clampf(focus_rect.position.x + focus_rect.size.x / 2.0 - 150, 8, vp_size.x - 308)
	var panel_y = focus_rect.position.y - 10
	if panel_y < 40:
		panel_y = focus_rect.end.y + 10  # Place below if no room above

	panel.position = Vector2(panel_x, panel_y)
	# Override to place at specific position
	panel.anchors_preset = Control.PRESET_TOP_LEFT
	panel.position = Vector2(panel_x, panel_y)

	canvas.add_child(panel)
	add_child(canvas)
	_tooltip_panel = panel

	# Auto-dismiss after 4 seconds or on any input
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func():
		if _tooltip_panel != null and is_instance_valid(_tooltip_panel):
			var parent_canvas = _tooltip_panel.get_parent()
			if parent_canvas != null:
				parent_canvas.queue_free()
			_tooltip_panel = null
	)
