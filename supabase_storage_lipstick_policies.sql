-- ============================================================
-- Supabase Storage: RLS policies cho bucket "lipstick"
-- Chạy trong Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Cho phép user đã đăng nhập UPLOAD (insert) vào bucket "lipstick"
--    Path upload trong app: {userId}/{filename}.jpg → chỉ cần bucket_id = 'lipstick'
CREATE POLICY "Allow authenticated uploads to lipstick"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'lipstick');

-- 2. Cho phép mọi người ĐỌC (select) file trong bucket "lipstick" (public URL)
CREATE POLICY "Allow public read lipstick"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'lipstick');

-- (Tùy chọn) Cho phép user xóa/update file của chính mình trong "lipstick"
-- Bỏ comment nếu bạn cần tính năng xóa/đè file sau này.
/*
CREATE POLICY "Allow authenticated delete own lipstick"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'lipstick'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Allow authenticated update own lipstick"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'lipstick'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
*/
