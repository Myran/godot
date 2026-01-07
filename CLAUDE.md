# CLAUDE.md

@./CLAUDE-ADVANCED.md
@./justfiles/CLAUDE.md

<!-- Contextual: project/, tests/, godot/modules/firebase/ have CLAUDE.md files -->

GameTwo mobile game with custom Godot 4.3 engine, Firebase integration, and debugging systems.

## 🔍 Streamlined Logging System

**🆕 Unified Log Command (Primary Interface):**
```bash
just logs TEST_ID                         # Smart defaults: errors + auto-platform
just logs TEST_ID --platform android      # Explicit platform
just logs TEST_ID --search "term"         # Search instead of errors
just logs TEST_ID --full                  # All content, not just errors
just logs TEST_ID --raw                   # No filtering, for piping
```

**Legacy Commands (still work, with deprecation notices):**
- `just logs-errors TEST_ID [PLATFORM]` - Error-focused analysis (98% savings)
- `just logs-search TEST_ID "pattern" [PLATFORM]` - Text search (98% savings)
- `just logs-pattern TEST_ID "wildcard*" [PLATFORM]` - Wildcard pattern matching

**Platform-Specific Log Retrieval:**
- `just logs-android TEST_ID [TAGS]` - Android logs with optional tag filtering
- `just logs-editor TEST_ID [TAGS]` - Editor logs with optional tag filtering
- `just logs-ios TEST_ID [TAGS]` - iOS logs with optional tag filtering
- `just logs-macos TEST_ID [TAGS]` - macOS logs with optional tag filtering
- `just logs-windows-physical TEST_ID` - Windows physical machine logs

**Platform-Specific Error Analysis (⚠️ Deprecated - use `just logs TEST_ID --platform X`):**
- `just logs-android-errors TEST_ID [TAGS]` - Android errors with optional tag filtering
- `just logs-editor-errors TEST_ID [TAGS]` - Editor errors with optional tag filtering
- `just logs-ios-errors TEST_ID [TAGS]` - iOS errors with optional tag filtering
- `just logs-macos-errors TEST_ID [TAGS]` - macOS errors with optional tag filtering
- `just logs-windows-physical-errors TEST_ID` - Windows physical machine errors

**Android Device Log Management:**
- `just logs-android-device "SEARCH_TERM" [LINES]` - Device log search (consolidated 6 commands)
- `just logs-android-clear` - Clear device buffers (replaced android-logs-clear-lightweight)
- `just logs-android-health` - Buffer health monitoring (replaced android-logs-health-check)
- `just logs-android-status` - Device & app diagnostics

**Platform Auto-Detection:**
- Commands auto-detect platform from TEST_ID prefix (`android_*`, `editor_*`, `ios_*`, `macos_*`, `windows-physical_*`)
- Explicit platform available: `PLATFORM="android|editor|ios|macos|windows"`
- Backwards compatible: defaults to "auto" if no platform specified

**🚨 Migration Guide (Old → New):**
- `logs-android-errors TEST_ID` → `just logs TEST_ID --platform android`
- `logs-editor-errors TEST_ID` → `just logs TEST_ID --platform editor`
- `logs-ios-errors TEST_ID` → `just logs TEST_ID --platform ios`
- `logs-macos-errors TEST_ID` → `just logs TEST_ID --platform macos`
- `logs-text TEST_ID "pattern"` → `just logs TEST_ID --search "pattern"`
- `logs-last*` commands → Removed (use `just logs TEST_ID`)
- `android-logs-search` → `logs-android-device`
- `android-logs-clear-lightweight` → `logs-android-clear`
- `android-logs-health-check` → `logs-android-health`

## 📝 Backlog Management

**Essential Commands:**
- `backlog tasks list --plain` - List tasks by status
- `backlog tasks view task-XXX --plain` - View task details
- `backlog tasks create "Title"` - Create task
- `backlog tasks edit task-XXX` - Edit task
- `backlog tasks edit task-XXX --status Done` - **Update status (REQUIRED for sync)**
- `backlog doc list` - List documents
- `backlog doc view DOC_ID` - View document
- `backlog board` - Kanban view
- `backlog overview` - Project statistics
- `backlog browser` - Interactive browser

## 🎯 Checksum Baseline Management

