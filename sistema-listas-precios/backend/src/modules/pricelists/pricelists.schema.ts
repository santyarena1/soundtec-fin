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
