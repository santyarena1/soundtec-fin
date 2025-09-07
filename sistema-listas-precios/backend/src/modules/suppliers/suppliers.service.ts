import { prisma } from '../../db/connection';

export async function listSuppliers() {
  return prisma.supplier.findMany({
    orderBy: { name: 'asc' }
  });
}

export async function createSupplier(data: {
  name: string; slug?: string | null; websiteUrl?: string | null; isCrestron?: boolean;
}) {
  return prisma.supplier.create({
    data: {
      name: data.name,
      slug: data.slug ?? null,
      websiteUrl: data.websiteUrl ?? null,
      isCrestron: data.isCrestron ?? false
    }
  });
}

export async function updateSupplier(id: string, data: {
  name?: string; slug?: string | null; websiteUrl?: string | null; isCrestron?: boolean;
}) {
  return prisma.supplier.update({
    where: { id },
    data: {
      ...(data.name !== undefined ? { name: data.name } : {}),
      ...(data.slug !== undefined ? { slug: data.slug } : {}),
      ...(data.websiteUrl !== undefined ? { websiteUrl: data.websiteUrl } : {}),
      ...(data.isCrestron !== undefined ? { isCrestron: data.isCrestron } : {}),
    }
  });
}
