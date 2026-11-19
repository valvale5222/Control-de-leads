-- =====================================================================
-- 31: Perfiles y permisos — Fase 1
--
-- Perfiles (tabla `roles`, sin tocar los que ya existen):
--
--   admin                 Administrador (Valeria). Todo, Perú + Colombia.
--                         Usuarios, eliminación definitiva, valida y aprueba
--                         conversiones.
--   gerencia     (nuevo)  Gerencia (Misael). Perú + Colombia, consulta todo,
--                         aprueba conversiones. Oportunidades en solo lectura.
--                         Sin usuarios ni eliminación.
--   ejecutivo    (nuevo)  Ejecutivo comercial (Hugo, Jhon, Víctor, Vivian).
--                         Solo su país. Planner: consulta TODAS las
--                         oportunidades de su país, como un visor (sin
--                         editar). Gestión Comercial: edita sus leads, agenda,
--                         visitas y tareas (privados) y solicita conversiones.
--   visor                 Visor técnico: consulta, como hasta ahora.
--   operativo_restringido Visor técnico restringido (Ingeniería / Presupuestos):
--                         áreas y vistas configurables; acciones limitadas a
--                         consulta.
--   editor                Se conserva tal cual (perfil anterior).
--
-- Regla Lead -> Oportunidad:
--   · El ejecutivo administra su lead hasta solicitar la conversión
--     (tipo 'solicitud' en gestion_comercial, estado «Pendiente de validación»).
--     Desde ahí el lead queda en solo consulta para él.
--   · Valeria (admin) valida («En aprobación») o devuelve («Devuelta»).
--   · Valeria o Misael aprueban: gcm_aprobar_conversion() crea la oportunidad
--     en el Planner de Perú (KAM = el ejecutivo) y marca el lead «Convertido».
--     El ejecutivo la consulta; Valeria la sigue administrando en Planner.
--   · El rol del ejecutivo NO pasa a visor: la restricción va por registro.
--
-- Qué se agrega:
--   usuario.pais              'peru' | 'colombia' | 'ambos' (ambos: solo admin y gerencia)
--   usuario.codigo_comercial  clave de KAM con la que figura en las oportunidades
--                             (hugo_escobar, co_vivian_castrillon…)
--   gestion_comercial.propietario_uid  dueño del registro (ejecutivo)
--   gestion_comercial.compartido_uids  quién más lo ve (acompañantes de visita,
--                             gestión compartida, dueño del lead vinculado)
--   Funciones de perfil, RLS por perfil / país / propietario, un trigger que
--   aplica las reglas por campo y acción, la aprobación de conversiones y la
--   activación / desactivación de cuentas (sin borrar historial).
--
-- No se toca: Planner (oportunidades/entregables siguen editables solo por
-- admin y editor), la vista oportunidades_operativo ni el filtro por áreas
-- del perfil restringido (conexión con Ingeniería), Control de horarios.
--
-- Requiere 12, 13, 17, 20, 25, 27, 28 y 30. Idempotente: se puede correr
-- varias veces. Ejecutar en Supabase: SQL Editor -> pegar y Run.
-- Mientras no se corra, el panel sigue funcionando con los perfiles de antes.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0) Requisitos
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.usuario') is null or to_regclass('public.roles') is null then
    raise exception 'Faltan las tablas de usuarios: corré 12_roles_permisos.sql y 13_login_por_usuario.sql.';
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'usuario' and column_name = 'permisos') then
    raise exception 'Falta correr 25_perfil_operativo_restringido.sql.';
  end if;
  if to_regclass('public.historial_oportunidades') is null then
    raise exception 'Falta correr 17_ficha_equipo_historial.sql.';
  end if;
  if to_regclass('public.clientes') is null then
    raise exception 'Falta correr 28_clientes_maestra.sql.';
  end if;
  if to_regclass('public.gestion_comercial') is null then
    raise exception 'Falta correr 30_gestion_comercial.sql.';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1) Perfiles nuevos y datos del usuario
