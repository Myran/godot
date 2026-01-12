---
id: task-429
title: >-
  Fix Sentry macOS crash: RenderingServer singleton access during early
  initialization
status: To Do
assignee: []
created_date: '2026-01-07 17:42'
labels:
  - bugfix
  - sentry
  - macos
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sentry GDExtension crashes on macOS when accessing RenderingServer::get_singleton() during early initialization in make_performance_context() at contexts.cpp:343.

The crash occurs because Sentry's performance context capture runs before RenderingServer is initialized. This is triggered during crash handling when the app exits early.

Error:
ERROR: Failed to retrieve non-existent singleton 'RenderingServer'.
   at: get_singleton_object (core/config/engine.cpp:308)
ERROR: Parameter 'RenderingServer::get_singleton()' is null.
   at: make_performance_context (src/sentry/contexts.cpp:343)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sentry safely handles early init phase before RenderingServer exists,macOS automated tests pass without Sentry crash,Performance context capture defers until RenderingServer available
<!-- AC:END -->
