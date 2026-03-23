### Descrição

Datasets são contêineres para organização e controle de acesso de tabelas e views no BigQuery.

O nome do dataset deve ser o mesmo na definição do pipeline e na pasta de modelos do DBT.

### Dataset Sources

Os dataset utilizados na captura de dados brutos devem seguir o seguinte padrão ao serem nomeados:

`[dataset_id]_[fonte]_source (ex.: cadastro_jae_source)`

### Datasets atuais

- **gtfs**:

Dados de planejamento da malha de transporte da cidade. Tabelas no formato padrão [GTFS (*General Transport Feed Specification*)](https://gtfs.org).

- **cadastro**:

Dados cadastrais de recursos físicos e humanos do sistema de transporte da cidade.

- **monitoramento**:

Dados de frequência contínua (minuto, diário, outros) sobre a operação de transportes na cidade.

- **financeiro**:

Dados de movimentações financeiras do sistema de transporte da cidade.

- **bilhetagem**:

Dados de componentes e recursos do sistema de bilhetagem da cidade.

- **subsidio**:

Dados de componentes e recursos do sistema de subsídio da cidade.

- **sustentabilidade**:

Dados e indicadores de mobilidade sustentável da cidade.
