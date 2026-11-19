-- =====================================================================
-- TEST 01 · Prueba integral de Gestión Comercial con datos ficticios
--
-- QUÉ HACE
--   Ejecuta, en la base REAL y con las reglas REALES (RLS + trigger
--   gcm_control + función gcm_aprobar_conversion), los flujos Lead →
--   Oportunidad de Perú y Colombia suplantando a las cuentas que YA existen:
--     Valeria Rodríguez (admin) · Misael Estrada (gerencia)
--     Hugo Escobar y Jhon Rojas (ejecutivos Perú) · Vivian Castrillón (ejecutiva Colombia)
--   Cada paso corre con `set local role authenticated` y el JWT de esa
--   persona, igual que si lo hiciera desde su navegador. No crea cuentas,
--   no cambia contraseñas ni perfiles.
--
-- DATOS TEST (aislados y reconocibles)
--   · gestion_comercial: ids 'TEST-…' y datos.test = true
--   · clientes: 'CLI-TEST-PE' y 'CLI-TEST-CO' (nombre «ZZ TEST · …»). El
--     correlativo CLI-xxxx del panel los ignora (cliNumero = 0).
--   · oportunidades: UNA en Perú (la crea la aprobación), proyecto
--     «[TEST] …», cliente_id 'CLI-TEST-PE', importe US$ 1, probabilidad 10 %.
--     Mientras exista, suma 1 registro / US$ 1 al Planner Perú: correr
--     TEST_99_limpiar.sql al terminar la verificación.
--   · historial_oportunidades: el evento 'conv-TEST-SC-PE' de esa oportunidad.
--
-- CÓMO SE USA
--   1. Supabase → SQL Editor → pegar este archivo completo → Run.
--   2. El resultado es la matriz de casos (columna «resultado»:
--      FUNCIONA / FALLA). Copiarla o exportarla.
--   3. Con los datos TEST ya en la nube, hacer la verificación en sesiones
--      reales (ver PRUEBA_INTEGRAL_TEST.md, sección «Verificación en sesiones»).
--   4. Al terminar: TEST_99_limpiar.sql.
--
-- Si ya hay datos TEST de una corrida anterior, el script se detiene sin
-- tocar nada: limpiar primero con TEST_99_limpiar.sql.
-- Requiere 28, 30 y 31 aplicados (lo verifica).
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0) Requisitos y tope de seguridad
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.gestion_comercial') is null then raise exception 'Falta 30_gestion_comercial.sql.'; end if;
  if to_regprocedure('public.gcm_aprobar_conversion(text,text)') is null then raise exception 'Falta 31_perfiles_permisos.sql.'; end if;
  if to_regclass('public.clientes') is null then raise exception 'Falta 28_clientes_maestra.sql.'; end if;
  if exists (select 1 from public.gestion_comercial where id like 'TEST-%' or datos ->> 'test' = 'true')
     or exists (select 1 from public.clientes where id_cliente like 'CLI-TEST-%')
     or exists (select 1 from public.oportunidades where cliente_id like 'CLI-TEST-%') then
    raise exception 'Ya hay datos TEST de una corrida anterior. Corré primero TEST_99_limpiar.sql.';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1) Cuentas existentes (no se crean). Se detiene si falta alguna o si su
--    perfil no es el esperado.
-- ---------------------------------------------------------------------
drop table if exists pg_temp._u;
create temporary table _u (clave text primary key, nombre text, uid uuid, rol text, pais text, codigo text, activo boolean);
insert into _u (clave, nombre)
values ('valeria', 'Valeria Rodríguez'), ('misael', 'Misael Estrada'),
       ('hugo', 'Hugo Escobar'), ('jhon', 'Jhon Rojas'), ('vivian', 'Vivian Castrillón');

update _u set uid = public.uid_por_nombre(_u.nombre);
update _u set rol = r.descripcion, pais = u.pais, codigo = u.codigo_comercial, activo = u.activo,
              uid = coalesce(u.auth_user_id, u.identificador)
  from public.usuario u join public.roles r on r.identificador = u.rol_id
 where u.identificador = _u.uid or u.auth_user_id = _u.uid;

