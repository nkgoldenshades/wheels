# Compilation Errors After Document Removal

**Status:** Expected errors after removing 24 document fields  
**Impact:** App won't compile until these are fixed  
**Estimated Fix Time:** 1-2 hours

---

## Summary of Errors:

### 1. customer_vehicle_repository.dart (60+ errors)
**Problem:** Still trying to access removed vehicle document fields  
**Lines:** 140-283  
**Fields:** rcVerified, rcFrontUrl, rcBackUrl, insuranceNumber, insuranceExpiry, insuranceDocumentUrl, insuranceVerified, pollutionCertificateUrl, pollutionExpiry, fitnessCertificateUrl, fitnessExpiry

**Fix:** Remove all lines trying to access these fields

### 2. customer_slot_repository.dart (2 errors)
**Lines:** 90-91  
**Fields:** rcVerified, insuranceVerified  

**Fix:** Remove these two lines

### 3. slot_repository.dart (3 errors)
**Lines:** 124-128  
**Fields:** rcVerified, insuranceVerified, panVerified

**Fix:** Already partially fixed, remove remaining references

### 4. vehicle_actions_screen.dart (10+ errors)
**Lines:** 584, 1399, 1405, 2515, 2534, 2650, 2656, 2662, 3150  
**Problems:**
- operatorDocumentUrl field removed
- isFullyVerified getter removed  
- updateVehicle method doesn't exist
- Unused _buildDocumentItem methods

**Fix:** 
- Remove operatorDocumentUrl references
- Remove isFullyVerified checks
- Replace updateVehicle with correct method name
- Delete unused document UI builder methods

### 5. user_post_detail_screen.dart (1 error)
**Line:** 470  
**Field:** isFullyVerified

**Fix:** Remove or replace with false

### 6. vehicle_list_screen.dart (3 errors)
**Lines:** 185, 233, 403  
**Methods:** isOnline, removeVehicle, setOnline

**Fix:** Use correct method names from VehicleRepository

### 7. slot_detail_screen.dart (2 errors)
**Lines:** 82, 86  
**Method:** getById

**Fix:** Use correct method name from VehicleRepository

### 8. booking_repository.dart (1 error)
**Line:** 160  
**Method:** getById

**Fix:** Use correct method name from VehicleRepository

### 9. main.dart (1 error)
**Line:** 7936  
**Method:** getById

**Fix:** Use correct method name from VehicleRepository

---

## Quick Fix Strategy:

### Step 1: Fix customer_vehicle_repository.dart (biggest file)
Search and remove all lines with:
- `rcVerified`
- `rcFrontUrl`
- `rcBackUrl`  
- `rcVerifiedAt`
- `insuranceNumber`
- `insuranceExpiry`
- `insuranceDocumentUrl`
- `insuranceVerified`
- `pollutionCertificateUrl`
- `pollutionExpiry`
- `fitnessCertificateUrl`
- `fitnessExpiry`

### Step 2: Fix VehicleRepository method names
The repository probably has different method names. Check:
- `getById` → might be `getVehicleById` or `fetchVehicleById`
- `updateVehicle` → might be `update` or `updateVehicleData`
- `removeVehicle` → might be `delete` or `deleteVehicle`
- `isOnline` → might be `checkOnlineStatus`
- `setOnline` → might be `setVehicleOnline`

Search the VehicleRepository file for actual method names.

### Step 3: Fix remaining files
- Remove all `isFullyVerified` references (return false or remove check)
- Remove all `operatorDocumentUrl` references
- Delete unused `_buildDocumentItem` methods in vehicle_actions_screen.dart

---

## Automated Fix Script (PowerShell):

```powershell
# Remove document field references from customer_vehicle_repository.dart
$file = "lib\services\customer_vehicle_repository.dart"
$content = Get-Content $file
$content = $content | Where-Object { 
    $_ -notmatch "rcVerified|rcFrontUrl|rcBackUrl|insuranceNumber|insuranceExpiry|insuranceDocumentUrl|pollutionCertificate|fitnessCertificate" 
}
$content | Set-Content $file

# Remove from customer_slot_repository.dart  
$file = "lib\services\customer_slot_repository.dart"
$content = Get-Content $file | Where-Object { 
    $_ -notmatch "rcVerified|insuranceVerified" 
}
$content | Set-Content $file

# Remove isFullyVerified checks
Get-ChildItem -Recurse -Filter *.dart | ForEach-Object {
    (Get-Content $_.FullName) -replace 'vehicle\.isFullyVerified', 'false' | Set-Content $_.FullName
}

# Remove operatorDocumentUrl
Get-ChildItem -Recurse -Filter *.dart | ForEach-Object {
    (Get-Content $_.FullName) | Where-Object { $_ -notmatch "operatorDocumentUrl" } | Set-Content $_.FullName
}
```

---

## Manual Fix (Safer):

1. Open `lib/services/customer_vehicle_repository.dart`
2. Find all lines with document fields (Ctrl+F)
3. Delete those lines one by one
4. Save and check errors decrease

5. Open `lib/services/vehicle_repository.dart`
6. Find actual method names for:
   - Getting vehicle by ID
   - Updating vehicle
   - Removing vehicle
   - Setting online status

7. Replace all wrong method calls with correct names

8. Remove `isFullyVerified` checks - replace with `false` or remove entirely

9. Delete `_buildDocumentItem` and `_buildDocumentItemWithExpiry` methods from vehicle_actions_screen.dart (they're unused now)

---

## After Fixing:

```bash
flutter analyze
```

Should show 0 errors!

Then rebuild and redeploy:

```bash
flutter build web --release
firebase deploy --only hosting:quickohunt-app
```

---

## Why These Errors Happened:

We removed 24 document fields from the Vehicle model, but many files were still trying to access them. This is normal when doing large refactoring.

The good news: These are all **compile-time errors** (easy to find and fix), not runtime bugs!

---

## Estimated Time:

- **Customer_vehicle_repository.dart:** 30 minutes
- **Method name fixes:** 20 minutes  
- **Other files:** 20 minutes
- **Testing:** 10 minutes

**Total:** ~1-2 hours of focused work

---

## Priority:

**HIGH** - App won't compile until fixed

But the deployment you did earlier IS still live and working! These errors only affect new builds.

---

**Need help? All the error locations are listed above with line numbers!**
