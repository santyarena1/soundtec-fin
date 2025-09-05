import { Request, Response, NextFunction } from 'express';
import { LoginSchema } from './auth.schema';
import { validateLogin } from './auth.service';

export async function loginController(req: Request, res: Response, next: NextFunction) {
  try {
    const parsed = LoginSchema.parse(req.body);
    const result = await validateLogin(parsed.email, parsed.password);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function meController(req: Request, res: Response) {
  const u = (req as any).user;
  res.json({ user: u });
}
