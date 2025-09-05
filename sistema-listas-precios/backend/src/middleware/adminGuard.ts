import { Request, Response, NextFunction } from 'express';

export function adminGuard(req: Request, res: Response, next: NextFunction) {
  const u = (req as any).user;
  if (!u || u.role !== 'admin') {
    return res.status(403).json({ error: 'FORBIDDEN_ADMIN_ONLY' });
  }
  return next();
}
