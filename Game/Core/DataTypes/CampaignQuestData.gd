## CampaignQuestData.gd
## Data container for a campaign quest instance with objectives, mission bag,
## and serialization. Campaign quests are linear (one active at a time) and
## chain automatically on completion.
class_name CampaignQuestData
extends RefCounted


# ============================================================================
# QUEST IDENTITY
# ============================================================================

var quest_id: String = ""            # "cq_r1_investigate", "cq_r2_rescue_npc", etc.
var region_id: String = ""           # "region_1" through "region_7"
var display_name: String = ""        # "Crown's First Assignment"
var description: String = ""         # Flavor text / briefing
var quest_type: String = ""          # "investigate", "rescue_npc", "retrieve_item", "collect_fragments", "confront"

# ============================================================================
# OBJECTIVES
# ============================================================================

## Array of objective dicts:
## { "id": "r1_kill_boss", "type": "kill_boss", "target_id": "thorn_ent",
##   "description": "Defeat the Thorn-Ent", "is_complete": false }
## Supported types: kill_boss, find_npc, collect_item, return_to_town
var objectives: Array = []

# ============================================================================
# MISSION BAG (hidden from player)
# ============================================================================

## Items collected during the quest (boss drops, event pickups).
## Array of dicts: { "item_id": "crown_artifact_strand", "qty": 1 }
var mission_bag: Array = []

# ============================================================================
# NPC RESCUE
# ============================================================================

var npc_id: String = ""              # NPC to rescue (for rescue_npc type)
var npc_name: String = ""            # Display name of NPC
var npc_found: bool = false          # Whether NPC has been found in dungeon

# ============================================================================
# REWARDS & CHAIN
# ============================================================================

var reward_gold: int = 0             # Gold awarded on completion
var reward_items: Array = []         # Array of item_id strings
var next_quest_id: String = ""       # Auto-chain to this quest on completion

# ============================================================================
# CAMPAIGN FLAGS
# ============================================================================

var flag_required: String = ""       # Must have this flag to start quest
var flag_set_on_complete: String = ""# Set this flag on completion

# ============================================================================
# DIALOG REFERENCES
# ============================================================================

var quest_given_dialog_id: String = ""    # CampaignDialog ID for quest assignment
var quest_complete_dialog_id: String = "" # CampaignDialog ID for quest turn-in

# ============================================================================
# STATE
# ============================================================================

var is_active: bool = false
var is_complete: bool = false


# ============================================================================
# OBJECTIVE MANAGEMENT
# ============================================================================

## Check whether all objectives are met.
func check_completion() -> bool:
	for obj in objectives:
		if not obj.get("is_complete", false):
			return false
	is_complete = true
	return true


## Mark a specific objective as complete by ID.
func complete_objective(objective_id: String) -> bool:
	for obj in objectives:
		if obj.get("id", "") == objective_id:
			if obj.get("is_complete", false):
				return false  # Already complete
			obj["is_complete"] = true
			print("[CampaignQuest] Objective complete: %s (%s)" % [objective_id, quest_id])
			return true
	return false


## Mark kill_boss objective for a specific boss.
func mark_boss_killed(boss_id: String) -> bool:
	for obj in objectives:
		if obj.get("type", "") == "kill_boss" and obj.get("target_id", "") == boss_id:
			if obj.get("is_complete", false):
				return false
			obj["is_complete"] = true
			print("[CampaignQuest] Boss killed: %s (%s)" % [boss_id, quest_id])
			return true
	return false


## Mark find_npc objective.
func mark_npc_found(found_npc_id: String) -> bool:
	if npc_id == "" or found_npc_id != npc_id:
		return false
	npc_found = true
	for obj in objectives:
		if obj.get("type", "") == "find_npc" and obj.get("target_id", "") == found_npc_id:
			obj["is_complete"] = true
			print("[CampaignQuest] NPC found: %s (%s)" % [found_npc_id, quest_id])
			return true
	return false


## Increment collect_item objective progress.
func add_collected_item(item_id: String, qty: int = 1) -> bool:
	var advanced: bool = false
	for obj in objectives:
		if obj.get("type", "") == "collect_item" and obj.get("target_id", "") == item_id:
			var current: int = int(obj.get("current_count", 0))
			var required: int = int(obj.get("required_count", 1))
			if current >= required:
				return false
			obj["current_count"] = mini(current + qty, required)
			if obj["current_count"] >= required:
				obj["is_complete"] = true
			print("[CampaignQuest] Collected %s: %d/%d (%s)" % [item_id, obj["current_count"], required, quest_id])
			advanced = true
	return advanced


