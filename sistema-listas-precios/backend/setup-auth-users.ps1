# backend\setup-auth-users.ps1
# Crea Auth + Users con Prisma, seed de admin desde .env, login JWT y rutas protegidas.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Write-Host "==> Configurando Auth + Users" -ForegroundColor Cyan

# 0) Verificación .env y variables de admin
$envPath = Join-Path $here ".env"
if (-not (Test-Path $envPath)) { throw ".env no encontrado en backend/.env" }
$envContent = Get-Content $envPath -Raw

function Upsert-EnvLine {
  param(
    [string]$key,
    [string]$value
  )
  $regex = "^\s*$key\s*="
  if ($envContent -match $regex) {
    $script:envContent = [regex]::Replace($script:envContent, $regex + ".*$", "$key=$value", 'Multiline')
  } else {
    $script:envContent = $script:envContent.TrimEnd() + "`r`n$key=$value"
  }
}


if ($envContent -notmatch "^\s*ADMIN_EMAIL\s*=")   { Upsert-EnvLine "ADMIN_EMAIL" "admin@example.com" }
if ($envContent -notmatch "^\s*ADMIN_PASSWORD\s*="){ Upsert-EnvLine "ADMIN_PASSWORD" "admin123" }
if ($envContent -notmatch "^\s*JWT_SECRET\s*=")    { Upsert-EnvLine "JWT_SECRET" ([Guid]::NewGuid().ToString('N')) }

$envContent | Out-File -FilePath $envPath -Encoding utf8 -Force
Write-Host "   .env verificado (ADMIN_EMAIL, ADMIN_PASSWORD, JWT_SECRET)" -ForegroundColor Gray

# 1) Instalar (o reafirmar) dependencias necesarias
Write-Host "==> Instalando dependencias si hiciera falta..." -ForegroundColor Cyan
npm pkg set scripts.lint="echo skip" | Out-Null
npm install bcryptjs jsonwebtoken zod @prisma/client --save
npm install -D @types/bcryptjs @types/jsonwebtoken --save-dev

# 2) Archivos: AUTH
$authDir = Join-Path $here "src\modules\auth"
New-Item -ItemType Directory -Force -Path $authDir | Out-Null

# auth.schema.ts
@"
import { z } from 'zod';

export const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(4),
});
export type LoginDTO = z.infer<typeof LoginSchema>;
"@ | Out-File -FilePath (Join-Path $authDir "auth.schema.ts") -Encoding utf8 -Force

# auth.service.ts
@"
import prisma from '../../db/connection';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config';

export async function bootstrapAdmin() {
  const email = process.env.ADMIN_EMAIL || 'admin@example.com';
  const password = process.env.ADMIN_PASSWORD || 'admin123';

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) return;

  const hash = await bcrypt.hash(password, 10);
  await prisma.user.create({
    data: {
      email,
      passwordHash: hash,
      role: 'admin',
      descuentoPct: 0,
      isActive: true,
    },
  });
}

export async function validateLogin(email: string, password: string) {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user || !user.isActive) {
    const e: any = new Error('INVALID_CREDENTIALS');
    e.status = 401;
    throw e;
  }
  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) {
    const e: any = new Error('INVALID_CREDENTIALS');
    e.status = 401;
    throw e;
  }
  const token = jwt.sign(
    { sub: user.id, role: user.role, descuentoPct: user.descuentoPct, email: user.email },
    env.JWT_SECRET,
    { expiresIn: '7d' }
  );
  return {
    token,
    user: {
      id: user.id,
      email: user.email,
      role: user.role,
      descuentoPct: user.descuentoPct,
      isActive: user.isActive,
      createdAt: user.createdAt,
    },
  };
}
"@ | Out-File -FilePath (Join-Path $authDir "auth.service.ts") -Encoding utf8 -Force

# auth.controller.ts
@"
import { Request, Response, NextFunction } from 'express';
import { LoginSchema } from './auth.schema';
import { validateLogin } from './auth.service';

