# FRAME-DADOS – Framework de Documentação de Projetos de Dados Públicos

## 1. Identificação do Projeto

* *Nome do Projeto:* Avaliação de Climatização de Viagens
* *Identificador do Projeto:* `climatizacao`
* *Equipe Técnica:*
    * Rodrigo Cunha (Diretor Técnico Especial de Dados e Inovação)
    * Adriano Neto (Analista de Dados)
* *Instituição/Setor:* PCRJ/SMTR/SUBTT
* *Data de Início:*  21/05/2025
* *Status:* Em andamento

## 2. Objetivo e Justificativa

* Descreva o propósito do projeto e o problema que pretende resolver:  
  
  De forma geral o objetivo primordial do projeto é garantir o pleno funcionamento da climatização dos veículos durante as viagens da frota municipal.
    
* Contextualize com políticas públicas, metas estratégicas ou necessidades operacionais.

## 3. Diagnóstico e Fontes de Dados

* **3.1. Plataforma de bilhetagem Jaé:**
 **Bases utilizadas:**
  <br>  

* **Origem dos dados:**  
  - Plataforma de bilhetagem Jaé.  
    Assim como, dados de bilhetagem provenientes da concessionária de bilhetagem digital da prefeitura do Rio de Janeiro.

  <br>  

     - **Dados - Concessionária de Bilhetagem Digital Jaé:**  <br>  
  Segundamente, com os dados de temperatura interna temos algumas inconsistências em relação aos valores de medição de temperatura captados pelos sensores do veículos da frota municipal, com uma presença frequente de dados extremos (outliers) que vão desde medições de 0°C ou 1°C até mesmo 900°C de temperatura. Dessa forma, fazendo necessário todo uma identificação e tratamento de registros problemáticos durante toda a base de dados obtida através do gps_validador.  
  <br>  

* **3.2. INMET:**
  **Bases utilizadas:**  

  * **Origem dos dados:** 
    - Banco de Dados Meteorológicos do INMET.  
    Base de dados meteorológicos das 4 estações de medição do município do Rio de Janeiro oriundas do Banco de Dados Meteorológicos do INMET
    
  * **Avaliação da qualidade e limitações:**  
   - **Dados - Instituto Nacional de Meteorologia:**  <br>  
  Avaliando de forma objetiva as origens de dados de temperatura, temos duas principais fontes utilizadas, que foram de suma importância na busca por soluções dado o contexto de climatização de viagens de veículos do transporte público da prefeitura, apesar da disponibilidade do dado, observou-se algumas limitações que foram contornadas adequadamente, mas que carecem ser mecionadas.  <br>  
  Buscando trazer um maior detalhamente das características aos dados de temperatura oriundos do INMET, temos um dado com precisão e qualidade ótima, que dispõe de maior robustez dada a infraestrutura especializada utilizada nas estações metereológicas para captação de de temperatura, umidade do ar, precipitação e dentre outras informações. Mas, que no momento ainda demonstram algumas limitações no que tange documentação, como dicionário de variáveis ou mesmo métodos aplicados no tratamento do dados e afins, porém nada que não possa ser inferido pelo usuário da informação.  
    
  <br>  

## 4. Levantamento de Requisitos

* **Requisitos funcionais:**  
  - Classificar de forma clara e objetiva se a viagem efetuada está em regularidade com as regras de climatização impostas pela Secretaria Municipal de Transportes (SMTR).  
  
  - **Requisitos funcionais acessório:**
    - Tabelas, painéis ou algo do gêneros contendo informações atualizadas em tempo real sobre veículos com possíveis problemas de médição visando apoiar e direcionar a operação de fiscalização nas concessionárias envolvidas. 

      Para Exemplificar o que poderia constar como esses veículos com problemas, temos como exemplo:
        - Veículos que após avaliarmos a temperatura captada durante o período de 1 dia ou mesmo 1 viagem, não temos uma variação da temperatura medida. Essa avaliação pode ser feita através do cálculo do desvio padrão da temperatura no período, deverá haver um desvio padrão diferente de zero.  
  - API com dados de temperatura, onde a operação poderá ter acesso as informações e assim poder efetuar um monitoramento em tempo real. As condições de disponbilidade serão disponibilizar as duas horas mais recentes do dia em relação ao momento da consulta a API.
    
* **Requisitos não funcionais (desempenho, segurança, disponibilidade etc.):** 
  - Testes, validação, relacionamento de tabelas, verificação de replicabilidade e desempenho factível.
  - Dados públicos, portanto não há problema em relação a LGPD e entre outros fatores que vigoram sobre dados sensíveis, privados ou de terceiros.
* **Demandas regulatórias ou legais:**  
  - Acordo Judicial Nº 0072879-94.2023.8.19.0001
  - Norma ABNT NBR 15570:2021
  - Termo de conciliação
* **Partes interessadas envolvidas:**  
  - Gestores internos:
    - Subsecretário de Tecnologia em Transportes.
    - Subsecretário de Operação e Planejamento.
    - Coordenador de Monitoramento.
  - Concessionárias de Transporte Público.
  - Consumidor final (População).

