#!/usr/bin/env bash
set -euo pipefail

main() {
script_dir=''
if [[ -n ${BASH_SOURCE[0]:-} ]]; then
    script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fi
project_dir=${PROJECT_DIR:-"$HOME/prefeitura_rio/pipelines_v3"}
skip_install=false
skip_auth=false
shell_only=false

usage() {
    cat <<'HELP'
Uso: bash scripts/onboarding/setup-ubuntu.sh [opções]
  --project-dir DIRETORIO  Checkout pipelines_v3 (padrão: ~/prefeitura_rio/pipelines_v3)
  --skip-install          Usar ferramentas já instaladas; sem apt/instaladores
  --skip-auth             Não executar login GitHub/Google
  --shell-only            Instalar somente o bloco gerenciado do Bash
  --help                  Mostrar esta ajuda

Configuração opcional: GCP_ACCOUNT, GCP_PROJECT_ID, QUOTA_PROJECT_ID, DBT_USER.
Valores ausentes necessários são solicitados. Não execute o script inteiro com sudo.
HELP
}
while (($#)); do
    case "$1" in
        --project-dir) [[ $# -ge 2 && -n $2 ]] || { usage >&2; exit 2; }; project_dir=$2; shift 2 ;;
        --skip-install) skip_install=true; shift ;;
        --skip-auth) skip_auth=true; shift ;;
        --shell-only) shell_only=true; shift ;;
        --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
[[ $EUID -ne 0 ]] || { echo 'Execute como usuário comum; sudo será usado apenas para apt.' >&2; exit 1; }
[[ -f /etc/os-release ]] || { echo 'Ubuntu necessário.' >&2; exit 1; }
# shellcheck disable=SC1091
source /etc/os-release
[[ $ID == ubuntu ]] || { echo 'Este instalador suporta Ubuntu.' >&2; exit 1; }
case "$VERSION_ID" in
    24.04|26.04) ;;
    *) echo 'Use Ubuntu 24.04 ou 26.04 LTS; este instalador não migra a distribuição.' >&2; exit 1 ;;
esac

require() { command -v "$1" >/dev/null 2>&1 || { echo "Ferramenta ausente: $1" >&2; exit 1; }; }
ask() {
    local variable=$1 label=$2 value
    if [[ -z ${!variable:-} ]]; then
        read -r -p "$label: " value || { echo "Informe $variable no ambiente." >&2; exit 1; }
        [[ -n $value ]] || { echo "$variable não pode ser vazio." >&2; exit 1; }
        printf -v "$variable" '%s' "$value"
    fi
}

setup_tmp=$(mktemp -d)
trap 'rm -rf -- "$setup_tmp"' EXIT

if ! $shell_only && ! $skip_install; then
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg git python3 build-essential
    sudo install -d -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$setup_tmp/github.gpg"
    sudo install -m 644 "$setup_tmp/github.gpg" /etc/apt/keyrings/githubcli-archive-keyring.gpg
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o "$setup_tmp/google.asc"
    gpg --batch --yes --dearmor -o "$setup_tmp/google.gpg" "$setup_tmp/google.asc"
    sudo install -m 644 "$setup_tmp/google.gpg" /etc/apt/keyrings/google-cloud.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main\n' | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y gh google-cloud-cli
    if ! command -v uv >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/uv" ]]; then
        curl -fsSL https://astral.sh/uv/install.sh -o "$setup_tmp/uv-install.sh"
        UV_NO_MODIFY_PATH=1 sh "$setup_tmp/uv-install.sh"
    fi
fi

# A standalone download has no sibling templates. Fetch them before changing
# user configuration.
helpers=(shell.bash)
for helper in "${helpers[@]}"; do
    if [[ ! -f "$script_dir/$helper" ]]; then
        require curl
        for remote in "${helpers[@]}"; do
            curl -fsSL "https://raw.githubusercontent.com/RJ-SMTR/pipelines-docs/main/scripts/onboarding/$remote" -o "$setup_tmp/$remote"
        done
        script_dir=$setup_tmp
        break
    fi
done
# Keep the shell template available after the temporary installer is removed.
installed_dir="$HOME/.local/share/smtr/onboarding"
mkdir -p -- "$installed_dir"
for helper in "${helpers[@]}"; do
    if [[ "$script_dir/$helper" != "$installed_dir/$helper" ]]; then
        install -m 644 "$script_dir/$helper" "$installed_dir/$helper"
    fi
done
script_dir=$installed_dir

# Back up and replace only our own block; keep all other user configuration.
require python3
python3 - "$script_dir/shell.bash" <<'PY'
from pathlib import Path
import shutil
import sys
import tempfile

