import '../services/currency_service.dart';

/// Base class for slot data
abstract class SlotData {
  final double price;
  final String currencyCode;
  final double securityPrice;

  const SlotData({
    required this.price,
    required this.currencyCode,
    required this.securityPrice,
  });

  Map<String, dynamic> toJson();
  
  String getFormattedPrice() {
    return CurrencyService().formatPrice(price, currencyCode);
  }
  
  String getFormattedSecurityPrice() {
    return CurrencyService().formatPrice(securityPrice, currencyCode);
  }
}

/// Passenger slot data (seat/berth)
class PassengerSlotData extends SlotData {
  final String travelChoice; // 'seat' or 'berth'
  final String gender; // 'male', 'female', 'any'
  final List<String> images; // Array of image URLs

  const PassengerSlotData({
    required this.travelChoice,
    required this.gender,
    required super.price,
    required super.currencyCode,
    required super.securityPrice,
    this.images = const [], // Default empty list
  });

  factory PassengerSlotData.fromJson(Map<String, dynamic> json) {
    return PassengerSlotData(
      travelChoice: json['travel_choice'] as String,
      gender: json['gender'] as String,
      price: (json['price'] as num).toDouble(),
      currencyCode: json['currency'] as String,
      securityPrice: (json['security_price'] as num).toDouble(),
      images: json['images'] != null 
          ? List<String>.from(json['images'])
          : [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'price': price,
      'currency': currencyCode,
      'security_price': securityPrice,
      'gender': gender,
      'travel_choice': travelChoice,
      'images': images,
    };
  }

  PassengerSlotData copyWith({
    String? travelChoice,
    String? gender,
    double? price,
    String? currencyCode,
    double? securityPrice,
    List<String>? images,
  }) {
    return PassengerSlotData(
      travelChoice: travelChoice ?? this.travelChoice,
      gender: gender ?? this.gender,
      price: price ?? this.price,
      currencyCode: currencyCode ?? this.currencyCode,
      securityPrice: securityPrice ?? this.securityPrice,
      images: images ?? this.images,
    );
  }
}

/// Parcel slot data (dimensions)
class ParcelSlotData extends SlotData {
  final double l; // length in cm
  final double h; // height in cm  
  final double w; // width in cm
  final double b; // breadth in cm
  final List<String> images; // Array of image URLs

  const ParcelSlotData({
    required this.l,
    required this.h,
    required this.w,
    required this.b,
    required super.price,
    required super.currencyCode,
    required super.securityPrice,
    this.images = const [], // Default empty list
  });

  factory ParcelSlotData.fromJson(Map<String, dynamic> json) {
    return ParcelSlotData(
      l: (json['l'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      b: (json['b'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      currencyCode: json['currency'] as String,
      securityPrice: (json['security_price'] as num).toDouble(),
      images: json['images'] != null 
          ? List<String>.from(json['images'])
          : [],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'price': price,
      'currency': currencyCode,
      'security_price': securityPrice,
      'l': l,
      'h': h,
      'w': w,
      'b': b,
      'images': images,
    };
  }

  /// Get volume in cubic cm
  double get volume => l * h * w;

  /// Get formatted dimensions string
  String getFormattedDimensions() {
    return '${l.toInt()}×${w.toInt()}×${h.toInt()} cm';
  }

  /// Get formatted weight string (using volume as proxy)
  String getFormattedWeight() {
    return '${(volume / 1000).toStringAsFixed(1)} kg'; // Rough estimate
  }

  ParcelSlotData copyWith({
    double? l,
    double? h,
    double? w,
    double? b,
    double? price,
    String? currencyCode,
    double? securityPrice,
    List<String>? images,
  }) {
    return ParcelSlotData(
      l: l ?? this.l,
      h: h ?? this.h,
      w: w ?? this.w,
      b: b ?? this.b,
      price: price ?? this.price,
      currencyCode: currencyCode ?? this.currencyCode,
      securityPrice: securityPrice ?? this.securityPrice,
      images: images ?? this.images,
    );
  }
}

/// Grid position for slot layout
class GridPosition {
  final int row;
  final int col;
  final SlotData data;

  const GridPosition({
    required this.row,
    required this.col,
    required this.data,
  });

  factory GridPosition.fromJson(Map<String, dynamic> json) {
    final dataJson = json['data'] as Map<String, dynamic>;
    
    // Determine slot type based on data structure
    SlotData slotData;
    if (dataJson.containsKey('travel_choice')) {
      // Passenger slot
      slotData = PassengerSlotData.fromJson(dataJson);
    } else {
      // Parcel slot
      slotData = ParcelSlotData.fromJson(dataJson);
    }

    return GridPosition(
      row: json['row'] as int,
      col: json['col'] as int,
      data: slotData,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'data': data.toJson(),
    };
  }
}

/// Complete slot configuration
class SlotConfiguration {
  final List<GridPosition> grid;

  const SlotConfiguration({required this.grid});

  factory SlotConfiguration.fromJson(Map<String, dynamic> json) {
    final gridList = json['grid'] as List;
    return SlotConfiguration(
      grid: gridList
          .map((item) => GridPosition.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'grid': grid.map((position) => position.toJson()).toList(),
    };
  }

  /// Create passenger slot configuration with auto-currency
  factory SlotConfiguration.passenger({
    required List<PassengerSlotData> slots,
    String? currencyCode,
  }) {
    final currency = currencyCode ?? CurrencyService().getDeviceCurrency();
    
    final grid = <GridPosition>[];
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i].copyWith(currencyCode: currency);
      grid.add(GridPosition(
        row: 1,
        col: i + 1,
        data: slot,
      ));
    }
    
    return SlotConfiguration(grid: grid);
  }

  /// Create parcel slot configuration with auto-currency
  factory SlotConfiguration.parcel({
    required List<ParcelSlotData> slots,
    String? currencyCode,
  }) {
    final currency = currencyCode ?? CurrencyService().getDeviceCurrency();
    
    final grid = <GridPosition>[];
    for (int i = 0; i < slots.length; i++) {
      final slot = slots[i].copyWith(currencyCode: currency);
      grid.add(GridPosition(
        row: 1,
        col: i + 1,
        data: slot,
      ));
    }
    
    return SlotConfiguration(grid: grid);
  }

  /// Get total slots count
  int get totalSlots => grid.length;

  /// Get all passenger slots
  List<PassengerSlotData> get passengerSlots {
    return grid
        .where((pos) => pos.data is PassengerSlotData)
        .map((pos) => pos.data as PassengerSlotData)
        .toList();
  }

  /// Get all parcel slots
  List<ParcelSlotData> get parcelSlots {
    return grid
        .where((pos) => pos.data is ParcelSlotData)
        .map((pos) => pos.data as ParcelSlotData)
        .toList();
  }

  /// Check if configuration is for passengers
  bool get isPassengerConfig => grid.isNotEmpty && grid.first.data is PassengerSlotData;

  /// Check if configuration is for parcels
  bool get isParcelConfig => grid.isNotEmpty && grid.first.data is ParcelSlotData;
}