enum CellType { empty, seat, space }

enum SeatKind { seat, berth }

enum SeatGender { any, male, female }

class LayoutCell {
  final int row;
  final int col;
  final CellType type;
  final String? seatName;
  final int? price;
  final SeatKind seatKind;
  final SeatGender gender;
  final bool isLocked;
  
  // Parcel-specific fields (for parcel service layout)
  final double? maxWeight; // kg
  final double? maxLength; // cm
  final double? maxWidth; // cm
  final double? maxHeight; // cm

  const LayoutCell({
    required this.row,
    required this.col,
    required this.type,
    this.seatName,
    this.price,
    this.seatKind = SeatKind.seat,
    this.gender = SeatGender.any,
    this.isLocked = false,
    this.maxWeight,
    this.maxLength,
    this.maxWidth,
    this.maxHeight,
  });

  String get key => '$row:$col';

  LayoutCell copyWith({
    CellType? type,
    String? seatName,
    int? price,
    SeatKind? seatKind,
    SeatGender? gender,
    bool? isLocked,
    double? maxWeight,
    double? maxLength,
    double? maxWidth,
    double? maxHeight,
  }) {
    return LayoutCell(
      row: row,
      col: col,
      type: type ?? this.type,
      seatName: seatName,
      price: price,
      seatKind: seatKind ?? this.seatKind,
      gender: gender ?? this.gender,
      isLocked: isLocked ?? this.isLocked,
      maxWeight: maxWeight ?? this.maxWeight,
      maxLength: maxLength ?? this.maxLength,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'row': row,
      'col': col,
      'type': type.name,
      'seatName': seatName,
      'price': price,
      'seatKind': seatKind.name,
      'gender': gender.name,
      'isLocked': isLocked,
      'maxWeight': maxWeight,
      'maxLength': maxLength,
      'maxWidth': maxWidth,
      'maxHeight': maxHeight,
    };
  }

  factory LayoutCell.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type'] as String?) ?? CellType.empty.name;
    final kindName = (json['seatKind'] as String?) ?? SeatKind.seat.name;
    final genderName = (json['gender'] as String?) ?? SeatGender.any.name;

    return LayoutCell(
      row: json['row'],
      col: json['col'],
      type: CellType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => CellType.empty,
      ),
      seatName: json['seatName'],
      price: json['price'],
      seatKind: SeatKind.values.firstWhere(
        (e) => e.name == kindName,
        orElse: () => SeatKind.seat,
      ),
      gender: SeatGender.values.firstWhere(
        (e) => e.name == genderName,
        orElse: () => SeatGender.any,
      ),
      isLocked: json['isLocked'] ?? false,
      maxWeight: json['maxWeight']?.toDouble(),
      maxLength: json['maxLength']?.toDouble(),
      maxWidth: json['maxWidth']?.toDouble(),
      maxHeight: json['maxHeight']?.toDouble(),
    );
  }
}

class SeatLayout {
  final String id;
  final String name;
  final int rows;
  final int cols;
  final Map<String, LayoutCell> cells;
  final List<String> images;

  const SeatLayout({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.cells,
    this.images = const [],
  });

  SeatLayout copyWith({
    String? name,
    int? rows,
    int? cols,
    Map<String, LayoutCell>? cells,
    List<String>? images,
  }) {
    return SeatLayout(
      id: id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
      cols: cols ?? this.cols,
      cells: cells ?? this.cells,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rows': rows,
      'cols': cols,
      'cells': cells.map((key, value) => MapEntry(key, value.toJson())),
      'images': images,
    };
  }

  factory SeatLayout.fromJson(Map<String, dynamic> json) {
    final cellsJson = json['cells'] as Map<String, dynamic>;
    final cells = cellsJson.map(
      (key, value) => MapEntry(key, LayoutCell.fromJson(value)),
    );
    return SeatLayout(
      id: json['id'],
      name: json['name'],
      rows: json['rows'],
      cols: json['cols'],
      cells: Map<String, LayoutCell>.from(cells),
      images: List<String>.from(json['images'] ?? []),
    );
  }
}

