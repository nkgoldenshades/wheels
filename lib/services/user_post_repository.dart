import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_type.dart';
import '../models/slot_type.dart';
import 'auth_repository.dart';

enum UserPostStatus { active, archived }

class UserPost {
  final String id;
  final String userId;
  final ServiceType serviceType;
  final SlotType slotType;
  final String? fromLocation;
  final String? toLocation;
  final String? baseLocation;
  final double? radius;
  final DateTime startTime;
  final DateTime endTime;
  final double budget;
  final int persons;
  final String? notes;
  final bool requiresVerifiedVehicle;
  final bool requiresExpertVehicle;
  final DateTime createdAt;
  final UserPostStatus status;
  final bool isOnline;

  // Parcel-specific fields
  final double? parcelWeight; // kg
  final double? parcelLength; // cm
  final double? parcelWidth;  // cm
  final double? parcelHeight; // cm

  static const Object _unset = Object();

  const UserPost({
    required this.id,
    required this.userId,
    required this.serviceType,
    required this.slotType,
    this.fromLocation,
    this.toLocation,
    this.baseLocation,
    this.radius,
    required this.startTime,
    required this.endTime,
    required this.budget,
    required this.persons,
    this.notes,
    this.requiresVerifiedVehicle = false,
    this.requiresExpertVehicle = false,
    required this.createdAt,
    required this.status,
    this.isOnline = true,
    this.parcelWeight,
    this.parcelLength,
    this.parcelWidth,
    this.parcelHeight,
  });

  UserPost copyWith({
    String? id,
    String? userId,
    ServiceType? serviceType,
    SlotType? slotType,
    Object? fromLocation = _unset,
    Object? toLocation = _unset,
    Object? baseLocation = _unset,
    Object? radius = _unset,
    DateTime? startTime,
    DateTime? endTime,
    double? budget,
    int? persons,
    Object? notes = _unset,
    bool? requiresVerifiedVehicle,
    bool? requiresExpertVehicle,
    DateTime? createdAt,
    UserPostStatus? status,
    bool? isOnline,
    Object? parcelWeight = _unset,
    Object? parcelLength = _unset,
    Object? parcelWidth = _unset,
    Object? parcelHeight = _unset,
  }) {
    return UserPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      serviceType: serviceType ?? this.serviceType,
      slotType: slotType ?? this.slotType,
      fromLocation: identical(fromLocation, _unset)
          ? this.fromLocation
          : fromLocation as String?,
      toLocation: identical(toLocation, _unset)
          ? this.toLocation
          : toLocation as String?,
      baseLocation: identical(baseLocation, _unset)
          ? this.baseLocation
          : baseLocation as String?,
      radius: identical(radius, _unset) ? this.radius : radius as double?,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      budget: budget ?? this.budget,
      persons: persons ?? this.persons,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      requiresVerifiedVehicle:
          requiresVerifiedVehicle ?? this.requiresVerifiedVehicle,
      requiresExpertVehicle: requiresExpertVehicle ?? this.requiresExpertVehicle,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      parcelWeight: identical(parcelWeight, _unset) ? this.parcelWeight : parcelWeight as double?,
      parcelLength: identical(parcelLength, _unset) ? this.parcelLength : parcelLength as double?,
      parcelWidth: identical(parcelWidth, _unset) ? this.parcelWidth : parcelWidth as double?,
      parcelHeight: identical(parcelHeight, _unset) ? this.parcelHeight : parcelHeight as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'service_type': serviceType.name,
      'slot_type': slotType == SlotType.fromTo ? 'from_to' : 'base_radius',
      'from_location': fromLocation,
      'to_location': toLocation,
      'base_location': baseLocation,
      'radius': radius,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'budget': budget,
      'persons': persons,
      'notes': notes,
      'requires_verified_vehicle': requiresVerifiedVehicle,
      'requires_expert_vehicle': requiresExpertVehicle,
      'status': status.name,
      'is_online': isOnline,
      'parcel_weight': parcelWeight,
      'parcel_length': parcelLength,
      'parcel_width': parcelWidth,
      'parcel_height': parcelHeight,
    };
  }

  factory UserPost.fromJson(Map<String, dynamic> json) {
    return UserPost(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      serviceType: ServiceType.values.firstWhere(
        (e) => e.name == json['service_type'],
        orElse: () => ServiceType.passenger,
      ),
      slotType: json['slot_type'] == 'from_to'
          ? SlotType.fromTo
          : SlotType.fromRange,
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      baseLocation: json['base_location'] as String?,
      radius: json['radius'] != null ? (json['radius'] as num).toDouble() : null,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      budget: (json['budget'] as num).toDouble(),
      persons: json['persons'] as int,
      notes: json['notes'] as String?,
      requiresVerifiedVehicle:
          json['requires_verified_vehicle'] as bool? ?? false,
      requiresExpertVehicle: json['requires_expert_vehicle'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: UserPostStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => UserPostStatus.active,
      ),
      isOnline: json['is_online'] as bool? ?? false,
      parcelWeight: (json['parcel_weight'] as num?)?.toDouble(),
      parcelLength: (json['parcel_length'] as num?)?.toDouble(),
      parcelWidth: (json['parcel_width'] as num?)?.toDouble(),
      parcelHeight: (json['parcel_height'] as num?)?.toDouble(),
    );
  }
}

