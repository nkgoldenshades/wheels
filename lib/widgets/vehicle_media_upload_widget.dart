import 'package:flutter/material.dart';
import '../services/vehicle_media_service.dart';
import '../services/image_content_filter_service.dart';

class VehicleMediaUploadWidget extends StatefulWidget {
  final String vehicleId;
  final List<VehicleMediaItem> initialImages;
  final VehicleMediaItem? initialVideo;
  final Function(List<VehicleMediaItem>) onImagesChanged;
  final Function(VehicleMediaItem?) onVideoChanged;

  const VehicleMediaUploadWidget({
    super.key,
    required this.vehicleId,
    required this.initialImages,
    required this.initialVideo,
    required this.onImagesChanged,
    required this.onVideoChanged,
  });

  @override
  State<VehicleMediaUploadWidget> createState() =>
      _VehicleMediaUploadWidgetState();
}

class _VehicleMediaUploadWidgetState extends State<VehicleMediaUploadWidget> {
  late List<VehicleMediaItem> _images;
  VehicleMediaItem? _video;
  UploadMethod _imageUploadMethod = UploadMethod.upload;
  UploadMethod _videoUploadMethod = UploadMethod.upload;
  bool _uploading = false;

  final _imageUrlController = TextEditingController();
  final _videoUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
    _video = widget.initialVideo;
  }

  @override
  void dispose() {
    _imageUrlController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      VehicleMediaItem? newImage;

      if (_imageUploadMethod == UploadMethod.upload) {
        // Upload from device
        final file = await VehicleMediaService.instance.pickImage();
        if (file != null) {
          // Validate image content (check for phone numbers, emails, etc.)
          final filterError = await ImageContentFilterService.instance
              .validateImage(file);

          if (filterError != null) {
            _showError(filterError);
            setState(() => _uploading = false);
            return;
          }

          newImage = await VehicleMediaService.instance.uploadImage(
            vehicleId: widget.vehicleId,
            imageFile: file,
          );
        }
      } else {
        // External URL
        final url = _imageUrlController.text.trim();
        if (url.isNotEmpty &&
            VehicleMediaService.instance.isValidImageUrl(url)) {
          newImage = VehicleMediaService.instance.createExternalMedia(url);
          _imageUrlController.clear();
        } else {
          _showError('Please enter a valid image URL');
        }
      }

      if (newImage != null) {
        setState(() {
          _images.add(newImage!);
        });
        widget.onImagesChanged(_images);
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _addVideo() async {
    if (_uploading) return;

    setState(() => _uploading = true);

    try {
      VehicleMediaItem? newVideo;

      if (_videoUploadMethod == UploadMethod.upload) {
        // Upload from device
        final file = await VehicleMediaService.instance.pickVideo();
        if (file != null) {
          // Validate video (check for phone numbers, emails, etc. in audio/subtitle text)
          final filterError = await ImageContentFilterService.instance
              .validateImage(file);

          if (filterError != null) {
            _showError(filterError);
            setState(() => _uploading = false);
            return;
          }

          newVideo = await VehicleMediaService.instance.uploadVideo(
            vehicleId: widget.vehicleId,
            videoFile: file,
          );
        }
      } else {
        // External URL
        final url = _videoUrlController.text.trim();
        if (url.isNotEmpty &&
            VehicleMediaService.instance.isValidVideoUrl(url)) {
          newVideo = VehicleMediaService.instance.createExternalMedia(url);
          _videoUrlController.clear();
        } else {
          _showError('Please enter a valid video URL');
        }
      }

      if (newVideo != null) {
        setState(() {
          _video = newVideo;
        });
        widget.onVideoChanged(_video);
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  void _removeImage(int index) {
    final image = _images[index];

    // Delete from storage if uploaded
    if (image.source == MediaSource.uploaded && image.storageId != null) {
      VehicleMediaService.instance.deleteUploadedMedia(image.storageId!);
    }

    setState(() {
      _images.removeAt(index);
    });
    widget.onImagesChanged(_images);
  }

  void _removeVideo() {
    if (_video?.source == MediaSource.uploaded && _video?.storageId != null) {
      VehicleMediaService.instance.deleteUploadedMedia(_video!.storageId!);
    }

    setState(() {
      _video = null;
    });
    widget.onVideoChanged(null);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Images Section
        const Text(
          '📷 Vehicle Images',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Image upload method selector
        SegmentedButton<UploadMethod>(
          segments: const [
            ButtonSegment(
              value: UploadMethod.upload,
              label: Text('Upload'),
              icon: Icon(Icons.upload, size: 16),
            ),
            ButtonSegment(
              value: UploadMethod.url,
              label: Text('URL'),
              icon: Icon(Icons.link, size: 16),
            ),
          ],
          selected: {_imageUploadMethod},
          onSelectionChanged: (Set<UploadMethod> selection) {
            setState(() => _imageUploadMethod = selection.first);
          },
        ),

        const SizedBox(height: 12),

        // Image input section
        if (_imageUploadMethod == UploadMethod.upload)
          _buildImageUploadSection()
        else
          _buildImageUrlSection(),

        const SizedBox(height: 16),

        // Images grid
        if (_images.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final image = _images[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          image.url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, a, b) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      // Source indicator
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: image.source == MediaSource.uploaded
                                ? Colors.green
                                : Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            image.source == MediaSource.uploaded ? 'UP' : 'URL',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Remove button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Video Section
        const Text(
          '🎥 Vehicle Video',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        // Video upload method selector
        SegmentedButton<UploadMethod>(
          segments: const [
            ButtonSegment(
              value: UploadMethod.upload,
              label: Text('Upload'),
              icon: Icon(Icons.upload, size: 16),
            ),
            ButtonSegment(
              value: UploadMethod.url,
              label: Text('URL'),
              icon: Icon(Icons.link, size: 16),
            ),
          ],
          selected: {_videoUploadMethod},
          onSelectionChanged: (Set<UploadMethod> selection) {
            setState(() => _videoUploadMethod = selection.first);
          },
        ),

        const SizedBox(height: 12),

        // Video input section
        if (_videoUploadMethod == UploadMethod.upload)
          _buildVideoUploadSection()
        else
          _buildVideoUrlSection(),

        // Current video display
        if (_video != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video added',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _video!.source == MediaSource.uploaded
                            ? 'Uploaded'
                            : 'External URL',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _removeVideo,
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      children: [
        Text(
          '📱 Upload from device (compressed)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _uploading ? null : _addImage,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera),
          label: Text(_uploading ? 'Uploading...' : 'Add Image'),
        ),
      ],
    );
  }

  Widget _buildImageUrlSection() {
    return Column(
      children: [
        Text(
          '🔗 External URL (high quality)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _uploading ? null : _addImage,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoUploadSection() {
    return Column(
      children: [
        Text(
          '📱 Upload from device (max 5 min)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _uploading || _video != null ? null : _addVideo,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.videocam),
          label: Text(_uploading ? 'Uploading...' : 'Add Video'),
        ),
      ],
    );
  }

  Widget _buildVideoUrlSection() {
    return Column(
      children: [
        Text(
          '🔗 External video URL',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/video.mp4',
                  prefixIcon: Icon(Icons.link),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _uploading || _video != null ? null : _addVideo,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}
