-- =====================================================================
-- 12: Los 3 roles con permisos reales (admin / editor / visor)
--
--   admin  -> ve todo, edita todo y gestiona usuarios (usuarios.html)
--   editor -> ve todo y edita oportunidades y entregables
--   visor  -> solo lectura: ve todo, no puede crear, editar ni borrar
--
-- Hasta ahora el rol era solo una etiqueta: 09_auth_login.sql le daba
-- permiso de escritura a CUALQUIER usuario logueado, así que un visor podía
-- borrar oportunidades. Este script hace que el rol mande de verdad, del
-- lado del servidor, que es el único lugar donde un permiso es real:
-- esconder botones en la pantalla no impide que alguien escriba por su
-- cuenta contra la API.
--
-- Reemplaza a 09_auth_login.sql, 10_revert_auth_login.sql y
-- 11_admin_usuarios.sql. Es idempotente: se puede correr varias veces.
--
-- Escrito contra el esquema REAL de la base (verificado en el proyecto
-- tfzanbbdvzullwlauxia), que no es el que suponían los scripts anteriores:
--
--   roles(identificador integer SIN default, descripcion varchar)
--   usuario(identificador uuid SIN default, rol_id integer, nombre varchar,
--           activo boolean default true, creado_en timestamptz default now(),
--           auth_user_id uuid)
--
-- Dos diferencias que importan: `usuario` NO tiene columna "user" (los
-- scripts 09/11 y usuarios.html la usaban, y por eso el alta de usuarios
-- fallaba), y ningún `identificador` se genera solo, así que todo insert
-- tiene que proveerlo.
--
-- IMPORTANTE — ORDEN: no corras este script hasta que login.html esté
-- publicado en Vercel y hayas confirmado que podés entrar con tu cuenta. Si
-- lo corrés antes, el panel deja de mostrar datos (como pasó la vez
-- anterior), porque el sitio publicado entraría como anónimo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Tablas de roles y perfiles.
-- Las creaste a mano desde el Table Editor, así que no estaban en ningún
-- script. Quedan acá, con la forma que tienen hoy, para que el proyecto se
-- pueda reconstruir de cero. Si ya existen, estas sentencias no las tocan.
-- ---------------------------------------------------------------------
create table if not exists public.roles (
  identificador integer primary key,
  descripcion   varchar not null unique
);

-- Ojo con `identificador`: no es un id propio de la tabla, es el id de la
-- cuenta en auth.users (tiene una clave foránea que lo obliga). O sea que la
-- tabla ya vinculaba el perfil con la cuenta por ahí, y el script 09 agregó
-- `auth_user_id` como segundo vínculo a lo mismo. Quedan las dos columnas
-- porque el panel usa `auth_user_id`, pero las dos deben valer igual: por eso
-- todo insert de acá en adelante escribe el mismo uuid en ambas.
create table if not exists public.usuario (
  identificador uuid primary key references auth.users(id) on delete cascade,
  rol_id        integer not null references public.roles(identificador),
  nombre        varchar not null,
  activo        boolean not null default true,
  creado_en     timestamptz not null default now(),
  auth_user_id  uuid unique references auth.users(id) on delete cascade
);

-- Los 3 roles. Solo inserta los que falten, y calcula el identificador a
-- mano porque la columna no tiene default (en la base ya están como
-- 1=admin, 2=editor, 3=visor, así que normalmente esto no inserta nada).
insert into public.roles (identificador, descripcion)
select (select coalesce(max(identificador), 0) from public.roles) + row_number() over (order by v.d),
       v.d
from (values ('admin'), ('editor'), ('visor')) as v(d)
where not exists (
  select 1 from public.roles r where r.descripcion = v.d
);

-- Rellena `auth_user_id` en los perfiles que lo tengan vacío, copiándolo de
-- `identificador`. Es exactamente el caso del perfil que ya existe cargado a
-- mano: tiene el uuid correcto en `identificador` (2cb308f1-…, la cuenta de
-- Valeria) pero `auth_user_id` en null, así que el panel lo busca por esa
-- columna, no lo encuentra, y trata la cuenta como si no tuviera rol.
-- Es seguro y determinista: la clave foránea de `identificador` garantiza que
-- ese uuid es una cuenta real de auth.users, así que no hace falta adivinar
-- nada por nombre.
update public.usuario
   set auth_user_id = identificador
 where auth_user_id is null;


-- ---------------------------------------------------------------------
-- 2) Funciones que responden "¿quién sos y qué podés hacer?".
--
-- Van con security definer para poder leer `usuario` y `roles` sin quedar
-- atrapadas en las políticas RLS de esas mismas tablas (si no, para saber tu
-- rol habría que leer tu fila, y para leer tu fila habría que saber tu rol:
-- recursión infinita). El search_path fijo evita que alguien las redirija a
-- tablas suyas.
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
  where (u.auth_user_id = auth.uid() or u.identificador = auth.uid())
    and u.activo;
$$;

