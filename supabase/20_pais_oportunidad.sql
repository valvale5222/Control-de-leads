-- =====================================================================
-- 20: País de la oportunidad
--
-- Valores: peru, colombia, ecuador, mexico, marruecos, chile, otros.
-- Zona y Región siguen siendo de Perú (solo se muestran cuando el país es
-- Perú). Las oportunidades que ya tienen zona o región cargadas se marcan
-- como Perú.
--
-- Compatibilidad: "add column if not exists", se puede correr varias veces.
-- Mientras no se corra, el panel guarda el país solo en el navegador.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

alter table public.oportunidades add column if not exists pais text;

alter table public.oportunidades drop constraint if exists oportunidades_pais_check;
alter table public.oportunidades add constraint oportunidades_pais_check
  check (pais is null or pais in ('peru','colombia','ecuador','mexico','marruecos','chile','otros'));

update public.oportunidades
set pais = 'peru'
where pais is null and (zona is not null or region is not null);

select pais, count(*) from public.oportunidades group by pais order by pais;
