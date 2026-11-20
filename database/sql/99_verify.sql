-- ============================================================
-- 99_verify.sql - Verificacion automatica del caso de estudio
-- Valores esperados: P*=12, Q*=400, PI*=1700, EPD=1.5
-- ============================================================
\set ON_ERROR_STOP on

DO $$
DECLARE
    v_sim simulations%ROWTYPE;
    v_filas INTEGER;
BEGIN
    SELECT * INTO v_sim
      FROM simulations
     WHERE name = 'Caso base'
     LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'FALLO: no se encontro la simulacion semilla "Caso base"';
    END IF;

    IF ROUND(v_sim.intercept_a, 2) <> 1000 OR ROUND(v_sim.slope_b, 2) <> 50 THEN
        RAISE EXCEPTION 'FALLO demanda: a=%, b=% (esperado 1000, 50)',
            v_sim.intercept_a, v_sim.slope_b;
    END IF;

    IF ROUND(v_sim.optimal_price, 2) <> 12 THEN
        RAISE EXCEPTION 'FALLO precio optimo: % (esperado 12)', v_sim.optimal_price;
    END IF;

    IF ROUND(v_sim.optimal_quantity, 2) <> 400 THEN
        RAISE EXCEPTION 'FALLO cantidad optima: % (esperado 400)', v_sim.optimal_quantity;
    END IF;

    IF ROUND(v_sim.max_profit, 2) <> 1700 THEN
        RAISE EXCEPTION 'FALLO beneficio maximo: % (esperado 1700)', v_sim.max_profit;
    END IF;

    IF ROUND(v_sim.epd, 2) <> 1.50 OR v_sim.demand_type <> 'elastic' THEN
        RAISE EXCEPTION 'FALLO elasticidad: EPD=%, tipo=% (esperado 1.5, elastic)',
            v_sim.epd, v_sim.demand_type;
    END IF;

    IF ROUND(v_sim.break_even_min, 2) <> 6.17 OR ROUND(v_sim.break_even_max, 2) <> 17.83 THEN
        RAISE EXCEPTION 'FALLO equilibrio: % / % (esperado 6.17 / 17.83)',
            v_sim.break_even_min, v_sim.break_even_max;
    END IF;

    SELECT COUNT(*) INTO v_filas
      FROM simulation_results WHERE simulation_id = v_sim.id;
    IF v_filas <> 43 THEN
        RAISE EXCEPTION 'FALLO grilla: % filas (esperado 43 de 4.00 a 25.00 paso 0.50)', v_filas;
    END IF;

    IF (SELECT COUNT(*) FROM simulation_results
         WHERE simulation_id = v_sim.id AND is_optimal) <> 1 THEN
        RAISE EXCEPTION 'FALLO: debe existir exactamente una fila marcada como optima';
    END IF;

    RAISE NOTICE 'OK: caso base verificado correctamente';
END $$;

\echo ''
\echo '==> Resumen de la simulacion semilla'
SELECT name, intercept_a AS a, slope_b AS b, optimal_price AS "P*",
       optimal_quantity AS "Q*", max_profit AS "PI*", epd, demand_type,
       break_even_min AS "eq_min", break_even_max AS "eq_max"
  FROM v_resumen_simulaciones;

\echo ''
\echo '==> Punto optimo dentro de la grilla'
SELECT price, quantity, profit, epd, is_optimal
  FROM simulation_results
 WHERE simulation_id = (SELECT id FROM simulations WHERE name = 'Caso base' LIMIT 1)
   AND is_optimal;

\echo ''
\echo '==> Filas por tabla'
SELECT 'users' AS tabla, COUNT(*) AS filas FROM users
UNION ALL SELECT 'businesses', COUNT(*) FROM businesses
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'price_observations', COUNT(*) FROM price_observations
UNION ALL SELECT 'simulations', COUNT(*) FROM simulations
UNION ALL SELECT 'simulation_results', COUNT(*) FROM simulation_results
UNION ALL SELECT 'audit_log', COUNT(*) FROM audit_log
UNION ALL SELECT 'product_cost_history', COUNT(*) FROM product_cost_history
ORDER BY tabla;

\echo ''
\echo '==> VERIFICACION EXITOSA'
