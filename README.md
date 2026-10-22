# pipelines-docs

Documentação da equipe de dados da SMTR, publicada com MkDocs Material.

- [Onboarding](docs/onboarding.md): ambiente Ubuntu/WSL para desenvolvimento no `RJ-SMTR/pipelines_v3`.
- `scripts/onboarding/setup-ubuntu.sh`: instalação de ferramentas, preparação do checkout e configuração gerenciada do Bash.
- `scripts/onboarding/shell.bash`: template revisável da configuração do Bash.

Os scripts ficam junto ao guia de instalação; versões e dependências Python continuam definidas no `pyproject.toml` e `uv.lock` do `pipelines_v3`. Execute os scripts com Bash conforme o onboarding. Não é necessário instalar as dependências MkDocs para usá-los.

O onboarding permite baixar e executar o instalador com curl, sem clonar este repositório. Ele obtém os auxiliares da branch `main` e os mantém em `~/.local/share/smtr/onboarding/`.
