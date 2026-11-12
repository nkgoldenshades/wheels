# Testing Subscription Payment Function

## Issue
Payment failing with error: `ClientException: Failed to fetch, uri=https://us-central1-quickohunt-app.cloudfunctions.net/createSubscriptionCheckoutSession`

## Root Cause
The error "Failed to fetch" means the HTTP request is failing BEFORE reaching the Firebase Function. This is a **client-side network issue**, not a server error.

## Possible Causes
1. **Internet connectivity issue** - The device/emulator has no internet or can't reach Firebase
2. **Auth token expired/invalid** - The Firebase auth token might be expired
3. **Network restrictions** - Firewall or network policy blocking the request
4. **DNS resolution failure** - Can't resolve the Firebase Functions domain

## Solutions

### 1. Check Internet Connectivity
Make sure your test device/emulator has active internet:
- Try opening a webpage in the device browser
- Check if other Firebase features work (authentication, Firestore)
- Restart the emulator/device

### 2. Verify Firebase Function is Accessible
Test the function directly using curl/Postman:

```bash
# Get your Firebase ID token first
firebase auth:export users.json
# Or get it from the Flutter app debug logs

# Then test the function (replace YOUR_ID_TOKEN with actual token)
curl -X POST \
  https://us-central1-quickohunt-app.cloudfunctions.net/createSubscriptionCheckoutSession \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -d '{
    "user_id": "YOUR_USER_ID",
    "plan_name": "Premium",
    "amount": 1299,
    "currency": "usd"
  }'
```

### 3. Check App Internet Permissions
Ensure your Android app has internet permission in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### 4. Add Debug Logging
Add more detailed logging to see exactly where it fails:

```dart
// In stripe_service.dart, processSubscriptionPayment method
try {
  print('[DEBUG] Getting auth headers...');
  final headers = await _authorizedJsonHeaders();
  print('[DEBUG] Headers: ${headers.keys}');
  
  final url = '$backendUrl/createSubscriptionCheckoutSession';
  print('[DEBUG] Calling: $url');
  
  final response = await http.post(
    Uri.parse(url),
    headers: headers,
    body: json.encode({
      'user_id': userId,
      'plan_name': planName,
      'amount': amount,
      'currency': currency,
    }),
  ).timeout(Duration(seconds: 30)); // Add timeout
  
  print('[DEBUG] Response status: ${response.statusCode}');
  print('[DEBUG] Response body: ${response.body}');
  
  // Rest of the code...
} on http.ClientException catch (e) {
  print('[ERROR] ClientException: $e');
  print('[ERROR] This usually means network connectivity issue');
  return {'error': 'Network error: ${e.message}'};
} on TimeoutException catch (e) {
  print('[ERROR] Timeout: $e');
  return {'error': 'Request timed out'};
} catch (e) {
  print('[ERROR] Unexpected error: $e');
  return {'error': e.toString()};
}
```

### 5. Test with Different Network
- Try switching from WiFi to mobile data (or vice versa)
- Try on a different device
- Try on a real device instead of emulator

### 6. Check if Function Requires Secrets
The function needs Stripe API keys. Verify they're configured in Firebase Secret Manager:

```bash
# Check if secrets exist
firebase functions:secrets:access STRIPE_SECRET_KEY_TEST
firebase functions:secrets:access USE_LIVE_KEYS

# If missing, set them
firebase functions:secrets:set STRIPE_SECRET_KEY_TEST
# Enter: sk_test_51SvbBRPL6V2gHHHXG3E10yXmKrN8XbXn4aCG1GYm5G293d9OMtn6nn5gwjjOyKLT3RYyPMb8UHQgHTDsoaUfuOgF00CGLze3LL

firebase functions:secrets:set USE_LIVE_KEYS
# Enter: false
```

## Quick Fix to Try Now

1. **Restart the app completely** - Close and reopen
2. **Clear app cache** - In device settings
3. **Check internet** - Open a browser on the device
4. **Check Firebase Auth** - Make sure user is logged in:

```dart
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  print('[ERROR] User not logged in!');
  return {'error': 'Please log in first'};
}
print('[DEBUG] User ID: ${user.uid}');
print('[DEBUG] Token: ${await user.getIdToken()}');
```

## Expected Behavior
When working correctly:
1. App calls `processSubscriptionPayment()`
2. Function authenticates the user
3. Function creates a Stripe Checkout Session
4. Function returns a checkout URL
5. App opens the URL in a browser
6. User completes payment in Stripe
7. User is redirected back to success URL

## Next Steps
1. Add the debug logging above
2. Run the app again
3. Check the console output
4. Share the debug logs to identify exact failure point
