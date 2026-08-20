# ADN de Diseño — Directorio Ejecutivo Frioteam

> **Documento de referencia visual, UX/UI y motion design**  
> Proyecto auditado: `https://directoriousuario.netlify.app/`  
> Tipo de producto: presentación ejecutiva B2B interactiva en formato web  
> Uso recomendado: dashboards de directorio, revisiones gerenciales, reportes comerciales y financieros de alto impacto.

---

## 1. Propósito del sistema visual

Este producto no debe tratarse como un dashboard operativo convencional. Su ADN corresponde a una **presentación ejecutiva navegable**, diseñada para dirigir una reunión, contar una historia y profundizar en la información solo cuando el presentador lo necesita.

El diseño combina cuatro funciones:

1. **Presentar:** cada sección funciona como una diapositiva ejecutiva.
2. **Explicar:** los indicadores incluyen contexto, meta, tendencia y lectura gerencial.
3. **Explorar:** tabs, cards, botones y vistas internas permiten profundizar sin abandonar la narrativa.
4. **Controlar la atención:** la interfaz muestra primero la conclusión y después el detalle.

### Principio rector

> **Primero la lectura ejecutiva; después la evidencia.**

El usuario debe comprender el estado de una métrica en pocos segundos. Las tablas, gráficos secundarios, comentarios y cálculos permanecen disponibles como segunda capa.

---

## 2. Personalidad visual

La experiencia debe sentirse:

- Tecnológica, pero no futurista en exceso.
- Corporativa, sin parecer una plantilla tradicional.
- Premium, mediante profundidad, contraste y precisión.
- Fría y técnica, alineada con la refrigeración industrial.
- Dinámica, mediante movimientos breves y funcionales.
- Ejecutiva, con títulos grandes, métricas dominantes y poco ruido visual.

### Conceptos visuales clave

- Frío inteligente.
- Ingeniería y precisión.
- Control y trazabilidad.
- Profundidad por capas.
- Información viva.
- Confianza institucional.

---

## 3. Arquitectura de la experiencia

### 3.1 Navegación narrativa

La navegación principal organiza el contenido como capítulos de una presentación:

- Agenda.
- Portada.
- Objetivos.
- Mano de Obra.
- Plan de Acción.
- Organigrama.
- Contabilidad.

No debe sentirse como un menú de software administrativo. Debe comportarse como un **índice de revisión ejecutiva**.

### 3.2 Estructura general de cada sección

Cada sección debe respetar esta jerarquía:

1. **Hero o encabezado de contexto.**
2. **Conclusión principal o KPI dominante.**
3. **Mini-KPIs o comparaciones.**
4. **Visualización principal.**
5. **Detalle complementario.**
6. **Acción de profundización.**

### 3.3 Capas de profundidad

La experiencia emplea tres niveles:

- **Nivel 1 — Resumen:** lectura inmediata y visual.
- **Nivel 2 — Análisis:** gráficos, comparaciones y distribución.
- **Nivel 3 — Evidencia:** tablas, casos, comentarios, organigramas o documentos.

La transición entre niveles debe ser clara y reversible mediante acciones como:

- `Ver análisis →`
- `Ver plan →`
- `Volver al resumen`
- `Análisis ejecutivo completo →`

---

## 4. Paleta cromática

### 4.1 Colores principales de marca

Los siguientes colores se obtienen de los activos visuales públicos del proyecto:

```css
:root {
  --ft-navy: #0A0A1E;
  --ft-blue: #3AABEF;
  --group-teal: #3EC6AC;
}
```

| Token | Hex | Uso principal |
|---|---:|---|
| `--ft-navy` | `#0A0A1E` | Fondos oscuros, títulos, navegación y contraste institucional. |
| `--ft-blue` | `#3AABEF` | Acentos, series principales, botones, progresos y resaltados. |
| `--group-teal` | `#3EC6AC` | Marca Grupo Friopacking, estados positivos y acento secundario. |

### 4.2 Superficies recomendadas

Los siguientes tokens reconstruyen el comportamiento visual observado y permiten replicar el estilo de manera consistente:

```css
:root {
  --bg-deep: #070B18;
  --bg-navy: #0A0A1E;
  --bg-panel-dark: #11172A;
  --bg-panel-soft: #F4F7FB;
  --surface: #FFFFFF;
  --surface-muted: #F8FAFD;
  --surface-glass: rgba(255, 255, 255, 0.08);

  --text-primary: #101426;
  --text-secondary: #596276;
  --text-muted: #8B94A7;
  --text-on-dark: #FFFFFF;
  --text-on-dark-muted: rgba(255, 255, 255, 0.68);

  --border-light: rgba(15, 24, 48, 0.08);
  --border-dark: rgba(255, 255, 255, 0.12);
  --grid-line: rgba(69, 91, 130, 0.10);
}
```

### 4.3 Colores semánticos

```css
:root {
  --success: #22B573;
  --success-soft: #E9F8F1;
  --warning: #F5A623;
  --warning-soft: #FFF5DF;
  --danger: #E55353;
  --danger-soft: #FDECEC;
  --info: #3AABEF;
  --info-soft: #EAF6FD;
  --neutral: #667085;
}
```

