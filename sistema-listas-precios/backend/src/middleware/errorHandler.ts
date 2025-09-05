import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { logger } from '../config';

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    return res.status(400).json({ error: 'VALIDATION_ERROR', details: err.flatten() });
  }

  const status = (err as any)?.status ?? 500;
  const message = (err as any)?.message ?? 'INTERNAL_SERVER_ERROR';

  if (status >= 500) {
    logger.error({ err }, 'Unhandled error');
  } else {
    logger.warn({ err }, 'Handled error');
  }

  return res.status(status).json({ error: message });
}
