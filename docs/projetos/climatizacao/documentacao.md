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
    
  O transporte público municipal trava uma jornada constante pela busca de melhorias no serviço prestado à população. Um dos fatores que impactam diretamente na qualidade do serviço e consequentemente na satisfação do usuário do transporte público, é a climatização, que se aplicada de forma correta proporcionará a população um transporte mais confortável e de qualidade.
  
  COm o objetivo primário de alcançar níveis adequados de qualidade e conforto, a SMTR está criando regras guiarão a frota municipal para garantir a climatização adequada visando viagens mais agradáveis ao usuário. Mas, também garantindo a aplicação real na operação diária pelas operadoras das concessionárias de transportes público. Segundamente, no contexto operacional avaliar a efetividade dessas medidas, utilizou-se da construção de regras e patamares mínimos aceitáveis para a regularidade da temperatura nas viagens efetuadas, assim como punição para casos onde o patamar mínimo não for obtido.

  De forma a contextualizar melhor essa necessidade, é possível citar as grandes ondas de calor que afetam diretamente todo o planeta e que estão cada vez mais frequentes no dia-a-dia da população e que podem causar diversos malefícios à saúde do individuo. Medidas como esta podem incentivar o aumento do uso de transporte público, assim como evitar possíveis complicações de saúde durante o trajeto e garantir conforto durante o uso (OLIVEIRA, 2015).

  Essas medidas dão continuidade às políticas públicas já estabelecidas, como o Decreto nº 38.328/2014, que determina que todos os ônibus adquiridos para o sistema municipal sejam equipados com ar-condicionado. Além disso, reforçam a necessidade de evidências técnicas que assegurem o funcionamento adequado desses equipamentos, com o objetivo de atingir a meta de que 100% das viagens tenham, no mínimo, 80% dos registros de temperatura em conformidade com os parâmetros definidos neste projeto.


## 3. Diagnóstico e Fontes de Dados

* **3.1. Plataforma de Bilhetagem Digital Jaé:**
  
  Dados de temperatura interna dos veículos são provenientes do Sistema Digital de Bilhetagem fornecido pela concessionária de Bilhetagem Digital (Jaé).

  A procedência e a disponibilidade desses dados são caracterizadas pela disponibilidade constante das medições realizadas pelos sensores de temperatura localizados no interior dos veículos da frota municipal de transportes público. Embora apresentem um grau de precisão razoável, a qualidade da informação é considerada adequada, especialmente sob boas condições de manutenção dos equipamentos.

   Apesar de algumas limitações, as medições podem ser devidamente tratadas por técnicas estatísticas robustas para identificação e mitigação de dados extremos(Outliers). Estes, em poucos casos, mostram-se presentes, mas, em sua maioria, não comprometem a integridade da análise técnica e rigorosa, que utiliza regras e métodos cientificamente validados.

  Através dessa avaliação, é possível também identificar possíveis problemáticas que estarão sendo monitoradas visando reduzir e mitigar toda e qualquer intervenção indesejada na disponibilidade de informações de qualidade por defeitos técnicos, operacionais ou acidentais.
  <br>  

* **3.2. Instituto Nacional de Meteorologia - INMET:** 

  Os dados meteorológicos utilizados como parâmetro de avaliação para a temperatura externa do ambiente são provenientes das 4 estações de medição do INMET referentes ao município do Rio de Janeiro, que são devidamente armazenadas e disponibilizadas publicamente no Site/Banco de Dados Meteorológicos do INMET.

  A procedência e qualidade dos dados fornecidos pelo INMET são de alta precisão e qualidade, dada toda a tecnologia e equipamento especializado para medições de temperatura. Podemos citar o uso de termohigrógrafos e estações meteorológicas automáticas para medir e registrar a temperatura do ambiente, considerando a umidade relativa do ar e outras variáveis relevantes. Há dados disponibilizados em tempo real, mas que carecem de algumas padronizações e tratamentos (nada referente a imprecisão), e dados consolidados, os quais demoram um tempo um pouco maior para serem disponibilizados, portanto não estão disponíveis em tempo real.

  Apesar de todos os pontos positivos mencionados anteriormente, ainda é observável a carência de um dicionário de dados mais robusto e acessível, que, dessa forma, possa centralizar informações e conceitos de forma mais detalhada sobre colunas e tabelas dos dados meteorológicos.
    
  <br>  

## 4. Levantamento de Requisitos

* **Requisitos funcionais:**  
  - Classificar de forma clara e objetiva se a viagem efetuada está em regularidade com as regras de climatização impostas pela Secretaria Municipal de Transportes (SMTR).  
  
  - **Requisitos funcionais acessório:**
    - Tabelas, painéis ou elementos similares contendo informações atualizadas em tempo real sobre veículos com possíveis problemas de medição visando apoiar e direcionar a operação de fiscalização nas concessionárias envolvidas. 

      Para Exemplificar o que poderia constar como esses veículos com problemas, temos como exemplo:
        - Veículos que após avaliarmos a temperatura registrada ao longo de um dia ou mesmo 1 viagem, não é possível observar qualquer variação da temperatura medida. Essa avaliação pode ser feita através do cálculo do desvio padrão da temperatura no período, onde espera-se que o desvio padrão seja maior que zero.  

  - API com dados de temperatura, onde a operação poderá ter acesso as informações e assim poder efetuar um monitoramento em tempo real. As condições de disponbilidade serão disponibilizar as duas horas mais recentes do dia em relação ao momento da consulta a API.
    
* **Requisitos não funcionais (desempenho, segurança, disponibilidade etc.):** 
  - Testes, validação, relacionamento de tabelas, verificação de replicabilidade e desempenho factível.
  - Os dados são públicos, não sendo abrangidos por restrições da LGPD quanto a dados sensíveis.  
  
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
  Possivelmente verificações de duplicações, nulidade dos dados e frequência adequada de atualização do dado visando não impactar o operador.  

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
  - Efetuar uma análise completa em um momento anterior a definição de quaisquer regras necessárias para aplicação posterior. Com isso, evidências e resultados prévios passam a fundamentar tecnicamente as regras e políticas públicas, ao invés de serem desenvolvidas posteriormente à sua implementação.

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
  - NETO, Adriano. Análise da Regularidade de Temperatura - SMTR20250521. Rio de Janeiro: SMTR, 2025. Disponível em: Anexo no repositório institucional da SMTR. Acesso em: 23 jun. 2025.   
  - NETO, Adriano. 20250616_Análise da Regularidade de Temperatura - SMTR 2025. Rio de Janeiro: SMTR, 2025. Apresentação em slides. Disponível em: https://docs.google.com/presentation/d/1lFGgDx2-42lpawTwoulhAXygr0CgW4-S99R2sQR-Fic/. Acesso em: 23 jun. 2025.  
  
  - TUKEY, John W. Exploratory Data Analysis. Reading, MA: Addison-Wesley, 1977.  
  - IGLEWICZ, Boris; HOAGLIN, David C. How to Detect and Handle Outliers. Milwaukee, WI: ASQC Quality Press, 1993. (ASQC Statistics Textbook Series)  
  <br>
* **Anexos:**  
  
* **Processos administrativos ou ofícios:**  
  
* **Links para dossiês complementares:**  
  <br>  