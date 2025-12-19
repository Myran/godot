---
id: task-131
title: Fix gamestate testing command-line integration issues
status: Done
assignee: []
created_date: '2025-09-07 08:39'
updated_date: '2025-12-18 10:37'
labels:
  - testing
  - integration
  - gamestate
dependencies: []
priority: high
ordinal: 167000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Address command-line parsing and platform-specific issues in gamestate testing integration while preserving the working core functionality from commit 7f04aaee. The underlying gamestate testing system works correctly - this task focuses on fixing the integration layer issues that prevent seamless usage.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 @ symbol reference parsing works correctly in test commands (just test-target @reference works)
- [x] #2 Command execution script error is resolved (return statement outside function)
- [ ] #3 **Android DataSource/Firebase backend initialization works correctly** - CURRENT STATUS: ❌ Still hangs, never completes
- [x] #4 Desktop gamestate testing works completely via command-line
- [ ] #5 **Android gamestate test action collection functions properly** - CURRENT STATUS: Still "Actions collected: 0"
- [ ] #6 **Android debug coordinator properly emits DEBUG_TEST_SUCCESS events** - CURRENT STATUS: Debug coordinator never starts due to Game initialization hang
- [ ] #7 **Both desktop and Android platforms execute gamestate tests successfully** - CURRENT STATUS: Desktop ✅ perfect, Android ❌ broken
- [ ] #8 All existing gamestate functionality continues to work without regression
<!-- AC:END -->
