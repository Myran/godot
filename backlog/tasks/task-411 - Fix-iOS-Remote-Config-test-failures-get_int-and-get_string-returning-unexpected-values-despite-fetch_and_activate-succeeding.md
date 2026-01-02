---
id: task-411
title: >-
  Fix iOS Remote Config test failures - get_int and get_string returning
  unexpected values despite fetch_and_activate succeeding
status: In Progress
assignee: []
created_date: '2026-01-02 19:56'
updated_date: '2026-01-02 20:11'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Root Cause: Firebase Remote Config Console has Platform condition targeting.

**Evidence:**
- iOS gets: ["test_string", "test_bool", "test_number", "test_int", "test_float"]
- Tests expect: ["max_players", "retry_count", "welcome_message", "app_name"]
- iOS and Desktop use SAME API Key and App ID but get different values

**Official Firebase Docs:**
Remote Config supports 'Platform' condition rule type with values: iOS, Android, Web
Source: https://firebase.google.com/docs/remote-config/parameters

**Fix Required:**
1. Go to Firebase Console → Remote Config → Conditions tab
2. Check for Platform == iOS conditions that override default parameters
3. Either:
   - Remove platform-specific targeting for these parameters, OR
   - Add max_players, retry_count, welcome_message, app_name to iOS platform condition
<!-- SECTION:DESCRIPTION:END -->
