extends Node
var _seed = 1
var seeded_rng = DeterministicRNG.new()


func start_with_base_seed():
	seeded_rng.reset(_seed)
