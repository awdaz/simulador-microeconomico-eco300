-- ============================================================
-- 03_procedures.sql - Procedimientos almacenados (PA)
-- ============================================================

-- ------------------------------------------------------------
-- PA 1: Genera la grilla de resultados de una simulacion
--       Recalcula precio, cantidad, ingresos, costos, beneficio
--       y EPD para cada precio del rango, y marca el optimo.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_generar_resultados(
    IN p_simulation_id BIGINT,
    IN p_a NUMERIC,
    IN p_b NUMERIC,
    IN p_cv NUMERIC,
    IN p_cf NUMERIC,
    IN p_min NUMERIC,
    IN p_max NUMERIC,
    IN p_step NUMERIC
)
LANGUAGE plpgsql AS $$
DECLARE
    v_price    NUMERIC;
    v_q        NUMERIC;
    v_revenue  NUMERIC;
    v_cost     NUMERIC;
    v_profit   NUMERIC;
    v_epd      NUMERIC;
    v_optprice NUMERIC;
BEGIN
    IF p_min <= 0 OR p_max <= p_min OR p_step <= 0 THEN
        RAISE EXCEPTION 'Rango de precios invalido: min=%, max=%, paso=%', p_min, p_max, p_step;
    END IF;

    v_optprice := (p_a + p_b * p_cv) / (2 * p_b);

    DELETE FROM simulation_results WHERE simulation_id = p_simulation_id;

    v_price := p_min;
    WHILE v_price <= p_max LOOP
        v_q       := fn_calcular_demanda(p_a, p_b, v_price);
        v_revenue := v_price * v_q;
        v_cost    := p_cf + p_cv * v_q;
        v_profit  := v_revenue - v_cost;
        v_epd     := fn_calcular_epd(p_a, p_b, v_price);

        INSERT INTO simulation_results
            (simulation_id, price, quantity, revenue, total_cost, profit, epd, is_optimal)
        VALUES
            (p_simulation_id, v_price, v_q, v_revenue, v_cost, v_profit, v_epd, FALSE);

        v_price := v_price + p_step;
    END LOOP;

    -- Se marca como optimo el punto de la grilla mas cercano al optimo analitico
    UPDATE simulation_results
       SET is_optimal = TRUE
     WHERE id = (
        SELECT id
          FROM simulation_results
         WHERE simulation_id = p_simulation_id
         ORDER BY ABS(price - v_optprice), price
         LIMIT 1
     );
END; $$;

