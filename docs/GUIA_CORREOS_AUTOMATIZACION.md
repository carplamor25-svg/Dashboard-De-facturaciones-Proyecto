# Guía Técnica: Módulo Correos_cor · Gestión Automatizada de Facturas por Email
**Proyecto:** Dashboard de Facturaciones v2.0 PRO · 2º DAW  
**Autor:** Carlos Plata Morán (`carplamor25@iesfidiana.es` | Tel: `+34 633 97 15 27`)  
**URL de Acceso en GitHub Pages:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/correos_cor/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/correos_cor/)  
**Repositorio GitHub:** [https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto](https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto)

---

## 1. Finalidad y Alcance de `Correos_cor`

`Correos_cor` es el módulo especializado dentro de la plataforma que centraliza la recepción, inspección de ciberseguridad, extracción con IA y envío certificado de facturas electrónicas a través de los buzones de correo de la empresa.

### Objetivos Clave de 2º DAW:
1. **Control de Facturas Recibidas (Inbound Pipeline):** Escaneo de buzones corporativos (`facturas@estudiovega.es`, `administracion@estudiovega.es`, `contabilidad@estudiovega.es`) para identificar facturas en PDF y extraer sus campos contables.
2. **Despacho Certificado a Clientes (Outbound Pipeline):** Envío formal de facturas emitidas con firma digital, verificación VERI*FACTU y huella SHA-256.
3. **Multi-Bandeja Corporativa:** Capacidad de enlazar múltiples buzones IMAP/SMTP seguros con cifrado TLS 1.3.
4. **Ciberseguridad y Anti-Phishing:** Validación estricta de políticas SPF, DKIM y DMARC para impedir la suplantación de identidad en facturas de proveedores.
5. **Preparación para APIs y Webhooks:** Interfaz desacoplada lista para conectar servicios de automatización masiva (Resend, SendGrid, EmailJS, n8n).

---

## 2. Matriz de Control de Acceso (RBAC) y Seguridad

El acceso a `Correos_cor` está protegido por un sistema de autenticación segregado:

| Rol | Usuario / Correo | Contraseña | Permisos en `Correos_cor` |
| :--- | :--- | :--- | :--- |
| **SuperAdmin (Carlos)** | `carplamor25@iesfidiana.es` | `Motosierra@27` | **Control Absoluto:** Acceso a todos los buzones, vincular/desvincular cuentas de empresa, configuración de API Keys y webhooks, borrado de correos, auditoría de ciberseguridad, exportación y restauración de copias de seguridad de la base de datos. |
| **Empresa Gestor** | `empresa@estudiovega.es` | `Motosierra@27` | Gestión operativa: visualizar facturas recibidas, procesar adjuntos al dashboard contable, redactar y despachar facturas a clientes. |
| **Empleado (Consulta)** | `empleado@estudiovega.es` | `Motosierra@27` | **Solo Lectura:** Consulta de facturas recibidas y estado de envíos sin permisos para desvincular cuentas ni modificar configuraciones. |

---

## 3. Arquitectura de Ciberseguridad Aplicada al Correo Electrónico

Conforme a las exigencias del Esquema Nacional de Seguridad (ENS) y el estándar OWASP:

1. **Inspección de Cabeceras RFC 822:**
   - Cada correo entrante pasa por un analizador que comprueba:
     - **SPF (Sender Policy Framework):** Comprueba que la IP de origen esté autorizada en el registro DNS del dominio del proveedor.
     - **DKIM (DomainKeys Identified Mail):** Verifica la firma criptográfica de clave pública del correo para descartar alteraciones en tránsito.
     - **DMARC (Domain-based Message Authentication, Reporting, and Conformance):** Garantiza que el remitente coincida con la política declarada por el proveedor (rechazando suplantaciones del tipo *facturacion@amazon-falsa.com*).
2. **Sandboxing de Archivos Adjuntos:**
   - Los archivos adjuntos se analizan para constatar que son exclusivamente documentos PDF válidos y no ejecutables disfrazados (`.pdf.exe`).
   - Se calcula el hash SHA-256 de cada factura antes de pasarla al motor OCR.
3. **Audit Trail (Registro de Auditoría Inmutable):**
   - Cada acción (inicio de sesión, recepción de correo, descarga de factura o cambio de regla) genera un evento con marca temporal ISO 8601, IP de origen y usuario responsable.

---

## 4. Conexión de Cuentas de Empresa (IMAP / SMTP)

El módulo permite conectar buzones de cualquier proveedor estándar:

- **Google Workspace / Gmail para Empresas:**
  - Servidor IMAP: `imap.gmail.com` (Puerto 993 SSL)
  - Servidor SMTP: `smtp.gmail.com` (Puerto 587 TLS)
- **Microsoft 365 / Exchange:**
  - Servidor IMAP: `outlook.office365.com` (Puerto 993 SSL)
  - Servidor SMTP: `smtp.office365.com` (Puerto 587 STARTTLS)
- **Servidor Plesk / cPanel propio:**
  - Servidor IMAP: `mail.tudominio.com` (Puerto 993 SSL/TLS)
  - Servidor SMTP: `mail.tudominio.com` (Puerto 465 o 587)

---

## 5. Preparación para Automatización Masiva con APIs Gratuitas

En la pestaña **Automatización & API**, la aplicación está preparada para conectar las siguientes plataformas:

1. **Resend API (Recomendada · 3.000 emails/mes gratis):**
   - Web: `https://resend.com`
   - Clave tipo: `re_123456789...`
   - Permite enviar facturas por correo directamente mediante llamadas HTTP REST.
2. **EmailJS:**
   - Envío de correos directamente desde el navegador del cliente sin backend intermedio.
3. **Webhooks n8n / Zapier:**
   - La aplicación permite introducir una URL de webhook receptora para encadenar flujos automáticos con el bot de Telegram de Carlos (`+34 633 97 15 27`).

---

## 6. Persistencia y Respaldo de la Base de Datos

- La base de datos opera bajo la clave local `CORREOS_COR_DATABASE_V1`.
- Cuenta con herramientas integradas de:
  - **Exportar Copia de Seguridad JSON:** Descarga un fichero completo con todos los buzones, correos e histórico.
  - **Restaurar Copia de Seguridad JSON:** Carga cualquier copia previa para recuperar el entorno.
  - **Restablecer Datos de Demostración:** Vuelve al estado inicial con los 6 correos oficiales de proveedores (Adobe, Google Cloud, Telefónica, Iberdrola, Impact Hub).
