# **Wildcard Pattern System Design**

## **🎯 Objective**
Design and implement a comprehensive wildcard pattern matching system for logger tag filtering that provides 10x productivity improvement in log analysis.

## **📋 Pattern Specification**

### **1. Basic Wildcard Patterns**

| Pattern Type | Syntax | Example | Matches |
|--------------|--------|---------|---------|
| **Prefix** | `prefix.*` | `firebase.*` | `firebase.connect`, `firebase.auth`, `firebase.timeout` |
| **Suffix** | `*.suffix` | `*.error` | `network.error`, `database.error`, `firebase.error` |
| **Partial** | `prefix*suffix` | `perf*mem` | `performance.memory`, `perf_test.memory` |
| **Middle** | `layer.*.operation` | `game.*.start` | `game.battle.start`, `game.draft.start` |
| **Exact** | `exact.match` | `firebase.auth` | `firebase.auth` only |

### **2. Advanced Pattern Matching**

| Pattern Type | Syntax | Example | Description |
|--------------|--------|---------|-------------|
| **Group Selection** | `{option1,option2}` | `firebase.{auth,connect}` | Multiple specific matches |
| **Exclusion** | `!pattern` | `!firebase.*` | Everything except pattern |
| **Boolean AND** | `pattern1 && pattern2` | `firebase.* && !firebase.debug` | Both conditions |
| **Boolean OR** | `pattern1 \|\| pattern2` | `firebase.* \|\| database.*` | Either condition |
| **Nested Groups** | `layer.{domain1.op1,domain2.*}` | `game.{battle.start,draft.*}` | Complex combinations |

### **3. Special Pattern Modifiers**

| Modifier | Syntax | Example | Effect |
|----------|--------|---------|--------|
| **Case Insensitive** | `~pattern` | `~Firebase.*` | Ignore case matching |
| **Frequency Filter** | `pattern:>N` | `firebase.*:>5` | Only tags with >N occurrences |
| **Time Window** | `pattern@timespec` | `firebase.*@last_30s` | Time-bounded matching |
| **Context Lines** | `pattern+N` | `firebase.error+5` | Include N context lines |

## **🛠️ Implementation Architecture**

### **Pattern Processing Pipeline**
```
User Input → Pattern Parser → Regex Generator → Cache Manager → Log Matcher → Results Formatter
```

### **Core Components**

#### **1. Pattern Parser**
```bash
# Input: "firebase.* && !firebase.debug"
# Output: {
#   type: "boolean_and",
#   left: {type: "prefix", value: "firebase"},
#   right: {type: "exclusion", value: "firebase.debug"}
# }
```

#### **2. Regex Generator**
```bash
# Converts parsed patterns to optimized regex
firebase.*     → "firebase\\.([^,\\]]*)"
*.error        → "([^\\.])*\\.error"
game.*.start   → "game\\.([^\\.])*\\.start"
```

#### **3. Cache Manager**
```bash
# Cache compiled regex patterns for performance
PATTERN_CACHE[pattern] = compiled_regex
FREQUENCY_CACHE[pattern] = {hits: N, last_used: timestamp}
```

## **📊 Pattern Examples & Test Cases**

### **Basic Patterns**
```bash
# Test Case 1: Prefix matching
Pattern: "firebase.*"
Should Match: ["firebase.connect", "firebase.auth", "firebase.timeout"]
Should Not Match: ["database.firebase", "firebase_test", "firebaseconnect"]

# Test Case 2: Suffix matching  
Pattern: "*.error"
Should Match: ["network.error", "database.error", "firebase.error"]
Should Not Match: ["error.network", "errorlog", "error_handling"]

# Test Case 3: Middle wildcards
Pattern: "game.*.start"
Should Match: ["game.battle.start", "game.draft.start", "game.menu.start"]
Should Not Match: ["game.start", "game.battle.start.action", "start.game.battle"]
```

