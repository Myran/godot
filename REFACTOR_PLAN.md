# Refactor Plan: Remove Auto-Detection, Keep Platform-Specific Commands

## Current State

We have successfully implemented and validated:

### ✅ Working Platform-Specific Commands
- `replay-generate-android SESSION_ID CONFIG_NAME`
- `replay-generate-from-last-session-android CONFIG_NAME`
- `replay-generate-desktop SESSION_ID CONFIG_NAME`
- `replay-generate-from-last-session-desktop CONFIG_NAME`

### ✅ Working Helper Functions
- `_generate-debug-actions-inline`
- `_extract-checksums-to-android-config`
- `_extract-checksums-to-desktop-config`
- `_add-checksum-config-to-android-file`
- `_add-checksum-config-to-desktop-file`

### ✅ Auto-Detection Wrappers (TO BE REMOVED)
- `replay-generate session_id config_name=""` (auto-detection wrapper)
- `replay-generate-from-last-session config_name` (auto-detection wrapper)

## Changes to Make

### 1. Remove Auto-Detection Wrapper Functions
**Remove these functions entirely:**
- Lines ~1708-1727: `replay-generate-from-last-session` (auto-detection wrapper)
- Lines ~1729-1753: `replay-generate` (auto-detection wrapper)

### 2. Keep Platform-Specific Commands
**Keep these functions as the primary interface:**
- `replay-generate-android` - Generate from Android logs with session ID
- `replay-generate-from-last-session-android` - Generate from most recent Android session
- `replay-generate-desktop` - Generate from Desktop logs with session ID  
- `replay-generate-from-last-session-desktop` - Generate from most recent Desktop session

### 3. Update Documentation
**Update help text and comments to reflect:**
- No more auto-detection
- Users explicitly choose Android or Desktop commands
- Clear guidance on which command to use when

## Benefits of This Change

### 🎯 **Explicit Intent**
```bash
# Clear intent - user knows exactly which platform
just replay-generate-desktop SESSION_ID CONFIG_NAME
just replay-generate-android SESSION_ID CONFIG_NAME
```

### 🚀 **Simpler Logic**
- No more platform detection code
- No more delegation logic
- Direct execution of intended function

### 🔧 **Better Error Messages**
- Platform-specific error messages
- No confusion about which platform was detected
- Clear guidance for each platform

### 📖 **Clearer Usage**
```bash
# Desktop development
just replay-generate-from-last-session-desktop my_test

# Android development  
just replay-generate-from-last-session-android my_test
```

## Files to Modify

### 1. `justfiles/justfile-semantic-replay-commands.justfile`
- Remove auto-detection wrapper functions
- Keep platform-specific functions
- Update section headers/comments

### 2. `CLAUDE.md` (if needed)
- Update command examples to use platform-specific commands
- Remove references to auto-detection

## Validation

After changes, ensure:
1. ✅ `just --list | grep replay` shows only platform-specific commands
2. ✅ `just replay-generate-desktop` works correctly
3. ✅ `just replay-generate-android` works correctly  
4. ✅ No broken function references
5. ✅ All helper functions still work

## Current Function Count
**Before refactor:** 8 replay functions (4 platform-specific + 4 auto-detection/legacy)
**After refactor:** 4 replay functions (4 platform-specific only)

This simplification eliminates complexity while maintaining all the validated functionality.