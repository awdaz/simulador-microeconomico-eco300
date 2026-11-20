#!/usr/bin/env bash
# ============================================================
# init_db.sh - Levanta la BD, aplica SQL y verifica el caso base
# Uso:  bash scripts/init_db.sh
# ============================================================
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  cp .env.example .env
  echo "[0/5] Creado .env desde .env.example"
fi

echo "[1/5] Levantando PostgreSQL y pgAdmin..."
docker compose up -d postgres pgadmin

echo "[2/5] Esperando a que PostgreSQL este healthy..."
STATUS=""
for _ in $(seq 1 40); do
  STATUS="$(docker inspect --format '{{.State.Health.Status}}' simeco-postgres 2>/dev/null || true)"
  [ "$STATUS" = "healthy" ] && break
  sleep 2
done
if [ "$STATUS" != "healthy" ]; then
  echo "PostgreSQL no alcanzo el estado 'healthy' (estado: '$STATUS')" >&2
  exit 1
fi
echo "      PostgreSQL listo."

echo "[3/5] Aplicando esquema, funciones, PA, triggers y seeders..."
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/00_run_all.sql'

echo "[4/5] Verificando el caso de estudio..."
docker compose exec -T postgres sh -c 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/99_verify.sql'

echo "[5/5] Listo."
echo ""
echo "  pgAdmin : http://localhost:5050  (admin@economia.com / admin)"
echo "  Postgres: localhost:5433         (economia / economia / economia)"
