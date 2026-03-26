import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../services/face_matching_service.dart';
import '../../services/profile_repository.dart';

enum DocumentType {
  rc, // Registration Certificate
  insurance, // Vehicle Insurance
  dl, // Driving License
  aadhaar,
  pan,
}

enum VerificationStep {
  detectFace, // Step 1: Detect face
  turnLeft, // Step 2: Turn head left
  turnRight, // Step 3: Turn head right
  holdDocument, // Step 4: Hold document
  capturing, // Step 5: Capturing photo
}

class DocumentVerificationScreen extends StatefulWidget {
  final DocumentType documentType;
  final Uint8List? referenceDocumentBytes;

  const DocumentVerificationScreen({
    super.key,
    required this.documentType,
    this.referenceDocumentBytes,
  });

  @override
  State<DocumentVerificationScreen> createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends State<DocumentVerificationScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSwitchingCamera = false;
  bool _isStreaming = false;

  // Liveness detection state
  VerificationStep _currentStep = VerificationStep.detectFace;
  int _stepProgress = 0;
  final int _requiredDetections =
      2; // Need 2 consecutive detections per step (reduced for better UX)
  String _debugMessage = ''; // Debug feedback

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
      enableClassification: true, // Enable for smile/eyes detection
      enableLandmarks: true, // Enable for facial landmarks
      enableTracking: true, // Enable for tracking same face
      minFaceSize: 0.10, // Reduced from 0.15 - detect smaller faces
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

      // Use front camera for selfie verification by default
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
      ResolutionPreset.medium,
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
      final currentLens = _controller?.description.lensDirection;
      await _safeStopImageStream();
      await _controller?.dispose();
      _controller = null;

      // Get opposite camera
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

  Future<void> _safeStopImageStream() async {
    try {
      final controller = _controller;
      if (controller != null &&
          controller.value.isInitialized &&
          _isStreaming) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('stopImageStream error (ignored): $e');
    } finally {
      _isStreaming = false;
    }
  }

