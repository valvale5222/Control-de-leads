-- 006_user_trigger.sql
-- Crea automáticamente public.users (mismo UUID) y asigna Visualizador al registrarse.
-- Ignora cualquier "role" que venga en user_metadata: el rol nunca lo decide el cliente.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email, name, last_name)
  values (
    new.id,
    new.email,
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'last_name'), '')
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role_id)
  values (new.id, 3)   -- Visualizador
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Mantiene sincronizado el correo si cambia en Supabase Auth
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();

-- Promover el primer Admin. Ejecutar SOLO desde el SQL Editor del dashboard (rol postgres).
--   select public.bootstrap_admin('correo@grupofriopacking.pe');
create or replace function public.bootstrap_admin(p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid;
begin
  select id into uid from public.users where lower(email) = lower(p_email);
  if uid is null then
    raise exception 'No existe un usuario con correo %', p_email;
  end if;
  insert into public.user_roles (user_id, role_id) values (uid, 1) on conflict do nothing;
  update public.users set is_active = true where id = uid;
  return 'Admin asignado a ' || p_email;
end;
$$;

revoke execute on function public.handle_new_user(), public.handle_user_email_change()
  from public, anon, authenticated;
revoke execute on function public.bootstrap_admin(text) from public, anon, authenticated, service_role;
