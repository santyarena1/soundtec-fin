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
