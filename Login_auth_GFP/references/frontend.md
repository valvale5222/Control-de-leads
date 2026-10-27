# Frontend — arquitectura e implementación

Adaptar todo a la arquitectura detectada en el Paso 1. Los ejemplos están en TypeScript con
`@supabase/supabase-js` v2; traducirlos al framework real (React, Next.js, Vue, Angular, Svelte, JS plano).

## 1. Cliente Supabase (uno solo)

Reutilizar el cliente existente si ya hay uno. La URL y la clave salen del Paso 1b del SKILL.md
(se detectan con `scripts/check_supabase_config.sh` o se piden al desarrollador). Si no hay cliente:

```ts
// src/lib/supabase.ts  (ajustar prefijo: VITE_, NEXT_PUBLIC_, NUXT_PUBLIC_, PUBLIC_, NG_APP_ ...)
import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
if (!url || !anonKey) throw new Error('Faltan VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY')

export const supabase = createClient(url, anonKey)
```

Solo la **anon/publishable key** va en el frontend. La service role jamás.

`.env.example` (sin valores reales):

```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
# Solo servidor / Edge Functions. Nunca con prefijo público:
# SUPABASE_SERVICE_ROLE_KEY=
```

## 2. Servicio de autenticación

```ts
// src/features/auth/authService.ts
import { supabase } from '@/lib/supabase'

const origin = window.location.origin

export const authService = {
  signIn: (email: string, password: string) =>
    supabase.auth.signInWithPassword({ email, password }),

  signUp: (email: string, password: string, name: string, last_name: string) =>
    supabase.auth.signUp({
      email,
      password,
      // El trigger lee name/last_name. Cualquier "role" aquí se ignora en la BD.
      options: { data: { name, last_name }, emailRedirectTo: `${origin}/login` },
    }),

  signOut: () => supabase.auth.signOut(),

  requestPasswordReset: (email: string) =>
    supabase.auth.resetPasswordForEmail(email, { redirectTo: `${origin}/nueva-contrasena` }),

  updatePassword: (password: string) => supabase.auth.updateUser({ password }),

  getAccess: () => supabase.rpc('get_my_access'), // { user_id, is_active, roles: string[] }

  getProfile: (id: string) =>
    supabase.from('users').select('id,name,last_name,email,is_active,created_at').eq('id', id).single(),
}
```

## 3. Estado de sesión (`useAuth` / AuthProvider / AuthService / store)

Estado: `session`, `user`, `profile`, `roles: string[]`, `isActive`, `loading`.

Reglas:
- Al iniciar: `supabase.auth.getSession()` y luego cargar `get_my_access` + perfil.
- Suscribirse a `supabase.auth.onAuthStateChange((event, session) => ...)`:
  - `SIGNED_IN` / `TOKEN_REFRESHED` / `USER_UPDATED` → recargar acceso.
  - `SIGNED_OUT` → limpiar todo el estado y navegar a `/login`.
  - `PASSWORD_RECOVERY` → navegar a `/nueva-contrasena`.
- Si `is_active === false`: `signOut()` y mostrar en Login "Tu cuenta está desactivada. Contacta al administrador."
- No guardar tokens manualmente en localStorage ni en tablas. Supabase ya maneja la persistencia.
- Anular la suscripción al desmontar.

Permisos derivados (solo UX; la seguridad la da RLS):

```ts
export type Action = 'read' | 'create' | 'update' | 'delete' | 'admin'

export function can(roles: string[], action: Action): boolean {
  if (roles.includes('Admin')) return true
  if (roles.includes('Editor')) return action === 'read' || action === 'create' || action === 'update'
  if (roles.includes('Visualizador')) return action === 'read'
  return false
}
```

## 4. Rutas

| Ruta | Acceso | Vista |
|---|---|---|
| `/login` | pública (si hay sesión → `/dashboard`) | LoginForm |
| `/registro` | pública (ocultar si el autorregistro está desactivado) | RegisterForm |
| `/recuperar-contrasena` | pública | ForgotPasswordForm |
| `/nueva-contrasena` | sesión de recuperación | ResetPasswordForm |
| `/dashboard` | autenticado | (existente o placeholder) |
| `/perfil` | autenticado | ProfileView |
| `/usuarios` | Admin | UserTable + UserForm |
| `/roles` | Admin | RoleTable + RoleDetails |
| `/configuracion` | Admin | (si aplica) |

Si los nombres de ruta del proyecto son distintos (o están en inglés), respetarlos.

- `ProtectedRoute`: mientras `loading` → `LoadingState`. Sin sesión → redirigir a `/login?next=<ruta>`.
- `RoleGuard roles={['Admin']}`: sin el rol → página "No tienes permiso para ver esta sección" (no redirigir en bucle).
- Tras login, redirigir a `next` si es una ruta interna (empieza con `/` y no con `//`), si no a `/dashboard`.

### Por framework

