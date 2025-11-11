---
id: task-274
title: Update Godot Build Commands with Modern SCons Arguments and Production Flags
status: To Do
assignee: []
created_date: '2025-11-11 10:26'
updated_date: '2025-11-11 13:07'
labels:
  - build-system
  - godot-engine
  - optimization
  - technical-debt
dependencies: []
priority: medium
---

## Description

Update Godot Engine SCons build commands across all justfile recipes to use modern Godot 4.5 arguments and production optimization flags. Current build commands are missing critical optimization flags like `production=yes` for release builds, which can result in suboptimal binary performance and larger binary sizes.

**Current State:**
- Android template builds: Missing `production=yes` on `template_release` builds
- iOS template builds: Missing `production=yes` on `template_release` builds
- macOS template builds: Missing `production=yes` on `template_release` builds
- Editor builds: Using `use_lto=yes` but could benefit from additional optimization flags
- Inconsistent argument patterns across platforms

**Target State:**
- All release template builds use `production=yes` for maximum optimization
- Consistent SCons argument patterns across all platforms (Android, iOS, macOS)
- Updated documentation to reflect modern Godot 4.5 build practices
- Clear distinction between development builds (`dev_build=yes`) and production builds (`production=yes`)

## Root Cause Analysis

**Investigation Findings:**

According to Godot 4.5 official documentation (Context7 research):

1. **Modern Android Template Pattern:**
   ```bash
   # Release templates (production-optimized)
   scons platform=android target=template_release arch=arm64 production=yes

   # Debug templates (development)
   scons platform=android target=template_debug arch=arm64

   # Editor builds (production-optimized)
   scons platform=android target=editor arch=arm64 production=yes
   ```

2. **Server/Headless Build Pattern:**
   ```bash
   # Release server (production-optimized)
   scons platform=linuxbsd target=template_release production=yes

   # Debug server (development)
   scons platform=linuxbsd target=template_debug
   ```

3. **Current GameTwo Commands (justfile-platform-android.justfile:160-164):**
   ```bash
   # Missing production=yes on release builds
   scons platform=android target=template_debug arch=arm32 arch=arm64 --jobs={{jobs}}
   scons platform=android target=template_release arch=arm32 arch=arm64 --jobs={{jobs}}
   ```

4. **Current GameTwo Commands (justfile-build-system.justfile:30-31):**
   ```bash
   # Missing production=yes on release builds
   scons platform=macos target=template_debug --jobs={{jobs}}
   scons platform=macos target=template_release --jobs={{jobs}}
   ```

**Impact Assessment:**
- **Performance**: `production=yes` enables aggressive compiler optimizations for release builds
- **Binary Size**: Production builds may result in smaller optimized binaries
- **Debugging**: Keeping debug builds without `production=yes` preserves debugging capabilities
- **Consistency**: Aligning with official Godot patterns improves maintainability

## Proposed Solutions

### Option 1: Minimal Update (Recommended - Low Risk)

Add `production=yes` to all `target=template_release` builds across all platforms.

**Pros:**
- Low risk - follows official Godot documentation patterns
- Immediate performance improvement for release builds
- Minimal code changes required
- No impact on debug/development workflows

**Cons:**
- Doesn't address other potential optimization opportunities

**Implementation:**
```bash
# Android (justfile-platform-android.justfile)
scons platform=android target=template_release arch=arm32 arch=arm64 production=yes --jobs={{jobs}}

# macOS (justfile-build-system.justfile)
scons platform=macos target=template_release production=yes --jobs={{jobs}}

# iOS (justfile-build-system.justfile)
scons platform=ios target=template_release arch=arm64 production=yes --jobs={{jobs}}
```

### Option 2: Comprehensive Optimization (Higher Risk)

Add `production=yes` to release builds AND explore additional optimization flags.

**Pros:**
- Maximum performance optimization
- Future-proofs build system
- Aligns with Godot best practices

**Cons:**
- Higher risk - more changes to test
- May require longer build times
- Could introduce compatibility issues

**Additional Flags to Consider:**
- `lto=full` or `lto=thin` - Link-Time Optimization (Note: `use_lto=yes` is deprecated, use `lto=` instead)
- `optimize=speed` or `optimize=size` - Explicit optimization targets
- `debug_symbols=no` - Remove debug symbols from release builds (enabled by `production=yes`)
- `use_static_cpp=yes` - Static linking for portable binaries (enabled by `production=yes`)

