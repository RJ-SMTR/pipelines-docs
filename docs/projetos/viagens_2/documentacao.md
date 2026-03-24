# FRAME-DADOS – Framework de Documentação de Projetos de Dados Públicos

## 1. Identificação do Projeto

* *Nome do Projeto:* Viagens 2.0
* *Equipe Técnica:*
    * Rodrigo Cunha (Diretor Técnico Especial de Dados e Inovação)
    * Guilherme Botelho (Engenheiro de Dados)
    * Rafael Pinheiro (Engenheiro de Dados)
* *Instituição/Setor:* PCRJ/SMTR/SUBTT
* *Data de Início:* 07/10/2025
* *Status:* Em andamento

## 2. Diagnóstico, Objetivo e Justificativa

Em 2022, durante a retomada pós-pandemia, a Secretaria Municipal de Transportes do Rio de Janeiro se deparava com um cenário de forte assimetria de informações. Não havia mecanismos consolidados de monitoramento das viagens realizadas pelos operadores, o que comprometia a transparência e dificultava a gestão da operação. Nesse contexto, foi desenvolvido um método de inferência de viagens baseado no cruzamento entre dados de GPS e informações de planejamento (OS e GTFS), posteriormente convalidado pela Controladoria Geral do Município (CGM). À época, a iniciativa representou um marco importante, pois estabeleceu, pela primeira vez, uma referência objetiva para acompanhamento da operação, reduzindo significativamente a lacuna informacional existente.

Passados três anos, o avanço tecnológico e a maturidade institucional permitem que esse modelo seja aperfeiçoado. O processo de inferência de viagens, embora tenha cumprido papel fundamental em sua origem, apresenta limitações para lidar com situações operacionais mais complexas, como diferentes itinerários possíveis para um mesmo serviço ou linhas de característica circular. Além disso, a ausência de uma interface direta para registro das viagens pelos operadores dificulta a consolidação de um processo mais transparente e auditável.

O objetivo do projeto Viagens 2.0 é, portanto, evoluir esse sistema de monitoramento, estabelecendo critérios mais robustos de validação, mecanismos de registro direto pelos operadores e integração aprimorada com dados de planejamento e posicionamento. A proposta busca aumentar a segurança jurídica e regulatória, fortalecer a confiabilidade da informação e oferecer maior clareza para todos os atores envolvidos na prestação do serviço de transporte público. Dessa forma, preserva-se a contribuição histórica do método anterior, mas adequa-se a governança da operação ao novo estágio de exigência institucional, tecnológica e social.

## 3. Fontes de Dados

* **Bases utilizadas:**

  * **GPS 2.0:** registros de geolocalização em tempo real dos veículos.
  * **OS (Ordens de Serviço):** programação oficial emitida pela **SMTR**.
  * **GTFS (General Transit Feed Specification):** dados estruturados de planejamento das linhas e serviços de transporte publicados pela **SMTR**.
  * **Camada de logradouros – IPP:** base geográfica do município utilizada, entre outras finalidades, para identificação de trechos em túneis.

* **Origem dos dados:**

  * **Operadores de transporte público**, responsáveis pelo envio de informações primárias.
  * **Secretaria Municipal de Transportes (SMTR/PCRJ)**, responsável pela consolidação, regulação e disponibilização dos dados operacionais e de planejamento.
  * **Instituto Pereira Passos (IPP/PCRJ)**, provedor da base cartográfica e de geoinformações de referência.

## 4. Levantamento de Requisitos

* **Requisitos funcionais:**

  * Implementação de uma **interface oficial** para que os operadores registrem as viagens realizadas.
  * **Validação automatizada** das viagens a partir da integração entre dados de GPS, OS e GTFS.
  * Aplicação de **critérios objetivos e auditáveis** para assegurar consistência, transparência e comparabilidade dos registros.

* **Demandas regulatórias e legais:**

  * **Contratos de concessão** firmados com as concessionárias de transporte.
  * **Acordos judiciais** que impactam diretamente a forma de apuração das viagens.
  * **Resolução SMTR nº 3.552/2022**, que estabelece parâmetros e diretrizes para o controle operacional.

* **Partes interessadas:**

  * **Áreas internas da SMTR:**

    * TR/SUBTT;
    * TR/SUBTT/CMO;
    * TR/SUBTOP.
  * **Concessionárias de transporte público**, responsáveis pela execução da operação.
  * **População usuária**, beneficiária final da melhoria na confiabilidade e transparência das informações.

