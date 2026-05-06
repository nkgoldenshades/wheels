import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_media.dart';
import '../models/booking.dart';
import '../services/auth_repository.dart';

/// Step-by-step trip media upload widget.
///
/// Flow:
/// 1. Booking starts → "Start" section unlocked, upload photos/video
/// 2. Click "Submit Start" → start locked, "End" section unlocked
/// 3. Trip ends → upload end photos/video
/// 4. Click "Submit End" → both phases complete
class TripMediaWidget extends StatefulWidget {
  final Booking booking;
  final bool isProvider;
  final Future<void> Function(TripMedia updated) onUpdated;

  const TripMediaWidget({
    super.key,
    required this.booking,
    required this.isProvider,
    required this.onUpdated,
  });

  @override
  State<TripMediaWidget> createState() => _TripMediaWidgetState();
}

class _TripMediaWidgetState extends State<TripMediaWidget> {
  late TripMedia _media;
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _media = widget.booking.tripMedia;
  }

  @override
  void didUpdateWidget(TripMediaWidget old) {
    super.didUpdateWidget(old);
    if (old.booking.tripMedia != widget.booking.tripMedia) {
      setState(() => _media = widget.booking.tripMedia);
    }
  }

  String get _myParty => widget.isProvider ? 'provider' : 'customer';

  /// Whether the current user has submitted their start media
  bool get _startSubmitted {
    final party = widget.isProvider ? _media.start.provider : _media.start.customer;
    return party.uploadedAt != null;
  }

  /// Whether the current user has submitted their end media
  bool get _endSubmitted {
    final party = widget.isProvider ? _media.end.provider : _media.end.customer;
    return party.uploadedAt != null;
  }

  // ── Upload helpers ────────────────────────────────────────────────────────

  Future<String?> _uploadFile(XFile file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      final supabase = Supabase.instance.client;
      await supabase.storage.from('trip_media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: file.mimeType ?? 'application/octet-stream',
              upsert: true,
            ),
          );
      return supabase.storage.from('trip_media').getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return null;
    }
  }

  String _storagePath(String phase, String filename) {
    final bookingId = widget.booking.id;
    final userId = AuthRepository.instance.currentUser?.id ?? 'unknown';
    // Path: {bookingId}/{userId}/{phase}/{filename}
    // [1]=bookingId, [2]=userId — matches RLS policy
    return '$bookingId/$userId/$phase/$filename';
  }

  Future<void> _pickImages(String phase) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    setState(() { _uploading = true; _uploadError = null; });

    try {
      final urls = <String>[];
      for (final file in picked) {
        final ext = file.name.split('.').last;
        final url = await _uploadFile(file, _storagePath(phase, '${DateTime.now().millisecondsSinceEpoch}.$ext'));
        if (url != null) urls.add(url);
      }
      if (urls.isEmpty) { setState(() => _uploadError = 'Upload failed.'); return; }

      final updated = _addImages(_media, phase, urls);
      await widget.onUpdated(updated);
      setState(() => _media = updated);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickVideo(String phase) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 30));
    if (file == null) return;

    setState(() { _uploading = true; _uploadError = null; });

    try {
      final ext = file.name.split('.').last;
      final url = await _uploadFile(file, _storagePath(phase, 'video_${DateTime.now().millisecondsSinceEpoch}.$ext'));
      if (url == null) { setState(() => _uploadError = 'Video upload failed.'); return; }

      final updated = _setVideo(_media, phase, url);
      await widget.onUpdated(updated);
      setState(() => _media = updated);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeImage(String phase, int index) async {
    final party = _getParty(_media, phase);
    final newImages = List<String>.from(party.images)..removeAt(index);
    final updated = _setParty(_media, phase, party.copyWith(images: newImages));
    await widget.onUpdated(updated);
    setState(() => _media = updated);
  }

  /// Submit a phase — sets uploadedAt to lock it
  Future<void> _submit(String phase) async {
    final party = _getParty(_media, phase);
    if (!party.hasMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one photo before submitting.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit ${phase == 'start' ? 'Start' : 'End'} Media'),
        content: Text('Once submitted, you cannot edit your ${phase == 'start' ? 'start' : 'end'} photos. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;

    final updated = _setParty(_media, phase, party.copyWith(uploadedAt: DateTime.now()));
    await widget.onUpdated(updated);
    setState(() => _media = updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${phase == 'start' ? 'Start' : 'End'} media submitted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Immutable helpers ─────────────────────────────────────────────────────

  TripMediaParty _getParty(TripMedia m, String phase) {
    final ph = phase == 'start' ? m.start : m.end;
    return _myParty == 'provider' ? ph.provider : ph.customer;
  }

  TripMedia _setParty(TripMedia m, String phase, TripMediaParty p) {
    if (phase == 'start') {
      return m.copyWith(start: _myParty == 'provider'
          ? m.start.copyWith(provider: p)
          : m.start.copyWith(customer: p));
    } else {
      return m.copyWith(end: _myParty == 'provider'
          ? m.end.copyWith(provider: p)
          : m.end.copyWith(customer: p));
    }
  }

  TripMedia _addImages(TripMedia m, String phase, List<String> urls) {
    final p = _getParty(m, phase);
    return _setParty(m, phase, p.copyWith(images: [...p.images, ...urls]));
  }

  TripMedia _setVideo(TripMedia m, String phase, String url) {
    final p = _getParty(m, phase);
    return _setParty(m, phase, p.copyWith(videoUrl: url));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 20),
            const SizedBox(width: 8),
            const Text('Trip Media', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_uploading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 4),
          Text(_uploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 12),

        // ── START phase ───────────────────────────────────────────────────
        _PhaseCard(
          phase: 'start',
          label: 'Start of Trip',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          myParty: _getParty(_media, 'start'),
          otherParty: _myParty == 'provider' ? _media.start.customer : _media.start.provider,
          otherLabel: _myParty == 'provider' ? 'Customer' : 'Provider',
          isSubmitted: _startSubmitted,
          uploading: _uploading,
          onPickImages: () => _pickImages('start'),
          onPickVideo: () => _pickVideo('start'),
          onRemoveImage: (i) => _removeImage('start', i),
          onSubmit: () => _submit('start'),
        ),

        const SizedBox(height: 16),

        // ── END phase — only unlocked after start is submitted ────────────
        if (_startSubmitted)
          _PhaseCard(
            phase: 'end',
            label: 'End of Trip',
            icon: Icons.stop_circle_outlined,
            color: Colors.orange,
            myParty: _getParty(_media, 'end'),
            otherParty: _myParty == 'provider' ? _media.end.customer : _media.end.provider,
            otherLabel: _myParty == 'provider' ? 'Customer' : 'Provider',
            isSubmitted: _endSubmitted,
            uploading: _uploading,
            onPickImages: () => _pickImages('end'),
            onPickVideo: () => _pickVideo('end'),
            onRemoveImage: (i) => _removeImage('end', i),
            onSubmit: () => _submit('end'),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Text(
                  'End of Trip — unlocks after Start is submitted',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Phase card ────────────────────────────────────────────────────────────

class _PhaseCard extends StatelessWidget {
  final String phase;
  final String label;
  final IconData icon;
  final Color color;
  final TripMediaParty myParty;
  final TripMediaParty otherParty;
  final String otherLabel;
  final bool isSubmitted;
  final bool uploading;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final void Function(int) onRemoveImage;
  final VoidCallback onSubmit;

  const _PhaseCard({
    required this.phase,
    required this.label,
    required this.icon,
    required this.color,
    required this.myParty,
    required this.otherParty,
    required this.otherLabel,
    required this.isSubmitted,
    required this.uploading,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                const Spacer(),
                if (isSubmitted)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('Submitted', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                    ],
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // My uploads
                Text('Your Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 8),

                if (myParty.images.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: myParty.images.length + (isSubmitted ? 0 : 1),
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (!isSubmitted && i == myParty.images.length) {
                          return _AddBtn(onTap: uploading ? null : onPickImages);
                        }
                        return _Thumb(
                          url: myParty.images[i],
                          canRemove: !isSubmitted,
                          onRemove: () => onRemoveImage(i),
                        );
                      },
                    ),
                  ),
                ] else if (!isSubmitted) ...[
                  _AddBtn(onTap: uploading ? null : onPickImages),
                ] else ...[
                  Text('No photos uploaded', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],

                const SizedBox(height: 8),

                // Video
                if (myParty.videoUrl != null)
                  Row(
                    children: [
                      const Icon(Icons.videocam, size: 16, color: Colors.blue),
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Video uploaded', style: TextStyle(fontSize: 12, color: Colors.blue))),
                    ],
                  )
                else if (!isSubmitted)
                  OutlinedButton.icon(
                    onPressed: uploading ? null : onPickVideo,
                    icon: const Icon(Icons.videocam_outlined, size: 16),
                    label: const Text('Add Video (max 30s)', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // Submit button
                if (!isSubmitted) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: uploading ? null : onSubmit,
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('Submit ${phase == 'start' ? 'Start' : 'End'} Media'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],

                // Other party's uploads (read-only)
                if (otherParty.hasMedia) ...[
                  const Divider(height: 20),
                  Text('$otherLabel Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  if (otherParty.images.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: otherParty.images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _Thumb(url: otherParty.images[i], canRemove: false, onRemove: () {}),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thumbnail ─────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final String url;
  final bool canRemove;
  final VoidCallback onRemove;

  const _Thumb({required this.url, required this.canRemove, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
              Positioned(top: 8, right: 8, child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              )),
            ],
          ),
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey)),
            ),
          ),
          if (canRemove)
            Positioned(top: 2, right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add button ────────────────────────────────────────────────────────────

class _AddBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddBtn({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: onTap != null ? Colors.blue : Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: onTap != null ? Colors.blue : Colors.grey[400], size: 24),
            const SizedBox(height: 4),
            Text('Photos', style: TextStyle(fontSize: 10, color: onTap != null ? Colors.blue : Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}


