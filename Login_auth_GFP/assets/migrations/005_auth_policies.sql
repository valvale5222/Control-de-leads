-- 005_auth_policies.sql
-- Row Level Security para users, roles y user_roles + guardas contra autoescalado.

alter table public.users      enable row level security;
alter table public.roles      enable row level security;
alter table public.user_roles enable row level security;

-- Usuarios anónimos no acceden a estas tablas en ningún caso
revoke all on public.users, public.roles, public.user_roles from anon;

-- ---------------------------------------------------------------- users
drop policy if exists users_select on public.users;
create policy users_select on public.users
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

drop policy if exists users_insert on public.users;
create policy users_insert on public.users
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists users_update on public.users;
create policy users_update on public.users
  for update to authenticated
  using ((id = auth.uid() and public.is_active_user()) or public.is_admin())
  with check ((id = auth.uid() and public.is_active_user()) or public.is_admin());

drop policy if exists users_delete on public.users;
create policy users_delete on public.users
  for delete to authenticated
  using (public.is_admin());

-- Un no-Admin solo puede cambiar sus propios name / last_name.
-- Un Admin no puede desactivarse a sí mismo.
-- SECURITY INVOKER a propósito: current_user debe ser el rol de la petición.
create or replace function public.guard_users_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id <> old.id or new.created_at <> old.created_at then
      raise exception 'Campos de solo lectura' using errcode = '42501';
    end if;

    if not public.is_admin() then
      if new.is_active is distinct from old.is_active
         or new.email is distinct from old.email then
        raise exception 'No autorizado para modificar estado o correo' using errcode = '42501';
      end if;
    elsif old.id = auth.uid() and new.is_active = false then
      raise exception 'Un Admin no puede desactivarse a sí mismo' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists users_guard_update on public.users;
create trigger users_guard_update
  before update on public.users
  for each row execute function public.guard_users_update();

-- ---------------------------------------------------------------- roles
drop policy if exists roles_select on public.roles;
create policy roles_select on public.roles
  for select to authenticated
  using (public.is_active_user());

drop policy if exists roles_write on public.roles;
create policy roles_write on public.roles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------- user_roles
drop policy if exists user_roles_select on public.user_roles;
create policy user_roles_select on public.user_roles
  for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- Solo Admin asigna, cambia o quita roles. Un Editor/Visualizador no puede autoasignarse Admin.
drop policy if exists user_roles_insert on public.user_roles;
create policy user_roles_insert on public.user_roles
  for insert to authenticated
  with check (public.is_admin());

drop policy if exists user_roles_update on public.user_roles;
create policy user_roles_update on public.user_roles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists user_roles_delete on public.user_roles;
create policy user_roles_delete on public.user_roles
  for delete to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------- último Admin
-- Impide quedarse sin ningún Admin activo (quitando el rol o desactivando al último).
create or replace function public.guard_last_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected uuid;
  remaining int;
begin
  if tg_table_name = 'user_roles' then
    if old.role_id <> 1 or (tg_op = 'UPDATE' and new.role_id = 1 and new.user_id = old.user_id) then
      return coalesce(new, old);
    end if;
    affected := old.user_id;
  else -- users
    if not (old.is_active and new.is_active = false) then
      return new;
    end if;
    if not exists (select 1 from public.user_roles where user_id = old.id and role_id = 1) then
      return new;
    end if;
    affected := old.id;
  end if;

  select count(*) into remaining
  from public.user_roles ur
  join public.users u on u.id = ur.user_id
  where ur.role_id = 1 and u.is_active and ur.user_id <> affected;

  if remaining = 0 then
    raise exception 'Debe existir al menos un Admin activo' using errcode = '42501';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists user_roles_guard_last_admin on public.user_roles;
create trigger user_roles_guard_last_admin
  before update or delete on public.user_roles
  for each row execute function public.guard_last_admin();

drop trigger if exists users_guard_last_admin on public.users;
create trigger users_guard_last_admin
  before update of is_active on public.users
  for each row execute function public.guard_last_admin();

-- ---------------------------------------------------------------- cambio de rol atómico
-- Reemplaza el/los rol(es) de un usuario por uno solo, en una transacción.
-- SECURITY INVOKER: se ejecuta con los permisos de quien llama, así que RLS exige Admin
-- y la guarda de "último Admin" sigue aplicando.
-- Frontend: supabase.rpc('set_user_role', { p_user_id, p_role_id })
create or replace function public.set_user_role(p_user_id uuid, p_role_id smallint)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'Solo un Admin puede cambiar roles' using errcode = '42501';
  end if;
  insert into public.user_roles (user_id, role_id) values (p_user_id, p_role_id)
    on conflict do nothing;
  delete from public.user_roles where user_id = p_user_id and role_id <> p_role_id;
end;
$$;

revoke execute on function public.set_user_role(uuid, smallint) from public, anon;
grant execute on function public.set_user_role(uuid, smallint) to authenticated;
