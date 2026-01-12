# ================================================
# WILDCARD PATTERN LOG FILTERING COMMANDS  
# ================================================
# Advanced pattern matching for hierarchical tag filtering
# Provides 10x productivity improvement for log analysis

# Smart pattern-based log filtering with wildcard support
logs-pattern TEST_ID PATTERN PLATFORM="auto":
    #!/usr/bin/env bash
    set -euo pipefail

    TEST_ID="{{TEST_ID}}"
    PATTERN="{{PATTERN}}"
    PLATFORM="{{PLATFORM}}"
    EDITOR_LOG_DIR="{{EDITOR_LOG_DIR}}"

    # Auto-detect platform from TEST_ID if platform is "auto"
    if [ "$PLATFORM" = "auto" ]; then
        if [[ "$TEST_ID" == android_* ]]; then
            PLATFORM="android"
        elif [[ "$TEST_ID" == editor_* ]]; then
            PLATFORM="editor"
        elif [[ "$TEST_ID" == ios_* ]]; then
            PLATFORM="ios"
        elif [[ "$TEST_ID" == macos_* ]]; then
            PLATFORM="macos"
        else
            # Default to editor when platform cannot be auto-detected from TEST_ID
            PLATFORM="editor"
        fi
    fi

    # Saved test logs are in project's logs/ directory
    SAVED_LOGS_DIR="logs"

    # Find log file based on platform
    case "$PLATFORM" in
        android|ios|macos)
            # Search in saved test logs directory
            LOG_FILE=$(find "$SAVED_LOGS_DIR" -name "*${TEST_ID}*.log" -type f 2>/dev/null | head -1)
            if [ -z "$LOG_FILE" ]; then
                echo "❌ No log file found for test ID: $TEST_ID" >&2
                echo "🔍 Searched in: $SAVED_LOGS_DIR" >&2
                exit 1
            fi
            ;;
        editor)
            # Use existing desktop infrastructure
            LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
            ;;
        *)
            echo "❌ Invalid platform: $PLATFORM" >&2
            exit 1
            ;;
    esac

    echo "🔍 Filtering logs by pattern: $PATTERN"
    echo "🖥️  Platform: $PLATFORM ($([ "{{PLATFORM}}" = "auto" ] && echo "auto-detected" || echo "explicit"))"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Validate pattern first
    if ! just _validate-pattern "$PATTERN"; then
        echo ""
        echo "💡 Try one of these pattern examples:"
        echo "  firebase.*          (all Firebase operations)"
        echo "  *.error            (all error operations)"
        echo "  database.query     (exact match)"
        echo "  game.*.start       (middle wildcard)"
        return 1
    fi
    
    # Check cache first for performance
    CACHED_REGEX=$(just _get-cached-pattern "$PATTERN")
    if [[ -n "$CACHED_REGEX" ]]; then
        REGEX="$CACHED_REGEX"
        echo "⚡ Using cached pattern..."
    else
        REGEX=$(just _wildcard-to-regex "$PATTERN")
        just _cache-pattern "$PATTERN" "$REGEX"
        echo "🔧 Compiled pattern: $REGEX"
    fi
    
    echo ""
    echo "🏷️  Matching logs:"
    echo "=================="
    
    # Apply pattern matching
    MATCHES=$(grep -E "$REGEX" "$LOG_FILE" 2>/dev/null || true)
    
    if [[ -n "$MATCHES" ]]; then
        echo "$MATCHES" | head -50
        
        # Show count and suggest refinements
        TOTAL_MATCHES=$(echo "$MATCHES" | wc -l)
        if [[ $TOTAL_MATCHES -gt 50 ]]; then
            echo ""
            echo "📊 Found $TOTAL_MATCHES matches (showing first 50)"
            echo "💡 Tip: Use more specific patterns to narrow results"
        else
            echo ""
            echo "📊 Found $TOTAL_MATCHES matches"
        fi
    else
        echo "❌ No matches found for pattern '$PATTERN'"
        echo ""
        echo "🔍 Available patterns in this log:"
        just _suggest-patterns "$LOG_FILE" "$(echo "$PATTERN" | cut -d'.' -f1)"
    fi

# Multiple pattern matching with OR logic
logs-multi TEST_ID *PATTERNS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    PATTERNS="{{PATTERNS}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "🔍 Filtering logs by multiple patterns: $PATTERNS"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Build combined regex for all patterns
    COMBINED_REGEX=""
    for pattern in $PATTERNS; do
        if ! just _validate-pattern "$pattern" >/dev/null; then
            echo "❌ Invalid pattern: $pattern"
            return 1
        fi
        
        REGEX=$(just _wildcard-to-regex "$pattern")
        if [[ -z "$COMBINED_REGEX" ]]; then
            COMBINED_REGEX="$REGEX"
        else
            COMBINED_REGEX="$COMBINED_REGEX|$REGEX"
        fi
    done
    
    echo "🔧 Combined regex: ($COMBINED_REGEX)"
    echo ""
    echo "🏷️  Matching logs:"
    echo "=================="
    
    # Apply combined pattern matching
    MATCHES=$(grep -E "($COMBINED_REGEX)" "$LOG_FILE" 2>/dev/null || true)
    
    if [[ -n "$MATCHES" ]]; then
        echo "$MATCHES" | head -50
        
        TOTAL_MATCHES=$(echo "$MATCHES" | wc -l)
        echo ""
        echo "📊 Found $TOTAL_MATCHES matches across $(echo $PATTERNS | wc -w) patterns"
    else
        echo "❌ No matches found for any patterns"
    fi

# Pattern-based filtering with exclusions
logs-exclude TEST_ID PATTERN EXCLUDE_PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    PATTERN="{{PATTERN}}"
    EXCLUDE_PATTERN="{{EXCLUDE_PATTERN}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "🔍 Filtering logs: include '$PATTERN', exclude '$EXCLUDE_PATTERN'"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Validate both patterns
    if ! just _validate-pattern "$PATTERN" >/dev/null; then
        echo "❌ Invalid include pattern: $PATTERN"
        return 1
    fi
    
    if ! just _validate-pattern "$EXCLUDE_PATTERN" >/dev/null; then
        echo "❌ Invalid exclude pattern: $EXCLUDE_PATTERN"
        return 1
    fi
    
    # Convert patterns to regex
    INCLUDE_REGEX=$(just _wildcard-to-regex "$PATTERN")
    EXCLUDE_REGEX=$(just _wildcard-to-regex "$EXCLUDE_PATTERN")
    
    echo "🔧 Include regex: $INCLUDE_REGEX"
    echo "🔧 Exclude regex: $EXCLUDE_REGEX"
    echo ""
    echo "🏷️  Matching logs:"
    echo "=================="
    
    # Apply inclusion then exclusion
    MATCHES=$(grep -E "$INCLUDE_REGEX" "$LOG_FILE" 2>/dev/null | grep -v -E "$EXCLUDE_REGEX" 2>/dev/null || true)
    
    if [[ -n "$MATCHES" ]]; then
        echo "$MATCHES" | head -50
        
        TOTAL_MATCHES=$(echo "$MATCHES" | wc -l)
        echo ""
        echo "📊 Found $TOTAL_MATCHES matches (after exclusions)"
    else
        echo "❌ No matches found after applying exclusions"
    fi

# Discover available tags with pattern prefix
logs-discover TEST_ID PREFIX:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    PREFIX="{{PREFIX}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "🔍 Discovering tags starting with: $PREFIX"
    echo "📄 Log file: $LOG_FILE"
    echo ""
    
    # Extract all tags and filter by prefix
    ALL_TAGS=$(just _extract-tags-from-log "$LOG_FILE")
    
    echo "🏷️  Available tags:"
    echo "=================="
    
    FOUND_TAGS=$(echo "$ALL_TAGS" | grep -i "^$PREFIX" | sort)
    
    if [[ -n "$FOUND_TAGS" ]]; then
        # Show tags with frequency counts
        echo "$FOUND_TAGS" | while read tag; do
            if [[ -n "$tag" ]]; then
                COUNT=$(grep -c "$tag" "$LOG_FILE" 2>/dev/null || echo "0")
                echo "  $tag ($COUNT occurrences)"
            fi
        done
        
        echo ""
        echo "💡 Suggested wildcard patterns:"
        echo "  $PREFIX.*     (all $PREFIX operations)"
        echo "  $PREFIX.{specific1,specific2}  (group selection)"
    else
        echo "❌ No tags found starting with '$PREFIX'"
        echo ""
        echo "🔍 Available prefixes in this log:"
        echo "$ALL_TAGS" | cut -d'.' -f1 | sort | uniq | head -10
    fi

# Smart pattern suggestions with auto-completion
logs-suggest TEST_ID PARTIAL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    PARTIAL="{{PARTIAL}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "💡 Smart suggestions for: $PARTIAL"
    echo "================================="
    echo ""
    
    # Use core suggestion function
    just _suggest-patterns "$LOG_FILE" "$PARTIAL"
    
    echo ""
    echo "🎯 Pattern examples:"
    echo "  Exact match:    $PARTIAL"
    echo "  Prefix search:  $PARTIAL.*"
    echo "  Suffix search:  *.$PARTIAL"
    echo "  Contains:       *$PARTIAL*"

# Show hierarchical tag tree structure  
logs-tree TEST_ID:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "🌳 Tag hierarchy in $TEST_ID:"
    echo "============================"
    echo ""
    
    # Extract all tags and build hierarchy
    ALL_TAGS=$(just _extract-tags-from-log "$LOG_FILE")
    
    # Group by top-level domains (first part before dot)
    echo "$ALL_TAGS" | grep '\.' | while read tag; do
        if [[ -n "$tag" ]]; then
            echo "$tag"
        fi
    done | sort | awk -F'.' '
    {
        domain = $1
        if (domain != prev_domain) {
            if (prev_domain != "") print ""
            printf "├── %s\n", domain
            prev_domain = domain
        }
        printf "│   ├── %s\n", $0
    }' | head -50
    
    echo ""
    echo "💡 Use 'just logs-discover TEST_ID <domain>' to explore specific domains"

# Benchmark pattern matching performance
logs-benchmark TEST_ID PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    TEST_ID="{{TEST_ID}}"
    PATTERN="{{PATTERN}}"
    
    LOG_FILE=$(just _find-editor-log-with-test-id "$TEST_ID")
    
    echo "⚡ Performance benchmark for pattern matching"
    echo "==========================================="
    echo ""
    
    just _benchmark-pattern "$LOG_FILE" "$PATTERN"
    
    echo ""
    echo "💡 Performance tips:"
    echo "  - More specific patterns are faster"
    echo "  - Prefix patterns (firebase.*) are fastest"
    echo "  - Avoid complex middle wildcards for large files"

# Test pattern matching with sample data
logs-test-pattern PATTERN *SAMPLE_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{PATTERN}}"
    SAMPLE_TAGS="{{SAMPLE_TAGS}}"
    
    echo "🧪 Pattern Testing Utility"
    echo "========================="
    echo ""
    
    just _test-pattern "$PATTERN" $SAMPLE_TAGS
    
    echo ""
    echo "💡 Test your patterns before using on large log files"

# Show comprehensive wildcard pattern help
help-wildcards:
    #!/usr/bin/env bash
    echo "WILDCARD PATTERN SYSTEM HELP"
    echo "==============================="
    echo ""
    echo "Transform your log analysis with powerful pattern matching!"
    echo ""
    echo "BASIC WILDCARD PATTERNS"
    echo "--------------------------"
    echo ""
    echo "Pattern Type     Syntax              Example           Matches"
    echo "========================================================================"
    echo "Prefix           prefix.*            firebase.*        firebase.connect, firebase.auth"
    echo "Suffix           *.suffix            *.error           network.error, database.error"  
    echo "Middle           layer.*.operation   game.*.start      game.battle.start, game.draft.start"
    echo "Exact            exact.match         firebase.auth     firebase.auth only"
    echo "Partial          prefix*             firebase*         firebase.connect, firebase_test"
    echo ""
    echo "AVAILABLE COMMANDS"
    echo "---------------------"
    echo ""
    echo "PATTERN MATCHING:"
    echo "just logs-pattern TEST_ID PATTERN           # Single pattern matching"
    echo "just logs-multi TEST_ID PATTERN1 PATTERN2   # Multiple patterns (OR logic)"  
    echo "just logs-exclude TEST_ID PATTERN EXCLUDE  # Include/exclude filtering"
    echo ""
    echo "DISCOVERY & SUGGESTIONS:"
    echo "just logs-discover TEST_ID PREFIX           # Find all tags with prefix"
    echo "just logs-suggest TEST_ID PARTIAL           # Auto-complete suggestions"
    echo "just logs-tree TEST_ID                      # Show hierarchical tag structure"
    echo ""
    echo "TESTING & PERFORMANCE:"
    echo "just logs-benchmark TEST_ID PATTERN         # Performance benchmarking"
    echo "just logs-test-pattern PATTERN tag1 tag2    # Test pattern against sample tags"
    echo ""
    echo "PATTERN EXAMPLES"
    echo "-------------------"
    echo ""
    echo "FIREBASE DEBUGGING:"
    echo "just logs-pattern TEST_ID \"firebase.*\"                    # All Firebase operations"
    echo "just logs-pattern TEST_ID \"firebase.auth\"                 # Authentication only"
    echo "just logs-exclude TEST_ID \"firebase.*\" \"firebase.debug\"  # Firebase without debug"
    echo ""
    echo "DATABASE OPERATIONS:"  
    echo "just logs-pattern TEST_ID \"database.*\"                    # All database operations"
    echo "just logs-pattern TEST_ID \"*.query\"                       # All query operations"
    echo ""
    echo "PERFORMANCE MONITORING:"
    echo "just logs-pattern TEST_ID \"performance.*\"                 # All performance data"
    echo "just logs-pattern TEST_ID \"*.memory\"                      # Memory-related logs"
    echo ""
    echo "GAME SYSTEM DEBUGGING:"
    echo "just logs-pattern TEST_ID \"game.*\"                        # All game operations"  
    echo "just logs-pattern TEST_ID \"game.*.start\"                  # All start events"
    echo ""
    echo "NETWORK TROUBLESHOOTING:"
    echo "just logs-pattern TEST_ID \"*.error\"                       # All error operations"
    echo "just logs-multi TEST_ID \"*.timeout\" \"*.error\" \"*.retry\"   # Connection issues"
    echo ""
    echo "PRODUCTIVITY TIPS"
    echo "--------------------"
    echo ""
    echo "PERFORMANCE OPTIMIZATION:"
    echo "• Prefix patterns (firebase.*) are fastest"
    echo "• Exact matches are most efficient"
    echo "• Use specific patterns to reduce result sets"
    echo ""
    echo "DISCOVERY WORKFLOW:"
    echo "1. Start broad:     just logs-tree TEST_ID"
    echo "2. Explore domain:  just logs-discover TEST_ID firebase"  
    echo "3. Refine pattern:  just logs-pattern TEST_ID \"firebase.auth\""
    echo "4. Add exclusions:  just logs-exclude TEST_ID \"firebase.*\" \"firebase.debug\""
    echo ""
    echo "GET STARTED"
    echo "--------------"
    echo ""
    echo "1. Explore your logs:"
    echo "just logs-tree TEST_ID"
    echo ""
    echo "2. Try basic patterns:"
    echo "just logs-pattern TEST_ID \"firebase.*\""
    echo ""
    echo "3. Discover new tags:"
    echo "just logs-discover TEST_ID firebase"
    echo ""
    echo "4. Combine patterns:"
    echo "just logs-multi TEST_ID \"*.error\" \"*.timeout\""
    echo ""
    echo "Ready to 10x your debugging productivity!"

# Show quick reference for common patterns
help-wildcard-quick:
    #!/usr/bin/env bash
    echo "WILDCARD QUICK REFERENCE"
    echo "==========================="
    echo ""
    echo "COMMON PATTERNS:"
    echo "firebase.*           # All Firebase operations"  
    echo "*.error             # All errors"
    echo "game.*.start        # All start events"
    echo "database.query      # Exact match"
    echo ""
    echo "ESSENTIAL COMMANDS:"
    echo "logs-pattern TEST_ID PATTERN    # Pattern matching"
    echo "logs-discover TEST_ID PREFIX    # Find available tags"  
    echo "logs-tree TEST_ID              # Show tag hierarchy"
    echo "logs-suggest TEST_ID PARTIAL   # Auto-complete"
    echo ""
    echo "WORKFLOW:"
    echo "1. just logs-tree TEST_ID           # Explore"
    echo "2. just logs-discover TEST_ID domain # Investigate"  
    echo "3. just logs-pattern TEST_ID pattern # Filter"
    echo "4. just logs-exclude TEST_ID pattern unwanted  # Refine"
    echo ""
    echo "Performance: Prefix patterns fastest, exact matches most efficient"