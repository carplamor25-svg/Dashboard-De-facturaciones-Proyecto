import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'staging', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  HOST: z.string().default('0.0.0.0'),
  APP_URL: z.string().url().default('http://localhost:5173'),
  API_URL: z.string().url().default('http://localhost:3000'),

  // Base de datos PostgreSQL
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().default(5432),
  DB_NAME: z.string().default('dashboard_facturas_dev'),
  DB_USER: z.string().default('postgres'),
  DB_PASSWORD: z.string().default('postgres'),
  DB_SSL: z.string().transform(v => v === 'true').default('false'),

  // Seguridad y JWT
  JWT_SECRET: z.string().min(32, 'JWT_SECRET debe tener al menos 32 caracteres').default('default-insecure-secret-key-32-chars-long-minimum'),
  COOKIE_SECRET: z.string().min(32).default('default-cookie-secret-key-32-chars-long-minimum'),
  COOKIE_SECURE: z.string().transform(v => v === 'true').default('false'),
  COOKIE_SAME_SITE: z.enum(['Strict', 'Lax', 'None']).default('Lax'),

  // Cloudflare Turnstile
  TURNSTILE_SECRET_KEY: z.string().default('1x0000000000000000000000000000000AA'), // Llave dummy para desarrollo
  TURNSTILE_VERIFY_URL: z.string().url().default('https://challenges.cloudflare.com/turnstile/v0/siteverify'),

  // Redis / BullMQ
  REDIS_HOST: z.string().default('127.0.0.1'),
  REDIS_PORT: z.coerce.number().default(6379),
  REDIS_PASSWORD: z.string().optional(),

  // IA y Worker Local
  OLLAMA_API_BASE_URL: z.string().url().default('http://127.0.0.1:11434'),
  OLLAMA_MODEL: z.string().default('gemma2:9b-instruct-q4_K_M'),

  // Almacenamiento Efímero
  TEMP_STORAGE_PATH: z.string().default('/tmp/facturas_uploads'),
  COLUMN_ENCRYPTION_KEY: z.string().length(64).default('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef')
});

export const env = envSchema.parse(process.env);

