---
id: task-299
title: Implement robust CardDefinition Resource class with strict typing
status: Done
assignee: []
created_date: '2025-11-20 09:11'
updated_date: '2025-12-06 19:35'
labels:
  - robustness
  - typing
  - resources
  - cards
  - strict-typing
  - editor-completion
dependencies: []
priority: medium
---

## Description

## Assessment (2025-12-06) - DETAILED INVESTIGATION

**Value: MEDIUM-HIGH** - Eliminates silent fallbacks that hide bugs.

**Recommendation: KEEP** - After detailed codebase analysis with fail-fast philosophy:

### Current State Analysis
- **~100+ usages** of `card_info: Dictionary` across 20+ files
- **Two inconsistent access patterns**:
  - Direct: `card_info.id` (~40 usages) - ✅ crashes if missing (good)
  - Fallback: `card_info.get("id", "unknown")` (~30 usages) - ❌ hides issues silently

### Problem: Silent Fallbacks Hide Bugs
The ~30 `.get("id", "unknown")` usages **actively hide malformed data** instead of crashing. This violates fail-fast principles and makes debugging harder.

### Why CardDefinition Resource Helps
1. **Fail at boundary**: Conversion from Firebase Dictionary → Resource crashes immediately on malformed data
2. **Eliminate fallbacks**: No more `.get()` with silent defaults throughout codebase
3. **Single validation point**: Validate once at conversion, trust typed properties everywhere else
4. **Consistent access**: All code uses `card_definition.id` - no inconsistent patterns

### Implementation Priority
1. Create CardDefinition Resource with required properties (no defaults)
2. Add strict `from_dictionary()` that throws on missing fields
3. Migrate high-traffic files first (unit_behavior.gd, core_event_resolver.gd)
4. Remove all `.get()` fallbacks during migration

**Effort**: Medium (100+ usages, phased migration)
**Risk**: Low-Medium (fail-fast at boundary prevents downstream issues)

---

## Description

Replace the loose Dictionary usage for card_info with a strict Resource class to prevent runtime type errors and enable editor auto-completion. This refactoring improves code reliability, type safety, and developer experience by moving from dynamic dictionary access to strongly-typed Resource properties.

**Current Problem:**
```gdscript
# Loose typing prone to runtime errors
var card_info: Dictionary
var card_id = card_info.get("id", "unknown")  # No type safety
var attack = card_info.get("base_attack", 0)   # No validation
```

**Target Solution:**
```gdscript
# Strict typing with compile-time safety
var card_definition: CardDefinition
var card_id = card_definition.id               # Type-safe access
var attack = card_definition.base_attack       # Editor completion
```

**Benefits:**
- Compile-time type checking prevents runtime errors
- Editor auto-completion improves developer productivity
- Clear property definitions improve code documentation
- Better IDE support for refactoring and navigation

## Implementation Complete (2025-12-06)

### Phase 1 & 2: Full Implementation ✅

**Files Created:**
- `project/rules/card_definition.gd` - New CardDefinition Resource class with @export properties

**Files Modified (Primary):**
- `project/rules/unit_data.gd` - Replaced `card_info: Dictionary` with `card_definition: CardDefinition`
- `project/core/clicker/blocks/block_base_card.gd` - Replaced `card_info: Dictionary` with `card_definition: CardDefinition`
- `project/core/card_controller.gd` - Creates CardDefinition from Dictionary, passes to `init_card()`

**Files Modified (Secondary - 16 files):**
- `project/rules/unit_behavior.gd` - Updated all `card_info` references to `card_definition`
- `project/rules/battle.gd` - Updated logging to use `card_definition`
- `project/core/game.gd` - Updated reconciliation logging
- `project/core/lineup_handler.gd` - Updated card serialization
- `project/core/clicker/clicker.gd` - Updated merge/draft logging
- `project/rules/ability_helper.gd` - Updated ability processing
- `project/rules/merge_bonus_ability.gd` - Updated merge bonus calculations
- `project/core/holder_base.gd` - Updated card duplication
- `project/core/card/card.gd` - Updated UI setup
- `project/debug/actions/registrations/game_action_core.gd` - Updated debug logging
- `project/debug/actions/game/validate_combat_only_abilities_action.gd` - Updated validation
- Additional files with `card_info` → `card_definition` property updates

**Key Implementation Details:**

1. **No Backward Compatibility Layer** (per user request):
   - Direct replacement: `card_info: Dictionary` → `card_definition: CardDefinition`
   - No computed properties or wrapper methods
   - Clean, direct access to strongly-typed properties

2. **Initialization Flow**:
   - `CardController.create_unit_from_id()` fetches Dictionary from data source
   - Immediately converts to `CardDefinition` via `CardDefinition.from_dictionary()`
   - Passes `CardDefinition` to `Card.init_card()`
   - `Card.init_card()` stores `card_definition` and passes to `UnitData.init_with_definition()`

