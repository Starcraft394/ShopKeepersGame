## EventTableData.gd
## Data container for event table definitions used in non-combat rooms.
## Each event table contains weighted entries that reference EventData definitions.
## Event tables are zone-specific (e.g., et_region1_forest, et_region1_lumber).
class_name EventTableData
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""

# Event entries: Array of Dictionaries with:
#   event_id: String - references an EventData definition
#   weight: float - selection weight (higher = more likely)
var entries: Array = []


static func from_dict(data: Dictionary) -> EventTableData:
	var instance = EventTableData.new()
	instance.id = data.get("id", "")
	instance.display_name = data.get("display_name", "")
	instance.description = data.get("description", "")

	var raw_entries = data.get("entries", [])
	instance.entries.clear()
	if raw_entries is Array:
		for e in raw_entries:
			if e is Dictionary:
				var entry = {
					"event_id": e.get("event_id", ""),
					"weight": float(e.get("weight", 1.0))
				}
				if entry.event_id != "":
					instance.entries.append(entry)

	return instance


func is_valid() -> bool:
	return id != "" and not entries.is_empty()


## Roll a random event_id from this table using the provided RNG.
## Returns the event_id string of the selected entry.
## Caller should use DataRegistry.get_event(event_id) to get full EventData.
func roll_event_id(rng: RandomNumberGenerator) -> String:
	if entries.is_empty():
		return ""

	# Build weighted selection array
	var total_weight: float = 0.0
	for entry in entries:
		total_weight += entry.get("weight", 1.0)

	if total_weight <= 0.0:
		return entries[0].get("event_id", "")

	var roll = rng.randf() * total_weight
	var cumulative: float = 0.0

	for entry in entries:
		cumulative += entry.get("weight", 1.0)
		if roll < cumulative:
			return entry.get("event_id", "")

	return entries[entries.size() - 1].get("event_id", "")


## Get all event_ids in this table (for validation/debugging).
func get_all_event_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		var event_id = entry.get("event_id", "")
		if event_id != "":
			ids.append(event_id)
	return ids