export async function loginController(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = LoginSchema.parse(req.body);
    const result = await validateLogin(parsed.email, parsed.password);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function meController(req: Request, res: Response) {
  const u = (req as any).user;
  res.json({ user: u });
}
"@ | Out-File -FilePath (Join-Path $authDir "auth.controller.ts") -Encoding utf8 -Force

# auth.routes.ts
@"
import { Router } from 'express';
import { loginController, meController } from './auth.controller';
import { authGuard } from '../../middleware/authGuard';

const router = Router();

router.post('/login', loginController);
router.get('/me', authGuard, meController);

export default router;
"@ | Out-File -FilePath (Join-Path $authDir "auth.routes.ts") -Encoding utf8 -Force

# 3) Archivos: USERS
$usersDir = Join-Path $here "src\modules\users"
New-Item -ItemType Directory -Force -Path $usersDir | Out-Null

# users.service.ts
@"
import prisma from '../../db/connection';
import bcrypt from 'bcryptjs';

type CreateUserInput = {
  email: string;
  password: string;
  descuentoPct?: number;
  role?: 'admin' | 'user';
  isActive?: boolean;
};

type UpdateUserInput = {
  password?: string;
  descuentoPct?: number;
  role?: 'admin' | 'user';
  isActive?: boolean;
};

export async function listUsers() {
  return prisma.user.findMany({
    orderBy: { createdAt: 'desc' },
    select: { id: true, email: true, role: true, descuentoPct: true, isActive: true, createdAt: true },
  });
}

export async function createUser(data: CreateUserInput) {
  const hash = await bcrypt.hash(data.password, 10);
  return prisma.user.create({
    data: {
      email: data.email,
      passwordHash: hash,
      role: data.role ?? 'user',
      descuentoPct: data.descuentoPct ?? 0,
      isActive: data.isActive ?? true,
    },
    select: { id: true, email: true, role: true, descuentoPct: true, isActive: true, createdAt: true },
  });
}

export async function updateUser(id: string, data: UpdateUserInput) {
  let passwordHash: string | undefined;
  if (data.password) {
    passwordHash = await bcrypt.hash(data.password, 10);
  }
  return prisma.user.update({
    where: { id },
    data: {
      ...(passwordHash ? { passwordHash } : {}),
      ...(data.descuentoPct !== undefined ? { descuentoPct: data.descuentoPct } : {}),
      ...(data.role ? { role: data.role } : {}),
      ...(data.isActive !== undefined ? { isActive: data.isActive } : {}),
    },
    select: { id: true, email: true, role: true, descuentoPct: true, isActive: true, createdAt: true },
  });
}
"@ | Out-File -FilePath (Join-Path $usersDir "users.service.ts") -Encoding utf8 -Force

# users.controller.ts
@"
import { Request, Response, NextFunction } from 'express';
import { listUsers, createUser, updateUser } from './users.service';

export async function listUsersController(_req: Request, res: Response, next: NextFunction) {
  try {
    const users = await listUsers();
    res.json({ items: users });
  } catch (err) { next(err); }
}

export async function createUserController(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, password, descuentoPct, role, isActive } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: 'EMAIL_AND_PASSWORD_REQUIRED' });
    }
    const u = await createUser({ email, password, descuentoPct, role, isActive });
    res.status(201).json(u);
  } catch (err: any) {
    if (err?.code === 'P2002') {
      return res.status(409).json({ error: 'EMAIL_ALREADY_EXISTS' });
    }
    next(err);
  }
}

export async function updateUserController(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = req.params;
    const { password, descuentoPct, role, isActive } = req.body ?? {};
    const u = await updateUser(id, { password, descuentoPct, role, isActive });
    res.json(u);
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $usersDir "users.controller.ts") -Encoding utf8 -Force

# users.routes.ts
@"
import { Router } from 'express';
import { listUsersController, createUserController, updateUserController } from './users.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Todas las rutas de /users son sólo para ADMIN
router.use(authGuard, adminGuard);

router.get('/', listUsersController);
router.post('/', createUserController);
router.patch('/:id', updateUserController);

export default router;
"@ | Out-File -FilePath (Join-Path $usersDir "users.routes.ts") -Encoding utf8 -Force

# 4) Middlewares authGuard / adminGuard
$mwDir = Join-Path $here "src\middleware"

@"
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config';

export function authGuard(req: Request, res: Response, next: NextFunction) {
  const hdr = req.headers.authorization || '';
  const [, token] = hdr.split(' ');
  if (!token) return res.status(401).json({ error: 'UNAUTHORIZED' });
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as any;
    (req as any).user = {
      id: payload.sub,
      role: payload.role,
      descuentoPct: payload.descuentoPct,
      email: payload.email,
    };
    return next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}
"@ | Out-File -FilePath (Join-Path $mwDir "authGuard.ts") -Encoding utf8 -Force

@"
import { Request, Response, NextFunction } from 'express';

export function adminGuard(req: Request, res: Response, next: NextFunction) {
  const u = (req as any).user;
  if (!u || u.role !== 'admin') {
    return res.status(403).json({ error: 'FORBIDDEN_ADMIN_ONLY' });
  }
  return next();
}
"@ | Out-File -FilePath (Join-Path $mwDir "adminGuard.ts") -Encoding utf8 -Force

# 5) Montar routers en app.ts
$appPath = Join-Path $here "src\app.ts"
@"
import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';
import prisma from './db/connection';

import authRouter from './modules/auth/auth.routes';
import usersRouter from './modules/users/users.routes';

const app = express();

// Middlewares base
app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

// Healthcheck
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Test DB
app.get('/dbtest', async (_req, res, next) => {
  try {
    const count = await prisma.user.count();
    res.json({ ok: true, users: count });
  } catch (err) { next(err); }
});

// Rutas
app.use('/auth', authRouter);
app.use('/users', usersRouter);

// Namespaces pendientes (por ahora 501)
app.use('/suppliers', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/products', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/pricelists', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));
app.use('/scraping', (_req, res) => res.status(501).json({ error: 'NOT_IMPLEMENTED' }));

// Error handler al final
app.use(errorHandler);

export default app;
"@ | Out-File -FilePath $appPath -Encoding utf8 -Force

# 6) Bootstrap admin en server.ts
$serverPath = Join-Path $here "src\server.ts"
@"
import app from './app';
import { env, logger } from './config';
import { bootstrapAdmin } from './modules/auth/auth.service';

async function start() {
  try {
    await bootstrapAdmin();
    const server = app.listen(env.PORT, () => {
      logger.info(`Servidor escuchando en http://localhost:${env.PORT}`);
    });

    const shutdown = (signal: string) => {
      logger.info(`Recibida señal ${signal}, cerrando servidor...`);
      server.close(() => {
        logger.info('Servidor cerrado correctamente.');
        process.exit(0);
      });
    };
    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (err) {
    logger.error({ err }, 'Fallo al iniciar servidor');
    process.exit(1);
  }
}

start();
"@ | Out-File -FilePath $serverPath -Encoding utf8 -Force

Write-Host "✅ Auth + Users listos. Reiniciá con: npm run dev" -ForegroundColor Green
