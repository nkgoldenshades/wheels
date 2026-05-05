import 'package:flutter/material.dart';
import '../../models/service_type.dart';
import '../../services/vehicle_repository.dart';
import 'create_post_screen.dart';

class ServiceTypeScreen extends StatelessWidget {
  const ServiceTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose Service Type',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        _buildServiceTypeCard(
          context,
          serviceType: ServiceType.passenger,
          icon: Icons.people,
          description: 'Transport passengers from one location to another',
        ),
        const SizedBox(height: 16),
        _buildServiceTypeCard(
          context,
          serviceType: ServiceType.parcel,
          icon: Icons.local_shipping,
          description: 'Deliver parcels and packages',
        ),
        const SizedBox(height: 16),
        _buildServiceTypeCard(
          context,
          serviceType: ServiceType.lease,
          icon: Icons.car_rental,
          description: 'Lease your vehicle to others',
        ),
      ],
    );
  }

  Widget _buildServiceTypeCard(
    BuildContext context, {
    required ServiceType serviceType,
    required IconData icon,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final vehicles = VehicleRepository.instance.allVehicles;
          if (vehicles.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No vehicles available. Please add a vehicle first.')),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostScreen(serviceType: serviceType),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceType.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}