### 4.4 Regla de aplicación

- El azul Frioteam identifica el dato o acción principal.
- El turquesa se utiliza como refuerzo corporativo o estado favorable.
- El verde, ámbar y rojo se reservan para estados, no para decoración.
- Los fondos oscuros se concentran en portada, navegación y heroes especiales.
- Las áreas de lectura densa deben permanecer claras.
- Nunca usar más de dos colores de acento dominantes dentro de una misma card.

---

## 5. Tipografía

### 5.1 Familia recomendada

La estética observada corresponde a una sans serif geométrica y limpia. Para replicarla:

```css
font-family: Inter, Manrope, "Segoe UI", Arial, sans-serif;
```

Prioridad sugerida:

1. `Inter` para datos, tablas y UI.
2. `Manrope` opcional para títulos de alto impacto.
3. `Segoe UI` como respaldo nativo.

### 5.2 Escala tipográfica

```css
:root {
  --fs-display-xl: clamp(3.2rem, 6vw, 6.2rem);
  --fs-display: clamp(2.4rem, 4.5vw, 4.6rem);
  --fs-h1: clamp(2rem, 3.2vw, 3.4rem);
  --fs-h2: clamp(1.55rem, 2.2vw, 2.4rem);
  --fs-h3: 1.25rem;
  --fs-kpi-xl: clamp(2.2rem, 4vw, 4rem);
  --fs-kpi: clamp(1.65rem, 2.6vw, 2.7rem);
  --fs-body-lg: 1.05rem;
  --fs-body: 0.94rem;
  --fs-small: 0.78rem;
  --fs-micro: 0.68rem;
}
```

### 5.3 Pesos y jerarquía

- **800:** titulares de portada y métricas dominantes.
- **700:** títulos de cards, subtítulos y KPIs.
- **600:** labels, tabs, botones y encabezados de tabla.
- **500:** datos secundarios y leyendas.
- **400:** texto descriptivo.

### 5.4 Tratamiento de textos

#### Eyebrow o antetítulo

- Mayúsculas.
- Tracking entre `0.08em` y `0.14em`.
- Peso 600–700.
- Tamaño reducido.
- Color de acento o gris medio.

Ejemplo:

```text
REVISIÓN EJECUTIVA · JULIO 2026
```

#### Título principal

- De una a tres líneas.
- Interlineado compacto: `0.95–1.08`.
- Peso 750–850.
- Preferir frases, no nombres técnicos de módulos.

#### KPI

- Números grandes.
- Espaciado tabular.
- Unidad secundaria de menor tamaño.
- Separación visual entre valor, contexto y comparación.

```css
.kpi-value {
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.045em;
}
```

---

## 6. Espaciado y composición

### 6.1 Escala base

Usar una escala de 4 puntos:

```css
:root {
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-5: 20px;
  --space-6: 24px;
  --space-8: 32px;
  --space-10: 40px;
  --space-12: 48px;
  --space-16: 64px;
  --space-20: 80px;
}
```

### 6.2 Contenedor principal

```css
.page-container {
  width: min(1440px, calc(100% - 48px));
  margin-inline: auto;
}
```

- Desktop amplio: `max-width` entre `1360px` y `1480px`.
- Desktop estándar: padding horizontal `24–40px`.
- Tablet: `20–24px`.
- Móvil: `16px`.

### 6.3 Ritmo vertical

- Hero a contenido: `32–48px`.
- Bloques principales: `28–40px`.
- Cards relacionadas: `16–24px`.
- Label a valor: `4–8px`.
- Título a descripción: `8–12px`.

### 6.4 Regla de densidad

- Las pantallas de apertura pueden ser espaciosas.
- Las pantallas analíticas pueden ser más densas, pero deben conservar agrupación visual.
- Una sección no debe combinar simultáneamente demasiados gráficos, tarjetas y tablas con igual peso.
- La composición siempre debe tener un foco dominante.

---

## 7. Bordes, radios y profundidad

### 7.1 Radios

```css
:root {
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 18px;
  --radius-xl: 24px;
  --radius-pill: 999px;
}
```

Uso:

- Chips y estados: `999px`.
- Botones: `10–14px`.
- Cards estándar: `16–20px`.
- Heroes y cards de alto impacto: `20–28px`.
- Modales: `20–24px`.

### 7.2 Sombras

La profundidad debe ser suave, amplia y limpia. Evitar sombras negras duras.

```css
:root {
  --shadow-xs: 0 2px 8px rgba(10, 18, 45, 0.05);
  --shadow-sm: 0 6px 18px rgba(10, 18, 45, 0.07);
  --shadow-md: 0 14px 36px rgba(10, 18, 45, 0.10);
  --shadow-lg: 0 24px 60px rgba(6, 12, 32, 0.16);
  --shadow-blue: 0 16px 40px rgba(58, 171, 239, 0.20);
}
```

### 7.3 Capas de profundidad

