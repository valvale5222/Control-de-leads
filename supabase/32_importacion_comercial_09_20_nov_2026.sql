-- =====================================================================
-- 32: Importación del Consolidado Comercial 09–20/11/2026 (Perú)
--
-- Fuente: Consolidado_Comercial_09-20_Noviembre_2026.md (agendas y reportes
-- originales de HE, JR y VR). Carga en public.gestion_comercial, país 'peru':
--   · actividades (visitas y reuniones), con su estado de origen
--   · leads (hallazgos comerciales para evaluación, estado «Nuevo»)
--   · tareas (próximos pasos de los reportes y bloques de oficina)
--
-- Reglas que aplica:
--   · Dueño desde el inicio: propietario_uid = UUID REAL de la tabla usuario
--     (HE = Hugo Escobar, JR = Jhon Rojas, VR = Víctor Ramírez), resuelto con
--     public.uid_por_nombre() de 31. Si alguno no existe o hay varias cuentas
--     con ese nombre, el script se detiene y NO carga nada. No crea usuarios.
--   · Programado no es realizado: agenda sin reporte = «Programada».
--     Agenda + reporte de la misma actividad = UN registro con el reporte.
--     «No realizada» = «Cancelada» (no se realizó), con su motivo si consta.
--   · Sin hora en el origen = hora vacía (hora no informada). No se inventan
--     horas, zonas, contactos, resultados ni fechas. El resultado comercial
--     (Positiva / Neutra / Descartada) queda vacío: el origen no lo indica.
--   · Leads: sin opId, sin solicitud de conversión, sin vínculo a
--     oportunidades. Las vinculaciones siguen el flujo establecido
--     (solicitud del ejecutivo → validación y aprobación de administración).
--   · Clientes: solo se vinculan a la Base Maestra (CLI-xxxx) por nombre
--     EXACTO (nombre_clave). El resto queda con empresaId vacío y el nombre
--     del documento en datos.clienteOrigen, para conciliarlo a mano (sección 2).
--     No se crean clientes ni se fusionan nombres (p. ej. Ti-Cay / CERDEÑA).
--   · Solapamientos de agenda: se conservan y se marcan en datos.conciliar.
--   · Trazabilidad: datos.importacion {lote, documento, seccion, importado}.
--
-- Idempotente: IDs fijos y «on conflict do nothing». Volver a correrlo no
-- duplica ni pisa lo que los ejecutivos hayan editado después. Si se completa
-- la tabla de conciliación de clientes (sección 2) y se vuelve a correr, solo
-- se completa empresaId en los registros importados que siguen sin cliente.
--
-- Requiere 28, 30 y 31. Ejecutar en Supabase: SQL Editor -> pegar y Run.
-- No toca otras tablas ni módulos.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 0) Requisitos
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.gestion_comercial') is null then
    raise exception 'Falta correr 30_gestion_comercial.sql.';
  end if;
  if not exists (select 1 from information_schema.columns
                 where table_schema = 'public' and table_name = 'gestion_comercial' and column_name = 'propietario_uid') then
    raise exception 'Falta correr 31_perfiles_permisos.sql.';
  end if;
  if to_regclass('public.clientes') is null then
    raise exception 'Falta correr 28_clientes_maestra.sql.';
  end if;
end $$;


-- ---------------------------------------------------------------------
-- 1) Ejecutivos: UUID real de la tabla usuario (no se generan IDs)
-- ---------------------------------------------------------------------
drop table if exists imp_ej, imp_cli, imp_cli_manual, imp_act, imp_lead, imp_tarea, imp_meta;

create temporary table imp_ej (ini text primary key, nombre text, uid uuid);
insert into imp_ej (ini, nombre) values
  ('HE', 'Hugo Escobar'),
  ('JR', 'Jhon Rojas'),
  ('VR', 'Víctor Ramírez');

update imp_ej e
   set uid = u.identificador
  from public.usuario u
 where u.identificador = public.uid_por_nombre(e.nombre);

do $$
declare r record;
begin
  for r in select * from imp_ej where uid is null loop
    raise exception 'No se encontró UNA cuenta en public.usuario para % (%). Revisá el nombre en usuarios.html; no se cargó nada.', r.nombre, r.ini;
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 2) Clientes del documento -> Base Maestra
--    Automático: solo coincidencia exacta de nombre_clave.
--    Manual: completá id_cliente en «imp_cli_manual» (CLI-xxxx) y volvé a
--    correr el script. Dejar null = sin vincular (se muestra el nombre del
--    documento en el panel).
-- ---------------------------------------------------------------------
create temporary table imp_cli (origen text primary key, id_cliente text, via text);

create temporary table imp_cli_manual (origen text primary key, id_cliente text);
insert into imp_cli_manual (origen, id_cliente) values
  -- ('SOMEREX', 'CLI-0000'),
  ('__ejemplo__', null);


-- ---------------------------------------------------------------------
-- 3) Actividades (agenda + reporte en un solo registro)
--    estado: Programada | Realizada | Cancelada (= no se realizó)
-- ---------------------------------------------------------------------
create temporary table imp_act (
  id text primary key, ini text, fecha date, h_ini text, h_fin text,
  tipo text, modalidad text, cliente text, contacto text, titulo text, zona text,
  estado text, situacion text, descarte text, motivo text,
  lead text, prox text, prox_f text, tarea text,
  tipo_origen text, conciliar text, seccion text
);

