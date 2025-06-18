# FRAME-DADOS – Framework de Documentação de Projetos de Dados Públicos

## 1. Identificação do Projeto

* *Nome do Projeto:* Avaliação de Climatização de Viagens
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

* Bases utilizadas:  
Base de dados meteorológicos das 4 estações de medição do município do Rio de Janeiro oriundas do Banco de Dados Meteorológicos do INMET. Assim como, dados de bilhetagem provenientes da concessionária de bilhetagem digital da prefeitura do Rio de Janeiro.  

* Origem dos dados:  
 Plataforma de bilhetagem Jaé e  Banco de Dados Meteorológicos do INMET.  
  
* Avaliação da qualidade e limitações:
  
   - **Dados - Instituto Nacional de Meteorologia:**  
  
  Avaliando de forma objetiva, sobre os dados de temperatura das duas fontes de origem utilizadas foram de suma importância na busca por soluções no contexto de climatização de viagens do transporte público de ônibus da prefeitura, mas que também demonstram cercas limitações. Detalhamento melhor sobre, no que diz respeito aos dados de temperatura oriundos do INMET, temos um dado com precisão muito acima da média, além de maior robustez e confiabilidade dado toda infraestrutura especializada  contida nas estações para tal captação de informações meteorológicas. Porém, no contexto de descritivos acerca de variáveis, colunas ou metologodias aplicadas aos dados carece de um dicionário descritivo ou mesmo de transparência maior em relação a determinados conceitos e detalhes sobre os números consolidados.
    
   - **Dados - Concessionária de bilhetagem Jaé:**  
  
  Segundamente, com os dados de temperatura interna temos algumas inconsistências em relação aos valores de medição de temperatura captados pelos sensores do veículos da frota municipal, com uma presença frequente de dados extremos (outliers) que vão desde medições de 0°C ou 1°C até mesmo 900°C de temperatura. Dessa forma, fazendo necessário todo uma identificação e tratamento de registros problemáticos durante toda a base de dados obtida através do gps_validador.
* Observações relevantes:  


## 4. Levantamento de Requisitos

* Requisitos funcionais (o que o projeto precisa fazer):
* Requisitos não funcionais (desempenho, segurança, disponibilidade etc.):
* Demandas regulatórias ou legais:
* Partes interessadas envolvidas:

## 5. Análise de Alternativas Técnicas (AIR)

* Alternativas consideradas:
* Análise comparativa (vantagens, desvantagens, viabilidade):
* Justificativa da escolha da solução:

## 6. Solução Técnica Definida

* Arquitetura de dados:
* Ferramentas e linguagens utilizadas:
* Principais pipelines ou tabelas modeladas:
* Padrões e naming conventions adotadas:
* Mecanismos de validação e testes:

## 7. Riscos e Controles

* Riscos identificados (técnicos, institucionais, de segurança):
* Probabilidade e impacto:
* Controles ou mitigadores adotados:

## 8. Indicadores de Impacto

* Como o sucesso do projeto será medido?
* Indicadores institucionais:
* Indicadores técnicos (desempenho, tempo de resposta, completude etc.):

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
* O que poderia ter sido feito de outra forma:
* Barreiras encontradas e superadas:
* Recomendações para projetos futuros:

## 12. Referências e Documentos Vinculados

* Normas, leis, decretos:
* Relatórios técnicos:
* Processos administrativos ou ofícios:
* Links para dossiês complementares:

## 13. RIPD – Relatório de Impacto à Proteção de Dados Pessoais

* Dados sensíveis envolvidos?
* Base legal de tratamento:
* Encarregado pelo tratamento:
* Medidas de segurança adotadas:
* Avaliação de riscos à privacidade:
* Referência ao documento completo, se necessário:

## 14. Anexos

* Screenshots, esquemas, mapas mentais ou fluxos de dados:
* Links para dashboards, painéis ou pipelines:

---

# FRAME-DADOS LITE (para alterações técnicas pontuais)

Usar esta versão diretamente no changelog do projeto ou como parte do corpo do PR.

```md
## [Não publicado]

### Adicionado
- Campo `uf_autuacao` no modelo `autuacao.sql`

#### FRAME-DADOS LITE
- **Motivo:** Necessidade de filtro federativo nos painéis da CGM
- **Impacto técnico:** Rebuild do modelo `mart_autuacoes_mensais` e ajustes em dashboards
- **Impacto institucional:** Atende recomendação CGM 2025, dá suporte a painel de fiscalização pública
- **Responsável:** Rodrigo Cunha
- **Data:** 31/05/2025
```
