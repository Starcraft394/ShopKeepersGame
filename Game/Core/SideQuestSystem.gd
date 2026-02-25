## SideQuestSystem.gd
## Static class for side quest generation, tracking, completion, and UI.
## Quests trigger on town return with per-region chance rolls.
extends RefCounted
class_name SideQuestSystem

# ============================================================================
# TRIGGER CHANCES (per region)
# ============================================================================

const TRIGGER_CHANCES: Dictionary = {
	"region_1": 0.05, "region_2": 0.06, "region_3": 0.07,
	"region_4": 0.08, "region_5": 0.09, "region_6": 0.10, "region_7": 0.12
}

# ============================================================================
# REWARD QUALITY TABLES (Rare=2, Epic=3 only)
# ============================================================================

const REWARD_QUALITY_TABLE: Dictionary = {
	"region_1": [{"value": 2, "weight": 97.0}, {"value": 3, "weight": 3.0}],
	"region_2": [{"value": 2, "weight": 95.0}, {"value": 3, "weight": 5.0}],
	"region_3": [{"value": 2, "weight": 93.0}, {"value": 3, "weight": 7.0}],
	"region_4": [{"value": 2, "weight": 90.0}, {"value": 3, "weight": 10.0}],
	"region_5": [{"value": 2, "weight": 87.0}, {"value": 3, "weight": 13.0}],
	"region_6": [{"value": 2, "weight": 83.0}, {"value": 3, "weight": 17.0}],
	"region_7": [{"value": 2, "weight": 78.0}, {"value": 3, "weight": 22.0}]
}

# Region → dungeon_id mapping
const REGION_DUNGEON_MAP: Dictionary = {
	"region_1": "dungeon_thornhaven",
	"region_2": "dungeon_sproutrest",
	"region_3": "dungeon_shelldrift",
	"region_4": "dungeon_embercradle",
	"region_5": "dungeon_crystalhearth",
	"region_6": "dungeon_duskhollow",
	"region_7": "dungeon_void_threshold"
}

# Region → common loot table ID for material drops
const REGION_LOOT_TABLE_MAP: Dictionary = {
	"region_1": "lt_region1_common",
	"region_2": "lt_region2_common",
	"region_3": "lt_region3_common",
	"region_4": "lt_region4_common",
	"region_5": "lt_region5_common",
	"region_6": "lt_region6_common",
	"region_7": "lt_region7_common"
}

# Quest types
const QUEST_TYPES: Array[String] = ["kill", "resupply", "mini_dungeon"]

# Kill quest: target count ranges by region
const KILL_COUNT_MIN: int = 4
const KILL_COUNT_MAX: int = 10

# Resupply quest: material count ranges
const RESUPPLY_QTY_MIN: int = 3
const RESUPPLY_QTY_MAX: int = 8

# Mini-dungeon fight counts
const MINI_DUNGEON_FIGHTS_LOW: int = 2   # R1-R3
const MINI_DUNGEON_FIGHTS_HIGH: int = 3  # R4-R7

# Mini-dungeon final fight buff multipliers
const MINI_BOSS_HP_MULT: float = 1.3
const MINI_BOSS_ATK_MULT: float = 1.2
const MINI_BOSS_DEF_MULT: float = 1.2


# ============================================================================
# QUEST GENERATION
# ============================================================================

## Try to generate a side quest for the given region.
## Returns a SideQuestData or null if the roll fails or all types are taken.
static func try_generate_quest(region_id: String, rng: RandomNumberGenerator = null) -> SideQuestData:
	if not TRIGGER_CHANCES.has(region_id):
		print("[SideQuest] Unknown region: %s" % region_id)
		return null

	# Roll trigger chance
	var chance: float = TRIGGER_CHANCES[region_id]
	var roll: float = randf() if rng == null else rng.randf()
	if roll >= chance:
		print("[SideQuest] Trigger roll failed: %.2f >= %.2f (region=%s)" % [roll, chance, region_id])
		return null

	# Find available quest types (not already active)
	var available_types: Array[String] = []
	for qt in QUEST_TYPES:
		if GameContext.get_active_quest_by_type(qt) == null:
			available_types.append(qt)

	if available_types.is_empty():
		print("[SideQuest] All quest types already active — skipping")
		return null

	# Pick a random type
	var type_idx: int = randi() % available_types.size() if rng == null else rng.randi() % available_types.size()
	var quest_type: String = available_types[type_idx]

	# Generate quest
	var quest: SideQuestData = _generate_quest(region_id, quest_type, rng)
	if quest == null:
		print("[SideQuest] Generation failed for %s/%s" % [region_id, quest_type])
		return null

	print("[SideQuest] Generated: %s (%s in %s) reward=%s Q%d" % [
		quest.quest_id, quest.quest_type, quest.region_id,
		quest.reward_item_id, quest.reward_quality])
	return quest


