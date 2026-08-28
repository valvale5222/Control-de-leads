-- =====================================================================
-- 09: Login obligatorio con Supabase Auth
-- El panel ahora exige iniciar sesión. La autenticación la resuelve
-- Supabase Auth (auth.users) con email + contraseña; la tabla `usuario`
-- (creada a mano, junto con `roles`) deja de guardar contraseña propia y
-- pasa a ser solo el perfil de cada cuenta (nombre + rol), vinculado por
-- auth_user_id a auth.users.
--
-- Pasos para dar de alta a alguien:
--   1) Dashboard -> Authentication -> Users -> Add user (email + contraseña).
--   2) Copiar el UUID de esa cuenta.
--   3) INSERT o UPDATE en `usuario` para vincularla (ver ejemplo al final).
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- =====================================================================

alter table public.usuario
  add column if not exists auth_user_id uuid unique references auth.users(id) on delete cascade;

alter table public.usuario
  drop column if exists contrasena;

alter table public.usuario enable row level security;
alter table public.roles enable row level security;

-- Cada usuario autenticado puede leer su propia fila de perfil (nombre + rol).
drop policy if exists "usuario_select_propio" on public.usuario;
create policy "usuario_select_propio" on public.usuario
  for select using (auth_user_id = auth.uid());

-- Los roles (admin/editor/visor) son solo catálogo: cualquier usuario logueado los puede leer.
drop policy if exists "roles_select_authenticated" on public.roles;
create policy "roles_select_authenticated" on public.roles
  for select using (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------
-- El panel ya exige login: las políticas abiertas "anon_*" de 03_policies.sql
-- quedan reemplazadas por políticas que solo dejan pasar a usuarios logueados.
-- ---------------------------------------------------------------------
drop policy if exists "anon_select_oportunidades" on public.oportunidades;
drop policy if exists "anon_write_oportunidades" on public.oportunidades;
drop policy if exists "auth_select_oportunidades" on public.oportunidades;
drop policy if exists "auth_write_oportunidades" on public.oportunidades;
create policy "auth_select_oportunidades" on public.oportunidades
  for select using (auth.role() = 'authenticated');
create policy "auth_write_oportunidades" on public.oportunidades
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "anon_select_entregables" on public.entregables;
drop policy if exists "anon_write_entregables" on public.entregables;
drop policy if exists "auth_select_entregables" on public.entregables;
drop policy if exists "auth_write_entregables" on public.entregables;
create policy "auth_select_entregables" on public.entregables
  for select using (auth.role() = 'authenticated');
create policy "auth_write_entregables" on public.entregables
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ---------------------------------------------------------------------
-- Ejemplo para vincular una cuenta ya creada en Authentication > Users
-- a su fila de perfil en `usuario` (ajustar el UUID y el "user"/nombre):
-- ---------------------------------------------------------------------
-- update public.usuario
--   set auth_user_id = '00000000-0000-0000-0000-000000000000'
--   where "user" = 'valeria';
--
-- Si la fila todavía no existe:
-- insert into public.usuario (auth_user_id, "user", nombre, rol_id)
-- values ('00000000-0000-0000-0000-000000000000', 'valeria', 'Valeria Rodríguez',
--         (select identificador from public.roles where descripcion = 'admin'));
