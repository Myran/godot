---
id: task-168
title: Implement no-focus background launch for automated Godot tests on macOS
status: To Do
assignee: []
created_date: '2025-09-20 07:34'
labels:
  - enhancement
  - macos
  - ci
  - automation
dependencies: []
priority: high
---

## Description

## Context

Current automated desktop tests launch Godot with --minimized flag which minimizes the window but still captures focus, interrupting developer workflow during CI/testing.

## Research Findings

Based on GitHub research and macOS automation analysis:

### Methods That Work (With Caveats):
1. **`open -gj` Command**
   - Works for: Native macOS apps (Safari, Firefox, TextEdit)
   - Doesn't work for: Electron apps, some applications ignore flags
   - Usage: `open -gj /Applications/App.app --args <command-line-args>`

2. **AppleScript + osascript**
   - More reliable across app types
   - Example: `osascript -e 'launch app "AppName"' -e 'tell app "System Events" to set visible of process "AppName" to false'`

3. **Godot Window FLAGS**
   - FLAG_NO_FOCUS: Prevents window from receiving focus
   - UNFOCUSABLE flag: Makes window visible but non-interactive
   - Runtime control via main.gd modifications

### Known Issues from GitHub:
- Docker for Mac Issue #5962: `open -g` doesn't work
- Postman Issue #7112: Ignores -g flag and steals focus  
- UTM Issue #2280: No native headless mode
- Electron apps generally don't respect macOS background launch flags

## Implementation Plan

### Phase 1: Test Native macOS Support
1. Test if Godot respects `open -gj` background launch flags
2. Modify justfile-validation-enhanced-testing.justfile automated test commands:
   - Current: `./editor/{{GODOT_EXECUTABLE}} --path {{PROJECT_PATH}} --test-mode --minimized`
   - Test: `open -gj ./editor/{{GODOT_EXECUTABLE}} --args --path {{PROJECT_PATH}} --test-mode --minimized`

### Phase 2: Godot Window Flag Fallback
1. Add `--no-focus` flag detection to main.gd
2. Implement FLAG_NO_FOCUS window flag when detected
3. Combine with existing --minimized for complete background behavior

### Phase 3: Validation & Hybrid Approach
1. Add detection to verify background launch worked (focus not stolen)
2. Implement automatic fallback from macOS `open` to Godot flags
3. Add platform detection (macOS-only feature)

## Benefits
- **Improved Developer Experience**: Terminal/IDE stays focused during automated testing
- **Better CI Performance**: No focus interruption during test execution  
- **Robust Implementation**: Multiple fallback methods for reliability

## Files to Modify
1. `justfiles/justfile-validation-enhanced-testing.justfile` (lines 2618, 3216)
2. `project/main.gd` (add --no-focus flag support)
3. Test validation scripts

## Success Criteria
- Automated desktop tests launch without stealing focus from terminal/IDE
- Manual tests remain visible for verification
- Cross-platform compatibility maintained (macOS-specific enhancement)
- Fallback mechanisms work when primary method fails
