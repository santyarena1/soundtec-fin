// backend/src/admin/admin.users.routes.ts
import { Router } from "express";
import { PrismaClient, UserRole } from "@prisma/client";
import jwt from "jsonwebtoken";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();
const router = Router();

/* ========== Middlewares mínimos ========== */
function requireAuth(req: any, res: any, next: any) {
  try {
    const hdr = String(req.headers["authorization"] || "");
    const parts = hdr.split(" ");
    if (parts.length !== 2 || parts[0] !== "Bearer") {
      return res.status(401).json({ error: "Missing token" });
    }
    const token = parts[1];
    const secret = process.env.JWT_SECRET || "devsecret";
    const payload = jwt.verify(token, secret) as any;
    req.auth = { sub: payload.sub, role: payload.role, email: payload.email };
    next();
  } catch {
    return res.status(401).json({ error: "Invalid token" });
  }
}

function requireAdmin(req: any, res: any, next: any) {
  if (!req.auth || req.auth.role !== "admin") {
    return res.status(403).json({ error: "Admin requerido" });
  }
  next();
}

/* ========== GET /admin/users  (lista con paginación) ========== */
router.get("/users", requireAuth, requireAdmin, async (req, res) => {
  try {
    const page = Math.max(parseInt(String(req.query.page ?? "1")), 1);
    const pageSize = Math.min(
      Math.max(parseInt(String(req.query.pageSize ?? "20")), 1),
      100
    );
    const skip = (page - 1) * pageSize;
    const take = pageSize;

    const [items, total] = await prisma.$transaction([
      prisma.user.findMany({
        skip,
        take,
        orderBy: { createdAt: "desc" },
        // ⚠️ Solo campos que existen en tu modelo User
        select: {
          id: true,
          email: true,
          role: true,
          descuentoPct: true,
          isActive: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
      prisma.user.count(),
    ]);

    return res.json({ ok: true, items, total, page, pageSize });
  } catch (err) {
    console.error("[GET /admin/users] error:", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/* ========== POST /admin/users  (crear usuario) ========== */
router.post("/users", requireAuth, requireAdmin, async (req, res) => {
  try {
    const { email, password, role, descuentoPct } = (req.body || {}) as {
      email?: string;
      password?: string;
      role?: UserRole;
      descuentoPct?: number;
    };

    if (!email || !password) {
      return res
        .status(400)
        .json({ error: "email y password son obligatorios" });
    }

    const exists = await prisma.user.findUnique({ where: { email } });
    if (exists) return res.status(409).json({ error: "Email ya registrado" });

    const hash = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        passwordHash: hash,
        role: (role as UserRole) || "user",
        descuentoPct: Number.isFinite(descuentoPct) ? (descuentoPct as number) : 0,
        isActive: true,
      },
      select: {
        id: true,
        email: true,
        role: true,
        descuentoPct: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return res.status(201).json({ ok: true, user, message: "Usuario creado" });
  } catch (err) {
    console.error("[POST /admin/users] error:", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/* ========== PATCH /admin/users/:id  (editar datos básicos) ========== */
router.patch("/users/:id", requireAuth, requireAdmin, async (req, res) => {
  try {
    const id = String(req.params.id);
    const { email, role, descuentoPct, isActive } = (req.body || {}) as {
      email?: string;
      role?: UserRole;
      descuentoPct?: number;
      isActive?: boolean;
    };

    // Solo incluimos lo que venga definido
    const data: any = {};
    if (typeof email === "string") data.email = email;
    if (role === "admin" || role === "user") data.role = role;
    if (Number.isFinite(descuentoPct)) data.descuentoPct = descuentoPct;
    if (typeof isActive === "boolean") data.isActive = isActive;

    const user = await prisma.user.update({
      where: { id },
      data,
      select: {
        id: true,
        email: true,
        role: true,
        descuentoPct: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return res.json({ ok: true, user, message: "Usuario actualizado" });
  } catch (err) {
    console.error("[PATCH /admin/users/:id] error:", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/* ========== POST /admin/users/:id/reset-password  (resetear/emitir temporal) ========== */
router.post(
  "/users/:id/reset-password",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const id = String(req.params.id);
      const { newPassword } = (req.body || {}) as { newPassword?: string };

      // Genera una temporal si no viene
      const temp =
        newPassword ||
        Math.random().toString(36).slice(-6) + Math.random().toString(36).slice(-4);

      const hash = await bcrypt.hash(temp, 10);

      const user = await prisma.user.update({
        where: { id },
        data: {
          passwordHash: hash,
          // ⚠️ Nada de passwordUpdatedAt/lastPasswordResetAt/by
        },
        select: {
          id: true,
          email: true,
          role: true,
          descuentoPct: true,
          isActive: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      return res.json({
        ok: true,
        user,
        temporaryPassword: newPassword ? undefined : temp,
        message: newPassword
          ? "Contraseña actualizada"
          : "Contraseña temporal generada",
      });
    } catch (err) {
      console.error("[POST /admin/users/:id/reset-password] error:", err);
      return res.status(500).json({ error: "Error interno" });
    }
  }
);

export default router;
