# backend\setup-products-prices.ps1
# Crea módulos: suppliers, products, pricelists con Prisma y rutas.
# Incluye importación de una lista de precios (JSON) y cálculo de precio con descuento del usuario.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

Write-Host "==> Configurando Suppliers/Products/PriceLists" -ForegroundColor Cyan

# ---- Dependencias (por si falta zod) ----
npm install zod @prisma/client --save | Out-Null

# ============ utils: paginación ============
$utilsDir = Join-Path $here "src\utils"
New-Item -ItemType Directory -Force -Path $utilsDir | Out-Null
@"
export function parsePagination(query: any) {
  const page = Math.max(1, parseInt(query.page as string) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(query.pageSize as string) || 20));
  const skip = (page - 1) * pageSize;
  const take = pageSize;
  return { page, pageSize, skip, take };
}
"@ | Out-File -FilePath (Join-Path $utilsDir "pagination.ts") -Encoding utf8 -Force

# ============ SUPPLIERS ============
$supDir = Join-Path $here "src\modules\suppliers"
New-Item -ItemType Directory -Force -Path $supDir | Out-Null

# suppliers.schema.ts
@"
import { z } from 'zod';

export const SupplierCreateSchema = z.object({
  name: z.string().min(2),
  slug: z.string().min(2).optional(),
  websiteUrl: z.string().url().optional(),
  isCrestron: z.boolean().optional()
});
export type SupplierCreateDTO = z.infer<typeof SupplierCreateSchema>;

export const SupplierUpdateSchema = SupplierCreateSchema.partial();
export type SupplierUpdateDTO = z.infer<typeof SupplierUpdateSchema>;
"@ | Out-File -FilePath (Join-Path $supDir "suppliers.schema.ts") -Encoding utf8 -Force

# suppliers.service.ts
@"
import prisma from '../../db/connection';

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
"@ | Out-File -FilePath (Join-Path $supDir "suppliers.service.ts") -Encoding utf8 -Force

# suppliers.controller.ts
@"
import { Request, Response, NextFunction } from 'express';
import { SupplierCreateSchema, SupplierUpdateSchema } from './suppliers.schema';
import { listSuppliers, createSupplier, updateSupplier } from './suppliers.service';

export async function listSuppliersController(_req: Request, res: Response, next: NextFunction) {
  try {
    const items = await listSuppliers();
    res.json({ items });
  } catch (err) { next(err); }
}

export async function createSupplierController(req: Request, res: Response, next: NextFunction) {
  try {
    const dto = SupplierCreateSchema.parse(req.body);
    const s = await createSupplier(dto);
    res.status(201).json(s);
  } catch (err: any) {
    if (err?.code === 'P2002') {
      return res.status(409).json({ error: 'SUPPLIER_UNIQUE_CONSTRAINT' });
    }
    next(err);
  }
}

export async function updateSupplierController(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = req.params;
    const dto = SupplierUpdateSchema.parse(req.body);
    const s = await updateSupplier(id, dto);
    res.json(s);
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $supDir "suppliers.controller.ts") -Encoding utf8 -Force

# suppliers.routes.ts
@"
import { Router } from 'express';
import { listSuppliersController, createSupplierController, updateSupplierController } from './suppliers.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Sólo admin por ahora para listar/gestionar proveedores.
router.use(authGuard, adminGuard);

router.get('/', listSuppliersController);
router.post('/', createSupplierController);
router.patch('/:id', updateSupplierController);

export default router;
"@ | Out-File -FilePath (Join-Path $supDir "suppliers.routes.ts") -Encoding utf8 -Force

# ============ PRODUCTS ============
$prodDir = Join-Path $here "src\modules\products"
New-Item -ItemType Directory -Force -Path $prodDir | Out-Null

# products.schema.ts
@"
import { z } from 'zod';

export const ProductUpdateSchema = z.object({
  name: z.string().min(1).optional(),
  brand: z.string().optional(),
  family: z.string().optional(),
  description: z.string().optional(),
  photoUrl: z.string().url().optional(),
  stockMiami: z.number().int().nullable().optional(),
  stockLaredo: z.number().int().nullable().optional(),
  manufacturerInfo: z.any().optional()
});
export type ProductUpdateDTO = z.infer<typeof ProductUpdateSchema>;
"@ | Out-File -FilePath (Join-Path $prodDir "products.schema.ts") -Encoding utf8 -Force

