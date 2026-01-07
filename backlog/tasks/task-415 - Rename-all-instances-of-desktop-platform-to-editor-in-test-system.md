---
id: task-415
title: Rename all instances of 'desktop' platform to 'editor' in test system
status: Consider
assignee: []
created_date: '2026-01-03 23:22'
updated_date: '2026-01-07 04:51'
labels: []
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The test system currently uses 'desktop' to refer to the Godot Editor, but this is confusing since we now have two real desktop targets (macOS and Windows-Physical). We need to rename all instances of 'desktop' to 'editor' throughout the test infrastructure, justfiles, and documentation. This is a careful refactoring task that requires updating:
- Test config platform arrays (desktop → editor)
- Justfile recipe names and descriptions
- Documentation and comments
- Platform detection logic

Related to task-414 iOS Firebase Auth testing work.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All test config platform arrays updated from 'desktop' to 'editor'
- [ ] #2 Justfile recipe names containing 'desktop' renamed to 'editor'
- [ ] #3 Documentation and comments updated to use 'editor' terminology
- [ ] #4 Platform detection logic updated (desktop → editor)
- [ ] #5 Cross-platform tests still work after rename
- [ ] #6 No remaining references to 'desktop' platform in test system
<!-- AC:END -->
