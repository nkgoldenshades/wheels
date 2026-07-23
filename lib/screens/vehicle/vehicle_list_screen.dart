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

class VehicleListScreen extends StatefulWidget {
  final bool isUserMode;
  final VehicleRepository? vehicleRepository;

  const VehicleListScreen({
    super.key,
    this.isUserMode = false,
    this.vehicleRepository,
  });

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  VehicleRepository get _vehicleRepo => widget.isUserMode
      ? CustomerVehicleRepository.instance as VehicleRepository
      : widget.vehicleRepository ?? VehicleRepository.instance;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isUserMode) {
      setState(() => _loading = true);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Reload vehicles
        await CustomerVehicleRepository.instance.reload();
        if (CustomerVehicleRepository.instance.allVehicles.isEmpty) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            await CustomerVehicleRepository.instance.reload();
          }
        }

        // Also reload customer posts to ensure post counts are accurate
        debugPrint('🔄 Reloading customer posts for accurate counts...');
        await CustomerSlotRepository.instance.loadSlots();
        debugPrint(
          '✅ Customer posts reloaded: ${CustomerSlotRepository.instance.allSlots.length} posts',
        );

        if (mounted) {
          setState(() => _loading = false);
        }
      });
    }
  }

  Uint8List? _tryDecodePhoto(String? photo) {
    if (photo == null) return null;
    try {
      // If it's a URL, we can't decode it to bytes here - return null
      // The widget should handle NetworkImage separately
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return null; // Will be handled by NetworkImage in the widget
      }

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
        title: Text(
          widget.isUserMode ? 'Needed Vehicles' : 'Providing Vehicles',
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          debugPrint(
            '🔵 Opening AddVehicleScreen, isUserMode=${widget.isUserMode}',
          );

          final vehicle = await Navigator.push<Vehicle>(
            context,
            MaterialPageRoute(builder: (context) => const AddVehicleScreen()),
          );

          debugPrint('🔵 Returned from AddVehicleScreen, vehicle=$vehicle');

          if (vehicle != null) {
            debugPrint(
              '🔵 Saving vehicle to repository, isUserMode=${widget.isUserMode}',
            );

            // Save the vehicle to the appropriate repository
            if (widget.isUserMode) {
              debugPrint('🔵 Adding to CustomerVehicleRepository');
              await CustomerVehicleRepository.instance.addVehicle(vehicle);
              // Force UI refresh after adding
              debugPrint('🔵 Forcing UI rebuild after adding customer vehicle');
              if (mounted) setState(() {});
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
          widget.isUserMode
              ? CustomerVehicleRepository.instance.vehiclesListenable
              : _vehicleRepo.vehiclesListenable,
          widget.isUserMode
              ? CustomerSlotRepository.instance.slotsListenable
              : SlotRepository.instance.slotsListenable,
          widget.isUserMode
              ? CustomerVehicleRepository.instance.onlineStatusListenable
              : _vehicleRepo.onlineStatusListenable,
        ]),
        builder: (context, _) {
          final vehicles = widget.isUserMode
              ? CustomerVehicleRepository
                    .instance
                    .allVehicles // User mode shows all (for browsing)
              : _vehicleRepo
                    .userVehicles; // Provider mode shows only MY vehicles

          debugPrint(
            '🔵 VehicleListScreen builder called: isUserMode=${widget.isUserMode}, vehicles.length=${vehicles.length}',
          );

          if (vehicles.isEmpty) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
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
              final isOnline = widget.isUserMode
                  ? CustomerVehicleRepository.instance.isOnline(v.id)
                  : _vehicleRepo.isOnline(v.id);

              return Card(
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    // For provider mode, go directly to create post (skips VehicleActionsScreen which freezes)
                    if (!widget.isUserMode) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreatePostScreen(
                            serviceType: ServiceType.passenger,
                            initialVehicle: v,
                          ),
                        ),
                      );
                    } else {
                      // For user mode, use VehicleActionsScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: 'vehicle_detail'),
                          builder: (context) => VehicleActionsScreen(
                            vehicleId: v.id,
                            isUserMode: widget.isUserMode,
                            vehicleRepository: widget.isUserMode
                                ? null
                                : _vehicleRepo,
                          ),
                        ),
                      );
                    }
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
                      try {
                        if (widget.isUserMode) {
                          await CustomerVehicleRepository.instance
                              .deleteVehicle(v.id);
                        } else {
                          await _vehicleRepo.removeVehicle(v.id);
                        }

                        // Show success message
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${v.name} deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        // Show error message
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Cannot Delete Vehicle'),
                                ],
                              ),
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              actions: [
                                FilledButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
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
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 18,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
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
                                    const Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '${v.averageRating.toStringAsFixed(1)} (${v.totalRatings})',
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  const Icon(
                                    Icons.history,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      '${v.totalBookings} trips',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.post_add,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: FutureBuilder<int>(
                                      future: widget.isUserMode
                                          ? CustomerSlotRepository.instance
                                                .getTotalPostCountForVehicle(
                                                  v.id,
                                                )
                                          : SlotRepository.instance
                                                .getTotalPostCountForVehicle(
                                                  v.id,
                                                ),
                                      builder: (context, snapshot) {
                                        final count = snapshot.data ?? 0;
                                        return Text(
                                          '$count posts',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        );
                                      },
                                    ),
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
                                if (widget.isUserMode) {
                                  CustomerVehicleRepository.instance.setOnline(
                                    v.id,
                                    value,
                                  );
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
    final imageToShow =
        vehicle.profileImage ??
        (vehicle.galleryImages.isNotEmpty ? vehicle.galleryImages.first : null);

    // No image at all
    if (imageToShow == null || imageToShow.trim().isEmpty) {
      return const Icon(Icons.directions_car);
    }

    // Validate URL format
    String? validatedUrl;
    if (imageToShow.startsWith('http://') ||
        imageToShow.startsWith('https://')) {
      try {
        // Try to parse URL to validate it
        Uri.parse(imageToShow);
        validatedUrl = imageToShow;
      } catch (e) {
        debugPrint('⚠️ Invalid vehicle image URL: $imageToShow, error: $e');
        // Invalid URL, show icon
        return const Icon(Icons.directions_car);
      }
    }

    // Handle network images (HTTP URLs from storage)
    if (validatedUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Image.network(
            validatedUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('⚠️ Failed to load vehicle image: $validatedUrl');
              return const Icon(Icons.directions_car);
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      );
    }

    // Handle base64 images
    final Uint8List? bytes = decode(imageToShow);
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