1. Fondo general.
2. Card principal.
3. Elemento activo o destacado.
4. Popover, tooltip o modal.

Cada salto debe incrementar ligeramente sombra, contraste y elevación.

---

## 8. Fondo y ambientación

### 8.1 Portada oscura

La portada debe sentirse inmersiva:

- Fondo azul noche o imagen industrial.
- Overlay oscuro de `55–75%`.
- Degradado para proteger la legibilidad del texto.
- Elementos de marca grandes, pero no invasivos.
- Uso decorativo de engranajes, copos o formas técnicas con baja opacidad.

```css
.cover {
  background:
    linear-gradient(90deg, rgba(7, 11, 24, .94) 0%, rgba(7, 11, 24, .76) 46%, rgba(7, 11, 24, .48) 100%),
    var(--cover-image) center / cover no-repeat;
}
```

### 8.2 Grid tecnológico sutil

Para heroes o secciones tecnológicas puede añadirse una cuadrícula casi imperceptible:

```css
.tech-grid {
  background-image:
    linear-gradient(rgba(58,171,239,.045) 1px, transparent 1px),
    linear-gradient(90deg, rgba(58,171,239,.045) 1px, transparent 1px);
  background-size: 32px 32px;
}
```

### 8.3 Brillos ambientales

Usar halos radiales con opacidad baja:

```css
.ambient-glow::before {
  content: "";
  position: absolute;
  width: 520px;
  height: 520px;
  border-radius: 50%;
  background: radial-gradient(circle, rgba(58,171,239,.18), transparent 68%);
  filter: blur(20px);
  pointer-events: none;
}
```

Nunca colocar más de dos halos visibles en una pantalla.

---

## 9. Navegación superior

### 9.1 Apariencia

- Barra horizontal fija o sticky.
- Logo a la izquierda.
- Navegación centrada o alineada a la derecha.
- Fondo claro translúcido o fondo oscuro según sección.
- Backdrop blur moderado.
- Separación inferior tenue.

```css
.topbar {
  position: sticky;
  top: 0;
  z-index: 1000;
  backdrop-filter: blur(18px);
  -webkit-backdrop-filter: blur(18px);
  border-bottom: 1px solid var(--border-light);
}
```

### 9.2 Estado activo

El estado activo debe combinar:

- Mayor peso tipográfico.
- Color azul Frioteam.
- Línea, cápsula o fondo suave.
- Transición deslizante, no aparición brusca.

### 9.3 Comportamiento

- El cambio de sección debe preservar la sensación de presentación.
- Evitar recargas de página.
- Mantener el foco visual en la parte superior de la nueva sección.
- En móvil, convertir el menú en scroll horizontal o menú compacto.

---

## 10. Pantalla de carga

El proyecto incorpora una escena de carga con texto `Cargando` y confirmación visual.

### Secuencia recomendada

1. Logo o símbolo aparece con `fade + scale`.
2. Indicador de carga o línea progresa.
3. Se muestra un check breve.
4. La pantalla completa se desvanece.
5. La portada entra con una transición más lenta.

```css
@keyframes loaderPulse {
  0%, 100% { transform: scale(.96); opacity: .65; }
  50% { transform: scale(1); opacity: 1; }
}

@keyframes loaderExit {
  to { opacity: 0; visibility: hidden; }
}
```

Duración total sugerida: `900–1500ms`.  
No bloquear al usuario más tiempo del necesario.

---

## 11. Heroes ejecutivos

### 11.1 Función

El hero debe establecer:

- Sección.
- Periodo.
- Mensaje principal.
- Indicador dominante.
- Contexto de meta o variación.

### 11.2 Composición recomendada

Desktop:

- Columna izquierda: título, periodo y narrativa.
- Columna derecha: KPI o mini-KPIs.

Alternativa:

- Título en parte superior.
- Banda inferior de KPIs.

### 11.3 Mini-KPIs

Cada mini-KPI debe contener como máximo:

- Label.
- Valor.
- Contexto o comparación.

No convertir mini-KPIs en cards independientes con exceso de bordes. Pueden estar separados mediante divisores verticales.

---

## 12. Cards

### 12.1 Card base

```css
.card {
  background: var(--surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  padding: 24px;
}
```

### 12.2 Comportamiento hover

```css
.card-interactive {
  transition:
    transform 220ms cubic-bezier(.2,.8,.2,1),
    box-shadow 220ms ease,
    border-color 220ms ease;
}

.card-interactive:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-md);
  border-color: rgba(58,171,239,.25);
}
```

### 12.3 Tipos de card

#### Card KPI

- Valor dominante.
- Label breve.
- Meta o comparación.
- Indicador de estado.
- Barra o micrográfico opcional.

#### Card de objetivo

- Número del objetivo.
- Nombre.
- Meta anual.
- Avance actual.
- Flecha para ingresar.

#### Card de plan de acción

- Categoría del plan.
- Número y tipo.
- Título.
- Tres indicadores concretos.
- Estado.
- Acción `Ver plan →`.

