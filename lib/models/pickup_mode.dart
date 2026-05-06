enum PickupMode {
  customerPickup,
  providerPickup,
}

extension PickupModeExtension on PickupMode {
  String get displayTitle {
    switch (this) {
      case PickupMode.customerPickup:
        return 'Customer comes to pickup';
      case PickupMode.providerPickup:
        return 'Provider comes to customer';
    }
  }

  String get shortLabel {
    switch (this) {
      case PickupMode.customerPickup:
        return 'Customer pickup';
      case PickupMode.providerPickup:
        return 'Provider comes to pickup';
    }
  }

  String get icon {
    switch (this) {
      case PickupMode.customerPickup:
        return '🚶';
      case PickupMode.providerPickup:
        return '🚗';
    }
  }
}