-- ¿El usuario actual puede modificar datos? Solo admin y editor.
-- coalesce: si no tiene perfil, está inactivo o no tiene rol, mi_rol()
-- devuelve null y la respuesta es "no". El default es negar, no permitir.
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
-- 3) Fuera TODAS las políticas viejas de estas cuatro tablas.
--
-- Se borran en bloque, y no por nombre, por una razón concreta: en la base
-- había políticas (auth_insert_oportunidades, auth_update_oportunidades,
-- auth_delete_oportunidades y sus gemelas de entregables) que no las creó
-- ninguno de los scripts de esta carpeta, así que un `drop policy if exists`
-- con una lista escrita a mano no las hubiera tocado.
--
-- Dejar una sola de esas sueltas rompe todo el esquema de roles, porque las
-- políticas de una tabla se combinan con O, no con Y: alcanza que UNA diga
-- sí para que el permiso pase. Una política de INSERT abierta a cualquier
-- logueado le habría dado a un visor el mismo poder que a un admin, y encima
-- en silencio, sin ningún error a la vista.
--
-- Por eso: tabla rasa primero, y después solo lo que este script define.
-- ---------------------------------------------------------------------
do $$
declare
  p record;
begin
  for p in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('oportunidades', 'entregables', 'usuario', 'roles')
  loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 4) Oportunidades y entregables.
-- Leer: cualquiera que haya iniciado sesión (los 3 roles).
-- Escribir: solo admin y editor.
--
-- Se separan insert / update / delete en vez de usar "for all" para que
-- quede explícito qué se está permitiendo.
-- ---------------------------------------------------------------------
alter table public.oportunidades enable row level security;

create policy "oportunidades_select_logueado" on public.oportunidades
  for select to authenticated using (true);
create policy "oportunidades_insert_editor" on public.oportunidades
  for insert to authenticated with check (public.puede_editar());
create policy "oportunidades_update_editor" on public.oportunidades
  for update to authenticated using (public.puede_editar()) with check (public.puede_editar());
create policy "oportunidades_delete_editor" on public.oportunidades
  for delete to authenticated using (public.puede_editar());

alter table public.entregables enable row level security;

create policy "entregables_select_logueado" on public.entregables
  for select to authenticated using (true);
create policy "entregables_insert_editor" on public.entregables
  for insert to authenticated with check (public.puede_editar());
create policy "entregables_update_editor" on public.entregables
  for update to authenticated using (public.puede_editar()) with check (public.puede_editar());
create policy "entregables_delete_editor" on public.entregables
  for delete to authenticated using (public.puede_editar());


-- ---------------------------------------------------------------------
-- 5) Perfiles y catálogo de roles.
-- Cada uno ve su propia fila (el panel la necesita para saber su rol y
-- mostrar el nombre en el header). El admin ve y edita todas, que es lo que
-- hace funcionar usuarios.html.
-- ---------------------------------------------------------------------
alter table public.usuario enable row level security;
alter table public.roles   enable row level security;

-- Las políticas de un mismo comando se combinan con OR: cada quien ve la
-- suya, y el admin además ve todas.
create policy "usuario_select_propio" on public.usuario
  for select to authenticated using (auth_user_id = auth.uid() or identificador = auth.uid());
create policy "usuario_select_admin" on public.usuario
  for select to authenticated using (public.es_admin());
create policy "usuario_write_admin" on public.usuario
  for all to authenticated using (public.es_admin()) with check (public.es_admin());

create policy "roles_select_authenticated" on public.roles
  for select to authenticated using (true);


-- =====================================================================
-- 6) VINCULAR TU CUENTA CON TU PERFIL DE ADMIN.
--
-- En la base ya existe la cuenta de acceso (Authentication > Users) y ya
-- existe el perfil "Valeria Rodriguez" con rol admin, pero están
-- desconectados: la fila de `usuario` tiene auth_user_id en null. El panel
-- busca el perfil por auth_user_id, no lo encuentra, y trata a la cuenta
-- como si no tuviera rol. Sin este paso te quedás en solo lectura y sin
-- acceso a la gestión de usuarios.
--
-- Corré la línea del final (ya viene con tu correo). De ahí en más, los
-- demás usuarios los das de alta desde usuarios.html, sin tocar SQL.
-- =====================================================================

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
  v_rol_id integer;
  v_perfil uuid;
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

  -- ¿Ya hay un perfil para esta cuenta? Se busca por las dos columnas que la
  -- referencian, así que no hace falta adivinar por nombre: cualquiera de las
  -- dos que esté cargada identifica la fila sin ambigüedad.
  select identificador into v_perfil
  from public.usuario
  where auth_user_id = v_uid or identificador = v_uid;

  if v_perfil is null then
    -- identificador NO se genera al azar: tiene una clave foránea contra
    -- auth.users(id), así que tiene que ser el uuid de la cuenta. Se escribe
    -- el mismo valor en las dos columnas para que queden consistentes.
    insert into public.usuario (identificador, auth_user_id, nombre, rol_id)
    values (v_uid, v_uid, p_nombre, v_rol_id);
    return p_nombre || ' se creó y quedó vinculado con el rol ' || p_rol || '.';
  end if;

  update public.usuario
     set auth_user_id = v_uid,
         nombre       = p_nombre,
         rol_id       = v_rol_id,
         activo       = true
   where identificador = v_perfil;

  return p_nombre || ' quedó vinculado con el rol ' || p_rol || '.';
end;
$$;

select public.vincular_usuario('vrodriguez@friopacking.pe', 'Valeria Rodriguez', 'admin');
