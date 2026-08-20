-- =====================================================================
-- OPCIONAL — reparto inicial del tablero de Prioridades.
--
-- La migración 05 dejó las 104 oportunidades en prioridad_tablero = 3
-- (Programado), así que el tablero arranca con una sola columna llena. Este
-- script las reparte una única vez según la urgencia real de su entregable
-- pendiente más próximo, con el mismo criterio que usaba el panel para calcular
-- la prioridad automática (calcularPrioridadOperativa):
--
--   1 = Crítico      vencido, vence hoy o dentro de 3 días
--   2 = Importante   vence dentro de 4 a 7 días
--   3 = Programado   vence más adelante, o no tiene entregables con fecha
--
-- El 4 (En proceso) no se asigna aquí: no se deduce de una fecha, es una
-- decisión de equipo. A partir de este reparto todo es manual — arrastrando las
-- cards o desde el selector "Prioridad del tablero" del modal.
--
-- CUIDADO: sobrescribe prioridad_tablero en TODAS las filas. Si el equipo ya
-- acomodó cards a mano, esos cambios se pierden. Correr solo la primera vez.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- =====================================================================

with proxima as (
  -- Entregable pendiente más próximo de cada oportunidad (el que manda la card).
  select oportunidad_identificador as opp_id,
         min(fecha_entrega) as fecha
  from public.entregables
  where estado = 'pendiente'
    and fecha_entrega is not null
  group by oportunidad_identificador
)
update public.oportunidades o
set prioridad_tablero = case
      when p.fecha is null                              then 3
      when p.fecha <= current_date + interval '3 days'  then 1
      when p.fecha <= current_date + interval '7 days'  then 2
      else 3
    end
from (select o2."Identificador" as id, pr.fecha
      from public.oportunidades o2
      left join proxima pr on pr.opp_id = o2."Identificador") p
where o."Identificador" = p.id;

-- Verificación: cuántas quedan en cada columna del tablero.
select prioridad_tablero,
       case prioridad_tablero
         when 1 then 'Crítico'
         when 2 then 'Importante'
         when 3 then 'Programado'
         when 4 then 'En proceso'
       end as etiqueta,
       count(*) as oportunidades
from public.oportunidades
group by prioridad_tablero
order by prioridad_tablero;
