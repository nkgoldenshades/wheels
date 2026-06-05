/// Model for tracking post edit history
class EditHistoryEntry {
  final int editNumber;
  final DateTime timestamp;
  final Map<String, dynamic> changes; // field -> {old, new}

  EditHistoryEntry({
    required this.editNumber,
    required this.timestamp,
    required this.changes,
  });

  Map<String, dynamic> toJson() {
    return {
      'editNumber': editNumber,
      'timestamp': timestamp.toIso8601String(),
      'changes': changes,
    };
  }

  factory EditHistoryEntry.fromJson(Map<String, dynamic> json) {
    return EditHistoryEntry(
      editNumber: json['editNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      changes: json['changes'] as Map<String, dynamic>,
    );
  }

  /// Get a human-readable description of changes
  String getDescription() {
    final changedFields = <String>[];
    
    changes.forEach((field, change) {
      final oldValue = change['old'];
      final newValue = change['new'];
      
      switch (field) {
        case 'price':
          changedFields.add('price from ₹$oldValue to ₹$newValue');
          break;
        case 'capacity':
          changedFields.add('capacity from $oldValue to $newValue seats');
          break;
        case 'startTime':
          changedFields.add('start time');
          break;
        case 'endTime':
          changedFields.add('end time');
          break;
        case 'fromLocation':
          changedFields.add('pickup location');
          break;
        case 'toLocation':
          changedFields.add('drop-off location');
          break;
        case 'baseLocation':
          changedFields.add('base location');
          break;
        case 'radius':
          changedFields.add('service radius');
          break;
        case 'notes':
          changedFields.add('terms');
          break;
        default:
          changedFields.add(field);
      }
    });
    
    if (changedFields.isEmpty) return 'No changes';
    if (changedFields.length == 1) return 'Changed ${changedFields[0]}';
    if (changedFields.length == 2) {
      return 'Changed ${changedFields[0]} and ${changedFields[1]}';
    }
    return 'Changed ${changedFields.sublist(0, changedFields.length - 1).join(', ')}, and ${changedFields.last}';
  }

  /// Get time ago string (e.g., "2 hours ago")
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${(difference.inDays / 7).floor()} ${(difference.inDays / 7).floor() == 1 ? 'week' : 'weeks'} ago';
    }
  }
}

/// List of edit history entries
class EditHistory {
  final List<EditHistoryEntry> entries;

  EditHistory({required this.entries});

  factory EditHistory.empty() => EditHistory(entries: []);

  factory EditHistory.fromJson(List<dynamic>? json) {
    if (json == null || json.isEmpty) return EditHistory.empty();
    
    return EditHistory(
      entries: json
          .map((e) => EditHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  List<Map<String, dynamic>> toJson() {
    return entries.map((e) => e.toJson()).toList();
  }

  int get totalEdits => entries.length;
  bool get hasEdits => entries.isNotEmpty;
  
  EditHistoryEntry? get latestEdit => entries.isEmpty ? null : entries.last;

  /// Add a new edit entry
  EditHistory addEdit(Map<String, dynamic> changes) {
    final newEntry = EditHistoryEntry(
      editNumber: entries.length + 1,
      timestamp: DateTime.now(),
      changes: changes,
    );
    
    return EditHistory(entries: [...entries, newEntry]);
  }
}