**Recommendation:** Start with Option 1, then evaluate Option 2 based on results.

## Comprehensive SCons Optimization Flags (Godot 4.5/4.6)

**Based on official Godot 4.5 source code analysis and documentation:**

### Core Production Flag

**`production=yes`** (Available in Godot 4.x)
- **Description**: "Set defaults to build Godot for use in production"
- **Default**: `False`
- **Automatically Enables**:
  - `use_static_cpp=yes` - Portable binaries for Linux/Windows
  - `debug_symbols=no` - Removes debug symbols (smaller binaries)
  - `lto=auto` - Link-time optimization (platform-specific best defaults)
  - `swappy=yes` (Android only) - Frame pacing support

**CRITICAL: MSVC Limitation**
- Build system **aborts** when using `production=yes` with MSVC compiler
- Reason: MSVC cannot optimize GDScript VM like GCC/Clang (significant performance degradation)
- MSVC LTO support is unreliable and has caused crashes historically
- **Impact**: Windows builds should use GCC (MinGW) or Clang for production mode

### Optimization Level Options

**`optimize=<level>`** (Available in Godot 4.x)
- **Description**: "Optimization level (by default inferred from 'target' and 'dev_build')"
- **Default**: `auto` (smart defaults based on build type)
- **Available Choices**:
  - `auto` - Automatic selection:
    - Dev builds (`dev_build=yes`): Uses `none` (-O0)
    - Debug features (`target=template_debug`): Uses `speed_trace` (-O2)
    - Release builds (`target=template_release`): Uses `speed` (-O3)
  - `none` - No optimization (-O0)
  - `custom` - User-defined CXXFLAGS (no automatic flags)
  - `debug` - Debug-friendly optimization (-Og for GCC/Clang, /Od for MSVC)
  - `speed` - Maximum speed optimization (-O3 for GCC/Clang, /O2 for MSVC)
  - `speed_trace` - Speed with better crash backtraces (-O2, recommended for debugging optimized builds)
  - `size` - Size optimization (-Os for GCC/Clang, /O1 for MSVC)
  - `size_extra` - Aggressive size optimization (-Os + `SIZE_EXTRA` define)

**Platform-Specific Compiler Flags**:
```bash
# GCC/Clang
optimize=speed       → -O3
optimize=speed_trace → -O2
optimize=size        → -Os
optimize=size_extra  → -Os + SIZE_EXTRA define
optimize=debug       → -Og
optimize=none        → -O0

# MSVC
optimize=speed       → /O2 + /OPT:REF + /OPT:NOICF (for speed_trace)
optimize=size        → /O1 + /OPT:REF
optimize=debug/none  → /Od
```

### Link-Time Optimization (LTO)

**`lto=<mode>`** (Available in Godot 4.x)
- **Description**: "Link-time optimization (production builds)"
- **Default**: `none`
- **Available Choices**:
  - `none` - No LTO
  - `auto` - Platform-specific best defaults (chosen by platform detect.py)
  - `thin` - ThinLTO (faster compilation, good optimization) - Clang/LLVM only
  - `full` - Full LTO (slower compilation, maximum optimization)

**Requirements**:
- Significant RAM required (especially `full` mode)
- Best used with GCC or Clang compilers
- **MSVC**: LTO support unreliable, avoid for production

**How `production=yes` Handles LTO**:
- Sets `lto=auto` which delegates to platform-specific detection
- Each platform's `detect.py` chooses best LTO mode for that platform
- Android: Typically uses `thin` LTO
- Linux/macOS: Typically uses `full` LTO
- Windows (MinGW): Typically uses `full` LTO

**DEPRECATED**: `use_lto=yes` is the old flag, replaced by `lto=` in Godot 4.x

### Debug Symbols Options

**`debug_symbols=<bool>`** (Available in all Godot versions)
- **Description**: "Build with debugging symbols"
- **Default**: `False` (except dev builds default to `True`)
- **Effect**:
  - GCC/Clang: Adds `-g` flag
  - MSVC: Adds `/Zi /FS` flags
  - Significantly increases binary size
  - Essential for debugging crashes and profiling

