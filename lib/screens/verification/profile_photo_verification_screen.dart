import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/face_matching_service.dart';

enum ProfileVerificationStep {
  detectFace, // Step 1: Detect face
  turnLeft, // Step 2: Turn head left
  turnRight, // Step 3: Turn head right
  smile, // Step 4: Smile for the camera
  capturing, // Step 5: Capturing photo
}

class ProfilePhotoVerificationScreen extends StatefulWidget {
  final Uint8List? referencePhotoBytes;

  const ProfilePhotoVerificationScreen({super.key, this.referencePhotoBytes});

  @override
  State<ProfilePhotoVerificationScreen> createState() =>
      _ProfilePhotoVerificationScreenState();
}

class _ProfilePhotoVerificationScreenState
    extends State<ProfilePhotoVerificationScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSwitchingCamera = false;
  bool _isStreaming = false; // ✅ FIX: Track stream state

  // Liveness detection state
  ProfileVerificationStep _currentStep = ProfileVerificationStep.detectFace;
  int _stepProgress = 0;
  final int _requiredDetections =
      2; // Need 2 consecutive detections per step (reduced for better UX)
  String _debugMessage = ''; // Debug feedback

  // Face detection visualization
  Rect? _faceRect;
  Size? _imageSize;

  late FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeCamera();
  }

  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true, // Enable for head pose detection
      enableClassification: true, // Enable for smile detection
      enableLandmarks: true, // Enable for facial landmarks
      enableTracking: true, // Enable for tracking same face
      minFaceSize: 0.15, // Slightly larger minimum for profile photo
      performanceMode: FaceDetectorMode
          .fast, // Changed to fast mode for better responsiveness
    );
    _faceDetector = FaceDetector(options: options);
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No camera found')));
        return;
      }

      // Use front camera for selfie by default
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      await _setupCamera(camera);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high, // High quality for profile photo
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();

    if (!mounted) return;
    setState(() => _isInitialized = true);

    // Start continuous face detection
    _startFaceDetection();
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2 || _isSwitchingCamera) return;

    setState(() => _isSwitchingCamera = true);

    try {
      // Stop current camera
      await _safeStopImageStream(); // ✅ FIX: use safe stop
      await _controller?.dispose();

      // Get opposite camera
      final currentLens = _controller?.description.lensDirection;
      final newCamera = _cameras!.firstWhere(
        (c) => c.lensDirection != currentLens,
        orElse: () => _cameras!.first,
      );

      // Setup new camera
      await _setupCamera(newCamera);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Switched to ${newCamera.lensDirection == CameraLensDirection.front ? 'front' : 'back'} camera',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      debugPrint('Camera switch error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to switch camera: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSwitchingCamera = false);
      }
    }
  }

  // ✅ FIX: Safe stop that checks if stream is actually running
  Future<void> _safeStopImageStream() async {
    try {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          _isStreaming) {
        await _controller!.stopImageStream();
        _isStreaming = false;
      }
    } catch (e) {
      debugPrint('stopImageStream error (ignored): $e');
      _isStreaming = false;
    }
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return; // ✅ FIX: Don't start if already streaming

    _isStreaming = true; // ✅ FIX: Mark as streaming
    _controller!.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _detectFaces(image);
    });
  }

  Future<void> _detectFaces(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        if (mounted) {
          setState(() => _debugMessage = '❌ Camera conversion failed');
        }
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) {
        _isProcessing = false;
        return;
      }

      // Debug: Show face count and detection status
      if (faces.isEmpty) {
        setState(() {
          _stepProgress = 0;
          _debugMessage =
              '👤 No face detected — move closer & ensure good lighting';
          _faceRect = null;
        });
        _isProcessing = false;
        return;
      }

      // Debug: Face detected - show details
      final face = faces.first;
      debugPrint('✅ Face detected! Bounds: ${face.boundingBox}');
      debugPrint('   Head Y angle: ${face.headEulerAngleY}');
      debugPrint('   Smile prob: ${face.smilingProbability}');

      // Update face rectangle for visualization
      setState(() {
        _faceRect = face.boundingBox;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });

      bool stepCompleted = false;
      String debugInfo = '';

      switch (_currentStep) {
        case ProfileVerificationStep.detectFace:
          // Just need to detect a face
          stepCompleted = true;
          debugInfo = '✓ Face detected! (${faces.length} faces)';
          break;

        case ProfileVerificationStep.turnLeft:
          // Check if head is turned left (positive Y rotation)
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          debugInfo =
              '← Turn LEFT: ${headEulerAngleY.toStringAsFixed(1)}° (need >8°)';
          stepCompleted = headEulerAngleY > 8;
          break;

        case ProfileVerificationStep.turnRight:
          // Check if head is turned right (negative Y rotation)
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          debugInfo =
              '→ Turn RIGHT: ${headEulerAngleY.toStringAsFixed(1)}° (need <-8°)';
          stepCompleted = headEulerAngleY < -8;
          break;

        case ProfileVerificationStep.smile:
          // Check if person is smiling
          final smilingProbability = face.smilingProbability ?? 0;
          debugInfo =
              '😊 Smile: ${(smilingProbability * 100).toStringAsFixed(0)}% (need >50%)';
          stepCompleted = smilingProbability > 0.5;
          break;

        case ProfileVerificationStep.capturing:
          // Already capturing, do nothing
          debugInfo = '📸 Capturing...';
          break;
      }

      if (stepCompleted) {
        setState(() {
          _stepProgress++;
          _debugMessage = '$debugInfo ($_stepProgress/$_requiredDetections)';
        });

        if (_stepProgress >= _requiredDetections) {
          // Step completed, move to next
          debugPrint('✅ Step ${_currentStep.name} completed!');
          _moveToNextStep();
        }
      } else {
        // Reset progress if condition not met
        setState(() {
          _stepProgress = 0;
          _debugMessage = debugInfo;
        });
      }
    } catch (e) {
      debugPrint('❌ Face detection error: $e');
      if (mounted) {
        setState(
          () => _debugMessage =
              '❌ Detection error: ${e.toString().substring(0, 50)}',
        );
      }
    }

    _isProcessing = false;
  }

  void _moveToNextStep() {
    setState(() {
      _stepProgress = 0;

      switch (_currentStep) {
        case ProfileVerificationStep.detectFace:
          _currentStep = ProfileVerificationStep.turnLeft;
          break;
        case ProfileVerificationStep.turnLeft:
          _currentStep = ProfileVerificationStep.turnRight;
          break;
        case ProfileVerificationStep.turnRight:
          _currentStep = ProfileVerificationStep.smile;
          break;
        case ProfileVerificationStep.smile:
          _currentStep = ProfileVerificationStep.capturing;
          _captureVerifiedPhoto();
          break;
        case ProfileVerificationStep.capturing:
          // Already capturing
          break;
      }
    });
  }

  // ✅ FIX: Properly concatenate all YUV420 planes so ML Kit gets full image data
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _controller?.description;
      InputImageRotation imageRotation = InputImageRotation.rotation0deg;

      if (camera != null) {
        if (camera.lensDirection == CameraLensDirection.front) {
          imageRotation = InputImageRotation.rotation270deg;
        } else {
          imageRotation = InputImageRotation.rotation90deg;
        }
      }

      // ✅ FIX: Concatenate ALL planes (Y + U + V) for proper YUV420 data
      final WriteBuffer allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: InputImageFormat.yuv420,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  Future<void> _captureVerifiedPhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop image stream before taking picture
      await _safeStopImageStream(); // ✅ FIX: use safe stop

      final image = await _controller!.takePicture();

      if (!mounted) return;

      // If reference photo provided, perform face matching
      if (widget.referencePhotoBytes != null) {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Matching faces...'),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          // Read captured image
          final capturedBytes = await XFile(image.path).readAsBytes();

          // Perform face matching
          final matchResult = await FaceMatchingService.instance.compareFaces(
            widget.referencePhotoBytes!,
            capturedBytes,
            threshold: 40.0, // Increased threshold for better matching
          );

          if (!mounted) return;
          Navigator.pop(context); // Close loading

          // Return result with match info
          Navigator.pop(context, {
            'type': 'profile_photo',
            'path': image.path,
            'livenessVerified': true,
            'faceMatched': matchResult.isMatch,
            'matchScore': matchResult.similarity,
          });
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Close loading

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Face matching failed: $e')));
          // Restart image stream if matching failed
          _startFaceDetection();
        }
      } else {
        // No reference photo - just return the captured image
        Navigator.pop(context, {
          'type': 'profile_photo',
          'path': image.path,
          'livenessVerified': true,
          'faceMatched': true, // No reference to match against
          'matchScore': 100.0,
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to capture: $e')));
      // Restart image stream if capture failed
      _startFaceDetection();
    }
  }

  @override
  void dispose() {
    _safeStopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.referencePhotoBytes != null
              ? 'Verify Your Face'
              : 'Verify Profile Photo',
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview
                Positioned.fill(child: CameraPreview(_controller!)),

                // Face detection box overlay
                if (_faceRect != null && _imageSize != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: FaceDetectionPainter(
                        faceRect: _faceRect!,
                        imageSize: _imageSize!,
                        isDetecting: _stepProgress > 0,
                      ),
                    ),
                  ),

                // Face detection overlay (green border when detecting)
                if (_stepProgress > 0 &&
                    _currentStep != ProfileVerificationStep.capturing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green, width: 4),
                      ),
                    ),
                  ),

                // Instructions card
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: _buildInstructionCard(),
                ),

                // Progress indicator
                if (_stepProgress > 0 &&
                    _currentStep != ProfileVerificationStep.capturing)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hold steady... $_stepProgress/$_requiredDetections',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Debug message
                if (_debugMessage.isNotEmpty)
                  Positioned(
                    bottom: 160,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _debugMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                // Cancel button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Camera flip button
                        if (_cameras != null && _cameras!.length > 1)
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _isSwitchingCamera
                                  ? null
                                  : _switchCamera,
                              icon: const Icon(Icons.flip_camera_android),
                              color: Colors.white,
                              iconSize: 28,
                              tooltip: 'Switch camera',
                            ),
                          ),
                        // Skip verification button (for testing)
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Skip liveness and just capture
                              await _safeStopImageStream(); // ✅ FIX: use safe stop
                              _captureVerifiedPhoto();
                            },
                            icon: const Icon(Icons.camera),
                            color: Colors.white,
                            iconSize: 28,
                            tooltip: 'Skip verification & capture',
                          ),
                        ),
                        // Cancel button
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInstructionCard() {
    String instruction;
    IconData icon;
    Color color;

    switch (_currentStep) {
      case ProfileVerificationStep.detectFace:
        instruction = 'Show your face clearly';
        icon = Icons.face;
        color = Colors.blue;
        break;
      case ProfileVerificationStep.turnLeft:
        instruction = 'Turn your head LEFT slowly';
        icon = Icons.arrow_back;
        color = Colors.orange;
        break;
      case ProfileVerificationStep.turnRight:
        instruction = 'Turn your head RIGHT slowly';
        icon = Icons.arrow_forward;
        color = Colors.orange;
        break;
      case ProfileVerificationStep.smile:
        instruction = 'Smile for the camera! 😊';
        icon = Icons.sentiment_satisfied_alt;
        color = Colors.purple;
        break;
      case ProfileVerificationStep.capturing:
        instruction = 'Perfect! Capturing...';
        icon = Icons.camera_alt;
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _stepProgress > 0 ? Colors.green : color,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _stepProgress > 0 ? Icons.check_circle : icon,
            color: _stepProgress > 0 ? Colors.green : color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            instruction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepDot(ProfileVerificationStep.detectFace),
              const SizedBox(width: 8),
              _buildStepDot(ProfileVerificationStep.turnLeft),
              const SizedBox(width: 8),
              _buildStepDot(ProfileVerificationStep.turnRight),
              const SizedBox(width: 8),
              _buildStepDot(ProfileVerificationStep.smile),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(ProfileVerificationStep step) {
    final isCompleted = _currentStep.index > step.index;
    final isCurrent = _currentStep == step;

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isCurrent
            ? Colors.orange
            : Colors.grey,
      ),
    );
  }
}