## 5. Fluxo de Validação da Viagem

```
└── Ínicio - Demanda pela análise
    │
    ├── Processamento dos dados de temperatura externa brutos
    │   ├── Identificação de temperatura máxima                    
    │   └── Gerar Dados de temperatura externa por hora
    │
    ├── Processamento dos dados de temperatura interna brutos
    │   └── Realizar Remoção de Nulos  
    │   └── Realizar Remoção de outliers (IQR + Modified Z-Score)           
    │
    └── Avaliação da Regularidade e Apuração Final da Viagem 
        │
        ├── Decisão de Regularidade:
        │   │
        │   └── Condição: (Temperatura Externa - Temperatura Interna >= 8°C ou Temperatura Interna <= 24°C)
        │       │                                                 
        │       ├── SE SIM (Condição de regularidade atendida):
        │       │   └── Classificar como Registro de temperatura regular
        │       │
        │       └── SE NÃO (Condição de regularidade não atendida):
        │           └── Classificar como Registro de temperatura irregular
        │
        └── Apuração do percentual de registros de temperatura válida por viagem
            │
            └── Classificação de validade da Viagem
                │
                └── Condição: (Percentual de registros de temperatura válidos >= 80%)
                    │
                    ├── SE SIM:
                    │   └── Viagem válida
                    └── SE NÃO:
                        └── Viagem inválida
```

## 6. Análise de Impacto Regulatório (AIR)

* **Cenários avaliados:**  <br>  

  - **Primeiro cenário - Avaliação pela temperatura média dos registros:**  
  Este cenário considerava a utilização da média (ou mediana) da temperatura interna dos veículos como base para a análise.

  - **Segundo cenário - Avaliação por registros unitários:**  
  Este cenário propunha a comparação individual de cada registro de temperatura interna com o valor máximo da temperatura externa para determinar a regularidade.  
  <br>  
  
---

- **Análise comparativa (vantagens, desvantagens, viabilidade):**

  | Aspecto             | **1. Temperatura Média**                                                                                       | **2. Registros Unitários**                                                                                                          |
  |---------------------|----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
  | **Vantagens**        | - Simplicidade de cálculo e compreensão inicial.                                                               | - Maior precisão e detalhamento.<br>- Melhor representação do comportamento térmico durante a viagem.                              |
  | **Desvantagens**     | - Dados com distribuição não normal (bimodal).<br>- Média e mediana não representavam adequadamente o centro.<br>- Sensível a distorções por registros extremos.<br>- Limitações técnicas dos sensores. | - Requer mais processamento e cuidado na análise individual dos dados.                                                              |
  | **Viabilidade**      | Reduzida, devido ao comportamento estatístico dos dados e limitações técnicas.                                 | Alta, pois permite validação detalhada e análise mais robusta diante das incertezas dos dados.                                      |

---
  <br>  

- **Justificativa da escolha da solução:**

  A escolha pela **avaliação por registros unitários** foi motivada por diversos fatores que comprometiam a representatividade e a confiabilidade da análise baseada em médias, tais como:

  - Comportamento atípico dos dados devido às limitações dos medidores internos de temperatura.
  - Presença de distribuição bimodal, dificultando representação dos dados e, portanto, a interpretação através de estatísticas de tendência central, como a média ou mediana.
  - Perda de detalhamento das variações ao longo da viagem, como temperaturas elevadas no início do trajeto e entre outros fenômenos observados ao longo das viagens.

  Ao adotar o cenário baseado em **registros unitários**, tornou-se possível:

  - Contornar as distorções observadas no cenário anterior.
  - Obter maior precisão e representatividade dos dados.
  - Garantir capacidade de validação e rastreabilidade.
  - Viabilizar uma análise mais robusta, simples e segura para a tomada de decisão.


## 7. Solução Técnica Definida

* **Arquitetura de dados:**
    - Arquitura Não Relacional.
* **Ferramentas e linguagens utilizadas:**
    - Prefect.
    - Data Build Tool - DBT.
    - Google Cloud Platform - GCP.
    - Python (Pandas, Numpy, matplotlib, seaborn, scipy, plotly, etc).
    - Quarto.
    - Git/Github.  
* **Principais pipelines ou tabelas modeladas:**  

* **Padrões e naming conventions adotadas:**  

* **Mecanismos de validação e testes:**  
  - Testes de unicidade.
  - Testes de viagens avaliadas.
  - Testes de dados nulos.  
## 8. Riscos e Controles

* **Riscos identificados (técnicos, institucionais, de segurança):**
  - Possibilidade de interferência indevida no funcionamento dos medidores de temperatura por operadores e afins. Responsabilizando a operadora de forma clara e objetiva pela etapa do fluxo de captação do dado, que tange o intervalo desde a medição até a chegada do dado no validador do gps. 
  - Falta de disponibilidade do dado de temperatura interna por algum problema técnico na etapa pós validador para a SMTR, que é responsabilidade da Concessionária de Bilhetagem Digital Jaé.  
  - Furto dos sensores de medição.
  - Qualquer tipo de avaria que impeça o funcionamento adequado do sensor de temperatura.  
  
