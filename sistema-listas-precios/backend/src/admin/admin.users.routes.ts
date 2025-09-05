// backend/src/admin/admin.users.routes.ts
// ✅ Actualizado para forzar cambio de contraseña en próximo login y auditar resets.
// - Al CREAR usuario: mustChangePassword = true (si no querés forzar, podés cambiarlo aquí).
// - Al RESET (manual o auto): mustChangePassword = true, lastPasswordResetAt/by se registran.
// - NO se expone la contraseña actual (por seguridad), solo se devuelve una temporal cuando se genera.

import express, { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs'; // sin binarios nativos
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();
const router = express.Router();

type Role = 'admin' | 'user';
type JwtUser = {
  sub: string;
  role: Role;
  email: string;
  descuentoPct: number;
  iat?: number;
  exp?: number;
};

declare global {
  namespace Express {
    interface Request {
      auth?: JwtUser;
    }
  }
}

/* -------------------- Auth middlewares -------------------- */
function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const hdr = req.headers.authorization || '';
    const [, token] = hdr.split(' ');
    if (!token) return res.status(401).json({ error: 'Missing token' });
    const secret = process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ error: 'JWT_SECRET not set' });
    const payload = jwt.verify(token, secret) as JwtUser;
    req.auth = payload;
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

function requireAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.auth) return res.status(401).json({ error: 'Unauthorized' });
  if (req.auth.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
  next();
}

/* -------------------- Helpers -------------------- */
function isValidEmail(email?: string) {
  return !!email && typeof email === 'string' && email.includes('@') && email.includes('.');
}
function clampPct(n: any) {
  const x = Number(n);
  if (!Number.isFinite(x)) return 0;
  return Math.max(0, Math.min(100, x));
}
function randomPassword(len = 10) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
  let out = '';
  for (let i = 0; i < len; i++) out += chars[Math.floor(Math.random() * chars.length)];
  return out;
}

/* -------------------- Rutas Admin Usuarios -------------------- */

/** Listar usuarios */
router.get('/users', requireAuth, requireAdmin, async (_req, res) => {
  const users = await prisma.user.findMany({
    orderBy: { createdAt: 'desc' },
    select: {
      id: true,
      email: true,
      role: true,
      descuentoPct: true,
      isActive: true,
      mustChangePassword: true,
      passwordUpdatedAt: true,
      lastPasswordResetAt: true,
      lastPasswordResetBy: true,
      createdAt: true,
      updatedAt: true,
    },
  });
  res.json({ items: users });
});

/** Crear usuario (admin) */
router.post('/users', requireAuth, requireAdmin, async (req, res) => {
  try {
    const { email, role, descuentoPct, isActive, password } = req.body as {
      email?: string;
      role?: Role;
      descuentoPct?: number;
      isActive?: boolean;
      password?: string;
    };

    if (!isValidEmail(email)) return res.status(400).json({ error: 'email inválido' });

    const r: Role = role === 'admin' ? 'admin' : 'user';
    const desc = clampPct(descuentoPct);
    const active = isActive === undefined ? true : Boolean(isActive);

    const plain = password && typeof password === 'string' && password.length >= 6
      ? password
      : randomPassword(10);

    const passwordHash = await bcrypt.hash(plain, 10);

    // 👇 Por política: forzar cambio al primer login
    const user = await prisma.user.create({
      data: {
        email: email!.trim().toLowerCase(),
        role: r,
        descuentoPct: desc,
        isActive: active,
        passwordHash,
        mustChangePassword: true,           // ← fuerza cambio al primer login
        passwordUpdatedAt: null,            // aún no fue cambiada por el usuario
        lastPasswordResetAt: null,
        lastPasswordResetBy: null,
      },
      select: {
        id: true, email: true, role: true, descuentoPct: true, isActive: true,
        mustChangePassword: true, passwordUpdatedAt: true,
        lastPasswordResetAt: true, lastPasswordResetBy: true,
        createdAt: true, updatedAt: true,
      },
    });

    res.status(201).json({ user, temporaryPassword: password ? undefined : plain });
  } catch (e: any) {
    if (e.code === 'P2002') return res.status(409).json({ error: 'Email ya en uso' });
    console.error('POST /admin/users error', e);
    res.status(500).json({ error: 'Unexpected error' });
  }
});

/** Actualizar campos (email, role, descuentoPct, isActive) */
router.patch('/users/:id', requireAuth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { email, role, descuentoPct, isActive } = req.body as {
    email?: string;
    role?: Role;
    descuentoPct?: number;
    isActive?: boolean;
  };

  const data: any = {};
  if (email !== undefined) {
    if (!isValidEmail(email)) return res.status(400).json({ error: 'email inválido' });
    data.email = email.trim().toLowerCase();
  }
  if (role !== undefined) {
    if (role !== 'admin' && role !== 'user') return res.status(400).json({ error: 'role inválido' });
    data.role = role;
  }
  if (descuentoPct !== undefined) data.descuentoPct = clampPct(descuentoPct);
  if (isActive !== undefined) data.isActive = Boolean(isActive);

  try {
    const updated = await prisma.user.update({
      where: { id },
      data,
      select: {
        id: true, email: true, role: true, descuentoPct: true, isActive: true,
        mustChangePassword: true, passwordUpdatedAt: true,
        lastPasswordResetAt: true, lastPasswordResetBy: true,
        createdAt: true, updatedAt: true,
      },
    });
    res.json(updated);
  } catch (e: any) {
    if (e.code === 'P2002') return res.status(409).json({ error: 'Email ya en uso' });
    if (e.code === 'P2025') return res.status(404).json({ error: 'Usuario no encontrado' });
    console.error('PATCH /admin/users/:id error', e);
    res.status(500).json({ error: 'Unexpected error' });
  }
});

/** Resetear contraseña (manual o auto) + forzar cambio al próximo login */
router.post('/users/:id/reset-password', requireAuth, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { newPassword } = req.body as { newPassword?: string };

  const plain = newPassword && typeof newPassword === 'string' && newPassword.length >= 6
    ? newPassword
    : randomPassword(10);

  const passwordHash = await bcrypt.hash(plain, 10);
  try {
    const now = new Date();
    await prisma.user.update({
      where: { id },
      data: {
        passwordHash,
        mustChangePassword: true,         // ← obliga a cambiarla tras login
        // passwordUpdatedAt se setea cuando el propio usuario la cambie en /auth/change-password
        lastPasswordResetAt: now,
        lastPasswordResetBy: req.auth?.email ?? null,
      },
      select: { id: true },
    });
    res.json({
      ok: true,
      message: newPassword ? 'Contraseña actualizada' : 'Contraseña temporal generada',
      temporaryPassword: newPassword ? undefined : plain,
    });
  } catch (e: any) {
    if (e.code === 'P2025') return res.status(404).json({ error: 'Usuario no encontrado' });
    console.error('POST /admin/users/:id/reset-password error', e);
    res.status(500).json({ error: 'Unexpected error' });
  }
});

export default router;
