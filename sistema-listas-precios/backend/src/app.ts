import express from 'express';
import cors, { CorsOptions, CorsOptionsDelegate } from 'cors';
import { errorHandler } from './middleware/errorHandler';
import { prisma } from './db/connection';

import authRouter from './modules/auth/auth.routes';
import usersRouter from './modules/users/users.routes';
import suppliersRouter from './modules/suppliers/suppliers.routes';
import productsRouter from './modules/products/products.routes';
import pricelistsRouter from './modules/pricelists/pricelists.routes';
import priceitemsRouter from './modules/priceitems/priceitems.routes';
import adminUsersRouter from './admin/admin.users.routes';

const app = express();

/**
 * Lista blanca de orígenes permitidos para CORS.
 * En Render seteá CORS_ORIGIN con una lista separada por comas. Ej:
 *   http://localhost:5173,https://soundtec-fin.vercel.app
 */
const CORS_ENV =
  process.env.CORS_ORIGIN ??
  'http://localhost:5173,https://soundtec-fin.vercel.app';

const ALLOWED_ORIGINS = CORS_ENV.split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// Evita cache incorrecto de CORS en proxies/CDN
app.use((_, res, next) => {
  res.setHeader('Vary', 'Origin');
  next();
});

/**
 * CORS + preflight primero, antes de cualquier router.
 * Usamos Bearer token, así que credentials = false.
 */
const corsOptions: CorsOptions | CorsOptionsDelegate = (req, cb) => {
  const origin = req.headers['origin'] as string | undefined;
  // Permite herramientas sin Origin (curl/Postman)
  if (!origin) {
    return cb(null, {
      origin: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: false,
      optionsSuccessStatus: 204,
    } as CorsOptions);
  }

  const ok = ALLOWED_ORIGINS.includes(origin);
  cb(null, {
    origin: ok,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false, // no cookies
    optionsSuccessStatus: 204,
  } as CorsOptions);
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // responde preflight

// Parsers
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true }));

// Healthcheck
app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// Test DB
app.get('/dbtest', async (_req, res, next) => {
  try {
    const count = await prisma.user.count();
    res.json({ ok: true, users: count });
  } catch (err) {
    next(err);
  }
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
