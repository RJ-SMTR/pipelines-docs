# Fontes de Dados

## Visão Geral

Este documento descreve as principais fontes de dados capturadas pela plataforma SMTR, com ênfase em timestamps, particionamento e estratégias de carga incremental.

## JAE (Jornada Eletrônica)

### Definição

JAE é o sistema de billing e transações do transporte público do Rio de Janeiro, mantido pela operadora BillingPay. Concentra dados operacionais, financeiros e de gratuidade.

### Tabelas Principais

#### Transações
- **Tabela**: `transacao`, `transacao_riocard`, `transacao_retificada`
- **Fonte**: `transacao_db` (BillingPay)
- **Chaves Primárias**: `id`, `id_ordem_ressarcimento`, `data_processamento`, `data_transacao`
- **Timestamp**: `data_processamento`, `data_transacao`
- **Particionamento**: `data` (data apenas)
- **Frequência de Captura**: Contínua
- **Pipeline**: `capture__jae_transacao*`

#### Lançamentos e Erros
- **Tabela**: `lancamento`, `transacao_erro`
- **Fonte**: `processador_transacao_db` e `principal_db`
- **Timestamp**: `dt_inclusao`, `data_inclusao`
- **Particionamento**: `data` (data apenas)
- **Frequência**: Horária
- **Pipeline**: `capture__jae_lancamento`, `capture__jae_transacao_erro`

#### Ordens de Pagamento
- **Tabela**: `ordem_pagamento`, `ordem_ressarcimento`
- **Fonte**: `ressarcimento_db`
- **Timestamp**: `dt_inclusao`, `data_inclusao`
- **Particionamento**: `data` (data e hora)
- **Frequência**: Horária
- **Pipeline**: `capture__jae_ordem_pagamento`

#### Auxiliares
- **Tabela**: Tabelas de suporte operacional
- **Fonte**: `principal_db`
- **Timestamp**: `dt_inclusao`, `dt_inclusao`
- **Frequência**: Diária
- **Pipeline**: `capture__jae_auxiliar`

#### Integrações
- **Tabela**: `matriz_integracao`
- **Fonte**: `tarifa_db`
- **Timestamp**: `dt_inclusao`
- **Particionamento**: `data` (data apenas)
- **Frequência**: Diária
- **Pipeline**: `capture__jae_integracao`

### Backup Incremental BillingPay

O sistema de backup incremental mantém sincronização entre BillingPay e GCP através de checkpoints em Redis.

#### Estratégia de Particionamento

- **Por Data**: `data=YYYY-MM-DD`
- **Armazenamento**: `backup_jae_billingpay/{database_name}/{table_name}/{data}/`
- **Naming**: `{timestamp}_*.json` (múltiplas páginas por tabela)

#### Tipo de Carga

**Datetime** (padrão para filtros de data):
```python
WHERE column_name >= '{last_capture}' AND column_name < '{current_timestamp}'
```
- Armazenado em Redis: `{env}.backup_jae_billingpay.{database_name}.{table_name}`
- Padrão: `YYYY-MM-DD HH:MM:SS`

**Integer** (para ID sequenciais):
```python
WHERE column_id BETWEEN {last_id} AND {max_id}
```
- Último valor (max_id) sincronizado em Redis
- Apropriado para tabelas com incremento apenas em IDs

**Count** (para validação de integridade):
- Comparação de total de registros
- Notifica Discord se houver tabelas sem filtro com >5000 registros

#### Configuração de Bancos de Dados

| Base | Tabelas | Filtro Primário | Frequência | Pipeline |
|------|---------|-----------------|-----------|----------|
| `principal_db` | CLIENTE, PEDIDO, ITEM_PEDIDO | `dt_inclusao`, `dt_conclusao_pedido` | 1h | `capture__jae_backup_billingpay` |
| `tarifa_db` | matriz_integracao | `dt_inclusao` | 6h | `capture__jae_backup_billingpay` |
| `transacao_db` | confirmacao_envio_pms | `data_confirmacao` | 6h | `capture__jae_backup_billingpay` |
| `tracking_db` | tracking_sumarizado | `ultima_data_tracking` | 6h | `capture__jae_backup_billingpay` |
| `ressarcimento_db` | item_ordem_transferencia | `data_inclusao` | 6h | `capture__jae_backup_billingpay` |
| `gratuidade_db` | gratuidade, estudante, laudo_pcd | `data_inclusao` | 6h | `capture__jae_backup_billingpay` |
| `midia_db` | midia, midia_cliente | `dt_gravacao`, `dt_associacao` | 6h | `capture__jae_backup_billingpay` |
| `financeiro_db` | movimento, conta, lote_credito | `dt_movimento`, `dt_lancamento` | 6h | `capture__jae_backup_billingpay` |

## GPS (Localização de Veículos)

### Operadores Suportados

| Operador | Fonte | Registros | Realocação | Endpoints |
|----------|-------|-----------|-----------|-----------|
| **Cittati** | cittati_api | 1 min | Retroativa | EnvioRastreamentos / EnvioViagensRetroativasSMTR |
| **Conecta** | conecta_api | 1 min | Retroativa | envioSMTR / EnvioRealocacoesSMTR |
| **Zirix** | zirix_api | 1 min | Retroativa | EnvioIplan / EnvioViagensRetroativas |

