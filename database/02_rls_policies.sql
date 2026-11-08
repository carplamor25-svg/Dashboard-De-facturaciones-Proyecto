-- ==============================================================================
-- DASHBOARD DE FACTURACIONES Y NÓMINAS
-- POLÍTICAS DE ROW-LEVEL SECURITY (RLS) EN POSTGRESQL 16
-- Aislamiento Estricto Multitenant por Organización y Bypass Seguro para Admin
-- ==============================================================================

-- 1. Habilitar RLS en todas las tablas sensibles
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE payslips ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_advice ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_deletions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- 2. Funciones de sesión seguras (inmutables y ejecutadas en contexto del servidor)

-- Obtener el ID de la organización actual fijado en la sesión de la base de datos
CREATE OR REPLACE FUNCTION current_app_org_id() 
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_org_id', true), '')::UUID;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Obtener el ID del usuario actual fijado en la sesión
CREATE OR REPLACE FUNCTION current_app_user_id() 
RETURNS UUID AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_user_id', true), '')::UUID;
EXCEPTION
    WHEN OTHERS THEN RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Comprobar si el usuario actual ostenta el rol de administrador
CREATE OR REPLACE FUNCTION is_app_admin() 
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_is_admin BOOLEAN;
BEGIN
    v_user_id := current_app_user_id();
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = v_user_id AND role = 'admin'
    ) INTO v_is_admin;
    
    RETURN COALESCE(v_is_admin, FALSE);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 3. Políticas RLS para Organizaciones
-- ------------------------------------------------------------------------------
CREATE POLICY org_tenant_isolation_policy ON organizations
    FOR ALL
    USING (id = current_app_org_id() OR is_app_admin())
    WITH CHECK (id = current_app_org_id() OR is_app_admin());

-- ------------------------------------------------------------------------------
-- 4. Políticas RLS para Usuarios
-- ------------------------------------------------------------------------------
CREATE POLICY users_tenant_isolation_policy ON users
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (organization_id = current_app_org_id() OR is_app_admin());

-- ------------------------------------------------------------------------------
-- 5. Políticas RLS para Facturas y Líneas con Segregación de Roles (Empleado vs Empresa)
-- ------------------------------------------------------------------------------
-- Empleados: Solo LECTURA (SELECT). Empresa (company_admin) y Admin: LECTURA, INSERCIÓN y MODIFICACIÓN (ALL).
CREATE OR REPLACE FUNCTION can_manage_invoices()
RETURNS BOOLEAN AS $$
DECLARE
    v_user_id UUID;
    v_can_manage BOOLEAN;
BEGIN
    v_user_id := current_app_user_id();
    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    SELECT EXISTS (
        SELECT 1 FROM user_roles 
        WHERE user_id = v_user_id AND role IN ('company_admin', 'admin')
    ) INTO v_can_manage;
    
    RETURN COALESCE(v_can_manage, FALSE);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Consulta permitida para todos los miembros de la organización (incluidos empleados con vista consulta)
CREATE POLICY invoices_tenant_select_policy ON invoices
    FOR SELECT
    USING (organization_id = current_app_org_id() OR is_app_admin());

-- Modificación / Inserción permitida SOLO para Empresa (company_admin) y Administrador de plataforma
CREATE POLICY invoices_tenant_insert_policy ON invoices
    FOR INSERT
    WITH CHECK ((organization_id = current_app_org_id() AND can_manage_invoices()) OR is_app_admin());

CREATE POLICY invoices_tenant_update_policy ON invoices
    FOR UPDATE
    USING ((organization_id = current_app_org_id() AND can_manage_invoices()) OR is_app_admin())
    WITH CHECK ((organization_id = current_app_org_id() AND can_manage_invoices()) OR is_app_admin());

CREATE POLICY invoices_tenant_delete_policy ON invoices
    FOR DELETE
    USING ((organization_id = current_app_org_id() AND can_manage_invoices()) OR is_app_admin());

-- Líneas de Factura
CREATE POLICY invoice_lines_tenant_select_policy ON invoice_lines
    FOR SELECT
    USING (
        invoice_id IN (
            SELECT id FROM invoices 
            WHERE organization_id = current_app_org_id()
        ) OR is_app_admin()
    );

CREATE POLICY invoice_lines_tenant_write_policy ON invoice_lines
    FOR ALL
    USING (
        (invoice_id IN (SELECT id FROM invoices WHERE organization_id = current_app_org_id()) AND can_manage_invoices())
        OR is_app_admin()
    )
    WITH CHECK (
        (invoice_id IN (SELECT id FROM invoices WHERE organization_id = current_app_org_id()) AND can_manage_invoices())
        OR is_app_admin()
    );

-- ------------------------------------------------------------------------------
-- 6. Políticas RLS para Subidas Temporales
-- ------------------------------------------------------------------------------
CREATE POLICY uploads_tenant_isolation_policy ON uploads
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (organization_id = current_app_org_id() OR is_app_admin());

-- ------------------------------------------------------------------------------
-- 7. Políticas RLS para Nóminas y Consejos de IA
-- ------------------------------------------------------------------------------
CREATE POLICY payslips_tenant_isolation_policy ON payslips
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (organization_id = current_app_org_id() OR is_app_admin());

CREATE POLICY ai_advice_tenant_isolation_policy ON ai_advice
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (organization_id = current_app_org_id() OR is_app_admin());

-- ------------------------------------------------------------------------------
-- 8. Políticas RLS para Informes y Registro de Borrado
-- ------------------------------------------------------------------------------
CREATE POLICY reports_tenant_isolation_policy ON reports
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (organization_id = current_app_org_id() OR is_app_admin());

CREATE POLICY audit_deletions_tenant_isolation_policy ON audit_deletions
    FOR ALL
    USING (organization_id = current_app_org_id() OR is_app_admin())
    WITH CHECK (is_app_admin()); -- Solo el sistema/admin puede certificar borrados

-- ------------------------------------------------------------------------------
-- 9. Políticas RLS para Logs de Auditoría
-- ------------------------------------------------------------------------------
-- El usuario solo puede consultar sus propios logs de actividad reciente; el admin ve todo
CREATE POLICY audit_logs_isolation_policy ON audit_logs
    FOR SELECT
    USING (user_id = current_app_user_id() OR is_app_admin());

CREATE POLICY audit_logs_insert_policy ON audit_logs
    FOR INSERT
    WITH CHECK (TRUE); -- Permitir inserción desde el middleware de auditoría

