---
id: task-403
title: 'Firebase Services Integration Epic - Auth, Remote Config, Firestore, Analytics'
status: In Progress
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2026-01-07 00:33'
labels:
  - firebase
  - epic
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Epic task tracking the implementation of remaining Firebase services following the established RTDB architecture patterns. This coordinates the work across Auth, Remote Config, Firestore, Analytics, and Steam Auth.

## Existing Code Analysis (2025-12-31)

### C++ Layer Status

| Service | File Exists | Code Size | Needs Work |
|---------|-------------|-----------|------------|
| **Database** | ✅ `database.cpp` | 51KB | ✅ REFERENCE IMPLEMENTATION |
| **Auth** | ✅ `auth.cpp` | 11KB | ⚠️ REFACTOR (add thread safety) |
| **Remote Config** | ✅ `remote_config.cpp` | 5KB | ⚠️ UPGRADE (add patterns) |
| **Analytics** | ❌ None | - | 🆕 NEW (library linked) |
| **Firestore** | ❌ None | - | 🆕 NEW (verify library first) |

### GDScript Layer Status

| Component | Exists | Reusable |
|-----------|--------|----------|
| `firebase_request.gd` | ✅ | ✅ Use for all async ops |
| `firebase_rate_limiter.gd` | ✅ | ✅ Circuit breaker pattern |
| `firebase_service.gd` | ✅ | ✅ Extend with new services |
| `database_service.gd` | ✅ | ✅ Template for new services |
| `auth.gd` | ✅ | ✅ Extend for new methods |

## Child Tasks

1. **task-402** - Firebase Analytics (RECOMMENDED FIRST)
   - Library already linked on all platforms
   - Simplest implementation (fire-and-forget)
   - Proves C++ → GDScript pattern works
   - **Scope**: NEW C++ module + GDScript service

2. **task-399** - Firebase Auth Enhancement
   - C++ exists but needs thread-safety refactoring
   - Required for Steam auth and service integration
   - **Scope**: REFACTOR existing C++ + extend GDScript

3. **task-400** - Firebase Remote Config Enhancement
   - C++ exists with basic functionality
   - Needs thread-safety upgrade and new methods
   - **Scope**: UPGRADE existing C++ + NEW GDScript service

4. **task-401** - Cloud Firestore (HIGHEST RISK)
   - New C++ module from scratch
   - Library existence MUST be verified first
   - Most complex implementation
   - **Scope**: Verify library → NEW C++ module + GDScript

5. **task-404** - Steam Auth with Firebase Custom Tokens
   - Depends on task-399 completion
   - Requires backend Cloud Function infrastructure
   - External dependency on GodotSteam GDExtension
   - **Scope**: GDExtension integration + backend + C++ extension

## Recommended Implementation Order

| Phase | Task | Type | Risk | Rationale |
|-------|------|------|------|-----------|
| 1 | task-402 | NEW | LOW | Simplest, proves pattern, immediate value |
| 2 | task-399 | REFACTOR | MEDIUM | Foundation, unblocks Steam auth |
| 3 | task-400 | UPGRADE | LOW | Feature flags for safe rollouts |
| 4 | task-401 | NEW | HIGH | Most complex, verify library first |
| 5 | task-404 | NEW | MEDIUM | Depends on Auth + backend infra |

## Shared Architecture Patterns

All implementations must follow patterns from `database.cpp`:
- Thread-safe singleton with `std::mutex` and `std::atomic`
- `is_shutting_down` flag for cleanup safety
- MessageQueue marshalling for worker → main thread
- Request ID tracking for concurrent operations
- Use existing `FirebaseRequest` pattern in GDScript
- Rate limiting through `firebase_rate_limiter.gd`
- Debug action testing (5+ actions per service)
- Cross-platform test configurations

## Key Reference Files

**C++ Patterns:**
- `godot/modules/firebase/database.cpp:88-120` - Thread-safe singleton
- `godot/modules/firebase/database.cpp:404-453` - MessageQueue marshalling
- `godot/modules/firebase/database.cpp:814-862` - Main thread handlers
- `godot/modules/firebase/convertor.cpp` - Type conversion

