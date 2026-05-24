import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

enum CaptureMode {
  photo, // Single photo capture
  video, // Video recording for verification
}

class LiveCameraScreen extends StatefulWidget {
  final CaptureMode mode;
  final String title;
  final String instruction;
  final int? maxVideoDuration; // seconds

  const LiveCameraScreen({
    super.key,
    required this.mode,
    required this.title,
    required this.instruction,
    this.maxVideoDuration = 10,
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickOnWeb());
      return;
    }
    _initializeCamera();
  }

  Future<void> _pickOnWeb() async {
    try {
      final picker = ImagePicker();
      final picked = widget.mode == CaptureMode.video
          ? await picker.pickVideo(source: ImageSource.camera)
          : await picker.pickImage(
              source: ImageSource.camera,
              imageQuality: 90,
            );
      if (picked == null) {
        if (mounted) Navigator.pop(context);
        return;
      }
      if (!mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found')),
        );
        return;
      }

      // Use back camera for photos, front camera for selfie verification
      final camera = widget.mode == CaptureMode.video
          ? _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras!.first,
            )
          : _cameras!.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras!.first,
            );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: widget.mode == CaptureMode.video,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (!mounted) return;
      
      if (!mounted) return;
      String errorMessage = 'Camera error: $e';
      if (e.toString().contains('RECORD_AUDIO') || e.toString().contains('audio')) {
        errorMessage = 'Audio permission required for video recording. Please grant microphone permission.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.pop(context, {'type': 'photo', 'path': image.path});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });

      // Auto-stop after max duration
      Future.delayed(Duration(seconds: widget.maxVideoDuration!), () {
        if (_isRecording) _stopRecording();
      });

      // Update timer
      _updateTimer();
    } catch (e) {
      if (!mounted) return;
      
      if (!mounted) return;
      String errorMessage = 'Failed to start recording: $e';
      if (e.toString().contains('RECORD_AUDIO') || e.toString().contains('audio')) {
        errorMessage = 'Audio permission required for video recording. Please grant microphone permission.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  void _updateTimer() {
    if (!_isRecording) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;
      setState(() => _recordingSeconds++);
      _updateTimer();
    });
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_isRecording) return;

    try {
      final video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      if (!mounted) return;
      Navigator.pop(context, {'type': 'video', 'path': video.path});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Camera preview
                Positioned.fill(
                  child: CameraPreview(_controller!),
                ),

                // Instruction overlay
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.instruction,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // Recording indicator
                if (_isRecording)
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.fiber_manual_record,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recording ${_recordingSeconds}s / ${widget.maxVideoDuration}s',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Capture button
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: widget.mode == CaptureMode.photo
                        ? _buildPhotoButton()
                        : _buildVideoButton(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPhotoButton() {
    return GestureDetector(
      onTap: _capturePhoto,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: const Icon(Icons.camera_alt, size: 32, color: Colors.black),
      ),
    );
  }

  Widget _buildVideoButton() {
    return GestureDetector(
      onTap: _isRecording ? _stopRecording : _startRecording,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording ? Colors.red : Colors.white,
          border: Border.all(
            color: _isRecording ? Colors.red : Colors.white,
            width: 4,
          ),
        ),
        child: Icon(
          _isRecording ? Icons.stop : Icons.videocam,
          size: 32,
          color: _isRecording ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}



