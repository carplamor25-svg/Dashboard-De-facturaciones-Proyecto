-- ==============================================================================
-- DASHBOARD DE FACTURACIONES Y NÓMINAS
-- DATOS SEED DEMO: "Estudio Creativo Vega SL" (CIF B-12345678)
-- Contiene las 16 facturas del kit original (10 ingresos y 6 gastos)
-- ==============================================================================

-- 1. Insertar Planes de Suscripción
INSERT INTO plans (id, name, description, price_eur_month, price_eur_year, max_invoices_month, max_users, delivery_sla_hours, has_payslip_audit, has_telegram_bot, has_api_access)
VALUES
('gratuito', 'Plan Gratuito (Demo)', 'Prueba limitada con borrado automático', 0.00, 0.00, 5, 1, 48, FALSE, FALSE, FALSE),
('basico', 'Plan Básico', 'Hasta 20 facturas/mes, dashboard mensual, entrega < 24h', 50.00, 500.00, 20, 2, 24, TRUE, FALSE, FALSE),
('profesional', 'Plan Profesional', 'Hasta 60 facturas/mes, histórico acumulado, < 12h, soporte prioritario', 80.00, 800.00, 60, 5, 12, TRUE, TRUE, TRUE),
('empresa', 'Instalación On-Premise', 'Servidor propio, manual, 1h formación y soporte dedicado', 200.00, 2000.00, 9999, 20, 1, TRUE, TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 2. Insertar Organización de Demostración
-- Usamos un UUID fijo para el entorno de pruebas
INSERT INTO organizations (id, fiscal_name, trade_name, tax_id_encrypted, tax_id_hash, address, postal_code, city, country, current_plan_id)
VALUES (
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'Estudio Creativo Vega SL',
    'Estudio Vega',
    'ENC_AES256_B12345678_DEMO',
    encode(digest('B-12345678', 'sha256'), 'hex'),
    'Calle Gran Vía 28, Planta 4',
    '28013',
    'Madrid',
    'ES',
    'profesional'
) ON CONFLICT (id) DO NOTHING;

-- 3. Insertar Usuarios (Admin y Cliente Demo)
-- Hash simulado con Argon2id para tests (en producción generado con argon2.hash)
-- Clave de prueba: 'VegaDemo2026!Secure' y 'AdminMaster2026!Secure'
INSERT INTO users (id, organization_id, email, email_verified, password_hash, full_name, is_two_factor_enabled, preferred_language)
VALUES 
(
    'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'empresa@estudiovega.es',
    TRUE,
    '$argon2id$v=19$m=65536,t=3,p=4$dGVzdHNhbHRzZWVkZGVtbw$KqQn8QYq+eCvhLd1tQ7e9oU6e7W6vQz9r5Q1x3y4z8A',
    'Carlos Vega Morán (Gerente Empresa)',
    TRUE,
    'es'
),
(
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'empleado@estudiovega.es',
    TRUE,
    '$argon2id$v=19$m=65536,t=3,p=4$ZW1wbGVhZG9zYWx0ZGVtbw$MpQn9QYq+eCvhLd1tQ7e9oU6e7W6vQz9r5Q1x3y4z8B',
    'Laura Gómez Sanz (Empleado - Vista Consulta)',
    FALSE,
    'es'
),
(
    'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33',
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'admin@dashboardfacturas.es',
    TRUE,
    '$argon2id$v=19$m=65536,t=3,p=4$YWRtaW5zYWx0c2VlZGRlbW8$JqPn7PXp+dCuhKd0sP6d8nT5d6V5uPy8q4P0w2x3y7Z',
    'Administrador del Sistema (SuperAdmin)',
    TRUE,
    'es'
) ON CONFLICT (id) DO NOTHING;

-- Asignar Roles
INSERT INTO user_roles (user_id, role) VALUES 
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22', 'company_admin'),
('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380d44', 'employee'),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380c33', 'admin')
ON CONFLICT (user_id, role) DO NOTHING;

-- 4. Insertar las 10 Facturas de Ingresos del Kit
INSERT INTO invoices (
    organization_id, invoice_type, invoice_number, issue_date, due_date,
    issuer_name, issuer_tax_id, receiver_name, receiver_tax_id,
    tax_base, vat_rate, vat_amount, irpf_rate, irpf_amount, total_amount,
    ai_confidence_score, ai_model_used
) VALUES
-- 1
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2025-018', '2025-10-12', '2025-11-12',
 'Estudio Creativo Vega SL', 'B-12345678', 'Restaurante La Mesa SL', 'B-87654321',
 1800.00, 21.00, 378.00, 15.00, 270.00, 1908.00, 99.50, 'gemma2:9b-local'),
-- 2
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2025-019', '2025-10-28', '2025-11-28',
 'Estudio Creativo Vega SL', 'B-12345678', 'Tech Startup Innova SL', 'B-99887766',
 3500.00, 21.00, 735.00, 15.00, 525.00, 3710.00, 98.80, 'gemma2:9b-local'),
-- 3
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2025-020', '2025-11-15', '2025-12-15',
 'Estudio Creativo Vega SL', 'B-12345678', 'Boutique Mariposa SL', 'B-11223344',
 1200.00, 21.00, 252.00, 15.00, 180.00, 1272.00, 99.10, 'gemma2:9b-local'),
-- 4
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2025-021', '2025-11-30', '2025-12-30',
 'Estudio Creativo Vega SL', 'B-12345678', 'Hotel Costa Blanca SA', 'A-55443322',
 4200.00, 21.00, 882.00, 15.00, 630.00, 4452.00, 99.40, 'gemma2:9b-local'),
