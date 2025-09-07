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

const allowed = (process.env.CORS_ORIGIN ?? 'http://localhost:5173,https://soundtec-fin.vercel.app')
  .split(',')
  .map(s => s.trim());

app.use((_, res, next) => {
  res.setHeader('Vary', 'Origin');
  next();
});

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

  const ok = allowed.includes(origin);
  cb(null, {
    origin: ok,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false, // no cookies
    optionsSuccessStatus: 204,
  } as CorsOptions);
};

app.use(cors({
  origin: (origin, cb) => {
    if (!origin) return cb(null, true);           // Postman o fetch sin Origin
    return cb(null, allowed.includes(origin));
  },
  methods: ['GET','POST','PUT','PATCH','DELETE','OPTIONS'],
  allowedHeaders: ['Content-Type','Authorization'],
  credentials: false,
  optionsSuccessStatus: 204,
}));

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

app.options('/*', cors());

export default app;
