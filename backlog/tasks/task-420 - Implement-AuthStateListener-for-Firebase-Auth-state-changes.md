---
id: task-420
title: Implement AuthStateListener for Firebase Auth state changes
status: Done
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-05 08:41'
labels:
  - firebase
  - auth
  - cpp
  - listener
  - state
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Task Description

Implement AuthStateListener to track Firebase Auth user state changes in real-time.

**From task-399 acceptance criteria**:
- C++ layer: AuthStateListener implementation

## Acceptance Criteria
1. Implement AuthStateListener class in C++ layer
2. Register listener with Firebase SDK
3. Emit signals when auth state changes (signed in, signed out)
4. Add C++ layer test: `cpp.firebase.auth.state_listener`
5. Add service layer test: `backend.firebase.auth.state_changes`
6. Verify listener cleanup on app exit
7. Test on Android platform

## Technical Notes
- Firebase SDK provides auth state listener callbacks
- Should emit Godot signals for GDScript consumption
- Must handle app lifecycle events (background/foreground)

## Related
- Parent task: task-399 (Firebase Auth service layer)
- Critical for real-time auth state tracking
<!-- SECTION:DESCRIPTION:END -->
