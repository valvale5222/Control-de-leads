-- =====================================================================
-- 25: Perfil "operativo_restringido" (Presupuestos e Ingeniería)
--
-- Un rol nuevo, por encima del sistema de usuarios existente (no reemplaza
-- nada de 12/13): admin, editor y visor quedan exactamente como estaban.
--
--   · ÁREAS    — a qué áreas operativas llega la persona. Hoy: presupuestos
--                (en el panel "Presupuestos e Ingeniería").
--   · ACCIONES — qué puede hacer en esas áreas, una por una:
--                  ver, crear, editar, completar_tareas, actualizar_avance
--                Hoy solo "ver" está en true. Habilitar otra más adelante es
--                un UPDATE de `usuario.permisos`, sin tocar código ni políticas.
--
-- Todo vive en una columna jsonb `usuario.permisos`:
--   {"areas":["presupuestos"], "vistas":["revision","carga"],
--    "acciones":{"ver":true,"crear":false,"editar":false,
--                "completar_tareas":false,"actualizar_avance":false}}
--
-- Qué se aplica en la BASE (no solo en la pantalla):
--   · entregables: el perfil solo lee las tareas de sus áreas (RLS).
--   · oportunidades: el perfil NO lee la tabla base (tiene importe, margen,
--     probabilidad, cotizaciones, productos…). Lee la vista
--     `oportunidades_operativo`, que expone solo datos generales, fechas y
--     responsables de las áreas autorizadas, y solo proyectos que tengan
--     tareas en esas áreas.
--   · historial: sin acceso (registra cambios de importe y margen).
--   · escritura: las políticas de oportunidades/historial siguen exigiendo
--     admin/editor, así que el perfil no puede escribirlas. Sobre entregables
--     se agregan políticas por acción + un trigger que limita QUÉ columnas
--     puede cambiar cada acción. Con acciones en false, no escribe nada.
--
-- Requiere haber corrido antes 12, 13, 17, 18, 19, 20 y 21.
-- Es idempotente. Ejecutar en Supabase: SQL Editor -> pegar y Run.
--
-- ALTA DE USUARIOS: desde usuarios.html (Gestión de usuarios). Se crea con
-- nombre y contraseña, y al elegir el rol operativo_restringido se marcan ahí
-- mismo sus áreas y acciones (se guardan en usuario.permisos). No hace falta
-- SQL por persona. La sección 6 queda solo como alternativa por SQL.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) Rol y columna de permisos
-- ---------------------------------------------------------------------
insert into public.roles (identificador, descripcion)
select (select coalesce(max(identificador), 0) from public.roles) + 1, 'operativo_restringido'
where not exists (select 1 from public.roles where descripcion = 'operativo_restringido');

alter table public.usuario add column if not exists permisos jsonb;

comment on column public.usuario.permisos is
  'Solo para el rol operativo_restringido: {"areas":[...],"vistas":[revision,carga,desempeno],"acciones":{ver,crear,editar,completar_tareas,actualizar_avance}}.';


-- ---------------------------------------------------------------------
-- 2) Funciones. security definer por la misma razón que mi_rol() (12).
-- ---------------------------------------------------------------------
create or replace function public.es_restringido()
returns boolean
language sql security definer set search_path = public stable
as $$ select coalesce(public.mi_rol() = 'operativo_restringido', false); $$;

create or replace function public.mi_permisos()
returns jsonb
language sql security definer set search_path = public stable
as $$
  select coalesce(u.permisos, '{}'::jsonb)
  from public.usuario u
  where (u.auth_user_id = auth.uid() or u.identificador = auth.uid())
    and u.activo;
$$;

-- ¿Puede ejecutar esta acción? Solo aplica al perfil restringido: para el
-- resto de roles responde según su rol de siempre.
-- Va antes que mis_areas(), que la usa (Postgres valida al crear).
create or replace function public.puede_accion(p_accion text)
returns boolean
language sql security definer set search_path = public stable
as $$
  select case public.mi_rol()
    when 'admin' then true
    when 'editor' then true
    when 'operativo_restringido'
      then coalesce((public.mi_permisos() -> 'acciones' ->> p_accion)::boolean, false)
    else false
  end;
$$;

