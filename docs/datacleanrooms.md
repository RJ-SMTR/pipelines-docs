## Como fixar o projeto no bigquery
- Abra o console do [Bigquery](https://console.cloud.google.com/bigquery)
- No lado esquerdo da tela, clique no ícone de bússola (Explorador) como mostrado na imagem abaixo; em seguida clique em "Adicionar dados"
- <img width="322" height="234" alt="image" src="https://github.com/user-attachments/assets/866a3e42-7133-4262-b010-3122b7091c82" />
- Na nova aba que será aberta do lado direito da tela, na parte inferior, clique em "Marcar um projeto com estrela por nome"
- Quando solicitado o nome do projeto, adicione "rj-smtr"
- Clique no ícone ao lado da bússola (Explorador)
- Agora, sempre que abrir o seu console, o projeto aberto de produção da SMTR estará visível para exploração
    - Caso não esteja aparecendo, atualize a sua página com F5 e/ou clique no seletor "Mostrar apenas com estrela"

## Como fazer a inscrição (subscribe) nos Data Clean Rooms da SMTR
- Ao entrar no console do Bigquery, passe o mouse no canto direito da tela para abrir o menu lateral como mostra a imagem abaixo:
- <img width="222" height="606" alt="image" src="https://github.com/user-attachments/assets/1487d591-f65e-4267-b78c-4d7ba22f2b1e" />
- Clique em "Compartilhamento (Analytics Hub)", caso esteja usando o console em inglês, esse botão se chamará "Sharing"
- Ao ser direcionado para a pagina inicial do Analytics Hub, clique em pesquisar listagens
- <img width="669" height="280" alt="image" src="https://github.com/user-attachments/assets/46d2a33b-ddf3-48ab-ac65-176ab9afcd39" />
- Na aba que será aberta, em "Filtros", selecione "Data clean rooms". Após selecionar este filtro, a pesquisa deve retornar os Data Clean Rooms compartilhados com seu usuário
- Clique em "Inscrever-se"
- A partir de agora, no projeto que estava selecionado no momento da inscrição, você deverá encontrar um dataset com o mesmo nome da Clean Room na qual você se inscreveu
    - Dentro desse dataset, você deve conseguir ver as tabelas que foram compartilhadas dentro do Clean Room
    - Dados compartilhados em Data Clean Rooms, normalmente são protegidos por regras de análise, para mais informações, leia o [tutorial](https://cloud.google.com/bigquery/docs/analytics-hub-view-subscribe-listings?hl=pt-br)
