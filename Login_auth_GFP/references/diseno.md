# Diseño visual — Grupo Frío Packing

Estilo: minimalista, moderno, corporativo, limpio. Referencia conceptual: SaaS modernos
(espaciado amplio, jerarquía clara, bordes sutiles, poca decoración). No copiar branding,
logotipos ni colores de terceros (ChatGPT/OpenAI u otros).

Tokens listos en `assets/theme/tokens.css`. Si el proyecto usa Tailwind, extender `theme.colors`
con `fp.navy`, `fp.blue`, `fp.cyan`, `fp.teal`, `fp.sky` en vez de importar el CSS completo.

## Paleta (exclusiva)

| Token | Hex | Uso |
|---|---|---|
| Azul marino | `#102267` | Títulos, texto principal, encabezados |
| Azul eléctrico | `#007BDF` | Botón principal, links, acciones, iconos destacados |
| Cian | `#00CFE8` | Bordes, líneas, anillo de foco, detalles |
| Turquesa Friopacking | `#39C1AD` | Marca, indicadores, estado "Activo", ítem activo del sidebar |
| Celeste muy claro | `#EAF9FF` | Fondos suaves, hover, avisos informativos, fondo del login |
| Blanco | `#FFFFFF` | Fondos principales, tarjetas, texto sobre azul |
| Negro | `#000000` | Texto secundario (con opacidad ~56 %) |

Accesibilidad: cian y turquesa tienen poco contraste sobre blanco; no usarlos como color de texto
pequeño. El rojo de error (`#C62828`) es la única excepción técnica a la paleta.

## Tipografía

- Títulos: **Inter Bold** (700). Google Fonts o `@fontsource/inter`.
- Textos: **Noway**. Es comercial: si el proyecto tiene los archivos con licencia, cargarlos con
  `@font-face` desde `/public/fonts/`. Si no, usar el fallback (`Inter` regular / `system-ui`)
  y avisar al desarrollador. No descargar Noway de sitios no oficiales.

## Iconos

Una sola familia. La del proyecto si existe; si no, **Lucide** (`lucide-react`, `lucide-vue-next`,
`lucide-angular`, `lucide-svelte` o `lucide` para JS plano). Tamaño 16–18 px, trazo 1.75–2.

| Uso | Icono Lucide |
|---|---|
| Dashboard | `LayoutDashboard` |
| Usuarios | `Users` |
| Roles | `ShieldCheck` |
| Configuración | `Settings` |
| Perfil | `UserRound` |
| Cerrar sesión | `LogOut` |
| Buscar | `Search` |
| Nuevo | `Plus` |
| Acciones | `MoreHorizontal` |
| Editar | `Pencil` |
| Desactivar / activar | `UserX` / `UserCheck` |
| Mostrar / ocultar contraseña | `Eye` / `EyeOff` |
| Permiso sí / no | `Check` / `X` |
| Menú móvil | `Menu` |

Prohibido: emojis como iconos (👤 ⚙ 📦 🔍 ✏️ 🗑️ ✅) y caracteres ✓ ✕ como iconografía.

## Login

```
┌──────────────── fondo #EAF9FF ────────────────┐
│                                               │
│        ┌───────── tarjeta blanca ─────────┐   │
│        │  [logo Grupo Frío Packing]       │   │
│        │  Iniciar sesión          (Inter) │   │
│        │  Ingresa con tu cuenta corporativa│  │
│        │                                  │   │
│        │  Correo electrónico              │   │
│        │  [______________________]        │   │
│        │  Contraseña                      │   │
│        │  [__________________] [Eye]      │   │
│        │            ¿Olvidaste tu contraseña?│ │
│        │  [      Iniciar sesión      ]    │   │
│        │  ¿No tienes cuenta? Regístrate   │   │
│        └──────────────────────────────────┘   │
└───────────────────────────────────────────────┘
```

- Logo: usar el del proyecto (buscar en `public/`, `assets/`). Si no hay, el texto "Grupo Frío Packing"
  en Inter Bold azul marino con un detalle turquesa. No inventar un logo.
- Botón con spinner y texto "Ingresando..." en carga; inputs deshabilitados mientras tanto.
- Error en `fp-alert-error` encima del botón. `aria-live="polite"`.
- Sin ilustraciones, gradientes llamativos ni animaciones innecesarias. Responsive desde 320 px.
- `autocomplete="email"` y `autocomplete="current-password"` (en registro: `new-password`).

## Layout administrativo

```
┌ Sidebar 248px ┬ Header 60px: [Menu móvil]                 [UserMenu: nombre · rol ▾] ┐
│ [logo]        ├──────────────────────────────────────────────────────────────────────┤
│ Dashboard     │ Usuarios                                          [+ Nuevo usuario]   │
│ Usuarios      │ Gestiona los usuarios y sus permisos.                                 │
│ Roles         │ [Search Buscar usuarios...]  [Rol ▾]  [Estado ▾]                      │
│ Configuración │ ┌────────────────────────────────────────────────────────────────┐   │
│               │ │ NOMBRE      CORREO              ROL          ESTADO   CREADO  ⋯ │   │
│               │ │ Juan Pérez  juan@empresa.com    Admin        ● Activo 02/10/26 ⋯ │   │
│               │ └────────────────────────────────────────────────────────────────┘   │
│ [LogOut] Salir│                                                                       │
└───────────────┴───────────────────────────────────────────────────────────────────────┘
```

- Sidebar muestra solo lo permitido al rol (Admin: Dashboard, Usuarios, Roles, Configuración;
  Editor y Visualizador: Dashboard y sus módulos). En < 900 px se vuelve drawer.
- UserMenu: nombre, rol, enlace a Perfil, Cerrar sesión.
- Rol como badge `fp-badge-role`; estado con punto turquesa (Activo) o gris (Inactivo).
- Fechas en formato local `es-PE` (dd/mm/aaaa).
- En móvil la tabla hace scroll horizontal dentro de su contenedor; nunca la página completa.

## Estados obligatorios

- **Cargando**: skeleton de filas en tablas; spinner en botones.
- **Vacío**: "No hay usuarios que coincidan con la búsqueda." + botón para limpiar filtros.
- **Error**: mensaje breve + botón "Reintentar".
- **Sin permiso**: icono `ShieldCheck`, "No tienes permiso para ver esta sección." + volver al Dashboard.
- **Confirmación**: `ConfirmDialog` para desactivar usuarios y cambiar a/desde Admin.
