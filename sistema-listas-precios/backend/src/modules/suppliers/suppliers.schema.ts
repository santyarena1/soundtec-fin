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
