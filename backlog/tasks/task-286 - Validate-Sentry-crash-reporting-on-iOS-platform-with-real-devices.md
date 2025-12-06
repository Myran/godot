---
id: task-286
title: Validate Sentry crash reporting on iOS platform with real devices
status: To Do
assignee: []
created_date: '2025-11-16 21:47'
updated_date: '2025-11-16 21:51'
labels: []
dependencies: []
---

## Assessment (2025-12-06)

**Value: MEDIUM-HIGH** - iOS crash reporting validation.

**Recommendation: KEEP** - iOS is a key platform. Sentry validation ensures crash visibility. Android already done, this is the iOS counterpart. Depends on iOS test infrastructure being functional.

**Effort**: Medium (real device testing)
**Related**: Part of task-283 scope (cross-platform Sentry validation)

---

## Description

Validate comprehensive Sentry crash reporting on iOS platform using real devices, ensuring complete parity with Android crash reporting capabilities. This task leverages the iOS testing infrastructure from Task-285 and the shared crash scenarios already developed and validated on Android.

**Android Validation Results (Reference):**
- ✅ 3 real crashes successfully captured: GODOT-16, GODOT-17, GODOT-18
- ✅ Comprehensive device metadata captured (device model, iOS version, memory, storage)
- ✅ Complete stack traces with function names and line numbers
- ✅ Crash reporting within 2 minutes of incident
- ✅ SentryRealCrashTestAction validated with 4 crash scenarios
- ✅ 100% success criteria achieved for Android platform

**Shared Crash Scenarios (Already Implemented):**
- **Null Dereference Crash**: `obj.some_method_that_does_not_exist()` with obj = null
- **Bounds Access Crash**: Array index out of bounds access (`arr[999]`)
- **Type Violation Crash**: Invalid type casting and assignment
- **Resource Corruption Crash**: Invalid node tree access after deletion

**iOS-Specific Validation Requirements:**
- Native iOS crash capture (Objective-C/Swift stack frames)
- Godot iOS engine integration with Sentry SDK
- iOS system-level crash reporting integration
- Real device crash context (not simulator limitations)
- Cross-platform stack trace consistency validation

## Technical Requirements

### 1. iOS Crash Scenario Execution
- Execute SentryRealCrashTestAction on real iOS device
- Validate all 4 crash scenarios trigger properly on iOS
- Ensure iOS app termination and crash capture
- Test crash scenario isolation and repeatability

### 2. Sentry iOS Integration Validation
- Verify Sentry SDK properly initialized on iOS
- Validate native crash capture (not just GDScript level)
- Confirm iOS-specific metadata collection (device model, iOS version)
- Test crash report transmission and Sentry dashboard appearance

### 3. Cross-Platform Consistency
- Compare iOS crash reports with Android reference data
- Validate stack trace quality and completeness
- Ensure device metadata captures iOS-specific information
- Test crash timing and report delivery consistency

### 4. Real Device Testing
- Use actual iOS hardware (preferred: iPhone/iPad physical device)
- Avoid simulator limitations for crash testing
- Test on multiple iOS versions if possible (iOS 16.x, 17.x)
- Validate crash behavior under different device conditions

### 5. Integration with Testing Infrastructure
- Use Task-285's `just test-ios-target` for automated execution
- Leverage existing SentryRealCrashTestAction (no modifications needed)
- Integrate with Sentry MCP tools for validation
- Maintain session-based test isolation and logging

## Validation Methodology

### Phase 1: Infrastructure Preparation
1. **Complete Task-285**: Ensure iOS testing infrastructure operational
2. **Device Setup**: Connect real iOS device, verify deployment capability
3. **Sentry Configuration**: Verify iOS Sentry SDK integration and DSN configuration
4. **Baseline Testing**: Validate basic app functionality on target device

### Phase 2: Crash Scenario Testing
1. **Deploy Crash Test Config**: Use iOS app bundle file overwriting (like PCK files)
2. **Execute Crash Scenarios**: Run `sentry-real-crash-test.json` via overwritten config file
3. **Monitor Sentry Dashboard**: Use Sentry MCP tools for real-time validation
4. **Collect iOS Device Logs**: Capture crash reports and system logs

**iOS File Overwriting Method**: Deploy configs to `export/ios/build/products/Debug-iphoneos/{{GAME_NAME}}.app/debug_startup_actions.json` using existing PCK overwriting infrastructure.

