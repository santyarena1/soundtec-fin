import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';
import prisma from './db/connection';

import authRouter from './modules/auth/auth.routes';
import usersRouter from './modules/users/users.routes';
import suppliersRouter from './modules/suppliers/suppliers.routes';
import productsRouter from './modules/products/products.routes';
import pricelistsRouter from './modules/pricelists/pricelists.routes';
import priceitemsRouter from './modules/priceitems/priceitems.routes';
import adminUsersRouter from './admin/admin.users.routes';

const app = express();

// Middlewares base
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Healthcheck
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Test DB
app.get('/dbtest', async (_req, res, next) => {
  try {
    const count = await prisma.user.count();
    res.json({ ok: true, users: count });
  } catch (err) { next(err); }
});

// Rutas
app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/suppliers', suppliersRouter);
app.use('/products', productsRouter);
app.use('/pricelists', pricelistsRouter);
app.use('/priceitems', priceitemsRouter);
app.use('/admin', adminUsersRouter);

// Error handler al final
app.use(errorHandler);

export default app;

