# Utilitários GCP

## Visão Geral

Este módulo fornece abstrações para interação com serviços Google Cloud Platform (GCP), especificamente BigQuery, Cloud Storage e abstrações de tabelas de origem. Utilizado amplamente em pipelines de captura e tratamento de dados.

**Localização**: `pipelines/common/utils/gcp/`

**Componentes principais**:
- `base.py`: Classes base para autenticação e gerenciamento de clientes GCP
- `bigquery.py`: Utilitários para BigQuery (SourceTable, Dataset, BQTable)
- `storage.py`: Utilitários para Cloud Storage

---

## GCPBase

Classe base que centraliza autenticação e configuração de variáveis de ambiente para clientes GCP.

### Atributos

| Atributo | Tipo | Descrição |
|----------|------|-----------|
| `project_id` | `str` | ID do projeto GCP |
| `dataset_id` | `str` | ID do dataset BigQuery |
| `table_id` | `str` | ID da tabela |

### Métodos

#### `__post_init__()`
Inicializa variáveis de ambiente necessárias após instanciação.

#### `set_env()`
Define variáveis de ambiente para autenticação GCP.

#### `client`
**Propriedade** que retorna o cliente autenticado (lazy-loaded).

#### `__getitem__(key: str) -> Any`
Permite acesso aos atributos via notação de dicionário.

---

## SourceTable

Classe que encapsula metadados de uma tabela de origem (source) para captura de dados.

### Atributos

| Atributo | Tipo | Descrição |
|----------|------|-----------|
| `source_name` | `str` | Nome da fonte (ex: "cittati", "conecta", "jae") |
| `table_id` | `str` | ID da tabela no BigQuery |
| `first_timestamp` | `datetime` | Primeira timestamp válida para captura |
| `flow_folder_name` | `str` | Nome da pasta do flow Prefect |
| `primary_keys` | `list[str]` | Chaves primárias para identificação de registros |
| `partition_date_only` | `bool` | Se `True`, particiona apenas por data; se `False`, por data+hora |
| `pretreatment_reader_args` | `dict` | Argumentos para leitura/pré-processamento dos dados |

### Métodos

#### `exists() -> bool`
Verifica se a tabela existe no BigQuery.

```python
source = SourceTable(...)
if source.exists():
    print("Tabela existe")
```

#### `create()`
Cria a tabela no BigQuery com schema inferido.

#### `append(data: pd.DataFrame, partition: str)`
Adiciona dados à tabela com particionamento Hive.

```python
source.append(df, partition="data=2025-01-15/hora=10")
```

#### `upload_raw_file(filepath: str, partition: str)`
Carrega arquivo JSON/CSV bruto para a tabela.

#### `get_last_scheduled_timestamp() -> datetime`
Retorna o último timestamp capturado desta fonte.

#### `get_uncaptured_timestamps(start: datetime, end: datetime) -> list[datetime]`
Retorna timestamps não capturadas no intervalo.

#### `get_table_min_max_value(column: str) -> tuple`
Retorna valores mínimo e máximo de uma coluna.

---

## Dataset

Wrapper para datasets BigQuery com operações comuns.

### Atributos

| Atributo | Tipo | Descrição |
|----------|------|-----------|
| `dataset_id` | `str` | ID do dataset |
| `project_id` | `str` | ID do projeto GCP |

### Métodos

Padrão similar a `GCPBase` com operações específicas a datasets (criação, limpeza, etc.).

---

## BQTable

Classe para operações em tabelas BigQuery com suporte a particionamento e schema management.

### Atributos

| Atributo | Tipo | Descrição |
|----------|------|-----------|
| `table_id` | `str` | ID da tabela |
| `dataset_id` | `str` | ID do dataset |
| `project_id` | `str` | ID do projeto |

### Métodos

#### `create()`
Cria tabela com schema configurado.

#### `exists() -> bool`
Verifica existência da tabela.

#### `append(data: pd.DataFrame, partition: str)`
Insere dados com particionamento automático.

---

## Storage

Classe para operações em Google Cloud Storage.

### Atributos

| Atributo | Tipo | Descrição |
|----------|------|-----------|
| `env` | `str` | Ambiente (`prod` ou `dev`) |
| `dataset_id` | `str` | Identificador do dataset (usado para determinar bucket) |
| `table_id` | `str` | Identificador da tabela (usado para determinar bucket) |

### Métodos

#### `__init__(env: str, dataset_id: str, table_id: str)`
Inicializa cliente Storage com credenciais automáticas.

#### `upload_file(filepath: str, mode: str, partition: str) -> str`
Faz upload de arquivo local para GCS.

```python
storage = Storage(env="prod", dataset_id="captura", table_id="gps_cittati")
storage.upload_file(
    filepath="/tmp/data.json",
    mode="raw",
    partition="data=2025-01-15"
)
```

