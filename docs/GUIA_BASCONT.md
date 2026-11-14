# Guía Técnica: Módulo BasCont · Gestor de Base de Datos y Usuarios
**Proyecto:** Dashboard de Facturaciones v2.0 PRO · 2º DAW  
**Autor:** Carlos Plata Morán (`carplamor25@iesfidiana.es` | Tel: `+34 633 97 15 27`)  
**URL de Acceso:** [https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/bascont/](https://carplamor25-svg.github.io/Dashboard-De-facturaciones-Proyecto/bascont/)  
**Licencia de Acceso:** Exclusivo para **SuperAdmin (Carlos)** y **Empresas con Plan Profesional o Instalación Única**.

---

## 1. Finalidad y Alcance de `BasCont`

`BasCont` es el módulo avanzado de administración de bases de datos multi-inquilino (multi-tenant) que permite a las empresas con **Plan Pro** y al **SuperAdmin** gestionar directamente:
1. **Usuarios de Base de Datos:** Alta, baja, asignación de contraseñas y permisos granulares por tabla (Facturas, Impuestos, Nóminas, Auditoría).
2. **Esquema y Campos Dinámicos (ALTER TABLE):** Extensión del esquema de base de datos añadiendo columnas personalizadas (ej. centro de coste, número de pedido, retención especial) sin alterar la lógica central.
3. **Conexión Externa con API Key:** Preparación para enlazar la base local con clústeres remotos PostgreSQL en la nube (Supabase, Neon, AWS RDS o REST APIs seguras).
4. **Ciberseguridad OWASP Top 10:** Aislamiento total de inquilinos con Row-Level Security (RLS) y parametrización de consultas contra inyecciones SQL.

---

## 2. Matriz de Acceso por Plan y Rol

| Usuario | Plan / Nivel | Permisos en `BasCont` |
| :--- | :--- | :--- |
| **Carlos Plata Morán** (`carplamor25@iesfidiana.es`) | **SuperAdmin Supremo** | **Control Total Ilimitado:** Puede ver, editar y administrar cualquier base de datos de cualquier empresa registrada. |
| **Estudio Creativo Vega SL** (`empresa@estudiovega.es`) | **Plan Pro / Instalación Única** | **Administrador de su Base de Datos:** Gestión exclusiva de los usuarios y campos de su propia empresa (aislado por RLS). |
| **Usuarios Estándar / Empleados** | **Plan Básico o Sin Plan Pro** | **Acceso Denegado:** El sistema bloquea el acceso mostrando el requerimiento de licencia Pro. |

---

## 3. Ciberseguridad OWASP Top 10 Implementada

1. **A01: Broken Access Control:** Mitigado mediante PostgreSQL Row-Level Security (`app.current_org_id = org_id`). Ninguna empresa puede consultar registros ajenos.
2. **A02: Cryptographic Failures:** Contraseñas hasheadas con **Argon2id** (memory cost 64MB, time cost 3). Tráfico cifrado mediante TLS 1.3 forzado.
3. **A03: Injection:** Sentencias SQL 100% preparadas (`prepared statements`) con parámetros indexados (`$1`, `$2`), eliminando cualquier vector de SQLi.
4. **A09: Security Logging:** Cada cambio en usuarios o columnas genera un registro de auditoría inmutable con IP, usuario y marca temporal ISO 8601.
