---
id: task-298
title: Flatten data layer architecture by removing DatabaseService middleware
status: To Do
assignee: []
created_date: '2025-11-20 09:10'
updated_date: '2025-11-20 09:15'
labels:
  - architecture
  - refactoring
  - firebase
  - performance
  - code-reduction
dependencies: []
priority: medium
---

## Description

Remove the redundant DatabaseService middleware to reduce call stack depth and cognitive load while improving performance. This architectural simplification moves from a 4-layer stack to a 3-layer stack, making the codebase more maintainable and reducing complexity.

**Target Architecture Transformation:**
- **Current**: DataSource → FirebaseServiceBackend → DatabaseService → FirebaseService (Autoload)
- **Target**: DataSource → FirebaseServiceBackend → FirebaseService (Autoload)

**Performance Benefits:**
- Reduced call stack depth improves execution speed
- Eliminated middleware layer reduces cognitive load
- Direct FirebaseService access improves debugging clarity
- Simplified error tracing and debugging workflow

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Enhance FirebaseService (Autoload) with DatabaseService functionality
- [ ] Move _safe_copy_variant logic from database_service.gd to firebase_service.gd for ARM64 stability
- [ ] Transfer listener signal definitions (child_added, child_changed, child_removed) to FirebaseService
- [ ] Implement signal forwarding logic directly in FirebaseService._connect_cpp_signals
- [ ] Refactor FirebaseServiceBackend to use FirebaseService directly instead of DatabaseService
- [ ] Update all CRUD methods in FirebaseServiceBackend to call FirebaseService methods directly
- [ ] Convert FirebaseServiceBackend methods to handle FirebaseRequest objects properly with await_completion()
- [ ] Refactor listener methods (start_listening, stop_listening) to use FirebaseService directly
- [ ] Delete project/firebase/database_service.gd after successful migration
- [ ] Verify BackendAsyncPatternTestAction continues to function correctly
- [ ] Ensure FirebaseRateLimiter continues to function during direct FirebaseService calls
- [ ] Validate performance improvements through reduced call stack depth
- [ ] Update all dependent code that references DatabaseService to use FirebaseService directly
<!-- AC:END -->
