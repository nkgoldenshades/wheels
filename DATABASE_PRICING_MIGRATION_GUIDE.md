# Database Pricing Migration Guide

## ✅ Migration Complete!

Your pricing system now uses **Supabase database** with **automatic fallback** to hardcoded values if the database is unavailable.

---

## 🎯 What Changed

### Before (Hardcoded):
```dart
// Pricing hardcoded in PlansScreen
final pricing = _getPricing(currency);
```

### After (Database + Fallback):
```dart
// Pricing fetched from database with fallback
final pricing = await PricingService.instance.getPricing(currency);
```

---

## 📁 New Files Created

### 1. **`lib/services/pricing_service.dart`** ✅
Complete service for fetching pricing from Supabase with:
- ✅ Database fetching
- ✅ 1-hour caching (reduces database calls)
- ✅ Automatic fallback to default pricing
- ✅ Preloading support
- ✅ Analytics methods (by continent, tier)
- ✅ Cache management

### 2. **`create_subscription_pricing_table.sql`** ✅
Ready-to-run SQL script with:
- ✅ Table schema
- ✅ All 100+ currencies pre-populated
- ✅ RLS policies (public read, admin write)
- ✅ Helper functions
- ✅ Indexes for performance

### 3. **Updated `lib/main.dart`** ✅
PlansScreen now:
- ✅ Uses FutureBuilder for async database fetching
- ✅ Shows loading indicator while fetching
- ✅ Falls back to hardcoded pricing if database fails
- ✅ Maintains all existing functionality

---

## 🚀 Deployment Steps

### Step 1: Run SQL Script in Supabase

1. Open Supabase Dashboard → SQL Editor
2. Copy contents of `create_subscription_pricing_table.sql`
3. Click "Run" to create table and populate data
4. Verify: `SELECT COUNT(*) FROM subscription_pricing;` should return 100+

### Step 2: Verify RLS Policies

```sql
-- Check that RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'subscription_pricing';

-- Should show: rowsecurity = true
```

### Step 3: Test Database Access

```sql
-- Test fetching pricing for India
SELECT * FROM subscription_pricing WHERE currency_code = 'INR';

-- Test fetching all Tier 1 countries
SELECT * FROM subscription_pricing WHERE tier = 1 AND is_active = true;

-- Test fetching Asia pricing
SELECT * FROM subscription_pricing WHERE continent = 'Asia' AND is_active = true;
```

### Step 4: Test in App

1. Run the app: `flutter run`
2. Navigate to Plans screen
3. Check console logs:
   ```
   [PricingService] Fetching pricing for INR from database
   [PricingService] ✅ Fetched pricing for INR: ₹999
   ```
4. Change currency in settings and verify pricing updates

### Step 5: Test Fallback (Optional)

1. Temporarily disable Supabase connection
2. Navigate to Plans screen
3. Should see fallback message in console:
   ```
   [PlansScreen] Database fetch failed, using hardcoded fallback
   ```
4. Pricing should still display (using hardcoded values)

---

## 🎨 Features

### 1. **Automatic Caching**
```dart
// First call: Fetches from database
final pricing1 = await PricingService.instance.getPricing('INR');

// Second call within 1 hour: Uses cache (no database call)
final pricing2 = await PricingService.instance.getPricing('INR');
```

### 2. **Preloading (Optional)**
```dart
// Preload common currencies at app startup
await PricingService.instance.preloadPricing([
  'USD', 'EUR', 'GBP', 'INR', 'JPY', 'AUD'
]);
```

### 3. **Cache Management**
```dart
// Clear cache to force refresh
PricingService.instance.clearCache();

// Get cache statistics
final stats = PricingService.instance.getCacheStats();
print('Cached currencies: ${stats['cached_currencies']}');
print('Cache age: ${stats['cache_age_minutes']} minutes');
```

### 4. **Analytics Methods**
```dart
// Get all pricing data
final allPricing = await PricingService.instance.getAllPricing();

// Get pricing by continent
final asiaPricing = await PricingService.instance.getPricingByContinent('Asia');

// Get pricing by tier
final tier1Pricing = await PricingService.instance.getPricingByTier(1);
```

---

## 💰 Updating Prices

### Method 1: SQL Query (Direct)
```sql
-- Update India pricing
UPDATE subscription_pricing 
SET 
  premium_monthly = 1099,
  expert_monthly = 5499,
  expert_deposit = 54990,
  updated_at = NOW()
WHERE currency_code = 'INR';

-- Update all Tier 1 countries (10% increase)
UPDATE subscription_pricing 
SET 
  premium_monthly = premium_monthly * 1.10,
  expert_monthly = expert_monthly * 1.10,
  expert_deposit = expert_deposit * 1.10,
  updated_at = NOW()
WHERE tier = 1;
```

