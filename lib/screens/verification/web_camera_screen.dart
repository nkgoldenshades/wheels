// Platform-agnostic export for WebCameraVerificationScreen
// Automatically uses the correct implementation based on platform

export 'web_camera_verification_screen_io.dart'
    if (dart.library.js_interop) 'web_camera_verification_screen_web.dart';

