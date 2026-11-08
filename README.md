# Dashboard de Facturaciones y Nóminas — "Tus facturas, organizadas solas"
> **Proyecto Final de Grado Superior en Desarrollo de Aplicaciones Web (2º DAW)**  
> **Autor:** Carlos Plata Morán  
> **GitHub:** [https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto.git](https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto.git)  
> **Web Oficial (GitHub Pages):** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/)

---

## 📞 CANALES OFICIALES DE CONTACTO
- 📱 **Teléfono Directo:** [+34 633 97 15 27](tel:+34633971527)
- 💬 **WhatsApp:** [Escribir a Carlos Plata (+34 633 97 15 27)](https://wa.me/34633971527?text=Hola%20Carlos,%20he%20visto%20tu%20proyecto%20de%20Dashboard%20de%20Facturaciones)
- ✈️ **Telegram y Bot Asistente:** [t.me/+34633971527](https://t.me/+34633971527) *(con Código QR incluido en la portada)*
- 💼 **LinkedIn:** [Carlos Plata Morán](https://www.linkedin.com/in/carlos-plata-mor%C3%A1n-86a978445)
- ✉️ **Correo:** `carplamor25@iesfidiana.es` / `cpm4tic@gmail.com`

---

## 🌟 ¿QUÉ ES ESTE PROYECTO?
**Dashboard de Facturaciones** es una aplicación web y SaaS diseñada para automatizar la gestión contable y fiscal de autónomos y pymes españolas:
- **Lectura Inteligente:** Extracción con IA local privada (Ollama) sin enviar datos personales a nubes de terceros.
- **Cuadre Fiscal Español:** Validación estricta de NIF/CIF y cálculo en tiempo real de los **Modelos 303 (IVA)** y **111 (IRPF)**.
- **Base de Datos Relacional con RLS:** PostgreSQL 16 con aislamiento estricto por organización.
- **Segregación de Roles (RBAC):**
  - 👤 **Vista Empleado:** Modo solo consulta para trabajadores (sin permisos de edición ni borrado).
  - 🏢 **Vista Empresa:** Modo gestor que permite modificar datos de facturas, recalculando impuestos en vivo y subiendo nuevos archivos.
  - 🛡️ **Vista Administrador:** Control de usuarios, planes pagados y visor de logs de auditoría de ciberseguridad en tiempo real.
- **Política Demostrable "Sin Persistencia":** Los documentos originales se almacenan en `/tmpfs` temporal y se borran con sobreescritura segura (**DoD 5220.22-M**) tras la entrega, registrando su hash SHA-256 en la tabla `audit_deletions`.

---

## 📂 ESTRUCTURA DEL PROYECTO
```text
Trabajo terminado/
├── index.html                      # Portada oficial para GitHub Pages + App Web Interactiva
├── README.md                       # Este archivo explicativo maestro
├── .gitignore                      # Exclusión estricta de claves y temporales
├── .env.example                    # Plantilla segura de variables de entorno
├── assets/                         # Códigos QR de Telegram e imágenes oficiales
│   ├── qr-telegram.png
│   └── qr-telegram.jpg
├── database/                       # Scripts DDL y datos de PostgreSQL
│   ├── 01_schema.sql               # Creación de tablas, tipos y restricciones
│   ├── 02_rls_policies.sql         # Políticas de Row-Level Security por rol y tenant
│   ├── 03_seed_demo_data.sql       # Datos seed reales (Estudio Creativo Vega SL)
│   ├── 04_audit_triggers.sql       # Triggers de auditoría inmutable
│   └── backup_restore.sh           # Script de copia cifrada y prueba de restauración
├── backend/                        # API REST en Node.js, TypeScript y Fastify
│   ├── package.json
│   ├── tsconfig.json
│   └── src/                        # Módulos de Auth (Argon2id, 2FA), Tax Engine, Payslips
├── automation/                     # Los 3 Sistemas Automatizados
│   ├── telegram_bot/               # Bot asistente financiero en Telegram + Manual
│   ├── email_pipeline/             # Procesador automático de correos entrantes
│   └── cybersecurity/              # Módulo de hashing seguro y destrucción física DoD
└── docs/                           # Documentación completa y manuales
    ├── DOCUMENTACION_COMPLETA_PROYECTO.md
    └── fase1-analisis-y-arquitectura.md
```

---

## 🚀 CÓMO ACTIVAR GITHUB PAGES EN 2 CLICS
1. Entra a tu repositorio: `https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto`
2. Ve a **Settings** > **Pages**.
3. En **Branch**, elige `main` y la carpeta `/ (root)`.
4. Pulsa **Save**. En menos de un minuto tu aplicación estará online en:
   👉 **`https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/`**
