# Dependências entre Pipelines, Tasks e Utilitários

## 1. Mapa de Dependências Estruturais

### 1.1 Pipelines de Captura (Capture)

#### Grupo GPS (Cittati, Conecta, Zirix)
```
capture__cittati_realocacao
capture__cittati_registros
capture__conecta_realocacao
capture__conecta_registros
capture__zirix_realocacao
capture__zirix_registros
    ↓
create_gps_extractor (pipelines/common/capture/gps/tasks.py)
    ↓
get_raw_api (pipelines/common/utils/extractors/api.py)
```

**Dependências Compartilhadas:**
- `SourceTable` (pipelines/common/utils/gcp/bigquery.py)
- `create_capture_flows_default_tasks()` (pipelines/common/capture/default_capture/flow.py)
- `GPS_SOURCE_CONFIGS` (pipelines/common/capture/gps/constants.py)
- `get_env_secret()` (pipelines/common/utils/secret.py)

#### Grupo JAE
```
capture__jae_backup_billingpay
    ↓ (depende de)
    ├─ get_jae_db_config()
    ├─ get_table_info()
    ├─ get_raw_backup_billingpay()
    ├─ upload_backup_billingpay()
    └─ set_redis_backup_billingpay()
    ↓
    ├─ create_database_url() (pipelines/common/utils/database.py)
    ├─ Storage (pipelines/common/utils/gcp/storage.py)
    ├─ get_redis_client() (pipelines/common/utils/redis.py)
    └─ BACKUP_JAE_BILLING_PAY (constants.py - 447 linhas)
```

### 1.2 Pipelines de Tratamento (Treatment)

```
treatment__*
    ↓
create_materialization_flows_default_tasks()
    ↓
    ├─ run_dbt_selectors()
    ├─ run_dbt_snapshots()
    ├─ run_dbt_tests()
    ├─ wait_data_sources()
    └─ dbt_test_notify_discord()
    ↓
    ├─ DBTSelector (context manager)
    ├─ DBTSelectorMaterializationContext
    ├─ convert_timezone()
    ├─ cron_get_last_date()
    ├─ Storage
    └─ send_discord_message()
```

### 1.3 Pipelines de Controle (Control)

```
control__source_freshness
    ↓
    ├─ parse_source_freshness_output()
    ├─ source_freshness_notify_discord()
    ├─ get_project_root_path()
    └─ send_discord_message()

control__set_redis_key
    ↓
    └─ set_redis_keys()
        ↓
        └─ get_redis_client()
```

### 1.4 Pipelines de Integração (Integration)

```
integration__previnity_negativacao
    ↓
    ├─ get_previnity_credentials()
    ├─ get_previnity_date_range()
    ├─ prepare_previnity_payloads()
    ├─ async_post_request()
    └─ send_discord_message()
```

---

## 2. Dependências de Utilitários Compartilhados

### 2.1 Utilitários de Extração (pipelines/common/utils/extractors/)

```
get_raw_api()
├─ async_post_request()
├─ get_api_data()
└─ normalize_text() (pretreatment)

get_raw_db()
├─ create_database_url()
├─ test_database_connection()
└─ list_accessible_tables()

get_raw_db_paginated()
├─ get_db_data()
├─ save_local_file()
└─ normalize_text()
```

**Impacto:** Mudanças em `create_database_url()` afetam:
- `capture__jae_backup_billingpay` (get_raw_backup_billingpay)
- `capture__jae_*` (todas as capturas JAE)

### 2.2 Utilitários GCP (pipelines/common/utils/gcp/)

```
Storage
├─ upload_file()
├─ move_folder()
├─ unzip_file()
└─ create_blob_name()
    ↓ (usado por)
    ├─ capture__jae_backup_billingpay
    ├─ treatment__* (upload de materialisações)
    └─ common/capture/default_capture/tasks.py

BigQuery
├─ get_last_scheduled_timestamp()
├─ get_uncaptured_timestamps()
├─ upload_raw_file()
└─ SourceTable (classe raiz para configuração de fontes)
    ↓ (usado por)
    ├─ Todos os capture__*
    ├─ Todas as SourceTable customizadas
    └─ treatment__ (via dbt vars)
```

**Dependências Críticas:**
- `SourceTable` → 6+ pipelines de captura
- `Storage.upload_file()` → 3+ pipelines (backup, treatment, capture)

### 2.3 Utilitários de Redis (pipelines/common/utils/redis.py)