**GDScript Patterns:**
- `project/firebase/firebase_request.gd` - Async with ARM64 safety
- `project/firebase/firebase_service.gd` - Central coordinator
- `project/firebase/database_service.gd` - Service layer template

**Debug Action Patterns:**
- `project/debug/actions/firebase_cpp/` - C++ testing (10 actions)
- `project/debug/actions/firebase_backend/` - Backend testing (11 actions)

## Success Criteria

- All 5 Firebase services integrated and tested
- Consistent architecture matching database.cpp patterns
- Full test coverage on Android, iOS, macOS, Windows
- Documentation in code and CLAUDE.md updated
- Each service independently disableable for rollback
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 #1 task-399 (Auth) completed with all acceptance criteria met
- [x] #2 #2 task-400 (Remote Config) completed with all acceptance criteria met
- [ ] #3 #3 task-401 (Firestore) completed with all acceptance criteria met
- [x] #4 #4 task-402 (Analytics) completed with all acceptance criteria met
- [ ] #5 #5 task-404 (Steam Auth) completed with all acceptance criteria met
- [ ] #6 #6 All services follow consistent 3-layer architecture (C++ → GDScript Service → Backend)
- [ ] #7 #7 Cross-platform testing passes on Android (arm64 device)

- [ ] #8 #8 Cross-platform testing passes on iOS (arm64 device)
- [ ] #9 #9 Cross-platform testing passes on macOS (Universal binary)
- [ ] #10 #10 Cross-platform testing passes on Windows (x64 physical machine)
- [ ] #11 #11 Integration test: Auth user ID correctly linked to Analytics
- [ ] #12 #12 Integration test: Auth state affects Firestore security rules
- [ ] #13 #13 Integration test: Remote Config respects Auth user targeting
- [ ] #14 #14 CLAUDE.md updated with Firebase services documentation
- [ ] #15 #15 All C++ modules use thread-safe singleton pattern from database.h
- [ ] #16 #16 All C++ modules implement shutdown safety (is_shutting_down flag)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### Epic Coordination Requirements

**1. Platform Testing Must Be Explicit**
Original criteria was too vague. Split into specific platforms with architecture:
- Android: arm64 (modern devices)
- iOS: arm64 device (not simulator)
- macOS: Universal binary (arm64 + x86_64)
- Windows: x64 physical machine (not VM for GUI tests)

**2. Integration Tests Required**
Services interact with each other. Must verify:
- Auth user ID → Analytics user ID linking works
- Auth state → Firestore security rules respected
- Auth user → Remote Config targeting works

**3. Recommended Implementation Order**

| Phase | Task | Rationale |
|-------|------|----------|
| 1 | task-402 (Analytics) | Simplest, proves pattern, immediate value |
| 2 | task-399 (Auth) | Foundation, blocks Steam and service integration |
| 3 | task-400 (Remote Config) | Feature flags for safe rollouts |
| 4 | task-401 (Firestore) | Most complex, do last |
| 5 | task-404 (Steam Auth) | Depends on Auth + backend infra |

**4. Rollback Strategy**
Each service should be independently disable-able:
```gdscript
# firebase_service.gd
var analytics_enabled: bool = true
var firestore_enabled: bool = true
# etc.
```

If a service causes issues in production, we can disable it without full rollback.

**5. Child Task Added**
Added task-404 (Steam Auth) as 5th child task in this epic.

## Revised Epic Scope (2025-12-31)

### Key Discoveries from Code Exploration

**1. Existing C++ is More Complete Than Expected:**
- `auth.cpp` (11KB) already has all social auth methods
- `remote_config.cpp` (5KB) already has value retrieval
- Only need to refactor/upgrade, not rewrite

**2. GDScript Patterns Are Production-Tested:**
- `firebase_request.gd` handles ARM64 memory alignment
- `firebase_rate_limiter.gd` has circuit breaker pattern
- `firebase_service.gd` has request queueing
- Extend these, don't reinvent

**3. Analytics Library Already Linked:**
- SCsub shows `libfirebase_analytics.a` on all platforms
- Can immediately implement C++ module
- No build system changes needed

**4. Firestore Library Status Unknown:**
- NOT found in SCsub exploration
- Must verify existence before implementation
- May need SDK update or alternative approach

### Risk-Adjusted Implementation Order

