#!/usr/bin/env bash
#
# install-claude-skills.sh
#
# Instala Agent Skills de Claude (carpetas con SKILL.md) en Claude Code,
# a nivel de usuario (~/.claude/skills) o de proyecto (./.claude/skills).
#
# Origen por defecto: repositorio público https://github.com/anthropics/skills
# (subcarpeta "skills"). Acepta también cualquier repositorio Git HTTPS/SSH
# o un directorio local.
#
# Uso rápido:
#   ./install-claude-skills.sh --list
#   ./install-claude-skills.sh pdf docx xlsx pptx
#   ./install-claude-skills.sh --all --scope project
#   ./install-claude-skills.sh --source ./mis-skills --path . --all --force
#
# Requisitos: bash >= 4, git (solo para orígenes remotos), coreutils.

set -Eeuo pipefail
shopt -s nullglob

readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_VERSION="1.0.0"

readonly DEFAULT_SOURCE="https://github.com/anthropics/skills.git"
readonly DEFAULT_SOURCE_PATH="skills"
readonly DEFAULT_SCOPE="user"

# Restricciones oficiales del campo "name" de SKILL.md:
# minúsculas, dígitos y guiones; máximo 64 caracteres.
readonly SKILL_NAME_REGEX='^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$'
readonly GIT_REF_REGEX='^[A-Za-z0-9._][A-Za-z0-9._/-]{0,199}$'

# ---------------------------------------------------------------------------
# Estado global (se llena en parse_args / prepare_source)
# ---------------------------------------------------------------------------
source_location="$DEFAULT_SOURCE"
source_path="$DEFAULT_SOURCE_PATH"
git_ref=""
scope="$DEFAULT_SCOPE"
target_dir=""
install_all=false
list_only=false
force=false
dry_run=false
quiet=false
requested_skills=()

work_dir=""
skills_root=""
declare -A available_skills=()

# ---------------------------------------------------------------------------
# Utilidades de salida
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  readonly C_RED=$'\033[31m' C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m'
  readonly C_BLUE=$'\033[34m' C_RESET=$'\033[0m'
else
  readonly C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_RESET=""
fi

