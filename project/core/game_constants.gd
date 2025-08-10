class_name GameConstants
extends RefCounted

# ================================
# CARD SYSTEM CONSTANTS  
# ================================

static var DEFAULT_CARD_HEALTH: int = 1
static var DEFAULT_CARD_ATTACK: int = 1
static var DEFAULT_CARD_LEVEL: int = 1
static var DEFAULT_UNIT_LEVEL: int = 1

# ================================
# GRID AND LAYOUT CONSTANTS
# ================================

static var GRID_WIDTH: int = 5
static var GRID_HEIGHT: int = 5

# ================================
# PLAYER CONSTANTS
# ================================

static var DEFAULT_PLAYER_LEVEL: int = 1
static var DEFAULT_PLAYER_LIVES: int = 3

# ================================
# RANDOM NUMBER GENERATION
# ================================

static var DEFAULT_RNG_SEED: int = 12345
static var HARD_RESET_RNG_SEED: int = 54321
static var UNIT_LEVEL_ROLL_MAX: int = 99

# ================================
# BATTLE SYSTEM CONSTANTS
# ================================

static var ZERO_HEALTH_THRESHOLD: int = 0
static var ZERO_ATTACK_THRESHOLD: int = 0
static var ZERO_STAT_VALUE: int = 0

# ================================
# UI AND ANIMATION CONSTANTS
# ================================

static var FULL_ROTATION_DEGREES: int = 360
static var UI_PADDING: int = 20
static var UI_PANEL_HEIGHT: int = 30

# ================================
# PERFORMANCE AND TIMING
# ================================

static var FPS_ASSUMPTION: int = 60
static var PERFORMANCE_WARNING_THRESHOLD_SEC: int = 5
static var MILLISECONDS_PER_SECOND: int = 1000

# ================================
# NETWORK CONSTANTS
# ================================

static var HTTP_SUCCESS_MIN: int = 200
static var HTTP_SUCCESS_MAX: int = 300
static var HTTP_NOT_FOUND: int = 404
static var FACEBOOK_API_LIMIT: int = 3000

# ================================
# DATA DEFAULTS
# ================================

static var DEFAULT_INT_VALUE: int = 0
static var DEFAULT_TEST_GROUP: int = 0
static var DEFAULT_STACK_TRACE_DEPTH: int = 2
static var DEFAULT_INCREMENT_VALUE: int = 1
static var DEFAULT_REFILL_COUNT: int = 0

# ================================
# ARRAY/STRING OPERATIONS
# ================================

static var ARRAY_INDEX_OFFSET: int = 1
static var STRING_TRUNCATION_SUFFIX_LENGTH: int = 3
static var MINIMUM_PART_COUNT: int = 2
static var MIDDLE_WILDCARD_PART_COUNT: int = 3
static var EXTENDED_MATCH_PART_COUNT: int = 5

# ================================
# TEST DATA CONSTANTS
# ================================

static var TEST_CARD_HEALTH: int = 10
static var TEST_CARD_ATTACK: int = 5
static var TEST_ITEM_BASE_PRICE: int = 10
static var TEST_PROGRESS_DEFAULT: int = 1

# ================================
# SYSTEM LIMITS
# ================================

static var SESSION_ID_RANDOM_LIMIT: int = 10000
static var WEBSOCKET_RANDOM_ID_RANGE: int = 1073741824  # 1 << 30
static var SPACE_TO_TAB_DIVISOR: int = 4