**Essential Commands:**
- `just test-android-update CONFIG_NAME` - Update Android checksum baseline
- `just test-editor-update CONFIG_NAME` - Update Editor/Desktop checksum baseline
- `just test-ios-update CONFIG_NAME` - Update iOS checksum baseline
- `just test-macos-update CONFIG_NAME` - Update macOS checksum baseline
- `just test-windows-update CONFIG_NAME` - Update Windows VM checksum baseline
- `just test-windows-physical-update CONFIG_NAME` - Update Windows Physical checksum baseline
- `just test-android-reset CONFIG_NAME` - Reset Android baseline (start fresh)
- `just test-editor-reset CONFIG_NAME` - Reset Editor/Desktop baseline
- `just test-ios-reset CONFIG_NAME` - Reset iOS baseline
- `just test-macos-reset CONFIG_NAME` - Reset macOS baseline
- `just test-windows-reset CONFIG_NAME` - Reset Windows VM baseline
- `just test-windows-physical-reset CONFIG_NAME` - Reset Windows Physical baseline

**When to Update Baselines:**
- ✅ **Legitimate system changes** (new features, balance updates)
- ✅ **Card stat changes** (intentional balance modifications)
- ✅ **Expected gameplay changes** (new mechanics, animations)
- ✅ **Engine optimization changes** (improved performance, new rendering)

**When to Reset Baselines:**
- 🔄 **Starting over** (completely new test setup)
- 🔄 **Baseline corruption** (damaged checksum files)
- 🔄 **Major refactoring** (fundamental system changes)

**Workflow Integration:**
1. **Run test** → Detects checksum mismatch
2. **Review changes** → Confirm they're legitimate
3. **Update baseline** → `just test-android-update CONFIG_NAME`
4. **Re-run test** → Validates new baseline
5. **Commit** → Both code and updated baseline

**Interactive Usage:**
```bash
just test-android-update          # Shows menu of available configs
just test-editor-update           # Shows menu of available configs
just test-ios-update              # Shows menu of available configs
just test-macos-update            # Shows menu of available configs
just test-windows-update          # Shows menu of available configs
just test-windows-physical-update # Shows menu of available configs
```

**🚨 CRITICAL: Use CLI Commands, Not Direct File Editing**

Backlog maintains separate database that doesn't sync with direct markdown edits.

**Workflow:**
1. **Content Changes**: `backlog tasks edit task-XXX` (opens editor)
2. **Status Changes**: ALWAYS use `backlog tasks edit task-XXX --status Done`
3. **Bulk Updates**: `for task in 248 249 250; do backlog tasks edit task-$task --status Done; done`

**Task Creation & Linking:**
```bash
# Investigation → Documentation → Task Creation
just logs-errors TEST_ID
just logs-search TEST_ID "pattern"
backlog tasks create "Fix discovered issue"
# Add investigation context and links

# Link in commits
git commit -m "fix: description

Related: task-XXX
Analysis: /tmp/analysis_file.md"
```

**Task Frontmatter:**
```yaml
---
id: task-222
title: Fix Android Checksum Collection Race Condition
status: Open              # Open | In Progress | Done
priority: critical        # low | medium | high | critical
labels:
  - critical
  - test-framework
  - android
dependencies:
  - task-221
created_date: '2025-10-15 19:45'
updated_date: '2025-10-15 19:45'
---
```

**Key Document:**
- `backlog doc view doc-002` - Build System Architecture & Workflows

## 🤖 Claude Code Preferences

**Essential Patterns:**
- Use `rg` instead of `grep` (10x faster)
- REQUIRED: `just fastbuild-android` after ANY GDScript/C++ changes before Android testing
- CRITICAL: Prefix long-running commands with `just log-run-silent` (saves tokens)
- Link tasks bidirectionally: Reference task in commit, commit in task
- Use Advanced OODA Loop Debugging (investigation-first with expert panel)

**🚨 FILE SAFETY:**
- NEVER remove/delete files without explicit permission
- ALWAYS ask before removing any files, even temporary ones

**Values:**
- **Simplicity**: Clean, readable code
- **Robustness**: Handle edge cases reliably

**MCP Tools:**
- **Repomix MCP**: Pack codebase once, search multiple times
- **Godot MCP**: Launch editor, run project, get debug output
- **Context7 MCP**: Get up-to-date docs for any library

**Repomix Codebase Analysis:**
- `just generate-repofile` - Creates repomix-output.xml (276+ files)
- `just generate-claude-context` - Optimized for Claude Code consumption
- Includes: Firebase C++ module, Advanced Logger, Battle System, Gamestate, Checksum validation, 200+ GDScript files
- See [CLAUDE-ADVANCED.md](CLAUDE-ADVANCED.md) for complete Repomix guide and use cases

**Git workflow:**
- Use `git commit --amend` for related documentation updates
- Include "Closes: task-XXX" and "Related: backlog/tasks/..." in commits
- Exception: Use `grep` only for pipeline scripts requiring exact compatibility

