-- =====================================================================
-- MIGRACIÓN — columna nueva en "oportunidades" que el panel necesita y
-- esta base todavía no tiene:
--
--   fecha_seguimiento   Fecha de seguimiento comercial de la oportunidad
--                        (DATE). Se edita en la ficha de la oportunidad,
--                        en "C. Seguimiento comercial", justo antes de
--                        "Próximo paso".
--
-- Es la ÚNICA fuente de la columna "Fecha de seguimiento" y del grid
-- resumen de Detalle > Entregas: ya no se deriva de la fecha de entrega
-- de ningún entregable ni tiene ningún otro fallback. Sin valor cargado,
-- las vistas muestran "—".
--
-- Las oportunidades que ya existen quedan en NULL a propósito: NO se
-- rellenan con fechas anteriores (fecha_entrega de entregables,
-- f_comprometida, etc.). Cada una se carga a mano cuando corresponda.
--
-- Mientras falte, el panel sigue guardando TODO lo demás en la nube
-- (detecta la columna ausente y la omite), pero ese campo se queda solo
-- en el navegador de cada persona y no se comparte con el equipo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

alter table public.oportunidades
  add column if not exists fecha_seguimiento date;

comment on column public.oportunidades.fecha_seguimiento is
  'Fecha de seguimiento comercial de la oportunidad. NULL = sin seguimiento agendado; es la única fuente de la columna y el resumen de Detalle > Entregas.';

-- ---------------------------------------------------------------------
-- Verificación 1: debe listar la columna, con is_nullable = YES y sin default.
-- ---------------------------------------------------------------------
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'oportunidades'
  and column_name = 'fecha_seguimiento';

-- ---------------------------------------------------------------------
-- Verificación 2: recién migrada, todas las filas existentes deben quedar
-- en NULL (con_fecha = 0).
-- ---------------------------------------------------------------------
select count(*) as total,
       count(fecha_seguimiento) as con_fecha
from public.oportunidades;