## Force-generate a quest of a specific type (for testing / guaranteed offers).
static func generate_quest_of_type(region_id: String, quest_type: String, rng: RandomNumberGenerator = null) -> SideQuestData:
	return _generate_quest(region_id, quest_type, rng)


## Internal: generate a quest of the given type.
static func _generate_quest(region_id: String, quest_type: String, rng: RandomNumberGenerator = null) -> SideQuestData:
	var quest = SideQuestData.new()
	quest.quest_id = GameContext._next_side_quest_id(region_id, quest_type)
	quest.quest_type = quest_type
	quest.region_id = region_id

	match quest_type:
		"kill":
			_populate_kill_quest(quest, region_id, rng)
		"resupply":
			_populate_resupply_quest(quest, region_id, rng)
		"mini_dungeon":
			_populate_mini_dungeon_quest(quest, region_id, rng)

	# Roll reward
	_roll_reward(quest, region_id, rng)

	return quest


## Populate a kill quest with monster targets from the region dungeon.
static func _populate_kill_quest(quest: SideQuestData, region_id: String, rng: RandomNumberGenerator) -> void:
	var dungeon_id: String = REGION_DUNGEON_MAP.get(region_id, "")
	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	if dungeon == null:
		print("[SideQuest] No dungeon for region %s" % region_id)
		return

	# Combine tier1 and tier2 monster pools
	var pool: Array = []
	for mid in dungeon.tier1_monster_ids:
		pool.append(mid)
	for mid in dungeon.tier2_monster_ids:
		pool.append(mid)

	if pool.is_empty():
		print("[SideQuest] Empty monster pool for %s" % dungeon_id)
		return

	# Pick 1-2 distinct monster types
	pool.shuffle()
	var num_targets: int = 1 if pool.size() == 1 else (1 + (randi() % 2 if rng == null else rng.randi() % 2))
	num_targets = mini(num_targets, pool.size())

	var names_parts: Array = []
	for i in range(num_targets):
		var mid: String = pool[i]
		var count: int = KILL_COUNT_MIN + (randi() % (KILL_COUNT_MAX - KILL_COUNT_MIN + 1) if rng == null else rng.randi() % (KILL_COUNT_MAX - KILL_COUNT_MIN + 1))
		quest.kill_targets[mid] = count
		quest.kill_progress[mid] = 0
		var monster = DataRegistry.get_monster(mid)
		var mname: String = monster.display_name if monster != null else mid
		names_parts.append("%d %s" % [count, mname])

	quest.display_name = "Hunt: Slay %s" % " & ".join(names_parts)
	quest.description = "A local requests your help clearing dangerous creatures from the area."


