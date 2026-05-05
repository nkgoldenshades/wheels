import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/review_repository.dart';
import '../services/profile_repository.dart';
import '../services/auth_repository.dart';
import '../services/vehicle_repository.dart';

class ReviewsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const ReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _showVerifiedOnly = false;
  bool _showExpertsOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: (_fromDate != null && _toDate != null)
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  void _clearDateFilter() => setState(() {
        _fromDate = null;
        _toDate = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Reviews'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ValueListenableBuilder<List<Review>>(
        valueListenable: ReviewRepository.instance.reviews,
        builder: (context, allReviews, _) {
          final userReviews = allReviews
              .where((r) => r.revieweeId == widget.userId)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final averageRating = ReviewRepository.instance.getAverageRating(widget.userId);

          final filtered = userReviews.where((r) {
                  // Search filter
                  if (_query.isNotEmpty &&
                      !(r.comment ?? '').toLowerCase().contains(_query.toLowerCase())) {
                    return false;
                  }
                  
                  // Date filters
                  if (_fromDate != null && r.createdAt.isBefore(_fromDate!)) {
                    return false;
                  }
                  if (_toDate != null &&
                      r.createdAt.isAfter(_toDate!.add(const Duration(days: 1)))) {
                    return false;
                  }
                  
                  // Verified users filter - check if reviewer has verified vehicles
                  if (_showVerifiedOnly) {
                    final reviewerVehicles = VehicleRepository.instance.allVehicles
                        .where((v) => v.userId == r.reviewerId && v.isVerifiedToggle)
                        .toList();
                    if (reviewerVehicles.isEmpty) {
                      return false;
                    }
                  }
                  
                  // Expert providers filter
                  if (_showExpertsOnly) {
                    final reviewerVehicles = VehicleRepository.instance.allVehicles
                        .where((v) => v.userId == r.reviewerId && v.isExpertToggle)
                        .toList();
                    if (reviewerVehicles.isEmpty) {
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();

          return Column(
            children: [
              // Rating Summary
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.star, color: Colors.amber, size: 40),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${userReviews.length} ${userReviews.length == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    _buildRatingDistribution(userReviews),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reviews...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),

              // Date filter row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          (_fromDate == null && _toDate == null)
                              ? 'Filter by date'
                              : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year} – ${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    if (_fromDate != null || _toDate != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearDateFilter,
                        tooltip: 'Clear date filter',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              ),

              // Trust filters
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Verified Users Only', style: TextStyle(fontSize: 12)),
                      selected: _showVerifiedOnly,
                      onSelected: (selected) => setState(() => _showVerifiedOnly = selected),
                      avatar: Icon(
                        Icons.verified_user,
                        size: 16,
                        color: _showVerifiedOnly ? Colors.white : Colors.blue,
                      ),
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(
                        color: _showVerifiedOnly ? Colors.white : Colors.black87,
                      ),
                    ),
                    FilterChip(
                      label: const Text('Expert Providers Only', style: TextStyle(fontSize: 12)),
                      selected: _showExpertsOnly,
                      onSelected: (selected) => setState(() => _showExpertsOnly = selected),
                      avatar: Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: _showExpertsOnly ? Colors.white : Colors.orange,
                      ),
                      selectedColor: Colors.orange,
                      labelStyle: TextStyle(
                        color: _showExpertsOnly ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              if (_query.isNotEmpty || _fromDate != null || _showVerifiedOnly || _showExpertsOnly)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ),

              // Reviews List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            _query.isEmpty ? 'No reviews yet' : 'No reviews match "$_query"',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, c) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildReviewCard(filtered[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingDistribution(List<Review> reviews) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final distribution = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      distribution[i] = reviews.where((r) => r.rating.round() == i).length;
    }

    return Column(
      children: [5, 4, 3, 2, 1].map((star) {
        final count = distribution[star] ?? 0;
        final percentage = reviews.isEmpty ? 0.0 : count / reviews.length;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$star', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 12, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewCard(Review review) {
    // Get reviewer name from profile
    final currentUser = AuthRepository.instance.currentUser;
    final reviewerName = (currentUser != null && review.reviewerId == currentUser.id)
        ? ProfileRepository.instance.profile.value.profileName
        : 'User';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reviewerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatDate(review.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                  ],
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment!,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

