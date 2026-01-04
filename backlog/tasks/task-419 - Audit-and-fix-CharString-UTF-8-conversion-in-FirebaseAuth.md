---
id: task-419
title: Audit and fix CharString UTF-8 conversion in FirebaseAuth
status: To Do
assignee: []
created_date: '2026-01-04 21:38'
labels:
  - firebase
  - auth
  - cpp
  - utf8
  - internationalization
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Task Description

Audit all CharString usage in FirebaseAuth C++ class for proper UTF-8 string handling.

**From task-399 acceptance criteria**:
- C++ layer: CharString UTF-8 audit for proper string conversion

## Acceptance Criteria
1. Audit all CharString usage in `firebase_auth.cpp` and `firebase_auth.h`
2. Identify any improper UTF-8 conversions
3. Fix any encoding issues
4. Add tests for non-ASCII characters in email/password
5. Verify on Android platform

## Technical Notes
- Ensure String::utf8() is used correctly
- Check email, password, and display_name handling
- Test with unicode characters in credentials

## Related
- Parent task: task-399 (Firebase Auth service layer)
- UTF-8 safety is critical for international users
<!-- SECTION:DESCRIPTION:END -->
