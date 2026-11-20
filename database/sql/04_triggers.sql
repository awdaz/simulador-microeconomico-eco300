-- ============================================================
-- 04_triggers.sql - Triggers del simulador
-- ============================================================

-- ------------------------------------------------------------
-- updated_at automatico
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_businesses_updated_at ON businesses;
CREATE TRIGGER trg_businesses_updated_at
    BEFORE UPDATE ON businesses
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_products_updated_at ON products;
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

DROP TRIGGER IF EXISTS trg_simulations_updated_at ON simulations;
CREATE TRIGGER trg_simulations_updated_at
    BEFORE UPDATE ON simulations
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

-- ------------------------------------------------------------
-- Auditoria de operaciones sobre tablas del dominio
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_audit_businesses ON businesses;
CREATE TRIGGER trg_audit_businesses
    AFTER INSERT OR UPDATE OR DELETE ON businesses
    FOR EACH ROW EXECUTE FUNCTION trg_audit_changes();

DROP TRIGGER IF EXISTS trg_audit_products ON products;
CREATE TRIGGER trg_audit_products
    AFTER INSERT OR UPDATE OR DELETE ON products
    FOR EACH ROW EXECUTE FUNCTION trg_audit_changes();

DROP TRIGGER IF EXISTS trg_audit_observations ON price_observations;
CREATE TRIGGER trg_audit_observations
    AFTER INSERT OR UPDATE OR DELETE ON price_observations
    FOR EACH ROW EXECUTE FUNCTION trg_audit_changes();

DROP TRIGGER IF EXISTS trg_audit_simulations ON simulations;
CREATE TRIGGER trg_audit_simulations
    AFTER INSERT OR UPDATE OR DELETE ON simulations
    FOR EACH ROW EXECUTE FUNCTION trg_audit_changes();

-- ------------------------------------------------------------
-- Validacion de observaciones precio/cantidad
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validate_observations ON price_observations;
CREATE TRIGGER trg_validate_observations
    BEFORE INSERT OR UPDATE ON price_observations
    FOR EACH ROW EXECUTE FUNCTION trg_validar_observacion();

-- ------------------------------------------------------------
-- Historial de cambios de costo variable
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_cost_history_products ON products;
CREATE TRIGGER trg_cost_history_products
    AFTER UPDATE OF variable_cost_unit ON products
    FOR EACH ROW
    WHEN (OLD.variable_cost_unit IS DISTINCT FROM NEW.variable_cost_unit)
    EXECUTE FUNCTION trg_audit_costo_producto();

-- ------------------------------------------------------------
-- Validacion de consistencia de simulaciones
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_validate_simulations ON simulations;
CREATE TRIGGER trg_validate_simulations
    BEFORE INSERT OR UPDATE ON simulations
    FOR EACH ROW EXECUTE FUNCTION trg_validar_simulacion();
