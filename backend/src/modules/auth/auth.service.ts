import argon2 from 'argon2';
import speakeasy from 'speakeasy';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { pool } from '../../config/database.js';
import { env } from '../../config/env.js';

export class AuthService {
  /**
   * Hashear contraseña con Argon2id (NIST SP 800-63B)
   */
  async hashPassword(password: string): Promise<string> {
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: 65536, // 64 MB
      timeCost: 3,
      parallelism: 4
    });
  }

  /**
   * Verificar contraseña contra hash Argon2id
   */
  async verifyPassword(password: string, hash: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, password);
    } catch {
      return false;
    }
  }

  /**
   * Validar política de contraseñas NIST SP 800-63B y HaveIBeenPwned API (k-Anonymity)
   */
  async validatePasswordPolicy(password: string): Promise<{ valid: boolean; reason?: string }> {
    if (password.length < 12) {
      return { valid: false, reason: 'La contraseña debe contener al menos 12 caracteres.' };
    }

    try {
      // k-Anonymity SHA-1 hash lookup
      const sha1 = crypto.createHash('sha1').update(password).digest('hex').toUpperCase();
      const prefix = sha1.slice(0, 5);
      const suffix = sha1.slice(5);

      const response = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`, {
        headers: { 'Add-Padding': 'true' }
      });

      if (response.ok) {
        const text = await response.text();
        const hasLeak = text.split('\r\n').some(line => line.startsWith(suffix));
        if (hasLeak) {
          return { valid: false, reason: 'Esta contraseña ha aparecido en filtraciones de seguridad públicas conocidas. Por favor, elige otra.' };
        }
      }
    } catch {
      // Si la API externa no está disponible, no bloqueamos el registro pero aseguramos longitud
    }

    return { valid: true };
  }

  /**
   * Generar secreto TOTP para 2FA y 8 códigos de recuperación
   */
  generate2FASecret(userEmail: string) {
    const secret = speakeasy.generateSecret({
      name: `Dashboard Facturas (${userEmail})`,
      issuer: 'DashboardFacturas',
      length: 20
    });

    const recoveryCodes: string[] = [];
    const recoveryHashes: string[] = [];

    for (let i = 0; i < 8; i++) {
      const code = crypto.randomBytes(4).toString('hex').toUpperCase(); // 8 caracteres legibles
      recoveryCodes.push(code);
      recoveryHashes.push(crypto.createHash('sha256').update(code).digest('hex'));
    }

    return {
      otpauthUrl: secret.otpauth_url,
      base32Secret: secret.base32,
      recoveryCodes,
      recoveryHashes
    };
  }

  /**
   * Verificar código TOTP (RFC 6238)
   */
  verifyTOTP(base32Secret: string, userToken: string): boolean {
    return speakeasy.totp.verify({
      secret: base32Secret,
      encoding: 'base32',
      token: userToken,
      window: 1 // +/- 30 segundos de tolerancia de reloj
    });
  }

  /**
   * Generar JWT de sesión firmado
   */
  generateSessionToken(payload: { userId: string; orgId: string; email: string; roles: string[] }): string {
    return jwt.sign(payload, env.JWT_SECRET, { expiresIn: '2h' });
  }

  /**
   * Registrar intento de login y gestionar bloqueo progresivo
   */
  async recordLoginAttempt(email: string, success: boolean, ip: string, userAgent: string) {
    const client = await pool.connect();
    try {
      const userRes = await client.query('SELECT id, organization_id, failed_login_attempts FROM users WHERE email = $1', [email]);
      const user = userRes.rows[0];

      if (user) {
        if (success) {
          await client.query(
            'UPDATE users SET failed_login_attempts = 0, lockout_until = NULL, last_login_at = NOW() WHERE id = $1',
            [user.id]
          );
        } else {
          const attempts = user.failed_login_attempts + 1;
          const lockoutTime = attempts >= 5 ? new Date(Date.now() + 15 * 60 * 1000) : null; // Bloqueo 15 min tras 5 intentos
          await client.query(
            'UPDATE users SET failed_login_attempts = $1, lockout_until = $2 WHERE id = $3',
            [attempts, lockoutTime, user.id]
          );
        }

        // Registrar en audit_logs
        await client.query(
          `INSERT INTO audit_logs (organization_id, user_id, event_type, ip_address, user_agent, details)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            user.organization_id,
            user.id,
            success ? 'LOGIN_SUCCESS' : 'LOGIN_FAILED',
            ip,
            userAgent,
            JSON.stringify({ timestamp: new Date().toISOString() })
          ]
        );
      }
    } finally {
      client.release();
    }
  }
}

export const authService = new AuthService();

