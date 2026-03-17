# Fluxo Genérico de Captura: Raw → GCS → BigQuery

## Visão Geral

O fluxo de captura é o primeiro estágio da plataforma de dados SMTR. Responsável por extrair dados de fontes externas (APIs, bancos de dados, sistemas legados) e transportá-los para o Cloud Storage (GCS) e BigQuery em formato raw, sem transformações de negócio.

**Princípios:**
- Captura incremental (apenas dados novos/modificados)
- Rastreabilidade completa (timestamps, partições, metadados)
- Isolamento por contexto de fonte (diferentes lógicas de extração)
- Recuperação automática de falhas (recapture)

---

## Arquitetura do Fluxo

```
┌─────────────────┐
│   Fonte Externa │ (API, BD, arquivo)
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Etapa 1: Extração (Raw)            │
│  • create_extractor_task()          │
│  • get_raw_data()                   │
│  • Serialização JSON/CSV            │
└────────┬────────────────────────────┘
         │ Raw (sem transformação)
         ▼
┌─────────────────────────────────────┐
│  Etapa 2: Upload para GCS (Storage) │
│  • upload_raw_file_to_gcs()         │
│  • Particionamento Hive             │
│  • Modo: raw (rastreável)           │
└────────┬────────────────────────────┘
         │ gs://bucket/raw/.../{partition}/*.json
         ▼
┌─────────────────────────────────────┐
│  Etapa 3: Materialização BigQuery   │
│  • upload_raw_file() (BQTable)      │
│  • Transformação para nested        │
│  • Criação automática de tabelas    │
└────────┬────────────────────────────┘
         │ dataset.{source_name}__{table_id}
         ▼
┌──────────────────────────────────────┐
│  BigQuery: Tabelas Raw (Staging)     │
│  • Particionadas (data/hora)         │
│  • Versionadas (load_timestamp)      │
│  • Rastreáveis (source, flow_run)    │
└──────────────────────────────────────┘
```

---

## Contextos de Captura

A captura é parametrizada por **contextos** que definem:

### 1. SourceTable (Metadados da Fonte)

```python
SourceTable(
    source_name="cittati",           # Nome da operadora/sistema
    table_id="registros",            # Identificador da tabela
    first_timestamp=datetime(...),   # Primeiro dado disponível
    flow_folder_name="capture__cittati_registros",
    primary_keys=["id_veiculo", "datetime_servidor"],
    partition_date_only=False,       # Partição hora/hora
    pretreatment_reader_args={...},  # Args para leitura (pandas)
)
```

**Responsabilidades:**
- Define metadados únicos da fonte
- Controla opções de leitura e particionamento
- Determina chaves primárias para deduplicação

### 2. SourceCaptureContext (Contexto de Execução)

Encapsula dados de execução:
- `source` (SourceTable)
- `timestamp` (quando a captura foi disparada)
- `raw_filepath` (caminho local para arquivo temporário)
- `source_filepath` (caminho GCS destino)
- `partition` (data/hora em formato Hive)

**Métodos principais:**
```python
context.get_partition()      # → "data=2025-01-15/hora=10"
context.get_filepaths()      # → (raw_local, source_gcs)
```

---

## Fluxo de Execução

### Etapa 1: Criação de Extrators Customizados

Cada fonte define sua própria **função extratora** que retorna dados brutos:

#### GPS (Cittati, Conecta, Zirix)
```python
@task
def create_gps_extractor(context: SourceCaptureContext):
    """Retorna função parcial que chama a API correta"""
    source_config = GPS_SOURCE_CONFIGS[context.source.source_name]
    
    return partial(
        get_raw_api,
        url=f"{source_config['base_url']}/{endpoint}",
        params={...},
        raw_filepath=context.raw_filepath,
    )
```

**Lógica:**
- Calcula intervalo de tempo (6-10 min de atraso)
- Monta headers de autenticação (secret manager)
- Retorna função parcial pronta para execução

#### JAE (Banco de Dados)
```python
@task
def create_jae_general_extractor(context, database_name, table_name):
    """Retorna função que consulta BD com filtros incrementais"""
    last_capture = get_redis_last_capture(...)
    
    where_clause = f"dt_modificacao >= '{last_capture}'"
    
    return partial(
        get_raw_db,
        query=f"SELECT * FROM {table_name} WHERE {where_clause}",
        raw_filepath=context.raw_filepath,
        database_config=db_config,
    )
```

**Lógica:**
- Redis armazena último timestamp capturado
- Cria cláusula WHERE incremental
- Carrega apenas dados novos

#### SERPRO (API com Certificado SSL)
```python
@task
def create_serpro_extractor(context):
    """Retorna função com setup de certificado SSL"""
    cert_path = _setup_serpro_certificate()
    
    return partial(
        extract_serpro_data,
        url=...,
        cert=cert_path,
        raw_filepath=context.raw_filepath,
    )
```

