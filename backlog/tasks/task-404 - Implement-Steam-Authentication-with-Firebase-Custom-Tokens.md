---
id: task-404
title: Implement Steam Authentication with Firebase Custom Tokens
status: Done
assignee: []
created_date: '2025-12-30 23:33'
updated_date: '2026-01-07 00:33'
labels:
  - firebase
  - steam
  - authentication
  - gdextension
  - integration
dependencies:
  - task-399
  - task-406
priority: medium
ordinal: 14000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Overview

Integrate Steam authentication into GameTwo, allowing players to sign in with their Steam account and have it linked to Firebase Auth via custom tokens.

## Research Findings

### GodotSteam Integration

**GodotSteam GDExtension** is the primary solution for Steam integration with Godot 4:
- **Latest Version**: GDExtension 4.4+ (December 2025)
- **Steamworks SDK**: 1.63 (latest)
- **Platforms**: Windows, Linux, macOS
- **Repository**: https://github.com/GodotSteam/GodotSteam
- **Documentation**: https://godotsteam.com/

Key GodotSteam features for authentication:
- `Steam.steamInit()` - Initialize Steam client
- `Steam.getSteamID()` - Get user's Steam ID (64-bit)
- `Steam.getAuthSessionTicket()` - Generate encrypted auth ticket for server validation
- `Steam.getPersonaName()` - Get Steam display name

### Firebase Custom Token Authentication

Firebase supports custom tokens for integrating third-party auth providers like Steam:

**Flow Architecture**:
```
1. Godot Game (GodotSteam)
   ↓ getAuthSessionTicket()
2. Backend Server (Cloud Function / Node.js)
   ↓ Verify ticket with Steam Web API
   ↓ Create Firebase custom token
3. Firebase Auth
   ↓ signInWithCustomToken()
4. Authenticated User
```

**Firebase Admin SDK** (server-side) creates custom tokens:
```javascript
const admin = require('firebase-admin');
const customToken = await admin.auth().createCustomToken(steamId, {
  provider: 'steam',
  displayName: steamPersonaName
});
```

### Reference Implementation: firebase-steam-login

GitHub library demonstrating the complete flow:
- **Repository**: https://github.com/nicholasareed/firebase-steam-login
- **Key Components**:
  - Steam OpenID validation
  - Firebase custom token generation
  - Client-side token exchange

### Required Components

1. **Client-Side (Godot)**:
   - GodotSteam GDExtension integration
   - Steam session ticket generation
   - HTTP request to backend for custom token
   - Firebase signInWithCustomToken()

2. **Server-Side (Cloud Function)**:
   - Steam Web API ticket validation
   - Firebase Admin SDK for custom token creation
   - Secure endpoint for token exchange

3. **Steam Developer Setup**:
   - Steam Web API key
   - App ID configuration
   - Steamworks SDK agreement

## Implementation Approach

### Phase 1: GodotSteam Setup
- Add GodotSteam GDExtension to project
- Initialize Steam on game launch
- Verify Steam client connection
- Test basic Steam API calls

### Phase 2: Steam Auth Ticket Flow
- Implement `getAuthSessionTicket()` in GDScript
- Create backend Cloud Function for ticket validation
- Integrate with Steam Web API ISteamUserAuth/AuthenticateUserTicket

### Phase 3: Firebase Custom Token Bridge
- Generate Firebase custom tokens from validated Steam tickets
- Include Steam user metadata (SteamID, persona name)
- Handle token expiration and refresh

### Phase 4: Client Token Exchange
- Add signInWithCustomToken() to FirebaseAuth C++ module
- Link Steam identity to Firebase Auth user
- Support account linking (Steam + anonymous → merged account)

## C++ Module Enhancement Required

Add to `godot/modules/firebase/auth.cpp`:
```cpp
void FirebaseAuth::sign_in_with_custom_token(String token) {
    print_line("[Auth] Start sign in with custom token");
    firebase::Future<firebase::auth::AuthResult> result = 
        auth->SignInWithCustomToken(token.utf8().get_data());
    result.OnCompletion([](const firebase::Future<firebase::auth::AuthResult>& result, void* user_data) {
        ((FirebaseAuth*)user_data)->OnCreateUserCallback(result, user_data);
    }, this);
}
```

