import 'package:flutter/material.dart';

// Stub implementation for non-web platforms
// This file is used when compiling for Android/iOS
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
    // This should never be shown as we check kIsWeb before navigating
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: const Center(
        child: Text('Web camera is only available on web platform'),
      ),
    );
  }
}


