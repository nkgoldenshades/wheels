# 🚗 VaultWheels - Complete App Overview

## 📱 What is VaultWheels?

**VaultWheels** is a comprehensive peer-to-peer mobility marketplace that connects vehicle owners (providers) with customers who need transportation or delivery services. Think of it as a combination of Uber, Airbnb for vehicles, and a parcel delivery service - all in one platform.

---

## 🎯 Core Concept

VaultWheels enables vehicle owners to monetize their vehicles by offering three distinct service types:

### 1. **🚕 Passenger Transport (Ride-Sharing)**
- Customers book seats in vehicles for point-to-point travel
- Similar to carpooling or shared taxi services
- Providers create "posts" (trips) with routes, timings, and pricing
- Customers can book individual seats or charter the entire vehicle

### 2. **📦 Parcel Delivery**
- Customers send packages using available vehicle capacity
- Providers transport parcels along their existing routes
- Efficient use of empty vehicle space
- Tracked delivery with OTP verification

### 3. **🚙 Vehicle Lease (Rental)**
- Customers rent entire vehicles for a period
- Short-term or long-term rentals
- Security deposit system for protection
- Full vehicle documentation and insurance verification

---

## 🔑 Key Features

### **For Customers (Riders/Renters)**

#### Booking Modes
1. **Instant Booking** - Book immediately and get confirmed
2. **Wait for Full** - Wait until all seats are filled before trip starts
3. **Full Post (Charter)** - Book all remaining seats/capacity at once

#### Smart Search & Discovery
- **Map-based browsing** - See available vehicles and posts on an interactive map
- **Filter by service type** - Passenger, parcel, or lease
- **Real-time availability** - Live updates on seat availability
- **Provider ratings** - See reviews and ratings before booking

#### Secure Payment System
- **Multi-currency support** - INR (Razorpay), USD/EUR/etc (Stripe)
- **Payment escrow** - Money held securely until service completion
- **OTP verification** - Secure handoff with 6-digit OTP
- **Automatic refunds** - If service is cancelled or not delivered

#### Safety & Trust
- **OTP verification** - 5-attempt limit with auto-lock
- **Provider verification** - All documents verified (RC, insurance, DL)
- **Real-time tracking** - GPS tracking of vehicles
- **Rating system** - Rate providers after each trip

### **For Providers (Vehicle Owners)**

#### Vehicle Management
- **Multi-vehicle support** - Manage multiple vehicles from one account
- **Document verification** - Upload RC, insurance, pollution certificate
- **GPS tracking** - Live location, external link, or manual updates
- **Photo gallery** - Showcase your vehicle with multiple images

#### Post Creation (Service Listings)
- **Flexible scheduling** - Set departure times, routes, and pricing
- **Seat layout management** - Define seating arrangements
- **Gender preferences** - Optional gender-specific seat allocation
- **Dynamic pricing** - Set your own rates per seat/km

#### Revenue Management
- **Instant payouts** - Get paid after OTP verification
- **Commission structure** - Platform takes a small percentage
- **Security deposits** - For lease bookings
- **Earnings dashboard** - Track your income

#### Verification & Trust
- **Mandatory documents**:
  - Registration Certificate (RC) - Front & back
  - Insurance policy with expiry date
  - Driver's License (DL)
- **Optional documents** (increase trust):
  - Pollution Certificate (PUC)
  - Fitness Certificate
  - Aadhaar (identity proof)
  - PAN card
- **Operator details** - Add driver/operator information

---

## 🔄 How It Works

### **Customer Journey**

1. **Browse & Search**
   - Open app → See map with available vehicles/posts
   - Filter by service type (passenger/parcel/lease)
   - View details: route, timing, price, provider rating

2. **Book & Pay**
   - Select seats or full vehicle
   - Enter passenger/parcel details
   - Choose payment method (Razorpay/Stripe)
   - Payment held in escrow

3. **Travel/Delivery**
   - Receive booking confirmation with OTP
   - Meet provider at pickup location
   - Share OTP to verify handoff
   - Track journey in real-time

