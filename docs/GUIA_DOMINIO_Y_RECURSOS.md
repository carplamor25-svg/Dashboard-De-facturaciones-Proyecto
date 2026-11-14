# Guía Oficial: Conexión de Dominio (.com / .net), APIs Gratuitas de IA y Bot de Telegram
**Proyecto:** Dashboard de Facturaciones v2.0 · 2º DAW  
**Autor:** Carlos Plata Morán (`carplamor25@iesfidiana.es` | Tel: `+34 633 97 15 27`)  
**Repositorio GitHub:** [https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto](https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto)  
**URL de GitHub Pages:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/)  
**URL de la Aplicación Web:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/app/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/app/)

---

## 1. Conexión de un Dominio Personalizado (.com / .net) a GitHub Pages

Para que tu proyecto no tenga la URL larga de GitHub y tenga una dirección propia profesional tipo `tudominio.com` o `facturas-carlosplata.com`, sigue estos pasos:

### Paso 1.1: Registrar el Dominio
Proveedores recomendados con precios transparentes y sin sobrecostes:
1. **Cloudflare Registrar** (Recomendado): Ofrece dominios a precio de coste mayorista (~9$ a 10$ anuales para `.com` o `.net`), sin tarifas ocultas de renovación, e integra automáticamente DNS Anycast y certificados SSL gratuitos.
2. **Porkbun** o **Namecheap**: Alternativas económicas con whois privacy gratuito.

### Paso 1.2: Configurar los Servidores DNS en Cloudflare
Si registras el dominio en otro proveedor, apunta los NS (Nameservers) hacia Cloudflare. En el panel de Cloudflare DNS, añade los siguientes registros:

| Tipo | Nombre (Host) | Contenido / Valor | Proxy Status |
| :--- | :--- | :--- | :--- |
| **A** | `@` | `185.199.108.153` | Nube Naranja (Proxied) |
| **A** | `@` | `185.199.109.153` | Nube Naranja (Proxied) |
| **A** | `@` | `185.199.110.153` | Nube Naranja (Proxied) |
| **A** | `@` | `185.199.111.153` | Nube Naranja (Proxied) |
| **CNAME** | `www` | `carplamor25-svg.github.io` | Nube Naranja (Proxied) |

> **Ventaja de Cloudflare:** Activa WAF (Web Application Firewall), protección contra ataques DDoS y emite un certificado SSL TLS 1.3 gestionado automáticamente con HTTPS forzado.

### Paso 1.3: Vincular el Dominio en GitHub Pages
1. Entra a tu repositorio: `https://github.com/carplamor25-svg/Dashboard-De-facturaciones-Proyecto`
2. Ve a **Settings** -> **Pages** (en el menú lateral izquierdo).
3. En la sección **Custom domain**, escribe tu dominio (ejemplo: `tudominio.com`) y pulsa **Save**.
4. GitHub verificará la propagación DNS y creará automáticamente un archivo llamado `CNAME` en la raíz de tu repositorio.
5. Marca la casilla **"Enforce HTTPS"** para garantizar que todo el tráfico sea cifrado.

---

## 2. Dónde y Cómo Obtener Claves de API Gratuitas para la Inteligencia Artificial

La aplicación ya incluye un **motor de inferencia fiscal inteligente integrado en español** que responde de forma inmediata a cálculos de IVA, IRPF, beneficio y deducciones. Si además quieres conectar modelos de lenguaje generativos masivos (LLMs), tienes estas fuentes gratuitas:

