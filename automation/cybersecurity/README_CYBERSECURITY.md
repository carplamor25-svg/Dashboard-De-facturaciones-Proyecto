# ARQUITECTURA DE CIBERSEGURIDAD, HASHING Y PROTECCIÓN DE DATOS
**Autor:** Carlos Plata Morán  
**Proyecto:** Dashboard de Facturaciones y Nóminas — "Tus facturas, organizadas solas"  
**Estándares de Referencia:** OWASP ASVS v4.0 Nivel 2 · NIST SP 800-63B · ENS (Nivel Medio) · RGPD / LOPDGDD

---

## 1. PRINCIPIOS DE SEGURIDAD IMPLEMENTADOS

### 1.1 Autenticación y Gestión de Contraseñas (NIST SP 800-63B)
- **Hash de Contraseñas:** Algoritmo **Argon2id** (o PBKDF2/SHA-512 con 100.000 iteraciones y salt único por usuario).
- **Prohibición de Contraseñas Filtradas:** Verificación asíncrona mediante la API de HaveIBeenPwned mediante k-Anonymity (solo se envían los 5 primeros caracteres del hash SHA-1).
- **Segundo Factor (2FA TOTP):** Conforme al estándar RFC 6238, compatible con Google Authenticator y Authy, con 8 códigos de recuperación hasheados.
- **Protección contra Fuerza Bruta:** Bloqueo progresivo tras 5 intentos fallidos durante 15 minutos y rate-limiting en el servidor.

### 1.2 Segregación de Roles en Servidor (RBAC)
- Los roles (`employee`, `company_admin`, `admin`, `auditor`) se almacenan en una tabla relacional independiente `user_roles`.
- Nunca se confía en parámetros enviados por el cliente. Las comprobaciones de autorización se ejecutan en middleware en el servidor y a nivel de motor de base de datos con **Row-Level Security (RLS)** en PostgreSQL.

### 1.3 Política "Sin Persistencia" y Destrucción Criptográfica
- Los archivos PDF o imágenes subidos por los clientes residen únicamente en un volumen temporal cifrado en memoria RAM (`/tmpfs`).
- Tras procesar la extracción y generar el reporte consolidado, se ejecuta el borrado físico mediante sobreescritura de 3 pasadas (**Norma DoD 5220.22-M**).
- Como prueba de destrucción auditable ante la AEPD (RGPD Art. 5.1.c), se registra un certificado con el hash SHA-256 del fichero original en la tabla inmutable `audit_deletions`.

### 1.4 Logs de Auditoría Inmutables
- Se registran todos los eventos de seguridad: `LOGIN_SUCCESS`, `LOGIN_FAILED`, `2FA_CHALLENGE`, `INVOICE_MODIFIED`, `FILE_SHREDDED`.
- Cada registro almacena: marca de tiempo UTC, usuario, dirección IP de origen, User-Agent del navegador y resultado.

### 1.5 Protección en el Perímetro (Cloudflare Edge)
- **Cloudflare WAF:** Bloqueo de ataques automatizados, inyecciones SQL y Cross-Site Scripting (XSS).
- **Cloudflare Turnstile:** Captcha inteligente sin fricción validado en el servidor para evitar registros masivos de bots.
- **TLS 1.3 Full Strict:** Cifrado extremo a extremo sin certificados obsoletos.
