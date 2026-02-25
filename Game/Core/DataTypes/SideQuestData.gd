## SideQuestData.gd
## Data container for a side quest instance with serialization.
class_name SideQuestData
extends RefCounted

var quest_id: String = ""          # Unique ID: "sq_{region}_{type}_{counter}"
var quest_type: String = ""        # "kill", "resupply", "mini_dungeon"
var region_id: String = ""         # "region_1" through "region_7"
var display_name: String = ""      # "Hunt: Slay 8 Wolves"
var description: String = ""       # Flavor text

# Kill quest specifics
var kill_targets: Dictionary = {}  # { "wolf": 5, "goblin": 3 }
var kill_progress: Dictionary = {} # { "wolf": 2, "goblin": 0 }

# Resupply quest specifics
var required_items: Dictionary = {} # { "wood_bundle": 5, "herb_sprig": 3 }

# Mini-dungeon specifics
var mini_dungeon_fights: int = 0   # Number of elite fights (2-3)
var mini_dungeon_completed: bool = false

# Reward (pre-rolled at quest creation)
var reward_item_id: String = ""
var reward_quality: int = 2        # 2=Rare, 3=Epic

# State
var is_complete: bool = false


## Check whether this quest's objectives are met.
func check_completion() -> bool:
	match quest_type:
		"kill":
			for target_id in kill_targets:
				var needed: int = int(kill_targets[target_id])
				var done: int = int(kill_progress.get(target_id, 0))
				if done < needed:
					return false
			is_complete = true
			return true
		"resupply":
			for item_id in required_items:
				var needed: int = int(required_items[item_id])
				var have: int = GameContext.get_run_item_count(item_id)
				if have < needed:
					return false
			is_complete = true
			return true
		"mini_dungeon":
			if mini_dungeon_completed:
				is_complete = true
				return true
			return false
	return false


## Record a monster kill for kill quests.
## Returns true if this kill advanced progress.
func record_kill(monster_id: String) -> bool:
	if quest_type != "kill":
		return false
	if not kill_targets.has(monster_id):
		return false
	var current: int = int(kill_progress.get(monster_id, 0))
	var needed: int = int(kill_targets[monster_id])
	if current >= needed:
		return false
	kill_progress[monster_id] = current + 1
	print("[SideQuest] Kill progress: %s %d/%d (quest=%s)" % [
		monster_id, current + 1, needed, quest_id])
	return true


## Get progress summary string for display.
func get_progress_text() -> String:
	match quest_type:
		"kill":
			var parts: Array = []
			for target_id in kill_targets:
				var needed: int = int(kill_targets[target_id])
				var done: int = int(kill_progress.get(target_id, 0))
				var tmpl = DataRegistry.get_monster(target_id)
				var dname: String = tmpl.display_name if tmpl != null else target_id
				parts.append("%s: %d/%d" % [dname, done, needed])
			return "\n".join(parts)
		"resupply":
			var parts: Array = []
			for item_id in required_items:
				var needed: int = int(required_items[item_id])
				var have: int = GameContext.get_run_item_count(item_id)
				var tmpl = DataRegistry.get_item_template(item_id)
				var dname: String = tmpl.display_name if tmpl != null else item_id
				parts.append("%s: %d/%d" % [dname, have, needed])
			return "\n".join(parts)
		"mini_dungeon":
			if mini_dungeon_completed:
				return "Completed"
			return "Enter Mini-Dungeon (%d fights)" % mini_dungeon_fights
	return ""


## Serialize to dictionary for save_game.
func to_dict() -> Dictionary:
	return {
		"quest_id": quest_id,
		"quest_type": quest_type,
		"region_id": region_id,
		"display_name": display_name,
		"description": description,
		"kill_targets": kill_targets,
		"kill_progress": kill_progress,
		"required_items": required_items,
		"mini_dungeon_fights": mini_dungeon_fights,
		"mini_dungeon_completed": mini_dungeon_completed,
		"reward_item_id": reward_item_id,
		"reward_quality": reward_quality,
		"is_complete": is_complete
	}


## Factory: create from saved dictionary.
static func from_dict(d: Dictionary) -> SideQuestData:
	var q = SideQuestData.new()
	q.quest_id = d.get("quest_id", "")
	q.quest_type = d.get("quest_type", "")
	q.region_id = d.get("region_id", "")
	q.display_name = d.get("display_name", "")
	q.description = d.get("description", "")
	var kt = d.get("kill_targets", {})
	q.kill_targets = kt if kt is Dictionary else {}
	var kp = d.get("kill_progress", {})
	q.kill_progress = kp if kp is Dictionary else {}
	var ri = d.get("required_items", {})
	q.required_items = ri if ri is Dictionary else {}
	q.mini_dungeon_fights = int(d.get("mini_dungeon_fights", 0))
	q.mini_dungeon_completed = d.get("mini_dungeon_completed", false)
	q.reward_item_id = d.get("reward_item_id", "")
	q.reward_quality = int(d.get("reward_quality", 2))
	q.is_complete = d.get("is_complete", false)
	return q


func _to_string() -> String:
	return "SideQuest(%s: %s [%s] complete=%s)" % [quest_id, quest_type, region_id, str(is_complete)]