## Populate a resupply quest with materials from the region's loot table.
static func _populate_resupply_quest(quest: SideQuestData, region_id: String, rng: RandomNumberGenerator) -> void:
	var lt_id: String = REGION_LOOT_TABLE_MAP.get(region_id, "")
	var loot_table = DataRegistry.get_loot_table(lt_id)
	if loot_table == null:
		print("[SideQuest] No loot table for region %s (id=%s)" % [region_id, lt_id])
		return

	# Get material entries (non-empty item_id)
	var material_ids: Array = []
	for entry in loot_table.entries:
		var eid: String = entry.get("item_id", "") if entry is Dictionary else ""
		if eid != "":
			material_ids.append(eid)

	if material_ids.is_empty():
		print("[SideQuest] No materials in loot table %s" % lt_id)
		return

	# Pick 2-3 distinct materials
	material_ids.shuffle()
	var num_mats: int = 2 + (randi() % 2 if rng == null else rng.randi() % 2)
	num_mats = mini(num_mats, material_ids.size())

	var names_parts: Array = []
	for i in range(num_mats):
		var mid: String = material_ids[i]
		var qty: int = RESUPPLY_QTY_MIN + (randi() % (RESUPPLY_QTY_MAX - RESUPPLY_QTY_MIN + 1) if rng == null else rng.randi() % (RESUPPLY_QTY_MAX - RESUPPLY_QTY_MIN + 1))
		quest.required_items[mid] = qty
		var tmpl = DataRegistry.get_item_template(mid)
		var dname: String = tmpl.display_name if tmpl != null else mid
		names_parts.append("%d %s" % [qty, dname])

	quest.display_name = "Resupply: Gather %s" % " & ".join(names_parts)
	quest.description = "A merchant needs materials restocked. Check your Storage for the required items."


## Populate a mini-dungeon quest.
static func _populate_mini_dungeon_quest(quest: SideQuestData, region_id: String, _rng: RandomNumberGenerator) -> void:
	var region_num: int = int(region_id.replace("region_", ""))
	quest.mini_dungeon_fights = MINI_DUNGEON_FIGHTS_HIGH if region_num >= 4 else MINI_DUNGEON_FIGHTS_LOW
	quest.display_name = "Mini-Dungeon: Clear the Hideout"
	quest.description = "A hidden lair has been discovered. Fight through %d elite encounters to claim your reward." % quest.mini_dungeon_fights


## Roll a reward item for the quest.
static func _roll_reward(quest: SideQuestData, region_id: String, rng: RandomNumberGenerator) -> void:
	# Collect equipment pool across T1-T3 + base
	var pool: Array = []
	for tier in range(1, 4):
		var items: Array = DataRegistry.get_equipment_for_region_tier(region_id, tier)
		for eid in items:
			if eid not in pool:
				pool.append(eid)
	# Add base T1 as fallback
	var base_items: Array = DataRegistry.get_equipment_for_region_tier("base", 1)
	for eid in base_items:
		if eid not in pool:
			pool.append(eid)

	if pool.is_empty():
		print("[SideQuest] No equipment pool for %s — using rusty_sword fallback" % region_id)
		quest.reward_item_id = "rusty_sword"
	else:
		var idx: int = randi() % pool.size() if rng == null else rng.randi() % pool.size()
		quest.reward_item_id = pool[idx]

	# Roll quality (Rare or Epic)
	var quality_table: Array = REWARD_QUALITY_TABLE.get(region_id, [{"value": 2, "weight": 100.0}])
	if rng != null:
		quest.reward_quality = SeededRNG.choose_weighted(quality_table, rng)
	else:
		# Use built-in randf for non-seeded
		var total_w: float = 0.0
		for entry in quality_table:
			total_w += entry.get("weight", 1.0)
		var roll: float = randf() * total_w
		var cumulative: float = 0.0
		for entry in quality_table:
			cumulative += entry.get("weight", 1.0)
			if roll < cumulative:
				quest.reward_quality = entry.get("value", 2)
				break


# ============================================================================
# MINI-DUNGEON COMBAT CHAIN
# ============================================================================

## Start a mini-dungeon quest combat chain. Sets up GameContext state and
## transitions to CombatScene via boot router.
static func start_mini_dungeon(quest_id: String, caller: Node) -> void:
	var quest = GameContext.get_side_quest(quest_id)
	if quest == null or quest.quest_type != "mini_dungeon":
		print("[SideQuest] Cannot start mini-dungeon: invalid quest %s" % quest_id)
		return

	var total: int = quest.mini_dungeon_fights
	GameContext.mini_dungeon_state = {
		"active": true,
		"quest_id": quest_id,
		"fight_index": 0,
		"total_fights": total,
		"region_id": quest.region_id,
		"is_final_fight": total == 1
	}

	print("[SideQuest] Starting mini-dungeon: quest=%s fights=%d region=%s" % [
		quest_id, total, quest.region_id])

	# Set phase to COMBAT and route through boot
	GameContext.set_phase(GameContext.GamePhase.COMBAT)
	caller.get_tree().call_deferred("change_scene_to_file", "res://Game/Boot/game_boot.tscn")


