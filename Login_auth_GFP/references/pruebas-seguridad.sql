-- pruebas-seguridad.sql
-- Pruebas de RLS y autorización (casos 1-8 de la sección 46 + extras).
-- Ejecutar SOLO en base local o de pruebas, nunca en producción:
--   supabase start && supabase db reset
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f pruebas-seguridad.sql
-- Todo corre en una transacción que termina en ROLLBACK: no deja datos.
-- Si una prueba falla, el script se detiene mostrando "FALLO: ...".
-- El caso 9 (no autenticado -> /usuarios redirige a /login) se prueba en el navegador.

\set ON_ERROR_STOP on
begin;

-- Sesión simulada: lo mismo que hace PostgREST con el JWT del usuario
create function pg_temp.login(uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
end $$;

-- ------------------------------------------------------------ datos de prueba
insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000001', 'admin@test.local',  '{"name":"Ana","last_name":"Admin"}', 'authenticated', 'authenticated'),
  -- intenta autoasignarse Admin vía metadata: debe ignorarse
  ('00000000-0000-0000-0000-000000000002', 'editor@test.local', '{"name":"Eva","last_name":"Editor","role":"Admin"}', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000000003', 'viewer@test.local', '{"name":"Vic","last_name":"Viewer"}', 'authenticated', 'authenticated');

do $$ begin
  if (select count(*) from public.users where email like '%@test.local') <> 3 then
    raise exception 'FALLO: el trigger no creó los perfiles';
  end if;
  if exists (select 1 from public.user_roles
             where user_id in ('00000000-0000-0000-0000-000000000001',
                               '00000000-0000-0000-0000-000000000002',
                               '00000000-0000-0000-0000-000000000003')
               and role_id <> 3) then
    raise exception 'FALLO: un usuario nuevo recibió un rol distinto de Visualizador';
  end if;
end $$;
\echo 'OK  registro crea perfil + Visualizador (metadata "role" ignorada)'

select public.bootstrap_admin('admin@test.local');
delete from public.user_roles where user_id = '00000000-0000-0000-0000-000000000001' and role_id = 3;
update public.user_roles set role_id = 2 where user_id = '00000000-0000-0000-0000-000000000002';

create table public.prueba_items (id serial primary key, nombre text);
select public.apply_crud_policies('public.prueba_items');
grant all on public.prueba_items to authenticated;
grant usage on sequence public.prueba_items_id_seq to authenticated;
insert into public.prueba_items (nombre) values ('item inicial');

-- ------------------------------------------------------------ Visualizador
select pg_temp.login('00000000-0000-0000-0000-000000000003');
set local role authenticated;

do $$ begin
  if (select count(*) from public.prueba_items) <> 1 then
    raise exception 'FALLO: Visualizador no puede consultar';
  end if;
end $$;
\echo 'OK  Visualizador consulta'

do $$ begin
  insert into public.prueba_items (nombre) values ('x');
  raise exception 'FALLO caso 1: Visualizador pudo hacer INSERT';
exception when insufficient_privilege then null;
end $$;
\echo 'OK  caso 1: Visualizador INSERT denegado'

do $$ declare n int; begin
  update public.prueba_items set nombre = 'x';
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLO caso 2: Visualizador pudo hacer UPDATE'; end if;
end $$;
\echo 'OK  caso 2: Visualizador UPDATE denegado'

do $$ declare n int; begin
  delete from public.prueba_items;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLO caso 3: Visualizador pudo hacer DELETE'; end if;
end $$;
\echo 'OK  caso 3: Visualizador DELETE denegado'

do $$ begin
  update public.users set is_active = false where id = auth.uid();
  raise exception 'FALLO: Visualizador cambió su propio estado';
exception when insufficient_privilege then null;
end $$;
do $$ declare n int; begin
  update public.users set name = 'Victor' where id = auth.uid();
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: Visualizador no puede editar su nombre en /perfil'; end if;
end $$;
\echo 'OK  perfil: edita nombre, no puede cambiar su estado'

reset role;

-- ------------------------------------------------------------ Editor
select pg_temp.login('00000000-0000-0000-0000-000000000002');
set local role authenticated;

insert into public.prueba_items (nombre) values ('creado por editor');
do $$ declare n int; begin
  update public.prueba_items set nombre = 'editado' where nombre = 'creado por editor';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: Editor no puede hacer UPDATE'; end if;
end $$;
\echo 'OK  Editor crea y edita'

do $$ declare n int; begin
  delete from public.prueba_items;
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLO caso 4: Editor pudo hacer DELETE'; end if;
end $$;
\echo 'OK  caso 4: Editor DELETE denegado'

do $$ declare n int; begin
  if (select count(*) from public.users) <> 1 then
    raise exception 'FALLO caso 5: Editor ve perfiles de otros usuarios';
  end if;
  update public.users set is_active = false where id = '00000000-0000-0000-0000-000000000003';
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLO caso 5: Editor desactivó a otro usuario'; end if;
end $$;
\echo 'OK  caso 5: Editor no administra usuarios'

do $$ begin
  insert into public.user_roles (user_id, role_id) values (auth.uid(), 1);
  raise exception 'FALLO caso 8: Editor se asignó Admin (INSERT)';
exception when insufficient_privilege then null;
end $$;
do $$ declare n int; begin
  update public.user_roles set role_id = 1 where user_id = auth.uid();
  get diagnostics n = row_count;
  if n > 0 then raise exception 'FALLO caso 8: Editor se asignó Admin (UPDATE)'; end if;
  if public.is_admin() then raise exception 'FALLO caso 8: Editor es Admin'; end if;
  begin
    perform public.set_user_role(auth.uid(), 1::smallint);
    raise exception 'FALLO caso 8: Editor se asignó Admin (set_user_role)';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo 'OK  caso 8: Editor no puede asignarse Admin'

reset role;

-- ------------------------------------------------------------ Admin
-- Caso 6: la credencial la crea la Edge Function (auth.admin.createUser con service role).
-- Aquí se simula ese alta y se verifica que el Admin puede completar perfil y rol.
insert into auth.users (id, email, raw_user_meta_data, aud, role) values
  ('00000000-0000-0000-0000-000000000004', 'nuevo@test.local', '{"name":"Nuevo"}', 'authenticated', 'authenticated');

select pg_temp.login('00000000-0000-0000-0000-000000000001');
set local role authenticated;

do $$ declare n int; begin
  update public.users set last_name = 'Usuario' where id = '00000000-0000-0000-0000-000000000004';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO caso 6: Admin no puede editar usuario nuevo'; end if;
  update public.user_roles set role_id = 2 where user_id = '00000000-0000-0000-0000-000000000004';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO caso 6: Admin no puede asignar rol a usuario nuevo'; end if;
end $$;
\echo 'OK  caso 6: Admin crea/completa usuario'

do $$ declare n int; begin
  update public.user_roles set role_id = 2 where user_id = '00000000-0000-0000-0000-000000000003';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO caso 7: Admin no puede cambiar rol'; end if;
  update public.user_roles set role_id = 3 where user_id = '00000000-0000-0000-0000-000000000003';
  perform public.set_user_role('00000000-0000-0000-0000-000000000003', 2::smallint);
  if (select array_agg(role_id) from public.user_roles
      where user_id = '00000000-0000-0000-0000-000000000003') <> array[2::smallint] then
    raise exception 'FALLO caso 7: set_user_role no dejó un único rol Editor';
  end if;
  perform public.set_user_role('00000000-0000-0000-0000-000000000003', 3::smallint);
end $$;
\echo 'OK  caso 7: Admin cambia rol'

do $$ declare n int; begin
  delete from public.prueba_items where nombre = 'item inicial';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'FALLO: Admin no puede hacer DELETE'; end if;
end $$;
\echo 'OK  Admin DELETE permitido'

do $$ begin
  delete from public.user_roles where user_id = auth.uid() and role_id = 1;
  raise exception 'FALLO: se eliminó al último Admin';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  perform public.set_user_role(auth.uid(), 3::smallint);
  raise exception 'FALLO: el último Admin se degradó con set_user_role';
exception when insufficient_privilege then null;
end $$;
do $$ begin
  update public.users set is_active = false where id = auth.uid();
  raise exception 'FALLO: el Admin se desactivó a sí mismo';
exception when insufficient_privilege then null;
end $$;
\echo 'OK  no se puede quedar el sistema sin Admin activo'

update public.users set is_active = false where id = '00000000-0000-0000-0000-000000000002';
reset role;

-- ------------------------------------------------------------ Usuario desactivado
select pg_temp.login('00000000-0000-0000-0000-000000000002');
set local role authenticated;
do $$ begin
  if (select count(*) from public.prueba_items) <> 0 then
    raise exception 'FALLO: usuario desactivado sigue leyendo datos';
  end if;
  begin
    insert into public.prueba_items (nombre) values ('x');
    raise exception 'FALLO: usuario desactivado pudo hacer INSERT';
  exception when insufficient_privilege then null;
  end;
end $$;
\echo 'OK  usuario desactivado sin acceso'
reset role;

-- ------------------------------------------------------------ Anónimo
set local role anon;
do $$ begin
  perform 1 from public.users;
  raise exception 'FALLO: anon puede leer public.users';
exception when insufficient_privilege then null;
end $$;
\echo 'OK  anónimo sin acceso a users'
reset role;

\echo ''
\echo 'TODAS LAS PRUEBAS PASARON'
rollback;
