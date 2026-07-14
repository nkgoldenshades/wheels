import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../services/review_repository.dart';
import '../services/auth_repository.dart';

class ReviewDialog extends StatefulWidget {
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final String revieweeName;
  final ReviewType type;

  const ReviewDialog({
    super.key,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
    required this.type,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewMediaItem {
  final String url;        // public URL after upload
  final bool isVideo;
  _ReviewMediaItem({required this.url, required this.isVideo});
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isUploading = false;
  String? _uploadError;

  final List<_ReviewMediaItem> _media = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Upload to Supabase Storage ──────────────────────────────────────────

  Future<String?> _uploadToStorage(XFile file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      final supabase = Supabase.instance.client;
      await supabase.storage.from('review_media').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: file.mimeType ?? 'application/octet-stream',
          upsert: true,
        ),
      );
      return supabase.storage.from('review_media').getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ Review media upload failed: $e');
      return null;
    }
  }

  String _storagePath(String filename) {
    final userId = AuthRepository.instance.currentUser?.id ?? 'unknown';
    final bookingId = widget.bookingId;
    return 'reviews/$bookingId/$userId/${DateTime.now().millisecondsSinceEpoch}_$filename';
  }

  // ── Pick photo ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_media.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max 5 photos/videos allowed')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked == null) return;

    setState(() { _isUploading = true; _uploadError = null; });
    try {
      final ext = picked.name.split('.').last;
      final url = await _uploadToStorage(picked, _storagePath('photo.$ext'));
      if (url != null) {
        setState(() => _media.add(_ReviewMediaItem(url: url, isVideo: false)));
      } else {
        setState(() => _uploadError = 'Photo upload failed. Check storage permissions.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Pick video ──────────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    if (_media.any((m) => m.isVideo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only 1 video allowed per review')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (picked == null) return;

    setState(() { _isUploading = true; _uploadError = null; });
    try {
      final ext = picked.name.split('.').last;
      final url = await _uploadToStorage(picked, _storagePath('video.$ext'));
      if (url != null) {
        setState(() => _media.add(_ReviewMediaItem(url: url, isVideo: true)));
      } else {
        setState(() => _uploadError = 'Video upload failed. Check storage permissions.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removeMedia(int index) => setState(() => _media.removeAt(index));

  // ── Submit ──────────────────────────────────────────────────────────────

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      await ReviewRepository.instance.addReview(
        bookingId: widget.bookingId,
        reviewerId: widget.reviewerId,
        revieweeId: widget.revieweeId,
        type: widget.type,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        mediaUrls: _media.map((m) => m.url).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final photoCount = _media.where((m) => !m.isVideo).length;
    final hasVideo = _media.any((m) => m.isVideo);

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Review ${widget.revieweeName}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stars
            const Text('How was your experience?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final v = i + 1.0;
                return GestureDetector(
                  onTap: () => setState(() => _rating = v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      v <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              _getRatingText(_rating),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                hintText: _getCommentHint(_rating),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Media section header
            Row(
              children: [
                const Icon(Icons.perm_media_outlined,
                    size: 18, color: Colors.blue),
                const SizedBox(width: 6),
                const Text('Photos & Video',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 4),
                Text('($photoCount/5 photos · ${hasVideo ? '1' : '0'}/1 video)',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 4),
            Text('Max 5 photos + 1 video (30s)',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 10),

            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_uploadError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            // Media thumbnails
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Existing media
                  ..._media.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.isVideo
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.videocam,
                                            color: Colors.blue, size: 32),
                                        Text('Video',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[700])),
                                      ],
                                    )
                                  : Image.network(
                                      item.url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, e, s) =>
                                          const Icon(Icons.broken_image),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _removeMedia(i),
                              child: Container(
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close,
                                    size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add photo button
                  if (photoCount < 5)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickPhoto,
                        child: _addBtn(
                          icon: Icons.add_photo_alternate_outlined,
                          label: 'Photo',
                          color: Colors.blue,
                          loading: _isUploading,
                        ),
                      ),
                    ),

                  // Add video button
                  if (!hasVideo)
                    GestureDetector(
                      onTap: _isUploading ? null : _pickVideo,
                      child: _addBtn(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        color: Colors.orange,
                        loading: _isUploading,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit
            FilledButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool loading,
  }) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: loading
          ? const Center(
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Good';
    if (rating >= 3) return 'Average';
    if (rating >= 2) return 'Below Average';
    return 'Poor';
  }

  String _getCommentHint(double rating) {
    if (rating >= 5) return 'What made it excellent?';
    if (rating >= 4) return 'What went well?';
    if (rating >= 3) return 'What could have been better?';
    if (rating >= 2) return 'What went wrong?';
    return 'What was the issue?';
  }
}
