---
id: task-415
title: Rename all instances of 'desktop' platform to 'editor' in test system
status: Consider
assignee: []
created_date: '2026-01-03 23:22'
updated_date: '2026-01-06 10:47'
labels: []
dependencies: []
priority: medium
ordinal: 14000
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
