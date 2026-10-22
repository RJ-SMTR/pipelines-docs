# Ambientes

No [pipelines_v3](https://github.com/RJ-SMTR/pipelines_v3), o **target dbt**, o **projeto Google Cloud** e o **ambiente do deployment Prefect** são configurações distintas. Configurar um deles não modifica automaticamente os demais.

## Targets dbt locais

O arquivo `queries/dev/profiles-example.yml` define os seguintes targets:

| Target | Projeto BigQuery do perfil | Comportamento de schema |
| --- | --- | --- |
| `dev` (padrão) | `rj-smtr-dev` | A macro `generate_schema_name` adiciona o prefixo `DBT_USER__`. |
| `hmg` | `rj-smtr-dev` | Schemas terminados em `_staging` recebem o sufixo `_dbt`. |
| `prod` | `rj-smtr` | A macro não adiciona o prefixo pessoal de desenvolvimento. |

O `profiles.yml` pessoal pode ter outras configurações; revise-o antes da execução. Modelos e sources também podem referenciar outros projetos explicitamente, portanto o projeto do perfil não descreve todos os dados lidos ou escritos.

Para desenvolvimento, execute dbt Core a partir de `queries`, com `--profiles-dir ./dev --target dev`, e defina seu `DBT_USER` conforme o [onboarding](onboarding.md). `GCP_PROJECT_ID` configura o projeto ativo do gcloud; `QUOTA_PROJECT_ID` configura quota no ADC. Nenhuma dessas variáveis reescreve os targets do perfil.

## Deployments Prefect

O projeto usa Prefect 3 e work pools. Consulte `pipelines/<nome>/prefect.yaml` para o deployment, parâmetros e `secretName`, além dos workflows de CI/CD correspondentes.

As branches `staging/*` são usadas para deployments de staging e `master` para produção no repositório `pipelines_v3`. A branch `main` deste repositório de documentação não determina o ambiente de execução das pipelines.

Credenciais de usuário OAuth usadas no Ubuntu não substituem as credenciais e os segredos configurados nos containers.
