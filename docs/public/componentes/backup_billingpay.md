# Backup Incremental de Dados BillingPay da Jaé

## Visão Geral

O pipeline `capture__jae_backup_billingpay` realiza backup incremental de dados provenientes de múltiplos bancos de dados da plataforma BillingPay (Jaé), utilizando diferentes estratégias de captura baseadas em filtros por data, sequências numéricas ou contagem de registros.

Este componente é responsável por:

- **Captura incremental** de dados de 14 bancos de dados distintos da Jaé
- **Estratégias adaptáveis** de sincronização (datetime, integer, count)
- **Filtragem inteligente** com suporte a colunas customizadas
- **Persistência em armazenamento** de nuvem (Google Cloud Storage)
- **Rastreamento de estado** via Redis para controle de incrementos
- **Notificações automáticas** de tabelas sem configuração de filtro

## Arquitetura

### Fluxo Principal

```
get_table_info
    ↓
get_non_filtered_tables (validação)
    ↓
get_raw_backup_billingpay (captura)
    ↓
upload_backup_billingpay (persistência)
    ↓
set_redis_backup_billingpay (rastreamento)
```

### Bancos de Dados Suportados

| Database | Descrição | Frequência |
|----------|-----------|-----------|
| `principal_db` | Dados cadastrais principais (clientes, pedidos, etc.) | 1x/dia (01:00) |
| `tarifa_db` | Configurações de tarifas | 1x/dia (01:30) |
| `transacao_db` | Transações de pagamento | 1x/dia (02:00) |
| `tracking_db` | Rastreamento de entregas | 1x/dia (02:30) |
| `ressarcimento_db` | Ordens de ressarcimento e pagamento | 1x/dia (03:00) |
| `gratuidade_db` | Dados de gratuidade e estudantes | 1x/dia (03:30) |
| `fiscalizacao_db` | Registros de fiscalização | 1x/dia (04:00) |
| `atm_gateway_db` | Gateway de pagamento ATM | 1x/dia (04:30) |
| `device_db` | Configuração de dispositivos | 1x/dia (05:00) |
| `erp_integracao_db` | Integração com ERP | 1x/dia (05:30) |
| `financeiro_db` | Dados financeiros e movimentações | 1x/dia (06:00) |
| `midia_db` | Dados de mídias (cartões, chips) | A cada 6h |
| `processador_transacao_db` | Processamento de transações | A cada 6h |
| `vendas_db` | Dados de vendas | 1x/dia (07:00) |

## Estratégias de Captura Incremental

### 1. **Incremental por DateTime**

Filtra registros com base em colunas de data/hora. Ideal para tabelas com timestamps de alteração.

**Exemplo:** Tabela `PEDIDO`
- Colunas de filtro: `DT_CONCLUSAO_PEDIDO`, `DT_CANCELAMENTO`, `DT_PAGAMENTO`, `DT_INCLUSAO`
- Captura: Registros onde qualquer uma dessas colunas está entre o último backup e agora

### 2. **Incremental por Integer**

Filtra registros baseado em sequências numéricas (IDs, códigos sequenciais).

**Exemplo:** Tabela `ERRO_IMPORTACAO_COLABORADOR`
- Coluna de filtro: `CD_ERRO`
- Captura: Novos registros com `CD_ERRO` entre o último ID capturado e o máximo atual

### 3. **Incremental por Contagem**

Valida mudanças na contagem total de registros, útil para tabelas pequenas sem colunas de data.

**Exemplo:** Tabela `pcd_mae`
- Monitora: Total de registros
- Captura: Completa se a contagem mudou desde o último backup

## Componentes Principais

### Tasks

#### `get_jae_db_config(database_name: str) → dict`
Prepara credenciais e configurações de conexão com o banco.

**Entrada:** Nome do banco (`principal_db`, `transacao_db`, etc.)
**Saída:** Dicionário com credenciais e parâmetros de conexão

#### `get_table_info() → list[dict]`
Descobre todas as tabelas disponíveis e determina sua estratégia de captura.

**Saída para cada tabela:**
```python
{
    "table_name": "PEDIDO",
    "incremental_type": "datetime",  # datetime | integer | count | None
    "filepath": "/path/to/backup/...",
    "partition": "data=2025-01-15/hora=10",
    "last_capture": datetime(2025, 1, 15, 9, 0),
    "custom_select": None  # SQL customizado, se houver
}
```

#### `get_non_filtered_tables() → tuple[bool, list]`
Identifica tabelas grandes (>5000 registros) sem filtro configurado.

**Retorna:** Tupla com flag de alerta e lista de tabelas

#### `get_raw_backup_billingpay() → list[dict]`
Executa a captura de dados do banco com base na estratégia de cada tabela.

