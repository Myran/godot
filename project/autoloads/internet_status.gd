extends Node
signal has_internet
signal no_internet
var socket: StreamPeerTCP = StreamPeerTCP.new()
var time: float = float(0)

func _ready()->void:
#	#socket.set_no_delay(true)
	#socket.connect_to_host("8.8.8.8", 53)
	print('internet status checker ready')

func _process(delta: float) -> void:
	time = time + delta
	socket.poll()
	print(socket.get_status())
	if socket.get_status() == 2:
		emit_signal("has_internet")
		socket.disconnect_from_host()
		set_process(false)
	else:
		if time >= 5.0:
			socket.disconnect_from_host()
			emit_signal("no_internet")
			set_process(false)

func get_status()->void:
	set_process(true)
	time = 0.0
	socket.connect_to_host("8.8.8.8", 53)
