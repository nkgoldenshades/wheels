import 'slot_type.dart';

class EventSlot {
  final String id;
  final String eventId;
  final String name;
  final String description;
  final SlotType slotType;
  final String? fromLocation;
  final String? toLocation;
  final String? baseLocation;
  final double? radius;
  final DateTime startTime;
  final DateTime endTime;
  final double price;
  final int capacity;
  final String? notes;
  final bool isAvailable;
  final DateTime createdAt;
  final String? seatLayoutId;
  final String? profileImage;
  final List<String> descriptionImages;
  final String? shortVideo;

  EventSlot({
    required this.id,
    required this.eventId,
    required this.name,
    required this.description,
    required this.slotType,
    this.fromLocation,
    this.toLocation,
    this.baseLocation,
    this.radius,
    required this.startTime,
    required this.endTime,
    required this.price,
    required this.capacity,
    this.notes,
    this.isAvailable = true,
    required this.createdAt,
    this.seatLayoutId,
    this.profileImage,
    this.descriptionImages = const [],
    this.shortVideo,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'name': name,
      'description': description,
      'slotType': slotType.name,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'baseLocation': baseLocation,
      'radius': radius,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'price': price,
      'capacity': capacity,
      'notes': notes,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
      'seatLayoutId': seatLayoutId,
      'profileImage': profileImage,
      'descriptionImages': descriptionImages,
      'shortVideo': shortVideo,
    };
  }

  factory EventSlot.fromJson(Map<String, dynamic> json) {
    return EventSlot(
      id: json['id'],
      eventId: json['eventId'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      slotType: SlotType.values.firstWhere((s) => s.name == json['slotType']),
      fromLocation: json['fromLocation'],
      toLocation: json['toLocation'],
      baseLocation: json['baseLocation'],
      radius: json['radius']?.toDouble(),
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: DateTime.parse(json['endTime']).toLocal(),
      price: json['price'].toDouble(),
      capacity: json['capacity'],
      notes: json['notes'],
      isAvailable: json['isAvailable'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      seatLayoutId: json['seatLayoutId'],
      profileImage: json['profileImage'],
      descriptionImages: json['descriptionImages'] != null
          ? List<String>.from(json['descriptionImages'])
          : [],
      shortVideo: json['shortVideo'],
    );
  }
}
