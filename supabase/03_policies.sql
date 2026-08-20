-- =====================================================================
-- POLÍTICAS RLS — elige UNA de las dos opciones y ejecútala.
-- Sin esto, con RLS habilitado (ya lo activa 01_schema.sql) nadie puede
-- leer ni escribir en las tablas desde el navegador, aunque el schema
-- y los datos ya existan.
-- =====================================================================

-- ---------------------------------------------------------------------
-- OPCIÓN A (ACTIVA) — Acceso abierto con la clave "anon"
-- Elegida para este proyecto: el panel sigue siendo una herramienta interna,
-- sin login, y la clave anon no se expone fuera del equipo (igual que hoy:
-- el HTML se abre localmente). Cualquiera con la anon key podría leer/escribir,
-- así que no distribuyas ese archivo .html ni la anon key fuera del equipo.
-- ---------------------------------------------------------------------
create policy "anon_select_oportunidades" on public.oportunidades
  for select using (true);
create policy "anon_write_oportunidades" on public.oportunidades
  for all using (true) with check (true);

create policy "anon_select_entregables" on public.entregables
  for select using (true);
create policy "anon_write_entregables" on public.entregables
  for all using (true) with check (true);

-- ---------------------------------------------------------------------
-- OPCIÓN B — Solo usuarios autenticados (recomendada si se agrega login
-- de Supabase Auth más adelante).
-- ---------------------------------------------------------------------
-- create policy "auth_select_oportunidades" on public.oportunidades
--   for select using (auth.role() = 'authenticated');
-- create policy "auth_write_oportunidades" on public.oportunidades
--   for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- create policy "auth_select_entregables" on public.entregables
--   for select using (auth.role() = 'authenticated');
-- create policy "auth_write_entregables" on public.entregables
--   for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
