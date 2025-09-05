# init-estructura.ps1
# Crea la estructura base para el sistema de listas de precios (backend + frontend básico).
# Uso: en PowerShell (VS Code): Set-ExecutionPolicy -Scope Process Bypass -Force; .\init-estructura.ps1

# ---------- Config ----------
$ProjectName = "sistema-listas-precios"
$Root = Join-Path (Get-Location) $ProjectName

if (Test-Path $Root) {
  Write-Host "ERROR: Ya existe la carpeta '$ProjectName' en: $Root" -ForegroundColor Red
  Write-Host "Borrala o cambia el nombre en el script y volvé a ejecutar."
  exit 1
}

# ---------- Helpers ----------
function New-Dir($path) {
  if (-not (Test-Path $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

function Write-File($path, $content = "") {
  $dir = Split-Path $path -Parent
  New-Dir $dir
  $content | Out-File -FilePath $path -Encoding utf8 -Force
}

# ---------- Directorios ----------
$dirs = @(
  # Raíz
  "$Root",
  "$Root/docs",
  "$Root/postman",

  # Backend
  "$Root/backend",
  "$Root/backend/src",
  "$Root/backend/src/config",
  "$Root/backend/src/middleware",
  "$Root/backend/src/utils",
  "$Root/backend/src/modules",
  "$Root/backend/src/modules/auth",
  "$Root/backend/src/modules/users",
  "$Root/backend/src/modules/suppliers",
  "$Root/backend/src/modules/products",
  "$Root/backend/src/modules/pricelists",
  "$Root/backend/src/modules/scraping",
  "$Root/backend/src/jobs",
  "$Root/backend/src/db",
  "$Root/backend/tests/unit",
  "$Root/backend/tests/integration",

  # Frontend súper básico (placeholder)
  "$Root/frontend-basic",
  "$Root/frontend-basic/public",
  "$Root/frontend-basic/src",
  "$Root/frontend-basic/src/components",
  "$Root/frontend-basic/src/pages"
)

foreach ($d in $dirs) { New-Dir $d }

# ---------- Archivos raíz ----------
Write-File "$Root/README.md" @"
# $ProjectName

Monorepo del sistema de **listas de precios**:
- **backend/**: API (Node+Express) con auth, RBAC (Admin/Usuario), y módulos de listas de precios.
- **frontend-basic/**: maqueta mínima para probar la API (login y tabla).

## Próximos pasos
1. Configurar backend (package.json, tsconfig, dependencias).
2. Definir modelo en DB y migraciones.
3. Implementar auth, endpoints y pricing.
4. Subir a Render y probar con Postman.
"@

Write-File "$Root/.gitignore" @"
# Node / general
node_modules/
dist/
.env
.env.*
.DS_Store
.vscode/
*.log

# Frontend
frontend-basic/node_modules/
frontend-basic/dist/

# Backend
backend/node_modules/
backend/dist/
"@

Write-File "$Root/docs/roadmap.md" @"
# Roadmap
- Fase 0: Entorno
- Fase 1: Estructura (este script)
- Fase 2: Backend base (TS, Express, CORS, logger, errores)
- Fase 3: DB y migraciones (PostgreSQL)
- Fase 4: Auth + RBAC (Admin/Usuario)
- Fase 5: Módulos (usuarios, suppliers, products, pricelists)
- Fase 6: Pricing centralizado
- Fase 7: Scrapers (imagenes/descripcion y descarga excels)
- Fase 8: Front básico
- Fase 9: Deploy Render
- Fase 10: Prompt IA para front pro
"@

Write-File "$Root/postman/PriceSystem.postman_collection.json" @"
{
  "info": {
    "name": "PriceSystem API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": []
}
"@

# ---------- Backend: placeholders ----------
Write-File "$Root/backend/README.md" @"
# Backend
API para listas de precios con usuarios (Admin/Usuario), pricing y gestión de listas.

Estructura principal:
- src/config: carga de entorno, CORS, logger
- src/middleware: authGuard, adminGuard, errorHandler
- src/utils: funciones de utilidad (pricing, paginación)
- src/modules: auth, users, suppliers, products, pricelists, scraping
- src/db: conexión y migraciones
"@

Write-File "$Root/backend/.env.example" @"
# Backend environment example
PORT=3000
JWT_SECRET=CAMBIAME_POR_UNA_CLAVE_SEGURA
DATABASE_URL=postgresql://usuario:password@localhost:5432/preciosdb

# Admin bootstrap (creado al iniciar si no existe)
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=admin123

# Almacenamiento/estáticos
STORAGE_BASE_URL=

# Scraping
SCRAPE_USER_AGENT=PriceBot/1.0
"@

Write-File "$Root/backend/src/server.ts" @"
// Arranque del servidor (placeholder). Se completará al configurar Express/TS.
console.log('Servidor placeholder. Próximo paso: configurar Express y TypeScript.');
"@

Write-File "$Root/backend/src/app.ts" @"
// Configuración de la app (placeholder).
// Aquí irá Express, middlewares, rutas y manejo de errores.
"@

Write-File "$Root/backend/src/config/index.ts" @"
// Carga de variables de entorno, logger y CORS (placeholder).
// Próximo paso: dotenv, pino/winston, cors.
"@

Write-File "$Root/backend/src/middleware/authGuard.ts" @"
// Verifica JWT y adjunta req.user (placeholder).
"@

Write-File "$Root/backend/src/middleware/adminGuard.ts" @"
// Permite sólo a roles 'admin' (placeholder).
"@

Write-File "$Root/backend/src/middleware/errorHandler.ts" @"
// Manejo centralizado de errores (placeholder).
"@

Write-File "$Root/backend/src/utils/pricing.ts" @"
/**
 * pricing.ts (placeholder)
 * Fórmula:
 *   finalAdmin = base * (1+markup) * (1+impuestos) * (1+iva)
 *   finalParaUsuario = finalAdmin * (1 - descuentoUsuario)
 */
export function calcularPrecio(baseUsd: number, markupPct: number, impuestosPct: number, ivaPct: number, descuentoUsuarioPct: number) {
  const finalAdmin = baseUsd * (1 + markupPct/100) * (1 + impuestosPct/100) * (1 + ivaPct/100);
  const finalUsuario = finalAdmin * (1 - descuentoUsuarioPct/100);
  return { finalAdmin, finalUsuario };
}
"@

# Módulos
Write-File "$Root/backend/src/modules/auth/auth.routes.ts" "// Rutas de auth (login, bootstrap admin) - placeholder"
Write-File "$Root/backend/src/modules/auth/auth.controller.ts" "// Controlador de auth - placeholder"
Write-File "$Root/backend/src/modules/auth/auth.service.ts" "// Servicio de auth (bcrypt, jwt) - placeholder"
Write-File "$Root/backend/src/modules/auth/auth.types.ts" "// Tipos de auth - placeholder"
Write-File "$Root/backend/src/modules/users/users.routes.ts" "// Rutas de usuarios (Admin) - placeholder"
Write-File "$Root/backend/src/modules/users/users.controller.ts" "// Controlador de usuarios - placeholder"
Write-File "$Root/backend/src/modules/users/users.service.ts" "// Servicio de usuarios - placeholder"
Write-File "$Root/backend/src/modules/suppliers/suppliers.routes.ts" "// Rutas de proveedores - placeholder"
Write-File "$Root/backend/src/modules/suppliers/suppliers.controller.ts" "// Controlador de proveedores - placeholder"
Write-File "$Root/backend/src/modules/suppliers/suppliers.service.ts" "// Servicio de proveedores - placeholder"
Write-File "$Root/backend/src/modules/products/products.routes.ts" "// Rutas de productos - placeholder"
Write-File "$Root/backend/src/modules/products/products.controller.ts" "// Controlador de productos - placeholder"
Write-File "$Root/backend/src/modules/products/products.service.ts" "// Servicio de productos - placeholder"
Write-File "$Root/backend/src/modules/pricelists/pricelists.routes.ts" "// Rutas de listas de precios - placeholder"
Write-File "$Root/backend/src/modules/pricelists/pricelists.controller.ts" "// Controlador de listas de precios - placeholder"
Write-File "$Root/backend/src/modules/pricelists/pricelists.service.ts" "// Servicio de listas de precios - placeholder"
Write-File "$Root/backend/src/modules/scraping/scraping.routes.ts" "// Rutas para lanzar scrapers - placeholder"
Write-File "$Root/backend/src/modules/scraping/scraping.service.ts" "// Servicio de scraping (pendiente fase 2) - placeholder"
Write-File "$Root/backend/src/jobs/scheduler.ts" "// Tareas programadas (descarga excels / completar imagenes) - placeholder"

# DB
Write-File "$Root/backend/src/db/connection.ts" "// Conexión a PostgreSQL (se implementará con pg/prisma) - placeholder"
Write-File "$Root/backend/src/db/schema.sql" @"
-- Esquema SQL (placeholder). Próximo paso: definir tablas y migraciones.
"

# Tests
Write-File "$Root/backend/tests/unit/README.md" "Tests unitarios - placeholder"
Write-File "$Root/backend/tests/integration/README.md" "Tests de integración - placeholder"

# ---------- Frontend básico: placeholders ----------
Write-File "$Root/frontend-basic/README.md" @"
# Frontend básico (placeholder)
Maqueta mínima para login y vista de productos usando fetch hacia la API.
"@

Write-File "$Root/frontend-basic/public/index.html" @"
<!doctype html>
<html>
  <head>
    <meta charset='utf-8' />
    <meta name='viewport' content='width=device-width, initial-scale=1' />
    <title>Listas de Precios - Admin</title>
  </head>
  <body>
    <div id='app'>Cargando frontend básico...</div>
    <script src='../src/app.js' type='module'></script>
  </body>
</html>
"@

Write-File "$Root/frontend-basic/src/app.js" @"
// Front súper básico (placeholder). Luego se conectará a la API (/auth/login, /products).
document.getElementById('app').innerText = 'Frontend básico listo. Próximo paso: conectar a la API.';
"@

Write-Host "✅ Estructura creada en: $Root" -ForegroundColor Green
