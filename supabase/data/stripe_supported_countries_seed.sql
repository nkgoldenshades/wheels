-- Stripe-supported countries/regions seed for Supabase.
-- Source: Stripe global availability page checked 2026-05-25.
-- Includes standard, preview, and extended_network entries shown by Stripe.

do $$
begin
  create type country_tier as enum ('tier_1', 'tier_2', 'tier_3');
exception
  when duplicate_object then null;
end;
$$;

create table if not exists public.stripe_supported_countries (
  id bigint generated always as identity primary key,
  name text not null,
  iso2 text not null unique,
  iso3 text not null unique,
  continent text not null,
  region text not null,
  subregion text,
  stripe_supported boolean not null default true,
  stripe_availability text not null check (stripe_availability in ('standard', 'preview', 'extended_network')),
  in_countries_197 boolean not null default true,
  tier country_tier not null default 'tier_2',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists stripe_supported_countries_continent_idx on public.stripe_supported_countries (continent);
create index if not exists stripe_supported_countries_availability_idx on public.stripe_supported_countries (stripe_availability);

insert into public.stripe_supported_countries (
  name, iso2, iso3, continent, region, subregion, stripe_supported,
  stripe_availability, in_countries_197, tier
) values
  ('Australia', 'AU', 'AUS', 'Oceania', 'Oceania', 'Australia and New Zealand', true, 'standard', true, 'tier_1'),
  ('Austria', 'AT', 'AUT', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('Belgium', 'BE', 'BEL', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_2'),
  ('Brazil', 'BR', 'BRA', 'South America', 'Americas', 'South America', true, 'standard', true, 'tier_1'),
  ('Bulgaria', 'BG', 'BGR', 'Europe', 'Europe', 'Southeast Europe', true, 'standard', true, 'tier_2'),
  ('Canada', 'CA', 'CAN', 'North America', 'Americas', 'North America', true, 'standard', true, 'tier_1'),
  ('Cote d''Ivoire', 'CI', 'CIV', 'Africa', 'Africa', 'Western Africa', true, 'extended_network', true, 'tier_3'),
  ('Croatia', 'HR', 'HRV', 'Europe', 'Europe', 'Southeast Europe', true, 'standard', true, 'tier_2'),
  ('Cyprus', 'CY', 'CYP', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_2'),
  ('Czech Republic', 'CZ', 'CZE', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('Denmark', 'DK', 'DNK', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Estonia', 'EE', 'EST', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Finland', 'FI', 'FIN', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('France', 'FR', 'FRA', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_1'),
  ('Germany', 'DE', 'DEU', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_1'),
  ('Ghana', 'GH', 'GHA', 'Africa', 'Africa', 'Western Africa', true, 'extended_network', true, 'tier_3'),
  ('Gibraltar', 'GI', 'GIB', 'Europe', 'Europe', 'Southern Europe', true, 'standard', false, 'tier_2'),
  ('Greece', 'GR', 'GRC', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_2'),
  ('Hong Kong', 'HK', 'HKG', 'Asia', 'Asia', 'Eastern Asia', true, 'standard', false, 'tier_2'),
  ('Hungary', 'HU', 'HUN', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('India', 'IN', 'IND', 'Asia', 'Asia', 'Southern Asia', true, 'preview', true, 'tier_1'),
  ('Indonesia', 'ID', 'IDN', 'Asia', 'Asia', 'South-Eastern Asia', true, 'preview', true, 'tier_1'),
  ('Ireland', 'IE', 'IRL', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Italy', 'IT', 'ITA', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_1'),
  ('Japan', 'JP', 'JPN', 'Asia', 'Asia', 'Eastern Asia', true, 'standard', true, 'tier_1'),
  ('Kenya', 'KE', 'KEN', 'Africa', 'Africa', 'Eastern Africa', true, 'extended_network', true, 'tier_2'),
  ('Latvia', 'LV', 'LVA', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Liechtenstein', 'LI', 'LIE', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_2'),
  ('Lithuania', 'LT', 'LTU', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Luxembourg', 'LU', 'LUX', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_2'),
  ('Malaysia', 'MY', 'MYS', 'Asia', 'Asia', 'South-Eastern Asia', true, 'standard', true, 'tier_2'),
  ('Malta', 'MT', 'MLT', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_2'),
  ('Mexico', 'MX', 'MEX', 'North America', 'Americas', 'North America', true, 'standard', true, 'tier_1'),
  ('Netherlands', 'NL', 'NLD', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_1'),
  ('New Zealand', 'NZ', 'NZL', 'Oceania', 'Oceania', 'Australia and New Zealand', true, 'standard', true, 'tier_2'),
  ('Nigeria', 'NG', 'NGA', 'Africa', 'Africa', 'Western Africa', true, 'extended_network', true, 'tier_2'),
  ('Norway', 'NO', 'NOR', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Poland', 'PL', 'POL', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('Portugal', 'PT', 'PRT', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_2'),
  ('Romania', 'RO', 'ROU', 'Europe', 'Europe', 'Southeast Europe', true, 'standard', true, 'tier_2'),
  ('Singapore', 'SG', 'SGP', 'Asia', 'Asia', 'South-Eastern Asia', true, 'standard', true, 'tier_1'),
  ('Slovakia', 'SK', 'SVK', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('Slovenia', 'SI', 'SVN', 'Europe', 'Europe', 'Central Europe', true, 'standard', true, 'tier_2'),
  ('South Africa', 'ZA', 'ZAF', 'Africa', 'Africa', 'Southern Africa', true, 'extended_network', true, 'tier_1'),
  ('Spain', 'ES', 'ESP', 'Europe', 'Europe', 'Southern Europe', true, 'standard', true, 'tier_1'),
  ('Sweden', 'SE', 'SWE', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_2'),
  ('Switzerland', 'CH', 'CHE', 'Europe', 'Europe', 'Western Europe', true, 'standard', true, 'tier_2'),
  ('Thailand', 'TH', 'THA', 'Asia', 'Asia', 'South-Eastern Asia', true, 'standard', true, 'tier_2'),
  ('United Arab Emirates', 'AE', 'ARE', 'Asia', 'Asia', 'Western Asia', true, 'standard', true, 'tier_1'),
  ('United Kingdom', 'GB', 'GBR', 'Europe', 'Europe', 'Northern Europe', true, 'standard', true, 'tier_1'),
  ('United States', 'US', 'USA', 'North America', 'Americas', 'North America', true, 'standard', true, 'tier_1')
on conflict (iso2) do update set
  name = excluded.name,
  iso3 = excluded.iso3,
  continent = excluded.continent,
  region = excluded.region,
  subregion = excluded.subregion,
  stripe_supported = excluded.stripe_supported,
  stripe_availability = excluded.stripe_availability,
  in_countries_197 = excluded.in_countries_197,
  tier = excluded.tier,
  updated_at = now();

-- Optional: mark matching rows in public.countries, if you add these columns there.
-- alter table public.countries add column if not exists stripe_supported boolean not null default false;
-- alter table public.countries add column if not exists stripe_availability text;
-- update public.countries c set stripe_supported = true, stripe_availability = s.stripe_availability from public.stripe_supported_countries s where s.iso2 = c.iso2;
