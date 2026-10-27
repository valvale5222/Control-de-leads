-- 003_user_roles.sql
-- Relación usuarios <-> roles. Preparada para múltiples roles por usuario.

create table if not exists public.user_roles (
  user_id     uuid     not null references public.users (id) on delete cascade,
  role_id     smallint not null references public.roles (id) on delete restrict,
  created_at  timestamptz not null default now(),
  primary key (user_id, role_id)
);

create index if not exists user_roles_role_id_idx on public.user_roles (role_id);