  void _startFaceDetection() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isStreaming) return;

    _isStreaming = true;
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
        setState(() => _debugMessage = 'Camera conversion failed');
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) {
        _isProcessing = false;
        return;
      }

      // Debug: Show face count
      if (faces.isEmpty) {
        setState(() {
          _stepProgress = 0;
          _debugMessage = 'No face detected (${faces.length} faces)';
        });
        _isProcessing = false;
        return;
      }

      // Debug: Face detected
      setState(() => _debugMessage = 'Face found! Processing...');

      final face = faces.first;
      bool stepCompleted = false;
      String debugInfo = '';

      switch (_currentStep) {
        case VerificationStep.detectFace:
          // Just need to detect a face
          stepCompleted = true;
          debugInfo = 'Face detected ✓ (${faces.length} faces)';
          break;

        case VerificationStep.turnLeft:
          // Check if head is turned left (positive Y rotation)
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          debugInfo =
              'Turn LEFT: ${headEulerAngleY.toStringAsFixed(1)}° (need >8°)';
          stepCompleted = headEulerAngleY > 8; // Even more lenient: 8 degrees
          break;

        case VerificationStep.turnRight:
          // Check if head is turned right (negative Y rotation)
          final headEulerAngleY = face.headEulerAngleY ?? 0;
          debugInfo =
              'Turn RIGHT: ${headEulerAngleY.toStringAsFixed(1)}° (need <-8°)';
          stepCompleted = headEulerAngleY < -8; // Even more lenient: -8 degrees
          break;

        case VerificationStep.holdDocument:
          // Just need face present for document capture
          stepCompleted = true;
          debugInfo = 'Ready to capture ✓';
          break;

        case VerificationStep.capturing:
          // Already capturing, do nothing
          debugInfo = 'Capturing...';
          break;
      }

      if (stepCompleted) {
        setState(() {
          _stepProgress++;
          _debugMessage = '$debugInfo ($_stepProgress/$_requiredDetections)';
        });

        if (_stepProgress >= _requiredDetections) {
          // Step completed, move to next
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
      debugPrint('Face detection error: $e');
      setState(() => _debugMessage = 'Detection error: $e');
    }

    _isProcessing = false;
  }

  void _moveToNextStep() {
    setState(() {
      _stepProgress = 0;

      switch (_currentStep) {
        case VerificationStep.detectFace:
          _currentStep = VerificationStep.turnLeft;
          break;
        case VerificationStep.turnLeft:
          _currentStep = VerificationStep.turnRight;
          break;
        case VerificationStep.turnRight:
          _currentStep = VerificationStep.holdDocument;
          break;
        case VerificationStep.holdDocument:
          _currentStep = VerificationStep.capturing;
          _captureVerifiedPhoto();
          break;
        case VerificationStep.capturing:
          // Already capturing
          break;
      }
    });
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final camera = _controller?.description;
      if (camera == null) return null;

      final nv21 = _yuv420ToNv21(image);

      final rotation = InputImageRotationValue.fromRawValue(
        camera.sensorOrientation,
      );
      if (rotation == null) return null;

      final inputImageData = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      );

      return InputImage.fromBytes(bytes: nv21, metadata: inputImageData);
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final Uint8List nv21 = Uint8List(width * height + (width * height ~/ 2));

    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final int uvHeight = height ~/ 2;
    final int uvWidth = width ~/ 2;
    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final int uBpp = uPlane.bytesPerPixel ?? 1;
        final int vBpp = vPlane.bytesPerPixel ?? 1;
        final int uvIndex = row * uPlane.bytesPerRow + col * uBpp;
        final int vuIndex = row * vPlane.bytesPerRow + col * vBpp;
        nv21[offset++] = vPlane.bytes[vuIndex];
        nv21[offset++] = uPlane.bytes[uvIndex];
      }
    }

    return nv21;
  }

  Future<void> _captureVerifiedPhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Stop image stream before taking picture
      await _safeStopImageStream();

      final image = await _controller!.takePicture();
      final imageBytes = await XFile(image.path).readAsBytes();

      if (!mounted) return;

      // Show preview dialog with the captured document
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('${_getDocumentName()} Captured'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  width: 300,
                  height: 400,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Is the document clear and readable?',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Retake'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Use This Photo'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        // User wants to retake - restart verification
        if (!mounted) return;
        setState(() {
          _currentStep = VerificationStep.detectFace;
          _stepProgress = 0;
        });
        _startFaceDetection();
        return;
      }

      // Perform face matching
      bool faceMatched = false;
      double matchScore = 0.0;

      // If reference document provided, match with it; otherwise match with profile photo
      final referenceBytes = widget.referenceDocumentBytes;

      if (referenceBytes != null) {
        if (!mounted) return;

        // Show matching dialog
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
                    Text('Matching face with document...'),
                  ],
                ),
              ),
            ),
          ),
        );

        try {
          // Compare faces
          final matchResult = await FaceMatchingService.instance.compareFaces(
            referenceBytes,
            imageBytes,
            threshold: 25.0,
          );

          if (!mounted) return;
          Navigator.pop(context); // Close loading dialog

          faceMatched = matchResult.isMatch;
          matchScore = matchResult.similarity;

          if (!faceMatched) {
            // Show mismatch dialog
            final retry = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Face Mismatch'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Face does not match the document photo.\n\n'
                      'Match score: ${matchScore.toStringAsFixed(1)}%\n'
                      'Required: 25%',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );

            if (retry == true) {
              // Restart verification
              setState(() {
                _currentStep = VerificationStep.detectFace;
                _stepProgress = 0;
              });
              _startFaceDetection();
              return;
            } else {
              if (!mounted) return;
              Navigator.pop(context);
              return;
            }
          }
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Close loading dialog
          debugPrint('Face matching error: $e');
          // Continue without face matching on error
        }
      } else {
        // No reference document - match with profile photo (old behavior)
        final profilePhoto = ProfileRepository.instance.profile.value.avatarUrl;

        if (profilePhoto != null && profilePhoto.isNotEmpty) {
          if (!mounted) return;

          // Show matching dialog
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
                      Text('Matching face with profile...'),
                    ],
                  ),
                ),
              ),
            ),
          );

          try {
            // Extract profile photo bytes
            Uint8List profileBytes;
            if (profilePhoto.startsWith('http')) {
              // URL - would need to download
              profileBytes = imageBytes; // Fallback for now
            } else {
              // Base64
              final base64String = profilePhoto.contains(',')
                  ? profilePhoto.split(',').last
                  : profilePhoto;
              profileBytes = base64Decode(base64String);
            }

            // Compare faces
            final matchResult = await FaceMatchingService.instance.compareFaces(
              profileBytes,
              imageBytes,
              threshold: 25.0,
            );

            if (!mounted) return;
            Navigator.pop(context); // Close loading dialog

            faceMatched = matchResult.isMatch;
            matchScore = matchResult.similarity;

            if (!faceMatched) {
              // Show mismatch dialog
              final retry = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Face Mismatch'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Face does not match your profile photo.\n\n'
                        'Match score: ${matchScore.toStringAsFixed(1)}%\n'
                        'Required: 25%',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );

              if (retry == true) {
                // Restart verification
                setState(() {
                  _currentStep = VerificationStep.detectFace;
                  _stepProgress = 0;
                });
                _startFaceDetection();
                return;
              } else {
                if (!mounted) return;
                Navigator.pop(context);
                return;
              }
            }
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context); // Close loading dialog
            debugPrint('Face matching error: $e');
            // Continue without face matching on error
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, {
        'type': 'document',
        'path': image.path,
        'documentType': widget.documentType.name,
        'faceVerified': true,
        'faceMatched': faceMatched,
        'matchScore': matchScore,
      });
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

  String _getDocumentName() {
    switch (widget.documentType) {
      case DocumentType.rc:
        return 'RC Book';
      case DocumentType.insurance:
        return 'Insurance Certificate';
      case DocumentType.dl:
        return 'Driving License';
      case DocumentType.aadhaar:
        return 'National ID';
      case DocumentType.pan:
        return 'Tax ID';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Verify ${_getDocumentName()}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview
                Positioned.fill(child: CameraPreview(_controller!)),

                // Face detection overlay
                if (_stepProgress > 0 &&
                    _currentStep != VerificationStep.capturing)
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
                    _currentStep != VerificationStep.capturing)
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
                              await _controller?.stopImageStream();
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
    String subInstruction = '';
    IconData icon;
    Color color;

    switch (_currentStep) {
      case VerificationStep.detectFace:
        instruction = 'Show your face clearly';
        subInstruction = 'Position your face in the center';
        icon = Icons.face;
        color = Colors.blue;
        break;
      case VerificationStep.turnLeft:
        instruction = 'Turn your head LEFT slowly';
        subInstruction = 'Look to your left side';
        icon = Icons.arrow_back;
        color = Colors.orange;
        break;
      case VerificationStep.turnRight:
        instruction = 'Turn your head RIGHT slowly';
        subInstruction = 'Look to your right side';
        icon = Icons.arrow_forward;
        color = Colors.orange;
        break;
      case VerificationStep.holdDocument:
        instruction = 'Hold your ${_getDocumentName()} next to your face';
        subInstruction = 'Show both your face and the document clearly in camera';
        icon = Icons.description;
        color = Colors.purple;
        break;
      case VerificationStep.capturing:
        instruction = 'Capturing... Please wait';
        subInstruction = 'Hold steady';
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
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            instruction,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (subInstruction.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subInstruction,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 12),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepDot(VerificationStep.detectFace),
              const SizedBox(width: 8),
              _buildStepDot(VerificationStep.turnLeft),
              const SizedBox(width: 8),
              _buildStepDot(VerificationStep.turnRight),
              const SizedBox(width: 8),
              _buildStepDot(VerificationStep.holdDocument),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(VerificationStep step) {
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
