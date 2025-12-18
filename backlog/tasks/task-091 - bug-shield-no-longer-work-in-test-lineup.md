---
id: task-091
title: bug shield no longer work in test lineup
status: Done
assignee: []
created_date: '2025-08-22 12:50'
updated_date: '2025-12-18 10:37'
labels: []
dependencies: []
ordinal: 206000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
shield no longer shield from first damage in test lineup as expected
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Resolved as side effect of TASK-106. The shield functionality has been fixed by the commits 5b2573fc and 4c00d34f which restored shield ability functionality by adding missing 'onanyupgrade' ability parsing and restored archer damage shield testing scaffolding. Testing with ability-guard-01 config shows shield functionality is working correctly (test passes with no errors, checksum differences indicate behavior changes from the fix).
<!-- SECTION:NOTES:END -->
