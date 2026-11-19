# Prueba integral con datos TEST — Gestión Comercial, Planner y operación Colombia

Fecha de preparación: 18/11/2026 · Sin commit ni push · No se modificó `index.html`, `login.html` ni `usuarios.html`.

## 1. Persistencia: qué vive dónde

Comprobado en el código y con consultas de solo lectura a Supabase: las tablas existen, `gcm_aprobar_conversion` existe y rechaza a anónimos, y `mi_pais` / `uid_por_nombre` responden. Es decir, los scripts 30 y 31 están aplicados.

| Módulo | Dónde se guarda | ¿Se comparte entre usuarios? |
|---|---|---|
| Planner Perú (oportunidades, entregables, historial) | Supabase. localStorage solo como caché del primer pintado | Sí, también en tiempo real |
| Base Maestra de Clientes | Supabase `clientes` | Sí |
| Gestión Comercial (leads, agenda, visitas, tareas, solicitudes de conversión) | Supabase `gestion_comercial` + copia local por cuenta | Sí, también en tiempo real (RLS por dueño y país) |
| Aprobación de conversión **Perú** | Función de base `gcm_aprobar_conversion`: crea la oportunidad en `oportunidades` | Sí |
| **Planner Colombia** | Solo `localStorage['fp-demo-colombia-v1']` del navegador | **No** |
| **Solicitudes Colombia → Perú**, avisos, avances y entregas | Solo `localStorage['fp-demo-colombia-v1']` | **No**, y además solo se muestran al admin |
| Oportunidad creada al aprobar una conversión **Colombia** | `localStorage` de quien aprueba (`gcmCrearOppLocal`) | **No** |

## 2. Flujos que solo funcionan en el navegador del administrador

Están confirmados en el código. No dependen de los datos de prueba.

