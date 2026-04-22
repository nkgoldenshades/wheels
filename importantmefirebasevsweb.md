Problem:
Flutter Web compiles Dart → JavaScript. When Firebase throws an error on web, it becomes a JavaScript object — not a Dart object.
Where:
Inside these 3 catch blocks in auth_repository.dart:
dart// signUpWithEmail
// signInWithEmail  
// sendPasswordResetEmail
What was broken:
dartif (e is firebase_auth.FirebaseAuthException) // ← FAILS on web
On web this check always returns false because the error is a JS object, not a Dart FirebaseAuthException. So error message was never extracted → app crashed with red screen.
What was fixed:
dartString? _extractFirebaseError(Object e) {
  // Try Dart way first (works on mobile)
  if (e is firebase_auth.FirebaseAuthException) {
    return _getErrorMessage(e);
  }
  // Web fallback - check error string instead
  final str = e.toString();
  if (str.contains('weak-password')) return '...';
  if (str.contains('email-already-in-use')) return '...';
  // etc...
}
Summary in one line:

Mobile uses is check → Web uses toString() check → both now work ✅
Found it. Look at this in your main.dart:
dart// Start app immediately, initialize services in background
runApp(MyApp(startupError: startupError));

// Initialize services in background (non-blocking)
_initializeServicesInBackground(initWithTimeout);
The problem: The app starts and renders the splash screen before Firebase is initialized. The splash screen immediately accesses AuthRepository.instance.currentUserListenable — which internally uses FirebaseAuth.instance — but Firebase hasn't finished initializing yet. This causes the JS type crash on web.
The fix — make main() wait for Firebase before running the app:
dartvoid main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) print('❌ Platform Error: $error');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Wait for Firebase FIRST before starting app
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) print('✅ Firebase initialized');
  } catch (e) {
    try {
      Firebase.app();
      if (kDebugMode) print('✅ Firebase already initialized');
    } catch (_) {
      if (kDebugMode) print('⚠️ Firebase unavailable');
    }
  }

  // Now start app — Firebase is ready
  runApp(const MyApp());

  // Everything else in background
  _initializeServicesInBackground();
}
And simplify _initializeServicesInBackground to skip the Firebase init block since it's already done. That's the only change needed.
