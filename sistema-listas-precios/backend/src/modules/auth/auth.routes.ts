// backend/src/modules/auth/auth.routes.ts
// Versión con SELECT explícito + logging de SQL para el modelo User

import express, { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";
// ⚠️ Importamos el prisma compartido (no creamos un client nuevo)
import prisma from "../../db/connection";

const router = express.Router();

type Role = "admin" | "user";
type JwtUser = { sub: string; role: Role; email: string; descuentoPct: number; iat?: number; exp?: number };

declare global {
  namespace Express { interface Request { auth?: JwtUser } }
}

/* ─────────────────────── Debug SQL (solo modelo User) ─────────────────────── */
let __prismaUserLoggerHooked = false;
if (!__prismaUserLoggerHooked) {
  // Si tu PrismaClient en connection.ts ya tiene log de queries, esto suma un filtro para User
  // y evita duplicados configurándolo una sola vez.
  try {
    // @ts-ignore - $on existe en PrismaClient
    prisma.$on("query", (e: any) => {
      // Mostramos solo las consultas que tocan "public"."User"
      if (typeof e?.query === "string" && e.query.includes('"public"."User"')) {
        console.log(`[SQL User] ${e.query}`);
      }
    });
    __prismaUserLoggerHooked = true;
  } catch (e) {
    // No tiramos el server si por alguna razón no está $on
  }
}

/* ───────────────────────── Helpers de auth ───────────────────────── */

function signToken(user: { id: string; role: Role; email: string; descuentoPct: number }) {
  const secret = process.env.JWT_SECRET;
  if (!secret) throw new Error("JWT_SECRET not set");
  return jwt.sign(
    { sub: user.id, role: user.role, email: user.email, descuentoPct: user.descuentoPct },
    secret,
    { expiresIn: "7d" }
  );
}

function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const hdr = req.headers.authorization || "";
    const [, token] = hdr.split(" ");
    if (!token) return res.status(401).json({ error: "Missing token" });
    const secret = process.env.JWT_SECRET;
    if (!secret) return res.status(500).json({ error: "JWT_SECRET not set" });
    const payload = jwt.verify(token, secret) as JwtUser;
    req.auth = payload;
    next();
  } catch (err) {
    console.error("requireAuth error:", err);
    return res.status(401).json({ error: "Invalid token" });
  }
}

function safeUser(u: any) {
  const { passwordHash, ...rest } = u;
  return rest;
}

function prismaError(res: Response, where: string, err: unknown) {
  const anyErr = err as any;
  if (anyErr?.code === "P2022") {
    console.error(`[${where}] Prisma P2022 meta:`, anyErr?.meta);
    return res
      .status(500)
      .json({ error: "Error de esquema (columna inexistente en DB). Revisá selects/campos del modelo User." });
  }
  console.error(`[${where}] error:`, err);
  return res.status(500).json({ error: "Error interno" });
}

/* ───────────────────────── Rutas ───────────────────────── */

/** POST /auth/login { email, password } */
router.post("/login", async (req, res) => {
  const { email, password } = (req.body || {}) as { email?: string; password?: string };
  if (!email || !password) return res.status(400).json({ error: "email y password requeridos" });

  try {
    // ⚠️ SELECT EXPLÍCITO para esquivar cualquier campo fantasma
    const user = await prisma.user.findFirst({
      where: { email: email.trim().toLowerCase() },
      select: {
        id: true,
        email: true,
        passwordHash: true,
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

    if (!user) return res.status(401).json({ error: "Credenciales inválidas" });
    if (!user.isActive) return res.status(403).json({ error: "Usuario inactivo" });

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ error: "Credenciales inválidas" });

    const token = signToken({
      id: user.id,
      role: user.role as Role,
      email: user.email,
      descuentoPct: Number(user.descuentoPct || 0),
    });

    return res.json({ token, user: safeUser(user) });
  } catch (err) {
    return prismaError(res, "POST /auth/login", err);
  }
});

/** GET /auth/me (necesita token) */
router.get("/me", requireAuth, async (req, res) => {
  try {
    const id = req.auth!.sub;
    // ⚠️ SELECT EXPLÍCITO para esquivar cualquier campo fantasma
    const user = await prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        passwordHash: true,
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

    if (!user) return res.status(404).json({ error: "Usuario no encontrado" });
    return res.json({ user: safeUser(user) });
  } catch (err) {
    return prismaError(res, "GET /auth/me", err);
  }
});

/** POST /auth/change-password { currentPassword, newPassword } */
router.post("/change-password", requireAuth, async (req, res) => {
  const { currentPassword, newPassword } = (req.body || {}) as { currentPassword?: string; newPassword?: string };
  if (!currentPassword || !newPassword) {
    return res.status(400).json({ error: "currentPassword y newPassword requeridos" });
  }
  if (newPassword.length < 6) {
    return res.status(400).json({ error: "La nueva contraseña debe tener al menos 6 caracteres" });
  }

  try {
    const id = req.auth!.sub;
    const user = await prisma.user.findUnique({
      where: { id },
      select: { id: true, passwordHash: true },
    });
    if (!user) return res.status(404).json({ error: "Usuario no encontrado" });

    const ok = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!ok) return res.status(401).json({ error: "Contraseña actual incorrecta" });

    const newHash = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id },
      data: { passwordHash: newHash, passwordUpdatedAt: new Date() },
      select: { id: true },
    });

    return res.json({ ok: true, message: "Contraseña actualizada" });
  } catch (err) {
    return prismaError(res, "POST /auth/change-password", err);
  }
});

/** GET /auth/__debug  → estado básico (no requiere token) */
router.get("/__debug", async (_req, res) => {
  try {
    const jwtOk = !!process.env.JWT_SECRET;
    const users = await prisma.user.count();
    return res.json({
      ok: true,
      jwtSecretSet: jwtOk,
      usersCount: users,
      adminEmail: process.env.ADMIN_EMAIL || "admin@example.com",
      note: jwtOk ? "JWT_SECRET OK" : "⚠️ Falta JWT_SECRET en .env",
    });
  } catch (err) {
    return prismaError(res, "GET /auth/__debug", err);
  }
});

/** GET /auth/token  → inspección del payload */
router.get("/token", requireAuth, (req, res) => {
  return res.json({ payload: req.auth });
});

export default router;
