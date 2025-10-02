# `just test` Command Flowchart

```mermaid
flowchart TD
    A[just test] --> B[_test-multi-platform "main"]

    %% Multi-platform setup phase
    B --> C{Initialize Multi-Platform Session}
    C --> D[Create session timestamp<br/>MULTI_SESSION = timestamp]
    C --> E[Set environment variables<br/>MULTI_PLATFORM_MODE=true<br/>DISABLE_TEST_CLEANUP=true]
    C --> F[Clean up old test files<br/>Remove files older than 1 hour]

    %% Platform detection and setup
    F --> G{Auto-detect supported platforms}
    G --> H[Supported: desktop, android]
    G --> I[Test platforms: desktop, android<br/>Desktop first for consistency]

    %% Initialize tracking
    I --> J[Initialize tracking arrays<br/>PLATFORM_RESULTS, PLATFORM_HIERARCHIES<br/>HIERARCHY_FILES]

    %% Platform loop starts
    J --> K{Loop through platforms}
    K --> L[Platform: desktop]
    K --> M[Platform: android]

    %% Desktop testing flow
    L --> N{Desktop Setup}
    N --> O[🖥️ Running Desktop tests...]
    O --> P[test-desktop-target "main"]

    P --> Q{Desktop test execution}
    Q --> R[_test-setup-desktop<br/>Display header]
    R --> S[_test-prepare-desktop<br/>Validate configs]
    S --> T[_test-check-desktop-godot<br/>Verify Godot editor]
    T --> U[Expand test list "main"]

    U --> V[Process @ references<br/>Find all *-all test lists]
    V --> W{18 total configs}
    W --> X[Include configs like:<br/>• battle-logic-only<br/>• firebase-cpp-layer<br/>• system-layer-all<br/>• gamestate-save-load-test<br/>etc.]

    X --> Y{For each config}
    Y --> Z[Execute test actions<br/>via debug coordinator]
    Z --> AA[Capture action results<br/>Save to JSON files]
    AA --> BB[Generate hierarchy file<br/>test_hierarchy_*.json]
    BB --> CC{Continue to next config}
    CC --> Y

    %% Android testing flow
    M --> DD{Android Setup}
    DD --> EE[📱 Running Android tests...]
    EE --> FF[test-android-target "main"]

    FF --> GG{Android test execution}
    GG --> HH[_test-setup-android<br/>Display header]
    HH --> II[_test-prepare-android<br/>Clear cache, validate configs]
    II --> JJ[_test-check-android-device<br/>Verify device connection]
    JJ --> KK[Expand test list "main"<br/>Same 18 configs as desktop]

    KK --> LL{For each config}
    LL --> MM[Deploy config to device<br/>adb push config.json]
    MM --> NN[Launch test via debug coordinator<br/>Auto-quit enabled]
    NN --> OO[Execute test actions<br/>Same sequence as desktop]
    OO --> PP[Capture action results<br/>Save to JSON files]
    PP --> QQ[Generate hierarchy file<br/>test_hierarchy_*.json]
    QQ --> RR{Continue to next config}
    RR --> LL

    %% Results collection phase
    BB --> SS[Collect desktop results]
    QQ --> TT[Collect android results]
    SS --> UU[Update PLATFORM_RESULTS<br/>Store exit codes]
    TT --> VV[Update PLATFORM_RESULTS<br/>Store exit codes]
    UU --> WW{Find hierarchy files}
    VV --> WW
    WW --> XX[Locate test_hierarchy_*.json files<br/>Match by session timestamp]

    %% Generate unified summary
    XX --> YY{Generate Multi-Platform Summary}
    YY --> ZZ[Calculate totals across platforms<br/>TOTAL_PASSED, TOTAL_SKIPPED, TOTAL_FAILED]
    ZZ --> AAA[Display platform breakdown]
    AAA --> BBB[🎯 Platform Breakdown:<br/>• 🖥️ desktop: ✅ X passed, ⏭️ Y skipped, ❌ Z failed<br/>• 📱 android: ✅ X passed, ⏭️ Y skipped, ❌ Z failed]

    %% Comprehensive test map
    BBB --> CCC[📋 Comprehensive Test Map]
    CCC --> DDD{Process each unique config}
    DDD --> EEE[🔧 config-name]
    EEE --> FFF[Show status per platform:<br/>• ├── 🖥️ desktop: ✅ PASSED (N actions)<br/>• │   └── action1 (duration)<br/>• │   └── action2 (duration)<br/>• ├── 📱 android: ✅ PASSED (N actions)<br/>• │   └── action1 (duration)<br/>• │   └── action2 (duration)]
    FFF --> DDD

    %% Final results and cleanup
    DDD --> GGG[Display combined results]
    GGG --> HHH[Combined Results:<br/>✅ Passed: TOTAL_PASSED<br/>⏭️ Skipped: TOTAL_SKIPPED<br/>❌ Failed: TOTAL_FAILED]
    HHH --> III{Overall result check}
    III --> JJ{Any failures?}
    JJ -->|No| KK[✅ Multi-platform test suite<br/>completed successfully!]
    JJ -->|Yes| LL[❌ Multi-platform test suite<br/>completed with failures!]
    LL --> MMM[📊 Failure Summary:<br/>• 🔧 Failed Configs: N<br/>• 📱 Failed Platforms: N<br/>• Show failed configs list]
    MMM --> NNN[💡 Comprehensive analysis complete<br/>Use details above to prioritize fixes]
    KK --> NNN

    %% Cleanup
    NNN --> OOO[🧹 Cleanup session files]
    OOO --> PPP[Remove temporary JSON files<br/>test_action_results_*.json<br/>test_hierarchy_*.json]
    PPP --> QQQ{Exit with appropriate code}
    QQQ -->|Success| RRR[exit 0]
    QQQ -->|Failure| SSS[exit 1]

    %% Styling
    classDef platformBox fill:#e1f5fe
    classDef testBox fill:#f3e5f5
    classDef resultBox fill:#e8f5e8
    classDef errorBox fill:#ffebee
    classDef actionBox fill:#fff3e0

    class A,B,C,D,E,F,G,H,I,J platformBox
    class K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,AA,BB,CC,DD,EE,FF,GG,HH,II,JJ,KK,LL,MM,NN,OO,PP,QQ,RR testBox
    class SS,TT,UU,VV,WW,XX,YY,ZZ,AAA,BBB,CCC,DDD,EEE,FFF,GGG,HHH,III,JJJ,KKK,LLL,MMM,NNN,OOO,PPP,QQQ resultBox
    class RRR,SSS errorBox
    class N actionBox
```