* **Probabilidade e impacto:**  
  - Melhoria da qualidade da climatização pela operadora.
  - 
* Controles ou mitigadores adotados:
  - 
  - 
## 9. Indicadores de Impacto

* **Como o sucesso do projeto será medido?**  
  Poderemos avaliar e medir o sucesso do projeto através da melhoria dos indicadores institucionais e técnicos, que impactarão diretamente a população que é o foco principal da busca pela melhoria desse serviço.
* **Indicadores institucionais:**  
  - Índice de regularidade da temperatura (descrever o que é isso)
* **Indicadores técnicos (desempenho, tempo de resposta, completude etc.):**
  - Índice de veículos suspeitos.
  - Índice de ajuste da operação:  
     Avaliado através do tempo que os indicadores anteriores progridem ou regridem em marcos temporais de 30 dias, 90 dias, 180 dias e 365 dias. Ou mesmo avaliando uma série de tempo diária.   
## 10. Plano de Manutenção Técnica

* **Frequência de revisão dos dados/pipelines:**  
  Definida de acordo com a demanda dos gestores e outros envolvidos.
* **Procedimento de versionamento:**  
  Versionamento via GitHub.  

* **Responsável pela sustentação:**  
  Equipe de dados da SMTR.
* **Monitoramento e alertas:**  
  Possívelmente verificações de duplicações, nulidade dos dados e frequência adequada de atualização do dado visando não impactar o operador.
## 11. Plano de Manutenção da Documentação

* **Responsável por atualizar o FRAME-DADOS:**  
  Adriano Neto (Analista de dados - SMTR)  

* **Frequência de revisão:**  
  Conforme a demanda dos gestores e outras autoridades envolvidas. 
* **Local de armazenamento e versão:**  
  Repositório de documentações da equipe de dados da SMTR no GitHub.  
* **Estratégia para manter o material atualizado (checklists, rotinas, versionamento):**  
  A partir das demandas e entregas de alterações iremos atualizando o material base.

## 12. Lições Aprendidas

* **O que funcionou bem:** 
  - Uma análise inicial curta para atender demandas mais urgentes e dessa forma, pautar melhor as discussões sobre melhorias, resultados encontrados e caminhos a seguir.  
* **O que poderia ter sido feito de outra forma:**
  - Efetuar uma análise completa em um momento anterior a definição de quaisquer regras necessárias para aplicação posterior. Pois assim, as avaliações, evidências e resultados servem como base teórica e prática para fundamentar regras e políticas públicas de qualidade e não de forma contrária.  

  - Definição inicial do escopo (detalhar melhor)  

* **Barreiras encontradas e superadas:**  
  - A falta de disponibilidade completa de dados das 4 estações, o que nos guiou a utilizar o valor máximo com apenas 3 estações do total de 4 disponíveis para o município do Rio de Janeiro.  
  -  A falta de um dicionário de dados visando facilitar o entendimento e metodologia das tabelas, colunas e conceitos envolvidos no contexto de dados meteorológicos.  
* **Recomendações para projetos futuros:**  
  - 

## 13. Referências e Documentos Vinculados

  - Acordo Judicial Nº 0072879-94.2023.8.19.0001 firmado em 30 de abril de 2025 entre o Município do Rio de Janeiro e os consórcios operadores do sistema de transporte coletivo, foram estabelecidas novas diretrizes para a operação e monitoramento do serviço, incluindo obrigações específicas de transparência e cumprimento de metas operacionais sob a supervisão da SPPO.  

  - Norma ABNT NBR 15570:2021 
  - Art. 3° do Decreto n° 53.856/2023.
  - Resolução SMTR Nº 3636, de 11 de julho de 2023.  
  - NETO, Adriano. Análise da Regularidade de Temperatura - SMTR20250521. Rio de Janeiro: SMTR, 2025. Disponível em: Anexo no repositório. Acesso em: 23 jun. 2025.   
  - NETO, Adriano. 20250616_Análise da Regularidade de Temperatura - SMTR 2025. Rio de Janeiro: SMTR, 2025. Apresentação em slides. Disponível em: https://docs.google.com/presentation/d/1lFGgDx2-42lpawTwoulhAXygr0CgW4-S99R2sQR-Fic/. Acesso em: 23 jun. 2025.  
  
  - TUKEY, John W. Exploratory Data Analysis. Reading, MA: Addison-Wesley, 1977.  
  - IGLEWICZ, Boris; HOAGLIN, David C. How to Detect and Handle Outliers. Milwaukee, WI: ASQC Quality Press, 1993. (ASQC Statistics Textbook Series)  
  <br>
* **Anexos:**  
  
* **Processos administrativos ou ofícios:**  
  
* **Links para dossiês complementares:**  
  <br>  