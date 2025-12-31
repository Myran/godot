---
id: task-098
title: Implement comprehensive magic number extraction system
status: Done
assignee: []
created_date: '2025-09-13'
updated_date: '2025-12-31 01:05'
labels:
  - code-quality
  - refactoring
  - technical-debt
dependencies: []
priority: medium
ordinal: 1.953125
---

# task-098 - Implement comprehensive magic number extraction system

## Context

**Priority**: 🔧 MEDIUM - Technical Debt
**Status**: Open  
**Complexity**: MEDIUM - Codebase-wide refactoring  
**Category**: Code Quality - Constants Management  

## Problem Statement

The GameTwo codebase contains numerous magic numbers scattered throughout game logic, Firebase timeouts, performance thresholds, and configuration values. These hardcoded values reduce code maintainability, make configuration changes difficult, and obscure the intent of numerical values in business logic.

**Impact Areas**:
- Firebase timeout values (10.0, 30.0, etc.)
- Battle system constants (damage calculations, ability thresholds)
- Performance thresholds (<5ms, <100ms, <500ms)
- UI layout values and animation durations
- Debug system configuration values

## Technical Goals

### Primary Objectives
1. **Centralized Constants**: Create organized constant management system
2. **Improved Maintainability**: Easy configuration changes without code changes
3. **Enhanced Readability**: Self-documenting code with named constants
4. **Type Safety**: Strongly typed constant definitions

### Success Criteria
- [ ] Centralized constants system with logical organization
- [ ] 90%+ magic numbers replaced with named constants
- [ ] Zero functional regressions after refactoring
- [ ] Improved code readability with self-documenting constants
- [ ] Easy configuration management for different environments

## Implementation Approach

### Phase 1: Constants Architecture Design

**Hierarchical Constants Organization**:
```gdscript
# project/core/constants/game_constants.gd
class_name GameConstants
extends RefCounted

# Performance Thresholds
class Performance:
    const EXCELLENT_THRESHOLD_MS: float = 5.0
    const GOOD_THRESHOLD_MS: float = 100.0
    const ACCEPTABLE_THRESHOLD_MS: float = 500.0
    const WARNING_THRESHOLD_MS: float = 1000.0

# Firebase Configuration
class Firebase:
    const DEFAULT_TIMEOUT_SEC: float = 10.0
    const LONG_OPERATION_TIMEOUT_SEC: float = 30.0
    const CONNECTION_RETRY_DELAY_SEC: float = 2.0
    const MAX_RETRY_ATTEMPTS: int = 3

# Battle System Constants
class Battle:
    const MAX_LINEUP_SIZE: int = 6
    const DEFAULT_HEALTH: int = 100
    const CRITICAL_DAMAGE_MULTIPLIER: float = 1.5
    const SHIELD_ABSORPTION_PERCENT: float = 0.5

# Debug System Configuration
class Debug:
    const MAX_LOG_ENTRIES: int = 1000
    const TOKEN_EFFICIENCY_TARGET: float = 0.98
    const STATE_EXTRACTION_TIMEOUT_MS: float = 5.0
```

### Phase 2: Domain-Specific Constant Files

**Battle System Constants**:
```gdscript
# project/core/constants/battle_constants.gd
class_name BattleConstants
extends RefCounted

# Unit Statistics
class Stats:
    const MIN_LEVEL: int = 1
    const MAX_LEVEL: int = 50
    const BASE_ATTACK: int = 10
    const BASE_HEALTH: int = 100
    const STAT_GROWTH_RATE: float = 1.1

# Abilities and Effects
class Abilities:
    const FIRST_STRIKE_PRIORITY: int = 1
    const NORMAL_PRIORITY: int = 0
    const SHIELD_DURATION_TURNS: int = 3
    const POISON_DAMAGE_PER_TURN: int = 5
    const HEAL_PERCENTAGE: float = 0.25

# Battle Mechanics
class Mechanics:
    const TURN_TIME_LIMIT_SEC: float = 30.0
    const ANIMATION_SPEED_MULTIPLIER: float = 1.0
    const AUTO_RESOLVE_TIMEOUT_SEC: float = 120.0
```

**Firebase Constants**:
```gdscript
# project/core/constants/firebase_constants.gd
class_name FirebaseConstants
extends RefCounted

# Timeouts and Retries
class Timeouts:
    const AUTH_TIMEOUT_SEC: float = 15.0
    const DATABASE_READ_TIMEOUT_SEC: float = 10.0
    const DATABASE_WRITE_TIMEOUT_SEC: float = 15.0
    const CONNECTION_CHECK_TIMEOUT_SEC: float = 5.0

# Error Codes and Messages
class ErrorCodes:
    const NETWORK_ERROR: String = "NETWORK_ERROR"
    const AUTH_FAILED: String = "AUTH_FAILED"
    const PERMISSION_DENIED: String = "PERMISSION_DENIED"
    const TIMEOUT_ERROR: String = "TIMEOUT_ERROR"

# Configuration Paths
class Paths:
    const USER_DATA_PATH: String = "/users/{user_id}/data"
    const GAME_CONFIG_PATH: String = "/config/game"
    const LEADERBOARD_PATH: String = "/leaderboards/global"
```

### Phase 3: Systematic Magic Number Replacement

