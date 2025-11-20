---
id: task-299
title: Implement robust CardDefinition Resource class with strict typing
status: To Do
assignee: []
created_date: '2025-11-20 09:11'
updated_date: '2025-11-20 09:16'
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