## Advance to the next mini-dungeon fight. Returns true if there's another fight.
static func advance_mini_dungeon() -> bool:
	var state: Dictionary = GameContext.mini_dungeon_state
	if not state.get("active", false):
		return false

	var fight_idx: int = state.get("fight_index", 0) + 1
	var total: int = state.get("total_fights", 1)

	if fight_idx >= total:
		# All fights done — mark quest complete
		var quest_id: String = state.get("quest_id", "")
		var quest = GameContext.get_side_quest(quest_id)
		if quest != null:
			quest.mini_dungeon_completed = true
			print("[SideQuest] Mini-dungeon completed: %s" % quest_id)
		GameContext.mini_dungeon_state = {}
		return false

	# Update state for next fight
	state["fight_index"] = fight_idx
	state["is_final_fight"] = (fight_idx == total - 1)
	print("[SideQuest] Mini-dungeon fight %d/%d (final=%s)" % [
		fight_idx + 1, total, str(state["is_final_fight"])])
	return true


## Cancel / clear mini-dungeon state (used on defeat or manual exit).
static func cancel_mini_dungeon() -> void:
	if GameContext.mini_dungeon_state.get("active", false):
		print("[SideQuest] Mini-dungeon cancelled (defeat or exit)")
	GameContext.mini_dungeon_state = {}


## Generate enemy list for the current mini-dungeon fight.
## Uses elite + tier2 monsters from the quest's region dungeon.
static func get_mini_dungeon_enemies(rng: RandomNumberGenerator) -> Array:
	var state: Dictionary = GameContext.mini_dungeon_state
	if not state.get("active", false):
		return ["goblin", "goblin"]

	var region_id: String = state.get("region_id", "region_1")
	var is_final: bool = state.get("is_final_fight", false)

	var dungeon_id: String = REGION_DUNGEON_MAP.get(region_id, "")
	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	if dungeon == null:
		return ["goblin", "goblin"]

	# Build pool: elite + tier2 monsters
	var pool: Array = []
	for mid in dungeon.elite_monster_ids:
		pool.append(mid)
	for mid in dungeon.tier2_monster_ids:
		if mid not in pool:
			pool.append(mid)

	if pool.is_empty():
		for mid in dungeon.tier1_monster_ids:
			pool.append(mid)

	if pool.is_empty():
		return ["goblin", "goblin"]

	# Enemy count: 2-3 normal, 3-4 final fight
	var count: int
	if is_final:
		count = rng.randi_range(3, 4)
	else:
		count = rng.randi_range(2, 3)

	var enemies: Array = []
	for i in range(count):
		var idx: int = rng.randi_range(0, pool.size() - 1)
		enemies.append(pool[idx])

	print("[SideQuest] Mini-dungeon enemies: %s (final=%s)" % [str(enemies), str(is_final)])
	return enemies


## Check if the game is currently in a mini-dungeon side quest combat.
static func is_in_mini_dungeon() -> bool:
	return GameContext.mini_dungeon_state.get("active", false)


# ============================================================================
# KILL PROGRESS TRACKING
# ============================================================================

## Called after combat victory with a list of defeated monster IDs.
## Updates kill progress for all matching active kill quests.
static func check_kill_progress(monster_id: String) -> void:
	for quest in GameContext.active_side_quests:
		if quest is SideQuestData and quest.quest_type == "kill" and not quest.is_complete:
			quest.record_kill(monster_id)


# ============================================================================
# QUEST COMPLETION
# ============================================================================