class UserPostRepository {
  UserPostRepository._();

  static final UserPostRepository instance = UserPostRepository._();

  final _supabase = Supabase.instance.client;
  final ValueNotifier<List<UserPost>> posts = ValueNotifier<List<UserPost>>([]);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await loadPosts();
    _initialized = true;
  }

  List<UserPost> get userPosts {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return [];
    return posts.value
        .where((p) => p.userId == currentUser.id)
        .toList(growable: false);
  }

  Future<void> loadPosts() async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        posts.value = [];
        return;
      }

      // Load ALL user posts (not just current user's) so providers can see requests
      final response = await _supabase
          .from('user_posts')
          .select()
          .order('created_at', ascending: false);

      posts.value = (response as List)
          .map((json) => UserPost.fromJson(json))
          .toList();

      debugPrint('✅ Loaded ${posts.value.length} user posts from Supabase');
    } catch (e) {
      debugPrint('❌ Failed to load user posts: $e');
      posts.value = [];
    }
  }

  Future<void> add(UserPost post) async {
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      // Insert to Supabase
      await _supabase.from('user_posts').insert(post.toJson());

      // Update local state
      posts.value = [post, ...posts.value];

      debugPrint('✅ User post created in Supabase: ${post.id}');
    } catch (e) {
      debugPrint('❌ Failed to create user post: $e');
      rethrow;
    }
  }

  Future<void> update(UserPost post) async {
    try {
      // Update in Supabase
      await _supabase
          .from('user_posts')
          .update(post.toJson())
          .eq('id', post.id);

      // Update local state
      posts.value = posts.value
          .map((p) => p.id == post.id ? post : p)
          .toList(growable: false);

      debugPrint('✅ User post updated in Supabase: ${post.id}');
    } catch (e) {
      debugPrint('❌ Failed to update user post: $e');
      rethrow;
    }
  }

  Future<void> archive(String postId) async {
    try {
      // Update in Supabase
      await _supabase
          .from('user_posts')
          .update({'status': 'archived'})
          .eq('id', postId);

      // Update local state
      posts.value = posts.value
          .map(
            (p) => p.id == postId
                ? p.copyWith(status: UserPostStatus.archived)
                : p,
          )
          .toList(growable: false);

      debugPrint('✅ User post archived in Supabase: $postId');
    } catch (e) {
      debugPrint('❌ Failed to archive user post: $e');
      rethrow;
    }
  }

  Future<void> restore(String postId) async {
    try {
      // Update in Supabase
      await _supabase
          .from('user_posts')
          .update({'status': 'active'})
          .eq('id', postId);

      // Update local state
      posts.value = posts.value
          .map(
            (p) =>
                p.id == postId ? p.copyWith(status: UserPostStatus.active) : p,
          )
          .toList(growable: false);

      debugPrint('✅ User post restored in Supabase: $postId');
    } catch (e) {
      debugPrint('❌ Failed to restore user post: $e');
      rethrow;
    }
  }

  Future<void> toggleOnline(String postId) async {
    try {
      final post = posts.value.firstWhere((p) => p.id == postId);
      final newOnlineStatus = !post.isOnline;

      // Update in Supabase
      await _supabase
          .from('user_posts')
          .update({'is_online': newOnlineStatus})
          .eq('id', postId);

      // Update local state
      posts.value = posts.value
          .map(
            (p) => p.id == postId ? p.copyWith(isOnline: newOnlineStatus) : p,
          )
          .toList(growable: false);

      debugPrint('✅ User post online status toggled in Supabase: $postId');
    } catch (e) {
      debugPrint('❌ Failed to toggle user post online status: $e');
      rethrow;
    }
  }

  Future<void> delete(String postId) async {
    try {
      // Delete from Supabase
      await _supabase.from('user_posts').delete().eq('id', postId);

      // Update local state
      posts.value = posts.value.where((p) => p.id != postId).toList();

      debugPrint('✅ User post deleted from Supabase: $postId');
    } catch (e) {
      debugPrint('❌ Failed to delete user post: $e');
      rethrow;
    }
  }
}
