import { prisma } from '../../db/connection';
import { calcularPrecio } from '../../utils/pricing';

export async function getProductById(id: string, userDescuentoPct: number) {
  const product = await prisma.product.findUnique({
    where: { id },
    include: {
      supplier: true,
      priceItems: {
        include: { priceList: true },
        orderBy: [
          { priceList: { effectiveDate: 'desc' } },
          { createdAt: 'desc' }
        ],
        take: 1
      }
    }
  });
  if (!product) return null;

  const latest = product.priceItems[0];
  let pricing: any = null;
  if (latest) {
    const { finalAdmin } = calcularPrecio(
      latest.basePriceUsd,
      latest.markupPct,
      latest.impuestosPct,
      latest.ivaPct,
      0
    );
    const priceForUser = finalAdmin * (1 - (userDescuentoPct ?? 0) / 100);
    pricing = {
      priceItemId: latest.id,
      basePriceUsd: latest.basePriceUsd,
      markupPct: latest.markupPct,
      impuestosPct: latest.impuestosPct,
      ivaPct: latest.ivaPct,
      finalAdminUsd: Number(finalAdmin.toFixed(4)),
      priceForUserUsd: Number(priceForUser.toFixed(4)),
      effectiveDate: latest.priceList.effectiveDate
    };
  }

  const { priceItems, ...p } = product as any;
  return { ...p, pricing };
}

export async function listProducts(params: {
  q?: string;
  supplierId?: string;
  skip: number; take: number;
  userDescuentoPct: number;
}) {
  const where: any = {};
  if (params.q) {
    where.OR = [
      { name: { contains: params.q, mode: 'insensitive' } },
      { brand: { contains: params.q, mode: 'insensitive' } },
      { family: { contains: params.q, mode: 'insensitive' } },
      { code: { contains: params.q, mode: 'insensitive' } }
    ];
  }
  if (params.supplierId) where.supplierId = params.supplierId;

  const [items, total] = await Promise.all([
    prisma.product.findMany({
      where,
      orderBy: [{ createdAt: 'desc' }],
      skip: params.skip,
      take: params.take,
      include: {
        supplier: true,
        priceItems: {
          include: { priceList: true },
          orderBy: [
            { priceList: { effectiveDate: 'desc' } },
            { createdAt: 'desc' }
          ],
          take: 1
        }
      }
    }),
    prisma.product.count({ where })
  ]);

  const mapped = items.map(p => {
    const latest = p.priceItems[0];
    let pricing: any = null;
    if (latest) {
      const { finalAdmin } = calcularPrecio(
        latest.basePriceUsd, latest.markupPct, latest.impuestosPct, latest.ivaPct, 0
      );
      const priceForUser = finalAdmin * (1 - (params.userDescuentoPct ?? 0) / 100);
      pricing = {
        priceItemId: latest.id,
        basePriceUsd: latest.basePriceUsd,
        markupPct: latest.markupPct,
        impuestosPct: latest.impuestosPct,
        ivaPct: latest.ivaPct,
        finalAdminUsd: Number(finalAdmin.toFixed(4)),
        priceForUserUsd: Number(priceForUser.toFixed(4)),
        effectiveDate: (latest as any).priceList.effectiveDate
      };
    }
    const { priceItems, ...rest } = p as any;
    return { ...rest, pricing };
  });

  return { items: mapped, total };
}

export async function updateProduct(id: string, data: any) {
  return prisma.product.update({
    where: { id },
    data
  });
}
