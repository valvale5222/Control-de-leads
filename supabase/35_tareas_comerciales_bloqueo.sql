-- =====================================================================
-- 35: Tareas del Planner desde Gestión Comercial + bloqueo con pausa
--
-- A) Bloqueo con pausa (todas las tareas). Mientras una tarea está
--    Bloqueada su tiempo no corre; al desbloquearla el plazo se reinicia
--    completo desde ese día. El panel lo calcula; aquí solo se guardan:
--      bloqueo_desde  día en que se bloqueó (null si no está bloqueada)
--      inicio_plazo   día desde el que corre el plazo vigente (último
--                     desbloqueo; null = la creación de la tarea)
--      pausa_dias     días que los reinicios corrieron la fecha. La fecha
--                     original sigue inmutable (22); Desempeño la compara
--                     corrida por estos días.
--
-- B) El ejecutivo crea tareas en SUS oportunidades (kam = su
--    codigo_comercial) desde Gestión Comercial. Nunca las edita.
--      · Comercial: cualquier estado inicial (el panel la crea En proceso).
--      · Arquitectura / Presupuestos: es una SOLICITUD de tarea. Nace
--        bloqueada («Por habilitar») y SIN responsable: Administración o
--        Gerencia asigna al arquitecto o presupuestador y la habilita.
--        Mientras siga por habilitar, el ejecutivo puede retirarla (borrarla);
--        una vez habilitada ya no.
--
-- Requiere 12, 22, 31 y 34. Idempotente. Ejecutar en Supabase:
-- SQL Editor -> pegar y Run.
-- =====================================================================

do $$
begin
  if to_regprocedure('public.es_ejecutivo()') is null then
    raise exception 'Falta correr 31_perfiles_permisos.sql.';
  end if;
end $$;


-- A) Columnas del bloqueo con pausa (nullable, sin default: null = sin dato).
alter table public.entregables add column if not exists bloqueo_desde date;
alter table public.entregables add column if not exists inicio_plazo  date;
alter table public.entregables add column if not exists pausa_dias    integer;

comment on column public.entregables.bloqueo_desde is
  'Día en que la tarea quedó bloqueada (su tiempo no corre). Null si no está bloqueada.';
comment on column public.entregables.inicio_plazo is
  'Día desde el que corre el plazo vigente: el último desbloqueo. Null = la creación.';
comment on column public.entregables.pausa_dias is
  'Días que los reinicios de plazo (tras un bloqueo) corrieron la fecha de la tarea.';


-- B) Alta de tareas por el ejecutivo, solo en sus oportunidades.
drop policy if exists "entregables_insert_ejecutivo" on public.entregables;
create policy "entregables_insert_ejecutivo" on public.entregables
  for insert to authenticated
  with check (
    public.es_ejecutivo()
    and public.ve_planner_peru()
    and public.mi_codigo_comercial() is not null
    and exists (
      select 1 from public.oportunidades o
      where o."Identificador" = oportunidad_identificador
        and o.kam = public.mi_codigo_comercial()
    )
    and (
      area = 'comercial'
      or (area in ('arquitectura', 'presupuestos')
          and estado_tarea = 'bloqueado'
          and bloqueo_origen = 'por_habilitar'
          and responsable is null)
    )
  );

-- C) El ejecutivo retira sus solicitudes mientras siguen por habilitar.
drop policy if exists "entregables_delete_ejecutivo" on public.entregables;
create policy "entregables_delete_ejecutivo" on public.entregables
  for delete to authenticated
  using (
    public.es_ejecutivo()
    and public.ve_planner_peru()
    and public.mi_codigo_comercial() is not null
    and area in ('arquitectura', 'presupuestos')
    and estado_tarea = 'bloqueado'
    and bloqueo_origen = 'por_habilitar'
    and exists (
      select 1 from public.oportunidades o
      where o."Identificador" = oportunidad_identificador
        and o.kam = public.mi_codigo_comercial()
    )
  );

-- Recargar el esquema de PostgREST para que vea las columnas nuevas.
notify pgrst, 'reload schema';