**Lógica:**
- Setup de certificado SSL em `/tmp`
- Chamada HTTP com validação de certificado
- Cleanup automático

### Etapa 2: Obtenção de Dados Raw

```python
@task
def get_raw_data(extractor, context):
    """
    Executa a função extratora e salva dados localmente
    
    Fluxo:
    1. Chama extractor() → retorna dados (JSON/CSV)
    2. Detecta formato automaticamente
    3. Salva em contexto.raw_filepath
    4. Retorna contexto atualizado
    """
    data = extractor()
    save_local_file(data, context.raw_filepath)
    return context
```

**Tratamento de Formato:**
- JSON → pandas DataFrame → JSON (estrutura padrão)
- CSV → pandas DataFrame → JSON
- Detecta automaticamente via mimetype

### Etapa 3: Transformação (Raw → Nested)

```python
@task
def transform_raw_to_nested_structure(context):
    """
    Normaliza estrutura JSON para padrão SMTR
    
    Transforma:
    {
        "data": [
            {"id": 1, "sensor": "gps", "value": 23.5},
            {"id": 1, "sensor": "temp", "value": 28.2}
        ]
    }
    
    Para:
    {
        "data": [
            {"id": 1, "sensors": [
                {"sensor": "gps", "value": 23.5},
                {"sensor": "temp", "value": 28.2}
            ]}
        ]
    }
    """
    df = read_raw_data(context.raw_filepath)
    df_nested = transform_to_nested_structure(df, ...)
    save_local_file(df_nested, context.raw_filepath)
    return context
```

**Critérios de Transformação:**
- Chaves primárias definem agrupamento
- Arrays de objetos similar → estrutura nested
- Preserva tipos (datetime, números, strings)

### Etapa 4: Upload para GCS

```python
@task
def upload_raw_file_to_gcs(context):
    """
    Sobe arquivo bruto para GCS
    
    Caminho destino:
    gs://bucket/raw/{source_name}/{table_id}/{partition}/{timestamp}_*.json
    """
    Storage(env=env).upload_file(
        mode="raw",  # Modo específico para dados brutos
        filepath=context.raw_filepath,
        partition=context.partition,
    )
    return context
```

**Modos de Storage:**
- `raw` → Rastreável, completo, sem transformação
- `source` → Opcional, processado antes de BigQuery

### Etapa 5: Materialização em BigQuery

```python
@task
def upload_source_data_to_gcs(context):
    """
    Prepara dados para BigQuery
    
    Etapas:
    1. Lê JSON raw do GCS
    2. Valida schema
    3. Cria tabela se não existir
    4. Append ou Replace
    """
    bq_table = BQTable(
        dataset_id=context.source.source_name,
        table_id=context.source.table_id,
    )
    
    bq_table.upload_raw_file(
        raw_filepath=context.source_filepath,
        partition=context.partition,
    )
```

**Criação de Tabelas:**
- Schema inferido de JSON
- Partições automáticas (data/hora)
- Clustering por chaves primárias
- Descrição automática (metadados)

---

## Tratamento de Contextos Específicos

### GPS (Cittati, Conecta, Zirix)

**Configuração:**
```python
# constants.py
CITTATI_REALOCACAO_SOURCE = SourceTable(
    source_name="cittati",
    table_id="realocacao",
    partition_date_only=False,  # Partição hora/hora
    pretreatment_reader_args={"dtype": "object"},
)
```

**Fluxo:**
1. API retorna JSON com registros de GPS
2. Cada 10 minutos captura novos registros
3. Transforma em estrutura aninhada (id_veiculo → histórico)
4. Particiona por data/hora para eficiência de leitura

**Deduplicação:**
```python
primary_keys=["id_veiculo", "datetime_servidor"]
# BigQuery usa estas chaves para merge incremental
```

### JAE (Billing & Finance)

**Backup Incremental (capture__jae_backup_billingpay):**
```python
def get_table_info(...):
    """Busca informações de todas as tabelas"""
    for table in table_names:
        filter_columns = BACKUP_CONFIG[database][table]
        
        if filter_columns == ["count(*)"]:
            # Lógica: compara contagem total com Redis
            incremental_type = "count"
        elif column_type in [DATE, DATETIME, TIMESTAMP]:
            # Lógica: filtra por data/hora
            incremental_type = "datetime"
        else:
            # Lógica: filtra por ID incrementado
            incremental_type = "integer"
```

**Estratégias de Retenção:**
- `exclude`: Tabelas sensíveis (CLIENTE, PESSOA_FISICA, MIDIA_CHIP)
- `filter`: Colunas de data para captura incremental
- `page_size`: Controle de memória (padrão 200K linhas/página)

