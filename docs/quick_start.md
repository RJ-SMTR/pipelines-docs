# Quick Start

## Configuração de ambiente para desenvolvimento

### Requisitos

- Um editor de texto (recomendado VS Code)
- Python 3.10.x
- `pip`
- (Opcional, mas recomendado) Um ambiente virtual para desenvolvimento (`miniconda`, `virtualenv` ou similares)

---

### Procedimentos

- Clonar esse repositório:

```
git clone https://github.com/prefeitura-rio/pipelines_rj_smtr
```

- Criar um ambiente virtual com venv:

```
python -m venv ./venv 
```

- Ativar o ambiente:

```
source venv/bin/activate
```

Obs.: Essa maneira de criar o ambiente virtual presume que você já tenha a versão correta do python, caso você tenha uma versão diferente do Python, utilize outro tipo de gerenciador de ambientes, como `anaconda`, `miniconda`, `pyenv` ou `virtualenv`.

- Abra-o no seu editor de texto

- No seu ambiente de desenvolvimento, instalar [poetry](https://python-poetry.org/) para gerenciamento de dependências:

```
pip3 install poetry
```

- Instalar as dependências para desenvolvimento:

```
poetry install
```

- Instalar os hooks de pré-commit:

```
pre-commit install
```

- Pode ser necessário rodar manualmente o pre-commit pela primeira vez.

Obs.: o comando abaixo serve para ambientes Linux.

```
 bash .git/hooks/pre-commit 
```
Ou:

```
pre-commit run
```

- Pronto! Seu ambiente está configurado para desenvolvimento.

---

### Como testar uma pipeline localmente

Escolha a pipeline que deseja executar (exemplo, `pipelines.rj_escritorio.template_pipeline.flows.flow`):

```py
from pipelines.utils.utils import run_local
pipelines.rj_escritorio.template_pipeline.flows import flow

run_local(flow, parameters = {"param": "val"})
```
---

### Como testar uma pipeline na nuvem

1. Configure as variáveis de ambiente num arquivo chamado `.env` na raiz
   do projeto:

```
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json  # Credenciais do Google Cloud
PREFECT__BACKEND=cloud
PREFECT__SERVER__HOST=https://prefect.dados.rio/api
PREFECT__SERVER__PORT=443
VAULT_ADDRESS=https://vault.dados.rio/
VAULT_TOKEN=<token> # Valor do token do órgão para o qual você está desenvolvendo. Caso não saiba o token, entre em contato.
```

- `source .env`

- Também garanta que o arquivo `$HOME/.prefect/auth.toml` exista e tenha um conteúdo semelhante a:

```toml
# This file is auto-generated and should not be manually edited
# Update the Prefect config or use the CLI to login instead

["prefect.dados.rio"]
api_key = "<sua-api-key>"
tenant_id = "<tenant-id>"
```

- Em seguida, tenha certeza que você já tem acesso à UI do Prefect, tanto para realizar a submissão da run, como para
  acompanhá-la durante o processo de execução. Caso não tenha, verifique o procedimento em https://library-emd.herokuapp.com/infraestrutura/como-acessar-a-ui-do-prefect

2. Crie o arquivo `test.py` com a pipeline que deseja executar e adicione a função `run_cloud`
   com os parâmetros necessários:

```py
from pipelines.utils import run_cloud
from pipelines.[secretaria].[pipeline].flows import flow # Complete com as infos da sua pipeline

run_cloud(
    flow,               # O flow que você deseja executar
    labels=[
        "example",      # Label para identificar o agente que irá executar a pipeline (ex: rj-sme)
    ],
    parameters = {
        "param": "val", # Parâmetros que serão passados para a pipeline (opcional)
    }
)
```

3. Rode a pipeline com:

```sh
python test.py
```

A saída deve se assemelhar ao exemplo abaixo:

```sh
[2022-02-19 12:22:57-0300] INFO - prefect.GCS | Uploading xxxxxxxx-development/2022-02-19t15-22-57-694759-00-00 to datario-public
Flow URL: http://localhost:8080/default/flow/xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
 └── ID: xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
 └── Project: main
 └── Labels: []
Run submitted, please check it at:
http://prefect-ui.prefect.svc.cluster.local:8080/flow-run/xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

- (Opcional, mas recomendado) Quando acabar de desenvolver sua pipeline, delete todas as versões da mesma pela UI do Prefect.



