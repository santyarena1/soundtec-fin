fix-user-model-and-generate.ps1# backend\fix-user-model-and-generate.ps1
# Arregla el modelo User en prisma/schema.prisma (elimina cualquier campo fantasma como 'existe'),
# asegura el enum UserRole, y regenera Prisma Client.

$ErrorActionPreference = "Stop"

# Ubicación backend (donde está este script)
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ROOT

# Ruta del schema
$SchemaPath = Join-Path $ROOT "prisma\schema.prisma"
if (!(Test-Path $SchemaPath)) {
  Write-Error "No se encontró prisma\schema.prisma en $ROOT"
}

# Contenido actual
$schema = Get-Content $SchemaPath -Raw

# ----------- Definición correcta del modelo User (sin 'existe') -----------
$userModel = @'
model User {
  id                   String    @id @default(uuid())
  email                String    @unique
  passwordHash         String
  role                 UserRole
  descuentoPct         Int       @default(0)
  isActive             Boolean   @default(true)
  mustChangePassword   Boolean   @default(false)
  passwordUpdatedAt    DateTime?
  lastPasswordResetAt  DateTime?
  lastPasswordResetBy  String?
  createdAt            DateTime  @default(now())
  updatedAt            DateTime  @updatedAt
}
'@

# Reemplazar/insertar modelo User
$patternUser = [regex]'model\s+User\s*\{[\s\S]*?\}'
if ($patternUser.IsMatch($schema)) {
  $schema = $patternUser.Replace($schema, $userModel, 1)
  Write-Host "✔ Modelo User reemplazado en schema.prisma" -ForegroundColor Green
} else {
  # Insertar al final si no existe
  $schema = $schema.TrimEnd() + "`r`n`r`n" + $userModel + "`r`n"
  Write-Host "✔ Modelo User agregado al final de schema.prisma" -ForegroundColor Green
}

# Asegurar enum UserRole
$patternEnum = [regex]'enum\s+UserRole\s*\{[\s\S]*?\}'
if (-not $patternEnum.IsMatch($schema)) {
  $enumBlock = @'
enum UserRole {
  admin
  user
}
'@
  $schema = $schema.TrimEnd() + "`r`n`r`n" + $enumBlock + "`r`n"
  Write-Host "✔ Enum UserRole agregado" -ForegroundColor Green
} else {
  Write-Host "✓ Enum UserRole ya existe" -ForegroundColor DarkGray
}

# Guardar con UTF-8 sin BOM
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($SchemaPath, $schema, $Utf8NoBom)
Write-Host "✔ schema.prisma guardado" -ForegroundColor Green

# Limpiar cliente Prisma cacheado
$PrismaCache = Join-Path $ROOT "node_modules\.prisma"
if (Test-Path $PrismaCache) {
  Remove-Item $PrismaCache -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "✔ Cache .prisma eliminado" -ForegroundColor Green
}

# Regenerar Prisma Client
Write-Host "⏳ Ejecutando: npx prisma generate" -ForegroundColor Yellow
$null = & npx prisma generate
if ($LASTEXITCODE -ne 0) { throw "Fallo prisma generate" }
Write-Host "✔ Prisma Client generado" -ForegroundColor Green

Write-Host "`nPASOS FINALES:" -ForegroundColor Yellow
Write-Host " 1) Cerrá TODAS las terminales de 'npm run dev'." -ForegroundColor Gray
Write-Host " 2) taskkill /F /IM node.exe   (ignora error si no hay procesos)." -ForegroundColor Gray
Write-Host " 3) Volvé a iniciar el backend: npm run dev" -ForegroundColor Gray
Write-Host " 4) Probá POST http://localhost:3000/auth/login (admin@example.com / admin123)." -ForegroundColor Gray
Write-Host " 5) Luego GET http://localhost:3000/auth/me con el token." -ForegroundColor Gray
