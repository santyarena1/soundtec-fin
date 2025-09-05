import { Request, Response, NextFunction } from 'express';
import { listUsers, createUser, updateUser } from './users.service';

export async function listUsersController(_req: Request, res: Response, next: NextFunction) {
  try {
    const users = await listUsers();
    res.json({ items: users });
  } catch (err) { next(err); }
}

export async function createUserController(req: Request, res: Response, next: NextFunction) {
  try {
    const { email, password, descuentoPct, role, isActive } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ error: 'EMAIL_AND_PASSWORD_REQUIRED' });
    }
    const u = await createUser({ email, password, descuentoPct, role, isActive });
    res.status(201).json(u);
  } catch (err: any) {
    if (err?.code === 'P2002') {
      return res.status(409).json({ error: 'EMAIL_ALREADY_EXISTS' });
    }
    next(err);
  }
}

export async function updateUserController(req: Request, res: Response, next: NextFunction) {
  try {
    const { id } = req.params;
    const { password, descuentoPct, role, isActive } = req.body ?? {};
    const u = await updateUser(id, { password, descuentoPct, role, isActive });
    res.json(u);
  } catch (err) { next(err); }
}
