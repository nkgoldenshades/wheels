import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/seat_layout_controller.dart';
import '../../models/booking.dart';
import '../../models/seat_layout.dart';
import '../../models/service_type.dart';
import '../../services/booking_repository.dart';
import '../../services/slot_repository.dart';

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
              b.status != BookingStatus.rejected,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 images allowed')),
      );
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
        final bytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(bytes);
        
        widget.controller.addImage(base64Image);
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
    widget.controller.removeImage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seating setup'),
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
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final layout = widget.controller.layout;
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 2.5,
            constrained: false,
            child: SizedBox(
              width: layout.cols * _cellSize,
              height: layout.rows * _cellSize,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
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
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _bgColor(type),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? Colors.blue
                                : (type == CellType.seat
                                      ? ((stored?.gender ?? SeatGender.any) ==
                                              SeatGender.male
                                          ? Colors.blue
                                          : ((stored?.gender ??
                                                      SeatGender.any) ==
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
                  );
                },
              ),
            ),
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

    final name = c.seatName ?? '';
    final kindLabel = c.seatKind == SeatKind.berth ? 'B' : 'S';
    final genderLabel = switch (c.gender) {
      SeatGender.male => 'M',
      SeatGender.female => 'F',
      SeatGender.any => '',
    };
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$kindLabel $name${genderLabel.isEmpty ? '' : ' ($genderLabel)'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c.isLocked ? Colors.grey : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            c.price?.toString() ?? '',
            style: TextStyle(
              fontSize: 10,
              color: c.isLocked ? Colors.grey : Colors.black54,
            ),
          ),
          if (c.isLocked)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.lock, size: 12, color: Colors.grey),
            ),
        ],
      ),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          final r = int.tryParse(rowsController.text) ?? curRows;
                          final c = int.tryParse(colsController.text) ?? curCols;
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                            final p = int.tryParse(priceController.text) ?? 0;
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
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    // Image Grid
                    if (widget.controller.layout.images.isNotEmpty) ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: widget.controller.layout.images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    base64Decode(widget.controller.layout.images[index]),
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
                  leading: Icon(isParcel ? Icons.inventory_2 : Icons.event_seat),
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
                  leading: Icon(isParcel ? Icons.inventory_2 : Icons.event_seat),
                  title: Text(isParcel ? 'Convert to compartment' : 'Convert to seat'),
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
    
    final nameController = TextEditingController(
      text: existing?.seatName ?? '',
    );
    final priceController = TextEditingController(
      text: existing?.price?.toString() ?? '',
    );
    
    // Parcel-specific controllers
    final lengthController = TextEditingController();
    final heightController = TextEditingController();
    final weightController = TextEditingController();
    final breadthController = TextEditingController();
    
    var locked = existing?.isLocked ?? false;
    var seatKind = existing?.seatKind ?? SeatKind.seat;
    var gender = existing?.gender ?? SeatGender.any;
    var parcelType = 'Normal'; // Default parcel type

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
                    const SizedBox(height: 8),
                    
                    // Parcel-specific fields
                    if (isParcel) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lengthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Length (cm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: breadthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Breadth (cm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: heightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Height (cm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: weightController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: parcelType,
                        decoration: const InputDecoration(
                          labelText: 'Parcel Type',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
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
                            child: Text('Live Animals'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => parcelType = v);
                        },
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
                        onPressed: () => Navigator.pop(context, true),
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
        
        if (length.isNotEmpty || breadth.isNotEmpty || height.isNotEmpty || weight.isNotEmpty) {
          finalSeatName = '$finalSeatName|L:$length|B:$breadth|H:$height|W:$weight|T:$parcelType';
        }
      }
      
      widget.controller.setSeat(
        row: row,
        col: col,
        seatName: finalSeatName,
        price: int.tryParse(priceController.text.trim()),
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