#### Card de alerta

- Franja superior o icono semántico.
- Estado visible.
- Valor principal.
- Benchmark.
- Recomendación ejecutiva.

#### Card de evidencia

- Imagen o captura.
- Texto explicativo.
- Secuencia numerada.
- Flechas de proceso.

---

## 13. Estados y chips

### Estados principales

- Favorable.
- Moderado.
- Crítico.
- En proceso.
- Completado.
- Fuera de meta.
- Superada.

```css
.status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  font-size: .72rem;
  font-weight: 700;
  letter-spacing: .02em;
}
```

### Regla semántica

El estado nunca debe comunicarse únicamente con color. Añadir:

- Texto.
- Icono.
- Símbolo de tendencia.
- Benchmark cuando corresponda.

---

## 14. Botones y enlaces

### 14.1 Botón primario

```css
.btn-primary {
  background: linear-gradient(135deg, #3AABEF, #248ED8);
  color: #fff;
  border: 0;
  border-radius: 12px;
  box-shadow: 0 10px 24px rgba(58,171,239,.24);
  transition: transform 180ms ease, box-shadow 180ms ease;
}
```

Hover:

- Elevación de `-2px`.
- Sombra azul ligeramente mayor.
- Flecha con desplazamiento horizontal de `2–4px`.

### 14.2 Enlace ejecutivo

Acciones como `Ver análisis →` deben sentirse ligeras:

- Sin fondo permanente.
- Peso 600–700.
- Flecha animada en hover.
- Subrayado opcional mediante pseudo-elemento.

### 14.3 Botones secundarios

- Fondo blanco o transparente.
- Borde tenue.
- Hover con fondo azul muy suave.

---

## 15. Tabs y segmentadores

### 15.1 Tabs internos

- Contenedor compacto.
- Fondo suave.
- Tab activo en blanco o azul oscuro.
- Indicador activo animado.
- Radio tipo cápsula.

```css
.tabs {
  display: inline-flex;
  padding: 4px;
  border-radius: 12px;
  background: #EEF2F7;
}
```

### 15.2 Reglas

- Máximo recomendado: 5 tabs visibles.
- Labels de una línea.
- El contenido debe cambiar sin salto brusco de altura.
- Conservar la posición de lectura.
- En móvil, permitir scroll horizontal.

### 15.3 Transición de contenido

```css
.tab-panel.is-entering {
  animation: panelIn 320ms cubic-bezier(.2,.8,.2,1) both;
}

@keyframes panelIn {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}
```

---

## 16. Sistema de gráficos

El proyecto emplea gráficos como evidencia narrativa. Cada gráfico debe responder una pregunta concreta.

### 16.1 Principios

- Un gráfico, un mensaje principal.
- Título que explique la lectura, no solo la variable.
- Tooltips ricos.
- Leyendas compactas.
- Ejes discretos.
- Líneas de cuadrícula muy suaves.
- Colores consistentes entre secciones.
- Animación solo en la entrada o al cambiar filtro.

### 16.2 Tipografía del gráfico

```js
const chartTypography = {
  family: 'Inter, Segoe UI, sans-serif',
  size: 12,
  weight: 500
};
```

- Ticks: `11–12px`.
- Leyenda: `12–13px`, peso 600.
- Tooltip: `12–13px`.
- Etiquetas de datos: `11–12px`, peso 600–700.

### 16.3 Gráficos de línea

Usos:

- Evolución acumulada.
- Tendencia mensual.
- Comparación histórica.

Especificación:

- Grosor de línea: `2.5–3px`.
- Punto normal: `0–2px`.
- Punto hover: `4–5px`.
- Tensión: `0.3–0.4`.
- Área bajo la línea opcional y muy transparente.
- Serie principal en azul Frioteam.
- Series históricas en grises o azules desaturados.

```js
const lineDataset = {
  borderWidth: 3,
  tension: 0.36,
  pointRadius: 0,
  pointHoverRadius: 5,
  fill: false
};
```

### 16.4 Gráficos de barras

Usos:

- Comparación por canal.
- Distribución por zona.
- Venta o margen por categoría.

Especificación:

- Radio superior: `6–10px`.
- Separación suficiente.
- Hover con mayor saturación, no con cambio radical de color.
- Etiquetas visibles solo cuando aporten lectura.

```js
const barDataset = {
  borderRadius: 8,
  borderSkipped: false,
  categoryPercentage: 0.68,
  barPercentage: 0.78
};
```

### 16.5 Donas

Usos:

- Distribución de ventas.
- Participación de categorías.
- Servicios evaluados.

Especificación:

- `cutout`: `68–74%`.
- Centro con total o métrica principal.
- Máximo 5–6 segmentos visibles.
- Para más categorías, agrupar en `Otros` o usar barras.

### 16.6 Barras de progreso

- Altura: `6–10px`.
- Fondo gris azulado.
- Relleno con degradado sutil.
- Animación horizontal al ingresar.
- Etiqueta de meta separada del valor real.

### 16.7 Gráficos mixtos

