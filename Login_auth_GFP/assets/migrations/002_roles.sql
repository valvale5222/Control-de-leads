-- 002_roles.sql
-- Catálogo de roles. Los IDs son fijos: el código y las funciones los referencian por nombre.

create table if not exists public.roles (
  id           smallint primary key,
  name         text not null unique,
  description  text,
  created_at   timestamptz not null default now()
);

insert into public.roles (id, name, description) values
  (1, 'Admin',        'Acceso completo al sistema.'),
  (2, 'Editor',       'Puede consultar, crear y modificar información permitida.'),
  (3, 'Visualizador', 'Solo puede consultar información.')
on conflict (id) do nothing;
