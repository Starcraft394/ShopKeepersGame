## CampaignQuestSystem.gd
## Static class managing campaign quest lifecycle: start, track, complete, chain.
## Follows the same pattern as SideQuestSystem.
class_name CampaignQuestSystem
extends RefCounted


# ============================================================================
# QUEST LIFECYCLE
# ============================================================================

## Start a campaign quest by ID. Loads template from DataRegistry, sets as active.
static func start_quest(quest_id: String) -> bool:
	var template: Dictionary = DataRegistry.get_campaign_quest_template(quest_id)
	if template.is_empty():
		print("[CampaignQuest] Template not found: %s" % quest_id)
		return false
	# Check flag prerequisite
	var flag_req: String = template.get("flag_required", "")
	if flag_req != "" and not GameContext.has_campaign_flag(flag_req):
		print("[CampaignQuest] Flag prerequisite not met: %s for %s" % [flag_req, quest_id])
		return false
	# Already have an active quest?
	if GameContext.active_campaign_quest != null:
		print("[CampaignQuest] Cannot start %s — already have active quest: %s" % [
			quest_id, GameContext.active_campaign_quest.quest_id])
		return false
	# Create quest instance from template
	var quest := CampaignQuestData.from_dict(template)
	quest.is_active = true
	GameContext.active_campaign_quest = quest
	GameContext.save_game()
	print("[CampaignQuest] Started: %s (%s)" % [quest.display_name, quest.quest_id])
	return true


## Complete the active campaign quest. Grants rewards, sets flags, auto-chains.
static func complete_quest() -> void:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return
	quest.is_complete = true
	quest.is_active = false
	# Grant rewards
	if quest.reward_gold > 0:
		GameContext.run_gold += quest.reward_gold
		print("[CampaignQuest] Reward: +%d gold" % quest.reward_gold)
	for item_id in quest.reward_items:
		GameContext.add_run_item(item_id, 1)
		print("[CampaignQuest] Reward item: %s" % item_id)
	# Clear mission bag
	quest.clear_mission_bag()
	# Set completion flag
	if quest.flag_set_on_complete != "":
		GameContext.set_campaign_flag(quest.flag_set_on_complete)
	# Track completion
	if not GameContext.completed_campaign_quests.has(quest.quest_id):
		GameContext.completed_campaign_quests.append(quest.quest_id)
	# Clear active quest
	var next_id: String = quest.next_quest_id
	GameContext.active_campaign_quest = null
	GameContext.save_game()
	print("[CampaignQuest] Completed: %s" % quest.quest_id)
	# Auto-chain to next quest
	if next_id != "":
		print("[CampaignQuest] Chaining to: %s" % next_id)
		start_quest(next_id)


## Get the first available quest that hasn't been completed or started.
static func get_next_available_quest_id() -> String:
	var templates: Array = DataRegistry.get_all_campaign_quest_templates()
	for tmpl in templates:
		var qid: String = tmpl.get("quest_id", "")
		if qid == "":
			continue
		# Already completed?
		if GameContext.completed_campaign_quests.has(qid):
			continue
		# Currently active?
		if GameContext.active_campaign_quest != null and GameContext.active_campaign_quest.quest_id == qid:
			continue
		# Flag prerequisite met?
		var flag_req: String = tmpl.get("flag_required", "")
		if flag_req != "" and not GameContext.has_campaign_flag(flag_req):
			continue
		return qid
	return ""


# ============================================================================
# TRACKING HOOKS (called from game systems)
# ============================================================================

## Called when a boss is killed. Marks kill_boss objective and adds quest item
## to mission bag for retrieve_item quests.
static func on_boss_killed(boss_id: String, region_id: String) -> void:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null or quest.region_id != region_id:
		return
	quest.mark_boss_killed(boss_id)
	# For retrieve_item quests, boss drops the quest item into mission bag
	if quest.quest_type == "retrieve_item":
		for obj in quest.objectives:
			if obj.get("type", "") == "collect_item" and not obj.get("is_complete", false):
				var item_id: String = obj.get("target_id", "")
				if item_id != "":
					quest.add_to_mission_bag(item_id, 1)
					quest.add_collected_item(item_id, 1)
	GameContext.save_game()


## Called when an NPC is found in a dungeon event.
static func on_npc_found(found_npc_id: String) -> void:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return
	if quest.mark_npc_found(found_npc_id):
		GameContext.save_game()


## Called when a fragment or quest item is collected (from elite kills or events).
static func on_fragment_collected(item_id: String, qty: int = 1) -> void:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return
	if quest.quest_type == "collect_fragments":
		quest.add_to_mission_bag(item_id, qty)
		quest.add_collected_item(item_id, qty)
		GameContext.save_game()


