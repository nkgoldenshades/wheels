# New Features Added

## 1. Rating Requirements ⭐
**What**: Posts can require minimum ratings/trips
**Where**: Customer posts (main.dart) 
**Fields**: Min Rating (4.0), Min Trips (10)
**DB**: Already added (min_ratings, min_no_ratings)

## 2. Demand Plan 🎯
**What**: Profile-based access control (Basic/Verified/Expert)
**Where**: Customer posts (main.dart)
**Who**: Checks PROFILE not vehicle. Both customers & providers can be verified/expert
**DB**: Run `add_demand_plan_column.sql`

## Expert Status
50+ trips + 4.5+ rating (as provider OR customer)

## Verified Status  
At least 1 verified doc (Aadhaar/PAN/DL)

## TODO
- [ ] Run SQL migration
- [ ] Add same fields to provider screen (create_post_screen.dart)
- [ ] Test

## Files Modified
- lib/models/demand_plan.dart (new)
- lib/services/user_post_repository.dart
- lib/services/profile_repository.dart
- lib/screens/user_post/user_post_detail_screen.dart
- lib/main.dart
