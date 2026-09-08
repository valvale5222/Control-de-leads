-- =====================================================================
-- MIGRACIÓN — dos columnas nuevas en "entregables" que el panel necesita y
-- esta base todavía no tiene:
--
--   pendiente_envio_cliente        Check "Pendiente por enviar al cliente" del
--                                   entregable ya completado. Es el que engendra
--                                   el entregable de Comercial.
--   envio_origen_identificador     Vínculo del entregable "Enviar al cliente"
--                                   con el entregable que lo pidió. NULL en
--                                   cualquier otro entregable.
--
-- Contexto: cuando Arquitectura o Presupuestos termina un entregable, casi nunca
-- sale al cliente en ese mismo momento — queda esperando a que Comercial lo
-- mande. Ese paso intermedio no existía en el panel: el área ya no tenía nada
-- que hacer, pero el cliente tampoco había recibido nada, y la oportunidad se
-- veía como si ya estuviera en cancha del cliente.
--
-- Al marcar el check en un entregable completado, el panel crea un segundo
-- entregable de área 'comercial' llamado «Enviar al cliente — "<nombre del
-- origen>"» en la misma oportunidad, a nombre del KAM, con fecha de entrega al
-- día siguiente y en la misma ronda que su origen. Es un entregable normal:
-- aparece en Revisión semanal, Prioridades, Calendario, Carga de trabajo,
-- Cronograma, KPIs y en los filtros por Área = Comercial como cualquier otro.
-- Es el mismo patrón que el "Metrado" de la migración 15, con otra área.
--
-- Los dos gestos que lo cierran NO significan lo mismo:
--   · Completar el envío  = ya se mandó. El panel pone etapa = 'analisis' y
--                           responsable_actual = 'cliente' en la oportunidad, y
--                           por la regla de la etapa pasa a la vista Entregas.
--   · Desmarcar el check  = esto nunca debió existir. Borra el envío y no toca
--                           ni la etapa ni el responsable, para que un error de
--                           clic no reporte como enviado algo que jamás salió.
--
-- envio_origen_identificador va sin clave foránea a public.entregables por la
-- misma razón que metrado_origen_identificador: el panel sube el estado completo
-- como snapshot (upsert + delete de lo que ya no existe), y una restricción entre
-- filas de la misma tabla haría fallar ese borrado según el orden en que caen el
-- entregable de origen y su envío. La integridad del vínculo la mantiene el panel.
--
-- Mientras falten estas columnas, el panel sigue guardando TODO lo demás en la
-- nube (detecta las columnas ausentes y las omite). Lo único que se pierde al
-- recargar es el vínculo y el check: el entregable "Enviar al cliente" sobrevive
-- como un entregable normal de Comercial —el trabajo pendiente no se pierde—,
-- solo deja de estar enlazado con su origen.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- Es idempotente: se puede correr varias veces sin efecto adicional.
-- =====================================================================

alter table public.entregables
  add column if not exists pendiente_envio_cliente boolean not null default false;

alter table public.entregables
  add column if not exists envio_origen_identificador integer;

comment on column public.entregables.pendiente_envio_cliente is
  'Check "Pendiente por enviar al cliente": el área ya terminó el entregable y falta que Comercial lo mande. Al marcarlo, el panel crea el entregable "Enviar al cliente" vinculado por envio_origen_identificador.';

comment on column public.entregables.envio_origen_identificador is
  'Identificador del entregable que generó este "Enviar al cliente". NULL en cualquier otro entregable; es la relación que evita envíos duplicados y permite borrar solo el envío al desmarcar el check.';

create index if not exists entregables_envio_origen_idx
  on public.entregables (envio_origen_identificador)
  where envio_origen_identificador is not null;

-- ---------------------------------------------------------------------
-- Verificación 1: deben listar las dos columnas (boolean not null default
-- false, e integer nullable sin default).
-- ---------------------------------------------------------------------
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
  and table_name = 'entregables'
  and column_name in ('pendiente_envio_cliente', 'envio_origen_identificador')
order by column_name;

-- ---------------------------------------------------------------------
-- Verificación 2: recién migrada, ninguna fila tiene check ni vínculo
-- (pendientes_de_envio = 0 y con_vinculo = 0).
-- ---------------------------------------------------------------------
select count(*)                                                as total,
       count(*) filter (where pendiente_envio_cliente is true)  as pendientes_de_envio,
       count(envio_origen_identificador)                        as con_vinculo
from public.entregables;

-- ---------------------------------------------------------------------
-- Verificación 3 (después de usar el panel): cada "Enviar al cliente" debe
-- apuntar a un entregable existente de la misma oportunidad, y ese origen debe
-- estar completado. Esta consulta debe devolver 0 filas.
-- ---------------------------------------------------------------------
select e."Identificador" as envio, e.envio_origen_identificador as origen
from public.entregables e
left join public.entregables o
  on o."Identificador" = e.envio_origen_identificador
 and o.oportunidad_identificador = e.oportunidad_identificador
where e.envio_origen_identificador is not null
  and (o."Identificador" is null or coalesce(o.estado,'') <> 'completado');

-- ---------------------------------------------------------------------
-- Verificación 4 (después de usar el panel): todo entregable con el check
-- marcado debe tener su envío, y todo envío debe ser del área Comercial.
-- Ambas consultas deben devolver 0 filas.
-- ---------------------------------------------------------------------
select o."Identificador" as sin_envio
from public.entregables o
where o.pendiente_envio_cliente is true
  and not exists (
    select 1 from public.entregables e
    where e.envio_origen_identificador = o."Identificador"
  );

select e."Identificador" as envio_fuera_de_comercial, e.area
from public.entregables e
where e.envio_origen_identificador is not null
  and coalesce(e.area,'') <> 'comercial';
