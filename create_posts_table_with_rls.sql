-- Create posts table
CREATE TABLE public.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- User & Vehicle
  profile_id TEXT REFERENCES public.profiles(id),
  vehicle_id UUID REFERENCES public.vehicles(id),
  
  -- Type
  capabilities TEXT CHECK (
    capabilities IN ('passenger', 'parcel', 'lease')
  ),
  lease_type TEXT CHECK (
    lease_type IN ('with_operator', 'without_operator')
  ),
  interaction_type TEXT CHECK (
    interaction_type IN ('customer_comes_to_pickup', 'provider_comes_to_customer')
  ),
  
  -- Route
  route_type TEXT CHECK (
    route_type IN ('from_to', 'base_range')
  ),
  range_km NUMERIC,
  
  -- Location (From → To)
  from_address TEXT,
  from_lat NUMERIC,
  from_lng NUMERIC,
  to_address TEXT,
  to_lat NUMERIC,
  to_lng NUMERIC,
  
  -- Location (Base + Range)
  base_address TEXT,
  base_lat NUMERIC,
  base_lng NUMERIC,
  
  -- Time
  start_time TIMESTAMP WITH TIME ZONE,
  end_time TIMESTAMP WITH TIME ZONE,
  
  -- Pricing
  price NUMERIC,
  currency_code TEXT,
  
  -- Slot
  slot_mode TEXT CHECK (
    slot_mode IN ('simple', 'layout_based')
  ),
  capacity INTEGER,
  grid JSONB,
  
  -- Terms
  terms TEXT,
  
  -- Media
  post_image_url TEXT,
  video_url TEXT,
  gallery_images TEXT[],
  
  -- Created location
  created_lat NUMERIC,
  created_lng NUMERIC,
  
  -- Status
  status TEXT,
  is_active BOOLEAN DEFAULT true,
  is_deleted BOOLEAN DEFAULT false,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Constraints
  CHECK (
    (route_type = 'from_to' AND from_address IS NOT NULL) OR
    (route_type = 'base_range' AND base_address IS NOT NULL AND range_km IS NOT NULL)
  ),
  CHECK (
    (slot_mode = 'simple' AND price IS NOT NULL AND capacity IS NOT NULL) OR
    (slot_mode = 'layout_based' AND grid IS NOT NULL)
  )
);

-- Enable RLS
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- RLS Policies for posts (works with Firebase anon role)
CREATE POLICY "posts_select" ON public.posts
  FOR SELECT 
  TO anon, authenticated
  USING (is_active = true AND is_deleted = false);

CREATE POLICY "posts_insert" ON public.posts
  FOR INSERT 
  TO anon, authenticated
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "posts_update" ON public.posts
  FOR UPDATE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub')
  WITH CHECK (profile_id = auth.jwt()->>'sub');

CREATE POLICY "posts_delete" ON public.posts
  FOR DELETE 
  TO anon, authenticated
  USING (profile_id = auth.jwt()->>'sub');

-- Indexes for performance
CREATE INDEX idx_posts_profile_id ON public.posts(profile_id);
CREATE INDEX idx_posts_vehicle_id ON public.posts(vehicle_id);
CREATE INDEX idx_posts_capabilities ON public.posts(capabilities);
CREATE INDEX idx_posts_route_type ON public.posts(route_type);
CREATE INDEX idx_posts_is_active ON public.posts(is_active) WHERE is_active = true;
CREATE INDEX idx_posts_created_at ON public.posts(created_at DESC);

-- Verify
SELECT 
  tablename, 
  policyname, 
  roles, 
  cmd 
FROM pg_policies 
WHERE tablename = 'posts' 
ORDER BY cmd, policyname;
