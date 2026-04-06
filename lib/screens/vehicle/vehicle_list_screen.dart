import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../../models/service_type.dart';
import '../../models/vehicle.dart';
import '../../services/slot_repository.dart';
import '../../services/vehicle_repository.dart';
import '../../services/customer_vehicle_repository.dart';
import '../../services/customer_slot_repository.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_actions_screen.dart';

class VehicleListScreen extends StatelessWidget {
  final bool isUserMode;
  final VehicleRepository? vehicleRepository;

  VehicleListScreen({super.key, this.isUserMode = false, VehicleRepository? vehicleRepository})
    : vehicleRepository = vehicleRepository ?? (isUserMode ? null : VehicleRepository.instance);
  
  VehicleRepository get _vehicleRepo => isUserMode 
      ? CustomerVehicleRepository.instance as VehicleRepository
      : vehicleRepository!;

  Uint8List? _tryDecodePhoto(String? photo) {
    if (photo == null) return null;
    try {
      final normalized = photo.contains(',') ? photo.split(',').last : photo;
      if (normalized.trim().isEmpty) return null;
      return base64Decode(normalized);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isUserMode ? 'Needed Vehicles' : 'Providing Vehicles'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          debugPrint('🔵 Opening AddVehicleScreen, isUserMode=$isUserMode');
          
          final vehicle = await Navigator.push<Vehicle>(
            context,
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );

          debugPrint('🔵 Returned from AddVehicleScreen, vehicle=$vehicle');

          if (vehicle != null) {
            debugPrint('🔵 Saving vehicle to repository, isUserMode=$isUserMode');
            
            // Save the vehicle to the appropriate repository
            if (isUserMode) {
              debugPrint('🔵 Adding to CustomerVehicleRepository');
              await CustomerVehicleRepository.instance.addVehicle(vehicle);
            } else {
              debugPrint('🔵 Adding to VehicleRepository (provider)');
              await _vehicleRepo.addVehicle(vehicle);
            }
            
            debugPrint('🔵 Vehicle saved successfully');
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vehicle added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            debugPrint('🔵 Vehicle is null - user cancelled or error occurred');
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          isUserMode 
              ? CustomerVehicleRepository.instance.vehiclesListenable
              : _vehicleRepo.vehiclesListenable,
          isUserMode 
              ? CustomerSlotRepository.instance.slotsListenable
              : SlotRepository.instance.slotsListenable,
          isUserMode
              ? CustomerVehicleRepository.instance.onlineStatusListenable
              : _vehicleRepo.onlineStatusListenable,
        ]),
        builder: (context, _) {
          final vehicles = isUserMode 
              ? CustomerVehicleRepository.instance.allVehicles
              : _vehicleRepo.allVehicles;
          if (vehicles.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Add a vehicle first. Then open it to add Passenger / Parcel / Lease posts.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final v = vehicles[index];
              final yearText = v.year != null ? ' ${v.year}' : '';
              final isOnline = isUserMode 
                  ? CustomerVehicleRepository.instance.isOnline(v.id)
                  : _vehicleRepo.isOnline(v.id);
              final servicesCount = isUserMode
                  ? CustomerSlotRepository.instance.allSlots
                      .where((e) => e.slot.vehicleId == v.id)
                      .length
                  : SlotRepository.instance.getSlotsByVehicleId(v.id).length;
              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'vehicle_detail'),
                        builder: (context) => VehicleActionsScreen(
                          vehicleId: v.id,
                          isUserMode: isUserMode,
                          vehicleRepository: isUserMode ? null : _vehicleRepo,
                        ),
                      ),
                    );
                  },
                  onLongPress: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Delete vehicle?'),
                          content: Text('Delete ${v.name}$yearText?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmed == true) {
                      if (isUserMode) {
                        CustomerVehicleRepository.instance.deleteVehicle(v.id);
                      } else {
                        await _vehicleRepo.removeVehicle(v.id);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        _VehicleThumb(vehicle: v, decode: _tryDecodePhoto),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '${v.name}$yearText',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (v.isVerifiedToggle) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified, color: Colors.blue, size: 18),
                                  ],
                                ],
                              ),                              const SizedBox(height: 4),
                              Text(
                                '${v.type} • ${v.capabilities.map((e) => e.displayName).join(', ')}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (v.averageRating > 0) ...[
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${v.averageRating.toStringAsFixed(1)} (${v.totalRatings})',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  const Icon(Icons.history, size: 14, color: Colors.grey),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${v.totalBookings} trips',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.post_add, size: 14, color: Colors.grey),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$servicesCount posts',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                color: isOnline ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Switch(
                              value: isOnline,
                              onChanged: (value) {
                                if (isUserMode) {
                                  CustomerVehicleRepository.instance.setOnline(v.id, value);
                                } else {
                                  _vehicleRepo.setOnline(v.id, value);
                                }
                              },
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _VehicleThumb extends StatelessWidget {
  final Vehicle vehicle;
  final Uint8List? Function(String?) decode;

  const _VehicleThumb({required this.vehicle, required this.decode});

  @override
  Widget build(BuildContext context) {
    // Use profile image if available, otherwise first gallery image
    final imageToShow = vehicle.profileImage ?? 
        (vehicle.galleryImages.isNotEmpty ? vehicle.galleryImages.first : null);
    
    final Uint8List? bytes = imageToShow != null ? decode(imageToShow) : null;

    if (bytes == null) {
      return const Icon(Icons.directions_car);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image_outlined));
          },
        ),
      ),
    );
  }
}
