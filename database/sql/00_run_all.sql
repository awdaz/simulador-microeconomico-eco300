-- ============================================================
-- 00_run_all.sql
-- Punto de entrada único. Se ejecuta desde dentro del contenedor:
--   psql -U economia -d economia -f /sql/00_run_all.sql
-- ============================================================
\set ON_ERROR_STOP on

\echo '==> 01_schema.sql   (tablas, indices y vistas)'
\i /sql/01_schema.sql

\echo '==> 02_functions.sql (funciones y funciones de trigger)'
\i /sql/02_functions.sql

\echo '==> 03_procedures.sql (procedimientos almacenados / PA)'
\i /sql/03_procedures.sql

\echo '==> 04_triggers.sql   (triggers)'
\i /sql/04_triggers.sql

\echo '==> 05_seed.sql       (seeders / datos de prueba)'
\i /sql/05_seed.sql

\echo '==> 06_api_helpers.sql (helpers para la API)'
\i /sql/06_api_helpers.sql

\echo '==> Instalacion de la base de datos completada.'
