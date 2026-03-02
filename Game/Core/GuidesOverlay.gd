class_name GuidesOverlay
extends RefCounted
## Tabbed guides overlay: Tutorials, Items, Monsters, Heroes (Races/Classes).
## Usage: var overlay = GuidesOverlay.show(self)
##        if overlay != null: await overlay.guides_closed


static func show(caller: Node) -> Node:
	var panel := _GuidesPanel.new()
	caller.add_child(panel)
	return panel


# ============================================================================
# INNER CLASS
# ============================================================================

class _GuidesPanel extends CanvasLayer:
	signal guides_closed

	enum Tab { TUTORIALS, ITEMS, MONSTERS, HEROES, CONTROLS }

	# --- Colors (matches Quest Log palette) ---
	const BG_COLOR := Color(0.08, 0.06, 0.12, 0.97)
	const BORDER_COLOR := Color(0.6, 0.5, 0.3, 0.9)
	const HEADER_COLOR := Color(1.0, 0.85, 0.5, 1.0)
	const SECTION_COLOR := Color(0.7, 0.85, 1.0, 1.0)
	const BODY_COLOR := Color(0.85, 0.85, 0.85, 1.0)
	const DIM_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
	const SEP_COLOR := Color(0.4, 0.35, 0.25, 0.6)

	# Tab highlight
	const TAB_ACTIVE_COLOR := Color(1.0, 0.85, 0.5, 1.0)
	const TAB_INACTIVE_COLOR := Color(0.55, 0.55, 0.55, 1.0)

	# Tier colors
	const TIER_COLORS: Dictionary = {
		1: Color(0.6, 0.6, 0.6, 1.0),
		2: Color(0.5, 0.9, 0.5, 1.0),
		3: Color(0.4, 0.6, 1.0, 1.0),
		4: Color(0.75, 0.4, 0.9, 1.0),
	}

	# Resize constants
	const DEFAULT_WIDTH := 580.0
	const DEFAULT_HEIGHT := 480.0
	const MIN_WIDTH := 400.0
	const MIN_HEIGHT := 300.0
	const MAX_WIDTH := 900.0
	const MAX_HEIGHT := 520.0
	const RESIZE_MARGIN := 12

	# Tutorial categories
	const TUTORIAL_CATEGORIES: Array = [
		{
			"label": "Getting Started",
			"ids": ["tutorial_welcome", "tutorial_first_dungeon", "tutorial_first_combat",
					"tutorial_first_camp", "tutorial_first_event", "tutorial_first_extraction"]
		},
		{
			"label": "Town & Facilities",
			"ids": ["tutorial_facilities_overview", "tutorial_storage",
					"tutorial_equipment_facilities", "tutorial_training_hall",
					"tutorial_shop", "tutorial_production"]
		},
		{
			"label": "Party Management",
			"ids": ["tutorial_manage_roster", "tutorial_party_bar"]
		},
		{
			"label": "Combat",
			"ids": ["tutorial_abilities", "tutorial_flee"]
		},
		{
			"label": "Progression",
			"ids": ["tutorial_region_progression", "tutorial_side_quests", "tutorial_ng_plus"]
		},
	]

	# State
	var _root: Control
	var _panel: PanelContainer
	var _tab_bar: HBoxContainer
	var _sub_tab_bar: HBoxContainer
	var _content_vbox: VBoxContainer
	var _scroll: ScrollContainer
	var _current_tab: int = Tab.TUTORIALS
	var _current_sub: int = 0
	var _tab_buttons: Array = []
	var _sub_tab_buttons: Array = []

	# Resize + drag state
	var _is_resizing: bool = false
	var _resize_edge: int = 0
	var _resize_start_mouse: Vector2 = Vector2.ZERO
	var _resize_start_size: Vector2 = Vector2.ZERO
	var _resize_start_panel_pos: Vector2 = Vector2.ZERO
	var _is_dragging: bool = false
	var _drag_offset: Vector2 = Vector2.ZERO


	func _ready() -> void:
		layer = 10
		_build_shell()
		_switch_tab(Tab.TUTORIALS)
		# Fade in
		_root.modulate.a = 0.0
		create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
		UIAudio.register_closeable(self, _close)


	func _build_shell() -> void:
		# Root control (full rect, blocks input)
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_root)

		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.color = BACKDROP_COLOR
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if not _is_resizing and not _is_dragging:
					_close()
		)
		_root.add_child(backdrop)

		# Panel — manually positioned and resizable
		_panel = PanelContainer.new()
		_panel.add_theme_stylebox_override("panel", _create_panel_style())
		_panel.custom_minimum_size = Vector2(DEFAULT_WIDTH, DEFAULT_HEIGHT)
		_panel.size = Vector2(DEFAULT_WIDTH, DEFAULT_HEIGHT)
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(_panel)
		_center_panel()

		# Margin
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		_panel.add_child(margin)

		# Main VBox
		var main_vbox := VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 4)
		margin.add_child(main_vbox)

		# Header row: "Guides" title + close button
		var header_row := HBoxContainer.new()
		main_vbox.add_child(header_row)

		var title_lbl := Label.new()
		title_lbl.text = "Guides"
		title_lbl.add_theme_font_size_override("font_size", GameContext.fs(20))
		title_lbl.add_theme_color_override("font_color", HEADER_COLOR)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(title_lbl)

		var close_btn := Button.new()
		close_btn.text = "X"
		close_btn.add_theme_font_size_override("font_size", GameContext.fs(15))
		close_btn.custom_minimum_size = Vector2(32, 32)
		close_btn.focus_mode = Control.FOCUS_ALL
		close_btn.pressed.connect(_close)
		header_row.add_child(close_btn)

		# Tab bar
		_tab_bar = HBoxContainer.new()
		_tab_bar.add_theme_constant_override("separation", 4)
		main_vbox.add_child(_tab_bar)

		var tab_names: Array = ["Tutorials", "Items", "Monsters", "Heroes", "Controls"]
		for i in tab_names.size():
			var btn := Button.new()
			btn.text = tab_names[i]
			btn.add_theme_font_size_override("font_size", GameContext.fs(14))
			btn.custom_minimum_size = Vector2(85, 30)
			btn.focus_mode = Control.FOCUS_ALL
			var tab_idx: int = i
			btn.pressed.connect(func(): _switch_tab(tab_idx))
			_tab_bar.add_child(btn)
			_tab_buttons.append(btn)

		# Sub-tab bar (dynamic, hidden when not needed)
		_sub_tab_bar = HBoxContainer.new()
		_sub_tab_bar.add_theme_constant_override("separation", 4)
		main_vbox.add_child(_sub_tab_bar)

		# Separator
		var sep := HSeparator.new()
		sep.modulate = Color(0.55, 0.4, 0.25, 0.6)
		main_vbox.add_child(sep)

		# Scroll container — fills remaining space
		_scroll = ScrollContainer.new()
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_vbox.add_child(_scroll)

		# Content VBox inside scroll
		_content_vbox = VBoxContainer.new()
		_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_vbox.add_theme_constant_override("separation", 2)
		_scroll.add_child(_content_vbox)

		# Resize grip indicator (bottom-right)
		var grip_row := HBoxContainer.new()
		grip_row.alignment = BoxContainer.ALIGNMENT_END
		main_vbox.add_child(grip_row)
		var grip_lbl := Label.new()
		grip_lbl.text = "⋱"
		grip_lbl.add_theme_font_size_override("font_size", GameContext.fs(10))
		grip_lbl.add_theme_color_override("font_color", DIM_COLOR)
		grip_lbl.tooltip_text = "Drag corner to resize"
		grip_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		grip_row.add_child(grip_lbl)


	# ========================================================================
	# RESIZE + DRAG SYSTEM
	# ========================================================================

	const TITLE_BAR_HEIGHT := 48.0

	func _center_panel() -> void:
		if not is_instance_valid(_panel) or not is_instance_valid(_root):
			return
		var vp: Vector2 = _root.get_viewport_rect().size
		_panel.position = (vp - _panel.size) / 2.0


	## Detect which edge(s) the mouse is near. Returns bitmask: 1=left, 2=right, 4=top, 8=bottom.
	func _detect_resize_edge(local_pos: Vector2) -> int:
		var edge: int = 0
		if local_pos.x < RESIZE_MARGIN:
			edge |= 1
		elif local_pos.x > _panel.size.x - RESIZE_MARGIN:
			edge |= 2
		if local_pos.y < RESIZE_MARGIN:
			edge |= 4
		elif local_pos.y > _panel.size.y - RESIZE_MARGIN:
			edge |= 8
		return edge


	## Map edge bitmask to cursor shape.
	func _cursor_for_edge(edge: int) -> Control.CursorShape:
		match edge:
			5:  # top+left
				return Control.CURSOR_FDIAGSIZE
			10: # bottom+right
				return Control.CURSOR_FDIAGSIZE
			6:  # top+right
				return Control.CURSOR_BDIAGSIZE
			9:  # bottom+left
				return Control.CURSOR_BDIAGSIZE
			1, 2: # left or right
				return Control.CURSOR_HSIZE
			4, 8: # top or bottom
				return Control.CURSOR_VSIZE
			_:
				return Control.CURSOR_ARROW


	func _input(event: InputEvent) -> void:
		if not is_instance_valid(_panel):
			return

		# Handle ongoing resize
		if _is_resizing:
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_is_resizing = false
				_resize_edge = 0
				_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
				get_viewport().set_input_as_handled()
			elif event is InputEventMouseMotion:
				_handle_resize_motion(event.global_position)
				get_viewport().set_input_as_handled()
			return

		# Handle ongoing drag
		if _is_dragging:
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_is_dragging = false
				_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
				get_viewport().set_input_as_handled()
			elif event is InputEventMouseMotion:
				_panel.position = event.global_position + _drag_offset
				get_viewport().set_input_as_handled()
			return

		var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
		var mouse: Vector2 = event.global_position if "global_position" in event else Vector2.ZERO

		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if panel_rect.has_point(mouse):
				var local: Vector2 = mouse - _panel.global_position
				var edge: int = _detect_resize_edge(local)
				if edge != 0:
					# Start resize
					_is_resizing = true
					_resize_edge = edge
					_resize_start_mouse = mouse
					_resize_start_size = _panel.size
					_resize_start_panel_pos = _panel.position
					get_viewport().set_input_as_handled()
				elif local.y < TITLE_BAR_HEIGHT:
					# Start drag from title bar
					_is_dragging = true
					_drag_offset = _panel.position - mouse
					_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
					get_viewport().set_input_as_handled()

		elif event is InputEventMouseMotion:
			# Hover cursor feedback
			if panel_rect.has_point(mouse):
				var local: Vector2 = mouse - _panel.global_position
				var edge: int = _detect_resize_edge(local)
				if edge != 0:
					_panel.mouse_default_cursor_shape = _cursor_for_edge(edge)
				elif local.y < TITLE_BAR_HEIGHT:
					_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
				else:
					_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
			else:
				_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW


	func _handle_resize_motion(global_pos: Vector2) -> void:
		var delta: Vector2 = global_pos - _resize_start_mouse
		var new_pos: Vector2 = _resize_start_panel_pos
		var new_size: Vector2 = _resize_start_size

		# Right edge
		if _resize_edge & 2:
			new_size.x = clampf(_resize_start_size.x + delta.x, MIN_WIDTH, MAX_WIDTH)
		# Left edge
		if _resize_edge & 1:
			var dx: float = clampf(delta.x, _resize_start_size.x - MAX_WIDTH, _resize_start_size.x - MIN_WIDTH)
			new_size.x = _resize_start_size.x - dx
			new_pos.x = _resize_start_panel_pos.x + dx
		# Bottom edge
		if _resize_edge & 8:
			new_size.y = clampf(_resize_start_size.y + delta.y, MIN_HEIGHT, MAX_HEIGHT)
		# Top edge
		if _resize_edge & 4:
			var dy: float = clampf(delta.y, _resize_start_size.y - MAX_HEIGHT, _resize_start_size.y - MIN_HEIGHT)
			new_size.y = _resize_start_size.y - dy
			new_pos.y = _resize_start_panel_pos.y + dy

		_panel.custom_minimum_size = new_size
		_panel.size = new_size
		_panel.position = new_pos


	# ========================================================================
	# TAB SWITCHING
	# ========================================================================

	func _switch_tab(tab: int) -> void:
		_current_tab = tab
		_current_sub = 0
		_update_tab_highlights()
		_rebuild_sub_tabs()
		_rebuild_content()


	func _switch_sub_tab(sub: int) -> void:
		_current_sub = sub
		_update_sub_tab_highlights()
		_rebuild_content()


	func _update_tab_highlights() -> void:
		for i in _tab_buttons.size():
			_tab_buttons[i].modulate = TAB_ACTIVE_COLOR if i == _current_tab else TAB_INACTIVE_COLOR


	func _update_sub_tab_highlights() -> void:
		for i in _sub_tab_buttons.size():
			_sub_tab_buttons[i].modulate = TAB_ACTIVE_COLOR if i == _current_sub else TAB_INACTIVE_COLOR


	func _rebuild_sub_tabs() -> void:
		# Clear existing sub-tabs
		for child in _sub_tab_bar.get_children():
			child.queue_free()
		_sub_tab_buttons.clear()

		match _current_tab:
			Tab.TUTORIALS, Tab.CONTROLS:
				_sub_tab_bar.visible = false
			Tab.ITEMS, Tab.MONSTERS:
				_sub_tab_bar.visible = true
				for i in 7:
					var btn := Button.new()
					btn.text = "R%d" % (i + 1)
					btn.add_theme_font_size_override("font_size", GameContext.fs(13))
					btn.custom_minimum_size = Vector2(46, 28)
					btn.focus_mode = Control.FOCUS_ALL
					var sub_idx: int = i
					btn.pressed.connect(func(): _switch_sub_tab(sub_idx))
					_sub_tab_bar.add_child(btn)
					_sub_tab_buttons.append(btn)
			Tab.HEROES:
				_sub_tab_bar.visible = true
				var race_btn := Button.new()
				race_btn.text = "Races"
				race_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
				race_btn.custom_minimum_size = Vector2(75, 28)
				race_btn.focus_mode = Control.FOCUS_ALL
				race_btn.pressed.connect(func(): _switch_sub_tab(0))
				_sub_tab_bar.add_child(race_btn)
				_sub_tab_buttons.append(race_btn)

				var class_btn := Button.new()
				class_btn.text = "Classes"
				class_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
				class_btn.custom_minimum_size = Vector2(75, 28)
				class_btn.focus_mode = Control.FOCUS_ALL
				class_btn.pressed.connect(func(): _switch_sub_tab(1))
				_sub_tab_bar.add_child(class_btn)
				_sub_tab_buttons.append(class_btn)

		_update_sub_tab_highlights()


	func _rebuild_content() -> void:
		_clear_content()
		match _current_tab:
			Tab.TUTORIALS:
				_build_tutorials_tab()
			Tab.ITEMS:
				_build_items_tab(_current_sub + 1)
			Tab.MONSTERS:
				_build_monsters_tab(_current_sub + 1)
			Tab.HEROES:
				if _current_sub == 0:
					_build_races_tab()
				else:
					_build_classes_tab()
			Tab.CONTROLS:
				_build_controls_tab()
		_scroll.scroll_vertical = 0
		_focus_first_button()


	func _clear_content() -> void:
		for child in _content_vbox.get_children():
			child.queue_free()


	func _focus_first_button() -> void:
		call_deferred("_do_focus_first_button")


	func _do_focus_first_button() -> void:
		var btn: Button = _find_first_button(_content_vbox)
		if btn != null:
			btn.grab_focus()
		elif _tab_buttons.size() > 0:
			_tab_buttons[0].grab_focus()


	func _find_first_button(node: Node) -> Button:
		if node is Button and node.focus_mode != Control.FOCUS_NONE and node.visible:
			return node
		for child in node.get_children():
			var found: Button = _find_first_button(child)
			if found != null:
				return found
		return null


	# ========================================================================
	# TAB 1: TUTORIALS
	# ========================================================================

	func _build_tutorials_tab() -> void:
		_add_column_header_row([
			{"text": "", "min_w": 28, "sep": 6},
			{"text": "Tutorial", "expand": true},
		])
		for cat in TUTORIAL_CATEGORIES:
			_add_section_header(cat.label)
			for tutorial_id in cat.ids:
				_add_tutorial_row(tutorial_id)


	func _add_tutorial_row(tutorial_id: String) -> void:
		# Load JSON for title
		var title_text: String = tutorial_id.replace("tutorial_", "").replace("_", " ").capitalize()
		var path: String = "res://Data/Tutorials/%s.json" % tutorial_id
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data: Dictionary = json.data
					if data.has("steps") and data.steps is Array and not data.steps.is_empty():
						var first_step: Dictionary = data.steps[0]
						if first_step.has("title"):
							title_text = first_step.title
				file.close()

		var is_complete: bool = GameContext.has_completed_tutorial(tutorial_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_content_vbox.add_child(row)

		# Completion status
		var status_lbl := Label.new()
		if is_complete:
			status_lbl.text = "[Y]"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
		else:
			status_lbl.text = "[ ]"
			status_lbl.add_theme_color_override("font_color", DIM_COLOR)
		status_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		row.add_child(status_lbl)

		# Replay button
		var replay_btn := Button.new()
		replay_btn.text = title_text
		replay_btn.add_theme_font_size_override("font_size", GameContext.fs(13))
		replay_btn.flat = true
		replay_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		replay_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		replay_btn.focus_mode = Control.FOCUS_ALL
		replay_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		var tid: String = tutorial_id
		replay_btn.pressed.connect(func(): _replay_tutorial(tid))
		row.add_child(replay_btn)


	func _replay_tutorial(tutorial_id: String) -> void:
		GameContext.completed_tutorials.erase(tutorial_id)
		var overlay: Node = TutorialOverlay.try_show(self, tutorial_id)
		if overlay != null:
			await overlay.tutorial_finished
		if is_instance_valid(self):
			_rebuild_content()


	# ========================================================================
	# TAB 2: ITEMS
	# ========================================================================

	func _build_items_tab(region_num: int) -> void:
		var region_tag: String = "region_%d" % region_num
		var all_templates: Array = DataRegistry.get_all_item_templates()

		var filtered: Array = []
		for tmpl in all_templates:
			if region_tag in tmpl.tags:
				filtered.append(tmpl)

		if filtered.is_empty():
			_add_empty_label("No items found for Region %d" % region_num)
			return

		filtered.sort_custom(func(a, b):
			if a.tier != b.tier:
				return a.tier < b.tier
			if a.item_type != b.item_type:
				var order: Dictionary = {"equipment": 0, "consumable": 1, "material": 2}
				return order.get(a.item_type, 9) < order.get(b.item_type, 9)
			return a.display_name < b.display_name
		)

		_add_column_header_row([
			{"text": "", "min_w": 20},
			{"text": "Name", "expand": true},
			{"text": "Type", "min_w": 80},
			{"text": "Tier", "min_w": 28},
			{"text": "Stats", "min_w": 120},
		])

		var current_tier: int = -1
		var current_type: String = ""
		for tmpl in filtered:
			if tmpl.tier != current_tier:
				current_tier = tmpl.tier
				current_type = ""
				_add_section_header("Tier %d" % current_tier)

			var type_label: String = tmpl.item_type.capitalize()
			if type_label != current_type:
				current_type = type_label
				_add_sub_header(current_type)

			_add_item_row(tmpl)


	func _add_item_row(tmpl) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_content_vbox.add_child(row)

		# Icon
		if tmpl.has_method("create_icon_rect"):
			var icon: TextureRect = tmpl.create_icon_rect(16)
			if icon != null:
				row.add_child(icon)

		row.add_child(_col_sep())

		# Name
		var name_lbl := Label.new()
		name_lbl.text = tmpl.display_name
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		name_lbl.add_theme_color_override("font_color", BODY_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row.add_child(name_lbl)

		row.add_child(_col_sep())

		# Subtype
		var subtype_text: String = ""
		if "item_subtype" in tmpl and tmpl.item_subtype != "":
			subtype_text = tmpl.item_subtype.capitalize()
		elif "item_type" in tmpl:
			subtype_text = tmpl.item_type.capitalize()
		var sub_lbl := Label.new()
		sub_lbl.text = subtype_text
		sub_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		sub_lbl.add_theme_color_override("font_color", DIM_COLOR)
		sub_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(sub_lbl)

		row.add_child(_col_sep())

		# Tier badge
		var tier_lbl := Label.new()
		tier_lbl.text = "T%d" % tmpl.tier
		tier_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		tier_lbl.add_theme_color_override("font_color", _tier_color(tmpl.tier))
		tier_lbl.custom_minimum_size = Vector2(28, 0)
		row.add_child(tier_lbl)

		row.add_child(_col_sep())

		# Stats summary
		var stats_text: String = _format_item_stats(tmpl)
		var stats_lbl := Label.new()
		stats_lbl.text = stats_text
		stats_lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
		stats_lbl.add_theme_color_override("font_color", DIM_COLOR)
		stats_lbl.custom_minimum_size = Vector2(120, 0)
		stats_lbl.clip_text = true
		row.add_child(stats_lbl)

		# Row separator
		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		_content_vbox.add_child(sep)


	# ========================================================================
	# TAB 3: MONSTERS
	# ========================================================================

	func _build_monsters_tab(region_num: int) -> void:
		var region_id: String = "region_%d" % region_num
		var all_monsters: Array = DataRegistry.get_all_monsters()

		var filtered: Array = []
		for mon in all_monsters:
			if mon.region_id == region_id:
				filtered.append(mon)

		if filtered.is_empty():
			_add_empty_label("No monsters found for Region %d" % region_num)
			return

		_add_column_header_row([
			{"text": "Name", "expand": true},
			{"text": "Family", "min_w": 70},
			{"text": "Role", "min_w": 55},
		])

		var normal: Array = []
		var bosses: Array = []
		for mon in filtered:
			if mon.is_boss:
				bosses.append(mon)
			else:
				normal.append(mon)

		normal.sort_custom(func(a, b):
			if a.tier != b.tier:
				return a.tier < b.tier
			return a.display_name < b.display_name
		)

		var current_tier: int = -1
		for mon in normal:
			if mon.tier != current_tier:
				current_tier = mon.tier
				_add_section_header("Tier %d" % current_tier)
			_add_monster_row(mon)

		if not bosses.is_empty():
			_add_section_header("Bosses")
			bosses.sort_custom(func(a, b): return a.display_name < b.display_name)
			for mon in bosses:
				_add_monster_row(mon)


	func _add_monster_row(mon) -> void:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 1)
		_content_vbox.add_child(block)

		# Row 1: Name + badges + family + role (with column separators)
		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 4)
		block.add_child(row1)

		var name_lbl := Label.new()
		name_lbl.text = mon.display_name
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		name_lbl.add_theme_color_override("font_color", BODY_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true
		row1.add_child(name_lbl)

		if mon.is_boss:
			row1.add_child(_badge_label("[Boss]", Color(1.0, 0.4, 0.4)))
		elif mon.is_elite:
			row1.add_child(_badge_label("[Elite]", Color(1.0, 0.7, 0.3)))

		row1.add_child(_col_sep())

		if mon.family != "":
			var family_lbl := Label.new()
			family_lbl.text = mon.family.capitalize()
			family_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			family_lbl.add_theme_color_override("font_color", DIM_COLOR)
			family_lbl.custom_minimum_size = Vector2(70, 0)
			row1.add_child(family_lbl)

		row1.add_child(_col_sep())

		var role_lbl := Label.new()
		role_lbl.text = mon.combat_role.capitalize()
		role_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		role_lbl.add_theme_color_override("font_color", DIM_COLOR)
		role_lbl.custom_minimum_size = Vector2(55, 0)
		row1.add_child(role_lbl)

		# Row 2: Stats + AI (with column separator)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 4)
		block.add_child(row2)

		var stats: Dictionary = mon.base_stats if mon.base_stats is Dictionary else {}
		var stat_parts: Array = []
		for key in ["health", "attack", "defense", "speed"]:
			if stats.has(key) and stats[key] != 0:
				var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
				stat_parts.append("%s:%d" % [abbrev, stats[key]])

		for key in ["crit_chance", "evasion", "resist", "thorns", "armor_penetration", "life_steal"]:
			if stats.has(key) and stats[key] != 0:
				var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
				stat_parts.append("%s:%d" % [abbrev, stats[key]])

		var stats_lbl := Label.new()
		stats_lbl.text = " ".join(stat_parts)
		stats_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		stats_lbl.add_theme_color_override("font_color", DIM_COLOR)
		stats_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(stats_lbl)

		row2.add_child(_col_sep())

		var ai_names: Array = ["Feral", "Basic", "Tactical", "Strategic"]
		var ai_text: String = ai_names[mon.ai_tier] if mon.ai_tier < ai_names.size() else "Unknown"
		var ai_lbl := Label.new()
		ai_lbl.text = "AI: %s" % ai_text
		ai_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		ai_lbl.add_theme_color_override("font_color", DIM_COLOR)
		ai_lbl.custom_minimum_size = Vector2(80, 0)
		row2.add_child(ai_lbl)

		# Row 3: Abilities (if any)
		var ability_names: Array = []
		for aid in mon.ability_ids:
			if aid == "basic_attack":
				continue
			var ability = DataRegistry.get_ability(aid)
			if ability != null:
				ability_names.append(ability.display_name)
		if not ability_names.is_empty():
			var ab_lbl := Label.new()
			ab_lbl.text = "Abilities: %s" % ", ".join(ability_names)
			ab_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			ab_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
			ab_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			block.add_child(ab_lbl)

		# Row separator
		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		block.add_child(sep)


	# ========================================================================
	# TAB 4: HEROES — RACES
	# ========================================================================

	func _build_races_tab() -> void:
		var all_races: Array = DataRegistry.get_all_races()
		if all_races.is_empty():
			_add_empty_label("No races found")
			return

		all_races.sort_custom(func(a, b): return a.unlock_region < b.unlock_region)

		_add_column_header_row([
			{"text": "", "min_w": 32, "sep": 8},
			{"text": "Race"},
			{"text": "Unlock"},
			{"text": "XP Mod"},
		])

		for race in all_races:
			_add_race_entry(race)


	func _add_race_entry(race) -> void:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 1)
		_content_vbox.add_child(block)

		# Row 1: Portrait + name + unlock region + XP modifier
		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 8)
		block.add_child(row1)

		if race.portrait_path != "" and ResourceLoader.exists(race.portrait_path):
			var tex := ResourceLoader.load(race.portrait_path) as Texture2D
			if tex != null:
				var portrait := TextureRect.new()
				portrait.texture = tex
				portrait.custom_minimum_size = Vector2(32, 32)
				portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row1.add_child(portrait)

		var name_lbl := Label.new()
		name_lbl.text = race.display_name
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		name_lbl.add_theme_color_override("font_color", HEADER_COLOR)
		row1.add_child(name_lbl)

		row1.add_child(_col_sep())

		var unlock_lbl := Label.new()
		unlock_lbl.text = "Unlocks: R%d" % race.unlock_region
		unlock_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		unlock_lbl.add_theme_color_override("font_color", DIM_COLOR)
		row1.add_child(unlock_lbl)

		if race.xp_modifier != 1.0:
			row1.add_child(_col_sep())
			var xp_lbl := Label.new()
			xp_lbl.text = "XP: x%.1f" % race.xp_modifier
			xp_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			xp_lbl.add_theme_color_override("font_color", DIM_COLOR)
			row1.add_child(xp_lbl)

		# Row 2: Stat modifiers
		var stat_mods: Dictionary = race.stat_modifiers if race.stat_modifiers is Dictionary else {}
		if not stat_mods.is_empty():
			var mod_parts: Array = []
			for key in stat_mods:
				var val: int = stat_mods[key]
				if val != 0:
					var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
					var sign_str: String = "+" if val > 0 else ""
					mod_parts.append("%s%s%d" % [abbrev, sign_str, val])
			if not mod_parts.is_empty():
				var mods_lbl := Label.new()
				mods_lbl.text = "Stats: %s" % ", ".join(mod_parts)
				mods_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
				mods_lbl.add_theme_color_override("font_color", BODY_COLOR)
				block.add_child(mods_lbl)

		# Row 3: Racial passive
		if race.racial_passive_id != "":
			var passive = DataRegistry.get_passive(race.racial_passive_id)
			if passive != null:
				var passive_lbl := Label.new()
				passive_lbl.text = "Passive: %s — %s" % [passive.display_name, passive.description]
				passive_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
				passive_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 1.0))
				passive_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				block.add_child(passive_lbl)

		# Row 4: Traits
		if not race.trait_tags.is_empty():
			var traits_lbl := Label.new()
			traits_lbl.text = "Traits: %s" % ", ".join(race.trait_tags)
			traits_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			traits_lbl.add_theme_color_override("font_color", DIM_COLOR)
			block.add_child(traits_lbl)

		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		block.add_child(sep)


	# ========================================================================
	# TAB 4: HEROES — CLASSES
	# ========================================================================

	func _build_classes_tab() -> void:
		var all_classes: Array = DataRegistry.get_all_classes()
		if all_classes.is_empty():
			_add_empty_label("No classes found")
			return

		var filtered: Array = []
		for cls in all_classes:
			if not cls.is_legacy:
				filtered.append(cls)
		filtered.sort_custom(func(a, b): return a.unlock_region < b.unlock_region)

		_add_column_header_row([
			{"text": "Class", "sep": 8},
			{"text": "Archetype"},
			{"text": "Unlock"},
		])

		for cls in filtered:
			_add_class_entry(cls)


	func _add_class_entry(cls) -> void:
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 1)
		_content_vbox.add_child(block)

		# Row 1: Name + archetype + unlock region
		var row1 := HBoxContainer.new()
		row1.add_theme_constant_override("separation", 8)
		block.add_child(row1)

		var name_lbl := Label.new()
		name_lbl.text = cls.display_name
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		name_lbl.add_theme_color_override("font_color", HEADER_COLOR)
		row1.add_child(name_lbl)

		if cls.archetype != "":
			row1.add_child(_col_sep())
			var arch_lbl := Label.new()
			arch_lbl.text = cls.archetype.capitalize()
			arch_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			arch_lbl.add_theme_color_override("font_color", DIM_COLOR)
			row1.add_child(arch_lbl)

		row1.add_child(_col_sep())

		var unlock_lbl := Label.new()
		unlock_lbl.text = "Unlocks: R%d" % cls.unlock_region
		unlock_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		unlock_lbl.add_theme_color_override("font_color", DIM_COLOR)
		row1.add_child(unlock_lbl)

		# Row 2: Base stats
		var base: Dictionary = cls.base_stats if cls.base_stats is Dictionary else {}
		if not base.is_empty():
			var base_parts: Array = []
			for key in ["health", "attack", "defense", "speed"]:
				if base.has(key):
					var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
					base_parts.append("%s:%d" % [abbrev, base[key]])
			if not base_parts.is_empty():
				var base_lbl := Label.new()
				base_lbl.text = "Base: %s" % " ".join(base_parts)
				base_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
				base_lbl.add_theme_color_override("font_color", BODY_COLOR)
				block.add_child(base_lbl)

		# Row 3: Growth per level
		var growth: Dictionary = cls.stat_growth if cls.stat_growth is Dictionary else {}
		if not growth.is_empty():
			var growth_parts: Array = []
			for key in ["health", "attack", "defense", "speed"]:
				if growth.has(key) and growth[key] != 0:
					var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
					growth_parts.append("%s+%d" % [abbrev, growth[key]])
			if not growth_parts.is_empty():
				var growth_lbl := Label.new()
				growth_lbl.text = "Growth/Lv: %s" % " ".join(growth_parts)
				growth_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
				growth_lbl.add_theme_color_override("font_color", DIM_COLOR)
				block.add_child(growth_lbl)

		# Row 4: Abilities
		var ability_ids: Array = []
		if cls.ability_a_id != "":
			ability_ids.append(cls.ability_a_id)
		if cls.ability_b_id != "":
			ability_ids.append(cls.ability_b_id)
		if not ability_ids.is_empty():
			var ab_header := Label.new()
			ab_header.text = "Abilities:"
			ab_header.add_theme_font_size_override("font_size", GameContext.fs(12))
			ab_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
			block.add_child(ab_header)

			for aid in ability_ids:
				var ability = DataRegistry.get_ability(aid)
				if ability != null:
					var cd_text: String = " (CD:%d)" % ability.cooldown if ability.cooldown > 0 else ""
					var desc_text: String = ability.description if ability.description != "" else ""
					var ab_lbl := Label.new()
					ab_lbl.text = "  %s%s — %s" % [ability.display_name, cd_text, desc_text]
					ab_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
					ab_lbl.add_theme_color_override("font_color", BODY_COLOR)
					ab_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					block.add_child(ab_lbl)

		# Row 5: Passives
		var passive_ids: Array = []
		if cls.passive_a_id != "":
			passive_ids.append(cls.passive_a_id)
		if cls.passive_b_id != "":
			passive_ids.append(cls.passive_b_id)
		if not passive_ids.is_empty():
			var pass_header := Label.new()
			pass_header.text = "Passives:"
			pass_header.add_theme_font_size_override("font_size", GameContext.fs(12))
			pass_header.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 1.0))
			block.add_child(pass_header)

			for pid in passive_ids:
				var passive = DataRegistry.get_passive(pid)
				if passive != null:
					var pass_lbl := Label.new()
					pass_lbl.text = "  %s — %s" % [passive.display_name, passive.description]
					pass_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
					pass_lbl.add_theme_color_override("font_color", BODY_COLOR)
					pass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					block.add_child(pass_lbl)

		# Row 6: Weapon types
		if not cls.weapon_types.is_empty():
			var wep_lbl := Label.new()
			wep_lbl.text = "Weapons: %s" % ", ".join(cls.weapon_types)
			wep_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
			wep_lbl.add_theme_color_override("font_color", DIM_COLOR)
			block.add_child(wep_lbl)

		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		block.add_child(sep)


	# ========================================================================
	# TAB 5: CONTROLS
	# ========================================================================

	const CONTROL_CATEGORIES: Array = [
		{
			"label": "Navigation",
			"actions": [
				{"action": "ui_up", "name": "Move Up"},
				{"action": "ui_down", "name": "Move Down"},
				{"action": "ui_left", "name": "Move Left"},
				{"action": "ui_right", "name": "Move Right"},
				{"action": "ui_accept", "name": "Confirm / Select"},
				{"action": "ui_cancel", "name": "Back / Cancel"},
				{"action": "gp_tab_left", "name": "Previous Tab"},
				{"action": "gp_tab_right", "name": "Next Tab"},
			]
		},
		{
			"label": "Combat",
			"actions": [
				{"action": "combat_action_1", "name": "Ability 1"},
				{"action": "combat_action_2", "name": "Ability 2"},
				{"action": "combat_action_3", "name": "Ability 3"},
				{"action": "combat_action_4", "name": "Ability 4"},
				{"action": "combat_action_5", "name": "Ability 5"},
				{"action": "combat_pass", "name": "Pass Turn"},
				{"action": "combat_auto", "name": "Auto-Battle"},
			]
		},
		{
			"label": "Loot",
			"actions": [
				{"action": "loot_hero_1", "name": "Hero 1 Bag"},
				{"action": "loot_hero_2", "name": "Hero 2 Bag"},
				{"action": "loot_hero_3", "name": "Hero 3 Bag"},
				{"action": "loot_hero_4", "name": "Hero 4 Bag"},
				{"action": "loot_shop_bag", "name": "Shopkeeper Bag"},
				{"action": "loot_deposit", "name": "Deposit to Stash"},
			]
		},
		{
			"label": "Dungeon",
			"actions": [
				{"action": "choice_1", "name": "Choice 1 / A"},
				{"action": "choice_2", "name": "Choice 2 / B"},
				{"action": "choice_3", "name": "Choice 3 / C"},
				{"action": "camp_extract", "name": "Extract from Dungeon"},
			]
		},
		{
			"label": "Inventory",
			"actions": [
				{"action": "use_item", "name": "Use Item"},
				{"action": "swap_item", "name": "Swap Item"},
				{"action": "gp_inspect", "name": "Inspect / Details"},
			]
		},
		{
			"label": "System",
			"actions": [
				{"action": "gp_pause", "name": "Pause Menu"},
			]
		},
	]


	func _build_controls_tab() -> void:
		# Device header
		var device_text: String = "Gamepad" if InputManager.active_device == "gamepad" else "Keyboard"
		var device_lbl := Label.new()
		device_lbl.text = "Showing: %s bindings" % device_text
		device_lbl.add_theme_font_size_override("font_size", GameContext.fs(12))
		device_lbl.add_theme_color_override("font_color", DIM_COLOR)
		device_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(device_lbl)

		_add_column_header_row([
			{"text": "Action", "expand": true},
			{"text": "Keyboard", "min_w": 80},
			{"text": "Gamepad", "min_w": 80},
		])

		for cat in CONTROL_CATEGORIES:
			_add_section_header(cat.label)
			for entry in cat.actions:
				_add_control_row(entry.action, entry.name)


	func _add_control_row(action_id: String, display_name: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_content_vbox.add_child(row)

		# Action name
		var name_lbl := Label.new()
		name_lbl.text = display_name
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		name_lbl.add_theme_color_override("font_color", BODY_COLOR)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		row.add_child(_col_sep())

		# Keyboard glyph
		var kb_glyph: String = InputManager._KEYBOARD_GLYPHS.get(action_id, "—")
		if kb_glyph == "":
			kb_glyph = "—"
		var kb_lbl := Label.new()
		kb_lbl.text = kb_glyph
		kb_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		kb_lbl.add_theme_color_override("font_color", HEADER_COLOR if InputManager.active_device != "gamepad" else DIM_COLOR)
		kb_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(kb_lbl)

		row.add_child(_col_sep())

		# Gamepad glyph
		var gp_glyph: String = InputManager._GAMEPAD_GLYPHS.get(action_id, "—")
		if gp_glyph == "":
			gp_glyph = "—"
		var gp_lbl := Label.new()
		gp_lbl.text = gp_glyph
		gp_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		gp_lbl.add_theme_color_override("font_color", HEADER_COLOR if InputManager.active_device == "gamepad" else DIM_COLOR)
		gp_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(gp_lbl)

		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		_content_vbox.add_child(sep)


	# ========================================================================
	# FORMATTING HELPERS
	# ========================================================================

	func _add_column_header_row(columns: Array) -> void:
		var row := HBoxContainer.new()
		var sep_val: int = columns[0].get("sep", 4) if not columns.is_empty() else 4
		row.add_theme_constant_override("separation", sep_val)
		_content_vbox.add_child(row)
		for i in columns.size():
			if i > 0:
				row.add_child(_col_sep())
			var col: Dictionary = columns[i]
			var lbl := Label.new()
			lbl.text = col.get("text", "")
			lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
			lbl.add_theme_color_override("font_color", SECTION_COLOR)
			if col.has("min_w"):
				lbl.custom_minimum_size = Vector2(col.min_w, 0)
			if col.get("expand", false):
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
		var sep := HSeparator.new()
		sep.modulate = SEP_COLOR
		_content_vbox.add_child(sep)


	func _add_section_header(text: String) -> void:
		var lbl := Label.new()
		lbl.text = "— %s —" % text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		lbl.add_theme_color_override("font_color", SECTION_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(lbl)


	func _add_sub_header(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		lbl.add_theme_color_override("font_color", HEADER_COLOR)
		_content_vbox.add_child(lbl)


	func _add_empty_label(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		lbl.add_theme_color_override("font_color", DIM_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content_vbox.add_child(lbl)


	func _badge_label(text: String, color: Color) -> Label:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
		lbl.add_theme_color_override("font_color", color)
		return lbl


	func _col_sep() -> VSeparator:
		var sep := VSeparator.new()
		sep.modulate = SEP_COLOR
		return sep


	func _tier_color(tier: int) -> Color:
		return TIER_COLORS.get(tier, BODY_COLOR)


	func _format_item_stats(tmpl) -> String:
		var parts: Array = []

		var bonuses: Dictionary = {}
		if "stat_bonuses" in tmpl and tmpl.stat_bonuses is Dictionary:
			bonuses = tmpl.stat_bonuses
		elif "base_stats" in tmpl and tmpl.base_stats is Dictionary and tmpl.item_type == "equipment":
			bonuses = tmpl.base_stats

		for key in bonuses:
			var val = bonuses[key]
			if val != 0:
				var abbrev: String = CombatUnit.STAT_ABBREV.get(key, key.to_upper())
				var sign_str: String = "+" if val > 0 else ""
				parts.append("%s%s%s" % [abbrev, sign_str, val])

		if parts.is_empty() and tmpl.item_type == "consumable" and tmpl.has_method("get_effect_label"):
			var effect: String = tmpl.get_effect_label()
			if effect != "":
				return effect

		return " ".join(parts)


	func _create_panel_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = BORDER_COLOR
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(0)
		return style


	# ========================================================================
	# LIFECYCLE
	# ========================================================================

	func _close() -> void:
		if is_instance_valid(_panel):
			_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		UIAudio.unregister_closeable(self)
		guides_closed.emit()
		queue_free()
