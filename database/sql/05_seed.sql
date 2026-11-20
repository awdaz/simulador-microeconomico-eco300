-- ============================================================
-- 05_seed.sql - Seeders (datos de prueba)
-- El PA sp_seed_case_study carga user, empresa, producto,
-- observaciones y la simulacion "Caso base".
-- ============================================================

CALL sp_seed_case_study();

-- Usuario estandiar para probar el registro/login desde el frontend
INSERT INTO users (name, email, password, role, email_verified_at)
VALUES ('Usuario Demo', 'user@economia.test',
        '$2y$10$2YACyf7g/eeiDGjKdcYo5eG8DUU4KSEJGnWFAzRHTM4X/s0uu9nIq',
        'user', NOW())
ON CONFLICT (email) DO NOTHING;
