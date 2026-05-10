enum ServiceType {
  passenger,
  parcel,
  working,
  lease,
}

extension ServiceTypeExtension on ServiceType {
  String get displayName {
    switch (this) {
      case ServiceType.passenger:
        return 'Passenger';
      case ServiceType.parcel:
        return 'Parcel';
      case ServiceType.working:
        return 'Working';
      case ServiceType.lease:
        return 'Lease';
    }
  }
}



