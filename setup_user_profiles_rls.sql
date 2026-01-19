-- ============================================
-- RLS Policies cho bảng user_profiles
-- ============================================
-- Chạy script này trong Supabase SQL Editor để cho phép authenticated users
-- có thể INSERT, SELECT, UPDATE, DELETE vào bảng user_profiles

-- ============================================
-- FIX RLS POLICIES CHO BẢNG user_profiles
-- ============================================
-- Script này sẽ xóa và tạo lại các RLS policies đúng cách
-- Chạy script này trong Supabase SQL Editor

-- Bước 1: Xóa TẤT CẢ các policy cũ (để tránh conflict)
DROP POLICY IF EXISTS "Users can view own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can delete their own profile" ON user_profiles;

-- Bước 2: Enable RLS trên bảng user_profiles (nếu chưa enable)
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Bước 3: Tạo lại các policies với SECURITY DEFINER để bypass RLS khi cần
-- Lưu ý: user_id trong bảng là TEXT, auth.uid() trả về UUID
-- Cần cast cả hai về cùng kiểu để so sánh

-- Policy cho SELECT: User chỉ có thể xem profile của chính mình
CREATE POLICY "Users can view their own profile"
ON user_profiles
FOR SELECT
USING (auth.uid()::text = user_id);

-- Policy cho INSERT: User có thể tạo profile cho chính mình
-- QUAN TRỌNG: Policy này phải cho phép INSERT với user_id từ request
CREATE POLICY "Users can insert their own profile"
ON user_profiles
FOR INSERT
WITH CHECK (auth.uid()::text = user_id);

-- Policy cho UPDATE: User chỉ có thể update profile của chính mình
CREATE POLICY "Users can update their own profile"
ON user_profiles
FOR UPDATE
USING (auth.uid()::text = user_id)
WITH CHECK (auth.uid()::text = user_id);

-- Policy cho DELETE: User chỉ có thể xóa profile của chính mình
CREATE POLICY "Users can delete their own profile"
ON user_profiles
FOR DELETE
USING (auth.uid()::text = user_id);

-- ============================================
-- Kiểm tra sau khi chạy:
-- ============================================
-- 1. Vào Authentication > Users trong Supabase Dashboard
-- 2. Copy UUID của một user
-- 3. Chạy query này để test:
--    SELECT * FROM user_profiles WHERE user_id::text = 'YOUR_USER_UUID_HERE';
-- 4. Nếu query trả về kết quả hoặc không có lỗi permission, RLS đã được setup đúng

-- ============================================
-- Lưu ý:
-- ============================================
-- - auth.uid() trả về UUID của user hiện tại từ JWT token
-- - user_id trong bảng user_profiles phải match với auth.uid()
-- - Script này cast cả hai về text để đảm bảo so sánh đúng
-- - Nếu vẫn gặp lỗi 403, kiểm tra:
--   1. User đã đăng nhập và có valid JWT token chưa?
--   2. user_id trong request có match với auth.uid() không?
--   3. RLS đã được enable trên bảng chưa?
