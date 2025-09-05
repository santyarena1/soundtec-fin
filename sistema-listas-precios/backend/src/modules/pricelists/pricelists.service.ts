import prisma from '../../db/connection';

export async function listPriceLists(params?: { supplierId?: string }) {
  return prisma.priceList.findMany({
    where: params?.supplierId ? { supplierId: params.supplierId } : undefined,
    orderBy: [{ effectiveDate: 'desc' }, { createdAt: 'desc' }],
    include: { supplier: true }
  });
}

export async function importPriceList(payload: {
  supplierId?: string;
  supplierName?: string;
  sourceLabel?: string | null;
  effectiveDate?: Date | null;
  rawCurrency?: string | null;
  items: Array<{
    code: string;
    name?: string | null;
    brand?: string | null;
    family?: string | null;
    description?: string | null;
    photoUrl?: string | null;
    basePriceUsd: number;
    markupPct?: number;
    impuestosPct?: number;
    ivaPct?: number;
    stockMiami?: number | null;
    stockLaredo?: number | null;
    manufacturerInfo?: any;
  }>;
}) {
  // 1) Resolver supplier
  let supplierId = payload.supplierId;
  if (!supplierId) {
    if (!payload.supplierName) {
      const e: any = new Error('SUPPLIER_REQUIRED');
      e.status = 400; throw e;
    }
    const existing = await prisma.supplier.findFirst({
      where: { name: { equals: payload.supplierName, mode: 'insensitive' } }
    });
    if (existing) supplierId = existing.id;
    else {
      const created = await prisma.supplier.create({
        data: { name: payload.supplierName }
      });
      supplierId = created.id;
    }
  }

  // 2) Crear priceList
  const pl = await prisma.priceList.create({
    data: {
      supplierId,
      sourceLabel: payload.sourceLabel ?? null,
      effectiveDate: payload.effectiveDate ?? new Date(),
      rawCurrency: payload.rawCurrency ?? 'USD'
    }
  });

  // 3) Upsert products + crear priceItems
  for (const it of payload.items) {
    // upsert producto por (supplierId, code)
    const product = await prisma.product.upsert({
      where: { supplierId_code: { supplierId, code: it.code } },
      update: {
        ...(it.name ? { name: it.name } : {}),
        ...(it.brand !== undefined ? { brand: it.brand } : {}),
        ...(it.family !== undefined ? { family: it.family } : {}),
        ...(it.description !== undefined ? { description: it.description } : {}),
        ...(it.photoUrl !== undefined ? { photoUrl: it.photoUrl } : {}),
        ...(it.stockMiami !== undefined ? { stockMiami: it.stockMiami } : {}),
        ...(it.stockLaredo !== undefined ? { stockLaredo: it.stockLaredo } : {}),
        ...(it.manufacturerInfo !== undefined ? { manufacturerInfo: it.manufacturerInfo } : {})
      },
      create: {
        supplierId,
        code: it.code,
        name: it.name ?? it.code,
        brand: it.brand ?? null,
        family: it.family ?? null,
        description: it.description ?? null,
        photoUrl: it.photoUrl ?? null,
        stockMiami: it.stockMiami ?? null,
        stockLaredo: it.stockLaredo ?? null,
        manufacturerInfo: it.manufacturerInfo ?? undefined
      }
    });

    await prisma.priceItem.create({
      data: {
        priceListId: pl.id,
        productId: product.id,
        basePriceUsd: it.basePriceUsd,
        markupPct: it.markupPct ?? 0,
        impuestosPct: it.impuestosPct ?? 0,
        ivaPct: it.ivaPct ?? 0
      }
    });
  }

  return pl;
}
