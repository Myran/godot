---
id: task-297
title: Implement comprehensive cross-platform authentication system
status: To Do
assignee: []
created_date: '2025-11-19 22:30'
updated_date: '2025-11-19 22:45'
labels:
  - authentication
  - firebase
  - cross-platform
  - security
  - high-priority
  - user-management
dependencies:
  - task-107.06
priority: high
---

## Description

Implement a comprehensive cross-platform authentication system using Firebase Authentication that provides secure user login, registration, and session management across Android, iOS, Windows, and macOS platforms. This system leverages existing Firebase C++ module infrastructure and domain services architecture to minimize development effort while maximizing strategic value.

**Architecture Optimization**: Based on codebase analysis, this task will extend existing structures rather than rebuilding:
- Extend `godot/modules/firebase/auth.h` C++ module with Steam/web handshake capabilities
- Follow established `DatabaseService` pattern for new `AuthService`
- Integrate with existing `FirebaseServiceBackend` domain architecture
- Leverage current Firebase backend patterns and testing infrastructure

**Implementation Efficiency**: 50% reduction in development effort by reusing:
- Existing FirebaseAuth C++ module (auth.h/auth.mm)
- DatabaseService signal-based architecture patterns
- FirebaseServiceBackend service composition pattern
- Established Firebase testing methodologies

Master Architecture: Godot Hybrid Authentication System
Version: 2.0 (Final Approved)
Scope: Cross-Platform Authentication (Steam + Firebase) for Desktop & Mobile.
1. Visual Architecture Overview
This diagram illustrates the split logic between Desktop and Mobile to ensure maximum compatibility and native User Experience.
code
Mermaid
graph TD
    %% Subgraphs for Context
    subgraph Client_Godot ["Godot Client (C++ Module)"]
        AuthMgr[AuthManager State Machine]
        SteamSDK[Steamworks SDK]
        NativeOverlay[Native Mobile Overlay]
        AnonAuth[Anonymous Auth]
    end

    subgraph Backend_Firebase ["Firebase Backend (Serverless)"]
        Fn_Steam[Cloud Fn: steamLogin]
        Fn_Handshake[Cloud Fn: finalizeHandshake]
        Fn_Link[Cloud Fn: redeemTransferCode]
        RTDB[(Realtime Database)]
        Firestore[(Cloud Firestore)]
        FB_Auth[Firebase Auth]
        Hosting[Firebase Hosting]
    end

    subgraph External_Services
        Valve[Valve / Steam API]
        Socials[Google / Apple / Facebook]
        UserBrowser[System Web Browser]
    end

    %% --- FLOW 1: DESKTOP STEAM (Silent) ---
    AuthMgr -- "1. Get Ticket" --> SteamSDK
    SteamSDK -- "2. Ticket Hex" --> AuthMgr
    AuthMgr -- "3. Call Function" --> Fn_Steam
    Fn_Steam -- "4. Verify" --> Valve
    Fn_Steam -- "5. Mint Token" --> AuthMgr
    AuthMgr -- "6. Sign In" --> FB_Auth

    %% --- FLOW 2: DESKTOP SOCIAL (Handshake) ---
    AuthMgr -- "1. Sign In Anon" --> FB_Auth
    AuthMgr -- "2. Listen (SessionID)" --> RTDB
    AuthMgr -- "3. Open Browser" --> UserBrowser
    UserBrowser -- "4. Auth UI" --> Hosting
    Hosting -- "5. OAuth" --> Socials
    Hosting -- "6. ID Token" --> Fn_Handshake
    Fn_Handshake -- "7. Mint Custom Token" --> RTDB
    RTDB -- "8. Push Token" --> AuthMgr
    AuthMgr -- "9. Upgrade Account" --> FB_Auth

    %% --- FLOW 3: MOBILE NATIVE ---
    AuthMgr -- "1. SignInWithProvider" --> NativeOverlay
    NativeOverlay -- "2. OAuth Flow" --> Socials
    NativeOverlay -- "3. Return Credential" --> FB_Auth

    %% --- FLOW 4: CROSS-LINKING ---
    AuthMgr -- "Generate Code" --> Fn_Link
    Fn_Link -- "Store Code" --> Firestore
    AuthMgr -- "Redeem Code" --> Fn_Link
    Fn_Link -- "Transactional Swap" --> FB_Auth
