-- ============================================
-- FIX HOÀN CHỈNH: ALTER TABLE + RLS POLICIES
-- ============================================
-- Chạy script này để fix cả ALTER TABLE và RLS policies một lúc

-- ============================================
-- PHẦN 1: ALTER TABLE - Đổi user_id từ UUID sang TEXT
-- ============================================

-- Bước 1: Xóa foreign key constraint (nếu có)
ALTER TABLE user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_user_id_fkey;

-- Bước 2: Xóa các RLS policies cũ (sẽ tạo lại sau)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON user_profiles;

-- Bước 3: Thay đổi kiểu dữ liệu từ UUID sang TEXT
-- Nếu đã có dữ liệu, PostgreSQL sẽ tự động convert UUID -> TEXT
ALTER TABLE user_profiles 
ALTER COLUMN user_id TYPE TEXT USING user_id::text;

-- Bước 4: Xóa và tạo lại UNIQUE constraint
-- Xóa tất cả các constraint có thể liên quan đến user_id
ALTER TABLE user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_user_id_key;

ALTER TABLE user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_user_id_unique;

-- Tạo lại UNIQUE constraint
ALTER TABLE user_profiles 
ADD CONSTRAINT user_profiles_user_id_unique UNIQUE (user_id);

-- Bước 5: Tạo lại index trên user_id (TEXT)
DROP INDEX IF EXISTS idx_user_profiles_user_id;
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- ============================================
-- PHẦN 2: TẠO LẠI RLS POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- SELECT policy
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id);

-- INSERT policy (QUAN TRỌNG NHẤT - đang bị lỗi 403)
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid()::text = user_id);

-- UPDATE policy
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- DELETE policy
CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (auth.uid()::text = user_id);

-- ============================================
-- KIỂM TRA SAU KHI CHẠY:
-- ============================================

-- 1. Kiểm tra kiểu dữ liệu của user_id (phải là TEXT)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' AND column_name = 'user_id';
-- Kết quả: data_type phải là 'text'

-- 2. Kiểm tra RLS policies đã được tạo
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'user_profiles';
-- Phải có 4 policies: SELECT, INSERT, UPDATE, DELETE

-- 3. Test với user hiện tại
SELECT auth.uid()::text as current_user_id;

-- ============================================
-- SAU KHI CHẠY XONG:
-- ============================================
-- 1. Thử edit profile và bấm Save trong app
-- 2. Kiểm tra console logs - không còn lỗi 403
-- 3. Kiểm tra bảng user_profiles có record mới không
