# Fluxos de Captura GPS

Este documento descreve os fluxos de captura de dados GPS implementados na plataforma SMTR, incluindo as novas fontes de dados (Cittati, Conecta, Zirix) e o backup de dados BillingPay.

## Visão Geral

Os fluxos de captura GPS coletam dados de posicionamento veicular em tempo próximo ao real de múltiplas operadoras. A arquitetura suporta:

- **Captura de registros GPS** (posições instantâneas)
- **Captura de realocações** (viagens retroativas)
- **Backup incremental** de dados de bilhetagem (BillingPay)

## Fontes de Dados GPS

### Cittati

**Endpoints:**
- `EnvioRastreamentos` — registros de GPS (atualizações a cada ~5 minutos)
- `EnvioViagensRetroativasSMTR` — viagens retroativas

**Características:**
- Base URL: `https://servicos.cittati.com.br/WSIntegracaoCittati/SMTR/v2`
- Autenticação via `guidIdentificacao` (header)
- Granularidade temporal: minuto

**Fluxos:**
- `capture__cittati_registros` — executa a cada minuto, captura registros dos últimos 6 minutos
- `capture__cittati_realocacao` — executa a cada 10 minutos, captura viagens dos últimos 10 minutos

### Conecta

**Endpoints:**
- `envioSMTR` — registros de GPS
- `EnvioRealocacoesSMTR` — viagens retroativas

**Características:**
- Base URL: `https://ccomobility.com.br/webservices/binder/wsconecta`
- Autenticação via `guidIdentificacao` (header)
- Granularidade temporal: minuto

**Fluxos:**
- `capture__conecta_registros` — executa a cada minuto, captura registros dos últimos 6 minutos
- `capture__conecta_realocacao` — executa a cada 10 minutos, captura viagens dos últimos 10 minutos

### Zirix

**Endpoints:**
- `EnvioIplan` — registros de GPS
- `EnvioViagensRetroativas` — viagens retroativas

**Características:**
- Base URL: `https://integration.systemsatx.com.br/Globalbus/SMTR/V2`
- Autenticação via `guidIdentificacao` (header)
- Granularidade temporal: minuto

**Fluxos:**
- `capture__zirix_registros` — executa a cada minuto, captura registros dos últimos 6 minutos
- `capture__zirix_realocacao` — executa a cada 10 minutos, captura viagens dos últimos 10 minutos

## Estrutura Técnica - Fluxos GPS

Todos os fluxos GPS utilizam a arquitetura padrão de captura:

```
create_gps_extractor()
    ↓
get_raw_api() → [requisição HTTP]
    ↓
upload_raw_file_to_gcs() → raw/
    ↓
transform_raw_to_nested_structure() → source/
    ↓
upload_source_data_to_gcs() → source/
```

### Task: create_gps_extractor

Cria a função de extração baseada em:
1. **Fonte de dados** (cittati, conecta, zirix)
2. **Tipo de captura** (registros ou realocação)
3. **Range temporal** — calcula `dataInicial` e `dataFinal` com base no timestamp da execução

**Parâmetros enviados à API:**
```json
{
  "guidIdentificacao": "<credentials>",
  "dataInicial": "YYYY-MM-DD HH:MM:SS",
  "dataFinal": "YYYY-MM-DD HH:MM:SS"
}
```

### Particionamento

- **Data:** `data=YYYY-MM-DD`
- **Sem hora:** fluxos GPS utilizam apenas data para organizar dados

### Tabelas BigQuery

```
smtr.monitoramento.gps_validador           ← dados processados (treatment)
smtr.monitoramento.gps_validador_van       ← filtro por modo = van

smtr_raw.monitoramento.registros           ← raw da Cittati
smtr_raw.monitoramento.registros           ← raw da Conecta
smtr_raw.monitoramento.registros           ← raw da Zirix
```

## Backup BillingPay

O fluxo `capture__jae_backup_billingpay` realiza backup incremental de dados do sistema BillingPay (Jaé).

### Características

- **Backup incremental** por tabela
- **Filtros por data** para tabelas transacionais
- **Filtros por ID** para tabelas mestres
- **Exclusões de tabelas** (temperadas, sem permissão)
- **Armazenamento:** Cloud Storage (raw)
- **Controle de estado:** Redis (último valor capturado)

### Bancos de Dados

O backup cobre 15 bancos de dados:

| Database | Frequência | Escopo |
|----------|-----------|--------|
| `principal_db` | 01:00 UTC | Cadastro de clientes, linhas, operadoras |
| `tarifa_db` | 01:30 UTC | Tarifas e integrações |
| `transacao_db` | 02:00 UTC | Transações processadas |
| `tracking_db` | 02:30 UTC | Rastreamento de operações |
| `ressarcimento_db` | 03:00 UTC | Ordens de ressarcimento e pagamento |
| `gratuidade_db` | 03:30 UTC | Dados de gratuidades (PCD, estudante) |
| `fiscalizacao_db` | 04:00 UTC | Registros de fiscalização |
| `atm_gateway_db` | 04:30 UTC | Gateway de ATM |
| `device_db` | 05:00 UTC | Dispositivos e associações |
| `erp_integracao_db` | 05:30 UTC | Integração ERP |
| `atendimento_db` | 06:00 UTC | Atendimento |
| `gateway_pagamento_db` | 06:30 UTC | Gateway de pagamento |
| `financeiro_db` | 06:20 UTC | Financeiro (a cada 6h) |
| `midia_db` | 06:10 UTC | Mídias (a cada 6h) |
| `processador_transacao_db` | 06:00 UTC | Processador de transações (a cada 6h) |
| `vendas_db` | 07:00 UTC | Vendas |