4. **Complete & Rate**
   - Provider enters OTP at destination
   - Payment released to provider
   - Rate your experience
   - Automatic refund if issues occur

### **Provider Journey**

1. **Register Vehicle**
   - Add vehicle details (type, brand, model, capacity)
   - Upload mandatory documents (RC, insurance, DL)
   - Add photos and videos
   - Wait for verification (or start with unverified status)

2. **Create Post (Service Listing)**
   - Choose service type (passenger/parcel/lease)
   - Set route (from → to) or base location + radius
   - Define timing (start/end time)
   - Set pricing and capacity
   - Choose booking mode (instant/wait-for-full/full-post)

3. **Receive Bookings**
   - Get notified when customers book
   - View passenger/parcel details
   - Receive OTP for verification
   - Track booking status

4. **Complete Service**
   - Meet customer at pickup
   - Verify OTP (customer shares 6-digit code)
   - Complete journey/delivery
   - Enter OTP at destination
   - Receive payment automatically

5. **Manage Earnings**
   - View completed bookings
   - Track earnings and commissions
   - Receive payouts to bank account

---

## 💰 Payment System

### **Multi-Gateway Support**

#### **India (INR) → Razorpay**
- Local payment gateway for Indian users
- Supports UPI, cards, net banking, wallets
- Lower transaction fees
- Instant payment confirmation

#### **International → Stripe**
- Global payment gateway for non-Indian users
- Supports 135+ currencies
- Stripe Connect for provider payouts
- Payment escrow with automatic release

### **Payment Flow**

1. **Customer pays** → Money held in escrow
2. **Service starts** → OTP verification at pickup
3. **Service completes** → OTP verification at destination
4. **Payment released** → Provider receives funds (minus commission)
5. **Refund if needed** → Automatic refund if service cancelled

### **Security Features**

- **OTP verification** - 6-digit code generated by backend
- **5-attempt limit** - Booking locked after 5 wrong OTP attempts
- **Escrow protection** - Money held until service completion
- **Automatic refunds** - If provider cancels or doesn't show up
- **Commission deduction** - Platform fee deducted automatically

---

## 🗺️ Location & Mapping

### **Interactive Map**
- **Flutter Map** with OpenStreetMap tiles
- **Marker clustering** for dense areas
- **Offline caching** for better performance
- **Real-time vehicle tracking**

### **Location Types**

1. **Point-to-Point** (Passenger transport)
   - From location → To location
   - Route displayed on map
   - Distance and duration calculated

2. **Radius-based** (Parcel delivery, some services)
   - Base location + radius (e.g., 10km)
   - Service available within circle
   - Flexible pickup/delivery points

3. **GPS Tracking**
   - **Device Live** - Real-time GPS from device
   - **External Link** - Link to external GPS tracker
   - **Manual** - Provider manually updates location

---

## 🔐 Security & Verification

### **OTP System**

#### **Generation**
- Backend generates 6-digit OTP when booking is created
- Stored in database (encrypted)
- Sent to both customer and provider

#### **Verification**
- Customer shares OTP with provider at pickup
- Provider enters OTP in app
- Backend validates and increments attempt counter
- After 5 failed attempts → Booking locked
- On success → `otp_verified = true`, `otp_attempts = NULL`

#### **Security Rules**
- OTP generated by backend (NOT frontend)
- Attempts tracked in database
- NULL = 0 attempts (saves storage)
- Locked bookings cannot be unlocked (contact support)

### **Document Verification**

#### **Mandatory for Providers**
- ✅ Registration Certificate (RC) - Front & back images
- ✅ Insurance policy - Number, expiry date, document
- ✅ Driver's License (DL) - Image and verification

#### **Optional (Increases Trust)**
- Pollution Certificate (PUC) - Document and expiry
- Fitness Certificate - Document and expiry
- Aadhaar - Identity proof
- PAN card - Tax identification

#### **Verification Status**
- `isFullyVerified` - All mandatory docs verified + not expired
- `hasMandatoryDocuments` - Documents uploaded but may not be verified
- Verified vehicles get priority in search results

