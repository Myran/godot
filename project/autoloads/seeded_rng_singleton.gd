extends Node

# Autonomous RNG seed initialization system
# Automatically reads seeds from debug configs during _ready()
# 
# Config format for deterministic tests:
# {
#   "checksum_config": {
#     "initial_seed": 12345
#   }
# }
# 
# NO EXPLICIT ACTIONS NEEDED - seeds are applied before game systems initialize

var seeded_rng: DeterministicRNG = DeterministicRNG.new(1)  # Force deterministic construction
var _seed: int = 1
var _seed_source: String = "default"


func _ready() -> void:
	# Autonomous seed configuration during autoload initialization
	# This happens before any game systems can consume RNG values
	var debug_seed: int = DebugConfigReader.get_debug_seed()
	
	if debug_seed != 12345:  # 12345 is the default fallback in DebugConfigReader
		_seed = debug_seed
		_seed_source = "debug_config"
		if Log:
			Log.info(
				"RNG autoload initialized with debug seed",
				{"seed": _seed, "source": _seed_source},
				["debug", "rng", "initialization", "config"]
			)
	else:
		# Check if we actually found a config with the default value vs no config
		var config_data: Dictionary = DebugConfigReader.get_full_config()
		if config_data.has("checksum_config") or config_data.has("seed"):
			_seed = debug_seed
			_seed_source = "debug_config_default"
			if Log:
				Log.info(
					"RNG autoload initialized with debug seed (default value)",
					{"seed": _seed, "source": _seed_source},
					["debug", "rng", "initialization", "config"]
				)
		else:
			_seed_source = "hardcoded_default"
			if Log:
				Log.info(
					"RNG autoload initialized with hardcoded default seed",
					{"seed": _seed, "source": _seed_source},
					["debug", "rng", "initialization"]
				)
	
	# Initialize the RNG immediately with the configured seed
	seeded_rng.reset(_seed)
	
	if Log:
		Log.info(
			"RNG autoload initialization complete",
			{
				"final_seed": _seed,
				"source": _seed_source,
				"initial_state": seeded_rng._current_state
			},
			["debug", "rng", "initialization", "complete"]
		)


func start_with_base_seed() -> void:
	# Legacy method - now a no-op since initialization happens in _ready()
	# Keep for backward compatibility but log usage
	Log.debug(
		"start_with_base_seed() called but RNG already initialized",
		{"current_seed": _seed, "source": _seed_source},
		["debug", "rng", "legacy"]
	)
