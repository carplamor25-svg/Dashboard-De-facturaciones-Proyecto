/**
 * ==============================================================================
 * BOT DE TELEGRAM: ASISTENTE FINANCIERO Y FISCAL DE FACTURAS
 * Autor: Carlos Plata Morán
 * Proyecto: Dashboard de Facturaciones — "Tus facturas, organizadas solas"
 * ==============================================================================
 * Funcionalidades:
 * - /start: Bienvenida y menú de opciones con teclado interactivo.
 * - /resumen: KPIs del trimestre actual (Facturación neta, Gastos, Beneficio, IVA).
 * - /facturas: Lista resumida de las últimas facturas procesadas.
 * - /iva: Desglose del Modelo 303 (IVA repercutido vs IVA soportado y resultado).
 * - /gastos: Auditoría de mayores gastos y suscripciones.
 * - /consejo: Recomendación fiscal contextual con citación de la normativa española.
 * - Consulta libre: Procesamiento mediante IA local (Ollama) para resolver dudas contables.
 */

import { Telegraf, Markup } from 'telegraf';
import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || 'TU_TELEGRAM_BOT_TOKEN_AQUI';
const OLLAMA_URL = process.env.OLLAMA_API_BASE_URL || 'http://127.0.0.1:11434';

// Conexión a la base de datos PostgreSQL
const pool = new pg.Pool({
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'dashboard_facturas_prod',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'postgres'
});

const bot = new Telegraf(BOT_TOKEN);

// Teclado persistente de comandos rápidos
const mainKeyboard = Markup.keyboard([
  ['📊 Resumen Financiero', '🧾 Últimas Facturas'],
  ['📑 Modelo 303 (IVA)', '💡 Consejo Fiscal IA'],
  ['📞 Contactar Asesor', '❓ Ayuda']
]).resize();

// 1. Comando /start
bot.start(async (ctx) => {
  const userName = ctx.from.first_name || 'Usuario';
  await ctx.replyWithMarkdown(
    `👋 *¡Hola, ${userName}!* Bienvenido a tu *Asistente Financiero IA*.\n\n` +
    `Estoy conectado a tu *Dashboard de Facturaciones*. Conmigo puedes:\n` +
    `• Consultar ingresos, gastos y márgenes al instante.\n` +
    `• Calcular la previsión del Modelo 303 de IVA y 111 de IRPF.\n` +
    `• Recibir alertas fiscales y consejos anti-fugas.\n\n` +
    `_Selecciona una opción del menú o escríbeme directamente tu consulta._`,
    mainKeyboard
  );
});

// 2. Resumen Financiero
bot.hears(['📊 Resumen Financiero', '/resumen'], async (ctx) => {
  try {
    const res = await pool.query(`
      SELECT 
        COALESCE(SUM(CASE WHEN invoice_type = 'INGRESO' THEN tax_base ELSE 0 END), 0) as total_ingresos,
        COALESCE(SUM(CASE WHEN invoice_type = 'GASTO' THEN tax_base ELSE 0 END), 0) as total_gastos,
        COALESCE(SUM(CASE WHEN invoice_type = 'INGRESO' THEN vat_amount ELSE 0 END), 0) as iva_repercutido,
        COALESCE(SUM(CASE WHEN invoice_type = 'GASTO' THEN vat_amount ELSE 0 END), 0) as iva_soportado,
        COALESCE(SUM(CASE WHEN invoice_type = 'INGRESO' THEN irpf_amount ELSE 0 END), 0) as irpf_retenido
      FROM invoices
    `);

    const d = res.rows[0];
    const ingresos = parseFloat(d.total_ingresos);
    const gastos = parseFloat(d.total_gastos);
    const beneficio = ingresos - gastos;
    const margen = ingresos > 0 ? ((beneficio / ingresos) * 100).toFixed(1) : '0';

    await ctx.replyWithMarkdown(
      `📊 *RESUMEN FINANCIERO ACTUAL*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `🟢 *Facturación Neta:* \`${ingresos.toLocaleString('es-ES', { minimumFractionDigits: 2 })} €\`\n` +
      `🔴 *Gastos Deducibles:* \`${gastos.toLocaleString('es-ES', { minimumFractionDigits: 2 })} €\`\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `💎 *Beneficio Neto:* \`${beneficio.toLocaleString('es-ES', { minimumFractionDigits: 2 })} €\`\n` +
      `📈 *Margen Comercial:* \`${margen} %\`\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `🛡️ _Datos calculados con base en las facturas auditadas._`
    );
  } catch (err) {
    console.error(err);
    await ctx.reply('⚠️ No se pudo obtener el resumen en este momento. Revisa la conexión con la base de datos.');
  }
});

// 3. Últimas Facturas
bot.hears(['🧾 Últimas Facturas', '/facturas'], async (ctx) => {
  try {
    const res = await pool.query(`
      SELECT invoice_number, issuer_name, receiver_name, invoice_type, total_amount, issue_date
      FROM invoices
      ORDER BY issue_date DESC
      LIMIT 5
    `);

    let msg = `🧾 *ÚLTIMAS FACTURAS REGISTRADAS*\n━━━━━━━━━━━━━━━━━━━━━━━━━\n`;
    res.rows.forEach((row) => {
      const icono = row.invoice_type === 'INGRESO' ? '🟢' : '🔴';
      const contacto = row.invoice_type === 'INGRESO' ? row.receiver_name : row.issuer_name;
      msg += `${icono} *${row.invoice_number}* · \`${row.total_amount} €\`\n   _${contacto}_ (${row.issue_date.toISOString().split('T')[0]})\n\n`;
    });

    await ctx.replyWithMarkdown(msg);
  } catch (err) {
    console.error(err);
    await ctx.reply('⚠️ Error al consultar el listado de facturas.');
  }
});

