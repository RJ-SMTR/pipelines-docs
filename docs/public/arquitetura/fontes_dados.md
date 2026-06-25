# Fontes de Dados

A plataforma SMTR integra dados de múltiplas fontes externas, categorizadas em três camadas principais: **captura de GPS**, **sistemas transacionais** e **backup incremental**.

## Visão Geral

As fontes de dados alimentam o ecossistema de dados público e interno através de pipelines de captura (Prefect), armazenamento bruto em Google Cloud Storage e transformação em BigQuery (dbt).

### Arquitetura de Integração

```
Fonte Externa → Pipeline Capture → Raw Storage (GCS) → Treatment (dbt) → BigQuery Público/Interno
```

---

## 1. Fontes de GPS

### 1.1 Operadores GPS Integrados

A plataforma captura dados de localização veicular em tempo real de três operadores de GPS:

| Operador | Tipo de Dado | Frequência | Início |
|----------|-------------|-----------|--------|
| **Cittati** | Posicionamento + Realocações | Contínua | Maio/2025 |
| **Conecta** | Posicionamento + Realocações | Contínua | Maio/2025 |
| **Zirix** | Posicionamento + Realocações | Contínua | Maio/2025 |

### 1.2 Estrutura de Dados GPS

Cada operador fornece dois tipos de registros:

#### **Registros** (`registros`)
- Posicionamento instantâneo do veículo
- Captura a cada 5-6 minutos
- Inclui: ID veículo, coordenadas, timestamp servidor
- **Chave primária**: `id_veiculo`, `datetime_servidor`

#### **Realocações** (`realocacao`)
- Alterações de rota ou viagem retroativas
- Captura retroativa de movimentação
- Captura histórica (até 10 minutos anteriores)
- **Chave primária**: `id_veiculo`, `datetime_processamento`

### 1.3 Pipelines de Captura GPS

Cada operador × tipo de dado = 1 pipeline de captura:

| Pipeline | Operador | Tipo | Cronograma Prod |
|----------|----------|------|-----------------|
| `capture__cittati_registros` | Cittati | Registros | A cada minuto |
| `capture__cittati_realocacao` | Cittati | Realocação | A cada 10 min |
| `capture__conecta_registros` | Conecta | Registros | A cada minuto |
| `capture__conecta_realocacao` | Conecta | Realocação | A cada 10 min |
| `capture__zirix_registros` | Zirix | Registros | A cada minuto |
| `capture__zirix_realocacao` | Zirix | Realocação | A cada 10 min |

**Funcionalidade**: Consulta endpoint HTTP específico da API do operador, normaliza resposta JSON e persiste em GCS no formato particionado por `data/hora`.

---

## 2. Fontes Transacionais e Cadastrais (Jaé)

### 2.1 Sistema Jaé

O **Jaé** é o sistema central de bilhetagem eletrônica. A plataforma integra múltiplos bancos de dados do Jaé para construir a visão unificada de operações.

#### Bancos de Dados Integrados

| Banco | Conteúdo | Cadência |
|------|----------|----------|
| **principal_db** | Cadastro de clientes, linhas, operadoras, consórcios | Diária (1h) |
| **transacao_db** | Transações de pagamento, recargas | Contínua + incremental |
| **tarifa_db** | Estrutura tarifária, integrações | Diária |
| **tracking_db** | Rastreamento de mídia de pagamento | Contínua |
| **ressarcimento_db** | Órdenes e rateios de ressarcimento | Diária (3h) |
| **gratuidade_db** | Elegibilidade de gratuidade, estudantes, PCD | Diária (3h30) |
| **midia_db** | Cartões e mídia de pagamento | Contínua |
| **financeiro_db** | Lançamentos contábeis, movimentação | Diária (3h) |
| **fiscalizacao_db** | Registros operacionais de fiscalização | Semanal |
| **device_db** | Configuração de validadores, terminais | Diária |
| **atm_gateway_db** | Requisições de gateway de pagamento | Contínua |
| **atendimento_db** | Interações com centrais de atendimento | Contínua |
| **vendas_db** | Transações de venda complementares | Contínua |

### 2.2 Pipelines de Captura Jaé

#### Captura Padrão (via `capture__jae_*`)

Pipelines de captura incremental por tabela:

| Pipeline | Tabelas | Tipo | Cadência |
|----------|---------|------|----------|
| `capture__jae_transacao` | Principais de transação | Incremental | A cada 5 min |
| `capture__jae_transacao_riocard` | Transações RioCard | Incremental | A cada 5 min |
| `capture__jae_lancamento` | Lançamentos contábeis | Incremental | Horária |
| `capture__jae_ordem_pagamento` | Órdenes de pagamento | Incremental | Horária |
| `capture__jae_integracao` | Dados de integração | Incremental | Horária |
| `capture__jae_auxiliar` | Dados auxiliares | Completa | Diária |

#### Captura GPS Validador (`capture__jae_gps_validador`)

- Localização dos validadores em terminal
- Integra com sistema de monitoramento operacional

#### Backup Incremental (`capture__jae_backup_billingpay`)

Sistema de backup estruturado para o BillingPay do Jaé:

**Características**:
- Carga incremental por tabela com filtros temporais configuráveis
- Suporta múltiplos tipos de coluna de controle (data, ID, contagem)
- Execução distribuída ao longo do dia (17 bancos em paralelo)
- Armazenamento em GCS em formato JSON paginado
- Rastreamento em Redis do último valor capturado