### Fluxo de Execução

```
get_jae_db_config()              ← credenciais do banco
    ↓
get_table_info()                 ← lista tabelas e define filtros
    ↓
get_non_filtered_tables()        ← verifica tabelas sem filtro
    ↓
get_raw_backup_billingpay()      ← extrai dados com filtros
    │
    ├─ Tabelas com filtro datetime
    │   └─ WHERE (col >= last_capture AND col < now)
    │
    ├─ Tabelas com filtro integer (ID)
    │   └─ WHERE id BETWEEN last_id AND max_id
    │
    └─ Tabelas sem filtro
        └─ SELECT * (completo)
    ↓
upload_backup_billingpay()       ← envia para Cloud Storage
    ↓
set_redis_backup_billingpay()    ← salva último valor capturado
```

### Configuração de Filtros

Exemplo (banco `principal_db`):

```python
"filter": {
    "ITEM_PEDIDO": ["DT_INCLUSAO"],           # incremental por data
    "PEDIDO": ["DT_CONCLUSAO_PEDIDO", ...],   # múltiplas datas (OR)
    "CLIENTE_IMAGEM": ["DT_INCLUSAO"],        # com SELECT customizado
    "pcd_mae": ["count(*)"],                  # captura se count mudar
}
```

### Armazenamento

**Cloud Storage:**
```
gs://rj-smtr-data/backup_jae_billingpay/
├── {database_name}/
│   ├── {table_name}/
│   │   └── data=YYYY-MM-DD/
│   │       ├── {timestamp}_1.json
│   │       ├── {timestamp}_2.json
│   │       └── ...
```

**Redis:**
```
{env}.backup_jae_billingpay.{database_name}.{table_name}
= {
    "last_backup_value": "2025-01-15 10:30:45" ou "12345"
  }
```

### Alertas

Se uma tabela sem filtro configurado ultrapassar 5.000 registros, uma notificação é enviada ao Discord com:
- Nome do banco
- Lista de tabelas e contagem de registros

## Fluxos Auxiliares JAE

Além do backup BillingPay, existem fluxos de captura para outros sistemas Jaé:

| Flow | Descrição | Fonte |
|------|-----------|--------|
| `capture__jae_transacao` | Transações bilhetagem | `transacao_db` |
| `capture__jae_transacao_riocard` | Transações RioCard | `transacao_db` |
| `capture__jae_transacao_erro` | Erros de transação | `processador_transacao_db` |
| `capture__jae_transacao_ordem` | Transações x Ordens | `ressarcimento_db` |
| `capture__jae_integracao` | Integrações | `ressarcimento_db` |
| `capture__jae_lancamento` | Lançamentos | `financeiro_db` |
| `capture__jae_ordem_pagamento` | Ordens de pagamento | `ressarcimento_db` |
| `capture__jae_gps_validador` | GPS validado | `transacao_db` |
| `capture__jae_auxiliar` | Dados auxiliares | `principal_db` |

## Tratamento e Materialização

Os dados capturados alimentam fluxos de tratamento (treatment) que:

1. **Validam** dados GPS contra registros de viagem
2. **Enriquecem** com informações de planejamento
3. **Agregam** em tabelas de análise (passageiro/hora, etc)
4. **Materializam** em BigQuery

Exemplo: `treatment__gps_validador` processa registros GPS capturados e gera a tabela `monitoramento.gps_validador`.

## Logs e Monitoramento

### Partições

Os fluxos criam partições Hive estruturadas:
```
data=2025-01-15/hora=10/        ← registros com hora
data=2025-01-15/                ← realocações (sem hora)
```

### Timestamps

- **Capture timezone:** `America/Sao_Paulo` (UTC-3)
- **API datetime:** `YYYY-MM-DD HH:MM:SS`
- **BigQuery datetime:** `TIMESTAMP` (UTC)

### Redis

Fluxos consultam e atualizam Redis para:
- **Rastreamento** de última execução (`last_materialized_datetime`)
- **Controle incremental** de backup (`last_backup_value`)
- **Agendamento** de próximas execuções

## Recapturas

Todos os fluxos GPS suportam:

```python
recapture=True              # habilita recaptura
recapture_days=2            # número de dias no passado
recapture_timestamps=[...]  # timestamps específicas
```

Útil para:
- Corrigir falhas de API
- Reprocessar dados inválidos
- Atualizar retroativamente