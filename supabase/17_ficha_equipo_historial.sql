-- =====================================================================
-- 17: Ficha de la oportunidad — equipo, tareas con estado fino e historial
--
-- La ficha se rediseñó en 3 secciones (Información general, Equipo de
-- trabajo, Historial). No se crea ninguna fuente de datos paralela:
--
--   · Las TAREAS siguen siendo filas de public.entregables (1 tarea =
--     1 registro), las mismas que leen Equipo de trabajo, Carga laboral,
--     Revisión semanal, Calendario y Gantt. Solo se agrega su estado fino
--     y el bloqueo.
--   · La TRÍADA sigue en oportunidades.kam / arquitecto / presupuestador.
--   · Los APOYOS (personas extra de Arquitectura/Presupuestos) se guardan en
--     la oportunidad como jsonb.
--   · El HISTORIAL es una tabla nueva de solo agregar: nunca se actualiza ni
--     se borra un evento (no hay políticas de update/delete).
--
-- Compatibilidad:
--   · Todo es "add column if not exists" / "create table if not exists": se
--     puede correr varias veces.
--   · La columna entregables.estado NO cambia (sigue aceptando solo
--     pendiente/completado). Una tarea cancelada se guarda con
--     estado = 'completado' y estado_tarea = 'cancelado'.
--   · Registros existentes: estado_tarea queda NULL y el panel lo deriva al
--     cargar (pendiente → En proceso, completado → Completado).
--   · Mientras no se corra este script el panel sigue funcionando: omite
--     estas columnas al guardar y el historial queda solo en el navegador.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- Requiere las funciones public.mi_rol() y public.puede_editar() de
-- 12_roles_permisos.sql / 13_login_por_usuario.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Oportunidades: contacto, segmentación y apoyos
-- ---------------------------------------------------------------------
alter table public.oportunidades add column if not exists contacto text;
alter table public.oportunidades add column if not exists zona     text;   -- norte / centro / sur
alter table public.oportunidades add column if not exists region   text;   -- departamento del Perú (incluye Callao)
alter table public.oportunidades add column if not exists sector   text;   -- Agroexportación, Centros Logísticos, ...
alter table public.oportunidades add column if not exists apoyos   jsonb not null default '[]'::jsonb;

alter table public.oportunidades drop constraint if exists oportunidades_zona_check;
alter table public.oportunidades add constraint oportunidades_zona_check
  check (zona is null or zona in ('norte','centro','sur'));

comment on column public.oportunidades.apoyos is
  'Apoyos del equipo: [{"area":"arquitectura"|"presupuestos","responsable":"<value del catálogo>"}]. La tríada principal vive en kam/arquitecto/presupuestador.';

-- ---------------------------------------------------------------------
-- 2) Entregables (= tareas): estado fino y bloqueo
-- ---------------------------------------------------------------------
alter table public.entregables add column if not exists estado_tarea    text;
alter table public.entregables add column if not exists bloqueo_origen  text;
alter table public.entregables add column if not exists bloqueo_detalle text;

alter table public.entregables drop constraint if exists entregables_estado_tarea_check;
alter table public.entregables add constraint entregables_estado_tarea_check
  check (estado_tarea is null or estado_tarea in ('por_iniciar','en_proceso','bloqueado','completado','cancelado'));

comment on column public.entregables.estado_tarea is
  'Estado de la tarea: por_iniciar / en_proceso / bloqueado / completado / cancelado. "estado" (pendiente/completado) se deriva de éste.';
comment on column public.entregables.bloqueo_origen is
  'De quién se espera información cuando estado_tarea = bloqueado. Se conserva al desbloquear como antecedente.';

-- ---------------------------------------------------------------------
-- 3) Historial de la oportunidad (solo agregar)
-- ---------------------------------------------------------------------
create table if not exists public.historial_oportunidades (
  id                        text primary key,              -- uuid generado por el panel (idempotente al reintentar)
  oportunidad_identificador integer not null references public.oportunidades ("Identificador") on delete cascade,
  entregable_identificador  integer,                       -- tarea afectada, si aplica (sin FK: la tarea puede borrarse y el evento queda)
  creado_en                 timestamptz not null default now(),
  area                      text not null check (area in ('comercial','arquitectura','presupuestos','sistema')),
  cambio                    text not null,
  detalle                   text,
  valor_anterior            text,
  valor_nuevo               text,
  usuario                   text
);

create index if not exists historial_oportunidades_opp_idx
  on public.historial_oportunidades (oportunidad_identificador, creado_en);

comment on table public.historial_oportunidades is
  'Eventos relevantes de cada oportunidad (tareas, estados, fechas, bloqueos, equipo, etapa, rondas, importe/margen). Solo se insertan.';

alter table public.historial_oportunidades enable row level security;

drop policy if exists "historial_select_con_perfil" on public.historial_oportunidades;
create policy "historial_select_con_perfil" on public.historial_oportunidades
  for select to authenticated using (public.mi_rol() is not null);

drop policy if exists "historial_insert_editor" on public.historial_oportunidades;
create policy "historial_insert_editor" on public.historial_oportunidades
  for insert to authenticated with check (public.puede_editar());
-- Sin políticas de update ni delete: los eventos no se sobrescriben.

-- Realtime (opcional; el panel ya se refresca con los cambios de oportunidades).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'historial_oportunidades'
  ) then
    alter publication supabase_realtime add table public.historial_oportunidades;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- Verificación: deben aparecer las 8 columnas nuevas y la tabla.
-- ---------------------------------------------------------------------
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and ((table_name = 'oportunidades' and column_name in ('contacto','zona','region','sector','apoyos'))
    or (table_name = 'entregables'   and column_name in ('estado_tarea','bloqueo_origen','bloqueo_detalle')))
order by table_name, column_name;

select count(*) as eventos_historial from public.historial_oportunidades;
