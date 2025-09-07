import { Router } from "express";
import jwt from "jsonwebtoken";
import bcrypt from 'bcryptjs';
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();
const router = Router();

/** Middleware: requiere Authorization: Bearer <token> */
function requireAuth(req: any, res: any, next: any) {
  try {
    const hdr = String(req.headers["authorization"] || "");
    const parts = hdr.split(" ");
    if (parts.length !== 2 || parts[0] !== "Bearer") {
      return res.status(401).json({ error: "Missing token" });
    }
    const token = parts[1];
    const secret = process.env.JWT_SECRET || "devsecret";
    if (!secret || secret.length < 6) {
      // No cortamos la app: devolvemos 500 con error claro
      return res.status(500).json({ error: "JWT secret not configured" });
    }
    const payload = jwt.verify(token, secret) as any;
    req.auth = { sub: payload.sub, role: payload.role, email: payload.email };
    next();
  } catch (e) {
    // Token inválido/expirado/formato incorrecto
    return res.status(401).json({ error: "Invalid token" });
  }
}

/** POST /auth/login */
router.post("/login", async (req, res) => {
  try {
    const { email, password } = (req.body || {}) as {
      email?: string;
      password?: string;
    };

    if (!email || !password) {
      return res.status(400).json({ error: "email y password requeridos" });
    }

    // Traemos solo columnas que existen
    const user = await prisma.user.findUnique({
      where: { email },
      select: {
        id: true,
        email: true,
        role: true,
        passwordHash: true,
        descuentoPct: true,
        isActive: true,
      },
    });

    // Evitamos 500 cuando el mail no existe
    if (!user) {
      return res.status(401).json({ error: "Credenciales inválidas" });
    }
    if (!user.isActive) {
      return res.status(403).json({ error: "Usuario inactivo" });
    }

    // Evitamos llamar a bcrypt con hash inválido
    if (!user.passwordHash || user.passwordHash.length < 10) {
      return res
        .status(400)
        .json({ error: "Usuario sin contraseña definida. Pedí reset al admin." });
    }

    let ok = false;
    try {
      ok = await bcrypt.compare(password, user.passwordHash);
    } catch {
      // Si bcrypt explota, devolvemos 401 limpio
      return res.status(401).json({ error: "Credenciales inválidas" });
    }
    if (!ok) {
      return res.status(401).json({ error: "Credenciales inválidas" });
    }

    const secret = process.env.JWT_SECRET || "devsecret";
    if (!secret || secret.length < 6) {
      return res.status(500).json({ error: "JWT secret not configured" });
    }

    const token = jwt.sign(
      {
        sub: user.id,
        role: user.role,
        email: user.email,
        descuentoPct: user.descuentoPct,
      },
      secret,
      { expiresIn: "7d" }
    );

    return res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        descuentoPct: user.descuentoPct,
      },
    });
  } catch (err) {
    console.error("[POST /auth/login] error:", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

/** GET /auth/me (requiere token) */
router.get("/me", requireAuth, async (req: any, res) => {
  try {
    const id = req.auth!.sub as string;
    const me = await prisma.user.findUnique({
      where: { id },
      select: { id: true, email: true, role: true, descuentoPct: true, isActive: true },
    });
    if (!me) return res.status(404).json({ error: "No encontrado" });
    return res.json({ user: me });
  } catch (err) {
    console.error("[GET /auth/me] error:", err);
    return res.status(500).json({ error: "Error interno" });
  }
});

export default router;
