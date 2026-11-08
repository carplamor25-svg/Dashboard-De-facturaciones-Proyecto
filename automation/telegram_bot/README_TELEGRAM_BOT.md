# ASISTENTE DE TELEGRAM PARA FACTURAS Y FISCALIDAD
**Autor:** Carlos Plata Morán  
**Proyecto:** Dashboard de Facturaciones — "Tus facturas, organizadas solas"  
**Enlace Directo:** [t.me/+34633971527](https://t.me/+34633971527) · **Teléfono:** +34 633 97 15 27

---

## 1. DESCRIPCIÓN Y OBJETIVO
El Bot de Telegram actúa como un **asistente financiero y fiscal en tiempo real** disponible 24/7 para el autónomo o la empresa. Permite consultar al instante:
- Facturación neta acumulada y gastos del trimestre.
- Estimación del **Modelo 303 de IVA** (resultado a pagar o compensar).
- Retenciones soportadas para el **Modelo 111 / 130** de IRPF.
- Últimas facturas procesadas por la IA local.
- Consejos fiscales contextuales citando la Ley del IVA (LIVA) o Ley de IRPF (LIRPF).

---

## 2. COMANDOS DISPONIBLES EN EL BOT

| Comando | Acción Realizada en Base de Datos |
| :--- | :--- |
| `/start` | Mensaje de bienvenida y despliegue del teclado interactivo táctil. |
| `/resumen` | Consulta SQL sobre `invoices` para calcular Total Ingresos, Total Gastos, Beneficio y Margen Comercial. |
| `/facturas` | Devuelve las 5 últimas facturas registradas (emisor, fecha, importe y estado). |
| `/iva` | Agregación del Modelo 303: IVA Repercutido menos IVA Soportado = Liquidación. |
| `/gastos` | Análisis de principales proveedores y suscripciones (coworking, suministros, software). |
| `/consejo` | Última recomendación generada por la IA sobre optimización de gastos y deducciones. |
| `/contacto` | Datos de contacto directo con Carlos Plata Morán (Teléfono, WhatsApp, LinkedIn y Email). |

---

## 3. CÓMO PONER EN MARCHA EL BOT

### Paso 1: Crear el Bot con @BotFather en Telegram
1. Abre Telegram y busca `@BotFather`.
2. Envía el comando `/newbot`.
3. Introduce el nombre visible (ej: `DashboardFacturasBot`) y un username único terminado en `bot`.
4. Copia el **HTTP API Token** generado (ej: `1234567890:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

### Paso 2: Configurar las Variables de Entorno
Añade el token a tu archivo `.env`:
```bash
TELEGRAM_BOT_TOKEN="tu-token-obtenido-de-botfather"
DB_HOST="127.0.0.1"
DB_PORT="5432"
DB_NAME="dashboard_facturas_prod"
DB_USER="postgres"
DB_PASSWORD="tu-password-seguro"
```

### Paso 3: Ejecutar el Servicio
```bash
# Instalar dependencias si no están instaladas
npm install telegraf pg dotenv

# Ejecutar el bot en modo polling o mediante PM2 en el servidor
node automation/telegram_bot/telegram_bot.js
```

---

## 4. INTEGRACIÓN Y CIBERSEGURIDAD
- **Autenticación por Chat ID:** El bot puede configurarse para responder exclusivamente al `telegram_chat_id` registrado en la tabla `users` de la base de datos, impidiendo que terceros no autorizados consulten datos contables.
- **Sin Almacenamiento de Ficheros:** El bot consulta las métricas estructuradas de PostgreSQL mediante consultas parametrizadas `$1, $2` inmunes a SQL Injection.
- **Simulador Web:** En la portada `index.html` del proyecto se incluye un simulador interactivo idéntico para que el tribunal de 2º DAW pueda probar todos los comandos sin necesidad de configurar un bot en vivo.
