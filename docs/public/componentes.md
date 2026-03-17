# Componentes

## Visão Geral

A arquitetura de pipelines da SMTR é organizada em **camadas reutilizáveis** que centralizam lógica comum e permitem a criação de novos fluxos de forma eficiente. Cada componente pode ser combinado com outros para estruturar operações de captura, tratamento e integração de dados.

## Estrutura de Camadas

### 1. **Camada Comum** (`pipelines/common`)

Contém utilidades, tarefas e fluxos compartilhados por todas as pipelines específicas.

#### **Captura de Dados** (`pipelines/common/capture`)

Responsável pela extração de informações de fontes externas.

##### **Captura Padrão** (`default_capture`)

Framework genérico para implementar extrações de APIs e bancos de dados:

- **`SourceCaptureContext`**: Classe que encapsula contexto de uma fonte (timestamp, partição, caminhos de arquivo)
- **`create_capture_flows_default_tasks()`**: Factory que monta fluxos completos de captura
- **Tarefas principais**:
  - `get_raw_data`: Extrai dados usando função customizável
  - `transform_raw_to_nested_structure`: Normaliza estrutura de dados
  - `upload_raw_file_to_gcs`: Envia arquivo para Google Cloud Storage
  - `upload_source_data_to_gcs`: Envia metadados de fonte

##### **Captura GPS** (`gps`)

Componentes reutilizáveis para integração com provedores de localização (Cittati, Conecta, Zirix):

- **`create_gps_extractor`**: Task que retorna um extrator parcial configurado para consultar APIs de GPS
- **Constantes compartilhadas**: URLs base, endpoints, mapeamento de secrets
- **Suporte a dois tipos de dados**:
  - `registros`: Rastreamentos em tempo real
  - `realocacao`: Viagens retroativas/realocações

##### **Captura JAE** (`jae`)

Utilidades para extração de dados do sistema BillingPay Jaé:

- **`create_jae_general_extractor`**: Factory para extrair dados de bancos SQL da Jaé
- **`get_capture_delay_minutes`**: Calcula delay de captura baseado em cronograma
- Suporte a múltiplos bancos de dados internos (principal, tarifa, transação, etc.)

#### **Tratamento de Dados** (`pipelines/common/treatment`)

Orquestração de transformações em dados já capturados.

##### **Tratamento Padrão** (`default_treatment`)

Framework para materialização de dados em BigQuery usando dbt:

- **`DBTSelector`**: Classe para seleção dinâmica de modelos dbt
- **`DBTMaterializationContext`**: Contexto com dados de agendamento, timestamps, variáveis dbt
- **`create_materialization_flows_default_tasks()`**: Factory que constrói fluxos de transformação
- **Tarefas principais**:
  - `wait_data_sources`: Aguarda disponibilidade de dados em Redis
  - `run_dbt_selectors`: Executa seleções customizadas de modelos
  - `run_dbt_snapshots`: Cria snapshots dbt
  - `run_dbt_tests`: Valida dados transformados
  - `dbt_test_notify_discord`: Notifica falhas em testes

#### **Utilitários Comuns** (`pipelines/common/utils`)

Funções auxiliares de propósito geral:

- **`gcp/`**: Abstrações para BigQuery e Cloud Storage
  - `BQTable`, `Dataset`, `SourceTable`: Classes para gerenciar tabelas
  - `Storage`: Interface unificada para upload/download de arquivos
- **`extractors/`**: Helpers para extração de dados
  - `get_raw_api`: Consome APIs REST paginadas
  - `get_raw_db`: Consulta bancos de dados SQL
- **`database.py`**: Utilitários de conexão e listagem de tabelas
- **`discord.py`**: Envio de mensagens a webhooks Discord
- **`redis.py`**: Cliente de cache/estado com chaves estruturadas
- **`fs.py`**: Operações com sistema de arquivos local e particionamento Hive
- **`pretreatment.py`**: Normalização de dados (texto, tipos, timestamps)
- **`secret.py`**: Acesso a secrets (Infisical, variáveis de ambiente)
- **`cron.py`**: Utilitários para trabalhar com agendas cron

### 2. **Pipelines Específicas**

Cada pipeline segue um padrão de diretório:
```
pipelines/capture__<source>__<table>/
  flow.py          # Flow principal (Prefect)
  constants.py     # Configurações e definições de fonte
  tasks.py         # Tasks customizadas (quando necessário)
  prefect.yaml     # Agendamentos e deployments
  Dockerfile       # Imagem de execução
```

#### **Captura GPS** (Reutilizáveis)

Usam `create_gps_extractor` para consultar provedores:

- **`capture__cittati_registros`** / **`capture__cittati_realocacao`**: Rastreamentos Cittati
- **`capture__conecta_registros`** / **`capture__conecta_realocacao`**: Rastreamentos Conecta
- **`capture__zirix_registros`** / **`capture__zirix_realocacao`**: Rastreamentos Zirix

Característica comum: usam a mesma task de extração, diferenciando-se apenas nas constantes de fonte.

#### **Captura JAE** (Billetagem)

Extraem dados de múltiplos bancos da plataforma Jaé:

- **`capture__jae_auxiliar`**: Tabelas auxiliares
- **`capture__jae_lancamento`**: Movimentações financeiras
- **`capture__jae_transacao`**: Transações de bilhetagem
- **`capture__jae_transacao_erro`**: Erros de processamento
- **`capture__jae_ordem_pagamento`**: Ordens de pagamento
- **`capture__jae_transacao_ordem`**: Relação transação-ordem
- **`capture__jae_transacao_riocard`**: Transações RioCard
- **`capture__jae_integracao`**: Dados de integração
- **`capture__jae_gps_validador`**: Validação de GPS
- **`capture__jae_backup_billingpay`**: Backup incremental de bases BillingPay

#### **Captura RioOnibus**

- **`capture__rioonibus_viagem_informada`**: Viagens registradas no sistema RioOnibus

#### **Captura Transito**

- **`capture__serpro_autuacao`**: Autuações de trânsito via SERPRO (certificado SSL)

#### **Tratamento de Dados**

Transformam dados brutos em assets analíticos:

- **`treatment__cadastro`**: Dados de registro (operadoras, linhas, serviços)
- **`treatment__bilhetagem`**: Agregações de transações de passageiros
- **`treatment__gps_validador`**: Validação de rastreamentos GPS
- **`treatment__infraestrutura`**: Logs de operação e custos de cloud
- **`treatment__passageiro_hora`**: Contagem de passageiros por hora
- **`treatment__planejamento_diario`**: Planos operacionais
- **`treatment__transito_autuacao`**: Processamento de infrações
- **`treatment__viagem_informada`**: Viagens planejadas vs realizadas

#### **Pipelines de Controle**

Orquestração e monitoramento:

- **`control__set_redis_key`**: Atualiza chaves de estado em Redis
- **`control__source_freshness`**: Verifica atualização de dados com dbt freshness

#### **Pipelines de Integração**

Sincronização com sistemas externos:

- **`integration__previnity_negativacao`**: Integração com plataforma de negativação

## Padrões de Design

### **Composição de Flows**

As pipelines específicas **não reimplementam lógica**. Em vez disso:

```python
@flow
def capture__cittati_registros(...):
    create_capture_flows_default_tasks(
        sources=[CITTATI_REGISTROS_SOURCE],
        create_extractor_task=create_gps_extractor,  # ← Task reutilizável
        ...
    )
```

### **Configuração via Constantes**

Fontes de dados são definidas como `SourceTable`:

```python
CITTATI_REGISTROS_SOURCE = SourceTable(
    source_name="cittati",
    table_id="registros",
    first_timestamp=...,
    primary_keys=["id_veiculo", "datetime_servidor"],
    ...
)
```

### **Injeção de Dependências**

Tasks de extração são passadas como callbacks:

- `create_gps_extractor`: Extrai de APIs de localização
- `create_jae_general_extractor`: Extrai de bancos SQL Jaé
- Custom: Funções definidas por pipeline

### **Gestão de Estado**

- **Redis**: Armazena últimas timestamps de captura, contadores, flags
- **BigQuery**: Metadados de fonte em `source_freshness`, versionamento
- **Cloud Storage**: Arquivos raw em estrutura particionada (data/hora)

## Integração com Ecossistema

### **Prefect (Orquestração)**

- Flows e tasks decorados com `@flow` e `@task`
- Agendamentos via `prefect.yaml` (cron ou manual)
- Deployments em K8s com imagens Docker

### **dbt (Transformação)**

- Modelos SQL em `queries/models/`
- Seletores customizados para controle de execução
- Tests genéricos e específicos
- Macros para lógica reutilizável

### **BigQuery (Data Lake)**

- Schemas organizados por domínio (bilhetagem, cadastro, transito, etc.)
- Particionamento por data e/ou hora
- Clustering por chaves naturais
- Snapshots para histórico

### **Cloud Storage**

- Estrutura: `gs://bucket/dataset_id/table_id/data=YYYY-MM-DD/hora=HH/arquivo.json`
- Compressão gzip automática
- Acesso via `Storage` class para abstração

## Extensibilidade

### **Criar Nova Pipeline de Captura**

1. Defina fonte em `constants.py`:
   ```python
   SOURCE = SourceTable(source_name="...", table_id="...", ...)
   ```

2. Crie flow em `flow.py`:
   ```python
   @flow
   def capture__novo(...):
       create_capture_flows_default_tasks(
           sources=[SOURCE],
           create_extractor_task=create_gps_extractor,  # ou custom
           ...
       )
   ```

3. Configure agendamento em `prefect.yaml`

### **Criar Nova Pipeline de Tratamento**

1. Implemente modelos dbt em `queries/models/novo_dominio/`
2. Defina seletor em `DBTSelector` ou use tags
3. Configure flow:
   ```python
   @flow
   def treatment__novo(...):
       create_materialization_flows_default_tasks(
           dataset_id="novo_dominio",
           dbt_selector=...,
           ...
       )
   ```

### **Reutilizar Task em Nova Pipeline**

Importe do módulo `common`:

```python
from pipelines.common.capture.gps.tasks import create_gps_extractor
from pipelines.common.utils.extractors.api import get_raw_api
```

## Conclusão

A arquitetura em camadas permite:

- ✅ **Reutilização máxima** de código testado
- ✅ **Consistência** entre pipelines similares
- ✅ **Manutenção centralizada** de lógica comum
- ✅ **Escalabilidade** para novos dados sem replicação
- ✅ **Testabilidade** mediante desacoplamento

Novos dados podem ser integrados apenas definindo constantes e escolhendo task de extração adequada.