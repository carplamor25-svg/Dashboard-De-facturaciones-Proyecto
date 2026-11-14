# Guía Técnica: Módulo Gestor n8n · Hub de Automatización y Webhooks
**Proyecto:** Dashboard de Facturaciones v2.0 PRO · 2º DAW  
**Autor:** Carlos Plata Morán (`carplamor25@iesfidiana.es` | Tel: `+34 633 97 15 27`)  
**URL de Acceso:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/gestor/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/gestor/)  
**Licencia de Acceso:** Exclusivo para **SuperAdmin (Carlos)** y **Empresas con Plan Profesional o Instalación Única**.

---

## 1. Finalidad y Alcance del `Gestor n8n`

El `Gestor n8n` es el centro de control y orquestación de procesos automáticos diseñado para ejecutar flujos de trabajo sin intervención manual:
1. **Lienzo Gráfico de Nodos:** Representación visual de la cadena completa de eventos (Entrada Webhook → IA OCR → Base de Datos BasCont → Alerta Push Telegram → Cumplimiento VERI*FACTU).
2. **Workflows Preconfigurados:**
   - **Auto-Ingesta de Facturas por Webhook:** Recepción desatendida y extracción de datos contables.
   - **Alerta Push a Telegram:** Aviso instantáneo al móvil de Carlos Plata (`+34 633 97 15 27`) ante gastos significativos (> 200,00 €).
   - **Conciliación Trimestral Modelo 303:** Cálculo de IVA e IRPF programado periódicamente.
   - **Sincronización con ERP Externo:** Exportación a sistemas contables corporativos.
3. **Consola de Ejecuciones en Vivo:** Registro en tiempo real de llamadas HTTP POST, payloads JSON y tiempos de respuesta.
4. **Seguridad en Webhooks:** Autenticación por Bearer Token y validación de firma HMAC-SHA256 para evitar solicitudes no autorizadas (anti-spoofing).

---

## 2. Configuración de API Keys y Enlace con n8n

1. En tu servidor VPS o Docker local, ejecuta n8n (`n8n start` en puerto 5678).
2. En el panel de n8n, genera una **API Key** desde **Settings → n8n API**.
3. En el **Gestor n8n**, introduce la URL de tu instancia (ej: `https://n8n.tudominio.com`) y la API Key correspondiente.
4. Cualquier evento generado en el Dashboard o en `Correos_cor` activará de forma desacoplada los nodos del flujo.
