# FRAME-DADOS – Framework de Documentação de Projetos de Dados Públicos

## 1. Identificação do Projeto

* *Nome do Projeto:* Avaliação de Climatização de Viagens
* *Identificador do Projeto:* `climatizacao`
* *Equipe Técnica:*
    * Rodrigo Cunha (Diretor Técnico Especial de Dados e Inovação)
    * Adriano Neto (Analytics Engineer)
* *Instituição/Setor:* PCRJ/SMTR/SUBTT
* *Data de Início:*  21/05/2025
* *Status:* Concluído

## 2. Objetivo e Justificativa 
    
  O **transporte público municipal da cidade do Rio de Janeiro** busca constantemente implementar **melhorias no serviço** prestado à população. O **conforto térmico** é um fator crucial na garantia da qualidade deste serviço, sendo o objetivo principal da adoção de **novas medidas** que visam assegurar o bem-estar e a qualidade das viagens.

  Com o propósito de garantir a qualidade do serviço e o **conforto térmico** aos usuários, a **SMTR** estipulou regras de referência para a adequação do funcionamento operacional da frota municipal. Em conjunto, realiza o **monitoramento e a manutenção** dessas medidas de qualidade, estabelecendo um **conjunto de patamares mínimos aceitáveis** para a regularidade da climatização durante as viagens.

  Tendo em vista o **cenário de problemáticas climáticas**, faz-se necessária a adoção de melhorias para garantir o **conforto térmico**, especialmente para enfrentar as **frequentes ondas de calor** que impactam a população diariamente e podem **aumentar os riscos de problemas de saúde**. O **investimento em climatização adequada** no transporte público não apenas melhora a qualidade do serviço, mas também **impacta positivamente a satisfação e a saúde** do usuário final.

  Essas ações dão **continuidade às políticas públicas já estabelecidas**, como o **Decreto nº 38.328/2014**, que determina que todos os ônibus adquiridos para o sistema municipal sejam equipados com **ar-condicionado**. Além disso, reforçam a necessidade de **evidências técnicas** que assegurem o funcionamento adequado desses equipamentos, **requisitos que serão garantidos e detalhados nas novas regras adotadas nesta documentação**.


## 3. Diagnóstico e Fontes de Dados

* **3.1. Sistema Digital de Bilhetagem - Jaé:**
  
  Dados de temperatura interna dos veículos são provenientes do Sistema Digital de Bilhetagem fornecido pela concessionária de Bilhetagem Digital (Jaé).

  A procedência e a disponibilidade desses dados são caracterizadas pela disponibilidade constante das medições realizadas pelos sensores de temperatura localizados no interior dos veículos da frota municipal de transporte público. Disponibilizando o grau de precisão conforme manual do fabricante, observada as adequadas condições de manutenção.
  

  Apesar de algumas limitações, as medições podem ser devidamente tratadas por técnicas estatísticas robustas para identificação e mitigação de dados extremos (outliers). Estes, em poucos casos, mostram-se presentes, mas, em sua maioria, não comprometem a integridade da análise técnica e rigorosa, que utiliza regras e métodos cientificamente validados.

  Sendo estes dados apenas comunicados pelo Sistema Digital de Bilhetagem (Jaé), conforme consta na resolução  SMTR Nº 3857/2025.
  <br>  

* **3.2. Instituto Nacional de Meteorologia - INMET:** 

  Os dados meteorológicos utilizados como parâmetro de avaliação para a temperatura externa do ambiente são provenientes das 4 estações de medição do INMET referentes ao município do Rio de Janeiro, que são devidamente armazenadas e disponibilizadas publicamente no Site/Banco de Dados Meteorológicos do INMET.

  A fidedignidade e a alta precisão dos dados de temperatura fornecidos pelo Instituto Nacional de Meteorologia (INMET) são garantidas pelo emprego de tecnologia de ponta e equipamentos especializados, como termo-higrógrafos e Estações Meteorológicas Automáticas (EMAs), que asseguram medições robustas ao considerar variáveis atmosféricas correlatas, incluindo a umidade relativa do ar. O INMET opera com dois fluxos de disponibilização: Dados em Tempo Real, que são fornecidos imediatamente após a coleta e possuem alta precisão intrínseca, embora possam demandar padronização e tratamentos complementares pelo usuário final para monitoramento contínuo (o que não reflete imprecisão da medição) e os dados consolidados, que são submetidos a processos rigorosos de validação e tratamento de qualidade, sendo disponibilizados em um prazo maior e, portanto, inadequados para aplicações que exigem monitoramento estrito em tempo real.
  <br>  

