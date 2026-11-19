-- =====================================================================
-- 30: Gestión Comercial integrada (Perú y Colombia)
--
-- gestion_comercial   una fila por registro comercial, con su detalle en jsonb.
--   tipo = 'empresa'    datos comerciales de un cliente de la Base Maestra
--                       (id = clientes.id_cliente, CLI-xxxx): RUC/NIT, rubro,
--                       sedes. El nombre sigue siendo el de la Base Maestra.
--   tipo = 'contacto'   persona de contacto de una empresa (sede, zona, país,
--                       ejecutivo responsable, gestión compartida).
--   tipo = 'lead'       necesidad comercial detectada. Registro progresivo:
--                       datos.campos se completa a medida que avanza.
--   tipo = 'actividad'  visita, reunión o llamada de la agenda. Estado
--                       operativo (Programada, Reprogramada, Realizada,
--                       Cancelada) separado del resultado comercial del
--                       reporte (Positiva, Neutra, Descartada), acompañantes
--                       internos y su historial de reprogramaciones.
--   tipo = 'tarea'      tarea comercial vinculada a un lead, un cliente o una
--                       oportunidad (vinculo.tipo + vinculo.id). Estados:
--                       Pendiente, En proceso, Completada («Vencida» se
--                       calcula). origen = reporte de visita que la generó.
--   tipo = 'evento'     interacción registrada (llamada, correo, reunión,
--                       nota, acuerdo) para el historial único.
--   tipo = 'solicitud'  solicitudes de conversión de lead a oportunidad.
--                       Estructura preparada: el flujo de aprobación llega en
--                       la etapa 2.
--   tipo = 'permiso'    permisos configurables por país y usuario
--                       (datos: {usuario, pais, rol, paises[], permisos{}}).
--                       Los administra el admin (etapa 2).
--
-- pais         'peru' | 'colombia': aislamiento de datos por operación.
-- responsable  ejecutivo o responsable del registro (para filtros y reportes).
--
-- Los identificadores existentes no cambian: clientes (CLI-xxxx), oportunidades
-- (Identificador) y usuarios se referencian, nunca se copian ni se recrean.
--
-- Permisos:
--   · Leen y escriben los perfiles con rol, salvo el perfil operativo
--     restringido (no tiene acceso a Gestión Comercial).
--   · Los permisos ('permiso') solo los escribe el admin.
--   · Nadie borra: los registros se cierran, completan o anulan (datos.anulado)
--     y se conservan en el historial.
--
-- Compatibilidad: idempotente. Mientras no se corra, el panel guarda Gestión
-- Comercial solo en el navegador de cada usuario y avisa al admin.
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================

create table if not exists public.gestion_comercial (
  id             text primary key,
  tipo           text not null check (tipo in ('empresa', 'contacto', 'lead', 'actividad', 'tarea', 'evento', 'solicitud', 'permiso')),
  pais           text not null default 'peru' check (pais in ('peru', 'colombia')),
  responsable    text,
  datos          jsonb not null default '{}'::jsonb,
  creado_por     text,
  creado_uid     uuid default auth.uid(),
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index if not exists gestion_comercial_tipo_idx on public.gestion_comercial (tipo);
create index if not exists gestion_comercial_pais_idx on public.gestion_comercial (pais);
create index if not exists gestion_comercial_resp_idx on public.gestion_comercial (responsable);

comment on table public.gestion_comercial is
  'Gestión Comercial (Perú y Colombia): empresas, contactos, leads, agenda, tareas, interacciones, solicitudes de conversión y permisos.';

alter table public.gestion_comercial enable row level security;

drop policy if exists "gcom_select_con_perfil" on public.gestion_comercial;
create policy "gcom_select_con_perfil" on public.gestion_comercial
  for select to authenticated
  using (public.mi_rol() is not null and public.mi_rol() <> 'operativo_restringido');

drop policy if exists "gcom_insert" on public.gestion_comercial;
create policy "gcom_insert" on public.gestion_comercial
  for insert to authenticated with check (
    public.mi_rol() is not null and public.mi_rol() <> 'operativo_restringido'
    and (tipo <> 'permiso' or public.es_admin())
  );

drop policy if exists "gcom_update" on public.gestion_comercial;
create policy "gcom_update" on public.gestion_comercial
  for update to authenticated
  using (
    public.mi_rol() is not null and public.mi_rol() <> 'operativo_restringido'
    and (tipo <> 'permiso' or public.es_admin())
  )
  with check (
    public.mi_rol() is not null and public.mi_rol() <> 'operativo_restringido'
    and (tipo <> 'permiso' or public.es_admin())
  );

-- Realtime: los cambios aparecen sin recargar en los demás paneles abiertos.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'gestion_comercial'
  ) then
    alter publication supabase_realtime add table public.gestion_comercial;
  end if;
end $$;