**Exemplo:**
```python
"principal_db": {
    "exclude": ["CLIENTE", "LINHA", ...],
    "filter": {
        "ITEM_PEDIDO": ["DT_INCLUSAO"],        # Filtra por data
        "TRANSACAO": ["DT_TRANSACAO"],         # Filtra por data
        "pcd_mae": ["count(*)"],               # Monitora contagem
    },
    "custom_select": {
        "CLIENTE_IMAGEM": """
            SELECT * FROM CLIENTE_IMAGEM
            WHERE ID_CLIENTE_IMAGEM IN (
                SELECT DISTINCT ID FROM ... WHERE {filter}
            )
        """
    }
}
```

### SERPRO (Autuações)

**Fluxo:**
1. Setup de certificado SSL dinâmico
2. Chamada SOAP com autenticação
3. Parsing XML → JSON
4. Upload incremental por data de autuação

**Redis:**
```python
redis_key = f"{env}.capture.serpro_autuacao.last_timestamp"
# Armazena: "2025-01-15 10:30:45"
```

---

## Recaptura e Tratamento de Falhas

### Recaptura Manual
```python
def flow(..., recapture=False, recapture_days=2, recapture_timestamps=None):
    """
    recapture=True → Ignora Redis, refaz captura dos últimos N dias
    recapture_timestamps=["2025-01-10", "2025-01-11"] → Datas específicas
    """
```

### Lógica de Retry
```python
# Cada task tem timeout e retry automático
@task(retries=2, retry_delay_seconds=60)
def get_raw_data(extractor):
    return extractor()
```

### Monitoramento
- Discord: Notificação de falhas (webhook)
- Sentry: Rastreamento de exceções
- Redis: Marca captura como "em progresso" (evita duplicação)

---

## Particionamento Hive

### Formato Padrão
```
gs://bucket/raw/{source_name}/{table_id}/data=YYYY-MM-DD/hora=HH/{timestamp}_*.json
```

### Configuração por Contexto
```python
# Apenas data
create_partition(timestamp, partition_date_only=True)
# → "data=2025-01-15"

# Data + hora
create_partition(timestamp, partition_date_only=False)
# → "data=2025-01-15/hora=10"
```

**Benefícios:**
- Pruning automático em BigQuery
- Leitura eficiente (apenas partições necessárias)
- Compatível com ferramentas Hive/Spark

---

## Rastreabilidade

### Colunas Injetadas Automaticamente

```json
{
    "id_veiculo": 123,
    "timestamp_registro": "2025-01-15T10:30:45Z",
    
    // Colunas SMTR
    "_smtr_timestamp_captura": "2025-01-15T10:35:00Z",  // Quando foi capturado
    "_smtr_fonte": "cittati",
    "_smtr_flow_run_id": "abc-def-123",
    "_smtr_partition": "data=2025-01-15/hora=10"
}
```

### Redis: Último Estado de Captura
```
{env}.capture.{source}_{table_id}.last_timestamp
→ "2025-01-15 10:35:00"

{env}.backup_jae_billingpay.{database}.{table}
→ {"last_backup_value": "2025-01-15 10:35:00"}
```

---

## Dependências Críticas

### Componentes Internos
- `pipelines.common.capture.default_capture` → Lógica base
- `pipelines.common.capture.gps` → Extrator GPS
- `pipelines.common.capture.jae` → Extrator JAE
- `pipelines.common.utils.extractors` → API/BD/FS
- `pipelines.common.utils.gcp` → Storage + BigQuery

### Dependências Externas
- **Prefect 3.4.8+** → Orquestração de workflows
- **SQLAlchemy** → Conexão com BD (JAE, SERPRO)
- **Pandas** → Transformação de dados
- **google-cloud-storage** → GCS API
- **google-cloud-bigquery** → BigQuery API

### Secrets (Secret Manager)
```
{env}.jae_credentials       → user, password
{env}.cittati_api           → guidIdentificacao
{env}.conecta_api           → credenciais
{env}.zirix_api             → credenciais
{env}.serpro_certificate    → arquivo .p12
```

---

## Checklist de Implementação

Para adicionar nova fonte de captura:

- [ ] Criar `pipelines/capture__{source}__{table}/` com:
  - `constants.py` (SourceTable)
  - `flow.py` (@flow decorator)
  - `prefect.yaml` (deployment config)
  - `Dockerfile`, `pyproject.toml`
  
- [ ] Implementar extrator em `pipelines/common/capture/{context}/tasks.py`
  - `create_{context}_extractor(context: SourceCaptureContext)`
  
- [ ] Configurar contexto no extrator
  - URL/endpoint
  - Autenticação (headers/cert)
  - Intervalo de captura
  
- [ ] Adicionar constants de contexto (se novo tipo)
  - Endpoints
  - Tipos de filtros incrementais
  
- [ ] Testar fluxo: raw → GCS → BigQuery
  
- [ ] Configurar Redis para estado de captura
  
- [ ] Deploy em staging → prod com agendamento