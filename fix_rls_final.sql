-- ============================================
-- FIX RLS POLICY - CHẠY NGAY SCRIPT NÀY
-- ============================================
-- Script này sẽ fix lỗi 403 bằng cách tạo lại RLS policies đúng cách

-- Bước 1: Xóa TẤT CẢ policies cũ
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

-- Bước 3: Tạo lại policies
-- QUAN TRỌNG: Cast cả auth.uid() và user_id về TEXT để so sánh

-- SELECT: User chỉ có thể xem profile của chính mình
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id::text);

-- INSERT: User có thể tạo profile cho chính mình
-- Đây là policy quan trọng nhất - đang bị lỗi 403
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid()::text = user_id::text);

-- UPDATE: User chỉ có thể update profile của chính mình
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid()::text = user_id::text)
WITH CHECK (auth.uid()::text = user_id::text);

-- DELETE: User chỉ có thể xóa profile của chính mình
CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (auth.uid()::text = user_id::text);

-- ============================================
-- KIỂM TRA NGAY SAU KHI CHẠY:
-- ============================================
-- Chạy query này để xem policies đã được tạo chưa:
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles';

-- Kết quả phải có 4 policies:
-- 1. Users can view their own profile (SELECT)
-- 2. Users can insert their own profile (INSERT) <- QUAN TRỌNG
-- 3. Users can update their own profile (UPDATE)
-- 4. Users can delete their own profile (DELETE)

-- ============================================
-- DEBUG NẾU VẪN LỖI:
-- ============================================
-- 1. Kiểm tra user_id trong bảng là TEXT hay UUID:
--    SELECT column_name, data_type 
--    FROM information_schema.columns 
--    WHERE table_name = 'user_profiles' AND column_name = 'user_id';
--
-- 2. Kiểm tra auth.uid() trả về gì:
--    SELECT auth.uid(), auth.uid()::text;
--
-- 3. Test policy với user hiện tại:
--    SELECT auth.uid()::text = '2F753077-04FF-481F-AB32-E37A150940BE'::text;
--    -- Phải trả về true nếu đang login với user đó
