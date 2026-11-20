-- ============================================================
-- 02_functions.sql - Funciones del modelo microeconomico
-- Todas usan: Q = a - b*P , con b > 0 (sensibilidad de la demanda)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Pendiente positiva b = (Q1 - Q2) / (P2 - P1)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_pendiente(
    p_p1 NUMERIC, p_q1 NUMERIC, p_p2 NUMERIC, p_q2 NUMERIC
) RETURNS NUMERIC
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_b NUMERIC;
BEGIN
    IF p_p1 = p_p2 THEN
        RAISE EXCEPTION 'Los precios historicos no pueden ser identicos';
    END IF;
    v_b := (p_q1 - p_q2) / (p_p2 - p_p1);
    IF v_b <= 0 THEN
        RAISE EXCEPTION 'Los datos no describen una demanda decreciente (b = %)', v_b;
    END IF;
    RETURN v_b;
END; $$;

-- ------------------------------------------------------------
-- 2. Intercepto a = Q + b*P
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_intercepto(
    p_p NUMERIC, p_q NUMERIC, p_b NUMERIC
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT p_q + p_b * p_p;
$$;

-- ------------------------------------------------------------
-- 3. Estimacion por minimos cuadrados de TODAS las observaciones
--    Devuelve (a, b) de Q = a - b*P
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_estimar_demanda(p_product_id BIGINT)
RETURNS TABLE (a NUMERIC, b NUMERIC)
LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_n   INTEGER;
    v_sp  NUMERIC;
    v_sq  NUMERIC;
    v_spq NUMERIC;
    v_sp2 NUMERIC;
    v_den NUMERIC;
BEGIN
    SELECT COUNT(*),
           COALESCE(SUM(price), 0),
           COALESCE(SUM(quantity_demanded), 0),
           COALESCE(SUM(price * quantity_demanded), 0),
           COALESCE(SUM(price * price), 0)
      INTO v_n, v_sp, v_sq, v_spq, v_sp2
      FROM price_observations
     WHERE product_id = p_product_id;

    IF v_n < 2 THEN
        RAISE EXCEPTION 'Se requieren al menos 2 observaciones para estimar la demanda del producto %', p_product_id;
    END IF;

    v_den := v_n * v_sp2 - v_sp * v_sp;
    IF v_den = 0 THEN
        RAISE EXCEPTION 'Todos los precios observados son iguales; no se puede estimar la pendiente';
    END IF;

    b := -(v_n * v_spq - v_sp * v_sq) / v_den;   -- pendiente negativa => b positivo
    a := (v_sq + b * v_sp) / v_n;

    IF b <= 0 THEN
        RAISE EXCEPTION 'Los datos no describen una demanda decreciente (b = %)', b;
    END IF;

    RETURN NEXT;
END; $$;

-- ------------------------------------------------------------
-- 4. Demanda en un precio dado (nunca negativa)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_demanda(
    p_a NUMERIC, p_b NUMERIC, p_price NUMERIC
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT GREATEST(p_a - p_b * p_price, 0);
$$;

-- ------------------------------------------------------------
-- 5. Beneficio: IT - CT = (P*Q) - (CF + CV*Q)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_beneficio(
    p_a NUMERIC, p_b NUMERIC, p_price NUMERIC,
    p_cv NUMERIC, p_cf NUMERIC
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT fn_calcular_demanda(p_a, p_b, p_price) * (p_price - p_cv) - p_cf;
$$;

-- ------------------------------------------------------------
-- 6. Elasticidad precio de la demanda: EPD = b*P / Q
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_epd(
    p_a NUMERIC, p_b NUMERIC, p_price NUMERIC
) RETURNS NUMERIC
LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
             WHEN (p_a - p_b * p_price) > 0
             THEN ROUND(p_b * p_price / (p_a - p_b * p_price), 6)
             ELSE 0
           END;
$$;

-- ------------------------------------------------------------
-- 7. Clasificacion de la demanda segun |EPD|
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_clasificar_demanda(p_epd NUMERIC)
RETURNS VARCHAR
LANGUAGE plpgsql IMMUTABLE AS $$
BEGIN
    IF p_epd > 1.0001 THEN
        RETURN 'elastic';
    ELSIF p_epd < 0.9999 THEN
        RETURN 'inelastic';
    END IF;
    RETURN 'unitary';
END; $$;

-- ------------------------------------------------------------
-- 8. Optimo economico (IMg = CMg) y puntos de equilibrio
--    P* = (a + b*CV) / (2b)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_calcular_optimo(
    p_a NUMERIC, p_b NUMERIC, p_cv NUMERIC, p_cf NUMERIC
)
RETURNS TABLE (
    optimal_price    NUMERIC,
    optimal_quantity NUMERIC,
    max_profit       NUMERIC,
    epd              NUMERIC,
    demand_type      VARCHAR,
    break_even_min   NUMERIC,
    break_even_max   NUMERIC
)
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    v_num     NUMERIC;   -- a + b*CV
    v_const   NUMERIC;   -- a*CV + CF
    v_disc    NUMERIC;
BEGIN
    IF p_b <= 0 THEN
        RAISE EXCEPTION 'La sensibilidad b debe ser mayor a cero';
    END IF;

    optimal_price := (p_a + p_b * p_cv) / (2 * p_b);
    optimal_quantity := p_a - p_b * optimal_price;

    IF optimal_quantity <= 0 THEN
        RAISE EXCEPTION 'El precio optimo supera la saturacion del mercado (Q <= 0)';
    END IF;

    max_profit := optimal_quantity * (optimal_price - p_cv) - p_cf;
    epd := fn_calcular_epd(p_a, p_b, optimal_price);
    demand_type := fn_clasificar_demanda(epd);

    v_num   := p_a + p_b * p_cv;
    v_const := p_a * p_cv + p_cf;
    v_disc  := v_num * v_num - 4 * p_b * v_const;

    IF v_disc >= 0 THEN
        break_even_min := (v_num - SQRT(v_disc)) / (2 * p_b);
        break_even_max := (v_num + SQRT(v_disc)) / (2 * p_b);
    ELSE
        break_even_min := NULL;
        break_even_max := NULL;
    END IF;

    RETURN NEXT;
END; $$;

-- ============================================================
-- FUNCIONES DE TRIGGER
-- ============================================================

-- Actualiza updated_at automaticamente
CREATE OR REPLACE FUNCTION trg_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END; $$;

-- Auditoria generica de INSERT / UPDATE / DELETE
CREATE OR REPLACE FUNCTION trg_audit_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_id    BIGINT;
    v_accion VARCHAR(20);
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id := OLD.id;
        v_accion := 'Eliminado';
    ELSE
        v_id := NEW.id;
        v_accion := CASE TG_OP WHEN 'INSERT' THEN 'Creado' ELSE 'Actualizado' END;
    END IF;

    INSERT INTO audit_log (table_name, operation, record_id, description)
    VALUES (TG_TABLE_NAME, TG_OP, v_id,
            FORMAT('%s %s #%s', v_accion, TG_TABLE_NAME, v_id));

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END; $$;

-- Normaliza y valida cada observacion de precio/cantidad
CREATE OR REPLACE FUNCTION trg_validar_observacion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.price IS NULL OR NEW.price <= 0 THEN
        RAISE EXCEPTION 'El precio debe ser mayor a 0';
    END IF;
    IF NEW.quantity_demanded IS NULL OR NEW.quantity_demanded < 0 THEN
        RAISE EXCEPTION 'La cantidad demandada no puede ser negativa';
    END IF;
    IF NEW.source IS NULL OR BTRIM(NEW.source) = '' THEN
        NEW.source := 'historico';
    END IF;
    IF NEW.observed_at IS NULL THEN
        NEW.observed_at := CURRENT_DATE;
    END IF;
    RETURN NEW;
END; $$;

-- Guarda el historial de cambios de costo variable unitario
CREATE OR REPLACE FUNCTION trg_audit_costo_producto()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.variable_cost_unit IS DISTINCT FROM NEW.variable_cost_unit THEN
        INSERT INTO product_cost_history (product_id, old_cost, new_cost)
        VALUES (NEW.id, OLD.variable_cost_unit, NEW.variable_cost_unit);
    END IF;
    RETURN NEW;
END; $$;

-- Valida consistencia interna de una simulacion antes de grabarla
CREATE OR REPLACE FUNCTION trg_validar_simulacion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.price_min <= 0 OR NEW.price_max <= NEW.price_min OR NEW.price_step <= 0 THEN
        RAISE EXCEPTION 'Rango de precios invalido (min=%, max=%, paso=%)',
            NEW.price_min, NEW.price_max, NEW.price_step;
    END IF;
    IF NEW.slope_b <= 0 THEN
        RAISE EXCEPTION 'La sensibilidad b debe ser mayor a cero';
    END IF;
    IF NEW.demand_type <> fn_clasificar_demanda(NEW.epd) THEN
        RAISE EXCEPTION 'El tipo de demanda (%) no coincide con la EPD (%)',
            NEW.demand_type, NEW.epd;
    END IF;
    RETURN NEW;
END; $$;