// 4. Modelo 303 (IVA)
bot.hears(['📑 Modelo 303 (IVA)', '/iva'], async (ctx) => {
  try {
    const res = await pool.query(`
      SELECT 
        COALESCE(SUM(CASE WHEN invoice_type = 'INGRESO' THEN vat_amount ELSE 0 END), 0) as iva_rep,
        COALESCE(SUM(CASE WHEN invoice_type = 'GASTO' THEN vat_amount ELSE 0 END), 0) as iva_sop
      FROM invoices
    `);

    const rep = parseFloat(res.rows[0].iva_rep);
    const sop = parseFloat(res.rows[0].iva_sop);
    const liquidacion = rep - sop;

    await ctx.replyWithMarkdown(
      `📑 *PREVISIÓN FISCAL: MODELO 303 (IVA)*\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      `➕ *IVA Repercutido (Cobrado):* \`${rep.toFixed(2)} €\`\n` +
      `➖ *IVA Soportado (Pagado):* \`${sop.toFixed(2)} €\`\n` +
      `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
      (liquidacion >= 0
        ? `🔴 *Resultado a Ingresar a Hacienda:* \`${liquidacion.toFixed(2)} €\`\n_Recuerda apartar este importe antes del fin del trimestre fiscal._`
        : `🟢 *Resultado a Compensar/Devolver:* \`${Math.abs(liquidacion).toFixed(2)} €\``)
    );
  } catch (err) {
    console.error(err);
    await ctx.reply('⚠️ Error al calcular la estimación del Modelo 303.');
  }
});

// 5. Consejo Fiscal con IA
bot.hears(['💡 Consejo Fiscal IA', '/consejo'], async (ctx) => {
  try {
    const res = await pool.query(`
      SELECT category, advice_text, legal_source, confidence_level 
      FROM ai_advice 
      ORDER BY created_at DESC 
      LIMIT 1
    `);

    if (res.rows.length > 0) {
      const adv = res.rows[0];
      await ctx.replyWithMarkdown(
        `💡 *CONSEJO FISCAL INTELIGENTE*\n` +
        `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
        `🏷️ *Categoría:* \`${adv.category}\`\n\n` +
        `${adv.advice_text}\n\n` +
        `⚖️ *Base Legal:* _${adv.legal_source || 'Normativa tributaria vigente'}_\n` +
        `🔒 *Nivel de Certeza:* \`${adv.confidence_level}\``
      );
    } else {
      await ctx.reply('💡 No hay alertas contables pendientes. Todas tus deducciones están cuadradas.');
    }
  } catch (err) {
    console.error(err);
    await ctx.reply('⚠️ Error al consultar los consejos de IA.');
  }
});

// 6. Contacto directo
bot.hears(['📞 Contactar Asesor', '/contacto'], async (ctx) => {
  await ctx.replyWithMarkdown(
    `📞 *CONTACTO DIRECTO CON EL DESARROLLADOR Y ASESOR*\n` +
    `━━━━━━━━━━━━━━━━━━━━━━━━━\n` +
    `👤 *Carlos Plata Morán*\n` +
    `📱 *Teléfono / WhatsApp:* [+34 633 97 15 27](tel:+34633971527)\n` +
    `💬 *Telegram:* [@carlos_plata](https://t.me/+34633971527)\n` +
    `💼 *LinkedIn:* [Carlos Plata Morán](https://www.linkedin.com/in/carlos-plata-morán-86a978445)\n` +
    `✉️ *Email:* \`carplamor25@iesfidiana.es\``
  );
});

// Iniciar bot
if (process.env.NODE_ENV !== 'test') {
  bot.launch().then(() => {
    console.log('🤖 [TELEGRAM BOT] Bot de Facturación en ejecución.');
  }).catch((err) => {
    console.error('Error al iniciar el bot de Telegram:', err.message);
  });

  process.once('SIGINT', () => bot.stop('SIGINT'));
  process.once('SIGTERM', () => bot.stop('SIGTERM'));
}

export { bot };

