extends CanvasLayer

@export var animation_player: AnimationPlayer


func _ready() -> void:
	core.connect("event", Callable(self, "_on_core_event"))


func _on_core_event(event: core.CoreEvent) -> void:
	#match event_type:
	# 	core.EVENT_TYPE.GAME_STATE_TRANSITION:
	if event is core.TransitionEvent:
		var new_state: core.GameState = event.new_state
		match new_state:
			core.GameState.DRAFT:
				animation_player.play("show")
			core.GameState.PREPARE:
				animation_player.play_backwards("show")
