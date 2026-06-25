# Padrão de Pipeline de Captura

## Visão Geral

Os pipelines de captura são responsáveis por extrair dados brutos de diversas fontes de dados e armazená-los no Data Lake (Google Cloud Storage). Cada pipeline segue um padrão arquitetural comum, adaptado para características específicas da fonte.

## Padrão Padrão de Captura

### Fluxo Geral

```
┌─────────────────────────────────────────────────────────┐
│ 1. Inicialização                                        │
│    - Setup de ambiente                                  │
│    - Configuração de credenciais                        │
│    - Inicialização de observabilidade (Sentry)          │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│ 2. Extração de Dados                                    │
│    - Conexão com fonte (API, DB, etc)                   │
│    - Paginação (se necessário)                          │
│    - Transformação mínima (nested structure)            │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│ 3. Armazenamento Local                                  │
│    - Salvamento em disco temporário                     │
│    - Formatação em arquivos JSON/Parquet                │
│    - Estrutura de pastas com partições Hive             │
└──────────────┬──────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────┐
│ 4. Upload para Cloud Storage                            │
│    - Envio para Google Cloud Storage                    │
│    - Manutenção de partições (data/hora)               │
│    - Registro no Redis (última captura)                 │
└─────────────────────────────────────────────────────────┘
```

### Componentes Principais

#### Flow Base: `create_capture_flows_default_tasks`

Orquestra o pipeline de captura com as seguintes responsabilidades:

1. **Contexto de Captura** (`SourceCaptureContext`)
   - Armazena metadados da fonte (nome, tabela, timestamp)
   - Calcula partições Hive automaticamente
   - Gerencia caminhos de arquivo

2. **Extração** (`get_raw_data`)
   - Chama a função extratora específica (API, DB, GPS)
   - Retorna dados brutos sem transformação estrutural
   - Registra metadados de captura (timestamp, quantidade de registros)

3. **Transformação Mínima** (`transform_raw_to_nested_structure`)
   - Normaliza estruturas simples para formato aninhado
   - Aplica pré-processamento (limpeza de texto, validações)
   - Mantém fidelidade aos dados originais

4. **Armazenamento Local** (`upload_raw_file_to_gcs` - primeira etapa)
   - Salva dados em arquivos particionados
   - Oferece suporte a múltiplos formatos (JSON, Parquet)
   - Calcula estatísticas de qualidade

5. **Upload para Cloud** (`upload_raw_file_to_gcs` - segunda etapa)
   - Transfere arquivos para GCS com metadados
   - Atualiza tabelas BigQuery de referência (`raw_*`)
   - Registra timestamp no Redis para próximas capturas

## Padrões por Tipo de Fonte

### 1. Captura de API (Padrão Padrão)

**Características:**
- Fonte externa via HTTP/REST
- Paginação automática
- Credenciais em variáveis de ambiente/secrets

**Exemplo:** `capture__rioonibus_viagem_informada`, `capture__serpro_autuacao`

**Fluxo:**
```python
@task
def create_extractor_task(context: SourceCaptureContext):
    return partial(
        get_raw_api,
        url="https://api.exemplo.com/dados",
        raw_filepath=context.raw_filepath,
        params={"chave": "valor"}
    )
```

**Recursos:**
- Suporte a paginação automática (`get_raw_api_list`)
- Retry automático em falhas
- Tratamento de rate limiting

### 2. Captura de GPS

**Características:**
- Três fornecedores: Cittati, Conecta, Zirix
- Dois tipos de dados por fornecedor:
  - **Registros**: posições de veículos em tempo real (5-6 minutos atrás)
  - **Realocação**: histórico de viagens retroativas (últimos 10 minutos)
- Credenciais específicas por fornecedor

**Fontes Mapeadas:**
- `capture__cittati_registros` / `capture__cittati_realocacao`
- `capture__conecta_registros` / `capture__conecta_realocacao`
- `capture__zirix_registros` / `capture__zirix_realocacao`

**Fluxo:**
```python
from pipelines.common.capture.gps.tasks import create_gps_extractor

@flow
def capture__[origem]_[tipo](env=None, timestamp=None, recapture=False):
    create_capture_flows_default_tasks(
        env=env,
        sources=[constants.[ORIGEM]_[TIPO]_SOURCE],
        timestamp=timestamp,
        create_extractor_task=create_gps_extractor,
        recapture=recapture
    )
```

**Configurações (em `pipelines/common/capture/gps/constants.py`):**

| Fornecedor | Registros | Realocação | Frequência |
|-----------|-----------|-----------|-----------|
| Cittati | EnvioRastreamentos | EnvioViagensRetroativasSMTR | A cada minuto |
| Conecta | envioSMTR | EnvioRealocacoesSMTR | A cada minuto |
| Zirix | EnvioIplan | EnvioViagensRetroativas | A cada minuto |

**Detalhes Técnicos:**
- Timestamp é convertida para UTC antes da requisição
- Janelas de tempo: registros (5-6 min atrás), realocação (até 10 min atrás)
- Credenciais armazenadas em secrets específicos por fornecedor
- Particiona por data apenas (sem granularidade horária)

### 3. Captura de Banco de Dados

**Características:**
- Conexão direta a bancos de dados internos
- Suporte a paginação por volume
- Carga incremental via Redis

**Exemplo:** `capture__jae_*` (diversos fluxos)

**Padrão Incremental:**
```python
# Primeira captura
timestamp_inicio = redis.get("ultima_captura") or data_inicial
timestamp_fim = timestamp_atual

query = f"SELECT * FROM tabela WHERE data >= '{timestamp_inicio}' AND data < '{timestamp_fim}'"
```

### 4. Backup Incremental (JAE BillingPay)

