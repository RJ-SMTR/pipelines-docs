# Fluxo de Tratamento (dbt + Testes + Redis)

## Visão Geral

O fluxo de tratamento (materialização) é responsável pela transformação de dados brutos em modelos analíticos usando dbt, execução de testes de qualidade e atualização de estado em Redis. O componente central é a tarefa `wait_data_sources`, que implementa a lógica de aguardar dados suficientes antes de iniciar a materialização.

## Arquitetura do Fluxo

### Componentes Principais

```
Treatment Flow
├── wait_data_sources ← [NOVO - Dependência crítica]
├── run_dbt_selectors
├── run_dbt_snapshots
├── run_dbt_tests
├── dbt_test_notify_discord
└── save_materialization_datetime_redis
```

## wait_data_sources: Lógica de Orquestração

### Responsabilidades

A tarefa `wait_data_sources` implementa o padrão de "sensor" para garantir que dados capturados estejam disponíveis no BigQuery antes da materialização:

- **Aguarda completude de fontes**: Verifica timestamps em Redis para confirmar que pipelines de captura finalizaram
- **Calcula intervalo de processamento**: Determina qual período de dados será materializado baseado no schedule (cron) do tratamento
- **Valida disponibilidade**: Consulta BigQuery para confirmar existência de dados no intervalo esperado
- **Falha rápido se incompleto**: Lança `IncompleteDataError` se dados não estão prontos, permitindo retry automático

### Assinatura

```python
@task
def wait_data_sources(
    context: DBTSelectorMaterializationContext,
    sources: list[str],
    timeout_minutes: int = 60,
) -> DBTSelectorMaterializationContext
```

### Fluxo de Execução

#### 1. Cálculo de Intervalo de Processamento

```python
# Baseado no schedule cron do tratamento
# Exemplo: treatment__viagem_informada roda a cada hora
last_materialized = context.get_last_materialized_datetime()
next_schedule = context.get_next_schedule_datetime(last_materialized)
datetime_start = context.get_datetime_start(last_materialized)
datetime_end = context.get_datetime_end(next_schedule)
```

- `datetime_start`: Última data/hora materializada (ou fallback configurado)
- `datetime_end`: Próxima execução do schedule
- Intervalo define o escopo de dados a serem processados

#### 2. Verificação em Redis (Captura)

```python
for source in sources:
    redis_key = f"{env}.capture__{source}.last_materialized"
    last_capture = redis_client.get(redis_key)
    
    if last_capture < datetime_start:
        raise IncompleteDataError(
            f"Source {source} last captured at {last_capture}, "
            f"but treatment needs {datetime_start}"
        )
```

Cada fonte de captura atualiza sua chave Redis ao finalizar (`save_materialization_datetime_redis`).

#### 3. Validação em BigQuery

```python
# Exemplo para viagem_informada
query = f"""
    SELECT COUNT(*) as row_count
    FROM `{project}.monitoramento.viagem_informada`
    WHERE data_hora BETWEEN '{datetime_start}' AND '{datetime_end}'
"""
result = query_bq(query)

if result['row_count'] == 0:
    raise IncompleteDataError(f"No data in {datetime_start} to {datetime_end}")
```

Confirma que dados estão no data warehouse no intervalo esperado.

#### 4. Timeout e Retry

- Timeout padrão: 60 minutos
- Prefect retry policy (configurável em `treatment__*.flow`): tipicamente 3 tentativas com backoff exponencial
- Logs de diagnóstico em cada falha

### Dependências e Contexto

A tarefa recebe `DBTSelectorMaterializationContext`, que encapsula:

```python
class DBTSelectorMaterializationContext:
    selector: DBTSelector          # Define models/tests a executar
    env: str                       # prod | dev
    dataset_id: str                # schema BigQuery (ex: "monitoramento")
    project_id: str                # GCP project
    dbt_vars: dict                 # Variáveis para dbt run
    datetime_start: datetime       # Início do intervalo
    datetime_end: datetime         # Fim do intervalo
    materialization_cron: str      # Schedule do flow (ex: "0 * * * *")
    
    # Métodos auxiliares
    def _get_redis_key() -> str
    def _get_schedule_cron() -> str
    def get_last_materialized_datetime() -> datetime
    def get_next_schedule_datetime(last_mat) -> datetime
    def get_datetime_start(last_mat) -> datetime
    def get_datetime_end(next_sched) -> datetime
    def is_up_to_date() -> bool
    def adjust_datetime_range(start, end) -> tuple
```

## Integração com dbt

