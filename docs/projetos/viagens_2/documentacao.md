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

## 2. Objetivo e Justificativa

* Contexto
    * Em 2022 na retomada da pandemia existia uma excessiva assimetria de informações, a SMTR não tinha nenhum controle sobre as viagens realizadas pelos operadores de transporte, o que gerava insegurança jurídica e operacional (exceto RDO)
    * Método convalidado pela Controladoria Geral do Município (CGM)

* Vulnerabilidades do método atual
    * Desenvolve um processo de inferência de viagens a partir do cruzamento entre os dados de GPS e os dados de planejamento (OS + GTFS)
    * Não existe uma interface para quem opera/executa a viagem informar as viagens que o operador realiza
    * Há falhas recorrentes em itinerários complexos e em trajetos circulares
    * Em um mesmo serviço e sentido pode ser realizado mais de um itinerário, e a SMTR necessita fazer um processo de inferência para identificar qual itinerário foi realizado
    * Riscos
        * Poder concedente: apurar possíveis viagens que não ocorreram de fato
        * Operador: não ter como informar viagens que foram realizadas, mas não estão apuradas
        * Operador: como o poder concedente infere as viagens, é possível que a caracterização de início/fim de viagem não seja a mais adequada, o que por sua vez pode interferir na remuneração do operador pois o cálculo é feito por faixa horária

    * O método atual possui poucos critérios de validação, o que pode favorecer os operadores. É o mesmo método desde 2022, na qual os operadores já se adaptaram e conhecem as regras de inferência, o que pode levar a uma manipulação dos dados de GPS para obter uma remuneração maior.
    * Em 2022 era um outro contexto e agora há espaço para aprimorar o processo de validação e controle das viagens realizadas pelos operadores de transporte.

## 3. Diagnóstico e Fontes de Dados

* Bases utilizadas:
    * GPS 2.0: dados de geolocalização dos veículos
    * OS: ordens de serviço emitidas pelo poder concedentes
    * GTFS: dados de planejamento das linhas de transporte emitidos pelo poder concedente
    * Camada logradouro: dados geográficos dos logradouros do município para fins de identificação de túneis
* Origem dos dados:
    * Operadores de transporte
    * PCRJ/SMTR
    * PCRJ/IPP

## 4. Levantamento de Requisitos

* Requisitos funcionais:
    * Interface para os operadores informarem as viagens realizadas
    * Validação de viagens com base em GPS, OS e GTFS
    * Validação com base em critérios objetivos

* Demandas regulatórias ou legais:
    * Contrato de concessão
    * Acordo judicial
    * RESOLUÇÃO SMTR Nº 3552, DE 12 DE SETEMBRO DE 2022

* Partes interessadas envolvidas:
  - Gestores internos:
    - Subsecretário de Tecnologia em Transportes.
    - Subsecretário de Operação e Planejamento.
    - Coordenador de Monitoramento.
  - Concessionárias de Transporte Público.
  - Consumidor final (População).

## 5. Análise de Alternativas Técnicas (AIR)

* **Cenários avaliados:**
    - **Cenário 1 - Manter o método atual de inferência de viagens:**
        - Regras
            - II - uma viagem será avaliada quando um veículo comunicar a posição, por GPS, no raio aceitável nos pontos
                início e im da linha, ou no ponto regulador para o caso das linhas circulares;
                III - a avaliação da viagem será composta por dois parâmetros:
                a) qualidade da transmissão das posições de GPS;
                b) quantidade de transmissão das posições de GPS dentro do itinerário.
                § 1º Uma viagem apenas será considerada válida quando ela for completamente concluída conforme os
                parâmetros de conformidade, descritos no artigo 2º.
                § 2º A avaliação da viagem só ocorrerá para os veículos devidamente associados à linha correta no cadastro do
                GPS, desde o momento de início da viagem até o término.
                § 3º A conformidade da distância percorrida em comparação ao planejado para a viagem de cada linha será aferida por meio da comunicação do GPS nos pontos inicial e inal (ou regulador), como também pela comunicação
                ao longo do itinerário cadastrado.
                Art. 2º Os valores dos parâmetros dispostos no artigo 1º são:
                I - raio aceitável: 500 metros;
                II - qualidade do GPS: 50%;
                III - quantidade de transmissões dentro do itinerário: 80%.
            
            - Critérios adicionais
                - Velocidade média máxima: 110 km/h

    - **Cenário 2 - Implementar uma interface para registro de viagens pelos operadores:**
        - Realizado benchmarking com a experiência de outra cidade que fez implementação semelhante (Prefeitura de Belo Horizonte)
            - Regras
                - Regra geral
                    - Itinerário é segmentado em segmetnos de ~1 km (o menor sempre fica o mais próximo possível do meio)
                    - Cada segmento tem um buffer de 30 m para cada lado (sem sobreposição entre eles)
                    - Segmentos válidos: segmentos considerados que possuem, no mínimo, 1 ponto de GPS dentro do buffer
                    - Segmentos necessários: 90% dos segmentos considerados
                    - Segmentos válidos >= segmentos necessários: viagem válida

                - Exceções
                    - Trechos em túneis: desconsiderar
                    - Trechos com menos de 990 m: desconsiderar
                    - Buffer com menos de 50% da área original (após ajustes de sobreposição): desconsiderar

                - Tolerâncias
                    - Segmentos necessários: sempre há no mínimo 1 segmento de tolerância (ainda que 90% dos trechos considerados seja < 1)
                    - Arredondamentos
                        - Uso da função ROUND BigQuery 

                - Critérios adicionais de invalidação
                    - Serviço planejado: serviço deve constar na OS e no GTFS para o dia da semana e faixa horária
                    - Serviço divergente: serviço informado no GPS e na viagem devem ser iguais
                    - Shape inválido: shape deve constar no GTFS no serviço informado
                    - Velocidade média máxima: 110 km/h
                    - Viagem sobreposta: viagens realizadas pelo mesmo veículo que se sobrepõem no tempo (impossível o mesmo veículo realizar duas viagens ao mesmo tempo)
                    - Campos obrigatórios:
                        - ID da viagem
                        - datetime partida
                        - datetime chegada
                        - datetime partida < datetime chegada
                        - shape_id
                        - route_id
                        - id_veiculo

    * Análise comparativa (vantagens, desvantagens, viabilidade):
        - Cenário 1: 
            - Vantagens: Simplicidade, baixo custo de implementação.
            - Desvantagens: Falta de controle, insegurança jurídica, manipulação dos dados pelos operadores, apenas a Prefeitura do Rio de Janeiro utiliza esse método (ao que sabemos).
        - Cenário 2:
            - Vantagens: Maior controle, transparência, segurança jurídica, redução de manipulação.
            - Desvantagens: Custo de desenvolvimento e manutenção da interface.