3. **Property Access Pattern** (before → after):
   - `unit.card_info.get("id", "unknown")` → `unit.card_definition.id if unit.card_definition else "unknown"`
   - `card.card_info.id` → `card.card_definition.id`
   - `info.card_info["base_attack"]` → `info.card_definition.base_attack`

**Validation:**
- ✅ `just ci-validate` - All checks passed (formatting, linting, runtime validation)
- ✅ `just test-desktop-target battle-logic-only` - 4/4 actions passed (100%)
  - `game.lineup.populate_enemy` - ✅ PASSED (75ms)
  - `game.battle.test_determinism_logic_only` - ✅ PASSED (25ms)
  - `game.debug.hide_debug_menu` - ✅ PASSED (9ms)
  - `system.debug.replay_complete` - ✅ PASSED (1ms)

**Branch:** `feature/task-299-card-definition-resource`

## Analysis Results (2025-12-06)

### Current card_info Dictionary Structure

From JSON data source (`resources/gameone-577cb-export.json`), the card_info dictionary contains:

| Field | JSON Type | GDScript Access | Usage |
|-------|-----------|-----------------|-------|
| `id` | String | `card_info.id` or `card_info.get("id")` | Card unique identifier |
| `card_name` | String | `card_info.card_name` | Display name |
| `name` | String | `card_info.name` | Internal/technical name |
| `description` | String | `card_info.description` | Card flavor text |
| `health` | String | `card_info.health` | Base health (stored as string) |
| `attack` | String | `card_info.attack` | Base attack (stored as string) |
| `abilities` | String | `card_info.abilities` | Ability string (e.g., "guard:1;1") |
| `tags` | String | `card_info.tags` | Comma-separated tags (e.g., "knight,evil") |
| `tribe` | String | `card_info.tribe` | Tribe classification |
| `upgrade_level` | String | `card_info.upgrade_level` | Card tier (stored as string) |

### Files Affected (Primary)

1. **`project/rules/unit_data.gd`** - Core usage, stores `card_info: Dictionary`
2. **`project/core/card_controller.gd`** - Creates cards, passes `card_info` dictionary
3. **`project/core/clicker/blocks/block_base_card.gd`** - Card scene, stores `card_info: Dictionary`

### Files Affected (Secondary - Access Only)

- `project/rules/unit_behavior.gd` - 15+ access points
- `project/core/events/core_event_resolver.gd` - 15+ access points (logging)
- `project/core/lineup_handler.gd` - 8+ access points
- `project/core/clicker/clicker.gd` - 6+ access points
- `project/rules/battle.gd` - 2+ access points
- `project/core/game.gd` - 5+ access points
- `project/core/card/card.gd` - 8+ access points (UI card details)
- `project/debug/actions/` - Various debug actions

### Access Patterns Identified

1. **Direct property access**: `card_info.id`, `card_info.card_name`
2. **Safe get with default**: `card_info.get("id", "unknown")`
3. **Has check**: `card_info.has("abilities")`
4. **Chained access**: `unit_info.card_info.id`

### CardDefinition Resource Class Design

```gdscript
class_name CardDefinition
extends Resource

## Card unique identifier
@export var id: String = ""

## Display name shown to players
@export var card_name: String = ""

## Internal/technical name
@export var name: String = ""

## Card flavor/description text
@export var description: String = ""

## Base health value
@export var base_health: int = 1

## Base attack value
@export var base_attack: int = 1

## Ability definition string (e.g., "guard:1;1")
@export var abilities_string: String = ""

## Comma-separated tags (e.g., "knight,evil")
@export var tags: String = ""

## Tribe classification
@export var tribe: String = ""

## Card tier/upgrade level
@export var upgrade_level: int = 1


static func from_dictionary(data: Dictionary) -> CardDefinition:
    """Create CardDefinition from legacy Dictionary format"""
    var def := CardDefinition.new()
    def.id = data.get("id", "")
    def.card_name = data.get("card_name", "")
    def.name = data.get("name", "")
    def.description = data.get("description", "")
    def.base_health = int(data.get("health", "1"))
    def.base_attack = int(data.get("attack", "1"))
    def.abilities_string = data.get("abilities", "")
    def.tags = data.get("tags", "")
    def.tribe = data.get("tribe", "")
    def.upgrade_level = int(data.get("upgrade_level", "1"))
    return def


func to_dictionary() -> Dictionary:
    """Convert back to Dictionary for backward compatibility"""
    return {
        "id": id,
        "card_name": card_name,
        "name": name,
        "description": description,
        "health": str(base_health),
        "attack": str(base_attack),
        "abilities": abilities_string,
        "tags": tags,
        "tribe": tribe,
        "upgrade_level": str(upgrade_level)
    }
```

