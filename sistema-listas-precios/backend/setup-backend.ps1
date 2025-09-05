# backend/setup-backend.ps1
# Configura un backend Node+TypeScript con Express, CORS, dotenv, logger y manejo de errores.

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$backend = Join-Path (Split-Path $here -Parent) "backend"
Set-Location $backend

Write-Host "==> Inicializando backend en: $backend" -ForegroundColor Cyan

# 1) Inicializar npm y limpiar paquete por si existe
if (Test-Path ".\package.json") {
  Write-Host "   package.json ya existe: será sobrescrito." -ForegroundColor Yellow
}

# 2) Crear/Escribir package.json
@"
{
  "name": "sistema-listas-precios-backend",
  "version": "0.1.0",
  "private": true,
  "type": "commonjs",
  "main": "dist/server.js",
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only --exit-child src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "typecheck": "tsc --noEmit"
  },
  "engines": {
    "node": ">=20"
  }
}
"@ | Out-File -FilePath ".\package.json" -Encoding utf8 -Force

# 3) tsconfig.json
@"
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
"@ | Out-File -FilePath ".\tsconfig.json" -Encoding utf8 -Force

# 4) Dependencias
Write-Host "==> Instalando dependencias..." -ForegroundColor Cyan
npm install express cors dotenv jsonwebtoken bcryptjs pino pino-pretty zod
npm install -D typescript ts-node ts-node-dev @types/node @types/express @types/cors @types/jsonwebtoken @types/bcryptjs

# 5) Archivos fuente (sobrescribimos placeholders con implementación base)
# src/config/index.ts
@"
import dotenv from 'dotenv';
import pino from 'pino';

dotenv.config();

export const env = {
  NODE_ENV: process.env.NODE_ENV ?? 'development',
  PORT: Number(process.env.PORT ?? 3000),
  JWT_SECRET: process.env.JWT_SECRET ?? 'CAMBIAME_POR_UNA_CLAVE_SEGURA',
};

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { translateTime: 'SYS:standard', colorize: true } }
    : undefined,
});
"@ | Out-File -FilePath ".\src\config\index.ts" -Encoding utf8 -Force

# src/middleware/errorHandler.ts
@"
import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { logger } from '../config';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', details: err.flatten() });
  }

  const status = (err as any)?.status ?? 500;
  const message = (err as any)?.message ?? 'INTERNAL_SERVER_ERROR';

  if (status >= 500) {
    logger.error({ err }, 'Unhandled error');
  } else {
    logger.warn({ err }, 'Handled error');
  }

  return res.status(status).json({ error: message });
}
"@ | Out-File -FilePath ".\src\middleware\errorHandler.ts" -Encoding utf8 -Force

# src/middleware/authGuard.ts (stub: se completará con JWT en fase Auth)
@"
import { Request, Response, NextFunction } from 'express';

export function authGuard(req: Request, res: Response, next: NextFunction) {
  // TODO: implementar verificación JWT y setear req.user
  // Por ahora, pasa directo para probar estructura.
  return next();
}
"@ | Out-File -FilePath ".\src\middleware\authGuard.ts" -Encoding utf8 -Force

# src/middleware/adminGuard.ts (stub)
@"
import { Request, Response, NextFunction } from 'express';

export function adminGuard(_req: Request, res: Response, next: NextFunction) {
  // TODO: cuando haya JWT, verificar role === 'admin'
  // Por ahora, bloquea (descomentar next() al probar libre).
  // return next();
  return res.status(403).json({ error: 'FORBIDDEN_ADMIN_ONLY' });
}
"@ | Out-File -FilePath ".\src\middleware\adminGuard.ts" -Encoding utf8 -Force

# src/utils/pricing.ts (ya existía, lo respetamos si está; si no, creamos)
if (-not (Test-Path ".\src\utils\pricing.ts")) {
@"
/**
 * Fórmula:
 *   finalAdmin = base * (1+markup) * (1+impuestos) * (1+iva)
 *   finalUsuario = finalAdmin * (1 - descuentoUsuario)
 */
export function calcularPrecio(
  baseUsd: number,
  markupPct: number,
  impuestosPct: number,
  ivaPct: number,
  descuentoUsuarioPct: number
) {
  const finalAdmin = baseUsd * (1 + markupPct/100) * (1 + impuestosPct/100) * (1 + ivaPct/100);
  const finalUsuario = finalAdmin * (1 - descuentoUsuarioPct/100);
  return { finalAdmin, finalUsuario };
}
"@ | Out-File -FilePath ".\src\utils\pricing.ts" -Encoding utf8 -Force
}

# src/app.ts
@"
import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';

const app = express();

// Middlewares base
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// Healthcheck
app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Namespaces base (se completarán luego)
app.use('/auth', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/users', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/suppliers', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/products', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/pricelists', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/scraping', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));

// Error handler al final
app.use(errorHandler);

export default app;
"@ | Out-File -FilePath ".\src\app.ts" -Encoding utf8 -Force

# src/server.ts
@"
import app from './app';
import { env, logger } from './config';

const server = app.listen(env.PORT, () => {
  logger.info(`Servidor escuchando en http://localhost:${env.PORT}`);
});

// Manejo de señales
const shutdown = (signal: string) => {
  logger.info(`Recibida señal ${signal}, cerrando servidor...`);
  server.close(() => {
    logger.info('Servidor cerrado correctamente.');
    process.exit(0);
  });
};

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
"@ | Out-File -FilePath ".\src\server.ts" -Encoding utf8 -Force

# 6) .env (si no existe, crear desde ejemplo)
if (-not (Test-Path ".\.env")) {
  if (Test-Path ".\.env.example") {
    Copy-Item ".\.env.example" ".\.env" -Force
    (Get-Content ".\.env") -replace "JWT_SECRET=CAMBIAME_POR_UNA_CLAVE_SEGURA","JWT_SECRET=$( [Guid]::NewGuid().ToString('N') )" | Set-Content ".\.env"
  } else {
    @"
PORT=3000
JWT_SECRET=$( [Guid]::NewGuid().ToString('N') )
"@ | Out-File -FilePath ".\.env" -Encoding utf8 -Force
  }
}

Write-Host "==> Backend configurado." -ForegroundColor Green
Write-Host "   Comandos:" -ForegroundColor Gray
Write-Host "     cd backend" -ForegroundColor Gray
Write-Host "     npm run dev" -ForegroundColor Gray
