---
name: login-auth-gfp
description: Implementa login, registro, recuperación de contraseña, roles (Admin/Editor/Visualizador), administración de usuarios, protección de rutas y RLS con Supabase Auth en una app web existente de Grupo Frío Packing. Usar cuando un proyecto con Supabase no tiene login, roles o control de acceso, o cuando se pida "agregar autenticación", "login", "usuarios y roles" o "RLS".
---

# Supabase Secure Auth & User Management (Grupo Frío Packing)

Este skill agrega a un proyecto web con Supabase un módulo completo de autenticación,
autorización y administración de usuarios, respetando la arquitectura existente.

Los requisitos completos y no negociables están en `references/requisitos.md`.
Léelo antes de empezar. Este archivo define **el orden de trabajo**.

## Reglas que nunca se rompen

1. La identidad, contraseñas, sesiones y tokens los maneja **solo Supabase Auth**.
   Nada de JWT propios, hashes, `password`, `access_token` ni `refresh_token` en tablas propias.
2. La seguridad real está en **RLS**. Ocultar botones es solo UX.
3. La `SUPABASE_SERVICE_ROLE_KEY` **jamás** llega al navegador (ni en `VITE_*`, `NEXT_PUBLIC_*`,
   `NUXT_PUBLIC_*`, `PUBLIC_*`, HTML, logs ni repositorio). Solo vive en servidor / Edge Functions.
4. No se borran ni se reemplazan funcionalidades existentes. Se integra.
5. Nunca se asigna Admin automáticamente. Todo usuario nuevo es **Visualizador**.
6. Sin emojis en la interfaz. Iconos: la librería que ya use el proyecto; si no hay, Lucide.

## Flujo de trabajo

### Paso 1 — Analizar el proyecto (no modificar nada todavía)

Detectar y anotar:

- Framework y versión (React/Vite, Next.js App o Pages Router, Vue/Nuxt, Angular, SvelteKit, HTML+JS plano).
- Routing, sistema de estilos (Tailwind, CSS Modules, SCSS, UI kit), librería de iconos.
- Cliente Supabase existente (`createClient`), dónde se instancia y cómo lee la URL/anon key.
- Sistema de variables de entorno y su prefijo público (`VITE_`, `NEXT_PUBLIC_`, etc.).
- Carpeta `supabase/migrations` existente y la numeración que usa.
- Tablas de negocio existentes (las que recibirán políticas CRUD estándar).

Ejecutar el escaneo de secretos **antes** de tocar código:

```bash
bash <ruta-del-skill>/scripts/scan_secrets.sh .
```

Si aparece una service role key o cualquier credencial real en código de frontend:
**detener**, informar al desarrollador, moverla a variable de entorno de servidor y
recomendar rotarla en Supabase (Project Settings → API) porque pudo quedar expuesta.

### Paso 1b — Conexión a Supabase (URL y clave pública)

Verificar si el proyecto **ya tiene** la URL del proyecto y la clave pública (anon / publishable):

```bash
bash <ruta-del-skill>/scripts/check_supabase_config.sh .
```

El script revisa `.env*`, `src/environments/*.ts` (Angular) y valores escritos en el código,
y termina con `STATUS_URL`, `STATUS_KEY`, `ENV_FILE`, `URL_VAR`, `KEY_VAR`. Actuar según el resultado:

| Resultado | Qué hacer |
|---|---|
| `STATUS_URL=ok` y `STATUS_KEY=ok` | **No pedir nada.** Reutilizar las variables existentes (`URL_VAR`, `KEY_VAR`) con sus nombres actuales. |
| `missing` o `invalid` en alguna | **Pedir al desarrollador solo lo que falta** (ver mensaje abajo). |
| `hardcoded` | No pedir nada: tomar el valor del código, moverlo a `ENV_FILE` con el prefijo del framework y reemplazarlo en el código por la variable. Avisar al desarrollador. |
| `STATUS_KEY=service_role` | **Detener.** La clave que usa el frontend es la service role. Informar, pedir la clave anon/publishable correcta, mover la service role fuera del frontend y recomendar rotarla. |

Mensaje para pedir los datos (incluir solo lo que falte):

