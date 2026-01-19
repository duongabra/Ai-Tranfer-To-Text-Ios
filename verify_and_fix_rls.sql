-- ============================================
-- VERIFY VÀ FIX RLS POLICIES
-- ============================================
-- Script này sẽ kiểm tra và fix RLS policies nếu cần

-- Bước 1: Kiểm tra kiểu dữ liệu của user_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'user_id';
-- Kết quả mong đợi: data_type = 'text'

-- Bước 2: Kiểm tra RLS policies hiện tại
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY cmd;

-- Bước 3: Xóa TẤT CẢ policies cũ (nếu có)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON user_profiles;

-- Bước 4: Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Bước 5: Tạo lại policies với cast đúng kiểu
-- QUAN TRỌNG: user_id là TEXT, auth.uid() trả về UUID
-- Cần cast cả hai về TEXT để so sánh

CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (auth.uid()::text = user_id);

-- Bước 6: Kiểm tra lại policies đã được tạo
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY cmd;
-- Phải có 4 policies: SELECT, INSERT, UPDATE, DELETE

-- ============================================
-- DEBUG: Test với user_id cụ thể
-- ============================================
-- Thay YOUR_USER_ID bằng UUID từ logs (ví dụ: 7D817E66-C582-4D2D-8BB2-7DA9ECC1FA2A)
-- SELECT auth.uid()::text = '7D817E66-C582-4D2D-8BB2-7DA9ECC1FA2A'::text;
-- Nếu đang login với user đó trong app, sẽ trả về true
