/// Simplified seat layout model matching the exact JSON structure
/// Used for storing seat configurations in posts
library;

enum SlotStatus {
  available,
  booked,
  locked,
  gap,
}

extension SlotStatusExtension on SlotStatus {
  String get value {
    switch (this) {
      case SlotStatus.available:
        return 'available';
      case SlotStatus.booked:
        return 'booked';
      case SlotStatus.locked:
        return 'locked';
      case SlotStatus.gap:
        return 'gap';
    }
  }

  static SlotStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'booked':
        return SlotStatus.booked;
      case 'locked':
        return SlotStatus.locked;
      case 'gap':
        return SlotStatus.gap;
      default:
        return SlotStatus.available;
    }
  }
}

/// Parcel dimensions
class ParcelDimensions {
  final double h; // height
  final double w; // width
  final double l; // length
  final double b; // breadth

  ParcelDimensions({
    required this.h,
    required this.w,
    required this.l,
    required this.b,
  });

  Map<String, dynamic> toJson() {
    return {
      'h': h,
      'w': w,
      'l': l,
      'b': b,
    };
  }

  factory ParcelDimensions.fromJson(Map<String, dynamic> json) {
    return ParcelDimensions(
      h: (json['h'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      l: (json['l'] as num).toDouble(),
      b: (json['b'] as num).toDouble(),
    );
  }
}

/// Base class for layout items (passenger seats or parcel slots)
abstract class LayoutItem {
  final String key; // Unified key for both passenger and parcel
  final String matrix; // e.g., "1x1", "1x2"
  final SlotStatus status;
  final int price;
  final String? bookingId;

  LayoutItem({
    required this.key,
    required this.matrix,
    required this.status,
    required this.price,
    this.bookingId,
  });

  // Get row and column from matrix (e.g., "1x2" -> row=1, col=2)
  int get row => int.parse(matrix.split('x')[0]);
  int get col => int.parse(matrix.split('x')[1]);

  bool get isAvailable => status == SlotStatus.available;
  bool get isBooked => status == SlotStatus.booked;
  bool get isLocked => status == SlotStatus.locked;
  bool get isGap => status == SlotStatus.gap;

  Map<String, dynamic> toJson();
}

/// Passenger seat item
class PassengerSeat extends LayoutItem {
  final String allowedGender; // Rule: "Male", "Female", "Any"

  PassengerSeat({
    required super.key,
    required super.matrix,
    required super.status,
    required super.price,
    super.bookingId,
    this.allowedGender = 'Any',
  });

  PassengerSeat copyWith({
    String? key,
    String? matrix,
    SlotStatus? status,
    int? price,
    String? bookingId,
    String? allowedGender,
  }) {
    return PassengerSeat(
      key: key ?? this.key,
      matrix: matrix ?? this.matrix,
      status: status ?? this.status,
      price: price ?? this.price,
      bookingId: bookingId ?? this.bookingId,
      allowedGender: allowedGender ?? this.allowedGender,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'key': key,
      'matrix': matrix,
      'status': status.value,
      'price': price,
    };
    
    // Only add allowed_gender if not gap
    if (status != SlotStatus.gap) {
      json['allowed_gender'] = allowedGender;
    }
    
    if (bookingId != null) {
      json['booking_id'] = bookingId;
    }
    
    return json;
  }

  factory PassengerSeat.fromJson(Map<String, dynamic> json) {
    return PassengerSeat(
      key: json['key'] as String,
      matrix: json['matrix'] as String,
      status: SlotStatusExtension.fromString(json['status'] as String? ?? 'available'),
      price: (json['price'] as num?)?.toInt() ?? 0,
      bookingId: json['booking_id'] as String?,
      allowedGender: json['allowed_gender'] as String? ?? 'Any',
    );
  }

  // Check if user can book this seat based on gender restriction
  bool canBook(String userGender) {
    if (status != SlotStatus.available) return false;
    if (allowedGender == 'Any') return true;
    return allowedGender == userGender;
  }
}

/// Parcel slot item
class ParcelSlot extends LayoutItem {
  final String? parcelType; // "Normal", "Fragile", "Perishable", etc.
  final ParcelDimensions? dimensions;

  ParcelSlot({
    required super.key,
    required super.matrix,
    required super.status,
    required super.price,
    super.bookingId,
    this.parcelType,
    this.dimensions,
  });

  ParcelSlot copyWith({
    String? key,
    String? matrix,
    SlotStatus? status,
    int? price,
    String? bookingId,
    String? parcelType,
    ParcelDimensions? dimensions,
  }) {
    return ParcelSlot(
      key: key ?? this.key,
      matrix: matrix ?? this.matrix,
      status: status ?? this.status,
      price: price ?? this.price,
      bookingId: bookingId ?? this.bookingId,
      parcelType: parcelType ?? this.parcelType,
      dimensions: dimensions ?? this.dimensions,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'key': key,
      'matrix': matrix,
      'status': status.value,
    };
    
    // Only add price and other fields if not gap
    if (status != SlotStatus.gap) {
      json['price'] = price;
      if (parcelType != null) json['parcel_type'] = parcelType;
      if (dimensions != null) json['dimensions'] = dimensions!.toJson();
    }
    
    if (bookingId != null) {
      json['booking_id'] = bookingId;
    }
    
    return json;
  }

  factory ParcelSlot.fromJson(Map<String, dynamic> json) {
    return ParcelSlot(
      key: json['key'] as String,
      matrix: json['matrix'] as String,
      status: SlotStatusExtension.fromString(json['status'] as String? ?? 'available'),
      price: (json['price'] as num?)?.toInt() ?? 0,
      bookingId: json['booking_id'] as String?,
      parcelType: json['parcel_type'] as String?,
      dimensions: json['dimensions'] != null
          ? ParcelDimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Main layout structure for both passenger and parcel
class SimpleSeatLayout {
  final String type; // "passenger" or "parcel"
  final List<LayoutItem> layout;

  SimpleSeatLayout({
    required this.type,
    required this.layout,
  });

  bool get isPassenger => type == 'passenger';
  bool get isParcel => type == 'parcel';

  SimpleSeatLayout copyWith({
    String? type,
    List<LayoutItem>? layout,
  }) {
    return SimpleSeatLayout(
      type: type ?? this.type,
      layout: layout ?? this.layout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'layout': layout.map((item) => item.toJson()).toList(),
    };
  }

  factory SimpleSeatLayout.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final layoutList = json['layout'] as List;

    List<LayoutItem> items;
    if (type == 'passenger') {
      items = layoutList
          .map((itemJson) => PassengerSeat.fromJson(itemJson as Map<String, dynamic>))
          .toList();
    } else if (type == 'parcel') {
      items = layoutList
          .map((itemJson) => ParcelSlot.fromJson(itemJson as Map<String, dynamic>))
          .toList();
    } else {
      items = [];
    }

    return SimpleSeatLayout(
      type: type,
      layout: items,
    );
  }

  // Helper methods
  LayoutItem? getItem(String key) {
    try {
      return layout.firstWhere((item) => item.key == key);
    } catch (e) {
      return null;
    }
  }

  List<LayoutItem> get availableItems =>
      layout.where((item) => item.isAvailable).toList();

  List<LayoutItem> get bookedItems =>
      layout.where((item) => item.isBooked).toList();

  List<LayoutItem> get lockedItems =>
      layout.where((item) => item.isLocked).toList();

  List<LayoutItem> get gapItems =>
      layout.where((item) => item.isGap).toList();

  int get totalItems => layout.where((item) => !item.isGap).length;
  int get availableCount => availableItems.length;
  int get bookedCount => bookedItems.length;
  int get lockedCount => lockedItems.length;

  // Update item status
  SimpleSeatLayout updateItemStatus(String key, SlotStatus status, {String? bookingId}) {
    final updatedLayout = layout.map((item) {
      if (item.key == key) {
        if (item is PassengerSeat) {
          return item.copyWith(status: status, bookingId: bookingId);
        } else if (item is ParcelSlot) {
          return item.copyWith(status: status, bookingId: bookingId);
        }
      }
      return item;
    }).toList();

    return copyWith(layout: updatedLayout);
  }

  // Get max row and column for grid display
  int get maxRow => layout.isEmpty ? 0 : layout.map((s) => s.row).reduce((a, b) => a > b ? a : b);
  int get maxCol => layout.isEmpty ? 0 : layout.map((s) => s.col).reduce((a, b) => a > b ? a : b);
}