| Order | Task | Actual Scope | Risk |
|-------|------|--------------|------|
| 1 | task-402 | NEW C++ (simple) | LOW |
| 2 | task-399 | REFACTOR existing | MEDIUM |
| 3 | task-400 | UPGRADE existing | LOW |
| 4 | task-401 | NEW C++ (complex) | HIGH |
| 5 | task-404 | Multi-component | MEDIUM |

### Child Task Scope Summary

**task-399 (Auth):**
- Was: "Add GDScript layer"
- Now: REFACTOR C++ to add thread safety + extend GDScript

**task-400 (Remote Config):**
- Was: "New implementation"
- Now: UPGRADE existing C++ + add GDScript service

**task-402 (Analytics):**
- Was: Unknown complexity
- Now: NEW but simple (fire-and-forget, library linked)

**task-401 (Firestore):**
- Was: "New C++ module"
- Now: VERIFY library first → then NEW C++ module

**task-404 (Steam):**
- Unchanged: External dependencies + backend infrastructure

## Progress Update (2026-01-03)

### Completed Child Tasks (2 of 5)

**task-402 (Analytics)** - ✅ **DONE** (2025-12-31)
- Firebase Analytics C++ module implemented with UTF-8 dangling pointer fix
- 6 debug actions all passing: log_event_basic, log_event_params, set_user_id, set_user_property, collection_enabled, reset_data
- Cross-platform validation completed on Android, iOS, macOS, Windows
- Key commits: `ee6b7657`, `6341d941`, `e7a925df`, `4af23be4`

**task-400 (Remote Config)** - ✅ **DONE** (2026-01-01)
- Remote Config debug actions and service layer implemented
- Comprehensive tests with local+remote validation
- TDD test infrastructure established
- iOS cache issue diagnosed and resolved
- Key commits: `d92c8df2`, `9d2e443b`, `efb6d6bd`, `e3701903`, `411a0bec`

### Remaining Child Tasks (3 of 5)

**task-399 (Auth)** - To Do
- Required for Steam auth (signInWithCustomToken)
- Thread-safe singleton refactoring needed

**task-401 (Firestore)** - To Do (HIGHEST RISK)
- Library existence must be verified first
- Depends on Auth completion

**task-404 (Steam Auth)** - To Do
- Blocked by task-399 (Auth)
- Requires backend Cloud Function infrastructure

### Related Commits (Last 3 Days)

```
e3701903 feat: update godot submodule with Remote Config diagnostic improvements
411a0bec docs: resolve iOS Remote Config cache issue and cleanup logging
efb6d6bd feat: Add Firebase Remote Config C++ debug actions and TDD test infrastructure
9d2e443b feat: Implement comprehensive Remote Config tests with local+remote validation
d92c8df2 feat: Add Firebase Remote Config debug actions and service layer
6341d941 feat: Complete Firebase Analytics cross-platform validation
ee6b7657 feat: Implement Firebase Analytics with UTF-8 dangling pointer fix
8bbfa6cb feat: Implement Firebase SDK Test Suite for TDD Development (task-406)
```

### Infrastructure Improvements

- TDD test suite established (task-406) enabling rapid Firebase development
- Build-export-test recipes added for all platforms
- Cross-platform testing infrastructure validated

### Next Steps

1. **Recommended**: Start task-399 (Auth) - unblocks Steam auth and service integration
2. After Auth: task-401 (Firestore) with library verification first
3. Finally: task-404 (Steam Auth) once Auth is complete

### Progress Update (2026-01-06)

**task-404 (Steam Auth)** - ✅ **PLACEHOLDER DONE** (2026-01-06)

- SteamAuthService created with graceful degradation pattern

- Cloud Function backend documentation created

- 4 debug tests passing (validate behavior when Steam unavailable)

- Full implementation pending: GodotSteam GDExtension integration + backend deployment

### Completed Child Tasks (3 of 5)

- task-402 (Analytics) - ✅ DONE

- task-400 (Remote Config) - ✅ DONE

- task-404 (Steam Auth) - ✅ PLACEHOLDER DONE (graceful degradation)

### Remaining Child Tasks (2 of 5)

- task-399 (Auth) - To Do (unblocks Steam full implementation)

- task-401 (Firestore) - To Do
<!-- SECTION:NOTES:END -->
