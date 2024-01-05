### Estrutura de diretórios

```
├── pipelines
│   ├── nome_dataset_projeto # diretório de projeto
│   │   ├── flows.py # declaração dos flows
│   │   ├── __init__.py # obrigatório para que o python reconheça como pacote, pode estar vazio
│   │   ├── tasks.py # declaração das tasks
│   |   ├── schedules.py # declaração de schedules
|   |   └── utils.py  # funções auxiliares
│   ├── constants.py # valores constantes
|   ├── templates
|   │   ├── flows.py # flows genéricos
|   │   ├── __init__.py # inicia o pacote
|   |   └── tasks.py # tasks genéricas
│   └── utils
│       ├── __init__.py # inicia o pacote
│       ├── secret.py # funções para acessar tokens e secrets necessários
│       └── utils.py # funções auxiliares 
├── queries
│   ├── dbt_project.yml # configurações do dbt e dos modelos
│   ├── dev
│   │   ├── __init__.py # inicia o pacote
│   │   ├── profiles-example.yml # arquivo de exemplo para criação do profiles.yml
|   |   ├── profiles.yml # criado localmente, contém configurações para teste local
│   │   ├── run.py # arquivo de teste local dos modelos dbt
│   │   └── utils.py # funções auxiliares do dbt
│   ├── macros
│   │   ├── nome_macro.sql # scripts que podem ser reutilizados várias vezes (similar a uma função)
│   ├── models
│   │   ├── nome_dataset
│   │   │   ├── nome_modelo.sql # instruções sql para materialização de uma tabela ou view
│   │   │   ├── schema.yml # estrutura e documentação do modelo
│   │   ├── sources.yml # fonte dos modelos DBT
│   ├── profiles.yml # configuração do ambiente cloud
│   └── tests # arquivos para testar a qualidade dos dados
└── README.md # descrição do repositório


```
