class_name CampaignDialogData
extends RefCounted
## Data container for a single campaign dialog entry.
## Loaded from Data/Campaign/campaign_dialog_r{1-7}.json.


var id: String = ""
var region: String = ""
var trigger: String = ""             # region_first_arrival|boss_first_kill|herald_visit|dungeon_camp_story|keeper_story
var flag_required: String = ""       # prerequisite campaign flag (empty = none)
var flag_set: String = ""            # flag to set on completion (empty = none)
var display_type: String = "full_screen_overlay"  # full_screen_overlay|portrait_text_box|event_popup
var dungeon_floor: int = -1          # for dungeon_camp_story (-1 = final floor before boss)
var speaker_id: String = ""
var speaker_name: String = ""
var speaker_portrait: String = ""    # res:// path or empty for no portrait
var lines: Array[String] = []
var min_ng_cycle: int = 0            # minimum NG+ cycle for this dialog to appear (0 = any)


static func from_dict(data: Dictionary, region_id: String) -> CampaignDialogData:
	var inst := CampaignDialogData.new()
	inst.id = data.get("id", "")
	inst.region = region_id
	inst.trigger = data.get("trigger", "")
	var fr = data.get("flag_required", null)
	inst.flag_required = "" if fr == null else str(fr)
	var fs = data.get("flag_set", null)
	inst.flag_set = "" if fs == null else str(fs)
	inst.display_type = data.get("display_type", "full_screen_overlay")
	inst.dungeon_floor = int(data.get("dungeon_floor", -1))
	var sid = data.get("speaker_id", null)
	inst.speaker_id = "" if sid == null else str(sid)
	var sn = data.get("speaker_name", null)
	inst.speaker_name = "" if sn == null else str(sn)
	var sp = data.get("speaker_portrait", null)
	inst.speaker_portrait = "" if sp == null else str(sp)
	inst.min_ng_cycle = int(data.get("min_ng_cycle", 0))
	var raw_lines = data.get("lines", [])
	if raw_lines is Array:
		for line in raw_lines:
			inst.lines.append(str(line))
	return inst


func is_valid() -> bool:
	return id != "" and trigger != "" and lines.size() > 0
