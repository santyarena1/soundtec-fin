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