## GDScript Integration Layer

```gdscript
# steam_auth_service.gd
class_name SteamAuthService
extends Node

signal steam_auth_completed(success: bool, firebase_user_id: String)
signal steam_auth_failed(error: String)

var _steam_initialized: bool = false

func initialize_steam() -> bool:
    if not Steam.steamInit():
        push_error("[SteamAuth] Failed to initialize Steam")
        return false
    _steam_initialized = true
    return true

func authenticate_with_firebase() -> void:
    if not _steam_initialized:
        steam_auth_failed.emit("Steam not initialized")
        return
    
    var ticket_data = Steam.getAuthSessionTicket()
    var steam_id = Steam.getSteamID()
    var persona_name = Steam.getPersonaName()
    
    # Send to backend for custom token generation
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_token_request_completed)
    
    var body = JSON.stringify({
        "ticket": ticket_data.hex_encode(),
        "steam_id": str(steam_id),
        "persona_name": persona_name
    })
    
    http.request(
        "https://your-backend.com/steam-auth",
        ["Content-Type: application/json"],
        HTTPClient.METHOD_POST,
        body
    )

func _on_token_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if code != 200:
        steam_auth_failed.emit("Backend returned error: %d" % code)
        return
    
    var json = JSON.parse_string(body.get_string_from_utf8())
    var custom_token = json.get("firebase_token", "")
    
    if custom_token.is_empty():
        steam_auth_failed.emit("No token in response")
        return
    
    # Sign in to Firebase with custom token
    FirebaseAuth.sign_in_with_custom_token(custom_token)
```

## Dependencies

- **task-399**: Firebase Auth Enhancement (signInWithCustomToken requires base Auth improvements)
- GodotSteam GDExtension 4.4+
- Backend infrastructure (Cloud Functions or custom server)
- Steam Web API key

## Testing Requirements

1. **Unit Tests**: Mock Steam ticket validation
2. **Integration Tests**: Full auth flow with test Steam account
3. **Debug Actions**:
   - `system.steam.init_status` - Check Steam initialization
   - `system.steam.user_info` - Display Steam user data
   - `system.steam.auth_flow` - Test complete authentication flow

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 #1 #1 #1 GodotSteam GDExtension integrated and initializing
- [ ] #2 #2 #2 #2 Steam session tickets generated successfully
- [ ] #3 #3 #3 #3 Backend validates tickets with Steam Web API
- [ ] #4 #4 #4 #4 Firebase custom tokens created from validated tickets
- [ ] #5 #5 #5 #5 signInWithCustomToken() working in C++ module
- [ ] #6 #6 #6 #6 GDScript service layer for Steam auth
- [ ] #7 #7 #7 #7 Account linking (Steam + existing Firebase user)
- [ ] #8 #8 #8 #8 Debug actions for testing Steam auth flow
- [ ] #9 #9 #9 #9 Cross-platform support (Windows, Linux, macOS)
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan (Based on quickstart-cpp Analysis)

### Key Discovery: Requires SignInWithCustomToken
From auth quickstart and our analysis, task-404 requires:
```cpp
Future<AuthResult> future = auth->SignInWithCustomToken(token);
```

This method is **MISSING from our current auth.cpp** and must be added in task-399.

### Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  GodotSteam     │────▶│  Cloud Function  │────▶│  Firebase Auth  │
│  (GDExtension)  │     │  (Backend)       │     │  (Custom Token) │
└─────────────────┘     └──────────────────┘     └─────────────────┘
        │                        │                        │
   Steam Session           Verify ticket          Return custom token
   Ticket                  Create custom token    Sign in user
```

### Phase 1: Cloud Function Backend

**Steam ticket verification + Firebase custom token generation:**
```typescript
// functions/src/steamAuth.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const STEAM_API_KEY = functions.config().steam.apikey;
const STEAM_APP_ID = functions.config().steam.appid;

