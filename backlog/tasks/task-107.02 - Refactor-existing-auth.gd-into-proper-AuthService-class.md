---
id: task-107.02
title: Refactor existing auth.gd into proper AuthService class
status: To Do
assignee: []
created_date: '2025-08-30 16:10'
labels:
  - firebase
  - architecture
  - authentication
dependencies: []
parent_task_id: task-107
priority: high
---

## Description

Transform the existing auth.gd file into a properly structured AuthService class that follows the FirebaseRequest async pattern and integrates with the Anti-Corruption Layer architecture. The current auth system has authentication methods but lacks proper error handling and async patterns.

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AuthService class extends proper base class and follows project patterns,All existing authentication methods (uid, Apple auth, Facebook auth) work with FirebaseRequest pattern,Firebase authentication integration uses firebase_service.gd Anti-Corruption Layer,Error handling upgraded to use firebase_auth_error.gd consistently,Authentication state management improved with proper signal-based async patterns,All existing auth functionality maintains behavioral compatibility during migration,Unit tests achieve >90% coverage for AuthService lifecycle and error scenarios
<!-- AC:END -->
