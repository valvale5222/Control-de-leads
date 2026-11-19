-- =====================================================================
-- TEST 99 · Limpieza segura de los datos TEST
--
-- Borra SOLO lo que la prueba integral (TEST_01) y la verificación manual
-- marcaron como prueba. Criterios (todos explícitos):
--   · clientes:           id_cliente 'CLI-TEST-…'
--   · oportunidades:      cliente_id 'CLI-TEST-…' o proyecto que empieza por '[TEST]'
--                         (+ sus entregables e historial)
--   · gestion_comercial:  id 'TEST-…', datos.test = true, empresa/cliente CLI-TEST-…,
--                         título o nombre que empieza por '[TEST]', o vinculado
--                         (leadId / vínculo / solicitud) a uno de los anteriores.
--
-- Topes de seguridad (si alguno salta, NO se borra nada):
--   · una oportunidad con cliente CLI-TEST-… cuyo proyecto no empieza por
--     '[TEST]' → se detiene: puede ser un registro real mal vinculado.
--   · más de 10 oportunidades o más de 200 registros comerciales candidatos.
--
-- Uso: Supabase → SQL Editor → pegar → Run. El resultado muestra lo borrado y
-- un control final (debe quedar todo en 0). Se puede correr varias veces.
-- Antes de correrlo: que nadie tenga abierta la ficha de un registro TEST en el
-- panel (al guardar volvería a subirlo). Después: recargar los paneles abiertos.
-- =====================================================================

begin;

drop table if exists pg_temp._borr;
create temporary table _borr (tabla text, id text, detalle text);

-- 1) Candidatos
insert into _borr
select 'oportunidades', "Identificador"::text, coalesce(proyecto, '') || ' · ' || coalesce(cliente, '')
  from public.oportunidades
 where cliente_id like 'CLI-TEST-%' or proyecto like '[TEST]%';

with recursive base as (
  select g.id from public.gestion_comercial g
   where g.id like 'TEST-%'
      or g.datos ->> 'test' = 'true'
      or g.id like 'CLI-TEST-%'
      or g.datos ->> 'empresaId' like 'CLI-TEST-%'
      or g.datos ->> 'titulo' like '[TEST]%'
      or g.datos ->> 'nombre' like '[TEST]%'
), rel as (
  select id from base
  union
  select g.id from public.gestion_comercial g join rel on
         g.datos ->> 'leadId' = rel.id
      or g.datos -> 'vinculo' ->> 'id' = rel.id
      or g.datos -> 'conversion' ->> 'solicitudId' = rel.id
      or g.datos ->> 'contactoId' = rel.id
      or g.datos ->> 'actId' = rel.id
)
insert into _borr
select 'gestion_comercial', g.id, g.tipo || ' · ' || g.pais || ' · ' || coalesce(g.datos ->> 'titulo', g.datos ->> 'nombre', '')
  from public.gestion_comercial g where g.id in (select id from rel);

insert into _borr
select 'clientes', id_cliente, nombre from public.clientes where id_cliente like 'CLI-TEST-%';

-- 2) Topes de seguridad
do $$
declare n int;
begin
  select count(*) into n from public.oportunidades
   where cliente_id like 'CLI-TEST-%' and coalesce(proyecto, '') not like '[TEST]%';
  if n > 0 then
    raise exception 'Hay % oportunidad(es) con cliente TEST cuyo proyecto no empieza por [TEST]. Revisar a mano: no se borró nada.', n;
  end if;
  if (select count(*) from _borr where tabla = 'oportunidades') > 10 then
    raise exception 'Más de 10 oportunidades candidatas: no parece un set de prueba. No se borró nada.';
  end if;
  if (select count(*) from _borr where tabla = 'gestion_comercial') > 200 then
    raise exception 'Más de 200 registros comerciales candidatos. No se borró nada.';
  end if;
  -- Un lead TEST nunca debe haber generado una oportunidad sin marca TEST.
  select count(*) into n from public.gestion_comercial g
   where g.id in (select id from _borr where tabla = 'gestion_comercial')
     and coalesce(g.datos ->> 'opId', '') ~ '^\d+$'
     and g.pais = 'peru'
     and (g.datos ->> 'opId') not in (select id from _borr where tabla = 'oportunidades');
  if n > 0 then
    raise exception 'Un registro TEST apunta a una oportunidad sin marca TEST. Revisar a mano: no se borró nada.';
  end if;
end $$;

-- 3) Borrado (hijos primero)
delete from public.historial_oportunidades
 where oportunidad_identificador in (select id::int from _borr where tabla = 'oportunidades')
    or id like 'conv-TEST-%';
delete from public.entregables
 where oportunidad_identificador in (select id::int from _borr where tabla = 'oportunidades');
delete from public.oportunidades
 where "Identificador" in (select id::int from _borr where tabla = 'oportunidades');
delete from public.gestion_comercial
 where id in (select id from _borr where tabla = 'gestion_comercial');
delete from public.clientes
 where id_cliente in (select id from _borr where tabla = 'clientes');

commit;

-- 4) Lo borrado y control final (todo debe dar 0)
select 'borrado' as accion, tabla, id, detalle from _borr
union all
select 'control', 'quedan oportunidades TEST', count(*)::text, '' from public.oportunidades where cliente_id like 'CLI-TEST-%' or proyecto like '[TEST]%'
union all
select 'control', 'quedan registros comerciales TEST', count(*)::text, '' from public.gestion_comercial
 where id like 'TEST-%' or datos ->> 'test' = 'true' or datos ->> 'empresaId' like 'CLI-TEST-%' or datos ->> 'titulo' like '[TEST]%'
union all
select 'control', 'quedan clientes TEST', count(*)::text, '' from public.clientes where id_cliente like 'CLI-TEST-%'
order by 1, 2, 3;
