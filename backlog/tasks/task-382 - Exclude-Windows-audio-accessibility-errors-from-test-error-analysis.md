---
id: task-382
title: Exclude Windows audio/accessibility errors from test error analysis
status: Done
assignee: []
created_date: '2025-12-26 00:27'
updated_date: '2025-12-29 00:07'
labels:
  - windows
  - test-framework
  - false-positive
dependencies: []
priority: high
ordinal: 258000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

Windows Sentry tests fail error analysis despite all test actions passing (100% success rate).

## Root Cause

Three Windows-specific system errors appear in logs and trigger false-positive test failures:

1. `ERROR: Can't create an accessibility driver, accessibility support disabled!`
2. `ERROR: Condition "hr != ((HRESULT)0L)" is true. Returning: ERR_CANT_OPEN`
3. `ERROR: WASAPI: init_output_device error.`

These are environmental errors from:
- **WASAPI** - Windows Audio Session API failing (no audio hardware on test machine)
- **Accessibility driver** - Windows accessibility services unavailable
- Both are unrelated to actual test functionality

## Evidence

From `sentry-all` test run on Windows physical (2025-12-26):
- `sentry-addon-validation`: Actions 2/2 PASSED, Error analysis FAILED
- `sentry-integration-test`: Actions 2/2 PASSED, Error analysis FAILED  
- `sentry-crash-scenarios`: Actions 3/3 PASSED, Error analysis FAILED
- `sentry-integration-bridges`: PASSED (uses expected error validation)

## Solution

Update Windows error filtering in the test infrastructure to exclude these known benign Windows system errors.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Windows audio errors (WASAPI, ERR_CANT_OPEN) excluded from test error analysis
- [x] #2 Windows accessibility driver error excluded from test error analysis
- [x] #3 sentry-all test suite passes on Windows physical machine
- [x] #4 No regression on other platforms
<!-- AC:END -->
