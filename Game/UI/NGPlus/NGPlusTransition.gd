class_name NGPlusTransition
extends RefCounted
## NG+ Transition overlay — hero selection, ability infusion, and cycle confirmation.
## Usage: var overlay = NGPlusTransition.show(self)
##        if overlay != null: await overlay.transition_complete


## Show the NG+ transition overlay. Returns the panel node (await transition_complete).
static func show(caller: Node) -> Node:
	var panel := _NGPlusPanel.new()
	caller.add_child(panel)
	return panel


## Check if the player is eligible to start a new NG+ cycle.
## True when R7 boss has been killed in this cycle (first play or NG+).
static func can_start_new_cycle() -> bool:
	return GameContext.has_campaign_flag("story_r7_boss_killed") or \
		GameContext.has_campaign_flag("story_ng_r7_boss_killed")


# ==========================================================================
# INNER CLASS: NG+ Transition Panel
# ==========================================================================

class _NGPlusPanel extends CanvasLayer:
	signal transition_complete

	enum Page { INTRO, HERO_SELECT, INFUSION, SUMMARY }

	# Colours (warm gold/amber theme — distinct from campaign blue-gold)
	const BG_COLOR := Color(0.08, 0.06, 0.12, 0.97)
	const BORDER_COLOR := Color(0.85, 0.65, 0.25, 0.9)
	const TITLE_COLOR := Color(1.0, 0.82, 0.35, 1.0)
	const BODY_COLOR := Color(0.9, 0.85, 0.75, 1.0)
	const DIM_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const SELECTED_COLOR := Color(0.85, 0.65, 0.25, 0.4)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.75)
	const PANEL_WIDTH := 620

	# State
	var _current_page: int = Page.INTRO
	var _carry_limit: int = 0
	var _selected_hero_ids: Array[String] = []
	var _infusion_hero_id: String = ""
	var _infusion_slot: String = ""
	var _infusion_ability_id: String = ""
	var _portrait_cache: Dictionary = {}

	# UI
	var _root: Control
	var _backdrop: ColorRect
	var _center: CenterContainer
	var _panel: PanelContainer
	var _content_vbox: VBoxContainer
	var _margin: MarginContainer

	func _init() -> void:
		layer = 10
		_carry_limit = GameContext.get_ng_carry_limit()

	func _ready() -> void:
		_build_shell()
		_show_page(Page.INTRO)
		# Fade in
		_root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, 0.3)

	# ------------------------------------------------------------------
	# SHELL (shared frame — pages swap content inside _content_vbox)
	# ------------------------------------------------------------------

	func _build_shell() -> void:
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_root)

		_backdrop = ColorRect.new()
		_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		_backdrop.color = BACKDROP_COLOR
		_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		_root.add_child(_backdrop)

		# ScrollContainer wrapping CenterContainer so content can scroll on small screens
		var scroll := ScrollContainer.new()
		scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_root.add_child(scroll)

		_center = CenterContainer.new()
		_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(_center)

		_panel = PanelContainer.new()
		_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		_panel.add_theme_stylebox_override("panel", _create_panel_style())
		_center.add_child(_panel)

		_margin = MarginContainer.new()
		_margin.add_theme_constant_override("margin_left", 28)
		_margin.add_theme_constant_override("margin_right", 28)
		_margin.add_theme_constant_override("margin_top", 24)
		_margin.add_theme_constant_override("margin_bottom", 24)
		_panel.add_child(_margin)

		_content_vbox = VBoxContainer.new()
		_content_vbox.add_theme_constant_override("separation", 14)
		_margin.add_child(_content_vbox)

	# ------------------------------------------------------------------
	# PAGE ROUTER
	# ------------------------------------------------------------------

	func _show_page(page: int) -> void:
		_current_page = page
		_clear_content()
		match page:
			Page.INTRO:
				_build_intro_page()
			Page.HERO_SELECT:
				_build_hero_select_page()
			Page.INFUSION:
				_build_infusion_page()
			Page.SUMMARY:
				_build_summary_page()

	func _clear_content() -> void:
		for child in _content_vbox.get_children():
			_content_vbox.remove_child(child)
			child.queue_free()

	# ------------------------------------------------------------------
	# PAGE 1: INTRO
	# ------------------------------------------------------------------

	func _build_intro_page() -> void:
		_add_title("The Anchor Stone Pulses")
		_add_separator()

		var cycle_num: int = GameContext.ng_plus_cycle + 1
		var lines: Array[String] = []
		if GameContext.ng_plus_cycle == 0:
			lines = [
				"The corruption fades, but the Anchor Stone's rhythm grows stronger.",
				"Reality shifts. The world resets. Towns forget. Heroes forget.",
				"But you remember. The Stone ensures it.",
				"You may carry one companion into the next cycle. Choose wisely.",
				"Your equipment will be stored. Your gold — most of it — will be lost.",
				"The road ahead is harder. The monsters, stronger.",
				"But so are you."
			]
		else:
			lines = [
				"Again. The Stone pulses. The cycle turns.",
				"Each pass through the world leaves its mark — on you, on your heroes, on the corruption itself.",
				"You may carry %d companion%s into Cycle %d." % [
					_carry_limit,
					"" if _carry_limit == 1 else "s",
					cycle_num
				],
				"The world will be harder. But you know the road now."
			]

		for line in lines:
			var lbl := RichTextLabel.new()
			lbl.bbcode_enabled = false
			lbl.fit_content = true
			lbl.scroll_active = false
			lbl.add_theme_font_size_override("normal_font_size", GameContext.fs(16))
			lbl.add_theme_color_override("default_color", BODY_COLOR)
			lbl.text = line
			_content_vbox.add_child(lbl)

		_add_separator()
		_add_button_row(["Continue"], [_on_intro_continue])

	func _on_intro_continue() -> void:
		_show_page(Page.HERO_SELECT)

	# ------------------------------------------------------------------
	# PAGE 2: HERO SELECTION
	# ------------------------------------------------------------------

	var _hero_buttons: Dictionary = {}  # hero_id -> Button
	var _hero_count_label: Label = null

	func _build_hero_select_page() -> void:
		_selected_hero_ids.clear()
		_hero_buttons.clear()

		_add_title("Choose Your Companions")

		# Carry limit info
		_hero_count_label = Label.new()
		_hero_count_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		_hero_count_label.add_theme_color_override("font_color", DIM_COLOR)
		_content_vbox.add_child(_hero_count_label)
		_update_hero_count_label()

		_add_separator()

		# Hero grid
		var heroes: Array = GameContext.owned_heroes
		if heroes.is_empty():
			var no_heroes := Label.new()
			no_heroes.text = "No heroes to carry over."
			no_heroes.add_theme_font_size_override("font_size", GameContext.fs(15))
			no_heroes.add_theme_color_override("font_color", BODY_COLOR)
			_content_vbox.add_child(no_heroes)
		else:
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			_content_vbox.add_child(grid)

			for hero in heroes:
				var hid: String = hero.get("hero_id", "")
				var card := _create_hero_card(hero)
				grid.add_child(card)
				_hero_buttons[hid] = card

		_add_separator()

		# Auto-select all if under limit
		if heroes.size() <= _carry_limit:
			for hero in heroes:
				var hid: String = hero.get("hero_id", "")
				_selected_hero_ids.append(hid)
				_update_hero_card_visual(hid, true)
			_update_hero_count_label()

		_add_button_row(["Back", "Continue"], [_on_hero_back, _on_hero_continue])

	func _create_hero_card(hero: Dictionary) -> PanelContainer:
		var hid: String = hero.get("hero_id", "")
		var hname: String = hero.get("name", hid)
		var class_id: String = hero.get("class_id", "")
		var level: int = int(hero.get("level", 1))
		var portrait_path: String = hero.get("portrait_path", "")

		var class_data = DataRegistry.get_class_data(class_id) if DataRegistry.has_method("get_class_data") else null
		var class_name_str: String = class_data.display_name if class_data else class_id

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 0)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.12, 0.1, 0.18, 0.8)
		card_style.border_color = Color(0.4, 0.4, 0.5, 0.5)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", card_style)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		card.add_child(hbox)

		# Portrait
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(48, 48)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if portrait_path != "":
			var tex = _load_portrait(portrait_path)
			if tex != null:
				portrait.texture = tex
		hbox.add_child(portrait)

		# Info column
		var vcol := VBoxContainer.new()
		vcol.add_theme_constant_override("separation", 2)
		vcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(vcol)

		var name_lbl := Label.new()
		name_lbl.text = hname
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		name_lbl.add_theme_color_override("font_color", TITLE_COLOR)
		vcol.add_child(name_lbl)

		var info_lbl := Label.new()
		info_lbl.text = "Lv%d %s" % [level, class_name_str]
		info_lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		info_lbl.add_theme_color_override("font_color", BODY_COLOR)
		vcol.add_child(info_lbl)

		# Make card clickable
		card.gui_input.connect(_on_hero_card_input.bind(hid))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		return card

	func _on_hero_card_input(event: InputEvent, hero_id: String) -> void:
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return

		if _selected_hero_ids.has(hero_id):
			# Deselect
			_selected_hero_ids.erase(hero_id)
			_update_hero_card_visual(hero_id, false)
		else:
			# Select (if under limit)
			if _selected_hero_ids.size() >= _carry_limit:
				return  # At limit — can't select more
			_selected_hero_ids.append(hero_id)
			_update_hero_card_visual(hero_id, true)

		_update_hero_count_label()

	func _update_hero_card_visual(hero_id: String, selected: bool) -> void:
		var card = _hero_buttons.get(hero_id) as PanelContainer
		if card == null:
			return
		var style: StyleBoxFlat = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if selected:
			style.bg_color = SELECTED_COLOR
			style.border_color = BORDER_COLOR
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.12, 0.1, 0.18, 0.8)
			style.border_color = Color(0.4, 0.4, 0.5, 0.5)
			style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", style)

	func _update_hero_count_label() -> void:
		if _hero_count_label == null:
			return
		_hero_count_label.text = "Selected: %d / %d" % [_selected_hero_ids.size(), _carry_limit]
		if _selected_hero_ids.size() >= _carry_limit:
			_hero_count_label.add_theme_color_override("font_color", TITLE_COLOR)
		else:
			_hero_count_label.add_theme_color_override("font_color", DIM_COLOR)

	func _on_hero_back() -> void:
		_show_page(Page.INTRO)

	func _on_hero_continue() -> void:
		# Skip infusion if no seen abilities
		if GameContext.seen_abilities.size() > 0 and _selected_hero_ids.size() > 0:
			_show_page(Page.INFUSION)
		else:
			_show_page(Page.SUMMARY)

	# ------------------------------------------------------------------
	# PAGE 3: ABILITY INFUSION (optional)
	# ------------------------------------------------------------------

	var _infusion_item_buttons: Dictionary = {}  # "hero_id:slot" -> Button
	var _infusion_ability_buttons: Dictionary = {}  # ability_id -> Button
	var _infusion_preview_label: Label = null

	func _build_infusion_page() -> void:
		_infusion_hero_id = ""
		_infusion_slot = ""
		_infusion_ability_id = ""
		_infusion_item_buttons.clear()
		_infusion_ability_buttons.clear()

		_add_title("Ability Infusion")

		var desc := Label.new()
		desc.text = "Choose one equipment item to infuse with a seen ability (optional)."
		desc.add_theme_font_size_override("font_size", GameContext.fs(14))
		desc.add_theme_color_override("font_color", DIM_COLOR)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(desc)

		_add_separator()

		# Split: items on left, abilities on right
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		_content_vbox.add_child(hbox)

		# Left column: equipment items from selected heroes
		var left_col := VBoxContainer.new()
		left_col.add_theme_constant_override("separation", 6)
		left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(left_col)

		var items_title := Label.new()
		items_title.text = "Equipment"
		items_title.add_theme_font_size_override("font_size", GameContext.fs(14))
		items_title.add_theme_color_override("font_color", TITLE_COLOR)
		left_col.add_child(items_title)

		var has_items: bool = false
		for hid in _selected_hero_ids:
			var equip: Dictionary = GameContext.get_hero_equipment(hid)
			var hero: Dictionary = GameContext.get_hero(hid)
			var hname: String = hero.get("name", hid)
			for slot in GameContext.ALL_EQUIP_SLOTS:
				var slot_data: Dictionary = equip.get(slot, {})
				var item_id: String = slot_data.get("id", "")
				if item_id == "":
					continue
				var template = DataRegistry.get_item_template(item_id)
				var display_name: String = template.display_name if template else item_id
				var btn := Button.new()
				btn.text = "%s — %s (%s)" % [hname, display_name, slot]
				btn.add_theme_font_size_override("font_size", GameContext.fs(13))
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				var key: String = "%s:%s" % [hid, slot]
				btn.pressed.connect(_on_infusion_item_selected.bind(hid, slot, key))
				left_col.add_child(btn)
				_infusion_item_buttons[key] = btn
				has_items = true

		if not has_items:
			var no_items := Label.new()
			no_items.text = "No equipped items."
			no_items.add_theme_font_size_override("font_size", GameContext.fs(13))
			no_items.add_theme_color_override("font_color", DIM_COLOR)
			left_col.add_child(no_items)

		# Right column: seen abilities
		var right_col := VBoxContainer.new()
		right_col.add_theme_constant_override("separation", 6)
		right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(right_col)

		var abilities_title := Label.new()
		abilities_title.text = "Seen Abilities"
		abilities_title.add_theme_font_size_override("font_size", GameContext.fs(14))
		abilities_title.add_theme_color_override("font_color", TITLE_COLOR)
		right_col.add_child(abilities_title)

		var ability_ids: Array = GameContext.seen_abilities.keys()
		ability_ids.sort()
		for aid in ability_ids:
			var ability_data = DataRegistry.get_ability(aid) if DataRegistry.has_method("get_ability") else null
			var display: String = ability_data.display_name if ability_data else aid
			var btn := Button.new()
			btn.text = display
			btn.add_theme_font_size_override("font_size", GameContext.fs(13))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.tooltip_text = ability_data.description if ability_data and ability_data.has_method("get") == false else ""
			# Try to get description safely
			if ability_data != null:
				var desc_text = ability_data.get("description") if ability_data is Dictionary else ""
				if desc_text is String and desc_text != "":
					btn.tooltip_text = desc_text
			btn.pressed.connect(_on_infusion_ability_selected.bind(aid))
			right_col.add_child(btn)
			_infusion_ability_buttons[aid] = btn

		_add_separator()

		# Preview
		_infusion_preview_label = Label.new()
		_infusion_preview_label.text = "Select an item and ability to infuse."
		_infusion_preview_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		_infusion_preview_label.add_theme_color_override("font_color", DIM_COLOR)
		_infusion_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(_infusion_preview_label)

		_add_button_row(["Back", "Skip", "Infuse & Continue"], [_on_infusion_back, _on_infusion_skip, _on_infusion_confirm])

	func _on_infusion_item_selected(hero_id: String, slot: String, key: String) -> void:
		_infusion_hero_id = hero_id
		_infusion_slot = slot
		# Update button visuals
		for k in _infusion_item_buttons:
			var btn: Button = _infusion_item_buttons[k]
			btn.modulate = TITLE_COLOR if k == key else Color.WHITE
		_update_infusion_preview()

	func _on_infusion_ability_selected(ability_id: String) -> void:
		_infusion_ability_id = ability_id
		# Update button visuals
		for k in _infusion_ability_buttons:
			var btn: Button = _infusion_ability_buttons[k]
			btn.modulate = TITLE_COLOR if k == ability_id else Color.WHITE
		_update_infusion_preview()

	func _update_infusion_preview() -> void:
		if _infusion_preview_label == null:
			return
		if _infusion_hero_id == "" or _infusion_slot == "" or _infusion_ability_id == "":
			_infusion_preview_label.text = "Select an item and ability to infuse."
			_infusion_preview_label.add_theme_color_override("font_color", DIM_COLOR)
			return
		var hero: Dictionary = GameContext.get_hero(_infusion_hero_id)
		var hname: String = hero.get("name", _infusion_hero_id)
		var equip: Dictionary = GameContext.get_hero_equipment(_infusion_hero_id)
		var slot_data: Dictionary = equip.get(_infusion_slot, {})
		var item_id: String = slot_data.get("id", "")
		var template = DataRegistry.get_item_template(item_id)
		var item_name: String = template.display_name if template else item_id
		var ability_data = DataRegistry.get_ability(_infusion_ability_id) if DataRegistry.has_method("get_ability") else null
		var ability_name: String = ability_data.display_name if ability_data else _infusion_ability_id
		_infusion_preview_label.text = "Infuse %s's %s with %s" % [hname, item_name, ability_name]
		_infusion_preview_label.add_theme_color_override("font_color", TITLE_COLOR)

	func _on_infusion_back() -> void:
		_show_page(Page.HERO_SELECT)

	func _on_infusion_skip() -> void:
		_infusion_hero_id = ""
		_infusion_slot = ""
		_infusion_ability_id = ""
		_show_page(Page.SUMMARY)

	func _on_infusion_confirm() -> void:
		# Apply infusion if both selected
		if _infusion_hero_id != "" and _infusion_slot != "" and _infusion_ability_id != "":
			var success: bool = GameContext.infuse_item_ability(_infusion_hero_id, _infusion_slot, _infusion_ability_id)
			if success:
				print("[NG+] Infusion applied before transition")
			else:
				print("[NG+] Infusion failed — proceeding anyway")
		_show_page(Page.SUMMARY)

	# ------------------------------------------------------------------
	# PAGE 4: SUMMARY + CONFIRM
	# ------------------------------------------------------------------

	func _build_summary_page() -> void:
		var current_cycle: int = GameContext.ng_plus_cycle
		var next_cycle: int = current_cycle + 1

		_add_title("Begin Cycle %d" % next_cycle)
		_add_separator()

		# Heroes
		var hero_text: String = "Heroes: "
		if _selected_hero_ids.is_empty():
			hero_text += "None (starting fresh)"
		else:
			var names: Array[String] = []
			for hid in _selected_hero_ids:
				var hero: Dictionary = GameContext.get_hero(hid)
				names.append(hero.get("name", hid))
			hero_text += ", ".join(names)
		_add_info_line(hero_text)

		# Gold
		var carry_gold: int = mini(int(GameContext.run_gold * 0.25), 500)
		_add_info_line("Gold: %d (25%% of %d, max 500)" % [carry_gold, GameContext.run_gold])

		# Equipment note
		_add_info_line("Equipment from carried heroes will be moved to your stash.")

		# Non-carried heroes
		var left_behind: int = GameContext.owned_heroes.size() - _selected_hero_ids.size()
		if left_behind > 0:
			_add_info_line("%d hero%s will be left behind (recorded in the Book of the Dead)." % [
				left_behind, "" if left_behind == 1 else "es"])

		_add_separator()

		# Difficulty preview
		var diff_title := Label.new()
		diff_title.text = "Difficulty Scaling"
		diff_title.add_theme_font_size_override("font_size", GameContext.fs(14))
		diff_title.add_theme_color_override("font_color", TITLE_COLOR)
		_content_vbox.add_child(diff_title)

		var idx: int = clampi(next_cycle, 0, GameContext.NG_DIFFICULTY_MULT.size() - 1)
		var mult: Dictionary = GameContext.NG_DIFFICULTY_MULT[idx]
		_add_info_line("  Monster HP: x%.2f  |  ATK: x%.2f  |  DEF: x%.2f  |  SPD: x%.2f" % [
			mult.hp, mult.atk, mult.def, mult.spd])

		if next_cycle >= 5:
			_add_info_line("  Hero perm stat bonus: +%.0f%%" % ((GameContext.ng_plus_perm_stat_bonus + 0.05) * 100))

		_add_separator()

		# Warning
		var warning := Label.new()
		warning.text = "This cannot be undone. All progress except carried data will be reset."
		warning.add_theme_font_size_override("font_size", GameContext.fs(13))
		warning.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4, 0.9))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(warning)

		_add_button_row(["Back", "Begin New Cycle"], [_on_summary_back, _on_summary_confirm])

	func _on_summary_back() -> void:
		if GameContext.seen_abilities.size() > 0 and _selected_hero_ids.size() > 0:
			_show_page(Page.INFUSION)
		else:
			_show_page(Page.HERO_SELECT)

	func _on_summary_confirm() -> void:
		print("[NG+] Player confirmed transition — starting new game plus")
		GameContext.start_new_game_plus(_selected_hero_ids)
		transition_complete.emit()
		# Navigate to town hub
		SceneTransition.fade_to("res://Game/UI/TownHub/TownHubScene.tscn")
		queue_free()

	# ------------------------------------------------------------------
	# HELPERS
	# ------------------------------------------------------------------

	func _add_title(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", GameContext.fs(20))
		lbl.add_theme_color_override("font_color", TITLE_COLOR)
		_content_vbox.add_child(lbl)

	func _add_separator() -> void:
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 8)
		_content_vbox.add_child(sep)

	func _add_info_line(text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
		lbl.add_theme_color_override("font_color", BODY_COLOR)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content_vbox.add_child(lbl)

	func _add_button_row(labels: Array, callbacks: Array) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_END
		_content_vbox.add_child(row)

		# Spacer to push buttons right
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)

		for i in range(labels.size()):
			var btn := Button.new()
			btn.text = labels[i]
			btn.add_theme_font_size_override("font_size", GameContext.fs(16))
			if i == labels.size() - 1:
				# Primary button (last one) — more prominent
				btn.modulate = Color(1.0, 0.9, 0.5)
			btn.pressed.connect(callbacks[i])
			row.add_child(btn)

	func _load_portrait(path: String) -> Texture2D:
		if path == "":
			return null
		if _portrait_cache.has(path):
			return _portrait_cache[path]
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			_portrait_cache[path] = tex
			return tex
		_portrait_cache[path] = null
		return null

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			_close()
			get_viewport().set_input_as_handled()

	func _close() -> void:
		transition_complete.emit()
		queue_free()

	static func _create_panel_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = BORDER_COLOR
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 12
		return style