Solo utilizarlos cuando las métricas compartan una relación clara. Diferenciar:

- Barras para volumen.
- Línea para tasa, margen o participación.
- Eje secundario explícito.

### 16.8 Tooltips

El tooltip debe contener:

1. Periodo o categoría.
2. Valor principal.
3. Comparación o porcentaje.
4. Contexto adicional si es necesario.

```js
const tooltipStyle = {
  backgroundColor: 'rgba(10,10,30,.94)',
  titleColor: '#FFFFFF',
  bodyColor: 'rgba(255,255,255,.82)',
  padding: 12,
  cornerRadius: 10,
  displayColors: true
};
```

---

## 17. Tablas ejecutivas

### 17.1 Apariencia

- Fondo blanco.
- Encabezado gris azulado o azul noche, según densidad.
- Filas con separación ligera.
- Hover de fila suave.
- Números alineados a la derecha.
- Texto alineado a la izquierda.
- Valores tabulares.

### 17.2 Jerarquía

- Primera columna más prominente.
- Totales destacados mediante peso y fondo.
- Variaciones con icono y color semántico.
- Columnas secundarias pueden reducir contraste.

### 17.3 Sticky headers

En tablas extensas:

```css
thead th {
  position: sticky;
  top: 0;
  z-index: 2;
}
```

### 17.4 Tablas dentro de una presentación

- No mostrar más filas de las necesarias en la primera vista.
- Ofrecer scroll interno o modal de detalle.
- Mantener visible la conclusión por encima de la tabla.

---

## 18. Visualización de objetivos

El sistema de objetivos funciona como un conjunto de historias individuales.

### Vista resumen

Cada objetivo contiene:

- Número.
- Nombre.
- Meta anual.
- Avance.
- Estado visual.
- Acción para ingresar.

### Vista de detalle

Debe incluir:

- Navegación de regreso.
- Título y periodo.
- Valor actual frente a meta.
- Variación frente a años previos.
- Gráfico principal.
- Tabla o distribución.
- Interpretación ejecutiva.

### Regla de lectura

El objetivo no se comunica solo con un porcentaje. Deben mostrarse simultáneamente:

- Resultado actual.
- Meta.
- Esperado al periodo.
- Comparación histórica.

---

## 19. Planes de acción

### Vista general

Las cards de plan deben funcionar como portadas de proyecto.

Jerarquía:

1. Categoría estratégica.
2. Número del plan.
3. Título principal.
4. Tres datos concretos.
5. Estado.
6. Acción de detalle.

### Vista de detalle

Puede estructurarse mediante preguntas:

- ¿Por qué?
- ¿Cuándo?
- ¿Con quién?
- ¿Para qué?
- ¿Cuánto?

Esto convierte el contenido en una narrativa de decisión y facilita la revisión en directorio.

### Responsables

Los responsables deben representarse mediante:

- Avatares o iconos discretos.
- Chips o lista agrupada.
- Jerarquía clara entre líder y equipo involucrado.

---

## 20. Organigrama y mapas de equipo

### Principios

- Mostrar jerarquía sin saturar con líneas.
- Utilizar cards consistentes por nivel.
- Diferenciar sedes, zonas o áreas mediante color secundario, no mediante diseños completamente distintos.
- Permitir entrar al detalle de una sede o equipo.

### Cards de persona

Contenido recomendado:

- Foto o iniciales.
- Nombre.
- Cargo.
- Sede o zona.
- Estado o especialidad.
- Acción `Ver perfil` cuando corresponda.

### Mapas y distribución

- El mapa es contextual, no decorativo.
- Debe acompañarse de totales y distribución por tipo de colaborador.
- La interacción debe resaltar una zona y actualizar el detalle lateral.

---

## 21. Estados financieros y ratios

Las secciones financieras requieren mayor sobriedad.

### KPIs financieros

- Valor grande.
- Variación interanual.
- Estado semántico.
- Benchmark.
- Explicación de una línea.

### Alertas prioritarias

Una alerta principal puede ocupar todo el ancho y contener:

- Icono.
- Nivel de criticidad.
- Indicador.
- Comparación contra benchmark.
- Impacto.
- Recomendación.

### Ratios

Usar cards homogéneas y agruparlas por dimensión:

- Liquidez.
- Endeudamiento.
- Gestión.
- Rentabilidad.

No mezclar todos los ratios sin una jerarquía de criticidad.

---

## 22. Modales, drawers y vistas de detalle

### 22.1 Modal

```css
.modal-backdrop {
  background: rgba(5, 9, 22, .58);
  backdrop-filter: blur(8px);
}

.modal {
  border-radius: 22px;
  box-shadow: var(--shadow-lg);
  animation: modalIn 260ms cubic-bezier(.2,.8,.2,1) both;
}

@keyframes modalIn {
  from { opacity: 0; transform: translateY(12px) scale(.985); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}
```

### 22.2 Drawer lateral

Usar para:

- Perfil de colaborador.
- Detalle de indicador.
- Filtros avanzados.
- Explicación metodológica.

