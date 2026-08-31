-- =====================================================================
-- 13: Login por usuario (sin correo) + leer exige tener perfil
--
-- Dos cambios, uno de seguridad y uno de comodidad.
--
-- (A) SEGURIDAD — leer ya no alcanza con estar logueado.
--
-- El proyecto tiene "Allow new users to sign up" activado y la clave
-- publicable está a la vista en el código del sitio. Con esas dos cosas,
-- cualquiera que abra la página puede registrarse solo (un signUp con esa
-- clave) y quedar como usuario autenticado. Y las políticas de
-- 12_roles_permisos.sql dejaban leer a cualquier autenticado, así que un
-- desconocido podía listar las 108 oportunidades.
--
-- El arreglo no depende de esa configuración: para leer hay que tener perfil
-- en la tabla `usuario`, no solo sesión. Alguien que se registre por su
-- cuenta queda sin perfil, sin rol, y sin ver absolutamente nada. Es el
-- mismo criterio de negar por defecto que ya usa el panel.
--
-- Se deja el registro habilitado a propósito: usuarios.html crea las cuentas
-- con signUp usando la clave publicable, así que apagarlo rompería el alta
-- de usuarios desde el panel. Con esta política, tenerlo abierto es inocuo.
--
-- (B) COMODIDAD — la columna `usuario_login`.
--
-- Supabase Auth necesita un correo como identificador, pero el equipo no
-- tiene por qué verlo: el panel pide un usuario ("hugo") y le agrega el
-- dominio por detrás ("hugo@friopacking.pe"), que puede no existir. Para que
-- un admin pueda ver con qué usuario entra cada persona, hace falta
-- guardarlo: auth.users no es accesible desde el navegador, así que el
-- nombre de usuario no se puede leer de ahí.
--
-- Esto es, en la práctica, la columna "user" que el diseño original tenía y
-- que se había perdido (los scripts 09/11 la usaban aunque ya no existía).
--
-- Ejecutar en Supabase: Dashboard -> SQL Editor -> New query -> pegar y Run.
-- =====================================================================


-- ---------------------------------------------------------------------
-- (B) Nombre de usuario para entrar.
-- Único para que no haya dos personas con el mismo, y nullable para no
-- romper las filas que ya existen antes del relleno de abajo.
-- ---------------------------------------------------------------------
alter table public.usuario
  add column if not exists usuario_login text;

do $$
begin
  alter table public.usuario add constraint usuario_login_unico unique (usuario_login);
exception
  when duplicate_table or duplicate_object then null;
end $$;

-- Rellena el usuario de las filas que ya existen, sacándolo de la parte
-- anterior al @ del correo de la cuenta. Para vrodriguez@friopacking.pe
-- queda "vrodriguez", así que Valeria entra con ese usuario y su misma
-- contraseña: la cuenta no se toca, solo se le pone nombre visible.
update public.usuario u
   set usuario_login = split_part(a.email, '@', 1)
  from auth.users a
 where a.id = u.identificador
   and u.usuario_login is null;


-- ---------------------------------------------------------------------
-- (A) Leer exige perfil, no solo sesión.
--
-- mi_rol() devuelve null si la cuenta no tiene fila en `usuario`, si está
-- inactiva o si no tiene rol. Es security definer, así que puede consultar
-- esas tablas sin quedar atrapada en sus propias políticas.
--
-- Los permisos de escritura no se tocan: puede_editar() ya exigía rol
-- admin o editor, y un intruso sin perfil nunca los tuvo.
-- ---------------------------------------------------------------------
drop policy if exists "oportunidades_select_logueado"   on public.oportunidades;
drop policy if exists "oportunidades_select_con_perfil" on public.oportunidades;
create policy "oportunidades_select_con_perfil" on public.oportunidades
  for select to authenticated using (public.mi_rol() is not null);

drop policy if exists "entregables_select_logueado"   on public.entregables;
drop policy if exists "entregables_select_con_perfil" on public.entregables;
create policy "entregables_select_con_perfil" on public.entregables
  for select to authenticated using (public.mi_rol() is not null);

-- El catálogo de roles tampoco: no es información sensible (son tres
-- palabras), pero nadie sin perfil tiene motivo para leerlo, y el panel
-- siempre lo consulta con una sesión que sí tiene perfil.
drop policy if exists "roles_select_authenticated" on public.roles;
drop policy if exists "roles_select_con_perfil"    on public.roles;
create policy "roles_select_con_perfil" on public.roles
  for select to authenticated using (public.mi_rol() is not null);


-- ---------------------------------------------------------------------
-- Comprobación: debería devolver una fila por persona, con su usuario.
-- ---------------------------------------------------------------------
select u.usuario_login as usuario,
       u.nombre,
       r.descripcion   as rol,
       u.activo
from public.usuario u
join public.roles r on r.identificador = u.rol_id
order by u.nombre;
