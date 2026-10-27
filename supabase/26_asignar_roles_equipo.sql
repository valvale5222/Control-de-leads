-- =====================================================================
-- 26: Roles y permisos del equipo actual
--
--   admin                  -> Valeria Rodríguez
--   editor                 -> Misael Estrada
--   visor                  -> Jesús Chávez, Tiffany Ollero, Piero Añanca,
--                             Lizeth Arévalo, Diego Morales, Manuel Henríquez,
--                             Sebastián Flores, José Pérez
--   operativo_restringido  -> Thalía Borja, Pablo Yvala
--                             Presupuestos e Ingeniería · solo ver ·
--                             Revisión semanal + Carga laboral + Desempeño
--
-- Solo actualiza perfiles que YA existen en `usuario` (la cuenta con
-- contraseña no se puede crear por SQL). Busca por nombre y apellido sin
-- tildes ni mayúsculas. Al final lista a cada persona con lo que quedó o con
-- "NO ENCONTRADO": a esas personas creálas desde usuarios.html (Gestión de
-- usuarios) con el rol y permisos de esta tabla.
--
-- Requiere 12, 13 y 25. Idempotente. Ejecutar en Supabase: SQL Editor -> Run.
-- =====================================================================

drop table if exists equipo_objetivo, equipo_match;
create temporary table equipo_objetivo (nombre text, palabras text[], rol text, permisos jsonb);

insert into equipo_objetivo values
  ('Valeria Rodríguez', '{valeria,rodriguez}', 'admin', null),
  ('Misael Estrada',    '{misael,estrada}',    'editor', null),
  ('Jesús Chávez',      '{jesus,chavez}',      'visor', null),
  ('Tiffany Ollero',    '{tiffany,ollero}',    'visor', null),
  ('Piero Añanca',      '{piero,ananca}',      'visor', null),
  ('Lizeth Arévalo',    '{lizeth,arevalo}',    'visor', null),
  ('Diego Morales',     '{diego,morales}',     'visor', null),
  ('Manuel Henríquez',  '{manuel,henriquez}',  'visor', null),
  ('Sebastián Flores',  '{sebastian,flores}',  'visor', null),
  ('José Pérez',        '{jose,perez}',        'visor', null),
  ('Thalía Borja',      '{thalia,borja}',      'operativo_restringido',
   '{"areas":["presupuestos"],"vistas":["revision","carga","desempeno"],
     "acciones":{"ver":true,"crear":false,"editar":false,"completar_tareas":false,"actualizar_avance":false}}'),
  ('Pablo Yvala',       '{pablo,yvala}',       'operativo_restringido',
   '{"areas":["presupuestos"],"vistas":["revision","carga","desempeno"],
     "acciones":{"ver":true,"crear":false,"editar":false,"completar_tareas":false,"actualizar_avance":false}}');

-- Perfil que corresponde a cada persona: el nombre guardado (sin tildes)
-- contiene su nombre y su apellido.
create temporary table equipo_match as
select t.nombre as persona, t.rol, t.permisos, u.identificador
from equipo_objetivo t
left join public.usuario u
  on (select bool_and(
        lower(translate(u.nombre, 'ÁÉÍÓÚáéíóúÑñÜü', 'AEIOUaeiouNnUu')) like '%' || w || '%')
      from unnest(t.palabras) w);

-- Solo si el nombre identifica a UNA sola cuenta: con dos coincidencias no se
-- adivina, se reporta para resolverlo a mano.
update public.usuario u
   set rol_id   = r.identificador,
       activo   = true,
       permisos = case when m.rol = 'operativo_restringido' then m.permisos else u.permisos end
  from equipo_match m
  join public.roles r on r.descripcion = m.rol
 where u.identificador = m.identificador
   and (select count(*) from equipo_match m2 where m2.persona = m.persona) = 1;

select m.persona,
       m.rol as rol_esperado,
       case
         when m.identificador is null then 'NO ENCONTRADO: crear en usuarios.html'
         when (select count(*) from equipo_match m2 where m2.persona = m.persona) > 1
           then 'VARIAS CUENTAS con ese nombre: revisar a mano'
         else 'OK · usuario ' || coalesce(u.usuario_login, '—') || ' · rol ' || r.descripcion
       end as resultado
from equipo_match m
left join public.usuario u on u.identificador = m.identificador
left join public.roles r on r.identificador = u.rol_id
order by m.rol, m.persona;