### Registros (Rastreamento Contínuo)

- **Tabela**: `registros`
- **Timestamp**: `datetime_servidor`
- **Chave Primária**: `id_veiculo`, `datetime_servidor`
- **Particionamento**: `data/hora` (data e hora)
- **Frequency**: A cada 1 minuto
- **Window**: Últimos 6 minutos
- **Latência**: ~1 minuto
- **Pipelines**: 
  - `capture__cittati_registros`
  - `capture__conecta_registros`
  - `capture__zirix_registros`

### Realocação (Viagens Retroativas)

- **Tabela**: `realocacao`
- **Timestamp**: `datetime_processamento`
- **Chave Primária**: `id_veiculo`, `datetime_processamento`
- **Particionamento**: `data` (data apenas)
- **Frequência**: A cada 10 minutos
- **Window**: Até timestamp atual
- **Latência**: ~5-10 minutos
- **Pipelines**:
  - `capture__cittati_realocacao`
  - `capture__conecta_realocacao`
  - `capture__zirix_realocacao`

### Autenticação

Cada operador possui credencial específica armazenada em `Secrets`:
```
{source_name}_api: {
  "{key_name}": "identificador_api"
}
```

Usada como `guidIdentificacao` no header de requisições.

## Billing (Bilhetagem)

### Fontes Primárias

#### Transações de Bilhetagem
- **Tabela**: `transacao`, `transacao_riocard`
- **Fonte**: `transacao_db` (BillingPay)
- **Chaves**: `id_cliente`, `data_transacao`, `id_cartao`
- **Timestamp**: `data_transacao`
- **Particionamento**: `data` (data apenas)
- **Frequência**: Contínua
- **Pipeline**: `capture__jae_transacao*`

#### Extratos de Cliente
- **Tabela**: `movimento` (financeiro_db)
- **Timestamp**: `dt_movimento`
- **Particionamento**: `data` (data apenas)
- **Frequência**: Horária
- **Pipeline**: `treatment__extrato_cliente_cartao`

### Tratamento de Erros

#### Transações com Erro
- **Tabela**: `transacao_erro`
- **Fonte**: `processador_transacao_db`
- **Timestamp**: `dt_inclusao`
- **Particionamento**: `data` (data apenas)
- **Frequência**: Horária
- **Pipeline**: `capture__jae_transacao_erro` → `treatment__transacao_erro`

#### Itens Pendentes
- **Reprocessamento**: Via `capture__jae_transacao_retificada`
- **Retenção**: Últimos 7 dias
- **SLA**: Máximo 24h para resolução

## Validação de Integridade

### Checkpoint em Redis

Cada fonte mantém registro do último timestamp capturado:

```
{env}.{source_type}.{source_name}.last_capture: "YYYY-MM-DD HH:MM:SS"
```

Exemplos:
- `prod.capture.jae_transacao.last_capture`
- `prod.backup_jae_billingpay.principal_db.cliente.last_capture`
- `prod.capture.cittati_registros.last_capture`

### Monitoramento

**Freshness Check** (controle__source_freshness):
- Valida atraso máximo de cada fonte
- Notifica Discord em caso de atraso > threshold
- Frequência: 5 em 5 minutos

**Data Quality**:
- Testes dbt para completude, unicidade e ranges
- Validação de valores esperados (ex: km planejado > 0)
- Notificação automática em falhas críticas

## Particionamento Padrão

### Estrutura Hive

```
gs://bucket/{dataset}/{table}/data={YYYY-MM-DD}/[hora={HH}/]{timestamp}_{batch}.parquet
```

### Estratégias por Tipo

| Tipo | Formato | Exemplo | Caso de Uso |
|------|---------|---------|------------|
| **Data apenas** | `data=YYYY-MM-DD` | Transações diárias | Billing, Ordens |
| **Data + Hora** | `data=YYYY-MM-DD/hora=HH` | Registros horários | GPS, Monitoramento |
| **Data + Minuto** | Não usado (considerar) | - | Casos de alta frequência |

### Nomeação de Arquivo

```
{YYYYMMDD}T{HHMMSS}_{batch_index}.parquet
Exemplo: 20250316T143022_001.parquet
```

## Fluxo de Captura

```
┌─────────────┐
│   Fonte     │
│  (JAE/GPS)  │
└──────┬──────┘
       │
       ▼
┌──────────────────────┐
│  Extract Raw Data    │
│  (com timestamp)     │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Validate & Format   │
│  (pretreatment)      │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Partition & Upload  │
│  para GCS            │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Update Redis        │
│  (last_capture)      │
└──────────────────────┘
```

## Referências e Dependências

- **Timestamps**: Usar sempre `America/Sao_Paulo` como timezone padrão
- **Retenção**: Mínimo 2 anos (configurável por fonte)
- **Documentação dbt**: `queries/models/sources.yml` (catálogo de fontes)
- **Monitoring**: Integração com Discord + Sentry
- **Secrets**: Infisical (`pipelines/common/utils/secret.py`)