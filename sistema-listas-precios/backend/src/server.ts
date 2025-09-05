import app from './app';
import { env, logger } from './config';
import { bootstrapAdmin } from './modules/auth/auth.service';

async function start() {
  try {
    await bootstrapAdmin();

    const server = app.listen(env.PORT, () => {
      logger.info(`Servidor escuchando en http://localhost:${env.PORT}`);
    });

    const shutdown = (signal: string) => {
      logger.info(`Recibida señal ${signal}, cerrando servidor...`);
      server.close(() => {
        logger.info('Servidor cerrado correctamente.');
        process.exit(0);
      });
    };

    process.on('SIGINT', () => shutdown('SIGINT'));
    process.on('SIGTERM', () => shutdown('SIGTERM'));
  } catch (err) {
    logger.error({ err }, 'Fallo al iniciar servidor');
    process.exit(1);
  }
}

start();
