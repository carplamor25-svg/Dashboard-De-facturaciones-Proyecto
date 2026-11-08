# DASHBOARD DE FACTURACIONES Y NÓMINAS
## "Tus facturas, organizadas solas"
**Documentación Oficial del Proyecto Final de Grado Superior en Desarrollo de Aplicaciones Web (2º DAW)**  
**Autor:** Carlos Plata Morán  
**Curso Académico:** 2026 / 2027  
**Repositorio GitHub:** [https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto.git](https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto.git)  
**Portada GitHub Pages:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/)

---

## CANALES OFICIALES DE CONTACTO Y ATENCIÓN DIRECTA
- 📱 **Teléfono de Contacto:** [+34 633 97 15 27](tel:+34633971527)
- 💬 **WhatsApp Directo:** [Chat con Carlos Plata (+34 633 97 15 27)](https://wa.me/34633971527?text=Hola%20Carlos,%20he%20visto%20tu%20proyecto%20de%20Dashboard%20de%20Facturaciones)
- ✈️ **Telegram Personal y Bot:** [t.me/+34633971527](https://t.me/+34633971527) *(Código QR oficial incluido en la portada web)*
- 💼 **Perfil en LinkedIn:** [linkedin.com/in/carlos-plata-morán-86a978445](https://www.linkedin.com/in/carlos-plata-mor%C3%A1n-86a978445)
- ✉️ **Correo Electrónico Institucional:** `carplamor25@iesfidiana.es` / `cpm4tic@gmail.com`

---

## 1. EXECUTIVE SUMMARY (ENGLISH)
*The **Invoice Dashboard ("Tus facturas, organizadas solas")** is a production-ready, security-hardened SaaS platform and Progressive Web Application (PWA) designed to eliminate manual bookkeeping for Spanish freelancers and SMBs. The system allows users to ingest invoices and payslips in diverse formats (PDF, images, Facturae XML).*

*An on-premise local Artificial Intelligence engine (**Ollama** connected via an encrypted Zero-Trust **Cloudflare Tunnel**) extracts fiscal metadata in seconds, normalizes the data into standard JSON, and computes accounting balances including Spanish VAT Form 303 and Personal Income Tax withholding Form 111. To uphold strict data privacy (GDPR Art. 5.1.c), **the original document binaries are never persisted in the database**; they are held in ephemeral RAM storage (/tmpfs) and systematically destroyed using a 3-pass cryptographic wipe (DoD 5220.22-M standard) with SHA-256 deletion evidence logging.*

*The platform introduces a full-stack **PostgreSQL 16** relational database with **Row-Level Security (RLS)** and three dedicated user access profiles: (1) **Employee View** (read-only queries), (2) **Company Manager View** (real-time invoice editing and live tax recalculation), and (3) **SuperAdmin View** (audit logs, user management, and subscription gating). The frontend is hosted on **GitHub Pages**, providing an interactive web application, an interactive Telegram bot simulator, and automated email pipeline visualizers.*

---

## 2. RESUMEN EJECUTIVO (ESPAÑOL)
El proyecto **Dashboard de Facturaciones** resuelve la carga administrativa y el coste desproporcionado que sufren autónomos y pymes españolas al gestionar su contabilidad trimestral. A partir de una idea inicial basada en scripts de terminal, este proyecto se ha rediseñado por completo como una **aplicación web empresarial con base de datos relacional, control de acceso basado en roles (RBAC) y ciberseguridad avanzada**.

### ¿Qué hace la aplicación?
1. **Recepción Multicanal:** El cliente sube sus facturas o nóminas mediante arrastrar y soltar en la web, a través de un bot de Telegram o enviándolas por correo electrónico.
2. **Extracción con IA Local Privada:** Un modelo de IA alojado en servidor propio extrae emisor, CIF/NIF, número, fecha, base imponible, desglose de IVA (21%, 10%, 4%), IRPF y total.
3. **Auditoría Fiscal Inmediata:** Cuadre matemático estricto ($Base + IVA - IRPF = Total$), validación de NIF/CIF según el algoritmo oficial de la AEAT y previsión de los Modelos 303 y 111.
4. **Política Demostrable "Sin Persistencia":** Los archivos PDF e imágenes se almacenan exclusivamente en memoria efímera mientras se procesan. Tras entregar los resultados, se destruyen físicamente mediante sobreescritura segura (DoD 5220.22-M) y se emite un certificado criptográfico con hash SHA-256.
5. **Base de Datos Relacional y Roles:** Se almacenan únicamente los usuarios, empresas, planes y datos normalizados de las facturas, permitiendo a la empresa corregir datos y a los empleados consultar la información con permisos de solo lectura.

---

## 3. NOVEDADES Y DIFERENCIAS RESPECTO AL KIT PREVIO

| Aspecto | Prototipo Anterior (Kit de partida) | Versión Definitiva Mejorada |
| :--- | :--- | :--- |
| **Persistencia de Datos** | Archivo JSON plano local (`facturas_datos.json`). | Base de datos relacional **PostgreSQL 16** con integridad referencial, claves foráneas y tipos monetarios exactos `NUMERIC(12,2)`. |
| **Seguridad de Datos (RLS)** | Sin control de acceso multiempresa. | **Row-Level Security (RLS)** a nivel de motor: una empresa jamás puede consultar ni modificar datos de otra organización. |
| **Gestión de Usuarios y Roles** | Sin login ni autenticación. | Autenticación completa con **hash Argon2id**, **2FA TOTP**, y 3 roles diferenciados: **Empleado (Consulta)**, **Empresa (Edición)** y **Administrador (SuperAdmin)**. |
| **Almacenamiento de Ficheros** | Ficheros PDF guardados en disco indefinidamente. | **Almacenamiento Efímero:** Los PDFs se guardan en `/tmpfs` temporal y se borran con sobreescritura de 3 pasadas tras su extracción. |
| **Portada y Despliegue** | Archivo estático sin opciones comerciales. | Portada interactiva `index.html` lista para **GitHub Pages** con aplicación web funcional integrada, enlaces directos y código QR de Telegram. |
| **Automatización** | Procesamiento manual por comandos en terminal. | **3 Sistemas Automatizados:** Bot de Telegram, Procesador de Correo Desatendido y Monitor de Ciberseguridad. |

---

## 4. DETALLE DE ROLES Y PRIVILEGIOS DE ACCESO

### 1. Vista Empleado (Rol: `employee`)
- **Objetivo:** Permitir a los trabajadores de la empresa consultar facturas, comprobar abonos de proveedores o descargar justificantes sin riesgo de descuadrar la contabilidad.
- **Permisos:** LECTURA exclusiva (`SELECT`). No puede editar importes, eliminar facturas, subir nuevos archivos ni acceder a la configuración de suscripción de la empresa.

### 2. Vista Empresa / Gestor (Rol: `company_admin`)
- **Objetivo:** Cuenta principal de la empresa (autónomo o gerente).
- **Permisos:** LECTURA, INSERCIÓN y MODIFICACIÓN (`SELECT`, `INSERT`, `UPDATE`).
- **Funcionalidades Clave:**
  - Puede **editar cualquier campo de una factura** (número, base imponible, concepto, IVA o IRPF) directamente en la interfaz.
  - El sistema **recalcula en tiempo real** el total, el balance de beneficios y las casillas del Modelo 303 de IVA.
  - Puede subir nuevas facturas arrastrando archivos a la zona de carga.
  - Descarga de reportes PDF firmados con HMAC.

### 3. Vista Administrador (Rol: `admin`)
- **Objetivo:** Gestión de la plataforma SaaS y supervisión técnica.
- **Permisos:** Control total del sistema (`ALL`).
- **Funcionalidades Clave:**
  - Panel maestro de empresas registradas y usuarios activos.
  - Comprobación de suscripciones y control de acceso según plan pagado.
  - **Visor de Logs de Ciberseguridad en Tiempo Real:** Monitor inmutable que registra inicios de sesión correctos y fallidos, IPs de origen, navegadores (User-Agents) y eventos de destrucción criptográfica de ficheros.

---

## 5. LOS 3 FLUJOS AUTOMATIZADOS DEL PROYECTO

### Automatización 1: Bot de Telegram con Asistente Fiscal
- **Código Fuente:** `automation/telegram_bot/telegram_bot.js`
- **Funcionalidad:** Conectado directamente a PostgreSQL, responde a comandos como `/start`, `/resumen`, `/facturas`, `/iva`, `/gastos`, `/consejo` y `/contacto`.
- **Simulador en Portada:** La página web principal `index.html` incorpora un simulador de chat idéntico para que el tribunal pueda interactuar con el bot de forma inmediata sin necesidad de token.

### Automatización 2: Pipeline de Correos Electrónicos Desatendido
- **Código Fuente:** `automation/email_pipeline/email_processor.js`
- **Funcionalidad:** El cliente envía facturas adjuntas a un email corporativo. El servicio descarga los ficheros, verifica magic bytes binarios contra código malicioso, ejecuta la extracción por IA, cuadra los impuestos y envía de vuelta al cliente un correo con el PDF consolidado y su enlace firmado.

### Automatización 3: Ciberseguridad, Hashing y Borrado Demostrable
- **Código Fuente:** `automation/cybersecurity/security_manager.js`
- **Funcionalidad:** Implementa hashing de contraseñas seguro con salt criptográfico, validación 2FA TOTP conforme a RFC 6238, y el algoritmo de destrucción física de archivos en disco conforme a la **Norma militar estadounidense DoD 5220.22-M (3 pasadas: ceros, unos y bytes aleatorios)** con registro de hash SHA-256.

---

## 6. GUÍA DE ACTIVACIÓN EN GITHUB PAGES

El repositorio oficial está configurado en:
`https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto.git`

Para activar la portada web pública en GitHub Pages:
1. Accede a tu repositorio en GitHub: `https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto`
2. Haz clic en la pestaña **Settings** (Configuración) en la parte superior derecha.
3. En el menú lateral izquierdo, haz clic en **Pages**.
4. En el apartado **Build and deployment**:
   - **Source:** Selecciona *Deploy from a branch*.
   - **Branch:** Selecciona la rama `main` y la carpeta `/ (root)`.
   - Haz clic en **Save** (Guardar).
5. En 1-2 minutos, tu sitio web estará publicado y accesible para todo el mundo en:
   **`https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/`**

