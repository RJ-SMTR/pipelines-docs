# FRAME-DADOS – Framework de Documentação de Projetos de Dados Públicos

> Versão completa para projetos estruturantes com impacto institucional, regulatório ou de alta visibilidade.

---

## 1. Identificação do Projeto

* Nome do Projeto:
* Responsável Técnico:
* Instituição/Setor:
* Data de Início:
* Status:

## 2. Objetivo e Justificativa

* Descreva o propósito do projeto e o problema que pretende resolver.
* Contextualize com políticas públicas, metas estratégicas ou necessidades operacionais.

## 3. Diagnóstico e Fontes de Dados

* Bases utilizadas:
* Origem dos dados:
* Avaliação da qualidade e limitações:
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