### **Advanced Patterns**
```bash
# Test Case 4: Group selection
Pattern: "firebase.{auth,connect,timeout}"
Should Match: ["firebase.auth", "firebase.connect", "firebase.timeout"]
Should Not Match: ["firebase.retry", "firebase.error"]

# Test Case 5: Boolean combinations
Pattern: "firebase.* && !firebase.debug"
Should Match: ["firebase.auth", "firebase.connect"]
Should Not Match: ["firebase.debug", "database.error"]

# Test Case 6: Complex nested patterns
Pattern: "game.{battle.start,draft.*,*.error}"
Should Match: ["game.battle.start", "game.draft.reroll", "game.menu.error"]
Should Not Match: ["game.battle.end", "system.error"]
```

## **🚀 Performance Optimization**

### **Regex Optimization Strategies**
1. **Pattern Compilation Caching**: Store compiled regex patterns
2. **Early Termination**: Stop processing when pattern clearly won't match
3. **Pattern Ordering**: Process most restrictive patterns first
4. **Streaming Processing**: Process large log files in chunks

### **Memory Management**
```bash
# Cache size limits
MAX_PATTERN_CACHE_SIZE=100
MAX_FREQUENCY_CACHE_SIZE=1000
CACHE_TTL=3600  # 1 hour

# Memory-efficient log processing
CHUNK_SIZE=1MB  # Process logs in 1MB chunks
MAX_CONTEXT_LINES=50  # Limit context to prevent memory explosion
```

## **🔧 Implementation Files**

### **File Structure**
```
justfiles/
├── justfile-wildcard-commands.justfile     # New wildcard commands
├── justfile-wildcard-core.justfile         # Core pattern matching functions
└── justfile-log-filter-commands.justfile   # Enhanced existing commands

patterns/
├── pattern_parser.sh                       # Pattern parsing logic
├── regex_generator.sh                      # Regex generation utilities
└── pattern_cache.sh                        # Caching mechanisms
```

### **Command Interface**
```bash
# Primary wildcard commands
logs-pattern TEST_ID PATTERN               # Single pattern matching
logs-multi TEST_ID PATTERN1 PATTERN2       # Multiple patterns (OR logic)
logs-exclude TEST_ID PATTERN --exclude=EXCLUDE  # Exclusion support
logs-boolean TEST_ID "PATTERN1 && PATTERN2"     # Boolean expressions

# Discovery and suggestion commands  
logs-discover TEST_ID PREFIX               # Find tags starting with prefix
logs-suggest TEST_ID PARTIAL               # Auto-complete suggestions
logs-tree TEST_ID                          # Hierarchical tag view
logs-frequency TEST_ID PATTERN             # Show tag frequency analysis
```

## **✅ Success Criteria**

### **Functional Requirements**
- [ ] All basic wildcard patterns work correctly (prefix, suffix, middle)
- [ ] Advanced patterns support (groups, exclusions, boolean logic)
- [ ] Pattern validation with helpful error messages
- [ ] Backward compatibility with existing log commands

### **Performance Requirements**
- [ ] Pattern matching <2 seconds for 10MB log files
- [ ] Pattern compilation cache hit rate >90%
- [ ] Memory usage <100MB for largest expected log files
- [ ] Regex compilation time <100ms for complex patterns

### **User Experience Requirements**  
- [ ] Intuitive pattern syntax (minimal learning curve)
- [ ] Auto-completion and suggestions work reliably
- [ ] Error messages provide helpful correction suggestions
- [ ] Pattern examples available in help documentation

## **🎯 Implementation Phases**

### **Phase 1: Basic Wildcards (3 days)**
- Implement prefix, suffix, and exact matching
- Add pattern validation and error handling
- Create comprehensive test suite

### **Phase 2: Advanced Patterns (4 days)**
- Add group selection and boolean logic
- Implement exclusion patterns
- Add performance optimizations

### **Phase 3: Discovery & Suggestions (3 days)**
- Create tag discovery commands
- Add auto-completion system
- Implement hierarchical tree view

## **🧪 Validation Strategy**

### **Test Methodology**
1. **Unit Tests**: Each pattern type with comprehensive test cases
2. **Integration Tests**: End-to-end workflow validation
3. **Performance Tests**: Large file processing benchmarks
4. **User Acceptance Tests**: Real debugging scenario validation

### **Test Data Requirements**
- Sample log files with diverse tag patterns (1KB - 100MB)
- Edge cases: empty logs, malformed tags, special characters
- Performance data: realistic production log volumes

This design provides a solid foundation for implementing a world-class wildcard pattern system that will transform log analysis productivity.