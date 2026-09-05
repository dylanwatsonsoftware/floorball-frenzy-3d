extends SceneTree


func _init() -> void:
	var buffer_script = load("res://scripts/network/remote_snapshot_buffer.gd")
	if buffer_script == null:
		fail("Remote actors need a timestamped interpolation buffer")
		return
	var buffer = buffer_script.new()
	buffer.push(1000, Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 0.0)
	buffer.push(1100, Vector3(1.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), PI * 0.5)
	var midpoint: Dictionary = buffer.sample(1050)
	if not midpoint.position.is_equal_approx(Vector3(0.5, 0.0, 0.0)) or absf(midpoint.rotation - PI * 0.25) > 0.001:
		fail("Remote snapshots must interpolate position and rotation by host timestamp; got %s" % midpoint)
		return
	buffer.push(1025, Vector3(0.25, 0.0, 0.0), Vector3(10.0, 0.0, 0.0), PI * 0.25)
	var reordered: Dictionary = buffer.sample(1062)
	if float(reordered.position.x) < 0.60 or float(reordered.position.x) > 0.64:
		fail("Out-of-order snapshots must be sorted instead of moving a replica backward; got %s" % reordered)
		return
	var short_gap: Dictionary = buffer.sample(1160)
	if float(short_gap.position.x) <= 1.0 or float(short_gap.position.x) > 1.61:
		fail("Short packet gaps should extrapolate from the newest velocity; got %s" % short_gap)
		return
	var long_gap: Dictionary = buffer.sample(1600)
	if float(long_gap.position.x) > 2.01 or not long_gap.velocity.is_zero_approx():
		fail("Long packet gaps must stop bounded extrapolation rather than drift indefinitely; got %s" % long_gap)
		return
	print("Remote snapshot interpolation handles jitter, reordering, and burst gaps.")
	quit(0)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
