# Ferramentas

Esta página descreve o [pipelines_v3](https://github.com/RJ-SMTR/pipelines_v3). As versões exatas instaladas são definidas pelo `uv.lock`; os requisitos ficam no `pyproject.toml` do checkout. Use o [onboarding](onboarding.md) para preparar o ambiente.

## Python e uv

O projeto exige Python **3.13** (`>=3.13,<3.14`) e usa **uv workspaces** para gerenciar as dependências da raiz e das pipelines. A venv local é `.venv` e deve ser sincronizada com `uv sync --locked --all-packages`.

Documentação: [Python 3.13](https://docs.python.org/pt-br/3.13/) e [uv](https://docs.astral.sh/uv/).

## Prefect

O projeto usa **Prefect 3** para orquestrar pipelines, com deployments definidos em `prefect.yaml` e execução em work pools.

Documentação: [Prefect 3](https://docs.prefect.io/v3/).

## dbt Core

Usamos **dbt Core** com o adapter `dbt-bigquery`, instalado na mesma venv pelo uv. Execute os comandos a partir de `queries`, com `--profiles-dir ./dev`. Não use dbt Fusion ou dbt Cloud neste projeto, salvo orientação explícita.

Documentação: [dbt](https://docs.getdbt.com/docs/introduction).

## Google Cloud CLI, BigQuery e Google Cloud Storage

O BigQuery armazena tabelas transformadas e materializadas; o GCS armazena arquivos usados pelas pipelines, incluindo dados brutos de captura. No desenvolvimento local, o Google Cloud CLI obtém credenciais **OAuth de usuário** e configura **Application Default Credentials (ADC)**. O login também solicita acesso ao Google Drive.

Documentação: [BigQuery](https://cloud.google.com/bigquery/docs), [Cloud Storage](https://cloud.google.com/storage/docs) e [gcloud](https://cloud.google.com/sdk/docs).

## Git, GitHub CLI e pre-commit

Git e `gh` gerenciam o checkout e a autenticação GitHub. O pre-commit é instalado pelo uv e os hooks são definidos em `.pre-commit-config.yaml` do projeto.

## Infisical

O cliente atual de segredos usa `INFISICAL_ADDRESS`, `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` e `INFISICAL_PROJECT_ID`. A necessidade de segredos depende da pipeline executada.

Documentação: [Infisical](https://infisical.com/docs/documentation/getting-started/introduction).
