# Padrões de Tratamento de Erros e Notificações Discord

## Visão Geral

Este documento descreve os padrões padronizados para tratamento de erros e notificações via Discord na plataforma de pipelines SMTR. O objetivo é garantir consistência na comunicação de falhas, rastreamento de exceções e alertas operacionais.

## 1. Componentes Principais

### 1.1 Sentry para Rastreamento de Exceções

**Arquivo**: `pipelines/common/tasks.py`

A inicialização do Sentry deve ocorrer no início de cada flow:

```python
@task
def initialize_sentry(env: str):
    """
    Inicializa o cliente Sentry para rastreamento de exceções
    
    Args:
        env (str): Ambiente de execução (dev/prod)
    """
    sentry_sdk.init(
        dsn=get_env_secret("sentry_dsn"),
        environment=env,
        traces_sample_rate=1.0,
    )
```

**Padrão de uso em flows:**

```python
@flow(log_prints=True)
def meu_flow(env: Optional[str] = None):
    env = get_run_env(env=env, deployment_name=runtime.deployment.name)
    sentry = initialize_sentry(env=env)
    # ... resto do flow aguarda sentry
```

**Responsabilidades**:
- Capturar exceções não tratadas
- Rastrear contexto de execução (versão, ambiente)
- Integrar com alertas de on-call

---

### 1.2 Discord para Notificações de Falha

**Arquivo**: `pipelines/common/utils/discord.py`

#### Função Base: `send_discord_message`

```python
def send_discord_message(message: str, webhook_url: str):
    """
    Envia uma mensagem para um webhook do Discord
    
    Args:
        message (str): Corpo da mensagem (suporta Markdown Discord)
        webhook_url (str): URL completa do webhook
    """
```

#### Função de Formatação: `format_send_discord_message`

```python
def format_send_discord_message(
    message: str,
    title: Optional[str] = None,
    color: Optional[int] = None,
) -> str:
    """
    Formata a mensagem com embed Discord
    
    Args:
        message (str): Conteúdo da mensagem
        title (str): Título do embed
        color (int): Cor hexadecimal (ex: 0xFF0000 para vermelho)
    
    Returns:
        str: JSON para envio ao webhook
    """
```

---

### 1.3 Task para Envio de Notificações

**Arquivo**: `pipelines/common/tasks.py`

```python
@task
def task_send_discord_message(message: str, webhook: str):
    """
    Task Prefect para enviar mensagens Discord
    
    Args:
        message (str): Conteúdo da mensagem
        webhook (str): Chave do webhook no secret (ex: 'alert_webhook')
    
    Recupera a URL completa do secret conforme padrão:
    - Secret path: WEBHOOKS_SECRET_PATH
    - Chave específica: webhook parameter
    """
    webhook_secret = get_env_secret(constants.WEBHOOKS_SECRET_PATH)
    webhook_url = webhook_secret[webhook]
    send_discord_message(message=message, webhook_url=webhook_url)
```

---

## 2. Padrões por Tipo de Pipeline

### 2.1 Pipelines de Captura (Capture)

**Localização**: `pipelines/common/capture/default_capture/`

#### Cenário: Detecção de Tabelas sem Filtro Configurado

**Arquivo**: `pipelines/capture__jae_backup_billingpay/tasks.py`

```python
@task
def get_non_filtered_tables(
    database_name: str,
    database_config: dict,
    table_info: list[dict],
) -> tuple[bool, list[dict]]:
    """
    Identifica tabelas grandes (>5000 registros) sem filtro incremental
    
    Returns:
        (bool, list): (enviar_alerta, lista_de_tabelas)
    """

@task
def create_non_filtered_discord_message(
    database_name: str,
    table_count: list[dict],
) -> str:
    """
    Cria mensagem Discord com detalhes das tabelas problemáticas
    """
    message = f"Database: {database_name}\nAs seguintes tabelas não possuem filtros:\n"
    message += "\n".join([f"{t['table']}: {t['ct']} registros" for t in table_count])
    return message
```

**Padrão no flow**:

```python
send_message, table_count = get_non_filtered_tables(...)

if send_message:
    message = create_non_filtered_discord_message(
        database_name=database_name,
        table_count=table_count,
    )
    task_send_discord_message(
        message=message,
        webhook=jae_constants.ALERT_WEBHOOK  # ex: 'jae_alerts'
    )
```

---

### 2.2 Pipelines de Tratamento (Treatment)

**Localização**: `pipelines/common/treatment/default_treatment/tasks.py`

#### Cenário: Falhas em Testes dbt

**Função**: `dbt_test_notify_discord`

```python
@task
def dbt_test_notify_discord(
    test_results: dict,
    materialization_context: DBTSelectorMaterializationContext,
):
    """
    Notifica Discord quando testes dbt falham
    
    Args:
        test_results (dict): Resultado da execução dbt test
        materialization_context: Contexto com informações do dataset/seletor
    """
```

**Padrão de uso**:

```python
dbt_test_results = run_dbt_tests(...)

if dbt_test_results["status"] == "error":
    dbt_test_notify_discord(
        test_results=dbt_test_results,
        materialization_context=context,
    )
```

---

### 2.3 Pipelines de Controle (Control)

**Localização**: `pipelines/control__source_freshness/`

#### Cenário: Verificação de Atualidade de Dados

**Função**: `source_freshness_notify_discord`

```python
@task
def source_freshness_notify_discord(freshness_results: dict):
    """
    Notifica quando fontes de dados estão desatualizadas (stale)
    
    Args:
        freshness_results (dict): Resultado do dbt source freshness
    """
```

**Estrutura esperada**:

```python
{
    "alert": {
        "source_name": str,
        "table_name": str,
        "error_description": str,
        "last_update": datetime,
    }
}
```

---

## 3. Configuração de Webhooks

### 3.1 Locais de Webhook

Webhooks são armazenados em secret conforme:

**Path padrão**: `WEBHOOKS_SECRET_PATH` (definido em `pipelines/common/constants.py`)

**Chaves conhecidas**:

| Chave | Propósito | Usado em |
|-------|----------|---------|
| `alert_webhook` | Alertas operacionais genéricos | múltiplos pipelines |
| `jae_alerts` | Alertas específicos da Jaé BillingPay | `capture__jae_backup_billingpay` |
| `dbt_webhook` | Alertas de testes dbt | `treatment__*` |
| `freshness_webhook` | Alertas de atualidade de dados | `control__source_freshness` |

### 3.2 Injeção de Webhooks em Secrets

**Arquivo**: `pipelines/common/utils/env.py`

```python
def validate_bd_credentials():
    """
    Valida e injeta credenciais de webhook no ambiente
    """
```

---

## 4. Padrão de Tratamento de Erros em Tasks

### 4.1 Estrutura Recomendada

```python
from prefect import task
from pipelines.common.utils.secret import get_env_secret
from pipelines.common.utils.discord import send_discord_message

@task(retries=3, retry_delay_seconds=60)
def minha_task(param1: str):
    """
    Task com retry automático e notificação de falha
    """
    try:
        # Lógica principal
        resultado = processar(param1)
        return resultado
    except SpecificException as e:
        # Exceção esperada - notificar e falhar controladamente
        mensagem = f"Erro esperado em minha_task: {str(e)}"
        print(f"ERROR: {mensagem}")
        # Sentry rastreará automaticamente via handler de flow
        raise
    except Exception as e:
        # Exceção inesperada - logar e re-lançar
        print(f"UNEXPECTED ERROR: {str(e)}")
        raise
```

### 4.2 Handler de Falha de Flow

**Arquivo**: `pipelines/common/utils/prefect.py`

```python
def handler_notify_failure():
    """
    Handler de falha de flow que notifica Discord
    
    Executado automaticamente quando um flow falha
    """
```

**Ativação em flow**:

```python
@flow(on_failure=[handler_notify_failure])
def meu_flow():
    pass
```

---

## 5. Contexto de Execução

### 5.1 Informações Capturadas

Ao enviar notificações, incluir:

