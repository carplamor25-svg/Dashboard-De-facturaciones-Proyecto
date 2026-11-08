-- ==============================================================================
-- DASHBOARD DE FACTURACIONES Y NÓMINAS
-- SCRIPT DDL: CREACIÓN DE BASE DE DATOS Y TABLAS (PostgreSQL 16)
-- Arquitectura Multitenant con Integridad Referencial y Tipos Monetarios Exactos
-- ==============================================================================

-- 1. Extensiones requeridas
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Enumerados para estados y tipos
CREATE TYPE role_type AS ENUM ('user', 'employee', 'company_admin', 'admin', 'auditor');
CREATE TYPE subscription_status AS ENUM ('trialing', 'active', 'past_due', 'canceled', 'unpaid');
CREATE TYPE upload_status AS ENUM ('SUBIDO', 'EN_COLA', 'PROCESANDO_IA', 'AUDITADO_FISCAL', 'GENERADO', 'DESTRUIDO_SEGURO', 'ERROR');
CREATE TYPE invoice_type AS ENUM ('INGRESO', 'GASTO');
CREATE TYPE job_status AS ENUM ('PENDIENTE', 'EN_CURSO', 'COMPLETADO', 'FALLIDO');
CREATE TYPE arco_request_type AS ENUM ('ACCESO', 'RECTIFICACION', 'SUPRESION', 'PORTABILIDAD', 'OPOSICION');
CREATE TYPE arco_status AS ENUM ('RECIBIDA', 'EN_TRAMITE', 'COMPLETADA', 'RECHAZADA');

-- ------------------------------------------------------------------------------
-- 3. Tabla de Planes de Suscripción
-- ------------------------------------------------------------------------------
CREATE TABLE plans (
    id VARCHAR(50) PRIMARY KEY, -- 'gratuito', 'basico', 'profesional', 'empresa'
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price_eur_month NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    price_eur_year NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    max_invoices_month INTEGER NOT NULL DEFAULT 10,
    max_users INTEGER NOT NULL DEFAULT 1,
    delivery_sla_hours INTEGER NOT NULL DEFAULT 24,
    has_payslip_audit BOOLEAN NOT NULL DEFAULT FALSE,
    has_telegram_bot BOOLEAN NOT NULL DEFAULT FALSE,
    has_api_access BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 4. Tabla de Organizaciones (Empresas o Autónomos clientes)
-- ------------------------------------------------------------------------------
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fiscal_name VARCHAR(255) NOT NULL,
    trade_name VARCHAR(255),
    tax_id_encrypted TEXT NOT NULL, -- NIF/CIF cifrado con AES-256
    tax_id_hash VARCHAR(64) NOT NULL, -- SHA-256 para búsquedas deterministas
    address TEXT,
    postal_code VARCHAR(10),
    city VARCHAR(100),
    country VARCHAR(2) NOT NULL DEFAULT 'ES',
    current_plan_id VARCHAR(50) NOT NULL REFERENCES plans(id) DEFAULT 'gratuito',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orgs_tax_id_hash ON organizations(tax_id_hash);

-- ------------------------------------------------------------------------------
-- 5. Tabla de Usuarios y Perfiles
-- ------------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    email_verification_token VARCHAR(128),
    email_verification_expires TIMESTAMPTZ,
    password_hash VARCHAR(255) NOT NULL, -- Argon2id
    full_name VARCHAR(150) NOT NULL,
    phone_encrypted TEXT,
    totp_secret_encrypted TEXT, -- Clave secreta TOTP en Base32 cifrada
    is_two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    recovery_codes_hashes TEXT[], -- Hashes SHA-256 de 8 códigos de recuperación
    webauthn_credentials JSONB, -- Credenciales Passkeys (opcional)
    preferred_language VARCHAR(5) NOT NULL DEFAULT 'es', -- 'es' o 'en'
    password_reset_token VARCHAR(128),
    password_reset_expires TIMESTAMPTZ,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    lockout_until TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_org ON users(organization_id);
CREATE INDEX idx_users_email ON users(email);

-- ------------------------------------------------------------------------------
-- 6. Tabla de Asignación de Roles (RBAC en Servidor)
-- ------------------------------------------------------------------------------
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role role_type NOT NULL DEFAULT 'user',
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, role)
);

CREATE INDEX idx_user_roles_lookup ON user_roles(user_id, role);

