# Quick Start

O desenvolvimento atual usa [RJ-SMTR/pipelines_v3](https://github.com/RJ-SMTR/pipelines_v3), Python 3.13, uv, Prefect 3 e dbt Core. Para instalar ferramentas, autenticar com OAuth e configurar `.env` e o Bash, siga o [onboarding](onboarding.md).

Com as ferramentas e credenciais já disponíveis:

```bash
cd ~/prefeitura_rio/pipelines_v3
uv sync --locked --all-packages --python 3.13
.venv/bin/pre-commit install
```

Selecione `.venv/bin/python` no editor. Terminais abertos na pasta do projeto ativam a venv e carregam o `.env` automaticamente.

## Validar o ambiente

```bash
uv sync --locked --all-packages --check
cd queries
../.venv/bin/dbt deps --profiles-dir ./dev
../.venv/bin/dbt parse --profiles-dir ./dev --target dev
```

A execução usa dbt Core local. `parse` valida o projeto; não executa modelos nem comprova acesso ao warehouse. Antes de executar modelos, selecione o escopo e confirme o target de desenvolvimento.

## Desenvolver uma pipeline

Consulte o `flow.py`, o `pyproject.toml` e o `prefect.yaml` da pipeline em `pipelines/<nome>/`, além das instruções do repositório. Dependências específicas são gerenciadas pelo uv workspace.

Para executar Python pelo ambiente do projeto, use `uv run --locked python` ou `.venv/bin/python`. A execução de uma pipeline pode acessar serviços externos, carregar segredos e gravar dados; siga a configuração e os parâmetros do fluxo escolhido.

O projeto usa Prefect 3. Para execução na infraestrutura da equipe, siga os deployments e os work pools definidos no `prefect.yaml`; o onboarding não publica deployments nem dispara runs.