---

## 📊 Data Architecture

### **Backend: Supabase (PostgreSQL)**

#### **Key Tables**

1. **`profiles`** - User accounts
   - Firebase Auth JWT → Supabase RLS
   - Customer and provider profiles
   - KYC verification status

2. **`vehicles`** - Vehicle listings
   - Owner: `profile_id`
   - Documents: RC, insurance, DL, etc.
   - Statistics: ratings, bookings, active posts

3. **`posts`** - Service listings (trips/rentals)
   - Vehicle: `vehicle_id`
   - Provider: `profile_id`
   - Route, timing, pricing
   - Booking mode: instant/wait-for-full/full-post

4. **`bookings`** - Customer bookings
   - Customer: `profile_customer_id`
   - Provider: `profile_provider_id`
   - Post: `post_id`
   - OTP: `otp_code`, `otp_verified`, `otp_attempts`
   - Payment: `payment_gateway_id`, `price_snapshot`
   - Status: pending/accepted/completed/rejected/refunded

5. **`seat_layouts`** - Vehicle seating arrangements
   - Grid-based layout (rows × columns)
   - Seat types: driver, passenger, empty, blocked
   - Gender preferences per seat

### **Frontend: Flutter**

#### **State Management**
- **ValueNotifier** - Reactive state updates
- **Repositories** - Singleton pattern for data management
- **Local storage** - SharedPreferences for offline support

#### **Key Services**

1. **AuthRepository** - Firebase Authentication
2. **ProfileRepository** - User profile management
3. **VehicleRepository** - Vehicle CRUD operations
4. **SlotRepository** - Post/slot management
5. **BookingRepository** - Booking lifecycle
6. **PaymentService** - Payment gateway routing
7. **OtpService** - OTP verification
8. **CurrencyService** - Multi-currency support

---

## 🌍 Multi-Currency & Localization

### **Currency Support**
- **INR** (Indian Rupee) - Default for India
- **USD** (US Dollar) - International
- **EUR** (Euro) - Europe
- **GBP** (British Pound) - UK
- And more...

### **Currency Detection**
- Based on vehicle location
- Extracted from location string: `Name|lat,lon|district,state,postcode,country,CC`
- Country code (CC) determines currency
- Payment gateway selected automatically

### **Localization**
- **smart_translate_text** package
- Multi-language support
- Date/time formatting per locale
- Currency formatting per region

---

## 🎨 User Interface

### **Main Screens**

1. **Home/Map Screen**
   - Interactive map with vehicle markers
   - Filter by service type
   - Search and browse posts
   - Real-time updates

2. **Profile Screen**
   - User information
   - My Vehicles (for providers)
   - My Bookings (for customers)
   - My Posts (for providers)
   - Earnings dashboard

3. **Vehicle Management**
   - Add/edit vehicles
   - Upload documents
   - View verification status
   - Manage operators

4. **Post Creation**
   - Select vehicle
   - Choose service type
   - Set route and timing
   - Define pricing
   - Configure booking mode

5. **Booking Details**
   - View booking information
   - OTP verification
   - Track journey
   - Contact provider/customer
   - Rate and review

6. **Payment Screen**
   - Select payment method
   - Enter payment details
   - Confirm booking
   - View payment status

---

## 🚀 Technical Stack

### **Frontend**
- **Flutter** 3.10+ (Dart)
- **flutter_map** - Interactive maps
- **geolocator** - GPS location
- **image_picker** - Photo uploads
- **camera** - Camera access
- **speech_to_text** - Voice input
- **flutter_tts** - Text-to-speech
- **google_mlkit** - Face detection, text recognition

### **Backend**
- **Supabase** - PostgreSQL database + Auth + Storage
- **Firebase Auth** - User authentication (JWT)
- **Firebase Cloud Functions** - Serverless functions
- **Firebase Vertex AI** - AI features

### **Payment Gateways**
- **Razorpay** - India (INR)
- **Stripe** - International (USD, EUR, etc.)
- **Stripe Connect** - Provider payouts

