-- =====================================================================
-- 10: Revertir el login obligatorio (09_auth_login.sql)
-- Se descartó el login con Supabase Auth. Este script devuelve las
-- políticas de oportunidades/entregables al acceso abierto con la clave
-- "anon" (igual que 03_policies.sql, opción A), para que el panel vuelva
-- a funcionar sin necesidad de iniciar sesión.
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y correr.
-- =====================================================================

drop policy if exists "auth_select_oportunidades" on public.oportunidades;
drop policy if exists "auth_write_oportunidades" on public.oportunidades;
create policy "anon_select_oportunidades" on public.oportunidades
  for select using (true);
create policy "anon_write_oportunidades" on public.oportunidades
  for all using (true) with check (true);

drop policy if exists "auth_select_entregables" on public.entregables;
drop policy if exists "auth_write_entregables" on public.entregables;
create policy "anon_select_entregables" on public.entregables
  for select using (true);
create policy "anon_write_entregables" on public.entregables
  for all using (true) with check (true);