Entrada lateral entre `280–360ms`.

### 22.3 Regla de cierre

Siempre incluir:

- Botón de cerrar visible.
- Cierre con `Esc`.
- Cierre por backdrop cuando no exista riesgo de pérdida de datos.
- Retorno del foco al elemento de origen.

---

## 23. Sistema de movimiento

El movimiento es parte del ADN, pero debe permanecer subordinado a la lectura.

### 23.1 Principios de motion design

- Breve.
- Suave.
- Direccional.
- Consistente.
- Vinculado a una acción o cambio de estado.
- Sin loops decorativos permanentes, salvo ambientación extremadamente sutil.

### 23.2 Curvas de aceleración

```css
:root {
  --ease-standard: cubic-bezier(.2, .8, .2, 1);
  --ease-emphasized: cubic-bezier(.16, 1, .3, 1);
  --ease-exit: cubic-bezier(.4, 0, 1, 1);
}
```

### 23.3 Duraciones

| Acción | Duración |
|---|---:|
| Hover simple | `160–220ms` |
| Botón o chip | `140–180ms` |
| Cambio de tab | `240–340ms` |
| Entrada de card | `320–500ms` |
| Cambio de sección | `420–650ms` |
| Modal o drawer | `260–380ms` |
| Animación de gráfico | `700–1100ms` |
| Contador KPI | `800–1400ms` |

### 23.4 Entrada de sección

```css
@keyframes sectionReveal {
  from {
    opacity: 0;
    transform: translateY(18px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
```

### 23.5 Stagger de cards

- Diferencia entre cards: `50–90ms`.
- Máximo total del stagger: `450ms`.
- No animar veinte filas individualmente.

```css
.card-reveal {
  opacity: 0;
  animation: cardReveal 480ms var(--ease-emphasized) forwards;
}
```

### 23.6 Contadores

Los números dominantes pueden realizar `count-up` una sola vez al entrar en viewport.

Reglas:

- Respetar decimales y unidades.
- No reiniciar al mover el cursor.
- No usar para datos críticos que deban mostrarse instantáneamente tras un filtro.

### 23.7 Barras de progreso

```css
@keyframes growX {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}

.progress-fill {
  transform-origin: left center;
  animation: growX 900ms var(--ease-emphasized) both;
}
```

### 23.8 Hover de flecha

```css
.link-arrow svg {
  transition: transform 180ms ease;
}

.link-arrow:hover svg {
  transform: translateX(4px);
}
```

### 23.9 Movimiento ambiental

Puede existir un desplazamiento lento en halos o elementos de fondo:

- Duración: `10–18s`.
- Distancia: `8–20px`.
- Opacidad baja.
- Sin afectar texto ni gráficos.

### 23.10 Reduced motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

---

## 24. Scroll y transiciones entre escenas

### Comportamiento recomendado

- Scroll suave para navegación interna.
- Cada sección inicia con suficiente aire superior.
- La barra de navegación puede actualizar el estado activo según la sección visible.
- Evitar scroll-jacking estricto.
- En una reunión, debe ser posible avanzar mediante menú, botones y scroll normal.

### Transición de sección

Al seleccionar un capítulo:

1. Atenuar ligeramente la sección actual.
2. Mover al destino.
3. Revelar el hero.
4. Activar cards y gráficos cuando sean visibles.

---

## 25. Imágenes y capturas de evidencia

Las capturas de sistemas, documentos o apps deben presentarse como evidencia dentro de una narrativa.

### Tratamiento

- Marco con radio `12–18px`.
- Borde tenue.
- Sombra media.
- Fondo neutro.
- Caption o paso numerado.
- Zoom o modal opcional.

### Flujos visuales

Cuando existan procesos, utilizar:

- Pasos numerados.
- Flechas simples.
- Una captura por paso.
- Texto de máximo dos líneas por etapa.

---

## 26. Iconografía

### Estilo

- Línea o sólido simple.
- Grosor uniforme.
- Esquinas redondeadas.
- Tamaños de `16`, `20`, `24` y `32px`.
- Evitar mezclar familias con estilos distintos.

### Uso

- Icono como refuerzo, no como sustituto de un label crítico.
- En cards de estado, usar icono dentro de una cápsula o círculo suave.
- En heroes, los iconos pueden ser mayores, con opacidad controlada.

---

## 27. Diseño responsive

### Breakpoints sugeridos

```css
/* mobile */
@media (max-width: 639px) {}

/* tablet */
@media (min-width: 640px) and (max-width: 1023px) {}

/* desktop */
@media (min-width: 1024px) {}

/* wide */
@media (min-width: 1440px) {}
```

### 27.1 Desktop

- Aprovechar composición de 12 columnas.
- Heroes en dos columnas.
- Cards de objetivos en grillas.
- Gráfico y tabla pueden convivir.

### 27.2 Tablet

- Reducir a 6 columnas.
- Permitir hero apilado.
- Conservar KPIs en dos o tres columnas.
- Tabs con scroll horizontal.

### 27.3 Móvil

