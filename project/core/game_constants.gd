extends Node

# ================================
# CARD SYSTEM CONSTANTS
# ================================


class CardSystem:
	const DEFAULT_HEALTH: int = 1
	const DEFAULT_ATTACK: int = 1
	const DEFAULT_LEVEL: int = 1
	const LEVEL_TWO: int = 2
	const LEVEL_THREE: int = 3
	const DEFAULT_UNIT_LEVEL: int = 1

	# Card creation constants
	const CARD_IMAGE_PREFIX: String = "card_image_"
	const CARD_SCENE_NAME: String = "res://core/clicker/blocks/block_base_card.tscn"
	const CARD_IMAGE_FOLDER: String = "res://assets/card_images/"


# ================================
# UNIT CLASSIFICATION CONSTANTS
# ================================


class UnitTags:
	"""
	Unit Tags - Used to categorize units with multiple possible classifications.
	Units can have multiple tags (comma-separated in data).

	Complete list of all tags found in game data:
	- evil: Found in 3 units (knight_red, monk, mooseman)
	- forest: Found in 3 units (knight_green, monk, swordman)
	- knight: Found in 6 units (knight_blue, knight_green, knight_red, monk, swordman, knight_gold)
	- soldier: Found in 2 units (monk, archer)

	Note: 21 units have no tags (empty string)
	"""
	const EVIL: String = "evil"
	const FOREST: String = "forest"
	const KNIGHT: String = "knight"
	const MAGIC: String = "magic"
	const SOLDIER: String = "soldier"


class BlockSystem:
	const TYPE_ZERO: int = 0
	const UPGRADE_LEVEL_FOUR: int = 4
	const UPGRADE_LEVEL_FIVE: int = 5


# ================================
# GRID AND LAYOUT CONSTANTS
# ================================


class GridSystem:
	const WIDTH: int = 5
	const HEIGHT: int = 5


# ================================
# PLAYER CONSTANTS
# ================================


class PlayerSystem:
	const DEFAULT_LEVEL: int = 1
	const DEFAULT_LIVES: int = 3


# ================================
# RANDOM NUMBER GENERATION
# ================================


class RandomSystem:
	const DEFAULT_SEED: int = 12345
	const HARD_RESET_SEED: int = 54321
	const UNIT_LEVEL_ROLL_MAX: int = 99


# ================================
# BATTLE SYSTEM CONSTANTS
# ================================


class BattleSystem:
	const ZERO_HEALTH_THRESHOLD: int = 0
	const ZERO_ATTACK_THRESHOLD: int = 0
	const ZERO_STAT_VALUE: int = 0


# ================================
# UI AND ANIMATION CONSTANTS
# ================================


class UISystem:
	const FULL_ROTATION_DEGREES: int = 360
	const PADDING: int = 20
	const PANEL_HEIGHT: int = 30


# ================================
# PERFORMANCE AND TIMING
# ================================


class TimingSystem:
	const FPS_ASSUMPTION: int = 60
	const WARNING_THRESHOLD_SEC: int = 5
	const MILLISECONDS_PER_SECOND: int = 1000


# ================================
# NETWORK CONSTANTS
# ================================


class NetworkSystem:
	const HTTP_SUCCESS_MIN: int = 200
	const HTTP_SUCCESS_MAX: int = 300
	const HTTP_NOT_FOUND: int = 404
	const FACEBOOK_API_LIMIT: int = 3000


# ================================
# DATA DEFAULTS
# ================================


class DataSystem:
	const DEFAULT_INT_VALUE: int = 0
	const DEFAULT_TEST_GROUP: int = 0
	const DEFAULT_STACK_TRACE_DEPTH: int = 2
	const DEFAULT_INCREMENT_VALUE: int = 1
	const DEFAULT_REFILL_COUNT: int = 0


# ================================
# ARRAY/STRING OPERATIONS
# ================================


class StringSystem:
	const ARRAY_INDEX_OFFSET: int = 1
	const TRUNCATION_SUFFIX_LENGTH: int = 3
	const MINIMUM_PART_COUNT: int = 2
	const MIDDLE_WILDCARD_PART_COUNT: int = 3
	const EXTENDED_MATCH_PART_COUNT: int = 5