## Mark return_to_town objective.
func mark_returned_to_town() -> bool:
	for obj in objectives:
		if obj.get("type", "") == "return_to_town":
			if obj.get("is_complete", false):
				return false
			obj["is_complete"] = true
			print("[CampaignQuest] Returned to town (%s)" % quest_id)
			return true
	return false


## Reset kill_boss objectives (boss respawns on re-entry after wipe).
func reset_boss_objectives() -> void:
	for obj in objectives:
		if obj.get("type", "") == "kill_boss":
			obj["is_complete"] = false


# ============================================================================
# MISSION BAG
# ============================================================================

## Add an item to the mission bag.
func add_to_mission_bag(item_id: String, qty: int = 1) -> void:
	for entry in mission_bag:
		if entry.get("item_id", "") == item_id:
			entry["qty"] = int(entry.get("qty", 0)) + qty
			print("[CampaignQuest] Mission bag +%d %s (total: %d)" % [qty, item_id, entry["qty"]])
			return
	mission_bag.append({"item_id": item_id, "qty": qty})
	print("[CampaignQuest] Mission bag +%d %s (new)" % [qty, item_id])


## Get count of an item in mission bag.
func get_mission_bag_count(item_id: String) -> int:
	for entry in mission_bag:
		if entry.get("item_id", "") == item_id:
			return int(entry.get("qty", 0))
	return 0


## Remove an item from the mission bag.
func remove_from_mission_bag(item_id: String, qty: int = 1) -> bool:
	for i in mission_bag.size():
		if mission_bag[i].get("item_id", "") == item_id:
			var current: int = int(mission_bag[i].get("qty", 0))
			if current <= qty:
				mission_bag.remove_at(i)
			else:
				mission_bag[i]["qty"] = current - qty
			return true
	return false


## Clear entire mission bag (on quest completion).
func clear_mission_bag() -> void:
	mission_bag.clear()


# ============================================================================
# PROGRESS TEXT
# ============================================================================

## Get progress summary for quest log display.
func get_progress_text() -> String:
	var parts: Array = []
	for obj in objectives:
		var desc: String = obj.get("description", "???")
		var done: bool = obj.get("is_complete", false)
		if obj.get("type", "") == "collect_item":
			var current: int = int(obj.get("current_count", 0))
			var required: int = int(obj.get("required_count", 1))
			parts.append("[%s] %s (%d/%d)" % ["X" if done else " ", desc, current, required])
		else:
			parts.append("[%s] %s" % ["X" if done else " ", desc])
	return "\n".join(parts)


# ============================================================================
# SERIALIZATION
# ============================================================================

func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"region_id": region_id,
		"display_name": display_name,
		"description": description,
		"quest_type": quest_type,
		"objectives": objectives.duplicate(true),
		"mission_bag": mission_bag.duplicate(true),
		"npc_id": npc_id,
		"npc_name": npc_name,
		"npc_found": npc_found,
		"reward_gold": reward_gold,
		"reward_items": reward_items.duplicate(),
		"next_quest_id": next_quest_id,
		"flag_required": flag_required,
		"flag_set_on_complete": flag_set_on_complete,
		"quest_given_dialog_id": quest_given_dialog_id,
		"quest_complete_dialog_id": quest_complete_dialog_id,
		"is_active": is_active,
		"is_complete": is_complete,
	}


static func from_dict(d: Dictionary) -> CampaignQuestData:
	var q := CampaignQuestData.new()
	q.quest_id = d.get("quest_id", "")
	q.region_id = d.get("region_id", "")
	q.display_name = d.get("display_name", "")
	q.description = d.get("description", "")
	q.quest_type = d.get("quest_type", "")
	var objs = d.get("objectives", [])
	q.objectives = objs.duplicate(true) if objs is Array else []
	var mb = d.get("mission_bag", [])
	q.mission_bag = mb.duplicate(true) if mb is Array else []
	q.npc_id = d.get("npc_id", "")
	q.npc_name = d.get("npc_name", "")
	q.npc_found = d.get("npc_found", false)
	q.reward_gold = int(d.get("reward_gold", 0))
	var ri = d.get("reward_items", [])
	q.reward_items = ri.duplicate() if ri is Array else []
	q.next_quest_id = d.get("next_quest_id", "")
	q.flag_required = d.get("flag_required", "")
	q.flag_set_on_complete = d.get("flag_set_on_complete", "")
	q.quest_given_dialog_id = d.get("quest_given_dialog_id", "")
	q.quest_complete_dialog_id = d.get("quest_complete_dialog_id", "")
	q.is_active = d.get("is_active", false)
	q.is_complete = d.get("is_complete", false)
	return q


func _to_string() -> String:
	return "CampaignQuest(%s: %s [%s] complete=%s)" % [quest_id, quest_type, region_id, str(is_complete)]
