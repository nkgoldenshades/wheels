import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip_media.dart';
import '../models/booking.dart';
import '../services/auth_repository.dart';

/// Full trip-media panel shown inside booking details.
///
/// Shows two sections — Start and End.
/// Each section has a Provider slot and a Customer slot.
/// The current user can only upload to their own slot.
/// The other party's slot is read-only.
///
/// Usage:
/// ```dart
/// TripMediaWidget(
///   booking: booking,
///   isProvider: true,   // false for customer
///   onUpdated: (newMedia) { /* persist to Supabase */ },
/// )
/// ```
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

  // ── Upload helpers ────────────────────────────────────────────────────────

  Future<String?> _uploadFile(XFile file, String path) async {
    try {
      final bytes = await file.readAsBytes();
      final supabase = Supabase.instance.client;
      await supabase.storage.from('trip-media').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: file.mimeType ?? 'application/octet-stream',
              upsert: true,
            ),
          );
      return supabase.storage.from('trip-media').getPublicUrl(path);
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return null;
    }
  }

  String _storagePath(String phase, String party, String filename) {
    final bookingId = widget.booking.id;
    final userId = AuthRepository.instance.currentUser?.id ?? 'unknown';
    return 'bookings/$bookingId/$phase/$party/$userId/$filename';
  }

  Future<void> _pickAndUploadImages(String phase, String party) async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    try {
      final urls = <String>[];
      for (final file in picked) {
        final ext = file.name.split('.').last;
        final path = _storagePath(
            phase, party, '${DateTime.now().millisecondsSinceEpoch}.$ext');
        final url = await _uploadFile(file, path);
        if (url != null) urls.add(url);
      }

      if (urls.isEmpty) {
        setState(() => _uploadError = 'Upload failed. Try again.');
        return;
      }

      final updated = _applyImages(_media, phase, party, urls);
      await widget.onUpdated(updated);
      setState(() => _media = updated);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUploadVideo(String phase, String party) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    setState(() {
      _uploading = true;
      _uploadError = null;
    });

    try {
      final ext = file.name.split('.').last;
      final path = _storagePath(
          phase, party, 'video_${DateTime.now().millisecondsSinceEpoch}.$ext');
      final url = await _uploadFile(file, path);

      if (url == null) {
        setState(() => _uploadError = 'Video upload failed. Try again.');
        return;
      }

      final updated = _applyVideo(_media, phase, party, url);
      await widget.onUpdated(updated);
      setState(() => _media = updated);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _removeImage(String phase, String party, int index) async {
    final current = _partyOf(_media, phase, party);
    final newImages = List<String>.from(current.images)..removeAt(index);
    final updated = _applyParty(
      _media,
      phase,
      party,
      current.copyWith(images: newImages),
    );
    await widget.onUpdated(updated);
    setState(() => _media = updated);
  }

  Future<void> _removeVideo(String phase, String party) async {
    final current = _partyOf(_media, phase, party);
    final updated = _applyParty(
      _media,
      phase,
      party,
      current.copyWith(clearVideo: true),
    );
    await widget.onUpdated(updated);
    setState(() => _media = updated);
  }

  // ── Immutable update helpers ──────────────────────────────────────────────

  TripMediaParty _partyOf(TripMedia m, String phase, String party) {
    final ph = phase == 'start' ? m.start : m.end;
    return party == 'provider' ? ph.provider : ph.customer;
  }

  TripMedia _applyParty(
      TripMedia m, String phase, String party, TripMediaParty newParty) {
    if (phase == 'start') {
      return m.copyWith(
        start: party == 'provider'
            ? m.start.copyWith(provider: newParty)
            : m.start.copyWith(customer: newParty),
      );
    } else {
      return m.copyWith(
        end: party == 'provider'
            ? m.end.copyWith(provider: newParty)
            : m.end.copyWith(customer: newParty),
      );
    }
  }

  TripMedia _applyImages(
      TripMedia m, String phase, String party, List<String> newUrls) {
    final current = _partyOf(m, phase, party);
    return _applyParty(
      m,
      phase,
      party,
      current.copyWith(
        images: [...current.images, ...newUrls],
        uploadedAt: DateTime.now(),
      ),
    );
  }

  TripMedia _applyVideo(
      TripMedia m, String phase, String party, String url) {
    final current = _partyOf(m, phase, party);
    return _applyParty(
      m,
      phase,
      party,
      current.copyWith(videoUrl: url, uploadedAt: DateTime.now()),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Trip Media',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (_uploadError != null) ...[
          const SizedBox(height: 4),
          Text(_uploadError!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        const SizedBox(height: 12),

        // START section
        _PhaseSection(
          phase: 'start',
          label: 'Start of Trip',
          icon: Icons.play_circle_outline,
          color: Colors.green,
          providerParty: _media.start.provider,
          customerParty: _media.start.customer,
          isProvider: widget.isProvider,
          uploading: _uploading,
          onPickImages: (party) => _pickAndUploadImages('start', party),
          onPickVideo: (party) => _pickAndUploadVideo('start', party),
          onRemoveImage: (party, i) => _removeImage('start', party, i),
          onRemoveVideo: (party) => _removeVideo('start', party),
        ),

        const SizedBox(height: 16),

        // END section
        _PhaseSection(
          phase: 'end',
          label: 'End of Trip',
          icon: Icons.stop_circle_outlined,
          color: Colors.orange,
          providerParty: _media.end.provider,
          customerParty: _media.end.customer,
          isProvider: widget.isProvider,
          uploading: _uploading,
          onPickImages: (party) => _pickAndUploadImages('end', party),
          onPickVideo: (party) => _pickAndUploadVideo('end', party),
          onRemoveImage: (party, i) => _removeImage('end', party, i),
          onRemoveVideo: (party) => _removeVideo('end', party),
        ),
      ],
    );
  }
}

// ── Phase section (Start / End) ───────────────────────────────────────────

class _PhaseSection extends StatelessWidget {
  final String phase;
  final String label;
  final IconData icon;
  final Color color;
  final TripMediaParty providerParty;
  final TripMediaParty customerParty;
  final bool isProvider;
  final bool uploading;
  final void Function(String party) onPickImages;
  final void Function(String party) onPickVideo;
  final void Function(String party, int index) onRemoveImage;
  final void Function(String party) onRemoveVideo;

  const _PhaseSection({
    required this.phase,
    required this.label,
    required this.icon,
    required this.color,
    required this.providerParty,
    required this.customerParty,
    required this.isProvider,
    required this.uploading,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Provider slot
          _PartySlot(
            partyLabel: 'Provider',
            partyKey: 'provider',
            party: providerParty,
            canEdit: isProvider,
            uploading: uploading,
            onPickImages: () => onPickImages('provider'),
            onPickVideo: () => onPickVideo('provider'),
            onRemoveImage: (i) => onRemoveImage('provider', i),
            onRemoveVideo: () => onRemoveVideo('provider'),
          ),

          const Divider(height: 1),

          // Customer slot
          _PartySlot(
            partyLabel: 'Customer',
            partyKey: 'customer',
            party: customerParty,
            canEdit: !isProvider,
            uploading: uploading,
            onPickImages: () => onPickImages('customer'),
            onPickVideo: () => onPickVideo('customer'),
            onRemoveImage: (i) => onRemoveImage('customer', i),
            onRemoveVideo: () => onRemoveVideo('customer'),
          ),
        ],
      ),
    );
  }
}