log_info()  { [[ "$quiet" == true ]] || printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_ok()    { [[ "$quiet" == true ]] || printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn()  { printf '%s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_error() { printf '%s[ERROR]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }

die() {
  log_error "$1"
  exit "${2:-1}"
}

usage() {
  cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION
Instala Agent Skills de Claude en Claude Code.

USO
  $SCRIPT_NAME [opciones] [skill ...]

OPCIONES
  -s, --source <git-url|dir>   Origen de las skills.
                               Por defecto: $DEFAULT_SOURCE
  -p, --path <subdir>          Subcarpeta del origen que contiene las skills.
                               Por defecto: "$DEFAULT_SOURCE_PATH" (usa "." para la raíz).
  -r, --ref <rama|tag|commit>  Revisión Git a usar (solo orígenes Git).
  -S, --scope <user|project>   user    -> \$HOME/.claude/skills (por defecto)
                               project -> ./.claude/skills
  -t, --target <dir>           Directorio destino explícito (ignora --scope).
  -a, --all                    Instala todas las skills disponibles.
  -l, --list                   Lista las skills disponibles y sale.
  -f, --force                  Reemplaza skills ya instaladas (con respaldo).
  -n, --dry-run                Muestra lo que haría sin modificar nada.
  -q, --quiet                  Solo muestra advertencias y errores.
  -h, --help                   Muestra esta ayuda.
  -V, --version                Muestra la versión.

EJEMPLOS
  $SCRIPT_NAME --list
  $SCRIPT_NAME pdf docx xlsx pptx
  $SCRIPT_NAME --all --scope project
  $SCRIPT_NAME --source git@github.com:org/skills.git --ref v1.2.0 --all
  $SCRIPT_NAME --source ./skills-locales --path . mi-skill --force

CÓDIGOS DE SALIDA
  0 éxito | 1 error general | 2 uso incorrecto | 3 dependencia faltante
  4 skill no encontrada o inválida
EOF
}

# ---------------------------------------------------------------------------
# Limpieza
# ---------------------------------------------------------------------------
cleanup() {
  if [[ -n "$work_dir" && -d "$work_dir" ]]; then
    rm -rf -- "$work_dir"
  fi
}
trap cleanup EXIT
trap 'die "Interrumpido por el usuario." 130' INT TERM

# ---------------------------------------------------------------------------
# Validaciones
# ---------------------------------------------------------------------------
require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Dependencia faltante: '$1'." 3
}

require_value() {
  local option="$1" value="${2-}"
  [[ -n "$value" && "$value" != -* ]] || die "La opción $option requiere un valor." 2
}

is_valid_skill_name() {
  [[ "$1" =~ $SKILL_NAME_REGEX ]]
}

is_remote_source() {
  [[ "$1" =~ ^(https://|ssh://|git@) ]]
}

validate_source_path() {
  local path="$1"
  # Evita salir del origen mediante rutas absolutas o "..".
  [[ "$path" != /* ]] || die "--path debe ser relativo al origen." 2
  [[ "/$path/" != */../* ]] || die "--path no puede contener '..'." 2
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
parse_args() {
  while (($# > 0)); do
    case "$1" in
      -s|--source)  require_value "$1" "${2-}"; source_location="$2"; shift 2 ;;
      -p|--path)    require_value "$1" "${2-}"; source_path="$2"; shift 2 ;;
      -r|--ref)     require_value "$1" "${2-}"; git_ref="$2"; shift 2 ;;
      -S|--scope)   require_value "$1" "${2-}"; scope="$2"; shift 2 ;;
      -t|--target)  require_value "$1" "${2-}"; target_dir="$2"; shift 2 ;;
      -a|--all)     install_all=true; shift ;;
      -l|--list)    list_only=true; shift ;;
      -f|--force)   force=true; shift ;;
      -n|--dry-run) dry_run=true; shift ;;
      -q|--quiet)   quiet=true; shift ;;
      -h|--help)    usage; exit 0 ;;
      -V|--version) printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      --)           shift; requested_skills+=("$@"); break ;;
      -*)           die "Opción desconocida: $1 (usa --help)." 2 ;;
      *)            requested_skills+=("$1"); shift ;;
    esac
  done

  validate_args
}

validate_args() {
  validate_source_path "$source_path"

  if [[ -n "$git_ref" && ! "$git_ref" =~ $GIT_REF_REGEX ]]; then
    die "Valor de --ref inválido: '$git_ref'." 2
  fi

  if [[ -z "$target_dir" ]]; then
    case "$scope" in
      user)    [[ -n "${HOME:-}" ]] || die "\$HOME no está definido." 2
               target_dir="$HOME/.claude/skills" ;;
      project) target_dir="$PWD/.claude/skills" ;;
      *)       die "--scope debe ser 'user' o 'project'." 2 ;;
    esac
  fi

  local skill
  for skill in "${requested_skills[@]}"; do
    is_valid_skill_name "$skill" || die "Nombre de skill inválido: '$skill'." 2
  done

  if [[ "$list_only" == false && "$install_all" == false && ${#requested_skills[@]} -eq 0 ]]; then
    die "Indica las skills a instalar, o usa --all / --list (ver --help)." 2
  fi
  if [[ "$install_all" == true && ${#requested_skills[@]} -gt 0 ]]; then
    die "--all no se combina con nombres de skills." 2
  fi
}

# ---------------------------------------------------------------------------
# Origen
# ---------------------------------------------------------------------------
# Clona el origen remoto en "$work_dir/source" (sin imprimir en stdout).
clone_remote_source() {
  require_command git
  local clone_dir="$1"

  log_info "Descargando $source_location${git_ref:+ (ref: $git_ref)}..."

  # protocol.file.allow=never impide que submódulos apunten a rutas locales.
  if [[ -z "$git_ref" ]]; then
    git -c protocol.file.allow=never clone --quiet --depth 1 -- \
      "$source_location" "$clone_dir" || die "No se pudo clonar el origen."
  else
    git -c protocol.file.allow=never clone --quiet --no-checkout -- \
      "$source_location" "$clone_dir" || die "No se pudo clonar el origen."
    git -C "$clone_dir" -c advice.detachedHead=false checkout --quiet "$git_ref" \
      || die "No existe la referencia '$git_ref' en el origen."
  fi
}

prepare_source() {
  work_dir="$(mktemp -d "${TMPDIR:-/tmp}/claude-skills.XXXXXXXX")"
  chmod 700 "$work_dir"

  local base_dir
  if is_remote_source "$source_location"; then
    base_dir="$work_dir/source"
    clone_remote_source "$base_dir"
  else
    [[ -z "$git_ref" ]] || log_warn "--ref se ignora en orígenes locales."
    [[ -d "$source_location" ]] || die "El origen local no existe: $source_location"
    base_dir="$(cd -- "$source_location" && pwd -P)"
  fi

  skills_root="$base_dir/$source_path"
  [[ -d "$skills_root" ]] || die "No existe la subcarpeta '$source_path' en el origen."
  skills_root="$(cd -- "$skills_root" && pwd -P)"
}

# Extrae el valor de un campo del frontmatter YAML (entre las dos primeras '---').
read_frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR == 1 { if ($0 !~ /^---[[:space:]]*$/) exit; next }
    /^---[[:space:]]*$/ { exit }
    index($0, field ":") == 1 {
      value = substr($0, length(field) + 2)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      gsub(/^["'\'']|["'\'']$/, "", value)
      print value
      exit
    }
  ' "$file"
}

# Valida una carpeta de skill; imprime el motivo si es inválida.
skill_validation_error() {
  local dir="$1" expected_name="$2" manifest="$1/SKILL.md"

  [[ -f "$manifest" && ! -L "$manifest" ]] || { echo "falta SKILL.md"; return; }

  local declared_name description
  declared_name="$(read_frontmatter_field "$manifest" name)"
  description="$(read_frontmatter_field "$manifest" description)"

  [[ -n "$declared_name" ]] || { echo "frontmatter sin 'name'"; return; }
  [[ -n "$description" ]]   || { echo "frontmatter sin 'description'"; return; }
  [[ "$declared_name" == "$expected_name" ]] \
    || { echo "'name: $declared_name' no coincide con la carpeta"; return; }

  # Los enlaces simbólicos podrían apuntar fuera de la skill (p. ej. ~/.ssh).
  if [[ -n "$(find "$dir" -type l -print -quit)" ]]; then
    echo "contiene enlaces simbólicos (no permitidos)"
    return
  fi
}

discover_skills() {
  local dir name reason
  for dir in "$skills_root"/*/; do
    dir="${dir%/}"
    name="${dir##*/}"
    [[ -f "$dir/SKILL.md" ]] || continue

    if ! is_valid_skill_name "$name"; then
      log_warn "Se omite '$name': nombre de carpeta inválido."
      continue
    fi
    reason="$(skill_validation_error "$dir" "$name")"
    if [[ -n "$reason" ]]; then
      log_warn "Se omite '$name': $reason."
      continue
    fi
    available_skills["$name"]="$dir"
  done

  ((${#available_skills[@]} > 0)) || die "No se encontraron skills válidas en '$source_path'." 4
}

sorted_skill_names() {
  printf '%s\n' "${!available_skills[@]}" | LC_ALL=C sort
}

# ---------------------------------------------------------------------------
# Acciones
# ---------------------------------------------------------------------------
list_skills() {
  local name description
  printf 'Skills disponibles en %s (%s):\n\n' "$source_location" "$source_path"
  while IFS= read -r name; do
    description="$(read_frontmatter_field "${available_skills[$name]}/SKILL.md" description)"
    ((${#description} <= 100)) || description="${description:0:97}..."
    printf '  %-24s %s\n' "$name" "$description"
  done < <(sorted_skill_names)
  printf '\nTotal: %d\n' "${#available_skills[@]}"
}

resolve_selection() {
  if [[ "$install_all" == true ]]; then
    mapfile -t requested_skills < <(sorted_skill_names)
    return
  fi

  local skill missing=()
  for skill in "${requested_skills[@]}"; do
    [[ -n "${available_skills[$skill]+x}" ]] || missing+=("$skill")
  done
  if ((${#missing[@]} > 0)); then
    die "Skills no encontradas o inválidas: ${missing[*]} (usa --list)." 4
  fi
}

# Copia atómica: se copia a un directorio temporal dentro del destino
# y luego se renombra, para no dejar instalaciones a medias.
install_skill() {
  local name="$1" source_dir="${available_skills[$1]}"
  local destination="$target_dir/$name"

  if [[ -e "$destination" && "$force" == false ]]; then
    log_warn "'$name' ya está instalada; se omite (usa --force para reemplazar)."
    return 1
  fi

  if [[ "$dry_run" == true ]]; then
    log_info "[dry-run] Instalaría '$name' en $destination"
    return 0
  fi

  local staging="$target_dir/.${name}.tmp.$$"
  rm -rf -- "$staging"
  # Dentro de un "if" bash desactiva set -e: cada paso se valida explícitamente.
  cp -R -- "$source_dir" "$staging" || die "Falló la copia de '$name'."
  rm -rf -- "$staging/.git"
  chmod -R u+rwX,go-w -- "$staging" || die "No se pudieron ajustar permisos de '$name'."

  if [[ -e "$destination" ]]; then
    local backup
    backup="$target_dir/.${name}.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$destination" "$backup" || die "No se pudo respaldar '$name'."
    log_info "Respaldo de la versión anterior: $backup"
  fi

  mv -- "$staging" "$destination" || die "No se pudo instalar '$name'."
  log_ok "Instalada '$name' -> $destination"
}

install_selected() {
  if [[ "$dry_run" == false ]]; then
    mkdir -p -- "$target_dir"
    [[ -w "$target_dir" ]] || die "Sin permiso de escritura en $target_dir"
  fi

  log_info "Destino: $target_dir"

  local skill installed=0 skipped=0
  for skill in "${requested_skills[@]}"; do
    if install_skill "$skill"; then
      installed=$((installed + 1))
    else
      skipped=$((skipped + 1))
    fi
  done

  local verb="instalada(s)"
  [[ "$dry_run" == false ]] || verb="por instalar (dry-run)"
  printf '\nResumen: %d %s, %d omitida(s).\n' "$installed" "$verb" "$skipped"
  if ((installed > 0)) && [[ "$dry_run" == false ]]; then
    printf 'Reinicia Claude Code para que detecte las nuevas skills.\n'
  fi
}

# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------
main() {
  ((BASH_VERSINFO[0] >= 4)) || die "Se requiere bash >= 4 (actual: $BASH_VERSION)." 3
  umask 022

  parse_args "$@"
  prepare_source
  discover_skills

  if [[ "$list_only" == true ]]; then
    list_skills
    return 0
  fi

  resolve_selection
  install_selected
}

main "$@"