**Características:**
- Backup distribuído de múltiplos bancos de dados
- Estratégias diferentes por tipo de tabela:
  - **Com filtro datetime**: carga por janelas de tempo
  - **Com filtro integer**: carga por ID incremental
  - **Count-only**: validação de mudanças

**Pipeline Específico:** `capture__jae_backup_billingpay`

**Bancos Suportados:**
- principal_db, tarifa_db, transacao_db
- tracking_db, ressarcimento_db, gratuidade_db
- fiscalizacao_db, atm_gateway_db, device_db
- erp_integracao_db, atendimento_db
- gateway_pagamento_db, financeiro_db, midia_db
- processador_transacao_db, vendas_db

**Fluxo:**
1. Consultar Redis para última captura
2. Validar tabelas sem filtro configurado (alerta se > 5000 registros)
3. Extrair dados com WHERE adaptado ao tipo de filtro
4. Paginar resultados por volume de tabela
5. Upload para GCS
6. Atualizar Redis com novo valor de referência

## Arquivos de Configuração

### Constants (Padrão)

```python
# pipelines/capture__[origem]_[tipo]/constants.py

from pipelines.common.utils.gcp.bigquery import SourceTable

[ORIGEM]_[TIPO]_SOURCE = SourceTable(
    source_name="[origem]",           # cittati, conecta, zirix, jae, etc
    table_id="[tipo]",                # registros, realocacao, etc
    first_timestamp=datetime(...),    # Quando começou a captura
    flow_folder_name="capture__[origem]_[tipo]",
    primary_keys=["col1", "col2"],    # Para detectar duplicatas
    pretreatment_reader_args={...},   # Args para pandas.read_csv
    partition_date_only=True/False,   # Se particiona por data ou data/hora
)
```

### Prefect Deployment

```yaml
# pipelines/capture__[origem]_[tipo]/prefect.yaml

deployments:
  - name: rj-capture--[origem]_[tipo]--prod
    version: "{{ get-commit-hash.stdout }}"
    entrypoint: pipelines/capture__[origem]_[tipo]/flow.py:capture__[origem]_[tipo]
    schedules:
      - cron: "*/10 * * * *"          # A cada 10 minutos
        timezone: "America/Sao_Paulo"
      - cron: "0 * * * *"             # A cada hora (recaptura)
        timezone: "America/Sao_Paulo"
        parameters:
          recapture: true
          recapture_days: 2            # Recaptura 2 últimos dias
```

## Tratamento de Erros e Observabilidade

### Sentry Integration
- Inicializado no início de cada flow
- Captura exceções não tratadas
- Contexto automático de ambiente (dev/prod)

### Redis para Estado
```
Chave: {env}.{flow_type}.{database}.{table}
Valor: {
  "last_capture_value": "2025-01-15 10:30:00" # ou ID inteiro
}
```

### Discord Notifications
- Alertas para tabelas sem filtro (backup)
- Falhas críticas em capturas de APIs
- Estatísticas de volume capturado

## Recaptura

Mecanismo para re-extrair dados de períodos anteriores (útil para corrigir falhas):

```python
@flow
def capture__[origem]_[tipo](
    env=None,
    timestamp=None,
    recapture=False,
    recapture_days=2,
    recapture_timestamps=None
):
    create_capture_flows_default_tasks(
        recapture=recapture,              # Ativa modo recaptura
        recapture_days=recapture_days,    # Quantos dias atrás
        recapture_timestamps=recapture_timestamps  # Timestamps específicas
    )
```

### Lógica:
1. Se `recapture=True`, lista últimas `recapture_days` datas
2. Para cada data, executa extração como normal
3. Dados são salvos nas mesmas partições (sobrescrita segura)
4. Redis atualizado com novo valor máximo

## Estrutura de Dados no GCS

```
gs://rj-smtr-data-lake/[DATASET]/[TABLE]/data=[YYYY-MM-DD]/hora=[HH]/
├── [TIMESTAMP]_0.json
├── [TIMESTAMP]_1.json
└── [TIMESTAMP]_n.json

Exemplo:
gs://rj-smtr-data-lake/gps/cittati_registros/data=2025-01-15/hora=10/
├── 2025-01-15T10-30-00_000000_0.json
└── 2025-01-15T10-30-00_000000_1.json
```

## Interação com Tratamento (Treatment)

Após captura, pipelines de tratamento processam dados brutos:

```
┌─────────────────────────────────┐
│ Pipeline de Captura             │
│ (raw_* no BigQuery)             │
└────────────┬────────────────────┘
             │
             ▼
    ┌─────────────────────┐
    │ Aguarda dados       │
    │ (wait_data_sources) │
    └────────┬────────────┘
             │
             ▼
    ┌──────────────────────────┐
    │ Pipeline de Tratamento   │
    │ (dbt models)             │
    │ Materializa em tabelas   │
    └──────────────────────────┘
```

## Boas Práticas

### 1. Idempotência
- Pipelines devem ser seguros para re-execução
- Partições Hive garantem sobrescrita sem duplicação
- Primary keys detectam registros duplicados

### 2. Validação de Dados
- Verificar campos obrigatórios antes de upload
- Registrar schema esperado nas constants
- Alertar em desvios significativos de volume

### 3. Gerenciamento de Credenciais
- Sempre usar `get_env_secret()` para senhas/tokens
- Nunca hardcoding credenciais
- Rotar secrets regularmente

### 4. Documentação
- Cada pipeline deve documentar sua fonte em constants
- Explicar filtros e estratégias de carga
- Listar dependências de dados (outros pipelines)

---

**Última atualização:** Janeiro 2025  
**Responsável:** Equipe de Data Engineering (SMTR)  
**Contato:** [Especificar equipe/slack]