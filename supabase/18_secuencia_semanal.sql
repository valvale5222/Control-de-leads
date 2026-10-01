-- =====================================================================
-- 18: Secuencia semanal de Revisión semanal (Prioridades)
--
-- Cada semana tiene su propia secuencia #1…#N de proyectos:
--   · semana_revision  = lunes de la semana a la que pertenece el proyecto.
--   · secuencia_semana = posición dentro de esa semana (1 = primero).
--                        NULL = enviado como pendiente a esa semana, todavía
--                        sin incorporar a la secuencia.
-- Las columnas del tablero se derivan de la posición (#1–#5 Foco inmediato,
-- #6–#12 Siguiente, #13+ En cola). No reemplaza prioridad_tablero ni
-- orden_trabajo, que siguen intactos para las demás vistas.
--
-- Compatibilidad: "add column if not exists", se puede correr varias veces.
-- Mientras no se corra, el panel guarda la secuencia solo en el navegador y
-- sincroniza todo lo demás con normalidad.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

alter table public.oportunidades add column if not exists semana_revision  date;
alter table public.oportunidades add column if not exists secuencia_semana integer;

alter table public.oportunidades drop constraint if exists oportunidades_secuencia_semana_check;
alter table public.oportunidades add constraint oportunidades_secuencia_semana_check
  check (secuencia_semana is null or secuencia_semana >= 1);

comment on column public.oportunidades.semana_revision is
  'Lunes de la semana de Revisión semanal a la que pertenece la oportunidad.';
comment on column public.oportunidades.secuencia_semana is
  'Posición #1…#N dentro de semana_revision. NULL = pendiente de incorporar a esa semana.';

select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'oportunidades'
  and column_name in ('semana_revision','secuencia_semana');
