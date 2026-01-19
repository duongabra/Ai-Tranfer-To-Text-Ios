-- ============================================
-- ALTER user_profiles.user_id TỪ UUID SANG TEXT
-- ============================================
-- Script này sẽ thay đổi kiểu dữ liệu của user_id từ UUID sang TEXT
-- để hỗ trợ import dữ liệu từ các nền tảng khác

-- Bước 1: Xóa foreign key constraint (nếu có)
-- Lưu ý: Nếu đã có dữ liệu, cần backup trước
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

-- Bước 4: Xóa UNIQUE constraint cũ và tạo lại (nếu cần)
ALTER TABLE user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_user_id_key;

ALTER TABLE user_profiles 
ADD CONSTRAINT user_profiles_user_id_unique UNIQUE (user_id);

-- Bước 5: Tạo lại index trên user_id (TEXT)
DROP INDEX IF EXISTS idx_user_profiles_user_id;
CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

-- Bước 6: Tạo lại RLS policies với TEXT
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- SELECT policy
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id);

-- INSERT policy
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
-- 1. Kiểm tra kiểu dữ liệu:
--    SELECT column_name, data_type 
--    FROM information_schema.columns 
--    WHERE table_name = 'user_profiles' AND column_name = 'user_id';
--    -- Kết quả phải là: data_type = 'text'
--
-- 2. Kiểm tra dữ liệu hiện có (nếu có):
--    SELECT user_id, typeof(user_id) FROM user_profiles LIMIT 5;
--
-- 3. Test INSERT từ app:
--    Thử edit profile và bấm Save trong app

-- ============================================
-- LƯU Ý:
-- ============================================
-- - Script này sẽ convert tất cả UUID hiện có sang TEXT
-- - Foreign key constraint với auth.users đã bị xóa (vì auth.users.id là UUID)
-- - Nếu cần maintain reference, có thể tạo trigger hoặc function để validate
-- - RLS policies đã được cập nhật để so sánh TEXT với TEXT
