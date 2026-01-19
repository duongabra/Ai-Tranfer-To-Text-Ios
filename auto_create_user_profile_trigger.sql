-- ============================================
-- Auto-create user_profile khi user mới được tạo trong auth.users
-- ============================================
-- Script này tạo một Database Trigger để tự động INSERT vào bảng user_profiles
-- khi một user mới được tạo trong bảng auth.users (Authentication > Users)

-- ============================================
-- CÁCH 1: PostgreSQL Trigger Function (Recommended)
-- ============================================
-- Tạo Function với SECURITY DEFINER để bypass RLS và tự động tạo profile

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Tự động INSERT vào bảng user_profiles khi có user mới
    INSERT INTO public.user_profiles (user_id, created_at, updated_at)
    VALUES (
        NEW.id::text,  -- Convert UUID sang TEXT để match với kiểu dữ liệu của user_id
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;  -- Nếu đã tồn tại thì không làm gì (tránh duplicate)
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Tạo Trigger trên bảng auth.users
-- Lưu ý: Supabase có thể không cho phép trigger trên auth.users
-- Nếu gặp lỗi permission, hãy thử cách 2 hoặc cách 3 bên dưới
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- CÁCH 2: RPC Function để code có thể gọi (Fallback)
-- ============================================
-- Nếu trigger không hoạt động, sử dụng function này từ code

CREATE OR REPLACE FUNCTION public.create_user_profile_if_not_exists(p_user_id UUID)
RETURNS void AS $$
BEGIN
    -- Chỉ INSERT nếu chưa tồn tại
    INSERT INTO public.user_profiles (user_id, created_at, updated_at)
    VALUES (
        p_user_id::text,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.create_user_profile_if_not_exists(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_user_profile_if_not_exists(UUID) TO anon;
GRANT EXECUTE ON FUNCTION public.create_user_profile_if_not_exists(UUID) TO service_role;

-- ============================================
-- CÁCH 3: Supabase Database Webhook (Nếu có Pro plan)
-- ============================================
-- 1. Vào Supabase Dashboard > Database > Webhooks
-- 2. Tạo webhook mới:
--    - Event: INSERT on auth.users
--    - URL: https://your-project.supabase.co/rest/v1/rpc/create_user_profile_if_not_exists
--    - Method: POST
--    - Headers: 
--      - Authorization: Bearer YOUR_SERVICE_ROLE_KEY
--      - Content-Type: application/json
--    - Body: {"p_user_id": "{{NEW.id}}"}
--
-- 3. Webhook sẽ tự động gọi function khi có user mới

-- ============================================
-- KIỂM TRA SAU KHI CHẠY:
-- ============================================
-- 1. Tạo một user mới trong Authentication > Users
-- 2. Kiểm tra bảng user_profiles xem có record mới không
-- 3. Nếu không có, trigger không hoạt động → sử dụng cách 2 hoặc 3

-- ============================================
-- Lưu ý:
-- ============================================
-- - SECURITY DEFINER cho phép function chạy với quyền của owner (bypass RLS)
-- - Trigger sẽ tự động chạy khi có INSERT vào auth.users
-- - Nếu trigger không hoạt động (do Supabase restrictions), code sẽ tiếp tục
--   gọi ensureUserProfileExists() khi user login lần đầu (đã implement sẵn)
