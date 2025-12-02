---
id: task-285
title: Implement comprehensive iOS testing methodology and infrastructure
status: Done
assignee: []
created_date: '2025-11-16 21:47'
updated_date: '2025-12-02 20:15'
labels: []
dependencies: []
---

## Description

Implement comprehensive iOS testing methodology and infrastructure to enable automated testing on real iOS devices, mirroring the robust Android testing capabilities already established.

**Key Insights from Android Validation:**
- Android testing achieved 100% automation with `just test-android-target CONFIG`
- Real crash scenarios successfully generated and captured by Sentry within 2 minutes
- Comprehensive device metadata, stack traces, and contextual data preserved
- Test isolation achieved through session-based filtering and unique TEST_ID generation
- DebugAction framework provides consistent cross-platform execution

**Current iOS State Analysis:**
- iOS executable already built (`export/ios/gametwo.xcframework/ios-arm64/libgodot.a`)
- No equivalent to Android's `test-android-target` automated workflow
- Missing iOS device deployment, log capture, and test result analysis infrastructure
- Need iOS-specific app lifecycle management and debugging integration

**Shared Methodology Requirements:**
- Leverage existing DebugAction framework (already platform-agnostic)
- Reuse test configuration system (`tests/debug_configs/*.json`)
- Maintain session-based isolation and TEST_ID consistency
- Share SentryRealCrashTestAction across platforms (already implemented)
- Utilize common log analysis and error detection patterns

## Technical Requirements

### 1. iOS Device Management
- Real iOS device connection and detection (prefer real devices over simulators)
- App deployment and installation automation
- Device status verification and health monitoring
- Multi-device support (future-proofing)

### 2. Automated Testing Framework
- `just test-ios-target CONFIG` command adapted for iOS constraints
- **File overwriting capability discovered** - Can modify files in iOS app bundle after build
- **iOS app bundle path**: `export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/`
- **Method**: Create placeholder files in Xcode project, overwrite after build like PCK files
- Real-time log capture with session-based filtering
- Test result extraction and analysis pipeline

### 3. Log Collection and Analysis
- iOS device log access (device console, app logs)
- Cross-platform compatible log parsing and filtering
- Integration with existing `just logs-*` commands for iOS
- Buffer management and test isolation strategies

### 4. Debug Integration
- Debug menu access and control on iOS
- Save/load gamestate system compatibility
- Action execution and result collection
- Error handling and crash detection

### 5. Build and Deployment Integration
- Integration with existing `just build-ios-*` commands
- Fastbuild optimization for iOS development cycles
- Automated app signing and provisioning profile handling
- Development vs release build testing

## Implementation Phases

### Phase 1: Foundation (Priority: High)
- Research iOS device automation tools (ios-deploy, libimobiledevice, Xcode tools)
- Implement basic device connection and app deployment
- Create `just test-ios-target` basic structure
- Validate with simple test configuration

### Phase 2: Log Collection (Priority: High)
- Implement iOS device log capture and filtering
- Integrate with existing log analysis pipeline
- Add iOS-specific commands to `just logs-*` family
- Test log isolation and session management

### Phase 3: Advanced Testing (Priority: Medium)
- Implement automated test execution and result collection
- Add support for complex test configurations
- Integrate with debug action system
- Add performance monitoring and validation

### Phase 4: Optimization (Priority: Low)
- Multi-device parallel testing support
- Advanced error analysis and cross-platform comparison
- Integration with CI/CD pipeline
- Documentation and workflow optimization

## Success Criteria

- [ ] `just test-ios-target CONFIG` executes automated tests on real iOS device
- [ ] Test results collected and analyzed with same quality as Android
- [ ] Log capture and filtering works with session-based isolation
- [ ] DebugAction execution works consistently across platforms
- [ ] Real crash scenarios can be generated and captured (enables Task-286)
- [ ] Performance comparable to Android testing (within 2-3x factor)
- [ ] Documentation complete with workflow examples

## Technical Considerations

### Shared Codepaths
- **DebugAction Framework**: Already platform-agnostic, reuse directly
- **Test Configurations**: Same JSON structure works for iOS
- **Sentry Integration**: Shared crash scenarios and validation logic
- **Log Analysis**: Adapt existing patterns for iOS log format

### iOS-Specific Challenges
- **File overwriting discovered** - Can modify app bundle after build like PCK files
- Device connection requires different tools than ADB (ios-deploy, Xcode tools)
- App lifecycle management differs from Android (backgrounding, suspension)
- Log access permissions and console tools vary (device console vs logcat)
- Code signing and provisioning profile complexity
- **Method**: Create placeholder files in Xcode project, overwrite in app bundle post-build

### Risk Mitigation
- Start with manual device deployment, automate incrementally
- Fallback to simulator for development if device access limited
- Leverage existing Godot iOS export capabilities
- Cross-platform compatibility testing throughout development

### iOS File Overwriting Method (Preferred Approach)

**Discovery**: iOS app bundle files can be overwritten after build, just like PCK files!

#### Implementation Strategy
1. **Create placeholder file** in Xcode project (e.g., `debug_startup_actions.json`)
2. **Build iOS app** normally with Xcode
3. **Overwrite placeholder** in app bundle: `export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/`
4. **Deploy modified app** to device with test configuration

#### Recipe Pattern (based on existing `save-ios-to-app`)
```bash
# Save test config to iOS app bundle
save-test-config-ios config_name:
    @echo "📝 Deploying test config to iOS app bundle..."
    cp tests/debug_configs/{{config_name}}.json \
       export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/debug_startup_actions.json
```

#### Benefits
- **Maintains Android workflow similarity** - file-based config deployment
- **No embedded configs needed** - dynamic test selection
- **Leverages existing PCK overwriting infrastructure**
- **Same test configurations work across platforms**

#### Required Xcode Project Setup
- Add `debug_startup_actions.json` as placeholder file to iOS app bundle
- Ensure file is included in build but can be overwritten post-build
- No impact on app store distribution (development builds only)

## Dependencies

- **Task-286**: iOS Sentry crash validation (depends on this infrastructure)
- **Existing Android Testing**: Reference implementation and patterns
- **Godot iOS Export**: Base build system and deployment
- **Real iOS Device**: Required for proper validation (not simulator)

## Related Work

- **Android Testing Infrastructure**: `just test-android-target` implementation (reference)
- **SentryRealCrashTestAction**: Already implemented and platform-agnostic
- **DebugAction Framework**: Cross-platform test execution system
- **Gamestate System**: Save/load testing across platforms
