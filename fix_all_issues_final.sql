-- ============================================
-- FIX TẤT CẢ VẤN ĐỀ - CHẠY SCRIPT NÀY
-- ============================================
-- Script này sẽ:
-- 1. Cleanup duplicate records
-- 2. Normalize tất cả user_id về lowercase
-- 3. Fix RLS policies với case-insensitive comparison

-- ============================================
-- PHẦN 1: CLEANUP DUPLICATE RECORDS
-- ============================================

-- Bước 1: Xem các duplicate records
SELECT 
    LOWER(user_id) as normalized_user_id,
    COUNT(*) as count,
    array_agg(id ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST) as record_ids,
    array_agg(user_id ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST) as user_ids
FROM user_profiles
GROUP BY LOWER(user_id)
HAVING COUNT(*) > 1;

-- Bước 2: Giữ lại record mới nhất và xóa các record cũ
-- Tạo bảng tạm để lưu các ID cần giữ lại
CREATE TEMP TABLE IF NOT EXISTS keep_records AS
SELECT DISTINCT ON (LOWER(user_id))
    id,
    LOWER(user_id) as normalized_user_id
FROM user_profiles
ORDER BY LOWER(user_id), updated_at DESC NULLS LAST, created_at DESC NULLS LAST;

-- Xem các record sẽ bị xóa (KIỂM TRA TRƯỚC KHI XÓA)
SELECT p.*
FROM user_profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM keep_records k WHERE k.id = p.id
)
ORDER BY LOWER(p.user_id), p.updated_at DESC NULLS LAST, p.created_at DESC NULLS LAST;

-- XÓA CÁC DUPLICATE RECORDS (CHỈ CHẠY SAU KHI ĐÃ KIỂM TRA BƯỚC TRÊN)
DELETE FROM user_profiles
WHERE id NOT IN (SELECT id FROM keep_records);

-- ============================================
-- PHẦN 2: NORMALIZE TẤT CẢ user_id VỀ LOWERCASE
-- ============================================

UPDATE user_profiles
SET user_id = LOWER(user_id)
WHERE user_id != LOWER(user_id);

-- ============================================
-- PHẦN 3: FIX RLS POLICIES VỚI CASE-INSENSITIVE
-- ============================================

-- Xóa TẤT CẢ policies cũ
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON user_profiles;

-- Enable RLS
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Tạo lại policies với LOWER() để case-insensitive
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
-- PHẦN 4: KIỂM TRA KẾT QUẢ
-- ============================================

-- Kiểm tra không còn duplicate
SELECT 
    LOWER(user_id) as normalized_user_id,
    COUNT(*) as count
FROM user_profiles
GROUP BY LOWER(user_id)
HAVING COUNT(*) > 1;
-- Phải trả về 0 rows

-- Kiểm tra RLS policies
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_profiles'
ORDER BY cmd;
-- Phải có 4 policies với LOWER() trong qual/with_check

-- Xóa bảng tạm
DROP TABLE IF EXISTS keep_records;
