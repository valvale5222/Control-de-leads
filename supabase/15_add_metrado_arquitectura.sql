-- =====================================================================
-- MIGRACIÓN — columna nueva en "entregables" que el panel necesita y esta
-- base todavía no tiene:
--
--   metrado_origen_identificador   Vínculo del entregable "Metrado"
--                                   autogenerado con el entregable de
--                                   Arquitectura que lo pidió. NULL en
--                                   cualquier otro entregable.
--
-- Contexto: "Requiere metrado" era un checkbox de los entregables de
-- Presupuestos e Ingeniería y ahora es una lógica exclusiva de Arquitectura.
-- Al marcarlo en un entregable de Arquitectura, el panel crea un segundo
-- entregable de Arquitectura llamado "Metrado" en la misma oportunidad, que
-- hereda su fecha de entrega, prioridad y ronda, toma el responsable elegido
-- para el metrado y arranca en estado 'pendiente'. Es un entregable normal:
-- aparece en Revisión semanal, Prioridades, Calendario, Carga de trabajo,
-- Cronograma, KPIs y filtros de Arquitectura como cualquier otro, y conserva
-- su propio estado (completar el Metrado NO completa su entregable de
-- Arquitectura, ni al revés).
--
-- Esta columna es la relación que evita duplicados: mientras el entregable de
-- Arquitectura ya tenga un Metrado apuntándole, volver a marcar el checkbox no
-- crea otro, y desmarcarlo borra únicamente ese Metrado.
--
-- Las columnas de la migración 07 se siguen usando, con el nuevo alcance:
--   requiere_metrados     ahora solo tiene sentido con area = 'arquitectura'.
--   resp_metrados         el responsable elegido para el metrado.
--   resp_metrados_otro    su nombre libre cuando resp_metrados = 'otro'.
-- Los entregables de otras áreas que traían requiere_metrados = true se
-- limpian solos al abrir el panel (ver ensureNuevosCampos en index.html) y el
-- siguiente guardado sube esa limpieza; abajo queda el UPDATE equivalente por
-- si se prefiere hacerlo directo en la base.
--
-- Sin clave foránea a public.entregables a propósito: el panel sube el estado
-- completo como snapshot (upsert + delete de lo que ya no existe), y una
-- restricción entre filas de la misma tabla haría fallar ese borrado según el
-- orden en que caen el entregable de Arquitectura y su Metrado. La integridad
-- del vínculo la mantiene el panel.
--
-- Mientras falte esta columna, el panel sigue guardando TODO lo demás en la
-- nube (detecta la columna ausente y la omite), pero el vínculo se queda solo
-- en el navegador de cada persona: al recargar, el panel intenta reenlazar el
-- "Metrado" suelto de la misma ronda y, si no lo encuentra, deja el checkbox
-- desmarcado en vez de duplicar el entregable.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

alter table public.entregables
  add column if not exists metrado_origen_identificador integer;

comment on column public.entregables.metrado_origen_identificador is
  'Identificador del entregable de Arquitectura que generó este "Metrado". NULL en cualquier otro entregable; es la relación que evita metrados duplicados.';

comment on column public.entregables.requiere_metrados is
  'Checkbox "Requiere metrado" del entregable. Solo tiene sentido cuando area = ''arquitectura''; al marcarlo el panel crea el entregable "Metrado" vinculado por metrado_origen_identificador.';
comment on column public.entregables.resp_metrados is
  'Responsable elegido para el metrado (catálogo de Arquitectura + "otro"). Baja al entregable "Metrado" como su responsable.';

create index if not exists entregables_metrado_origen_idx
  on public.entregables (metrado_origen_identificador)
  where metrado_origen_identificador is not null;

-- ---------------------------------------------------------------------
-- Limpieza del alcance anterior: "Requiere metrados" ya no existe fuera de
-- Arquitectura, así que los entregables de otras áreas no deben arrastrar un
-- responsable de metrado invisible. El panel hace lo mismo al cargar.
-- ---------------------------------------------------------------------
update public.entregables
set requiere_metrados = false,
    resp_metrados = null,
    resp_metrados_otro = null
where coalesce(area, '') <> 'arquitectura'
  and (requiere_metrados is true or resp_metrados is not null or resp_metrados_otro is not null);

-- ---------------------------------------------------------------------
-- Verificación 1: debe listar la columna (integer, nullable, sin default).
-- ---------------------------------------------------------------------
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'entregables'
  and column_name = 'metrado_origen_identificador';

-- ---------------------------------------------------------------------
-- Verificación 2: recién migrada, ninguna fila tiene vínculo todavía
-- (con_vinculo = 0) y no queda ningún "Requiere metrados" fuera de
-- Arquitectura (fuera_de_arquitectura = 0).
-- ---------------------------------------------------------------------
select count(*)                                        as total,
       count(metrado_origen_identificador)             as con_vinculo,
       count(*) filter (where requiere_metrados is true
                          and coalesce(area,'') <> 'arquitectura') as fuera_de_arquitectura
from public.entregables;

-- ---------------------------------------------------------------------
-- Verificación 3 (después de usar el panel): cada "Metrado" debe apuntar a un
-- entregable de Arquitectura existente y de la misma oportunidad. Esta consulta
-- debe devolver 0 filas.
-- ---------------------------------------------------------------------
select m."Identificador" as metrado, m.metrado_origen_identificador as origen
from public.entregables m
left join public.entregables o
  on o."Identificador" = m.metrado_origen_identificador
 and o.oportunidad_identificador = m.oportunidad_identificador
 and o.area = 'arquitectura'
where m.metrado_origen_identificador is not null
  and o."Identificador" is null;
