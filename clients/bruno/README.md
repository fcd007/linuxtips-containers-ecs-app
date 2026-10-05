# Importar no Bruno

A coleção Postman em `../postman/BuggyTrip.postman_collection.json` pode ser importada diretamente pelo Bruno:

1. No Bruno, escolha **Import → Postman Collection** e selecione `clients/postman/BuggyTrip.postman_collection.json`.
2. Selecione **Environment → Configure** e crie um ambiente `BuggyTrip AWS`.
3. Configure estas variáveis:

| Variável | Valor |
| --- | --- |
| `baseUrl` | `http://linuxtips-ecs-cluster-ingress-1313503812.us-east-2.elb.amazonaws.com` |
| `hostHeader` | `linuxtips-ecs-cluster-ingress-1313503812.us-east-2.elb.amazonaws.com` |
| `email` | Pode deixar vazio; a request de cadastro gera um e-mail de teste |
| `password` | Uma senha forte exclusiva para o cliente de teste |
| `token` | Preenchida após login, se o Bruno não importar o script que salva a resposta |
| `adminEmail`, `adminPassword` | Credenciais de uma conta ADMIN provisionada por processo administrativo |
| `adminToken` | JWT ADMIN após autenticação |
| `userId` | Capturado ao criar/logar o cliente |
| `bugueiroId` | ID de um usuário existente com tipo `BUGUEIRO` |
| `avaliacaoId` | Capturado ao criar uma avaliação |

Execute as requests na ordem indicada na coleção: Health/OpenAPI, criar CLIENTE, login e depois as chamadas autenticadas. Em Bruno, se os scripts Postman de teste não forem convertidos durante a importação, copie `token` e `userId` do response do login para o ambiente ativo manualmente. A listagem global de usuários exige `adminToken`; um CLIENTE receberá `403`, como esperado. As requests de criação de avaliação exigem `bugueiroId` válido. Exclusão de avaliação e desativação de usuário são operações destrutivas; deixe-as para o fim.

O banco PostgreSQL continua privado e não deve ser acessado diretamente pelo Bruno ou pela internet.
