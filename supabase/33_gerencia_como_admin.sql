-- =====================================================================
-- 33: Gerencia con permisos de administrador
--
-- Gerencia (Misael Estrada) pasa a tener los mismos permisos que admin en
-- todo el panel, con dos excepciones:
--   · Gestión de usuarios: sigue siendo solo admin (tabla usuario, cambiar
--     contraseñas, eliminar / activar / desactivar cuentas). es_admin() no
--     se toca.
--   · Gestión Comercial: conserva sus reglas propias de 31 (consulta todo,
--     aprueba conversiones ya validadas por administración). gcm_control y
--     las políticas de gestion_comercial no se tocan.
--
-- Qué cambia:
--   puede_editar()   admin, editor y gerencia -> Planner (oportunidades,
--                    entregables, historial) y Base Maestra de Clientes.
--   puede_accion()   gerencia, como admin.
--   control_horarios gerencia administra reglas y resuelve solicitudes.
--
-- Requiere 12, 25, 29 y 31. Idempotente. Ejecutar en Supabase:
-- SQL Editor -> pegar y Run.
-- =====================================================================

do $$
begin
  if to_regprocedure('public.es_gerencia()') is null then
    raise exception 'Falta correr 31_perfiles_permisos.sql.';
  end if;
  if to_regclass('public.control_horarios') is null then
    raise exception 'Falta correr 29_control_horarios.sql.';
  end if;
end $$;


-- 1) Escritura del Planner y de la Base Maestra de Clientes.
create or replace function public.puede_editar()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.mi_rol() in ('admin', 'gerencia', 'editor'), false);
$$;


-- 2) Acciones por perfil.
create or replace function public.puede_accion(p_accion text)
returns boolean
language sql security definer set search_path = public stable
as $$
  select case public.mi_rol()
    when 'admin' then true
    when 'gerencia' then true
    when 'editor' then true
    when 'operativo_restringido'
      then p_accion = 'ver'
           and coalesce((public.mi_permisos() -> 'acciones' ->> 'ver')::boolean, false)
    else false
  end;
$$;


-- 3) Control de horarios: gerencia administra como admin.
drop policy if exists "horarios_insert" on public.control_horarios;
create policy "horarios_insert" on public.control_horarios
  for insert to authenticated with check (
    public.es_admin() or public.es_gerencia()
    or (public.mi_rol() is not null and tipo in ('solicitud', 'evento') and creado_uid = auth.uid())
  );

drop policy if exists "horarios_update" on public.control_horarios;
create policy "horarios_update" on public.control_horarios
  for update to authenticated
  using (
    public.es_admin() or public.es_gerencia()
    or (tipo = 'solicitud' and creado_uid = auth.uid() and datos->>'status' = 'pendiente')
  )
  with check (
    public.es_admin() or public.es_gerencia()
    or (tipo = 'solicitud' and creado_uid = auth.uid() and datos->>'status' in ('pendiente', 'cancelada'))
  );


-- Verificación: cada perfil y si puede editar el Planner.
select r.descripcion as perfil,
       r.descripcion in ('admin', 'gerencia', 'editor') as edita_planner,
       r.descripcion = 'admin' as gestiona_usuarios
from public.roles r
order by r.identificador;
