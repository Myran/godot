---
id: task-411
title: >-
  Fix iOS Remote Config test failures - get_int and get_string returning
  unexpected values despite fetch_and_activate succeeding
status: In Progress
assignee: []
created_date: '2026-01-02 19:56'
updated_date: '2026-01-02 20:06'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
iOS Remote Config returns empty/default values because Firebase Console has different parameters for iOS app.

**Root Cause:** iOS Firebase Remote Config has:
- test_string, test_bool, test_number, test_int, test_float

But tests expect:
- max_players (100), retry_count (3), welcome_message ('Hello, World!'), app_name ('GameTwo')

**Fix:** Add missing parameters in Firebase Remote Config Console for iOS app (App ID: 1:308611281726:ios:c1b2f39901375e7692f26f)

**Note:** macOS and Android use same project but get correct values, suggesting platform-specific parameter targeting in Firebase Console.
<!-- SECTION:DESCRIPTION:END -->
