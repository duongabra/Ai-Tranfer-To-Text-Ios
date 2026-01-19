-- ============================================
-- CLEANUP DUPLICATE USER_PROFILES
-- ============================================
-- Script này sẽ xóa các duplicate records và normalize user_id về lowercase

-- Bước 1: Xem các duplicate records
SELECT 
    LOWER(user_id) as normalized_user_id,
    COUNT(*) as count,
    array_agg(id) as record_ids,
    array_agg(user_id) as user_ids
FROM user_profiles
GROUP BY LOWER(user_id)
HAVING COUNT(*) > 1;

-- Bước 2: Giữ lại record mới nhất (có updated_at lớn nhất) và xóa các record cũ
-- Lưu ý: Chạy từng bước một và kiểm tra kỹ trước khi xóa

-- Tạo bảng tạm để lưu các ID cần giữ lại
CREATE TEMP TABLE keep_records AS
SELECT DISTINCT ON (LOWER(user_id))
    id,
    LOWER(user_id) as normalized_user_id
FROM user_profiles
ORDER BY LOWER(user_id), updated_at DESC NULLS LAST, created_at DESC NULLS LAST;

-- Xem các record sẽ bị xóa (để kiểm tra trước)
SELECT p.*
FROM user_profiles p
WHERE NOT EXISTS (
    SELECT 1 FROM keep_records k WHERE k.id = p.id
)
ORDER BY LOWER(p.user_id), p.updated_at DESC NULLS LAST, p.created_at DESC NULLS LAST;

-- Bước 3: Xóa các duplicate records (CHỈ CHẠY SAU KHI ĐÃ KIỂM TRA BƯỚC 2)
-- UNCOMMENT DÒNG DƯỚI ĐÂY SAU KHI ĐÃ XÁC NHẬN:
-- DELETE FROM user_profiles
-- WHERE id NOT IN (SELECT id FROM keep_records);

-- Bước 4: Normalize tất cả user_id về lowercase
UPDATE user_profiles
SET user_id = LOWER(user_id)
WHERE user_id != LOWER(user_id);

-- Bước 5: Kiểm tra kết quả
SELECT 
    LOWER(user_id) as normalized_user_id,
    COUNT(*) as count
FROM user_profiles
GROUP BY LOWER(user_id)
HAVING COUNT(*) > 1;
-- Phải trả về 0 rows

-- Bước 6: Xóa bảng tạm
DROP TABLE IF EXISTS keep_records;
