---
id: doc-002
title: Justfile Build and Test System Architecture
type: other
created_date: '2025-12-22 10:31'
---
# Justfile Build and Test System Architecture

Comprehensive visual documentation of GameTwo's justfile-based build and test infrastructure.

**Purpose**: Help developers understand system relationships and assist Claude Code in reasoning about the build/test system.

---

## 📋 System Overview

```mermaid
flowchart TB
    subgraph "GameTwo Justfile System"
        direction TB
        MAIN[justfile<br/>Main Entry Point]
        
        subgraph FOUNDATION["🔧 Foundation Layer"]
            CONFIG[justfile-core-config<br/>Variables, Paths, Device IDs]
        end
        
        subgraph BUILD["🏗️ Build System Layer"]
            BUILD_SYS[justfile-build-system<br/>Templates, Pipelines]
            BUILD_UTILS[justfile-build-utils<br/>Helpers, Status]
            PLAT_ANDROID[justfile-platform-android<br/>Android Builds]
            PLAT_IOS[justfile-platform-ios<br/>iOS Builds]
            PLAT_MACOS[justfile-platform-macos<br/>macOS Builds]
            PLAT_WIN[justfile-platform-windows<br/>Windows VM + Physical]
        end
        
        subgraph TEST["🧪 Testing Layer"]
            TEST_CORE[justfile-testing-core<br/>Shared Setup]
            VALID_ENH[justfile-validation-enhanced-testing<br/>Automated Tests]
            CROSS_PLAT[justfile-cross-platform-testing<br/>Multi-Platform]
            VALID[justfile-validation<br/>Syntax, Format]
            CICD[justfile-cicd<br/>CI Pipeline]
        end
        
        subgraph DEBUG["🔍 Debug Layer"]
            LOGS[justfile-logs<br/>Log Extraction]
            WILD_CORE[justfile-wildcard-core<br/>Pattern Engine]
            WILD_CMD[justfile-wildcard-commands<br/>Pattern Interface]
            ENH_LOG[justfile-enhanced-log-analysis<br/>Advanced Analysis]
            ANDROID_LOGS[justfile-android-device-logs<br/>Device Monitoring]
        end
        
        subgraph GAME["🎮 Gamestate Layer"]
            GS_CAP[justfile-gamestate-capture<br/>State Extraction]
            GS_TEST[justfile-gamestate-testing<br/>Save/Load Tests]
            REPLAY[justfile-semantic-replay-commands<br/>Battle Replays]
        end
        
        subgraph SENTRY["📊 Sentry Layer"]
            SENTRY_MAIN[justfile-sentry<br/>Orchestration]
            SENTRY_GD[justfile-gdscript-sentry]
            SENTRY_AND[justfile-native-android-sentry]
            SENTRY_IOS[justfile-native-ios-sentry]
            SENTRY_WIN[justfile-native-windows-sentry]
        end
    end
    
    MAIN --> CONFIG
    CONFIG --> BUILD
    CONFIG --> TEST
    CONFIG --> DEBUG
    CONFIG --> GAME
    CONFIG --> SENTRY
```

---

## 🏗️ Build System Hierarchy

```mermaid
flowchart TB
    subgraph "Complete Build Pipeline (46 min)"
        BUILD["just build"]
        
        subgraph ARTIFACTS["build-artifacts (45 min)"]
            direction TB
            
            subgraph TOOLCHAIN["build-toolchain (40 min)"]
                EDITOR["build-editor<br/>Custom Godot Editor"]
                
                subgraph TEMPLATES["templates-all"]
                    TEMP_IOS["templates-ios<br/>iOS Templates"]
                    TEMP_AND["templates-android<br/>Android Templates"]
                end
            end
            
            INSTALL_TEMP["install-android-template<br/>Extract to project/android/build/"]
            
            subgraph QUICK["quick-build-android"]
                FIREBASE["insert-firebase-dependencies"]
                EXPORT_APK["export-apk-android<br/>Godot Export"]
            end
            
            IOS_PIPE["build-pipeline-ios"]
        end
        
        INSTALL_APK["install-apk-android"]
    end
    
    BUILD --> ARTIFACTS
    ARTIFACTS --> TOOLCHAIN
    TOOLCHAIN --> EDITOR
    TOOLCHAIN --> TEMPLATES
    ARTIFACTS --> INSTALL_TEMP
    ARTIFACTS --> QUICK
    ARTIFACTS --> IOS_PIPE
    BUILD --> INSTALL_APK
```

