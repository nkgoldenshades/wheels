-- ============================================================================
-- SUBSCRIPTION PRICING TABLE
-- ============================================================================
-- This table stores dynamic pricing for subscription plans across all countries
-- Allows easy updates without app redeployment
-- ============================================================================

-- Drop existing table if it exists
DROP TABLE IF EXISTS public.subscription_pricing CASCADE;

-- Create subscription pricing table
CREATE TABLE public.subscription_pricing (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  currency_code VARCHAR(3) NOT NULL UNIQUE,
  currency_symbol VARCHAR(10) NOT NULL,
  country_name VARCHAR(100),
  continent VARCHAR(50) NOT NULL,
  tier INTEGER NOT NULL CHECK (tier IN (1, 2, 3)),
  premium_monthly DECIMAL(12, 2) NOT NULL,
  expert_monthly DECIMAL(12, 2) NOT NULL,
  expert_deposit DECIMAL(12, 2) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for fast lookups
CREATE INDEX idx_subscription_pricing_currency ON public.subscription_pricing(currency_code);
CREATE INDEX idx_subscription_pricing_continent ON public.subscription_pricing(continent);
CREATE INDEX idx_subscription_pricing_tier ON public.subscription_pricing(tier);
CREATE INDEX idx_subscription_pricing_active ON public.subscription_pricing(is_active);

-- Enable RLS
ALTER TABLE public.subscription_pricing ENABLE ROW LEVEL SECURITY;

-- Allow everyone to read pricing (public data)
CREATE POLICY "Anyone can read pricing"
  ON public.subscription_pricing
  FOR SELECT
  USING (is_active = true);

-- Only admins can modify pricing (add your admin check here)
CREATE POLICY "Only admins can modify pricing"
  ON public.subscription_pricing
  FOR ALL
  USING (auth.uid() IN (
    SELECT user_id FROM public.admin_users WHERE is_admin = true
  ));

-- ============================================================================
-- INSERT PRICING DATA - ORGANIZED BY CONTINENT
-- ============================================================================

-- NORTH AMERICA
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('USD', '$', 'United States', 'North America', 1, 12.99, 59.99, 599),
('CAD', 'C$', 'Canada', 'North America', 1, 17.99, 83.99, 839),
('MXN', 'MX$', 'Mexico', 'North America', 2, 219, 1069, 10690);

-- SOUTH AMERICA
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('BRL', 'R$', 'Brazil', 'South America', 2, 65, 319, 3190),
('ARS', 'AR$', 'Argentina', 'South America', 2, 12000, 58800, 588000),
('CLP', 'CLP$', 'Chile', 'South America', 2, 11690, 57290, 572900),
('COP', 'COL$', 'Colombia', 'South America', 2, 50400, 246900, 2469000),
('PEN', 'S/', 'Peru', 'South America', 2, 45, 220, 2200),
('UYU', 'UY$', 'Uruguay', 'South America', 2, 504, 2469, 24690),
('BOB', 'Bs', 'Bolivia', 'South America', 3, 41, 205, 2050),
('PYG', '₲', 'Paraguay', 'South America', 3, 44000, 220000, 2200000);

-- EUROPE
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('EUR', '€', 'Eurozone (27 countries)', 'Europe', 1, 11.99, 54.99, 549),
('GBP', '£', 'United Kingdom', 'Europe', 1, 10.99, 49.99, 499),
('CHF', 'CHF ', 'Switzerland', 'Europe', 1, 11.49, 52.99, 529),
('SEK', 'kr', 'Sweden', 'Europe', 1, 139, 644, 6440),
('NOK', 'kr', 'Norway', 'Europe', 1, 139, 644, 6440),
('DKK', 'kr', 'Denmark', 'Europe', 1, 89, 412, 4120),
('ISK', 'kr', 'Iceland', 'Europe', 1, 1799, 8329, 83290),
('PLN', 'zł', 'Poland', 'Europe', 2, 49, 239, 2390),
('CZK', 'Kč', 'Czech Republic', 'Europe', 2, 279, 1369, 13690),
('HUF', 'Ft', 'Hungary', 'Europe', 2, 4390, 21490, 214900),
('RON', 'lei', 'Romania', 'Europe', 2, 55, 269, 2690),
('BGN', 'лв', 'Bulgaria', 'Europe', 2, 21.99, 107.69, 1076),
('HRK', 'kn', 'Croatia', 'Europe', 2, 82, 402, 4020),
('RSD', 'дин', 'Serbia', 'Europe', 2, 1290, 6318, 63180),
('UAH', '₴', 'Ukraine', 'Europe', 2, 494, 2419, 24190),
('RUB', '₽', 'Russia', 'Europe', 2, 1109, 5429, 54290);

-- ASIA - EAST ASIA (Tier 1)
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('JPY', '¥', 'Japan', 'Asia', 1, 1899, 8799, 87990),
('KRW', '₩', 'South Korea', 'Asia', 1, 17299, 80199, 801990),
('TWD', 'NT$', 'Taiwan', 'Asia', 1, 412, 1908, 19080),
('HKD', 'HK$', 'Hong Kong', 'Asia', 1, 101, 468, 4680),
('SGD', 'S$', 'Singapore', 'Asia', 1, 17.49, 80.99, 809);

-- ASIA - SOUTH & SOUTHEAST ASIA (Tier 2)
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('INR', '₹', 'India', 'Asia', 2, 999, 4999, 50000),
('CNY', '¥', 'China', 'Asia', 2, 87, 426, 4260),
('THB', '฿', 'Thailand', 'Asia', 2, 429, 2099, 20990),
('MYR', 'RM', 'Malaysia', 'Asia', 2, 56, 274, 2740),
('IDR', 'Rp', 'Indonesia', 'Asia', 2, 189000, 926000, 9260000),
('TRY', '₺', 'Turkey', 'Asia', 2, 409, 2004, 20040);

-- ASIA - SOUTH & SOUTHEAST ASIA (Tier 3)
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('PKR', 'Rs', 'Pakistan', 'Asia', 3, 1665, 8325, 83250),
('BDT', '৳', 'Bangladesh', 'Asia', 3, 660, 3300, 33000),
('VND', '₫', 'Vietnam', 'Asia', 3, 149000, 745000, 7450000),
('PHP', '₱', 'Philippines', 'Asia', 3, 335, 1675, 16750),
('LKR', 'Rs', 'Sri Lanka', 'Asia', 3, 1950, 9750, 97500),
('NPR', 'Rs', 'Nepal', 'Asia', 3, 795, 3975, 39750),
('MMK', 'K', 'Myanmar', 'Asia', 3, 12575, 62875, 628750),
('KHR', '៛', 'Cambodia', 'Asia', 3, 24500, 122500, 1225000),
('LAK', '₭', 'Laos', 'Asia', 3, 131000, 655000, 6550000);

-- ASIA - CENTRAL ASIA
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('KZT', '₸', 'Kazakhstan', 'Asia', 2, 5490, 26890, 268900),
('GEL', '₾', 'Georgia', 'Asia', 2, 33, 161, 1610),
('AMD', '֏', 'Armenia', 'Asia', 2, 4640, 22740, 227400),
('AZN', '₼', 'Azerbaijan', 'Asia', 2, 20.39, 99.89, 998),
('UZS', 'soʻm', 'Uzbekistan', 'Asia', 3, 76000, 380000, 3800000),
('TJS', 'ЅМ', 'Tajikistan', 'Asia', 3, 65, 325, 3250),
('KGS', 'с', 'Kyrgyzstan', 'Asia', 3, 520, 2600, 26000),
('AFN', '؋', 'Afghanistan', 'Asia', 3, 425, 2125, 21250);

-- MIDDLE EAST - GULF STATES (Tier 1)
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('AED', 'AED ', 'UAE', 'Middle East', 1, 47.69, 220.49, 2204),
('SAR', 'SAR ', 'Saudi Arabia', 'Middle East', 1, 48.69, 224.99, 2249),
('QAR', 'QAR ', 'Qatar', 'Middle East', 1, 47.29, 218.49, 2184),
('KWD', 'KWD ', 'Kuwait', 'Middle East', 1, 3.99, 18.49, 184),
('BHD', 'BHD ', 'Bahrain', 'Middle East', 1, 4.89, 22.59, 225),
('OMR', 'OMR ', 'Oman', 'Middle East', 1, 4.99, 23.09, 230),
('ILS', '₪', 'Israel', 'Middle East', 1, 47.99, 221.99, 2219);

-- MIDDLE EAST - OTHER (Tier 2 & 3)
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('EGP', 'E£', 'Egypt', 'Middle East', 2, 370, 1814, 18140),
('LBP', 'ل.ل', 'Lebanon', 'Middle East', 3, 535000, 2675000, 26750000),
('IQD', 'ع.د', 'Iraq', 'Middle East', 3, 7840, 39200, 392000),
('JOD', 'د.ا', 'Jordan', 'Middle East', 3, 4.25, 21.25, 212),
('SYP', '£S', 'Syria', 'Middle East', 3, 75500, 377500, 3775000),
('YER', '﷼', 'Yemen', 'Middle East', 3, 1500, 7500, 75000),
('IRR', '﷼', 'Iran', 'Middle East', 3, 252000, 1260000, 12600000);

-- AFRICA - NORTH AFRICA
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('ZAR', 'R', 'South Africa', 'Africa', 2, 219, 1074, 10740),
('MAD', 'د.م.', 'Morocco', 'Africa', 3, 59, 295, 2950),
('TND', 'د.ت', 'Tunisia', 'Africa', 3, 18.50, 92.50, 925),
('DZD', 'د.ج', 'Algeria', 'Africa', 3, 805, 4025, 40250);

-- AFRICA - SUB-SAHARAN
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('NGN', '₦', 'Nigeria', 'Africa', 3, 9500, 47500, 475000),
('KES', 'KSh', 'Kenya', 'Africa', 3, 775, 3875, 38750),
('GHS', 'GH₵', 'Ghana', 'Africa', 3, 95, 475, 4750),
('TZS', 'TSh', 'Tanzania', 'Africa', 3, 15000, 75000, 750000),
('UGX', 'USh', 'Uganda', 'Africa', 3, 22000, 110000, 1100000),
('ETB', 'Br', 'Ethiopia', 'Africa', 3, 330, 1650, 16500),
('RWF', 'FRw', 'Rwanda', 'Africa', 3, 8200, 41000, 410000),
('MWK', 'MK', 'Malawi', 'Africa', 3, 10400, 52000, 520000),
('ZMW', 'ZK', 'Zambia', 'Africa', 3, 165, 825, 8250),
('AOA', 'Kz', 'Angola', 'Africa', 3, 4950, 24750, 247500),
('MZN', 'MT', 'Mozambique', 'Africa', 3, 382, 1910, 19100),
('SDG', 'ج.س.', 'Sudan', 'Africa', 3, 3600, 18000, 180000),
('SSP', '£', 'South Sudan', 'Africa', 3, 7800, 39000, 390000),
('SOS', 'Sh', 'Somalia', 'Africa', 3, 3415, 17075, 170750),
('DJF', 'Fdj', 'Djibouti', 'Africa', 3, 1065, 5325, 53250),
('SLL', 'Le', 'Sierra Leone', 'Africa', 3, 125000, 625000, 6250000),
('LRD', 'L$', 'Liberia', 'Africa', 3, 1150, 5750, 57500),
('GNF', 'FG', 'Guinea', 'Africa', 3, 51500, 257500, 2575000),
('BIF', 'FBu', 'Burundi', 'Africa', 3, 17000, 85000, 850000),
('MGA', 'Ar', 'Madagascar', 'Africa', 3, 27000, 135000, 1350000),
('CDF', 'FC', 'DR Congo', 'Africa', 3, 16500, 82500, 825000),
('XOF', 'CFA', 'West African CFA (8 countries)', 'Africa', 3, 3600, 18000, 180000),
('XAF', 'FCFA', 'Central African CFA (6 countries)', 'Africa', 3, 3600, 18000, 180000),
('MRU', 'UM', 'Mauritania', 'Africa', 3, 238, 1190, 11900),
('GMD', 'D', 'Gambia', 'Africa', 3, 405, 2025, 20250),
('CVE', 'Esc', 'Cape Verde', 'Africa', 3, 605, 3025, 30250),
('STN', 'Db', 'São Tomé and Príncipe', 'Africa', 3, 135, 675, 6750),
('MUR', '₨', 'Mauritius', 'Africa', 3, 275, 1375, 13750),
('SCR', '₨', 'Seychelles', 'Africa', 3, 81, 405, 4050),
('BWP', 'P', 'Botswana', 'Africa', 3, 82, 410, 4100),
('SZL', 'L', 'Eswatini', 'Africa', 3, 109, 545, 5450),
('LSL', 'L', 'Lesotho', 'Africa', 3, 109, 545, 5450),
('NAD', 'N$', 'Namibia', 'Africa', 3, 109, 545, 5450);

-- OCEANIA
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('AUD', 'A$', 'Australia', 'Oceania', 1, 19.99, 92.99, 929),
('NZD', 'NZ$', 'New Zealand', 'Oceania', 1, 21.99, 101.99, 1019);

-- CENTRAL AMERICA & CARIBBEAN
INSERT INTO public.subscription_pricing (currency_code, currency_symbol, country_name, continent, tier, premium_monthly, expert_monthly, expert_deposit) VALUES
('CRC', '₡', 'Costa Rica', 'Central America', 2, 6120, 29988, 299880),
('DOP', 'RD$', 'Dominican Republic', 'Central America', 2, 720, 3528, 35280),
('HTG', 'G', 'Haiti', 'Central America', 3, 790, 3950, 39500),
('NIO', 'C$', 'Nicaragua', 'Central America', 3, 220, 1100, 11000),
('HNL', 'L', 'Honduras', 'Central America', 3, 150, 750, 7500),
('GTQ', 'Q', 'Guatemala', 'Central America', 3, 46, 230, 2300);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to get pricing by currency code
CREATE OR REPLACE FUNCTION get_subscription_pricing(p_currency_code VARCHAR(3))
RETURNS TABLE (
  currency_symbol VARCHAR(10),
  premium_monthly DECIMAL(12, 2),
  expert_monthly DECIMAL(12, 2),
  expert_deposit DECIMAL(12, 2),
  tier INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.currency_symbol,
    sp.premium_monthly,
    sp.expert_monthly,
    sp.expert_deposit,
    sp.tier
  FROM public.subscription_pricing sp
  WHERE sp.currency_code = UPPER(p_currency_code)
    AND sp.is_active = true
  LIMIT 1;
  
  -- If no pricing found, return default USD Tier 1 pricing
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 
      '$'::VARCHAR(10),
      12.99::DECIMAL(12, 2),
      59.99::DECIMAL(12, 2),
      599::DECIMAL(12, 2),
      1::INTEGER;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get all pricing by continent
CREATE OR REPLACE FUNCTION get_pricing_by_continent(p_continent VARCHAR(50))
RETURNS TABLE (
  currency_code VARCHAR(3),
  currency_symbol VARCHAR(10),
  country_name VARCHAR(100),
  tier INTEGER,
  premium_monthly DECIMAL(12, 2),
  expert_monthly DECIMAL(12, 2),
  expert_deposit DECIMAL(12, 2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sp.currency_code,
    sp.currency_symbol,
    sp.country_name,
    sp.tier,
    sp.premium_monthly,
    sp.expert_monthly,
    sp.expert_deposit
  FROM public.subscription_pricing sp
  WHERE sp.continent = p_continent
    AND sp.is_active = true
  ORDER BY sp.tier, sp.country_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Get pricing for India
-- SELECT * FROM get_subscription_pricing('INR');

-- Get all pricing for Asia
-- SELECT * FROM get_pricing_by_continent('Asia');

-- Get all Tier 1 countries
-- SELECT * FROM subscription_pricing WHERE tier = 1 AND is_active = true;

-- Update pricing for a specific currency
-- UPDATE subscription_pricing 
-- SET premium_monthly = 1099, expert_monthly = 5499, expert_deposit = 54990, updated_at = NOW()
-- WHERE currency_code = 'INR';

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. All prices are in the local currency (no conversion needed)
-- 2. Tier 1 = High-income countries (~$13/month premium)
-- 3. Tier 2 = Middle-income countries (~$12/month premium, ₹999 in India)
-- 4. Tier 3 = Lower-income countries (~$6/month premium, ₹499 equivalent)
-- 5. Expert deposit is refundable after 12 months
-- 6. Use get_subscription_pricing() function in your app to fetch pricing
-- ============================================================================
