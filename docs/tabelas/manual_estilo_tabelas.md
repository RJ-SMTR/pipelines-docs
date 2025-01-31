# Manual de Estilo de Modelos e Tabelas

Esta página é baseada no [manual de estilo da Base dos Dados](https://basedosdados.github.io/sdk/style_data/)

## Modelos DBT

### Organização do Diretório models

O diretório `queries/models` deve ser dividido em pastas referentes aos datasets do BigQuery em que cada tabela será criada. Cada pasta
de dataset pode conter uma subpasta `staging`, para armazenar os modelos intermediários para a criação das tabelas e views finais. Além disso, cada
dataset deve contenter um arquivo schema.yml para a criação das descrições das tabelas, views e colunas.

<br>Exemplo:
```
└── queries
    └── models
       └── nome_dataset
            ├── nome_modelo.sql # instruções sql para materialização de uma tabela ou view
            ├── schema.yml # estrutura e documentação do modelo
            └── staging
                └── nome_modelo_intermediario.sql
```

### Estruturação dos Modelos

## Tabelas e Datasets

### Nomeação de Datasets

- Caso sejam para tabelas de uso geral, os datasets são nomeados de acordo com a categoria dos dados armazenados.
<br><br>Exemplo:
    - `bilhetagem`
    - `financeiro`
    - `subsidio`

- Os datasets também podem ser nomeados de forma a indicar a finalidade específica em que os dados são usados
<br><br>Exemplo:
    - `validacao_dados_jae`

- Ou com o nome de um dashboard, utilizando o prefixo `dashboard_`
<br><br>Exemplo:
    - `dashboard_subsidio_sppo`

### Nomeação de Tabelas

- As tabelas devem ser sempre nomeadas no singular

- Caso a tabela tenha algum qualificador, por exemplo `aux` e `view`, ele deve ser colocado como prefixo. Exemplo: `aux_gratuidade`

- A nomeação de tabelas não agregadas é menos estruturada, devendo apenas indicar claramente qual informação que se encontra nela.

- Para tabelas agregadas, nós nomeamos de forma a indicar o nivel de agregação do menor para o maior. Exemplo:  
    `ordem_pagamento_servico_operador_dia`
    - Este exemplo indica uma tabela com os dados das ordens de pagamento, agregados por `servico` (campo mais específico), `operador` e `dia` (campo mais geral)

### Nomeação e Tipos de Colunas

- Procurar usar os nomes que já são utilizados. Exemplos: `data`, `servico`, `modo`, `id_veiculo`.
- Ser o mais claro e intuitivo possível.
- O nome das colunas devem ser escritos em snake_case (todas as letras minúsculas e palavras separadas por `_`).
- Colunas do tipo booleano devem ter um prefixo `indicador_`. Exemplo: `indicador_transacao_valida`.
- Colunas numéricas com ponto flutuante que representam valores financeiros devem utilizar o tipo `NUMERIC`.
- Colunas de id devem ser do tipo `STRING`, exceto se este for o campo de partição da tabela.

### Ordenamento de Colunas

- Os primeiros campos devem ser sempre a coluna de partição da tabela (se houver) e a chave única da tabela, nesta ordem.
  - Caso não tenha chave única, as chaves primárias devem ser dispostas em ordem decrescente de abrangência (Exemplo: `modo`, `id_servico`, `id_operador`)
- As próximas colunas devem ser outras informações identificadores em ordem decrescente de abrangência.
- Colunas de `id`, sua descrição e outras informações relativas a ele devem permanecer agrupadas. Sempre com o `id` sendo a primeira coluna. Exemplos: `id_servico`, `servico`, `descricao_servico`, `id_operador`, `operador`
- Colunas qualitativas devem ser agrupadas por tema e dispostas em ordem decrescente de relevância.
- O mesmo deve ser feito para colunas quantitativas, em seguida.
- Por fim, deve ser incluídas as colunas de controle: `datetime_captura` (se aplicável), `datetime_ultima_atualizacao`, `versao`

- Exemplo de ordenamento:  
    `data` (partição)  
    `id_transacao` (chave única)  
    `datetime_transacao` (identificador temporal)  
    `datetime_processamento` (identificador temporal)  
    `modo` (identificador modo)  
    `id_consorcio` (identificador consorcio)  
    `consorcio` (identificador consorcio)  
    `id_operadora` (identificador operadora)  
    `operadora` (identificador operadora)  
    `id_servico_jae` (identificador servico)  
    `servico_jae` (identificador servico)  
    `descricao_servico_jae` (identificador servico)  
    `sentido` (identificador sentido)  
    `id_veiculo` (identificador veiculo)  
    `id_validador` (identificador validador)  
    `id_cliente` (identificador cliente)  
    `tipo_pagamento` (qualitativa)  
    `tipo_transacao` (qualitativa)  
    `tipo_transacao_smtr` (qualitativa)  
    `tipo_gratuidade` (qualitativa)  
    `id_tipo_integracao` (qualitativa)  
    `id_integracao` (qualitativa)  
    `latitude` (qualitativa)  
    `longitude` (qualitativa)  
    `stop_id` (qualitativa)  
    `stop_lat` (qualitativa)  
    `stop_lon` (qualitativa)  
    `valor_transacao` (quantitativa)  
    `valor_pagamento` (quantitativa)  
    `datetime_captura` (controle)  
    `datetime_ultima_atualizacao` (controle),  
    `versao` (controle)  

## Unidades de medida

As unidades de medida devem ser registradas na descrição da coluna entre parênteses, garantindo clareza e padronização na interpretação dos dados. Nossas regras são:

- Caso a coluna represente um valor absoluto, utilize apenas a unidade correspondente (ex.: R$, km, min).
- Se a unidade estiver associada a uma referência, utilize o formato "Unidade/Referência" para indicar a relação entre grandezas (ex.: R$/km, km/h).
- Sempre use abreviações padronizadas para unidades, evitando variações informais (ex.: h para horas, não hrs).
- Caso a unidade não seja óbvia, inclua uma explicação sucinta.

<br>Exemplo:
- "Valor máximo de subsídio, conforme tipo de viagem (R$/km)."
- "Distância percorrida (km)."

## Cobertura temporal

Preencher a coluna `cobertura_temporal` nos metadados de tabela, coluna e chave (em dicionários) segue o seguinte padrão.

- Formato geral: `data_inicial(unidade_temporal)data_final`
    - `data_inicial` e `data_final` estão na correspondente unidade temporal.
        - Exemplo: tabela com unidade `ano` tem cobertura `2005(1)2018`.
        - Exemplo: tabela com unidade `mes` tem cobertura `2005-08(1)2018-12`.
        - Exemplo: tabela com unidade `semana` tem cobertura `2005-08-01(7)2018-08-31`.
        - Exemplo: tabela com unidade `dia` tem cobertura `2005-08-01(1)2018-12-31`.

## Dicionários

- Cada base inclui somente um dicionário (que cobre uma ou mais tabelas).
- Para cada tabela, coluna, e cobertura temporal, cada chave mapeia unicamente um valor.
- Chaves não podem ter valores nulos.
- Dicionários devem cobrir todas as chaves disponíveis nas tabelas originais.