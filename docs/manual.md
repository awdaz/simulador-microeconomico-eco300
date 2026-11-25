# Manual del Simulador Microeconómico ECO300

**Proyecto ECO300 · Grupo 99**

Manual de usuario y documentación técnica. Cubre desde el ingreso a la aplicación hasta el modelo económico, la API REST, la base de datos y el despliegue con Docker.

> La fuente de verdad de este documento es `docs/manual.md`. Las versiones PDF, DOCX y HTML se generan con `python scripts/build_manual.py`.

---

## Índice

**Parte I — Usuario**

1. [Qué hace el simulador](#1-qué-hace-el-simulador)
2. [Acceso a la aplicación](#2-acceso-a-la-aplicación)
3. [Pantallas y navegación](#3-pantallas-y-navegación)
4. [Flujo de trabajo paso a paso](#4-flujo-de-trabajo-paso-a-paso)
5. [Cómo interpretar los resultados](#5-cómo-interpretar-los-resultados)
6. [Mensajes de error frecuentes](#6-mensajes-de-error-frecuentes)
7. [Límites y comportamientos a tener en cuenta](#7-límites-y-comportamientos-a-tener-en-cuenta)

**Parte II — Desarrolladores**

8. [Arquitectura y stack](#8-arquitectura-y-stack)
9. [Arranque rápido](#9-arranque-rápido)
10. [Servicios, puertos y credenciales](#10-servicios-puertos-y-credenciales)
11. [Estructura del repositorio](#11-estructura-del-repositorio)
12. [Base de datos](#12-base-de-datos)
13. [API REST](#13-api-rest)
14. [Cómo se ejecuta una simulación](#14-cómo-se-ejecuta-una-simulación)
15. [Autenticación, roles y CORS](#15-autenticación-roles-y-cors)
16. [Verificación y pruebas](#16-verificación-y-pruebas)
17. [Configuración](#17-configuración)
18. [Comandos útiles](#18-comandos-útiles)
19. [Solución de problemas](#19-solución-de-problemas)
20. [Discrepancias conocidas entre README y código](#20-discrepancias-conocidas-entre-readme-y-código)

---

# Parte I — Manual de usuario

## 1. Qué hace el simulador

La aplicación estima una **función de demanda lineal** a partir de precios observados y calcula el precio que maximiza el beneficio.

| Concepto | Fórmula | Significado |
|---|---|---|
| Demanda | `Q = a − b·P` | A mayor precio, menor cantidad demandada (`b > 0`). |
| Ingreso | `IT = P · Q` | Precio por cantidad vendida. |
| Costo total | `CT = CF + CV·Q` | Costo fijo más costo variable unitario por unidad. |
| Beneficio | `Π = IT − CT` | Utilidad. |
| Precio óptimo | `P* = (a + b·CV) / (2b)` | Precio que maximiza `Π`. |
| Cantidad óptima | `Q* = a − b·P*` | Demanda al precio óptimo. |
| Elasticidad (EPD) | `EPD = b·P / Q` | Sensibilidad de la demanda al precio. |
| Equilibrio | `Π = 0` | Precios donde no hay pérdida (si existen). |

Clasificación de la demanda según EPD:

| EPD | Tipo | Etiqueta en pantalla |
|---|---|---|
| `> 1` | `elastic` | Elástica / Demanda elástica |
| `≈ 1` | `unitary` | Unitaria / Demanda unitaria |
| `< 1` | `inelastic` | Inelástica / Demanda inelástica |

La ecuación se estima por **mínimos cuadrados** usando todas las observaciones cargadas del producto. Se necesitan **al menos 2 observaciones con precios distintos**.

## 2. Acceso a la aplicación

| Servicio | URL |
|---|---|
| Aplicación (frontend) | http://localhost:5173 |
| API (backend) | http://localhost:8000/api |
| pgAdmin | http://localhost:5050 |

### Ingresar

1. Abrir http://localhost:5173. Si no hay sesión, se redirige a `/login`.
2. El formulario viene prellenado con la cuenta demo de administrador.

   | Campo | Valor |
   |---|---|
   | Correo electrónico | `admin@economia.test` |
   | Contraseña | `password123` |

3. Pulsar **Ingresar**. Se guarda un token en el navegador y se abre `/dashboard`.

También está la cuenta de usuario `user@economia.test` / `password123`.

### Crear una cuenta

En `/login`, pulsar **Regístrate** e completar:

| Campo | Requisito |
|---|---|
| Nombre | Obligatorio, hasta 120 caracteres |
| Correo electrónico | Obligatorio, válido y no registrado |
| Contraseña | Mínimo 8 caracteres |
| Confirmar contraseña | Debe coincidir con la contraseña |

Pulsar **Registrarse**. La cuenta se crea con rol `user` (la pantalla dice «rol estudiante», pero el rol real en el sistema es `user`).

> Si las contraseñas no coinciden, la propia pantalla muestra «Las contraseñas no coinciden.» y no envía la petición.

### Cerrar sesión

Pulsar **Cerrar sesión** en la parte inferior del menú lateral. Se revoca el token, se limpian los datos guardados y vuelve a `/login`.

## 3. Pantallas y navegación

El menú lateral («ECO — Simulador Microeconómico · ECO300») contiene:

| Opción | Ruta | Qué muestra | Acceso |
|---|---|---|---|
| ▦ Resumen | `/dashboard` | KPIs, última simulación y gráfico de beneficios | Todos |
| ◈ Simulaciones | `/simulations` | Listado y creación de escenarios | Todos |
| ▤ Productos | `/products` | Productos, estimación y observaciones de precio | Todos |
| ⚙ Administración | `/admin` | Auditoría y simulaciones de todos los usuarios | Solo `admin` |

Cualquier ruta desconocida redirige a `/dashboard` y, si no hay sesión, a `/login`. Mientras se valida la sesión se muestra «Cargando sesión…».

La moneda se muestra con formato `es-BO` / `BOB` y dos decimales en KPIs y tablas.

## 4. Flujo de trabajo paso a paso

### 4.1 Revisar productos y observaciones

Ir a **Productos** (`/products`).

Con la cuenta demo se selecciona automáticamente el producto del caso de estudio:

| Dato | Valor |
|---|---|
| Producto | Producto de alta rotacion |
| SKU | `PAR-001` |
| Unidad | unidad |
| Costo variable unitario (CV) | `4.00` |
| Stock | 100 |
| Estado | Activo |
| Empresa | Tienda Minorista Santa Cruz (CF = 1500) |

En el panel aparece la **función de demanda estimada**, por ejemplo `Q = 1000.0000 - 50.0000P`, junto a `Intercepto a`, `Pendiente b` y la cantidad de observaciones.

> La aplicación **no permite crear ni editar productos desde la interfaz**. Los productos se cargan con los scripts SQL iniciales. Si la cuenta no tiene productos, se muestra «Sin productos» y «Tu cuenta no tiene productos asociados. Usa el usuario demo para explorar el caso de estudio.»

### 4.2 Agregar o quitar observaciones de precio

En el panel **Agregar observación**:

| Campo | Tipo | Regla |
|---|---|---|
| Precio | Número | `≥ 0.01`, paso `0.01` |
| Cantidad | Número entero | `≥ 0` |
| Fecha | Fecha | Obligatoria; por defecto, hoy |
| Origen | Lista | `Histórico` u `Estimado` (por defecto, Histórico) |

Pulsar **Agregar**. La tabla **Observaciones registradas** se actualiza y la ecuación de demanda se reestima automáticamente con todas las observaciones. No aparece un mensaje de éxito: el cambio se ve reflejado en la ecuación.

Para borrar una fila, pulsar **Eliminar** en ella. Esta acción **no pide confirmación**.

Las observaciones del caso base son:

| Precio | Cantidad | Fecha |
|---|---|---|
| 10.00 | 500 | 2026-10-01 |
| 14.00 | 300 | 2026-10-15 |

### 4.3 Ejecutar una simulación

Ir a **Simulaciones** (`/simulations`) y pulsar **+ Nueva simulación**. Completar el panel **Parámetros de la simulación**:

| Campo | Valor por defecto | Observación |
|---|---|---|
| Producto | Primero de la lista | Opciones `nombre (SKU)` |
| Nombre | Vacío | Si se deja vacío se genera `Simulación <fecha>` |
| Precio mínimo | `4` | `≥ 0.01` |
| Precio máximo | `25` | Debe ser mayor al mínimo |
| Paso | `0.5` | `≥ 0.01` |
| CV unitario (opcional) | Vacío | Si se deja vacío usa el del producto |
| Costo fijo (opcional) | Vacío | Si se deja vacío usa el de la empresa |

Pulsar **Ejecutar simulación**. La aplicación abre automáticamente el detalle de la simulación creada.

> La grilla incluye ambos extremos: se genera desde `Precio mínimo` sumando `Paso` mientras el precio sea `≤ Precio máximo`. Con los valores por defecto salen **43 filas** (de 4.00 a 25.00, paso 0.50).

> Si se repite el mismo **Nombre** para el **mismo producto**, la simulación existente se **sobrescribe** en lugar de crear una nueva. Usar nombres distintos para conservar escenarios.

### 4.4 Ver el detalle de una simulación

En `/simulations/:id` se muestran cuatro indicadores:

| Indicador | Contenido |
|---|---|
| Precio óptimo (P*) | Precio que maximiza el beneficio; debajo, `Q* = …` |
| Beneficio máximo (Π*) | Utilidad en el óptimo |
| Elasticidad (EPD) | Valor con 4 decimales y tipo de demanda |
| Umbrales de equilibrio | Rango `mín – máx` de precios sin pérdida, o `—` |

La franja informativa muestra la demanda estimada, el costo variable unitario, el costo fijo, el rango de precios y el «Óptimo en grilla» (precio de la fila marcada como óptima).

#### Pestaña Gráficos

- **Beneficio por precio**: área verde de `Beneficio`, línea azul de `Ingreso`, línea ámbar de `Costo total` y una línea roja discontinua en `P*`.
- **Curva de demanda**: eje X = Cantidad (Q), eje Y = Precio (P), con líneas rojas en `P*` y `Q*`. Si hay observaciones, se agrega un gráfico de puntos «Observaciones registradas» con eje X = Precio y eje Y = Cantidad.

#### Pestaña Grilla de precios (N)

Columnas: **Precio | Cantidad | Ingreso | Costo total | Beneficio | EPD | estado**.

| Marcador | Significado |
|---|---|
| **Óptimo** | Fila con el precio más cercano al óptimo analítico (fondo verde) |
| **Equilibrio** | Precio dentro del rango sin pérdida |
| Beneficio en verde / rojo | `≥ 0` / `< 0` |

### 4.5 Recalcular y eliminar

- **↻ Recalcular**: vuelve a calcular la simulación con los **valores guardados** de demanda y costos al momento de ejecutarla. Actualiza KPIs, gráficos y grilla. No muestra mensaje de confirmación.
- **Eliminar**: pide confirmación con «¿Eliminar esta simulación?» y borra la simulación. En el listado y en el detalle está disponible; en el listado también hay un enlace **Ver**.

### 4.6 Administración (solo administrador)

La opción **⚙ Administración** solo aparece en el menú para usuarios con rol `admin`. Tiene dos pestañas de solo lectura:

| Pestaña | Contenido |
|---|---|
| Auditoría (N) | Últimos 100 eventos: ID, Tabla, Operación, Registro, Usuario, Fecha |
| Simulaciones (N) | Últimas 100 simulaciones de todos los usuarios: ID, Nombre, Usuario, Producto, P*, Beneficio, Fecha |

No hay botones para crear, editar ni borrar desde esta pantalla.

### 4.7 Ejemplo verificado del caso base

| Magnitud | Resultado |
|---|---|
| Demanda | `Q = 1000 − 50P` |
| Precio óptimo | `12.00 Bs.` |
| Cantidad óptima | `400 unidades` |
| Beneficio máximo | `1700.00 Bs.` |
| EPD | `1.50` → elástica |
| Puntos de equilibrio | `6.17 Bs.` y `17.83 Bs.` |
| Grilla | 43 filas (4.00 → 25.00, paso 0.50) |

## 5. Cómo interpretar los resultados

1. **La ecuación** `Q = a − bP` indica cuántas unidades se demandan a cada precio. `a` es el intercepto y `b` la sensibilidad al precio.
2. **El precio óptimo** (`P*`) es el que maximiza `Π`. En la grilla, la fila marcada **Óptimo** es el precio disponible más cercano a ese valor teórico.
3. **La elasticidad (EPD)** responde «¿cuánto cambia la demanda ante un cambio del precio?». Con `EPD = 1.50`, un aumento del 1 % en el precio reduce la cantidad demandada cerca de un 1.5 %: la demanda es elástica.
4. **Los umbrales de equilibrio** delimitan el rango de precios con beneficio no negativo. Fuera de ese rango, la fila aparece con beneficio en rojo.
5. **Cambiar los costos**: para analizar costos distintos sin alterar el producto, usar los campos opcionales **CV unitario** y **Costo fijo** al crear la simulación. Si los costos del producto cambian después, crear una simulación nueva refleja los valores vigentes; **Recalcular** usa los del snapshot guardado.

## 6. Mensajes de error frecuentes

Los errores aparecen en una alerta roja en la pantalla correspondiente.

| Mensaje | Causa probable |
|---|---|
| `Las credenciales no son correctas.` | Correo o contraseña incorrectos |
| `Este correo ya esta registrado.` | Registro con un correo existente |
| `La confirmacion de la contrasena no coincide.` | Las contraseñas no coinciden |
| `El precio maximo debe ser mayor al precio minimo.` | Rango de precios inválido |
| `El producto seleccionado no existe.` | Producto inexistente |
| `No tienes acceso a este producto.` / `No tienes acceso a esta simulacion.` | Recurso de otro usuario |
| `Se requiere rol de administrador.` | Usuario `user` accede a `/admin` por API |
| `Se requieren al menos 2 observaciones para estimar la demanda del producto …` | Faltan observaciones |
| `Todos los precios observados son iguales; no se puede estimar la pendiente` | Todos los precios son idénticos |
| `Los datos no describen una demanda decreciente (b = …)` | Las observaciones no muestran que suba el precio → baje la demanda |
| `El precio debe ser mayor a 0` / `La cantidad demandada no puede ser negativa` | Observación inválida |
| `Rango de precios invalido: min=…, max=…, paso=…` | Parámetros de grilla inconsistentes |
| `Error inesperado` | Error sin mensaje concreto desde la API |

Una respuesta `401` cierra la sesión y redirige a `/login`. Una respuesta `403` muestra el mensaje pero **no** cierra la sesión.

## 7. Límites y comportamientos a tener en cuenta

- No hay alta, edición ni baja de productos desde la interfaz; las observaciones sí se pueden agregar y eliminar.
- Borrar una observación **no pide confirmación** y no muestra mensaje de éxito.
- El listado de simulaciones muestra como máximo las **15 más recientes** (la API pagina en 15 y la interfaz no tiene controles de paginación).
- El panel de administración muestra como máximo 100 registros por tabla y no permite acciones.
- **Recalcular** no vuelve a estimar la demanda ni relee los costos actuales: usa los valores guardados en la simulación.
- Repetir nombre y producto al crear una simulación sobrescribe la anterior.
- La pestaña de grilla muestra la cantidad real de filas, que depende del rango y el paso elegidos (43 es el valor del caso base, no una constante).
- En el gráfico de demanda, la curva usa Q en X y P en Y, mientras que el gráfico de puntos de observaciones usa P en X y Q en Y.
- El token se guarda en `localStorage` bajo `eco300_token` y los datos del usuario bajo `eco300_user`.

---

# Parte II — Documentación técnica

## 8. Arquitectura y stack

| Capa | Tecnología |
|---|---|
| Base de datos | PostgreSQL 16 (`postgres:16-alpine`) |
| Backend | PHP 8.3 · Laravel 12 · Sanctum (Bearer token) |
| Frontend | React 18 · Vite 6 · React Router 7 · Axios · Recharts |
| Contenedores | Docker Compose: `postgres`, `pgadmin`, `backend`, `frontend` (nginx) |

La lógica económica vive en la base de datos (funciones, procedimientos almacenados y triggers). Laravel es una delgada capa HTTP que valida, verifica permisos y llama a la BD; React consume la API y presenta los resultados.

## 9. Arranque rápido

### Windows (PowerShell)

```powershell
# 1) Inicializar BD e instalarse datos demo (idempotente)
powershell -ExecutionPolicy Bypass -File scripts\init_db.ps1

# 2) Levantar API + frontend
docker compose up -d --build
```

Si la BD ya está inicializada, alcanza con `docker compose up -d`.

### Linux / macOS

```bash
bash scripts/init_db.sh
docker compose up -d --build
```

`init_db.ps1` / `init_db.sh` copian `.env` si no existe, levantan `postgres` y `pgadmin`, esperan hasta ~80 s a que `simeco-postgres` esté `healthy`, ejecutan `00_run_all.sql` y luego `99_verify.sql`.

> No ejecutar `php artisan migrate` sobre esta base. El esquema es propiedad de los scripts SQL de `database/sql`.

## 10. Servicios, puertos y credenciales

| Servicio | Contenedor | Puerto host | Interno | Credenciales |
|---|---|---|---|---|
| Frontend | `simeco-frontend` | 5173 | 80 (nginx) | — |
| Backend | `simeco-backend` | 8000 | 8000 | Token Bearer |
| pgAdmin | `simeco-pgadmin` | 5050 | 80 | `admin@economia.com` / `admin` |
| PostgreSQL | `simeco-postgres` | 5433 | 5432 | DB/usuario/password `economia` |

Usuarios demo:

| Correo | Contraseña | Rol |
|---|---|---|
| `admin@economia.test` | `password123` | `admin` |
| `user@economia.test` | `password123` | `user` |

En pgAdmin: *Add New Server → General: nombre `economia` → Connection: Host `postgres`, Port `5432`, Username `economia`, Password `economia`*. El correo de pgAdmin debe tener dominio público (`.com`), a diferencia del correo de la app (`.test`).

Detalles del compose:

- `postgres`: volumen nombrado `pgdata` en `/var/lib/postgresql/data`; bind readonly `./database/sql:/sql:ro`; healthcheck `pg_isready` cada 5 s, 12 reintentos; `PG_TIMEZONE=America/La_Paz`.
- `backend`: bind `./backend:/var/www` + volumen anónimo para `/var/www/vendor`; depende de `postgres` con `condition: service_healthy`; comando `php artisan serve --host=0.0.0.0 --port=8000 --no-reload`.
- `frontend`: build con `ARG VITE_API_URL`; depende de `backend`; sin volúmenes.
- `pgadmin`: depende de `postgres` con `condition: service_healthy`.

> `--no-reload` es necesario: sin esa opción, Laravel 12 filtra las variables de entorno hacia el proceso hijo y el backend intenta conectarse a `127.0.0.1:5433` en vez de `postgres:5432`.

## 11. Estructura del repositorio

```
docker-compose.yml             PostgreSQL + pgAdmin + backend Laravel + frontend nginx
.env.example                   Variables del stack
docs/
  manual.md                    Fuente de este manual
  manual.html / manual.pdf / manual.docx   Versiones generadas
scripts/
  init_db.ps1 / init_db.sh     Inicialización idempotente de la BD
  test_api.ps1                 Pruebas de extremo a extremo de la API
  build_manual.py              Genera HTML/PDF/DOCX desde docs/manual.md
database/sql/
  00_run_all.sql               Punto de entrada (incluye 01..06)
  01_schema.sql                11 tablas + 2 vistas + índices
  02_functions.sql             8 funciones + 5 funciones de trigger
  03_procedures.sql            4 procedimientos almacenados
  04_triggers.sql              11 triggers
  05_seed.sql                  Usuarios demo
  06_api_helpers.sql           fn_run_simulation (wrapper del PA para Laravel)
  98_tests.sql                 Pruebas de funciones y triggers (opcional)
  99_verify.sql                Verificación con aserciones
backend/                       Aplicación Laravel 12
frontend/                      Aplicación React + Vite
```

## 12. Base de datos

### 12.1 Tablas

| Tabla | Propósito |
|---|---|
| `users` | Usuarios; `role IN ('admin','user')`, default `user` |
| `personal_access_tokens` | Tokens Sanctum |
| `sessions`, `password_reset_tokens` | Soporte Laravel |
| `businesses` | Empresas; `user_id`, `name`, `currency`, `fixed_cost_monthly` |
| `products` | Productos; `business_id`, `sku`, `unit`, `variable_cost_unit`, `current_stock`, `active` |
| `price_observations` | Observaciones de precio; `price`, `quantity_demanded`, `observed_at`, `source IN ('historico','estimado')` |
| `simulations` | Snapshot de cada escenario: demanda, costos, óptimo, EPD, equilibrio y rango |
| `simulation_results` | Grilla precio → cantidad/ingreso/costo/beneficio/EPD; `is_optimal` |
| `audit_log` | Auditoría de INSERT/UPDATE/DELETE en tablas del dominio |
| `product_cost_history` | Historial de cambios de `variable_cost_unit` |

Restricciones relevantes: `UNIQUE (user_id, product_id, name)` en `simulations` (de ahí el **upsert** por nombre); `UNIQUE (simulation_id, price)` en resultados; índice único parcial `idx_sim_results_one_optimal` que garantiza una sola fila óptima por simulación.

### 12.2 Vistas

- `v_resumen_simulaciones`: una fila por simulación con usuario, negocio, producto, demanda, costos, óptimo, EPD, tipo y equilibrio.
- `v_curva_beneficios`: proyección de `simulation_results`.

### 12.3 Funciones económicas

| Función | Firma / utilidad |
|---|---|
| `fn_calcular_pendiente(p_p1, p_q1, p_p2, p_q2)` | `b = (Q1−Q2)/(P2−P1)`; valida precios distintos y `b > 0` |
| `fn_calcular_intercepto(p_p, p_q, p_b)` | `a = Q + b·P` |
| `fn_estimar_demanda(p_product_id)` | Regresión por mínimos cuadrados; devuelve `(a, b)` |
| `fn_calcular_demanda(p_a, p_b, p_price)` | `GREATEST(a − b·P, 0)` |
| `fn_calcular_beneficio(p_a, p_b, p_price, p_cv, p_cf)` | `Q·(P−CV) − CF` |
| `fn_calcular_epd(p_a, p_b, p_price)` | `b·P/Q` (6 decimales), o `0` si `Q ≤ 0` |
| `fn_clasificar_demanda(p_epd)` | `elastic` / `inelastic` / `unitary` |
| `fn_calcular_optimo(p_a, p_b, p_cv, p_cf)` | `P*`, `Q*`, `Π*`, EPD, tipo y umbrales de equilibrio |

### 12.4 Procedimientos almacenados

| Procedimiento | Qué hace |
|---|---|
| `sp_generar_resultados` | Borra la grilla anterior y genera precios desde `min` hasta `max` sumando `step`; marca como óptima la fila más cercana al óptimo analítico |
| `sp_run_simulation` | Lee costos del producto/empresa (o aplica overrides), estima demanda, calcula óptimo, hace upsert en `simulations` y genera la grilla; devuelve el id por parámetro `OUT` |
| `sp_refresh_simulation` | Recalcula usando los **valores guardados** en `simulations` y regenera la grilla; no reestima demanda ni relee costos |
| `sp_seed_case_study` | Siembra de forma idempotente usuarios, empresa, producto, observaciones y la simulación «Caso base»; borra y recrea «Caso base», por lo que su `id` cambia en cada re-seed |

Wrapper para Laravel (`06_api_helpers.sql`):

```sql
fn_run_simulation(p_user_id, p_product_id, p_name, p_price_min, p_price_max,
                  p_price_step, p_cv_override, p_cf_override) RETURNS BIGINT
```

Existe porque los procedimientos con parámetros `OUT` no son cómodos desde PDO: el wrapper permite llamar con un simple `SELECT`.

### 12.5 Triggers (11)

| Trigger | Tabla | Evento | Efecto |
|---|---|---|---|
| `trg_users_updated_at` | `users` | BEFORE UPDATE | Actualiza `updated_at` |
| `trg_businesses_updated_at` | `businesses` | BEFORE UPDATE | Actualiza `updated_at` |
| `trg_products_updated_at` | `products` | BEFORE UPDATE | Actualiza `updated_at` |
| `trg_simulations_updated_at` | `simulations` | BEFORE UPDATE | Actualiza `updated_at` |
| `trg_audit_businesses` | `businesses` | AFTER INSERT/UPDATE/DELETE | Escribe en `audit_log` |
| `trg_audit_products` | `products` | AFTER INSERT/UPDATE/DELETE | Escribe en `audit_log` |
| `trg_audit_observations` | `price_observations` | AFTER INSERT/UPDATE/DELETE | Escribe en `audit_log` |
| `trg_audit_simulations` | `simulations` | AFTER INSERT/UPDATE/DELETE | Escribe en `audit_log` |
| `trg_validate_observations` | `price_observations` | BEFORE INSERT/UPDATE | Valida precio y cantidad; normaliza `source`/`observed_at` |
| `trg_cost_history_products` | `products` | AFTER UPDATE OF `variable_cost_unit` | Registra cambio en `product_cost_history` |
| `trg_validate_simulacion` | `simulations` | BEFORE INSERT/UPDATE | Valida rango, `b > 0` y coherencia EPD ↔ tipo de demanda |

No hay triggers de auditoría sobre `users`, `simulation_results`, `audit_log` ni `product_cost_history`.

## 13. API REST

Base: `http://localhost:8000/api`. Todas las respuestas son JSON. Las rutas autenticadas exigen `Authorization: Bearer <token>`.

### 13.1 Públicas

| Método | Ruta | Request | Respuesta |
|---|---|---|---|
| POST | `/register` | `name`, `email`, `password`, `password_confirmation` | 201: `message`, `user`, `token` |
| POST | `/login` | `email`, `password` | 200: `message`, `user`, `token` |

### 13.2 Autenticadas

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/logout` | Revoca el token actual |
| GET | `/me` | Usuario autenticado |
| GET | `/dashboard` | `totals` (simulaciones, productos), `latest_simulation` con curva, `recent_simulations` (5) |
| GET | `/products` | Productos del usuario (con `business`) |
| GET | `/products/{product}` | Detalle con `business`, `observations` y `costHistory` |
| GET | `/products/{product}/estimate` | `{ product_id, intercept_a, slope_b, equation, observations }` |
| GET | `/products/{product}/observations` | Observaciones ordenadas por precio |
| POST | `/products/{product}/observations` | Alta de observación (201) |
| DELETE | `/products/{product}/observations/{observation}` | Baja de observación |
| GET | `/simulations` | Paginador de 15 simulaciones del usuario |
| POST | `/simulations` | Ejecuta una simulación (201) |
| GET | `/simulations/{simulation}` | Detalle con `product.business` y `results` |
| GET | `/simulations/{simulation}/curve` | Grilla ordenada por precio |
| POST | `/simulations/{simulation}/refresh` | Recalcula y devuelve el recurso actualizado |
| DELETE | `/simulations/{simulation}` | Elimina la simulación |

### 13.3 Solo administrador

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/admin/audit-log` | Últimas 100 entradas, `id desc` |
| GET | `/admin/simulations` | Últimas 100 simulaciones de todos los usuarios |

El control de rol se hace dentro de `AdminController::ensureAdmin()`; si no es admin, responde 403 con «Se requiere rol de administrador.».

### 13.4 Validaciones

`RegisterRequest`:

```php
'name'     => ['required', 'string', 'max:120'],
'email'    => ['required', 'email', 'max:190', 'unique:users,email'],
'password' => ['required', 'string', 'min:8', 'confirmed'],
```

`LoginRequest`: `email` required|email, `password` required|string.

`StoreObservationRequest`:

```php
'price'             => ['required', 'numeric', 'min:0.01', 'max:9999999999'],
'quantity_demanded' => ['required', 'integer', 'min:0'],
'observed_at'       => ['required', 'date'],
'source'            => ['sometimes', 'in:historico,estimado'],
```

`StoreSimulationRequest`:

```php
'product_id'  => ['required', 'integer', 'exists:products,id'],
'name'        => ['required', 'string', 'max:150'],
'price_min'   => ['required', 'numeric', 'min:0.01'],
'price_max'   => ['required', 'numeric', 'gt:price_min'],
'price_step'  => ['required', 'numeric', 'min:0.01'],
'cv_override' => ['nullable', 'numeric', 'min:0'],
'cf_override' => ['nullable', 'numeric', 'min:0'],
```

Mensajes propios: `email.unique` → «Este correo ya esta registrado.»; `password.confirmed` → «La confirmacion de la contrasena no coincide.»; `price_max.gt` → «El precio maximo debe ser mayor al precio minimo.»; `exists` → «El producto seleccionado no existe.».

### 13.5 Ejemplo: ejecutar una simulación

```powershell
$login = Invoke-RestMethod http://localhost:8000/api/login -Method Post `
  -ContentType application/json `
  -Body '{"email":"admin@economia.test","password":"password123"}'

$headers = @{ Authorization = "Bearer $($login.token)" }

$body = @{
  product_id = 1
  name       = 'Escenario navideño'
  price_min  = 4
  price_max  = 25
  price_step = 0.5
} | ConvertTo-Json

Invoke-RestMethod http://localhost:8000/api/simulations -Method Post `
  -Headers $headers -ContentType application/json -Body $body
```

Respuesta esperada en el caso base: `optimal_price=12`, `optimal_quantity=400`, `max_profit=1700`, `epd=1.5`, `demand_type=elastic`.

### 13.6 Verificación de propiedad

Los controladores verifican pertenencia antes de devolver o modificar recursos:

```php
abort_unless($product->business->user_id === $request->user()->id,
             403, 'No tienes acceso a este producto.');
abort_unless($simulation->user_id === $request->user()->id,
             403, 'No tienes acceso a esta simulacion.');
```

## 14. Cómo se ejecuta una simulación

Secuencia completa, de la UI a la BD:

1. El frontend envía `POST /api/simulations` con `product_id`, `name`, `price_min`, `price_max`, `price_step` y overrides opcionales.
2. `StoreSimulationRequest` valida los campos.
3. `SimulationController@store` verifica que el producto pertenezca al usuario.
4. Se llama al wrapper SQL (8 parámetros, en este orden):

   ```php
   DB::selectOne(
       'SELECT fn_run_simulation(?, ?, ?, ?, ?, ?, ?, ?) AS id',
       [$userId, $productId, $name, $priceMin, $priceMax, $priceStep, $cvOverride, $cfOverride]
   )->id;
   ```

5. `fn_run_simulation` invoca `sp_run_simulation`, que:
   - lee `products.variable_cost_unit` y `businesses.fixed_cost_monthly` (o aplica overrides);
   - llama a `fn_estimar_demanda(product_id)` → `(a, b)`;
   - llama a `fn_calcular_optimo(a, b, CV, CF)` → `P*`, `Q*`, `Π*`, EPD, tipo, equilibrio;
   - hace `INSERT ... ON CONFLICT (user_id, product_id, name) DO UPDATE` en `simulations`;
   - llama a `sp_generar_resultados`, que borra la grilla anterior y genera las filas, marcando una como `is_optimal`;
   - devuelve el id por `OUT p_simulation_id`.
6. El controlador recarga `Simulation::with(['product.business', 'results'])` y responde 201.
7. El frontend navega a `/simulations/{id}`.

**Refresh**, en cambio:

```php
DB::statement('CALL sp_refresh_simulation(?)', [$simulation->id]);
return response()->json($simulation->fresh()->load(['product.business', 'results']));
```

`sp_refresh_simulation` recalcula con `intercept_a`, `slope_b`, `variable_cost` y `fixed_cost` **ya guardados** en `simulations`; no vuelve a estimar la demanda ni a leer los costos vigentes del producto.

Las relaciones Eloquent `results()` ordenan por `price`, por lo que dashboard y detalle reciben la curva ordenada sin `orderBy` adicional en el controlador.

## 15. Autenticación, roles y CORS

- Laravel Sanctum con tokens personales (`createToken('api-token')`); `expiration => null`.
- El frontend guarda `eco300_token` y `eco300_user` en `localStorage` y envía `Authorization: Bearer …` en cada petición.
- Al arrancar, si hay token, llama a `GET /me`; si falla, limpia token y usuario.
- El interceptor de Axios ante `401` borra el storage y redirige a `/login` (salvo que ya esté en `/login`). El `403` solo muestra el mensaje.
- Roles: `admin` y `user`. `User::isAdmin()` compara estrictamente con `admin`. El registro público siempre crea `user` (default del modelo y de la BD).
- CORS: `paths => ['api/*', 'sanctum/csrf-cookie']`, orígenes desde `CORS_ALLOWED_ORIGINS` (default `http://localhost:5173`), todos los métodos y headers, `supports_credentials => false`.
- Las respuestas 401 de la API son JSON `{"message":"No autenticado."}`, sin redirección web.
- `extractMessage` del frontend prioriza `data.message`, luego `data.errors`, luego `error.message` y por último «Error inesperado».

## 16. Verificación y pruebas

```powershell
# BD: ejecuta 00_run_all.sql + 99_verify.sql con aserciones
powershell -ExecutionPolicy Bypass -File scripts\init_db.ps1

# API: extremo a extremo (requiere la API levantada)
powershell -ExecutionPolicy Bypass -File scripts\test_api.ps1
```

`scripts/test_api.ps1` comprueba, en orden:

1. `POST /login` (rol `admin`) y `GET /me`.
2. `GET /dashboard` (`epd = 1.5000`), `GET /products`, `GET /products/{id}/estimate` (`Q = 1000.0000 - 50.0000P`).
3. Alta y baja de una observación (`price=12`, `quantity=400`, `observed_at=2026-11-20`, `source=estimado`).
4. Creación de simulación (`4`–`25`, paso `0.5`): `P*=12.00`, `Q*=400.0000`, `Π*=1700.00`, `elastic`; curva de 43 filas; refresh; baja.
5. Registro público (rol `user`), 403 en `/admin/audit-log` y 401 con token inválido.

Al final imprime «TODAS LAS PRUEBAS DE LA API PASARON». La observación y la simulación de prueba se borran; el usuario registrado permanece.

Pruebas opcionales de SQL (no incluidas en `00_run_all.sql`):

```powershell
docker compose exec -T postgres psql -U economia -d economia -f /sql/98_tests.sql
docker compose exec -T postgres psql -U economia -d economia -f /sql/99_verify.sql
```

## 17. Configuración

### 17.1 Raíz `.env.example`

```dotenv
POSTGRES_DB=economia
POSTGRES_USER=economia
POSTGRES_PASSWORD=economia
PGADMIN_EMAIL=admin@economia.com
PGADMIN_PASSWORD=admin
APP_NAME="Simulador ECO300"
APP_ENV=local
APP_DEBUG=true
CORS_ALLOWED_ORIGINS=http://localhost:5173
```

El compose aplica defaults para esas variables. `VITE_API_URL` no está en el `.env` raíz: el compose usa `http://localhost:8000/api` por defecto.

### 17.2 Backend y frontend

- `backend/.env`: `DB_CONNECTION=pgsql`, `DB_HOST=127.0.0.1`, `DB_PORT=5433` en local; dentro de Docker el compose inyecta `DB_HOST=postgres`, `DB_PORT=5432`. `APP_KEY` ya generada en el entorno actual.
- `frontend/.env.example`: `VITE_API_URL=http://localhost:8000/api`.
- Cambiar la URL de la API en Docker requiere reconstruir la imagen del frontend:

  ```powershell
  docker compose up -d --build frontend
  ```

## 18. Comandos útiles

```powershell
# Estado de contenedores
docker compose ps

# Resumen de simulaciones
docker compose exec -T postgres psql -U economia -d economia -c "SELECT * FROM v_resumen_simulaciones;"

# Re-sembrar el caso base (cambia el id de "Caso base")
docker compose exec -T postgres psql -U economia -d economia -c "CALL sp_seed_case_study();"

# Refrescar una simulación por id
docker compose exec -T postgres psql -U economia -d economia -c "CALL sp_refresh_simulation(1);"

# Curva de beneficios de la última simulación base
docker compose exec -T postgres psql -U economia -d economia -c "SELECT * FROM v_curva_beneficios WHERE simulation_id = (SELECT id FROM simulations WHERE name = 'Caso base' ORDER BY id DESC LIMIT 1);"

# Listar rutas de la API
cd backend; php artisan route:list --path=api

# Desarrollo local del frontend (sin Docker)
cd frontend; npm install; npm run dev

# Build de producción del frontend
cd frontend; npm run build

# Regenerar este manual (HTML, PDF y DOCX)
python scripts/build_manual.py
```

## 19. Solución de problemas

| Síntoma | Causa / acción |
|---|---|
| El backend no conecta con la BD dentro de Docker | Verificar que se usa `postgres:5432` (no `127.0.0.1:5433`); el comando debe incluir `--no-reload` |
| «PostgreSQL no alcanzo el estado healthy» | Revisar `docker compose logs postgres` y volver a ejecutar `init_db.ps1` |
| `Se requieren al menos 2 observaciones…` | Cargar dos observaciones con precios distintos en **Productos** |
| `Los datos no describen una demanda decreciente` | Revisar las observaciones: al subir el precio debe bajar la cantidad |
| «Sin productos» en la UI | Usar el usuario demo o ejecutar `CALL sp_seed_case_study();` |
| `401` y redirección al login | Token vencido o inválido; volver a ingresar |
| `403` en administración | El rol del usuario es `user`, no `admin` |
| Cambió `VITE_API_URL` pero la app sigue llamando a la URL vieja | Reconstruir la imagen: `docker compose up -d --build frontend` |
| Error al ejecutar `php artisan migrate` | No hacerlo: el esquema lo gestionan los scripts SQL |
| Conflicto en el puerto 5432 | PostgreSQL se publica en el host como 5433; ajustar `DB_PORT` solo para ejecución local |

## 20. Discrepancias conocidas entre README y código

Esta sección documenta diferencias detectadas entre los README del repositorio y la implementación real, para evitar confusiones:

1. `README.md` afirma «21 triggers»; `04_triggers.sql` define **11**.
2. `backend/README.md` cita `database/sql/06_api_helpers.sql` como si estuviera dentro de `backend/`; la ruta real es `database/sql/06_api_helpers.sql` en la raíz.
3. `frontend/README.md` habla de «ABM de productos»; la interfaz **no** crea ni edita productos, solo observaciones.
4. `frontend/README.md` dice «grilla de 43 precios» como si fuera fija; la grilla es dinámica y depende de `price_min`, `price_max` y `price_step`.
5. `RegisterPage` indica «rol estudiante»; el rol asignado es `user`.
6. El comentario de `sp_refresh_simulation` sugiere que es útil cuando cambian los costos del producto, pero el procedimiento usa los costos guardados en la simulación, no los actuales.
7. `sp_seed_case_study` borra y recrea «Caso base», por lo que su `id` no es estable entre re-seeds.

---

*Generado para el Proyecto ECO300 · Grupo 99. Última revisión: noviembre de 2026.*
