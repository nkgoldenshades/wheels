-- Create storage bucket for seat layout images
INSERT INTO storage.buckets (id, name, public)
VALUES ('layout-images', 'layout-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for layout images
CREATE POLICY "Anyone can view layout images"
ON storage.objects FOR SELECT
USING (bucket_id = 'layout-images');

CREATE POLICY "Authenticated users can upload layout images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'layout-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own layout images"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'layout-images' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete their own layout images"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'layout-images' 
  AND auth.role() = 'authenticated'
);

-- Verify bucket created
SELECT * FROM storage.buckets WHERE id = 'layout-images';
