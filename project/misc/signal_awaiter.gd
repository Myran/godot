class_name SignalAwaiter extends Node

signal finished


func _init():
	Engine.get_main_loop().root.add_child(self)


func add(_signal: Signal) -> SignalAwaiter:
	_signal.connect(_on_signal_received.bind(_signal), CONNECT_ONE_SHOT)
	return self


func finish() -> void:
	finished.emit()
	queue_free()


func _on_signal_received(_signal: Signal) -> void:
	push_error("Method not implemented")
	finish()


class Any:
	extends SignalAwaiter

	func _on_signal_received(_signal: Signal) -> void:
		finish()


class Count:
	extends SignalAwaiter
	var _connections: int

	func _init(count: int):
		super()
		_connections = count

	func _on_signal_received(_signal: Signal) -> void:
		if get_incoming_connections().size() == _connections:
			finish()


class All:
	extends Count

	func _init():
		super(0)


class SequenceBreak:
	extends SignalAwaiter
	var _signals: Array[Signal]

	func _init(signals: Array[Signal]):
		super()
		_signals = signals

	func _on_signal_received(_signal: Signal) -> void:
		if _signal != _signals[0]:
			finish()


class SequenceMatch:
	extends SequenceBreak

	func _on_signal_received(_signal: Signal) -> void:
		if _signal == _signals[0]:
			_signals.remove_at(0)
			if _signals.is_empty():
				finish()