## Complete a quest: grant reward to Storage (stash) and remove from active list.
## For resupply quests, consumes the required materials.
## Returns the reward ItemInstance or null on failure.
static func complete_quest(quest_id: String) -> ItemInstance:
	var quest = GameContext.get_side_quest(quest_id)
	if quest == null:
		print("[SideQuest] Cannot complete: quest %s not found" % quest_id)
		return null

	if not quest.check_completion():
		print("[SideQuest] Cannot complete: quest %s objectives not met" % quest_id)
		return null

	# Consume materials for resupply quests
	if quest.quest_type == "resupply":
		for item_id in quest.required_items:
			var qty: int = int(quest.required_items[item_id])
			GameContext.remove_run_item(item_id, qty)
			print("[SideQuest] Consumed %d x %s" % [qty, item_id])

	# Create reward item and add to Storage (stash)
	var tmpl = DataRegistry.get_item_template(quest.reward_item_id)
	if tmpl == null:
		print("[SideQuest] Reward item %s not found" % quest.reward_item_id)
		GameContext.remove_side_quest(quest_id)
		return null

	var added: bool = GameContext.add_run_item(quest.reward_item_id, 1, quest.reward_quality)
	if not added:
		print("[SideQuest] Storage full — reward lost!")

	# Build an ItemInstance for return value / UI display
	var reward = ItemInstance.new()
	reward.template_id = quest.reward_item_id
	reward.quantity = 1
	reward.quality_tier = quest.reward_quality
	var prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quest.reward_quality, 0, ItemInstance.QUALITY_PREFIXES.size() - 1)]
	reward.display_name = prefix + tmpl.display_name

	print("[SideQuest] Reward granted to Storage: %s (Q%d)" % [reward.display_name, reward.quality_tier])

	# Remove quest
	GameContext.remove_side_quest(quest_id)

	return reward


# ============================================================================
# MAIN STORY OBJECTIVE (derived from campaign_flags + completed_regions)
# ============================================================================

## Get the current main story objective text.
static func get_main_story_objective() -> Dictionary:
	var region_num: int = GameContext.current_region
	var region_id: String = "region_%d" % region_num
	var flags: Dictionary = GameContext.campaign_flags

	# Region display names
	var region_names: Dictionary = {
		1: "Thornhaven", 2: "Sproutrest", 3: "Shelldrift",
		4: "Embercradle", 5: "Crystalhearth", 6: "Duskhollow",
		7: "Void Threshold"
	}

	var region_name: String = region_names.get(region_num, "Unknown")

	# Check if R7 boss killed (game complete)
	if flags.has("story_r7_boss_killed") or flags.has("story_ng_r7_boss_killed"):
		return {
			"region": "Region %d: %s" % [region_num, region_name],
			"objective": "Campaign complete! Begin a New Cycle or explore freely.",
			"context": "The Void Sovereign has been defeated."
		}

	# Check if current region's boss is killed
	var boss_flag: String = "story_r%d_boss_killed" % region_num
	if flags.has(boss_flag):
		# Boss killed, next region available
		if region_num < 7:
			var next_name: String = region_names.get(region_num + 1, "Unknown")
			return {
				"region": "Region %d: %s" % [region_num, region_name],
				"objective": "Travel to Region %d: %s" % [region_num + 1, next_name],
				"context": "The way forward is open."
			}
		else:
			return {
				"region": "Region 7: Void Threshold",
				"objective": "Confront the Void Sovereign",
				"context": "The final battle awaits."
			}

	# Boss not yet killed — explore dungeon
	var dungeon_id: String = REGION_DUNGEON_MAP.get(region_id, "")
	var dungeon = DataRegistry.get_dungeon(dungeon_id)
	var dungeon_name: String = dungeon.display_name if dungeon != null else "the dungeon"
	return {
		"region": "Region %d: %s" % [region_num, region_name],
		"objective": "Clear %s and defeat the boss" % dungeon_name,
		"context": "Delve deeper to progress."
	}


# ============================================================================
# UI: QUEST OFFER OVERLAY
# ============================================================================

## Show quest offer overlay. Returns panel node (await quest_resolved).
static func show_quest_offer(caller: Node, quest: SideQuestData) -> Node:
	var panel := _QuestOfferPanel.new(quest)
	caller.add_child(panel)
	return panel


## Show quest complete overlay. Returns panel node (await reward_collected).
static func show_quest_complete(caller: Node, quest: SideQuestData) -> Node:
	var panel := _QuestCompletePanel.new(quest)
	caller.add_child(panel)
	return panel


## Show quest log overlay. Returns panel node (await quest_log_closed).
static func show_quest_log(caller: Node) -> Node:
	var panel := _QuestLogPanel.new()
	caller.add_child(panel)
	return panel


