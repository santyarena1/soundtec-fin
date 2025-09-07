import { prisma } from '../../db/connection';
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
