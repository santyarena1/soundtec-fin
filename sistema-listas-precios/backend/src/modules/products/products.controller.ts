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