### 2.1 Groq Cloud (La más rápida y 100% gratuita)
- **Web oficial:** [https://console.groq.com/keys](https://console.groq.com/keys)
- **Modelos disponibles gratis:** `llama-3.3-70b-versatile`, `llama-3.1-8b-instant`, `mixtral-8x7b-32768`.
- **Cómo obtener la API Key:**
  1. Inicia sesión con tu cuenta de Google o GitHub.
  2. Haz clic en **"API Keys"** en el menú izquierdo.
  3. Haz clic en **"Create API Key"**, ponle un nombre (ejemplo: `DashboardFacturasCarlos`) y cópiala (`gsk_...`).
  4. En la App Web (`/app`), haz clic en la pestaña **Asistente IA** -> **Configurar API de IA Gratuita**, selecciona **Groq Cloud**, pega la clave y pulsa guardar.

### 2.2 OpenRouter (Múltiples modelos gratuitos)
- **Web oficial:** [https://openrouter.ai/keys](https://openrouter.ai/keys)
- **Modelos gratis (con sufijo `:free`):** `google/gemma-2-9b-it:free`, `meta-llama/llama-3-8b-instruct:free`, `mistralai/mistral-7b-instruct:free`.
- **Cómo obtener la clave:**
  1. Regístrate en OpenRouter.
  2. Entra en **Keys** -> **Create Key**.
  3. Pega la clave `sk-or-...` en la configuración de la App.

### 2.3 Hugging Face Inference API
- **Web oficial:** [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
- Crea un token con rol **Read** para consultar miles de modelos open-source alojados en la plataforma.

### 2.4 Ollama (IA 100% Local y Privada, Sin Internet)
- Si deseas procesar las facturas de forma totalmente confidencial sin enviar datos a la nube:
  1. Descarga Ollama desde [https://ollama.com](https://ollama.com).
  2. Ejecuta en tu terminal: `ollama run llama3:8b`
  3. El backend del proyecto ya está preparado en `automation/` para conectarse a `http://localhost:11434`.

---

## 3. Conexión del Bot de Telegram con @BotFather

Para conectar el bot de Telegram a tu número de teléfono personal (`+34 633 97 15 27`):

1. **Abrir Telegram:** En tu teléfono o PC con la cuenta asociada a `+34 633 97 15 27`, busca al usuario oficial **`@BotFather`** (asegúrate de que tenga el tick azul de verificación).
2. **Crear el Bot:**
   - Escribe y envía: `/newbot`
   - Elige el nombre para tu bot, por ejemplo: `Dashboard Facturas Carlos Plata`
   - Elige el nombre de usuario (debe terminar en `bot`), por ejemplo: `CarlosPlataFacturasBot`
3. **Guardar el Token:** BotFather te enviará un mensaje con el token HTTP API:
   ```text
   Use this token to access the HTTP API:
   7123456789:AAHq_ABC123xyz...
   ```
4. **Configurar el proyecto:**
   - Abre tu archivo `.env` en la raíz del proyecto.
   - Introduce el token:
     ```env
     TELEGRAM_BOT_TOKEN="7123456789:AAHq_ABC123xyz..."
     ADMIN_TELEGRAM_CHAT_ID="TU_ID_DE_CHAT"
     ```
5. **Poner en marcha el bot:**
   - En la carpeta del proyecto, ejecuta:
     ```powershell
     node automation/telegram_bot/telegram_bot.js
     ```
   - ¡Listo! Cuando envíes un PDF de factura a tu bot desde tu móvil `+34 633 97 15 27`, el bot extraerá los datos, calculará los impuestos y te responderá al instante.

---

## 4. Credenciales de Acceso a la Aplicación Web (`/app`)

La aplicación cuenta con roles segregados conforme a los requisitos de 2º DAW:

| Rol | Correo Electrónico | Contraseña | Permisos |
| :--- | :--- | :--- | :--- |
| **SuperAdmin (Carlos)** | `carplamor25@iesfidiana.es` | `Motosierra@27` | **Control Total:** Finanzas, Facturas CRUD, Modelos 303/111, Nóminas, Asistente IA, Panel de Administración de Usuarios, Descarga y Restauración de Base de Datos. |
| **Empresa Gestor** | `empresa@estudiovega.es` | `Motosierra@27` | Gestión de facturas, modificación de conceptos/bases, consulta fiscal y chat IA. |
| **Empleado (Consulta)** | `empleado@estudiovega.es` | `Motosierra@27` | Visualización de facturas e informes en modo solo lectura (sin permisos de edición ni eliminación). |

---

## 5. Resumen de la Arquitectura Creada en la Carpeta `/app`

La carpeta `app/` es un entorno web autónomo que funciona tanto en local como en GitHub Pages:
- **`app/index.html`**:
  - **Motor de lectura PDF.js:** Extrae el contenido de facturas PDF sin necesidad de servidores externos.
  - **Visualizador HTML:** Genera el diseño maquetado de la factura con código de verificación VERI*FACTU.
  - **Exportador:** Permite descargar la factura maquetada en HTML o imprimirla/guardarla en PDF.
  - **Base de Datos Persistente (localStorage):** Almacena las 16 facturas del Estudio Creativo Vega SL, usuarios, credenciales y registros de auditoría con IP y marca temporal.
  - **Chat de IA Libre:** Permite formular cualquier duda fiscal o de negocio en lenguaje natural.
