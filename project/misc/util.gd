extends Node


static func connect_signal_assert(
	origin: Object, sig: String, target: Object, meth: String
) -> void:
	var err: Error = origin.connect(sig, Callable(target, meth))
	assert(err == OK)
