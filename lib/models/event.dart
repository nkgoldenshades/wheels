import 'event_delivery_mode.dart';

class Event {
  final String id;
  final String userId;
  final String title;
  final String location;
  final double radiusKm;
  final DateTime startTime;
  final DateTime endTime;
  final List<String> images;
  final String description;
  final double? price;
  final DateTime createdAt;
  final EventDeliveryMode deliveryMode;

  Event({
    required this.id,
    required this.userId,
    required this.title,
    required this.location,
    required this.radiusKm,
    required this.startTime,
    required this.endTime,
    required this.images,
    required this.description,
    this.price,
    required this.createdAt,
    this.deliveryMode = EventDeliveryMode.customerComesToEvent,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'location': location,
      'radiusKm': radiusKm,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'images': images,
      'description': description,
      'price': price,
      'createdAt': createdAt.toIso8601String(),
      'deliveryMode': deliveryMode.name,
    };
  }

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      location: json['location'],
      radiusKm: json['radiusKm']?.toDouble() ?? 0.0,
      startTime: DateTime.parse(json['startTime']).toLocal(),
      endTime: DateTime.parse(json['endTime']).toLocal(),
      images: List<String>.from(json['images']),
      description: json['description'],
      price: json['price']?.toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
      deliveryMode: json['deliveryMode'] != null
          ? EventDeliveryMode.values.firstWhere(
              (e) => e.name == json['deliveryMode'],
              orElse: () => EventDeliveryMode.customerComesToEvent,
            )
          : EventDeliveryMode.customerComesToEvent,
    );
  }
}