insert into imp_act values
-- HE · Agenda 09–13/11 + Reporte de resultados 09–13/11
('AC-IMP2611-HE01','HE','2026-11-09','10:00','12:00','Reunión','Virtual','SOMEREX','Sergio Chávez (jefe)',
 'Retoma del proyecto de cámaras de congelado y túnel','Lima','Realizada',
 'Reunión virtual y visita a planta realizadas. Ampliación de cámaras de congelado y túnel. Adjudicación prevista para enero de 2027 y puesta en operación en julio de 2027.',
 '','','LD-IMP2611-HE01','','',null,'Reunión virtual',null,'HE · Agenda 09–13/11 + Reporte de resultados 09–13/11'),
('AC-IMP2611-HE02','HE','2026-11-10','10:00','12:00','Visita','Presencial','SOMEREX','Diana León (gerente de Producción)',
 'Visita a planta Callao: cámaras, túnel y sala de procesos; propuesta de layout','Callao','Realizada',
 'Reunión virtual y visita a planta realizadas. Ampliación de cámaras de congelado y túnel. Adjudicación prevista para enero de 2027 y puesta en operación en julio de 2027.',
 '','','LD-IMP2611-HE01','Diego Morales elaborará dos alternativas de layout para enviar como máximo el miércoles 18/11.','2026-11-18','TA-IMP2611-HE01',
 'Visita a planta',null,'HE · Agenda 09–13/11 + Reporte de resultados 09–13/11'),
('AC-IMP2611-HE03','HE','2026-11-11','09:00','12:00','Visita','Presencial','SAN FERNANDO — Huaral','',
 'Visita comercial y técnica, recorrido de planta','Huaral','Realizada',
 'Visita realizada, capacitación al personal técnico y recorrido de planta. Oportunidades de servicios identificadas en Chimbote y Sullana.',
 '','','LD-IMP2611-HE02','Coordinar visitas técnicas y reunión corporativa con Cristian Franco, Álvaro y Eduardo para el próximo jueves.',null,'TA-IMP2611-HE02',
 'Visita comercial y técnica',null,'HE · Agenda 09–13/11 + Reporte de resultados 09–13/11'),
('AC-IMP2611-HE04','HE','2026-11-12','09:00','11:00','Visita','Presencial','TASA — Callao','Erick Huancaya',
 'Visita a planta comercial','Callao','Cancelada','',
 'Otro','Visita presencial cancelada por fuga de NH3 y protocolo de seguridad de planta. Próximos pasos del reporte: reunión virtual 16/11, 3:00 p. m.; visita técnica 17/11.',
 '','','',null,'Visita a planta',null,'HE · Agenda 09–13/11 + Reporte de resultados 09–13/11'),
('AC-IMP2611-HE05','HE','2026-11-12','12:00','14:00','Visita','Presencial','Procesadora de Alimentos Ti-Cay','Rolando Díaz (gerente de Operaciones)',
 'Visita a planta','','Programada','','','',
 '','','',null,'Visita a planta',
 'El reporte 09–13/11 registra una reunión con Rolando Díaz bajo el cliente «CERDEÑA» (lead LD-IMP2611-HE03), sin fecha. No se fusionaron: confirmar si es la misma empresa y reportar o cancelar esta visita.',
 'HE · Agenda 09–13/11'),
('AC-IMP2611-HE06','HE','2026-11-13','09:00','11:00','Visita','Presencial','REDONDOS — Ate','Richard Sarmiento (coordinador)',
 'Visita (por confirmar en agenda)','Ate','Realizada',
 'Visita realizada. Solicitud de propuesta técnico-económica integral de ampliación y adecuación de planta: obras civiles, reforzamiento estructural, infraestructura, refrigeración para tres zonas de producción (4 a 6 °C, por confirmar), plataformas metálicas, cambio de cobertura por paneles PUR de 100 mm, ventilación y maniobras de montaje e izaje.',
 '','','LD-IMP2611-HE04','Recibir consultas y precisiones la próxima semana. Evaluar alcance integral y preparar propuesta con metrados, costos y cronograma. Ejecución referencial enero–febrero 2027, sin interrumpir operación 24/7.',null,'TA-IMP2611-HE05',
 'Visita por confirmar',null,'HE · Agenda 09–13/11 + Reporte de resultados 09–13/11'),
-- HE · Agenda 16–20/11 (programada)
('AC-IMP2611-HE07','HE','2026-11-16','10:00','12:00','Visita','','DELICE','Rodrigo Escalante',
 'Proyecto planta de quesos Chilca','','Programada','','','','','','',null,'No informado',null,'HE · Agenda 16–20/11'),
('AC-IMP2611-HE08','HE','2026-11-16','15:00','17:00','Reunión','Virtual','TASA — virtual','',
 'Reunión de proyectos y servicios','','Programada','','','','','','',null,'Reunión virtual',
 'Corresponde a la reunión virtual del 16/11, 3:00 p. m., indicada en el reporte 09–13/11 tras la cancelación de la visita del 12/11 (AC-IMP2611-HE04).',
 'HE · Agenda 16–20/11 + Reporte de resultados 09–13/11'),
('AC-IMP2611-HE09','HE','2026-11-17','08:00','10:00','Visita','','FRUTOS TROPICALES','',
 'Planta de congelado y servicios/suministros','Huacho–Huaral','Programada','','','','','','',null,'No informado',null,'HE · Agenda 16–20/11'),
