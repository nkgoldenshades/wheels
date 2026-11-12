# Vehicle Model Updated for Database Schema Compliance

## ✅ **Updated Vehicle Model**

The Vehicle model has been updated to match your comprehensive database schema with proper legal document support.

### **🆕 New Fields Added:**

#### **Basic Vehicle Info:**
- `brand` (String?) - Vehicle brand (e.g., "Maruti", "Honda")
- `model` (String?) - Vehicle model (e.g., "Swift", "City")
- `color` (String?) - Vehicle color
- `registrationNumber` (String?) - **MANDATORY** - License plate number
- `seatingCapacity` (int?) - Number of seats

#### **📋 Legal Documents - MANDATORY:**
- `rcFrontUrl` (String?) - Registration Certificate front image
- `rcBackUrl` (String?) - Registration Certificate back image
- `insuranceNumber` (String?) - Insurance policy number
- `insuranceExpiry` (DateTime?) - Insurance expiry date
- `insuranceDocumentUrl` (String?) - Insurance document file

#### **🌱 Compliance Certificates - OPTIONAL:**
- `pollutionCertificateUrl` (String?) - PUC certificate
- `pollutionExpiry` (DateTime?) - PUC expiry date
- `fitnessCertificateUrl` (String?) - Fitness certificate
- `fitnessExpiry` (DateTime?) - Fitness expiry date

### **🔍 Smart Validation:**

#### **`hasMandatoryDocuments`** - Checks if required docs are present:
- Registration number exists
- RC images (front or back) uploaded
- Insurance number and document provided

#### **`isFullyVerified`** - Checks if all docs are verified and valid:
- RC verified
- Insurance verified and not expired
- Driver's license verified
- Optional certificates not expired (if provided)

### **🗄️ Database Schema Mapping:**

#### **Supabase Fields → Model Fields:**
- `profile_id` → `userId`
- `vehicle_type` → `type`
- `vehicle_photo_url` → `profileImage`
- `registration_number` → `registrationNumber`
- `seating_capacity` → `seatingCapacity`
- `rc_front_url` → `rcFrontUrl`
- `rc_back_url` → `rcBackUrl`
- `insurance_number` → `insuranceNumber`
- `insurance_expiry` → `insuranceExpiry`
- `insurance_document_url` → `insuranceDocumentUrl`
- `pollution_certificate_url` → `pollutionCertificateUrl`
- `pollution_expiry` → `pollutionExpiry`
- `fitness_certificate_url` → `fitnessCertificateUrl`
- `fitness_expiry` → `fitnessExpiry`

### **📱 UI Impact:**

The vehicle detail screen you showed will now properly display:

#### **✅ MANDATORY (Required by Law):**
- **RC Book** - Front and back images required
- **Insurance** - Policy number and document required

#### **⭐ OPTIONAL (Increases Trust):**
- **Driving License** - For operator verification
- **National ID** - Identity verification
- **Tax ID** - Business verification
- **Pollution Certificate** - Environmental compliance
- **Fitness Certificate** - Vehicle roadworthiness

### **🔧 Repository Updates Needed:**

The repositories have been updated to use the correct field mappings:
- `profile_id` instead of `user_id`
- `vehicle_owner` enum instead of `is_user_vehicle`
- Proper document URL fields

### **🚀 Next Steps:**

1. **Update AddVehicleScreen** to collect the new mandatory fields
2. **Add Document Upload** functionality for RC and insurance
3. **Update Vehicle Detail Screen** to show document status
4. **Add Validation** to ensure mandatory documents before posting

### **💡 Benefits:**

- **Legal Compliance**: Matches real-world vehicle registration requirements
- **Trust Building**: Comprehensive document verification increases user confidence
- **Scalability**: Supports different document types for different regions
- **Flexibility**: Optional documents allow gradual verification process

The model now fully supports the comprehensive legal document system shown in your vehicle detail screen!