# products.service.ts
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
  let pricing = null;
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

  // Calcular precios por item
  const mapped = items.map(p => {
    const latest = p.priceItems[0];
    let pricing: any = null;
    if (latest) {
      const { finalAdmin } = calcularPrecio(
        latest.basePriceUsd, latest.markupPct, latest.impuestosPct, latest.ivaPct, 0
      );
      const priceForUser = finalAdmin * (1 - (params.userDescuentoPct ?? 0) / 100);
      pricing = {
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
"@ | Out-File -FilePath (Join-Path $prodDir "products.service.ts") -Encoding utf8 -Force

# products.controller.ts
@"
import { Request, Response, NextFunction } from 'express';
import { parsePagination } from '../../utils/pagination';
import { getProductById, listProducts, updateProduct } from './products.service';
import { ProductUpdateSchema } from './products.schema';

export async function listProductsController(req: Request, res: Response, next: NextFunction) {
  try {
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const supplierId = (req.query.supplierId as string) || undefined;
    const q = (req.query.q as string) || undefined;
    const user = (req as any).user;
    const userDescuentoPct = user?.descuentoPct ?? 0;

    const data = await listProducts({ q, supplierId, skip, take, userDescuentoPct });
    res.json({ page, pageSize, total: data.total, items: data.items });
  } catch (err) { next(err); }
}

export async function getProductController(req: Request, res: Response, next: NextFunction) {
  try {
    const user = (req as any).user;
    const userDescuentoPct = user?.descuentoPct ?? 0;
    const p = await getProductById(req.params.id, userDescuentoPct);
    if (!p) return res.status(404).json({ error: 'NOT_FOUND' });
    res.json(p);
  } catch (err) { next(err); }
}

export async function updateProductController(req: Request, res: Response, next: NextFunction) {
  try {
    const dto = ProductUpdateSchema.parse(req.body);
    const result = await updateProduct(req.params.id, dto);
    res.json(result);
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $prodDir "products.controller.ts") -Encoding utf8 -Force

# products.routes.ts
@"
import { Router } from 'express';
import { listProductsController, getProductController, updateProductController } from './products.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Se requiere auth para ver productos (aplica descuento del usuario)
router.use(authGuard);

router.get('/', listProductsController);
router.get('/:id', getProductController);

// Edición sólo admin
router.patch('/:id', adminGuard, updateProductController);

export default router;
"@ | Out-File -FilePath (Join-Path $prodDir "products.routes.ts") -Encoding utf8 -Force

# ============ PRICELISTS ============
$plDir = Join-Path $here "src\modules\pricelists"
New-Item -ItemType Directory -Force -Path $plDir | Out-Null

# pricelists.schema.ts
@"
import { z } from 'zod';

export const PriceListImportSchema = z.object({
  supplierId: z.string().uuid().optional(),
  supplierName: z.string().optional(),
  sourceLabel: z.string().optional(),
  effectiveDate: z.coerce.date().optional(),
  rawCurrency: z.string().optional().default('USD'),
  items: z.array(z.object({
    code: z.string().min(1),
    name: z.string().optional(),
    brand: z.string().optional(),
    family: z.string().optional(),
    description: z.string().optional(),
    photoUrl: z.string().url().optional(),
    basePriceUsd: z.number().nonnegative(),
    markupPct: z.number().nonnegative().default(0),
    impuestosPct: z.number().nonnegative().default(0),
    ivaPct: z.number().nonnegative().default(0),
    stockMiami: z.number().int().optional(),
    stockLaredo: z.number().int().optional(),
    manufacturerInfo: z.any().optional()
  })).min(1)
});
export type PriceListImportDTO = z.infer<typeof PriceListImportSchema>;
"@ | Out-File -FilePath (Join-Path $plDir "pricelists.schema.ts") -Encoding utf8 -Force

# pricelists.service.ts
@"
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
"@ | Out-File -FilePath (Join-Path $plDir "pricelists.service.ts") -Encoding utf8 -Force

# pricelists.controller.ts
@"
import { Request, Response, NextFunction } from 'express';
import { listPriceLists, importPriceList } from './pricelists.service';
import { PriceListImportSchema } from './pricelists.schema';

export async function listPriceListsController(req: Request, res: Response, next: NextFunction) {
  try {
    const supplierId = (req.query.supplierId as string) || undefined;
    const items = await listPriceLists({ supplierId });
    res.json({ items });
  } catch (err) { next(err); }
}

export async function importPriceListController(req: Request, res: Response, next: NextFunction) {
  try {
    const dto = PriceListImportSchema.parse(req.body);
    const pl = await importPriceList(dto);
    res.status(201).json(pl);
  } catch (err) { next(err); }
}
"@ | Out-File -FilePath (Join-Path $plDir "pricelists.controller.ts") -Encoding utf8 -Force

# pricelists.routes.ts
@"
import { Router } from 'express';
import { listPriceListsController, importPriceListController } from './pricelists.controller';
import { authGuard } from '../../middleware/authGuard';
import { adminGuard } from '../../middleware/adminGuard';

const router = Router();

// Sólo admin por ahora
router.use(authGuard, adminGuard);

router.get('/', listPriceListsController);
router.post('/import', importPriceListController);

export default router;
"@ | Out-File -FilePath (Join-Path $plDir "pricelists.routes.ts") -Encoding utf8 -Force

# ============ app.ts: montar routers ============
$appPath = Join-Path $here "src\app.ts"
@"
import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';
import prisma from './db/connection';

import authRouter from './modules/auth/auth.routes';
import usersRouter from './modules/users/users.routes';
import suppliersRouter from './modules/suppliers/suppliers.routes';
import productsRouter from './modules/products/products.routes';
import pricelistsRouter from './modules/pricelists/pricelists.routes';

const app = express();

// Middlewares base
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Healthcheck
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Test DB
app.get('/dbtest', async (_req, res, next) => {
  try {
    const count = await prisma.user.count();
    res.json({ ok: true, users: count });
  } catch (err) { next(err); }
});

// Rutas
app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/suppliers', suppliersRouter);
app.use('/products', productsRouter);
app.use('/pricelists', pricelistsRouter);

// Error handler al final
app.use(errorHandler);

export default app;
"@ | Out-File -FilePath $appPath -Encoding utf8 -Force

Write-Host "✅ Suppliers/Products/PriceLists listos. Reiniciá con: npm run dev" -ForegroundColor Green