2. Architectural Strategy
The system employs a "Best-in-Class per Platform" strategy to avoid the limitations of a single approach.
A. Desktop (Windows/Linux/Mac)
Challenge: No native OAuth system windows (like on iOS).
Solution 1 (Steam): Use Steamworks C++ SDK to get a ticket silently. Pass to Cloud Functions. Result: One-click login.
Solution 2 (Socials): Use a "Web Handshake". The game opens a system browser (Chrome/Edge). The user logs in there. The game "listens" to a secure channel (Realtime Database) for the resulting token.
Security: The Handshake requires the client to sign in Anonymously first. The handshake channel is secured so only the specific anonymous user can read the result.
B. Mobile (Android/iOS)
Challenge: Opening external browsers breaks immersion; Embeddedr clicks Google, selects account. Web page says "Success! You can close this."
Game: Detects the login instantly via RTDB listener. Spinner stops. Profile loads.
Journey 3: The Cross-Play Link (Mobile to PC)
Context: User has a Level 50 Mobile account. Wants to play on Steam.
Mobile: Settings -> "Link to Desktop". App generates code: X9-P4.
Steam: Settings -> "I have a Link Code". User types X9-P4.
System:
Cloud Function verifies code.
Finds the Level 50 Mobile User ID.
Links the current Steam ID to that Mobile User.
Logs the Steam Client in as the Level 50 User.
Result: Steam client reloads data. Progress is synced.
4. Edge Cases & Handling Protocol
Edge Case	Potential Failure	Implementation Solution
Steam API Down	Cloud Function returns 500/Timeout. Login hangs.	Retry & Fallback: Client tries 3 times with backoff. If fail, show "Steam Auth Unavailable. Play Offline or try Web Login?".
Browser Abandoned	User opens browser for handshake but closes it without logging in.	Timeout: The C++ state machine must hgodot_firebase_auth/
│       ├── SCsub                      # Build Logic
│       ├── config.py                  # Module Config
│       ├── auth_manager.h/.cpp        # Logic Core
│       ├── sdk/                       # Third-party SDKs
│       │   ├── firebase_cpp_sdk/
│       │   └── steamworks_sdk/
│       └── backend/
│           ├── functions/index.js     # Server Logic
│           ├── database.rules.json    # RTDB Security
│           └── public/login.html      # Web Portal
5.2 C++ Logic: The State Machine
Constraint: Do not block the main thread. Use polling.
code
C++
// AuthManager.h
enum AuthState {
    STATE_IDLE,
    STATE_ANON_PENDING,      // Waiting for anonymous login (Security layer)
    STATE_HANDSHAKE_PENDING, // Waiting for RTDB token (Desktop Web)
    STATE_STEAM_PENDING,     // Waiting for Cloud Function (Desktop Steam)
    STATE_LOGGED_IN
};

// AuthManager.cpp (_process)
void _process(float delta) {
    if (_state == STATE_HANDSHAKE_PENDING) {
        // Check if RTDB listener fired
        if (_handshake_complete) {
            _auth->SignInWithCustomToken(_received_token);
            _state = STATE_LOGGED_IN;
        }
        // Check Timeout
        if (OS::get_singleton()->get_ticks_msec() > _handshake_timeout) {
            _cancel_handshake();
        }
    }
}
5.3 Backend Logic: Cloud Functions (index.js)
Constraint: Use firebase-admin to mint tokens.
steamLogin(ticket):
GET api.steampowered.com/.../AuthenticateUserTicket
If valid, admin.auth().createCustomToken("steam:" + steamID)
finalizeHandshake(idToken, sessionId):
admin.auth().verifyIdToken(idToken) -> gets uid
admin.auth().createCustomToken(uid) -> gameToken
admin.database().ref("handshakes/" + sessionId).update({ token: gameToken })
redeemTransferCode(code, steamTicket):
Transactional read of Firestore transfer_codes/{code}.
If steamTicket exists, verify it, then link Steam ID to the Code's owner UID.
Return createCustomToken(ownerUid).
5.4 Security Rules (RTDB)
Constraint: Strict ownership.
code
JSON
{
  "rules": {
    "handshakes": {
      "$session": {
        // Client can only read if they own the session (via Anon Auth)
        ".read": "auth != null && data.child('owner').val() === auth.uid",
        // Client can only create the session claiming ownership
        ".write": "!data.exists() && newData.child('owner').val() === auth.uid"
      }
    }
  }
}
5.5 Build Logic (SCsub)
Constraint: Link order is critical for Cross-Platform compilation.
code
Python
# Windows Example
if env["platform"] == "windows":
    # 1. SDK Libs
    env.Append(LIBPATH=["sdk/firebase/libs/windows", "sdk/steam/libs/windows"])
    # 2. Specific Libraries
    env.Append(LIBS=[
        "firebase_auth", "firebase_database", "firebase_functions", "firebase_app", # Firebase
        "steam_api64", # Steam
        "ws2_32", "rpcrt4", "userenv" # System Deps
    ])