```
get_redis_client()
    ↓ (usado por)
    ├─ set_redis_backup_billingpay()
    ├─ wait_data_sources()
    ├─ save_materialization_datetime_redis()
    └─ control__set_redis_key
```

**Padrão de Chave:**
- `{env}.backup_jae_billingpay.{database_name}.{table_name}`
- `{env}.materialization.{dataset_id}.{table_id}`

### 2.4 Utilitários de Ambiente/Secret (pipelines/common/utils/)

```
getenv_or_action() → env.py
get_env_secret() → secret.py
get_infisical_client() → secret.py
inject_bd_credentials() → env.py
validate_bd_credentials() → env.py
```

**Fluxo de Inicialização:**
1. `initialize_sentry()` → setup Sentry
2. `setup_environment()` → load secrets via Infisical
3. `get_run_env()` → determina prod/staging

---

## 3. Dependências entre Processos (Grafo)

### 3.1 Processos Cross-Community Críticos

**Padrão: Treatment → Utilitários**
```
Treatment__viagem_informada
├─ getenv_or_action (6 steps)
├─ get_env_secret (4 steps)
├─ convert_timezone (4 steps)
└─ is_running_locally (4 steps)
```

**Padrão: Wait Data Sources → Storage**
```
wait_data_sources
├─ Storage (3 steps)
├─ cron_date_range (3 steps)
├─ cron_get_last_date (3 steps)
├─ convert_timezone (4 steps)
├─ _get_redis_key (4 steps)
└─ is_running_locally (5 steps)
```

### 3.2 Processos Intra-Community

```
dbt_test_notify_discord
├─ send_discord_message (3 steps)
└─ get_project_root_path (3 steps)

Extract_serpro_data
└─ _setup_serpro_certificate (3 steps)

Main (update_table_metadata.py)
└─ dfs (3 steps)
```

---

## 4. Mudanças Estruturais Relevantes

### 4.1 Novos Módulos/Dependências

| Módulo | Descrição | Dependências | Impacto |
|--------|-----------|--------------|--------|
| `pipelines/common/capture/gps/` | Extração de GPS (Cittati, Conecta, Zirix) | `get_raw_api`, `get_env_secret` | 6 novos pipelines capture |
| `capture__jae_backup_billingpay` | Backup incremental JAE | `Storage`, `Redis`, `SQLAlchemy`, `BigQuery` | Crítico para JAE |
| `control__source_freshness` | Monitoramento de freshness | `dbt source freshness`, `send_discord_message` | Operacional |

### 4.2 Mudanças em Arquivos Existentes

**`pipelines/capture__jae_transacao_ordem/constants.py`**
```python
# REMOVIDO:
bucket_names=jae_constants.JAE_PRIVATE_BUCKET_NAMES

# ADICIONADO:
partition_date_only=True
max_recaptures=5
```
**Impacto:** Mudança no particionamento. Verificar se afeta:
- `SourceCaptureContext.get_partition()`
- `rename_capture_flow_run()`

**`pipelines/common/capture/default_capture/utils.py`**
- Refatoração: Lógica de `get_partition()` → função utilitária `create_partition()`
- **Impacto:** Todos os `SourceCaptureContext` herdeiros

**`pipelines/common/utils/fs.py`**
- Nova função `create_partition()` (26 linhas)
- Substituiu lógica inline em `SourceCaptureContext.get_partition()`

---

## 5. Matriz de Dependências Entre Pipelines

### 5.1 Dependências Comuns

```
┌─────────────────────────────────────────┐
│  pipelines/common/                      │
│  ├─ capture/                            │
│  │  ├─ default_capture/                │
│  │  │  └─ flow.py (cria task flows)    │
│  │  ├─ gps/                            │
│  │  │  └─ tasks.py (NOVO)              │
│  │  └─ jae/                            │
│  │     └─ tasks.py                     │
│  ├─ treatment/                          │
│  │  └─ default_treatment/              │
│  │     ├─ flow.py                      │
│  │     └─ tasks.py (dbt runner)        │
│  ├─ utils/                              │
│  │  ├─ gcp/ (Storage, BigQuery, Base)  │
│  │  ├─ extractors/ (api, db)           │
│  │  ├─ secret.py                       │
│  │  ├─ env.py                          │
│  │  ├─ redis.py                        │
│  │  ├─ database.py                     │
│  │  ├─ discord.py                      │
│  │  ├─ cron.py                         │
│  │  ├─ pretreatment.py                 │
│  │  └─ utils.py                        │
│  └─ constants.py                        │
└─────────────────────────────────────────┘
```

### 5.2 Ordem de Inicialização Recomendada

