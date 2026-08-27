import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/seat_layout_controller.dart';
import '../../models/booking.dart';
import '../../models/seat_layout.dart';
import '../../models/service_type.dart';
import '../../services/booking_repository.dart';
import '../../services/slot_repository.dart';
import '../../services/auth_repository.dart';

class SeatLayoutBuilderScreen extends StatefulWidget {
  final SeatLayoutController controller;
  final String? ownerId;
  final ServiceType serviceType;

  const SeatLayoutBuilderScreen({
    super.key,
    required this.controller,
    this.ownerId,
    this.serviceType = ServiceType.passenger,
  });

  @override
  State<SeatLayoutBuilderScreen> createState() =>
      _SeatLayoutBuilderScreenState();
}

class _SeatLayoutBuilderScreenState extends State<SeatLayoutBuilderScreen> {
  static const double _cellSize = 56;

  // Image picker for seat layout
  final ImagePicker _imagePicker = ImagePicker();

  Set<String> _bookedSeatKeys() {
    final ownerId = widget.ownerId;
    if (ownerId == null || ownerId.trim().isEmpty) return <String>{};

    final slotIds = SlotRepository.instance.allSlots
        .where((e) => e.slot.seatLayoutOwnerId == ownerId)
        .map((e) => e.slot.id)
        .toSet();
    if (slotIds.isEmpty) return <String>{};

    return BookingRepository.instance.bookings.value
        .where(
          (b) =>
              slotIds.contains(b.slotId) &&
              b.seatKey != null &&
              b.status.isActive,
        )
        .map((b) => b.seatKey!)
        .toSet();
  }

  bool _isCellBooked(LayoutCell? cell) {
    if (cell == null) return false;
    if (cell.type != CellType.seat) return false;
    return _bookedSeatKeys().contains(cell.key);
  }