### Fluxo Sequencial

```
wait_data_sources
    ↓
run_dbt_selectors (run)
    ↓
run_dbt_snapshots (snapshot)
    ↓
run_dbt_tests
    ├─→ success → save_materialization_datetime_redis
    └─→ failure → dbt_test_notify_discord → raise DBTTestFailedError
```

### Tarefa: run_dbt_selectors

```python
@task
def run_dbt_selectors(
    context: DBTSelectorMaterializationContext,
) -> DBTSelectorMaterializationContext
```

- Executa `dbt run --selector <selector_name> --vars <dbt_vars>`
- Materializa models (tables/views) no BigQuery
- Popula `dbt_vars` com `datetime_start` e `datetime_end` para filtros SQL
- Retorna contexto atualizado com metadados da run

### Tarefa: run_dbt_snapshots

```python
@task
def run_dbt_snapshots(
    context: DBTSelectorMaterializationContext,
) -> DBTSelectorMaterializationContext
```

- Executa `dbt snapshot` para modelos configurados
- Mantém histórico de mudanças em dimensões lentamente mutáveis (SCD Type 2)

### Tarefa: run_dbt_tests

```python
@task
def run_dbt_tests(
    context: DBTSelectorMaterializationContext,
) -> DBTSelectorMaterializationContext
```

- Executa `dbt test` para validar integridade dos dados materializados
- Falhas causam parada imediata
- Saída é parseada para extrair testes falhados (classe `DBTTest`)

## Notificação e Persistência

### Tarefa: dbt_test_notify_discord

```python
@task
def dbt_test_notify_discord(
    context: DBTSelectorMaterializationContext,
    failed_tests: list[DBTTest],
)
```

Envia mensagem formatada para canal Discord com:
- Nome do flow
- Modelos afetados
- Descrição dos testes falhados
- Link para logs no Prefect

### Tarefa: save_materialization_datetime_redis

```python
@task
def save_materialization_datetime_redis(
    context: DBTSelectorMaterializationContext,
)
```

Atualiza Redis com sucesso da materialização:

```python
redis_key = f"{env}.treatment__{dataset_id}.last_materialized"
redis_client.set(redis_key, context.datetime_end.isoformat())
```

Usado por `wait_data_sources` de outros treatments downstream.

## Classe: DBTSelectorMaterializationContext

### Atributos Principais

```python
class DBTSelectorMaterializationContext:
    selector: DBTSelector                    # Qual selector rodar
    env: str                                 # prod | staging
    dataset_id: str                          # Nome do schema
    project_id: str                          # GCP project
    dbt_vars: dict                           # Vars para dbt
    datetime_start: datetime                 # Início do intervalo
    datetime_end: datetime                   # Fim do intervalo
    materialization_cron: str                # Cron do schedule
```

### Métodos de Contexto Temporal

#### `get_last_materialized_datetime()`

Consulta Redis ou retorna fallback:

```python
redis_key = self._get_redis_key()
last_mat = redis_client.get(redis_key)
if last_mat is None:
    # Fallback: 7 dias atrás
    return datetime.now() - timedelta(days=7)
return datetime.fromisoformat(last_mat)
```

#### `get_next_schedule_datetime(last_materialized)`

Calcula próxima execução do cron:

```python
cron = self._get_schedule_cron()
next_run = cron_get_next_date(
    last_date=last_materialized,
    cron=cron,
    tz=TIMEZONE
)
return next_run
```

Usa utilitários `croniter` para parsing do cron.

#### `get_datetime_start(last_materialized)` e `get_datetime_end(next_schedule)`

Ajusta intervalo com regras de negócio:

```python
# Exemplo: viagem_informada materializa últimas 6 horas
start = last_materialized
end = next_schedule

if self.dataset_id == "monitoramento":
    start, end = adjust_datetime_range(start, end, lookback_hours=6)

return start, end
```

## Tratamento de Erros

### IncompleteDataError

```python
class IncompleteDataError(Exception):
    """Levantada quando fontes não têm dados prontos"""
    pass
```

Cenários:
- Captura de fonte não completou no intervalo esperado
- BigQuery ainda não tem dados (latência de ingestão)
- Janela de observação não tem registros (esperado em horas vagas)

**Ação**: Prefect re-executa o flow com backoff automático (padrão: 3 tentativas em 5 minutos).

### DBTTestFailedError

```python
class DBTTestFailedError(Exception):
    """Levantada quando testes dbt falharam"""
    pass
```

