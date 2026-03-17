# Pipelines de Captura GPS

## Visão Geral

Documentação dos pipelines de captura de dados GPS das operadoras **Cittati**, **Conecta** e **Zirix**. Estes pipelines extraem dados de rastreamento veicular em tempo real e realocações de viagens retroativas.

## Arquitetura Geral

```
GPS Providers (Cittati, Conecta, Zirix)
         ↓
    API REST
         ↓
create_gps_extractor (task)
         ↓
get_raw_api (extração de dados)
         ↓
SourceCaptureContext (contexto de captura)
         ↓
GCS (particionado por data/hora)
```

## Fontes de Dados

### Cittati
- **Base URL**: `https://servicos.cittati.com.br/WSIntegracaoCittati/SMTR/v2`
- **Autenticação**: `guidIdentificacao` (secret: `cittati_api`)
- **Endpoints**:
  - `EnvioRastreamentos` (registros)
  - `EnvioViagensRetroativasSMTR` (realocações)

### Conecta
- **Base URL**: `https://ccomobility.com.br/webservices/binder/wsconecta`
- **Autenticação**: `guidIdentificacao` (secret: `conecta_api`)
- **Endpoints**:
  - `envioSMTR` (registros)
  - `EnvioRealocacoesSMTR` (realocações)

### Zirix
- **Base URL**: `https://integration.systemsatx.com.br/Globalbus/SMTR/V2`
- **Autenticação**: `guidIdentificacao` (secret: `zirix_api`)
- **Endpoints**:
  - `EnvioIplan` (registros)
  - `EnvioViagensRetroativas` (realocações)

## Pipelines

### capture__cittati_registros
Captura registros de GPS em tempo real da Cittati.

**Arquivo**: `pipelines/capture__cittati_registros/`

**Configuração**:
- **Tabela**: `registros`
- **Chaves primárias**: `[id_veiculo, datetime_servidor]`
- **Primeira execução**: 2025-05-09
- **Agendamento**:
  - Execução: a cada minuto (`* * * * *`)
  - Recaptura: a cada hora com `recapture=true`

**Flow**:
```python
capture__cittati_registros(
    env=None,
    timestamp=None,
    recapture=False,
    recapture_days=2,
    recapture_timestamps=None,
)
```

### capture__cittati_realocacao
Captura realocações de viagens retroativas da Cittati.

**Arquivo**: `pipelines/capture__cittati_realocacao/`

**Configuração**:
- **Tabela**: `realocacao`
- **Chaves primárias**: `[id_veiculo, datetime_processamento]`
- **Primeira execução**: 2025-05-09
- **Agendamento**:
  - Execução: a cada 10 minutos (`*/10 * * * *`)
  - Recaptura: a cada hora com `recapture=true`

### capture__conecta_registros
Captura registros de GPS em tempo real da Conecta.

**Arquivo**: `pipelines/capture__conecta_registros/`

**Configuração**:
- **Tabela**: `registros`
- **Chaves primárias**: `[id_veiculo, datetime_servidor]`
- **Primeira execução**: 2025-05-09
- **Agendamento**: Idêntico ao Cittati

### capture__conecta_realocacao
Captura realocações de viagens retroativas da Conecta.

**Arquivo**: `pipelines/capture__conecta_realocacao/`

**Configuração**:
- **Tabela**: `realocacao`
- **Chaves primárias**: `[id_veiculo, datetime_processamento]`
- **Primeira execução**: 2025-05-09
- **Agendamento**: Idêntico ao Cittati

### capture__zirix_registros
Captura registros de GPS em tempo real da Zirix.

**Arquivo**: `pipelines/capture__zirix_registros/`

**Configuração**:
- **Tabela**: `registros`
- **Chaves primárias**: `[id_veiculo, datetime_servidor]`
- **Primeira execução**: 2025-05-09
- **Agendamento**: Idêntico ao Cittati

### capture__zirix_realocacao
Captura realocações de viagens retroativas da Zirix.

**Arquivo**: `pipelines/capture__zirix_realocacao/`