### Method 2: Supabase Dashboard (GUI)
1. Go to Table Editor → `subscription_pricing`
2. Find the row (e.g., INR)
3. Click edit icon
4. Update values
5. Save

### Method 3: Admin Panel (Future)
Build an admin panel in your app to update pricing without SQL knowledge.

---

## 🔄 How Fallback Works

### Scenario 1: Database Available ✅
```
User opens Plans screen
  → PricingService fetches from database
  → Pricing displayed from database
  → Cached for 1 hour
```

### Scenario 2: Database Unavailable ⚠️
```
User opens Plans screen
  → PricingService tries database (fails)
  → Falls back to hardcoded pricing
  → Pricing displayed from hardcoded values
  → User sees no error (seamless)
```

### Scenario 3: Cache Hit 🚀
```
User opens Plans screen (within 1 hour of last fetch)
  → PricingService checks cache
  → Pricing displayed from cache (instant)
  → No database call (faster + cheaper)
```

---

## 📊 Performance Benefits

### Before (Hardcoded):
- ✅ Instant (no network call)
- ❌ Requires app redeployment to update prices
- ❌ No A/B testing
- ❌ No analytics

### After (Database):
- ✅ Update prices instantly (no redeployment)
- ✅ A/B testing possible
- ✅ Analytics available
- ✅ Still fast (1-hour cache)
- ✅ Automatic fallback (reliable)

---

## 🛡️ Security (RLS Policies)

### Read Access: Public ✅
```sql
-- Anyone can read active pricing
CREATE POLICY "Anyone can read pricing"
  ON public.subscription_pricing
  FOR SELECT
  USING (is_active = true);
```

### Write Access: Admin Only 🔒
```sql
-- Only admins can modify pricing
CREATE POLICY "Only admins can modify pricing"
  ON public.subscription_pricing
  FOR ALL
  USING (auth.uid() IN (
    SELECT user_id FROM public.admin_users WHERE is_admin = true
  ));
```

**Note:** You'll need to create an `admin_users` table or modify the policy to match your admin authentication system.

---

## 🧪 Testing Checklist

- [ ] SQL script runs successfully in Supabase
- [ ] Table has 100+ rows: `SELECT COUNT(*) FROM subscription_pricing;`
- [ ] RLS is enabled: Check table settings
- [ ] App fetches pricing from database (check console logs)
- [ ] Pricing displays correctly in Plans screen
- [ ] Cache works (second fetch is instant)
- [ ] Fallback works (disable Supabase, pricing still shows)
- [ ] Update a price in database, verify app shows new price after cache expires

---

## 🎯 Next Steps (Optional)

### 1. **Build Admin Panel**
Create a screen in your app for admins to update pricing:
```dart
class AdminPricingScreen extends StatelessWidget {
  // List all pricing
  // Edit pricing
  // View analytics
}
```

### 2. **Add Price History**
Track pricing changes over time:
```sql
CREATE TABLE subscription_pricing_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  currency_code VARCHAR(3),
  old_premium DECIMAL(12, 2),
  new_premium DECIMAL(12, 2),
  changed_by UUID REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3. **A/B Testing**
Test different prices for different user segments:
```sql
ALTER TABLE subscription_pricing 
ADD COLUMN ab_test_group VARCHAR(20),
ADD COLUMN ab_test_premium DECIMAL(12, 2);
```

### 4. **Promotional Pricing**
Add temporary discounts:
```sql
ALTER TABLE subscription_pricing 
ADD COLUMN promo_active BOOLEAN DEFAULT false,
ADD COLUMN promo_premium DECIMAL(12, 2),
ADD COLUMN promo_end_date TIMESTAMPTZ;
```

---

## 📝 Summary

✅ **Database table created** with 100+ currencies  
✅ **PricingService implemented** with caching and fallback  
✅ **PlansScreen updated** to use database  
✅ **Automatic fallback** ensures reliability  
✅ **1-hour caching** for performance  
✅ **RLS policies** for security  
✅ **Helper functions** for analytics  
✅ **Zero breaking changes** - app works exactly as before  

**You can now update prices instantly without app redeployment!** 🎉

---

## 🆘 Troubleshooting

### Issue: "Table doesn't exist"
**Solution:** Run the SQL script in Supabase Dashboard

### Issue: "Permission denied"
**Solution:** Check RLS policies, ensure public read access is enabled

### Issue: "Pricing not updating"
**Solution:** Clear cache: `PricingService.instance.clearCache()`

### Issue: "App shows default pricing"
**Solution:** Check Supabase connection, verify table has data

### Issue: "Slow loading"
**Solution:** Use preloading at app startup for common currencies

---

## 📞 Support

For issues or questions:
1. Check console logs for error messages
2. Verify Supabase table exists and has data
3. Test SQL queries directly in Supabase Dashboard
4. Check RLS policies are configured correctly