- Una columna.
- Navegación compacta.
- Títulos con menor ancho visual.
- KPIs grandes, pero sin desbordar.
- Gráficos con altura mínima de `280–340px`.
- Tablas con scroll horizontal.
- Modales casi a pantalla completa.
- Evitar tooltips dependientes exclusivamente del hover.

### 27.4 Regla de prioridad móvil

Ordenar el contenido así:

1. Conclusión.
2. KPI.
3. Estado.
4. Gráfico.
5. Comparación.
6. Tabla o evidencia.

---

## 28. Accesibilidad

### Contraste

- Texto normal: mínimo `4.5:1`.
- Texto grande: mínimo `3:1`.
- Evitar gris claro sobre blanco.
- Los textos dentro de gradientes deben conservar alto contraste.

### Teclado

- Tabs navegables con flechas.
- Botones y enlaces con foco visible.
- Modales con focus trap.
- Orden lógico de tabulación.

### Foco

```css
:focus-visible {
  outline: 3px solid rgba(58,171,239,.38);
  outline-offset: 3px;
}
```

### Gráficos

- Resumen textual adyacente.
- Tooltips accesibles o tabla alternativa.
- No depender solo del color.

---

## 29. Rendimiento

- Comprimir imágenes.
- Almacenar logos y fotos localmente dentro del proyecto.
- Usar `loading="lazy"` fuera del primer viewport.
- Crear gráficos solo cuando su panel esté visible.
- Destruir instancias de gráficos antes de recrearlas.
- Evitar animar `width`, `height`, `top` o `left`; preferir `transform` y `opacity`.
- Usar `will-change` únicamente durante animaciones concretas.
- Reducir sombras y blur en móvil si afectan el rendimiento.

---

## 30. Tokens CSS consolidados

```css
:root {
  /* Brand */
  --ft-navy: #0A0A1E;
  --ft-blue: #3AABEF;
  --group-teal: #3EC6AC;

  /* Backgrounds */
  --bg-deep: #070B18;
  --bg-panel-dark: #11172A;
  --bg-panel-soft: #F4F7FB;
  --surface: #FFFFFF;
  --surface-muted: #F8FAFD;

  /* Text */
  --text-primary: #101426;
  --text-secondary: #596276;
  --text-muted: #8B94A7;
  --text-on-dark: #FFFFFF;

  /* Semantic */
  --success: #22B573;
  --warning: #F5A623;
  --danger: #E55353;
  --info: #3AABEF;

  /* Borders */
  --border-light: rgba(15,24,48,.08);
  --border-dark: rgba(255,255,255,.12);

  /* Radius */
  --radius-sm: 8px;
  --radius-md: 12px;
  --radius-lg: 18px;
  --radius-xl: 24px;
  --radius-pill: 999px;

  /* Shadows */
  --shadow-xs: 0 2px 8px rgba(10,18,45,.05);
  --shadow-sm: 0 6px 18px rgba(10,18,45,.07);
  --shadow-md: 0 14px 36px rgba(10,18,45,.10);
  --shadow-lg: 0 24px 60px rgba(6,12,32,.16);
  --shadow-blue: 0 16px 40px rgba(58,171,239,.20);

  /* Motion */
  --ease-standard: cubic-bezier(.2,.8,.2,1);
  --ease-emphasized: cubic-bezier(.16,1,.3,1);
  --duration-fast: 180ms;
  --duration-base: 280ms;
  --duration-slow: 520ms;
}
```

---

## 31. Configuración base recomendada para Chart.js

```js
Chart.defaults.font.family = 'Inter, Segoe UI, sans-serif';
Chart.defaults.color = '#667085';
Chart.defaults.animation.duration = 900;
Chart.defaults.animation.easing = 'easeOutQuart';
Chart.defaults.responsive = true;
Chart.defaults.maintainAspectRatio = false;

const executiveChartOptions = {
  interaction: {
    mode: 'index',
    intersect: false
  },
  plugins: {
    legend: {
      position: 'top',
      align: 'end',
      labels: {
        usePointStyle: true,
        pointStyle: 'circle',
        boxWidth: 8,
        boxHeight: 8,
        padding: 18,
        font: { size: 12, weight: 600 }
      }
    },
    tooltip: {
      backgroundColor: 'rgba(10,10,30,.94)',
      titleColor: '#FFFFFF',
      bodyColor: 'rgba(255,255,255,.82)',
      padding: 12,
      cornerRadius: 10,
      displayColors: true
    }
  },
  scales: {
    x: {
      grid: { display: false },
      border: { display: false },
      ticks: { color: '#7A8499' }
    },
    y: {
      beginAtZero: true,
      grid: { color: 'rgba(69,91,130,.10)' },
      border: { display: false },
      ticks: { color: '#7A8499' }
    }
  }
};
```

---

## 32. Animaciones CSS base

