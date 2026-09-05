class_name NetworkTrace
extends RefCounted


const OnlineInputScript = preload("res://scripts/network/online_input.gd")
const FORMAT_VERSION := 1
const DEFAULT_MAX_ENTRIES := 3600

var _max_entries: int
var _entries: Array = []


func _init(max_entries: int = DEFAULT_MAX_ENTRIES) -> void:
	_max_entries = maxi(1, max_entries)


func record_command(command: Dictionary, local_time_ms: int) -> void:
	_append(&"command", command, local_time_ms)


func record_snapshot(snapshot: Dictionary, local_time_ms: int) -> void:
	_append(&"snapshot", snapshot, local_time_ms)


func entry_count() -> int:
	return _entries.size()


func entries() -> Array:
	return _entries.duplicate(true)


func to_json() -> String:
	return JSON.stringify({"format": "floorball-network-trace", "version": FORMAT_VERSION, "entries": _entries})


static func from_json(encoded: String) -> RefCounted:
	var decoded = JSON.parse_string(encoded)
	if not decoded is Dictionary or String(decoded.get("format", "")) != "floorball-network-trace" or int(decoded.get("version", 0)) != FORMAT_VERSION:
		return null
	var trace = new(maxi(1, (decoded.get("entries", []) as Array).size()))
	trace._entries = (decoded.get("entries", []) as Array).duplicate(true)
	return trace


func replay_commands(initial_state: Dictionary) -> Dictionary:
	var commands: Array = []
	for entry: Dictionary in _entries:
		if StringName(entry.get("kind", &"")) == &"command":
			commands.append(_restore(entry.get("data", {})))
	return OnlineInputScript.replay_player_commands(initial_state, commands)


func _append(kind: StringName, data: Dictionary, local_time_ms: int) -> void:
	_entries.append({"kind": String(kind), "time_ms": local_time_ms, "data": _portable(data)})
	while _entries.size() > _max_entries:
		_entries.pop_front()


static func _portable(value: Variant) -> Variant:
	if value is Vector2:
		return {"__vector2": [value.x, value.y]}
	if value is Vector3:
		return {"__vector3": [value.x, value.y, value.z]}
	if value is Dictionary:
		var converted := {}
		for key: Variant in value:
			converted[String(key)] = _portable(value[key])
		return converted
	if value is Array:
		var converted: Array = []
		for item: Variant in value:
			converted.append(_portable(item))
		return converted
	return value


static func _restore(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__vector2"):
			var vector2: Array = value.__vector2
			return Vector2(float(vector2[0]), float(vector2[1]))
		if value.has("__vector3"):
			var vector3: Array = value.__vector3
			return Vector3(float(vector3[0]), float(vector3[1]), float(vector3[2]))
		var restored := {}
		for key: Variant in value:
			restored[key] = _restore(value[key])
		return restored
	if value is Array:
		var restored: Array = []
		for item: Variant in value:
			restored.append(_restore(item))
		return restored
	return value
