import 'package:flutter/material.dart';
import '../../models/slot.dart';
import '../../models/slot_entry.dart';
import '../../models/service_type.dart';
import '../../models/vehicle.dart';
import '../../services/slot_repository.dart';
import '../../services/vehicle_repository.dart';
import '../../services/auth_repository.dart';
import '../vehicle/vehicle_list_screen.dart';
import '../../utils/timezone_utils.dart';

/// Unified My Posts page - shows all your personal vehicle-based posts
/// Uses SEPARATE repositories from provider section (CustomerVehicleRepository, CustomerSlotRepository)
class MyPostsUnifiedPage extends StatefulWidget {
  const MyPostsUnifiedPage({super.key});

  @override
  State<MyPostsUnifiedPage> createState() => _MyPostsUnifiedPageState();
}

class _MyPostsUnifiedPageState extends State<MyPostsUnifiedPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late TabController _tabController;

  bool _isInsuranceValidNow(Vehicle vehicle) {
    if (!vehicle.insuranceVerified) return false;
    final exp = vehicle.insuranceExpiry;
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }

  bool _isFullyVerified(Vehicle vehicle) {
    return vehicle.rcVerified &&
        _isInsuranceValidNow(vehicle) &&
        vehicle.dlVerified;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Services'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.post_add), text: 'My Posts'),
            Tab(icon: Icon(Icons.directions_car), text: 'My Vehicles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyPostsTab(), _buildMyVehiclesTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOptions(context),
        icon: const Icon(Icons.add),
        label: Text(_selectedTab == 0 ? 'Create Post' : 'Add Vehicle'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildMyPostsTab() {
    return ValueListenableBuilder<List<SlotEntry>>(
      valueListenable: SlotRepository.instance.slotsListenable,
      builder: (context, slots, _) {
        if (slots.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first post to offer services',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleListScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: slots.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final entry = slots[index];
            return _buildPostCard(entry);
          },
        );
      },
    );
  }

  Widget _buildPostCard(SlotEntry entry) {
    final slot = entry.slot;
    final vehicle = entry.vehicle;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.directions_car, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vehicle.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (_isFullyVerified(vehicle)) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 18,
                              color: Color(0xFFFFC107),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '${vehicle.type} • ${vehicle.year}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_getServiceLabel(slot.serviceType)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: _getServiceColor(slot.serviceType),
                ),
              ],
            ),
            const Divider(height: 16),
            // Route info
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _getRouteText(slot),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Time info
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatTimeRange(slot.startTime, slot.endTime),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Price and capacity
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${slot.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${slot.capacity} seats'),
              ],
            ),
            if (slot.notes != null && slot.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                slot.notes!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyVehiclesTab() {
    return ValueListenableBuilder(
      valueListenable: VehicleRepository.instance.vehiclesListenable,
      builder: (context, allVehicles, _) {
        // Filter to show only current user's vehicles
        final currentUser = AuthRepository.instance.currentUser;
        final vehicles = currentUser == null
            ? <Vehicle>[]
            : allVehicles.where((v) => v.userId == currentUser.id).toList();

        if (vehicles.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No vehicles yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first vehicle to start offering services',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleListScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Vehicle'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: vehicles.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  child: const Icon(Icons.directions_car, color: Colors.blue),
                ),
                title: Text(
                  vehicle.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${vehicle.type} • ${vehicle.year}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to vehicle details
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateOptions(BuildContext context) {
    // Both tabs go directly to vehicle list
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VehicleListScreen()),
    );
  }

  String _getRouteText(Slot slot) {
    if (slot.fromLocation != null && slot.toLocation != null) {
      return '${slot.fromLocation} → ${slot.toLocation}';
    }
    if (slot.baseLocation != null) {
      return '${slot.baseLocation} (${slot.radius?.toStringAsFixed(0) ?? 0} km radius)';
    }
    return 'Route not specified';
  }

  String _formatTimeRange(DateTime start, DateTime end) {
    return TimezoneUtils.formatTimeRangeWithTimezone(
      start,
      end,
      show24Hour: true,
    );
  }

  String _getServiceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.lease:
        return 'Help Vehicle';
      case ServiceType.working:
        return 'Working';
    }
  }

  Color _getServiceColor(ServiceType type) {
    switch (type) {
      case ServiceType.passenger:
        return Colors.blue.withValues(alpha: 0.1);
      case ServiceType.parcel:
        return Colors.orange.withValues(alpha: 0.1);
      case ServiceType.lease:
        return Colors.green.withValues(alpha: 0.1);
      case ServiceType.working:
        return Colors.purple.withValues(alpha: 0.1);
    }
  }
}
