# Visão Geral da Plataforma SMTR

A Secretaria Municipal de Transportes do Rio de Janeiro (SMTR) opera uma plataforma integrada de dados de transporte público que consolida informações de múltiplas fontes, processa-as de forma estruturada e disponibiliza análises para suporte à gestão e ao controle regulatório.

## Propósito

A plataforma SMTR fornece uma arquitetura moderna de engenharia de dados que:

- **Captura** dados de bilhetagem, GPS de veículos, planejamento operacional e dados de transações financeiras
- **Processa** esses dados através de pipelines de extração, transformação e carregamento (ETL)
- **Armazena** em um data warehouse centralizado (Google BigQuery) com histórico completo
- **Expõe** informações tratadas para controle, monitoramento e pesquisa

## Arquitetura em Camadas

```
┌─────────────────────────────────────────────────────────────┐
│                   Público-Alvo Externo                      │
│  (órgãos de controle, pesquisadores, municípios)            │
└────────────────────┬────────────────────────────────────────┘
                     │ (APIs, relatórios, dashboards)
┌────────────────────▼────────────────────────────────────────┐
│              Camada de Apresentação & Consultas              │
│  - BigQuery (análises, views públicas)                       │
│  - Dashboards (Metabase, Looker)                            │
│  - APIs de dados estruturados                               │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│         Camada de Processamento (Treatment/dbt)             │
│  - Transformação e materialização de dados                   │
│  - Modelagem semântica (staging → marts)                    │
│  - Testes de qualidade e validação                          │
│  - Snapshots históricos                                      │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│          Camada de Captura (Prefect Orchestration)          │
│  - Extração de dados brutos (raw)                           │
│  - Carregamento em Cloud Storage & BigQuery                 │
│  - Orquestração de pipelines com Prefect                    │
│  - Retry, tratamento de erros e alertas                     │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│            Camada de Fontes Externas                         │
│  - Operadoras (Jaé, RioOnibus, Zirix, Cittati, Conecta)    │
│  - APIs internas e externas                                 │
│  - Bancos de dados transacionais                            │
│  - Dispositivos GPS em tempo real                           │
└─────────────────────────────────────────────────────────────┘
```

## Fluxo de Dados Principal

1. **Captura (Acquisition Layer)**
   - Pipelines Prefect extraem dados de múltiplas fontes em ciclos regulares
   - Dados brutos armazenados em Google Cloud Storage (bucket `raw`)
   - Carregamento incremental ou full no BigQuery (dataset `raw`)

2. **Processamento (Treatment Layer)**
   - dbt (data build tool) transforma dados brutos em modelos semânticos
   - Estruturação em camadas: staging → intermediate → marts
   - Validação automática através de testes dbt
   - Snapshots de dimensões para rastreamento histórico

3. **Consumo (Consumption Layer)**
   - Views públicas no BigQuery para análise
   - Dashboards gerenciais e de monitoramento
   - APIs estruturadas para acesso programático
   - Relatórios estatísticos e documentação aberta

## Principais Componentes

### Captura de Dados (Pipelines)

A plataforma captura dados de diferentes domínios:

| Domínio | Fontes | Frequência | Tipo |
|---------|--------|-----------|------|
| **Bilhetagem** | Jaé (BillingPay), RioCard | Em tempo real / Incremental | Transações, cartões |
| **GPS & Monitoramento** | Cittati, Conecta, Zirix | A cada 5-10 minutos | Posições de veículos, deslocamentos |
| **Planejamento Operacional** | GTFS, dados internos | Diário / Sob demanda | Linhas, paradas, horários |
| **Transito & Autuação** | SERPRO, CITRAN | Incremental | Multas, infrações |
| **Cadastro** | Banco de dados corporativo | Incremental / Full | Operadoras, linhas, garagens |
| **Recursos Internos** | Sistemas de backup Jaé | 6h em 6h | Backup de múltiplos bancos |

### Processamento (dbt Models)

Os dados são organizados em modelos semânticos:

- **Bilhetagem**: `transacao`, `passageiro_hora`, `passageiro_tile_hora`
- **Monitoramento**: `gps_validador`, `viagem_informada_monitoramento`
- **Planejamento**: `servico_planejado_faixa_horaria`, `ordem_servico_faixa_horaria`
- **Trânsito**: `autuacao`, `receita_autuacao`, `autuacao_negativacao`
- **Cadastro**: `operadoras`, `servicos`, `consorcios`, `modos`
- **Infraestrutura**: `custo_cloud`, `log_bigquery`

### Orquestração (Prefect)

Pipelines executados via **Prefect 3.4.8** com:

- **Deployments** em staging e produção
- **Schedules** em cron (execução agendada)
- **Work Pools** em Kubernetes (SMTR)
- **Alertas** integrados com Discord
- **Monitoramento** via Sentry

## Novos Fluxos de Captura GPS

Recentemente foram adicionados fluxos especializados para captura de dados de GPS:

### Captura GPS - Múltiplas Operadoras

Novas pipelines para captura de dados de localização de veículos:

- **`capture__cittati_registros`** - Registros de GPS da Cittati (minuto a minuto)
- **`capture__cittati_realocacao`** - Viagens retroativas da Cittati
- **`capture__conecta_registros`** - Registros de GPS da Conecta
- **`capture__conecta_realocacao`** - Viagens retroativas da Conecta
- **`capture__zirix_registros`** - Registros de GPS da Zirix
- **`capture__zirix_realocacao`** - Viagens retroativas da Zirix

**Característica técnica**: Utilizem um extrator compartilhado (`create_gps_extractor`) que:
- Consulta APIs de GPS das operadoras via HTTP
- Aplica filtros de janela temporal (últimos 5-10 minutos)
- Diferencia entre dados de registro contínuo e realocação
- Particiona por data apenas (sem hora)

### Backup de Dados - Jaé/BillingPay

Nova pipeline para backup incremental de múltiplos bancos de dados da Jaé:

- **`capture__jae_backup_billingpay`** - Backup incremental em 6h em 6h

**Características**:
- Backup de 18 bancos de dados distintos (principal, tarifa, transação, tracking, etc.)
- Filtros inteligentes baseados em colunas de data ou ID
- Detecção de tabelas grandes sem filtro (alerta Discord)
- Persistência de estado em Redis (último valor capturado)
- Upload para Cloud Storage em pastas por database/tabela/partição

## Integração com Controle Regulatório

A plataforma suporta fluxos especializados para integração com órgãos de controle:

- **Negativação de autuações** (integração com Previnity)
- **Fonte de dados para fiscalização** (auditoria de bilhetagem)
- **Rastreabilidade de transações** (billetagem e pagamentos)
- **Monitoramento de regularidade** (cumprimento de cronograma)

## Stack Tecnológico

| Componente | Tecnologia |
|-----------|-----------|
| **Orquestração** | Prefect 3.4.8 |
| **Transformação** | dbt (data build tool) |
| **Data Warehouse** | Google BigQuery |
| **Storage** | Google Cloud Storage |
| **Infraestrutura** | Kubernetes (Helm), Docker |
| **Linguagens** | Python 3.11+, SQL, YAML |
| **CI/CD** | GitHub Actions |
| **Versionamento** | Git, uv (Python package manager) |
| **Cache/State** | Redis |
| **Observabilidade** | Sentry, Discord webhooks |

## Governança de Dados

A plataforma implementa:

- **Rastreabilidade completa** de cada extração e transformação
- **Versionamento semântico** de schemas e dados históricos
- **Testes automáticos** de integridade e completude
- **Políticas de acesso** baseadas em papéis
- **Documentação automática** via dbt (YAML + Markdown)
- **Auditoria** através de logs estruturados e Sentry

## Público-Alvo

A documentação e APIs servem a:

- **SMTR** - Gestão operacional e monitoramento
- **Órgãos de controle** (CGU, TCE-RJ) - Auditoria e compliance
- **Pesquisadores** - Acesso a dados públicos de mobilidade urbana
- **Outros municípios** - Referência para implementação de plataformas similares
- **Concessionárias** - Integração de dados e feedback de performance

---

**Versão:** 2025-03-16  
**Última atualização:** Adição de fluxos GPS e backup BillingPay