**Example Refactoring**:
```gdscript
# BEFORE: Magic numbers scattered throughout code
func _execute_rtdb_operation_and_await(timeout_sec: float = 10.0) -> Variant:
    if performance_ms < 5.0:
        Log.info("Excellent performance")
    elif performance_ms < 100.0:
        Log.info("Good performance")

# AFTER: Named constants with clear intent
func _execute_rtdb_operation_and_await(
    timeout_sec: float = FirebaseConstants.Timeouts.DATABASE_READ_TIMEOUT_SEC
) -> Variant:
    if performance_ms < GameConstants.Performance.EXCELLENT_THRESHOLD_MS:
        Log.info("Excellent performance")
    elif performance_ms < GameConstants.Performance.GOOD_THRESHOLD_MS:
        Log.info("Good performance")
```

## Dependencies

- **Builds on**: Recent successful refactoring patterns
- **Integrates with**: All major game systems
- **Follows**: Established utility class patterns (extends RefCounted)
- **Enhances**: Code maintainability and configuration management

## Implementation Details

### Constants Discovery Process

**Automated Magic Number Detection**:
```bash
# Find potential magic numbers in GDScript files
find-magic-numbers:
    #!/usr/bin/env bash
    echo "🔍 Scanning for potential magic numbers..."
    
    # Find numeric literals (excluding 0, 1, -1, common values)
    rg '\b(?!0\b|1\b|-1\b|2\b|10\b|100\b)\d+\.?\d*\b' project/ \
        --type=gdscript \
        --line-number \
        --context=1 > /tmp/magic_numbers.txt
    
    echo "📊 Found $(wc -l < /tmp/magic_numbers.txt) potential magic numbers"
    echo "📁 Results saved to /tmp/magic_numbers.txt"
```

### Configuration Management System

**Environment-Aware Constants**:
```gdscript
# project/core/constants/environment_constants.gd
class_name EnvironmentConstants
extends RefCounted

enum Environment { DEVELOPMENT, TESTING, PRODUCTION }

static var current_environment: Environment = Environment.DEVELOPMENT

static func get_firebase_timeout() -> float:
    match current_environment:
        Environment.DEVELOPMENT:
            return 30.0  # Longer timeouts for debugging
        Environment.TESTING:
            return 5.0   # Shorter timeouts for fast tests
        Environment.PRODUCTION:
            return 10.0  # Balanced timeouts for users
        _:
            return 10.0
```

### Constants Validation System

**Runtime Constants Validation**:
```gdscript
# Validate constants make logical sense
static func validate_constants() -> bool:
    assert(GameConstants.Performance.EXCELLENT_THRESHOLD_MS < 
           GameConstants.Performance.GOOD_THRESHOLD_MS,
           "Performance thresholds must be in ascending order")
    
    assert(BattleConstants.Stats.MIN_LEVEL < 
           BattleConstants.Stats.MAX_LEVEL,
           "Level range must be valid")
    
    assert(FirebaseConstants.Timeouts.CONNECTION_CHECK_TIMEOUT_SEC > 0,
           "Timeout values must be positive")
    
    return true
```

## Risk Mitigation

### Technical Risks
- **Breaking Changes**: Constant values might change behavior
  - *Mitigation*: Careful value preservation during extraction
- **Performance Impact**: Constant access overhead
  - *Mitigation*: Use compile-time constants where possible
- **Circular Dependencies**: Constants referencing other constants
  - *Mitigation*: Clear dependency hierarchy and validation

### Process Risks
- **Large Refactoring Scope**: Many files affected simultaneously
  - *Mitigation*: Incremental extraction by domain
- **Testing Coverage**: Hard to test all constant usage
  - *Mitigation*: Comprehensive regression testing

## Acceptance Criteria
<!-- AC:BEGIN -->
### Must Have
- [ ] #1 Centralized constants system with logical organization
- [ ] #2 90%+ identified magic numbers replaced with named constants
- [ ] #3 Zero functional regressions after refactoring
- [ ] #4 Clear documentation of all constant categories
- [ ] #5 Environment-aware configuration system

### Should Have
- [ ] #6 Automated magic number detection and reporting
- [ ] #7 Constants validation system with runtime checks
- [ ] #8 Clear migration guide for future constant additions
- [ ] #9 Integration with existing debug and testing systems

### Nice to Have
- [ ] #10 Hot-reloading of constants during development
- [ ] #11 Constants usage analytics and reporting
- [ ] #12 Automatic constant suggestion system
- [ ] #13 Visual constants management interface
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Migration Strategy**:
1. Create constants infrastructure
2. Extract constants by domain (Firebase, Battle, Debug, etc.)
3. Systematic replacement with regression testing
4. Validate and clean up legacy magic numbers

**Constants Naming Conventions**:
- SCREAMING_SNAKE_CASE for compile-time constants
- PascalCase for class names and namespaces
- Clear, descriptive names explaining purpose
- Grouped by domain and functionality

**Success Metrics**:
- Magic number reduction: Target 90%+ of identifiable magic numbers
- Code readability: Improved self-documentation
- Configuration flexibility: Easy environment-specific tuning
- Maintainability: Reduced time to change configuration values

This systematic approach to magic number extraction builds on the successful refactoring patterns already established in the GameTwo project, providing a foundation for improved code maintainability and configuration management.
<!-- SECTION:NOTES:END -->
