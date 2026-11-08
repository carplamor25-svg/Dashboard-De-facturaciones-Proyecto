-- ==============================================================================
-- DASHBOARD DE FACTURACIONES Y NÓMINAS
-- TRIGGERS DE AUDITORÍA AUTOMÁTICA Y SELLADO TEMPORAL INMUTABLE
-- ==============================================================================

-- 1. Función para actualizar automáticamente 'updated_at'
CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

CREATE TRIGGER trg_orgs_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();

-- 2. Función de log inmutable para eliminaciones o modificaciones de facturas
CREATE OR REPLACE FUNCTION audit_invoice_mutations()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_logs (organization_id, user_id, event_type, ip_address, user_agent, details)
        VALUES (
            OLD.organization_id,
            current_app_user_id(),
            'INVOICE_DELETED',
            '127.0.0.1',
            'PostgreSQL Internal Trigger',
            json_build_object(
                'invoice_number', OLD.invoice_number,
                'total_amount', OLD.total_amount,
                'deleted_at', NOW()
            )
        );
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_logs (organization_id, user_id, event_type, ip_address, user_agent, details)
        VALUES (
            NEW.organization_id,
            current_app_user_id(),
            'INVOICE_MODIFIED',
            '127.0.0.1',
            'PostgreSQL Internal Trigger',
            json_build_object(
                'invoice_number', NEW.invoice_number,
                'old_total', OLD.total_amount,
                'new_total', NEW.total_amount,
                'modified_at', NOW()
            )
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_invoices_mutation
    AFTER UPDATE OR DELETE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION audit_invoice_mutations();

