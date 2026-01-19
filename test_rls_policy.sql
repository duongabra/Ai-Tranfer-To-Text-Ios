-- ============================================
-- TEST RLS POLICY VỚI USER THỰC TẾ
-- ============================================
-- Script này để test xem RLS policy có hoạt động đúng không

-- 1. Kiểm tra auth.uid() trong SQL Editor (sẽ là NULL vì không có authenticated context)
SELECT auth.uid() as current_auth_uid, auth.uid()::text as current_auth_uid_text;

-- 2. Kiểm tra kiểu dữ liệu của user_id trong bảng
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'user_id';

-- 3. Kiểm tra RLS policies hiện tại
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY cmd;

-- 4. Test policy với một user_id cụ thể (thay YOUR_USER_ID bằng UUID thực tế)
-- SELECT auth.uid()::text = 'YOUR_USER_ID'::text;
-- Nếu đang login với user đó trong app, sẽ trả về true

-- 5. Kiểm tra xem có dữ liệu nào trong bảng không
SELECT COUNT(*) as total_profiles FROM user_profiles;

-- ============================================
-- LƯU Ý:
-- ============================================
-- - auth.uid() trong SQL Editor sẽ là NULL (bình thường)
-- - auth.uid() trong app (với JWT token) sẽ trả về UUID của user
-- - RLS policy sẽ hoạt động khi app gọi API với JWT token hợp lệ