('AC-IMP2611-HE10','HE','2026-11-17','12:00','14:00','Visita','','TYT FRUITS','',
 'Dos cámaras de enfriamiento y suministro de puertas','','Programada','','','','','','',null,'No informado',null,'HE · Agenda 16–20/11'),
('AC-IMP2611-HE11','HE','2026-11-18','11:00','13:00','Reunión','','TASA — Callao','',
 'Reunión de proyectos y servicios','Callao','Programada','','','','','','',null,'Reunión',
 'El reporte 09–13/11 indica una visita técnica a TASA el 17/11 (tarea TA-IMP2611-HE03); la agenda programa esta reunión el 18/11. Confirmar si es la misma actividad.',
 'HE · Agenda 16–20/11'),
('AC-IMP2611-HE12','HE','2026-11-19','09:00','11:00','Reunión','','SAN FERNANDO','',
 'Reunión con corporativo en Lima','Lima','Programada','','','','','','',null,'Reunión',
 'Posible reunión corporativa indicada en el reporte 09–13/11 («el próximo jueves», con Cristian Franco, Álvaro y Eduardo).',
 'HE · Agenda 16–20/11'),
('AC-IMP2611-HE13','HE','2026-11-20',null,null,'Visita','','FRÍO LA MERCED','',
 'Visita por confirmar','','Programada','','','','','','',null,'Visita por confirmar','Hora no informada; visita por confirmar.','HE · Agenda 16–20/11'),
('AC-IMP2611-HE14','HE','2026-11-20',null,null,'Visita','','KM30 S.A.C.','',
 'Visita por confirmar','','Programada','','','','','','',null,'Visita por confirmar','Hora no informada; visita por confirmar.','HE · Agenda 16–20/11'),

-- JR · Semana 09–13 Nov 2026 (actividades con cliente; las de oficina van como tareas)
('AC-IMP2611-JR03','JR','2026-11-09',null,null,'Reunión','','Arona','',
 'Reunión interna proyecto Arona (sistema de frío e infraestructura)','Oficina','Realizada','','','','','','',null,'Reunión interna',null,'JR · Semana 09–13 Nov 2026 · N° 3'),
('AC-IMP2611-JR04','JR','2026-11-09',null,null,'Visita','Presencial','TA Export','',
 'Revisión de observaciones del proyecto','Ica','Realizada','Coordinado con Operaciones.','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 4'),
('AC-IMP2611-JR06','JR','2026-11-10',null,null,'Reunión','','La Portada','',
 'Reunión interna – La Portada','Oficina','Realizada','','','','','','',null,'Reunión interna',null,'JR · Semana 09–13 Nov 2026 · N° 6'),
('AC-IMP2611-JR07','JR','2026-11-10',null,null,'Reunión','','La Portada','',
 'Reunión con cliente – La Portada','','Realizada','','','','','','',null,'Reunión cliente','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 7'),
('AC-IMP2611-JR08','JR','2026-11-10',null,null,'Reunión','','Surexpor','',
 'Reunión con cliente – Surexpor','','Realizada','','','','','','',null,'Reunión cliente','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 8'),
('AC-IMP2611-JR09','JR','2026-11-10',null,null,'Visita','Presencial','Agrícola Arona','',
 'Kick off en obra','Cañete','Realizada','Se levantaron todas las observaciones del área de Operaciones en obra.','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 9'),
('AC-IMP2611-JR10','JR','2026-11-10',null,null,'Visita','Presencial','Peruvian Fruits','',
 'Climatización de sala de procesos','Cañete','Realizada','Información recabada: Información para climatizar su sala de procesos.','','','LD-IMP2611-JR01','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 10'),
('AC-IMP2611-JR11','JR','2026-11-11',null,null,'Visita','Presencial','La Agrícola La Joya','',
 'Visita','Arequipa','Cancelada','','','Motivo no informado en el reporte de origen.','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 11'),
('AC-IMP2611-JR12','JR','2026-11-11',null,null,'Visita','Presencial','SC Packing','',
 'Revisión de avance del ambiente','Arequipa','Realizada','A la espera de confirmación.','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 12'),
('AC-IMP2611-JR13','JR','2026-11-11',null,null,'Visita','Presencial','Pampa Baja','',
 'Revisión de observaciones y nuevo proyecto de arándanos','Arequipa','Realizada','','','','LD-IMP2611-JR02','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 13'),
('AC-IMP2611-JR14','JR','2026-11-11',null,null,'Visita','Presencial','Kamuk','',
 'Visita','Arequipa','Realizada','','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 14'),
('AC-IMP2611-JR15','JR','2026-11-12',null,null,'Visita','Presencial','La Portada','',
 'Revisión del enfriamiento de los túneles','','Realizada','','','','','','',null,'Visita','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 15'),
('AC-IMP2611-JR16','JR','2026-11-12',null,null,'Visita','Presencial','Diamond','',
 'Ampliación','','Realizada','Información recabada: Levantamiento de información por ampliación.','','','LD-IMP2611-JR03','','',null,'Visita','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 16'),
('AC-IMP2611-JR17','JR','2026-11-12',null,null,'Visita','Presencial','Prolan San Fernando','',
 'Ingeniería','','Realizada','Información recabada: Levantamiento de información de ingeniería.','','','','','',null,'Visita','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 17'),