- **React + React Router**: `<Route element={<ProtectedRoute/>}>` con `<Outlet/>`; `RoleGuard` envolviendo rutas Admin.
- **Next.js (App Router)**: usar `@supabase/ssr` (`createBrowserClient` / `createServerClient` con cookies).
  `middleware.ts` refresca la sesión y redirige a `/login` en rutas protegidas. En Server Components
  validar con `supabase.auth.getUser()` (no confiar solo en `getSession()` en servidor).
  Rutas admin: comprobar rol en el layout del segmento (`app/(admin)/layout.tsx`) con `rpc('get_my_access')`.
- **Next.js (Pages Router)**: `@supabase/ssr` + `getServerSideProps` o middleware equivalente.
- **Vue / Nuxt**: router guard `beforeEach` (Vue) o `defineNuxtRouteMiddleware` (Nuxt) + store Pinia. En Nuxt considerar `@nuxtjs/supabase` si ya está.
- **Angular**: `AuthService` con `BehaviorSubject`/signals, `CanActivateFn` para auth y para rol.
- **SvelteKit**: `@supabase/ssr` en `hooks.server.ts`, protección en `+layout.server.ts`.
- **HTML + JS plano**: módulo `auth.js` con el cliente (CDN `@supabase/supabase-js@2` ESM),
  comprobación de sesión al cargar cada página protegida y redirección a `login.html`.

## 5. Administración de usuarios (`/usuarios`, solo Admin)

Listado (RLS solo devuelve todo si es Admin):

```ts
supabase
  .from('users')
  .select('id,name,last_name,email,is_active,created_at,user_roles(role_id,roles(name))')
  .order('created_at', { ascending: false })
```

Búsqueda por nombre/apellido/correo y filtros de rol y estado: en cliente si son pocos registros;
con `.or('name.ilike.%q%,last_name.ilike.%q%,email.ilike.%q%')`, `.eq('is_active', ...)` y paginación
`.range()` si son muchos.

Acciones (menú contextual de tres puntos, icono `MoreHorizontal`):

| Acción | Implementación |
|---|---|
| Crear usuario | `supabase.functions.invoke('admin-users', { body: { action: 'create', email, password, name, last_name, role_id, is_active } })` |
| Editar nombre/apellidos | `supabase.from('users').update({ name, last_name }).eq('id', id)` |
| Cambiar rol | `supabase.rpc('set_user_role', { p_user_id: id, p_role_id })` |
| Activar / desactivar | `supabase.functions.invoke('admin-users', { body: { action: 'set_active', user_id, is_active } })` (pedir confirmación con `ConfirmDialog`) |

- No permitir que el Admin se desactive o se quite el rol Admin a sí mismo (la BD también lo impide).
- Mostrar los errores de la BD/función de forma legible ("Debe existir al menos un Admin activo").
- La contraseña nunca se edita desde la tabla. Para cambiarla: el usuario usa "¿Olvidaste tu contraseña?"
  o el Admin le envía el enlace con `resetPasswordForEmail`.

## 6. Roles (`/roles`, solo Admin)

Vista de solo lectura: `supabase.from('roles').select('*').order('id')` + matriz de permisos estática
(coincide con las políticas RLS):

| Rol | Usuarios | Módulos | Configuración |
|---|---|---|---|
| Admin | Ver, Crear, Editar, Eliminar | Ver, Crear, Editar, Eliminar | Sí |
| Editor | No | Ver, Crear, Editar | No |
| Visualizador | No | Ver | No |

Usar iconos `Check` / `X` de Lucide (no los caracteres ✓ ✕ ni emojis).

## 7. Perfil (`/perfil`)

Muestra nombre, apellidos, correo, rol y estado. Editables: nombre y apellidos.
Rol, estado y correo en solo lectura. Botón "Cambiar contraseña" → `updatePassword` (pedir la nueva dos veces).

## 8. Componentes mínimos

`LoginForm`, `RegisterForm`, `ForgotPasswordForm`, `ResetPasswordForm`, `UserTable`, `UserForm`,
`RoleTable`, `RoleDetails`, `ProtectedRoute`, `RoleGuard`, `AppLayout` (Sidebar + Header + contenido),
`Sidebar`, `Header`, `UserMenu`, `LoadingState`, `ErrorState`, `EmptyState`, `ConfirmDialog`.

Reutilizar componentes del proyecto (botones, inputs, modales) si ya existen. No duplicar.

## 9. Mostrar/ocultar por rol en módulos de negocio

En los módulos existentes: ocultar "Nuevo"/"Editar" si `!can(roles,'create'|'update')`
y "Eliminar" si `!can(roles,'delete')`. Recordar al desarrollador que esto es UX: si la tabla
no tiene `apply_crud_policies`, cualquiera con sesión podría saltárselo desde la consola.

## 10. Mensajes de error (español, sin detalles internos)

| Origen | Mensaje |
|---|---|
| `Invalid login credentials` | Correo o contraseña incorrectos. |
| `Email not confirmed` | Debes confirmar tu correo antes de ingresar. |
| `User is banned` / inactivo | Tu cuenta está desactivada. Contacta al administrador. |
| `over_email_send_rate_limit` | Demasiados intentos. Espera unos minutos. |
| Recuperación enviada | Si el correo existe, recibirás un enlace para restablecer tu contraseña. (no revelar si existe) |
| Error de red | No se pudo conectar. Revisa tu conexión e inténtalo de nuevo. |