## Called on town return. Checks if all objectives are met.
## Returns true if quest can be completed (caller shows completion UI).
static func on_town_return() -> bool:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return false
	# Mark return_to_town objective if present
	quest.mark_returned_to_town()
	return quest.check_completion()


# ============================================================================
# QUEST NPC / FRAGMENT INJECTION
# ============================================================================

## Check if we should inject an NPC rescue event for the current quest.
## Returns the event_id to inject, or "" if none.
static func should_inject_npc_event(region_id: String, floor_num: int) -> String:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null or quest.quest_type != "rescue_npc":
		return ""
	if quest.region_id != region_id:
		return ""
	if quest.npc_found:
		return ""
	# Inject NPC event on floor 2 (0-indexed = 1)
	if floor_num == 1:
		# Look up the NPC event ID from quest objectives
		for obj in quest.objectives:
			if obj.get("type", "") == "find_npc":
				return obj.get("event_id", "")
	return ""


## Check if we should inject a fragment drop for the current quest.
## Returns the fragment item_id, or "" if none.
static func should_inject_fragment_drop(region_id: String) -> String:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null or quest.quest_type != "collect_fragments":
		return ""
	if quest.region_id != region_id:
		return ""
	# Check if we still need fragments
	for obj in quest.objectives:
		if obj.get("type", "") == "collect_item":
			var current: int = int(obj.get("current_count", 0))
			var required: int = int(obj.get("required_count", 1))
			if current < required:
				return obj.get("target_id", "")
	return ""


# ============================================================================
# UI HELPERS
# ============================================================================

## Get quest info for the quest log display.
static func get_quest_log_info() -> Dictionary:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return {}
	return {
		"quest_id": quest.quest_id,
		"display_name": quest.display_name,
		"description": quest.description,
		"quest_type": quest.quest_type,
		"progress_text": quest.get_progress_text(),
		"is_complete": quest.is_complete,
		"region_id": quest.region_id,
	}


## Show a quest completion overlay. Returns the overlay node for awaiting.
static func show_completion_overlay(caller: Node) -> Node:
	var quest: CampaignQuestData = GameContext.active_campaign_quest
	if quest == null:
		return null
	# Try to show the quest_complete_dialog_id as a campaign dialog
	if quest.quest_complete_dialog_id != "":
		var overlay = CampaignDialog.try_show(caller, "quest_complete", quest.region_id)
		if overlay != null:
			return overlay
	# Fallback: simple panel
	var panel := _QuestCompletePanel.new(quest)
	caller.add_child(panel)
	return panel


# ============================================================================
# INNER CLASS: Quest completion overlay
# ============================================================================

class _QuestCompletePanel extends CanvasLayer:
	signal dialog_finished

	var _quest: CampaignQuestData

	func _init(quest: CampaignQuestData) -> void:
		_quest = quest
		layer = 10

	func _ready() -> void:
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(root)

		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(backdrop)

		# Center container
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(center)

		# Panel
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(480, 0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.05, 0.1, 0.97)
		style.border_color = Color(0.85, 0.65, 0.25, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(12)
		style.set_content_margin_all(24)
		panel.add_theme_stylebox_override("panel", style)
		center.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		panel.add_child(vbox)

		# Title
		var title_lbl := Label.new()
		title_lbl.text = "Quest Complete!"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", GameContext.fs(20))
		title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		vbox.add_child(title_lbl)

		# Quest name
		var name_lbl := Label.new()
		name_lbl.text = _quest.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", GameContext.fs(16))
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
		vbox.add_child(name_lbl)

		# Rewards
		if _quest.reward_gold > 0:
			var gold_lbl := Label.new()
			gold_lbl.text = "Reward: +%d gold" % _quest.reward_gold
			gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gold_lbl.add_theme_font_size_override("font_size", GameContext.fs(14))
			gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
			vbox.add_child(gold_lbl)

		# Separator
		var sep := HSeparator.new()
		vbox.add_child(sep)

		# Continue button
		var btn := Button.new()
		btn.text = "Continue"
		btn.add_theme_font_size_override("font_size", GameContext.fs(16))
		btn.pressed.connect(_on_continue)
		vbox.add_child(btn)

		# Fade in
		root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(root, "modulate:a", 1.0, 0.25)

	func _on_continue() -> void:
		dialog_finished.emit()
		queue_free()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			_on_continue()
			get_viewport().set_input_as_handled()
