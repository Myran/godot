# Log Tag Reference for Universal Filtering

## Common Tag Categories

### **System & Core**
- `debug` - Debug system operations
- `system` - System initialization and core operations  
- `startup` - App startup and initialization
- `ui` - User interface events
- `initialization` - Component initialization

### **Testing & Lifecycle**
- `test` - Test execution events
- `success` - Successful operations
- `failure` - Failed operations  
- `complete` - Completion events
- `pid` - Process ID tracking
- `sequence` - Sequence/order tracking

### **Game Components**
- `battle` - Battle system operations
- `determinism` - Determinism testing
- `gameplay` - General gameplay events
- `game` - Game-specific operations

### **Firebase & Backend**
- `firebase` - Firebase operations
- `backend` - Backend Firebase operations
- `rtdb` - Real-time database operations
- `cpp_firebase` - C++ Firebase SDK operations
- `backend_firebase` - Backend Firebase wrapper operations

### **Data & Performance**
- `filesystem` - File system operations
- `phase` - Phase tracking (recording/validation)
- `registration` - Component registration
- `init` - Initialization events

## Example Usage Patterns

### **Focus on Specific Components**
```bash
just logs TEST_ID firebase              # All Firebase operations
just logs TEST_ID battle determinism    # Battle determinism only
just logs TEST_ID debug test           # Debug test events only
just logs TEST_ID system startup       # System startup only
```

### **Error Debugging**
```bash
just logs-errors-tagged TEST_ID                # All errors
just logs-errors-tagged TEST_ID firebase       # Firebase errors only
just logs-errors-tagged TEST_ID battle         # Battle errors only
```

### **Performance Analysis**
```bash
just logs-performance-tagged TEST_ID            # All performance data
just logs-performance-tagged TEST_ID battle     # Battle performance only
just logs-performance-tagged TEST_ID firebase   # Firebase performance only
```

### **Lifecycle Tracking**  
```bash
just logs-lifecycle-tagged TEST_ID              # All lifecycle events
just logs-lifecycle-tagged TEST_ID startup      # Startup events only
just logs-lifecycle-tagged TEST_ID test         # Test lifecycle only
```

## Token Savings Examples

- **Full logs**: 400+ lines = ~800 tokens
- **`logs TEST_ID battle`**: ~50 lines = ~100 tokens (87% reduction)
- **`logs TEST_ID debug test`**: ~30 lines = ~60 tokens (92% reduction)
- **`logs-errors-tagged TEST_ID firebase`**: 0-5 lines = ~10 tokens (98% reduction)

## Pro Tips

1. **Combine tags** for precise filtering: `debug battle`, `firebase rtdb`, `system startup`
2. **Start specific** then broaden: Try `battle` first, then `debug battle` if you need more context
3. **Use error commands first** for quick issue detection: `logs-errors-tagged TEST_ID`
4. **Performance debugging**: Use `logs-performance-tagged TEST_ID battle` for specific component timing