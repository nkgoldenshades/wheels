/// Represents a media item (image or video) for a post
class PostMediaItem {
  final String url;
  final String type; // 'image' or 'video'
  final String? storagePath; // Path in Supabase storage
  final DateTime createdAt;
  final bool isUploading; // During upload

  PostMediaItem({
    required this.url,
    required this.type,
    this.storagePath,
    required this.createdAt,
    this.isUploading = false,
  });

  PostMediaItem copyWith({
    String? url,
    String? type,
    String? storagePath,
    DateTime? createdAt,
    bool? isUploading,
  }) {
    return PostMediaItem(
      url: url ?? this.url,
      type: type ?? this.type,
      storagePath: storagePath ?? this.storagePath,
      createdAt: createdAt ?? this.createdAt,
      isUploading: isUploading ?? this.isUploading,
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'type': type,
    'storagePath': storagePath,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PostMediaItem.fromJson(Map<String, dynamic> json) => PostMediaItem(
    url: json['url'] as String,
    type: json['type'] as String,
    storagePath: json['storagePath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
