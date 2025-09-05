import { PrismaClient } from "@prisma/client";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

/**
 * Crea admin por defecto si no existe.
 * ADMIN_EMAIL / ADMIN_PASSWORD o admin@example.com / admin123
 */
export async function bootstrapAdmin() {
  const email = (process.env.ADMIN_EMAIL || "admin@example.com").trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD || "admin123";

  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true, email: true },
  });
  if (existing) return { created: false, email };

  const passwordHash = await bcrypt.hash(password, 10);
  await prisma.user.create({
    data: {
      email,
      passwordHash,
      role: "admin",
      descuentoPct: 0,
      isActive: true,
      mustChangePassword: false,
      passwordUpdatedAt: new Date(),
      lastPasswordResetAt: null,
      lastPasswordResetBy: null,
    },
  });

  return { created: true, email };
}

export async function ensureAdminAndLog(logger?: { info: Function }) {
  const res = await bootstrapAdmin();
  if (logger) {
    if (res.created) logger.info(`Admin creado: ${res.email}`);
    else logger.info(`Admin existente: ${res.email}`);
  } else {
    console.log(res.created ? `Admin creado: ${res.email}` : `Admin existente: ${res.email}`);
  }
}