## Key Components Explained

### 1. **Multi-Platform Architecture**
- The `just test` command runs the same 18 configurations on both desktop and Android
- Uses shared session tracking to correlate results across platforms
- Desktop runs first for consistency and baseline establishment

### 2. **Test List Expansion**
- The "main" test list includes 18 core configurations covering:
  - **Backend/Firebase**: async patterns, error handling, C++ layer, rate limiting
  - **Battle System**: animated and logic-only variants
  - **System Layer**: comprehensive system validation, performance testing
  - **Gamestate**: save/load cycle testing

### 3. **Execution Flow**
- Each config executes through the debug coordinator
- Actions run sequentially with timing capture
- Results saved to JSON files for analysis
- Hierarchy files track overall test structure

### 4. **Results Aggregation**
- Collects results from both platforms
- Generates comprehensive cross-platform summary
- Shows per-config status with action details
- Provides failure analysis and debugging guidance

### 5. **Error Handling**
- Continues testing even if individual configs fail
- Distinguishes between platform failures and config failures
- Provides detailed failure reporting for targeted fixes

### 6. **Cleanup**
- Removes temporary files after analysis
- Maintains clean state for next test run
- Preserves important logs in user data directory

This system provides comprehensive cross-platform validation ensuring GameTwo works identically on both desktop and Android platforms.