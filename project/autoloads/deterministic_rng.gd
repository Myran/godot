class_name DeterministicRNG extends Resource

var _initial_seed: int
var _current_state: int
var _result_sequence: Array[int]
var _rng: RandomNumberGenerator


func _init(new_seed: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if new_seed == 0:
		new_seed = randi()
	reset(new_seed)


func reset(new_seed: int = 0, hard: bool = false) -> void:
	if hard:
		new_seed = randi()
	if new_seed != 0:
		_initial_seed = new_seed

	_rng.seed = _initial_seed
	_result_sequence.clear()
	_current_state = _rng.state


func next() -> int:
	var random_integer: int = _rng.randi()
	_current_state = _rng.state
	_result_sequence.append(random_integer)
	return random_integer


func get_at_index(index: int) -> int:
	while index >= _result_sequence.size():
		next()
	return _result_sequence[index]


func save_state() -> String:
	var state: Dictionary = {"initial_seed": _initial_seed, "current_state": _current_state}
	return JSON.stringify(state)


func load_state(json_state: String) -> void:
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_state)
	if error == OK:
		var data: Variant = json.get_data()
		if data is Dictionary:
			_initial_seed = data.get("initial_seed", 0)
			var loaded_state: int = data.get("current_state", 0)
			reset(_initial_seed)
			while _current_state != loaded_state:
				next()
		else:
			Log.error("Unexpected data format when loading RNG state", {"data_type": typeof(data)}, [Log.TAG_RNG, Log.TAG_ERROR])
	else:
		Log.error(
			"JSON Parse Error when loading RNG state", 
			{
				"error": json.get_error_message(),
				"json": json_state,
				"line": json.get_error_line()
			}, 
			[Log.TAG_RNG, Log.TAG_ERROR]
		)
