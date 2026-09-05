class_name RemoteSnapshotBuffer
extends RefCounted


const MAX_SNAPSHOTS := 12
const MAX_EXTRAPOLATION_MS := 100

var _snapshots: Array[Dictionary] = []


func clear() -> void:
	_snapshots.clear()


func is_empty() -> bool:
	return _snapshots.is_empty()


func push(host_time_ms: int, position: Vector3, velocity: Vector3, rotation: float) -> void:
	var snapshot := {"time": host_time_ms, "position": position, "velocity": velocity, "rotation": rotation}
	for index in _snapshots.size():
		var existing_time := int(_snapshots[index].time)
		if existing_time == host_time_ms:
			_snapshots[index] = snapshot
			return
		if existing_time > host_time_ms:
			_snapshots.insert(index, snapshot)
			_trim()
			return
	_snapshots.append(snapshot)
	_trim()


func sample(host_time_ms: int) -> Dictionary:
	if _snapshots.is_empty():
		return {}
	var first: Dictionary = _snapshots.front()
	if host_time_ms <= int(first.time):
		return first.duplicate()
	for index in range(1, _snapshots.size()):
		var next: Dictionary = _snapshots[index]
		if host_time_ms > int(next.time):
			continue
		var previous: Dictionary = _snapshots[index - 1]
		var span := maxi(1, int(next.time) - int(previous.time))
		var weight := clampf(float(host_time_ms - int(previous.time)) / float(span), 0.0, 1.0)
		return {
			"time": host_time_ms,
			"position": previous.position.lerp(next.position, weight),
			"velocity": previous.velocity.lerp(next.velocity, weight),
			"rotation": lerp_angle(float(previous.rotation), float(next.rotation), weight),
		}
	var latest: Dictionary = _snapshots.back()
	var age_ms := maxi(0, host_time_ms - int(latest.time))
	var projected_ms := mini(age_ms, MAX_EXTRAPOLATION_MS)
	return {
		"time": host_time_ms,
		"position": latest.position + latest.velocity * (float(projected_ms) / 1000.0),
		"velocity": latest.velocity if age_ms <= MAX_EXTRAPOLATION_MS else Vector3.ZERO,
		"rotation": latest.rotation,
	}


func _trim() -> void:
	while _snapshots.size() > MAX_SNAPSHOTS:
		_snapshots.pop_front()
