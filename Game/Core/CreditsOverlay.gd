class_name CreditsOverlay
extends RefCounted
## Scrollable credits/attribution overlay.
## Usage: var overlay = CreditsOverlay.show(caller_node)
##        if overlay != null: await overlay.credits_closed


static func show(caller: Node) -> Node:
	var panel := _CreditsPanel.new()
	caller.add_child(panel)
	return panel


# ============================================================================
# INNER CLASS
# ============================================================================

class _CreditsPanel extends CanvasLayer:
	signal credits_closed

	const BG_COLOR := Color(0.08, 0.06, 0.12, 0.97)
	const BORDER_COLOR := Color(0.6, 0.5, 0.3, 0.9)
	const HEADER_COLOR := Color(1.0, 0.85, 0.5, 1.0)
	const SECTION_COLOR := Color(0.7, 0.85, 1.0, 1.0)
	const BODY_COLOR := Color(0.85, 0.85, 0.85, 1.0)
	const DIM_COLOR := Color(0.5, 0.5, 0.5, 0.8)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)

	var _root: Control
	var _close_btn: Button


	func _ready() -> void:
		layer = 11
		_build_ui()
		_root.modulate.a = 0.0
		create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
		UIAudio.register_closeable(self, _close)


	func _build_ui() -> void:
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_root)

		var backdrop := ColorRect.new()
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.color = BACKDROP_COLOR
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		backdrop.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_close()
		)
		_root.add_child(backdrop)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(center)

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_color = BORDER_COLOR
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(20)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(460, 400)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		center.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		panel.add_child(vbox)

		# Header row
		var header_row := HBoxContainer.new()
		vbox.add_child(header_row)

		var title_lbl := Label.new()
		title_lbl.text = "Credits"
		title_lbl.add_theme_font_size_override("font_size", GameContext.fs(20))
		title_lbl.add_theme_color_override("font_color", HEADER_COLOR)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header_row.add_child(title_lbl)

		_close_btn = Button.new()
		_close_btn.text = "X"
		_close_btn.add_theme_font_size_override("font_size", GameContext.fs(15))
		_close_btn.custom_minimum_size = Vector2(32, 32)
		_close_btn.focus_mode = Control.FOCUS_ALL
		_close_btn.pressed.connect(_close)
		header_row.add_child(_close_btn)

		var sep := HSeparator.new()
		sep.modulate = Color(0.55, 0.4, 0.25, 0.6)
		vbox.add_child(sep)

		# Scrollable content
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 6)
		scroll.add_child(content)

		_build_credits_content(content)
		_close_btn.call_deferred("grab_focus")


	func _build_credits_content(vbox: VBoxContainer) -> void:
		# --- Game ---
		_add_section(vbox, "Shops & Shadows")
		_add_entry(vbox, "A Shopkeeper's Tale")
		_add_entry(vbox, "Developed by Starcraft394")
		_add_spacer(vbox)

		# --- Engine ---
		_add_section(vbox, "Engine")
		_add_entry(vbox, "Godot Engine 4.5")
		_add_entry(vbox, "https://godotengine.org")
		_add_spacer(vbox)

		# --- Art Assets ---
		_add_section(vbox, "Art Assets")
		_add_entry(vbox, "RPG Item Icons — CraftPix.net")
		_add_entry(vbox, "Monster Sprites — CraftPix.net")
		_add_entry(vbox, "Skill & Buff Icons — CraftPix.net")
		_add_entry(vbox, "Character Avatars — CraftPix.net")
		_add_entry(vbox, "Pixel Art UI Pack — CraftPix.net")
		_add_spacer(vbox)

		# --- Audio ---
		_add_section(vbox, "Audio")
		_add_entry(vbox, "Background Music — Original compositions")
		_add_entry(vbox, "Sound Effects — Kenney.nl (CC0)")
		_add_entry(vbox, "UI Audio — Kenney.nl (CC0)")
		_add_spacer(vbox)

		# --- Background Art ---
		_add_section(vbox, "Backgrounds")
		_add_entry(vbox, "Town & Dungeon Backgrounds — AI-assisted generation")
		_add_spacer(vbox)

		# --- Tools ---
		_add_section(vbox, "Tools & Libraries")
		_add_entry(vbox, "Claude Code — Anthropic (development assistant)")
		_add_spacer(vbox)

		# --- Special Thanks ---
		_add_section(vbox, "Special Thanks")
		_add_entry(vbox, "Playtesters — Thank you for helping improve the game!")
		_add_spacer(vbox)

		# --- License note ---
		var license_lbl := Label.new()
		license_lbl.text = "All third-party assets used under their respective licenses."
		license_lbl.add_theme_font_size_override("font_size", GameContext.fs(11))
		license_lbl.add_theme_color_override("font_color", DIM_COLOR)
		license_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		license_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(license_lbl)


	func _add_section(vbox: VBoxContainer, text: String) -> void:
		var lbl := Label.new()
		lbl.text = "— %s —" % text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(15))
		lbl.add_theme_color_override("font_color", SECTION_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)


	func _add_entry(vbox: VBoxContainer, text: String) -> void:
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", GameContext.fs(13))
		lbl.add_theme_color_override("font_color", BODY_COLOR)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)


	func _add_spacer(vbox: VBoxContainer) -> void:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 8)
		vbox.add_child(spacer)


	func _close() -> void:
		UIAudio.unregister_closeable(self)
		credits_closed.emit()
		queue_free()
