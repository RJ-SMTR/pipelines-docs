# Loaded by the managed block in ~/.bashrc; no project-specific values here.
if [[ -f "$HOME/.local/bin/env" ]]; then
    # shellcheck disable=SC1091
    source "$HOME/.local/bin/env"
fi
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v explorer.exe >/dev/null 2>&1; then
    alias open='explorer.exe'
fi

# Activate the venv and load .env when a terminal opens in a project folder.
# The markers are not exported, so each new shell loads its own environment.
if [[ -f .venv/bin/activate && ${VENV_SESSION_LOADED:-} != "$PWD/.venv" ]]; then
    VENV_SESSION_LOADED="$PWD/.venv"
    # shellcheck disable=SC1091
    source .venv/bin/activate
fi
if [[ $PWD == "$HOME/prefeitura_rio/"* && -f .env && ${DOTENV_SESSION_LOADED:-} != "$PWD" ]]; then
    DOTENV_SESSION_LOADED="$PWD"
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

gcp-login() {
    if ! command -v gcloud >/dev/null 2>&1; then
        echo 'Instale o Google Cloud CLI antes de executar gcp-login.' >&2
        return 1
    fi
    if [[ -z ${GCP_ACCOUNT:-} ]]; then
        echo 'Defina GCP_ACCOUNT no .env do projeto.' >&2
        return 1
    fi
    # --update-adc updates the shared local ADC; --force can renew Drive scopes.
    gcloud auth login "$GCP_ACCOUNT" --enable-gdrive-access --update-adc "$@" || return 1
    if [[ -n ${QUOTA_PROJECT_ID:-} ]]; then
        gcloud auth application-default set-quota-project "$QUOTA_PROJECT_ID" || return 1
    fi
    if [[ -n ${GCP_PROJECT_ID:-} ]]; then
        gcloud config set project "$GCP_PROJECT_ID" || return 1
    fi
    echo "OAuth e ADC configurados para $GCP_ACCOUNT."
}
