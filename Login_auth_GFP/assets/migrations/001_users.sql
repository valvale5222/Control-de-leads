-- 001_users.sql
-- Perfil de usuario de la aplicación. NO contiene credenciales:
-- contraseñas, hashes y tokens viven exclusivamente en auth.users (Supabase Auth).

create table if not exists public.users (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text,
  last_name   text,
  email       text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.users is
  'Perfil de aplicación. id = auth.users.id. Sin password, hash, salt ni tokens.';

create index if not exists users_email_idx on public.users (lower(email));

-- updated_at automático (reutilizable en tablas de negocio)
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists users_set_updated_at on public.users;
create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();
