#!/usr/bin/env bash
# check_supabase_config.sh — Verifica si el proyecto ya tiene configurada la conexión a Supabase.
# Uso: bash check_supabase_config.sh [directorio_del_proyecto]
#
# Busca:
#   - URL del proyecto  (SUPABASE_URL con cualquier prefijo: VITE_, NEXT_PUBLIC_, NUXT_PUBLIC_, ...)
#   - Clave pública     (SUPABASE_ANON_KEY o SUPABASE_PUBLISHABLE_KEY con cualquier prefijo)
#   en archivos .env*, environment.ts (Angular), config.toml de Supabase y valores escritos en el código.
#
# Nunca imprime claves completas.
# Al final imprime líneas STATUS_* que Claude usa para decidir qué pedirle al desarrollador:
#   STATUS_URL=ok|missing|hardcoded|invalid
#   STATUS_KEY=ok|missing|hardcoded|invalid|service_role
#   ENV_FILE=<archivo donde está o donde debería ir>
#   URL_VAR=<nombre de variable encontrado>   KEY_VAR=<nombre de variable encontrado>

set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT" || { echo "No existe el directorio $ROOT"; exit 2; }

EXCL=(--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=dist --exclude-dir=build
      --exclude-dir=.next --exclude-dir=.nuxt --exclude-dir=.output --exclude-dir=.svelte-kit
      --exclude-dir=supabase-secure-auth --exclude-dir=Login_auth_GFP --exclude=*.lock --exclude=package-lock.json)

# --include debe ir ANTES que --exclude (si no, grep incluye todo lo que no coincide)
INCL=(--include=*.js --include=*.jsx --include=*.ts --include=*.tsx --include=*.vue
      --include=*.svelte --include=*.html --include=*.mjs --include=*.cjs)

STATUS_URL=missing; STATUS_KEY=missing; ENV_FILE=""; URL_VAR=""; KEY_VAR=""

mask() { local v="$1"; [ ${#v} -le 12 ] && echo "****" || echo "${v:0:12}…(${#v} caracteres)"; }

jwt_role() {
  python3 - "$1" 2>/dev/null <<'PY' || echo "desconocido"
import sys, base64, json
p = sys.argv[1].split('.')[1]; p += '=' * (-len(p) % 4)
print(json.loads(base64.urlsafe_b64decode(p)).get('role', 'desconocido'))
PY
}

classify_key() { # devuelve ok | service_role | invalid
  local v="$1"
  case "$v" in
    sb_publishable_*) echo ok ;;
    sb_secret_*)      echo service_role ;;
    eyJ*.*.*)
      case "$(jwt_role "$v")" in
        anon) echo ok ;; service_role) echo service_role ;; *) echo invalid ;;
      esac ;;
    *) echo invalid ;;
  esac
}