// Custom painter to draw face detection box
class FaceDetectionPainter extends CustomPainter {
  final Rect faceRect;
  final Size imageSize;
  final bool isDetecting;

  FaceDetectionPainter({
    required this.faceRect,
    required this.imageSize,
    required this.isDetecting,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale to fit image to screen
    final scaleX = size.width / imageSize.height; // Rotated 90 degrees
    final scaleY = size.height / imageSize.width;

    // Transform face rect to screen coordinates (accounting for rotation)
    final left = faceRect.top * scaleX;
    final top = (imageSize.width - faceRect.right) * scaleY;
    final right = faceRect.bottom * scaleX;
    final bottom = (imageSize.width - faceRect.left) * scaleY;

    final screenRect = Rect.fromLTRB(left, top, right, bottom);

    // Draw face detection box
    final paint = Paint()
      ..color = isDetecting ? Colors.green : Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawRect(screenRect, paint);

    // Draw corner markers
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = isDetecting ? Colors.green : Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Top-left corner
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top),
      Offset(screenRect.left + cornerLength, screenRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top),
      Offset(screenRect.left, screenRect.top + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(screenRect.right, screenRect.top),
      Offset(screenRect.right - cornerLength, screenRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(screenRect.right, screenRect.top),
      Offset(screenRect.right, screenRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(screenRect.left, screenRect.bottom),
      Offset(screenRect.left + cornerLength, screenRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(screenRect.left, screenRect.bottom),
      Offset(screenRect.left, screenRect.bottom - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(screenRect.right, screenRect.bottom),
      Offset(screenRect.right - cornerLength, screenRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(screenRect.right, screenRect.bottom),
      Offset(screenRect.right, screenRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(FaceDetectionPainter oldDelegate) {
    return oldDelegate.faceRect != faceRect ||
        oldDelegate.isDetecting != isDetecting;
  }
}