## 🔄 OODA Loop Development

**OBSERVE:**
- `just ci-validate` - Code quality, formatting, linting
- `just test` - Cross-platform functionality
- `just logs-errors TEST_ID` - Runtime issues (98% efficiency)

**ORIENT:**
- CI results → Code standards assessment
- Test results → Platform compatibility
- Error analysis → Technical issues

**DECIDE:**
- CI pass/fail → Commit readiness
- Test pass/fail → Feature stability
- Performance → Architectural decisions

**ACT:**
- Failed CI → Fix → `just ci-validate` → Repeat
- Failed tests → `just logs-errors TEST_ID` → Debug → `just fastbuild-android` → Re-test
- All pass → Continue

**Critical Pattern:**
```bash
just ci-validate           # Must pass
just fastbuild-android     # Required after code changes
just test-android CONFIG   # Validate on platform
just logs-errors TEST_ID   # Debug efficiently
```

**Deploy vs Ship:**
```bash
# Deploy = Development (export → install → run)
just deploy-android        # Deploy to Android device
just deploy-ios            # Deploy to iOS (default: iPad)
just deploy-ios-iphone     # Deploy to iPhone
just deploy-macos          # Deploy to macOS (export + run)
just deploy-windows        # Deploy to Windows physical

# Ship = Production (App Store)
just ship-android          # Ship to Play Store
just ship-ios              # Ship to App Store
```

**Clear Test Config (before deploy to avoid stale tests):**
```bash
just clear-test-android          # Clear Android device config
just clear-test-ios              # Clear iOS export bundle config
just clear-test-macos            # Clear macOS user data config
just clear-test-editor          # Clear desktop/editor config
just clear-test-windows-physical # Clear Windows physical machine config
```

## 🎯 Advanced OODA Debugging

**Evidence-First Investigation (OBSERVE):**
```bash
just logs-android-device "SEARCH_TERM"     # Full device logs (consolidated)
just logs-errors TEST_ID                   # 98% efficient analysis
just logs-search TEST_ID "specific_term"   # Targeted search (replaced logs-text)
```

**🚨 CRITICAL**: Gather current evidence, not rely on stale documentation.

**Expert Panel Evaluation (ORIENT):**

**Virtual Expert Panel** for complex issues:
- **Systems Architect** - Mobile/game engine expertise
- **Platform Specialist** - Android/Firebase/GDScript integration
- **Test Infrastructure Lead** - Testing patterns, CI/CD impact
- **Performance Engineer** - Timing, threading, optimization
- **Debt Reviewer** - Architecture decisions, maintainability

**Core Questions:**
1. "What would this expert think is the REAL problem?"
2. "What would this expert warn against fixing?"
3. "What evidence would this expert demand?"
4. "What dangerous oversimplification exists?"

**Investigation-First Decisions:**
❌ Avoid: Symptom-based fixes that break working systems
✅ Prefer: Evidence-gathering reveals true state

**Priority:**
1. Investigation (always start here)
2. Targeted Fix (only after understanding)
3. Architecture Review (last resort)
4. Workarounds (avoid - creates debt)

**Minimal Risk Implementation:**
1. Add targeted logging
2. Test and gather evidence
3. Analyze with expert panel mindset
4. Apply minimal fix based on evidence
5. Remove investigation code
6. Document with evidence

**Key Insights:**
- Investigation-first prevents fixing working code
- Error messages show symptoms, not root causes
- Evidence reveals reality vs. assumptions
- Time: 4-6h investigation vs 20-40h risky changes

**Expert Panel Validation:**
Before complex fixes, require unanimous agreement from all expert perspectives on architectural compatibility.

## 🚨 Android Log Buffer Limitations

**Root Cause**: Android logcat uses circular buffers (~50KB each) that overwrite older entries when full, causing misdiagnosis.

**Real-World Impact (Task-242)**:
- Investigation showed 2/16 successful Firebase operations
- Reality: 14/16 successful (proven by historical logs)
- Buffer overwrote 12 success entries with newer data
- Cost: 4-6h wasted investigating non-existent regression

**Buffer Status Indicators:**
- **🟢 Safe**: <30,000 lines (≤60% usage)
- **🟡 Caution**: 30,000-50,000 lines (60-90% usage)
- **🔴 Critical**: >50,000 lines (>90% usage)

**Buffer-Safe Investigation:**

**Phase 1: Assessment**
```bash
just logs-android-health                   # Check buffer health first
```

**Phase 2: Cross-Validation (if saturation detected)**
```bash
find logs/ -name "*.log" -exec grep -l "search_term" {} \;  # Historical logs
just logs-search TEST_ID "search_term"                        # Search saved test logs
```

