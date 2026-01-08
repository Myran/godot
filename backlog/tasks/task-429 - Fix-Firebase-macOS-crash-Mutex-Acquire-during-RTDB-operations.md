---
id: task-429
title: 'Fix Firebase macOS crash: Mutex::Acquire() during RTDB operations'
status: In Progress
assignee: []
created_date: '2026-01-07 17:42'
updated_date: '2026-01-07 18:09'
labels:
  - cpp
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Firebase C++ SDK crashes on macOS in Mutex::Acquire() during RTDB operations. The crash occurs in firebase::scheduler::Scheduler::Schedule when processing database queries via FirebaseDatabase::get_value_async(). This is a Firebase threading issue on macOS, NOT related to Sentry context capture as initially suspected.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sentry safely handles early init phase before RenderingServer exists,macOS automated tests pass without Sentry crash,Performance context capture defers until RenderingServer available
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROOT CAUNE ANALYSIS:

Real crash is in Firebase C++ SDK Mutex::Acquire(), NOT Sentry RenderingServer.

Stack trace:
- firebase::Mutex::Acquire() + 12
- firebase::scheduler::Scheduler::Schedule(...)
- firebase::database::internal::QueryInternal::GetValue()
- FirebaseDatabase::get_value_async()

This is a Firebase RTDB threading issue on macOS, not Sentry-related.

The Sentry RenderingServer ERROR was a red herring - just a warning log.

The macOS SDK version fix (task-427) resolved linker issues but exposed this deeper Firebase threading bug.

MACOS CRASH REPORT ANALYSIS (from ~/Library/Logs/DiagnosticReports/):

File: gametwo-2026-01-07-185719.ips
Exception: EXC_BAD_ACCESS (SIGABRT)
Address: 0x38 (NULL pointer dereference)
Termination: Abort trap: 6

CRITICAL FINDING:
firebase::Mutex::Acquire() + 12 appears TWICE consecutively in stack trace!

This suggests:
1. Double-acquisition bug (same mutex locked twice)
2. Recursive locking issue (thread trying to lock mutex it already holds)
3. Invalid pthread_mutex_t (NULL or corrupted mutex pointer)

The crash happens during RTDB get_value_async() when:
- firebase::database::internal::QueryInternal::GetValue()
- firebase::scheduler::Scheduler::Schedule()
- firebase::Mutex::Acquire() ← CRASH HERE

Threading context:
- Multiple Firebase worker threads active
- Firebase REST Curl thread active
- Main thread crashes during scheduler mutex lock

This is a Firebase C++ SDK bug in mutex handling, NOT a Sentry issue.

**ROOT CAUSE ANALYSIS (2026-01-07)**

Sentry: EXC_BAD_ACCESS at 0x38 in firebase::Mutex::Acquire()

Stack: FirebaseDatabase::get_value_async → QueryInternal::GetValue → Scheduler::Schedule → Mutex::Acquire CRASH

CRITICAL: Mutex::Acquire appears TWICE at same address - recursive locking/re-entrancy

Root Cause: Firebase SDK internal bug - scheduler mutex is NULL (0x38 = offset into NULL pointer)

Hypothesis: Uninitialized scheduler mutex on macOS OR recursive locking (CFRunLoop re-entering)

Test: firebase-cpp-layer runs concurrent_operations_test

Workaround: Add sequential delays between Firebase calls

Next: File bug with Firebase SDK team, verify scheduler initialization
<!-- SECTION:NOTES:END -->
