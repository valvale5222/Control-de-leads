# Supabase Secure Auth & User Management — Requisitos

Especificación oficial de TI de Grupo Frío Packing. Todo lo implementado por el skill debe cumplirla.

## Objetivo

Implementar un sistema completo de autenticación, autorización y administración de usuarios para
aplicaciones web que utilizan Supabase. El desarrollador debe poder ejecutarlo sin conocer detalles
de autenticación, JWT, RLS o gestión de usuarios.

Resultado esperado: Login, Registro, Logout, Recuperación de contraseña, Gestión de sesión, Usuarios,
Roles, Asignación de roles, Administración de usuarios, Control de acceso, Protección de rutas,
Row Level Security (RLS), Protección de credenciales e Interfaz visual completa.

---

## 1. Principios fundamentales

- Usar Supabase como proveedor de autenticación.
- NO crear un sistema de autenticación propio ni un sistema JWT propio.
- NO almacenar contraseñas, hashes de contraseñas ni tokens de autenticación en tablas propias.
- NO usar el frontend como mecanismo principal de seguridad.
- La seguridad real debe estar respaldada por Supabase Auth y Row Level Security.

## 2. Supabase Auth

Supabase Auth administra: registro, login, logout, sesiones, contraseñas, recuperación y cambio de
contraseña, identidad del usuario y tokens de autenticación.

No implementar manualmente: hash de contraseñas, JWT, refresh tokens, access tokens ni sesiones propias.

## 3. Login

Vista funcional que permita: ingresar correo, ingresar contraseña, mostrar/ocultar contraseña, iniciar
sesión, acceder a recuperación de contraseña, mostrar errores de autenticación, mostrar estado de carga y
redirigir al usuario después de autenticarse.

Usar `supabase.auth.signInWithPassword()`. No almacenar la contraseña en ninguna tabla propia.

## 4. Registro

Usar `supabase.auth.signUp()`. El registro crea la cuenta y luego su perfil en `public.users`.
El usuario nuevo recibe por defecto el rol **Visualizador**. Nunca asignar automáticamente Admin.

## 5. Recuperación de contraseña

El Login incluye "¿Olvidaste tu contraseña?". Vista de recuperación que permita:
1. Introducir correo. 2. Solicitar enlace. 3. Recibir el enlace enviado por Supabase. 4. Establecer nueva contraseña.

No implementar recuperación manual; usar los mecanismos oficiales de Supabase Auth.

## 6. Logout

`supabase.auth.signOut()`. Después: limpiar el estado de sesión del frontend, redirigir al Login e
impedir acceso a rutas protegidas.

## 7. Sesión

Comprobar el estado de autenticación con los mecanismos oficiales de Supabase para: obtener sesión,
detectar cambios de sesión, logout y expiración. No implementar un sistema de sesión paralelo.

## 8. Tabla users

`public.users` es el perfil de usuario de la aplicación:

```
id UUID PRIMARY KEY            -- = auth.users.id
name TEXT
last_name TEXT
email TEXT
is_active BOOLEAN DEFAULT true
created_at TIMESTAMPTZ DEFAULT now()
updated_at TIMESTAMPTZ DEFAULT now()
```

`public.users` NO debe contener: password, password_hash, salt, access_token, refresh_token.
Las credenciales pertenecen exclusivamente a `auth.users`.

## 9. Tabla roles

`public.roles` con campos id, name, description, created_at. Roles iniciales:

| id | name | description |
|---|---|---|
| 1 | Admin | Acceso completo al sistema. |
| 2 | Editor | Puede consultar, crear y modificar información permitida. |
| 3 | Visualizador | Solo puede consultar información. |

## 10. Tabla user_roles

`public.user_roles` con user_id (→ public.users.id), role_id (→ public.roles.id), created_at.
Aunque inicialmente cada usuario tenga un solo rol, la estructura debe permitir múltiples roles.

## 11. Permisos

**Admin**: SELECT, INSERT, UPDATE, DELETE. Además: administrar, crear, editar, activar y desactivar
usuarios; asignar y cambiar roles; administrar módulos; acceder a configuración administrativa.

**Editor**: SELECT, INSERT, UPDATE. NO puede DELETE, administrar usuarios, administrar roles, modificar
permisos ni acceder a configuración administrativa.

