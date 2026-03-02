## BossCutsceneData.gd
## Data container for a boss cutscene entry (entry/victory/defeat).
## Loaded from Data/Cutscenes/boss_cutscene_r{1-7}.json.
class_name BossCutsceneData
extends RefCounted


var id: String = ""                  # "boss_entry_r1", "boss_victory_r3", etc.
var region_id: String = ""           # "region_1"
var boss_id: String = ""             # "thorn_ent"
var boss_name: String = ""           # "Thorn-Ent"
var trigger_type: String = ""        # "boss_entry", "boss_victory", "boss_defeat"
var flag_set: String = ""            # campaign flag to set on completion (empty = none)
var once_only: bool = true           # if true, flag_set gates re-showing
var bgm: String = ""                 # BGM key override (empty = keep current)
var panels: Array = []               # Array of panel dicts for CutscenePlayer


static func from_dict(data: Dictionary, region: String, boss: String, boss_display_name: String) -> BossCutsceneData:
	var inst := BossCutsceneData.new()
	inst.id = data.get("id", "")
	inst.region_id = region
	inst.boss_id = boss
	inst.boss_name = boss_display_name
	inst.trigger_type = data.get("trigger_type", "")
	var fs = data.get("flag_set", null)
	inst.flag_set = "" if fs == null else str(fs)
	inst.once_only = data.get("once_only", true)
	var bgm_val = data.get("bgm", null)
	inst.bgm = "" if bgm_val == null else str(bgm_val)
	inst.panels = data.get("panels", [])
	return inst


func is_valid() -> bool:
	return id != "" and trigger_type != "" and panels.size() > 0
