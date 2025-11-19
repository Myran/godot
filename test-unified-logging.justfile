# Simple unified iOS logging test command
import "justfiles/justfile-core-config.justfile"
test-unified-ios-errors:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔍 Testing unified iOS error monitoring..."
    echo "📱 Device: iPad ({{IOS_IPAD_DEVICE_ID}})"
    echo "⏱️  Duration: 3s"
    echo "💡 Press Ctrl+C to stop early"
    echo ""

    # Check device connection
    if ! idevice_id -l | grep -q "{{IOS_IPAD_DEVICE_ID}}"; then
        echo "❌ iPad not connected"
        exit 1
    fi

    # Check if gametwo is running
    if ! idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep -q "gametwo"; then
        echo "❌ gametwo not running"
        echo "💡 Launch app first"
        exit 1
    fi

    # Execute filtered logging with timeout
    echo "✅ Device health check passed"
    echo "🎯 Monitoring for errors and Firebase events..."
    timeout 3 bash -c "idevicesyslog -u {{IOS_IPAD_DEVICE_ID}} -p gametwo --no-colors | grep -E '\\[ERROR\\]|\\[INFO\\]|Firebase|backend\\.|Sentry'" || echo "✅ Monitoring completed after 3s"

test-unified-ios-firebase:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "🔍 Testing unified iOS Firebase monitoring..."
    echo "📱 Device: iPad ({{IOS_IPAD_DEVICE_ID}})"
    echo "⏱️  Duration: 5s"
    echo "💡 Press Ctrl+C to stop early"
    echo ""

    # Device health check (same as above)
    if ! idevice_id -l | grep -q "{{IOS_IPAD_DEVICE_ID}}"; then
        echo "❌ iPad not connected"
        exit 1
    fi

    if ! idevicesyslog -u "{{IOS_IPAD_DEVICE_ID}}" pidlist | grep -q "gametwo"; then
        echo "❌ gametwo not running"
        exit 1
    fi

    # Firebase-specific monitoring
    echo "✅ Device health check passed"
    echo "🔥 Monitoring Firebase operations..."
    timeout 5 bash -c "idevicesyslog -u {{IOS_IPAD_DEVICE_ID}} -p gametwo --no-colors | grep -E 'Firebase|firebase|backend\.firebase'" || echo "✅ Firebase monitoring completed"