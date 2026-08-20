-- =====================================================================
-- MIGRACIÓN — columna nueva en "oportunidades" que el panel necesita y
-- esta base todavía no tiene:
--
--   duracion_proyecto   Duración estimada del proyecto, en meses (entero
--                        >= 0). Se edita en Segmentación comercial >
--                        "Duración del proyecto (meses)".
--
-- Mientras falte, el panel sigue guardando TODO lo demás en la nube
-- (detecta la columna ausente y la omite), pero ese campo se queda solo en
-- el navegador de cada persona y no se comparte con el equipo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

alter table public.oportunidades
  add column if not exists duracion_proyecto integer;

alter table public.oportunidades
  drop constraint if exists oportunidades_duracion_proyecto_check;

alter table public.oportunidades
  add constraint oportunidades_duracion_proyecto_check
  check (duracion_proyecto is null or duracion_proyecto >= 0);

comment on column public.oportunidades.duracion_proyecto is
  'Duración estimada del proyecto, en meses (entero >= 0). NULL = sin definir.';

-- ---------------------------------------------------------------------
-- Verificación: debe listar la columna.
-- ---------------------------------------------------------------------
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'oportunidades'
  and column_name = 'duracion_proyecto';
