class_name LagCompensatedHitHistory
extends RefCounted


const MAX_SAMPLES := 40
const MAX_REWIND_MS := 300
const HIT_RADIUS := 0.9
const MAX_BALL_HEIGHT := 0.72

var _samples: Array[Dictionary] = []


func clear() -> void:
	_samples.clear()


func sample_count() -> int:
	return _samples.size()


func record(host_time_ms: int, actor_id: StringName, actor_position: Vector3, facing: Vector3, blade_position: Vector3, ball_position: Vector3, owner_id: StringName) -> void:
	var sample := {
		"time": host_time_ms,
		"actor_id": actor_id,
		"actor_position": actor_position,
		"facing": facing.normalized(),
		"blade_position": blade_position,
		"ball_position": ball_position,
		"owner_id": owner_id,
	}
	_samples.append(sample)
	while _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


func can_hit(actor_id: StringName, host_time_ms: int) -> bool:
	var state := _sample(actor_id, host_time_ms)
	if state.is_empty():
		return false
	var ball: Vector3 = state.ball_position
	var blade: Vector3 = state.blade_position
	if ball.y > MAX_BALL_HEIGHT or Vector2(ball.x, ball.z).distance_to(Vector2(blade.x, blade.z)) > HIT_RADIUS:
		return false
	var facing := Vector2(state.facing.x, state.facing.z).normalized()
	var relative := Vector2(ball.x - state.actor_position.x, ball.z - state.actor_position.z)
	return StringName(state.owner_id) == actor_id or (not facing.is_zero_approx() and relative.dot(facing) > 0.0)


func _sample(actor_id: StringName, host_time_ms: int) -> Dictionary:
	var actor_samples: Array[Dictionary] = []
	for sample: Dictionary in _samples:
		if StringName(sample.actor_id) == actor_id:
			actor_samples.append(sample)
	if actor_samples.is_empty():
		return {}
	var first: Dictionary = actor_samples.front()
	var latest: Dictionary = actor_samples.back()
	if host_time_ms < int(first.time) or host_time_ms > int(latest.time) or int(latest.time) - host_time_ms > MAX_REWIND_MS:
		return {}
	for index in range(1, actor_samples.size()):
		var next: Dictionary = actor_samples[index]
		if host_time_ms > int(next.time):
			continue
		var previous: Dictionary = actor_samples[index - 1]
		var span := maxi(1, int(next.time) - int(previous.time))
		var weight := clampf(float(host_time_ms - int(previous.time)) / float(span), 0.0, 1.0)
		return {
			"actor_position": previous.actor_position.lerp(next.actor_position, weight),
			"facing": previous.facing.lerp(next.facing, weight).normalized(),
			"blade_position": previous.blade_position.lerp(next.blade_position, weight),
			"ball_position": previous.ball_position.lerp(next.ball_position, weight),
			"owner_id": previous.owner_id if weight < 0.5 else next.owner_id,
		}
	return latest.duplicate()
