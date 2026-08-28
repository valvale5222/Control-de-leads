-- =====================================================================
-- 12: Los 3 roles con permisos reales (admin / editor / visor)
--
--   admin  -> ve todo, edita todo y gestiona usuarios (usuarios.html)
--   editor -> ve todo y edita oportunidades y entregables
--   visor  -> solo lectura: ve todo, no puede crear, editar ni borrar
--
-- Hasta ahora el rol era solo una etiqueta: 09_auth_login.sql le daba
-- permiso de escritura a CUALQUIER usuario logueado, así que un visor
-- podía borrar oportunidades. Este script hace que el rol mande de verdad,
-- del lado del servidor (que es el único lugar donde un permiso es real:
-- esconder botones en la pantalla no impide que alguien escriba por su
-- cuenta contra la API).
--
-- Reemplaza a 09_auth_login.sql, 10_revert_auth_login.sql y
-- 11_admin_usuarios.sql: es seguro correrlo aunque los hayas corrido antes,
-- y también si nunca los corriste. Se puede volver a correr sin problema.
--
-- IMPORTANTE — ORDEN: no corras este script hasta que login.html esté
-- publicado en Vercel y hayas confirmado que podés entrar con tu cuenta.
-- Si lo corrés antes, el panel deja de mostrar datos (como pasó la vez
-- anterior), porque el sitio publicado entraría como anónimo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Tablas de roles y perfiles.
-- Las creaste a mano desde el Table Editor, así que no estaban en ningún
-- script. Quedan acá para que el proyecto se pueda reconstruir de cero.
-- Si ya existen, estas sentencias no las tocan.
-- ---------------------------------------------------------------------
create table if not exists public.roles (
  identificador bigint generated always as identity primary key,
  descripcion   text not null unique
);

create table if not exists public.usuario (
  identificador bigint generated always as identity primary key,
  auth_user_id  uuid unique references auth.users(id) on delete cascade,
  "user"        text,
  nombre        text,
  rol_id        bigint references public.roles(identificador)
);

-- Los 3 roles. Solo inserta los que falten.
insert into public.roles (descripcion)
select v.d
from (values ('admin'), ('editor'), ('visor')) as v(d)
where not exists (
  select 1 from public.roles r where r.descripcion = v.d
);


-- ---------------------------------------------------------------------
-- 2) Funciones que responden "¿quién sos y qué podés hacer?".
--
-- Van con security definer para poder leer `usuario` y `roles` sin quedar
-- atrapadas en las políticas RLS de esas mismas tablas (si no, para saber
-- tu rol habría que leer tu fila, y para leer tu fila habría que saber tu
-- rol: recursión infinita). El search_path fijo evita que alguien las
-- redirija a tablas suyas.
-- ---------------------------------------------------------------------
create or replace function public.mi_rol()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select r.descripcion
  from public.usuario u
  join public.roles r on r.identificador = u.rol_id
  where u.auth_user_id = auth.uid();
$$;

-- ¿El usuario actual puede modificar datos? Solo admin y editor.
-- coalesce: si no tiene perfil o no tiene rol, mi_rol() devuelve null y la
-- respuesta es "no". El default es negar, no permitir.
create or replace function public.puede_editar()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.mi_rol() in ('admin', 'editor'), false);
$$;

create or replace function public.es_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.mi_rol() = 'admin', false);
$$;


-- ---------------------------------------------------------------------
-- 3) Oportunidades y entregables.
-- Leer: cualquiera que haya iniciado sesión (los 3 roles).
-- Escribir: solo admin y editor.
--
-- Se separan insert / update / delete en vez de usar "for all" para que
-- quede explícito qué se está permitiendo, y porque insert lleva `with
-- check` y delete solo `using`.
-- ---------------------------------------------------------------------

-- Fuera las políticas viejas: las abiertas de 03_policies.sql y 10_revert
-- (dejaban entrar a cualquiera con la anon key, sin login) y las de
-- 09_auth_login.sql (dejaban escribir a cualquier logueado, sin mirar rol).
drop policy if exists "anon_select_oportunidades" on public.oportunidades;
drop policy if exists "anon_write_oportunidades"  on public.oportunidades;
drop policy if exists "auth_select_oportunidades" on public.oportunidades;
drop policy if exists "auth_write_oportunidades"  on public.oportunidades;

alter table public.oportunidades enable row level security;