**Related Options**:
- `separate_debug_symbols=yes` - Extract debug symbols to separate file (.pdb for Windows)
- `debug_paths_relative=yes` - Make file paths in debug symbols relative (improves build reproducibility)

**Behavior with `production=yes`**:
- Automatically sets `debug_symbols=no` unless explicitly overridden
- Can override: `scons production=yes debug_symbols=yes` (for profiling production builds)

### Static C++ Linking

**`use_static_cpp=<bool>`** (Available in Godot 4.x)
- **Description**: Statically link C++ standard library
- **Default**: `False`
- **Enabled by**: `production=yes`
- **Benefits**:
  - Portable binaries (no runtime library dependencies)
  - Important for Linux distribution (avoids glibc version conflicts)
  - Important for Windows (avoids MSVC runtime dependencies)

### Development Flags (Inverse of Production)

**`dev_build=yes`** (Available in Godot 4.x)
- **Description**: "Developer build with dev-only debugging code (DEV_ENABLED)"
- **Default**: `False`
- **Effect**:
  - Enables development-only debugging code
  - Sets `debug_symbols=yes` by default
  - Sets `optimize=none` by default
  - Adds `DEV_ENABLED` define

**`dev_mode=yes`** (Available in Godot 4.x)
- **Description**: "Alias for multiple development flags"
- **Equivalent to**: `verbose=yes warnings=extra werror=yes tests=yes strict_checks=yes`
- **Use case**: Maximum strictness during development

### Platform-Specific Considerations

**Android**:
- `production=yes` enables `swappy=yes` (frame pacing)
- LTO mode: Typically `thin` for faster builds
- ARM architectures benefit most from LTO

**iOS**:
- Static linking always enabled (platform requirement)
- LTO highly recommended for App Store builds

**macOS**:
- Universal binaries (arm64 + x86_64) benefit from LTO
- `use_static_cpp` less critical (macOS handles dependencies well)

**Linux**:
- `use_static_cpp=yes` critical for distribution (glibc version conflicts)
- Full LTO provides best optimization

**Windows**:
- **MUST use MinGW-w64 or Clang** for `production=yes`
- MSVC incompatible with production mode
- Static linking avoids MSVC runtime dependency issues

### Recommended Build Configurations

**Development Iteration** (fastest builds):
```bash
scons platform=android target=template_debug arch=arm64 dev_build=yes
# optimize=none, debug_symbols=yes, lto=none
```

**Testing Optimized Builds** (debugging friendly):
```bash
scons platform=android target=template_debug arch=arm64 optimize=speed_trace debug_symbols=yes
# -O2 optimization, debug symbols, no LTO
```

**Production Release** (maximum optimization):
```bash
scons platform=android target=template_release arch=arm64 production=yes
# optimize=speed (-O3), debug_symbols=no, lto=auto, use_static_cpp=yes
```

**Production with Debug Symbols** (profiling/crash analysis):
```bash
scons platform=android target=template_release arch=arm64 production=yes debug_symbols=yes separate_debug_symbols=yes
# All production optimizations + separate .pdb/.dwarf file
```

**Size-Optimized Build** (mobile distribution):
```bash
scons platform=android target=template_release arch=arm64 production=yes optimize=size
# -Os optimization, LTO, static linking
```

**Ultra Size-Optimized** (embedded/minimal):
```bash
scons platform=android target=template_release arch=arm64 production=yes optimize=size_extra
# -Os + SIZE_EXTRA define, maximum size reduction
```

### Godot 4.6 Changes

**Status**: Godot 4.6 is currently in development (dev snapshots available)

**Confirmed Changes** (as of research):
- SCons version bump: 4.9.0 → 4.10.0
- Build system improvements for mingw (big objects enabled in more contexts)
- `fast_unsafe` option no longer auto-enabled with `dev_build=yes`
- Minor build system cleanups and optimizations

**No Breaking Changes** to core optimization flags (`production`, `optimize`, `lto`, `debug_symbols`) identified between 4.5 and 4.6.

**Compatibility**: All optimization strategies documented above are **compatible with Godot 4.5 and 4.6**.

### Flag Precedence and Overrides

**Important**: Explicit flags override `production=yes` defaults:

