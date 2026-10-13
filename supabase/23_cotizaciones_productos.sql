-- =====================================================================
-- 23: Cotizaciones alternativas y productos de la oportunidad
--
-- cotizaciones   jsonb  [{id, descripcion, importe, estado, principal}]
--                Son alternativas excluyentes: el importe que cuenta (pipeline,
--                Gerencia, reportes) sigue siendo la columna importe, que el
--                panel mantiene igual al de la cotización principal.
-- productos      jsonb  ["Arándanos","Palta",...]  (categoría Frutas / Verduras)
-- productos_otro text   texto libre cuando se marca "Otros".
--
-- Compatibilidad: "add column if not exists", se puede correr varias veces.
-- Mientras no se corra, el panel guarda estos campos solo en el navegador.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

alter table public.oportunidades add column if not exists cotizaciones   jsonb;
alter table public.oportunidades add column if not exists productos      jsonb;
alter table public.oportunidades add column if not exists productos_otro text;
