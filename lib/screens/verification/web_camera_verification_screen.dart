import 'package:flutter/material.dart';

class WebCameraVerificationScreen extends StatelessWidget {
  final String title;
  final bool isProfilePhoto;

  const WebCameraVerificationScreen({
    super.key,
    required this.title,
    this.isProfilePhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Web camera verification is not available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature is only available on mobile devices.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