**Phase 3: Fresh Collection**
```bash
just logs-android-clear                    # Clear buffer (consolidated)
just test-android-target CONFIG           # Re-run test
just logs-android-device "*" 50          # Live monitoring (consolidated)
```

**Decision Tree:**
- **Buffer Safe (<60%)** → Use live buffer tools
- **Buffer Caution (60-90%)** → Cross-validate required
- **Buffer Critical (>90%)** → Use historical logs only

**Prevention:**
```bash
just logs-android-clear                    # Clear before testing (consolidated)
just log-run-silent test-android CONFIG   # Save complete output
```

**Red Flags (Buffer Issues):**
- Expected logs missing
- Fewer entries than expected
- Historical patterns disappeared
- Unusually poor performance data

**Response Protocol:**
1. Stop investigation (findings may be misleading)
2. Check buffer saturation
3. Switch to historical sources if critical
4. Re-run tests with cleared buffer

**Golden Rule**: Cross-validate with historical logs when in doubt. Live buffer data may be incomplete.

## 🪟 Windows Development

**Windows uses a two-machine architecture:** (Task-368)
- **Windows VM (192.168.50.92)** - `win-vm-*` recipes - Template building with native MSVC
- **Windows Physical (192.168.50.80)** - `win-physical-*` / `test-windows-physical-*` - GUI testing

**Recipe Naming Convention:**
- `test-windows-*` → Tests on VM (headless capable)
- `test-windows-physical-*` → Tests on physical machine (GUI mode)
- `win-vm-*` → VM operations (building)
- `win-physical-*` → Physical machine operations (deploy, wake, status)

**Essential Commands:**
```bash
# Build & Export (VM-based)
just build-all-windows           # Complete build: templates + sentry + package
just export-windows-debug        # Export debug build
just export-windows-release      # Export release build
just validate-windows-export     # Validate Firebase/Sentry integration

# Physical Machine Testing
just win-physical-status         # Check if machine is awake
just win-physical-wake           # Send Wake-on-LAN packet
just win-physical-deploy         # Deploy Windows export
just test-windows-physical-target CONFIG  # Automated GUI testing
just test-windows-physical-manual CONFIG  # Manual testing (stays open)

# Logs
just logs-windows-physical TEST_ID        # Retrieve test logs
just logs-windows-physical-errors TEST_ID # Error analysis
```

**Key Features:**
- ✅ Firebase C++ SDK integration (shared code architecture)
- ✅ Sentry GDExtension with crashpad backend (out-of-process crash handling)
- ✅ Native MSVC builds (ARM64→x64 cross-compilation on VM)
- ✅ Full testing infrastructure with GUI mode

**See**: `just help-windows` for complete Windows command reference

## 📂 Directory-Specific Documentation

**Comprehensive guides available in subdirectories** (loaded contextually when working in those areas):

### **`project/` - GDScript Game Code**
- GDScript anti-patterns (timing-based waits, async keyword)
- Strong typing requirements (fail-fast patterns)
- Firebase integration patterns
- Scene & node best practices
- Debug action registration
- See: `project/CLAUDE.md` (loads when editing game code)

### **`tests/` - Testing Infrastructure**
- Replay testing workflow (Play → Generate → Test)
- Checksum testing & validation
- Gamestate system (90% faster iteration)
- Test configuration format
- Debug workflow patterns
- See: `tests/CLAUDE.md` (loads when working on tests)

### **`godot/modules/firebase/` - Firebase C++ Module**
- C++ SDK integration
- Type conversion (GDScript ↔ Firebase)
- Platform-specific builds (Android/iOS)
- SCons build configuration
- Memory & thread safety
- See: `godot/modules/firebase/CLAUDE.md` (loads when editing module)

## 📖 Advanced Topics

**See [CLAUDE-ADVANCED.md](CLAUDE-ADVANCED.md) for:**
- Wildcard pattern system deep dive
- Git workflow & backlog integration
- Repomix MCP best practices
- Project architecture & structure
- Performance optimization strategies
- Complete command reference

**Key Documents:**
- **Build System**: `backlog doc view doc-002` - Complete build flows and timing

**MCP Tools:**
- **Repomix MCP**: Strategic codebase analysis for GameTwo's architecture
- **Godot MCP**: Direct Godot 4.3 integration and project management
- **Context7 MCP**: Library documentation for Firebase and GDScript

**For complex tasks:**
- `just generate-claude-context` - Optimized project context (250k tokens)
- Creates `claude-project-context.xml` for full codebase analysis

---

*This CLAUDE.md focuses on daily GameTwo development essentials.*