-- ---------------------------------------------------------------------
insert into public.roles (identificador, descripcion)
select (select coalesce(max(identificador), 0) from public.roles) + row_number() over (order by v.d), v.d
from (values ('gerencia'), ('ejecutivo')) as v(d)
where not exists (select 1 from public.roles r where r.descripcion = v.d);

alter table public.usuario add column if not exists pais text;
alter table public.usuario add column if not exists codigo_comercial text;
alter table public.usuario add column if not exists desactivado_en timestamptz;

alter table public.usuario drop constraint if exists usuario_pais_check;
alter table public.usuario add constraint usuario_pais_check
  check (pais is null or pais in ('peru', 'colombia', 'ambos'));

comment on column public.usuario.pais is
  'Operación a la que accede: peru, colombia o ambos (ambos solo para admin y gerencia).';
comment on column public.usuario.codigo_comercial is
  'Clave de KAM del ejecutivo en oportunidades.kam (p. ej. hugo_escobar, co_vivian_castrillon). Se usa como KAM de las oportunidades que nacen de sus conversiones.';
comment on column public.usuario.desactivado_en is
  'Fecha de desactivación. Un usuario inactivo no entra ni ve datos; su historial se conserva.';


-- ---------------------------------------------------------------------
-- 2) Normalización de nombres (sin tildes, minúsculas, un espacio)
-- ---------------------------------------------------------------------
create or replace function public.norm_nombre(p text)
returns text
language sql immutable
as $$
  select trim(regexp_replace(lower(translate(coalesce(p, ''),
    'ÁÉÍÓÚÀÈÌÒÙÄËÏÖÜÂÊÎÔÛÑáéíóúàèìòùäëïöüâêîôûñ',
    'AEIOUAEIOUAEIOUAEIOUNaeiouaeiouaeiouaeioun')), '\s+', ' ', 'g'));
$$;

-- Cuenta que corresponde a un nombre del directorio comercial ("Hugo Escobar").
-- Igual criterio que el panel (gcmPersonaDe): nombre exacto o, si no, primer
-- nombre y último apellido. Solo responde si hay UNA coincidencia.
create or replace function public.uid_por_nombre(p_nombre text)
returns uuid
language plpgsql stable security definer set search_path = public
as $$
declare
  v text := public.norm_nombre(p_nombre);
  t text[];
  n integer;
  r uuid;
begin
  if v = '' then return null; end if;
  select count(*), min(identificador::text)::uuid into n, r
  from public.usuario where public.norm_nombre(nombre) = v;
  if n = 1 then return r; end if;
  if n > 1 then return null; end if;
  t := string_to_array(v, ' ');
  select count(*), min(u.identificador::text)::uuid into n, r
  from public.usuario u,
       lateral (select string_to_array(public.norm_nombre(u.nombre), ' ') as ut) x
  where (array_length(t, 1) >= 2 and t[1] = any (x.ut) and t[array_length(t, 1)] = any (x.ut))
     or (array_length(x.ut, 1) >= 2 and x.ut[1] = any (t) and x.ut[array_length(x.ut, 1)] = any (t));
  return case when n = 1 then r end;
end;
$$;


-- ---------------------------------------------------------------------
-- 3) Funciones de perfil (security definer, como mi_rol())
-- ---------------------------------------------------------------------
create or replace function public.mi_pais()
returns text
language sql security definer set search_path = public stable
as $$
  select coalesce(u.pais, case when r.descripcion in ('admin', 'gerencia') then 'ambos' else 'peru' end)
  from public.usuario u
  join public.roles r on r.identificador = u.rol_id
  where (u.auth_user_id = auth.uid() or u.identificador = auth.uid()) and u.activo;
$$;

create or replace function public.mi_codigo_comercial()
returns text
language sql security definer set search_path = public stable
as $$
  select nullif(u.codigo_comercial, '')
  from public.usuario u
  where (u.auth_user_id = auth.uid() or u.identificador = auth.uid()) and u.activo;
$$;

create or replace function public.es_gerencia()
returns boolean
language sql security definer set search_path = public stable
as $$ select coalesce(public.mi_rol() = 'gerencia', false); $$;