# ==========================================================================
# INNER CLASS: Quest Offer Panel
# ==========================================================================

class _QuestOfferPanel extends CanvasLayer:
	signal quest_resolved(accepted: bool)

	const BG_COLOR := Color(0.06, 0.05, 0.1, 0.97)
	const BORDER_COLOR := Color(0.25, 0.65, 0.85, 0.9)
	const HEADER_COLOR := Color(0.35, 0.82, 1.0, 1.0)
	const BODY_COLOR := Color(0.9, 0.9, 0.95, 1.0)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
	const PANEL_WIDTH := 500

	var _quest: SideQuestData

	func _init(quest: SideQuestData) -> void:
		_quest = quest
		layer = 10
		name = "QuestOfferPanel"

	func _ready() -> void:
		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.color = BACKDROP_COLOR
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(backdrop)

		# Center container
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		# Main panel
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = BORDER_COLOR
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 20.0
		style.content_margin_top = 16.0
		style.content_margin_right = 20.0
		style.content_margin_bottom = 16.0
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		center.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)

		# Header
		var header := Label.new()
		header.text = "Side Quest Available!"
		header.add_theme_color_override("font_color", HEADER_COLOR)
		header.add_theme_font_size_override("font_size", GameContext.fs(18))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(header)

		# Quest name
		var title := Label.new()
		title.text = _quest.display_name
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_font_size_override("font_size", GameContext.fs(15))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(title)

		# Description
		var desc := Label.new()
		desc.text = _quest.description
		desc.add_theme_color_override("font_color", BODY_COLOR)
		desc.add_theme_font_size_override("font_size", GameContext.fs(12))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc)

		# Objectives
		var obj_label := Label.new()
		obj_label.text = "Objectives:"
		obj_label.add_theme_color_override("font_color", HEADER_COLOR)
		obj_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		vbox.add_child(obj_label)

		var obj_text := Label.new()
		obj_text.text = _quest.get_progress_text()
		obj_text.add_theme_color_override("font_color", BODY_COLOR)
		obj_text.add_theme_font_size_override("font_size", GameContext.fs(12))
		obj_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(obj_text)

		# Reward preview
		var reward_label := Label.new()
		reward_label.text = "Reward:"
		reward_label.add_theme_color_override("font_color", HEADER_COLOR)
		reward_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		vbox.add_child(reward_label)

		var reward_tmpl = DataRegistry.get_item_template(_quest.reward_item_id)
		var reward_name: String = reward_tmpl.display_name if reward_tmpl != null else _quest.reward_item_id
		var quality_name: String = ItemInstance.QUALITY_NAMES[clampi(_quest.reward_quality, 0, ItemInstance.QUALITY_NAMES.size() - 1)]
		var quality_color: Color = ItemInstance.QUALITY_COLORS[clampi(_quest.reward_quality, 0, ItemInstance.QUALITY_COLORS.size() - 1)]

		var reward_text := Label.new()
		reward_text.text = "%s %s (%s)" % [quality_name, reward_name, quality_name]
		reward_text.add_theme_color_override("font_color", quality_color)
		reward_text.add_theme_font_size_override("font_size", GameContext.fs(13))
		vbox.add_child(reward_text)

		# Buttons
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 20)
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(btn_row)

		var accept_btn := Button.new()
		accept_btn.text = "Accept Quest"
		accept_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		accept_btn.pressed.connect(_on_accept)
		btn_row.add_child(accept_btn)

		var decline_btn := Button.new()
		decline_btn.text = "Decline"
		decline_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		decline_btn.pressed.connect(_on_decline)
		btn_row.add_child(decline_btn)

	func _on_accept() -> void:
		GameContext.add_side_quest(_quest)
		quest_resolved.emit(true)
		queue_free()

	func _on_decline() -> void:
		quest_resolved.emit(false)
		queue_free()


# ==========================================================================
# INNER CLASS: Quest Complete Panel
# ==========================================================================

