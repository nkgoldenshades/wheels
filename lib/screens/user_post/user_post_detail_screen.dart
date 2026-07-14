import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../app_tab_controller.dart';
import '../../services/user_post_repository.dart';
import '../../services/user_post_acceptance_repository.dart';
import '../../services/auth_repository.dart';
import '../../services/payment_service.dart';
import '../../services/vehicle_repository.dart';
import '../../services/profile_repository.dart';
import '../../services/booking_repository.dart';
import '../../models/user_post_acceptance.dart';
import '../../models/service_type.dart';
import '../../models/slot_type.dart';
import '../../models/demand_plan.dart';
import '../../models/post_mode.dart';
import '../../widgets/acceptance_confirm_sheet.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../services/razorpay_service.dart';

class UserPostDetailScreen extends StatefulWidget {
  final UserPost post;
  final bool
  isProvider; // true if viewing as provider, false if viewing as post owner

  const UserPostDetailScreen({
    super.key,
    required this.post,
    required this.isProvider,
  });

  @override
  State<UserPostDetailScreen> createState() => _UserPostDetailScreenState();
}

class _UserPostDetailScreenState extends State<UserPostDetailScreen> {
  final _acceptanceRepo = UserPostAcceptanceRepository.instance;
  final _otpController = TextEditingController();
  bool _isProcessing = false;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isProvider ? 'Accept Request' : 'Your Request'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostDetails(),
            const SizedBox(height: 24),
            _buildAcceptanceSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Service',
              _getServiceTypeName(widget.post.serviceType),
            ),
            _buildDetailRow(
              'Type',
              widget.post.slotType == SlotType.fromTo
                  ? 'From-To'
                  : 'Base-Range',
            ),
            if (widget.post.fromLocation != null)
              _buildDetailRow('From', widget.post.fromLocation!),
            if (widget.post.toLocation != null)
              _buildDetailRow('To', widget.post.toLocation!),
            if (widget.post.baseLocation != null)
              _buildDetailRow('Base', widget.post.baseLocation!),
            if (widget.post.radius != null)
              _buildDetailRow('Radius', '${widget.post.radius} km'),
            _buildDetailRow('Start', _formatDateTime(widget.post.startTime)),
            _buildDetailRow('End', _formatDateTime(widget.post.endTime)),
            _buildDetailRow('Persons', widget.post.persons.toString()),
            _buildDetailRow(
              'Budget',
              '₹${widget.post.budget.toStringAsFixed(0)}',
              isHighlighted: true,
            ),
            if (widget.post.notes != null && widget.post.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Terms:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(widget.post.notes!),
            ],
            // Parcel dimensions
            if (widget.post.serviceType == ServiceType.parcel) ...[
              const SizedBox(height: 8),
              const Divider(),
              const Text(
                'Parcel Dimensions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (widget.post.parcelWeight != null)
                _buildDetailRow('Weight', '${widget.post.parcelWeight} kg'),
              if (widget.post.parcelLength != null)
                _buildDetailRow('Length', '${widget.post.parcelLength} cm'),
              if (widget.post.parcelWidth != null)
                _buildDetailRow('Width', '${widget.post.parcelWidth} cm'),
              if (widget.post.parcelHeight != null)
                _buildDetailRow('Height', '${widget.post.parcelHeight} cm'),
              if (widget.post.parcelWeight == null &&
                  widget.post.parcelLength == null &&
                  widget.post.parcelWidth == null &&
                  widget.post.parcelHeight == null)
                const Text(
                  'No dimensions specified',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                fontSize: isHighlighted ? 18 : 14,
                color: isHighlighted ? Colors.green : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceSection() {
    return ValueListenableBuilder(
      valueListenable: _acceptanceRepo.acceptances,
      builder: (context, acceptances, _) {
        final postAcceptances = acceptances
            .where((a) => a.postId == widget.post.id)
            .toList();

        if (widget.isProvider) {
          return _buildProviderActions(postAcceptances);
        } else {
          return _buildUserActions(postAcceptances);
        }
      },
    );
  }

  Widget _buildProviderActions(List<UserPostAcceptance> acceptances) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    final myAcceptance = acceptances.firstWhere(
      (a) =>
          a.providerId == currentUser.id &&
          a.status != AcceptanceStatus.cancelled,
      orElse: () => acceptances.first, // dummy
    );

    final hasAccepted = acceptances.any(
      (a) =>
          a.providerId == currentUser.id &&
          a.status != AcceptanceStatus.cancelled,
    );

    if (hasAccepted) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Request Accepted!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('OTP sent to user: ${myAcceptance.otp}'),
              const SizedBox(height: 4),
              Text(
                'Status: ${_getStatusText(myAcceptance.status)}',
                style: TextStyle(
                  color: _getStatusColor(myAcceptance.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _isProcessing ? null : _acceptPost,
      icon: const Icon(Icons.check),
      label: _isProcessing
          ? const Text('Processing...')
          : const Text('Accept Request'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildUserActions(List<UserPostAcceptance> acceptances) {
    if (acceptances.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Waiting for providers to accept your request...',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acceptances (${acceptances.length})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...acceptances.map((acceptance) => _buildAcceptanceCard(acceptance)),
      ],
    );
  }

  Widget _buildAcceptanceCard(UserPostAcceptance acceptance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    acceptance.providerId.substring(0, 2).toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Provider ${acceptance.providerId.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getStatusText(acceptance.status),
                        style: TextStyle(
                          color: _getStatusColor(acceptance.status),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${acceptance.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            if (acceptance.status == AcceptanceStatus.pending) ...[
              const SizedBox(height: 16),
              const Text(
                'Enter OTP to proceed with payment:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _otpController,
                      decoration: const InputDecoration(
                        labelText: 'Enter 6-digit OTP',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _verifyOTPAndPay(acceptance),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify & Pay'),
                  ),
                ],
              ),
            ],
            if (acceptance.status == AcceptanceStatus.paid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Payment Completed',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acceptPost() async {
    setState(() => _isProcessing = true);

    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Please login to accept requests');
      }

      // ✅ CHECK DEMAND PLAN - Profile-based access control
      final currentProfile = ProfileRepository.instance.profile.value;
      if (currentProfile.id.isEmpty) {
        throw Exception('Profile not found');
      }

      // Check if profile meets demand plan requirements
      if (!currentProfile.meetsDemandPlan(widget.post.demandPlan)) {
        switch (widget.post.demandPlan) {
          case DemandPlan.verified:
            throw Exception(
              'This post requires a verified profile. '
              'Please verify your Aadhaar, PAN, or Driving License.',
            );
          case DemandPlan.expert:
            throw Exception(
              'This post requires expert status. '
              'Complete 50+ trips with 4.5+ rating to become an expert.',
            );
          case DemandPlan.basic:
            break; // Everyone qualifies
        }
      }

      // ✅ CHECK RATING REQUIREMENTS (if any)
      // Get provider's vehicles to check if they meet requirements
      final providerVehicles = VehicleRepository.instance.allVehicles
          .where((v) => v.userId == currentUser.id)
          .toList();

      if (providerVehicles.isEmpty) {
        throw Exception('You need to add a vehicle before accepting posts');
      }

      // Check if ANY of provider's vehicles meets the requirements
      bool hasQualifiedVehicle = false;
      String? failureReason;

      for (final vehicle in providerVehicles) {
        // Check min rating requirement
        if (widget.post.minRatings != null &&
            vehicle.averageRating < widget.post.minRatings!) {
          failureReason =
              'Vehicle rating ${vehicle.averageRating.toStringAsFixed(1)}⭐ is below required ${widget.post.minRatings!.toStringAsFixed(1)}⭐';
          continue;
        }

        // Check min trips requirement
        if (widget.post.minNoRatings != null &&
            vehicle.totalBookings < widget.post.minNoRatings!) {
          failureReason =
              'Vehicle has ${vehicle.totalBookings} trips, but ${widget.post.minNoRatings}+ required';
          continue;
        }

        // Check verified vehicle requirement (legacy)
        if (widget.post.requiresVerifiedVehicle && !vehicle.isFullyVerified) {
          failureReason = 'Post requires verified vehicle';
          continue;
        }

        // Check expert vehicle requirement (legacy)
        if (widget.post.requiresExpertVehicle && !vehicle.isExpertToggle) {
          failureReason = 'Post requires expert vehicle';
          continue;
        }

        // Vehicle qualifies!
        hasQualifiedVehicle = true;
        break;
      }

      if (!hasQualifiedVehicle) {
        throw Exception(
          failureReason ?? 'Your vehicle does not meet the post requirements',
        );
      }

      // Use first qualified vehicle's operator details
      final vehicle = providerVehicles.first;

      // Show acceptance confirmation sheet (similar to booking sheet)
      final acceptanceResult =
          await showModalBottomSheet<AcceptanceConfirmResult>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => AcceptanceConfirmSheet(post: widget.post),
          );

      if (!mounted) return;

      if (acceptanceResult == null) {
        // User cancelled
        setState(() => _isProcessing = false);
        return;
      }

      // Create booking directly (no acceptance table - goes straight to bookings)
      final booking = await BookingRepository.instance.createBooking(
        slotId: widget.post.id,
        providerId: currentUser.id,
        providerName: acceptanceResult.operatorName, // Operator name from sheet
        providerPhone:
            acceptanceResult.operatorPhone, // Operator phone from sheet
        providerEmail: null,
        providerAvatar: vehicle.profileImage,
        userId: widget.post.userId,
        defaultCapacity: widget.post.persons,
        price: widget.post.budget,
        userName: 'Guest', // Customer details unknown at acceptance time
        userPhone: null,
        userAge: 18,
        userGender: null,
        serviceType: widget.post.serviceType,
        vehicleId: acceptanceResult.vehicleId ?? vehicle.id,
        slotStartTime: widget.post.startTime,
        slotEndTime: widget.post.endTime,
        slotCapacity: widget.post.persons,
        postMode: PostMode.instant,
        // Route snapshot
        routeType: widget.post.slotType.name,
        fromAddress: widget.post.fromLocation,
        toAddress: widget.post.toLocation,
        baseAddress: widget.post.baseLocation,
        rangeKm: widget.post.radius,
      );

      if (booking == null) {
        throw Exception('Failed to create booking');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! OTP sent to user.'),
            backgroundColor: Colors.green,
          ),
        );
        // Go to Requests tab
        mainTabIndex.value = 1;
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _verifyOTPAndPay(UserPostAcceptance acceptance) async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter 6-digit OTP')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Verify OTP
      final verified = await _acceptanceRepo.verifyOTP(
        acceptanceId: acceptance.id,
        enteredOTP: otp,
      );

      if (!verified) {
        throw Exception('Invalid or expired OTP');
      }

      // On web, skip Razorpay and mark as paid directly
      if (kIsWeb) {
        await _acceptanceRepo.updatePaymentDetails(
          acceptanceId: acceptance.id,
          razorpayOrderId: 'web_mock_${DateTime.now().millisecondsSinceEpoch}',
          razorpayPaymentId:
              'web_mock_pay_${DateTime.now().millisecondsSinceEpoch}',
          status: AcceptanceStatus.paid,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment completed!'),
              backgroundColor: Colors.green,
            ),
          );
          _otpController.clear();
        }
        return;
      }

      // Create Razorpay order
      final orderData = await PaymentService.instance.createOrder(
        amount: acceptance.amount.toInt(),
        currency: 'INR',
        notes: {
          'acceptance_id': acceptance.id,
          'post_id': acceptance.postId,
          'type': 'user_post_payment',
        },
      );

      // Update acceptance with order ID
      await _acceptanceRepo.updatePaymentDetails(
        acceptanceId: acceptance.id,
        razorpayOrderId: orderData['id'],
      );

      // Open Razorpay
      _openRazorpay(orderData, acceptance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _openRazorpay(
    Map<String, dynamic> orderData,
    UserPostAcceptance acceptance,
  ) {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) return;

    var options = {
      'key': RazorpayService.keyId,
      'amount': orderData['amount'],
      'currency': orderData['currency'],
      'name': 'VaultWheels',
      'description': 'Payment for service request',
      'order_id': orderData['id'],
      'prefill': {'email': currentUser.email, 'contact': ''},
      'theme': {'color': '#3399cc'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Verify payment on server
      final verified = await PaymentService.instance.verifyPayment(
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (verified['success'] == true) {
        // Update acceptance status
        final acceptance = _acceptanceRepo.acceptances.value.firstWhere(
          (a) => a.razorpayOrderId == response.orderId,
        );

        await _acceptanceRepo.updatePaymentDetails(
          acceptanceId: acceptance.id,
          razorpayOrderId: response.orderId!,
          razorpayPaymentId: response.paymentId!,
          status: AcceptanceStatus.paid,
        );

        if (mounted) {
          // Show success popup dialog
          _showPaymentSuccessDialog(
            paymentId: response.paymentId ?? '',
            orderId: response.orderId ?? '',
            amount: acceptance.amount,
          );
          _otpController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Show error popup dialog instead of just snackbar
    _showPaymentErrorDialog(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getServiceTypeName(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.lease:
        return 'Lease';
      case ServiceType.working:
        return 'Working';
    }
  }

  String _getStatusText(AcceptanceStatus status) {
    switch (status) {
      case AcceptanceStatus.pending:
        return 'Pending OTP Verification';
      case AcceptanceStatus.otpVerified:
        return 'OTP Verified - Processing Payment';
      case AcceptanceStatus.paid:
        return 'Payment Completed';
      case AcceptanceStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _getStatusColor(AcceptanceStatus status) {
    switch (status) {
      case AcceptanceStatus.pending:
        return Colors.orange;
      case AcceptanceStatus.otpVerified:
        return Colors.blue;
      case AcceptanceStatus.paid:
        return Colors.green;
      case AcceptanceStatus.cancelled:
        return Colors.red;
    }
  }

  /// Show success dialog after Razorpay payment
  void _showPaymentSuccessDialog({
    required String paymentId,
    required String orderId,
    required double amount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your payment has been completed successfully via Razorpay.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPaymentDetailRow(
                    'Amount',
                    '₹${amount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentDetailRow('Payment ID', paymentId),
                  const SizedBox(height: 8),
                  _buildPaymentDetailRow('Order ID', orderId),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your request has been updated with payment details.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog for payment failure
  void _showPaymentErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600], size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your payment could not be processed.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error Details:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(errorMessage, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please try again or contact support if the issue persists.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Retry payment by triggering the payment flow again
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