-- Áreas autorizadas del usuario actual (vacío si no es restringido o no ve).
create or replace function public.mis_areas()
returns text[]
language sql security definer set search_path = public stable
as $$
  select case
    when public.es_restringido() and public.puede_accion('ver')
      then coalesce(array(select jsonb_array_elements_text(public.mi_permisos() -> 'areas')), '{}')
    else '{}'::text[]
  end;
$$;


-- ---------------------------------------------------------------------
-- 3) Lectura: el perfil restringido sale de las políticas generales.
-- (Mismo patrón que 13: se recrean con la condición extra.)
-- ---------------------------------------------------------------------
drop policy if exists "oportunidades_select_con_perfil" on public.oportunidades;
create policy "oportunidades_select_con_perfil" on public.oportunidades
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido());

drop policy if exists "entregables_select_con_perfil" on public.entregables;
create policy "entregables_select_con_perfil" on public.entregables
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido());

drop policy if exists "entregables_select_restringido" on public.entregables;
create policy "entregables_select_restringido" on public.entregables
  for select to authenticated
  using (public.es_restringido() and area = any (public.mis_areas()));

drop policy if exists "historial_select_con_perfil" on public.historial_oportunidades;
create policy "historial_select_con_perfil" on public.historial_oportunidades
  for select to authenticated
  using (public.mi_rol() is not null and not public.es_restringido());


-- ---------------------------------------------------------------------
-- 4) Vista de oportunidades para el perfil restringido.
-- Corre con los permisos de su dueño (así puede leer la tabla base), pero
-- filtra por el usuario que consulta. Para cualquier otro rol devuelve 0
-- filas: ellos siguen leyendo la tabla base.
-- Columnas AUSENTES a propósito: importe, margen_comercial,
-- probabilidad_cierre, mes_cierre, segmento_cliente, valor_no_frio_*,
-- contacto, cotizaciones, productos*. Incidencias, KAM / arquitecto /
-- presupuestador solo llegan si su área está autorizada.
-- `apoyos` se filtra a las áreas autorizadas.
-- ---------------------------------------------------------------------
drop view if exists public.oportunidades_operativo;
create view public.oportunidades_operativo as
select
  o."Identificador", o.cliente, o.proyecto, o.tipo_sistema, o.refrigerante, o.refrigerante_otro,
  o.etapa, o.prioridad, o.responsable_actual,
  -- Responsables de la tríada: solo los de áreas autorizadas.
  case when 'comercial' = any (public.mis_areas()) then o.kam end as kam,
  case when 'comercial' = any (public.mis_areas()) then o.kam_otro end as kam_otro,
  case when 'arquitectura' = any (public.mis_areas()) then o.arquitecto end as arquitecto,
  case when 'arquitectura' = any (public.mis_areas()) then o.arquitecto_otro end as arquitecto_otro,
  case when 'presupuestos' = any (public.mis_areas()) then o.presupuestador end as presupuestador,
  case when 'presupuestos' = any (public.mis_areas()) then o.presupuestador_otro end as presupuestador_otro,
  o.requiere_metrados, o.resp_metrados, o.resp_metrados_otro,
  o.f_inicio, o.f_comprometida, o.f_entregada, o.fecha_seguimiento,
  o.proximo_paso, o.accion_pendiente_cliente, o.descripcion_pendiente,
  o.estado_operativo, o.ronda_actual, o.orden_trabajo, o.prioridad_tablero,
  o.duracion_proyecto, o.zona, o.region, o.sector, o.pais,
  o.fecha_comprometida_cliente, o.semana_revision, o.secuencia_semana,
  o.created_at, o.updated_at,
  coalesce((select jsonb_agg(a) from jsonb_array_elements(o.apoyos) a
            where a ->> 'area' = any (public.mis_areas())), '[]'::jsonb) as apoyos,
  -- Incidencias de desempeño, solo las de sus áreas (las usa Desempeño).
  coalesce((select jsonb_agg(i) from jsonb_array_elements(coalesce(o.incidencias, '[]'::jsonb)) i
            where i ->> 'area' = any (public.mis_areas())), '[]'::jsonb) as incidencias
from public.oportunidades o
where public.es_restringido()
  and exists (select 1 from public.entregables e
              where e.oportunidad_identificador = o."Identificador"
                and e.area = any (public.mis_areas()));

