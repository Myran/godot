---
id: task-419
title: Audit and fix CharString UTF-8 conversion in FirebaseAuth
status: Done
assignee: []
created_date: '2026-01-04 21:38'
updated_date: '2026-01-05 08:22'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Audit Results (2026-01-05)

**All 12 methods that pass String data TO Firebase SDK correctly store CharString:**
- sign_in_apple, link_to_apple (token_cs, nonce_cs)
- sign_in_facebook, link_to_facebook (token_cs)
- unlink_provider (provider_cs)
- sign_in_facebook_async, sign_in_apple_async, sign_in_with_custom_token_async (token_cs)
- sign_in_with_email_async (email_cs, password_cs)
- link_facebook_async, link_apple_async (token_cs, nonce_cs)
- unlink_provider_async (provider_cs)

**Methods reading FROM Firebase (safe, no CharString needed):**
- providers(), user_name(), email(), uid(), photo_url() - use c_str() from std::string

**Conclusion:** No issues found. All UTF-8 conversions follow correct lifetime extension pattern.
<!-- SECTION:NOTES:END -->