---

## ⚡ Android Build Pathways

```mermaid
flowchart LR
    subgraph "Android Build Options"
        direction TB
        
        subgraph FULL["🏗️ Full Pipeline (3-25 min)"]
            FULL_CMD["just build-all-android"]
            FULL_TEMP["build-android-templates<br/>SCons → Gradle .aar"]
            FULL_FB["insert-firebase-dependencies"]
            FULL_APK["export-apk-android"]
            FULL_AAB["export-aab-android"]
            
            FULL_CMD --> FULL_TEMP --> FULL_FB --> FULL_APK --> FULL_AAB
        end
        
        subgraph QUICK["🚀 Quick Build (2-3 min)"]
            QUICK_CMD["just quick-build-android"]
            QUICK_FB["insert-firebase-dependencies"]
            QUICK_EXP["export-apk-android"]
            
            QUICK_CMD --> QUICK_FB --> QUICK_EXP
        end
        
        subgraph FAST["⚡ Fast Build (30-60 sec)"]
            FAST_CMD["just fastbuild-android"]
            FAST_EXP["Godot export to /tmp/"]
            FAST_FB["insert-firebase-dependencies"]
            FAST_GRADLE["Gradle assembleStandardDebug"]
            FAST_INST["adb install"]
            FAST_LAUNCH["launch-android"]
            
            FAST_CMD --> FAST_EXP --> FAST_FB --> FAST_GRADLE --> FAST_INST --> FAST_LAUNCH
        end
        
        subgraph CPP["⭐ C++ Dev Workflow"]
            CPP_CMD["just cpp-dev"]
            CPP_TEMP["build-android-templates"]
            CPP_INST["install-android-template"]
            CPP_FAST["fastbuild-android"]
            
            CPP_CMD --> CPP_TEMP --> CPP_INST --> CPP_FAST
        end
    end
    
    style FAST fill:#90EE90
    style CPP fill:#FFD700
```

---

## 🧪 Testing Infrastructure

```mermaid
flowchart TB
    subgraph "Testing System Architecture"
        direction TB
        
        subgraph INPUT["Test Input Types"]
            ACTION["Direct Action<br/>'system.debug.stats'"]
            WILDCARD["Wildcard Pattern<br/>'cpp.*'"]
            CONFIG["Debug Config<br/>'system-testing'"]
            TESTLIST["Test List<br/>'firebase-all'"]
            FOLDER["Folder Pattern<br/>'/archive/replays/'"]
            AT_SYM["@ Symbol<br/>'@*-all'"]
        end
        
        subgraph DETECT["Auto-Detection Engine"]
            DETECT_ENGINE["Input Parser<br/>Determines type & expands patterns"]
        end
        
        subgraph EXECUTE["Test Execution"]
            ANDROID_T["test-android-target<br/>Automated + Validation"]
            DESKTOP_T["test-desktop-target<br/>Automated + Validation"]
            MACOS_T["test-macos-target<br/>Exported App Test"]
            WINDOWS_T["test-windows-physical-target<br/>GUI Mode Test"]
            
            ANDROID_M["test-android-manual<br/>Stays Open"]
            DESKTOP_M["test-desktop-manual<br/>Stays Open"]
        end
        
        subgraph VALID["Validation"]
            CHECKSUM["Checksum Validation<br/>Baseline Comparison"]
            ERROR_AN["Error Analysis<br/>Automatic Parsing"]
            LOG_EXT["Log Extraction<br/>Platform-Specific"]
        end
        
        subgraph CROSS["Cross-Platform"]
            TEST_ALL["just test-all<br/>Unified Summary"]
            TEST["just test<br/>Main Config"]
        end
    end
    
    INPUT --> DETECT
    DETECT --> EXECUTE
    EXECUTE --> VALID
    CROSS --> EXECUTE
    
    style ANDROID_T fill:#90EE90
    style DESKTOP_T fill:#87CEEB
    style MACOS_T fill:#DDA0DD
    style WINDOWS_T fill:#FFB6C1
```

---

## 🔍 Debug & Log Analysis Flow