Cenários:
- Violação de `not_null` em coluna obrigatória
- Duplicação de `unique_key`
- Falha em teste customizado (ex: `test_greater_than_zero`)

**Ação**: Flow para, mensagem é enviada para Discord, falha é registrada em logs.

## Integração com Redis

### Chaves de Estado

```
{env}.capture__{source_name}.last_materialized
    └─ Usado por: wait_data_sources (leitura)
    └─ Escrito por: captura (save_materialization_datetime_redis)

{env}.treatment__{dataset_id}.last_materialized
    └─ Usado por: wait_data_sources de outros treatments
    └─ Escrito por: save_materialization_datetime_redis
```

### Padrão de Data

```python
MATERIALIZATION_LAST_RUN_PATTERN = "%Y-%m-%d %H:%M:%S"
# Exemplo: "2025-01-15 14:30:00"
```

## Fluxo de Exemplo: treatment__viagem_informada

### Configuração

```python
@flow
def treatment__viagem_informada():
    context = create_materialization_contexts(
        selector="viagem_informada",
        dataset_id="monitoramento",
        materialization_cron="0 * * * *",  # A cada hora
    )
    
    # Aguarda dados de captura
    context = wait_data_sources(
        context=context,
        sources=["rioonibus_viagem_informada"],
    )
    
    # Materializa modelos
    context = run_dbt_selectors(context)
    context = run_dbt_snapshots(context)
    
    # Testa integridade
    context = run_dbt_tests(context)
    
    # Persiste sucesso
    save_materialization_datetime_redis(context)
```

### Cronograma

```
13:00 → Captura: rioonibus_viagem_informada captura dados de 12:55-13:00
13:05 → Salva em Redis: capture__rioonibus_viagem_informada.last_materialized = 13:00
14:00 → Treatment começa (cron "0 * * * *")
14:01 → wait_data_sources:
        - last_materialized (treatment) = 13:00
        - next_schedule (treatment) = 14:00
        - verifica Redis: capture__ = 13:00 ✓
        - verifica BQ: dados em [13:00, 14:00) ✓
14:05 → run_dbt_selectors com dbt_vars = {datetime_start: 13:00, datetime_end: 14:00}
14:10 → run_dbt_tests
14:15 → save_materialization_datetime_redis: treatment = 14:00
```

## Dependências de Código

### Arquivos-Chave

- `pipelines/common/treatment/default_treatment/tasks.py`: Implementação de tasks
- `pipelines/common/treatment/default_treatment/utils.py`: Classes `DBTSelectorMaterializationContext`, `IncompleteDataError`
- `pipelines/common/utils/cron.py`: `cron_get_next_date`, `cron_get_last_date`
- `pipelines/common/utils/redis.py`: `get_redis_client`
- `pipelines/common/tasks.py`: `query_bq`, `task_send_discord_message`

### Variáveis de Ambiente

```
PREFECT__CLOUD__API_URL=https://api.prefect.cloud/api
PREFECT__CLOUD__ACCOUNT_ID=...
REDIS_HOST=redis-server
REDIS_PORT=6379
GCP_PROJECT_ID=rj-smtr
BQ_DATASET_RAW=dados_brutos
```

## Monitoramento e Diagnóstico

### Logs de Sucesso

```
✓ wait_data_sources: dados prontos em [2025-01-15 13:00, 14:00)
✓ run_dbt_selectors: 12 models materializados em 4m23s
✓ run_dbt_snapshots: 2 snapshots atualizados
✓ run_dbt_tests: 45 testes passaram
✓ save_materialization_datetime_redis: treatment__viagem_informada = 2025-01-15 14:00:00
```

### Logs de Falha

```
✗ wait_data_sources: IncompleteDataError
  Motivo: Captura rioonibus_viagem_informada aguardando dados
  Redis: capture__rioonibus_viagem_informada.last_materialized = 2025-01-15 12:30:00
  Esperado: >= 2025-01-15 13:00:00
  Retry em 5 minutos (tentativa 2/3)
```

## Relacionamentos com Captura

O fluxo de tratamento não executa captura; depende dela via Redis e BigQuery:

```
Capture Flow (hourly)
    ├─ Extrai dados de fonte externa
    ├─ Salva em BigQuery (raw)
    └─ Atualiza Redis: capture__X.last_materialized

Treatment Flow (hourly, offset +1h)
    ├─ wait_data_sources verifica Redis e BigQuery
    ├─ Executa dbt run/snapshot/test
    └─ Atualiza Redis: treatment__Y.last_materialized
```

**Nota**: Delay entre captura e tratamento evita condições de corrida (race conditions).