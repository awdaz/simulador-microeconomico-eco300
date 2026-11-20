# Simulador Microeconómico — ECO300

Proyecto ECO300 · Grupo 99 · Estado actual: **stack completo implementado y verificado** (base de datos + API + frontend + Docker).

| Fase | Estado |
|---|---|
| Base de datos PostgreSQL (esquema, seeders, PA, funciones, triggers, vistas) | ✅ |
| Backend Laravel 12 + Sanctum + API REST | ✅ |
| Frontend React + Vite + Recharts | ✅ |
| Docker full stack (4 contenedores) | ✅ |
| Repositorio GitHub | ⏳ |

## Stack

| Capa | Tecnología |
|---|---|
| Base de datos | PostgreSQL 16 |
| Backend | Laravel 12 (PHP 8.3) + Sanctum |
| Frontend | React 18 + Vite + React Router + Axios + Recharts |
| Contenedores | Docker Compose (postgres, pgAdmin, backend, frontend/nginx) |

## Arranque rápido (stack completo)

```powershell
# 1) Base de datos (idempotente; crea datos demo si la BD está vacía)
powershell -ExecutionPolicy Bypass -File scripts\init_db.ps1

# 2) Levantar API + frontend
docker compose up -d --build
```

> Si la BD ya fue inicializada y solo quieres levantar la app, basta con `docker compose up -d`.

Servicios resultantes:

| Servicio | URL / Host | Credenciales |
|---|---|---|
| Frontend | http://localhost:5173 | `admin@economia.test` / `password123` |
| Backend API | http://localhost:8000/api | token Bearer (devuelto por `/api/login`) |
| pgAdmin | http://localhost:5050 | `admin@economia.com` / `admin` |
| PostgreSQL | `localhost:5433` | DB `economia` · usuario `economia` · password `economia` |

Usuarios demo:

| Rol | Email | Password |
|---|---|---|
| `admin` | `admin@economia.test` | `password123` |
| `user` | `user@economia.test` | `password123` |

También existe registro público en `/register` (rol `user` por defecto).

En pgAdmin: *Add New Server → General: nombre `economia` → Connection: Host `postgres`, Port `5432`, Username `economia`, Password `economia`*.

> Nota: pgAdmin exige un correo con dominio público válido, por eso usa `.com`. El correo de la app sigue siendo `.test`.

## Verificación

```powershell
# Base de datos (aserciones del caso base + pruebas de funciones/triggers)
powershell -ExecutionPolicy Bypass -File scripts\init_db.ps1

# API de extremo a extremo (login, dashboard, productos, observaciones,
# simulación, curva 43 filas, refresh, permisos 403/401)
powershell -ExecutionPolicy Bypass -File scripts\test_api.ps1
```

Resultado esperado de la API: todas las pruebas pasan, grilla de 43 filas, `P*=12`, `Q*=400`, `Π*=1700`, `EPD=1.50`.

## Estructura

```
docker-compose.yml          PostgreSQL + pgAdmin + backend Laravel + frontend nginx
.env.example                Variables de entorno del stack
scripts/
  init_db.ps1 / .sh         Script de ejecución de la BD
  test_api.ps1              Pruebas de extremo a extremo de la API
backend/                    Aplicación Laravel 12 (ver backend/README.md)
frontend/                   Aplicación React + Vite (ver frontend/README.md)
database/sql/
  00_run_all.sql            Punto de entrada
  01_schema.sql             11 tablas + 2 vistas + índices
  02_functions.sql          8 funciones + 5 funciones de trigger
  03_procedures.sql         4 procedimientos almacenados
  04_triggers.sql           21 triggers
  05_seed.sql               Seeders del caso de estudio
  06_api_helpers.sql        fn_run_simulation (wrapper del PA para Laravel)
  98_tests.sql              Pruebas de funciones y triggers (opcional)
  99_verify.sql             Verificación con aserciones
```

## Objeto catalogado

**Funciones**

