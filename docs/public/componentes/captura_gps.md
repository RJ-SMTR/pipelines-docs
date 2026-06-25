# Componente Comum de Captura GPS

## Visão Geral

O componente de captura GPS é um módulo reutilizável que padroniza a extração de dados de posicionamento de veículos de três operadoras de rastreamento: **Cittati**, **Conecta** e **Zirix**. Ele oferece uma interface consistente para capturar registros de GPS (telemetria) e dados de realocação de viagens.

## Objetivo

Centralizar a lógica de integração com APIs de GPS de múltiplas operadoras, evitando duplicação de código e garantindo consistência nos pipelines de captura.

## Funcionamento

### Arquitetura

O componente utiliza o padrão de **contexto reutilizável** (`SourceCaptureContext`) da plataforma e se integra com:

- **Extractors de API**: fazem requisições HTTP às APIs das operadoras
- **Operadoras suportadas**: Cittati, Conecta, Zirix
- **Tipos de dados**: registros (telemetria em tempo real) e realocações (correções históricas)

### Fluxo de Captura

```
Timestamp de Execução
    ↓
Identificar Operadora e Tipo de Dado
    ↓
Montar URL e Parâmetros (janela temporal específica)
    ↓
Fazer Requisição HTTP com Credenciais
    ↓
Salvar Resposta em Formato Raw (JSON)
```

### Janelas Temporais

O componente adapta a janela de captura conforme o tipo de dado:

- **Registros (telemetria)**: últimos 6-5 minutos
  - Captura dados mais recentes com pequena margem de segurança
  - Reexecuções podem gerar duplicatas (tratadas em etapa de deduplicação posterior)

- **Realocações (viagens retroativas)**: últimos 10 minutos até presente
  - Captura correções de viagens não informadas ou mal posicionadas

## Configuração por Operadora

Cada operadora possui:
- **URL base** da API
- **Endpoints** distintos (registros vs. realocações)
- **Credenciais** armazenadas em secrets

| Operadora | Base URL | Secret Path |
|-----------|----------|-------------|
| Cittati | `https://servicos.cittati.com.br/WSIntegracaoCittati/SMTR/v2` | `cittati_api` |
| Conecta | `https://ccomobility.com.br/webservices/binder/wsconecta` | `conecta_api` |
| Zirix | `https://integration.systemsatx.com.br/Globalbus/SMTR/V2` | `zirix_api` |

## Integração com Pipelines

### Uso em Flows de Captura

Cada operadora tem um conjunto de 2 pipelines (registros + realocações):

```python
from pipelines.common.capture.gps.tasks import create_gps_extractor

create_capture_flows_default_tasks(
    env=env,
    sources=[CITTATI_REGISTROS_SOURCE],
    timestamp=timestamp,
    create_extractor_task=create_gps_extractor,  # ← componente reutilizável
    recapture=recapture,
)
```

### Pipelines Instanciados

- `capture__cittati_registros` / `capture__cittati_realocacao`
- `capture__conecta_registros` / `capture__conecta_realocacao`
- `capture__zirix_registros` / `capture__zirix_realocacao`

Todos utilizam o mesmo `create_gps_extractor` para extrair dados.

## Artefatos Gerados

### Dados Brutos

Armazenados em **Google Cloud Storage** com estrutura:

```
gs://bucket/data/
  raw/
    {operadora}/
      {tipo_dado}/
        data=YYYY-MM-DD/
          hora=HH/
            YYYYMMDD_HHMMSS_000.json
```

Exemplo: `gs://bucket/data/raw/cittati/registros/data=2025-05-09/hora=14/20250509_141530_000.json`

### Características

- **Formato**: JSON (resposta bruta da API)
- **Particionamento**: por data e hora UTC
- **Retenção**: conforme política de dados brutos da plataforma
- **Acesso**: restrito a pipelines internos

## Estágio de Tratamento

Os dados brutos são posteriormente:

1. **Validados** (completude, tipos de dados)
2. **Normalizados** (timestamps, coordenadas)
3. **Consolidados** em tabelas de análise (`monitoramento.gps_validador`, etc.)

Isso ocorre em pipelines de tratamento específicos (ex: `treatment__gps_validador`).

## Considerações Operacionais

### Qualidade de Dados

- APIs podem ter indisponibilidades — implementar retry é responsabilidade do orquestrador (Prefect)
- Duplicatas podem ocorrer em reexecuções — tratamento é feito na etapa de consolidação
- Dados malformados são registrados em logs para investigação

### Performance

- Janelas pequenas (5-10 min) garantem volumes reduzidos e latência baixa
- Paralelização: três operadoras podem rodar simultaneamente

### Segurança

- Credenciais armazenadas em **secrets management** (Infisical)
- Comunicação via HTTPS
- Dados são salvos em storage protegido (GCS com controle de acesso)

## Manutenção e Extensão

### Adicionar Nova Operadora

1. Incluir entrada em `GPS_SOURCE_CONFIGS` (constants.py)
2. Criar flows `capture__{operadora}_registros` e `capture__{operadora}_realocacao`
3. Definir horários de execução em `prefect.yaml`
4. Novas integrações reutilizam `create_gps_extractor` automaticamente

### Monitorar Falhas

- Verificar logs do Prefect para tentativas e erros
- Alertas via Discord para indisponibilidades de API
- Métricas em infraestrutura (uptime de API)

## Referências

- **Código**: `pipelines/common/capture/gps/`
- **Flows**: `pipelines/capture__*/`
- **Tratamento**: pipelines `treatment__gps_validador`
- **Dados**: dataset `monitoramento.gps_validador` (BigQuery)