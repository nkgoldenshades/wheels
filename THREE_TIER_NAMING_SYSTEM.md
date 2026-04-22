# Three-Tier Naming System: User → Customer → Provider

## ✅ Final Naming Convention

### The Three Tiers

1. **User** - General app user (anyone using the app)
2. **Customer** - User looking for/booking services  
3. **Provider** - User offering services

### UI Labels Updated

#### Posts Tab
- **Before**: "Providers Posts" vs "Users Posts"
- **After**: "Provider Posts" vs "Customer Posts" ✅

#### Requests Tab  
- **Before**: "User" vs "Provider"
- **After**: "Customer" vs "Provider" ✅

#### Search Hints
- **Before**: "Search user requests"
- **After**: "Search customer requests" ✅

#### Debug Text
- **Before**: "User Vehicles", "User Posts"
- **After**: "Customer Vehicles", "Customer Posts" ✅

---

## Why This Three-Tier System Works

### Clear Hierarchy
```
User (General)
├── Customer (Looking for services)
└── Provider (Offering services)
```

### Real-World Examples
- **Uber**: User → Rider (Customer) vs Driver (Provider)
- **Airbnb**: User → Guest (Customer) vs Host (Provider)  
- **Your App**: User → Passenger (Customer) vs Vehicle Owner (Provider)

### Database Consistency
```sql
-- Database already uses this correctly
CREATE TABLE bookings (
  customer_id TEXT NOT NULL,  -- ✅ Customer
  provider_id TEXT NOT NULL,  -- ✅ Provider
  -- Both are users, but with different roles
);
```

---

## Code Structure

### Repositories
- `CustomerVehicleRepository` - Vehicles customers are looking for
- `CustomerSlotRepository` - Service requests from customers
- `VehicleRepository` - Vehicles providers own
- `SlotRepository` - Services providers offer

### UI Flow
```
User opens app
├── Customer Mode: Browse/book services
│   ├── Uses CustomerVehicleRepository
│   └── Uses CustomerSlotRepository
└── Provider Mode: Offer services  
    ├── Uses VehicleRepository
    └── Uses SlotRepository
```

---

## Benefits Achieved

1. **✅ Clear Terminology** - No confusion between "user" and "customer"
2. **✅ Industry Standard** - Matches Uber, Airbnb naming
3. **✅ Database Aligned** - Frontend matches database naming
4. **✅ Role Clarity** - Same person can be both customer and provider
5. **✅ UI Consistency** - All labels use consistent terminology

---

## What Each Term Means

| Term | Meaning | Example |
|------|---------|---------|
| **User** | Anyone using the app | John downloads the app |
| **Customer** | User looking for services | John needs a ride → Customer mode |
| **Provider** | User offering services | John offers his car → Provider mode |

### Dual Role Example
```
John (User) can be:
├── Customer: "I need a ride to airport" 
└── Provider: "I'm offering rides in my car"

Same person, different roles, separate data!
```

---

## Summary

The three-tier system provides:
- **User** = General term for app users
- **Customer** = Specific role when looking for services
- **Provider** = Specific role when offering services

This matches industry standards and eliminates the confusion between "user" and "customer" while maintaining the dual-role capability where one person can be both! 🎉