create or replace function public.es_ejecutivo()
returns boolean
language sql security definer set search_path = public stable
as $$ select coalesce(public.mi_rol() = 'ejecutivo', false); $$;

-- ¿El usuario actual llega al Planner de Perú (tablas oportunidades,
-- entregables, historial)? El ejecutivo de Colombia, no: su Planner es el de
-- Colombia. El resto de perfiles, como hasta ahora.
create or replace function public.ve_planner_peru()
returns boolean
language sql security definer set search_path = public stable
as $$
  select not public.es_ejecutivo() or public.mi_pais() = 'peru';
$$;

-- Perfil restringido: acciones limitadas a consulta. Áreas y vistas siguen
-- configurables. Para el resto de roles, igual que antes.
create or replace function public.puede_accion(p_accion text)
returns boolean
language sql security definer set search_path = public stable
as $$
  select case public.mi_rol()
    when 'admin' then true
    when 'editor' then true
    when 'operativo_restringido'
      then p_accion = 'ver'
           and coalesce((public.mi_permisos() -> 'acciones' ->> 'ver')::boolean, false)
    else false
  end;
$$;


-- ---------------------------------------------------------------------
-- 4) Reglas del perfil al guardar un usuario
--   · Perú + Colombia solo para admin y gerencia (y siempre las dos).
--   · Ejecutivo: un solo país y código comercial (se sugiere del nombre).
--   · Restringido: acciones solo de consulta.
-- ---------------------------------------------------------------------
create or replace function public.usuario_normalizar_perfil()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_rol text;
  t text[];
begin
  select descripcion into v_rol from public.roles where identificador = new.rol_id;

  if v_rol in ('admin', 'gerencia') then
    new.pais := 'ambos';
  elsif new.pais = 'ambos' then
    raise exception 'Perú + Colombia es exclusivo de los perfiles Administrador y Gerencia.'
      using errcode = '42501';
  elsif new.pais is null then
    new.pais := 'peru';
  end if;

  if v_rol = 'ejecutivo' and coalesce(new.codigo_comercial, '') = '' then
    t := string_to_array(public.norm_nombre(new.nombre), ' ');
    if array_length(t, 1) >= 1 then
      new.codigo_comercial := (case when new.pais = 'colombia' then 'co_' else '' end)
        || regexp_replace(array_to_string(t[1:2], '_'), '[^a-z_]', '', 'g');
    end if;
  end if;

  if v_rol = 'operativo_restringido' then
    new.permisos := jsonb_set(coalesce(new.permisos, '{}'::jsonb), '{acciones}',
      '{"ver":true,"crear":false,"editar":false,"completar_tareas":false,"actualizar_avance":false}'::jsonb);
  end if;

  if tg_op = 'UPDATE' and new.activo is distinct from old.activo then
    new.desactivado_en := case when new.activo then null else now() end;
  end if;
  return new;
end;
$$;

drop trigger if exists usuario_normalizar_perfil on public.usuario;
create trigger usuario_normalizar_perfil
  before insert or update on public.usuario
  for each row execute function public.usuario_normalizar_perfil();

-- Completa los perfiles existentes (dispara el trigger de arriba).
update public.usuario set pais = pais;


-- ---------------------------------------------------------------------
-- 5) Planner: oportunidades, tareas e historial
--   Leen: perfiles con rol (como antes), salvo el restringido (usa su vista).
--   El ejecutivo lee TODAS las oportunidades de su país, como un visor
--   (Perú: estas tablas; Colombia: no las lee).
--   Escribir: sin cambios (admin y editor). Gerencia y ejecutivo, consulta.
-- ---------------------------------------------------------------------
drop policy if exists "oportunidades_select_con_perfil" on public.oportunidades;
create policy "oportunidades_select_con_perfil" on public.oportunidades
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido()
         and public.ve_planner_peru());

drop policy if exists "entregables_select_con_perfil" on public.entregables;
create policy "entregables_select_con_perfil" on public.entregables
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido()
         and public.ve_planner_peru());