**Processo:**
1. Monta a query SQL (padrão ou customizada)
2. Aplica filtro apropriado (datetime/integer/count)
3. Executa captura paginada (200k registros por página)
4. Salva em arquivos JSON locais

#### `upload_backup_billingpay() → list[dict]`
Envia arquivos capturados para Google Cloud Storage.

**Persiste em:**
```
gs://bucket/backup_jae_billingpay/{database}/{table}/data=YYYY-MM-DD/hora=HH/{timestamp}_{page}.json
```

#### `set_redis_backup_billingpay()`
Atualiza chave Redis com o último valor capturado (para próximas execuções).

**Padrão de chave:**
```
{env}.backup_jae_billingpay.{database}.{table}
```

### Funções Utilitárias

#### `create_billingpay_backup_filepath()`
Gera caminho padronizado para arquivos de backup.

#### `get_redis_last_backup()`
Consulta Redis para obter o último ponto de sincronização.

#### `get_backup_billing_pay_flow_run_name()`
Formata o nome da execução com banco de dados e timestamp.

## Filtragem Customizada

### Tabelas com Select Customizado

Algumas tabelas requerem JOINs ou subconsultas especiais:

```python
"custom_select": {
    "CLIENTE_IMAGEM": """
        select * from CLIENTE_IMAGEM
        where ID_CLIENTE_IMAGEM IN (
            select distinct ID_CLIENTE_IMAGEM
            from CLIENTE_IMAGEM
            where {filter}
        )
    """,
}
```

### Tabelas Excluídas

Tabelas explicitamente não sincronizadas:
- Tabelas de cadastro (LINHA, OPERADORA_TRANSPORTE, CLIENTE, etc.)
- Tabelas temporárias de processamento
- Tabelas sem permissão de leitura

**Exemplo:** `principal_db` exclui 48+ tabelas (CLIENTE_FRAUDE_05092024, estudante_import_old, etc.)

## Alertas e Monitoramento

### Notificações Discord

Quando tabelas sem filtro ultrapassam 5.000 registros, o pipeline envia alerta automático:

```
Database: principal_db
As seguintes tabelas não possuem filtros:
TABELA_X: 125000 registros
TABELA_Y: 87500 registros
```

**Webhook:** Variável `JAE_ALERT_WEBHOOK` (do arquivo `jae_constants`)

## Configuração por Banco de Dados

### Exemplo: `financial_db`

```python
"financeiro_db": {
    "exclude": ["lancamento"],  # Excluir tabela
    "filter": {
        "conta": ["dt_abertura", "dt_fechamento", "dt_lancamento"],
        "movimento": ["dt_movimento"],
        ...
    },
    "custom_select": {
        "conta": "SELECT * FROM conta ... WHERE {filter}"
    },
    "page_size": {}  # Usar default 200k
}
```

## Tratamento de Erros

### Tabelas sem Filtro Configurado

Se uma tabela tiver >5000 registros e nenhuma estratégia de filtro:
1. Log de aviso é gerado
2. Mensagem Discord é enviada (se configurada)
3. Pipeline continua com próximas tabelas
4. A tabela não é sincronizada nesta execução

### Falhas de Conexão

Credenciais são injetadas dinamicamente via `get_env_secret()` — erros de autenticação interrompem a tarefa com mensagem clara.

### Dados Truncados

Se a resposta de uma página exceeder limite de memória, o pipeline registra e segue para próxima página.

## Performance e Escalabilidade

- **Paginação:** 200k registros por página (customizável por tabela)
- **Backup paralelo:** Cada banco de dados tem slot horário independente
- **Incrementalidade:** Reduz transferência em ~95% vs. full backup
- **Compressão:** Arquivos JSON são comprimidos antes de upload (via Storage)

## Integração com Ecossistema

### Dependências

- **Redis:** Rastreamento de último sync
- **Google Cloud Storage:** Persistência de backups
- **Discord:** Notificações de alertas
- **Prefect:** Orquestração e scheduling

### Fluxo Posterior

Dados em GCS podem ser consumidos por:
- Pipelines de restauração de emergência
- Análise forense
- Replicação para data warehouse

## Parâmetros de Execução

```python
capture__jae_backup_billingpay(
    database_name: str,      # Nome do banco ('principal_db', 'transacao_db', etc.)
    env: Optional[str],      # 'prod' ou 'dev' (default: via deployment)
    end_datetime: Optional[str]  # ISO format timestamp (default: now)
)
```

## Limitações Conhecidas

1. **Tabelas sem timestamp:** Requerem configuração manual de coluna filtro ou exclusão
2. **Dados deletados:** Não rastreia deletions (apenas INSERTs/UPDATEs)
3. **Ciclos de reexecução:** Se uma tabela falhar, será recuperada no próximo ciclo horário
4. **Limite de linhas sem filtro:** Máximo de 5.000 registros antes de alerta (configurável)