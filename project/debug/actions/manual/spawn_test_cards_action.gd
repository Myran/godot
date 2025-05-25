# Example custom manual debug action
@tool
class_name SpawnTestCardsAction
extends ManualDebugAction


func _init() -> void:
	action_name = "Spawn Test Cards"
	button_name = "spawn_test_cards"
	category = "Gameplay"
	group = "Cards"
	description = "Spawns 3 random test cards for the player"
	requires_confirmation = false

	# Define the action
	action_callable = _spawn_test_cards


func _spawn_test_cards() -> void:
	if not is_instance_valid(card_controller) or not is_instance_valid(core):
		Log.error("Cannot spawn cards: Missing card_controller or core")
		return

	Log.info("Spawning 3 test cards...")

	for i in 3:
		var card = await card_controller.get_card_from_pool()
		if card:
			# Add to player's hand or appropriate location
			core.action(core.DrawCardEvent.new(card))
			Log.debug("Spawned card: " + str(card.get("id", "unknown")))

	Log.info("Test cards spawned successfully")