**Visualizador**: SELECT. NO puede INSERT, UPDATE, DELETE, crear/editar usuarios, administrar roles,
modificar información ni acceder a configuración administrativa.

## 12. Row Level Security

Activar RLS en todas las tablas protegidas (`users`, `roles`, `user_roles` y tablas de negocio).
Las políticas usan `auth.uid()` para identificar al usuario. No confiar en un rol enviado desde el frontend.

## 13. Funciones de autorización

Funciones SQL reutilizables, como mínimo: `has_role()`, `is_admin()`, `is_editor()`, `is_viewer()`.
Ejemplo: `has_role('Admin')`. Identifican al usuario con `auth.uid()` y consultan `public.user_roles` y `public.roles`.

## 14. Políticas CRUD (tablas de negocio)

| Operación | Roles |
|---|---|
| SELECT | Admin, Editor, Visualizador |
| INSERT | Admin, Editor |
| UPDATE | Admin, Editor |
| DELETE | Admin |

## 15. Administración de usuarios

Vista `/usuarios` (o equivalente), solo para Admin. Permite: listar, buscar, filtrar, ver rol, ver
estado, crear, editar, cambiar rol, activar y desactivar usuarios.

## 16. Tabla de usuarios

Tabla limpia y minimalista. Columnas: Nombre, Correo, Rol, Estado, Fecha de creación, Acciones.
Encabezado "Usuarios — Gestiona los usuarios y sus permisos.", buscador, filtro de rol y filtro de estado.
Acciones en menú contextual de tres puntos. Sin emojis.

## 17. Crear usuario

Vista o modal "Nuevo usuario" con: Nombre, Apellidos, Correo electrónico, Contraseña, Rol
(Admin / Editor / Visualizador) y Estado. Solo la ejecuta un Admin. La credencial se crea con
Supabase Auth. No insertar contraseñas en `public.users`.

## 18. Editar usuario

El Admin puede editar nombre, apellidos, estado y rol. No editar la contraseña mediante la tabla users;
los cambios de autenticación usan Supabase Auth.

## 19. Activar / desactivar usuario

Estados Activo / Inactivo. Un usuario desactivado no puede usar la aplicación. Validación en frontend y
en backend/RLS.

## 20. Administración de roles

Vista `/roles` (o equivalente), solo Admin. Muestra nombre, descripción y permisos de Admin, Editor y Visualizador.

## 21. Interfaz de roles

Minimalista, por rol:

- **Admin** — Acceso completo. Usuarios: Ver, Crear, Editar, Eliminar. Módulos: Ver, Crear, Editar, Eliminar. Configuración: sí.
- **Editor** — Consulta y modifica. Usuarios: no. Módulos: Ver, Crear, Editar; Eliminar no.
- **Visualizador** — Solo consulta. Usuarios: no. Módulos: Ver; Crear, Editar, Eliminar no.

Sin emojis; iconografía profesional y consistente.

## 22. Protección de rutas

Rutas protegidas (ej. `/dashboard`, `/usuarios`, `/roles`, `/configuracion`) comprueban autenticación.
Sin sesión válida → redirigir a `/login`.

## 23. Protección según rol

Rutas administrativas: Admin. Rutas de edición: Admin, Editor. Rutas de consulta: Admin, Editor,
Visualizador. La protección existe en frontend y en las políticas de base de datos.

## 24. Frontend y permisos

- Admin: todas las funcionalidades.
- Editor: Consultar, Crear, Editar. Ocultar Eliminar, Usuarios, Roles, Configuración administrativa.
- Visualizador: Consultar. Ocultar Crear, Editar, Eliminar, Usuarios, Roles, Configuración.

Ocultar botones NO es una medida de seguridad. RLS debe impedir las operaciones no autorizadas.

## 25. Seguridad de credenciales

Nunca hardcodear `SUPABASE_URL`, `SUPABASE_ANON_KEY` ni `SUPABASE_SERVICE_ROLE_KEY`. Usar variables de
entorno (`SUPABASE_URL`, `SUPABASE_ANON_KEY`; en servidor `SUPABASE_SERVICE_ROLE_KEY`).

## 26. Service Role Key

Altamente sensible. Nunca debe aparecer en código frontend, JavaScript enviado al navegador, HTML, CSS,
repositorios, logs, capturas ni documentación pública. Solo en servidor cuando sea estrictamente necesario.

