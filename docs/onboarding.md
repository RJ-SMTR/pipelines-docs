# 🛠️ Tutorial de Onboarding - Equipe de Dados

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

```bash
sudo apt update && sudo apt upgrade
```

---

## 3. (Opcional) Instalar o Terminal do Windows

- Abra a **Microsoft Store**
- Instale o **Windows Terminal**

---

## 4. Instalar Git

```bash
sudo apt-get install git
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

```bash
sudo apt install python3.10
```

---

## 7. Instalar o VS Code

- Baixe o instalador: https://code.visualstudio.com/download
- Instale a extensão: **Power User for DBT**

---

## 8. Clonar o Projeto da Prefeitura

### 8.1 Criar pasta base

```bash
mkdir ~/prefeitura_rio
cd ~/prefeitura_rio
```

### 8.2 Clonar repositório

```bash
gh repo clone prefeitura-rio/pipelines_rj_smtr
cd pipelines_rj_smtr
```

---

## 9. Configuração do Ambiente Python

### 9.1 Criar ambiente virtual

```bash
python3.10 -m venv .pipelines
```

### 9.2 Ativar ambiente virtual

```bash
. .pipelines/bin/activate
```

---

## 10. Instalar dependências

```bash
poetry install --all-groups
pip install -e .
```

---

## 11. Credenciais e Variáveis de Ambiente

### 11.1 Salvar JSON da conta de serviço

Salve o arquivo `staging.json` em:

```
/home/SEU_USUARIO/.basedosdados/credentials/
```

> Crie a pasta caso não exista.

---

### 11.2 Criar arquivo `.env`

Na raiz do projeto, crie um arquivo chamado `.env` com o seguinte conteúdo:

```env
INFISICAL_TOKEN=
INFISICAL_ADDRESS=https://infisical.dados.rio
GOOGLE_APPLICATION_CREDENTIALS=/home/SEU_USUARIO/.basedosdados/credentials/staging.json
BASEDOSDADOS_CREDENTIALS_PROD=
BASEDOSDADOS_CREDENTIALS_STAGING=
DBT_PROFILES_DIR=/home/SEU_USUARIO/prefeitura_rio/pipelines_rj_smtr/queries/dev
DBT_USER=
```

---

### 11.3 Gerar BASE64 do JSON

- Acesse: https://www.base64encode.org/
- Copie **todo o conteúdo do JSON** (incluindo os `{}`)  
- Cole no campo e clique em **Encode**
- Copie o resultado e cole nas variáveis:
  - `BASEDOSDADOS_CREDENTIALS_PROD`
  - `BASEDOSDADOS_CREDENTIALS_STAGING`

---

## ✅ Pronto!

O ambiente está configurado para começar a trabalhar com os projetos da equipe.  
Qualquer dúvida, é só chamar! 🚀