class _QuestCompletePanel extends CanvasLayer:
	signal reward_collected

	const BG_COLOR := Color(0.05, 0.1, 0.05, 0.97)
	const BORDER_COLOR := Color(0.25, 0.85, 0.35, 0.9)
	const HEADER_COLOR := Color(0.35, 1.0, 0.5, 1.0)
	const BODY_COLOR := Color(0.9, 0.95, 0.9, 1.0)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
	const PANEL_WIDTH := 450

	var _quest: SideQuestData

	func _init(quest: SideQuestData) -> void:
		_quest = quest
		layer = 10
		name = "QuestCompletePanel"

	func _ready() -> void:
		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.color = BACKDROP_COLOR
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(backdrop)

		# Center
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		# Panel
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = BORDER_COLOR
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 20.0
		style.content_margin_top = 16.0
		style.content_margin_right = 20.0
		style.content_margin_bottom = 16.0
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		center.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		panel.add_child(vbox)

		# Header
		var header := Label.new()
		header.text = "Quest Complete!"
		header.add_theme_color_override("font_color", HEADER_COLOR)
		header.add_theme_font_size_override("font_size", GameContext.fs(20))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(header)

		# Quest name
		var title := Label.new()
		title.text = _quest.display_name
		title.add_theme_color_override("font_color", Color.WHITE)
		title.add_theme_font_size_override("font_size", GameContext.fs(14))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)

		# Reward
		var reward_tmpl = DataRegistry.get_item_template(_quest.reward_item_id)
		var reward_name: String = reward_tmpl.display_name if reward_tmpl != null else _quest.reward_item_id
		var quality_prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(_quest.reward_quality, 0, ItemInstance.QUALITY_PREFIXES.size() - 1)]
		var quality_color: Color = ItemInstance.QUALITY_COLORS[clampi(_quest.reward_quality, 0, ItemInstance.QUALITY_COLORS.size() - 1)]

		var reward_label := Label.new()
		reward_label.text = "Reward: %s%s" % [quality_prefix, reward_name]
		reward_label.add_theme_color_override("font_color", quality_color)
		reward_label.add_theme_font_size_override("font_size", GameContext.fs(15))
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(reward_label)

		var note := Label.new()
		note.text = "(Added to Storage)"
		note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		note.add_theme_font_size_override("font_size", GameContext.fs(11))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(note)

		# Collect button
		var collect_btn := Button.new()
		collect_btn.text = "Collect Reward"
		collect_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		collect_btn.pressed.connect(_on_collect)
		vbox.add_child(collect_btn)

	func _on_collect() -> void:
		SideQuestSystem.complete_quest(_quest.quest_id)
		reward_collected.emit()
		queue_free()


# ==========================================================================
# INNER CLASS: Quest Log Panel
# ==========================================================================