Si se detecta en el frontend: 1) detener la implementación, 2) eliminar la clave, 3) moverla a una
variable de entorno del servidor, 4) informar al desarrollador, 5) recomendar rotarla si ya fue expuesta.

## 27. Variables de entorno

Detectar el sistema usado (`.env`, `.env.local`, `.env.production`, ...). No asumir una tecnología; adaptarse al framework.

## 28. .gitignore

Verificar que no se suban archivos con secretos. Como mínimo `.env`, `.env.local`, `.env.*.local`.
Actualizar `.gitignore` si corresponde.

## 29. Detección de secretos

Antes de finalizar, buscar: `service_role`, `SUPABASE_SERVICE_ROLE_KEY`, `JWT_SECRET`, `password=`,
`password:`, `secret=`, `access_token=`, `refresh_token=`. Si hay una credencial real: no dejarla
hardcodeada, moverla a variables de entorno, corregir, informar y recomendar rotación.
(Automatizado en `scripts/scan_secrets.sh`.)

## 30. Creación automática del perfil

Trigger sobre `auth.users` que crea `public.users` al registrarse, con el mismo UUID.

## 31. Rol predeterminado

Todo usuario nuevo recibe Visualizador. Nunca Admin automáticamente; Admin requiere autorización administrativa.

## 32. Administración del Admin

Solo un Admin puede crear otro Admin, cambiar un usuario a Admin, quitar el rol Admin, administrar roles
y usuarios. Un Editor o Visualizador no puede convertirse a sí mismo en Admin: el frontend no lo permite
y RLS lo impide.

## 33. Perfil

Vista `/perfil` con nombre, apellidos, correo, rol y estado. El usuario modifica solo los campos
permitidos y no puede modificar su propio rol.

## 34. Diseño visual

Minimalista, moderno, corporativo, limpio, profesional. Referencia conceptual de SaaS modernos como
ChatGPT, sin copiar su branding, logotipo, interfaz ni colores. Espaciado amplio, jerarquía clara,
componentes discretos, bordes sutiles, tipografía limpia, interacciones suaves, poca decoración.

## 35. Paleta institucional

Azul marino `#102267` (títulos, texto principal), Azul eléctrico `#007BDF` (botones, links, acciones),
Cian `#00CFE8` (bordes, foco, detalles), Turquesa Friopacking `#39C1AD` (marca, indicadores),
Celeste muy claro `#EAF9FF` (fondos suaves), Blanco `#FFFFFF`, Negro `#000000` (texto secundario).
Usar exclusivamente esta paleta salvo necesidad técnica.

## 36. Tipografía

Títulos: Inter Bold. Textos: Noway. Si Noway no está disponible: intentar cargarla; si no es posible,
usar una sans-serif limpia y mantener Inter Bold en títulos.

## 37. Iconografía

Sin emojis como iconos. Una única familia profesional; preferencia Lucide Icons si el proyecto no tiene
una. Iconos simples, lineales, consistentes, pequeños, funcionales; no solo decorativos.

## 38. Login UI

Minimalista y responsive: identidad de la empresa, título, correo, contraseña, mostrar/ocultar, botón,
recuperación, errores, carga. Sin emojis, ilustraciones genéricas, fondos cargados, gradientes llamativos
ni animaciones innecesarias.

## 39. Dashboard de administración

Sidebar + Header + Contenido principal. Sidebar: Dashboard, Usuarios, Roles, Configuración.
Contenido: título, descripción, buscador, "Nuevo usuario", tabla. Sin recargar la interfaz.

## 40. Sidebar

Solo las opciones disponibles para el usuario. Admin: Dashboard, Usuarios, Roles, Configuración.
Editor: Dashboard, módulos permitidos. Visualizador: Dashboard, módulos de consulta.

## 41. Componentes

Mínimo: LoginForm, ForgotPasswordForm, UserTable, UserForm, RoleTable, RoleDetails, ProtectedRoute,
RoleGuard, Sidebar, Header, UserMenu, LoadingState, ErrorState, ConfirmDialog. Adaptar nombres a la
arquitectura del proyecto. No duplicar componentes.

## 42. Framework

Detectar framework, routing, estilos, librería de componentes, iconos y variables de entorno.
No reemplazar tecnologías existentes. React, Next.js, Vue, Angular: usar la arquitectura existente.

