---
id: task-403
title: 'Firebase Services Integration Epic - Auth, Remote Config, Firestore, Analytics'
status: To Do
assignee: []
created_date: '2025-12-30 21:26'
updated_date: '2025-12-31 11:21'
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
- [ ] #2 #2 task-400 (Remote Config) completed with all acceptance criteria met
- [ ] #3 #3 task-401 (Firestore) completed with all acceptance criteria met
- [ ] #4 #4 task-402 (Analytics) completed with all acceptance criteria met
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
<!-- SECTION:NOTES:END -->
