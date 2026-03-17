# Extractores API e DB

## Visão Geral

Extractores são componentes reutilizáveis que implementam a lógica de captura de dados de fontes externas (APIs e bancos de dados). Localizam-se em `pipelines/common/utils/extractors/` e são utilizados pelos pipelines de captura para extrair dados de forma padronizada e resiliente.

## Arquitetura

### Módulos

```
pipelines/common/utils/extractors/
├── __init__.py
├── api.py           # Extractores para APIs HTTP
└── db.py            # Extractores para bancos de dados
```

### Fluxo de Captura

```
┌─────────────────────────┐
│  Pipeline de Captura    │
│  (flow.py)              │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────┐
│  Task (create_*_extractor)      │
│  Retorna função parcial         │
└───────────┬─────────────────────┘
            │
            ▼
┌──────────────────────────────────────┐
│  get_raw_data (default_capture)      │
│  Executa a função parcial            │
└──────────────────────────────────────┘
```

## Extractores de API

### Módulo: `api.py`

Implementa extractores para consumo de APIs HTTP REST.

#### `get_raw_api(url, raw_filepath, params=None, headers=None, ...)`

Realiza uma única requisição GET à API e salva a resposta em arquivo JSON.

**Assinatura:**
```python
def get_raw_api(
    url: str,
    raw_filepath: str,
    params: Optional[dict] = None,
    headers: Optional[dict] = None,
    auth: Optional[tuple] = None,
    timeout: int = 30,
    verify_ssl: bool = True,
) -> str
```

**Parâmetros:**
- `url` (str): URL da API
- `raw_filepath` (str): Caminho para salvar o JSON
- `params` (dict, opcional): Parâmetros de query string
- `headers` (dict, opcional): Headers HTTP customizados
- `auth` (tuple, opcional): Tupla (user, password) para autenticação básica
- `timeout` (int): Timeout em segundos (padrão: 30)
- `verify_ssl` (bool): Validar certificado SSL (padrão: True)

**Retorno:**
- `str`: Caminho absoluto do arquivo salvo

**Exceções:**
- `requests.RequestException`: Erro na requisição HTTP
- `IOError`: Erro ao salvar arquivo

**Exemplo de Uso:**

```python
from functools import partial
from pipelines.common.utils.extractors.api import get_raw_api

# No task create_gps_extractor
extractor = partial(
    get_raw_api,
    url="https://api.cittati.com.br/rastreamentos",
    raw_filepath="/tmp/data/gps_registros.json",
    params={
        "dataInicial": "2025-01-20 10:00:00",
        "dataFinal": "2025-01-20 11:00:00",
    },
    headers={
        "Authorization": "Bearer token_xyz",
        "X-API-Key": "key_abc",
    },
)

# Na task get_raw_data
filepath = extractor()
```

#### `get_raw_api_list(url, raw_filepath, list_key, params=None, ...)`

Realiza requisições paginadas a uma API que retorna listas e concatena todos os resultados.

**Assinatura:**
```python
def get_raw_api_list(
    url: str,
    raw_filepath: str,
    list_key: str,
    params: Optional[dict] = None,
    headers: Optional[dict] = None,
    page_param: str = "page",
    page_size_param: str = "pageSize",
    page_size: int = 100,
    max_pages: int = 1000,
    timeout: int = 30,
) -> str
```

**Parâmetros Adicionais:**
- `list_key` (str): Chave JSON onde está o array de itens (ex: "data", "results")
- `page_param` (str): Nome do parâmetro de paginação (padrão: "page")
- `page_size_param` (str): Nome do parâmetro de tamanho da página (padrão: "pageSize")
- `page_size` (int): Itens por página (padrão: 100)
- `max_pages` (int): Limite máximo de páginas (padrão: 1000)

**Retorno:**
- `str`: Caminho do arquivo com todos os itens concatenados

**Comportamento:**
- Continua paginando enquanto a resposta contiver itens
- Para se atingir `max_pages`
- Valida presença de `list_key` em cada resposta

**Exemplo de Uso:**

```python
# API que retorna: {"results": [{...}, {...}], "total": 5000}
extractor = partial(
    get_raw_api_list,
    url="https://api.conecta.com.br/viagens",
    raw_filepath="/tmp/data/viagens_pendentes.json",
    list_key="results",
    params={
        "status": "pending",
        "operadora_id": 42,
    },
    page_param="page",
    page_size=500,
    max_pages=100,
)
```

#### `get_api_data(url, params=None, headers=None, ...)`

Realiza uma requisição sem salvar em arquivo. Retorna dict Python.

**Assinatura:**
```python
def get_api_data(
    url: str,
    params: Optional[dict] = None,
    headers: Optional[dict] = None,
    timeout: int = 30,
) -> dict
```

**Retorno:**
- `dict`: Resposta JSON parseada

**Uso:**
- Validações em tasks
- Integração com lógica Prefect complexa
- Pequenos volumes de dados

## Extractores de Banco de Dados

### Módulo: `db.py`

Implementa extractores para captura de dados de bancos de dados relacionais via SQLAlchemy.

#### `get_raw_db(query, raw_filepath, **db_config)`