drop policy if exists "historial_select_con_perfil" on public.historial_oportunidades;
create policy "historial_select_con_perfil" on public.historial_oportunidades
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido()
         and public.ve_planner_peru());


-- Una versión anterior de este script filtraba por cartera (KAM): se retiran
-- esas funciones, ya sin políticas que las usen.
drop function if exists public.opp_id_es_mia(integer);
drop function if exists public.opp_es_mia(text);


-- ---------------------------------------------------------------------
-- 6) Base Maestra de Clientes: compartida. La leen todos los perfiles con
--    rol; además de admin y editor, gerencia y ejecutivos pueden registrar
--    un cliente nuevo (no editar los existentes).
-- ---------------------------------------------------------------------
drop policy if exists "clientes_insert_editor" on public.clientes;
create policy "clientes_insert_editor" on public.clientes
  for insert to authenticated
  with check (public.puede_editar() or public.es_gerencia() or public.es_ejecutivo());


-- ---------------------------------------------------------------------
-- 7) Gestión Comercial: propietario por registro
-- ---------------------------------------------------------------------
alter table public.gestion_comercial add column if not exists propietario_uid uuid;
alter table public.gestion_comercial add column if not exists compartido_uids uuid[] not null default '{}';
create index if not exists gestion_comercial_prop_idx on public.gestion_comercial (propietario_uid);

comment on column public.gestion_comercial.propietario_uid is
  'Dueño del registro (ejecutivo responsable). Lo calcula la base: el ejecutivo siempre es dueño de lo que crea.';
comment on column public.gestion_comercial.compartido_uids is
  'Otras cuentas que ven el registro: acompañantes, gestión compartida, responsable de la tarea y dueño del lead vinculado.';

-- Dueño de los registros existentes: el responsable o, si no se reconoce,
-- quien lo creó. Va ANTES del trigger, que en un update conserva el dueño.
drop trigger if exists gcm_control on public.gestion_comercial;
update public.gestion_comercial
   set propietario_uid = coalesce(public.uid_por_nombre(responsable), creado_uid)
 where propietario_uid is null;

create or replace function public.gcm_control()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_rol  text := public.mi_rol();
  v_uid  uuid := auth.uid();
  v_rpc  boolean := coalesce(current_setting('app.gcm_rpc', true), '') = 'on';
  v_old  text;
  v_new  text;
  v_lead text;
  v_comp uuid[];
  v_libres constant text[] := '{estado,conversion,hist,opId}';
