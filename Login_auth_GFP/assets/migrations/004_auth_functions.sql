-- 004_auth_functions.sql
-- Funciones de autorización reutilizables.
-- SECURITY DEFINER para evitar recursión de RLS al consultar user_roles desde políticas.
-- Siempre identifican al usuario con auth.uid(); nunca confían en datos del frontend.
-- Un usuario inactivo (is_active = false) no tiene ningún rol efectivo.

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select u.is_active from public.users u where u.id = auth.uid()),
    false
  );
$$;

create or replace function public.has_role(role_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    join public.roles r on r.id = ur.role_id
    join public.users u on u.id = ur.user_id
    where ur.user_id = auth.uid()
      and u.is_active
      and r.name = role_name
  );
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.has_role('Admin'); $$;

create or replace function public.is_editor()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.has_role('Editor'); $$;

create or replace function public.is_viewer()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.has_role('Visualizador'); $$;

-- Helpers para políticas CRUD estándar
create or replace function public.can_read()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.is_admin() or public.is_editor() or public.is_viewer(); $$;

create or replace function public.can_write()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.is_admin() or public.is_editor(); $$;

create or replace function public.can_delete()
returns boolean language sql stable security definer set search_path = ''
as $$ select public.is_admin(); $$;

-- Acceso del usuario actual en una sola llamada (para el frontend: supabase.rpc('get_my_access'))
create or replace function public.get_my_access()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'user_id',   auth.uid(),
    'is_active', public.is_active_user(),
    'roles', coalesce((
      select jsonb_agg(r.name order by r.id)
      from public.user_roles ur
      join public.roles r on r.id = ur.role_id
      where ur.user_id = auth.uid()
    ), '[]'::jsonb)
  );
$$;

revoke execute on function
  public.is_active_user(), public.has_role(text), public.is_admin(), public.is_editor(),
  public.is_viewer(), public.can_read(), public.can_write(), public.can_delete(),
  public.get_my_access()
from public, anon;

grant execute on function
  public.is_active_user(), public.has_role(text), public.is_admin(), public.is_editor(),
  public.is_viewer(), public.can_read(), public.can_write(), public.can_delete(),
  public.get_my_access()
to authenticated, service_role;