### **Maps & Location**
- **OpenStreetMap** - Map tiles
- **flutter_map** - Map rendering
- **flutter_map_tile_caching** - Offline maps
- **geodesy** - Distance calculations

---

## 📈 Business Model

### **Revenue Streams**

1. **Commission on Bookings**
   - Platform takes 5-15% commission per booking
   - Deducted automatically from provider payout
   - Varies by service type and region

2. **KYC Verification Fee**
   - One-time fee for document verification
   - ₹49 (India) or $0.99 (international)
   - Increases trust and visibility

3. **Premium Features** (Future)
   - Featured listings
   - Priority support
   - Advanced analytics
   - Bulk booking discounts

### **Value Proposition**

#### **For Customers**
- ✅ Cheaper than traditional taxis/rentals
- ✅ More flexible than public transport
- ✅ Verified and rated providers
- ✅ Secure payment with escrow
- ✅ Real-time tracking

#### **For Providers**
- ✅ Monetize idle vehicle capacity
- ✅ Flexible scheduling
- ✅ Set your own prices
- ✅ Instant payouts
- ✅ Low platform commission

---

## 🔮 Future Enhancements

### **Planned Features**

1. **AI-Powered Matching**
   - Smart route optimization
   - Predictive pricing
   - Demand forecasting

2. **Social Features**
   - Ride-sharing groups
   - Frequent traveler discounts
   - Referral program

3. **Advanced Safety**
   - Emergency SOS button
   - Live journey sharing
   - Insurance integration

4. **Fleet Management**
   - Multi-vehicle operators
   - Driver assignment
   - Maintenance tracking

5. **Analytics Dashboard**
   - Earnings reports
   - Performance metrics
   - Customer insights

---

## 🎯 Target Market

### **Primary Users**

1. **Urban Commuters**
   - Daily office-goers
   - Students
   - Frequent travelers

2. **Vehicle Owners**
   - Private car owners
   - Small fleet operators
   - Taxi/cab drivers

3. **Small Businesses**
   - E-commerce sellers (parcel delivery)
   - Event organizers
   - Tour operators

### **Geographic Focus**

- **Phase 1**: India (INR, Razorpay)
- **Phase 2**: International expansion (USD, EUR, Stripe)
- **Target Cities**: Metro cities first, then tier-2/3 cities

---

## 🏆 Competitive Advantages

1. **Multi-Service Platform**
   - Passenger + Parcel + Lease in one app
   - Maximizes vehicle utilization

2. **Flexible Booking Modes**
   - Instant, wait-for-full, full-post
   - Caters to different customer needs

3. **Strong Security**
   - OTP verification with attempt limits
   - Payment escrow
   - Document verification

4. **Provider-Friendly**
   - Low commission rates
   - Instant payouts
   - Full control over pricing

5. **Technology-Driven**
   - Real-time tracking
   - AI-powered features
   - Offline support

---

## 📞 Support & Contact

### **Customer Support**
- In-app chat support
- Email: support@vaultwheels.com
- Phone: +91-XXXXXXXXXX

### **Provider Support**
- Dedicated provider helpline
- Onboarding assistance
- Document verification support

---

## 📝 Summary

**VaultWheels** is a comprehensive mobility marketplace that:

✅ Connects vehicle owners with customers needing transport/delivery  
✅ Offers 3 service types: Passenger, Parcel, Lease  
✅ Provides 3 booking modes: Instant, Wait-for-Full, Full-Post  
✅ Ensures security with OTP verification and payment escrow  
✅ Supports multi-currency payments (Razorpay + Stripe)  
✅ Verifies all provider documents (RC, insurance, DL)  
✅ Tracks vehicles in real-time with GPS  
✅ Enables providers to monetize idle vehicle capacity  
✅ Gives customers affordable, flexible, and safe mobility options  

**Mission**: Democratize mobility by making every vehicle a potential service provider while ensuring safety, trust, and convenience for all users.

---

*Last Updated: April 19, 2026*