begin
  -- Dueño y autor.
  if tg_op = 'INSERT' then
    new.creado_uid := coalesce(v_uid, new.creado_uid);
    if new.propietario_uid is null then
      new.propietario_uid := coalesce(public.uid_por_nombre(new.responsable), new.creado_uid);
    end if;
  else
    new.creado_uid := old.creado_uid;
    new.propietario_uid := case
      when new.responsable is distinct from old.responsable
        then coalesce(public.uid_por_nombre(new.responsable), old.propietario_uid)
      else coalesce(old.propietario_uid, new.propietario_uid) end;
  end if;

  if not v_rpc and v_rol is not null and v_rol <> 'admin' then
    v_old := case when tg_op = 'UPDATE' then old.datos ->> 'estado' end;
    v_new := new.datos ->> 'estado';

    -- Validar o devolver una solicitud de conversión: solo administración.
    if new.tipo = 'solicitud' and tg_op = 'UPDATE' and v_new is distinct from v_old
       and v_new in ('En aprobación', 'Devuelta') then
      raise exception 'Solo administración valida o devuelve solicitudes de conversión.' using errcode = '42501';
    end if;

    if v_rol = 'ejecutivo' then
      if tg_op = 'INSERT' then
        if new.tipo <> 'empresa' then
          new.propietario_uid := v_uid;
          if new.pais is distinct from public.mi_pais() then
            raise exception 'Solo puedes registrar información de tu país.' using errcode = '42501';
          end if;
        end if;
        if new.tipo = 'solicitud' and v_new is distinct from 'Pendiente de validación' then
          raise exception 'La solicitud de conversión se crea pendiente de validación.' using errcode = '42501';
        end if;
      else
        new.propietario_uid := old.propietario_uid;
        new.pais := old.pais;
        new.tipo := old.tipo;
        if old.tipo = 'solicitud' then
          raise exception 'La solicitud de conversión la resuelven administración o gerencia.' using errcode = '42501';
        end if;
        if old.tipo = 'lead' then
          if v_old in ('Conversión solicitada', 'Convertido') then
            raise exception 'El lead tiene la conversión solicitada o aprobada: queda en solo consulta.' using errcode = '42501';
          end if;
          if v_new is distinct from v_old and v_new in ('Convertido', 'Rechazado') then
            raise exception 'Solo administración o gerencia resuelven la conversión del lead.' using errcode = '42501';
          end if;
        end if;
      end if;

    elsif v_rol = 'gerencia' and tg_op = 'UPDATE'
          and old.propietario_uid is distinct from v_uid
          and not (v_uid = any (old.compartido_uids)) then
      new.propietario_uid := old.propietario_uid;
      new.pais := old.pais;
      new.tipo := old.tipo;
      if old.tipo = 'lead' then
        if (new.datos - v_libres) is distinct from (old.datos - v_libres) then
          raise exception 'Gerencia solo cambia el estado de conversión del lead.' using errcode = '42501';
        end if;
      elsif old.tipo = 'solicitud' then
        if v_new is distinct from v_old
           and not (v_old = 'En aprobación' and v_new in ('Aprobada', 'Rechazada')) then
          raise exception 'Gerencia aprueba o rechaza solicitudes ya validadas por administración.' using errcode = '42501';
        end if;
      elsif old.tipo <> 'empresa' then
        raise exception 'Gerencia consulta los registros de los ejecutivos, no los modifica.' using errcode = '42501';
      end if;
    end if;
  end if;

  -- Quién más lo ve.
  v_lead := coalesce(new.datos ->> 'leadId',
                     case when new.datos -> 'vinculo' ->> 'tipo' = 'lead' then new.datos -> 'vinculo' ->> 'id' end);
  select coalesce(array_agg(distinct u) filter (where u is not null and u is distinct from new.propietario_uid), '{}')
    into v_comp
  from (
    select public.uid_por_nombre(x ->> 'nombre') as u
      from jsonb_array_elements(case when jsonb_typeof(new.datos -> 'acomp') = 'array' then new.datos -> 'acomp' else '[]'::jsonb end) x
    union all
    select public.uid_por_nombre(x #>> '{}')
      from jsonb_array_elements(case when jsonb_typeof(new.datos -> 'compartido') = 'array' then new.datos -> 'compartido' else '[]'::jsonb end) x
    union all select public.uid_por_nombre(new.datos ->> 'responsable')
    union all select public.uid_por_nombre(new.datos ->> 'creadoPor')
    union all select g.propietario_uid from public.gestion_comercial g
               where v_lead is not null and g.id = v_lead and g.id <> new.id
  ) s;
  new.compartido_uids := v_comp;
  return new;
end;
$$;

create trigger gcm_control
  before insert or update on public.gestion_comercial
  for each row execute function public.gcm_control();

-- Calcula compartido_uids de los registros existentes.
update public.gestion_comercial set actualizado_en = actualizado_en;


-- ---------------------------------------------------------------------
-- 8) Gestión Comercial: quién ve y quién escribe
--   · Empresas (datos de la Base Maestra): compartidas.
--   · Leads, contactos, agenda, visitas, tareas, interacciones y solicitudes:
--     del dueño (+ compartidos). Admin y gerencia ven todo, de los dos países.
--   · Ejecutivo: además, solo su país.
--   · Nadie borra (sin política de delete).
-- ---------------------------------------------------------------------
drop policy if exists "gcom_select_con_perfil" on public.gestion_comercial;
create policy "gcom_select_con_perfil" on public.gestion_comercial
  for select to authenticated
  using (
    public.mi_rol() is not null and not public.es_restringido()
    and (
      tipo in ('empresa', 'permiso')
      or public.es_admin() or public.es_gerencia()
      or propietario_uid = auth.uid()
      or auth.uid() = any (compartido_uids)
    )
    and (not public.es_ejecutivo() or tipo = 'empresa' or pais = public.mi_pais())
  );

