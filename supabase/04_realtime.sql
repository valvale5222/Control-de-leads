-- =====================================================================
-- REALTIME — habilita el envío por websocket de los cambios de las tablas.
-- Sin esto, el panel sigue guardando y leyendo, pero una pestaña NO se
-- entera de lo que hace otra hasta recargar.
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- =====================================================================

-- "add table" falla si la tabla ya es miembro de la publicación, así que se
-- consulta antes para que este script se pueda correr las veces que sea.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'oportunidades'
  ) then
    alter publication supabase_realtime add table public.oportunidades;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'entregables'
  ) then
    alter publication supabase_realtime add table public.entregables;
  end if;
end $$;

-- Verificación: debe devolver las dos tablas.
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime' and schemaname = 'public';
