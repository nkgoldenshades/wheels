enum EventDeliveryMode {
  customerComesToEvent,
  eventGoesToCustomer,
}

extension EventDeliveryModeExtension on EventDeliveryMode {
  String get displayTitle {
    switch (this) {
      case EventDeliveryMode.customerComesToEvent:
        return 'Customer comes to event';
      case EventDeliveryMode.eventGoesToCustomer:
        return 'Event organizer goes to customer';
    }
  }

  String get shortLabel {
    switch (this) {
      case EventDeliveryMode.customerComesToEvent:
        return 'Customer comes';
      case EventDeliveryMode.eventGoesToCustomer:
        return 'We go to customer';
    }
  }

  String get icon {
    switch (this) {
      case EventDeliveryMode.customerComesToEvent:
        return '🏢';
      case EventDeliveryMode.eventGoesToCustomer:
        return '🚚';
    }
  }
}

