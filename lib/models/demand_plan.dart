enum DemandPlan {
  basic,
  verified,
  expert,
}

extension DemandPlanExtension on DemandPlan {
  String get displayName {
    switch (this) {
      case DemandPlan.basic:
        return 'Basic (Everyone)';
      case DemandPlan.verified:
        return 'Verified Users Only';
      case DemandPlan.expert:
        return 'Expert Users Only';
    }
  }
  
  String get description {
    switch (this) {
      case DemandPlan.basic:
        return 'Anyone can book this post';
      case DemandPlan.verified:
        return 'Requires verified Aadhaar, PAN, or Driving License';
      case DemandPlan.expert:
        return 'Requires 50+ trips with 4.5+ rating';
    }
  }
  
  String get dbValue {
    switch (this) {
      case DemandPlan.basic:
        return 'basic';
      case DemandPlan.verified:
        return 'verified';
      case DemandPlan.expert:
        return 'expert';
    }
  }
  
  static DemandPlan fromDbValue(String? value) {
    switch (value) {
      case 'verified':
        return DemandPlan.verified;
      case 'expert':
        return DemandPlan.expert;
      case 'basic':
      default:
        return DemandPlan.basic;
    }
  }
}