drop policy if exists "gcom_insert" on public.gestion_comercial;
create policy "gcom_insert" on public.gestion_comercial
  for insert to authenticated
  with check (
    public.mi_rol() is not null and not public.es_restringido() and public.mi_rol() <> 'visor'
    and (tipo <> 'permiso' or public.es_admin())
    and (public.es_admin() or tipo = 'empresa' or propietario_uid = auth.uid() or creado_uid = auth.uid())
  );

drop policy if exists "gcom_update" on public.gestion_comercial;
create policy "gcom_update" on public.gestion_comercial
  for update to authenticated
  using (
    public.mi_rol() is not null and not public.es_restringido() and public.mi_rol() <> 'visor'
    and (tipo <> 'permiso' or public.es_admin())
    and (
      public.es_admin()
      or tipo = 'empresa'
      or propietario_uid = auth.uid()
      or auth.uid() = any (compartido_uids)
      or (public.es_gerencia() and tipo in ('lead', 'solicitud'))
    )
    and (not public.es_ejecutivo() or tipo = 'empresa' or pais = public.mi_pais())
  )
  with check (
    public.mi_rol() is not null and not public.es_restringido() and public.mi_rol() <> 'visor'
    and (tipo <> 'permiso' or public.es_admin())
  );


-- ---------------------------------------------------------------------
-- 9) Aprobación de una conversión Lead -> Oportunidad
--   Admin: desde «Pendiente de validación» (valida y aprueba) o «En aprobación».
--   Gerencia: desde «En aprobación».
--   Perú: crea la oportunidad en el Planner (KAM = código del ejecutivo,
--   etapa Prospecto) y deja constancia en su historial.
--   Colombia: el Planner es una maqueta local; la oportunidad la crea el
--   panel de quien aprueba y aquí solo se resuelve la solicitud.
-- ---------------------------------------------------------------------
create or replace function public.gcm_aprobar_conversion(p_solicitud text, p_nota text default null)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_rol  text := public.mi_rol();
  s      public.gestion_comercial%rowtype;
  l      public.gestion_comercial%rowtype;
  c      jsonb;
  v_est  text;
  v_op   integer;
  v_cli  text;
  v_con  text;
  v_kam  text;
  v_por  text;
  v_hoy  text := to_char(now() at time zone 'America/Lima', 'YYYY-MM-DD');
  v_h    jsonb;