## 5. Análise de Alternativas Técnicas (AIR)

### Cenário 1 – Manutenção do método atual de inferência de viagens

* **Descrição:**
  Permanecer com a apuração de viagens baseada exclusivamente na inferência por cruzamento de dados de GPS e planejamento (OS + GTFS), sem comunicação ativa dos operadores.

* **Regras principais:**

  * Viagem considerada quando o veículo transmite posição de GPS no raio aceitável dos pontos inicial e final da linha, ou no ponto regulador (linhas circulares).
  * Avaliação composta por:
    1. **Qualidade do GPS:** mínimo de 50% das posições transmitidas.
    2. **Cobertura do itinerário:** pelo menos 80% das posições dentro da rota cadastrada.
  * Condição de validade: viagem concluída integralmente, vinculada à linha correta no cadastro do GPS.
  * **Critério adicional:** velocidade média máxima de 110 km/h.
* **Avaliação:**

  * *Vantagens:* simplicidade e baixo custo.
  * *Desvantagens:* limitações de controle, menor transparência regulatória e risco de inconsistências.

### Cenário 2 – Registro de viagens pelos operadores via API consumida pela SMTR

* **Descrição:**
  Nesse modelo, os operadores enviam registros de viagens por meio de **API padronizada e consumida diretamente pela SMTR**, que cruza essas informações com dados de GPS, OS e GTFS para validação. O desenho segue benchmarking da experiência de Belo Horizonte, adaptado ao contexto do Rio de Janeiro.

* **Regras gerais:**

  * O itinerário é segmentado em trechos de aproximadamente 1 km.
  * Cada segmento possui um buffer lateral de 30 m em ambos os lados, com **ajuste de área para evitar sobreposição entre buffers adjacentes**.
  * **Definições:**

    * **Segmentos considerados:** todos os trechos resultantes da segmentação, exceto aqueles descartados pelas regras de exceção.
    * **Segmentos válidos:** segmentos considerados que possuem ao menos 1 ponto de GPS dentro do buffer.
    * **Segmentos necessários:** quantidade mínima de segmentos válidos exigida, correspondente a 90% dos segmentos considerados (arredondado para o inteiro mais próximo, com .5 para cima).
  * **Regra de validação:** a viagem é válida quando **segmentos válidos ≥ segmentos necessários**, observada a tolerância mínima de 1 segmento.

* **Exemplo da regra:**

  * N=5 segmentos → 90% = 4,5 → arredondamento = 5 → exigência ajustada para **4 segmentos necessários** (tolerância mínima).
  * N=7 segmentos → 90% = 6,3 → arredondamento = 6 → exigência = **6 segmentos necessários**.
  * N=11 segmentos → 90% = 9,9 → arredondamento = 10 → exigência = **10 segmentos necessários**.

* **Exceções (segmentos que não são considerados):**

  * Segmentos que interceptam, ainda que parcialmente, túneis;
  * Trechos com extensão inferior a 990 metros;
  * Buffers cuja área remanescente, após ajuste para eliminar sobreposição, seja inferior a 50% da área original.

* **Critérios adicionais de invalidação:**

  * Serviço não previsto na OS ou GTFS.
  * Divergência entre serviço informado pelo operador e o registrado no GPS.
  * Shape inexistente ou incompatível com o GTFS.
  * Velocidade média superior a 110 km/h.
  * Viagens sobrepostas para o mesmo veículo no mesmo período.
  * Campos obrigatórios inconsistentes ou ausentes (ID da viagem, data/hora de partida e chegada, shape_id, route_id, id_veículo).

* **Avaliação:**

  * *Vantagens:* maior controle, transparência, auditabilidade e segurança jurídica; redução de inconsistências e manipulações.
  * *Desvantagens:* maior custo de implementação e manutenção da API e dos processos de integração.

### Comparativo

* **Cenário 1:** manutenção simples e barata, mas pouco robusta e sujeita a questionamentos.
* **Cenário 2:** maior confiabilidade, segurança regulatória e aderência a boas práticas, com investimento inicial justificado pelos ganhos institucionais.

### Justificativa da escolha