home = Path.home()
config = home / '.config' / 'smtr'
config.mkdir(parents=True, exist_ok=True)
shutil.copyfile(sys.argv[1], config / 'onboarding-shell.bash')
bashrc = home / '.bashrc'
original = bashrc.read_text() if bashrc.exists() else ''
begin = '# >>> SMTR onboarding >>>'
end = '# <<< SMTR onboarding <<<'
block = f'{begin}\nsource "$HOME/.config/smtr/onboarding-shell.bash"\n{end}\n'
if begin in original or end in original:
    if original.count(begin) != 1 or original.count(end) != 1:
        sys.exit('Bloco SMTR inválido no .bashrc; revise antes de repetir.')
    start = original.index(begin)
    finish = original.index(end) + len(end)
    if finish < start:
        sys.exit('Marcadores SMTR fora de ordem; revise o .bashrc.')
    if original[finish:finish + 1] == '\n':
        finish += 1
    updated = original[:start] + block + original[finish:]
else:
    updated = original + ('\n' if original and not original.endswith('\n') else '') + block
if updated != original:
    if bashrc.exists():
        with tempfile.NamedTemporaryFile(prefix='.bashrc.smtr-backup-', dir=home, delete=False) as backup:
            backup_path = Path(backup.name)
        shutil.copy2(bashrc, backup_path)
        print(f'Backup: {backup_path}')
    bashrc.write_text(updated)
print('Bloco Bash instalado.')
PY
# shellcheck disable=SC1091 # Installed from local templates or the selected remote ref.
source "$script_dir/shell.bash"
if $shell_only; then
    echo 'Abra um novo terminal; nenhum projeto ou login foi alterado.'
    exit 0
fi
for tool in git gh gcloud uv; do require "$tool"; done
if ! git config --global --get user.name >/dev/null; then
    ask GIT_AUTHOR_NAME 'Nome para commits Git'
    git config --global user.name "$GIT_AUTHOR_NAME"
fi
if ! git config --global --get user.email >/dev/null; then
    ask GIT_AUTHOR_EMAIL 'E-mail para commits Git'
    git config --global user.email "$GIT_AUTHOR_EMAIL"
fi
if ! $skip_auth; then
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        gh auth login --hostname github.com --git-protocol https --web
    fi
    gh auth setup-git --hostname github.com
fi
if [[ ! -e "$project_dir" ]]; then
    mkdir -p -- "$(dirname -- "$project_dir")"
    gh repo clone RJ-SMTR/pipelines_v3 "$project_dir"
fi
cd -- "$project_dir"
project_dir=$PWD
[[ -f pyproject.toml && -f uv.lock && -f queries/dev/profiles-example.yml ]] || {
    echo 'O diretório deve conter um checkout pipelines_v3 com uv.lock e perfis dbt.' >&2; exit 1;
}
# Ignore an inherited venv and always use this checkout's .venv.
UV_PROJECT_ENVIRONMENT="$project_dir/.venv" uv sync --locked --all-packages --python 3.13
.venv/bin/pre-commit install
if [[ ! -e queries/dev/profiles.yml ]]; then
    cp queries/dev/profiles-example.yml queries/dev/profiles.yml
fi
(cd queries && ../.venv/bin/dbt deps --profiles-dir ./dev)
# Reuse an existing .env for login instead of asking again.
if [[ -f .env ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi
if ! $skip_auth || [[ ! -e .env ]]; then
    ask GCP_ACCOUNT 'E-mail da conta Google autorizada'
    GCP_PROJECT_ID=${GCP_PROJECT_ID:-rj-smtr-dev}
    QUOTA_PROJECT_ID=${QUOTA_PROJECT_ID:-$GCP_PROJECT_ID}
    DBT_USER=${DBT_USER:-$(id -un)}
    [[ $GCP_ACCOUNT =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+$ && $GCP_PROJECT_ID =~ ^[a-z][a-z0-9-]+$ && $QUOTA_PROJECT_ID =~ ^[a-z][a-z0-9-]+$ && $DBT_USER =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || {
        echo 'Conta, projetos ou DBT_USER inválidos para o .env.' >&2; exit 1;
    }
fi
if [[ ! -e .env ]]; then
    (umask 077; cat > .env <<ENV
GCP_ACCOUNT=$GCP_ACCOUNT
GCP_PROJECT_ID=$GCP_PROJECT_ID
QUOTA_PROJECT_ID=$QUOTA_PROJECT_ID
DBT_USER=$DBT_USER
INFISICAL_ADDRESS=https://infisical.dados.rio
INFISICAL_CLIENT_ID=
INFISICAL_CLIENT_SECRET=
INFISICAL_PROJECT_ID=
ENV
    )
else
    echo '.env existente preservado; revise-o conforme o onboarding.'
fi
if ! $skip_auth; then
    gcp-login --force
fi
printf '\nConfiguração preparada em %s.\nRevise o .env e abra um novo terminal na pasta do projeto.\n' "$project_dir"
}

# Parse the complete installer before running it. With curl | bash, stdin holds
# shell code; give sudo, login commands and read prompts the terminal instead.
if [[ -t 0 ]]; then
    main "$@"
elif { true </dev/tty; } 2>/dev/null; then
    main "$@" </dev/tty
else
    # Unattended execution can still use supplied values and --skip-auth.
    main "$@" </dev/null
fi
