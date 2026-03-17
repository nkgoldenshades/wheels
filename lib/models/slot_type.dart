enum SlotType {
  fromTo,
  fromRange,
}

extension SlotTypeExtension on SlotType {
  String get displayName {
    switch (this) {
      case SlotType.fromTo:
        return 'From → To';
      case SlotType.fromRange:
        return 'From + Range';
    }
  }
}