revoke all on public.oportunidades_operativo from anon, public;
grant select on public.oportunidades_operativo to authenticated;


-- ---------------------------------------------------------------------
-- 5) Escritura por acción sobre entregables (hoy todas en false).
-- Las políticas dan paso por acción y área; el trigger limita las columnas.
-- No hay política de delete: el perfil nunca borra.
-- ---------------------------------------------------------------------
drop policy if exists "entregables_insert_restringido" on public.entregables;
create policy "entregables_insert_restringido" on public.entregables
  for insert to authenticated
  with check (public.es_restringido() and public.puede_accion('crear')
              and area = any (public.mis_areas()));

drop policy if exists "entregables_update_restringido" on public.entregables;
create policy "entregables_update_restringido" on public.entregables
  for update to authenticated
  using (public.es_restringido() and area = any (public.mis_areas())
         and (public.puede_accion('editar') or public.puede_accion('completar_tareas')
              or public.puede_accion('actualizar_avance')))
  with check (public.es_restringido() and area = any (public.mis_areas()));

create or replace function public.entregables_limitar_columnas()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_cambiadas text[];
  v_permitidas text[] := '{updated_at}';
begin
  if not public.es_restringido() then return new; end if;
  if public.puede_accion('editar') then return new; end if;

  if public.puede_accion('completar_tareas') then
    v_permitidas := v_permitidas || '{estado,estado_tarea,fecha_completado}';
  end if;
  if public.puede_accion('actualizar_avance') then
    v_permitidas := v_permitidas || '{carga_persona}';
  end if;

  select coalesce(array_agg(n.key), '{}') into v_cambiadas
  from jsonb_each(to_jsonb(new)) n
  join jsonb_each(to_jsonb(old)) o using (key)
  where n.value is distinct from o.value;

  if exists (select 1 from unnest(v_cambiadas) c where c <> all (v_permitidas)) then
    raise exception 'Tu perfil no permite modificar esos campos de la tarea.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists entregables_limitar_columnas on public.entregables;
create trigger entregables_limitar_columnas
  before update on public.entregables
  for each row execute function public.entregables_limitar_columnas();


-- ---------------------------------------------------------------------
-- 6) Alta del perfil de Thalía (solo consulta, Presupuestos e Ingeniería).
-- Se corre DESPUÉS de crear su cuenta en Authentication > Users.
-- Para habilitar acciones más adelante:
--   update public.usuario
--      set permisos = jsonb_set(permisos, '{acciones,completar_tareas}', 'true')
--    where usuario_login = 'thalia';
-- ---------------------------------------------------------------------
create or replace function public.vincular_operativo_restringido(
  p_email text, p_nombre text, p_usuario_login text
)
returns text
language plpgsql security definer set search_path = public
as $$
declare
  v_uid    uuid;
  v_rol_id integer;
  v_permisos constant jsonb := '{"areas":["presupuestos"],"vistas":["revision","carga"],
    "acciones":{"ver":true,"crear":false,"editar":false,"completar_tareas":false,"actualizar_avance":false}}';
begin
  select id into v_uid from auth.users where lower(email) = lower(p_email);
  if v_uid is null then
    return 'No existe la cuenta ' || p_email || '. Creala primero en Authentication > Users.';
  end if;
  select identificador into v_rol_id from public.roles where descripcion = 'operativo_restringido';

  insert into public.usuario (identificador, auth_user_id, usuario_login, nombre, rol_id, permisos)
  values (v_uid, v_uid, p_usuario_login, p_nombre, v_rol_id, v_permisos)
  on conflict (identificador) do update
    set rol_id = excluded.rol_id, nombre = excluded.nombre, activo = true,
        usuario_login = excluded.usuario_login,
        permisos = coalesce(public.usuario.permisos, excluded.permisos);
  return p_nombre || ' quedó con el perfil operativo restringido (solo consulta).';
end;
$$;

revoke all on function public.vincular_operativo_restringido(text, text, text) from public, anon, authenticated;

-- Alternativa por SQL (solo si la cuenta ya existe en Authentication > Users):
-- select public.vincular_operativo_restringido('thalia@friopacking.pe', 'Thalía', 'thalia');
