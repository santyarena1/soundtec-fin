import prisma from '../../db/connection';

export async function listPriceItems(params: { productId?: string; priceListId?: string; latestOnly?: boolean }) {
  const where: any = {};
  if (params.productId) where.productId = params.productId;
  if (params.priceListId) where.priceListId = params.priceListId;

  // Si latestOnly, traemos el mÃ¡s reciente por producto (por effectiveDate y createdAt)
  if (params.latestOnly && params.productId) {
    const items = await prisma.priceItem.findMany({
      where,
      include: { priceList: true, product: { include: { supplier: true } } },
      orderBy: [
        { priceList: { effectiveDate: 'desc' } },
        { createdAt: 'desc' }
      ],
      take: 1
    });
    return items;
  }

  return prisma.priceItem.findMany({
    where,
    include: { priceList: true, product: { include: { supplier: true } } },
    orderBy: [
      { priceList: { effectiveDate: 'desc' } },
      { createdAt: 'desc' }
    ],
    take: 200
  });
}

export async function getPriceItem(id: string) {
  return prisma.priceItem.findUnique({
    where: { id },
    include: { priceList: true, product: true }
  });
}

export async function updatePriceItem(id: string, data: {
  basePriceUsd?: number;
  markupPct?: number;
  impuestosPct?: number;
  ivaPct?: number;
}) {
  return prisma.priceItem.update({
    where: { id },
    data: {
      ...(data.basePriceUsd !== undefined ? { basePriceUsd: data.basePriceUsd } : {}),
      ...(data.markupPct !== undefined ? { markupPct: data.markupPct } : {}),
      ...(data.impuestosPct !== undefined ? { impuestosPct: data.impuestosPct } : {}),
      ...(data.ivaPct !== undefined ? { ivaPct: data.ivaPct } : {})
    },
    include: { priceList: true, product: true }
  });
}

export async function bulkUpdatePriceItems(ids: string[], data: {
  basePriceUsd?: number;
  markupPct?: number;
  impuestosPct?: number;
  ivaPct?: number;
}) {
  // Prisma no permite updateMany selectivo por distintos valores, pero sÃ­ el mismo set para todos
  const res = await prisma.priceItem.updateMany({
    where: { id: { in: ids } },
    data: {
      ...(data.basePriceUsd !== undefined ? { basePriceUsd: data.basePriceUsd } : {}),
      ...(data.markupPct !== undefined ? { markupPct: data.markupPct } : {}),
      ...(data.impuestosPct !== undefined ? { impuestosPct: data.impuestosPct } : {}),
      ...(data.ivaPct !== undefined ? { ivaPct: data.ivaPct } : {})
    }
  });
  return { count: res.count };
}
