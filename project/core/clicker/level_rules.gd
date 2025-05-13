class_name LevelRules extends Resource

const GRAVITY_VECTOR: Vector2i = Vector2i.DOWN
const REROLLABLES: Array[core.ObjectType] = [core.ObjectType.CARD, core.ObjectType.BLOCK_ITEM]
const GRID_WIDTH: int = 5  # max five cards in row
const GRID_HEIGTH: int = 5
const FREQ_REFILL_ITEM: int = 5