('AC-IMP2611-JR18','JR','2026-11-12',null,null,'Visita','Presencial','Agroaksa','',
 'Visita','Ica','Cancelada','','','Motivo no informado en el reporte de origen.','','','',null,'Visita',
 'La semana 16–20 escribe «Agrokasa» (N° 28). No se unificó el nombre: confirmar.','JR · Semana 09–13 Nov 2026 · N° 18'),
('AC-IMP2611-JR19','JR','2026-11-13',null,null,'Visita','Presencial','Proagro','',
 'Reunión de avance de obra','Ica','Realizada','','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 19'),
('AC-IMP2611-JR20','JR','2026-11-13',null,null,'Visita','Presencial','Vanguard','',
 'Revisión de contrato y orden de compra del proyecto Prosembra','Ica','Realizada','','','','','','',null,'Visita',null,'JR · Semana 09–13 Nov 2026 · N° 20'),
('AC-IMP2611-JR21','JR','2026-11-13',null,null,'Visita','Presencial','La Portada','',
 'Evaluación del enfriamiento de túnel','','Realizada','Se sigue evaluando.','','','','','',null,'Visita','Zona no informada.','JR · Semana 09–13 Nov 2026 · N° 21'),
-- JR · Semana 16–20 Nov 2026 (pendiente)
('AC-IMP2611-JR22','JR','2026-11-16',null,null,'Visita','Presencial','Coexa','','Visita','Por confirmar','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 22'),
('AC-IMP2611-JR23','JR','2026-11-16',null,null,'Visita','Presencial','Prolan – La Portada','','Visita','La Portada','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 23'),
('AC-IMP2611-JR24','JR','2026-11-17',null,null,'Visita','Presencial','Agrofloral','','Visita','Por confirmar','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 24'),
('AC-IMP2611-JR25','JR','2026-11-17',null,null,'Visita','Presencial','Peruvian Fruits','','Visita','Cañete','Programada','','','','LD-IMP2611-JR01','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 25'),
('AC-IMP2611-JR26','JR','2026-11-18',null,null,'Visita','Presencial','Diamond','','Visita','Pisco','Programada','','','','LD-IMP2611-JR03','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 26'),
('AC-IMP2611-JR27','JR','2026-11-18',null,null,'Visita','Presencial','Prosembra','','Visita','Por confirmar','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 27'),
('AC-IMP2611-JR28','JR','2026-11-19',null,null,'Visita','Presencial','Agrokasa','','Visita','Ica','Programada','','','','','','',null,'Visita',
 'La semana 09–13 escribe «Agroaksa» (N° 18). No se unificó el nombre: confirmar.','JR · Semana 16–20 Nov 2026 · N° 28'),
('AC-IMP2611-JR29','JR','2026-11-19',null,null,'Visita','Presencial','Safco','','Visita','Por confirmar','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 29'),
('AC-IMP2611-JR30','JR','2026-11-20',null,null,'Visita','Presencial','Proagro','','Visita','Ica','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 30'),
('AC-IMP2611-JR31','JR','2026-11-20',null,null,'Visita','Presencial','Machu Picchu','','Visita','Por confirmar','Programada','','','','','','',null,'Visita',null,'JR · Semana 16–20 Nov 2026 · N° 31'),

-- VR · Agenda 09–13/11 + Reporte de visitas y reuniones 09–14/11
('AC-IMP2611-VR01','VR','2026-11-09','10:00','12:00','Visita','Presencial','DINO PIURA','',
 'Verificación sistema frío con Frioteam','','Realizada','Sin oportunidad por el momento','','','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR02','VR','2026-11-10','08:00','09:30','Visita','Presencial','PACHAMAMA','',
 'Visita comercial','','Realizada','Aún sin ampliaciones','','','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR03','VR','2026-11-10','10:00','12:00','Visita','Presencial','DINO PIURA','',
 'Verificación de sistema de frío (chiller) con Frioteam','','Realizada','Sin oportunidad por el momento','','','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR04','VR','2026-11-10','10:00','12:00','Visita','Presencial','DINO PIMENTEL','',
 'Visita','','Programada','','','','','','',null,'Visita',
 'Solapamiento en la agenda de origen con DINO PIURA (10/11, 10:00–12:00). El reporte no registra DINO PIMENTEL este día (sí el 12/11): reportar o cancelar a mano.',
 'VR · Agenda 09–13/11'),
('AC-IMP2611-VR05','VR','2026-11-10','14:00','15:30','Visita','Presencial','RAPEL','',
 'Climatización / visita con Frioteam','','Realizada','En revisión de análisis','','','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR06','VR','2026-11-11','09:00','11:00','Visita','Presencial','SUNSHINE','',
 'Visita comercial','','Cancelada','','Otro','No se realizó, por motivo de certificación.','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR07','VR','2026-11-11','09:00','11:00','Visita','Presencial','SUNSHINE TAMBOGRANDE','',
 'Visita','','Programada','','','','','','',null,'Visita',
 'Solapamiento en la agenda de origen con SUNSHINE (11/11, 09:00–11:00), que el reporte registra como no realizada. Confirmar si es la misma visita.',
 'VR · Agenda 09–13/11'),
('AC-IMP2611-VR08','VR','2026-11-11','11:30','13:00','Visita','Presencial','EMPAFRUT','',
 'Visita comercial','','Realizada','Con visión de oportunidad de cambio de refrigerante','','','LD-IMP2611-VR01','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR09','VR','2026-11-11','14:30','16:30','Visita','Presencial','CAMPOSOL PAITA','',
 'Visita comercial con Frioteam','Paita','Realizada','Se pretende hacer un centro logístico pero como Fripusa (a su costado)','','','LD-IMP2611-VR02','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR10','VR','2026-11-12','09:30','11:30','Visita','Presencial','DINO PIMENTEL','',
 'Verificación de sistema frío con Frioteam','','Cancelada','','Otro','No se logró (según reporte).','','','',null,'Visita',null,'VR · Agenda 09–13/11 + Reporte 09–14/11'),