* **3.3. Sistema Alerta Rio:** 
Os dados meteorológicos utilizados como opção de substituição quando houver a ausência dos dados disponíveis por determinado período no Instituto Nacional de Metereologia (INMET) serão oriundos do Sistema Alerta Rio. Sendo este o sistema de alerta de chuvas intensas e de deslizamentos em encostas da cidade do Rio de Janeiro.

## 4. Levantamento de Requisitos

* **Requisitos funcionais:**  
  - Classificar de forma clara e objetiva se a viagem efetuada está em regularidade com as regras de climatização estabelecidas pela Secretaria Municipal de Transportes (SMTR).  
  
  - **Requisitos funcionais acessórios:**
    - Tabelas, painéis ou elementos similares contendo informações atualizadas frequentemente sobre veículos com possíveis problemas de medição visando apoiar e direcionar a operação de fiscalização nas concessionárias envolvidas. 



  - [API com dados de temperatura](https://tracking.mobilidade.rio/docs), onde a operação poderá ter acesso as informações e assim poder efetuar um monitoramento em tempo real. As condições de disponbilidade serão disponibilizar as duas horas mais recentes do dia em relação ao momento da consulta a API.
    
* **Requisitos não funcionais:** 
  - Testes, validação, relacionamento de tabelas, verificação de replicabilidade e desempenho factível.
  - Os dados são públicos, não sendo abrangidos por restrições da LGPD quanto a dados sensíveis.  
  
* **Demandas regulatórias ou legais:**  
  - Acordo Judicial Nº 0072879-94.2023.8.19.0001
  - Norma ABNT NBR 15570:2021
  - Termo de conciliação  
    
* **Partes interessadas envolvidas:**  
  - Áreas internas da SMTR:
    - TR/SUBTT;
    - TR/SUBTT/CMO;
    - TR/SUBTOP.
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
  | **Desvantagens**     | - Dados com distribuição não normal (bimodal).<br>- Média e mediana não representavam adequadamente o centro.<br>- Sensível a distorções por registros extremos.<br>- Requer mais processamento e cuidado na análise individual dos dados.                                                              |
  | **Viabilidade**      | Reduzida, devido ao comportamento estatístico dos dados e limitações técnicas.                                 | Alta, pois permite validação detalhada e análise mais robusta diante das incertezas dos dados.                                      |

---
  <br>  

- **Justificativa da escolha da solução:**

  A escolha pela **avaliação por registros unitários** foi motivada por diversos fatores que comprometiam a representatividade e a confiabilidade da análise baseada em médias, tais como:

  - Presença de distribuição bimodal, dificultando representação dos dados e, portanto, a interpretação através de estatísticas de tendência central, como a média ou mediana.
  - Perda de detalhamento das variações ao longo da viagem, como temperaturas elevadas no início do trajeto e entre outros fenômenos observados ao longo das viagens.

  Ao adotar o cenário baseado em **registros unitários**, tornou-se possível:

  - Contornar as distorções observadas no cenário anterior.
  - Obter maior precisão e representatividade dos dados.
  - Garantir capacidade de validação e rastreabilidade.
  - Viabilizar uma análise mais robusta, simples e segura para a tomada de decisão.


## 7. Riscos e Controles

| Categoria                                   | Descrição                                                                                                                                                                                                 |
|---------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Riscos identificados**                    | **Possibilidade de interferência indevida nos medidores** – Operadores podem afetar o funcionamento dos sensores; responsabilidade da operadora pela etapa entre a medição e o recebimento pelo validador. |
|                                             | **Indisponibilidade do dado de temperatura interna** – Problemas técnicos após o validador que impedem o envio para a SMTR; responsabilidade da Concessionária de Bilhetagem Digital Jaé.                 |
|                                             | **Furto dos sensores** de medição.                                                                                                                                                                         |
|                                             | **Avarias nos sensores** que impeçam seu funcionamento adequado.                                                                                                                                            |
| **Probabilidade e impacto**                 | **Melhoria da qualidade da climatização** pela operadora.                                                                                                                                                  |
|                                             | **Impacto real no conforto do usuário final**.                                                                                                                                                             |

## 9. Indicadores de Impacto

* **Indicadores de sucesso do projeto:**  
  - Avaliar e medir o sucesso do projeto através da melhoria dos indicadores institucionais e técnicos, que impactarão diretamente a população que é o foco principal da busca pela melhoria desse serviço.
* **Indicadores institucionais:**  
  - Índicador de regularidade da temperatura
* **Indicadores técnicos:**
  - Índicador de veículos suspeitos.
  - Índicador de ajuste da operação:  
     Avaliado através do tempo que os indicadores anteriores progridem ou regridem em marcos temporais de 30 dias, 90 dias, 180 dias e 365 dias. Ou mesmo avaliando uma série de tempo diária.   


## 8. Lições Aprendidas

* **O que funcionou bem:** 
  - Uma análise inicial mais objetiva e sucinta visando atender demandas mais prévias. Que dessa forma, proporcionou pautar melhor as discussões sobre melhorias, resultados encontrados e caminhos a seguir.  
* **O que poderia ter sido feito de outra forma:**
  - Efetuar uma análise completa em um momento anterior a definição de quaisquer regras necessárias para aplicação posterior. Com isso, evidências e resultados prévios passam a fundamentar tecnicamente as regras e políticas públicas, ao invés de serem desenvolvidas posteriormente à sua implementação.

  - Definição inicial do escopo geral, além de possíveis hipóteses a serem trabalhadas e avaliadas ao longo da análise.

* **Barreiras encontradas e superadas:**  
  - A falta de disponibilidade completa de dados das 4 estações, o que nos guiou a utilizar o valor máximo com apenas 3 estações do total de 4 disponíveis para o município do Rio de Janeiro.  
  -  A falta de um dicionário de dados visando facilitar o entendimento e metodologia das tabelas, colunas e conceitos envolvidos no contexto de dados meteorológicos.  
  - Recaptura de temperaturas disponibilizadas pelo INMET mediante a disponibilização;  
  - Falta em todas as estações do INMET;  
* **Recomendações para projetos futuros:**  

## 13. Referências e Documentos Vinculados

  - Acordo Judicial Nº 0072879-94.2023.8.19.0001 firmado em 30 de abril de 2025 entre o Município do Rio de Janeiro e os consórcios operadores do sistema de transporte coletivo, foram estabelecidas novas diretrizes para a operação e monitoramento do serviço, incluindo obrigações específicas de transparência e cumprimento de metas operacionais sob a supervisão da SPPO.  

  - Norma ABNT NBR 15570:2021 
  - Decreto RIO n° 53.856/2023.
  - Resolução SMTR Nº 3636, de 11 de julho de 2023.  
  - NETO, Adriano. Análise da Regularidade de Temperatura - SMTR20250521. Rio de Janeiro: SMTR, 2025a. 
  - NETO, Adriano. 20250616_Análise da Regularidade de Temperatura - SMTR 2025. Rio de Janeiro: SMTR, 2025b. 
  - RIO DE JANEIRO (Município). Secretaria Municipal de Transportes (SMTR). Resolução SMTR n. 3857, de 1º de julho de 2025. 
  - TUKEY, John W. Exploratory Data Analysis. Reading, MA: Addison-Wesley, 1977.  
  - IGLEWICZ, Boris; HOAGLIN, David C. How to Detect and Handle Outliers. Milwaukee, WI: ASQC Quality Press, 1993. (ASQC Statistics Textbook Series)  
  - CAMPOS, A. R. et al. Thermal discomfort and hypertension in bus drivers and chargers in the city of São Paulo, Brazil. Applied Ergonomics, v. 47, p. 122-127, 2015. DOI: 10.1016/j.apergo.2014.09.002. Disponível em: https://www.sciencedirect.com/science/article/abs/pii/S000368701400194X. Acesso em: 8 dez. 2025.
  -  PATANIA, A. et al. Thermal comfort analysis of public transport passengers in Catania. In: WIT TRANSACTIONS ON ECOLOGY AND THE ENVIRONMENT, v. 157, p. 217-227, 2012. WIT Press. DOI: 10.2495/SDP120191. Disponível em: https://www.witpress.com/elibrary/wit-transactions-on-ecology-and-the-environment/157/23292. Acesso em: 8 dez. 2025.
  <br>

  <br>  