export const authenticateWithSteam = functions.https.onCall(async (data, context) => {
    const { sessionTicket } = data;
    
    // 1. Verify Steam session ticket with Steam Web API
    const steamResponse = await fetch(
        `https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/` +
        `?key=${STEAM_API_KEY}&appid=${STEAM_APP_ID}&ticket=${sessionTicket}`
    );
    const steamData = await steamResponse.json();
    
    if (steamData.response.error) {
        throw new functions.https.HttpsError('unauthenticated', 'Invalid Steam ticket');
    }
    
    const steamId = steamData.response.params.steamid;
    
    // 2. Create Firebase custom token
    const customToken = await admin.auth().createCustomToken(`steam:${steamId}`, {
        steamId: steamId,
        provider: 'steam'
    });
    
    return { customToken, steamId };
});
```

### Phase 2: GodotSteam Integration

**Check GodotSteam GDExtension availability:**
```gdscript
# steam_auth_service.gd
class_name SteamAuthService extends Node

signal steam_auth_completed(success: bool, error: String)

var _steam: Node  # GodotSteam singleton
var _functions: FirebaseFunctions

func _ready() -> void:
    # Check if Steam is available
    if not Engine.has_singleton("Steam"):
        push_error("[SteamAuth] GodotSteam not available")
        return
    _steam = Engine.get_singleton("Steam")
```

### Phase 3: Auth Flow

```gdscript
func authenticate_with_steam() -> Dictionary:
    # 1. Get Steam session ticket
    var ticket_result = _steam.getAuthSessionTicket()
    if ticket_result.is_empty():
        return {"success": false, "error": "Failed to get Steam session ticket"}
    
    var ticket_hex = ticket_result.hex_encode()
    
    # 2. Call Cloud Function to verify ticket and get custom token
    var call_result = await _functions.call_function("authenticateWithSteam", {
        "sessionTicket": ticket_hex
    })
    
    if not call_result.success:
        return {"success": false, "error": call_result.error}
    
    var custom_token = call_result.data.customToken
    var steam_id = call_result.data.steamId
    
    # 3. Sign in to Firebase with custom token (REQUIRES task-399)
    var auth_result = await _auth_service.sign_in_with_custom_token(custom_token)
    
    if not auth_result.success:
        return {"success": false, "error": auth_result.error}
    
    return {
        "success": true,
        "steam_id": steam_id,
        "firebase_uid": auth_result.uid
    }
```

### Phase 4: Account Linking

**Link Steam to existing Firebase account:**
```gdscript
func link_steam_to_account() -> Dictionary:
    # User must already be signed in
    if not _auth_service.is_signed_in():
        return {"success": false, "error": "Must be signed in first"}
    
    var ticket_hex = _steam.getAuthSessionTicket().hex_encode()
    
    # Call function that links Steam ID to existing account
    var result = await _functions.call_function("linkSteamAccount", {
        "sessionTicket": ticket_hex,
        "existingUid": _auth_service.get_uid()
    })
    
    return result
```

### Phase 5: Error Handling

**Handle Steam not running:**
```gdscript
func ensure_steam_available() -> bool:
    if not Engine.has_singleton("Steam"):
        emit_signal("steam_error", "Steam not initialized")
        return false
    
    if not _steam.isSteamRunning():
        emit_signal("steam_error", "Steam client not running")
        return false
    
    return true
