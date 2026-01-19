-- ============================================
-- FIX RLS POLICY - CASE INSENSITIVE
-- ============================================
-- Script này sẽ fix RLS policies để hỗ trợ case-insensitive comparison

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

-- Bước 3: Tạo lại policies với LOWER() để case-insensitive
-- QUAN TRỌNG: Sử dụng LOWER() để so sánh case-insensitive

CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (LOWER(auth.uid()::text) = LOWER(user_id));

CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (LOWER(auth.uid()::text) = LOWER(user_id));

CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (LOWER(auth.uid()::text) = LOWER(user_id))
WITH CHECK (LOWER(auth.uid()::text) = LOWER(user_id));

CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (LOWER(auth.uid()::text) = LOWER(user_id));

-- ============================================
-- KIỂM TRA SAU KHI CHẠY:
-- ============================================
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY cmd;
