class_name HeatSystem
extends RefCounted

const MAX_HEAT := 100.0
const DECAY_PER_SECOND := 2.0
const EN_FUEGO_SECONDS := 8.0
const EN_FUEGO_SPEED_MULTIPLIER := 1.2


static func add_heat(heat: float, fuego_remaining: float, amount: float) -> Dictionary:
	if fuego_remaining > 0.0:
		return _result(MAX_HEAT, fuego_remaining, false)
	var next_heat := clampf(heat + amount, 0.0, MAX_HEAT)
	var activated := next_heat >= MAX_HEAT
	return _result(next_heat, EN_FUEGO_SECONDS if activated else 0.0, activated)


static func activate() -> Dictionary:
	return _result(MAX_HEAT, EN_FUEGO_SECONDS, true)


static func step(heat: float, fuego_remaining: float, delta: float) -> Dictionary:
	if fuego_remaining > 0.0:
		var next_fuego := maxf(0.0, fuego_remaining - delta)
		return _result(MAX_HEAT if next_fuego > 0.0 else 0.0, next_fuego, false)
	return _result(maxf(0.0, heat - DECAY_PER_SECOND * delta), 0.0, false)


static func speed_multiplier(fuego_remaining: float) -> float:
	return EN_FUEGO_SPEED_MULTIPLIER if fuego_remaining > 0.0 else 1.0


static func _result(heat: float, fuego_remaining: float, activated: bool) -> Dictionary:
	return {
		"heat": heat,
		"fuego_remaining": fuego_remaining,
		"activated": activated,
	}
