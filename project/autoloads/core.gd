extends Node

signal event(event_data: CoreEvent)

enum UIState { INITIALIZING, WAITING, HOLDING, LOCKED }
enum Tempus { PRE, POST }
enum TapState { IDLE, PRESSING, UNPRESSING, HOLDING }
enum GameState { START, DRAFT, PREPARE, PREBATTLE, BATTLE, POSTBATTLE }
enum ObjectType {
	TEST,
	CARD,
	CARD_HOLDER,
	BACKGROUND,
	BLOCK_LOCKED,
	BLOCK_UPGRADE,
	EMPTY_SPACE,
	BLOCK_NOSPACE,
	BLOCK_PASSTROUGH,
	BLOCK_ITEM
}

enum EventSource { PLAYER, DEBUG_SETUP, SYSTEM_CASCADE }
# PLAYER: Direct player decisions (record these)
# DEBUG_SETUP: Debug actions that setup game state (record these)
# SYSTEM_CASCADE: System-generated consequences (don't record)

const CARD_MERGE_AMOUNT: int = 3


class CoreEvent:
	extends Context.Event

	# Polymorphic method for type identification - override in serializable events
	func get_serialization_type_name() -> StringName:
		return &""  # Default: not serializable


class StatEffectEvent:
	extends CoreEvent

	var target_card: Card
	var health_bonus: int
	var attack_bonus: int
	var effect_source: EventSource

	func _init(card: Card, health: int, attack: int, src: EventSource) -> void:
		target_card = card
		health_bonus = health
		attack_bonus = attack
		effect_source = src
		source = EventSource.SYSTEM_CASCADE


class RerollDraftEvent:
	extends CoreEvent

	func _init() -> void:
		source = EventSource.PLAYER

	func get_serialization_type_name() -> StringName:
		return &"core.RerollDraftEvent"


class UpgradeEvent:
	extends CoreEvent
	var new_level: int

	func _init(m_level: int = 1) -> void:
		self.new_level = m_level
		source = EventSource.PLAYER

	func get_recording_data() -> Dictionary:
		var data: Dictionary = super.get_recording_data()
		data["new_level"] = new_level
		return data

	func get_serialization_type_name() -> StringName:
		return &"core.UpgradeEvent"


class DraftMergeEvent:
	extends CoreEvent
	var matches: Array[Card]

	func _init(m_matches: Array[Card]) -> void:
		self.matches = m_matches
		source = EventSource.SYSTEM_CASCADE


class DraftAddBlockEvent:
	extends CoreEvent
	var pos: Vector2i
	var block: Block
	var refill_count: int

	func _init(m_block: Block, m_pos: Vector2i, m_refill_count: int = 0) -> void:
		self.block = m_block
		self.pos = m_pos
		self.refill_count = m_refill_count
		source = EventSource.SYSTEM_CASCADE


class BlockEntersPlay:
	extends CoreEvent
	var block: Block
	var pos: Vector2i

	func _init(m_block: Block, m_pos: Vector2i = Vector2i(-1, -1)) -> void:
		self.block = m_block
		self.pos = m_pos


class DraftColumnStateEvent:
	extends CoreEvent
	var col: int
	var is_locked: bool

	func _init(column: int = -1, locked_state: bool = false) -> void:
		self.col = column
		self.is_locked = locked_state
		source = EventSource.PLAYER

	func get_serialization_type_name() -> StringName:
		return &"core.DraftColumnStateEvent"


class UpdateDraftAreaEvent:
	extends CoreEvent


class CardStatChangeEvent:
	extends CoreEvent
	var card: Card
	var health: int
	var attack: int

	func _init(m_card: Card, m_health: int = 0, m_attack: int = 0) -> void:
		self.card = m_card
		self.health = m_health
		self.attack = m_attack


class TransitionEvent:
	extends CoreEvent
	var new_state: GameState

	func _init(m_state: GameState) -> void:
		self.new_state = m_state


class EnemyLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(m_card: Card, m_pos: int) -> void:
		self.card = m_card
		self.pos = m_pos
		source = EventSource.DEBUG_SETUP


class DebugLineupAddCardEvent:
	extends CoreEvent
	var card: Card
	var pos: int

	func _init(m_card: Card, m_pos: int) -> void:
		self.card = m_card
		self.pos = m_pos
		source = EventSource.DEBUG_SETUP


class LineupAddCardEvent:
	extends CoreEvent
	var card: Card

	func _init(m_card: Card = null) -> void:
		self.card = m_card
		source = EventSource.PLAYER

	func get_serialization_type_name() -> StringName:
		return &"core.LineupAddCardEvent"


class TrippleTestEvent:
	extends CoreEvent


class LineupMergeEvent:
	extends CoreEvent
	var card: Card
	var tripples: Array[Card]

	func _init(m_card: Card, m_tripples: Array[Card]) -> void:
		self.card = m_card
		self.tripples = m_tripples
		source = EventSource.SYSTEM_CASCADE


class MoveLineupCardEvent:
	extends CoreEvent
	var card: Card
	var from_position: int
	var to_position: int

	func _init(moved_card: Card = null, from_pos: int = -1, to_pos: int = -1) -> void:
		self.card = moved_card
		self.from_position = from_pos
		self.to_position = to_pos
		source = EventSource.PLAYER

	func get_serialization_type_name() -> StringName:
		return &"core.MoveLineupCardEvent"


class LineupAddCardFromDraftEvent:
	extends CoreEvent
	var card: Card
	var from_position: Vector2i  # Draft grid position
	var to_position: int  # Lineup holder index

	func _init(m_card: Card, m_from_pos: Vector2i, m_to_pos: int) -> void:
		self.card = m_card
		self.from_position = m_from_pos
		self.to_position = m_to_pos
		source = EventSource.PLAYER  # Ensures semantic logging triggers

	func get_serialization_type_name() -> StringName:
		return &"core.LineupAddCardFromDraftEvent"


class BattleEvent:
	extends CoreEvent
	var battle_events: Array[Context.Event]
	var battle_result: Battle.BattleResult = null

	func _init(
		m_battle_events: Array[Context.Event], m_battle_result: Battle.BattleResult = null
	) -> void:
		self.battle_events = m_battle_events
		self.battle_result = m_battle_result


class ResetUnitsEvent:
	extends CoreEvent


class DraftSteadyEvent:
	extends CoreEvent


class LineupOperationStartEvent:
	extends CoreEvent


class LineupOperationCompleteEvent:
	extends CoreEvent


class SystemIdleActionEvent:
	extends CoreEvent
	var action_callable: Callable
	var auto_continue: bool

	func _init(callable: Callable, should_auto_continue: bool = false) -> void:
		action_callable = callable
		auto_continue = should_auto_continue


class ProcessQueueEvent:
	extends CoreEvent


class RemoveBlockFromDraft:
	extends CoreEvent
	var block: Block
	var destroy_block: bool

	func _init(m_block: Block = null, m_destroy_block: bool = false) -> void:
		self.block = m_block
		self.destroy_block = m_destroy_block
		source = EventSource.PLAYER

	func get_serialization_type_name() -> StringName:
		return &"core.RemoveBlockFromDraft"


func action(_event: CoreEvent) -> void:
	event.emit(_event)


func _ready() -> void:
	Log.info("Core autoload initialized", {}, [Log.TAG_SYSTEM])
