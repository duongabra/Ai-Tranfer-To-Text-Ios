-- ============================================
-- FIX RLS POLICY NGAY LẬP TỨC
-- ============================================
-- Chạy script này trong Supabase SQL Editor để fix lỗi 403

-- Bước 1: Xóa TẤT CẢ các policy cũ
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON user_profiles;

-- Bước 2: Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Bước 3: Kiểm tra kiểu dữ liệu của user_id trong bảng
-- Chạy query này để xem user_id là UUID hay TEXT:
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'user_profiles' AND column_name = 'user_id';

-- Bước 4: Tạo lại policies với cast đúng kiểu
-- THỬ CẢ HAI CÁCH để đảm bảo hoạt động:

-- CÁCH 1: Nếu user_id là TEXT (từ code gửi lên là TEXT)
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id::text);

-- INSERT policy (QUAN TRỌNG NHẤT - đây là policy đang bị lỗi)
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

-- UPDATE policy
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid()::text = user_id::text)
WITH CHECK (auth.uid()::text = user_id::text);

-- DELETE policy
CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (auth.uid()::text = user_id::text);

-- ============================================
-- KIỂM TRA SAU KHI CHẠY:
-- ============================================
-- 1. Thử edit profile lại trong app
-- 2. Nếu vẫn lỗi, kiểm tra:
--    SELECT auth.uid()::text;  -- Xem UUID của user hiện tại
--    SELECT user_id FROM user_profiles LIMIT 1;  -- Xem format của user_id trong bảng
