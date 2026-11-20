# Frontend — Simulador Microeconómico ECO300

SPA de React 18 con Vite, React Router, Axios y Recharts. Consume la API REST de `backend/`.

## Páginas

| Ruta | Descripción | Acceso |
|---|---|---|
| `/login` | Inicio de sesión (token Bearer) | público |
| `/register` | Registro de usuario (rol `user`) | público |
| `/dashboard` | KPIs, última simulación y gráficos de demanda/beneficio | autenticado |
| `/simulations` | Listado de simulaciones; crear y eliminar | autenticado |
| `/simulations/:id` | Detalle: óptimo, curva, grilla de 43 precios y refresh | autenticado |
| `/products` | ABM de productos y observaciones de precio | autenticado |
| `/admin` | Panel de administración (usuarios y auditoría) | solo `admin` |

## Desarrollo local

```powershell
cp .env.example .env
npm install
npm run dev        # http://localhost:5173
```

La API debe estar levantada en `http://localhost:8000/api`. Para cambiarla, edita `VITE_API_URL` en `.env`.

```powershell
npm run build      # genera dist/
npm run preview    # sirve dist/ localmente
```

## Docker

Desde la raíz del repositorio:

```powershell
docker compose up -d --build frontend
```

El `Dockerfile` compila la SPA con Node 22 y la sirve con nginx en el puerto `5173`. nginx redirige las rutas SPA a `index.html`. La variable `VITE_API_URL` se pasa como argumento de build desde `docker-compose.yml`; si cambias la URL de la API, reconstruye la imagen:

```powershell
docker compose up -d --build frontend
```

## Autenticación

El token se guarda en `localStorage` bajo `eco300_token` y se adjunta como `Authorization: Bearer <token>` en cada petición. Un `401` limpia la sesión y redirige a `/login`.

## Credenciales demo

- Admin: `admin@economia.test` / `password123`
- Usuario: `user@economia.test` / `password123`