> Para conectar el login necesito dos datos de tu proyecto de Supabase.
> Los encuentras en el dashboard de Supabase → tu proyecto → **Project Settings → API** (o "Data API" / "API Keys"):
> 1. **Project URL** — se ve como `https://xxxxxxxxxxxxxxxxxxxx.supabase.co`
> 2. **Clave pública** — `anon public` (empieza con `eyJ...`) o `publishable` (empieza con `sb_publishable_...`)
>
> No me pases la `service_role` ni la `secret` key: no hacen falta para esto.

Cuando el desarrollador responda:

1. Validar el formato: URL `https://<20 caracteres>.supabase.co` (o dominio propio / `localhost` en local);
   clave `eyJ...` con rol `anon` o `sb_publishable_...`. Si pega una service role o `sb_secret_`,
   **no usarla**, explicarle que es secreta, pedirle la pública y recomendar rotar la que compartió.
2. Escribir los valores en `ENV_FILE` con el prefijo público del framework detectado:

   | Framework | Archivo | Variables |
   |---|---|---|
   | Vite (React/Vue/Svelte) | `.env.local` | `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY` |
   | Next.js | `.env.local` | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` |
   | Nuxt | `.env` | `NUXT_PUBLIC_SUPABASE_URL`, `NUXT_PUBLIC_SUPABASE_KEY` |
   | SvelteKit | `.env` | `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY` |
   | Create React App | `.env.local` | `REACT_APP_SUPABASE_URL`, `REACT_APP_SUPABASE_ANON_KEY` |
   | Angular | `src/environments/environment*.ts` | `supabaseUrl`, `supabaseKey` |
   | HTML + JS plano | `config.js` (en `.gitignore`) + `config.example.js` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` |

   Si el proyecto ya usa otros nombres de variable, respetarlos. Si usa clave `sb_publishable_`,
   se puede nombrar `..._PUBLISHABLE_KEY`; lo importante es ser consistente con el cliente.
3. Crear/actualizar `.env.example` con los mismos nombres **sin valores**.
4. Confirmar que el archivo con valores está en `.gitignore` (Paso 5).
5. Volver a ejecutar `check_supabase_config.sh` y continuar solo con `STATUS_URL=ok` y `STATUS_KEY=ok`.

Nunca pedir la service role key. La Edge Function `admin-users` la recibe automáticamente de Supabase.
Si el proyecto tiene backend propio que la necesita, el desarrollador la configura él mismo en las
variables del servidor; el skill solo deja el nombre `SUPABASE_SERVICE_ROLE_KEY=` vacío en `.env.example`.

Si el proyecto no tiene la carpeta `supabase/` ni la CLI vinculada, preguntar también si aplicarán
las migraciones con la CLI (`supabase link --project-ref <ref>` + `supabase db push`) o pegándolas
en el SQL Editor. El *project ref* son los 20 caracteres de la URL; no hace falta pedirlo aparte.

Presentar al desarrollador un resumen breve de lo detectado y el plan de archivos a crear/modificar.

### Paso 2 — Base de datos (migraciones)

Copiar `assets/migrations/*.sql` a `supabase/migrations/` del proyecto.
- Si el proyecto ya tiene migraciones con timestamp (`20250101120000_x.sql`), renombrar con
  timestamps nuevos conservando el orden 001 → 007.
- Si ya existe una tabla `public.users` o `profiles`, **no la reemplaces**: adapta las
  migraciones (agrega columnas faltantes, conserva datos) y avisa al desarrollador.

| Archivo | Contenido |
|---|---|
| `001_users.sql` | `public.users` (perfil, sin credenciales), `updated_at` automático |
| `002_roles.sql` | `public.roles` + semilla Admin(1) / Editor(2) / Visualizador(3) |
| `003_user_roles.sql` | `public.user_roles` (N:M, preparado para varios roles) |
| `004_auth_functions.sql` | `has_role()`, `is_admin()`, `is_editor()`, `is_viewer()`, `is_active_user()`, `can_write()` y helpers |
| `005_auth_policies.sql` | RLS + políticas de `users`, `roles`, `user_roles`; bloqueo de autoescalado; guarda de último Admin; `set_user_role()` |
| `006_user_trigger.sql` | Trigger en `auth.users` → crea perfil + rol Visualizador |
| `007_business_policies.sql` | `apply_crud_policies('tabla')` para tablas de negocio |

