-- ============================================
-- KIỂM TRA SCHEMA CỦA BẢNG user_profiles
-- ============================================
-- Chạy script này để xem kiểu dữ liệu của các cột

-- Xem kiểu dữ liệu của user_id
SELECT 
    column_name, 
    data_type,
    udt_name
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_profiles' 
  AND column_name = 'user_id';

-- Xem tất cả các cột trong bảng
SELECT 
    column_name, 
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_profiles'
ORDER BY ordinal_position;

-- Kiểm tra RLS policies hiện tại
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Test: Xem auth.uid() trả về gì
SELECT auth.uid() as current_user_id, auth.uid()::text as current_user_id_text;