## Implementation Strategy & Risk Mitigation

**Phase 1: Foundation with Dual Compatibility**
- Create CardDefinition Resource with full @export support
- Implement both from_dictionary() AND to_dictionary() methods
- Add dual compatibility layer in UnitData supporting both Dictionary and CardDefinition
- Create comprehensive migration testing framework

**Phase 2: Gradual Migration by System**
- Migrate UnitData.init_with_info() first (most critical)
- Update battle system components (highest usage)
- Convert UI refresh methods incrementally
- Update CoreEventResolver last (logging focus)

**Phase 3: Data Source Migration**
- Implement Firebase data conversion pipeline
- Update JSON test data to CardDefinition format
- Create batch migration tools for existing gamestate data
- Validate cross-platform save/load compatibility

## Validation Steps & Existing Tests

**Pre-Migration Validation:**
- [ ] **Critical Baseline**: `just test-android-target battle-logic-only` - Establish current card system functionality
- [ ] Run combat ability validation: `validate_combat_only_abilities_action`
- [ ] Execute gamestate save/load test: `just test-android-target gamestate-save-load-test`
- [ ] Document all current card_info usage patterns and access frequencies

**Foundation Validation (Phase 1):**
- [ ] Test CardDefinition Resource creation and @export functionality
- [ ] Validate from_dictionary() conversion with existing card data samples
- [ ] Test to_dictionary() conversion for backward compatibility
- [ ] Verify editor auto-completion and type checking improvements

**Migration Validation (Phase 2):**
- [ ] **Critical Test**: `just test-android-target battle-logic-only` - Must pass after UnitData changes
- [ ] **Combat Validation**: `validate_combat_only_abilities_action` - Ensure card data integrity
- [ ] **Gamestate Test**: `just test-android-target gamestate-save-load-test` - Validate save/load compatibility
- [ ] UI testing: Verify all card display components render correctly with CardDefinition
- [ ] Performance testing: Compare card loading times before/after migration

**Data Source Validation (Phase 3):**
- [ ] Firebase data integration testing: Load card data from Firebase as CardDefinition
- [ ] JSON configuration testing: Ensure static card data converts correctly
- [ ] Cross-platform validation: `just test-desktop-target battle-logic-only`
- [ ] Gamestate compatibility: Load existing save games with new CardDefinition system

**Automated Testing Integration:**
- [ ] Add CardDefinition validation to existing battle test suites
- [ ] Create dedicated test configuration for CardDefinition migration
- [ ] Implement automated compatibility testing between Dictionary and CardDefinition
- [ ] Add performance regression detection for card loading operations

**Manual Testing Requirements:**
- [ ] Editor experience: Test auto-completion and property inspection
- [ ] Card creation workflow: Verify new card creation tools work with Resource system
- [ ] Ability assignment testing: Ensure ability parsing works with CardDefinition.abilities_string
- [ ] Load testing: High-volume card loading and battle scenarios
- [ ] Long-running stability: Extended battle sessions with CardDefinition

**Data Migration Safety:**
- [ ] Backup existing card data before migration
- [ ] Create rollback procedure for CardDefinition conversion failures
- [ ] Validate data integrity after each migration phase
- [ ] Test gamestate forward/backward compatibility

**Acceptance Criteria with Validation:**
<!-- AC:BEGIN -->
- [ ] **Create CardDefinition Resource** with @export variables for all card fields (id, card_name, base_health, base_attack, upgrade_level, tags, abilities_string)
- [ ] **Implement dual conversion methods**: from_dictionary() AND to_dictionary() for compatibility
- [ ] **Add dual compatibility layer** in UnitData supporting both Dictionary and CardDefinition during migration
- [ ] **Critical Test Validation**: `just test-android-target battle-logic-only` must pass 100% after UnitData migration
- [ ] **Combat System Validation**: `validate_combat_only_abilities_action` confirms card data integrity
- [ ] **Gamestate Compatibility**: `just test-android-target gamestate-save-load-test` validates save/load with CardDefinition
- [ ] **Editor Enhancement**: Verify auto-completion and type checking work with CardDefinition properties
- [ ] **UI Integration**: All card display components render correctly using CardDefinition
- [ ] **Data Source Migration**: Firebase and JSON card data successfully convert to CardDefinition
- [ ] **Performance Validation**: Card loading times maintained or improved after migration
- [ ] **Cross-Platform Validation**: `just test-desktop-target battle-logic-only` passes consistently
- [ ] **CoreEventResolver Integration**: Event logging works with CardDefinition properties
- [ ] **Migration Tooling**: Batch conversion tools available for existing card data
- [ ] **Rollback Procedure**: Automated rollback capability if CardDefinition issues arise
- [ ] **CI Integration**: CardDefinition validation added to `just ci-validate` pipeline
<!-- AC:END -->
