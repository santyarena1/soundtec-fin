import { Request, Response, NextFunction } from 'express';
import { importPriceList } from './pricelists.service';
import { parseCrestronXlsx } from './xlsx.parser';

export async function importXlsxController(req: Request, res: Response, next: NextFunction) {
  try {
    const supplierName = (req.query.supplierName as string) || undefined;
    const supplierId = (req.query.supplierId as string) || undefined;
    const sourceLabel = (req.query.sourceLabel as string) || undefined;
    const rawCurrency = (req.query.rawCurrency as string) || 'USD';

    // @ts-ignore file agregado por multer
    const file = req.file as Express.Multer.File | undefined;
    if (!file) return res.status(400).json({ error: 'FILE_REQUIRED' });

    const { rows, notes } = parseCrestronXlsx(file.path);
    if (!rows.length) return res.status(400).json({ error: 'NO_ROWS_PARSED' });

    const pl = await importPriceList({
      supplierId,
      supplierName,
      sourceLabel,
      effectiveDate: new Date(),
      rawCurrency,
      items: rows
    });

    res.status(201).json({ priceList: pl, imported: rows.length, notes });
  } catch (err) { next(err); }
}