1. **Planner Colombia en localStorage.** Se carga con `coCargarStore()` y se guarda con `coGuardarStore()`, en [index.html:22731-22751](../../index.html#L22731-L22751). Cada navegador arma su propia copia desde el pipeline incluido en el código. Lo que Valeria cambia en Colombia no llega a Vivian ni a Misael.
2. **Una conversión Colombia aprobada no crea una oportunidad compartida.** La base solo marca la solicitud «Aprobada» y deja `opId` vacío (script 31, sección 9). La oportunidad la crea el navegador de quien aprueba, en [index.html:28521-28525](../../index.html#L28521-L28525) y [index.html:28580-28591](../../index.html#L28580-L28591):
   - Si aprueba Misael, la oportunidad queda solo en su navegador. Valeria no la ve en su Planner.
   - Vivian nunca la ve en su Planner Colombia.
   - El `opId` es un correlativo local de cada navegador, así que puede repetirse entre equipos.
3. **Las solicitudes Colombia → Perú son exclusivas del admin y locales.**
   - `coSolicitudes()` devuelve una lista vacía si el usuario no es admin ([index.html:22781-22788](../../index.html#L22781-L22788)).
   - Crear, aceptar, rechazar, proponer fecha o registrar avance exige `puedeEditar` ([index.html:22892](../../index.html#L22892)). Vivian, como ejecutiva, no puede solicitar apoyo.
4. **La Carga laboral de Perú no muestra los trabajos de Colombia a los responsables asignados.** `coTrabajosParaPeru()` parte de `coSolicitudes()`, que es solo para el admin ([index.html:22809](../../index.html#L22809)). El arquitecto o presupuestador asignado no ve el trabajo en su sesión. Solo lo ve Valeria, en su navegador.
5. **Los avisos de la campana de Colombia son solo para el admin y locales** ([index.html:22874-22880](../../index.html#L22874-L22880)).

Observación aparte: el perfil admin puede solicitar y también aprobar. Si Valeria crea un lead propio, puede autoaprobarlo. La regla de que nadie apruebe sus propias conversiones sí se cumple para los ejecutivos.

## 3. Datos TEST (aislados, sin cuentas nuevas)

| Tipo | Identificadores | Marca |
|---|---|---|
| Clientes | `CLI-TEST-PE`, `CLI-TEST-CO` | Nombre «ZZ TEST · …». El correlativo CLI-xxxx los ignora |
| Gestión Comercial | `TEST-CT-*`, `TEST-LD-*`, `TEST-AC-*`, `TEST-SC-*` | `datos.test = true` y título «[TEST] …» |
| Oportunidad Perú | Una sola, creada por la aprobación | Proyecto «[TEST] …», cliente `CLI-TEST-PE`, importe US$ 1, probabilidad 10 % |
| Historial | `conv-TEST-SC-PE` | — |

Cuentas reutilizadas: Valeria (admin), Misael (gerencia), Hugo y Jhon (ejecutivos Perú) y Vivian (ejecutiva Colombia). El script se detiene sin cargar nada si alguna falta o si su perfil no coincide.

Impacto en indicadores reales: mientras exista la oportunidad TEST, el Planner Perú cuenta un registro más por US$ 1. Gestión Comercial suma un lead, una visita y una solicitud por país, todos atribuidos a Hugo y Vivian. Todo se elimina con `TEST_99_limpiar.sql`.

## 4. Cómo ejecutar

1. **`TEST_01_prueba_integral.sql`** en Supabase → SQL Editor. Suplanta a cada cuenta real (`set local role authenticated` + su JWT), así que se aplican la RLS, el trigger `gcm_control` y la función de aprobación reales. Devuelve la matriz con FUNCIONA / FALLA por caso.
2. **Verificación en sesiones reales** (sección 6), con los datos TEST ya cargados.
3. **Flujos 3 y 4** en el navegador de Valeria (sección 6.3), con una oportunidad «[TEST] …» creada a mano en el Planner Colombia.
4. **`TEST_99_limpiar.sql`** y la limpieza local (sección 7).

## 5. Matriz de resultados

Leyenda:
- **FUNCIONA**: verificado.
- **FALLA**: confirmado en el código.
- **PENDIENTE**: hay que correr `TEST_01` o probarlo en sesiones reales.

Las filas marcadas *(SQL)* las resuelve automáticamente `TEST_01`. Completar la columna «Resultado» con su salida.

### Flujo 1 · Perú

| # | Caso | Usuario | Resultado |
|---|---|---|---|
| 1.1 | Ejecutivo crea cliente, contacto y lead *(SQL)* | Hugo | PENDIENTE |
| 1.2 | Programa y reporta la visita (Realizada) *(SQL)* | Hugo | PENDIENTE |
| 1.3 | Solicita conversión → «Pendiente de validación»; lead en solo consulta *(SQL)* | Hugo | PENDIENTE |
| 1.4 | Valeria valida → «En aprobación» *(SQL)* | Valeria | PENDIENTE |
| 1.5 | Misael aprueba → oportunidad en Planner Perú (KAM Hugo, Prospecto) e historial *(SQL)* | Misael | PENDIENTE |
| 1.6 | Aprobar dos veces no duplica *(SQL)* | Valeria | PENDIENTE |
| 1.7 | Hugo ve la oportunidad en su Planner Perú (sesión real) | Hugo | PENDIENTE |
| 1.8 | Valeria aprueba directo desde «Pendiente de validación» (UI) | Valeria | PENDIENTE |

### Flujo 2 · Colombia

| # | Caso | Usuario | Resultado |
|---|---|---|---|
| 2.1 | Ejecutiva crea cliente, contacto, lead y visita realizada *(SQL)* | Vivian | PENDIENTE |
| 2.2 | Solicita conversión; Valeria valida y aprueba *(SQL)* | Vivian / Valeria | PENDIENTE |
| 2.3 | La aprobación crea la oportunidad en un Planner Colombia compartido *(SQL)* | — | **FALLA**: `opId` vacío, no hay tabla de Planner Colombia |
| 2.4 | Vivian ve la oportunidad en su Planner Colombia | Vivian | **FALLA**: solo existe en el navegador de quien aprobó |
| 2.5 | Si aprueba Misael, Valeria administra la oportunidad en Planner | Misael / Valeria | **FALLA**: queda en el navegador de Misael |

### Flujo 3 · Solicitudes Colombia → Perú

| # | Caso | Usuario | Resultado |
|---|---|---|---|
| 3.1 | Solicitar Arquitectura y Presupuestos desde una oportunidad CO (navegador del admin) | Valeria | PENDIENTE (sección 6.3) |
| 3.2 | Vivian solicita apoyo a Perú | Vivian | **FALLA**: exige `puedeEditar` y el ejecutivo no lo tiene |
| 3.3 | Recepción en Perú por un usuario distinto del admin | Equipo Perú | **FALLA**: `coSolicitudes()` es solo para admin y la solicitud es local |
| 3.4 | Aceptar, rechazar, proponer fecha y asignar responsable (navegador del admin) | Valeria | PENDIENTE (sección 6.3) |

### Flujo 4 · Integración

| # | Caso | Usuario | Resultado |
|---|---|---|---|
| 4.1 | El trabajo aceptado aparece en Carga laboral Perú con 🇨🇴, responsable, fechas y avance (navegador del admin) | Valeria | PENDIENTE (sección 6.3) |
| 4.2 | El responsable asignado lo ve en su propia sesión | Arquitecto / presupuestador | **FALLA** |
| 4.3 | Colombia ve los avances y la entrega (misma sesión del admin, al cambiar de operación) | Valeria | PENDIENTE (sección 6.3) |
| 4.4 | Vivian ve los avances y la entrega en su sesión | Vivian | **FALLA** |

### Flujo 5 · Usuarios y permisos

| # | Caso | Usuario | Resultado |
|---|---|---|---|
| 5.1 | Otro ejecutivo no ve ni edita un lead ajeno *(SQL)* | Jhon | PENDIENTE |
| 5.2 | Ejecutivo de un país no ve leads del otro país *(SQL)* | Hugo / Vivian | PENDIENTE |
| 5.3 | Ejecutivo no crea una solicitud ya aprobada, no la valida ni la aprueba (RPC ni update) *(SQL)* | Hugo / Vivian | PENDIENTE |
| 5.4 | Lead en solo consulta tras solicitar *(SQL)* | Hugo | PENDIENTE |
| 5.5 | Gerencia no valida y no aprueba sin validación previa *(SQL)* | Misael | PENDIENTE |
| 5.6 | Ejecutivo no edita el Planner; Vivian no ve el Planner Perú *(SQL)* | Hugo / Vivian | PENDIENTE |
| 5.7 | Vivian no registra datos con país Perú *(SQL)* | Vivian | PENDIENTE |
| 5.8 | Sincronización en tiempo real entre sesiones (Gestión Comercial y Planner Perú) | Todos | PENDIENTE (sección 6.1) |
| 5.9 | El botón «Aprobar» no aparece para el ejecutivo (UI) | Hugo / Vivian | PENDIENTE (sección 6.2) |

## 6. Verificación en sesiones reales

Usar navegadores o perfiles distintos, uno por cuenta: por ejemplo Chrome normal, Chrome incógnito y Edge. Cada persona entra con su propio usuario. Nadie comparte contraseña.

### 6.1 Sincronización (tras correr `TEST_01`, con Valeria, Hugo y Misael abiertos a la vez)

1. **Hugo**, Gestión Comercial → Leads: ve «[TEST] Cámara de frío ficticia Perú» Convertido y la visita Realizada en su agenda de hoy.
2. **Jhon**: no ve ese lead.
3. **Misael** y **Valeria**: lo ven en Seguimiento Comercial.
4. **Hugo**, Planner Perú: ve la oportunidad «[TEST] …» en solo consulta.
5. **Vivian**: no ve el Planner Perú y sí ve su lead «[TEST] Túnel de congelado…».
6. Tiempo real:
   - Con todos abiertos, Hugo crea un lead «[TEST] sync» (cliente ZZ TEST · Cliente ficticio Perú), registra una visita realizada y solicita la conversión. Sin recargar, Valeria debe ver la solicitud pendiente en su campana o en Seguimiento.
   - Valeria valida. Sin recargar, Misael debe ver el botón «Aprobar».
   - Misael aprueba. Sin recargar, Valeria debe ver la nueva oportunidad en Planner Perú y Hugo el lead «Convertido».

### 6.2 Permisos en la interfaz

- **Hugo y Vivian**: en la ficha de su lead con conversión solicitada no aparecen «Validar», «Aprobar», «Devolver» ni «Rechazar», y el lead no se puede editar.
- **Misael**: con la solicitud «Pendiente de validación» no aparece «Aprobar». Aparece una vez que Valeria valida.
- **Devolución (opcional)**: Valeria devuelve una solicitud «[TEST] sync». El lead vuelve a «Calificado» en la sesión de Hugo con el motivo visible.

### 6.3 Colombia → Perú (solo funciona en el navegador de Valeria)

1. Operación Colombia → Planner: crear la oportunidad «[TEST] Apoyo Perú», cliente «ZZ TEST · Cliente ficticio Colombia», con una tarea de Arquitectura y otra de Presupuestos.
2. Desde la ficha, «Solicitar apoyo a Perú» para cada una.
3. Cambiar a Perú → Detalle → bandeja «Colombia»:
   - Aceptar Arquitectura y asignar un arquitecto con fecha comprometida.
   - En Presupuestos, proponer otra fecha.
   - Volver a Colombia, aceptar la fecha propuesta, volver a Perú y aceptar con un responsable.
   - Crear una tercera solicitud y rechazarla con motivo.
4. Perú → Carga laboral: los trabajos aceptados aparecen con 🇨🇴, el responsable, la fecha y el avance. Cambiar el avance a 50 % y luego marcar la entrega.
5. Colombia: la ficha y la campana muestran «Avance 50 %» y «Entregable recibido de Perú».
6. Control negativo: abrir la sesión del arquitecto asignado y la de Vivian. Ninguna de las dos ve estas solicitudes ni los trabajos. Eso confirma las filas 3.3, 4.2 y 4.4.

## 7. Limpieza

1. Cerrar las fichas abiertas de registros TEST en todas las sesiones. Si una ficha queda abierta y se guarda después de la limpieza, el registro vuelve a subirse.
2. Correr **`TEST_99_limpiar.sql`**. Tiene topes de seguridad: no borra nada si encuentra una oportunidad con cliente TEST cuyo proyecto no es «[TEST]», ni si hay demasiados candidatos. Muestra lo borrado y un control final que debe quedar en 0.
3. Recargar los paneles abiertos. La nube manda: Planner Perú y Gestión Comercial descartan los registros borrados.
4. Solo en el navegador de Valeria, y en cualquier otro donde se haya probado Colombia: abrir la consola del panel (F12) y pegar este código. Quita las oportunidades «[TEST]» o «ZZ TEST» del Planner Colombia local, con sus solicitudes y avisos, y la copia local TEST de Gestión Comercial. Después recarga la página.

```js
(()=>{const K='fp-demo-colombia-v1';const st=JSON.parse(localStorage.getItem(K)||'null');
if(st){const es=o=>/^\[TEST\]/.test(o.proyecto||'')||/^ZZ TEST/.test(o.cliente||'');
const ids=new Set(st.oportunidades.filter(es).map(o=>o.id));
st.oportunidades=st.oportunidades.filter(o=>!ids.has(o.id));
const sol=new Set(st.solicitudes.filter(s=>ids.has(s.oppId)).map(s=>s.id));
st.solicitudes=st.solicitudes.filter(s=>!sol.has(s.id));
st.notificaciones=(st.notificaciones||[]).filter(n=>!sol.has(n.solId));
localStorage.setItem(K,JSON.stringify(st));console.log('Colombia: -'+ids.size+' oportunidades, -'+sol.size+' solicitudes');}
const G='fp-gestion-comercial-v1';const g=JSON.parse(localStorage.getItem(G)||'[]');
const n=g.filter(f=>!(/^TEST-/.test(f.id)||(f.datos&&(f.datos.test||/^\[TEST\]/.test(f.datos.titulo||'')||/^CLI-TEST-/.test(f.datos.empresaId||'')))));
localStorage.setItem(G,JSON.stringify(n));console.log('Gestión Comercial local: -'+(g.length-n.length));
location.reload();})();
```

## 8. Recomendación (fuera del alcance de esta prueba)

Para que los flujos 2.3–2.5, 3 y 4 funcionen entre usuarios reales, la operación Colombia necesita persistencia en Supabase:

- oportunidades y entregables de Colombia, con la columna `pais` que ya existe en `oportunidades`;
- una tabla de solicitudes de apoyo con RLS: Vivian crea, el equipo de Perú acepta o rechaza, el responsable actualiza el avance;
- que `gcm_aprobar_conversion` cree también la oportunidad colombiana en la base.

Es un cambio de funcionalidad. No se hizo en esta prueba.
