# Enhanced Debug Help - Model for improved help system
help-debug-enhanced:
    #!/usr/bin/env bash
    set -euo pipefail
    cat << 'EOF'
🐛 Debug & Testing Workflow Guide (Enhanced)
============================================

📋 TL;DR - QUICK REFERENCE
==========================
Emergency: just logs-errors-tagged TEST_ID (5 sec, <10 tokens)
Daily: just test-android development-workflow (comprehensive validation)
Iterate: just config-restart-android ACTION (5-second cycles)
Debug: Progressive → logs-errors-tagged → logs TEST_ID [component] → logs TEST_ID [component] [operation]

🚀 CORE WORKFLOW MATRIX
=======================
| TASK                    | COMMAND                              | TIME  | TOKENS |
|-------------------------|--------------------------------------|-------|--------|
| Quick error scan       | just logs-errors-tagged TEST_ID     | 5s    | <10    |
| Component analysis      | just logs TEST_ID [component]        | 15s   | <100   |
| Precision debugging     | just logs TEST_ID [comp] [operation] | 30s   | <200   |
| Fast iteration          | just config-restart-android ACTION  | 5s    | N/A    |
| Full validation         | just test-android development-workflow| 2-5m  | N/A    |

🔧 SMART DEBUGGING DECISION TREE
================================

┌─ Issue Detected?
├─ 🚨 STEP 1: Error Scan (5 sec, <10 tokens)
│   └─ just logs-errors-tagged TEST_ID
│       ├─ ✅ Errors found → Follow patterns below  
│       └─ ❌ No errors → Go to Step 2
│
├─ 🎯 STEP 2: Component Analysis (15 sec, <100 tokens)  
│   └─ just logs TEST_ID [component]
│       ├─ Firebase: just logs TEST_ID firebase
│       ├─ Battle: just logs TEST_ID battle  
│       ├─ System: just logs TEST_ID system
│       └─ Checksum: just logs TEST_ID checksum
│
└─ 🔬 STEP 3: Precision (30 sec, <200 tokens)
    └─ just logs TEST_ID [component] [operation] [status]

🔥 FAILURE PATTERN LIBRARY
==========================
| SYMPTOM                          | DEBUG COMMAND                        | FIX COMMAND                     |
|----------------------------------|--------------------------------------|---------------------------------|
| 🔥 Firebase timeout/auth failed  | logs-errors-tagged TEST_ID firebase | test-android 'system.network.*'|
| 🎯 Hash mismatch/validation fail | logs TEST_ID battle determinism     | test-android 'game.match.reset'|
| ⚡ Performance/timeouts          | logs-performance-tagged TEST_ID     | test-android '*.*.performance' |
| 🔄 Startup/registry errors       | logs TEST_ID system startup         | test-android 'system.debug.*'  |
| 🧪 Checksum mismatch            | logs-errors-tagged TEST_ID checksum | test-android-update CONFIG     |

📱 TESTING COMMAND REFERENCE
============================

PRIMARY COMMANDS (Auto-detection):
┌─────────────────────────────────────────────────────────────────────────────────┐
│ just test-android TARGET                # Main interface (auto-detects type)    │
│ just test-android-target CONFIG         # Automated mode (quits after)          │  
│ just test-android-enhanced TARGET       # Enhanced error analysis               │
└─────────────────────────────────────────────────────────────────────────────────┘

WORKFLOW COMMANDS:
```bash
# Standard workflows
just test-android development-workflow     # Daily development validation
just test-android pre-commit               # Pre-commit test suite  
just test-android production-ready         # Release validation
```

⚡ CONFIG COMMANDS (5-second iterations)
=======================================
```bash
# Ultra-fast testing cycles
just config-restart-android ACTION         # Deploy + restart (5 sec total)
just config-push-android CONFIG            # Deploy config only (2 sec)

# Configuration management  
just config-list                           # List available configs
just config-status-android                 # Check current config
just config-clear-android                  # Clear external config

# Runtime logger control (no rebuild needed)
just config-android-tags "active" "ignored" # Focus/filter log components  
just config-android-level DEBUG             # Set log verbosity
just config-android-reset                   # Reset to project defaults
just restart-android-app                    # Apply logger changes
```

🎯 WILDCARD PATTERNS (Zero-maintenance auto-discovery)
======================================================
HIERARCHICAL STRUCTURE: layer.domain.operation

