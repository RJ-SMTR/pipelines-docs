## **Glossário:**
- **Distância aferida**: Cálculo da distância percorrida entre dois pontos de dados de GPS sucessivos.
- **Garagem**: Local onde os veículos de transporte ficam quando não estão em operação.
- **GTFS**: Arquivo contendo informações sobre linhas de ônibus e serviços de BRT da cidade do Rio de Janeiro. Atualizado mensalmente pela Secretaria Municipal de Transportes <https://www.data.rio/datasets/8ffe62ad3b2f42e49814bf941654ea6c/about>
- **id_veiculo**: Identificação do veículo a partir de um número de ordem.
- **id_viagem**: Identificação única para cada viagem
- **Modelo ephemeral e incremental**: Vide DBT (<https://docs.getdbt.com/docs/build/materializations>)
- **Plano operacional**: Documento divulgado pelo site <https://transportes.prefeitura.rio> que contém as características operacionais dos serviços.
- **Ponto**: Comunicação pontual do GPS.
- **Rota planejada**: Rota planejada para aquele tipo de serviço e sentido conforme o GTFS.
- **Rota realizada**: Rota realizada pelo veículo em determinado tipo de serviço, sentido, data, horário
- **Serviço**: Codificação alfanumérica que possui itinerário pré-definido e especificação de quilometragem. 
- **Shape** - Elemento geométrico que representa o espaço em formato linestring ou multilinestring.
- **Timestamp** - Registro de data e hora
- **Viagem** - O percurso completo de um veículo, partindo de um ponto inicial e terminando em um ponto final, com determinado horário de início e término[duas meias viagens].
- **Viagem Circular** - Viagens que o início e o fim do trajeto possuem a mesma geolocalização. 

------------------------------------------------------------------------------

## **1. Tabela: gps_sppo** 

- Definição: A tabela *gps_sppo* é onde são armazenados os dados do gps após passar pelas seguintes transformações de cálculo da velocidade instantânea, 
cálculo da velocidade média, análise se o veículo encontra-se parado, conformidade com a rota. 

**1.1 Cálculo da velocidade instantânea [velocidade_instantanea]**
- A velocidade instantânea é calculada dividindo a distância percorrida pelo tempo entre dois registros de timestamp consecutivos. 
- O resultado é então multiplicado por 3,6 para converter a unidade para km/h.

**1.2 Cálculo da velocidade média [velocidade_estimada_10_min]**
- Modelo ephemeral [sppo_aux_registros_velocidade.sql]
- A velocidade média é zerada quando há qualquer alteração de veículo ou serviço.
- A velocidade média é calculada a partir da média das velocidades dos últimos 10 minutos (declarado no modelo como 600 seconds).
- Antes de completar os 10 minutos, a velocidade média permanece igual a zero.
- Caso a velocidade exceda 60 km/h (sendo um outlier), ela será ajustada para 60 km/h.

**1.3 Veículo parado [tipo_parada]**
- Modelo ephemeral [sppo_aux_registros_parada]
- Veículo recebe o *status quo* de parado quando a velocidade entre dois pontos é igual a 0km/h.
- Velocidade limiar parada: 3km/h
O veículo poderá estar parado próximos a terminais (dentro de um raio de 250m) ou dentro da garagem.
Esta definição permite rotular as observações da coluna tipo_parada como "Em operação", "Parado garagem"

**1.4 Rota**
- Modelo ephemeral [sppo_aux_registros_flag_trajeto_correto]
- Etapa que objetiva analisar se o veículo realizou o trajeto correto, conforme as shapes (camadas georreferenciadas) dos trajetos e dos trajetos alternativos. 
- A partir da utilização do window_function o modelo calcula um indicador de quantas vezes o veículo esteve dentro do trajeto correto.
- A condição de trajeto correto é atingida se o veículo estiver dentro da variável buffer_segmento_metros (500 metros). 

**1.5 Linhagem do dado**

- ![Linhagem GPS SPPO](imagens/linhagem_gps_sppo.png)

**1.6 Exemplo da Tabela**

- ![Exemplo da Tabela GPS_SPPO](imagens/gps_sppo_tabela.png)

------------------------------------------------------------------------------

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
------------------------------------------------------------------------------
# **ETAPA 5**

## **5 Tabela: `aux_viagem_circular`** 
*Caminho do modelo:* 
 *prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/aux_viagem_circular.sql*

- ![Modelo](imagens/etapa5.png)

**5.1 Objetivo**: Identificar viagens de ida que possuem volta subsequente. 

**5.2 Fluxo de execução do modelo**:
* Trata-se de uma *View*
* Utiliza a função [LEAD](https://cloud.google.com/bigquery/docs/reference/standard-sql/navigation_functions#lead) para inserir em mesmo registro o datetime ida e o datetime volta;
* Atribui um id_viagem unificando ida e volta.

**5.3 Resultados apresentados**
A tabela apresenta os seguintes atributos:
   * `id_viagem`;
   * `data`;
   * `id_empresa`;
   * `id_veiculo`;
   * `servico_informado`;
   * `servico_realizado`;
   * `trip_id`;
   * `shape_id`;
   * `sentido_shape`;
   * `distancia_inicio_fim`;
   * `distancia_planejada`;
   * `shape_id_planejado`;
   * `trip_id_planejado`;
   * `sentido`;
   * `datetime_partida`;
   * `datetime_chegada`;
   * `versao_modelo`.


**5.4 Linhagem**:

![Linhagem](imagens/aux_viagem_circular_linhagem.png)

-----------------------------------------------------------------------------
------------------------------------------------------------------------------
# **ETAPA 6**

## **6 Tabela: `registros_status_viagem`** 
*Caminho do modelo:* 
*prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/registros_status_viagem.sql*

![Modelo](imagens/etapa6.png)

**6.1 Objetivo**: Filtrar apenas viagens identificadas a partir dos modelos `aux_registros_status_trajeto`e `aux_viagem_circular`. 


**6.2 Fluxo de execução do modelo**:
* Materialização incremental com partição diária;
* Faz um join entre as tabelas `aux_registros_status_trajeto`e `aux_viagem_circular`
                  
**6.3 Resultados apresentados**
* A tabela `registros_status_viagem` apresenta cada linha como registro com os seguintes atributos:
   * `data` (YYYY-mm-dd);
   * `id_veiculo`;
   * `id_empresa`;
   * `timestamp_gps`;
   * `timestamp_minutos` que desconsidera os segundos do timestamp_gps;
   * `posicao_veiculo_geo`;
   * `servico_informado`;
   * `servico_realizado`;
   * `shape_id`;
   * `sentido_shape` (Ida 'I' e Volta 'V');
   * `shape_id_planejado`;
   * `trip_id`;
   * `trip_id_planejado`;
   * `sentido` (Ida 'I' e Volta 'V');
   * `start_pt` ponto de início georreferenciado;
   * `end_pt` ponto de fim da viagem georreferenciado;
   * `distancia_planeada`;
   * `distancia` que caracteriza a distância realizada;
   * `status` da viagem (start, middle, end, out);
   * `datetime_partida`;
   * `datetime_chegada`;
   * `distancia_Inicio_Fim`;
   * `id_viagem`;
   * `versao_modelo`.


**6.4 Linhagem**:

![Linhagem](imagens/registro_status_viagem_linhagem.png)

**6.5 Modelo da Tabela**

 ![Tabela gerada](imagens/registro_status_viagem_tab1.png)
 ![Tabela gerada](imagens/registro_status_viagem_tab2.png)
 ![Tabela gerada](imagens/registro_status_viagem_tab3.png)

-----------------------------------------------------------------------------
------------------------------------------------------------------------------
# **ETAPA 7**

## **7 Tabela: `aux_viagem_registros`** 
*Caminho do modelo:* 
*prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/aux_viagem_registros.sql*

![Modelo](imagens/etapa7.png)

**7.1 Objetivo**: Somar a quantidade total de registros de GPS.
         
**7.2 Fluxo de execução do modelo**:
* Trata-se de uma *View*.
* Conta quantos registros ocorreram em start, middle e end;
* Calcula a distância total.

**7.3 Resultados apresentados**
* A tabela `aux_viagem_registros` apresenta indicadores por viagem com a distância aferida, pontos de gps por fase (start, middle, end e out) e quantos minutos tiveram registros de gps, com os seguintes atributos:
   * `id_viagem`;
   * `distancia_aferida`;
   * `distancia_inicio_fim`;
   * `n_registros_middle` (os números de registros quando o veículo está na posição middle)
   * `n_registros_start` (os números de registros quando o veículo está na posição start)
   * `n_registros_end` (os números de registros quando o veículo está na posição end)
   * `n_registros_out` (os números de registros quando o veículo está na posição out, fora da rota)
   * `n_registros_total` (o número total de registros)
   * `n_registros_minuto` (o número total de registro por minuto)
   * `n_registros_shape` (o número total de registros que interccionam a shape)
   * `versao_modelo`

 **7.4 Linhagem**:

![Linhagem](imagens/aux_viagem_registros_linhagem.png)

-----------------------------------------------------------------------------
------------------------------------------------------------------------------
# **ETAPA 8**

## **8 Tabela: `Viagem_conformidade`** 
*Caminho do modelo:* 
*prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/viagem_conformidade.sql*

- ![Modelo](imagens/etapa8.png)

**8.1 Objetivo**: Calcular o tempo total de viagem, os percentuais de conformidade de distância e os registros no shape.
         
**8.2 Fluxo de execução do modelo**:
* Materialização incremental com particionamento por data e granularidade diária;
* Calcula o percentual de conformidade do shape, dividindo o registro do shape pelos registros totais;
* Calcula o percentual de conformidade da distância, dividindo a distância aferida pela distância planejada;
* Calcula o percentual de conformidade de registros da comunicação do gps ao dividir o número de registros por minuto pelo tempo total da viagem.

**8.3 Resultados apresentados**
* A tabela `Viagem_conformidade` apresenta:
   * `id_viagem`;
   * `data` (YYYY-mm-dd);
   * `id_empresa`;
   * `id_veiculo`;
   * `servico_informado`;
   * `servico_realizado`;
   * `distância planejada`;
   * `sentido` (ida "I", volta "V");
   * `datetime_partida`
   * `datetime_chegada`
   * `trip_id`;
   * `shape_id`;
   * `tempo_viagem` (em minutos);
   * `distancia_aferida` (metros);
   * `distancia_inicio_fim` (quilometros);
   * `n_registros_middle` (os números de registros quando o veículo está na posição middle);
   * `n_registros_start` (os números de registros quando o veículo está na posição start);
   * `n_registros_end` (os números de registros quando o veículo está na posição end);
   * `n_registros_total`(o número total de registros);
   * `n_registros_minuto` (o número total de registro por minuto);
   * `n_registros_shape` (o número total de registros que interccionam a shape);
   * `velocidade_media`;
   * E os percentuais de conformidade:
      * `perc_conformidade_shape`;
      * `perc_conformidade_distancia`;
      * `perc_conformidade_registros`.

 
**8.4 Linhagem**

![Linhagem](imagens/viagem_conformidade_linhagem.png)

**8.5 Modelo da Tabela**

 ![Tabela gerada](imagens/viagem_conformidade_tab1.png)
 ![Tabela gerada](imagens/viagem_conformidade_tab2.png)


------------------------------------------------------------------------------
------------------------------------------------------------------------------

# **ETAPA 9**

## **9 Tabela: `viagem_completa`** 
*Caminho do modelo:* 
*prefeitura_rio/pipelines_rj_smtr/queries/models/projeto_subsidio_sppo/viagem_completa.sql*

- ![Modelo](imagens/etapa9.png)

**9.1 Objetivo**: Consolidar as viagens e apresentação dos indicadores.
                  
**9.2 Fluxo de execução do modelo**:
* Materialização incremental com partição diária; (PADRONIZAR);
* Identifica as viagens que estão dentro do `viagem_planejada`;
* Filtra apenas as viagens que atendem aos percentuais mínimos de conformidade;
* Faz a associação de serviço informado e serviço realizado;
* Filtra as viagens com velocidade média acima de 110km/h (A partir de 16/11/2024);
* Utiliza as funções:
   * [ST_BUFFER](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_bufferwithtolerance) para criar uma área em volta do ponto;
   * [ST_INTERSECTION](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_intersection) para cruzar a área com o shape;
   * [ST_NUMGEOMETRIES](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_numgeometries) verifica se o buffer interccionou com o shape em pelo menos um registro.
   * Analisa se os percentuais de conformidade estão dentro dos mínimos declarados no dbt_project;
   * Possibilita ajuste no modelo diante de atipicidade, como shows, reveillon, etc. 

**9.3 Resultados apresentados**
* A tabela `viagem_completa` apresenta a consolidação de todas as informações e possui os seguintes atributos:
   * `consorcio`;
   * `data` (YYYY-mm-dd);
   * `tipo_dia` (útil, sábado, domingo, ponto facultativo, atípico);
   * `id_empresa`;
   * `id_veiculo`;
   * `id_viagem`;
   * `servico_informado`;
   * `servico_realizado`;
   * `vista` que são strings com os nomes das localidades iniciais e finais atendimento;
   * `trip_id`;
   * `shape_id`;
   * `datetime_partida`, ou seja, o horário que a viagem iniciou;
   * `datetime_chegada`, ou seja, o horário que a viagem finalizou;
   * `inicio_faixa_horaria`;
   * `fim_faixa_horaria`;
   * `tipo_viagem` (Exemplo: "Completa Linha correta" ou "Completa linha incorreta");
   * `tempo_viagem`;
   * `tempo_planejado`;
   * `distancia_planejada` (quilometros);
   * `distancia_aferida` em (quilometros);
   * `sentido` (ida "I", volta "V");
   * `n_registros_shape` (o número total de registros que interccionam a shape);
   * `n_registros_total`(o número total de registros);
   * `n_registros_minuto` (o número total de registro por minuto);
   * `velocidade_media`;
   * E os percentuais de conformidade:
      * `perc_conformidade_shape`;
      * `perc_conformidade_distancia`;
      * `perc_conformidade_registros`;
      * `perc_conformidade_tempo`.
   * `datetime_ultima_atualizacao`;
   * `versao_modelo`.

 
**9.4 Linhagem**

![Linhagem](imagens/viagem_completa_linhagem.png)

**9.5 Modelo da Tabela**

 ![Tabela gerada](imagens/viagem_completa_tab1.png)
 ![Tabela gerada](imagens/viagem_completa_tab2.png)
 ![Tabela gerada](imagens/viagem_completa_tab3.png)
 ![Tabela gerada](imagens/viagem_completa_tab4.png)
------------------------------------------------------------------------------
------------------------------------------------------------------------------
# **REFERENCIAS**

- [Documentação DBT Rio](https://docs.mobilidade.rio/#!/overview?g_v=1&g_i=%2Bviagem_completa);
- [Função ST_DISTANCE](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_distance);
- [Função ST_DWITHIN](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_dwithin);
- [Função ST_INTERSECTBOX](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions);
- [Função ST_GEOGFROMTEXT](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_geogfromtext);
- [Função ST_GEOGPOINT](https://cloud.google.com/bigquery/docs/reference/standard-sql/geography_functions#st_geogpoint)
- [Função LAG](https://cloud.google.com/bigquery/docs/reference/legacy-sql?hl=pt-br);
- [Função LEAD](https://cloud.google.com/bigquery/docs/reference/legacy-sql?hl=pt-br);
- [Função WINDOW](https://cloud.google.com/bigquery/docs/reference/standard-sql/window-function-calls);
- [GTFS Rio](https://www.data.rio/datasets/8ffe62ad3b2f42e49814bf941654ea6c/about);
- [Materialização de modelos Incremental e Ephemeral DBT](https://docs.getdbt.com/docs/build/materializations);
- [Plano Operacional](https://transportes.prefeitura.rio).


------------------------------------------------------------------------------
------------------------------------------------------------------------------
## Disposições Finais e Critérios de Precedência Normativa

Este documento possui caráter meramente técnico-descritivo, destinado a detalhar, de forma didática, os procedimentos, fluxos de dados, parâmetros e indicadores utilizados pela Secretaria Municipal de Transportes para a apuração de viagens e quilometragem do SPPO/RJ.

Em hipótese alguma este documento substitui, altera ou modifica as disposições contidas na legislação municipal, em normas regulamentares, em decisões judiciais ou em atos administrativos vigentes, nem o modelo computacional oficial parametrizado pela SMTR.

Para todos os efeitos legais e operacionais, em caso de divergência ou inconsistência entre as informações aqui descritas e:

A legislação vigente (leis, decretos, resoluções e demais normas aplicáveis), prevalecerá a legislação;
O modelo computacional oficial utilizado na produção da base viagem_completa e demais artefatos publicados no repositório oficial da [SMTR](https://github.com/prefeitura-rio/pipelines_rj_smtr), prevalecerá o resultado gerado por este modelo;
Este documento, que será interpretado como instrumento complementar, com função de apoio e transparência, não vinculando a Administração em detrimento das normas e modelos oficiais.

Eventuais ajustes ou atualizações técnicas na pipeline poderão ser implementados e refletidos no modelo oficial, observando-se sempre os parâmetros definidos em norma e os princípios de legalidade, publicidade e transparência administrativa.

