-- =====================================================================
-- 11: Gestión de usuarios (solo admin)
-- Habilita la vista usuarios.html: un admin puede ver todas las filas de
-- `usuario` (no solo la propia) y crear/editar filas (alta de gente,
-- cambio de rol). Requiere que 09_auth_login.sql ya se haya corrido.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- =====================================================================

-- Función auxiliar: ¿el usuario autenticado actual tiene rol admin?
-- security definer + search_path fijo para poder leer `usuario`/`roles` sin
-- quedar atrapada en sus propias políticas RLS (evita recursión) y sin
-- quedar expuesta a un search_path manipulado.
create or replace function public.es_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.usuario u
    join public.roles r on r.identificador = u.rol_id
    where u.auth_user_id = auth.uid() and r.descripcion = 'admin'
  );
$$;

-- Un admin puede ver todas las filas de `usuario` (se suma a
-- "usuario_select_propio" de 09_auth_login.sql: las políticas para el mismo
-- comando se combinan con OR, así que cada quien sigue viendo la suya y el
-- admin además ve todas).
drop policy if exists "usuario_select_admin" on public.usuario;
create policy "usuario_select_admin" on public.usuario
  for select using (public.es_admin());

-- Un admin puede crear y editar filas de `usuario` (dar de alta gente,
-- cambiar el rol de alguien). No había ninguna política de escritura hasta
-- ahora, así que sin esto ni el propio admin podía insertar/editar.
drop policy if exists "usuario_write_admin" on public.usuario;
create policy "usuario_write_admin" on public.usuario
  for all using (public.es_admin()) with check (public.es_admin());
