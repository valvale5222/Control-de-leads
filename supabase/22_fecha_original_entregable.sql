-- =====================================================================
-- 22: Fecha planificada ORIGINAL de cada entregable
--
-- Cada tarea maneja tres fechas:
--   · fecha_original   — planificada original (NUEVA): se fija una sola vez y
--                        no cambia nunca. Es la referencia del "cumplimiento
--                        original" en Desempeño.
--   · fecha_entrega    — vigente (actual / reprogramada). Ya existía.
--   · fecha_completado — real, automática al completar. Ya existía.
-- Las reprogramaciones (anterior, nueva, fecha/hora, usuario) ya quedan en
-- public.historial_oportunidades ("Reprogramación (fecha interna)").
--
-- Cómo se llena para las tareas existentes:
--   Lo hace el PANEL al abrirse con un usuario editor: toma la primera fecha
--   registrada en el historial de cada tarea (la original real, aunque luego
--   se haya reprogramado) y, si la tarea no tiene cambios de fecha en el
--   historial, usa su fecha vigente. Después la sube a esta columna.
--   Por eso este script NO rellena con fecha_entrega: así la base no congela
--   una vigente como si fuera la original.
--
-- Compatibilidad:
--   · "add column if not exists": se puede correr varias veces.
--   · Si ya se había corrido la versión anterior de este script (que copiaba
--     fecha_entrega), el paso 2 vacía SOLO las originales iguales a la vigente
--     para que el panel las vuelva a calcular desde el historial. Las que ya
--     difieren de la vigente no se tocan.
--   · Trigger: una vez fijada, la fecha original no se puede modificar ni
--     vaciar desde un update (aunque lo intente una versión vieja del panel).
--     Una tarea nueva sin original toma su fecha vigente al insertarse.
--   · Mientras no se corra, el panel guarda la fecha original solo en el
--     navegador y sincroniza todo lo demás.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

-- 1) Columna.
alter table public.entregables add column if not exists fecha_original date;

comment on column public.entregables.fecha_original is
  'Fecha planificada original de la tarea (inmutable). La vigente es fecha_entrega; la real, fecha_completado.';

-- 2) Re-cálculo seguro de las ambiguas (sin trigger mientras tanto).
drop trigger if exists trg_entregables_fecha_original on public.entregables;

update public.entregables
set fecha_original = null
where fecha_original is not null
  and fecha_original = fecha_entrega;

-- 3) Inmutabilidad.
create or replace function public.entregables_fecha_original_inmutable()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    -- Ya fijada: se conserva siempre.
    if old.fecha_original is not null then
      new.fecha_original := old.fecha_original;
    end if;
  elsif new.fecha_original is null and new.fecha_entrega is not null then
    -- INSERT de una tarea nueva sin original: nace con su fecha vigente.
    new.fecha_original := new.fecha_entrega;
  end if;
  return new;
end;
$$;

create trigger trg_entregables_fecha_original
  before insert or update on public.entregables
  for each row execute function public.entregables_fecha_original_inmutable();

-- Estado: después de abrir el panel con un editor, "sin_original" debería
-- quedar en 0 (salvo tareas sin ninguna fecha).
select count(*) filter (where fecha_original is not null) as con_fecha_original,
       count(*) filter (where fecha_original is null and fecha_entrega is not null) as sin_original,
       count(*) filter (where fecha_original is not null and fecha_entrega is not null and fecha_original <> fecha_entrega) as reprogramadas,
       count(*) as total
from public.entregables;