| Función | Uso |
|---|---|
| `fn_calcular_pendiente` | `b = (Q1-Q2)/(P2-P1)` con validación |
| `fn_calcular_intercepto` | `a = Q + b·P` |
| `fn_estimar_demanda` | Regresión por mínimos cuadrados de todas las observaciones |
| `fn_calcular_demanda` | `Q = GREATEST(a - b·P, 0)` |
| `fn_calcular_beneficio` | `Π = P·Q - (CF + CV·Q)` |
| `fn_calcular_epd` | `EPD = b·P/Q` |
| `fn_clasificar_demanda` | elástica / inelástica / unitaria |
| `fn_calcular_optimo` | `P*`, `Q*`, `Π*`, EPD y puntos de equilibrio |

**Procedimientos almacenados (PA)**

| PA | Uso |
|---|---|
| `sp_generar_resultados` | Genera la grilla precio→cantidad/ingreso/costo/beneficio/EPD |
| `sp_run_simulation` | Ejecuta y guarda una simulación nueva |
| `sp_refresh_simulation` | Recalcula una simulación existente |
| `sp_seed_case_study` | Carga el caso de estudio de forma idempotente |

**Triggers**

- `updated_at` automático en `users`, `businesses`, `products`, `simulations`.
- Auditoría `INSERT/UPDATE/DELETE` en las 4 tablas del dominio → `audit_log`.
- Validación de precios/cantidades en `price_observations`.
- Historial de cambios de costo en `product_cost_history`.
- Validación de consistencia EPD ↔ tipo de demanda en `simulations`.

## Caso de estudio semilla

Datos: `P1=10, Q1=500`; `P2=14, Q2=300`; `CV=4 Bs`; `CF=1500 Bs`.

| Métrica | Resultado verificado |
|---|---|
| Demanda | `Q = 1000 - 50P` |
| Precio óptimo | `12.00 Bs.` |
| Cantidad óptima | `400 unidades` |
| Beneficio máximo | `1700.00 Bs.` |
| EPD | `1.50` → **elástica** |
| Equilibrio | `6.17 Bs.` y `17.83 Bs.` |
| Grilla generada | 43 filas (4.00 → 25.00 paso 0.50) |

## Comandos útiles

```powershell
# Ver el resumen
docker compose exec -T postgres psql -U economia -d economia -c "SELECT * FROM v_resumen_simulaciones;"

# Reejecutar solo los seeders (borra y recrea "Caso base": cambia su id)
docker compose exec -T postgres psql -U economia -d economia -c "CALL sp_seed_case_study();"

# Refrescar una simulación por id
docker compose exec -T postgres psql -U economia -d economia -c "CALL sp_refresh_simulation(1);"

# Ver la curva de beneficios de la última simulación base
docker compose exec -T postgres psql -U economia -d economia -c "SELECT * FROM v_curva_beneficios WHERE simulation_id = (SELECT id FROM simulations WHERE name = 'Caso base' ORDER BY id DESC LIMIT 1);"

# Correr las pruebas de funciones y triggers
docker compose exec -T postgres psql -U economia -d economia -f /sql/98_tests.sql

# Ver estado de los contenedores
docker compose ps
```

### Backend

```powershell
# Pruebas de la API (requiere la API levantada)
powershell -ExecutionPolicy Bypass -File scripts\test_api.ps1

# Ver rutas disponibles
cd backend; php artisan route:list --path=api
```

### Frontend

```powershell
# Desarrollo local (sin Docker), requiere la API en :8000
cd frontend
npm install
npm run dev        # http://localhost:5173

# Build de producción
npm run build
```

La URL de la API se inyecta en build mediante `VITE_API_URL` (por defecto `http://localhost:8000/api`). El contenedor del frontend la recibe desde `.env` / `docker-compose.yml`.

## Notas de Docker

- El backend usa `php artisan serve --no-reload`: Laravel 12 filtra variables de entorno hacia el proceso hijo salvo con esa opción; sin ella el contenedor intentaba conectarse a `127.0.0.1:5433` en vez de `postgres:5432`.
- PostgreSQL se publica en el host como `5433` para no colisionar con otras instancias locales; dentro de la red de Docker se usa `postgres:5432`.
- No ejecutar migraciones Laravel sobre esta BD: el esquema es propiedad de los scripts SQL.