create policy "oportunidades_select_logueado" on public.oportunidades
  for select to authenticated using (true);
create policy "oportunidades_insert_editor" on public.oportunidades
  for insert to authenticated with check (public.puede_editar());
create policy "oportunidades_update_editor" on public.oportunidades
  for update to authenticated using (public.puede_editar()) with check (public.puede_editar());
create policy "oportunidades_delete_editor" on public.oportunidades
  for delete to authenticated using (public.puede_editar());

drop policy if exists "anon_select_entregables" on public.entregables;
drop policy if exists "anon_write_entregables"  on public.entregables;
drop policy if exists "auth_select_entregables" on public.entregables;
drop policy if exists "auth_write_entregables"  on public.entregables;

alter table public.entregables enable row level security;

create policy "entregables_select_logueado" on public.entregables
  for select to authenticated using (true);
create policy "entregables_insert_editor" on public.entregables
  for insert to authenticated with check (public.puede_editar());
create policy "entregables_update_editor" on public.entregables
  for update to authenticated using (public.puede_editar());
create policy "entregables_delete_editor" on public.entregables
  for delete to authenticated using (public.puede_editar());


-- ---------------------------------------------------------------------
-- 4) Perfiles y catálogo de roles.
-- Cada uno ve su propia fila (el panel la necesita para saber su rol y
-- mostrar el nombre en el header). El admin ve y edita todas, que es lo
-- que hace funcionar usuarios.html.
-- ---------------------------------------------------------------------
alter table public.usuario enable row level security;
alter table public.roles   enable row level security;

drop policy if exists "usuario_select_propio" on public.usuario;
drop policy if exists "usuario_select_admin"  on public.usuario;
drop policy if exists "usuario_write_admin"   on public.usuario;

-- Las políticas de un mismo comando se combinan con OR: cada quien ve la
-- suya, y el admin además ve todas.
create policy "usuario_select_propio" on public.usuario
  for select to authenticated using (auth_user_id = auth.uid());
create policy "usuario_select_admin" on public.usuario
  for select to authenticated using (public.es_admin());
create policy "usuario_write_admin" on public.usuario
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

drop policy if exists "roles_select_authenticated" on public.roles;
create policy "roles_select_authenticated" on public.roles
  for select to authenticated using (true);


-- =====================================================================
-- 5) DAR DE ALTA AL PRIMER ADMIN — hacelo ANTES de publicar el login.
--
-- Sin esto no hay ningún admin, y como el panel va a exigir sesión, nadie
-- podría entrar ni crear usuarios: te quedás afuera de tu propio panel.
--
--   Paso 1: Dashboard -> Authentication -> Users -> Add user.
--           Poné tu correo y una contraseña, y marcá "Auto Confirm User"
--           (si no, la cuenta queda sin confirmar y no puede entrar).
--   Paso 2: Volvé acá y corré la línea de abajo con tu correo y tu nombre.
--
-- De ahí en más, los demás usuarios los creás desde usuarios.html, sin SQL.
-- =====================================================================

-- Vincula una cuenta de Authentication con su perfil y su rol.
-- Si la persona ya tenía perfil, le actualiza el nombre y el rol.
create or replace function public.vincular_usuario(
  p_email  text,
  p_nombre text,
  p_rol    text default 'visor'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid;
  v_rol_id bigint;
begin
  select id into v_uid from auth.users where lower(email) = lower(p_email);
  if v_uid is null then
    return 'No existe ninguna cuenta con el correo ' || p_email ||
           '. Creala primero en Authentication > Users.';
  end if;

  select identificador into v_rol_id from public.roles where descripcion = p_rol;
  if v_rol_id is null then
    return 'El rol "' || p_rol || '" no existe. Usá admin, editor o visor.';
  end if;

  insert into public.usuario (auth_user_id, "user", nombre, rol_id)
  values (v_uid, split_part(p_email, '@', 1), p_nombre, v_rol_id)
  on conflict (auth_user_id) do update
    set nombre = excluded.nombre,
        rol_id = excluded.rol_id;

  return p_nombre || ' quedó vinculado con el rol ' || p_rol || '.';
end;
$$;

-- >>> DESCOMENTÁ ESTA LÍNEA, poné tu correo y tu nombre, y corré el script.
-- select public.vincular_usuario('vrodriguez@friopacking.pe', 'Valeria Rodríguez', 'admin');