-- ------------------------------------------------------------------------------
-- 7. Suscripciones y Pagos (Stripe / Pasarela delegada)
-- ------------------------------------------------------------------------------
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id VARCHAR(50) NOT NULL REFERENCES plans(id),
    status subscription_status NOT NULL DEFAULT 'active',
    external_subscription_id VARCHAR(100), -- ID de Stripe
    current_period_start TIMESTAMPTZ NOT NULL,
    current_period_end TIMESTAMPTZ NOT NULL,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    amount_eur NUMERIC(10,2) NOT NULL CHECK (amount_eur >= 0),
    status VARCHAR(50) NOT NULL, -- 'succeeded', 'failed', 'pending'
    payment_method VARCHAR(50) NOT NULL, -- 'card', 'sepa_debit'
    invoice_number VARCHAR(100),
    external_payment_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 8. Subidas de Archivos Temporales (Política de Borrado Seguro)
-- ------------------------------------------------------------------------------
CREATE TABLE uploads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    uploaded_by UUID NOT NULL REFERENCES users(id),
    original_filename VARCHAR(255) NOT NULL,
    file_type_declared VARCHAR(100) NOT NULL,
    file_type_detected VARCHAR(100) NOT NULL, -- Validación de magic bytes
    file_size_bytes BIGINT NOT NULL CHECK (file_size_bytes > 0 AND file_size_bytes <= 25000000), -- Máx 25 MB
    storage_temp_path TEXT NOT NULL, -- Ruta efímera en tmpfs
    file_sha256 VARCHAR(64) NOT NULL, -- Hash de integridad
    status upload_status NOT NULL DEFAULT 'SUBIDO',
    shredded_at TIMESTAMPTZ, -- Marca de tiempo de destrucción física
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
);

CREATE INDEX idx_uploads_org_status ON uploads(organization_id, status);

-- ------------------------------------------------------------------------------
-- 9. Facturas Procesadas (Datos Normalizados Extraídos por IA)
-- ------------------------------------------------------------------------------
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    upload_id UUID REFERENCES uploads(id) ON DELETE SET NULL,
    invoice_type invoice_type NOT NULL, -- INGRESO o GASTO
    invoice_number VARCHAR(100) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    
    -- Datos del Emisor
    issuer_name VARCHAR(255) NOT NULL,
    issuer_tax_id VARCHAR(50) NOT NULL,
    
    -- Datos del Receptor
    receiver_name VARCHAR(255) NOT NULL,
    receiver_tax_id VARCHAR(50) NOT NULL,
    
    -- Importes Fiscales (Precisión exacta a 2 decimales)
    tax_base NUMERIC(12,2) NOT NULL CHECK (tax_base >= 0),
    vat_rate NUMERIC(5,2) NOT NULL CHECK (vat_rate IN (0.00, 4.00, 10.00, 21.00)),
    vat_amount NUMERIC(12,2) NOT NULL CHECK (vat_amount >= 0),
    irpf_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (irpf_rate IN (0.00, 7.00, 15.00, 19.00)),
    irpf_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (irpf_amount >= 0),
    total_amount NUMERIC(12,2) NOT NULL CHECK (total_amount >= 0),
    
    -- Validación de Cuadre Aritmético: Total = Base + IVA - IRPF (tolerancia de 2 céntimos por redondeo)
    is_arithmetically_valid BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Metadatos de Confianza de la Extracción por IA
    ai_confidence_score NUMERIC(5,2) NOT NULL DEFAULT 100.00 CHECK (ai_confidence_score BETWEEN 0 AND 100),
    ai_model_used VARCHAR(100) NOT NULL,
    requires_manual_review BOOLEAN NOT NULL DEFAULT FALSE,
    manual_reviewed_by UUID REFERENCES users(id),
    manual_reviewed_at TIMESTAMPTZ,
    
    raw_extraction_data JSONB, -- Backup del JSON extraído por el worker
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Restricción de unicidad para evitar facturas duplicadas
    CONSTRAINT uq_org_invoice UNIQUE (organization_id, issuer_tax_id, invoice_number, issue_date)
);

CREATE INDEX idx_invoices_org_date ON invoices(organization_id, issue_date);
CREATE INDEX idx_invoices_org_type ON invoices(organization_id, invoice_type);

