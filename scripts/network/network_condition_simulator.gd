class_name NetworkConditionSimulator
extends RefCounted


var rtt_ms: int
var loss_rate: float
var jitter_ms: int
var seed: int


func _init(configured_rtt_ms: int = 0, configured_loss_rate: float = 0.0, configured_jitter_ms: int = 0, configured_seed: int = 1) -> void:
	rtt_ms = maxi(0, configured_rtt_ms)
	loss_rate = clampf(configured_loss_rate, 0.0, 1.0)
	jitter_ms = maxi(0, configured_jitter_ms)
	seed = configured_seed


func schedule(sequence: int, sent_at_ms: int) -> Dictionary:
	var random := RandomNumberGenerator.new()
	random.seed = hash([seed, sequence])
	var dropped := random.randf() < loss_rate
	var jitter := random.randi_range(-jitter_ms, jitter_ms)
	return {
		"dropped": dropped,
		"delivery_ms": sent_at_ms + maxi(0, roundi(float(rtt_ms) * 0.5) + jitter),
	}


static func profile(profile_name: StringName) -> Dictionary:
	match profile_name:
		&"good":
			return {"rtt_ms": 50, "loss_percent": 0.0, "jitter_ms": 5}
		&"typical":
			return {"rtt_ms": 100, "loss_percent": 1.0, "jitter_ms": 15}
		&"quality_gate":
			return {"rtt_ms": 150, "loss_percent": 2.0, "jitter_ms": 30}
		&"degraded":
			return {"rtt_ms": 250, "loss_percent": 5.0, "jitter_ms": 60}
		_:
			return {"rtt_ms": 0, "loss_percent": 0.0, "jitter_ms": 0}