-- 5
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2025-022', '2025-12-18', '2026-01-18',
 'Estudio Creativo Vega SL', 'B-12345678', 'Tech Startup Innova SL', 'B-99887766',
 950.00, 21.00, 199.50, 15.00, 142.50, 1007.00, 97.90, 'gemma2:9b-local'),
-- 6
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2026-001', '2026-01-14', '2026-02-14',
 'Estudio Creativo Vega SL', 'B-12345678', 'Centro Médico Salud+ SL', 'B-44332211',
 2400.00, 21.00, 504.00, 15.00, 360.00, 2544.00, 99.20, 'gemma2:9b-local'),
-- 7
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2026-002', '2026-01-29', '2026-02-28',
 'Estudio Creativo Vega SL', 'B-12345678', 'Restaurante La Mesa SL', 'B-87654321',
 600.00, 21.00, 126.00, 15.00, 90.00, 636.00, 98.70, 'gemma2:9b-local'),
-- 8
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2026-003', '2026-02-12', '2026-03-12',
 'Estudio Creativo Vega SL', 'B-12345678', 'Hotel Costa Blanca SA', 'A-55443322',
 2800.00, 21.00, 588.00, 15.00, 420.00, 2968.00, 99.00, 'gemma2:9b-local'),
-- 9
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2026-004', '2026-02-27', '2026-03-27',
 'Estudio Creativo Vega SL', 'B-12345678', 'Tech Startup Innova SL', 'B-99887766',
 3800.00, 21.00, 798.00, 15.00, 570.00, 4028.00, 99.60, 'gemma2:9b-local'),
-- 10
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'INGRESO', 'F-2026-005', '2026-03-20', '2026-04-20',
 'Estudio Creativo Vega SL', 'B-12345678', 'Boutique Mariposa SL', 'B-11223344',
 5500.00, 21.00, 1155.00, 15.00, 825.00, 5830.00, 99.80, 'gemma2:9b-local')
ON CONFLICT DO NOTHING;

-- 5. Insertar las 6 Facturas de Gastos del Kit
INSERT INTO invoices (
    organization_id, invoice_type, invoice_number, issue_date, due_date,
    issuer_name, issuer_tax_id, receiver_name, receiver_tax_id,
    tax_base, vat_rate, vat_amount, irpf_rate, irpf_amount, total_amount,
    ai_confidence_score, ai_model_used
) VALUES
-- 1
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'ADBE-25-10', '2025-10-01', '2025-10-01',
 'Adobe Systems Software Ireland Ltd', 'IE-987654321', 'Estudio Creativo Vega SL', 'B-12345678',
 59.99, 21.00, 12.60, 0.00, 0.00, 72.59, 99.90, 'gemma2:9b-local'),
-- 2
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'TEF-25-11', '2025-11-05', '2025-11-05',
 'Telefónica de España SAU', 'A-28015865', 'Estudio Creativo Vega SL', 'B-12345678',
 49.95, 21.00, 10.49, 0.00, 0.00, 60.44, 99.50, 'gemma2:9b-local'),
-- 3
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'IBE-25-12', '2025-12-10', '2025-12-10',
 'Iberdrola Clientes SAU', 'A-95748372', 'Estudio Creativo Vega SL', 'B-12345678',
 145.30, 21.00, 30.51, 0.00, 0.00, 175.81, 98.40, 'gemma2:9b-local'),
-- 4
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'HUB-26-01', '2026-01-15', '2026-01-15',
 'Impact Hub Madrid SL', 'B-86420975', 'Estudio Creativo Vega SL', 'B-12345678',
 250.00, 21.00, 52.50, 0.00, 0.00, 302.50, 99.70, 'gemma2:9b-local'),
-- 5
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'GOO-26-02', '2026-02-08', '2026-02-08',
 'Google Cloud EMEA Limited', 'IE-6388047V', 'Estudio Creativo Vega SL', 'B-12345678',
 23.40, 21.00, 4.91, 0.00, 0.00, 28.31, 99.80, 'gemma2:9b-local'),
-- 6
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'GASTO', 'ADBE-26-03', '2026-03-01', '2026-03-01',
 'Adobe Systems Software Ireland Ltd', 'IE-987654321', 'Estudio Creativo Vega SL', 'B-12345678',
 59.99, 21.00, 12.60, 0.00, 0.00, 72.59, 99.90, 'gemma2:9b-local')
ON CONFLICT DO NOTHING;

-- 6. Insertar Consejos de IA Demostrativos
INSERT INTO ai_advice (organization_id, category, advice_text, legal_source, confidence_level)
VALUES 
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'DEDUCCION_IVA',
    'Tienes deducciones de suministros (luz e internet) en oficina mixta. Conforme a la resolución vinculante DGT V1234-21, asegúrate de aplicar el porcentaje de afectación a la actividad (30% sobre el metro cuadrado afecto).',
    'Ley 37/1992 del IVA (Art. 95) y DGT V1234-21',
    'ALTO'
),
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'IRPF_OPTIMIZACION',
    'Las retenciones soportadas del 15% sobre ingresos suman 4.012,50 €. Podrás deducirlas íntegramente en tu declaración anual del Impuesto sobre Sociedades (Modelo 200) o pago fraccionado (Modelo 202).',
    'Ley 27/2014 del Impuesto sobre Sociedades (Art. 128)',
    'ALTO'
),
(
    'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'ALERTAS_FLUJO_CAJA',
    'Tu cliente "Tech Startup Innova SL" representa el 30,8% de tus ingresos totales (8.250 €). Se recomienda diversificar para reducir la concentración de riesgo de crédito comercial.',
    'Principio Contable de Prudencia y Gestión de Riesgo Financiero',
    'MEDIO'
);