- **Flow Run ID**: `runtime.flow_run.id`
- **Deployment Name**: `runtime.deployment.name`
- **Scheduled Start Time**: `runtime.flow_run.scheduled_start_time`
- **Environment**: `get_run_env()`
- **Timestamp**: `get_scheduled_timestamp()`

### 5.2 Exemplo de Mensagem Estruturada

```python
def criar_mensagem_erro(context_info: dict) -> str:
    return f"""
:warning: **Erro em Pipeline**

**Flow**: {context_info['deployment']}
**Run ID**: {context_info['run_id']}
**Ambiente**: {context_info['env']}
**Timestamp**: {context_info['timestamp']}

**Descrição**:
{context_info['error_message']}

**Ação**:
Verifique os logs em Prefect Cloud.
    """
```

---

## 6. Integração com Sentry e Discord

### 6.1 Fluxo Integrado

1. **Erro ocorre** → Sentry captura automaticamente
2. **Task falha** → Handler `handler_notify_failure` acionado
3. **Discord notificado** → Via webhook configurado
4. **Contexto enviado** → Para debugging posterior

### 6.2 Evitar Duplicação

- **Sentry**: Para rastreamento técnico detalhado
- **Discord**: Para alertas operacionais curtos
- **Logs Prefect**: Para auditoria completa

**Padrão**:
- Não enviar dump de stack trace para Discord (usar Sentry para isso)
- Discord deve ter resumo e link para Prefect Cloud

---

## 7. Boas Práticas

### 7.1 Mensagens Discord

✅ **BOM**:
- Usar embeds com cores diferenciadas (erro=vermelho, aviso=amarelo)
- Incluir links para Prefect Cloud e Sentry
- Mencionar @channel/group apenas para críticos
- Timestamp em timezone local (America/Sao_Paulo)

❌ **RUIM**:
- Enviar dumps completos de erro
- Mensagens genéricas sem contexto
- Múltiplas notificações para o mesmo erro

### 7.2 Retry e Idempotência

```python
@task(retries=3)
def tarefa_critica():
    """Task crítica com retry automático"""
    # Implementar idempotência para suportar retries
    try:
        resultado = operacao()
    except TransientError:
        # Sentry e Discord notificam na última tentativa
        raise
```

### 7.3 Secrets e Credenciais

- **Nunca** incluir credenciais em mensagens Discord
- Usar `get_env_secret()` para webhooks
- Validar `WEBHOOKS_SECRET_PATH` em startup

---

## 8. Troubleshooting

### Problema: Discord não recebe notificação

1. Verificar se webhook URL está no secret correto
2. Validar webhook existe (fazer POST manual)
3. Confirmar `WEBHOOKS_SECRET_PATH` está definido
4. Checar se task executou (logs Prefect)

### Problema: Muitas notificações duplicadas

1. Revisar handlers de flow (remover duplicação)
2. Usar `@task(cache_key_fn=...)` para evitar re-execução
3. Implementar debounce no webhook (verificar ID de mensagem)

### Problema: Contexto incompleto em notificações

1. Chamar `get_run_env()` e `get_scheduled_timestamp()` no início
2. Passar context explicitamente entre tasks
3. Usar `runtime.flow_run.*` para metadados Prefect

---

## 9. Referência de Constantes

**Arquivo**: `pipelines/common/constants.py`

```python
WEBHOOKS_SECRET_PATH = "webhooks"  # Path no Infisical/secret manager
TIMEZONE = "America/Sao_Paulo"
```

**Arquivo**: `pipelines/common/capture/jae/constants.py`

```python
ALERT_WEBHOOK = "jae_alerts"  # Chave no WEBHOOKS_SECRET_PATH
JAE_SECRET_PATH = "jae_credentials"
```

---

## 10. Evolução Futura

- [ ] Implementar rate limiting no Discord (máx 1 msg/min por webhook)
- [ ] Adicionar templates de mensagem por tipo de erro
- [ ] Integrar Slack como alternativa (decorator agnóstico)
- [ ] Dashboard de notificações (histórico)
- [ ] Escalação automática (Sentry → Slack → SMS)