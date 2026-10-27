-- 007_business_policies.sql
-- Políticas CRUD estándar para tablas de negocio:
--   SELECT  -> Admin, Editor, Visualizador (activos)
--   INSERT  -> Admin, Editor
--   UPDATE  -> Admin, Editor
--   DELETE  -> Admin
--
-- Uso (en una migración posterior, por cada tabla de negocio):
--   select public.apply_crud_policies('public.productos');

create or replace function public.apply_crud_policies(tbl regclass)
returns void
language plpgsql
set search_path = ''
as $$
begin
  execute format('alter table %s enable row level security', tbl);
  execute format('revoke all on %s from anon', tbl);

  execute format('drop policy if exists crud_select on %s', tbl);
  execute format('drop policy if exists crud_insert on %s', tbl);
  execute format('drop policy if exists crud_update on %s', tbl);
  execute format('drop policy if exists crud_delete on %s', tbl);

  execute format('create policy crud_select on %s for select to authenticated using (public.can_read())', tbl);
  execute format('create policy crud_insert on %s for insert to authenticated with check (public.can_write())', tbl);
  execute format('create policy crud_update on %s for update to authenticated using (public.can_write()) with check (public.can_write())', tbl);
  execute format('create policy crud_delete on %s for delete to authenticated using (public.can_delete())', tbl);
end;
$$;

revoke execute on function public.apply_crud_policies(regclass) from public, anon, authenticated, service_role;

-- Ejemplo (descomentar y adaptar):
-- select public.apply_crud_policies('public.productos');
