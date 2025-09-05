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