begin
  if v_rol is null or v_rol not in ('admin', 'gerencia') then
    raise exception 'Solo administración o gerencia aprueban conversiones.' using errcode = '42501';
  end if;

  select * into s from public.gestion_comercial where id = p_solicitud and tipo = 'solicitud' for update;
  if not found then raise exception 'No existe la solicitud %.', p_solicitud; end if;
  v_est := s.datos ->> 'estado';
  if v_est = 'Aprobada' then
    return jsonb_build_object('opId', s.datos ->> 'opId', 'pais', s.pais, 'yaAprobada', true);
  end if;
  if not (v_est = 'En aprobación' or (v_rol = 'admin' and v_est = 'Pendiente de validación')) then
    raise exception 'La solicitud está «%»: no se puede aprobar.', coalesce(v_est, 'sin estado');
  end if;

  select * into l from public.gestion_comercial
   where id = s.datos ->> 'leadId' and tipo = 'lead' for update;
  if not found then raise exception 'No existe el lead de la solicitud.'; end if;

  c := coalesce(l.datos -> 'campos', '{}'::jsonb);
  select nombre into v_por from public.usuario
   where auth_user_id = auth.uid() or identificador = auth.uid() limit 1;
  v_por := coalesce(v_por, 'Sistema');
  perform set_config('app.gcm_rpc', 'on', true);

  if s.pais = 'peru' then
    select nombre into v_cli from public.clientes where id_cliente = l.datos ->> 'empresaId';
    select datos ->> 'nombre' into v_con from public.gestion_comercial where id = l.datos ->> 'contactoId';
    select nullif(codigo_comercial, '') into v_kam from public.usuario
     where identificador = l.propietario_uid or auth_user_id = l.propietario_uid limit 1;

    perform pg_advisory_xact_lock(hashtext('oportunidades_nuevo_identificador'));
    select coalesce(max("Identificador"), 0) + 1 into v_op from public.oportunidades;

    insert into public.oportunidades (
      "Identificador", cliente, cliente_id, proyecto, refrigerante, importe, probabilidad_cierre,
      mes_cierre, segmento_cliente, sector, duracion_proyecto, valor_no_frio_oocc, valor_no_frio_eemm,
      etapa, responsable_actual, kam, kam_otro, contacto, proximo_paso, accion_pendiente_cliente,
      requiere_metrados, estado_operativo, ronda_actual, pais
    ) overriding system value values (
      v_op,
      coalesce(v_cli, ''),
      nullif(l.datos ->> 'empresaId', ''),
      nullif(l.datos ->> 'titulo', ''),
      nullif(c ->> 'refrigerante', ''),
      coalesce(nullif(c ->> 'importe', '')::numeric, 0),
      round(nullif(c ->> 'probabilidad', '')::numeric)::integer,
      nullif(c ->> 'mesCierre', ''),
      nullif(c ->> 'segmento', ''),
      nullif(c ->> 'sector', ''),
      round(nullif(c ->> 'duracion', '')::numeric)::integer,
      0, 0,
      'prospecto', 'comercial',
      coalesce(v_kam, 'otro'),
      case when v_kam is null then nullif(l.datos ->> 'ejecutivo', '') end,
      v_con,
      'Convertida desde el lead ' || l.id || coalesce(' · ' || nullif(p_nota, ''), ''),
      false, false, 'pendiente_interno', 1, 'peru'
    );

    insert into public.historial_oportunidades
      (id, oportunidad_identificador, area, cambio, detalle, valor_anterior, valor_nuevo, usuario)
    values
      ('conv-' || s.id, v_op, 'comercial', 'Oportunidad creada desde lead',
       'Lead ' || l.id || ' · ' || coalesce(l.datos ->> 'titulo', '') || ' · solicitado por '
         || coalesce(l.datos ->> 'ejecutivo', '') || ' · aprobado por ' || v_por,
       null, l.id, v_por)
    on conflict (id) do nothing;
  end if;

  v_h := jsonb_build_object('f', now(), 'por', v_por, 'accion', 'Conversión aprobada', 'nota', coalesce(p_nota, ''));

  update public.gestion_comercial
     set datos = s.datos || jsonb_build_object(
           'estado', 'Aprobada', 'opId', coalesce(v_op::text, ''), 'resueltoPor', v_por, 'resueltoEn', now(),
           'validadoPor', coalesce(s.datos ->> 'validadoPor', v_por),
           'hist', coalesce(s.datos -> 'hist', '[]'::jsonb) || v_h),
         actualizado_en = now()
   where id = s.id;

  update public.gestion_comercial
     set datos = l.datos || jsonb_build_object(
           'estado', 'Convertido', 'opId', coalesce(v_op::text, ''),
           'conversion', jsonb_build_object('solicitudId', s.id, 'fecha', v_hoy, 'opId', coalesce(v_op::text, ''), 'aprobadoPor', v_por),
           'hist', coalesce(l.datos -> 'hist', '[]'::jsonb) || v_h),
         actualizado_en = now()
   where id = l.id;

  return jsonb_build_object('opId', v_op, 'pais', s.pais);
end;
$$;

revoke all on function public.gcm_aprobar_conversion(text, text) from public, anon;
grant execute on function public.gcm_aprobar_conversion(text, text) to authenticated;


