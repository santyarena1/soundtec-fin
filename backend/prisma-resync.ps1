# backend\prisma-resync.ps1
# Sincroniza el schema de Prisma con tu Postgres usando `db push`
# (crea las tablas que faltan). Útil cuando hay drift o migraciones incompletas.

param(
  [string]$DatabaseUrl = ""
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Write-Host "==> Prisma resync iniciado" -ForegroundColor Cyan

# 1) Asegurar .env con DATABASE_URL correcta
$envPath = Join-Path $here ".env"
if (-not (Test-Path $envPath)) {
  throw ".env no encontrado en $here. Creá backend/.env con DATABASE_URL primero."
}

# Si pasaron -DatabaseUrl, actualizar/insertar en .env
if ($DatabaseUrl -ne "") {
  $content = Get-Content $envPath -Raw
  if ($content -match '^\s*DATABASE_URL\s*=' ) {
    $content = [regex]::Replace($content, '^\s*DATABASE_URL\s*=.*$', "DATABASE_URL=""$DatabaseUrl""", 'Multiline')
  } else {
    $content = $content.TrimEnd() + "`r`nDATABASE_URL=""$DatabaseUrl"""
  }
  $content | Out-File -FilePath $envPath -Encoding utf8 -Force
  Write-Host "   DATABASE_URL actualizado en .env" -ForegroundColor Yellow
}

# Leer DATABASE_URL actual (para confirmar)
$envContent = Get-Content $envPath -Raw
$match = [regex]::Match($envContent, '^\s*DATABASE_URL\s*=\s*"?([^"\r\n]+)"?', 'Multiline')
if (-not $match.Success) {
  throw "DATABASE_URL no encontrado en .env"
}
$currentDbUrl = $match.Groups[1].Value
Write-Host "   Usando DATABASE_URL: $currentDbUrl" -ForegroundColor Gray

# 2) Limpiar posibles restos de migraciones rotas (opcional, no borra tu DB)
$migDir = Join-Path $here "prisma\migrations"
if (Test-Path $migDir) {
  Write-Host "   (Opcional) Migraciones existentes detectadas en prisma/migrations (no se borran)" -ForegroundColor DarkGray
}

# 3) Generar cliente por las dudas
Write-Host "==> npx prisma generate" -ForegroundColor Cyan
npx prisma generate
if ($LASTEXITCODE -ne 0) { throw "Fallo prisma generate" }

# 4) Forzar sincronización de esquema -> CREA TABLAS (ignora migraciones)
Write-Host "==> npx prisma db push --force-reset" -ForegroundColor Cyan
npx prisma db push --force-reset
if ($LASTEXITCODE -ne 0) { throw "Fallo prisma db push" }

# 5) Verificación rápida con Prisma Studio (opcional)
Write-Host "==> (Opcional) Abriendo Prisma Studio..." -ForegroundColor Cyan
try {
  npx prisma studio
} catch {
  Write-Host "   Prisma Studio no abrió, pero la sincronización pudo haberse hecho igual." -ForegroundColor Yellow
}

Write-Host "✅ Resync terminado. Ahora corré: npm run dev  y probá  http://localhost:3000/dbtest" -ForegroundColor Green
