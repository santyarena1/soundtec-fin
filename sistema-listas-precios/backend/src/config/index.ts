import dotenv from 'dotenv';
import pino from 'pino';

dotenv.config();

export const env = {
  NODE_ENV: process.env.NODE_ENV ?? 'development',
  PORT: Number(process.env.PORT ?? 3000),
  JWT_SECRET: process.env.JWT_SECRET ?? 'CAMBIAME_POR_UNA_CLAVE_SEGURA',
};

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { translateTime: 'SYS:standard', colorize: true } }
    : undefined,
});