Para cada tabla de negocio detectada, agregar en una migración nueva:

```sql
select public.apply_crud_policies('public.nombre_tabla');
```

Esto aplica el estándar: SELECT = todos los roles activos, INSERT/UPDATE = Admin y Editor, DELETE = Admin.
Pregunta al desarrollador antes de aplicarlo a tablas que tengan políticas propias.

Aplicar: `supabase db push` (o pegar en el SQL Editor en orden si no usan CLI).

**Primer Admin** (una sola vez, desde el SQL Editor del dashboard, nunca desde el frontend):

```sql
select public.bootstrap_admin('correo@grupofriopacking.pe');
```

### Paso 3 — Edge Function para administración de usuarios

Crear usuarios con contraseña y bloquear el inicio de sesión de usuarios inactivos requiere
la service role key, así que **no se hace desde el navegador**. Copiar
`assets/edge-functions/admin-users/index.ts` a `supabase/functions/admin-users/index.ts`.

La función valida el JWT del que llama, verifica `is_admin()` con RLS y solo entonces usa la
service role (que Supabase inyecta como variable de entorno de la función). Acciones:
`create` (usuario + contraseña + rol + estado) y `set_active` (perfil + bloqueo de login).
Cambiar rol (`rpc('set_user_role')`) y editar nombre/apellidos se hacen directo desde el frontend con RLS.

Desplegar: `supabase functions deploy admin-users`.

Si el proyecto ya tiene backend propio (Next.js route handlers, Express, NestJS), se puede
implementar la misma lógica ahí en vez de la Edge Function, con la service key en variable de servidor.

### Paso 4 — Frontend

Seguir `references/frontend.md` (arquitectura, componentes, rutas, guards por framework) y
`references/diseno.md` (paleta, tipografía, layout, estados). Copiar `assets/theme/tokens.css`
o traducir los tokens al sistema de estilos del proyecto (p. ej. `tailwind.config`).

Entregables mínimos: Login, Registro, Recuperar contraseña, Nueva contraseña, Perfil,
Usuarios (Admin), Roles (Admin), layout con Sidebar + Header + UserMenu, `ProtectedRoute`,
`RoleGuard`, hook/servicio `useAuth` con sesión, perfil, roles y helpers `can()`.

### Paso 5 — Variables de entorno y .gitignore

- Crear/actualizar `.env.example` **sin valores reales**.
- Asegurar que `.gitignore` incluye `.env`, `.env.local`, `.env.*.local` (y `.env.production` si contiene secretos).
- Si `.env` ya fue commiteado, avisar y recomendar rotar las claves.

### Paso 6 — Verificación

1. Volver a ejecutar `scripts/check_supabase_config.sh` (debe dar `ok` / `ok`) y `scripts/scan_secrets.sh`. Debe quedar limpio (o solo falsos positivos explicados).
2. Ejecutar las pruebas de RLS de `references/pruebas-seguridad.sql` en una base local
   (`supabase start` + `supabase db reset`) o en un proyecto de pruebas. **Nunca en producción.**
3. Compilar el proyecto (`npm run build` o equivalente) y corregir errores.
4. Recorrer la lista de validación de la sección 45 de `references/requisitos.md` y reportar
   cada punto como OK / pendiente con la razón.

### Paso 7 — Informe final al desarrollador

Breve y concreto: archivos creados/modificados, migraciones a aplicar, comando de despliegue
de la Edge Function, cómo crear el primer Admin, configuración pendiente en el dashboard
(Auth → URL Configuration: Site URL y Redirect URLs para `/nueva-contrasena`; plantillas de correo),
y cualquier secreto detectado que deba rotarse.

## Configuración requerida en el dashboard de Supabase

- **Auth → URL Configuration**: Site URL de la app y Redirect URL `https://<app>/nueva-contrasena`
  (y `http://localhost:<puerto>/nueva-contrasena` para desarrollo).
- **Auth → Providers → Email**: habilitado. Decidir con el desarrollador si "Confirm email" queda activo.
- Si la app es solo interna y no debe permitir autorregistro, desactivar "Allow new users to sign up"
  y ocultar la vista de Registro; los usuarios los crea el Admin.
