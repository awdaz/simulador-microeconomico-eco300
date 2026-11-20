-- ============================================================
-- 98_tests.sql - Pruebas de funciones, PA y triggers
-- Ejecutar: psql -U economia -d economia -f /sql/98_tests.sql
-- Las pruebas que modifican datos se ejecutan dentro de una
-- transaccion que termina con ROLLBACK.
-- ============================================================
\set ON_ERROR_STOP on

\echo '==> Funciones economicas'
DO $$
DECLARE r RECORD;
BEGIN
    IF ROUND(fn_calcular_pendiente(10, 500, 14, 300), 2) <> 50 THEN
        RAISE EXCEPTION 'FALLO fn_calcular_pendiente';
    END IF;
    IF ROUND(fn_calcular_intercepto(10, 500, 50), 2) <> 1000 THEN
        RAISE EXCEPTION 'FALLO fn_calcular_intercepto';
    END IF;
    IF ROUND(fn_calcular_demanda(1000, 50, 12), 2) <> 400 THEN
        RAISE EXCEPTION 'FALLO fn_calcular_demanda';
    END IF;
    IF ROUND(fn_calcular_beneficio(1000, 50, 12, 4, 1500), 2) <> 1700 THEN
        RAISE EXCEPTION 'FALLO fn_calcular_beneficio';
    END IF;
    IF fn_clasificar_demanda(1.5) <> 'elastic'
       OR fn_clasificar_demanda(0.8) <> 'inelastic'
       OR fn_clasificar_demanda(1.0) <> 'unitary' THEN
        RAISE EXCEPTION 'FALLO fn_clasificar_demanda';
    END IF;

    SELECT * INTO r FROM fn_calcular_optimo(1000, 50, 4, 1500);
    IF ROUND(r.optimal_price, 2) <> 12 OR ROUND(r.optimal_quantity, 2) <> 400
       OR ROUND(r.max_profit, 2) <> 1700 OR ROUND(r.epd, 2) <> 1.5 THEN
        RAISE EXCEPTION 'FALLO fn_calcular_optimo';
    END IF;
    RAISE NOTICE 'OK funciones economicas';
END $$;

\echo '==> Estimacion con multiples observaciones'
DO $$
DECLARE v_a NUMERIC; v_b NUMERIC;
BEGIN
    SELECT a, b INTO v_a, v_b FROM fn_estimar_demanda(
        (SELECT id FROM products WHERE sku = 'PAR-001')
    );
    IF ROUND(v_a, 2) <> 1000 OR ROUND(v_b, 2) <> 50 THEN
        RAISE EXCEPTION 'FALLO fn_estimar_demanda: a=%, b=%', v_a, v_b;
    END IF;
    RAISE NOTICE 'OK estimacion por minimos cuadrados';
END $$;

\echo '==> Trigger de validacion de observaciones'
DO $$
BEGIN
    BEGIN
        INSERT INTO price_observations (product_id, price, quantity_demanded)
        VALUES ((SELECT id FROM products WHERE sku = 'PAR-001'), -5, 10);
        RAISE EXCEPTION 'FALLO: trigger no rechazo precio negativo';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM LIKE 'FALLO:%' THEN RAISE; END IF;
        RAISE NOTICE 'OK trigger rechazo precio invalido';
    END;
END $$;

\echo '==> Trigger de historial de costos (con rollback)'
BEGIN;
UPDATE products SET variable_cost_unit = 4.25 WHERE sku = 'PAR-001';
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM product_cost_history
         WHERE product_id = (SELECT id FROM products WHERE sku = 'PAR-001')
           AND old_cost = 4.00 AND new_cost = 4.25
    ) THEN
        RAISE EXCEPTION 'FALLO trigger product_cost_history';
    END IF;
    RAISE NOTICE 'OK trigger historial de costos';
END $$;
ROLLBACK;

\echo '==> Todas las pruebas pasaron'
