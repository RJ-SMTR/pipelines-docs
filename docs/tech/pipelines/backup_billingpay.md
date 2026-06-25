# Pipeline de Backup Incremental BillingPay

## Visão Geral

O pipeline `capture__jae_backup_billingpay` realiza backup incremental de dados BillingPay (Jaé) em múltiplos bancos de dados da plataforma de transporte público do Rio de Janeiro. O pipeline foi projetado para capturar alterações por tabela usando estratégia de filtros baseados em colunas de data/hora ou identificadores sequenciais.

## Arquitetura

### Componentes Principais

```
Flow Principal
├── get_jae_db_config
├── get_scheduled_timestamp
├── get_table_info
├── get_non_filtered_tables
├── get_raw_backup_billingpay
├── upload_backup_billingpay
└── set_redis_backup_billingpay
```

### Bancos de Dados Suportados

- **principal_db**: Dados de clientes, pedidos, pessoas físicas
- **tarifa_db**: Dados de tarifação
- **transacao_db**: Transações e confirmações PMS
- **tracking_db**: Rastreamento de entregas
- **ressarcimento_db**: Ordens de ressarcimento e pagamento
- **gratuidade_db**: Gratuidades, estudantes, laudo PCD
- **fiscalizacao_db**: Dados de fiscalização
- **atm_gateway_db**: Requisições de gateway
- **device_db**: Associações e controle de dispositivos
- **erp_integracao_db**: ERP integrado
- **financeiro_db**: Contas, lotes de crédito, movimentações
- **midia_db**: Cartões, mídias, eventos
- **processador_transacao_db**: Transações processadas e recebidas
- **atendimento_db**: Dados de atendimento
- **gateway_pagamento_db**: Processamento de pagamentos CNAB
- **vendas_db**: Vendas e créditos

## Fluxo de Execução

### 1. Inicialização

```
get_jae_db_config(database_name)
  → Carrega credenciais do secret
  → Constrói URL de conexão
```

**Saída**: `dict` com configuração de banco

### 2. Obtenção de Informações de Tabelas

```
get_table_info(
  env, database_name, database_config, timestamp
)
  → Lista tabelas acessíveis
  → Filtra tabelas excluídas
  → Consulta Redis para último backup
  → Determina tipo incremental (datetime/integer)
```

**Saída**: `list[dict]` com metadados de cada tabela
```python
{
    "table_name": str,
    "incremental_type": "datetime" | "integer" | None,
    "filepath": str,
    "partition": str,
    "custom_select": Optional[str],
    "last_capture": Union[datetime, int],
    "redis_save_value": Optional[Union[datetime, int]]
}
```

### 3. Verificação de Tabelas Não Filtradas

```
get_non_filtered_tables(
  database_name, database_config, table_info
)
  → Identifica tabelas sem filtro configurado
  → Conta registros
  → Alerta se > 5000 registros
```

**Saída**: `tuple[bool, list[dict]]`
- `bool`: Necessário notificar Discord
- `list[dict]`: Tabelas com contagem

### 4. Captura de Dados

```
get_raw_backup_billingpay(
  table_info, database_config, timestamp
)
  → Conecta ao banco de dados
  → Para cada tabela:
    ├── Constrói filtro WHERE dinâmico
    ├── Pagina resultados (padrão: 200k registros/página)
    └── Salva em JSON local
```

**Estratégias de Filtro**:

- **datetime**: Filtra por colunas de data/timestamp
  ```sql
  WHERE (col1 >= 'last_capture' AND col1 < 'timestamp')
     OR (col2 >= 'last_capture' AND col2 < 'timestamp')
  ```

- **integer**: Filtra por coluna ID sequencial
  ```sql
  WHERE id_column BETWEEN last_capture AND max_id
  ```

- **count(*)**: Compara contagem total
  - Captura se diferente do último backup

### 5. Upload para Storage

```
upload_backup_billingpay(env, table_info, database_name)
  → Inicializa Storage GCS
  → Para cada arquivo local:
    └── Upload para gs://bucket/
        /backup_jae_billingpay/
        /database_name/
        /table_name/
        /data=YYYY-MM-DD/
        /timestamp_page*.json
```

### 6. Atualização de Estado (Redis)

```
set_redis_backup_billingpay(
  env, table_info, database_name, timestamp
)
  → Para cada tabela com incremental_type:
    ├── Consulta valor atual no Redis
    ├── Atualiza se novo valor > anterior
    └── Salva padrão: "YYYY-MM-DD HH:MM:SS" ou inteiro
```