LAYER WILDCARDS:
```bash
just test-android 'cpp.*'                 # C++ Firebase SDK (8 actions)
just test-android 'backend.*'             # Backend Firebase (7 actions)  
just test-android 'rtdb.*'                # RTDB API (19 actions)
just test-android 'system.*'              # System utilities (5 actions)
just test-android 'game.*'                # Game logic (12 actions)
```

DOMAIN WILDCARDS (Cross-layer):
```bash
just test-android '*.firebase.*'          # All Firebase ops (all layers)
just test-android '*.debug.*'             # All debug utilities
just test-android '*.match.*'             # All game match functionality
```

OPERATION WILDCARDS (Cross-everything):
```bash
just test-android '*.*.error_handling'    # All error handling implementations
just test-android '*.*.performance'       # All performance tests
just test-android '*.*.set_value'         # All data writing operations
just test-android '*.*.get_value'         # All data reading operations
```

📊 TOKEN-EFFICIENT LOG ANALYSIS
===============================
LOG COMMAND HIERARCHY (90-98% token savings vs full logs):

PROGRESSIVE ANALYSIS:
```bash
# 1. Quick error scan (98% savings, <10 tokens)
just logs-errors-tagged TEST_ID [tags]

# 2. Component analysis (87-95% savings, <100 tokens)  
just logs TEST_ID [component]

# 3. Focused debugging (<200 tokens)
just logs TEST_ID [component] [operation] [status]
```

SPECIALIZED COMMANDS:
```bash
# Performance analysis
just logs-performance-tagged TEST_ID [tags] # Performance data only
just logs-lifecycle-tagged TEST_ID [tags]   # App lifecycle events

# Desktop analysis  
just logs-desktop-errors                    # Desktop errors only
just logs-desktop-performance               # Desktop performance data

# Latest run (99% savings, <5 tokens)
just logs-last                              # Most recent test results
```

🎯 PRACTICAL EXAMPLES  
=====================

EXAMPLE 1: Firebase Connection Issues
```bash
# 1. Quick scan
$ just logs-errors-tagged abc123

# Output shows: "Firebase timeout", "Connection refused"  
# → This is a Firebase issue

# 2. Focus on Firebase  
$ just logs-errors-tagged abc123 firebase
# → Shows specific Firebase errors

# 3. Fix network layer
$ just test-android 'system.network.*'
```

EXAMPLE 2: Performance Issues
```bash  
# 1. Performance-focused scan
$ just logs-performance-tagged abc123

# Shows: Slow battle calculations, 5000ms timeouts
# → Performance problem in battle system

# 2. Focus analysis  
$ just logs-performance-tagged abc123 battle

# 3. Test performance fixes
$ just test-android '*.*.performance'
```

EXAMPLE 3: Rapid Development Iteration
```bash
# 1. Edit code → Test immediately (5 seconds)
$ just config-restart-android 'system.debug.registry_stats'

# 2. Test entire layer after changes (5 seconds)
$ just config-restart-android 'cpp.*'

# 3. Full validation when ready (30+ seconds)  
$ just test-android 'cpp.*'
```

🚨 CRITICAL: Debug Action Execution
===================================
⚠️  ALWAYS use `test-*` commands for debug actions:

✅ CORRECT:
```bash
just test-desktop CONFIG              # Enables debug coordinator
just test-android CONFIG              # Debug actions execute properly
```

❌ WRONG:
```bash  
just run-desktop                      # Skips debug coordinator (editor mode)
just run-android-debug                # Debug actions won't execute
```

IMPACT: State capture, checksum validation, semantic logging require debug actions.

🔄 CROSS-REFERENCES
===================
• Detailed log analysis → just help-logs
• Build system integration → just help-build  
• Workflow patterns → just help-workflows
• Command discovery → just help-wildcards
• Config management → just help-config

✅ SUCCESS CRITERIA  
===================
YOU'RE DONE WHEN:
□ Errors found in <30 seconds using logs-errors-tagged
□ Root cause identified in <5 minutes using progressive debugging
□ Fix validated in <1 minute using config-restart-android  
□ Full test suite passes with test-android development-workflow

🎯 Ready for efficient debugging!
   Start with: just logs-errors-tagged TEST_ID
EOF