A alternativa recomendada é o **registro de viagens via API consumida pela SMTR**, pois responde às vulnerabilidades do método atual, amplia a transparência e fortalece a segurança regulatória. Essa solução está alinhada com experiências bem-sucedidas em outras cidades e representa a evolução natural da governança sobre as viagens, equilibrando inovação tecnológica com confiabilidade institucional.


## 7. Riscos e Controles

### Risco 1 – Divergência de horários de início e término de viagens

* **Definição:** possibilidade de discrepância entre os horários informados pelos operadores e os captados via GPS, considerando que a remuneração é calculada por faixa horária.
* **Probabilidade e impacto:** probabilidade **alta**, com impacto relevante sobre a consistência da informação e o cálculo da remuneração.
* **Controle/Mitigação:** utilização de cercas eletrônicas (*geofences*) para delimitação dos pontos de partida e chegada, com definição de tolerâncias entre o horário informado e o captado pelo GPS, assegurando critério uniforme para fins de remuneração.

### Risco 2 – Interrupções temporárias na execução da viagem

* **Definição:** ocorrência eventual de interrupções atípicas no percurso, mesmo quando os demais parâmetros técnicos sejam atendidos.
* **Probabilidade e impacto:** probabilidade **baixa**, impacto reduzido e considerado residual.
* **Controle/Mitigação:** alternativas de mitigação foram analisadas (como horários por segmento ou tempos médios entre segmentos), mas mostraram-se pouco aplicáveis devido à complexidade dos itinerários e à variabilidade do trânsito. Assim, o risco é acompanhado e tratado como residual.

### Risco 3 – Apuração das viagens além de D+1

* **Definição:** no novo método, a apuração das viagens observa o prazo regulamentar de até dois dias úteis para que os operadores registrem suas viagens. Trata-se de uma condição do modelo, com risco de impacto apenas sobre a disponibilidade imediata de dados.
* **Probabilidade e impacto:** **ocorrência prevista**, decorrente de regra normativa, com impacto restrito ao monitoramento tempestivo.
* **Controle/Mitigação:** a SMTR implementou processo complementar de inferência de viagens, inclusive com uso dos dados de GPS dos validadores, aplicando os mesmos critérios de validação do novo método. Esse processo garante continuidade do monitoramento e do planejamento operacional, sem efeito sobre a remuneração.

### Distinção fundamental

* **Viagens válidas (para fins de remuneração):** exclusivamente aquelas informadas pelos operadores via API e validadas pela SMTR.
* **Viagens inferidas (para fins de monitoramento):** apuradas pela SMTR a partir de dados de GPS e regras complementares, utilizadas apenas para monitoramento e planejamento, sem efeito sobre repasses financeiros.

## 8. Indicadores de Impacto

* Como o sucesso do projeto será medido?
* Indicadores institucionais:
    - Avaliação antes x depois (método atual x novo método)
        - Número de viagens validadas
        - Número de viagens invalidadas
        - Número de viagens contestadas pelos operadores

## 9. Lições Aprendidas

* **O que funcionou bem:**

  * A realização de benchmarking com experiências de outras cidades, em especial a referência da Prefeitura de Belo Horizonte, trouxe insumos relevantes para a concepção do modelo adotado.

* **O que poderia ter sido feito de outra forma:**

  * Estabelecer desde o início uma definição clara e consensual de escopo junto à área demandante.
  * Formalizar de maneira antecipada os requisitos funcionais, reduzindo ajustes posteriores.
  * Pactuar critérios de aceitação logo na fase inicial, evitando revisões tardias.

* **Barreiras encontradas e superadas:**

  * O método utilizado em Belo Horizonte não pôde ser integralmente replicado no Rio de Janeiro, em razão de especificidades locais como a presença de túneis e itinerários complexos. Essa barreira foi superada por meio de parceria com o Instituto Pereira Passos (IPP), que viabilizou a identificação e exclusão adequada desses segmentos da análise.

* **Recomendações para projetos futuros:**

  * Adotar um ciclo de vida estruturado para produtos de dados, contemplando as seguintes etapas:

    1. Compreensão aprofundada do problema.
    2. Processo de benchmarking e discovery com outras cidades e entidades.
    3. Avaliação das adaptações necessárias ao contexto local.
    4. Desenvolvimento de protótipo.
    5. Validação do protótipo junto ao cliente.
    6. Desenvolvimento e implantação da solução final.
  * Garantir a elaboração e manutenção contínua da documentação do projeto, assegurando rastreabilidade e transparência em todas as fases.