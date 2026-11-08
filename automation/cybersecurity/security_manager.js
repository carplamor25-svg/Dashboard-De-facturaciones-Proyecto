/**
 * ==============================================================================
 * MÓDULO DE CIBERSEGURIDAD, HASHING Y DESTRUCCIÓN CRIPTOGRÁFICA
 * Autor: Carlos Plata Morán
 * Cumplimiento: OWASP ASVS v4.0 Nivel 2 · NIST SP 800-63B · RGPD Art. 5.1.c
 * ==============================================================================
 */

import crypto from 'crypto';
import fs from 'fs/promises';

export class SecurityManager {
  /**
   * Hasheo de contraseñas de alta seguridad con salt criptográfico seguro
   */
  static hashPasswordSync(password, salt = crypto.randomBytes(16).toString('hex')) {
    // Implementación PBKDF2 / SHA-512 con 100.000 iteraciones como estándar compatible
    const hash = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
    return `$pbkdf2$iterations=100000$salt=${salt}$hash=${hash}`;
  }

  /**
   * Verificación en tiempo constante para mitigar ataques de temporización (Timing Attacks)
   */
  static verifyPasswordSync(password, storedCombinedHash) {
    try {
      const parts = storedCombinedHash.split('$');
      const salt = parts[3].replace('salt=', '');
      const expectedHash = parts[4].replace('hash=', '');

      const actualHash = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
      return crypto.timingSafeEqual(Buffer.from(actualHash, 'hex'), Buffer.from(expectedHash, 'hex'));
    } catch {
      return false;
    }
  }

  /**
   * Destrucción criptográfica de archivos en disco (Norma DoD 5220.22-M de 3 pasadas)
   * Sobreescribe el fichero con ceros, unos y bytes aleatorios antes de desvincularlo.
   */
  static async shredFile(filePath) {
    try {
      const stats = await fs.stat(filePath);
      const fileSize = stats.size;

      // Pasada 1: Sobreescribir con ceros (0x00)
      const zeroBuffer = Buffer.alloc(fileSize, 0x00);
      await fs.writeFile(filePath, zeroBuffer);

      // Pasada 2: Sobreescribir con unos (0xFF)
      const oneBuffer = Buffer.alloc(fileSize, 0xFF);
      await fs.writeFile(filePath, oneBuffer);

      // Pasada 3: Sobreescribir con bytes aleatorios seguros
      const randomBuffer = crypto.randomBytes(fileSize);
      await fs.writeFile(filePath, randomBuffer);

      // Eliminación física final del inodo
      await fs.unlink(filePath);

      return {
        success: true,
        method: 'DOD_5220_22_M_3_PASS',
        shreddedBytes: fileSize,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      console.error(`[CIBERSEGURIDAD] Error al destruir fichero: ${filePath}`, error);
      throw error;
    }
  }

  /**
   * Generación de Tokens HMAC para URLs privadas con caducidad
   */
  static generateSignedUrlToken(reportId, expirationTimestamp, secretKey) {
    const payload = `${reportId}:${expirationTimestamp}`;
    const hmac = crypto.createHmac('sha256', secretKey).update(payload).digest('hex');
    return `${payload}:${hmac}`;
  }

  /**
   * Validación de token de URL firmada HMAC
   */
  static verifySignedUrlToken(signedToken, secretKey) {
    try {
      const parts = signedToken.split(':');
      if (parts.length !== 3) return { valid: false, reason: 'Formato de token inválido' };

      const [reportId, expirationStr, providedHmac] = parts;
      const expiration = parseInt(expirationStr, 10);

      if (Date.now() > expiration) {
        return { valid: false, reason: 'El enlace privado ha caducado por motivos de seguridad' };
      }

      const expectedHmac = crypto.createHmac('sha256', secretKey).update(`${reportId}:${expirationStr}`).digest('hex');
      const isValid = crypto.timingSafeEqual(Buffer.from(providedHmac, 'hex'), Buffer.from(expectedHmac, 'hex'));

      return isValid 
        ? { valid: true, reportId } 
        : { valid: false, reason: 'Firma criptográfica inválida o alterada' };
    } catch {
      return { valid: false, reason: 'Error durante la verificación del token' };
    }
  }
}

