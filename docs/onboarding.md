# 🛠️ Tutorial de Onboarding - Equipe de Dados

## O que é o WSL?

O **WSL (Windows Subsystem for Linux)** é uma funcionalidade do Windows que permite executar um ambiente Linux completo diretamente no Windows, sem a necessidade de máquina virtual ou dual boot. Com o WSL, você pode usar ferramentas e aplicações Linux nativamente, mantendo a integração com o sistema Windows. Isso é especialmente útil para desenvolvimento, pois muitas ferramentas de dados e pipelines funcionam melhor em ambientes Linux.

---

## 1. Instalação do WSL (Subsistema do Windows para Linux)

### 1.1 Ativar WSL
- Abra o **PowerShell como Administrador**
- Execute o comando:

```bash
wsl --install
```

> Reinicie o computador após a instalação.

### 1.2 Configurar o WSL 2 como padrão
```bash
wsl --set-default-version 2
```

### 1.3 Instalar o Ubuntu 20.04
- Abra a Microsoft Store
- Procure por **Ubuntu 20.04.6 LTS**
- Clique em **Obter** e instale

---

## 2. Configuração Inicial do Ubuntu

Ao abrir o Ubuntu pela primeira vez, você será solicitado a criar um usuário e senha:
- Digite um **nome de usuário** (sem espaços, apenas letras minúsculas)
- Defina uma **senha** (ela não aparecerá na tela enquanto você digita, mas está sendo registrada)
- Confirme a senha

> **Importante:** Guarde bem essa senha, pois ela será necessária sempre que você executar comandos com `sudo`.

Após criar o usuário, atualize o sistema:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3. (Opcional) Instalar o Terminal do Windows

- Abra a **Microsoft Store**
- Instale o **Windows Terminal**

---

## 4. Instalar Git

```bash
sudo apt-get install git -y
```

Configure nome e e-mail:

```bash
git config --global user.name "Seu Nome"
git config --global user.email "seuemail@exemplo.com"
```

---

## 5. Instalar GitHub CLI

```bash
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && sudo mkdir -p -m 755 /etc/apt/sources.list.d \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y
```

```bash
sudo apt install gh
```

### Autenticar GitHub

```bash
gh auth login
```

Selecione:
- `github.com`
- Protocolo: `https`
- Método: `Login with a web browser`
- Copie o código fornecido e pressione ENTER
- Cole o código no navegador e autentique

---

## 6. Instalar Python 3.10

### 6.1 Instalar Python 3.10

```bash
sudo apt install python3.10 python3.10-venv python3.10-dev -y
```

### 6.2 Configurar Python 3.10 como versão padrão

```bash
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 2
sudo update-alternatives --config python3
```
> Selecione o número correspondente ao Python 3.10 quando solicitado.

---

## 7. Instalar Google Cloud CLI (gcloud)

### 7.1 Instalar o `apt-transport-https` e o `curl`

```bash
sudo apt-get install apt-transport-https ca-certificates gnupg curl
```

### 7.2 Importar a chave pública do Google Cloud

```bash
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
```

### 7.3 Adicionar o URI de distribuição da CLI gcloud como uma origem de pacote

```bash
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
```

### 7.3 Instalar o Google Cloud CLI

```bash
sudo apt update && sudo apt install google-cloud-cli -y
```

### 7.4 Inicializar o gcloud

```bash
gcloud init
```
> Siga as instruções para fazer login e configurar o projeto padrão.

---

## 8. Instalar o VS Code
- Baixe o instalador: https://code.visualstudio.com/download
- Instale a extensão: **Power User for DBT**

---

## 9. Clonar o Projeto da Prefeitura

### 9.1 Criar pasta base

```bash
mkdir ~/prefeitura_rio
cd ~/prefeitura_rio
```

### 9.2 Clonar repositório

```bash
gh repo clone prefeitura-rio/pipelines_rj_smtr
cd pipelines_rj_smtr
```

### 9.3 Configurar Perfis do DBT

Para que o dbt saiba como se conectar ao banco de dados, copie o arquivo de configuração de exemplo:

```bash
cp queries/dev/profiles-example.yml queries/dev/profiles.yml
```

---

## 10. Instalar Poetry

Poetry é o gerenciador de dependências Python usado no projeto.

### 10.1 Instalar Poetry

```bash
curl -sSL https://install.python-poetry.org | python3 -
```

### 10.2 Adicionar Poetry ao PATH

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## 11. Configuração do Ambiente Python

### 11.1 Criar ambiente virtual

```bash
python3.10 -m venv .pipelines
```

### 11.2 Ativar ambiente virtual

```bash
source .pipelines/bin/activate
```

---

## 12. Instalar dependências

```bash
poetry install --all-groups
pip install -e .
```

### 12.1 Instalar pre-commit

```bash
pip install pre-commit
pre-commit install
```

---

## 13. Configurar Variáveis de Ambiente

### 13.1 Criar arquivo `.env`

Na raiz do projeto, crie um arquivo chamado `.env` com o seguinte conteúdo:

```env
INFISICAL_TOKEN=
INFISICAL_ADDRESS=https://infisical.dados.rio
GOOGLE_APPLICATION_CREDENTIALS=/home/SEU_USUARIO/.config/gcloud/application_default_credentials.json
DBT_PROFILES_DIR=/home/SEU_USUARIO/prefeitura_rio/pipelines_rj_smtr/queries/dev
DBT_USER=
```
> **Importante:** Substitua `SEU_USUARIO` pelo seu nome de usuário do Ubuntu.

### 13.2 Carregar as variáveis de ambiente

Após preencher o arquivo `.env`, carregue as variáveis no terminal:

```bash
set -a && source .env && set +a
```

> **Nota:** Este comando precisa ser executado toda vez que você abrir um novo terminal. Alternativamente, você pode adicionar este comando ao final do arquivo `~/.bashrc` para carregar automaticamente:
>
> ```bash
> echo 'set -a && source ~/prefeitura_rio/pipelines_rj_smtr/.env && set +a' >> ~/.bashrc
> ```

---

## ✅ Pronto!
O ambiente está configurado para começar a trabalhar com os projetos da equipe.  
Qualquer dúvida, é só chamar! 🚀