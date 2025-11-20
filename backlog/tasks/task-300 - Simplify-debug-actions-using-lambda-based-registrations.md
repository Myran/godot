---
id: task-300
title: Simplify debug actions using lambda-based registrations
status: To Do
assignee: []
created_date: '2025-11-20 09:11'
updated_date: '2025-11-20 09:17'
labels:
  - debugging
  - code-reduction
  - lambda-functions
  - refactoring
  - maintenance
dependencies: []
priority: low
---

## Description

Reduce the file count and simplify maintenance by converting simple, single-purpose debug action scripts into inline lambda registrations within the registration files. This refactoring eliminates boilerplate code while maintaining all debug functionality through cleaner, more maintainable lambda-based implementations.

**Current Problem:**
```gdscript
# Separate file for each simple action
# project/debug/actions/rtdb/rtdb_delete_value_action.gd
class_name RTDBDeleteValueAction
extends DebugAction
func _init():
    action_name = "rtdb.database.remove_value"
func execute() -> bool:
    # Simple logic that could be inline
```

**Target Solution:**
```gdscript
# Inline lambda registration in rtdb_actions.gd
registry.register_action(
    DebugAction.create("rtdb.database.remove_value", func() -> bool:
        # Direct inline implementation
    )
)
```

**Benefits:**
- Reduced file count improves maintainability
- Eliminated boilerplate class definitions
- Logic is co-located with registration
- Simpler debugging and modification workflow
- Cleaner project structure

## Implementation Strategy & Risk Mitigation

**Phase 1: Complexity Classification**
- Analyze all 68 debug actions for complexity and conversion suitability
- Identify truly simple actions (single operation, minimal dependencies)
- Create action classification matrix with risk assessment
- Document complex actions that MUST remain as separate classes

**Phase 2: Lambda Conversion with Safety Net**
- Convert only pre-identified simple actions to lambda format
- Maintain original class files as backup during conversion
- Test each lambda conversion individually before deletion
- Validate utility access (RTDBTestPaths, TestUtils) in lambda context

**Phase 3: Validation and Cleanup**
- Comprehensive testing of all converted actions
- Performance comparison between lambda and class implementations
- Remove backup class files only after full validation
- Document lambda conversion patterns for future use

## Action Classification Matrix

**Simple Actions (Lambda Conversion Candidates - 4 total):**
- `RTDBGetSimpleValueAction` - Single get operation with validation
- `RTDBSetSimpleValueAction` - Single set operation with path validation
- `RTDBDeleteValueAction` - Single delete operation with error handling
- `RTDBUpdateValueAction` - Single update operation with result verification

**Medium Complexity (Keep as Classes - 7 total):**
- `RTDBGetNestedPathAction`, `RTDBSetNestedPathAction`, `RTDBListChildrenAction`
- `RTDBPushItemAction`, `RTDBSingleValueListenerAction`, `RTDBTransactionTestAction`
- `RTDBPathValidationAction`

**Complex Actions (Keep as Classes - 8 total):**
- `RTDBBatchOperationsAction`, `RTDBConcurrentOperationsAction`
- `RTDBErrorHandlingTestAction`, `RTDBListenerTestAction`, etc.

## Validation Steps & Existing Tests

**Pre-Conversion Validation:**
- [ ] **Critical Baseline**: `just test-android-target system-layer-all` - Establish current debug action functionality
- [ ] Run individual action tests: Execute all 19 RTDB actions manually to document current behavior
- [ ] Document utility access: Verify RTDBTestPaths and TestUtils accessibility in current registration context
- [ ] Performance baseline: Measure action execution times for performance comparison

**Lambda Conversion Validation (Each Action):**
- [ ] **Test lambda execution**: Verify converted action produces identical results to original class
- [ ] **Validate utility access**: Ensure RTDBTestPaths and TestUtils work correctly in lambda context
- [ ] **Error handling testing**: Verify lambda error handling matches original class behavior
- [ ] **DebugActionResult validation**: Confirm result reporting integrity is maintained
- [ ] **Debug menu verification**: Test action discovery and execution through debug menu

**Post-Conversion Validation:**
- [ ] **Critical Test**: `just test-android-target system-layer-all` - Must pass with all lambda actions
- [ ] Individual action testing: Execute all 4 converted lambda actions manually
- [ ] Performance comparison: Measure lambda vs class execution times
- [ ] Memory usage validation: Ensure no memory leaks with lambda implementations
- [ ] Debug menu integrity: Verify all converted actions appear and execute correctly

**Automated Testing Integration:**
- [ ] Add lambda action validation to existing system test suites
- [ ] Create automated comparison tests between original and lambda implementations
- [ ] Add performance regression detection for debug action execution
- [ ] Implement automated rollback if lambda tests fail

**Manual Testing Requirements:**
- [ ] Debug menu navigation: Test all lambda actions through debug menu interface
- [ ] Error scenario testing: Network failures, invalid paths, service unavailable
- [ ] Concurrent execution: Test multiple lambda actions running simultaneously
- [ ] Long-running stability: Extended debug menu usage with lambda actions

**Safety and Rollback:**
- [ ] Maintain backup copies of original class files during conversion
- [ ] Create automated rollback procedure if lambda issues arise
- [ ] Validate each conversion independently before proceeding to next
- [ ] Test utility class access thoroughly before lambda conversion

**Acceptance Criteria with Validation:**
<!-- AC:BEGIN -->
- [ ] **Classify debug actions by complexity** - Convert only 4 identified simple actions (RTDBGetSimpleValueAction, RTDBSetSimpleValueAction, RTDBDeleteValueAction, RTDBUpdateValueAction)
- [ ] **Preserve complex actions** - Keep 7 medium and 8 complex actions as separate classes for maintainability
- [ ] **Lambda Conversion Implementation**: Refactor rtdb_actions.gd to use DebugAction.create() with lambda functions
- [ ] **Utility Access Validation**: Ensure RTDBTestPaths and TestUtils remain accessible in lambda context
- [ ] **Individual Action Testing**: Each converted lambda action must produce identical results to original class
- [ ] **Critical Test Validation**: `just test-android-target system-layer-all` must pass with all lambda actions
- [ ] **Debug Menu Integrity**: All converted lambda actions appear and execute correctly through debug menu
- [ ] **Performance Validation**: Lambda execution times must be equal to or better than class implementations
- [ ] **Error Handling Consistency**: Lambda error handling must match original class behavior exactly
- [ ] **DebugActionResult Integrity**: Result reporting system must work correctly with lambda actions
- [ ] **Memory Management**: No memory leaks or resource issues with lambda implementations
- [ ] **Rollback Procedure**: Automated rollback capability if lambda conversion issues arise
- [ ] **Conversion Documentation**: Document lambda conversion patterns for future reference
- [ ] **CI Integration**: Lambda action validation added to `just ci-validate` pipeline
<!-- AC:END -->