1. **Secrets & Env** → `setup_environment()`, `get_env_secret()`
2. **Database** → `create_database_url()`, `list_accessible_tables()`
3. **Storage/GCP** → `Storage()`, `BigQuery()`
4. **Extractors** → `get_raw_api()`, `get_raw_db()`
5. **Pipelines** → capture → treatment → control

---

## 6. Dependências de dbt (queries/)

### 6.1 Macros Utilizadas por Pipelines

```
run_dbt_selectors()
├─ get_models_with_tags()
├─ generate_database_name()
├─ generate_schema_name()
└─ query_comment()

run_dbt_tests()
├─ test_*.sql (40+ macros)
├─ unique_key.sql
├─ many_to_one.sql
├─ one_to_one.sql
└─ custom_get_where_subquery.sql
```

### 6.2 Models Dependentes

```
treatment__* pipelines
    ↓
dbt run/test
    ↓
models/{dataset}/
├─ bilhetagem/
├─ cadastro/
├─ planejamento/
├─ monitoramento/
├─ transito/
└─ staging/
```

---

## 7. Impacto de Mudanças

### 7.1 Mudanças de Alto Risco

| Componente | Pipelines Afetadas | Severidade | Motivo |
|------------|------------------|-----------|--------|
| `SourceTable` | capture__* (6+) | **CRÍTICA** | Raiz de todas as capturas |
| `create_partition()` | capture__* (6+) | **ALTA** | Afeta particionamento GCS/BQ |
| `Storage.upload_file()` | treatment__*, capture__* (10+) | **ALTA** | Upload centralizado |
| `get_redis_client()` | treatment__*, control__*, capture__jae_backup_billingpay | **ALTA** | Estado compartilhado |
| `send_discord_message()` | control__*, treatment__*, capture__jae_backup_billingpay | **MÉDIA** | Notificações |

### 7.2 Mudanças de Baixo Risco

| Componente | Pipelines Afetadas | Motivo |
|------------|------------------|--------|
| `GPS_SOURCE_CONFIGS` | capture__cittati_*, capture__conecta_*, capture__zirix_* | Isolado em módulo novo |
| `BACKUP_JAE_BILLING_PAY` | capture__jae_backup_billingpay | Local (constants.py) |
| `dbt_test_notify_discord()` | treatment__* | Nova função, não refactor |

---

## 8. Checklist de Validação para Alterações

### Ao Adicionar Nova Task/Pipeline

- [ ] Declarar dependências explícitas em imports
- [ ] Validar compatibilidade com `SourceTable` (se capture)
- [ ] Testar com ambientes dev/staging/prod
- [ ] Verificar se usa `Storage`, `Redis`, ou `get_env_secret()`
- [ ] Adicionar logging de dependências inicializadas
- [ ] Documentar ordem esperada de execução em prefect.yaml

### Ao Modificar Utilitários Compartilhados

- [ ] Executar `grep -r "função_modificada"` em `pipelines/`
- [ ] Testar em todos os pipelines dependentes
- [ ] Verificar assinatura de função (tipos de parâmetros)
- [ ] Validar retorno esperado não mudou
- [ ] Atualizar documentação de dependências

### Ao Adicionar Nova Constante

- [ ] Colocar em arquivo apropriado: `pipelines/common/` se compartilhada
- [ ] Usar padrão `SNAKE_CASE_UPPERCASE`
- [ ] Documentar na seção de constantes deste arquivo

---

## 9. Referência Rápida: Imports Principais

```python
# Inicialização
from pipelines.common.tasks import setup_environment, initialize_sentry, get_run_env
from pipelines.common.utils.secret import get_env_secret, set_local_secrets

# Extração
from pipelines.common.utils.extractors.api import get_raw_api
from pipelines.common.utils.extractors.db import get_raw_db, get_raw_db_paginated
from pipelines.common.utils.gcp.bigquery import SourceTable

# Storage
from pipelines.common.utils.gcp.storage import Storage
from pipelines.common.utils.gcp.bigquery import BigQuery

# Redis
from pipelines.common.utils.redis import get_redis_client

# dbt
from pipelines.common.treatment.default_treatment.utils import (
    DBTSelector, DBTSelectorMaterializationContext, run_dbt
)

# Utilitários
from pipelines.common.utils.utils import convert_timezone, cron_date_range
from pipelines.common.utils.cron import cron_get_last_date, cron_get_next_date
from pipelines.common.utils.discord import send_discord_message
from pipelines.common.utils.fs import create_partition, get_data_folder_path