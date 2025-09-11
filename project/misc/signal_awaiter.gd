class_name SignalAwaiter extends Node

signal finished


func _init() -> void:
	var win: Window = Engine.get_main_loop().root
	win.call_deferred("add_child", self)


func add(_signal: Signal) -> SignalAwaiter:
	@warning_ignore("return_value_discarded")
	_signal.connect(_on_signal_received.bind(_signal), CONNECT_ONE_SHOT)
	return self


func finish() -> void:
	finished.emit()
	queue_free()


func _on_signal_received(_signal_param = null, _signal = null) -> void:
	Log.error(
		"Method not implemented in SignalAwaiter base class",
		{"method": "_on_signal_received"},
		[Log.TAG_ERROR]
	)
	finish()


class Any:
	extends SignalAwaiter

	func _on_signal_received(_signal_param = null, _signal = null) -> void:
		finish()


class Count:
	extends SignalAwaiter
	var _connections: int

	func _init(count: int) -> void:
		super()
		_connections = count

	func _on_signal_received(_signal_param = null, _signal = null) -> void:
		if get_incoming_connections().size() == _connections:
			finish()


class All:
	extends Count

	func _init() -> void:
		super(0)


class SequenceBreak:
	extends SignalAwaiter
	var _signals: Array[Signal]

	func _init(signals: Array[Signal]) -> void:
		super()
		_signals = signals

	func _on_signal_received(_signal_param = null, _signal = null) -> void:
		if _signal != _signals[0]:
			finish()


class SequenceMatch:
	extends SequenceBreak

	func _on_signal_received(_signal_param = null, _signal = null) -> void:
		if _signal == _signals[0]:
			_signals.remove_at(0)
			if _signals.is_empty():
				finish()


class Timeout:
	extends SignalAwaiter
	var _timer: SceneTreeTimer

	func _init(timeout_seconds: float) -> void:
		super()
		_timer = Engine.get_main_loop().create_timer(timeout_seconds)
		add(_timer.timeout)

	func _on_signal_received(_signal_param = null, _signal = null) -> void:
		# Timer expired - finish the awaiter
		finish()
