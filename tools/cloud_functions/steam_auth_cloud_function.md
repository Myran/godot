# Steam Authentication Cloud Function (Task-404)

## Overview

This Cloud Function verifies Steam authentication tickets with the Steam Web API and generates Firebase custom tokens for sign-in.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Godot Game     │────▶│  Cloud Function  │────▶│  Steam Web API   │
│  (Steam Ticket)  │     │  (Backend)       │     │  (Validation)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                        │                        │
         │                        ▼                        │
         │                 ┌──────────────┐                │
         └────────────────▶│  Firebase Auth│◀───────────────┘
                          │  (Custom Token)│
                          └──────────────┘
```

## Function: authenticateWithSteam

### Request Format

```typescript
interface AuthenticateWithSteamRequest {
  sessionTicket: string;  // Hex-encoded Steam auth ticket
  steamId?: string;        // Optional Steam ID (for validation)
  personaName?: string;    // Optional Steam display name
}

interface AuthenticateWithSteamResponse {
  success: boolean;
  customToken?: string;
  steamId?: string;
  error?: string;
}
```

### Implementation

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Get Steam API key from Firebase config
// Set with: firebase functions:config:get steam.apikey
const STEAM_API_KEY = functions.config().steam.apikey;
const STEAM_APP_ID = functions.config().steam.appid || '480'; // Default to Steamworks test app

export const authenticateWithSteam = functions.https.onCall(async (data, context) => {
  const { sessionTicket, steamId: clientSteamId, personaName } = data;

  // 1. Verify request contains session ticket
  if (!sessionTicket || typeof sessionTicket !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Session ticket is required'
    );
  }

  console.log(`Steam auth request for ticket: ${sessionTicket.substring(0, 16)}...`);

  // 2. Verify Steam session ticket with Steam Web API
  const steamUrl = `https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/`;
  const params = new URLSearchParams({
    key: STEAM_API_KEY,
    appid: STEAM_APP_ID,
    ticket: sessionTicket
  });

  let steamResponse;
  try {
    const response = await fetch(`${steamUrl}?${params.toString()}`);
    steamResponse = await response.json();
  } catch (error) {
    console.error('Steam API request failed:', error);
    throw new functions.https.HttpsError(
      'unavailable',
      'Steam API is currently unavailable'
    );
  }

  // 3. Check Steam API response
  if (!steamResponse.response || steamResponse.response.error) {
    const errorMsg = steamResponse.response?.error?.errormsg || 'Invalid Steam ticket';
    console.error('Steam ticket verification failed:', errorMsg);
    throw new functions.https.HttpsError(
      'unauthenticated',
      `Steam ticket validation failed: ${errorMsg}`
    );
  }

  const steamId = steamResponse.response.params.steamid;
  console.log(`Steam ticket validated for Steam ID: ${steamId}`);

  // 4. Optionally verify client-provided Steam ID matches
  if (clientSteamId && clientSteamId !== steamId) {
    console.warn(`Client Steam ID mismatch: ${clientSteamId} vs ${steamId}`);
    throw new functions.https.HttpsError(
      'permission-denied',
      'Steam ID mismatch'
    );
  }

  // 5. Create Firebase custom token
  // Using "steam:" prefix to indicate Steam auth provider
  const firebaseUid = `steam_${steamId}`;
  let customToken: string;

  try {
    const additionalClaims = {
      provider: 'steam',
      steamId: steamId,
      personaName: personaName || ''
    };

    customToken = await admin.auth().createCustomToken(firebaseUid, additionalClaims);
    console.log(`Firebase custom token created for UID: ${firebaseUid}`);
  } catch (error) {
    console.error('Failed to create Firebase custom token:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to generate authentication token'
    );
  }

  // 6. Return custom token to client
  return {
    success: true,
    customToken: customToken,
    steamId: steamId,
    firebaseUid: firebaseUid
  };
});
```

## Firebase Security Rules

After a user signs in with Steam, ensure Firebase security rules grant appropriate access:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid || auth.token.provider == 'steam'",
        ".write": "auth != null && auth.uid == $uid || auth.token.provider == 'steam'"
      }
    },
    "user_profiles": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

## Deployment

### 1. Configure Firebase Functions

```bash
# Set Steam API key in Firebase config
firebase functions:config:set steam.apikey "YOUR_STEAM_API_KEY"

# Optional: Set Steam App ID (default: 480 for Steamworks test)
firebase functions:config:set steam.appid "YOUR_STEAM_APP_ID"
```

### 2. Deploy Function

```bash
# Deploy only the Steam auth function
firebase deploy --only functions:authenticateWithSteam

# Or deploy all functions
firebase deploy --only functions
```

### 3. Get Function URL

```bash
# List deployed functions
firebase functions:list

# The function URL will be:
# https://REGION-PROJECT_ID.cloudfunctions.net/authenticateWithSteam
```

## Testing

### Local Testing with Firebase Functions Emulator

```bash
# 1. Start the emulator
firebase emulators:start --only functions

# 2. Test with curl
curl -X POST \
  http://localhost:5001/PROJECT_ID/us-central1/authenticateWithSteam \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "sessionTicket": "YOUR_TEST_TICKET_HEX",
      "steamId": "YOUR_STEAM_ID",
      "personaName": "TestUser"
    }
  }'
```

### Production Testing

Use the SteamAuthService in Godot to test the complete flow:

```gdscript
var steam_service = SteamAuthService.new()
steam_service.initialize("https://REGION-PROJECT_ID.cloudfunctions.net/authenticateWithSteam")

var result = await steam_service.authenticate_with_steam()
if result.success:
  print("Steam auth successful!")
else:
  print("Steam auth failed: " + result.error)
```

## Steam Web API Documentation

- **AuthenticateUserTicket**: https://steamapi.xpaw.com/ISteamUserAuth/AuthenticateUserTicket/v1/
- **Steam Web API Key**: https://steamcommunity.com/dev/apikey

## Error Handling

| Error Code | Description | Client Action |
|------------|-------------|---------------|
| `invalid-argument` | Missing or invalid session ticket | Check ticket format |
| `unavailable` | Steam API down | Retry with backoff |
| `unauthenticated` | Invalid Steam ticket | User must restart Steam |
| `permission-denied` | Steam ID mismatch | Check for account hijacking |
| `internal` | Firebase error | Contact support |

## Security Considerations

1. **Never trust client-provided Steam ID** - Always verify with Steam Web API
2. **Rate limiting** - Consider implementing rate limiting to prevent abuse
3. **HTTPS only** - Function is only accessible via HTTPS
4. **App check** - Consider adding Firebase App Check for additional security

## Future Enhancements

- Account linking (Steam + existing Firebase account)
- Transfer codes for cross-platform account linking
- Steam inventory integration
- Steam friends list synchronization
