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
