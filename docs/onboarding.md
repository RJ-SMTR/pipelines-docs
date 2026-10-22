# Onboarding da equipe de dados

Este guia configura o desenvolvimento no [RJ-SMTR/pipelines_v3](https://github.com/RJ-SMTR/pipelines_v3): Python 3.13, uv, Prefect 3 e dbt Core, com autenticação Google OAuth de usuário.

As dependências são definidas pelo `pyproject.toml` e pelo `uv.lock` do checkout. Não instale pacotes avulsos com pip nessa venv.

## 1. Preparação manual no Windows

Instale WSL 2 com Ubuntu 24.04 LTS pelo PowerShell como administrador:

```powershell
wsl --install -d Ubuntu-24.04
wsl --set-default-version 2
```

Reinicie se solicitado, abra o Ubuntu e crie seu usuário e senha. Ubuntu 26.04 LTS também é aceito pelo script; novas instalações não devem usar 20.04, cujo suporte padrão terminou em 2025. O script não instala WSL nem migra a distribuição. [Ciclo de suporte do Ubuntu](https://ubuntu.com/about/release-cycle).

Instale manualmente o [VS Code no Windows](https://code.visualstudio.com/download) e as extensões **WSL** e **Python**. Abra o projeto com `code .` dentro do Ubuntu e selecione `.venv/bin/python` como interpretador. Se usar uma extensão dbt, configure-a para o dbt Core local; não permita substituir a execução por dbt Fusion ou dbt Cloud. [VS Code com WSL](https://code.visualstudio.com/docs/remote/wsl).

Use o sistema de arquivos Linux, por exemplo `~/prefeitura_rio`, para os checkouts e ambientes virtuais.

## 2. Configuração automatizada no Ubuntu

No terminal Ubuntu, execute como usuário comum:

```bash
curl -fsSL https://raw.githubusercontent.com/RJ-SMTR/pipelines-docs/main/scripts/onboarding/setup-ubuntu.sh | bash
```

Se `curl` não estiver instalado, execute primeiro:

```bash
sudo apt-get update && sudo apt-get install -y curl
```

O script instala Git, GitHub CLI, Google Cloud CLI, e uv; cria `~/prefeitura_rio`; clona `pipelines_v3` e prepara a venv Python 3.13, os hooks e os pacotes dbt Core. Também cria `.env` se ausente, configura o Bash com backup e conduz os logins GitHub e Google OAuth. Informe sua identidade Git, conta Google e os consentimentos quando solicitado; a senha de sudo é necessária para instalar os pacotes.

Não é necessário clonar `pipelines-docs`. O instalador baixa os auxiliares da `main` e os mantém em `~/.local/share/smtr/onboarding/`. Checkouts, `.env` e perfis existentes são preservados; a venv é sincronizada com o `uv.lock`. Ele não troca o Python do Ubuntu, executa modelos ou faz deploy.

Para instalar apenas a configuração Bash, substitua `| bash` por `| bash -s -- --shell-only` (requer python3 já instalado). Outras opções estão em `| bash -s -- --help`.

Ao terminar, revise as variáveis e a configuração do Bash nas próximas seções. Entre no projeto com `cd ~/prefeitura_rio/pipelines_v3`. `DBT_USER` usa seu usuário Linux por padrão e identifica seus datasets de desenvolvimento, como `seu_usuario__monitoramento`.

## 3. Variáveis e OAuth

Revise o `.env` na raiz de `pipelines_v3`. O exemplo gerado contém:

```dotenv
GCP_ACCOUNT=seu.email@exemplo.com
GCP_PROJECT_ID=rj-smtr-dev
QUOTA_PROJECT_ID=rj-smtr-dev
DBT_USER=seu_usuario
INFISICAL_ADDRESS=https://infisical.dados.rio
INFISICAL_CLIENT_ID=
INFISICAL_CLIENT_SECRET=
INFISICAL_PROJECT_ID=
```

Os campos Infisical são necessários para fluxos que acessam segredos por `pipelines/common/utils/secret.py`. Obtenha os valores com a equipe; o instalador não solicita, preenche ou imprime segredos. Não versione `.env`.

Os perfis de exemplo já usam `method: oauth`. O ADC é gravado no diretório de configuração do gcloud e descoberto pelas bibliotecas Google. Em um terminal aberto na pasta do projeto, use:

```bash
gcp-login
```

A função executa `gcloud auth login "$GCP_ACCOUNT" --enable-gdrive-access --update-adc`, depois configura quota e projeto. Erros permanecem visíveis e qualquer falha retorna código diferente de zero.

`--update-adc` substitui o ADC anterior; tanto ele quanto a conta/projeto ativos do gcloud são compartilhados pelo usuário Linux, não isolados por projeto. O projeto do gcloud não altera o projeto declarado no perfil dbt. Não execute login automaticamente a cada abertura do shell. [Referência do login Google](https://docs.cloud.google.com/sdk/gcloud/reference/auth/login).

## 4. Configuração do Bash

O instalador adiciona ao `.bashrc` um único bloco, mantendo o restante do arquivo:

```bash
# >>> SMTR onboarding >>>
source "$HOME/.config/smtr/onboarding-shell.bash"
# <<< SMTR onboarding <<<
```

O arquivo carregado garante `$HOME/.local/bin` no PATH, define `open` quando `explorer.exe` existe e fornece a função `gcp-login`. Ao abrir um terminal na pasta do projeto, como o terminal integrado do VS Code, ele ativa `.venv` e carrega as variáveis do `.env` de pastas dentro de `~/prefeitura_rio`. Após alterar o `.env`, abra um novo terminal. O `.env` deve conter apenas pares `CHAVE=valor`, sem comandos.

## 5. Validar e começar a trabalhar

No terminal novo, dentro de `pipelines_v3`:

```bash
uv sync --locked --all-packages --check
echo "DBT_USER=$DBT_USER"
gcloud auth application-default print-access-token >/dev/null && echo 'ADC OK'
```

`uv sync --check` confirma que a `.venv` corresponde ao `uv.lock` sem alterá-la. O `DBT_USER` exibido confirma que o `.env` foi carregado. A obtenção de token confirma o ADC sem imprimi-lo. Essas verificações não comprovam permissões em tabelas BigQuery, planilhas Drive, Infisical ou Prefect.

Execute dbt **Core** pelo ambiente do checkout, a partir de `queries`:

```bash
cd ~/prefeitura_rio/pipelines_v3/queries
../.venv/bin/dbt --version
../.venv/bin/dbt deps --profiles-dir ./dev
../.venv/bin/dbt parse --profiles-dir ./dev --target dev
```

`deps` instala os pacotes dbt; `parse` valida o projeto localmente e não prova acesso ao BigQuery. Para testar conexão, execute deliberadamente `../.venv/bin/dbt debug --profiles-dir ./dev --target dev`. Comandos de execução de modelos devem selecionar o escopo desejado e o target `dev`.

Instalar as ferramentas e autenticar não concede permissões IAM nem acesso aos segredos. Execução de pipelines, configuração do servidor Prefect e deploy dependem do fluxo e devem seguir as orientações da equipe.
