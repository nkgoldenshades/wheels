import 'package:flutter/material.dart';
import '../models/review.dart';
import '../services/review_repository.dart';

class ReviewDialog extends StatefulWidget {
  final String bookingId;
  final String reviewerId;
  final String revieweeId;
  final String revieweeName;
  final ReviewType type;

  const ReviewDialog({
    super.key,
    required this.bookingId,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
    required this.type,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ReviewRepository.instance.addReview(
        bookingId: widget.bookingId,
        reviewerId: widget.reviewerId,
        revieweeId: widget.revieweeId,
        type: widget.type,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review ${widget.revieweeName}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1.0;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      starValue <= _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _getRatingText(_rating),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                hintText: _getCommentHint(_rating),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Review'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 5) return 'Excellent!';
    if (rating >= 4) return 'Good';
    if (rating >= 3) return 'Average';
    if (rating >= 2) return 'Below Average';
    return 'Poor';
  }

  String _getCommentHint(double rating) {
    if (rating >= 5) return 'What made it excellent? Tell others what stood out!';
    if (rating >= 4) return 'What went well? Any suggestions for improvement?';
    if (rating >= 3) return 'What was okay? What could have been better?';
    if (rating >= 2) return 'What went wrong? How could it be improved?';
    return 'What was the issue? Your feedback helps others.';
  }
}