# ================================
# TEST DATA CONSTANTS
# ================================


class TestSystem:
	const CARD_HEALTH: int = 10
	const CARD_ATTACK: int = 5
	const ITEM_BASE_PRICE: int = 10
	const PROGRESS_DEFAULT: int = 1


# ================================
# SYSTEM LIMITS
# ================================


class SystemLimits:
	const SESSION_ID_RANDOM_LIMIT: int = 10000
	const WEBSOCKET_RANDOM_ID_RANGE: int = 1073741824  # 1 << 30
	const SPACE_TO_TAB_DIVISOR: int = 4


# ================================
# NETWORK TIMING CONSTANTS
# ================================


class NetworkTiming:
	const DEFAULT_TIMEOUT_SEC: float = 10.0
	const FIREBASE_TIMEOUT_SEC: float = 45.0
	const INTERNET_CHECK_TIMEOUT_SEC: float = 7.0
	const CHUNK_PROCESSING_TIMEOUT_SEC: float = 2.0
	const LOGGER_SHUTDOWN_TIMEOUT_SEC: float = 2.0
	const ANDROID_LOGCAT_FLUSH_DELAY_SEC: float = 3.0
	const BATTLE_SEQUENCE_DELAY_SEC: float = 1.25


# ================================
# DEBUG AND TESTING LIMITS
# ================================


class DebugLimits:
	const DEFAULT_OPERATION_TIMEOUT_MS: int = 5000
	const PERFORMANCE_TARGET_MS: int = 5000
	const MAX_NESTING_DEPTH: int = 10
	const MAX_KEYS_DISPLAY: int = 5
	const MAX_KEYS_EXTENDED: int = 10
	const MIN_TEST_PATH_LENGTH: int = 3
	const STRING_TRUNCATE_LENGTH: int = 50
	const COMMIT_HASH_DISPLAY_LENGTH: int = 8


# ================================
# UI AND INTERFACE CONSTANTS
# ================================


class UIConstants:
	const DEBUG_TIMER_WAIT_TIME: float = 0.5
	const INDENTATION_SPACES: int = 2
	const ARRAY_INLINE_THRESHOLD: int = 5
	const SUCCESS_RATE_HIGH_THRESHOLD: float = 80.0
	const SUCCESS_RATE_MEDIUM_THRESHOLD: float = 50.0
	const DASHBOARD_SEPARATOR_LENGTH: int = 30
	const SUMMARY_SEPARATOR_LENGTH: int = 40
	const PANEL_PADDING_ADDITION: int = 20
	const PANEL_MINIMUM_HEIGHT: int = 30


# ================================
# CARD CREATION CONSTANTS
# ================================


class CardCreation:
	const PERCENTAGE_BASE: int = 99
	const PERCENTAGE_OFFSET: int = 1
	const LEVEL_2_STAR_1_THRESHOLD: String = "50"
	const LEVEL_2_STAR_2_THRESHOLD: String = "100"
	const LEVEL_3_STAR_1_THRESHOLD: String = "30"
	const LEVEL_3_STAR_2_THRESHOLD: String = "70"
	const LEVEL_3_STAR_3_THRESHOLD: String = "100"


# ================================
# RATE LIMITING AND PERFORMANCE
# ================================


class RateLimiting:
	const BASE_DELAY_MULTIPLIER: int = 2
	const PENDING_REQUEST_DELAY_MS: int = 20
	const FAILURE_PENALTY_DELAY_MS: int = 50
	const ADAPTIVE_DELAY_MULTIPLIER: float = 1.5
	const WEBSOCKET_HANDSHAKE_TIMEOUT_MS: int = 3000


# ================================
# STATE EXTRACTION AND PRECISION
# ================================


class StateExtraction:
	const FLOAT_PRECISION_PLACES: int = 6
	const NORMALIZATION_FACTOR: float = 0.000001
	const VERSION_STRING: String = "1.0.0"