-- ------------------------------------------------------------------------------
-- 10. Líneas de Detalle de Factura
-- ------------------------------------------------------------------------------
CREATE TABLE invoice_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,
    concept TEXT NOT NULL,
    quantity NUMERIC(10,3) NOT NULL DEFAULT 1.000,
    unit_price NUMERIC(12,2) NOT NULL,
    discount_percentage NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    line_tax_base NUMERIC(12,2) NOT NULL,
    vat_rate NUMERIC(5,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_lines_invoice ON invoice_lines(invoice_id);

-- ------------------------------------------------------------------------------
-- 11. Nóminas y Auditoría de Retenciones / Seguridad Social
-- ------------------------------------------------------------------------------
CREATE TABLE payslips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    upload_id UUID REFERENCES uploads(id) ON DELETE SET NULL,
    worker_name VARCHAR(255) NOT NULL,
    worker_nif_encrypted TEXT NOT NULL,
    period_month INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year INTEGER NOT NULL CHECK (period_year >= 2000),
    
    gross_salary NUMERIC(12,2) NOT NULL CHECK (gross_salary >= 0),
    ss_worker_deduction NUMERIC(12,2) NOT NULL CHECK (ss_worker_deduction >= 0),
    ss_company_cost NUMERIC(12,2) NOT NULL CHECK (ss_company_cost >= 0),
    irpf_rate NUMERIC(5,2) NOT NULL CHECK (irpf_rate >= 0),
    irpf_withheld NUMERIC(12,2) NOT NULL CHECK (irpf_withheld >= 0),
    net_salary NUMERIC(12,2) NOT NULL CHECK (net_salary >= 0),
    
    has_anomalies BOOLEAN NOT NULL DEFAULT FALSE,
    anomaly_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 12. Informes Generados, URLs Firmadas y Caducidad
-- ------------------------------------------------------------------------------
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    metrics_summary JSONB NOT NULL, -- Métricas consolidadas: total ingresos, gastos, modelos 303/111
    pdf_storage_path TEXT,
    signed_url_token VARCHAR(128) UNIQUE NOT NULL, -- Token HMAC
    signed_url_password_hash VARCHAR(255), -- Protección opcional con clave
    expires_at TIMESTAMPTZ NOT NULL,
    access_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_token ON reports(signed_url_token);

-- ------------------------------------------------------------------------------
-- 13. Consejos de IA y Auditoría de Fugas
-- ------------------------------------------------------------------------------
CREATE TABLE ai_advice (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL, -- 'DEDUCCION_IVA', 'IRPF_OPTIMIZACION', 'ALERTAS_FLUJO_CAJA'
    advice_text TEXT NOT NULL,
    legal_source TEXT, -- Referencia a la LIVA, LIRPF o resoluciones DGT
    confidence_level VARCHAR(20) NOT NULL DEFAULT 'ALTO', -- 'ALTO', 'MEDIO', 'ORIENTATIVO'
    dismissed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 14. Logs de Auditoría Inmutables (OWASP / ENS / RGPD)
-- ------------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    event_type VARCHAR(100) NOT NULL, -- 'LOGIN_SUCCESS', 'LOGIN_FAILED', '2FA_CHALLENGE', 'UPLOAD', 'SHRED'
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT NOT NULL,
    country_code VARCHAR(5),
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX idx_audit_user ON audit_logs(user_id);

-- ------------------------------------------------------------------------------
-- 15. Registro de Destrucción Criptográfica (Prueba de no persistencia)
-- ------------------------------------------------------------------------------
CREATE TABLE audit_deletions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    original_file_sha256 VARCHAR(64) NOT NULL,
    shred_method VARCHAR(100) NOT NULL DEFAULT 'DOD_5220_22_M_3_PASS',
    shredded_bytes BIGINT NOT NULL,
    shredded_by_cron BOOLEAN NOT NULL DEFAULT TRUE,
    timestamp_destroyed TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 16. Consentimientos RGPD y Ejercicio de Derechos ARCO
-- ------------------------------------------------------------------------------
CREATE TABLE consents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type VARCHAR(100) NOT NULL, -- 'PRIVACY_POLICY', 'DATA_PROCESSING_AGREEMENT', 'LOCAL_AI_PROCESSING'
    version VARCHAR(20) NOT NULL,
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address VARCHAR(45) NOT NULL
);

CREATE TABLE data_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_type arco_request_type NOT NULL,
    status arco_status NOT NULL DEFAULT 'RECIBIDA',
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 17. Colas de Trabajo y Notificaciones
-- ------------------------------------------------------------------------------
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    queue_name VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    status job_status NOT NULL DEFAULT 'PENDIENTE',
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    channel VARCHAR(50) NOT NULL, -- 'EMAIL', 'TELEGRAM', 'IN_APP'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 18. Claves de API Hash (Para futuras integraciones y n8n)
-- ------------------------------------------------------------------------------
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    key_prefix VARCHAR(16) NOT NULL,
    key_hash VARCHAR(64) NOT NULL, -- SHA-256 (nunca en claro)
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