```bash
# Example: Production mode but keep debug symbols
scons production=yes debug_symbols=yes  # Overrides production's debug_symbols=no

# Example: Production mode but use thin LTO instead of auto
scons production=yes lto=thin  # Explicit LTO mode

# Example: Production mode but custom optimization
scons production=yes optimize=size  # Override default optimize=speed
```

### Verification Commands

**Check what flags are active**:
```bash
# During build, SCons will print:
# "Using LTO: full" (if LTO enabled)
# Optimization flags in compiler output
```

**Verify binary optimization** (post-build):
```bash
# Check binary size
ls -lh bin/godot.*

# Check if debug symbols present (Linux/macOS)
file bin/godot.* | grep "not stripped"

# Check if static linking used (Linux)
ldd bin/godot.* | grep libstdc++  # Should show nothing if static
```

## Implementation Steps

### Phase 1: Audit Current Build Commands

- [ ] Document all current SCons commands across all justfiles
- [ ] Identify all `target=template_release` build commands
- [ ] Identify all `target=editor` build commands (if production flags apply)
- [ ] Create comparison table: Current vs. Recommended

### Phase 2: Update Build Commands

**Files to Modify:**

1. **justfiles/justfile-build-system.justfile**
   - [ ] Line 10: Review editor build - already has `use_lto=yes`
   - [ ] Line 31: Add `production=yes` to macOS template_release
   - [ ] Line 47: Add `production=yes` to iOS template_release

2. **justfiles/justfile-platform-android.justfile**
   - [ ] Line 164: Add `production=yes` to Android template_release
   - [ ] Consider separating debug/release builds for clarity

3. **Documentation Updates:**
   - [ ] Update CLAUDE.md with new build command examples
   - [ ] Update help-build command output
   - [ ] Update backlog/docs/doc-002 (Build System Architecture)

### Phase 3: Testing & Validation

**Build Testing:**
- [ ] Clean build environment: `rm -rf godot/bin/ templates/`
- [ ] Test macOS editor build: `just build-editor`
- [ ] Test macOS template builds: `just build-macos-templates`
- [ ] Test iOS template builds: `just templates-ios`
- [ ] Test Android template builds: `just templates-android`
- [ ] Verify all builds complete without errors

**Binary Validation:**
- [ ] Compare binary sizes (before/after production=yes)
- [ ] Test exported game performance on all platforms
- [ ] Verify Android APK size changes
- [ ] Verify iOS IPA size changes
- [ ] Test debug builds still contain debug symbols

**Integration Testing:**
- [ ] Run complete build pipeline: `just build-all-android`
- [ ] Test fastbuild-android workflow still works
- [ ] Verify export templates work correctly
- [ ] Test game deployment to devices (Android + iOS)

**Regression Testing:**
- [ ] Run comprehensive test suite: `just test-all`
- [ ] Verify Firebase integration still works
- [ ] Verify Sentry integration still works
- [ ] Test battle replay system
- [ ] Test gamestate save/load system

### Phase 4: Documentation & Rollout

- [ ] Update CHANGELOG with build system improvements
- [ ] Document build time comparisons (before/after)
- [ ] Document binary size comparisons (before/after)
- [ ] Update build system diagram in backlog docs
- [ ] Create git commit with comprehensive description

## Testing Checklist

### Pre-Implementation Testing

- [ ] Document current build times for all platforms
- [ ] Document current binary sizes for all platforms
- [ ] Backup current templates directory
- [ ] Tag current commit for easy rollback

### Post-Implementation Testing

**Build Verification:**
- [ ] macOS editor builds successfully
- [ ] macOS templates (debug + release) build successfully
- [ ] iOS templates (debug + release) build successfully
- [ ] Android templates (debug + release) build successfully
- [ ] All binaries execute without errors

**Performance Verification:**
- [ ] Release builds show performance improvement (benchmark tests)
- [ ] Binary sizes are optimized (compare before/after)
- [ ] Build times are acceptable (production=yes may increase compile time)

**Compatibility Verification:**
- [ ] Exported games run correctly on Android
- [ ] Exported games run correctly on iOS
- [ ] Desktop builds run correctly
- [ ] No regressions in Firebase functionality
- [ ] No regressions in Sentry integration

## Success Criteria

- [ ] All `target=template_release` builds use `production=yes`
- [ ] All builds complete without errors
- [ ] Binary sizes are optimized (documented improvement)
- [ ] Game performance improves or remains stable
- [ ] No regressions in existing functionality
- [ ] Documentation accurately reflects new build commands
- [ ] CI/CD pipeline remains functional

