import 'seat_layout.dart';

class Passenger {
  final String id;
  final String name;
  final int age;
  final SeatGender gender;

  Passenger({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender.name, // Use name instead of index for consistency
    };
  }

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      id: json['id'],
      name: json['name'],
      age: json['age'],
      gender: json['gender'] is String
          ? SeatGender.values.firstWhere((e) => e.name == json['gender'])
          : SeatGender.values[json['gender'] as int], // Backward compatibility
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Passenger && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}


