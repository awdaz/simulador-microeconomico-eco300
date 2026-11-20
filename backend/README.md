# Backend Laravel — Simulador Microeconómico ECO300

API REST sobre PostgreSQL. Autenticación con **Laravel Sanctum** (Bearer token).

## Arranque

### Desde Docker (recomendado)

```powershell
docker compose up -d --build backend
```

La API queda en `http://localhost:8000/api`. Dentro de la red Docker el host de la BD es `postgres` (ya configurado en el compose).

### Local (XAMPP / PHP 8.2+)

```powershell
cd backend
copy .env.example .env
php artisan key:generate
php artisan serve --host=127.0.0.1 --port=8000
```

> El puerto publicado de PostgreSQL es **5433** (el 5432 suele estar ocupado por una instalación local). Ajusta `DB_PORT` en `.env` si hace falta.

## Credenciales demo

| Correo | Contraseña | Rol |
|---|---|---|
| `admin@economia.test` | `password123` | admin |
| `user@economia.test` | `password123` | user |

El registro público (`POST /api/register`) crea usuarios con rol `user`.

## Endpoints

### Públicos

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/register` | Registro público (nombre, email, password, password_confirmation) |
| POST | `/api/login` | Login → devuelve `token` |

### Autenticados (cabecera `Authorization: Bearer <token>`)

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/logout` | Revoca el token actual |
| GET | `/api/me` | Usuario autenticado |
| GET | `/api/dashboard` | Resumen + última simulación con su curva |
| GET | `/api/products` | Productos del usuario |
| GET | `/api/products/{product}` | Detalle (observaciones + historial de costos) |
| GET | `/api/products/{product}/estimate` | Estimación `Q = a - bP` por mínimos cuadrados |
| GET | `/api/products/{product}/observations` | Observaciones de precio |
| POST | `/api/products/{product}/observations` | Alta de observación |
| DELETE | `/api/products/{product}/observations/{observation}` | Baja de observación |
| GET | `/api/simulations` | Lista paginada de simulaciones |
| POST | `/api/simulations` | Ejecuta una simulación (llama al PA) |
| GET | `/api/simulations/{simulation}` | Detalle con curva |
| GET | `/api/simulations/{simulation}/curve` | Grilla de precios (43 filas en el caso base) |
| POST | `/api/simulations/{simulation}/refresh` | Recalcula con los costos actuales |
| DELETE | `/api/simulations/{simulation}` | Elimina la simulación |

### Solo administrador

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/admin/audit-log` | Últimas 100 entradas de auditoría |
| GET | `/api/admin/simulations` | Últimas 100 simulaciones de todos los usuarios |

### Ejemplo: ejecutar una simulación

```powershell
$login = Invoke-RestMethod http://localhost:8000/api/login -Method Post `
  -ContentType application/json `
  -Body '{"email":"admin@economia.test","password":"password123"}'

$headers = @{ Authorization = "Bearer $($login.token)" }

$body = @{
  product_id  = 1
  name        = 'Mi simulacion'
  price_min   = 4
  price_max   = 25
  price_step  = 0.5
} | ConvertTo-Json

Invoke-RestMethod http://localhost:8000/api/simulations -Method Post `
  -Headers $headers -ContentType application/json -Body $body
```

Respuesta esperada (caso base): `optimal_price=12`, `optimal_quantity=400`, `max_profit=1700`, `epd=1.5`, `demand_type=elastic`.

## Estructura

```
app/
  Http/
    Controllers/Api/   Auth, Dashboard, Product, Observation, Simulation, Admin
    Requests/          Validación (Register, Login, StoreSimulation, StoreObservation)
  Models/              User, Business, Product, PriceObservation, Simulation,
                       SimulationResult, AuditLog, ProductCostHistory
config/cors.php        Orígenes permitidos (React en :5173)
routes/api.php         Todas las rutas
database/sql/06_api_helpers.sql   fn_run_simulation (wrapper del PA con OUT)
```

> El esquema y los datos los gestionan los scripts SQL de `database/sql`. No ejecutar `php artisan migrate` sobre PostgreSQL: las tablas Laravel ya están creadas por `01_schema.sql`.
