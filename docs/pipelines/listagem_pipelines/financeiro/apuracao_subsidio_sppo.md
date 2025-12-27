# Apuração do Subsídio (SPPO)

* [Queries](https://github.com/prefeitura-rio/pipelines_rj_smtr/tree/main/queries/models/projeto_subsidio_sppo)
* [Pipelines](https://github.com/prefeitura-rio/pipelines_rj_smtr/tree/main/pipelines/migration/projeto_subsidio_sppo)

## Legislações

[Acesse diretamente a seção de legislações](https://transportes.prefeitura.rio/subsidio/#wrapper-static-content)

## Etapas do Processo

### 1. Classificação diária do status do veículo

![Diagrama sppo_veiculo_dia](../../../img/veiculo_dia.png)

A classificação dos veículos ocorre diariamente por meio da tabela `veiculo_dia`, que consolida as seguintes informações:

- **Licenciamento**: Verifica se o veículo está devidamente licenciado no Sistema de Transporte Urbano (STU)
- **Vistoria**: Confirma se a vistoria está válida
- **Autuações**: Identifica infrações aplicadas no dia
- **Registros de Agentes de Verão**: Notificações sobre ar-condicionado inoperante
- **Tecnologia do Veículo**: Classifica o tipo do veículo como MINI, MIDI, BÁSICO ou PADRON

Status possíveis:
- Não licenciado
- Não vistoriado
- Lacrado
- Autuado por ar inoperante
- Registrado com ar inoperante
- Licenciado sem ar e não autuado
- Licenciado com ar e não autuado

### 2. Integração com dados de Bilhetagem e classificação de viagens

![Diagrama viagem_transacao](../../../img/viagem_transacao.png)

A integração ocorre via a tabela `viagem_transacao`, gerada a partir da `viagem_completa`, consolidando os seguintes dados:

- **GPS do Validador**: Verifica o estado do equipamento (aberto/fechado) durante a viagem:
  - Pelo menos 80% das transmissões com estado "ABERTO"
  - Todos os validadores vinculados ao mesmo serviço
- **Transações Jaé e RioCard**: Verifica se houve registro de passageiros na viagem, considerando uma tolerância de 30 minutos a partir do horário de início da viagem para contabilização das transações

As informações são cruzadas com o status do veículo e com autuações disciplinares, gerando uma classificação detalhada por viagem:

1. Não licenciado
2. Não vistoriado
3. Lacrado
4. Não autorizado por ausência de ar-condicionado
5. Não autorizado por capacidade
6. Autuado por ar inoperante
7. Autuado por alterar itinerário
8. Autuado por vista inoperante
9. Autuado por não atender solicitação de parada
10. Autuado por iluminação insuficiente
11. Autuado por não concluir itinerário
12. Registrado com ar inoperante
13. Detectado com ar inoperante
14. Sem transação
15. Validador fechado
16. Validador associado incorretamente
17. Licenciado sem ar e não autuado
18. Licenciado com ar e não autuado

### 3. Apuração de quilometragem total e cálculo do Percentual de Operação por faixa horária (POF)

![Diagrama subsidio_faixa_servico_dia](../../../img/subsidio_faixa_servico_dia.png)

O processo consiste em consolidar dados de viagens planejadas (`viagem_planejada`) e realizadas (`viagem_transacao`), associando-as por faixa horária e serviço, para apurar a quilometragem planejada e realizada. 

**Cálculo do POF**: Relação percentual entre a quilometragem realizada e a planejada, desconsiderando viagens de veículos não licenciados, não vistoriados, lacrados ou sem ar-condicionado, conforme legislação vigente.

![Tabela subsidio_faixa_servico_dia](../../../img/tabela_subsidio_faixa_servico_dia.png)

### 4. Cálculo de valor por viagem e identificação de quais viagens serão remuneradas (Teto de 120% / 200%)

![Diagrama viagens_remuneradas](../../../img/viagens_remuneradas.png)

A partir da tabela `viagem_transacao` e dos parâmetros de subsídio (`valor_km_tipo_viagem`), é calculado o valor de cada viagem elegível para remuneração.

**Critérios considerados:**

- **Valor do subsídio por km**, conforme tipo de viagem e status do veículo  
- **Faixas de limite máximo de viagens**, conforme dia do calendário:

| Tipo de Dia                 | Limite de Remuneração             |
|-----------------------------|-----------------------------------|
| Dias úteis                  | até 110% das viagens determinadas |
| Sábados, domingos, feriados | até 120% das viagens determinadas |
| Pontos facultativos         | até 150% das viagens determinadas |

![Tabela viagens_remuneradas](../../../img/tabela_viagens_remuneradas.png)

### 5. Aplicação de Penalidades por baixa operação

Se o POF estiver abaixo dos limites, penalidades são aplicadas:

| Faixa de POF         | Penalidade                                  |
|----------------------|---------------------------------------------|
| POF < 40%            | Penalidade equivalente à infração **grave** |
| 40% ≤ POF < 60%      | Penalidade equivalente à infração **média** |
| 60% ≤ POF < 80%      | Sem penalidade, porém **sem subsídio**      |
| POF ≥ 80%            | Operação regular, **subsídio integral**     |

### 6. Apuração da quilometragem e valor de pagamento

A apuração final consolida:

- **valor_a_pagar**: Valor efetivo de pagamento (valor_total_apurado - valor_acima_limite - valor_glosado).
- **valor_glosado**: Valor total das viagens considerando o valor máximo por km, subtraído pelo valor efetivo por km.
- **valor_acima_limite**: Valor apurado das viagens que não foram remuneradas (por estar acima do teto de 120% / 200%).
- **valor_total_sem_glosa**: Valor total das viagens considerando o valor máximo por km.
- **valor_total_apurado**: Valor total das viagens apuradas, subtraídas as penalidades (POF =< 60%).
- **valor_judicial**: Valor de glosa depositada em juízo (Autuação por ar inoperante, Veículo licenciado sem ar, Penalidade abaixo de 60% e Notificação dos Agentes de Verão).
- **valor_penalidade**: Valor penalidade [negativa] (POF =< 60%).