## References

**Godot Documentation (4.5-stable):**
- SCons Build Options: https://docs.godotengine.org/en/4.5/engine_details/development/compiling/
- Android Compilation: https://docs.godotengine.org/en/4.5/engine_details/development/compiling/compiling_for_android
- Production Flag Usage: Official docs show `production=yes` for optimized release builds

**Context7 Research:**
- Godot 4.5 documentation confirms `production=yes` is standard for release builds
- Android editor builds: `scons platform=android arch=arm64 production=yes target=editor`
- Android release templates: `scons platform=android target=template_release arch=arm64 production=yes`

**GameTwo Build System:**
- justfiles/justfile-build-system.justfile - Core build commands
- justfiles/justfile-platform-android.justfile - Android-specific builds
- backlog/docs/doc-002 - Build System Architecture reference

## Notes

**Build Time Impact:**
Adding `production=yes` may increase compilation time due to aggressive optimizations. Initial builds with this flag should be timed and documented for future reference.

**Backward Compatibility:**
This change should not affect existing exported games or save files, as it only modifies the engine build process, not runtime behavior.

**Rollback Plan:**
If issues are discovered after implementation:
1. Git revert the commit containing build command changes
2. Rebuild templates without `production=yes`
3. Document specific issues encountered
4. Investigate root cause before re-attempting

**Future Optimization Opportunities:**
- ~~Explore `use_lto=yes` for template builds~~ **DEPRECATED** - Use `lto=auto` or `lto=full` instead (handled by `production=yes`)
- Consider `optimize=size` for mobile templates to reduce download size
- Investigate build profiles for feature-specific optimizations
- Consider `optimize=size_extra` for ultra-minimal builds if needed

---

## Research Summary (2025-11-11)

**Comprehensive optimization research completed for Godot 4.5/4.6 compatibility.**

### Key Findings:

1. **`production=yes` is the recommended approach** - Automatically enables:
   - `use_static_cpp=yes` (portable binaries)
   - `debug_symbols=no` (smaller size)
   - `lto=auto` (platform-specific LTO)
   - `swappy=yes` (Android frame pacing)

2. **`use_lto=yes` is DEPRECATED** in Godot 4.x - Use `lto=` flag instead:
   - `lto=auto` - Platform chooses best mode (recommended)
   - `lto=thin` - ThinLTO (faster compilation, Clang/LLVM only)
   - `lto=full` - Full LTO (maximum optimization, slower builds)

3. **Godot 4.6 Compatibility**: All optimization flags are compatible between 4.5 and 4.6:
   - No breaking changes to `production`, `optimize`, `lto`, or `debug_symbols`
   - SCons version bumped 4.9.0 → 4.10.0
   - Minor build system improvements (mingw, fast_unsafe)

4. **MSVC Limitation**: `production=yes` **aborts** with MSVC compiler
   - MSVC cannot optimize GDScript VM effectively
   - Windows builds must use MinGW-w64 or Clang for production mode

5. **Recommended Strategy for GameTwo**:
   - **Minimal Update (Option 1)**: Add `production=yes` to all `target=template_release` builds
   - **Advanced Optimization**: Consider `optimize=size` for mobile (reduces APK/IPA size)
   - **Debug Profiling**: Use `production=yes debug_symbols=yes separate_debug_symbols=yes`

### Implementation Priority:

**Phase 1 (Low Risk - Recommended):**
```bash
# Android
scons platform=android target=template_release arch=arm64 production=yes --jobs={{jobs}}

# iOS
scons platform=ios target=template_release arch=arm64 production=yes --jobs={{jobs}}

# macOS
scons platform=macos target=template_release production=yes --jobs={{jobs}}
```

**Phase 2 (Optional - Size Optimization):**
```bash
# Mobile size optimization
scons platform=android target=template_release arch=arm64 production=yes optimize=size
```

### Research Sources:
- Godot 4.5 SConstruct analysis (official source code)
- Godot GitHub PR #45679 (production=yes implementation)
- Web search: Godot 4.6 development snapshots
- Context7: Godot engine documentation

**Status**: Ready for implementation with comprehensive understanding of all optimization options.
