-- ============================================================
-- 01_schema.sql - Esquema del simulador microeconomico
-- PostgreSQL 16 | Script idempotente (se puede repetir)
-- Convencion: a = intercepto, b = sensibilidad positiva, Q = a - b*P
-- ============================================================

-- ------------------------------------------------------------
-- Autenticacion (compatible con Laravel Sanctum)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id                 BIGSERIAL PRIMARY KEY,
    name               VARCHAR(120) NOT NULL,
    email              VARCHAR(190) NOT NULL UNIQUE,
    password           VARCHAR(255) NOT NULL,
    role               VARCHAR(20)  NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
    email_verified_at  TIMESTAMPTZ,
    remember_token     VARCHAR(100),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS personal_access_tokens (
    id              BIGSERIAL PRIMARY KEY,
    tokenable_type  VARCHAR(255) NOT NULL,
    tokenable_id    BIGINT       NOT NULL,
    name            VARCHAR(255) NOT NULL,
    token           VARCHAR(64)  NOT NULL UNIQUE,
    abilities       TEXT,
    last_used_at    TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pat_tokenable
    ON personal_access_tokens (tokenable_type, tokenable_id);

CREATE TABLE IF NOT EXISTS sessions (
    id            VARCHAR(255) PRIMARY KEY,
    user_id       BIGINT       REFERENCES users(id) ON DELETE CASCADE,
    ip_address    VARCHAR(45),
    user_agent    TEXT,
    payload       TEXT NOT NULL,
    last_activity BIGINT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_last_activity ON sessions (last_activity);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    email      VARCHAR(190) PRIMARY KEY,
    token      VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ
);

-- ------------------------------------------------------------
-- Dominio de negocio
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS businesses (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             BIGINT       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name                VARCHAR(150) NOT NULL,
    currency            VARCHAR(3)   NOT NULL DEFAULT 'Bs',
    fixed_cost_monthly  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (fixed_cost_monthly >= 0),
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);
CREATE INDEX IF NOT EXISTS idx_businesses_user_id ON businesses (user_id);

CREATE TABLE IF NOT EXISTS products (
    id                  BIGSERIAL PRIMARY KEY,
    business_id         BIGINT       NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name                VARCHAR(150) NOT NULL,
    sku                 VARCHAR(50),
    unit                VARCHAR(30)  NOT NULL DEFAULT 'unidad',
    variable_cost_unit  NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (variable_cost_unit >= 0),
    current_stock       INTEGER      NOT NULL DEFAULT 0 CHECK (current_stock >= 0),
    active              BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (business_id, sku)
);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON products (business_id);

CREATE TABLE IF NOT EXISTS price_observations (
    id                 BIGSERIAL PRIMARY KEY,
    product_id         BIGINT       NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    price              NUMERIC(12,2) NOT NULL CHECK (price > 0),
    quantity_demanded  INTEGER      NOT NULL CHECK (quantity_demanded >= 0),
    observed_at        DATE         NOT NULL DEFAULT CURRENT_DATE,
    source             VARCHAR(20)  NOT NULL DEFAULT 'historico'
                       CHECK (source IN ('historico', 'estimado')),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, price, observed_at)
);
CREATE INDEX IF NOT EXISTS idx_observations_product_id ON price_observations (product_id);

CREATE TABLE IF NOT EXISTS simulations (
    id                 BIGSERIAL PRIMARY KEY,
    user_id            BIGINT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id         BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name               VARCHAR(150)  NOT NULL,
    intercept_a        NUMERIC(16,4) NOT NULL,
    slope_b            NUMERIC(16,4) NOT NULL CHECK (slope_b > 0),
    variable_cost      NUMERIC(14,2) NOT NULL CHECK (variable_cost >= 0),
    fixed_cost         NUMERIC(14,2) NOT NULL CHECK (fixed_cost >= 0),
    optimal_price      NUMERIC(12,2) NOT NULL,
    optimal_quantity   NUMERIC(16,4) NOT NULL,
    max_profit         NUMERIC(16,2) NOT NULL,
    epd                NUMERIC(10,4) NOT NULL,
    demand_type        VARCHAR(20)   NOT NULL
                       CHECK (demand_type IN ('elastic', 'inelastic', 'unitary')),
    break_even_min     NUMERIC(12,2),
    break_even_max     NUMERIC(12,2),
    price_min          NUMERIC(12,2) NOT NULL,
    price_max          NUMERIC(12,2) NOT NULL,
    price_step         NUMERIC(12,2) NOT NULL CHECK (price_step > 0),
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CHECK (price_min < price_max),
    UNIQUE (user_id, product_id, name)
);
CREATE INDEX IF NOT EXISTS idx_simulations_user_id ON simulations (user_id);
CREATE INDEX IF NOT EXISTS idx_simulations_product_id ON simulations (product_id);
CREATE INDEX IF NOT EXISTS idx_simulations_created_at ON simulations (created_at DESC);

CREATE TABLE IF NOT EXISTS simulation_results (
    id              BIGSERIAL PRIMARY KEY,
    simulation_id   BIGINT        NOT NULL REFERENCES simulations(id) ON DELETE CASCADE,
    price           NUMERIC(12,2) NOT NULL,
    quantity        NUMERIC(16,4) NOT NULL,
    revenue         NUMERIC(16,2) NOT NULL,
    total_cost      NUMERIC(16,2) NOT NULL,
    profit          NUMERIC(16,2) NOT NULL,
    epd             NUMERIC(10,4) NOT NULL,
    is_optimal      BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (simulation_id, price)
);
CREATE INDEX IF NOT EXISTS idx_sim_results_simulation_id
    ON simulation_results (simulation_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_sim_results_one_optimal
    ON simulation_results (simulation_id) WHERE is_optimal;

-- ------------------------------------------------------------
-- Auditoria e historial de costos (alimentados por triggers)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  VARCHAR(60)  NOT NULL,
    operation   VARCHAR(10)  NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_id   BIGINT       NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_log_table_record
    ON audit_log (table_name, record_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
    ON audit_log (created_at DESC);

CREATE TABLE IF NOT EXISTS product_cost_history (
    id         BIGSERIAL PRIMARY KEY,
    product_id BIGINT        NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    old_cost   NUMERIC(14,2) NOT NULL,
    new_cost   NUMERIC(14,2) NOT NULL,
    changed_at TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cost_history_product_id
    ON product_cost_history (product_id);

-- ------------------------------------------------------------
-- Vistas de apoyo para el dashboard
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_resumen_simulaciones AS
SELECT s.id,
       s.name,
       u.name AS usuario,
       b.name AS negocio,
       p.name AS producto,
       s.intercept_a,
       s.slope_b,
       s.variable_cost,
       s.fixed_cost,
       s.optimal_price,
       s.optimal_quantity,
       s.max_profit,
       s.epd,
       s.demand_type,
       s.break_even_min,
       s.break_even_max,
       s.created_at
  FROM simulations s
  JOIN users u       ON u.id = s.user_id
  JOIN products p    ON p.id = s.product_id
  JOIN businesses b  ON b.id = p.business_id;

CREATE OR REPLACE VIEW v_curva_beneficios AS
SELECT r.simulation_id,
       r.price,
       r.quantity,
       r.revenue,
       r.total_cost,
       r.profit,
       r.epd,
       r.is_optimal
  FROM simulation_results r;
