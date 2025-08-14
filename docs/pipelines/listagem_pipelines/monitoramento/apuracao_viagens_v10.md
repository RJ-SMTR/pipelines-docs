### Documentação consolidada do processo de apuração das viagens para o subsídio do transporte público municipal do Rio de Janeiro. 
*Inclui glossário, descrição dos modelos que são apresentados na sequência de execução da pipeline.*

------------------------------------------------------------------------------
------------------------------------------------------------------------------
## **Glossário:**
- **Distância aferida**: Cálculo da distância percorrida entre dois pontos de dados de GPS sucessivos;
- **Garagem**: Local onde os veículos de transporte ficam quando não estão em operação;
- **GTFS**: Arquivo contendo informações sobre linhas de ônibus e serviços de BRT da cidade do Rio de Janeiro. Atualizado mensalmente pela Secretaria Municipal de Transportes <https://www.data.rio/datasets/8ffe62ad3b2f42e49814bf941654ea6c/about>;
- **id_veiculo**: Identificação do veículo a partir de um número de ordem;
- **id_viagem**: Identificação única para cada viagem;
- **Modelo ephemeral e incremental**: Vide DBT (<https://docs.getdbt.com/docs/build/materializations>);
- **Plano operacional**: Documento divulgado pelo site <https://transportes.prefeitura.rio> que contém as características operacionais dos serviços;
- **Ponto**: Comunicação pontual do GPS;
- **Rota planejada**: Rota planejada para aquele tipo de serviço e sentido conforme o GTFS;
- **Rota realizada**: Rota realizada pelo veículo em determinado tipo de serviço, sentido, data, horário;
- **Serviço**: Codificação alfanumérica que possui itinerário pré-definido e especificação de quilometragem;
- **Shape** - Elemento geométrico que representa o espaço em formato linestring ou multilinestring;
- **Timestamp** - Registro de data e hora;
- **Viagem** - O percurso completo de um veículo, partindo de um ponto inicial e terminando em um ponto final, com determinado horário de início e término[duas meias viagens];
- **Viagem Circular** - Viagens que o início e o fim do trajeto possuem a mesma geolocalização. 

------------------------------------------------------------------------------
## ETAPA 1
- A Figura 1 apresenta um esquema do processo, no qual cada etapa será detalhada nas seções seguintes.
- ![Figura 1 - Especificação](imagens/etapa1.png)


## **1. GTFS** 

- Esta etapa antecede a preparação da tabela de dados de GPS, que será utilizada na apuração das viagens.
- Consiste no tratamento e estruturação dos dados do GTFS para que possam ser corretamente consumidos nas etapas subsequentes.
- São utilizados os modelos sppo_realocacao, sppo_registros, sppo_aux_registros_filtrada, sppo_registros_relocacao, sppo_aux_registros_relocacao, sppo_aux_registros_flag_trajeto_correto, sppo_aux_registros_parada, sppo_aux_registros_velocidade que serão detalhados a seguir.

    **1.1 sppo_realocacao**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_realocacao.sql
         
         * **1.1.1 Objetivo**: Padronização de dados
         
         * **1.1.2 Fluxo de execução do modelo**:
          * *Consulta* que converte o id_veiculo para string, ajusta o timestamp para o horário de São Paulo, transforma a coluna serviço gerando um identificador padronizado.
         
         * **1.1.3 Resultados apresentados**
         * Trata os dados para o modelo sppo_aux_registros_relocacao

    **1.2 sppo_aux_registros_relocacao**
    - Caminho do modelo:   prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_realocacao.sql
         
         * **1.2.1 Objetivo**: O modelo ajusta os registros de GPS com o serviço, garantindo que nenhum veículo tenha mais de um serviço alocado para aquela viagem.
           
         * **1.2.2 Fluxo de execução do modelo**:
          * *Materização*: Caso a variável 15 estiver ativa, trata-se de um modelo ephemeral, caso contrário é incremental.
          * *Filtra* os registros de gps.
          * *Combina o gps* com a realocação. 
         
         * **1.2.3 Resultados apresentados**
         * Trata os dados para o modelo sppo_aux_registros_filtrada.

    **1.3 sppo_registros**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_filtrada.sql
         
         * **1.3.1 Objetivo**: Filtragem e tratamentos básicos de registro de gps.
         
         * **1.3.2 Fluxo de execução do modelo**:
          * *Filtra* que converte a coluna ordem para string.
          * *Trata* a latitude e longitude.
         
         * **1.3.3 Resultados apresentados**
         * Trata os dados para o modelo sppo_aux_registros_filtrada.
     
    **1.4 sppo_aux_registros_filtrada**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_filtrada.sql
         
         * **1.4.1 Objetivo**: Filtragem e tratamento básico de registros de gps.
         
         * **1.4.2 Fluxo de execução do modelo**:
           * *Materização*: Caso a variável 15 estiver ativa, trata-se de um modelo ephemeral, caso contrário é incremental.
           * *Filtra* registros que estão fora de uma marcação geográfica que contém a área do município de Rio de Janeiro. Usando a função st_intersectsbox [Vide documentação <https://postgis.net/docs/ST_Intersects.html>]
           * *Filtra* registros antigos. Remove registros que tem diferença maior que 1 minuto entre o timestamp_captura e timestamp_gps.
           * *Renomeia* ordem para id_veiculo.
                  
         * **1.4.3 Resultados apresentados**
         * Trata os dados para os modelos sppo_aux_registros_flag_trajeto_correto, sppo_aux_registros_parada, sppo_aux_registros_velocidade.

    **1.5 sppo_aux_registros_velocidade**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_velocidade.sql
         
         * **1.5.1 Objetivo**: Filtragem e tratamento básico de registros de gps.
         
         * **1.5.2 Fluxo de execução do modelo**:
           * *Materização*: Ephemeral.
           * *Calcula* a distância em metros entre a posição atual do veículo e aposição anterior. Usa a função lag [Vide documentação<https://www.postgresql.org/docs/current/functions-window.html>]
           * *Calcula* a velocidade instântanea.
           * *Cria* um indicador boleano para verificar se o veículo está em movimento.
                               
         * **1.5.3 Resultados apresentados**
         * Fornece insumos diretos para a Tabela gps_sppo.

    **1.6 sppo_aux_registros_parada**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_parada.sql
         
         * **1.6.1 Objetivo**: Identifica veículos parados em terminais ou garagens.
         
         * **1.6.2 Fluxo de execução do modelo**:
           * *Materização*: Ephemeral.
           * *Seleciona* a lista de terminais e garagens conhecidos para a definição do tipo_parada igual a terminal. Utiliza a função ST_GEOGPOINT e ST_GEOGFROMTEXT [vide documentação <https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions>]
           * *Calcula* a velocidade instântanea.
           * *Cria* um indicador boleano para verificar se o veículo está em movimento.
                               
         * **1.6.3 Resultados apresentados**
         * Fornece insumos diretos para a Tabela gps_sppo.
     
      **1.7 sppo_aux_registros_flag_trajeto_correto**
    - Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_onibus_gps/sppo_aux_registros_flag_trajeto_correto.sql
         
         * **1.7.1 Objetivo**: Identifica se os veículos estão dentro de um trajeto planejado.
         
         * **1.7.2 Fluxo de execução do modelo**:
           * *Materização*: Ephemeral.
           * *Verifica* a partir de uma janela de tempo (período pré-estabelecido) se o veículo esteve pelo menos uma vez dentro do trajeto planejado. 
           * *O Serviço* é verificado, analisa se ele está no cadastro do SIGMOB.
           * *Utiliza* a função ST_DWITHIN [vide documentação<http://postgis.net/docs/ST_DWithin.html>] com um buffer de 500 metros para verificar se o ponto está próximo do shape. Se ele esteve pelo menos uma vez no trajeto correto, cria uma flag_trajeto_correto_hist com o valor TRUE, caso contrário, essa flag recebe o valor FALSE.
                               
         * **1.7.3 Resultados apresentados**
         * Fornece insumos diretos para a Tabela gps_sppo.   



- ## LINHAGEM DOS MODELOS
- ![Figura 2 - Linhagem ETAPA 1](imagens/LINHAGEMETAPA1.png)


------------------------------------------------------------------------------
## ETAPA 2
- ![Figura 3 - Especificação ETAPA 2](imagens/ETAPA2.png)


## **2. Tabela: gps_sppo** 
- Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/br_rj_riodejaneiro_veiculos/gps_sppo.sql
- Modelo Incremental particionado por data com granularidade diária.

* **2.1 Objetivo**: A tabela *gps_sppo* armazena os dados do gps após passar pelas transformações de cálculo da velocidade instantânea, cálculo da velocidade média, análise se o veículo encontra-se parado, conformidade com a rota.

* **2.2 Fluxo de execução do modelo**:
 - *CTE[registros]*: seleciona os registros do gps por um filtro de data.
      - Utiliza a tabela ephemeral *sppo_aux_registros_filtrada* e seleciona os campos id_veiculo, timestamp_gps, timestamp_caputura, velocidade, linha, latitude e longitude.
    
 - *CTE[velocidades]*: seleciona as informações de velocidade, distância e movimento.
   - Utiliza a tabela ephemeral *sppo_aux_registros_velocidade* e seleciona os campos id_veiculo, timestamp_gps, velocidade, linha, distancia, flag_em_movimento.
   
 - *CTE[paradas]*: seleciona os tipos parada dos veiculos, como terminal, garagem.
   - Utiliza a tabela ephemeral *sppo_aux_registros_parada* e seleciona os campos id_veiculo, timestamp_gps, linha, tipo de parada.

 - *CTE[flags]*: seleciona as flags (indicadores) que determinam de forma booleana (True ou False) se o veículo está dentro do trajeto correto, além de verificar se a linha existe no sigmob.
   - Utiliza a tabela ephemeral *sppo_aux_registros_flag_trajeto_correto* e seleciona os campos id_veiculo, timestamp_gps, linha, route_id, flag_linha_existe_sigmob, flag_trajeto_correto, flag_trajeto_correto_hist .
  
- *Junção final*: seleciona as informações das CTE´s classifica se o veículo está em operação, operando fora do trajeto e define o tipo de parada, como parado trajeto correto e parado fora do trajeto.

* **2.3 Resultados apresentados**
- *Cálculo da velocidade instantânea [velocidade_instantanea]*
  - A velocidade instantânea é calculada dividindo a distância percorrida pelo tempo entre dois registros de timestamp consecutivos. 
  - O resultado é então multiplicado por 3,6 para converter a unidade para km/h.

- *Cálculo da velocidade média [velocidade_estimada_10_min]*
  - Modelo ephemeral [sppo_aux_registros_velocidade.sql]
  - A velocidade média é zerada quando há qualquer alteração de veículo ou serviço.
  - A velocidade média é calculada a partir da média das velocidades dos últimos 10 minutos (declarado no modelo como 600 seconds).
  - Antes de completar os 10 minutos, a velocidade média permanece igual a zero.
  - Caso a velocidade exceda 60 km/h (sendo um outlier), ela será ajustada para 60 km/h.

- *Veículo parado [tipo_parada]*
  - Modelo ephemeral [sppo_aux_registros_parada]
  - Veículo recebe o *status quo* de parado quando a velocidade entre dois pontos é igual a 0km/h.
  - Velocidade limiar parada: 3km/h
  - O veículo poderá estar parado próximos a terminais (dentro de um raio de 250m) ou dentro da garagem.
  Esta definição permite rotular as observações da coluna tipo_parada como "Em operação", "Parado garagem"

 * **2.4 Linhagem**:
- ![Linhagem GPS SPPO](imagens/1.linhagem_gps_sppo.png)

* **2.5 Modelo da Tabela**:
- ![Tabela gerada](imagens/1.tabela_sppo.png)

------------------------------------------------------------------------------
## **2. Tabela: viagem_planejada (ocorre em paralelo com o gps_sppo)** 
- Caminho do modelo: prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/viagem_planejada.sql
- Modelo Incremental particionado por data com granularidade diária.

* **1.1 Objetivo**: A tabela *viagem_planejada* combina os resultados das tabelas *viagem_planejada1* e "viagem_planejada2*

* **1.2 Fluxo de execução do modelo**:
 - *Junta as tabelas* de viagem_planejada1 e viagem_planejada2 a partir de uma condição de data como variável. 

* **1.3 Resultados apresentados**
- *Tipo de dia*: Caracterização do dia da operação como:
     * Dia útil;
     * Sábado;
     * Domingo;
     * Ponto Facultativo.
 - *Sentido*: Identificação de Ida (I) e Volta (V).
 - *Partidas planejadas*: Número de viagens planejadas para a aquela faixa horária.
 - *Distância planjeada*: Distância planejada para determinado serviço em determinada faixa horária.
 - *Distância total planeada*: A multiplicação de *Partidas planejadas* com a *Distância planjeada*
 - *Faixa horária de início e faixa horária de fim*: Faixa horária especificada, seguindo os critérios do Plano Operacional.
 - *Trip_id_planejado*:
 - *Trip_id*:
 - *Shape*:  Elemento geométrico que representa no espaço o serviço.
 - *start_pt*: Elemento geométrico que representa o início da viagem.
 - *end_pt*:  Elemento geométrico que representa o fim da viagem.
 
 * **1.4 Linhagem**:
- ![Linhagem GPS SPPO](imagens/2linhagem_viagem_planejada.png)

* **1.5 Modelo da Tabela**:
- ![Tabela gerada](imagens/2ViagemPlanejada.png)










### **2. Tabela: registros_status_viagem**
Caminho queries/models/projeto_subsidio_sppo/registro_status_viagem

- Objetivo: processamento do status da viagem (start, middle, end, out)

**2.1 Tratamento das viagens com serviço caracterizado como circular**
- Modelo ephemeral:aux_viagem_circular  
- Caminho queries/models/projeto_subsidios_sppo/aux_viagem_circular.sql
- Esse modelo ephemeral consulta o modelo aux_viagem_inicio_fim para filtrar apenas as viagens com sentido = "C", o objetivo é selecionar para essa análise apenas as viagens circulares.
- Ao utilizar a window function LEAD o modelo identifica o próximo registro de determinado veículo e serviço dentro de uma janela de tempo.
- flag_proximo_volta se for igual a TRUE e o sentido do shape for igual a "I" (Ida) e o datetime chegada for menor ou igual ao datetime partida volta gera um resultado que garante que o trajeto que representa a ida de uma viagem circular com sua volta logo em seguida.
- O modelo, ao realizar o particionamento de ida e volta, garante que ambos sentidos recebam o mesmo id_viagem.
- Após o tratamento das viagens circulares, o modelo concatena as viagens usando "union all" que não têm os serviços circulares. 

**2.2 Processamento**
- Modelo ephemeral: aux_registros_status_trajeto
- Caminho queries/models/projeto_subsidios_sppo/aux_registros_status_trajeto.sql

- O objetivo desse modelo é verificar se o veículo está em rota e, em caso positivo, verificar qual indicador de posição o veículo está.
- Indicador de posição:
      * start: o veículo está próximo ao início da rota.
      * middle: a viagem e o veículo recebem o status de middle a partir da primeira comunicação depois do buffer inicial (start).
      * end: o veículo encontra-se próximo ao final da rota
      * out: veículo fora da rota.
  - Vide ilustração esquemática:
  -  ![Esquema](imagens/esquema_status_viagem.png)

- Variável buffer geográfico {{ var("buffer") }} define o quanto o veículo precisa estar próximo a rota para que o trajeto seja considerado válido ( Atualmente o buffer está declarado como 500 metros)
- Função determinística para validação do indicador de posição - ST_DWITHIN.
- Caso especial (janela temporal): eventos como o show da Madonna requerem ajuste de parâemtros como do buffer geográfico ou seleções de tipos de serviço.
- Correspondência do tipo de serviço: o modelo analisa que se o serviço informado via GPS está igual ao serviço planejado. 
- Resumo de validação da viagem:
  * Indicador de posição (start, middle, end): a comunicação do GPS deve acontecer nas três instâncias do indicador de posição.
  * O serviço planejado deve ser igual ao serviço informado.

(Verificar se é nesse trecho que instancio a faixa horária)


**2.3 Modelo de tabela: registros_status_viagem**

  -  ![Modelo de tabela Registros_status_viagem](imagens/registro_status_viagem.png)

**2.4 Linhagem da tabela registro_status_viagem**

  -  ![Linhagem Registros_status_viagem](imagens/inhagem_registros_status_viagem.png)

------------------------------------------------------------------------------
### **3. Tabela: viagem completa**
- Caminho queries/models/projeto_subsidio_sppo/viagem_completa.sql
- Esse modelo acessa três tabelas, sendo os itens 3.1 Viagem Planejada e 3.2 Viagem Conformidade e a Tabela de Shapes proveniente do GTFS.
- O objetivo dessa tabela é consolidar informações para cada viagem de distância planejada e distância aferida, tempo de viagem, número de registros da comunicação do GPS e apresentar o percentual de conformidade.
  * Regra de negócio: O veículo para estar em conformidade, deve no mínimo comunicar em 80% do trajeto planejado, sendo que uma comunicação deve ser no star e outra no end..
- Modelo da tabela
- ![Tabela Viagem Completa](imagens/viagem_completa_tabela.png) 
- Linhagem da tabela
- ![Linhagem da Tabela Viagem Completa](imagens/linhagem_viagem_completa.png) 

**3.1 Tabela Viagem planejada**
- Modelo incremental: viagem_planejada.sql
- Caminho queries/models/projeto_subsidio_sppo/viagem_planejada.sql
- O objetivo dessa consulta para a geração do modelo viagem completa é gerar uma tabela de viagens planejadas para o período apurado.

**3.1.1 Modelo Tabela**
- ![Tabela_Viagem_Planejada](imagens/modelo_viagem_planejada.png)
**3.1.2 Linhagem da tabela viagem planejada**

- ![Linhagem_Viagem_Planejada](imagens/linhagem_viagem_planejada.png)

**3.2 Viagem conformidade**
- Modelo incremental: viagem_conformidade.sql
- Caminho queries/models/projeto_subsidio_sppo/viagem_conformidade.sql
- O objetivo dessa tabela que alimenta a tabela viagem completa é gerar uma tabela de viagens que analisa as conformidades conforme o planejado
- Esse modelo acessa os modelos efêmeros listados no item:
  * 2.1 Item aux_viagem_circular
- Esse modelo consulta o modelo ephemeral aux_viagem_registros (3.2.1).

     **3.2.1 aux_viagem_registro**
     - Modelo ephemeral: aux_viagem_registros.sql
     - Caminho queries/models/projeto_subsidio_sppo/ aux_viagem_registros.sql
     - Os principais objetivos desse modelo são:
       * medir a quantidade de registros;
       * medir a distância entre o início e fim do trecho;
       * contar registros de comunicações do GPS no indicador de posição (2.2): start, middle, end.

**3.2.2 Modelo Tabela Viagem Conformidade**
- ![Tabela_Viagem_Conformidade](imagens/tabela_viagem_conformidade.png)

- 
**3.2.3 Linhagem da Tabela viagem conformidade**
- ![Linhagem_Viagem_Conformidade](imagens/linhagem_viagem_conformidade.png)

------------------------------------------------------------------------------

**4. Tabela subsidio_data_versao_efetiva**
- Modelo Incremental: subsidio_data_versao_efetiva.sql
- Caminho queries/models/projeto_subsidio_sppo/subsidio_data_versao_efetiva.sql
- O objetivo desse modelo é criar um calendário operacional, classificando os tipos de dia como:
  * Dia útil,
  * Sábado,
  * Domingo,
  * Ponto Facultativo.
- O modelo faz a classificação por subtipo de dia, classificados como:
  * Verão,
  * E eventos como (Show da Madonna, Rock in Rio, Concurso Público Unificado (CNU), Eleição.
- O modelo capta a última data_versao, considerando um intervalo de 30 dias, que consta nas tabelas trips, shapes e frequencies.
- No modelo atual há especificação de datas atípicas, como eventos na cidade.
- Atenção para a variável: {var('DATA_SUBSIDIO_**_INICIO')- Declarada no dbt_project com datas importantes. 

**4.1 Modelo de tabela**

**4.2 Linhagem do dado**


------------------------------------------------------------------------------



------------------------------------------------------------------------------


