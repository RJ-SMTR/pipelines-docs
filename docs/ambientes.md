### Desenvolvimento

É o ambiente de testes dos pipelines e modelos do DBT, deve ser passado através da label
`RJ_SMTR_DEV_AGENT_LABEL` nos pipelines que estão sendo desenvolvidos e como `rj-smtr-dev` no campo `database` no arquivo `sources.yml` dos modelos do DBT.

### Produção

É o ambiente de produção dos pipelines e modelos do DBT, deve ser passado através da label
`RJ_SMTR_AGENT_LABEL` nos pipelines que estão sendo desenvolvidos e como `rj-smtr-staging` no campo `database` no arquivo `sources.yml` dos modelos do DBT.

Corresponde à branch `main` do repositório do github.
