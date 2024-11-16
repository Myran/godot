extends Node

var seeded_rng = DeterministicRNG.new()
var _seed = 1


func start_with_base_seed():
	seeded_rng.reset(_seed)
