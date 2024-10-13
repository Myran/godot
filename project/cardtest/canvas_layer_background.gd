extends CanvasLayer


func _ready():
	core.connect("event", Callable(self, "_on_core_event"))

func _on_core_event(event_type,_data):
	match event_type:
		core.EVENT_TYPE.GAME_STATE_TRANSITION:
			var new_state = _data[0]
			match new_state:
				core.GAME_STATE.DRAFT:
					$animation_player.play("show")
				core.GAME_STATE.PREPARE:
					$animation_player.play_backwards("show")
