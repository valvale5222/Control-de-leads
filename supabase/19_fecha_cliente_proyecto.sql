-- =====================================================================
-- 19: Fecha comprometida con el cliente = dato maestro del PROYECTO
--
-- Hasta ahora la fecha cliente vivía repetida en cada entregable
-- (entregables.fecha_comprometida_cliente) y el panel la deducía de las
-- tareas. Desde ahora hay UNA sola por oportunidad:
--   oportunidades.fecha_comprometida_cliente
-- La fecha interna de cada tarea sigue siendo entregables.fecha_entrega.
--
-- Compatibilidad:
--   · "add column if not exists": se puede correr varias veces.
--   · Backfill seguro: solo completa las oportunidades que todavía no tienen
--     fecha maestra, tomándola de sus tareas (la más próxima entre las
--     pendientes; si no hay, la más próxima de la ronda vigente; si tampoco,
--     la más reciente registrada). Es el mismo criterio que usa el panel.
--   · No borra ni modifica entregables.fecha_comprometida_cliente: queda como
--     antecedente histórico.
--   · Mientras no se corra, el panel recupera la fecha de las tareas al cargar
--     y la mantiene solo en el navegador.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

alter table public.oportunidades add column if not exists fecha_comprometida_cliente date;

comment on column public.oportunidades.fecha_comprometida_cliente is
  'Fecha comprometida con el cliente del proyecto (dato maestro). La fecha interna de cada tarea es entregables.fecha_entrega.';

-- 1) La más próxima entre las tareas pendientes.
update public.oportunidades o
set fecha_comprometida_cliente = s.f
from (
  select oportunidad_identificador, min(fecha_comprometida_cliente) as f
  from public.entregables
  where fecha_comprometida_cliente is not null and estado = 'pendiente'
  group by oportunidad_identificador
) s
where o."Identificador" = s.oportunidad_identificador
  and o.fecha_comprometida_cliente is null;

-- 2) Si no hay pendientes con fecha: la más próxima de la ronda vigente.
update public.oportunidades o
set fecha_comprometida_cliente = s.f
from (
  select e.oportunidad_identificador, min(e.fecha_comprometida_cliente) as f
  from public.entregables e
  join public.oportunidades op on op."Identificador" = e.oportunidad_identificador
  where e.fecha_comprometida_cliente is not null
    and coalesce(e.ronda, 1) = coalesce(op.ronda_actual, 1)
  group by e.oportunidad_identificador
) s
where o."Identificador" = s.oportunidad_identificador
  and o.fecha_comprometida_cliente is null;

-- 3) Si tampoco: la más reciente que haya registrado.
update public.oportunidades o
set fecha_comprometida_cliente = s.f
from (
  select oportunidad_identificador, max(fecha_comprometida_cliente) as f
  from public.entregables
  where fecha_comprometida_cliente is not null
  group by oportunidad_identificador
) s
where o."Identificador" = s.oportunidad_identificador
  and o.fecha_comprometida_cliente is null;

-- Verificación
select count(*) filter (where fecha_comprometida_cliente is not null) as con_fecha_cliente,
       count(*) as total
from public.oportunidades;
