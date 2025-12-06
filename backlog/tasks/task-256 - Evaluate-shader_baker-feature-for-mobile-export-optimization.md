---
id: task-256
title: Evaluate shader_baker feature for mobile export optimization
status: To Do
assignee: []
created_date: '2025-10-31 18:21'
updated_date: '2025-11-11 20:25'
labels:
  - performance
  - godot-4.5
  - mobile
  - research
dependencies: []
priority: low
---

## Assessment (2025-12-06)

**Value: LOW** - Research task for future optimization.

**Recommendation: KEEP but DEFER** - Good to track, but shader_baker has known issues in Godot 4.5. Re-evaluate when Godot patches address mobile export issues. Not actionable until upstream fixes land.

**Effort**: Small (research/testing only)
**Trigger**: Wait for Godot 4.5.x patches that fix Android headless export issues

---

## Description

Evaluate and test Godot 4.5's new **shader_baker** feature for potential startup performance improvements on mobile platforms (iOS/Android).

### What is shader_baker?

The shader_baker is a Godot 4.5 feature that pre-compiles shaders during export instead of at runtime, potentially reducing startup times by 20-30× on certain platforms.

### Current Status

Currently **DISABLED** (`shader_baker/enabled=false`) in all export presets due to:
- **Android headless export issues** - Shader sub-resources not properly included in APK
- **iOS Metal support incomplete** - Still in progress for Godot 4.5
- **Known bugs** - `OS.has_feature("shader_baker")` always returns false
- **New feature** - Limited production testing on mobile

### When to Re-evaluate

Consider testing when:
1. **Godot 4.5.x patches** address Android headless export issues
2. **Metal support complete** for iOS exports
3. **Community reports** show stable mobile usage
4. **Startup performance issues** identified in production

### Platform Performance Expectations

| Platform | Expected Benefit | Status |
|----------|------------------|--------|
| Android (Vulkan) | Moderate | ⚠️ Known issues |
| iOS (Metal) | High (20× reported) | 🚧 In progress |
| Desktop (D3D12) | Very High (30×) | ✅ Stable |

## Acceptance Criteria

- [ ] Monitor Godot release notes for shader_baker mobile fixes
- [ ] Test shader_baker on Android with current game build
  - Measure startup time with/without feature
  - Verify all shaders render correctly
  - Check APK size increase
- [ ] Test shader_baker on iOS (once Metal support complete)
  - Measure startup time improvements
  - Verify shader compilation success
  - Test on multiple iOS devices
- [ ] Compare export times with/without shader_baker enabled
- [ ] Document findings and recommendation for production use
- [ ] Update export presets if beneficial for mobile

## Testing Procedure

```bash
# 1. Enable shader_baker in export presets
# Edit project/export_presets.cfg:
#   shader_baker/enabled=true

# 2. Clear shader cache for accurate testing
rm -rf ~/Library/Application\ Support/Godot/app_userdata/gametwo/shader_cache

# 3. Export and measure startup time
just build-all-android
adb logcat | grep -E "startup|shader|compile"

# 4. Compare with disabled setting
# (Repeat with shader_baker/enabled=false)

# 5. Document results in this task
```

## Related Information

- **PR**: https://github.com/godotengine/godot/pull/102552
- **Release Notes**: https://godotengine.org/releases/4.5/
- **Android Issue**: Headless mode doesn't include shaders in APK
- **Commit**: 390d7c46 - Disabled shader_baker initially
- **Godot Version**: 4.5.1+ (feature introduced in 4.5)

## Notes

- Feature primarily benefits D3D12/Metal backends (desktop/iOS)
- Mobile Vulkan shows moderate improvements
- Trade-off: Longer export times, larger build sizes
- For production, may want separate export presets (desktop=enabled, mobile=disabled)
