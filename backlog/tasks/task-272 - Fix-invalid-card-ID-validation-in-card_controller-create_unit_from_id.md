---
id: task-272
title: Fix invalid card ID validation in card_controller create_unit_from_id
status: To Do
assignee: []
created_date: '2025-11-11 08:39'
updated_date: '2025-11-11 20:23'
labels:
  - critical
  - production-bug
  - validation
  - card-system
dependencies: []
---

## Description

**🚨 CRITICAL PRODUCTION BUG** - Card/unit creation system broken due to invalid card ID validation failing.

**Sentry Issue**: [GODOT-Z](https://primary-hive.sentry.io/issues/GODOT-Z)
**Error**: `Assertion failed: create_unit_from_id: Invalid card ID provided`
**File**: `res://core/card_controller.gd`
**Function**: `create_unit_from_id()`
**Timeline**: 1 event, 21 hours ago (Nov 10, 11:00:39 UTC)

**Root Cause**: The `create_unit_from_id()` function is receiving invalid or non-existent card IDs and failing assertion validation.

**Impact**:
- Players cannot create units from cards
- Card/unit system completely broken
- Core gameplay mechanics non-functional

## Root Cause Analysis

**Likely Code Pattern Causing Issue**:
```gdscript
# What's probably happening in card_controller.gd:
func create_unit_from_id(card_id: String):
    assert(card_id_valid(card_id), "Invalid card ID provided")  # ASSERTION FAILS
    # Unit creation code never reached
```

**Possible Root Causes**:
1. **Invalid ID Format**: Card ID string doesn't match expected format
2. **Missing Card Data**: Card ID valid but card data doesn't exist
3. **Corrupted Save Data**: Invalid card IDs loaded from save files
4. **Race Condition**: Card ID generated/validated before card data loaded

**Evidence from Sentry**:
- Error occurs exactly in `create_unit_from_id` function
- Assertion failure suggests defensive programming is working
- Similar timing to level_controller errors (both during game initialization)

## Proposed Solutions

### Option 1: Graceful Error Handling (Recommended)
```gdscript
func create_unit_from_id(card_id: String) -> Node:
    if not card_id_valid(card_id):
        push_error("Invalid card ID provided: " + str(card_id))
        return null  # or create default unit

    # Continue with unit creation
    return create_unit(card_id)
```

### Option 2: Enhanced Validation with Logging
```gdscript
func create_unit_from_id(card_id: String) -> Node:
    print_debug("Creating unit from card ID: ", card_id)

    if card_id.is_empty():
        push_error("Empty card ID provided to create_unit_from_id")
        return null

    if not card_id_exists(card_id):
        push_error("Card ID does not exist in database: " + str(card_id))
        print_debug("Available card IDs: ", get_available_card_ids())
        return null

    return create_unit(card_id)
```

### Option 3: Data Recovery Strategy
```gdscript
func create_unit_from_id(card_id: String) -> Node:
    if not card_id_valid(card_id):
        # Try to find closest matching card ID
        var corrected_id = find_similar_card_id(card_id)
        if corrected_id != null:
            push_warning("Corrected invalid card ID from '" + card_id + "' to '" + corrected_id + "'")
            return create_unit(corrected_id)

        # Fallback to default unit
        push_error("Invalid card ID '" + card_id + "', using default unit")
        return create_default_unit()
```

## Acceptance Criteria

- [x] **Issue Identification**: Bug identified via Sentry MCP integration
- [ ] **Root Cause Fixed**: Invalid card IDs handled gracefully without crashes
- [ ] **Proper Error Logging**: Add detailed logging for invalid card ID scenarios
- [ ] **Unit Creation Works**: Players can successfully create units from valid cards
- [ ] **Graceful Degradation**: Invalid IDs handled without game crashes
- [ ] **Sentry Validation**: No more GODOT-Z errors after fix deployment
- [ ] **Data Integrity**: Fix doesn't corrupt existing card data or save files
- [ ] **Cross-Platform**: Fix works on both desktop and Android platforms

## Testing Requirements

1. **Invalid ID Scenarios**: Test with empty, null, malformed, and non-existent card IDs
2. **Valid ID Scenarios**: Ensure normal card creation still works
3. **Edge Cases**: Test boundary conditions and special characters in IDs
4. **Integration Tests**: Verify complete card-to-unit workflow
5. **Production Validation**: Monitor Sentry after deployment

## Investigation Steps

1. **Code Analysis**: Examine `create_unit_from_id()` implementation
2. **Card ID Format**: Document expected card ID format and validation rules
3. **Call Stack Analysis**: Find all callers of `create_unit_from_id()`
4. **Data Validation**: Check card database integrity and ID consistency
5. **Reproduction**: Create test case that reproduces the exact error

## Related Issues

- **Sentry**: GODOT-Z - Primary production issue
- **Backlog**: task-271 (similar null/reference error pattern)
- **Code Location**: `res://core/card_controller.gd:21`
- **Related Systems**: Level creation, card database, unit management

## Implementation Notes

**Investigation Method**: Discovered through Sentry MCP server integration showing real-time production errors.

**Priority**: Critical - completely blocks unit creation and core gameplay functionality.

**Estimated Complexity**: Medium - requires investigation of card ID validation logic and possibly card database integrity.

**Data Safety**: Ensure fix doesn't lose or corrupt existing player card collections.