```mermaid
flowchart TB
    subgraph "Progressive Debugging (Token-Efficient)"
        direction TB
        
        subgraph STAGE1["Stage 1: Quick Scan (98% savings)"]
            ERR["just logs-errors TEST_ID<br/>Error-focused analysis"]
            SEARCH["just logs-search TEST_ID term<br/>Text search"]
        end
        
        subgraph STAGE2["Stage 2: Pattern Analysis (90-95% savings)"]
            TREE["just logs-tree TEST_ID<br/>Tag hierarchy"]
            PATTERN["just logs-pattern TEST_ID pattern<br/>Wildcard matching"]
            DISCOVER["just logs-discover TEST_ID prefix<br/>Tag discovery"]
        end
        
        subgraph STAGE3["Stage 3: Component Analysis (87-95% savings)"]
            ANDROID_L["just logs-android TEST_ID tags<br/>Android logs"]
            DESKTOP_L["just logs-desktop TEST_ID tags<br/>Desktop logs"]
            MACOS_L["just logs-macos TEST_ID tags<br/>macOS logs"]
            IOS_L["just logs-ios TEST_ID tags<br/>iOS logs"]
        end
        
        subgraph STAGE4["Stage 4: Precision (<200 tokens)"]
            TAGS["just logs-tags TEST_ID tag1 tag2<br/>Exact filtering"]
            EXCLUDE["just logs-exclude TEST_ID inc exc<br/>Include/Exclude"]
        end
        
        subgraph FULL["Full Logs (High Token Cost)"]
            DEVICE["just logs-android-device term<br/>Complete device logs"]
            ADB["adb logcat -d<br/>Direct access"]
        end
    end
    
    STAGE1 --> STAGE2
    STAGE2 --> STAGE3
    STAGE3 --> STAGE4
    STAGE4 -.-> FULL
    
    style STAGE1 fill:#90EE90
    style STAGE2 fill:#98FB98
    style STAGE3 fill:#FFFACD
    style STAGE4 fill:#FFDAB9
    style FULL fill:#FFB6C1
```

---

## 🌐 Multi-Platform Architecture

```mermaid
flowchart TB
    subgraph "Platform-Specific Workflows"
        
        subgraph ANDROID["📱 Android"]
            AND_BUILD["fastbuild-android<br/>30-60 sec"]
            AND_TEST["test-android-target"]
            AND_LOGS["logs-android TEST_ID"]
            AND_DEV["logs-android-device"]
            AND_CLEAR["logs-android-clear"]
            
            AND_BUILD --> AND_TEST --> AND_LOGS
            AND_DEV --> AND_CLEAR
        end
        
        subgraph DESKTOP["🖥️ Desktop"]
            DESK_RUN["run-desktop-debug"]
            DESK_TEST["test-desktop-target"]
            DESK_LOGS["logs-desktop TEST_ID"]
            
            DESK_RUN --> DESK_TEST --> DESK_LOGS
        end
        
        subgraph MACOS["🍎 macOS"]
            MAC_BUILD["build-macos<br/>Export .app"]
            MAC_TEST["test-macos-target"]
            MAC_LOGS["logs-macos TEST_ID"]
            
            MAC_BUILD --> MAC_TEST --> MAC_LOGS
        end
        
        subgraph IOS["📱 iOS"]
            IOS_BUILD["build-install-ios<br/>2-5 min"]
            IOS_TEST["test-ios-target"]
            IOS_LOGS["logs-ios TEST_ID"]
            
            IOS_BUILD --> IOS_TEST --> IOS_LOGS
        end
        
        subgraph WINDOWS["🪟 Windows"]
            subgraph WIN_VM["VM (192.168.50.92)<br/>MSVC Building"]
                WIN_TEMP["win-vm-template-*"]
            end
            
            subgraph WIN_PHYS["Physical (192.168.50.80)<br/>GUI Testing"]
                WIN_WAKE["win-physical-wake<br/>Wake-on-LAN"]
                WIN_DEPLOY["win-physical-deploy"]
                WIN_TEST["test-windows-physical-target"]
                WIN_LOGS["logs-windows-physical"]
                
                WIN_WAKE --> WIN_DEPLOY --> WIN_TEST --> WIN_LOGS
            end
        end
    end
    
    style ANDROID fill:#A8E6CF
    style DESKTOP fill:#88D8F0
    style MACOS fill:#DDA0DD
    style IOS fill:#FFB6C1
    style WINDOWS fill:#FFEAA7
```

