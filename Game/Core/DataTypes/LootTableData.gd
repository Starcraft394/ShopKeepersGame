## LootTableData.gd
## Data container for loot table definitions.
class_name LootTableData
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var min_drops: int = 1
var max_drops: int = 1
var entries: Array = []  # Array of { item_id, weight, min_qty, max_qty }


static func from_dict(data: Dictionary) -> LootTableData:
	var instance = LootTableData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")
	instance.min_drops = data.get("min_drops", 1)
	instance.max_drops = data.get("max_drops", 1)

	var raw_entries = data.get("entries", [])
	instance.entries.clear()
	if raw_entries is Array:
		for e in raw_entries:
			if e is Dictionary:
				instance.entries.append(e)

	return instance


func is_valid() -> bool:
	return id != "" and display_name != "" and not entries.is_empty()