**Chave Redis**: `{env}.backup_jae_billingpay.{database}.{table}`

## Configuração de Filtros

Definida em `constants.BACKUP_JAE_BILLING_PAY[database_name]`:

```python
BACKUP_JAE_BILLING_PAY = {
    "principal_db": {
        "exclude": [...],  # Tabelas completamente ignoradas
        "filter": {        # Colunas para filtro incremental
            "PEDIDO": [
                "DT_CONCLUSAO_PEDIDO",
                "DT_CANCELAMENTO",
                "DT_PAGAMENTO",
                "DT_INCLUSAO"
            ],
            "count(*)": [...]  # Tabelas filtradas por contagem
        },
        "custom_select": {  # SQL customizado para joins complexos
            "CLIENTE_IMAGEM": """
                SELECT * FROM CLIENTE_IMAGEM
                WHERE ID_CLIENTE_IMAGEM IN (...)
            """
        },
        "page_size": {
            "CLIENTE_IMAGEM": 500  # Override do page_size padrão
        }
    }
}
```

## Agendamento (Production)

| Horário | Database | Frequência |
|---------|----------|-----------|
| 00:00 | processador_transacao_db | 6h |
| 00:20 | financeiro_db | 6h |
| 00:10 | midia_db | 6h |
| 01:00 | principal_db | Diário |
| 01:30 | tarifa_db | Diário |
| 02:00 | transacao_db | Diário |
| 02:30 | tracking_db | Diário |
| 03:00 | ressarcimento_db | Diário |
| 03:30 | gratuidade_db | Diário |
| 04:00 | fiscalizacao_db | Diário |
| 04:30 | atm_gateway_db | Diário |
| 05:00 | device_db | Diário |
| 05:30 | erp_integracao_db | Diário |
| 06:00 | atendimento_db | Diário |
| 06:30 | gateway_pagamento_db | Diário |
| 07:00 | vendas_db | Diário |

**Timezone**: America/Sao_Paulo

## Dependências

### Internas
- `pipelines.common.capture.jae.constants`: Configurações JAE
- `pipelines.common.treatment.default_treatment.constants`: Padrões de timestamp
- `pipelines.common.utils.gcp.storage`: Upload GCS
- `pipelines.common.utils.redis`: Persistência de estado
- `pipelines.common.utils.database`: Utilitários de banco
- `pipelines.common.utils.extractors.db`: Extração paginada

### Externas
- `sqlalchemy`: ORM e inspeccção de schema
- `pandas`: Manipulação de dados
- `pytz`: Tratamento de timezones

## Tratamento de Erros e Alertas

### Tabelas Sem Filtro

Se tabelas acessíveis **não possuem** filtro configurado e contêm **> 5000 registros**:

1. `get_non_filtered_tables()` retorna `(True, tables_list)`
2. `create_non_filtered_discord_message()` formata alerta
3. `task_send_discord_message()` envia para webhook configurado

**Webhook**: `jae_constants.ALERT_WEBHOOK`

### Validações

- **Conexão**: `create_database_url()` valida credenciais
- **Schema**: `inspector.get_columns()` verifica tipos de dados
- **Redis**: Comparação `current_count vs last_count` para tabelas "count(*)"

## Exemplo de Uso

```python
# Staging
flow.serve(
    name="staging-jae-backup-billingpay",
)

# Production (via deployment)
prefect deployment run \
  capture__jae_backup_billingpay/rj-capture--jae_backup_billingpay--prod \
  -p database_name=principal_db
```

## Notas Técnicas

### Performance
- **Page size padrão**: 200.000 registros/página
- **Exceção**: CLIENTE_IMAGEM = 500 registros/página (customizado em constants)
- **Paginação**: Evita OOM em tabelas grandes

### Incremental Seguro
- **Datetime**: Captura por range de data/hora
- **Integer**: Captura por range de ID
- **Redis**: Garante idempotência (não recaptura mesmas linhas)

### Exclusões de Segurança
Tabelas excluídas: views temporárias, backups, tabelas de teste, cadastro (redundante com GCP)

Exemplo `principal_db`:
- LINHA, OPERADORA_TRANSPORTE, CLIENTE, PESSOA_FISICA (∈ cadastro)
- temp_* (tabelas de trabalho)
- check_* (views de validação)

## Monitoramento

- **Logs**: Cada task registra progresso
- **Redis**: Rastreia timestamp do último backup por tabela/banco
- **Discord**: Alertas de tabelas descobertas sem filtro
- **GCS**: Estrutura de pastas by-date para auditorias