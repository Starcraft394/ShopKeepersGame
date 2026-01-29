## EventData.gd
## Data container for dungeon event definitions.
## Events can be "choice" (player picks option) or "auto" (immediate effect).
class_name EventData
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
var kind: String = "choice"  # "choice" or "auto"
var choices: Array = []  # Array of choice dictionaries
var tags: Array[String] = []  # For future filtering

# Choice structure:
# {
#   "id": String,
#   "label": String,
#   "description": String (optional),
#   "weight": float (default 1.0),
#   "effects": Array of effect dictionaries,
#   "requirements": Dictionary (optional),
#   "risk": Dictionary (optional)
# }

# Effect types:
# { "type": "add_gold", "amount": int }
# { "type": "add_gold_range", "min": int, "max": int }
# { "type": "add_item", "item_id": String, "min_qty": int, "max_qty": int }
# { "type": "lose_gold", "min": int, "max": int }
# { "type": "lose_item", "item_id": String, "qty": int }
# { "type": "lose_item_by_tag", "tag": String, "qty": int }
# { "type": "heal_party", "amount": int }
# { "type": "nothing" }


static func from_dict(data: Dictionary) -> EventData:
	var instance = EventData.new()
	instance.id = data.get("id", "")
	instance.title = data.get("title", "Unknown Event")
	instance.description = data.get("description", "")
	instance.kind = data.get("kind", "choice")

	# Parse choices
	var raw_choices = data.get("choices", [])
	instance.choices.clear()
	if raw_choices is Array:
		for c in raw_choices:
			if c is Dictionary:
				var choice = {
					"id": c.get("id", ""),
					"label": c.get("label", "Option"),
					"description": c.get("description", ""),
					"weight": c.get("weight", 1.0),
					"effects": c.get("effects", []),
					"requirements": c.get("requirements", {}),
					"risk": c.get("risk", {})
				}
				instance.choices.append(choice)

	# Parse tags
	instance.tags.clear()
	var raw_tags = data.get("tags", [])
	if raw_tags is Array:
		for t in raw_tags:
			instance.tags.append(str(t))

	return instance


func is_valid() -> bool:
	return id != "" and title != ""


func get_choice_by_id(choice_id: String) -> Dictionary:
	for choice in choices:
		if choice.get("id", "") == choice_id:
			return choice
	return {}


func has_choices() -> bool:
	return choices.size() > 0