**Configuração**:
- **Tabela**: `realocacao`
- **Chaves primárias**: `[id_veiculo, datetime_processamento]`
- **Primeira execução**: 2025-05-09
- **Agendamento**: Idêntico ao Cittati

## Fluxo de Execução

### 1. Inicialização
```python
@flow(log_prints=True, flow_run_name=rename_capture_flow_run)
def capture__[fonte]_[tipo](
    env=None,
    timestamp=None,
    recapture=False,
    recapture_days=2,
    recapture_timestamps=None,
)
```

### 2. Extração de Dados
A task `create_gps_extractor` computa os parâmetros da API:

**Para registros**:
- `dataInicial`: timestamp - 6 minutos
- `dataFinal`: timestamp - 5 minutos

**Para realocações**:
- `dataInicial`: timestamp - 10 minutos
- `dataFinal`: timestamp

### 3. Armazenamento
Os dados são salvos em GCS com particionamento:
- **Padrão**: `data=YYYY-MM-DD/hora=HH/`
- **Estrutura**: JSON nested (processado pelo `transform_to_nested_structure`)

### 4. Processamento de Metadados
- Timestamp de captura adicionada
- Normalização de texto (uppercase → lowercase)
- Validação de colunas obrigatórias

## Tratamento (Treatment)

O pipeline de tratamento `treatment__gps_validador` consome estes dados e:
1. Valida integridade dos registros GPS
2. Detecta outliers de velocidade/localização
3. Materializa em tabelas de monitoramento
4. Alimenta dashboards operacionais

## Dependências

### Internas
- `pipelines.common.capture.default_capture.flow` → `create_capture_flows_default_tasks`
- `pipelines.common.capture.gps.tasks` → `create_gps_extractor`
- `pipelines.common.utils.extractors.api` → `get_raw_api`
- `pipelines.common.utils.secret` → `get_env_secret`
- `pipelines.common.utils.gcp.bigquery` → `SourceTable`

### Externas
- **Prefect**: Flow orchestration, runtime context
- **SQLAlchemy**: Database utilities
- **Google Cloud Storage**: Armazenamento de dados brutos

## Operação

### Deployments

Cada pipeline possui dois deployments:

**Staging**:
```yaml
name: rj-capture--[fonte]_[tipo]--staging
entrypoint: pipelines/capture__[fonte]_[tipo]/flow.py:capture__[fonte]_[tipo]
work_pool: smtr-pool
image: ghcr.io/rj-smtr/pipelines_v3/deployments:capture__[fonte]_[tipo]-<commit-hash>
```

**Production**:
```yaml
name: rj-capture--[fonte]_[tipo]--prod
schedules:
  - cron: [schedule]
    timezone: America/Sao_Paulo
    parameters: [env parameters]
```

### Recaptura

Acionada automaticamente a cada hora em produção:
- Padrão: últimos 2 dias
- Customizável via parâmetro `recapture_timestamps`
- Útil para corrigir falhas intermitentes de API

### Monitoramento

Cada pipeline registra:
- Timestamp de agendamento
- Quantidade de registros capturados
- Tamanho de arquivo salvo
- Erros de API ou validação

Alertas via Sentry em caso de falha na execução.

## Troubleshooting

### API Indisponível
1. Verificar conectividade com endpoint da operadora
2. Validar credenciais em `get_env_secret()`
3. Consultar logs do Prefect

### Dados Vazios
1. Confirmar se há dados no intervalo de tempo (6-10 min atrás)
2. Verificar se a operadora está transmitindo
3. Revisar logs da task `create_gps_extractor`

### Particionamento Incorreto
1. Confirmar timezone em `pipelines.common.constants.TIMEZONE`
2. Validar formato de timestamp em `create_partition()`
3. Verificar se `partition_date_only` está correto

## Histórico de Mudanças

**v1.0** (2025-05-09)
- Adição de suporte a Cittati, Conecta e Zirix
- Refatoração de extrator GPS em módulo `pipelines.common.capture.gps`
- Compartilhamento de constants entre operadoras
- Suporte a recaptura automática