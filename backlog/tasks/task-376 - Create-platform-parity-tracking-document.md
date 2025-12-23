---
id: task-376
title: Create platform parity tracking document
status: To Do
assignee: []
created_date: '2025-12-23 23:01'
updated_date: '2025-12-23 23:40'
labels:
  - documentation
  - parity
  - infrastructure
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Problem

There's no centralized tracking of platform capability parity. The analysis that generated these tasks should be preserved.

## Solution

Create a document (or backlog doc) that tracks:

### Capability Matrix
| Capability | Android | Editor | iOS | macOS | Windows | Win-Physical |
|------------|---------|--------|-----|-------|---------|--------------|
| Automated testing | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manual testing | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| Checksum update | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Checksum reset | ✅ | ⚠️ | ❌ | ✅ | ✅ | ❌ |
| Error analysis | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Device monitoring | ✅ | N/A | ⚠️ | N/A | N/A | ❌ |
| Fastbuild | ✅ | N/A | ❌ | ❌ | ❌ | N/A |

### Standard Recipe Patterns
Document the expected recipe pattern for each platform:
- `test-{platform}` - fzf selector
- `test-{platform}-target CONFIG` - automated
- `test-{platform}-manual CONFIG` - manual
- `test-{platform}-update CONFIG` - baseline update
- `test-{platform}-reset CONFIG` - baseline reset
- etc.

### Parity Scores
Track completion percentage for each platform.

## Location

Create as `backlog/docs/platform-parity.md` or as a backlog document.

## Reference

Part of platform parity analysis - Infrastructure/Cleanup.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Platform parity document created (backlog doc or markdown file)
- [ ] #2 Capability matrix included for all 6 platforms
- [ ] #3 Standard recipe patterns documented
- [ ] #4 Parity scores calculated and tracked
- [ ] #5 Validation: Document accurately reflects current state
- [ ] #6 Document linked from CLAUDE.md or ARCHITECTURE.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Order: Wave 0 (First)

This task must complete before all others - establishes baseline tracking.

## Chunked Validation

### Chunk 1: Create Document Structure
1. Create `backlog/docs/doc-platform-parity.md`
2. Add capability matrix skeleton
3. Validate: `backlog doc view doc-platform-parity`

### Chunk 2: Populate Current State
1. Run `just --list | grep test-` to audit test recipes
2. Run `just --list | grep logs-` to audit log recipes
3. Fill in matrix with current ✅/❌ status
4. Validate: Matrix matches `just --list` output

### Chunk 3: Add Recipe Patterns
1. Document standard recipe pattern for each category
2. Add parity scores
3. Validate: Review against task list (361-379)
<!-- SECTION:PLAN:END -->
