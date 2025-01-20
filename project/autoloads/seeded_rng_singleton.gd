extends Node

var seeded_rng: DeterministicRNG = DeterministicRNG.new()
var _seed: int = 1


func start_with_base_seed() -> void:
	seeded_rng.reset(_seed)