```

### Dependencies
1. **task-399 (Auth)** - MUST add `sign_in_with_custom_token()` method
2. **Cloud Functions** - Must be deployed to Firebase project
3. **GodotSteam** - GDExtension must be integrated into project
4. **Steam Web API Key** - Must be configured in Firebase Functions

### Files to Create

**Backend (Firebase Functions):**
- `functions/src/steamAuth.ts` - Steam ticket verification
- `functions/src/index.ts` - Export functions

**GDScript:**
- `project/firebase/steam_auth_service.gd` - Steam auth orchestration
- `project/debug/actions/steam_auth/steam_sign_in_test_action.gd`
- `project/debug/actions/steam_auth/steam_link_test_action.gd`

**Test Configs:**
- `tests/debug_configs/steam-auth-layer.json`

### Platform Considerations
- **Windows**: Primary platform for Steam
- **macOS**: Steam also available
- **Mobile**: Steam not available - skip gracefully

### Risk Factors
1. **GodotSteam integration** - External dependency
2. **Cloud Functions deployment** - New infrastructure
3. **Steam Web API** - External service dependency
4. **task-399 dependency** - Must complete Auth refactor first
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## CTO Review Notes (2025-12-31)

### External Dependency Risks

This task has more external dependencies than other Firebase tasks:
1. GodotSteam GDExtension (third-party)
2. Backend Cloud Function infrastructure
3. Steam Web API
4. Firebase Admin SDK (server-side)

### Critical Pre-Implementation Requirements

**1. Backend Infrastructure Must Be Defined**

The task says "Backend Cloud Function" but doesn't specify:
```markdown
## Backend Infrastructure Requirements
- Cloud Functions project: `gametwo-backend` (or create new)
- Deployment: `firebase deploy --only functions`
- Region: us-central1 (closest to users)
- Runtime: Node.js 18
- Secrets: Steam API key in Secret Manager, NOT environment variables
```

**2. Steam Client Not Running Handling**

Players may launch game without Steam. Handle gracefully:
```gdscript
func initialize_steam() -> Dictionary:
    var result = Steam.steamInit()
    match result:
        Steam.STEAM_INIT_RESULT_OK:
            return {"success": true}
        Steam.STEAM_INIT_NO_CLIENT:
            return {"success": false, "error": "steam_not_running", 
                    "message": "Please launch Steam before playing"}
        Steam.STEAM_INIT_VERSION_MISMATCH:
            return {"success": false, "error": "sdk_mismatch",
                    "message": "Game update required"}
        _:
            return {"success": false, "error": "unknown"}
```

**3. Account Linking Edge Cases**

Three scenarios need explicit handling:

| Scenario | Handling |
|----------|----------|
| New Steam user, no Firebase account | Create new Firebase user, link Steam |
| Steam user already linked to Firebase | Sign in to existing Firebase account |
| Steam user tries to link to different Firebase account | Error: "Steam account already in use" + offer to sign out |
| Anonymous user links Steam | Merge anonymous data into Steam-linked account |

**4. Security Considerations**

- Steam session tickets expire (verify freshness)
- Rate limit backend endpoint (prevent brute force)
- Validate Steam ticket on backend, NEVER trust client
- Log failed auth attempts for monitoring

**5. Retry Logic**

Network can fail during token exchange. Implement:
```gdscript
const MAX_RETRIES = 3
const RETRY_DELAY_MS = 1000

func _request_custom_token_with_retry(ticket: String, retries: int = 0) -> Dictionary:
    var result = await _request_custom_token(ticket)
    if not result.success and result.error == "network" and retries < MAX_RETRIES:
        await get_tree().create_timer(RETRY_DELAY_MS / 1000.0).timeout
        return await _request_custom_token_with_retry(ticket, retries + 1)
    return result
```

### Implementation Sequence

1. **First**: Ensure task-399 (Auth) is complete with `signInWithCustomToken`
2. **Second**: Set up Cloud Functions project and deployment pipeline
3. **Third**: Implement Steam ticket validation backend
4. **Fourth**: Implement GodotSteam client integration
5. **Last**: Account linking and edge case handling
<!-- SECTION:NOTES:END -->

<!-- AC:END -->

- [ ] #10 Add firebase-steam-tests to firebase-all.json so tests run with `just test`
<!-- AC:END -->

<!-- AC:END -->

- [ ] #10 #10 Handle Steam account already linked to different Firebase user (error + user choice)
- [ ] #11 #11 Handle anonymous → Steam account merge with data preservation
- [ ] #12 #12 Handle Steam client not running gracefully (user-friendly error, not crash)
- [ ] #13 #13 Backend Cloud Function project and deployment process documented
- [ ] #14 #14 Steam API key stored in Secret Manager (not in code or environment variables)
- [ ] #15 #15 Retry logic for transient network failures during token exchange
- [ ] #16 #16 Rate limiting on backend to prevent abuse
<!-- AC:END -->
