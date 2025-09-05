# backend\setup-priceitems-admin.ps1
# Crea módulo /priceitems (admin) para listar/editar MarkUp/Impuestos/IVA y expone priceItemId en /products

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Write-Host "==> Configurando módulo PriceItems (admin)" -ForegroundColor Cyan

# Asegurar zod
npm install zod --save | Out-Null

# ----- Directorio -----
$pidir = Join-Path $here "src\modules\priceitems"
New-Item -ItemType Directory -Force -Path $pidir | Out-Null

# ----- Schema -----
@"
import { z } from 'zod';

export const PriceItemUpdateSchema = z.object({
  basePriceUsd: z.number().nonnegative().optional(),
  markupPct: z.number().min(0).max(100).optional(),
  impuestosPct: z.number().min(0).max(100).optional(),
  ivaPct: z.number().min(0).max(100).optional()
});
export type PriceItemUpdateDTO = z.infer<typeof PriceItemUpdateSchema>;

export const PriceItemBulkUpdateSchema = z.object({
  ids: z.array(z.string().uuid()).min(1),
  basePriceUsd: z.number().nonnegative().optional(),
  markupPct: z.number().min(0).max(100).optional(),
  impuestosPct: z.number().min(0).max(100).optional(),
  ivaPct: z.number().min(0).max(100).optional()
}).refine(d => d.basePriceUsd !== undefined || d.markupPct !== undefined || d.impuestosPct !== undefined || d.ivaPct !== undefined, {
  message: 'At least one field to update is required'
});
export type PriceItemBulkUpdateDTO = z.infer<typeof PriceItemBulkUpdateSchema>;
"@ | Out-File -FilePath (Join-Path $pidir "priceitems.schema.ts") -Encoding utf8 -Force

# ----- Service -----
@"
import prisma from '../../db/connection';

export async function listPriceItems(params: { productId?: string; priceListId?: string; latestOnly?: boolean }) {
  const where: any = {};
  if (params.productId) where.productId = params.productId;
  if (params.priceListId) where.priceListId = params.priceListId;

  // Si latestOnly, traemos el más reciente por producto (por effectiveDate y createdAt)
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
  // Prisma no permite updateMany selectivo por distintos valores, pero sí el mismo set para todos
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
"@ | Out-File -FilePath (Join-Path $pidir "priceitems.service.ts") -Encoding utf8 -Force

# ----- Controller -----
@"
import { Request, Response, NextFunction } from 'express';
import { listPriceItems, getPriceItem, updatePriceItem, bulkUpdatePriceItems } from './priceitems.service';
import { PriceItemUpdateSchema, PriceItemBulkUpdateSchema } from './priceitems.schema';

export async function listPriceItemsController(req: Request, res: Response, next: NextFunction) {
  try {
    const productId = (req.query.productId as string) || undefined;
    const priceListId = (req.query.priceListId as string) || undefined;
    const latestOnly = (req.query.latestOnly as string) === 'true' || false;

    const items = await listPriceItems({ productId, priceListId, latestOnly });
    res.json({ items });
  } catch (err) { next(err); }
}

export async function getPriceItemController(req: Request, res: Response, next: NextFunction) {
  try {
    const it = await getPriceItem(req.params.id);
    if (!it) return res.status(404).json({ error: 'NOT_FOUND' });
    res.json(it);
  } catch (err) { next(err); }
}

export async function updatePriceItemController(req: Request, res: Response, next: NextFunction) {
  try {
    const dto = PriceItemUpdateSchema.parse(req.body);
    const it = await updatePriceItem(req.params.id, dto);
    res.json(it);
  } catch (err) { next(err); }
}

export async function bulkUpdatePriceItemsController(req: Request, res: Response, next: NextFunction) {
  try {
    const dto = PriceItemBulkUpdateSchema.parse(req.body);
    const result = await bulkUpdatePriceItems(dto.ids, dto);
    res.json(result);
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $pidir "priceitems.controller.ts") -Encoding utf8 -Force

# ----- Routes -----
@"
import { Router } from 'express';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';
import {
  listPriceItemsController,
  getPriceItemController,
  updatePriceItemController,
  bulkUpdatePriceItemsController
} from './priceitems.controller';

const router = Router();

// Admin-only
router.use(authGuard, adminGuard);

router.get('/', listPriceItemsController);
router.get('/:id', getPriceItemController);
router.patch('/:id', updatePriceItemController);
router.post('/bulk-update', bulkUpdatePriceItemsController);

export default router;
"@ | Out-File -FilePath (Join-Path $pidir "priceitems.routes.ts") -Encoding utf8 -Force

# ----- Actualizar products.service.ts para incluir priceItemId en pricing -----
$prodSvc = Join-Path $here "src\modules\products\products.service.ts"
@"
import prisma from '../../db/connection';
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
"@ | Out-File -FilePath $prodSvc -Encoding utf8 -Force

# ----- Montar /priceitems en app.ts -----
$appPath = Join-Path $here "src\app.ts"
$appContent = Get-Content $appPath -Raw
if ($appContent -notmatch "from './modules/priceitems/priceitems.routes'") {
  $appContent = $appContent -replace "import pricelistsRouter from './modules/pricelists/pricelists.routes';",
"import pricelistsRouter from './modules/pricelists/pricelists.routes';
import priceitemsRouter from './modules/priceitems/priceitems.routes';"
  $appContent = $appContent -replace "app.use\('/pricelists', pricelistsRouter\);\r?\n",
"app.use('/pricelists', pricelistsRouter);
app.use('/priceitems', priceitemsRouter);
"
  $appContent | Out-File -FilePath $appPath -Encoding utf8 -Force
}

Write-Host "✅ PriceItems (admin) listo. Reiniciá con: npm run dev" -ForegroundColor Green