### Phase 3: Cross-Platform Analysis
1. **Compare with Android Reference**: Match iOS crashes against Android benchmarks
2. **Stack Trace Analysis**: Validate iOS native frames and Godot integration
3. **Metadata Quality Assessment**: Verify iOS-specific device information
4. **Performance Validation**: Ensure crash reporting timing consistency

### Phase 4: Edge Case Testing
1. **Network Conditions**: Test crash reporting with poor connectivity
2. **App State Variations**: Crashes during different app lifecycle phases
3. **Memory Pressure**: Test under low memory conditions if possible
4. **Multiple Crashes**: Validate handling of rapid successive crashes

## Success Criteria

### Primary Success Metrics
- [ ] All 4 crash scenarios successfully trigger on iOS device
- [ ] Crashes captured and reported to Sentry within 2 minutes
- [ ] Complete stack traces with iOS native frames preserved
- [ ] iOS-specific device metadata collected (model, iOS version, hardware)
- [ ] Cross-platform consistency with Android validation results

### Quality Assurance
- [ ] Stack traces include both GDScript and native iOS frames
- [ ] Device context includes iOS-specific information (battery, storage, memory)
- [ ] No simulator usage - all testing on real iOS hardware
- [ ] Sentry MCP tools successfully validate iOS crash reports
- [ ] Crash scenarios are repeatable and consistent

### Integration Validation
- [ ] `just test-ios-target sentry-real-crash-test` executes successfully via app bundle file overwriting
- [ ] Session-based isolation works correctly on iOS
- [ ] Log capture and analysis provides actionable debugging information
- [ ] No impact on app stability during normal operation

## Technical Considerations

### Shared Codepaths (Leverage from Android)
- **SentryRealCrashTestAction**: Platform-agnostic crash scenarios
- **Test Configuration**: Same `sentry-real-crash-test.json` works for iOS
- **Sentry MCP Tools**: Cross-platform validation and analysis
- **DebugAction Framework**: Consistent execution and logging

### iOS-Specific Implementation Details
- **Native Crash Capture**: iOS signal handling and crash reporter integration
- **Stack Trace Unwinding**: iOS native frame preservation through Godot
- **Device Metadata**: iOS system APIs for hardware and software information
- **App Lifecycle**: iOS-specific crash timing and termination handling

### Risk Mitigation Strategies
- **Device Availability**: Ensure access to real iOS hardware for testing
- **Crash Isolation**: Prevent device instability during testing
- **Data Privacy**: Ensure no sensitive user data in crash reports
- **Fallback Plans**: Alternative validation approaches if iOS crashes differ

## Dependencies

- **Task-285**: iOS testing methodology and infrastructure (blocking dependency)
- **SentryRealCrashTestAction**: Already implemented and platform-agnostic
- **Real iOS Device**: Physical hardware required for accurate validation
- **Sentry MCP Tools**: For crash report validation and analysis
- **Android Reference Data**: GODOT-16, GODOT-17, GODOT-18 for comparison

## Expected Outcomes

### Immediate Deliverables
- Complete iOS crash reporting validation with Sentry dashboard confirmation
- Cross-platform consistency analysis comparing iOS vs Android crash reporting
- Documentation of iOS-specific crash behavior and metadata quality
- Validation report with success criteria assessment

### Long-term Benefits
- Confident Sentry crash reporting across all major mobile platforms
- Foundation for Windows and macOS validation using same methodology
- Enhanced debugging capabilities with iOS-native crash context
- Production-ready crash monitoring and alerting system

## Validation Checklist

### Pre-Testing Requirements
- [ ] Task-285 completed and iOS testing infrastructure operational
- [ ] Real iOS device connected and app deployment verified
- [ ] Sentry iOS SDK integration confirmed (DSN, initialization)
- [ ] Baseline app functionality tested on target device

### Crash Scenario Execution
- [ ] Null dereference crash executed and captured
- [ ] Bounds access crash executed and captured
- [ ] Type violation crash executed and captured
- [ ] Resource corruption crash executed and captured

### Sentry Dashboard Validation
- [ ] All 4 crashes appear in Sentry dashboard within 2 minutes
- [ ] Complete stack traces with iOS native frames
- [ ] iOS-specific device metadata present
- [ ] Cross-platform consistency with Android reference data

### Post-Testing Analysis
- [ ] Stack trace quality analysis completed
- [ ] Device metadata comprehensiveness validated
- [ ] Performance timing consistency confirmed
- [ ] Edge case behavior documented and understood
