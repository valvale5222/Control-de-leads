-- =====================================================================
-- 27: Gestión de usuarios — cambiar contraseña y eliminar usuarios
--
-- Desde el navegador (clave pública) no se puede tocar la cuenta de OTRA
-- persona en Supabase Auth. Estas dos funciones lo hacen del lado de la base,
-- y solo si quien las llama es admin (es_admin(), ver 12). Las usa
-- usuarios.html.
--
--   admin_cambiar_contrasena(uid, nueva)  -> nueva contraseña (mín. 6)
--   admin_eliminar_usuario(uid)           -> borra la cuenta y su perfil
--
-- Las contraseñas se guardan cifradas: nadie (ni el admin) puede VER la
-- actual; solo reemplazarla.
--
-- Requiere 12. Idempotente. Ejecutar en Supabase: SQL Editor -> Run.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

create or replace function public.admin_cambiar_contrasena(p_uid uuid, p_password text)
returns void
language plpgsql security definer set search_path = public, extensions, auth
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un admin puede cambiar contraseñas.' using errcode = '42501';
  end if;
  if p_password is null or length(p_password) < 6 then
    raise exception 'La contraseña debe tener al menos 6 caracteres.';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_uid;
  if not found then
    raise exception 'No existe la cuenta.';
  end if;
end;
$$;

create or replace function public.admin_eliminar_usuario(p_uid uuid)
returns void
language plpgsql security definer set search_path = public, auth
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un admin puede eliminar usuarios.' using errcode = '42501';
  end if;
  if p_uid = auth.uid() then
    raise exception 'No podés eliminar tu propia cuenta.';
  end if;
  -- Nunca dejar el panel sin admin activo.
  if exists (select 1 from public.usuario u join public.roles r on r.identificador = u.rol_id
             where (u.identificador = p_uid or u.auth_user_id = p_uid) and r.descripcion = 'admin')
     and (select count(*) from public.usuario u join public.roles r on r.identificador = u.rol_id
          where r.descripcion = 'admin' and u.activo) <= 1 then
    raise exception 'Es el único admin: asigná otro admin antes de eliminarlo.';
  end if;
  -- El perfil se borra explícito, por si la clave foránea no tiene cascada.
  delete from public.usuario where identificador = p_uid or auth_user_id = p_uid;
  delete from auth.users where id = p_uid;
end;
$$;

revoke all on function public.admin_cambiar_contrasena(uuid, text) from public, anon;
revoke all on function public.admin_eliminar_usuario(uuid) from public, anon;
grant execute on function public.admin_cambiar_contrasena(uuid, text) to authenticated;
grant execute on function public.admin_eliminar_usuario(uuid) to authenticated;
