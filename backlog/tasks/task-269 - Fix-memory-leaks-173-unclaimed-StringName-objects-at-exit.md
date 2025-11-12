---
id: task-269
title: 'Fix memory leaks: 173 unclaimed StringName objects at exit'
status: Done
assignee: []
created_date: '2025-11-10 23:12'
updated_date: '2025-11-12 07:51'
labels: []
dependencies: []
---

## Description

**Memory leak confirmed**: 135 unclaimed StringName objects detected at Godot editor exit (down from 173 originally reported).

**Evidence**: Build log `20251111_155255_build.log` shows consistent StringName leaks during Android export process, repeating 6 times with 135 unclaimed objects each occurrence.

**Key findings**:
- **810 total "Orphan StringName" entries** across all categories
- Issue occurs during **Godot editor shutdown** in build/export workflow
- **Primarily affects editor-related components** and Sentry integration
- **Count reduced from 173 → 135**, suggesting partial improvements or variation

**Major contributor categories**:
- **Sentry integration** (20+ StringName types): SentryBreadcrumb, SentryEvent, SentryAttachment, etc.
- **Editor system** (50+ StringName types): EditorDebuggerSession, EditorInspector, EditorPlugin, etc.
- **Core Godot engine** (30+ StringName types): Node, Resource, Script, RenderingServer, etc.
- **UI components** (15+ StringName types): Button, Control, Window, Container, etc.

## Root Cause Analysis

**Primary suspect**: Sentry integration appears to be a major contributor with 20+ custom StringName types that may not be properly cleaned up during editor shutdown.

**Investigation needed**:
1. **Sentry singleton cleanup**: Check if Sentry integration properly deregisters StringNames during editor exit
2. **Editor plugin lifecycle**: Verify if editor plugins follow proper cleanup patterns
3. **Static StringName usage**: Identify if any components use static StringNames without proper disposal
4. **Godot editor vs runtime**: Determine if this is purely an editor issue or affects runtime builds

**Hypothesis**: The recent Sentry integration (task-267) introduced StringName registrations that aren't properly cleaned up during editor shutdown, causing memory leaks in the build process.

## Acceptance Criteria

- [ ] Reduce unclaimed StringName objects from 135 to < 50 at editor exit
- [ ] Fix Sentry integration StringName cleanup during editor shutdown
- [ ] Verify no StringName leaks in runtime (non-editor) builds
- [ ] Test with verbose StringName debugging to confirm cleanup
- [ ] Document StringName cleanup best practices for editor plugins
- [ ] Validate fix doesn't break Sentry functionality
- [ ] Ensure build process completes without memory leak warnings

## Implementation Plan

### Phase 1: Investigation (Day 1)
1. **Analyze Sentry integration code**
   - Review Sentry singleton cleanup patterns
   - Check StringName registration/deregistration in Sentry plugin
   - Identify static vs dynamic StringName usage

2. **Godot editor shutdown debugging**
   - Run editor with verbose StringName tracking
   - Compare StringName counts with/without Sentry enabled
   - Identify cleanup order and timing issues

### Phase 2: Fix Implementation (Day 2)
1. **Sentry cleanup improvements**
   - Implement proper StringName deregistration in editor exit
   - Add cleanup handlers for editor plugin lifecycle
   - Fix static StringName disposal patterns

2. **Editor plugin fixes**
   - Review and fix editor plugin cleanup code
   - Implement proper resource disposal patterns
   - Add editor shutdown validation

### Phase 3: Validation (Day 3)
1. **Comprehensive testing**
   - Test builds with StringName debugging enabled
   - Verify no regressions in Sentry functionality
   - Validate memory leak reduction targets met
   - Document cleanup procedures
