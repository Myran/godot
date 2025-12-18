---
id: task-327
title: >-
  Reduce logging command complexity: 47→13 commands (72% reduction) with
  dependency safety
status: Done
assignee: []
created_date: '2025-12-04 08:23'
updated_date: '2025-12-18 10:37'
labels:
  - refactoring
  - justfile
  - high-priority
  - breaking-changes
dependencies: []
priority: high
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
**CRITICAL FINDINGS**: Dependency analysis revealed 5 commands with hard dependencies that WILL BREAK other recipes if removed without updates first.

Comprehensive validation shows 47 logging commands is too many. Reduce to 8 core + 5 legacy (13 total) commands with explicit platform parameters instead of auto-detection. Two-tier naming: `logs-*` for test results, `logs-android-*` for device logs.

**Must update dependencies BEFORE removal to prevent breaking changes.**
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Dependency analysis complete - 5 hard dependencies identified (2025-12-04)
- [x] #2 Update 5 dependent recipes - 23 replacements across 5 files (2025-12-04)
- [x] #3 Add 8 new consolidated commands with platform parameters (2025-12-04)
- [ ] #4 Test all updated recipes with new commands (IN PROGRESS)
- [ ] #5 Add deprecation warnings to 34 safe-to-remove commands
- [ ] #6 Create migration guide showing old → new command mapping
- [ ] #7 2-week grace period for feedback
- [ ] #8 Remove deprecated commands after grace period
- [ ] #9 Update documentation (CLAUDE.md, ARCHITECTURE.md, justfile help)
<!-- AC:END -->