('AC-IMP2611-VR11','VR','2026-11-13','09:31','11:31','Visita','Presencial','AIB MOTUPE','',
 'Visita y verificación','Motupe','Realizada','Se visitó con motivo de la proyección del avance y verificación de válvulas','','','','','',null,'Visita',
 'No figura en la agenda 09–13/11; solo en el reporte.','VR · Reporte 09–14/11'),
('AC-IMP2611-VR12','VR','2026-11-14','09:32','11:32','Visita','Presencial','FRUTOS DE ORO','',
 'Verificación de cámara de congelado y comunicación con mantenimiento','','Realizada','Se verificó avance de observaciones con área de mantenimiento','','','','','',null,'Visita',
 'Actividad del sábado 14/11: la agenda semanal termina el viernes 13/11.','VR · Reporte 09–14/11'),
-- VR · Agenda 16–20/11 (programada; alertas de solapamiento en origen)
('AC-IMP2611-VR13','VR','2026-11-16','09:00','10:00','Reunión','','','',
 'Reunión comercial','','Programada','','','','','','',null,'Reunión',null,'VR · Agenda 16–20/11'),
('AC-IMP2611-VR14','VR','2026-11-16','10:00','11:00','Reunión','','','',
 'Reunión congelado Tarapoto','Tarapoto','Programada','','','','','','',null,'Reunión',
 'Se solapa con el bloque de oficina 10:00–18:00 (tarea TA-IMP2611-VR01). Cliente no identificado en el origen.','VR · Agenda 16–20/11'),
('AC-IMP2611-VR15','VR','2026-11-17','08:00','18:00','Visita','Presencial','Prize','',
 'Verificación túneles MP','','Programada','','','','','','',null,'Visita','Se solapa con la reunión Talsa (17/11, 08:00–09:00).','VR · Agenda 16–20/11'),
('AC-IMP2611-VR16','VR','2026-11-17','08:00','09:00','Reunión','','Talsa','',
 'Reunión Talsa','','Programada','','','','','','',null,'Reunión','Solapamiento con Prize (17/11, 08:00–18:00).','VR · Agenda 16–20/11'),
('AC-IMP2611-VR17','VR','2026-11-18','08:00','18:00','Visita','Presencial','Prize','',
 'Verificación de T','','Programada','','','','','','',null,'Visita','Se solapa con otras reuniones del 18/11.','VR · Agenda 16–20/11'),
('AC-IMP2611-VR18','VR','2026-11-18','10:00','11:00','Reunión','','Talsa','P. Mori',
 'Reunión Talsa P. Mori','','Programada','','','','','','',null,'Reunión','Solapamiento con Prize (18/11, 08:00–18:00).','VR · Agenda 16–20/11'),
('AC-IMP2611-VR19','VR','2026-11-19','09:00','13:00','Reunión','','Camposol','',
 'Reunión Camposol','','Programada','','','','','','',null,'Reunión',null,'VR · Agenda 16–20/11');


-- ---------------------------------------------------------------------
-- 4) Leads: hallazgos comerciales para evaluación (estado «Nuevo»).
--    Sin opId, sin conversión, sin vínculo a oportunidades.
-- ---------------------------------------------------------------------
create temporary table imp_lead (id text primary key, ini text, cliente text, titulo text, seguimiento text, nota text, seccion text);

insert into imp_lead values
('LD-IMP2611-HE01','HE','SOMEREX','Ampliación de cámaras de congelado y túnel',
 'Adjudicación prevista para enero de 2027 y puesta en operación en julio de 2027 (según reporte).',
 'Reunión virtual 09/11 y visita a planta Callao 10/11.','HE · Reporte de resultados 09–13/11'),
('LD-IMP2611-HE02','HE','SAN FERNANDO — Huaral','Servicios en Chimbote y Sullana',
 'Oportunidades de servicios identificadas en Chimbote y Sullana durante la visita a Huaral.',
 'Visita 11/11.','HE · Reporte de resultados 09–13/11'),
('LD-IMP2611-HE03','HE','CERDEÑA','Ampliación y evaluación de migración de Freón a CO2',
 'Proyecto de ampliación y evaluación de migración del sistema actual de Freón a CO2, sujeta a rentabilidad del ahorro energético.',
 'Reunión con Rolando Díaz (fecha no informada en el reporte). La agenda del 12/11 registra a Rolando Díaz con «Procesadora de Alimentos Ti-Cay» (AC-IMP2611-HE05): no se fusionaron los clientes; confirmar su equivalencia.',
 'HE · Reporte de resultados 09–13/11'),
('LD-IMP2611-HE04','HE','REDONDOS — Ate','Ampliación y adecuación integral de planta',
 'Propuesta técnico-económica integral: obras civiles, reforzamiento estructural, infraestructura, refrigeración para tres zonas de producción (4 a 6 °C, por confirmar), plataformas metálicas, cambio de cobertura por paneles PUR de 100 mm, ventilación y maniobras de montaje e izaje. Ejecución referencial enero–febrero 2027, sin interrumpir operación 24/7.',
 'Visita 13/11 con Richard Sarmiento (coordinador).','HE · Reporte de resultados 09–13/11'),
