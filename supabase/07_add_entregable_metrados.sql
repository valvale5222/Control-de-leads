-- =====================================================================
-- MIGRACIÓN — tres columnas nuevas en "entregables" que el panel necesita
-- y esta base todavía no tiene:
--
--   requiere_metrados    Checkbox "Requiere metrados", solo aplica cuando el
--                         entregable tiene area = 'presupuestos'.
--   resp_metrados         Responsable de metrados del entregable (mismo
--                         catálogo que Arquitectura, más "otro").
--   resp_metrados_otro     Nombre libre cuando resp_metrados = 'otro'.
--
-- Antes esto vivía a nivel de la oportunidad completa (oportunidades.
-- requiere_metrados / resp_metrados / resp_metrados_otro), pero una
-- oportunidad puede tener varios entregables de Presupuestos y cada uno
-- necesita decidirlo por su cuenta. Esas columnas de "oportunidades" NO se
-- tocan ni se borran: se conservan como respaldo histórico.
--
-- Mientras falten estas columnas nuevas, el panel sigue guardando TODO lo
-- demás en la nube (detecta las columnas ausentes y las omite), pero
-- "Requiere metrados" y su responsable se quedan solo en el navegador de
-- cada persona y no se comparten con el equipo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

alter table public.entregables
  add column if not exists requiere_metrados boolean not null default false;

alter table public.entregables
  add column if not exists resp_metrados text;

alter table public.entregables
  add column if not exists resp_metrados_otro text;

comment on column public.entregables.requiere_metrados is
  'Checkbox "Requiere metrados" del entregable. Solo tiene sentido cuando area = ''presupuestos''.';
comment on column public.entregables.resp_metrados is
  'Responsable de metrados del entregable (catálogo de Arquitectura + "otro").';
comment on column public.entregables.resp_metrados_otro is
  'Nombre libre cuando resp_metrados = ''otro''.';

-- ---------------------------------------------------------------------
-- Verificación: debe listar las tres columnas.
-- ---------------------------------------------------------------------
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'entregables'
  and column_name in ('requiere_metrados','resp_metrados','resp_metrados_otro')
order by column_name;