## 43. No romper el proyecto existente

Antes de modificar: analizar estructura, arquitectura, rutas, dependencias, estilos y configuración de
Supabase. No reemplazar archivos sin necesidad ni eliminar funcionalidades. Integrar.

## 44. Migraciones

Migraciones para users, roles, user_roles, funciones, RLS, políticas y triggers en `supabase/migrations/`.
Adaptar si el proyecto ya tiene migraciones.

## 45. Validación

- [ ] Login funciona.
- [ ] Logout funciona.
- [ ] Registro funciona.
- [ ] Recuperación de contraseña funciona.
- [ ] Sesión funciona.
- [ ] Usuarios se crean correctamente.
- [ ] Roles existen.
- [ ] Usuarios tienen roles.
- [ ] Admin puede administrar usuarios.
- [ ] Admin puede asignar roles.
- [ ] Editor puede crear.
- [ ] Editor puede editar.
- [ ] Editor no puede eliminar.
- [ ] Visualizador puede consultar.
- [ ] Visualizador no puede crear.
- [ ] Visualizador no puede editar.
- [ ] Visualizador no puede eliminar.
- [ ] RLS está habilitado.
- [ ] Las políticas RLS funcionan.
- [ ] Las rutas están protegidas.
- [ ] Service Role Key no aparece en frontend.
- [ ] No existen credenciales hardcodeadas.
- [ ] .env está protegido.
- [ ] No existen contraseñas en tablas propias.
- [ ] No existen JWT propios.
- [ ] No existen tokens almacenados innecesariamente.
- [ ] No existen emojis utilizados como iconos.
- [ ] La interfaz utiliza la paleta institucional.
- [ ] La interfaz es responsive.

## 46. Pruebas de seguridad

| # | Caso | Esperado |
|---|---|---|
| 1 | Visualizador intenta INSERT | DENEGADO |
| 2 | Visualizador intenta UPDATE | DENEGADO |
| 3 | Visualizador intenta DELETE | DENEGADO |
| 4 | Editor intenta DELETE | DENEGADO |
| 5 | Editor intenta administrar usuarios | DENEGADO |
| 6 | Admin crea usuario | PERMITIDO |
| 7 | Admin cambia rol | PERMITIDO |
| 8 | Editor intenta asignarse Admin | DENEGADO |
| 9 | No autenticado accede a /usuarios | REDIRECCIÓN AL LOGIN |

Casos 1–8 automatizados en `references/pruebas-seguridad.sql`. El caso 9 se verifica en el navegador.

## 47. Resultado final

- Authentication: Login, Registro, Logout, Recuperación de contraseña, Sesiones, Supabase Auth.
- Users: Usuarios, Perfil, Crear, Editar, Activar/desactivar, Asignar rol.
- Roles: Admin, Editor, Visualizador.
- Security: RLS, Políticas, Protección de rutas, de roles y de usuarios, Variables de entorno, Protección de secretos.
- UI: Login minimalista, Administración de usuarios y roles, Sidebar, Header, Formularios, Tablas,
  Estados de carga y error, Responsive, Paleta institucional, Inter Bold, Noway, Iconografía profesional, Sin emojis.

## 48. Objetivo del skill

El desarrollador ejecuta el skill sobre un proyecto web con Supabase y obtiene un sistema completo de
autenticación, autorización y administración de usuarios listo para integrar, sin implementar a mano
login, sesiones, roles, RLS, administración de usuarios y roles, protección de rutas, recuperación de
contraseña ni el diseño del Login y la administración, respetando la arquitectura existente.

---

## Notas de implementación (decisiones de TI)

- **Usuario inactivo**: `has_role()` devuelve falso si `is_active = false`, por lo que RLS le niega
  todo. Además la Edge Function lo bloquea en Supabase Auth (`ban_duration`) para que no pueda iniciar sesión.
- **Crear usuario con contraseña** requiere la service role → se hace en la Edge Function `admin-users`,
  que valida que quien llama sea Admin antes de usarla.
- **Siempre debe quedar al menos un Admin activo**: la BD impide quitar el rol o desactivar al último.
- **Un usuario solo edita su nombre y apellidos**: un trigger bloquea cambios de estado y correo a no-Admins.
- **Primer Admin**: `select public.bootstrap_admin('correo')` desde el SQL Editor (no ejecutable por la API).