---

## 🔄 CI/CD Validation Pipeline

```mermaid
flowchart LR
    subgraph "CI Validation Pipeline"
        
        subgraph DESKTOP_CI["ci-validate-desktop"]
            D1["1. format<br/>Auto-fix formatting"]
            D2["2. godot-import<br/>Reimport assets"]
            D3["3. lint<br/>Code quality"]
            D4["4. validate-godot<br/>Runtime validation"]
            D5["5. show-warnings<br/>Desktop warnings"]
            
            D1 --> D2 --> D3 --> D4 --> D5
        end
        
        subgraph ANDROID_CI["ci-validate-android"]
            A1["1. format"]
            A2["2. godot-import"]
            A3["3. lint"]
            A4["4. validate-godot"]
            A5["5. show-warnings-android"]
            
            A1 --> A2 --> A3 --> A4 --> A5
        end
        
        CI["just ci-validate<br/>🚨 MANDATORY"]
    end
    
    CI --> DESKTOP_CI
    CI --> ANDROID_CI
    
    style CI fill:#FF6B6B
```

---

## 🎮 Gamestate & Replay System

```mermaid
flowchart TB
    subgraph "Gamestate Management"
        
        subgraph CAPTURE["State Capture"]
            PLAY["Play Game<br/>Reach desired state"]
            SAVE["Save State<br/>(in-game action)"]
            CAP_DESK["capture-gamestate-desktop NAME"]
            CAP_AND["capture-gamestate-android NAME"]
            
            PLAY --> SAVE --> CAP_DESK
            PLAY --> SAVE --> CAP_AND
        end
        
        subgraph STORAGE["State Storage"]
            LIST["list-saved-states"]
            CLEAN["clean-saved-states"]
            FILES["project/debug/saved_states/*.json"]
            
            LIST --> FILES
            CLEAN --> FILES
        end
        
        subgraph TESTING["State Testing"]
            LOAD["Load State<br/>(in-game action)"]
            CYCLE_D["test-save-load-cycle-desktop"]
            CYCLE_A["test-save-load-cycle-android"]
            FULL_CYC["test-gamestate-cycle"]
            
            LOAD --> CYCLE_D
            LOAD --> CYCLE_A
            CYCLE_D --> FULL_CYC
            CYCLE_A --> FULL_CYC
        end
        
        subgraph REPLAY["Battle Replays"]
            GEN_D["replay-generate-desktop SESSION_ID NAME"]
            GEN_A["replay-generate-android SESSION_ID NAME"]
            CONFIGS["/archive/generated-replays/<br/>25+ replay configs"]
            
            GEN_D --> CONFIGS
            GEN_A --> CONFIGS
        end
    end
    
    CAPTURE --> STORAGE
    STORAGE --> TESTING
    CAPTURE --> REPLAY
```

---

## 📦 Module Dependency Graph