valid_url() { [[ "$1" =~ ^https://[a-z0-9]{20}\.supabase\.co/?$ ]] || [[ "$1" =~ ^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?/?$ ]] || [[ "$1" =~ ^https://[A-Za-z0-9.-]+/?$ ]]; }

strip() { local v="$1"; v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"; echo "$v" | tr -d '\r' | sed 's/[[:space:]]*$//'; }

echo "== Configuración de Supabase en: $(pwd)"
echo

# 1. Archivos de entorno (orden de prioridad)
ENV_FILES=$(ls -1a .env.local .env.development.local .env.development .env .env.production 2>/dev/null)
for f in $ENV_FILES; do
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    name="${line%%=*}"; name="$(echo "$name" | sed 's/^export[[:space:]]*//; s/[[:space:]]//g')"
    val="$(strip "${line#*=}")"
    [ -z "$val" ] && continue
    if [[ "$name" =~ SUPABASE_URL$ ]] && [ "$STATUS_URL" = missing ]; then
      URL_VAR="$name"; ENV_FILE="$f"
      if valid_url "$val"; then STATUS_URL=ok; else STATUS_URL=invalid; fi
      echo "URL      : $name en $f -> $val  [$STATUS_URL]"
    fi
    if [[ "$name" =~ SUPABASE_(ANON|PUBLISHABLE)(_DEFAULT)?_KEY$ ]] && [ "$STATUS_KEY" = missing ]; then
      KEY_VAR="$name"; [ -z "$ENV_FILE" ] && ENV_FILE="$f"
      STATUS_KEY=$(classify_key "$val")
      echo "Clave    : $name en $f -> $(mask "$val")  [$STATUS_KEY]"
    fi
    if [[ "$name" =~ SERVICE_ROLE ]] && [[ "$name" =~ ^(VITE_|NEXT_PUBLIC_|NUXT_PUBLIC_|PUBLIC_|REACT_APP_|EXPO_PUBLIC_|NG_APP_) ]]; then
      echo "[CRÍTICO] $name en $f es una variable PÚBLICA con la service role (llega al navegador)."
    fi
  done < "$f"
done

# 2. Angular: src/environments/environment*.ts
if [ "$STATUS_URL" = missing ] || [ "$STATUS_KEY" = missing ]; then
  for f in $(ls src/environments/environment*.ts 2>/dev/null); do
    u=$(grep -oE "https://[a-z0-9]{20}\.supabase\.co" "$f" | head -1)
    k=$(grep -oE "(eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|sb_publishable_[A-Za-z0-9_-]+)" "$f" | head -1)
    if [ -n "$u" ] && [ "$STATUS_URL" = missing ]; then STATUS_URL=ok; ENV_FILE="$f"; URL_VAR="environment.supabaseUrl"; echo "URL      : en $f -> $u  [ok]"; fi
    if [ -n "$k" ] && [ "$STATUS_KEY" = missing ]; then STATUS_KEY=$(classify_key "$k"); KEY_VAR="environment.supabaseKey"; echo "Clave    : en $f -> $(mask "$k")  [$STATUS_KEY]"; fi
  done
fi

# 3. Valores escritos directamente en el código (deben moverse a variables de entorno)
CODE_URL=$(grep -RIlE "https://[a-z0-9]{20}\.supabase\.co" . "${INCL[@]}" "${EXCL[@]}" 2>/dev/null | grep -v "src/environments/" | head -5)
CODE_KEY=$(grep -RIoE "(eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|sb_(publishable|secret)_[A-Za-z0-9_-]{10,})" . "${INCL[@]}" "${EXCL[@]}" 2>/dev/null | grep -v "src/environments/" | head -5)
if [ -n "$CODE_URL" ]; then
  echo "[MOVER]  URL de Supabase escrita en el código:"; echo "$CODE_URL" | sed 's/^/    /'
  [ "$STATUS_URL" = missing ] && STATUS_URL=hardcoded
fi
if [ -n "$CODE_KEY" ]; then
  while IFS= read -r hit; do
    file="${hit%%:*}"; tok="${hit#*:}"; cls=$(classify_key "$tok")
    if [ "$cls" = service_role ]; then
      echo "[CRÍTICO] Service role escrita en el código: $file (rotarla en Supabase)"
      STATUS_KEY=service_role
    else
      echo "[MOVER]  Clave pública escrita en el código: $file -> $(mask "$tok")"
      [ "$STATUS_KEY" = missing ] && STATUS_KEY=hardcoded
    fi
  done <<< "$CODE_KEY"
fi

# 4. Proyecto vinculado con la CLI (informativo)
REF=""
[ -f supabase/.temp/project-ref ] && REF=$(cat supabase/.temp/project-ref)
[ -z "$REF" ] && [ -f supabase/config.toml ] && REF=$(grep -E '^project_id' supabase/config.toml | sed -E 's/.*"(.*)".*/\1/')
[ -n "$REF" ] && echo "CLI      : supabase/ presente (project ref / id: $REF)"
[ -d supabase/migrations ] && echo "CLI      : supabase/migrations existe ($(ls supabase/migrations | wc -l | tr -d ' ') archivo(s))"

# 5. Dónde debería ir si falta
if [ -z "$ENV_FILE" ]; then
  if [ -f angular.json ]; then ENV_FILE="src/environments/environment.ts"
  elif ls next.config.* >/dev/null 2>&1 || ls nuxt.config.* >/dev/null 2>&1 || ls vite.config.* >/dev/null 2>&1 || ls svelte.config.* >/dev/null 2>&1; then ENV_FILE=".env.local"
  else ENV_FILE=".env"; fi
fi

echo
echo "STATUS_URL=$STATUS_URL"
echo "STATUS_KEY=$STATUS_KEY"
echo "ENV_FILE=$ENV_FILE"
echo "URL_VAR=$URL_VAR"
echo "KEY_VAR=$KEY_VAR"

[ "$STATUS_KEY" = service_role ] && exit 1
exit 0
