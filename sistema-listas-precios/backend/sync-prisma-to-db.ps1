# backend\sync-prisma-to-db.ps1
# 1) Trae el schema desde la DB (db pull) -> elimina campos fantasmas como 'existe'
# 2) Borra caches del cliente de Prisma
# 3) Regenera el cliente
# 4) Verifica si queda la palabra 'existe' en schema o en el cliente generado

$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

Write-Host "⏳ Prisma db pull (sincronizando schema con la base)..." -ForegroundColor Yellow
npx prisma db pull | Out-Host

Write-Host "🧹 Borrando caches de Prisma..." -ForegroundColor Yellow
if (Test-Path ".\node_modules\.prisma") { Remove-Item ".\node_modules\.prisma" -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path ".\node_modules\@prisma\client") { Remove-Item ".\node_modules\@prisma\client" -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host "📦 Instalando @prisma/client (por si se borró)..." -ForegroundColor Yellow
npm i @prisma/client | Out-Host

Write-Host "⚙️  Generando Prisma Client..." -ForegroundColor Yellow
npx prisma generate | Out-Host

Write-Host "`n🔍 Buscando 'existe' en prisma/schema.prisma..." -ForegroundColor Yellow
$schemaHits = Select-String -Path .\prisma\schema.prisma -Pattern '\bexiste\b' -CaseSensitive:$false
if ($schemaHits) { $schemaHits | Format-List; Write-Host "⚠️  AÚN aparece 'existe' en schema.prisma" -ForegroundColor Red } else { Write-Host "✅ schema.prisma SIN 'existe'" -ForegroundColor Green }

Write-Host "`n🔍 Buscando 'existe' en el cliente generado..." -ForegroundColor Yellow
$clientHits = Get-ChildItem -Path .\node_modules -Recurse -Include *.d.ts,*.js |
  Select-String -Pattern '\bexiste\b' -CaseSensitive:$false
if ($clientHits) { $clientHits | Select Path, LineNumber, Line | Format-Table -AutoSize; Write-Host "⚠️  AÚN aparece 'existe' en el cliente" -ForegroundColor Red } else { Write-Host "✅ Cliente Prisma SIN 'existe'" -ForegroundColor Green }

Write-Host "`n✅ Listo. Ahora:" -ForegroundColor Green
Write-Host " 1) taskkill /F /IM node.exe  (cerrar procesos node)" -ForegroundColor Gray
Write-Host " 2) npm run dev               (levantar backend de nuevo)" -ForegroundColor Gray
Write-Host " 3) Probar POST /auth/login y GET /auth/me" -ForegroundColor Gray
