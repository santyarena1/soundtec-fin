import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env } from '../config';

export function authGuard(req: Request, res: Response, next: NextFunction) {
  const hdr = req.headers.authorization || '';
  const [, token] = hdr.split(' ');
  if (!token) return res.status(401).json({ error: 'UNAUTHORIZED' });
  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as any;
    (req as any).user = {
      id: payload.sub,
      role: payload.role,
      descuentoPct: payload.descuentoPct,
      email: payload.email,
    };
    return next();
  } catch {
    return res.status(401).json({ error: 'INVALID_TOKEN' });
  }
}
