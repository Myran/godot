class_name SignalAwaiter extends Node

# Added signal typing to indicate it emits no arguments
signal finished


func _init() -> void:  # Added return type
	var win: Window = Engine.get_main_loop().root
	win.call_deferred('add_child',self)


# Added Signal type to indicate godot built-in Signal class
func add(_signal: Signal) -> SignalAwaiter:  # Added return type
	@warning_ignore("return_value_discarded")
	_signal.connect(_on_signal_received.bind(_signal), CONNECT_ONE_SHOT)
	return self


func finish() -> void:  # Added return type
	finished.emit()
	queue_free()


func _on_signal_received(_signal: Signal) -> void:  # Added param and return type
	Log.error("Method not implemented in SignalAwaiter base class", {"method": "_on_signal_received"}, [Log.TAG_ERROR])
	finish()


# Changed inner classes to properly extend base class and add typing
class Any:
	extends SignalAwaiter

	func _on_signal_received(_signal: Signal) -> void:  # Added param and return type
		finish()


class Count:
	extends SignalAwaiter
	var _connections: int  # Added type hint

	func _init(count: int) -> void:  # Added param and return type
		super()
		_connections = count

	func _on_signal_received(_signal: Signal) -> void:  # Added param and return type
		if get_incoming_connections().size() == _connections:
			finish()


class All:
	extends Count

	func _init() -> void:  # Added return type
		super(0)


class SequenceBreak:
	extends SignalAwaiter
	var _signals: Array[Signal]  # Added typed array

	func _init(signals: Array[Signal]) -> void:  # Added typed array param
		super()
		_signals = signals

	func _on_signal_received(_signal: Signal) -> void:  # Added param and return type
		if _signal != _signals[0]:
			finish()


class SequenceMatch:
	extends SequenceBreak

	func _on_signal_received(_signal: Signal) -> void:  # Added param and return type
		if _signal == _signals[0]:
			_signals.remove_at(0)
			if _signals.is_empty():
				finish()
