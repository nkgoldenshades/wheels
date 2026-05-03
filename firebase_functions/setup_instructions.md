# Firebase AI Functions Setup Instructions

## 1. Prerequisites
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase project created
- Node.js 18+ installed

## 2. Initialize Firebase Functions
```bash
cd firebase_functions
firebase login
firebase init functions
# Select existing project
# Choose JavaScript
# Install dependencies: Yes
```

## 3. Install Dependencies
```bash
cd functions
npm install
```

## 4. Set Environment Variables
```bash
# Set your Gemini API key
firebase functions:config:set gemini.api_key="YOUR_GEMINI_API_KEY"

# Deploy config
firebase deploy --only functions:config
```

## 5. Deploy Functions
```bash
firebase deploy --only functions
```

## 6. Add to Flutter pubspec.yaml
```yaml
dependencies:
  cloud_functions: ^4.6.0
```

## 7. Initialize in Flutter main.dart
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // For development/testing with emulator
  // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  
  runApp(MyApp());
}
```

## 8. Usage Examples

### Content Moderation
```dart
final result = await AIService.instance.moderateContent(
  text: "This is my vehicle description",
  type: ContentType.vehicle_description,
);

if (result?.approved == true) {
  // Content is safe
} else {
  // Show error: result?.reason
}
```

### Image Analysis
```dart
final results = await AIService.instance.analyzeImages(
  imageUrls: ["https://example.com/image1.jpg"],
  type: ImageType.vehicle,
);

if (results?.every((r) => r.analysis?.appropriate == true) == true) {
  // All images are appropriate
}
```

### Smart Suggestions
```dart
final suggestions = await AIService.instance.generateSuggestions(
  type: SuggestionType.vehicle_title,
  inputData: {
    'vehicleType': 'SUV',
    'serviceType': 'passenger',
    'location': 'Mumbai',
  },
);

final titles = suggestions?.titleSuggestions;
// ["Comfortable SUV for Mumbai Rides", "Premium SUV Service", ...]
```

## 9. Security Rules
The functions automatically:
- ✅ Verify user authentication
- ✅ Apply rate limiting (20 requests/day for content, 5 for images)
- ✅ Log all AI interactions
- ✅ Validate input parameters
- ✅ Handle errors gracefully

## 10. Monitoring
Check Firebase Console > Functions for:
- Function execution logs
- Error rates
- Performance metrics
- Usage statistics

## 11. Cost Control
- Rate limiting prevents abuse
- Logs help track usage
- Can adjust limits in function code
- Monitor Firebase billing dashboard

## 12. Testing
```bash
# Run local emulator
firebase emulators:start --only functions

# Test with Flutter app pointing to emulator
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```