('LD-IMP2611-JR01','JR','Peruvian Fruits','Climatización de sala de procesos',
 'Información recabada: información para climatizar su sala de procesos.','Visita 10/11 (Cañete).','JR · Semana 09–13 Nov 2026 · N° 10'),
('LD-IMP2611-JR02','JR','Pampa Baja','Nuevo proyecto de arándanos',
 'Revisión de observaciones y nuevo proyecto de arándanos.','Visita 11/11 (Arequipa).','JR · Semana 09–13 Nov 2026 · N° 13'),
('LD-IMP2611-JR03','JR','Diamond','Ampliación',
 'Información recabada: levantamiento de información por ampliación.','Visita 12/11.','JR · Semana 09–13 Nov 2026 · N° 16'),
('LD-IMP2611-VR01','VR','EMPAFRUT','Cambio de refrigerante',
 'Con visión de oportunidad de cambio de refrigerante.','Visita comercial 11/11.','VR · Reporte 09–14/11'),
('LD-IMP2611-VR02','VR','CAMPOSOL PAITA','Centro logístico',
 'Se pretende hacer un centro logístico pero como Fripusa (a su costado).','Visita comercial con Frioteam 11/11.','VR · Reporte 09–14/11');


-- ---------------------------------------------------------------------
-- 5) Tareas: próximos pasos de los reportes y bloques de oficina.
--    vence null = sin fecha en el origen (el panel la muestra «Sin fecha»).
-- ---------------------------------------------------------------------
create temporary table imp_tarea (
  id text primary key, ini text, cliente text, titulo text, descr text,
  vence date, estado text, completada date, lead text, act text, seccion text
);

insert into imp_tarea values
('TA-IMP2611-HE01','HE','SOMEREX','Enviar dos alternativas de layout a SOMEREX',
 'Diego Morales elaborará dos alternativas de layout para enviar como máximo el miércoles 18/11.',
 '2026-11-18','Pendiente',null,'LD-IMP2611-HE01','AC-IMP2611-HE02','HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE02','HE','SAN FERNANDO — Huaral','Coordinar visitas técnicas (Chimbote y Sullana) y reunión corporativa con San Fernando',
 'Coordinar visitas técnicas y reunión corporativa con Cristian Franco, Álvaro y Eduardo para el próximo jueves (sin fecha exacta en el reporte; la agenda 16–20/11 programa la reunión corporativa el 19/11).',
 null,'Pendiente',null,'LD-IMP2611-HE02','AC-IMP2611-HE03','HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE03','HE','TASA — Callao','Visita técnica a TASA',
 'Próximo paso del reporte tras la cancelación del 12/11 (fuga de NH3): visita técnica 17/11. La agenda 16–20/11 programa una reunión en TASA — Callao el 18/11 (AC-IMP2611-HE11): confirmar si es la misma.',
 '2026-11-17','Pendiente',null,null,'AC-IMP2611-HE04','HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE04','HE','CERDEÑA','Enviar planos y proyección actualizada de producción a CERDEÑA',
 'Próximo paso del reporte. Sin fecha en el origen.',null,'Pendiente',null,'LD-IMP2611-HE03',null,'HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE06','HE','CERDEÑA','Nueva reunión con CERDEÑA',
 'Nueva reunión en aproximadamente dos semanas (sin fecha exacta en el reporte).',null,'Pendiente',null,'LD-IMP2611-HE03',null,'HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE05','HE','REDONDOS — Ate','Recibir consultas y precisiones de REDONDOS',
 'Recibir consultas y precisiones la próxima semana (sin fecha exacta en el reporte).',null,'Pendiente',null,'LD-IMP2611-HE04','AC-IMP2611-HE06','HE · Reporte de resultados 09–13/11'),
('TA-IMP2611-HE07','HE','REDONDOS — Ate','Evaluar alcance integral y preparar propuesta para REDONDOS',
 'Preparar propuesta con metrados, costos y cronograma. Ejecución referencial enero–febrero 2027, sin interrumpir operación 24/7.',
 null,'Pendiente',null,'LD-IMP2611-HE04','AC-IMP2611-HE06','HE · Reporte de resultados 09–13/11'),
-- JR · actividades de oficina (realizadas)
('TA-IMP2611-JR01','JR','Arona','Revisión y envío de presupuesto de climatización de cámara – Arona',
 'Actividad de oficina.','2026-11-09','Completada','2026-11-09',null,null,'JR · Semana 09–13 Nov 2026 · N° 1'),
('TA-IMP2611-JR02','JR','Pomica','Revisión y envío de presupuesto – Pomica',
 'Actividad de oficina.','2026-11-09','Completada','2026-11-09',null,null,'JR · Semana 09–13 Nov 2026 · N° 2'),
('TA-IMP2611-JR05','JR','Byblu','Revisión y envío de propuesta – Byblu',
 'Actividad de oficina.','2026-11-10','Completada','2026-11-10',null,null,'JR · Semana 09–13 Nov 2026 · N° 5'),
-- VR · bloques de agenda sin cliente
('TA-IMP2611-VR01','VR','','Oficina: coordinación para revisiones de propuestas enviadas',
 'Bloque de agenda 16/11, 10:00–18:00. Se solapa con la reunión congelado Tarapoto (10:00–11:00).','2026-11-16','Pendiente',null,null,null,'VR · Agenda 16–20/11'),