```mermaid
flowchart TB
    subgraph "Justfile Module Dependencies"
        MAIN["justfile<br/>Main Entry"]
        
        subgraph L1["Layer 1: Foundation"]
            CORE["justfile-core-config<br/>🔧 Loaded First"]
        end
        
        subgraph L2["Layer 2: Build"]
            BUILD_S["build-system"]
            BUILD_U["build-utils"]
            P_AND["platform-android"]
            P_IOS["platform-ios"]
            P_MAC["platform-macos"]
            P_WIN["platform-windows"]
        end
        
        subgraph L3["Layer 3: Testing"]
            TEST_C["testing-core"]
            VALID_S["validation-shared"]
            VALID["validation"]
            CFG_V["config-validation"]
            CROSS["cross-platform-testing"]
            CICD["cicd"]
        end
        
        subgraph L4["Layer 4: Debug"]
            WILD_C["wildcard-core"]
            WILD["wildcard-commands"]
            LOGS["logs"]
            ENH_L["enhanced-log-analysis"]
            LOG_F["log-filter-commands"]
            AND_L["android-device-logs"]
            DEV_L["device-logging-core"]
            LOG_X["log-cross-validation"]
        end
        
        subgraph L5["Layer 5: Gamestate"]
            GS_C["gamestate-capture"]
            GS_T["gamestate-testing"]
            REPLAY["semantic-replay-commands"]
        end
        
        subgraph L6["Layer 6: Dev Tools"]
            DEV_T["dev-tools"]
            RUN["run"]
            CODE_A["code-analysis"]
            CONFIG["config"]
            FILTER["filter-configs"]
            DEBUG["debug-commands"]
        end
        
        subgraph L7["Layer 7: Sentry"]
            SENTRY["sentry"]
            S_GD["gdscript-sentry"]
            S_AND["native-android-sentry"]
            S_IOS["native-ios-sentry"]
            S_WIN["native-windows-sentry"]
            S_TEST["sentry-test"]
        end
        
        subgraph L8["Layer 8: Support"]
            HELP["help"]
            SUPPORT["support"]
            BACKLOG["backlog"]
            TAGS["universal-log-tags"]
        end
        
        subgraph LAST["⚠️ Load Last (Overrides)"]
            V_ENH["validation-enhanced-testing<br/>Overrides test commands"]
        end
    end
    
    MAIN --> CORE
    CORE --> L2
    CORE --> L3
    CORE --> L4
    CORE --> L5
    CORE --> L6
    CORE --> L7
    CORE --> L8
    L3 --> LAST
    
    style CORE fill:#FFD700
    style LAST fill:#FF6B6B
```

---

## 🎯 Quick Decision Guide

```mermaid
flowchart TB
    subgraph "What Should I Run?"
        START{What do I need?}
        
        START -->|Build| BUILD_Q{What changed?}
        BUILD_Q -->|C++ Code| CPP_DEV["⭐ just cpp-dev<br/>(3-15 min)"]
        BUILD_Q -->|GDScript| FAST["⚡ just fastbuild-android<br/>(30-60 sec)"]
        BUILD_Q -->|First Time| BUILD["just build<br/>(46 min)"]
        BUILD_Q -->|Release| FULL_B["just build-all-android<br/>(3-25 min)"]
        
        START -->|Test| TEST_Q{What type?}
        TEST_Q -->|Automated| AUTO["just test-android-target CONFIG"]
        TEST_Q -->|Manual| MANUAL["just test-android-manual CONFIG"]
        TEST_Q -->|Cross-Platform| CROSS_T["just test-all CONFIG"]
        TEST_Q -->|Quick Iteration| QUICK_T["just config-restart-android CONFIG<br/>⚡ (5 sec)"]
        
        START -->|Debug| DEBUG_Q{Token budget?}
        DEBUG_Q -->|Minimal| ERR["just logs-errors TEST_ID<br/>(98% savings)"]
        DEBUG_Q -->|Pattern| PAT["just logs-pattern TEST_ID pattern"]
        DEBUG_Q -->|Full| DEV["just logs-android-device term"]
        
        START -->|Validate| VAL["🚨 just ci-validate<br/>MANDATORY before commit"]
    end
    
    style FAST fill:#90EE90
    style CPP_DEV fill:#FFD700
    style VAL fill:#FF6B6B
    style QUICK_T fill:#87CEEB
```

---

## 📊 Module Count Summary

| Layer | Module Count | Purpose |
|-------|--------------|---------|
| Foundation | 1 | Core configuration, paths, variables |
| Build System | 6 | Template generation, platform builds |
| Testing | 6 | Test execution, validation, CI/CD |
| Debug/Logs | 9 | Log analysis, pattern matching, device monitoring |
| Gamestate | 3 | State capture, replay, testing |
| Dev Tools | 6 | Running, config, code analysis |
| Sentry | 6 | Crash reporting integration |
| Support | 4 | Help, backlog, tags |
| **Total** | **41+** | **22,000+ lines of infrastructure** |

---

## 🚨 Critical Rules Summary

1. **`just fastbuild-android`** - MANDATORY after ANY code changes before Android testing
2. **`just ci-validate`** - MANDATORY before commits
3. **`just cpp-dev`** - Recommended one-command C++ workflow
4. Use `test-*` commands (NOT `run-*`) for debug actions
5. Start debugging with `logs-errors` (98% token savings)
6. Cross-platform testing uses `test-all` for unified summary

---

*Generated for GameTwo development. Use this diagram to understand system relationships and choose the right commands.*