  Future<void> _pickImage() async {
    if (widget.controller.layout.images.length >= 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Maximum 4 images allowed')));
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        if (!mounted) return;

        // Show uploading indicator
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

        final bytes = await File(image.path).readAsBytes();

        // Upload to Supabase Storage
        final supabase = Supabase.instance.client;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final userId = AuthRepository.instance.currentUser?.id ?? 'anonymous';
        final fileName = 'layout_${userId}_$timestamp.jpg';
        final filePath = '$userId/$fileName';

        try {
          await supabase.storage
              .from('layout-images')
              .uploadBinary(filePath, bytes);

          // Get public URL
          final imageUrl = supabase.storage
              .from('layout-images')
              .getPublicUrl(filePath);

          widget.controller.addImage(imageUrl);

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('✅ Image uploaded!')));
          }
        } catch (e) {
          debugPrint('❌ Failed to upload to Supabase Storage: $e');

          // Fallback to base64 (for offline or if storage fails)
          final base64Image = base64Encode(bytes);
          widget.controller.addImage(base64Image);

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Image saved locally (upload failed)'),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  void _removeImage(int index) {
    final imageUrl = widget.controller.layout.images[index];

    // If it's a Supabase Storage URL, delete from storage
    if (imageUrl.contains('supabase.co/storage')) {
      try {
        final supabase = Supabase.instance.client;
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;

        // Extract file path from URL
        // URL format: https://[project].supabase.co/storage/v1/object/public/layout-images/[userId]/[fileName]
        final bucketIndex = pathSegments.indexOf('layout-images');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');

          supabase.storage
              .from('layout-images')
              .remove([filePath])
              .then(
                (_) => debugPrint('✅ Deleted image from storage: $filePath'),
              )
              .catchError((e) => debugPrint('⚠️ Failed to delete image: $e'));
        }
      } catch (e) {
        debugPrint('⚠️ Failed to parse storage URL: $e');
      }
    }

    widget.controller.removeImage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.serviceType == ServiceType.parcel
              ? 'Compartment setup'
              : 'Seating setup',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => _showGridSettings(context),
            icon: const Icon(Icons.settings_applications),
            tooltip: 'Grid Settings',
          ),
          TextButton(
            onPressed: () {
              try {
                widget.controller.validate();
                Navigator.pop(context, widget.controller.layout);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Booking>>(
        // Listen to booking changes to refresh seat availability
        valueListenable: BookingRepository.instance.bookings,
        builder: (context, _, _) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final layout = widget.controller.layout;
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                constrained: true,
                boundaryMargin: const EdgeInsets.all(100),
                panEnabled: true,
                scaleEnabled: true,
                child: SizedBox(
                  width: layout.cols * _cellSize,
                  height: layout.rows * _cellSize,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    addAutomaticKeepAlives: true,
                    addRepaintBoundaries: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: layout.cols,
                      childAspectRatio: 1,
                    ),
                    itemCount: layout.rows * layout.cols,
                    itemBuilder: (context, index) {
                      final row = index ~/ layout.cols;
                      final col = index % layout.cols;

                      final stored = widget.controller.cellAt(row, col);
                      final type = stored?.type ?? CellType.empty;

                      final isSelected =
                          widget.controller.selectedRow == row &&
                          widget.controller.selectedCol == col;

                      return SizedBox(
                        width: _cellSize,
                        height: _cellSize,
                        child: InkWell(
                          onTap: () => _onTapCell(context, row, col),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _bgColor(type),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : (type == CellType.seat
                                            ? ((stored?.gender ??
                                                          SeatGender.any) ==
                                                      SeatGender.male
                                                  ? Colors.blue
                                                  : ((stored?.gender ??
                                                                SeatGender
                                                                    .any) ==
                                                            SeatGender.female
                                                        ? Colors.pink
                                                        : Colors.grey.shade400))
                                            : (type == CellType.empty
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade400)),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: _cellChild(stored),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _bgColor(CellType type) {
    switch (type) {
      case CellType.empty:
        return Colors.transparent;
      case CellType.space:
        return Colors.grey.withValues(alpha: 0.2);
      case CellType.seat:
        return Colors.white;
    }
  }

  Widget _cellChild(LayoutCell? c) {
    if (c == null || c.type == CellType.empty) {
      return const SizedBox.shrink();
    }

    if (c.type == CellType.space) {
      return Center(
        child: Icon(Icons.block, size: 16, color: Colors.grey.shade600),
      );
    }

    final genderLabel = switch (c.gender) {
      SeatGender.male => 'M',
      SeatGender.female => 'F',
      SeatGender.any => '',
    };

    // Parse parcel dimensions if they exist (format: name|L:10|B:20|H:30|W:5|...)
    // IMPORTANT: Only show dimensions if ALL FOUR are present and non-empty (complete compartment)
    String? length, breadth, height, weight;
    String displayName =
        c.seatName ?? 'Seat'; // Get the actual compartment name

    if (c.seatName != null && c.seatName!.contains('|')) {
      final parts = c.seatName!.split('|');
      displayName = parts[0]; // First part is the compartment name
      for (final part in parts.skip(1)) {
        if (part.startsWith('L:')) {
          length = part.substring(2);
        } else if (part.startsWith('B:')) {
          breadth = part.substring(2);
        } else if (part.startsWith('H:')) {
          height = part.substring(2);
        } else if (part.startsWith('W:')) {
          weight = part.substring(2);
        }
      }
    }

    // Check if this is a parcel compartment with COMPLETE dimensions
    // Only show if all 4 dimensions are present AND non-empty
    final hasCompleteParcelDimensions =
        length != null &&
        length.isNotEmpty &&
        breadth != null &&
        breadth.isNotEmpty &&
        height != null &&
        height.isNotEmpty &&
        weight != null &&
        weight.isNotEmpty;

    return Stack(
      children: [
        // Top-left: Compartment name with optional gender
        Positioned(
          top: 2,
          left: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.length > 8
                    ? displayName.substring(0, 8)
                    : displayName,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: c.isLocked ? Colors.grey : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (genderLabel.isNotEmpty)
                Text(
                  genderLabel,
                  style: TextStyle(
                    fontSize: 7,
                    color: c.isLocked ? Colors.grey : Colors.black54,
                  ),
                ),
            ],
          ),
        ),

        // For parcel dimensions: show in vertical stack on left edge (tiny, blue)
        // ONLY if all dimensions are complete
        if (hasCompleteParcelDimensions)
          Positioned(
            bottom: 2,
            left: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'L:$length',
                  style: const TextStyle(fontSize: 5, color: Colors.blue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'B:$breadth',
                  style: const TextStyle(fontSize: 5, color: Colors.blue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'H:$height',
                  style: const TextStyle(fontSize: 5, color: Colors.blue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'W:$weight',
                  style: const TextStyle(fontSize: 5, color: Colors.blue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        // For passenger seats: show price in bottom-right
        else if (!hasCompleteParcelDimensions && c.price != null)
          Positioned(
            bottom: 2,
            right: 2,
            child: Text(
              '₹${c.price}',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: c.isLocked ? Colors.grey : Colors.green.shade700,
              ),
            ),
          ),

        // Top-right: Security Deposit (if exists) - positioned above lock icon
        if (c.securityDeposit != null)
          Positioned(
            top: 2,
            right: 2,
            child: Text(
              'Dep: ₹${c.securityDeposit}',
              style: TextStyle(
                fontSize: 5,
                color: c.isLocked ? Colors.grey : Colors.orange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

        // Top-right corner: Lock icon (if locked) - positioned below deposit label
        if (c.isLocked)
          Positioned(
            top: 9,
            right: 2,
            child: Icon(Icons.lock, size: 10, color: Colors.grey),
          ),

        // Bottom-right: Price for parcels (tiny, only if complete dimensions showing)
        if (hasCompleteParcelDimensions && c.price != null)
          Positioned(
            bottom: 2,
            right: 2,
            child: Text(
              '₹${c.price}',
              style: TextStyle(
                fontSize: 5,
                fontWeight: FontWeight.w600,
                color: c.isLocked ? Colors.grey : Colors.green.shade700,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showGridSettings(BuildContext context) async {
    final curRows = widget.controller.layout.rows;
    final curCols = widget.controller.layout.cols;

    final rowsController = TextEditingController(text: curRows.toString());
    final colsController = TextEditingController(text: curCols.toString());
    final priceController = TextEditingController(
      text: '100',
    ); // Default price for auto-fill

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grid Settings (Matrix)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rowsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Rows',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: colsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Columns',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              final r =
                                  int.tryParse(rowsController.text) ?? curRows;
                              final c =
                                  int.tryParse(colsController.text) ?? curCols;
                              widget.controller.resize(r, c);
                              setModalState(() {});
                            },
                            icon: const Icon(Icons.aspect_ratio),
                            label: const Text('Update Grid Size'),
                          ),
                        ),
                        const Divider(height: 32),
                        const Text(
                          'Auto-Fill Seats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Seat Price',
                                  prefixIcon: Icon(Icons.currency_rupee),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: () {
                                final p =
                                    int.tryParse(priceController.text) ?? 0;
                                widget.controller.fillAllSeats(p);
                                setModalState(() {});
                              },
                              child: const Text('Fill All'),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // Images Section
                        const Text(
                          '📷 Layout Images (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Image Grid
                        if (widget.controller.layout.images.isNotEmpty) ...[
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                            itemCount: widget.controller.layout.images.length,
                            itemBuilder: (context, index) {
                              final imageData =
                                  widget.controller.layout.images[index];
                              final isUrl = imageData.startsWith('http');

                              return Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: isUrl
                                          ? Image.network(
                                              imageData,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value:
                                                        loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        size: 48,
                                                        color: Colors.grey,
                                                      ),
                                                    );
                                                  },
                                            )
                                          : Image.memory(
                                              base64Decode(imageData),
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        _removeImage(index);
                                        setModalState(() {});
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Add Image Button
                        if (widget.controller.layout.images.length < 4)
                          GestureDetector(
                            onTap: () async {
                              await _pickImage();
                              setModalState(() {});
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 32,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add Layout Images (${widget.controller.layout.images.length}/4)',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to select from gallery',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ), // Column
                  ), // SingleChildScrollView
                ), // Padding
              ), // SafeArea
            ); // ConstrainedBox
          },
        );
      },
    );
  }

  Future<void> _onTapCell(BuildContext context, int row, int col) async {
    widget.controller.select(row, col);

    final cell = widget.controller.cellAt(row, col);
    final type = cell?.type ?? CellType.empty;
    final isParcel = widget.serviceType == ServiceType.parcel;

    if (_isCellBooked(cell)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This seat is already booked')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                title: Text('Cell ($row,$col)'),
                subtitle: Text(type.name),
              ),
              if (type == CellType.empty) ...[
                ListTile(
                  leading: Icon(
                    isParcel ? Icons.inventory_2 : Icons.event_seat,
                  ),
                  title: Text(isParcel ? 'Add parcel compartment' : 'Add seat'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showSeatForm(row, col, existing: null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.crop_square),
                  title: const Text('Add space (gap)'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.controller.setSpace(row, col);
                  },
                ),
              ],
              if (type == CellType.space) ...[
                ListTile(
                  leading: Icon(
                    isParcel ? Icons.inventory_2 : Icons.event_seat,
                  ),
                  title: Text(
                    isParcel ? 'Convert to compartment' : 'Convert to seat',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showSeatForm(row, col, existing: null);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear (to empty)'),
                  onTap: () {
                    Navigator.pop(context);
                    widget.controller.clearCell(row, col);
                  },
                ),
              ],
              if (type == CellType.seat) ...[
                if (cell != null && cell.isLocked) ...[
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: const Text('Unlock'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.controller.toggleLock(row, col);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: Text(isParcel ? 'Edit compartment' : 'Edit seat'),
                    onTap: () async {
                      Navigator.pop(context);
                      await _showSeatForm(row, col, existing: cell);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Lock'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.controller.toggleLock(row, col);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.crop_square),
                    title: const Text('Convert to space'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.controller.convertSeatToSpace(row, col);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Clear (to empty)'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.controller.clearCell(row, col);
                    },
                  ),
                ],
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
  }

  Future<void> _showSeatForm(
    int row,
    int col, {
    required LayoutCell? existing,
  }) async {
    final isParcel = widget.serviceType == ServiceType.parcel;

    // Parse existing parcel data — dimensions are encoded into seatName as
    // "CompartmentName|L:10|B:20|H:30|W:5|T:Normal|HS:392310" on save.
    // Split it back out so the fields pre-fill correctly when editing.
    String existingName = existing?.seatName ?? '';
    String existingLength = '';
    String existingBreadth = '';
    String existingHeight = '';
    String existingWeight = '';
    String existingParcelType = 'Normal';
    String existingHSCode = '';

    if (isParcel && existingName.contains('|')) {
      final parts = existingName.split('|');
      existingName = parts[0];
      for (final part in parts.skip(1)) {
        if (part.startsWith('L:')) {
          existingLength = part.substring(2);
        } else if (part.startsWith('B:')) {
          existingBreadth = part.substring(2);
        } else if (part.startsWith('H:')) {
          existingHeight = part.substring(2);
        } else if (part.startsWith('W:')) {
          existingWeight = part.substring(2);
        } else if (part.startsWith('T:')) {
          final typeData = part.substring(2);
          // Handle formats: "type:Normal", "type:Normal|code:392310", "code:392310"
          if (typeData.startsWith('type:')) {
            // Simple mode: "type:Normal" or "type:Normal|code:392310"
            if (typeData.contains('|code:')) {
              final split = typeData.split('|code:');
              existingParcelType = split[0].substring(5); // Remove "type:"
              existingHSCode = split[1];
            } else {
              existingParcelType = typeData.substring(5); // Remove "type:"
            }
          } else if (typeData.startsWith('code:')) {
            // Advanced mode: just "code:392310"
            existingHSCode = typeData.substring(5); // Remove "code:"
          }
        } else if (part.startsWith('HS:')) {
          existingHSCode = part.substring(3);
        }
      }
    }

    final nameController = TextEditingController(text: existingName);
    final priceController = TextEditingController(
      text: existing?.price?.toString() ?? '',
    );
    final securityDepositController = TextEditingController(
      text: existing?.securityDeposit?.toString() ?? '',
    );

    // Parcel-specific controllers — pre-filled from parsed data
    final lengthController = TextEditingController(text: existingLength);
    final heightController = TextEditingController(text: existingHeight);
    final weightController = TextEditingController(text: existingWeight);
    final breadthController = TextEditingController(text: existingBreadth);

    var locked = existing?.isLocked ?? false;
    var seatKind = existing?.seatKind ?? SeatKind.seat;
    var gender = existing?.gender ?? SeatGender.any;
    var parcelType = existingParcelType;
    var selectedHSCode = existingHSCode; // Pre-fill with existing HS code

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null
                          ? (isParcel ? 'Add parcel compartment' : 'Add seat')
                          : (isParcel ? 'Edit compartment' : 'Edit seat'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: isParcel ? 'Compartment name' : 'Seat name',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: securityDepositController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Security Deposit (optional)',
                        border: OutlineInputBorder(),
                        helperText:
                            'Refundable deposit for this compartment/seat',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Parcel-specific fields — SIMPLIFIED LAYOUT
                    if (isParcel) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Dimensions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // L × B × H × W in one compact row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lengthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'L',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: breadthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'B',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'H',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'W',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Type + HS Code side by side
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: parcelType,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Normal',
                                  child: Text('Normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'Fragile',
                                  child: Text('Fragile'),
                                ),
                                DropdownMenuItem(
                                  value: 'Perishable',
                                  child: Text('Perishable'),
                                ),
                                DropdownMenuItem(
                                  value: 'Medical',
                                  child: Text('Medical'),
                                ),
                                DropdownMenuItem(
                                  value: 'Hazardous',
                                  child: Text('Hazardous'),
                                ),
                                DropdownMenuItem(
                                  value: 'Live Animals',
                                  child: Text('Animals'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => parcelType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: (value) {
                                setModalState(() => selectedHSCode = value);
                              },
                              controller: TextEditingController(
                                text: selectedHSCode,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'HS Code',
                                hintText: 'e.g., 392310',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Passenger-specific fields
                    if (!isParcel) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Lock seat'),
                        value: locked,
                        onChanged: (v) => setModalState(() => locked = v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<SeatKind>(
                              initialValue: seatKind,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: SeatKind.seat,
                                  child: Text('Seat'),
                                ),
                                DropdownMenuItem(
                                  value: SeatKind.berth,
                                  child: Text('Berth'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => seatKind = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<SeatGender>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: SeatGender.any,
                                  child: Text('Any'),
                                ),
                                DropdownMenuItem(
                                  value: SeatGender.male,
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem(
                                  value: SeatGender.female,
                                  child: Text('Female'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setModalState(() => gender = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          // Validate price is filled
                          final price = int.tryParse(
                            priceController.text.trim(),
                          );
                          if (price == null || price <= 0) {
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a price'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          // Validate dimensions for parcel
                          if (isParcel) {
                            final l = double.tryParse(
                              lengthController.text.trim(),
                            );
                            final b = double.tryParse(
                              breadthController.text.trim(),
                            );
                            final h = double.tryParse(
                              heightController.text.trim(),
                            );
                            final w = double.tryParse(
                              weightController.text.trim(),
                            );
                            if (l == null ||
                                l <= 0 ||
                                b == null ||
                                b <= 0 ||
                                h == null ||
                                h <= 0 ||
                                w == null ||
                                w <= 0) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all dimensions'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }
                          Navigator.pop(context, true);
                        },
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted) return;

    if (ok != true) return;

    try {
      // For parcel, store dimensions in seat name as metadata
      String finalSeatName = nameController.text;
      if (isParcel) {
        final length = lengthController.text.trim();
        final breadth = breadthController.text.trim();
        final height = heightController.text.trim();
        final weight = weightController.text.trim();

        if (length.isNotEmpty ||
            breadth.isNotEmpty ||
            height.isNotEmpty ||
            weight.isNotEmpty) {
          // Combine parcelType with HS code using prefix format
          final parcelWithHS = selectedHSCode.isNotEmpty
              ? 'type:$parcelType|code:$selectedHSCode'
              : 'type:$parcelType';
          finalSeatName =
              '$finalSeatName|L:$length|B:$breadth|H:$height|W:$weight|T:$parcelWithHS';
        } else if (selectedHSCode.isNotEmpty) {
          // Even if no dimensions, store parcel type + HS code
          final parcelWithHS = 'type:$parcelType|code:$selectedHSCode';
          finalSeatName = '$finalSeatName|T:$parcelWithHS';
        }
      }

      widget.controller.setSeat(
        row: row,
        col: col,
        seatName: finalSeatName,
        price: int.tryParse(priceController.text.trim()),
        securityDeposit: int.tryParse(securityDepositController.text.trim()),
        seatKind: seatKind,
        gender: gender,
        locked: locked,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
