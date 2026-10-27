#!/usr/bin/env bash
# scan_secrets.sh — Detecta credenciales expuestas en un proyecto web con Supabase.
# Uso: bash scan_secrets.sh [directorio_del_proyecto]
# Salida: 0 = sin hallazgos críticos, 1 = hay hallazgos críticos que corregir.
# No imprime valores completos de secretos (solo un prefijo enmascarado).

set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT" || { echo "No existe el directorio $ROOT"; exit 2; }

EXCLUDES=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.next/cache
          --exclude-dir=.turbo --exclude-dir=.svelte-kit --exclude-dir=coverage
          --exclude-dir=supabase-secure-auth --exclude-dir=Login_auth_GFP --exclude=*.lock --exclude=package-lock.json
          --exclude=pnpm-lock.yaml --exclude=yarn.lock --exclude=scan_secrets.sh)

CRIT=0
WARN=0
crit() { echo "[CRÍTICO] $*"; CRIT=$((CRIT+1)); }
warn() { echo "[REVISAR] $*"; WARN=$((WARN+1)); }
mask() { sed -E -e 's/((eyJ|sb_secret_|sb_publishable_)[A-Za-z0-9_-]{0,6})[A-Za-z0-9._-]+/\1…/g' \
                -e 's/(=[[:space:]]*["'"'"']?)[^"'"'"'[:space:]]{4,}/\1****/g' \
                -e 's/(:[[:space:]]*["'"'"'])[^"'"'"']{3,}/\1****/g'; }

echo "== Escaneo de secretos en: $(pwd)"
echo

# 1. Service role expuesta en variables públicas del frontend
PUBLIC_SR=$(grep -RInE "(VITE_|NEXT_PUBLIC_|NUXT_PUBLIC_|PUBLIC_|REACT_APP_|EXPO_PUBLIC_|NG_APP_)[A-Z_]*SERVICE_ROLE" . "${EXCLUDES[@]}" 2>/dev/null)
if [ -n "$PUBLIC_SR" ]; then
  crit "Service role key en variable PÚBLICA (llega al navegador):"
  echo "$PUBLIC_SR" | mask | sed 's/^/    /'
fi

# 2. Claves secretas con formato nuevo de Supabase
SB_SECRET=$(grep -RInE "sb_secret_[A-Za-z0-9_-]{10,}" . "${EXCLUDES[@]}" --exclude=.env --exclude=.env.local --exclude='.env.*.local' 2>/dev/null)
if [ -n "$SB_SECRET" ]; then
  crit "Clave secreta de Supabase (sb_secret_) en código:"
  echo "$SB_SECRET" | mask | sed 's/^/    /'
fi

# 3. JWT hardcodeados: decodificar y ver si son service_role
if command -v python3 >/dev/null 2>&1; then
  JWT_HITS=$(grep -RIonE "eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}" . "${EXCLUDES[@]}" \
             --exclude=.env --exclude=.env.local --exclude='.env.*.local' 2>/dev/null)
  if [ -n "$JWT_HITS" ]; then
    while IFS= read -r line; do
      file_line="${line%:*}"; token="${line##*:}"
      role=$(python3 - "$token" <<'PY'
import sys, base64, json
try:
    p = sys.argv[1].split('.')[1]; p += '=' * (-len(p) % 4)
    print(json.loads(base64.urlsafe_b64decode(p)).get('role', 'desconocido'))
except Exception:
    print('no-decodificable')
PY
)
      case "$role" in
        service_role) crit "JWT con role=service_role hardcodeado en $file_line" ;;
        anon)         warn "Anon key hardcodeada en $file_line (no es secreta, pero debe ir en variable de entorno)" ;;
        *)            warn "Token JWT hardcodeado ($role) en $file_line" ;;
      esac
    done <<< "$JWT_HITS"
  fi
fi

# 4. Patrones de la sección 29
PATTERNS='service_role|SUPABASE_SERVICE_ROLE_KEY|JWT_SECRET|password[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']+|password[[:space:]]*:[[:space:]]*["'"'"'][^"'"'"']{3,}|secret[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']+|access_token[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']+|refresh_token[[:space:]]*=[[:space:]]*["'"'"'][^"'"'"']+'
HITS=$(grep -RInE "$PATTERNS" . "${EXCLUDES[@]}" --exclude=.env --exclude=.env.local --exclude='.env.*.local' \
       --exclude=.env.example --exclude='*.md' --exclude='*.sql' 2>/dev/null)
if [ -n "$HITS" ]; then
  # En código de servidor (supabase/functions, api/, server/) leer la variable es correcto
  echo "$HITS" | while IFS= read -r h; do
    f="${h%%:*}"
    if echo "$h" | grep -qE "Deno\.env\.get|process\.env\.SUPABASE_SERVICE_ROLE_KEY" && \
       echo "$f" | grep -qE "(supabase/functions|/api/|/server/|server\.|\.server\.|route\.(t|j)s)"; then
      continue
    fi
    echo "[REVISAR] $(echo "$h" | mask)"
  done
fi
[ -n "$HITS" ] && WARN=$((WARN+1))

# 5. Uso de service role en archivos de frontend
FRONT_SR=$(grep -RIlE "SERVICE_ROLE" src app pages components lib public 2>/dev/null \
           | grep -vE "(/api/|/server/|\.server\.|route\.(t|j)s$|middleware)")
if [ -n "$FRONT_SR" ]; then
  crit "Referencias a SERVICE_ROLE en archivos que pueden llegar al navegador:"
  echo "$FRONT_SR" | sed 's/^/    /'
fi

# 6. .env en git y .gitignore
if [ -d .git ] && command -v git >/dev/null 2>&1; then
  TRACKED=$(git ls-files | grep -E "(^|/)\.env($|\.local$|\..+\.local$|\.production$)" || true)
  if [ -n "$TRACKED" ]; then
    crit "Archivos .env versionados en git (rotar claves y sacarlos del repo con git rm --cached):"
    echo "$TRACKED" | sed 's/^/    /'
  fi
fi
for p in ".env" ".env.local" ".env.*.local"; do
  if [ ! -f .gitignore ] || ! grep -qxF "$p" .gitignore; then
    warn ".gitignore no contiene la línea: $p"
  fi
done

echo
echo "== Resultado: $CRIT crítico(s), $WARN aviso(s) a revisar"
if [ "$CRIT" -gt 0 ]; then
  echo "Acción: detener la implementación, mover las claves a variables de entorno de servidor"
  echo "y ROTAR en Supabase (Project Settings -> API) toda clave que haya podido quedar expuesta."
  exit 1
fi
exit 0