**Escopo**:
- **Filtradas** (~50 tabelas): apenas registros novos/alterados desde última execução
- **Não filtradas** (~20 tabelas): exportação completa (com alertas se > 5.000 linhas)

**Cronograma** (horário Brasil):
- 00h: `processador_transacao_db`
- 01h: `principal_db`, 01h30: `tarifa_db`
- 02h: `transacao_db`, 02h30: `tracking_db`
- 03h: `ressarcimento_db`, 03h30: `gratuidade_db`
- 04h: `fiscalizacao_db`, 04h30: `atm_gateway_db`
- 05h: `device_db`, 05h30: `erp_integracao_db`
- 06h: `atendimento_db`, 06h30: `gateway_pagamento_db`
- 07h: `vendas_db`

---

## 3. Outras Fontes de Dados Operacionais

### 3.1 Rio Ônibus (RIO Mobilidade)

| Fonte | Dado | Pipeline |
|-------|------|----------|
| **Sistema RIO Ônibus** | Viagens informadas em tempo real | `capture__rioonibus_viagem_informada` |

Registra viagens efetivamente executadas pelas operadoras.

### 3.2 Sistemas de Controle

| Fonte | Dado | Pipeline |
|-------|------|----------|
| **Cittati** | Realocações | `capture__cittati_realocacao` |
| **Conecta** | Realocações | `capture__conecta_realocacao` |
| **Zirix** | Realocações | `capture__zirix_realocacao` |

### 3.3 Órgãos Externos

| Fonte | Dado | Pipeline |
|-------|------|----------|
| **SERPRO** | Autuações de trânsito | `capture__serpro_autuacao` |
| **Prefeitura RJ** | Cadastro de escolas | (via Jaé `gratuidade_db`) |
| **Seeduc RJ** | Matrícula escolar | (via Jaé `gratuidade_db`) |

---

## 4. Estrutura de Armazenamento

### 4.1 Organização em GCS

```
gs://rj-smtr-dev (ou prod)/
├── raw/                          # Dados brutos capturados
│   ├── cittati_registros/        # Registros GPS Cittati
│   │   ├── data=2025-05-09/
│   │   │   └── hora=14/
│   │   │       └── 2025-05-09_14-00-00_000000.json
│   ├── jae_transacao/            # Transações Jaé
│   ├── jae_backup_billingpay/    # Backup incremental
│   │   ├── principal_db/
│   │   │   ├── CLIENTE/
│   │   │   │   └── data=2025-05-09/
│   │   │   │       └── 2025-05-09_timestamp_0.json
├── treatment/                    # Dados tratados (via dbt)
│   ├── operacao/
│   ├── cadastro/
│   ├── bilhetagem/
│   └── ...
```

### 4.2 Particionamento

**GPS e Sistemas Transacionais**: `data=YYYY-MM-DD/hora=HH/`

**Backup BillingPay**: `data=YYYY-MM-DD/` (apenas data, carga diária)

---

## 5. Fluxo de Dados

### 5.1 Do Capture ao Público

```
1. Captura (Prefect)
   ↓
2. Armazenamento Bruto (GCS raw/)
   ↓
3. Transformação (dbt)
   ↓
4. BigQuery (Público + Interno)
```

### 5.2 Tratamento em dbt

- **Staging**: Normalização, limpeza, casting de tipos
- **Intermediate**: Agregações e enriquecimento
- **Marts**: Modelos finais (bilhetagem, operação, cadastro, monitoramento)

---

## 6. Características Técnicas

### 6.1 Extração

- **GPS**: API REST (HTTP GET com autenticação por chave)
- **Jaé**: JDBC SQL direto (SQLAlchemy)
- **SERPRO**: API SOAP com certificado SSL/TLS

### 6.2 Formato de Dados

- **Raw**: JSON (nested structure para arraysde sub-registros)
- **Staged**: Parquet particionado (BigQuery)

### 6.3 Incrementalismo

**GPS**: Baseado em timestamp de processamento

**Jaé Transacional**: Baseado em colunas de data/hora (DT_INCLUSAO, DT_ALTERACAO, etc.)

**Jaé Backup**: Baseado em múltiplas estratégias:
- Incremental datetime (comparação de coluna de data)
- Incremental ID (máximo ID alcançado)
- Count (detecção de alterações por mudança de volume)

### 6.4 Recuperação e Recaptura

- Recaptura de períodos específicos (parametrizável por dias ou timestamps)
- Verificação de completude automática (via dbt tests)
- Alertas no Discord em caso de falha ou dados incompletos

---

## 7. Qualidade e Monitoramento

### 7.1 Verificações de Dados

- **Source Freshness**: Monitora atraso de chegada de dados
- **Tests dbt**: Validação de unicidade, nulidade, ranges
- **Macros de controle**: Verificação de captura GPS, processamento de viagens, etc.

### 7.2 Rastreamento em Redis

Cada fonte mantém chave Redis com último valor capturado:

```
{env}.{source}.{database/table}.{field} → valor
```

Permite retomar captura exatamente de onde parou em caso de interrupção.

---

## 8. Contato e Mudanças

Para questões sobre:
- **Adição de nova fonte**: Contatar equipe de plataforma
- **Alteração de cronograma**: Validar impacto em tratamentos downstream
- **Acesso a dados brutos**: Consultar documentação de segurança e permissões