**Parâmetros**:
- `filepath`: Caminho local do arquivo
- `mode`: Tipo de armazenamento (ex: "raw", "backup_jae_billingpay")
- `partition`: Partição Hive (ex: "data=2025-01-15/hora=10")

**Retorno**: Path do blob criado no GCS

#### `get_blob_string(blob_name: str) -> str`
Lê conteúdo de um blob como string.

#### `get_blob_bytes(blob_name: str) -> bytes`
Lê conteúdo de um blob como bytes.

#### `get_blob_obj(blob_name: str)`
Retorna o objeto Blob do GCS.

#### `create_blob_name(mode: str, partition: str, filename: str) -> str`
Constrói caminho completo do blob no GCS.

#### `move_folder(source_prefix: str, dest_prefix: str)`
Move pasta inteira dentro do bucket.

#### `unzip_file(blob_name: str, dest_folder: str)`
Descompacta arquivo ZIP do GCS para pasta local.

#### `_check_mode(mode: str)`
Valida se o modo é permitido (uso interno).

---

## Fluxo de Integração

### Captura de Dados (GPS)

```
1. SourceTable define metadados (source_name, table_id, primary_keys)
   ↓
2. create_gps_extractor() prepara extração via API
   ↓
3. get_raw_api() retorna dados em JSON/CSV
   ↓
4. upload_raw_file() carrega arquivo para Storage (GCS)
   ↓
5. append() insere dados no BigQuery com particionamento
```

### Backup Incremental (BillingPay)

```
1. get_table_info() consulta metadados de tabelas origem
   ↓
2. get_raw_backup_billingpay() extrai dados com filtros incrementais
   ↓
3. Storage.upload_file() envia para GCS
   ↓
4. Redis armazena último timestamp/ID capturado
```

---

## Dependências

| Módulo | Função |
|--------|--------|
| `pipelines.common.utils.secret` | Carregamento de credenciais GCP |
| `pipelines.common.utils.database` | Conexões a bancos relacionais |
| `pipelines.common.utils.fs` | Operações de sistema de arquivos |
| `google.cloud.bigquery` | Cliente BigQuery |
| `google.cloud.storage` | Cliente Cloud Storage |

---

## Padrões de Uso

### Verificar e Criar Tabela

```python
from pipelines.common.utils.gcp.bigquery import SourceTable

source = SourceTable(
    source_name="cittati",
    table_id="registros",
    first_timestamp=datetime(2025, 1, 1),
    flow_folder_name="capture__cittati_registros",
    primary_keys=["id_veiculo", "datetime_servidor"],
)

if not source.exists():
    source.create()
```

### Upload para Storage

```python
from pipelines.common.utils.gcp.storage import Storage

storage = Storage(env="prod", dataset_id="captura", table_id="gps")
storage.upload_file(
    filepath="/tmp/registros_2025-01-15.json",
    mode="raw",
    partition="data=2025-01-15/hora=10"
)
```

### Consultar Timestamps Não Capturadas

```python
uncaptured = source.get_uncaptured_timestamps(
    start=datetime(2025, 1, 1),
    end=datetime(2025, 1, 31)
)
for ts in uncaptured:
    print(f"Timestamp não capturada: {ts}")
```

---

## Considerações de Segurança

- Credenciais GCP carregadas via **Infisical** (não hardcoded)
- Variáveis de ambiente configuradas dinamicamente em `set_env()`
- Acesso a buckets controlado por IAM roles
- Operações em BigQuery utilizam autenticação de serviço

---

## Evolução Recente

### Novos Componentes (v3)

- **`create_gps_extractor()`**: Abstração para captura GPS (cittati, conecta, zirix)
- **GPS Constants**: Centralização de configurações por fonte
- **`create_partition()`**: Função utilitária para particionamento Hive

### Refatorações

- Extração de lógica de partição para `pipelines/common/utils/fs.py`
- Consolidação de tipos de dados em dataclasses
- Suporte expandido a múltiplas fontes GPS

---

## Troubleshooting

| Problema | Causa | Solução |
|----------|-------|---------|
| `PermissionDenied` em BigQuery | Credenciais ou IAM insuficiente | Verificar `GOOGLE_APPLICATION_CREDENTIALS` e roles do serviço |
| Arquivo não encontrado no GCS | Path construído incorretamente | Validar `create_blob_name()` e permissões de bucket |
| `SourceTable.exists()` retorna `False` | Dataset/tabela não existe | Executar `SourceTable.create()` |
| Upload lento | Arquivo grande ou rede | Usar `get_raw_db_paginated()` para dividir em chunks |

---

## Ver Também

- `tech/arquitetura.md`: Visão geral da arquitetura
- `tech/pipelines/captura.md`: Fluxos de captura de dados
- `tech/utilitarios/database.md`: Utilitários de banco de dados