// ── Party slot (Provider / Customer) ─────────────────────────────────────

class _PartySlot extends StatelessWidget {
  final String partyLabel;
  final String partyKey;
  final TripMediaParty party;
  final bool canEdit;
  final bool uploading;
  final VoidCallback onPickImages;
  final VoidCallback onPickVideo;
  final void Function(int index) onRemoveImage;
  final VoidCallback onRemoveVideo;

  const _PartySlot({
    required this.partyLabel,
    required this.partyKey,
    required this.party,
    required this.canEdit,
    required this.uploading,
    required this.onPickImages,
    required this.onPickVideo,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedia = party.hasMedia;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Party label + uploaded_at
          Row(
            children: [
              Icon(
                partyKey == 'provider' ? Icons.drive_eta : Icons.person,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                partyLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              if (party.uploadedAt != null)
                Text(
                  _formatTime(party.uploadedAt!),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                )
              else if (!hasMedia)
                Text(
                  canEdit ? 'Not uploaded yet' : 'Pending',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Images grid
          if (party.images.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: party.images.length + (canEdit ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  // Add-more button at end
                  if (canEdit && i == party.images.length) {
                    return _AddImageButton(
                        onTap: uploading ? null : onPickImages);
                  }
                  return _ImageThumb(
                    url: party.images[i],
                    canRemove: canEdit,
                    onRemove: () => onRemoveImage(i),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ] else if (canEdit) ...[
            // Empty state — add images
            _AddImageButton(onTap: uploading ? null : onPickImages),
            const SizedBox(height: 8),
          ] else ...[
            // Read-only empty
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Center(
                child: Text(
                  'No photos uploaded',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Video row
          _VideoRow(
            videoUrl: party.videoUrl,
            canEdit: canEdit,
            uploading: uploading,
            onPickVideo: onPickVideo,
            onRemoveVideo: onRemoveVideo,
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = '${dt.day}/${dt.month}';
    return '$d $h:$m';
  }
}

// ── Image thumbnail ───────────────────────────────────────────────────────

class _ImageThumb extends StatelessWidget {
  final String url;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ImageThumb({
    required this.url,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
          if (canRemove)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullscreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Add image button ──────────────────────────────────────────────────────

class _AddImageButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddImageButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? Colors.blue : Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                color: onTap != null ? Colors.blue : Colors.grey[400],
                size: 24),
            const SizedBox(height: 4),
            Text(
              'Photos',
              style: TextStyle(
                fontSize: 10,
                color: onTap != null ? Colors.blue : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video row ─────────────────────────────────────────────────────────────

class _VideoRow extends StatelessWidget {
  final String? videoUrl;
  final bool canEdit;
  final bool uploading;
  final VoidCallback onPickVideo;
  final VoidCallback onRemoveVideo;

  const _VideoRow({
    required this.videoUrl,
    required this.canEdit,
    required this.uploading,
    required this.onPickVideo,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    if (videoUrl != null) {
      return Row(
        children: [
          const Icon(Icons.videocam, size: 16, color: Colors.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Video uploaded',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500),
            ),
          ),
          // View button
          TextButton.icon(
            onPressed: () => _openVideo(context, videoUrl!),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('View', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (canEdit)
            IconButton(
              onPressed: onRemoveVideo,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: Colors.red,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Remove video',
            ),
        ],
      );
    }

    if (!canEdit) {
      return Row(
        children: [
          const Icon(Icons.videocam_off, size: 16, color: Colors.grey),
          const SizedBox(width: 6),
          Text('No video',
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: uploading ? null : onPickVideo,
      icon: const Icon(Icons.videocam_outlined, size: 16),
      label: const Text('Add Video (max 30s)', style: TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _openVideo(BuildContext context, String url) {
    // Opens URL — on mobile use url_launcher, on web opens in new tab
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Video'),
        content: Text(
          url,
          style: const TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
