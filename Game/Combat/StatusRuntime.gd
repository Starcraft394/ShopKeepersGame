## StatusRuntime.gd
## Runtime tracking for status effects on a combat unit.
## Handles STUN (skip turns) and DOOM (stacks + countdown).
##
## Source: MVP_Milestones.md (M1), GDD Section 27, 39
class_name StatusRuntime
extends RefCounted

# ============================================================================
# STATUS INSTANCE
# ============================================================================

class StatusInstance:
	var effect_id: String = ""
	var stacks: int = 0
	var duration: int = 0      # For duration-based effects (STUN)
	var countdown: int = 0     # For countdown effects (DOOM)
	var source_unit_id: String = ""

	func _init(id: String, initial_stacks: int = 1, initial_duration: int = 1) -> void:
		effect_id = id
		stacks = initial_stacks
		duration = initial_duration
		countdown = initial_duration  # For DOOM, countdown starts at stacks

	func is_expired() -> bool:
		return stacks <= 0 and duration <= 0 and countdown <= 0

# ============================================================================
# STATE
# ============================================================================

var _statuses: Dictionary = {}  # effect_id -> StatusInstance
var _owner_id: String = ""

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(owner_id: String = "") -> void:
	_owner_id = owner_id

# ============================================================================
# PUBLIC API - STATUS APPLICATION
# ============================================================================

## Apply STUN effect. Duration-based, max 1 stack.
func apply_stun(duration: int, source_id: String = "") -> bool:
	if has_status("stun"):
		# Refresh duration if new is longer
		var existing = _statuses["stun"] as StatusInstance
		if duration > existing.duration:
			existing.duration = duration
			print("[StatusRuntime] %s: Stun refreshed to %d turns" % [_owner_id, duration])
		return true

	var instance = StatusInstance.new("stun", 1, duration)
	instance.source_unit_id = source_id
	_statuses["stun"] = instance
	print("[StatusRuntime] %s: Stunned for %d turns" % [_owner_id, duration])
	return true


## Apply DOOM effect using Option B: add-time-per-stack with MAX cap.
## If at max stacks -> no effect.
## Else: add stacks (up to max), add same amount to countdown.
func apply_doom(stacks_to_add: int, max_stacks: int, source_id: String = "") -> int:
	if stacks_to_add <= 0:
		return 0

	if has_status("doom"):
		var existing = _statuses["doom"] as StatusInstance
		if existing.stacks >= max_stacks:
			print("[StatusRuntime] %s: Doom at max (%d), no effect" % [_owner_id, max_stacks])
			return 0

		var add = mini(stacks_to_add, max_stacks - existing.stacks)
		existing.stacks += add
		existing.countdown += add
		print("[StatusRuntime] %s: Doom +%d stacks (now %d), countdown +%d (now %d)" % [
			_owner_id, add, existing.stacks, add, existing.countdown])
		return add
	else:
		var actual_stacks = mini(stacks_to_add, max_stacks)
		var instance = StatusInstance.new("doom", actual_stacks, 0)
		instance.countdown = actual_stacks
		instance.source_unit_id = source_id
		_statuses["doom"] = instance
		print("[StatusRuntime] %s: Doom applied: %d stacks, countdown %d" % [
			_owner_id, actual_stacks, actual_stacks])
		return actual_stacks


## Generic status application for other effects (DOT, buffs, etc.)
func apply_status(effect_id: String, stacks: int, duration: int, source_id: String = "") -> bool:
	if effect_id == "stun":
		return apply_stun(duration, source_id)

	if has_status(effect_id):
		var existing = _statuses[effect_id] as StatusInstance
		existing.stacks = mini(existing.stacks + stacks, 99)  # Generic max
		existing.duration = maxi(existing.duration, duration)
		return true

	var instance = StatusInstance.new(effect_id, stacks, duration)
	instance.source_unit_id = source_id
	_statuses[effect_id] = instance
	return true


# ============================================================================
# PUBLIC API - STATUS QUERIES
# ============================================================================

func has_status(effect_id: String) -> bool:
	return _statuses.has(effect_id)


func get_status(effect_id: String) -> StatusInstance:
	return _statuses.get(effect_id, null)


func is_stunned() -> bool:
	if not has_status("stun"):
		return false
	var stun = _statuses["stun"] as StatusInstance
	return stun.duration > 0


func get_doom_stacks() -> int:
	if not has_status("doom"):
		return 0
	return (_statuses["doom"] as StatusInstance).stacks


func get_doom_countdown() -> int:
	if not has_status("doom"):
		return 0
	return (_statuses["doom"] as StatusInstance).countdown


func get_all_statuses() -> Array:
	return _statuses.values()


# ============================================================================
# PUBLIC API - TURN PROCESSING
# ============================================================================

## Called when unit's turn starts. Returns true if unit can act.
func process_turn_start() -> bool:
	if is_stunned():
		var stun = _statuses["stun"] as StatusInstance
		stun.duration -= 1
		print("[StatusRuntime] %s: Stun consumed, %d turns remaining" % [_owner_id, stun.duration])
		if stun.duration <= 0:
			_statuses.erase("stun")
			print("[StatusRuntime] %s: Stun expired" % _owner_id)
		return false  # Cannot act
	return true  # Can act


## Called when unit's turn ends. Returns doom damage if triggered.
func process_turn_end() -> int:
	var doom_damage = 0

	# Process DOOM countdown
	if has_status("doom"):
		var doom = _statuses["doom"] as StatusInstance
		doom.countdown -= 1
		print("[StatusRuntime] %s: Doom countdown: %d" % [_owner_id, doom.countdown])

		if doom.countdown <= 0:
			# DOOM triggers! Get base damage from DataRegistry
			var doom_data = DataRegistry.get_status_effect("doom")
			var base_damage = 5  # Fallback
			if doom_data != null:
				base_damage = doom_data.base_value

			doom_damage = base_damage * doom.stacks
			print("[StatusRuntime] %s: DOOM TRIGGERS! %d stacks x %d base = %d damage" % [
				_owner_id, doom.stacks, base_damage, doom_damage])
			_statuses.erase("doom")

	# Process other duration-based effects
	var to_remove = []
	for effect_id in _statuses:
		if effect_id == "doom":
			continue  # Already handled
		var status = _statuses[effect_id] as StatusInstance
		if status.duration > 0:
			status.duration -= 1
			if status.duration <= 0 and status.stacks <= 0:
				to_remove.append(effect_id)

	for effect_id in to_remove:
		_statuses.erase(effect_id)
		print("[StatusRuntime] %s: %s expired" % [_owner_id, effect_id])

	return doom_damage


## Remove a specific status.
func remove_status(effect_id: String) -> bool:
	if _statuses.has(effect_id):
		_statuses.erase(effect_id)
		return true
	return false


## Clear all statuses.
func clear_all() -> void:
	_statuses.clear()


# ============================================================================
# DEBUG
# ============================================================================

func get_summary() -> String:
	if _statuses.is_empty():
		return "None"

	var parts = []
	for effect_id in _statuses:
		var status = _statuses[effect_id] as StatusInstance
		if effect_id == "doom":
			parts.append("Doom(%d stacks, %d countdown)" % [status.stacks, status.countdown])
		elif effect_id == "stun":
			parts.append("Stun(%d)" % status.duration)
		else:
			parts.append("%s(%d/%d)" % [effect_id, status.stacks, status.duration])
	return ", ".join(parts)
