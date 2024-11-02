class_name HandlerContainer extends Node

var input_handler: InputHandler
var card_handler: CardHandler
var draft_handler: DraftHandler
var lineup_handler: LineupHandler
var battle_handler: BattleHandler
var game_handler: GameHandler

func _init(game: Game):
	input_handler = InputHandler.new(game.clicker)
	lineup_handler = LineupHandler.new(game.holder_allies)
	battle_handler = BattleHandler.new(game.holder_allies, game.holder_enemy)
	card_handler = CardHandler.new()
	draft_handler = DraftHandler.new()
	game_handler = GameHandler.new(game)
	
	
	# Add all handlers as children for proper lifecycle management
	add_child(input_handler)
	add_child(card_handler)
	add_child(draft_handler)
	add_child(lineup_handler)
	add_child(battle_handler)
	add_child(game_handler)
