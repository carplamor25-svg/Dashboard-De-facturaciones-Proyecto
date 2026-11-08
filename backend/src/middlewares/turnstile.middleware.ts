import { FastifyRequest, FastifyReply } from 'fastify';
import { env } from '../config/env.js';

interface TurnstileBody {
  turnstileToken?: string;
  [key: string]: unknown;
}

/**
 * Middleware para validar el Captcha de Cloudflare Turnstile en el lado del servidor.
 * Protege formularios contra bots maliciosos según ASVS v4.0 Nivel 2.
 */
export async function verifyTurnstileCaptcha(
  request: FastifyRequest<{ Body: TurnstileBody }>,
  reply: FastifyReply
) {
  // En entorno de testing o desarrollo podemos omitir si se pasa token dummy
  if (env.NODE_ENV === 'test') {
    return;
  }

  const token = request.body?.turnstileToken;
  if (!token) {
    return reply.status(400).send({
      statusCode: 400,
      error: 'Bad Request',
      message: 'Token de verificación de captcha (Turnstile) obligatorio.'
    });
  }

  const clientIp = request.ip || request.headers['cf-connecting-ip'] || request.headers['x-forwarded-for'];

  try {
    const formData = new URLSearchParams();
    formData.append('secret', env.TURNSTILE_SECRET_KEY);
    formData.append('response', token);
    if (clientIp) {
      formData.append('remoteip', Array.isArray(clientIp) ? clientIp[0] : clientIp);
    }

    const verificationResponse = await fetch(env.TURNSTILE_VERIFY_URL, {
      method: 'POST',
      body: formData,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    const verificationResult = (await verificationResponse.json()) as { success: boolean; 'error-codes'?: string[] };

    if (!verificationResult.success) {
      return reply.status(403).send({
        statusCode: 403,
        error: 'Forbidden',
        message: 'Validación de Captcha fallida o token expirado.',
        details: verificationResult['error-codes']
      });
    }
  } catch (error) {
    request.log.error(error, 'Error al contactar con la API de Cloudflare Turnstile');
    return reply.status(502).send({
      statusCode: 502,
      error: 'Bad Gateway',
      message: 'No se pudo verificar el captcha con el proveedor de seguridad.'
    });
  }
}