('TA-IMP2611-VR02','VR','','Programación de actividad',
 'Bloque de agenda 18/11, 14:30–15:30 (solapamiento en origen).','2026-11-18','Pendiente',null,null,null,'VR · Agenda 16–20/11');


-- ---------------------------------------------------------------------
-- 6) Resolución de clientes (exacta + manual)
-- ---------------------------------------------------------------------
insert into imp_cli (origen)
select distinct cliente from (
  select cliente from imp_act union select cliente from imp_lead union select cliente from imp_tarea
) s where coalesce(cliente, '') <> '';

update imp_cli c set id_cliente = m.id_cliente, via = 'manual'
  from imp_cli_manual m
 where m.origen = c.origen and m.id_cliente is not null
   and exists (select 1 from public.clientes k where k.id_cliente = m.id_cliente);

update imp_cli c set id_cliente = k.id_cliente, via = 'exacta'
  from public.clientes k
 where c.id_cliente is null
   and k.nombre_clave = regexp_replace(upper(public.norm_nombre(c.origen)), '[^A-Z0-9]', '', 'g');


-- ---------------------------------------------------------------------
-- 7) Carga en gestion_comercial
-- ---------------------------------------------------------------------
create temporary table imp_meta as
select 'CONSOLIDADO-PE-2026-11-09-20'::text as lote,
       'Consolidado_Comercial_09-20_Noviembre_2026.md'::text as documento,
       to_char(now() at time zone 'America/Lima', 'YYYY-MM-DD"T"HH24:MI') as ts;

-- Leads
insert into public.gestion_comercial (id, tipo, pais, responsable, datos, creado_por, creado_uid, propietario_uid)
select l.id, 'lead', 'peru', e.nombre,
  jsonb_build_object(
    'id', l.id, '_t', 'lead', 'pais', 'peru',
    'empresaId', coalesce(c.id_cliente, ''), 'clienteOrigen', l.cliente, 'contactoId', '',
    'titulo', l.titulo, 'ejecutivo', e.nombre, 'estado', 'Nuevo', 'origen', 'Visita',
    'creado', m.ts, 'calif', '', 'opId', '', 'conversion', null,
    'campos', jsonb_build_object('seguimiento', l.seguimiento),
    'hist', jsonb_build_array(jsonb_build_object('f', m.ts, 'por', e.nombre, 'accion', 'Lead registrado',
              'nota', 'Importado del consolidado comercial 09–20/11/2026. ' || l.nota)),
    'creadoPor', e.nombre,
    'importacion', jsonb_build_object('lote', m.lote, 'documento', m.documento, 'seccion', l.seccion, 'importado', m.ts)),
  e.nombre, e.uid, e.uid
from imp_lead l
join imp_ej e on e.ini = l.ini
left join imp_cli c on c.origen = l.cliente
cross join imp_meta m
on conflict (id) do nothing;

-- Actividades
insert into public.gestion_comercial (id, tipo, pais, responsable, datos, creado_por, creado_uid, propietario_uid)
select a.id, 'actividad', 'peru', e.nombre,
  jsonb_build_object(
    'id', a.id, '_t', 'actividad', 'pais', 'peru',
    'tipo', a.tipo, 'categoria', '', 'fecha', a.fecha::text, 'hora', coalesce(a.h_ini, ''),
    'horaFin', coalesce(a.h_fin, ''), 'horaNoInformada', a.h_ini is null,
    'duracion', case when a.h_ini is not null and a.h_fin is not null
                     then (extract(epoch from (a.h_fin::time - a.h_ini::time)) / 60)::int end,
    'ejecutivo', e.nombre, 'empresaId', coalesce(c.id_cliente, ''), 'clienteOrigen', a.cliente,
    'contactoId', '', 'contactoOrigen', a.contacto, 'participantes', '[]'::jsonb,
    'modalidad', a.modalidad, 'sedeId', '', 'enlace', '', 'zona', a.zona,
    'leadId', coalesce(a.lead, ''), 'opRef', '', 'titulo', a.titulo,
    'acomp', '[]'::jsonb, 'acompanante', '',
    'estado', a.estado, 'resultado', '',
    'comentarios', a.situacion, 'acuerdos', a.situacion,
    'compromisos', '[]'::jsonb, 'reprogDe', '', 'motivo', a.motivo, 'descarte', a.descarte,
    'porDefinir', false, 'tipoOrigen', a.tipo_origen, 'conciliar', a.conciliar,
    'reporte', case
      when a.estado = 'Realizada' then jsonb_build_object(
        'f', m.ts, 'por', e.nombre, 'resultado', '', 'acuerdo', '', 'situacion', a.situacion,
        'motivoDescarte', '', 'proxAccion', coalesce(a.prox, ''), 'proxFecha', coalesce(nullif(a.prox_f, ''), ''),
        'tareaId', case when coalesce(a.prox_f, '') <> '' then coalesce(a.tarea, '') else '' end,
        'origen', 'Reporte importado')
      when a.estado = 'Cancelada' then jsonb_build_object('f', m.ts, 'por', e.nombre, 'origen', 'Reporte importado')
      end,
    'historial', jsonb_build_array(jsonb_build_object('tipo', 'creada', 'por', e.nombre, 'f', m.ts,
                   'motivo', 'Importada del consolidado comercial 09–20/11/2026'))
                 || case
                      when a.estado = 'Realizada' then jsonb_build_array(jsonb_build_object('tipo', 'realizada', 'por', e.nombre, 'f', m.ts, 'motivo', 'Según reporte de origen'))
                      when a.estado = 'Cancelada' then jsonb_build_array(jsonb_build_object('tipo', 'cancelada', 'por', e.nombre, 'f', m.ts,
                             'motivo', case when a.descarte <> '' then a.descarte || ': ' else '' end || a.motivo))
                      else '[]'::jsonb end,
    'creadoPor', e.nombre,
    'importacion', jsonb_build_object('lote', m.lote, 'documento', m.documento, 'seccion', a.seccion, 'importado', m.ts)),
  e.nombre, e.uid, e.uid
