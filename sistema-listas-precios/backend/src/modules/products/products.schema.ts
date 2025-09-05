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
