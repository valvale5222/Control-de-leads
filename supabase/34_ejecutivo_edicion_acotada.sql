-- =====================================================================
-- 34: Ejecutivo comercial con edición acotada en el Planner
--
-- Hasta 31 el ejecutivo solo consultaba el Planner. Ahora, sin dejar de ser
-- un perfil de consulta para todo lo demás:
--   · Ficha de SUS oportunidades (kam = su codigo_comercial): edita los campos
--     de «Información general». No cambia el KAM, el país, el equipo, las
--     tareas ni las incidencias.
--   · Revisión semanal: reordena el tablero (prioridad_tablero,
--     semana_revision, secuencia_semana) de las oportunidades de su Planner.
--   · Historial: registra los eventos de esos cambios y sus notas de bitácora.
--   · Nunca crea ni borra oportunidades, ni toca entregables (tareas): el
--     calendario sigue sin poder moverse.
--   · Gestión de equipos (Carga laboral, Control de horarios): solo consulta;
--     no cambia nada aquí.
--
-- Requiere 12, 17, 18, 31 y 33. Idempotente. Ejecutar en Supabase:
-- SQL Editor -> pegar y Run.
-- =====================================================================

do $$
begin
  if to_regprocedure('public.es_ejecutivo()') is null then
    raise exception 'Falta correr 31_perfiles_permisos.sql.';
  end if;
  if to_regclass('public.historial_oportunidades') is null then
    raise exception 'Falta correr 17_ficha_equipo_historial.sql.';
  end if;
end $$;


-- 1) Update de oportunidades para el ejecutivo (Planner de Perú). La política
--    deja pasar la fila; el trigger de abajo limita las columnas.
drop policy if exists "oportunidades_update_ejecutivo" on public.oportunidades;
create policy "oportunidades_update_ejecutivo" on public.oportunidades
  for update to authenticated
  using (public.es_ejecutivo() and public.ve_planner_peru())
  with check (public.es_ejecutivo() and public.ve_planner_peru());


-- 2) Columnas que el ejecutivo puede cambiar.
create or replace function public.oportunidades_limitar_ejecutivo()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  v_cambiadas text[];
  v_revision  text[] := '{prioridad_tablero,semana_revision,secuencia_semana,updated_at}';
  v_info      text[] := '{cliente,cliente_id,proyecto,contacto,importe,valor_no_frio_eemm,valor_no_frio_oocc,
                          margen_comercial,refrigerante,refrigerante_otro,f_inicio,fecha_seguimiento,
                          fecha_comprometida_cliente,etapa,estado_operativo,segmento_cliente,sector,productos,
                          productos_otro,probabilidad_cierre,mes_cierre,duracion_proyecto,zona,region,cotizaciones}';
  v_mia       boolean;
begin
  if not public.es_ejecutivo() or public.puede_editar() then return new; end if;

  v_mia := public.mi_codigo_comercial() is not null
           and old.kam is not distinct from public.mi_codigo_comercial();

  select coalesce(array_agg(n.key), '{}') into v_cambiadas
  from jsonb_each(to_jsonb(new)) n
  join jsonb_each(to_jsonb(old)) o using (key)
  where n.value is distinct from o.value;

  if exists (
    select 1 from unnest(v_cambiadas) c
    where c <> all (v_revision)
      and (not v_mia or c <> all (v_info))
  ) then
    raise exception 'Tu perfil solo edita la Información general de tus oportunidades y el orden de la Revisión semanal.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists oportunidades_limitar_ejecutivo on public.oportunidades;
create trigger oportunidades_limitar_ejecutivo
  before update on public.oportunidades
  for each row execute function public.oportunidades_limitar_ejecutivo();


-- 3) Historial: el ejecutivo agrega eventos (cambios de arriba y notas) de las
--    oportunidades que ve. Sigue sin update ni delete para nadie.
drop policy if exists "historial_insert_ejecutivo" on public.historial_oportunidades;
create policy "historial_insert_ejecutivo" on public.historial_oportunidades
  for insert to authenticated
  with check (public.es_ejecutivo() and public.ve_planner_peru());