class _QuestLogPanel extends CanvasLayer:
	signal quest_log_closed

	const BG_COLOR := Color(0.08, 0.06, 0.12, 0.97)
	const BORDER_COLOR := Color(0.6, 0.5, 0.3, 0.9)
	const HEADER_COLOR := Color(1.0, 0.85, 0.5, 1.0)
	const SECTION_COLOR := Color(0.7, 0.85, 1.0, 1.0)
	const BODY_COLOR := Color(0.85, 0.85, 0.85, 1.0)
	const BACKDROP_COLOR := Color(0.0, 0.0, 0.0, 0.65)
	const PANEL_WIDTH := 550

	func _init() -> void:
		layer = 10
		name = "QuestLogPanel"

	func _ready() -> void:
		# Backdrop
		var backdrop := ColorRect.new()
		backdrop.color = BACKDROP_COLOR
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(backdrop)

		# Center
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(center)

		# Panel
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = BG_COLOR
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = BORDER_COLOR
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 20.0
		style.content_margin_top = 16.0
		style.content_margin_right = 20.0
		style.content_margin_bottom = 16.0
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
		center.add_child(panel)

		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 400)
		panel.add_child(scroll)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)

		# Title
		var title := Label.new()
		title.text = "Quest Log"
		title.add_theme_color_override("font_color", HEADER_COLOR)
		title.add_theme_font_size_override("font_size", GameContext.fs(20))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)

		# === MAIN STORY SECTION ===
		var story_header := Label.new()
		story_header.text = "--- Main Story ---"
		story_header.add_theme_color_override("font_color", SECTION_COLOR)
		story_header.add_theme_font_size_override("font_size", GameContext.fs(15))
		story_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(story_header)

		var story_info: Dictionary = SideQuestSystem.get_main_story_objective()

		var region_label := Label.new()
		region_label.text = story_info.get("region", "")
		region_label.add_theme_color_override("font_color", HEADER_COLOR)
		region_label.add_theme_font_size_override("font_size", GameContext.fs(14))
		vbox.add_child(region_label)

		var objective_label := Label.new()
		objective_label.text = story_info.get("objective", "")
		objective_label.add_theme_color_override("font_color", Color.WHITE)
		objective_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(objective_label)

		var context_label := Label.new()
		context_label.text = story_info.get("context", "")
		context_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		context_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(context_label)

		# === SIDE QUESTS SECTION ===
		var side_header := Label.new()
		side_header.text = "--- Side Quests ---"
		side_header.add_theme_color_override("font_color", SECTION_COLOR)
		side_header.add_theme_font_size_override("font_size", GameContext.fs(15))
		side_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(side_header)

		var quests: Array = GameContext.get_active_side_quests()
		if quests.is_empty():
			var none_label := Label.new()
			none_label.text = "No active side quests."
			none_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			none_label.add_theme_font_size_override("font_size", GameContext.fs(12))
			vbox.add_child(none_label)
		else:
			for quest in quests:
				if not quest is SideQuestData:
					continue
				_add_quest_entry(vbox, quest)

		# Close button
		var close_btn := Button.new()
		close_btn.text = "Close"
		close_btn.add_theme_font_size_override("font_size", GameContext.fs(14))
		close_btn.pressed.connect(_on_close)
		vbox.add_child(close_btn)

	func _add_quest_entry(parent: VBoxContainer, quest: SideQuestData) -> void:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		parent.add_child(entry)

		# Quest name with type badge
		var type_badge: String = "[Kill]" if quest.quest_type == "kill" else ("[Resupply]" if quest.quest_type == "resupply" else "[Mini-Dungeon]")
		var name_label := Label.new()
		name_label.text = "%s %s" % [type_badge, quest.display_name]
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_font_size_override("font_size", GameContext.fs(13))
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(name_label)

		# Progress
		var progress_label := Label.new()
		progress_label.text = quest.get_progress_text()
		progress_label.add_theme_color_override("font_color", BODY_COLOR)
		progress_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_child(progress_label)

		# Mini-dungeon: "Enter" button (only if not completed and has party)
		if quest.quest_type == "mini_dungeon" and not quest.mini_dungeon_completed:
			var enter_btn := Button.new()
			enter_btn.text = "Enter Mini-Dungeon"
			enter_btn.add_theme_font_size_override("font_size", GameContext.fs(12))
			var quest_id: String = quest.quest_id
			enter_btn.pressed.connect(func(): _on_enter_mini_dungeon(quest_id))
			entry.add_child(enter_btn)

		# Reward preview
		var reward_tmpl = DataRegistry.get_item_template(quest.reward_item_id)
		var reward_name: String = reward_tmpl.display_name if reward_tmpl != null else quest.reward_item_id
		var quality_prefix: String = ItemInstance.QUALITY_PREFIXES[clampi(quest.reward_quality, 0, ItemInstance.QUALITY_PREFIXES.size() - 1)]
		var quality_color: Color = ItemInstance.QUALITY_COLORS[clampi(quest.reward_quality, 0, ItemInstance.QUALITY_COLORS.size() - 1)]

		var reward_label := Label.new()
		reward_label.text = "Reward: %s%s" % [quality_prefix, reward_name]
		reward_label.add_theme_color_override("font_color", quality_color)
		reward_label.add_theme_font_size_override("font_size", GameContext.fs(11))
		entry.add_child(reward_label)

		# Separator
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 4)
		parent.add_child(sep)

	func _on_enter_mini_dungeon(quest_id: String) -> void:
		quest_log_closed.emit()
		SideQuestSystem.start_mini_dungeon(quest_id, self)
		queue_free()

	func _on_close() -> void:
		quest_log_closed.emit()
		queue_free()

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_close()
