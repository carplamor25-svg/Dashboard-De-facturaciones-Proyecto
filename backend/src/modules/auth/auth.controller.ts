import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';
import crypto from 'crypto';
import { pool } from '../../config/database.js';
import { authService } from './auth.service.js';
import { env } from '../../config/env.js';
import { verifyTurnstileCaptcha } from '../../middlewares/turnstile.middleware.js';
import { authenticateSession } from '../../middlewares/auth.middleware.js';

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string(),
  fullName: z.string().min(2),
  companyName: z.string().min(2),
  taxId: z.string().min(5),
  turnstileToken: z.string().optional()
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string(),
  twoFactorCode: z.string().optional(),
  turnstileToken: z.string().optional()
});

export async function authRoutes(app: FastifyInstance) {
  // REGISTRO DE USUARIOS
  app.post('/register', { preHandler: [verifyTurnstileCaptcha] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = registerSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({ message: 'Datos de registro inválidos', errors: parseResult.error.format() });
    }

    const { email, password, fullName, companyName, taxId } = parseResult.data;

    // Validar contraseña según NIST SP 800-63B
    const policy = await authService.validatePasswordPolicy(password);
    if (!policy.valid) {
      return reply.status(400).send({ message: policy.reason });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const existing = await client.query('SELECT id FROM users WHERE email = $1', [email]);
      if (existing.rowCount && existing.rowCount > 0) {
        await client.query('ROLLBACK');
        return reply.status(409).send({ message: 'Ya existe una cuenta con este correo electrónico.' });
      }

      // Crear Organización
      const taxIdHash = crypto.createHash('sha256').update(taxId.toUpperCase().trim()).digest('hex');
      const orgRes = await client.query(
        `INSERT INTO organizations (fiscal_name, tax_id_encrypted, tax_id_hash)
         VALUES ($1, $2, $3) RETURNING id`,
        [companyName, `ENC_${taxId}`, taxIdHash]
      );
      const orgId = orgRes.rows[0].id;

      // Hashear Password con Argon2id
      const passwordHash = await authService.hashPassword(password);
      const verificationToken = crypto.randomBytes(32).toString('hex');
      const verificationExpires = new Date(Date.now() + 15 * 60 * 1000); // 15 min

      // Crear Usuario
      const userRes = await client.query(
        `INSERT INTO users (organization_id, email, password_hash, full_name, email_verification_token, email_verification_expires)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
        [orgId, email, passwordHash, fullName, verificationToken, verificationExpires]
      );
      const userId = userRes.rows[0].id;

      // Asignar Rol 'user' en tabla separada (RBAC en servidor)
      await client.query('INSERT INTO user_roles (user_id, role) VALUES ($1, $2)', [userId, 'user']);

      await client.query('COMMIT');

      return reply.status(201).send({
        message: 'Cuenta creada con éxito. Por favor, verifica tu correo electrónico antes de continuar.',
        userId,
        // En desarrollo devolvemos el token para facilitar pruebas
        debugVerificationToken: env.NODE_ENV !== 'production' ? verificationToken : undefined
      });
    } catch (err) {
      await client.query('ROLLBACK');
      request.log.error(err, 'Error durante el registro');
      return reply.status(500).send({ message: 'Error interno al procesar el registro.' });
    } finally {
      client.release();
    }
  });

  // INICIO DE SESIÓN
  app.post('/login', { preHandler: [verifyTurnstileCaptcha] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const parseResult = loginSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({ message: 'Credenciales inválidas' });
    }

    const { email, password, twoFactorCode } = parseResult.data;
    const clientIp = request.ip || '127.0.0.1';
    const userAgent = (request.headers['user-agent'] as string) || 'Unknown';

    const client = await pool.connect();
    try {
      const userQuery = await client.query(
        `SELECT u.id, u.organization_id, u.email, u.password_hash, u.is_two_factor_enabled,
                u.totp_secret_encrypted, u.failed_login_attempts, u.lockout_until,
                COALESCE(array_agg(r.role), '{}') as roles
         FROM users u
         LEFT JOIN user_roles r ON u.id = r.user_id
         WHERE u.email = $1
         GROUP BY u.id`,
        [email]
      );

      const user = userQuery.rows[0];

      if (!user) {
        await authService.recordLoginAttempt(email, false, clientIp, userAgent);
        return reply.status(401).send({ message: 'Correo o contraseña incorrectos.' });
      }

      // Comprobar bloqueo por intentos fallidos
      if (user.lockout_until && new Date(user.lockout_until) > new Date()) {
        return reply.status(429).send({
          message: 'Cuenta temporalmente bloqueada por reiterados intentos fallidos. Inténtalo más tarde.'
        });
      }

      // Validar Password con Argon2id
      const isValidPassword = await authService.verifyPassword(password, user.password_hash);
      if (!isValidPassword) {
        await authService.recordLoginAttempt(email, false, clientIp, userAgent);
        return reply.status(401).send({ message: 'Correo o contraseña incorrectos.' });
      }

      // Comprobar Segundo Factor (2FA)
      if (user.is_two_factor_enabled) {
        if (!twoFactorCode) {
          return reply.status(200).send({
            requires2FA: true,
            message: 'Introduce el código de 6 dígitos de tu aplicación autenticadora.'
          });
        }

        const isTotpValid = authService.verifyTOTP(user.totp_secret_encrypted, twoFactorCode);
        if (!isTotpValid) {
          await authService.recordLoginAttempt(email, false, clientIp, userAgent);
          return reply.status(401).send({ message: 'Código 2FA incorrecto o expirado.' });
        }
      }

      // Login Exitoso
      await authService.recordLoginAttempt(email, true, clientIp, userAgent);

      const token = authService.generateSessionToken({
        userId: user.id,
        orgId: user.organization_id,
        email: user.email,
        roles: user.roles
      });

      // Fijar cookie HttpOnly, Secure, SameSite
      reply.setCookie('session_token', token, {
        path: '/',
        httpOnly: true,
        secure: env.COOKIE_SECURE,
        sameSite: env.COOKIE_SAME_SITE,
        maxAge: 7200 // 2 horas
      });

      return reply.send({
        message: 'Sesión iniciada correctamente',
        user: {
          id: user.id,
          email: user.email,
          roles: user.roles,
          orgId: user.organization_id
        },
        token // Retornado también para clientes móviles/PWA
      });
    } finally {
      client.release();
    }
  });

  // CONFIGURAR 2FA (Generar QR y secreto Base32)
  app.post('/2fa/setup', { preHandler: [authenticateSession] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const user = request.user!;
    const setupData = authService.generate2FASecret(user.email);

    // Guardar temporalmente el secreto en base de datos
    await pool.query('UPDATE users SET totp_secret_encrypted = $1 WHERE id = $2', [setupData.base32Secret, user.userId]);

    return reply.send({
      otpauthUrl: setupData.otpauthUrl,
      base32Secret: setupData.base32Secret,
      recoveryCodes: setupData.recoveryCodes
    });
  });

  // ACTIVAR Y VERIFICAR 2FA
  app.post('/2fa/verify', { preHandler: [authenticateSession] }, async (request: FastifyRequest<{ Body: { token: string } }>, reply: FastifyReply) => {
    const user = request.user!;
    const { token } = request.body;

    const userRes = await pool.query('SELECT totp_secret_encrypted FROM users WHERE id = $1', [user.userId]);
    const secret = userRes.rows[0]?.totp_secret_encrypted;

    if (!secret || !authService.verifyTOTP(secret, token)) {
      return reply.status(400).send({ message: 'Código 2FA no válido.' });
    }

    await pool.query('UPDATE users SET is_two_factor_enabled = TRUE WHERE id = $1', [user.userId]);
    return reply.send({ message: '2FA activado correctamente en tu cuenta.' });
  });

  // CIERRE DE SESIÓN
  app.post('/logout', async (_request: FastifyRequest, reply: FastifyReply) => {
    reply.clearCookie('session_token', { path: '/' });
    return reply.send({ message: 'Sesión cerrada con éxito.' });
  });

  // DATOS DEL USUARIO ACTUAL
  app.get('/me', { preHandler: [authenticateSession] }, async (request: FastifyRequest, reply: FastifyReply) => {
    const session = request.user!;
    const userRes = await pool.query(
      `SELECT u.id, u.email, u.full_name, u.is_two_factor_enabled, u.preferred_language,
              o.fiscal_name as company_name, o.current_plan_id,
              COALESCE(array_agg(r.role), '{}') as roles
       FROM users u
       JOIN organizations o ON u.organization_id = o.id
       LEFT JOIN user_roles r ON u.id = r.user_id
       WHERE u.id = $1
       GROUP BY u.id, o.id`,
      [session.userId]
    );

    return reply.send({ user: userRes.rows[0] });
  });
}