-- ------------------------------------------------------------
-- PA 2: Ejecuta una simulacion completa y guarda su snapshot
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_run_simulation(
    IN  p_user_id      BIGINT,
    IN  p_product_id   BIGINT,
    IN  p_name         VARCHAR,
    IN  p_price_min    NUMERIC,
    IN  p_price_max    NUMERIC,
    IN  p_price_step   NUMERIC,
    IN  p_cv_override  NUMERIC,
    IN  p_cf_override  NUMERIC,
    OUT p_simulation_id BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_a   NUMERIC;
    v_b   NUMERIC;
    v_cv  NUMERIC;
    v_cf  NUMERIC;
    v_opt RECORD;
BEGIN
    SELECT variable_cost_unit INTO v_cv
      FROM products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el producto con id %', p_product_id;
    END IF;

    SELECT b.fixed_cost_monthly INTO v_cf
      FROM businesses b
      JOIN products pr ON pr.business_id = b.id
     WHERE pr.id = p_product_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la empresa asociada al producto %', p_product_id;
    END IF;

    IF p_cv_override IS NOT NULL THEN v_cv := p_cv_override; END IF;
    IF p_cf_override IS NOT NULL THEN v_cf := p_cf_override; END IF;

    SELECT a, b INTO v_a, v_b FROM fn_estimar_demanda(p_product_id);

    SELECT * INTO v_opt FROM fn_calcular_optimo(v_a, v_b, v_cv, v_cf);

    INSERT INTO simulations (
        user_id, product_id, name, intercept_a, slope_b,
        variable_cost, fixed_cost, optimal_price, optimal_quantity,
        max_profit, epd, demand_type, break_even_min, break_even_max,
        price_min, price_max, price_step
    ) VALUES (
        p_user_id, p_product_id, p_name, v_a, v_b,
        v_cv, v_cf, v_opt.optimal_price, v_opt.optimal_quantity,
        v_opt.max_profit, v_opt.epd, v_opt.demand_type,
        v_opt.break_even_min, v_opt.break_even_max,
        p_price_min, p_price_max, p_price_step
    )
    ON CONFLICT (user_id, product_id, name) DO UPDATE SET
        intercept_a      = EXCLUDED.intercept_a,
        slope_b          = EXCLUDED.slope_b,
        variable_cost    = EXCLUDED.variable_cost,
        fixed_cost       = EXCLUDED.fixed_cost,
        optimal_price    = EXCLUDED.optimal_price,
        optimal_quantity = EXCLUDED.optimal_quantity,
        max_profit       = EXCLUDED.max_profit,
        epd              = EXCLUDED.epd,
        demand_type      = EXCLUDED.demand_type,
        break_even_min   = EXCLUDED.break_even_min,
        break_even_max   = EXCLUDED.break_even_max,
        price_min        = EXCLUDED.price_min,
        price_max        = EXCLUDED.price_max,
        price_step       = EXCLUDED.price_step,
        updated_at       = NOW()
    RETURNING id INTO p_simulation_id;

    CALL sp_generar_resultados(
        p_simulation_id, v_a, v_b, v_cv, v_cf,
        p_price_min, p_price_max, p_price_step
    );
END; $$;

-- ------------------------------------------------------------
-- PA 3: Refresca una simulacion existente con sus datos guardados
--       (util cuando cambian los costos del producto)
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_refresh_simulation(IN p_simulation_id BIGINT)
LANGUAGE plpgsql AS $$
DECLARE
    v_sim  simulations%ROWTYPE;
    v_opt  RECORD;
BEGIN
    SELECT * INTO v_sim FROM simulations WHERE id = p_simulation_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la simulacion con id %', p_simulation_id;
    END IF;

    SELECT * INTO v_opt
      FROM fn_calcular_optimo(
          v_sim.intercept_a, v_sim.slope_b, v_sim.variable_cost, v_sim.fixed_cost
      );

    CALL sp_generar_resultados(
        p_simulation_id, v_sim.intercept_a, v_sim.slope_b,
        v_sim.variable_cost, v_sim.fixed_cost,
        v_sim.price_min, v_sim.price_max, v_sim.price_step
    );

    UPDATE simulations
       SET optimal_price    = v_opt.optimal_price,
           optimal_quantity = v_opt.optimal_quantity,
           max_profit       = v_opt.max_profit,
           epd              = v_opt.epd,
           demand_type      = v_opt.demand_type,
           break_even_min   = v_opt.break_even_min,
           break_even_max   = v_opt.break_even_max,
           updated_at       = NOW()
     WHERE id = p_simulation_id;
END; $$;

-- ------------------------------------------------------------
-- PA 4: Seeder del caso de estudio (idempotente)
--       P1=10/Q1=500, P2=14/Q2=300, CV=4, CF=1500
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_seed_case_study()
LANGUAGE plpgsql AS $$
DECLARE
    v_user_id     BIGINT;
    v_business_id BIGINT;
    v_product_id  BIGINT;
    v_sim_id      BIGINT;
BEGIN
    INSERT INTO users (name, email, password, role, email_verified_at)
    VALUES ('Administrador Demo', 'admin@economia.test',
            '$2y$10$2YACyf7g/eeiDGjKdcYo5eG8DUU4KSEJGnWFAzRHTM4X/s0uu9nIq',
            'admin', NOW())
    ON CONFLICT (email) DO UPDATE SET name = EXCLUDED.name, role = EXCLUDED.role
    RETURNING id INTO v_user_id;

    INSERT INTO businesses (user_id, name, currency, fixed_cost_monthly)
    VALUES (v_user_id, 'Tienda Minorista Santa Cruz', 'Bs', 1500.00)
    ON CONFLICT (user_id, name)
    DO UPDATE SET fixed_cost_monthly = EXCLUDED.fixed_cost_monthly
    RETURNING id INTO v_business_id;

    INSERT INTO products
        (business_id, name, sku, unit, variable_cost_unit, current_stock, active)
    VALUES
        (v_business_id, 'Producto de alta rotacion', 'PAR-001', 'unidad', 4.00, 100, TRUE)
    ON CONFLICT (business_id, sku)
    DO UPDATE SET name = EXCLUDED.name,
                  variable_cost_unit = EXCLUDED.variable_cost_unit,
                  active = TRUE
    RETURNING id INTO v_product_id;

    INSERT INTO price_observations
        (product_id, price, quantity_demanded, observed_at, source)
    VALUES (v_product_id, 10.00, 500, DATE '2026-10-01', 'historico')
    ON CONFLICT (product_id, price, observed_at) DO NOTHING;

    INSERT INTO price_observations
        (product_id, price, quantity_demanded, observed_at, source)
    VALUES (v_product_id, 14.00, 300, DATE '2026-10-15', 'historico')
    ON CONFLICT (product_id, price, observed_at) DO NOTHING;

    -- Se reconstruye la simulacion semilla para que siempre refleje los datos actuales
    DELETE FROM simulations
     WHERE user_id = v_user_id AND product_id = v_product_id AND name = 'Caso base';

    CALL sp_run_simulation(
        v_user_id, v_product_id, 'Caso base',
        4.0, 25.0, 0.5, NULL, NULL, v_sim_id
    );
END; $$;