* Justificativa da escolha da solução:
    - A implementação de uma interface para registro de viagens pelos operadores é a solução mais adequada, pois resolve as vulnerabilidades do método atual, aumenta a transparência e segurança jurídica, e reduz o risco de manipulação dos dados. Apesar do custo inicial, os benefícios superam as desvantagens.
    - A solução escolhida também está alinhada com as melhores práticas observadas em outras cidades.

## 7. Riscos e Controles

* Riscos identificados (técnicos, institucionais, de segurança):
    - Risco de manipulação dos horários de início e fim de viagens pelos operadores.
    - Risco de interrupção da viagem, mas atendidos os demais parâmetros (ex.: operador inicia a viagem, acessa a garagem, e depois retoma a viagem - viagem "fantasma").
    - Não apurar as viagens em até D+1 (método atual)
* Probabilidade e impacto:
    - Risco de manipulação dos horários de início e fim de viagens pelos operadores: alta
    - Risco de interrupção da viagem, mas atendidos os demais parâmetros (ex.: operador inicia a viagem, acessa a garagem, e depois retoma a viagem - viagem "fantasma"): baixa
* Controles ou mitigadores adotados:
    - Risco de manipulação dos horários de início e fim de viagens pelos operadores
        - Definir uma cerca eletrônica (geofence) para início e fim de viagem e definir uma tolerância entre o informado e o efetivamente registrado pelo GPS
    - Risco de interrupção da viagem, mas atendidos os demais parâmetros
        - Não identificamos nenhum controle efetivo para mitigar esse risco, mas o impacto é baixo.
        - Alternativas avaliadas:
            - Definir o horário de início e fim de cada segmento da viagem: inviável em razão de trajetos complexos (ida e volta pelo mesmo segmento)
            - Tempo médio entre segmentos sequenciais: inviável em razão de trajetos complexos e variação do trânsito
    - Não apurar as viagens em até D+1 (método atual)
        - Implementado processo de inferência de viagens utilizando, inclusive, os dados de GPS dos validadores utilizando os mesmos critérios de validação do Cenário 2 (válido para fins de monitoramento e planejamento operacional, mas não para remuneração dos operadores)

## 8. Indicadores de Impacto

* Como o sucesso do projeto será medido?
* Indicadores institucionais:
    - Avaliação antes x depois (método atual x novo método)
        - Número de viagens validadas
        - Número de viagens invalidadas
        - Número de viagens contestadas pelos operadores

## 9. Plano de Manutenção Técnica

* Frequência de revisão dos dados/pipelines:
* Procedimento de versionamento:
* Responsável pela sustentação:
* Monitoramento e alertas:

## 10. Plano de Manutenção da Documentação

* Responsável por atualizar o FRAME-DADOS:
* Frequência de revisão:
* Local de armazenamento e versão:
* Estratégia para manter o material atualizado (checklists, rotinas, versionamento):

## 11. Lições Aprendidas (a preencher ao final do projeto ou a cada versão relevante)

* O que funcionou bem:
    - Benchmarking com a experiência de outra cidade (Prefeitura de Belo Horizonte)

* O que poderia ter sido feito de outra forma:
    - Definição clara de escopo com o cliente desde o início
    - Definição clara de requisitos funcionais com o cliente desde o início
    - Definição clara de requisitos de aceitação com o cliente desde o início
    
* Barreiras encontradas e superadas:
    - Método da PBH não era totalmente aplicável ao contexto do Rio de Janeiro, exigindo adaptações principalmente em razão de túneis. Junto ao IPP foi possível identificar os túneis e desconsiderá-los na análise.

* Recomendações para projetos futuros:
    - Ter um ciclo de vida claro do produto de dados
        1. Entender o problema
        2. Realizar um processo de benchmarking/discovery com outras cidades/entidades
        3. Avaliar adaptações ao contexto local
        4. Desenvolver um protótipo
        5. Validar o protótipo com o cliente
        6. Desenvolver a solução final

    - Desenvolvimento de documentação

## 12. Referências e Documentos Vinculados

* Normas, leis, decretos:
* Relatórios técnicos:
* Processos administrativos ou ofícios:
* Links para dossiês complementares:

## 14. Anexos

* Screenshots, esquemas, mapas mentais ou fluxos de dados:
* Links para dashboards, painéis ou pipelines: