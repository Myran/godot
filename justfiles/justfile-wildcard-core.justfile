# ================================================
# WILDCARD PATTERN CORE FUNCTIONS
# ================================================
# Core pattern matching utilities for wildcard log filtering
# Provides regex generation, pattern validation, and caching

# Convert wildcard pattern to grep-compatible regex
_wildcard-to-regex PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{PATTERN}}"
    
    # Handle different wildcard pattern types
    case "$PATTERN" in
        # Prefix pattern: firebase.*
        *".*")
            PREFIX=$(echo "$PATTERN" | sed 's/\.\*//')
            echo "${PREFIX}\\.[^,\\]]*"
            ;;
        # Suffix pattern: *.error
        "*."*)
            SUFFIX=$(echo "$PATTERN" | sed 's/^\*\.//')
            echo "[^\\.]]*\\.${SUFFIX}"
            ;;
        # Middle pattern: game.*.start
        *".*"*)
            PARTS=($(echo "$PATTERN" | tr '.' ' '))
            if [[ ${#PARTS[@]} -eq 3 ]] && [[ "${PARTS[1]}" == "*" ]]; then
                echo "${PARTS[0]}\\.[^\\.]]*\\.${PARTS[2]}"
            else
                # Complex middle pattern - escape dots and convert * to regex
                echo "$PATTERN" | sed 's/\./\\./g' | sed 's/\*/[^\\.]*/g'
            fi
            ;;
        # Simple prefix: firebase*
        *"*")
            PREFIX=$(echo "$PATTERN" | sed 's/\*$//')
            echo "${PREFIX}[^,\\]]*"
            ;;
        # Exact match (no wildcards)
        *)
            echo "$PATTERN"
            ;;
    esac

# Validate wildcard pattern syntax
_validate-pattern PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{PATTERN}}"
    ERRORS=""
    
    # Check for invalid characters
    if [[ "$PATTERN" =~ [^a-zA-Z0-9._*{}!|&(),] ]]; then
        ERRORS="Invalid characters in pattern. Use only letters, numbers, dots, and wildcards."
    fi
    
    # Check for empty pattern
    if [[ -z "$PATTERN" ]]; then
        ERRORS="Pattern cannot be empty."
    fi
    
    # Check for malformed wildcards
    if [[ "$PATTERN" =~ \*\* ]]; then
        ERRORS="Double wildcards (**) not supported. Use single wildcard (*)."
    fi
    
    # Check for leading/trailing dots
    if [[ "$PATTERN" =~ ^\. ]] || [[ "$PATTERN" =~ \.$ ]]; then
        ERRORS="Pattern cannot start or end with a dot."
    fi
    
    # Return validation result
    if [[ -n "$ERRORS" ]]; then
        echo "❌ Pattern validation failed: $ERRORS"
        return 1
    else
        echo "✅ Pattern '$PATTERN' is valid"
        return 0
    fi

# Extract available tags from log file for pattern matching
_extract-tags-from-log LOG_FILE:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="{{LOG_FILE}}"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        echo "❌ Log file not found: $LOG_FILE"
        return 1
    fi
    
    # Extract unique tags from various log formats
    {
        # Format 1: [Log.TAG_CONSTANT, "literal"]
        grep -o 'Log\.TAG_[A-Z_]*' "$LOG_FILE" 2>/dev/null | sed 's/Log\.TAG_[^=]*= *"//' | sed 's/"//' || true
        
        # Format 2: ["literal1", "literal2"]  
        grep -o '\["[^"]*"[^]]*\]' "$LOG_FILE" 2>/dev/null | grep -o '"[^"]*"' | sed 's/"//g' || true
        
        # Format 3: Direct tag references in logs
        grep -o '\b[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\b' "$LOG_FILE" 2>/dev/null || true
        
    } | sort | uniq | head -100

# Generate pattern suggestions based on partial input
_suggest-patterns LOG_FILE PARTIAL:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="{{LOG_FILE}}"
    PARTIAL="{{PARTIAL}}"
    
    echo "💡 Pattern suggestions for '$PARTIAL':"
    echo "=================================="
    
    # Get all tags from log file
    ALL_TAGS=$(just _extract-tags-from-log "$LOG_FILE")
    
    # Filter and rank suggestions
    echo "$ALL_TAGS" | grep -i "^$PARTIAL" | sort | head -10 | while read tag; do
        if [[ -n "$tag" ]]; then
            # Count occurrences for ranking
            COUNT=$(grep -c "$tag" "$LOG_FILE" 2>/dev/null || echo "0")
            echo "  $tag ($COUNT occurrences)"
        fi
    done
    
    # Suggest wildcard patterns
    echo ""
    echo "🔍 Wildcard suggestions:"
    echo "  ${PARTIAL}.*     (all ${PARTIAL} operations)"
    echo "  *.${PARTIAL}     (all operations ending with ${PARTIAL})"
    if [[ "$PARTIAL" =~ \. ]]; then
        PREFIX=$(echo "$PARTIAL" | cut -d'.' -f1)
        echo "  ${PREFIX}.*     (all ${PREFIX} operations)"
    fi

# Test pattern matching against sample tags
_test-pattern PATTERN *SAMPLE_TAGS:
    #!/usr/bin/env bash
    set -euo pipefail
    
    PATTERN="{{PATTERN}}"
    SAMPLE_TAGS="{{SAMPLE_TAGS}}"
    
    echo "🧪 Testing pattern '$PATTERN' against sample tags:"
    echo "================================================"
    
    # Validate pattern first
    if ! just _validate-pattern "$PATTERN"; then
        return 1
    fi
    
    # Convert to regex
    REGEX=$(just _wildcard-to-regex "$PATTERN")
    echo "📝 Generated regex: $REGEX"
    echo ""
    
    # Test against sample tags
    echo "Results:"
    for tag in $SAMPLE_TAGS; do
        if echo "$tag" | grep -q "$REGEX"; then
            echo "  ✅ $tag"
        else
            echo "  ❌ $tag"
        fi
    done

# Performance benchmark for pattern matching
_benchmark-pattern LOG_FILE PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    LOG_FILE="{{LOG_FILE}}"
    PATTERN="{{PATTERN}}"
    
    echo "⚡ Performance benchmark for pattern '$PATTERN':"
    echo "=============================================="
    
    # File size
    FILE_SIZE=$(du -h "$LOG_FILE" | cut -f1)
    echo "📁 Log file size: $FILE_SIZE"
    
    # Convert pattern to regex
    REGEX=$(just _wildcard-to-regex "$PATTERN")
    
    # Benchmark pattern matching
    echo "🏃 Running benchmark..."
    START_TIME=$(date +%s.%N)
    
    MATCH_COUNT=$(grep -c "$REGEX" "$LOG_FILE" 2>/dev/null || echo "0")
    
    END_TIME=$(date +%s.%N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    
    echo "📊 Results:"
    echo "  Matches found: $MATCH_COUNT"
    echo "  Processing time: ${DURATION}s"
    echo "  Performance: $(echo "scale=2; $MATCH_COUNT / $DURATION" | bc) matches/second"

# Cache management for compiled patterns
_cache-pattern PATTERN REGEX:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CACHE_DIR="$HOME/.cache/gametwo-logs"
    mkdir -p "$CACHE_DIR"
    
    PATTERN="{{PATTERN}}"
    REGEX="{{REGEX}}"
    
    CACHE_FILE="$CACHE_DIR/pattern_cache.txt"
    TIMESTAMP=$(date +%s)
    
    # Add to cache with timestamp
    echo "$PATTERN|$REGEX|$TIMESTAMP" >> "$CACHE_FILE"
    
    # Keep cache size manageable (last 100 entries)
    tail -100 "$CACHE_FILE" > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"

# Retrieve cached pattern regex
_get-cached-pattern PATTERN:
    #!/usr/bin/env bash
    set -euo pipefail
    
    CACHE_DIR="$HOME/.cache/gametwo-logs"
    CACHE_FILE="$CACHE_DIR/pattern_cache.txt"
    PATTERN="{{PATTERN}}"
    
    if [[ -f "$CACHE_FILE" ]]; then
        # Look for cached pattern (return most recent)
        grep "^$PATTERN|" "$CACHE_FILE" | tail -1 | cut -d'|' -f2 || echo ""
    else
        echo ""
    fi