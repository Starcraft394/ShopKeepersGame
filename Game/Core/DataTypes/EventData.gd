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

# Choice structure (v2 — weighted outcomes):
# {
#   "id": String,
#   "label": String,
#   "description": String (optional),
#   "requires": Dictionary (optional),
#   "outcomes": Array of outcome dictionaries
# }
#
# Outcome structure:
# {
#   "weight": float (default 1.0),
#   "text": String — dialog/reaction text shown to player,
#   "effects": Array of effect dictionaries
# }

# Effect types:
# { "type": "add_gold", "amount": int }
# { "type": "add_gold_range", "min": int, "max": int }
# { "type": "add_item", "item_id": String, "min_qty": int, "max_qty": int }
# { "type": "lose_gold", "min": int, "max": int }
# { "type": "lose_item", "item_id": String, "qty": int }
# { "type": "heal_party", "amount": int }
# { "type": "heal_hero", "amount": int }
# { "type": "damage_party", "amount": int }
# { "type": "damage_hero", "amount": int }
# { "type": "apply_status", "status_id": String, "duration": int, "target": "random_hero"|"party" }
# { "type": "remove_equipment" }
# { "type": "trigger_combat", "encounter_type": "basic"|"elite" }
# { "type": "modifier", "id": String, "label": String, ... }
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
				var choice: Dictionary = {
					"id": c.get("id", ""),
					"label": c.get("label", "Option"),
					"description": c.get("description", ""),
					"requires": c.get("requires", c.get("requirements", {})),
					"outcomes": [],
				}
				# v2 schema: outcomes array
				var raw_outcomes = c.get("outcomes", [])
				if raw_outcomes is Array and raw_outcomes.size() > 0:
					for o in raw_outcomes:
						if o is Dictionary:
							choice.outcomes.append({
								"weight": float(o.get("weight", 1.0)),
								"text": o.get("text", ""),
								"effects": o.get("effects", []),
							})
				else:
					# Legacy v1 fallback: convert effects/risk/modifier to single outcome
					var legacy_effects: Array = c.get("effects", [])
					if legacy_effects.size() > 0 or c.has("risk") or c.has("modifier"):
						choice.outcomes.append({
							"weight": 100.0,
							"text": "",
							"effects": legacy_effects,
							"_legacy_risk": c.get("risk", {}),
							"_legacy_modifier": c.get("modifier", {}),
						})
				instance.choices.append(choice)

	# Parse tags
	instance.tags.clear()
	var raw_tags = data.get("tags", [])
	if raw_tags is Array:
		for t in raw_tags:
			instance.tags.append(str(t))

	return instance


## Roll a weighted random outcome from a choice's outcomes array.
static func roll_outcome(choice: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var outcomes: Array = choice.get("outcomes", [])
	if outcomes.is_empty():
		return {"weight": 100.0, "text": "Nothing happens.", "effects": [{"type": "nothing"}]}

	if outcomes.size() == 1:
		return outcomes[0]

	var total_weight: float = 0.0
	for outcome in outcomes:
		total_weight += float(outcome.get("weight", 1.0))

	if total_weight <= 0.0:
		return outcomes[0]

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for outcome in outcomes:
		cumulative += float(outcome.get("weight", 1.0))
		if roll < cumulative:
			return outcome

	return outcomes[outcomes.size() - 1]


func is_valid() -> bool:
	return id != "" and title != ""


func get_choice_by_id(choice_id: String) -> Dictionary:
	for choice in choices:
		if choice.get("id", "") == choice_id:
			return choice
	return {}


func has_choices() -> bool:
	return choices.size() > 0
