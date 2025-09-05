# backend/fix-prisma-client.ps1
# Limpia caché de Prisma, corre migración, regenera tipos y verifica mustChangePassword

$ErrorActionPreference = "Stop"

function Run($cmd) {
  Write-Host "`n> $cmd" -ForegroundColor Cyan
  iex $cmd
}

# 0) Ir a la carpeta del script (debe ser backend)
Set-Location -Path $PSScriptRoot
if (!(Test-Path ".\prisma\schema.prisma")) {
  Write-Host "No encuentro prisma\schema.prisma. Ejecutá este script dentro de la carpeta 'backend'." -ForegroundColor Red
  exit 1
}

Write-Host "Validando Prisma..." -ForegroundColor Yellow
Run "npx prisma validate"
Run "npx prisma format"

Write-Host "`nAplicando migración (add_password_flags)..." -ForegroundColor Yellow
Run "npx prisma migrate dev --name add_password_flags"

Write-Host "`nLimpiando caché de Prisma..." -ForegroundColor Yellow
if (Test-Path ".\node_modules\.prisma") { Remove-Item -Recurse -Force ".\node_modules\.prisma" }
if (Test-Path ".\node_modules\@prisma\client") { Remove-Item -Recurse -Force ".\node_modules\@prisma\client" }

Write-Host "`nRegenerando Prisma Client..." -ForegroundColor Yellow
Run "npx prisma generate"

# Verificación: buscar el campo en los tipos generados
$clientDts = ".\node_modules\@prisma\client\index.d.ts"
if (!(Test-Path $clientDts)) {
  Write-Host "No se encontró $clientDts. ¿Falló la generación?" -ForegroundColor Red
  exit 1
}

$hasField = Select-String -Path $clientDts -Pattern "mustChangePassword" -SimpleMatch -Quiet
if ($hasField) {
  Write-Host "`n✅ Tipos OK: 'mustChangePassword' encontrado en @prisma/client." -ForegroundColor Green
} else {
  Write-Host "`n❌ No aparece 'mustChangePassword' en los tipos." -ForegroundColor Red
  Write-Host "Revisá que el modelo User en prisma/schema.prisma tenga estos campos y guardá el archivo:" -ForegroundColor Yellow
  Write-Host @'
model User {
  id                   String     @id @default(uuid())
  email                String     @unique
  passwordHash         String
  role                 user_role  @default(user)
  descuentoPct         Float      @default(0)
  isActive             Boolean    @default(true)
  mustChangePassword   Boolean    @default(false)
  passwordUpdatedAt    DateTime?
  lastPasswordResetAt  DateTime?
  lastPasswordResetBy  String?
  createdAt            DateTime   @default(now())
  updatedAt            DateTime   @updatedAt
}
'@
  Write-Host "Luego corré de nuevo: npx prisma generate" -ForegroundColor Yellow
  exit 1
}

Write-Host "`nSugerencias si el editor sigue marcando en rojo:" -ForegroundColor Yellow
Write-Host " - En VS Code: Ctrl+Shift+P → 'TypeScript: Restart TS server'." -ForegroundColor Gray
Write-Host " - Cerrá y reabrí la ventana del editor si persiste." -ForegroundColor Gray

Write-Host "`nListo. Ahora podés iniciar el backend: npm run dev" -ForegroundColor Green