-- ---------------------------------------------------------------------
-- 10) Activar / desactivar usuarios (solo admin). No borra nada: la cuenta
--     queda bloqueada para entrar y su historial y registros se conservan.
-- ---------------------------------------------------------------------
create or replace function public.admin_activar_usuario(p_uid uuid, p_activo boolean)
returns void
language plpgsql security definer set search_path = public, auth
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un admin puede activar o desactivar usuarios.' using errcode = '42501';
  end if;
  if p_uid = auth.uid() and not p_activo then
    raise exception 'No podés desactivar tu propia cuenta.';
  end if;
  if not p_activo
     and exists (select 1 from public.usuario u join public.roles r on r.identificador = u.rol_id
                 where (u.identificador = p_uid or u.auth_user_id = p_uid) and r.descripcion = 'admin')
     and (select count(*) from public.usuario u join public.roles r on r.identificador = u.rol_id
          where r.descripcion = 'admin' and u.activo) <= 1 then
    raise exception 'Es el único admin activo: asigná otro admin antes de desactivarlo.';
  end if;
  update public.usuario set activo = p_activo
   where identificador = p_uid or auth_user_id = p_uid;
  if not found then raise exception 'No existe el perfil.'; end if;
  update auth.users
     set banned_until = case when p_activo then null else 'infinity'::timestamptz end
   where id = p_uid;
end;
$$;

revoke all on function public.admin_activar_usuario(uuid, boolean) from public, anon;
grant execute on function public.admin_activar_usuario(uuid, boolean) to authenticated;


-- ---------------------------------------------------------------------
-- 11) Perfiles del equipo (solo cuentas que YA existen; las que falten se
--     crean desde usuarios.html con el perfil de esta tabla).
-- ---------------------------------------------------------------------
drop table if exists perfil_objetivo, perfil_match;
create temporary table perfil_objetivo (nombre text, palabras text[], rol text, pais text, codigo text);
insert into perfil_objetivo values
  ('Valeria Rodríguez', '{valeria,rodriguez}', 'admin',     'ambos',    null),
  ('Misael Estrada',    '{misael,estrada}',    'gerencia',  'ambos',    'misael_estrada'),
  ('Hugo Escobar',      '{hugo,escobar}',      'ejecutivo', 'peru',     'hugo_escobar'),
  ('Jhon Rojas',        '{jhon,rojas}',        'ejecutivo', 'peru',     'jhon_rojas'),
  ('Víctor Ramírez',    '{victor,ramirez}',    'ejecutivo', 'peru',     'victor_ramirez'),
  ('Vivian Castrillón', '{vivian,castrillon}', 'ejecutivo', 'colombia', 'co_vivian_castrillon');

create temporary table perfil_match as
select t.nombre as persona, t.rol, t.pais, t.codigo, u.identificador
from perfil_objetivo t
left join public.usuario u
  on (select bool_and(public.norm_nombre(u.nombre) like '%' || w || '%') from unnest(t.palabras) w);

update public.usuario u
   set rol_id = r.identificador,
       pais = m.pais,
       codigo_comercial = coalesce(m.codigo, u.codigo_comercial)
  from perfil_match m
  join public.roles r on r.descripcion = m.rol
 where u.identificador = m.identificador
   and (select count(*) from perfil_match m2 where m2.persona = m.persona) = 1;

select m.persona,
       m.rol || ' · ' || m.pais as perfil_esperado,
       case
         when m.identificador is null then 'NO ENCONTRADO: crear en usuarios.html'
         when (select count(*) from perfil_match m2 where m2.persona = m.persona) > 1
           then 'VARIAS CUENTAS con ese nombre: revisar a mano'
         else 'OK · ' || coalesce(u.usuario_login, '—') || ' · ' || r.descripcion || ' · ' || u.pais
              || coalesce(' · KAM ' || u.codigo_comercial, '')
       end as resultado
from perfil_match m
left join public.usuario u on u.identificador = m.identificador
left join public.roles r on r.identificador = u.rol_id
order by m.rol, m.persona;
