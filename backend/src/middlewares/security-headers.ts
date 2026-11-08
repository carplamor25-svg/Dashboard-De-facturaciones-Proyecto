import { FastifyInstance } from 'fastify';
import helmet from '@fastify/helmet';
import cors from '@fastify/cors';
import { env } from '../config/env.js';

export async function configureSecurityHeaders(app: FastifyInstance) {
  // CORS restrictivo
  await app.register(cors, {
    origin: (origin, cb) => {
      // En producción solo admitimos orígenes autorizados
      if (!origin || origin === env.APP_URL || origin === env.FRONTEND_URL) {
        cb(null, true);
        return;
      }
      cb(new Error('Bloqueado por política CORS estricta'), false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'cf-turnstile-response']
  });

  // Cabeceras HTTP de Seguridad (OWASP ASVS / SSL Labs A+)
  await app.register(helmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: [
          "'self'",
          "https://challenges.cloudflare.com", // Cloudflare Turnstile
          "'unsafe-inline'" // Necesario para componentes de renderizado gráfico puntual
        ],
        frameSrc: ["https://challenges.cloudflare.com"],
        styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
        fontSrc: ["'self'", "https://fonts.gstatic.com"],
        imgSrc: ["'self'", "data:", "blob:"],
        connectSrc: ["'self'", env.API_URL, env.APP_URL, "https://challenges.cloudflare.com"],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"], // Protección anti-clickjacking
        upgradeInsecureRequests: env.NODE_ENV === 'production' ? [] : null
      }
    },
    hsts: {
      maxAge: 63072000, // 2 años
      includeSubDomains: true,
      preload: true
    },
    referrerPolicy: {
      policy: 'strict-origin-when-cross-origin'
    },
    xContentTypeOptions: true,
    xDnsPrefetchControl: { allow: false }
  });
}