End of Specification.
This package contains all logical, visual, and technical constraints required to implement the solution.

## Refined Implementation Plan (Based on Existing Codebase Analysis)

### Phase 1: Leverage Existing C++ Module Infrastructure
**Extend Existing FirebaseAuth (godot/modules/firebase/auth.h)**
```cpp
// ADD to existing FirebaseAuth class
enum AuthState { STATE_IDLE, STATE_STEAM_PENDING, STATE_HANDSHAKE_PENDING, STATE_LOGGED_IN };

// NEW methods extend existing capabilities
void sign_in_with_steam_ticket(String steam_ticket);
void start_web_handshake(String session_id);
void check_handshake_completion();
bool is_steam_available();
```

### Phase 2: Create AuthService Following DatabaseService Pattern
**New GDScript Service Using Established Architecture**
```gdscript
class_name AuthService
extends RefCounted

# Follow DatabaseService signal pattern
signal auth_state_changed(user: Dictionary)
signal auth_error(error: Dictionary)

# Service composition (like DatabaseService)
var _firebase_auth: FirebaseAuth  # Existing C++ module
var _steam_integration: SteamIntegration
```

### Phase 3: Integrate with FirebaseServiceBackend
**Extend Existing Domain Architecture**
```gdscript
// ADD to existing FirebaseServiceBackend
var _auth_service: AuthService  # New service following existing pattern

func initialize() -> bool:
    _database_service = DatabaseService.new()    # Existing
    _auth_service = AuthService.new()             # NEW
```

### Phase 4: Cloud Function Extensions
**Build on Existing Firebase Backend Patterns**
- Extend existing security rules with handshake logic
- Add steamLogin function using existing Firebase admin patterns
- Leverage existing RTDB structure for transfer codes

### Phase 5: Cross-Platform UI Components
**Use Established Game UI Patterns**
- Follow existing game UI component structure
- Integrate with existing visual design system
- Leverage established platform detection patterns

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] Extend existing FirebaseAuth C++ module (auth.h/auth.mm) with Steam integration and web handshake capabilities
- [ ] Create new AuthService class following DatabaseService signal-based architecture pattern
- [ ] Integrate AuthService into existing FirebaseServiceBackend domain architecture
- [ ] Implement Steam authentication flow using existing C++ module patterns
- [ ] Add web-based social authentication with RTDB handshake channels (leveraging existing Firebase patterns)
- [ ] Create secure session management building on existing JWT token handling in FirebaseAuth C++ module
- [ ] Implement cross-platform account linking using transfer codes with existing RTDB infrastructure
- [ ] Add cross-platform authentication UI components following established game UI patterns
- [ ] Extend existing Firebase security rules for authentication channels and transfer codes
- [ ] Implement authentication error handling using established Firebase service error patterns
- [ ] Create comprehensive testing using existing Firebase testing methodologies and infrastructure
- [ ] Ensure offline authentication support leveraging existing credential caching patterns
- [ ] Add user privacy controls and consent management following existing data handling patterns
- [ ] Implement authentication analytics using existing Firebase backend integration patterns
<!-- AC:END -->
