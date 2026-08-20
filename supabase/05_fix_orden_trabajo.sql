-- =====================================================================
-- MIGRACIÓN — dos columnas que el panel necesita y esta base no tiene:
--
--   orden_trabajo     La secuencia manual de trabajo (1, 2, 3 … N) que se edita
--                     en Detalle > Oportunidades > "Orden de trabajo". Es un
--                     entero libre: NO está limitado a 4, no es una categoría y
--                     no alimenta ningún tablero.
--   prioridad_tablero La columna del tablero de Prioridades de Revisión semanal
--                     (1=Crítico, 2=Importante, 3=Programado, 4=En proceso), que
--                     se edita arrastrando las cards. Independiente de la anterior.
--
-- Mientras falten, el panel sigue guardando TODO lo demás en la nube (detecta las
-- columnas ausentes y las omite), pero esos dos campos se quedan solo en el
-- navegador de cada persona y no se comparten con el equipo.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Secuencia de trabajo — entero libre >= 1
-- ---------------------------------------------------------------------
alter table public.oportunidades
  add column if not exists orden_trabajo integer default 1;

-- Si la columna venía de una versión anterior con el techo en 4, ese CHECK
-- rechazaría cualquier secuencia de 5 en adelante: se reemplaza por "> 0".
alter table public.oportunidades
  drop constraint if exists oportunidades_orden_trabajo_check;

alter table public.oportunidades
  add constraint oportunidades_orden_trabajo_check
  check (orden_trabajo is null or orden_trabajo >= 1);

-- ---------------------------------------------------------------------
-- 2) Prioridad del tablero — 1 a 4, con etiqueta fija
-- ---------------------------------------------------------------------
alter table public.oportunidades
  add column if not exists prioridad_tablero smallint default 3;

alter table public.oportunidades
  drop constraint if exists oportunidades_prioridad_tablero_check;

alter table public.oportunidades
  add constraint oportunidades_prioridad_tablero_check
  check (prioridad_tablero is null or prioridad_tablero between 1 and 4);

-- Las filas existentes quedan en NULL (el default solo aplica a filas nuevas).
-- El panel las trata como "sin asignar" y les da su valor inicial al cargar, pero
-- se rellenan aquí para que la base quede coherente por sí sola.
update public.oportunidades set prioridad_tablero = 3 where prioridad_tablero is null;

-- La secuencia arranca siguiendo el Identificador: es un orden arbitrario pero
-- estable y sin repetidos, mejor que dejar todas las filas en el mismo número.
-- El equipo lo reacomoda a mano desde el panel.
--
-- Ojo con la condición: "add column ... default 1" ya rellena las filas
-- existentes con 1, así que NO quedan en NULL y un "where orden_trabajo is null"
-- no las alcanzaría (fue el error de la primera versión de este script). Se
-- numeran las que están en el valor por defecto y todavía no tienen una
-- secuencia propia asignada desde el panel.
with numeradas as (
  select "Identificador", row_number() over (order by "Identificador") as pos
  from public.oportunidades
)
update public.oportunidades o
set orden_trabajo = n.pos
from numeradas n
where o."Identificador" = n."Identificador"
  and (o.orden_trabajo is null or o.orden_trabajo = 1);

comment on column public.oportunidades.orden_trabajo is
  'Secuencia manual de trabajo (entero >= 1, sin techo). Independiente de prioridad_tablero.';
comment on column public.oportunidades.prioridad_tablero is
  'Columna del tablero de Prioridades de Revisión semanal: 1=Crítico, 2=Importante, 3=Programado, 4=En proceso.';

-- ---------------------------------------------------------------------
-- Verificación: debe listar las dos columnas.
-- ---------------------------------------------------------------------
select column_name, data_type, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'oportunidades'
  and column_name in ('orden_trabajo','prioridad_tablero')
order by column_name;
