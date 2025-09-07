import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/errorHandler';
import { prisma } from './db/connection';

// Rutas importadas
import authRouter from './modules/auth/auth.routes';
import usersRouter from './modules/users/users.routes';
import suppliersRouter from './modules/suppliers/suppliers.routes';
import productsRouter from './modules/products/products.routes';
import pricelistsRouter from './modules/pricelists/pricelists.routes';
import priceitemsRouter from './modules/priceitems/priceitems.routes';
import adminUsersRouter from './admin/admin.users.routes';

const app = express();

/** Lista de dominios permitidos para CORS.
 *  Configúralo en Render con la variable CORS_ORIGIN, separando con comas:
 *  CORS_ORIGIN=http://localhost:5173,https://soundtec-fin.vercel.app,https://soundtec-buscador.onrender.com
 */
const allowedOrigins = (process.env.CORS_ORIGIN || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

/** Middleware para evitar cachear incorrectamente el encabezado Access-Control-Allow-Origin */
app.use((_, res, next) => {
  res.setHeader('Vary', 'Origin');
  next();
});

/** Configuración CORS. No registramos routes `app.options('*')` ni `/*` */
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin) return cb(null, true); // permite Postman/cURL sin header Origin
      return cb(null, allowedOrigins.includes(origin));
    },
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
    optionsSuccessStatus: 204,
  }),
);

// Parseadores JSON y URL-encoded
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

// Rutas del negocio
app.use('/auth', authRouter);
app.use('/users', usersRouter);
app.use('/suppliers', suppliersRouter);
app.use('/products', productsRouter);
app.use('/pricelists', pricelistsRouter);
app.use('/priceitems', priceitemsRouter);
app.use('/admin', adminUsersRouter);

// Manejador de errores
app.use(errorHandler);

export default app;
