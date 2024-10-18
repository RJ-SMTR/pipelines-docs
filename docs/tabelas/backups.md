# Processo de Backup

Esta página descreve o processo utilizado para realizar backups de dados do BigQuery.

## 1. Verificação da Quantidade de Dados

Antes de realizar o backup, utilizamos a seguinte query para contar o número de registros na tabela que será exportada:

```sql
SELECT
    COUNT(*) AS count
FROM
    `{project_id}.{dataset_id}.{table_id}`
```

Este valor é utilizado para exportar todos os dados em um único arquivo.

Caso a tabela contenha uma coluna de data, também coletamos a menor e a maior data dos registros que serão salvos:

```sql
SELECT
    MIN(data) AS data_inicio,
    MAX(data) AS data_fim
FROM
    `{project_id}.{dataset_id}.{table_id}`
```

## 2. Exportação dos Dados para o Google Cloud Storage (GCS)

Após verificar a quantidade de registros, realizamos a exportação dos dados da tabela para o GCS utilizando a seguinte query:

```sql
EXPORT DATA
  OPTIONS (
    uri = 'gs://rj-smtr-staging/backup/{dataset_id}/{table_id}/data={data}/{table_id}_00_*.csv',
    format = 'CSV',
    header = TRUE,
    OVERWRITE = TRUE
  ) AS (
    SELECT
      *
    FROM
      `{project_id}.{dataset_id}.{table_id}`
    LIMIT
      {count}
)
```

### Explicação dos parâmetros:
- **uri**: O local de destino no GCS onde os arquivos CSV serão salvos. O caminho segue o padrão:  
  `gs://rj-smtr-staging/backup/{dataset_id}/{table_id}/data={data}/{table_id}_00_*.csv`
- **format**: O formato do arquivo exportado, que será CSV.
- **header**: Indica que o cabeçalho das colunas será incluído no arquivo CSV.
- **OVERWRITE**: Permite que arquivos existentes sejam sobrescritos.

Nesta query:
- O `count` é o valor obtido na [etapa anterior](#1-verificação-da-quantidade-de-dados).


## 3. Atualização da Planilha de Controle

Após a exportação dos dados, realizamos a atualização de uma planilha de controle no Google Sheets. Esta planilha contém informações sobre cada backup realizado, permitindo que tenhamos um registro dos backups.

As colunas da planilha são:

| **Coluna**          | **Descrição**                                                 |
|---------------------|---------------------------------------------------------------|
| **Data**            | Data em que o backup foi realizado.                           |
| **dataset_id**      | O ID do dataset do BigQuery.                                  |
| **table_id**        | O ID da tabela que foi exportada.                             |
| **Local do backup** | O caminho no GCS onde o backup foi salvo.                     |
| **Descrição da tabela** | Descrição da tabela.                                      |
| **Motivo do backup** | Motivo para a realização do backup.                          |
| **Lista de colunas** | Colunas que foram exportadas no backup.                      |
| **Data início**     | Menor data dos registros exportados (se aplicável).           |
| **Data fim**        | Maior data dos registros exportados (se aplicável).           |

Essas informações permitem o controle dos backups, garantindo a integridade dos dados e facilitando futuras restaurações, se necessário.