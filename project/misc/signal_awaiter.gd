class_name SignalAwaiter extends Node

signal finished


func add(_signal: Signal) -> SignalAwaiter:
	_signal.connect(_on_signal_received.bind(_signal), CONNECT_ONE_SHOT)
	return self


func _on_signal_received(_signal: Signal) -> void:
	push_error("Method not implemented")
	_emit_deferred()


func _emit_deferred() -> void:
	call_deferred("emit_signal", "finished")
	queue_free()


class Any:
	extends SignalAwaiter

	func _on_signal_received(_signal: Signal) -> void:
		_emit_deferred()


class Count:
	extends SignalAwaiter
	var _connections: int

	func _init(count: int):
		_connections = count

	func _on_signal_received(_signal: Signal) -> void:
		if get_incoming_connections().size() == _connections:
			_emit_deferred()


class All:
	extends Count

	func _init():
		super(0)


class SequenceBreak:
	extends SignalAwaiter
	var _signals: Array[Signal]

	func _init(signals: Array[Signal]):
		_signals = signals

	func _on_signal_received(_signal: Signal) -> void:
		if _signal != _signals[0]:
			_emit_deferred()


class SequenceMatch:
	extends SequenceBreak

	func _on_signal_received(_signal: Signal) -> void:
		if _signal == _signals[0]:
			_signals.remove_at(0)
			if _signals.is_empty():
				_emit_deferred()

# Usage:
# await SignalAwaiter.SequenceBreak.new([...]).finished
# await SignalAwaiter.SequenceMatch.new([...]).finished
