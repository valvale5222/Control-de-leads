-- =====================================================================
-- 21: Incidencias de desempeño
--
-- Registro manual y cualitativo (positivo / negativo) por responsable,
-- vinculado a la oportunidad y, si corresponde, a una tarea. Se guarda en la
-- misma fila de la oportunidad, igual que "apoyos":
--   [{ id, responsable, area, tipo: 'positiva'|'negativa', descripcion,
--      fecha (ISO), entregableId (o null), autor }]
-- No modifica fechas, estado ni lógica de los entregables.
--
-- Compatibilidad: "add column if not exists", se puede correr varias veces.
-- Mientras no se corra, el panel guarda las incidencias solo en el navegador.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

alter table public.oportunidades add column if not exists incidencias jsonb not null default '[]'::jsonb;

comment on column public.oportunidades.incidencias is
  'Incidencias de desempeño (manuales): [{id, responsable, area, tipo, descripcion, fecha, entregableId, autor}]';

select count(*) filter (where jsonb_array_length(incidencias) > 0) as con_incidencias,
       count(*) as total
from public.oportunidades;