from imp_act a
join imp_ej e on e.ini = a.ini
left join imp_cli c on c.origen = a.cliente
cross join imp_meta m
on conflict (id) do nothing;

-- Tareas
insert into public.gestion_comercial (id, tipo, pais, responsable, datos, creado_por, creado_uid, propietario_uid)
select t.id, 'tarea', 'peru', e.nombre,
  jsonb_build_object(
    'id', t.id, '_t', 'tarea', 'pais', 'peru',
    'titulo', t.titulo, 'desc', t.descr, 'responsable', e.nombre, 'creadoPor', e.nombre, 'creado', m.ts,
    'vence', coalesce(t.vence::text, ''), 'estado', t.estado, 'completada', coalesce(t.completada::text, ''),
    'origen', case when t.act is not null then jsonb_build_object('tipo', 'reporte', 'actId', t.act) end,
    'actId', '', 'hist', '[]'::jsonb,
    'vinculo', case when t.lead is not null then jsonb_build_object('tipo', 'lead', 'id', t.lead)
                    when c.id_cliente is not null then jsonb_build_object('tipo', 'cliente', 'id', c.id_cliente) end,
    'leadId', coalesce(t.lead, ''), 'opId', '',
    'empresaId', coalesce(c.id_cliente, ''), 'clienteOrigen', t.cliente,
    'importacion', jsonb_build_object('lote', m.lote, 'documento', m.documento, 'seccion', t.seccion, 'importado', m.ts)),
  e.nombre, e.uid, e.uid
from imp_tarea t
join imp_ej e on e.ini = t.ini
left join imp_cli c on c.origen = t.cliente
cross join imp_meta m
on conflict (id) do nothing;

-- Re-ejecución tras conciliar clientes: completa empresaId solo en lo
-- importado que sigue sin cliente (no toca nada más).
update public.gestion_comercial g
   set datos = jsonb_set(case when g.tipo = 'tarea' and coalesce(g.datos -> 'vinculo', 'null'::jsonb) = 'null'::jsonb
                              then jsonb_set(g.datos, '{vinculo}', jsonb_build_object('tipo', 'cliente', 'id', c.id_cliente))
                              else g.datos end,
                         '{empresaId}', to_jsonb(c.id_cliente)),
       actualizado_en = now()
  from imp_cli c
 where c.id_cliente is not null
   and g.datos -> 'importacion' ->> 'lote' = (select lote from imp_meta)
   and coalesce(g.datos ->> 'empresaId', '') = ''
   and g.datos ->> 'clienteOrigen' = c.origen;


-- ---------------------------------------------------------------------
-- 8) Verificación
-- ---------------------------------------------------------------------
-- Dueño asignado: todo lo importado tiene propietario_uid = UUID del ejecutivo.
do $$
declare n integer;
begin
  select count(*) into n
  from public.gestion_comercial g
  left join imp_ej e on e.uid = g.propietario_uid
  where g.datos -> 'importacion' ->> 'lote' = (select lote from imp_meta) and e.uid is null;
  if n > 0 then
    raise exception '% registros importados sin dueño válido; se revierte la carga.', n;
  end if;
end $$;

commit;

-- Resumen por ejecutivo y tipo
select e.ini, e.nombre, e.uid as usuario_uuid, g.tipo, count(*) as registros,
       count(*) filter (where g.datos ->> 'estado' = 'Realizada') as realizadas,
       count(*) filter (where g.datos ->> 'estado' = 'Cancelada') as no_realizadas,
       count(*) filter (where g.datos ->> 'estado' = 'Programada') as programadas
from public.gestion_comercial g
join imp_ej e on e.uid = g.propietario_uid
where g.datos -> 'importacion' ->> 'lote' = 'CONSOLIDADO-PE-2026-11-09-20'
group by e.ini, e.nombre, e.uid, g.tipo
order by e.ini, g.tipo;

-- Clientes del documento y su vínculo a la Base Maestra (null = por conciliar a mano)
select c.origen as cliente_documento, c.id_cliente, k.nombre as nombre_base_maestra, coalesce(c.via, 'sin vincular') as via
from imp_cli c
left join public.clientes k on k.id_cliente = c.id_cliente
order by c.id_cliente nulls first, c.origen;

-- Registros con observaciones de conciliación (solapamientos, nombres a confirmar)
select g.id, g.responsable, g.datos ->> 'fecha' as fecha, g.datos ->> 'clienteOrigen' as cliente, g.datos ->> 'conciliar' as conciliar
from public.gestion_comercial g
where g.datos -> 'importacion' ->> 'lote' = 'CONSOLIDADO-PE-2026-11-09-20'
  and coalesce(g.datos ->> 'conciliar', '') <> ''
order by g.datos ->> 'fecha', g.id;
