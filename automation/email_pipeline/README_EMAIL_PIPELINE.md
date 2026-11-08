# PIPELINE DE RECEPCIÓN Y ENTREGA AUTOMATIZADA POR CORREO
**Autor:** Carlos Plata Morán  
**Proyecto:** Dashboard de Facturaciones — "Tus facturas, organizadas solas"

---

## 1. DESCRIPCIÓN DEL PROCESO
El sistema permite a cualquier autónomo o cliente enviar sus facturas recibidas o emitidas directamente a una dirección de correo exclusiva (ejemplo: `facturas@midominio.com`).
El servidor procesa el correo de forma totalmente desatendida:
1. **Detección de Archivos Adjuntos:** Descarga los archivos en formato PDF, imagen (PNG, JPG, TIFF) o XML Facturae.
2. **Validación de Seguridad:** Se verifican los *magic bytes* del fichero y se analiza contra malware con ClamAV.
3. **Almacenamiento Temporal Cifrado:** El archivo se almacena en un volumen temporal en memoria RAM (`/tmpfs`) cifrado con AES-256.
4. **Extracción con IA Local:** El worker local llama al modelo Ollama mediante túnel seguro Cloudflare Tunnel para extraer fechas, importes, bases e IVA.
5. **Auditoría Fiscal:** Se valida el cuadre aritmético ($Base + IVA - IRPF = Total$) y el NIF.
6. **Generación del Reporte:** Se genera un informe ejecutivo en PDF de alta resolución mediante Chromium Headless.
7. **Respuesta Automática al Cliente:** Se envía un correo de confirmación al cliente con el desglose en el cuerpo del mensaje, el PDF adjunto y un enlace privado temporal firmado con HMAC.
8. **Destrucción Criptográfica del Original:** El fichero temporal original se sobreescribe con ceros y datos aleatorios (método DoD 5220.22-M) y se registra la evidencia con su hash SHA-256 en la tabla `audit_deletions`.

---

## 2. INTEGRACIÓN CON N8N Y EMAILJS
Para usuarios que prefieran orquestación visual en lugar de scripts Node.js:
- **Flujo n8n:** El archivo `n8n_workflow_invoices.json` contiene el workflow completo listo para importar en cualquier instancia de n8n.
- **EmailJS:** Para el frontend estático alojado en GitHub Pages, el envío de solicitudes de contacto y alertas se realiza a través de la API cliente segura de EmailJS sin necesidad de exponer servidores SMTP.

