-- =====================================================================
-- 29: Control de horarios (Gestión de equipos · subvista «Control de horarios»)
--
-- control_horarios   una fila por registro del módulo, con el detalle en jsonb:
--   tipo = 'regla'      cambio de jornada (puntual, por rango o recurrente).
--                       datos: {persona, desde, hasta, dias[], estado O|R|C|V|P|B,
--                               nota, origen admin|solicitud, autor, anulada}
--   tipo = 'solicitud'  pedido de un colaborador. datos: {persona, desde, hasta,
--                       dias[], estado, motivo, status pendiente|aprobada|
--                       rechazada|cancelada, resueltoPor, resueltoEn, comentario}
--   tipo = 'evento'     historial de cambios (solo se inserta).
--   tipo = 'config'     equipo visible en el calendario (ocultos / agregados).
--
-- La programación base Nov–Dic 2026 vive en el panel (no se guarda acá): las
-- filas solo registran lo que cambia sobre ella.
--
-- Permisos:
--   · Leen todos los perfiles con rol.
--   · El admin crea y modifica todo (aplica cambios, aprueba / rechaza).
--   · El resto solo inserta solicitudes y eventos, y puede cancelar SUS
--     solicitudes pendientes. El calendario no cambia hasta que el admin aprueba.
--   · Nadie borra: las reglas se anulan (datos.anulada) y quedan en el historial.
--
-- Compatibilidad: idempotente. Mientras no se corra, el panel guarda el módulo
-- solo en el navegador de cada usuario y avisa al admin.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

create table if not exists public.control_horarios (
  id             text primary key,
  tipo           text not null check (tipo in ('regla', 'solicitud', 'evento', 'config')),
  datos          jsonb not null default '{}'::jsonb,
  creado_por     text,
  creado_uid     uuid default auth.uid(),
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists control_horarios_tipo_idx on public.control_horarios (tipo);

comment on table public.control_horarios is
  'Control de horarios: reglas de jornada, solicitudes de cambio, historial y configuración del equipo.';

alter table public.control_horarios enable row level security;

drop policy if exists "horarios_select_con_perfil" on public.control_horarios;
create policy "horarios_select_con_perfil" on public.control_horarios
  for select to authenticated using (public.mi_rol() is not null);

drop policy if exists "horarios_insert" on public.control_horarios;
create policy "horarios_insert" on public.control_horarios
  for insert to authenticated with check (
    public.es_admin()
    or (public.mi_rol() is not null and tipo in ('solicitud', 'evento') and creado_uid = auth.uid())
  );

drop policy if exists "horarios_update" on public.control_horarios;
create policy "horarios_update" on public.control_horarios
  for update to authenticated
  using (
    public.es_admin()
    or (tipo = 'solicitud' and creado_uid = auth.uid() and datos->>'status' = 'pendiente')
  )
  with check (
    public.es_admin()
    or (tipo = 'solicitud' and creado_uid = auth.uid() and datos->>'status' in ('pendiente', 'cancelada'))
  );

-- Realtime: los cambios aparecen sin recargar en los demás paneles abiertos.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'control_horarios'
  ) then
    alter publication supabase_realtime add table public.control_horarios;
  end if;
end $$;