Executa uma query SQL e salva resultado em arquivo JSON.

**Assinatura:**
```python
def get_raw_db(
    query: str,
    raw_filepath: str,
    engine: str,
    host: str,
    user: str,
    password: str,
    database: str,
    port: Optional[int] = None,
    **kwargs,
) -> str
```

**Parâmetros DB:**
- `engine` (str): Tipo de banco ("mysql", "postgresql", "mssql", "oracle")
- `host` (str): Host do servidor
- `user` (str): Usuário de acesso
- `password` (str): Senha de acesso
- `database` (str): Nome do banco de dados
- `port` (int, opcional): Porta (usa padrão do engine se não informado)

**Retorno:**
- `str`: Caminho do arquivo salvo

**Exemplo de Uso em Captura JAE:**

```python
# task create_ressarcimento_db_extractor
from datetime import datetime, timedelta
from functools import partial
from pipelines.common.utils.extractors.db import get_raw_db

def create_ressarcimento_db_extractor(context: SourceCaptureContext) -> partial:
    """Cria extractor para tabela de ordem_ressarcimento com filtro de data"""
    
    timestamp = context.timestamp
    last_timestamp = context.source.last_capture_timestamp  # do Redis
    
    query = f"""
    SELECT
        id,
        id_operadora,
        data_criacao,
        valor_total,
        status
    FROM ordem_ressarcimento
    WHERE data_criacao >= '{last_timestamp}'
        AND data_criacao < '{timestamp}'
    ORDER BY data_criacao
    """
    
    return partial(
        get_raw_db,
        query=query,
        raw_filepath=context.raw_filepath,
        engine="mysql",
        host="jae-db.internal",
        user="smtr_user",
        password=os.environ["JAE_PASSWORD"],
        database="ressarcimento_db",
    )
```

#### `get_raw_db_paginated(query, raw_filepath, page_size=200000, **db_config)`

Executa query em páginas, salvando múltiplos arquivos JSON.

**Assinatura:**
```python
def get_raw_db_paginated(
    query: str,
    raw_filepath: str,
    page_size: int = 200000,
    engine: str,
    host: str,
    user: str,
    password: str,
    database: str,
    **kwargs,
) -> list[str]
```

**Comportamento:**
- `raw_filepath` deve conter placeholder `{page}` (ex: `/tmp/data_{page}.json`)
- Retorna lista com todos os caminhos gerados
- Útil para grandes volumes para evitar memory overflow

**Retorno:**
- `list[str]`: Lista de caminhos dos arquivos gerados

**Exemplo de Uso em Backup BillingPay:**

```python
# task get_raw_backup_billingpay
filepaths = get_raw_db_paginated(
    query="""
    SELECT * FROM cliente_imagem
    WHERE dt_inclusao >= '2025-01-20 00:00:00'
        AND dt_inclusao < '2025-01-20 01:00:00'
    """,
    raw_filepath="/data/backup_billingpay/principal_db/cliente_imagem/data=2025-01-20/capture_{page}.json",
    page_size=50000,  # 50k linhas por arquivo
    engine="mysql",
    host="billingpay-prod.internal",
    user=db_config["user"],
    password=db_config["password"],
    database="principal_db",
)

# Resultado: 
# [
#   '/data/.../capture_0.json',    (50000 linhas)
#   '/data/.../capture_1.json',    (50000 linhas)
#   '/data/.../capture_2.json',    (linhas restantes)
# ]
```

#### `get_db_data(query, **db_config)`

Retorna dados sem salvar em arquivo. Retorna lista de dicts.

**Assinatura:**
```python
def get_db_data(
    query: str,
    engine: str,
    host: str,
    user: str,
    password: str,
    database: str,
    **kwargs,
) -> list[dict]
```

**Retorno:**
- `list[dict]`: Resultado da query como lista de dicionários

**Uso:**
- Queries de validação
- Cálculos de metadados
- Queries muito pequenas

**Exemplo:**

```python
# Obter ID máximo para determinar range de captura
max_result = get_db_data(
    query="SELECT MAX(id_ordem_pagamento) as max_id FROM ordem_pagamento",
    engine="mysql",
    host="jae-db.internal",
    user=secrets["user"],
    password=secrets["password"],
    database="ressarcimento_db",
)
max_id = max_result[0]["max_id"]
```

## Padrões de Uso

### 1. Extractor para Captura de GPS (API)

**Arquivo:** `pipelines/common/capture/gps/tasks.py`

