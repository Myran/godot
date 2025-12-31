---
id: task-385
title: Investigate adding Firebase to Godot editor for desktop testing
status: Consider
assignee: []
created_date: '2025-12-26 10:39'
updated_date: '2025-12-29 00:07'
labels:
  - firebase
  - editor
  - desktop
  - investigation
  - developer-experience
dependencies: []
priority: low
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Opportunity

Currently Firebase is only available on mobile platforms (Android/iOS) and exported apps. The Godot editor cannot use Firebase, which limits desktop development testing.

## Current State

When running tests in editor mode, this error appears:
```
ERROR: Unable to load Firebase app options ([google-services-desktop.json, google-services.json] are missing or malformed)
```

### What Works
- **Android**: Firebase via C++ module + google-services.json
- **iOS**: Firebase via C++ module + GoogleService-Info.plist
- **Exported macOS/Windows apps**: Should work with proper config

### What Doesn't Work
- **Godot Editor**: No Firebase - can't load google-services.json

## Why This Matters

1. **Faster iteration**: Editor testing is instant vs 30-60s Android fastbuild
2. **Better debugging**: Full debugger access in editor
3. **Unified testing**: Same tests could run in editor and on devices
4. **Sentry-Firebase integration testing**: Can't test user context flow in editor

## Investigation Areas

1. **google-services-desktop.json**: Does this exist? What format should it have?
2. **Firebase C++ SDK desktop support**: Is there a desktop version we can use?
3. **Firebase REST API fallback**: Could editor use REST API instead of native SDK?
4. **Mock Firebase backend**: Could we create a local mock for editor testing?

## Technical Context

Firebase integration architecture:
- `godot/modules/firebase/` - C++ Firebase module
- `project/firebase/` - GDScript wrappers
- `firebase/google-services-desktop.json` - Desktop config (if exists)
- `project/data/backends/firebase_service_backend.gd` - Backend implementation

## Trade-offs

| Approach | Pros | Cons |
|----------|------|------|
| Desktop C++ SDK | Full parity | Complex build, large binary |
| REST API | Simple, no build changes | Different code paths, auth complexity |
| Mock backend | Fast, reliable | Not testing real Firebase |
| Skip editor Firebase | No work needed | Limited editor testing |

## Conversation Reference

Session ID: 2025-12-26 Sentry test coverage analysis
Context: While investigating Sentry test failures, discovered editor platform lacks both Sentry AND Firebase. Removed editor from Sentry test platforms. This task explores whether Firebase could be added to editor for broader test coverage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Investigation complete with recommendation
- [ ] #2 Trade-offs documented
- [ ] #3 If feasible: POC implementation plan created
- [ ] #4 If not feasible: Rationale documented
<!-- AC:END -->