```css
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes scaleIn {
  from { opacity: 0; transform: scale(.97); }
  to { opacity: 1; transform: scale(1); }
}

@keyframes slideInRight {
  from { opacity: 0; transform: translateX(22px); }
  to { opacity: 1; transform: translateX(0); }
}

@keyframes growX {
  from { transform: scaleX(0); }
  to { transform: scaleX(1); }
}

@keyframes pulseSoft {
  0%, 100% { opacity: .72; transform: scale(1); }
  50% { opacity: 1; transform: scale(1.025); }
}
```

### Clases de utilidad

```css
.reveal-up {
  animation: fadeUp 480ms var(--ease-emphasized) both;
}

.reveal-scale {
  animation: scaleIn 360ms var(--ease-emphasized) both;
}

.progress-animate {
  transform-origin: left;
  animation: growX 900ms var(--ease-emphasized) both;
}
```

---

## 33. Patrón recomendado de entrada con IntersectionObserver

```js
const revealObserver = new IntersectionObserver((entries) => {
  entries.forEach((entry) => {
    if (!entry.isIntersecting) return;
    entry.target.classList.add('is-visible');
    revealObserver.unobserve(entry.target);
  });
}, {
  threshold: 0.15,
  rootMargin: '0px 0px -8% 0px'
});

document.querySelectorAll('[data-reveal]').forEach((element) => {
  revealObserver.observe(element);
});
```

Regla: ejecutar la animación una sola vez, salvo que el contenido cambie por filtro o tab.

---

## 34. Reglas de composición para presentaciones B2B

### Sí hacer

- Convertir cada pantalla en una conclusión ejecutiva.
- Mostrar metas, brechas y tendencias junto al valor.
- Utilizar números grandes y textos cortos.
- Reservar el detalle para una segunda interacción.
- Mantener una paleta consistente.
- Utilizar movimiento para guiar la atención.
- Diseñar los estados críticos con explicación y recomendación.
- Mantener tablas y gráficos sincronizados.

### No hacer

- Mostrar todos los datos al mismo nivel.
- Usar demasiadas tarjetas pequeñas.
- Animar permanentemente cada elemento.
- Agregar colores sin significado.
- Utilizar sombras negras duras.
- Hacer gráficos con demasiadas series similares.
- Ocultar información crítica exclusivamente en tooltips.
- Cambiar diseño, tipografía o comportamiento entre secciones sin una razón funcional.

---

## 35. Checklist de revisión visual

### Marca

- [ ] El azul principal es `#3AABEF`.
- [ ] El azul noche es `#0A0A1E`.
- [ ] El turquesa de Grupo Friopacking es `#3EC6AC`.
- [ ] Los logos conservan proporción y zona de seguridad.

### Jerarquía

- [ ] Cada pantalla tiene un foco dominante.
- [ ] El KPI principal se reconoce en menos de tres segundos.
- [ ] La meta y comparación están visibles.
- [ ] Las acciones de detalle son claras.

### Gráficos

- [ ] Cada gráfico responde una sola pregunta.
- [ ] Los tooltips incluyen contexto.
- [ ] Los ejes y leyendas son legibles.
- [ ] Los colores son consistentes entre vistas.
- [ ] La tabla y el gráfico usan la misma fuente de datos.

### Movimiento

- [ ] Las animaciones no retrasan la lectura.
- [ ] Los hovers duran menos de `220ms`.
- [ ] Las entradas se ejecutan una sola vez.
- [ ] Existe soporte para `prefers-reduced-motion`.

### Responsive

- [ ] No existe scroll horizontal global.
- [ ] Los tabs funcionan en móvil.
- [ ] Los gráficos conservan una altura legible.
- [ ] Las tablas tienen contenedor de scroll.
- [ ] Los modales se adaptan a pantalla completa cuando es necesario.

### Accesibilidad

- [ ] Existe foco visible.
- [ ] Los estados no dependen solo del color.
- [ ] Los botones tienen labels claros.
- [ ] Los modales son navegables con teclado.

---

## 36. Definición resumida del ADN

> Una presentación ejecutiva web de estética tecnológica y corporativa, construida sobre azul noche, azul hielo y turquesa; con heroes narrativos, KPIs grandes, cards elevadas, gráficos limpios, capas progresivas de detalle y animaciones suaves que guían la revisión sin distraer de la información.

### Fórmula visual

```text
Portada inmersiva
+ navegación por capítulos
+ conclusión ejecutiva
+ KPI dominante
+ evidencia gráfica
+ detalle bajo demanda
+ motion sutil
= ADN Directorio Frioteam
```

---

## 37. Nota de fidelidad técnica

Este documento se elaboró mediante la revisión del deployment público renderizado, su estructura de contenido y sus activos visuales accesibles. Los colores principales de marca se extrajeron de los logos públicos del proyecto.

Los valores dimensionales, sombras, curvas, duraciones y configuraciones técnicas constituyen una **reconstrucción normalizada y reutilizable del comportamiento visual observado**. No representan necesariamente una copia literal, línea por línea, del CSS o JavaScript original, ya que el código fuente del deployment no fue proporcionado como archivo editable.

Para una reproducción exacta a nivel de píxel y código, se debe contrastar este manual con el HTML/CSS/JS original del proyecto.