do $$
declare x record; v_esp text;
begin
  for x in select * from _u loop
    v_esp := case x.clave when 'valeria' then 'admin/ambos' when 'misael' then 'gerencia/ambos'
                          when 'vivian' then 'ejecutivo/colombia' else 'ejecutivo/peru' end;
    if x.uid is null then
      raise exception 'No se encontró una única cuenta para «%». No se carga nada.', x.nombre;
    end if;
    if coalesce(x.rol, '') || '/' || coalesce(x.pais, '') <> v_esp or not coalesce(x.activo, false) then
      raise exception 'La cuenta de «%» es %/% (activa: %) y la prueba espera % activa. Revisar el perfil en usuarios.html.',
        x.nombre, x.rol, x.pais, x.activo, v_esp;
    end if;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 2) Utilidades de la prueba (temporales: desaparecen al cerrar la sesión)
-- ---------------------------------------------------------------------
-- Ejecuta p_sql como la cuenta p_uid (rol authenticated + su JWT) y devuelve
-- el único valor de texto que produce la consulta, o 'ERR <código>: <mensaje>'.
-- Un error deshace solo ese paso (subtransacción).
create or replace function pg_temp.como(p_uid uuid, p_sql text) returns text
language plpgsql as $f$
declare v text;
begin
  begin
    perform set_config('app.gcm_rpc', 'off', true);
    perform set_config('request.jwt.claim.sub', p_uid::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
    execute p_sql into v;
    execute 'reset role';
    perform set_config('app.gcm_rpc', 'off', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claims', '', true);
    return coalesce(v, 'null');
  exception when others then
    return 'ERR ' || sqlstate || ': ' || sqlerrm;
  end;
end $f$;

create or replace function pg_temp.uid(p text) returns uuid language sql as $f$ select uid from _u where clave = p $f$;

drop table if exists pg_temp._res;
create temporary table _res (n serial, flujo text, caso text, usuario text, esperado text, obtenido text, resultado text);

-- Registra un caso. p_ok: ¿el resultado es el esperado?
create or replace function pg_temp.chk(p_flujo text, p_caso text, p_usuario text, p_esperado text, p_obtenido text, p_ok boolean)
returns void language sql as $f$
  insert into _res (flujo, caso, usuario, esperado, obtenido, resultado)
  values (p_flujo, p_caso, p_usuario, p_esperado, left(p_obtenido, 300), case when p_ok then 'FUNCIONA' else 'FALLA' end);
$f$;

-- Plantillas SQL (lo que hace el panel: upsert / update de la fila).
create or replace function pg_temp.sql_insert(p_id text, p_tipo text, p_pais text, p_resp text, p_datos jsonb) returns text
language sql as $f$
  select format($q$with x as (insert into public.gestion_comercial (id, tipo, pais, responsable, datos, creado_por)
                   values (%L, %L, %L, %L, %L::jsonb, %L) returning 1) select count(*)::text from x$q$,
                p_id, p_tipo, p_pais, p_resp, p_datos::text, p_resp);
$f$;
create or replace function pg_temp.sql_merge(p_id text, p_cambio jsonb) returns text
language sql as $f$
  select format($q$with x as (update public.gestion_comercial set datos = datos || %L::jsonb, actualizado_en = now()
                   where id = %L returning 1) select count(*)::text from x$q$, p_cambio::text, p_id);
$f$;
create or replace function pg_temp.sql_ver(p_id text) returns text
language sql as $f$ select format('select count(*)::text from public.gestion_comercial where id = %L', p_id); $f$;


-- ---------------------------------------------------------------------
-- 3) Flujos
-- ---------------------------------------------------------------------
do $$
declare
  hoy   text := to_char(now() at time zone 'America/Lima', 'YYYY-MM-DD');
  ahora text := to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
  r     text;
  v_op  text;
  v_opco text;
  campos jsonb := '{"tipoProyecto":"Cámara de frío","importe":"1","probabilidad":"10","mesCierre":"2027-06","segmento":"no_agro","sector":"Otros","duracion":"3","seguimiento":"[TEST] Dato ficticio de prueba integral"}';

  -- ---------- Perú ----------
  cli_pe text := format($q$with x as (insert into public.clientes (id_cliente, nombre, nombre_clave, creado_por)
                 values ('CLI-TEST-PE', 'ZZ TEST · Cliente ficticio Perú', 'ZZTESTCLIENTEFICTICIOPERU', 'Hugo Escobar') returning 1)
                 select count(*)::text from x$q$);
  cli_co text := format($q$with x as (insert into public.clientes (id_cliente, nombre, nombre_clave, creado_por)
                 values ('CLI-TEST-CO', 'ZZ TEST · Cliente ficticio Colombia', 'ZZTESTCLIENTEFICTICIOCOLOMBIA', 'Vivian Castrillón') returning 1)
                 select count(*)::text from x$q$);
begin
  -- ===== FLUJO 1 · PERÚ =====
  r := pg_temp.como(pg_temp.uid('hugo'), cli_pe);
  perform pg_temp.chk('1 Perú', 'Ejecutivo registra un cliente nuevo en la Base Maestra', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_insert('TEST-CT-PE', 'contacto', 'peru', 'Hugo Escobar', jsonb_build_object(
        'id','TEST-CT-PE','_t','contacto','pais','peru','test',true,'empresaId','CLI-TEST-PE','nombre','[TEST] Contacto ficticio Perú',
        'cargo','Jefe de planta (ficticio)','tel','','email','','ejecutivo','Hugo Escobar','zona','','sedeId','','compartido','[]'::jsonb)));
  perform pg_temp.chk('1 Perú', 'Ejecutivo crea contacto', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_insert('TEST-LD-PE', 'lead', 'peru', 'Hugo Escobar', jsonb_build_object(
        'id','TEST-LD-PE','_t','lead','pais','peru','test',true,'empresaId','CLI-TEST-PE','contactoId','TEST-CT-PE',
        'titulo','[TEST] Cámara de frío ficticia Perú','ejecutivo','Hugo Escobar','estado','Nuevo','origen','Visita',
        'creado',ahora,'calif','','opId','','campos',campos,'conversion',null,
        'hist',jsonb_build_array(jsonb_build_object('f',ahora,'por','Hugo Escobar','accion','Lead registrado','nota','[TEST]')))));
  perform pg_temp.chk('1 Perú', 'Ejecutivo crea lead', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_insert('TEST-AC-PE', 'actividad', 'peru', 'Hugo Escobar', jsonb_build_object(
        'id','TEST-AC-PE','_t','actividad','pais','peru','test',true,'tipo','Visita','cat','Prospección','fecha',hoy,'hora','10:00',
        'ejecutivo','Hugo Escobar','empresaId','CLI-TEST-PE','contactoId','TEST-CT-PE','leadId','TEST-LD-PE',
        'titulo','[TEST] Visita técnica ficticia','estado','Programada','resultado','','comentarios','','compromisos','[]'::jsonb,
        'reprogDe','','motivo','','acuerdos','','porDefinir',false,'descarte','','reporte',null,'acomp','[]'::jsonb,'participantes','[]'::jsonb,
        'creadoPor','Hugo Escobar','historial',jsonb_build_array(jsonb_build_object('tipo','creada','por','Hugo Escobar','f',ahora)))));
  perform pg_temp.chk('1 Perú', 'Ejecutivo programa la visita', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-AC-PE', jsonb_build_object(
        'estado','Realizada','resultado','Positiva','comentarios','[TEST] Reporte ficticio','reporte',jsonb_build_object('f',ahora,'por','Hugo Escobar'))));
  perform pg_temp.chk('1 Perú', 'Ejecutivo registra el reporte de visita (Realizada)', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-LD-PE', '{"estado":"Calificado"}'));
  perform pg_temp.chk('1 Perú', 'Ejecutivo califica su lead', 'Hugo', '1', r, r = '1');

  -- Privacidad entre ejecutivos y alcance de supervisión
  r := pg_temp.como(pg_temp.uid('jhon'), pg_temp.sql_ver('TEST-LD-PE'));
  perform pg_temp.chk('5 Usuarios', 'Otro ejecutivo de Perú NO ve el lead de Hugo', 'Jhon', '0', r, r = '0');
  r := pg_temp.como(pg_temp.uid('jhon'), pg_temp.sql_merge('TEST-LD-PE', '{"titulo":"[TEST] intento de Jhon"}'));
  perform pg_temp.chk('5 Usuarios', 'Otro ejecutivo de Perú NO puede editar el lead de Hugo', 'Jhon', '0 filas o ERR', r, r = '0' or r like 'ERR%');
  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_ver('TEST-LD-PE'));
  perform pg_temp.chk('5 Usuarios', 'Ejecutiva de Colombia NO ve leads de Perú', 'Vivian', '0', r, r = '0');
  r := pg_temp.como(pg_temp.uid('misael'), pg_temp.sql_ver('TEST-LD-PE'));
  perform pg_temp.chk('5 Usuarios', 'Gerencia ve el lead', 'Misael', '1', r, r = '1');
  r := pg_temp.como(pg_temp.uid('valeria'), pg_temp.sql_ver('TEST-LD-PE'));
  perform pg_temp.chk('5 Usuarios', 'Administración ve el lead', 'Valeria', '1', r, r = '1');

  -- Solicitud de conversión
  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_insert('TEST-SC-PE-X', 'solicitud', 'peru', 'Hugo Escobar', jsonb_build_object(
        'id','TEST-SC-PE-X','_t','solicitud','pais','peru','test',true,'leadId','TEST-LD-PE','estado','Aprobada')));
  perform pg_temp.chk('5 Usuarios', 'Ejecutivo NO puede crear una solicitud ya «Aprobada»', 'Hugo', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_insert('TEST-SC-PE', 'solicitud', 'peru', 'Hugo Escobar', jsonb_build_object(
        'id','TEST-SC-PE','_t','solicitud','pais','peru','test',true,'leadId','TEST-LD-PE','empresaId','CLI-TEST-PE',
        'titulo','[TEST] Cámara de frío ficticia Perú','ejecutivo','Hugo Escobar','estado','Pendiente de validación','fecha',ahora,
        'solicitadoPor','Hugo Escobar','nota','[TEST]','campos',campos,
        'hist',jsonb_build_array(jsonb_build_object('f',ahora,'por','Hugo Escobar','accion','Conversión solicitada','nota','[TEST]')))));
  perform pg_temp.chk('1 Perú', 'Ejecutivo solicita la conversión (Pendiente de validación)', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-LD-PE', '{"estado":"Conversión solicitada","conversion":{"solicitudId":"TEST-SC-PE"}}'));
  perform pg_temp.chk('1 Perú', 'El lead pasa a «Conversión solicitada»', 'Hugo', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-LD-PE', '{"titulo":"[TEST] editado tras solicitar"}'));
  perform pg_temp.chk('5 Usuarios', 'Lead en solo consulta para el ejecutivo tras solicitar', 'Hugo', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('hugo'), $q$select public.gcm_aprobar_conversion('TEST-SC-PE', 'autoaprobación')::text$q$);
  perform pg_temp.chk('5 Usuarios', 'Ejecutivo NO puede aprobar su propia conversión (RPC)', 'Hugo', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-SC-PE', '{"estado":"Aprobada"}'));
  perform pg_temp.chk('5 Usuarios', 'Ejecutivo NO puede marcar su solicitud como Aprobada', 'Hugo', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_merge('TEST-SC-PE', '{"estado":"En aprobación"}'));
  perform pg_temp.chk('5 Usuarios', 'Ejecutivo NO puede validar su solicitud', 'Hugo', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('misael'), $q$select public.gcm_aprobar_conversion('TEST-SC-PE', '[TEST]')::text$q$);
  perform pg_temp.chk('5 Usuarios', 'Gerencia NO aprueba sin la validación previa de Valeria', 'Misael', 'ERR', r, r like 'ERR%');

  r := pg_temp.como(pg_temp.uid('misael'), pg_temp.sql_merge('TEST-SC-PE', '{"estado":"En aprobación"}'));
  perform pg_temp.chk('5 Usuarios', 'Gerencia NO puede validar (solo administración)', 'Misael', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('valeria'), pg_temp.sql_merge('TEST-SC-PE', jsonb_build_object(
        'estado','En aprobación','validadoPor','Valeria Rodríguez','validadoEn',ahora)));
  perform pg_temp.chk('1 Perú', 'Valeria valida la solicitud (En aprobación)', 'Valeria', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('misael'), $q$select public.gcm_aprobar_conversion('TEST-SC-PE', '[TEST] aprobación de prueba')::text$q$);
  v_op := case when r like '{%' then r::jsonb ->> 'opId' end;
  perform pg_temp.chk('1 Perú', 'Misael aprueba la conversión (RPC)', 'Misael', 'opId numérico', r, v_op ~ '^\d+$');

  if v_op ~ '^\d+$' then
    r := (select count(*)::text from public.oportunidades
           where "Identificador" = v_op::int and pais = 'peru' and cliente_id = 'CLI-TEST-PE'
             and proyecto = '[TEST] Cámara de frío ficticia Perú' and kam = (select codigo from _u where clave = 'hugo') and etapa = 'prospecto');
    perform pg_temp.chk('1 Perú', 'Oportunidad #'||v_op||' en Planner Perú (KAM Hugo, etapa Prospecto, cliente TEST)', 'BD', '1', r, r = '1');
    r := (select count(*)::text from public.historial_oportunidades where id = 'conv-TEST-SC-PE' and oportunidad_identificador = v_op::int);
    perform pg_temp.chk('1 Perú', 'Historial de la oportunidad registra la conversión', 'BD', '1', r, r = '1');
    r := (select (datos ->> 'estado') || '/' || (datos ->> 'opId') from public.gestion_comercial where id = 'TEST-LD-PE');
    perform pg_temp.chk('1 Perú', 'Lead queda «Convertido» con el número de oportunidad', 'BD', 'Convertido/'||v_op, r, r = 'Convertido/'||v_op);
    r := pg_temp.como(pg_temp.uid('hugo'), format('select count(*)::text from public.oportunidades where "Identificador" = %s', v_op));
    perform pg_temp.chk('1 Perú', 'El ejecutivo ve la oportunidad en Planner Perú', 'Hugo', '1', r, r = '1');
    r := pg_temp.como(pg_temp.uid('hugo'), format($q$with x as (update public.oportunidades set proximo_paso = 'intento' where "Identificador" = %s returning 1) select count(*)::text from x$q$, v_op));
    perform pg_temp.chk('5 Usuarios', 'El ejecutivo NO edita la oportunidad (Planner solo consulta)', 'Hugo', '0 filas o ERR', r, r = '0' or r like 'ERR%');
    r := pg_temp.como(pg_temp.uid('vivian'), format('select count(*)::text from public.oportunidades where "Identificador" = %s', v_op));
    perform pg_temp.chk('5 Usuarios', 'Ejecutiva de Colombia NO ve el Planner Perú', 'Vivian', '0', r, r = '0');
  end if;

  r := pg_temp.como(pg_temp.uid('valeria'), $q$select public.gcm_aprobar_conversion('TEST-SC-PE', 'doble')::text$q$);
  perform pg_temp.chk('1 Perú', 'Aprobar dos veces no duplica la oportunidad', 'Valeria', 'yaAprobada', r, r like '%yaAprobada%');

  -- ===== FLUJO 2 · COLOMBIA =====
  r := pg_temp.como(pg_temp.uid('vivian'), cli_co);
  perform pg_temp.chk('2 Colombia', 'Ejecutiva registra un cliente nuevo en la Base Maestra', 'Vivian', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_insert('TEST-CT-CO-X', 'contacto', 'peru', 'Vivian Castrillón', jsonb_build_object(
        'id','TEST-CT-CO-X','_t','contacto','pais','peru','test',true,'nombre','[TEST] contacto en país ajeno')));
  perform pg_temp.chk('5 Usuarios', 'Ejecutiva de Colombia NO registra datos en Perú', 'Vivian', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_insert('TEST-CT-CO', 'contacto', 'colombia', 'Vivian Castrillón', jsonb_build_object(
        'id','TEST-CT-CO','_t','contacto','pais','colombia','test',true,'empresaId','CLI-TEST-CO','nombre','[TEST] Contacto ficticio Colombia',
        'cargo','Gerente de operaciones (ficticio)','tel','','email','','ejecutivo','Vivian Castrillón','zona','','sedeId','','compartido','[]'::jsonb)));
  perform pg_temp.chk('2 Colombia', 'Ejecutiva crea contacto', 'Vivian', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_insert('TEST-LD-CO', 'lead', 'colombia', 'Vivian Castrillón', jsonb_build_object(
        'id','TEST-LD-CO','_t','lead','pais','colombia','test',true,'empresaId','CLI-TEST-CO','contactoId','TEST-CT-CO',
        'titulo','[TEST] Túnel de congelado ficticio Colombia','ejecutivo','Vivian Castrillón','estado','Nuevo','origen','Visita',
        'creado',ahora,'calif','','opId','','campos',jsonb_set(campos, '{tipoProyecto}', '"Túnel de congelado"'),'conversion',null,
        'hist',jsonb_build_array(jsonb_build_object('f',ahora,'por','Vivian Castrillón','accion','Lead registrado','nota','[TEST]')))));
  perform pg_temp.chk('2 Colombia', 'Ejecutiva crea lead', 'Vivian', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_insert('TEST-AC-CO', 'actividad', 'colombia', 'Vivian Castrillón', jsonb_build_object(
        'id','TEST-AC-CO','_t','actividad','pais','colombia','test',true,'tipo','Visita','cat','Prospección','fecha',hoy,'hora','15:00',
        'ejecutivo','Vivian Castrillón','empresaId','CLI-TEST-CO','contactoId','TEST-CT-CO','leadId','TEST-LD-CO',
        'titulo','[TEST] Visita ficticia Colombia','estado','Realizada','resultado','Positiva','comentarios','[TEST] Reporte ficticio',
        'compromisos','[]'::jsonb,'reprogDe','','motivo','','acuerdos','','porDefinir',false,'descarte','',
        'reporte',jsonb_build_object('f',ahora,'por','Vivian Castrillón'),'acomp','[]'::jsonb,'participantes','[]'::jsonb,
        'creadoPor','Vivian Castrillón','historial',jsonb_build_array(jsonb_build_object('tipo','realizada','por','Vivian Castrillón','f',ahora)))));
  perform pg_temp.chk('2 Colombia', 'Ejecutiva registra la visita realizada', 'Vivian', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('hugo'), pg_temp.sql_ver('TEST-LD-CO'));
  perform pg_temp.chk('5 Usuarios', 'Ejecutivo de Perú NO ve leads de Colombia', 'Hugo', '0', r, r = '0');

  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_insert('TEST-SC-CO', 'solicitud', 'colombia', 'Vivian Castrillón', jsonb_build_object(
        'id','TEST-SC-CO','_t','solicitud','pais','colombia','test',true,'leadId','TEST-LD-CO','empresaId','CLI-TEST-CO',
        'titulo','[TEST] Túnel de congelado ficticio Colombia','ejecutivo','Vivian Castrillón','estado','Pendiente de validación','fecha',ahora,
        'solicitadoPor','Vivian Castrillón','nota','[TEST]','campos',campos,
        'hist',jsonb_build_array(jsonb_build_object('f',ahora,'por','Vivian Castrillón','accion','Conversión solicitada','nota','[TEST]')))));
  perform pg_temp.chk('2 Colombia', 'Ejecutiva solicita la conversión', 'Vivian', '1', r, r = '1');
  r := pg_temp.como(pg_temp.uid('vivian'), pg_temp.sql_merge('TEST-LD-CO', '{"estado":"Conversión solicitada","conversion":{"solicitudId":"TEST-SC-CO"}}'));
  perform pg_temp.chk('2 Colombia', 'El lead pasa a «Conversión solicitada»', 'Vivian', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('vivian'), $q$select public.gcm_aprobar_conversion('TEST-SC-CO', 'autoaprobación')::text$q$);
  perform pg_temp.chk('5 Usuarios', 'Ejecutiva NO puede aprobar su propia conversión (RPC)', 'Vivian', 'ERR 42501', r, r like 'ERR 42501%');

  r := pg_temp.como(pg_temp.uid('valeria'), pg_temp.sql_merge('TEST-SC-CO', jsonb_build_object(
        'estado','En aprobación','validadoPor','Valeria Rodríguez','validadoEn',ahora)));
  perform pg_temp.chk('2 Colombia', 'Valeria valida la solicitud', 'Valeria', '1', r, r = '1');

  r := pg_temp.como(pg_temp.uid('valeria'), $q$select public.gcm_aprobar_conversion('TEST-SC-CO', '[TEST] aprobación de prueba')::text$q$);
  v_opco := case when r like '{%' then r::jsonb ->> 'opId' end;
  perform pg_temp.chk('2 Colombia', 'Valeria aprueba la conversión (RPC)', 'Valeria', 'sin error', r, r not like 'ERR%');
  perform pg_temp.chk('2 Colombia', 'La aprobación crea la oportunidad en un Planner Colombia compartido',
    'BD', 'opId numérico', coalesce(r, 'null') || ' · no existe tabla de Planner Colombia en la base',
    coalesce(v_opco, '') ~ '^\d+$');

  r := (select datos ->> 'estado' from public.gestion_comercial where id = 'TEST-LD-CO');
  perform pg_temp.chk('2 Colombia', 'Lead de Colombia queda «Convertido»', 'BD', 'Convertido', r, r = 'Convertido');
end $$;

commit;


-- ---------------------------------------------------------------------
-- 4) Matriz de resultados
-- ---------------------------------------------------------------------
select n, flujo, caso, usuario, esperado, obtenido, resultado from _res order by n;
