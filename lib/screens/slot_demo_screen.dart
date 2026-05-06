import 'package:flutter/material.dart';
import '../models/slot.dart';
import '../models/vehicle.dart';
import '../models/service_type.dart';
import '../models/slot_type.dart';
import '../models/pickup_mode.dart';
import '../services/auth_repository.dart';
import '../widgets/slot_card.dart';

class SlotDemoScreen extends StatelessWidget {
  const SlotDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data for demonstration
    final currentUserId = AuthRepository.instance.currentUser?.id ?? 'demo-user';
    
    final sampleSlot = Slot(
      id: '1',
      profileId: currentUserId,
      vehicleId: 'v1',
      serviceType: ServiceType.passenger,
      slotType: SlotType.fromTo,
      fromLocation: 'Chennai',
      toLocation: 'Madurai',
      startTime: DateTime(2024, 1, 26, 10, 0),
      endTime: DateTime(2024, 1, 26, 14, 0),
      price: 800.0,
      capacity: 3,
      notes: 'Shared ride, luggage allowed',
      images: [],
      createdAt: DateTime.now(),
      pickupOption: PickupMode.customerPickup,
      withOperator: true,
    );

    final sampleVehicle = Vehicle(
      id: 'v1',
      userId: AuthRepository.instance.currentUser?.id ?? '',
      userName: AuthRepository.instance.currentUser?.profileName ?? 'Demo User',
      name: 'Swift',
      type: 'Car',
      year: 2020,
      capabilities: [ServiceType.passenger],
      profileImage: null,
      galleryImages: const [],
      createdAt: DateTime.now(),
      gpsMode: VehicleGpsMode.manual,
      manualLat: 13.0827,
      manualLng: 80.2707,
    );

    final sampleSlot2 = Slot(
      id: '2',
      profileId: currentUserId,
      vehicleId: 'v2',
      serviceType: ServiceType.parcel,
      slotType: SlotType.fromRange,
      baseLocation: 'Bangalore',
      radius: 15.0,
      startTime: DateTime(2024, 1, 26, 9, 0),
      endTime: DateTime(2024, 1, 26, 18, 0),
      price: 50.0,
      capacity: 2,
      notes: 'Same-day delivery available',
      images: [],
      createdAt: DateTime.now(),
      pickupOption: PickupMode.providerPickup,
      withOperator: false,
    );

    final sampleVehicle2 = Vehicle(
      id: 'v2',
      userId: AuthRepository.instance.currentUser?.id ?? '',
      userName: AuthRepository.instance.currentUser?.profileName ?? 'Demo User',
      name: 'Delivery Van',
      type: 'Van',
      year: 2022,
      capabilities: [ServiceType.parcel],
      profileImage: null,
      galleryImages: const [],
      createdAt: DateTime.now(),
      gpsMode: VehicleGpsMode.manual,
      manualLat: 12.9716,
      manualLng: 77.5946,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Slot Card Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Passenger Service (From → To)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SlotCard(
            slot: sampleSlot,
            vehicle: sampleVehicle,
            providerName: 'Raj Kumar',
            providerAvatar: 'https://via.placeholder.com/150',
            providerRating: 4.7,
            isOffer: true,
            isUserPost: false, // Demo: provider offering service
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening slot details...')));
            },
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking slot...')));
            },
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Parcel Service (From + Range)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SlotCard(
            slot: sampleSlot2,
            vehicle: sampleVehicle2,
            providerName: 'Express Logistics',
            providerAvatar: 'https://via.placeholder.com/150',
            providerRating: 4.9,
            isOffer: false,
            isUserPost: true, // Demo: user looking for service
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening slot details...')));
            },
            onAction: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Accepting request...')));
            },
          ),
        ],
      ),
    );
  }
}