```python
@task
def create_gps_extractor(context: SourceCaptureContext):
    """Cria extractor para GPS cittati/conecta/zirix"""
    
    source = context.source
    timestamp = context.timestamp.astimezone(timezone("UTC"))
    
    source_config = constants.GPS_SOURCE_CONFIGS[source.source_name]
    
    # Determina endpoint e range de datas
    if source.table_id == constants.REGISTROS_TABLE_ID:
        endpoint = source_config["registros_endpoint"]
        start = (timestamp - timedelta(minutes=6)).strftime("%Y-%m-%d %H:%M:%S")
        end = (timestamp - timedelta(minutes=5)).strftime("%Y-%m-%d %H:%M:%S")
    else:
        endpoint = source_config["realocacao_endpoint"]
        start = (timestamp - timedelta(minutes=10)).strftime("%Y-%m-%d %H:%M:%S")
        end = timestamp.strftime("%Y-%m-%d %H:%M:%S")
    
    url = f"{source_config['base_url']}/{endpoint}"
    headers = get_env_secret(source_config["secret_path"])
    
    return partial(
        get_raw_api,
        url=url,
        raw_filepath=context.raw_filepath,
        params={
            "guidIdentificacao": headers[next(iter(headers))],
            "dataInicial": start,
            "dataFinal": end,
        },
    )
```

### 2. Extractor para Captura JAE com Filtro Temporal

**Arquivo:** `pipelines/capture__jae_ordem_pagamento/tasks.py`

```python
@task
def create_ressarcimento_db_extractor(context: SourceCaptureContext):
    """Cria extractor incremental por timestamp"""
    
    source = context.source
    last_ts = context.last_capture_timestamp
    current_ts = context.timestamp
    
    query = f"""
    SELECT * FROM ordem_pagamento
    WHERE data_inclusao >= '{last_ts}'
        AND data_inclusao < '{current_ts}'
    ORDER BY data_inclusao
    """
    
    return partial(
        get_raw_db,
        query=query,
        raw_filepath=context.raw_filepath,
        engine="mysql",
        host="jae-db.internal",
        user=os.environ["JAE_USER"],
        password=os.environ["JAE_PASSWORD"],
        database="ressarcimento_db",
    )
```

### 3. Extractor para Backup Incremental (Paginado)

**Arquivo:** `pipelines/capture__jae_backup_billingpay/tasks.py`

```python
@task
def get_raw_backup_billingpay(table_info, database_config, timestamp):
    """Captura dados com paginação para backup"""
    
    new_table_info = []
    
    for table in table_info:
        # Constrói WHERE com base no tipo incremental
        if table["incremental_type"] == "datetime":
            where = " OR ".join([
                f"({col} >= '{table['last_capture']}' AND {col} < '{timestamp}')"
                for col in BACKUP_TABLES[table["table_name"]]["filter_columns"]
            ])
        else:
            where = f"id >= {table['last_capture']}"
        
        sql = f"SELECT * FROM {table['table_name']} WHERE {where}"
        
        # Executa com paginação
        filepaths = get_raw_db_paginated(
            query=sql,
            raw_filepath=table["filepath"],  # contém {page}
            page_size=50000,
            **database_config,
        )
        
        table["filepath"] = filepaths
        new_table_info.append(table)
    
    return new_table_info
```

## Tratamento de Erros

### Erros Comuns

| Erro | Causa | Solução |
|------|-------|---------|
| `requests.ConnectionError` | Host indisponível | Verificar conectividade, timeout de rede |
| `requests.Timeout` | Resposta muito lenta | Aumentar `timeout`, revisar query |
| `SQLAlchemy.OperationalError` | Credenciais/host inválido | Validar `db_config`, checar permissões |
| `JSONDecodeError` | Resposta não é JSON válido | Verificar formato da API, headers |
| `IOError` no `raw_filepath` | Diretório não existe | Usar `create_partition()` e garantir permissões |

### Retry e Resilência

Extractores delegam retry ao orquestrador Prefect via decoradores:

```python
from prefect import task

@task(
    retries=3,
    retry_delay_seconds=60,
    retry_jitter_factor=0.1,
)
def create_gps_extractor(context):
    # Task será retentada automaticamente
    ...
```

## Segurança

### Credenciais

Nunca embutir credenciais no código. Usar `get_env_secret()`:

```python
from pipelines.common.utils.secret import get_env_secret

# No task
secrets = get_env_secret("jae_database")
password = secrets["password"]

# No extractor
password=secrets["password"]  # Não: password="senha_hardcoded"
```

### SSL e Certificados

```python
# Produção: validar SSL
get_raw_api(url=url, verify_ssl=True)

# Desenvolvimento: desabilitar se necessário (não recomendado)
get_raw_api(url=url, verify_ssl=False)
```

## Integração com o Pipeline

### Fluxo Completo

```python
# flow.py
@flow
def capture__jae_ordem_pagamento():
    # Task que cria o extractor
    extractor = create_ressarcimento_db_extractor(
        context=...,
    )
    
    # Task que executa o extractor
    raw_data = get_raw_data(
        extractor=extractor,
        ...
    )
    
    # Tasks posteriores processam raw_data
    ...
```

### Monitoramento

Extractores registram:
- URL/query executada
- Número de linhas/registros
- Tempo de execução
- Erros e retries

Acessível via logs Prefect:

```bash
prefect flow-run logs <run-id>
```

## Referências

- **Módulos:** `pipelines/common/utils/extractors/api.py`, `db.py`
- **Uso em Capturas:** `pipelines/common/capture/gps/tasks.py`
- **Uso em Backup:** `pipelines/capture__jae_backup_billingpay/tasks.py`
- **Default Capture:** `pipelines/common/capture/default_capture/tasks.py`