-- ============================================================
-- 06_api_helpers.sql - Helpers para la capa de aplicacion (Laravel)
-- Se ejecuta despues de los procedimientos almacenados.
-- ============================================================

-- Permite invocar sp_run_simulation desde una simple SELECT y
-- recuperar el id generado (los PA con OUT no son comodos desde PDO).
CREATE OR REPLACE FUNCTION fn_run_simulation(
    p_user_id     BIGINT,
    p_product_id  BIGINT,
    p_name        VARCHAR,
    p_price_min   NUMERIC,
    p_price_max   NUMERIC,
    p_price_step  NUMERIC,
    p_cv_override NUMERIC DEFAULT NULL,
    p_cf_override NUMERIC DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    v_sim_id BIGINT;
BEGIN
    CALL sp_run_simulation(
        p_user_id, p_product_id, p_name,
        p_price_min, p_price_max, p_price_step,
        p_cv_override, p_cf_override, v_sim_id
    );
    RETURN v_sim_id;
END; $$;
