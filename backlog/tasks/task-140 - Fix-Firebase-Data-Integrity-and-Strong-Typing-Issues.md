---
id: task-140
title: Fix Firebase Data Integrity and Strong Typing Issues
status: To Do
assignee: []
created_date: '2025-09-10 22:15'
labels:
  - firebase
  - data-integrity
  - strong-typing
  - error-handling
dependencies: [task-137, task-138, task-139]
priority: high
---

## Description

Multiple Firebase data integrity and strong typing issues detected during testing that prevent clean test execution. While core functionality works (actions now complete successfully after task-137 fixes), these data validation errors cause test failures and indicate potential runtime issues.

## Issues Identified

### **1. Dictionary Type Assignment Errors**
```
SCRIPT ERROR: Trying to assign a dictionary of type "Dictionary" to a variable of type "Dictionary[String, Nil]"
```
- **Impact**: Strong typing validation failures during data processing
- **Root cause**: Type mismatch between Firebase data and GDScript strong typing expectations

### **2. Missing Database Rules Data**
```
[ERROR] [database, error] Rules data is missing or empty { 
  "collection_name": "rules", 
  "collection_key": "rules_0", 
  "stack_trace": [
    { "function": "_get_stack_trace", "file": "rules_collection.gd", "line": 75 }, 
    { "function": "get_rules", "file": "rules_collection.gd", "line": 41 }, 
    { "function": "get_data", "file": "firebase_service_backend.gd", "line": 0 }
  ] 
}
```
- **Impact**: Game rules unavailable, affecting battle logic
- **Root cause**: Firebase rules collection empty or inaccessible

### **3. Dictionary Property Access Errors**
```
SCRIPT ERROR: Invalid access to property or key 'id' on a base object of type 'Dictionary'
SCRIPT ERROR: Invalid access to property or key 'health' on a base object of type 'Dictionary'  
SCRIPT ERROR: Invalid access to property or key 'upgrade_level' on a base object of type 'Dictionary'
```
- **Impact**: Failed access to card/unit properties
- **Root cause**: Dictionary structure doesn't match expected property access patterns

### **4. Card ID Resolution Failures**
```
[ERROR] [database, error] Card with id not found { "card_id": "" }
```
- **Impact**: Empty card IDs causing lookup failures
- **Root cause**: Card ID not properly set or retrieved from Firebase data

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Dictionary type assignment errors resolved - proper typing for Firebase data structures
- [ ] #2 Rules collection data available and accessible during testing
- [ ] #3 Dictionary property access works without errors - consistent data structure
- [ ] #4 Card ID resolution works properly - no empty card ID lookups
- [ ] #5 Test execution passes without Firebase data errors
- [ ] #6 Error handling graceful - no script errors for missing data scenarios
<!-- AC:END -->

## Investigation Areas

### **File Locations (from stack traces)**
- `rules_collection.gd:75` - `_get_stack_trace()` 
- `rules_collection.gd:41` - `get_rules()` 
- `firebase_service_backend.gd:0` - `get_data()`

### **Potential Root Causes**
1. **Strong typing compatibility**: After task-137 signal handler fixes, data typing might need similar adjustments
2. **Firebase data structure changes**: Data format in Firebase may not match GDScript expectations
3. **Test environment data**: Missing or incomplete test data in Firebase database
4. **Dictionary vs Class confusion**: Code expecting class properties but receiving plain Dictionary

## Related Tasks
- **task-137**: Firebase signal handler strong typing fixes (completed)
- **task-138**: Validate Firebase strong typing compatibility (completed)  
- **task-139**: Comprehensive Firebase strong typing audit (in progress)

## Testing Commands
```bash
# Test current issue
just test-android system.debug.registry_stats

# Debug Firebase data errors specifically  
just logs-errors TEST_ID

# Test broader Firebase functionality
just test-android 'system.firebase.*'
```

## Success Metrics
- ✅ `just test-android system.debug.registry_stats` passes without errors
- ✅ Firebase data operations complete without script errors
- ✅ Rules collection loads successfully
- ✅ Card data resolves with proper IDs and properties