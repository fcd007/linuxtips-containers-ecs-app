# linuxtips-containers-ecs-app
Repositorio de exemplo de uma app no ECS

## BuggyTrip Java + PostgreSQL

O Terraform em `terraform/` publica a API Java do repositório AvaliaBugueMicrosservice no ECS existente e executa PostgreSQL em container em capacidade ECS/EC2 dedicada. O banco fica na mesma subnet privada da aplicação, sem IP público; o Security Group da tarefa PostgreSQL aceita TCP/5432 apenas do Security Group das tarefas Java. O volume de dados EBS gp3 é criptografado, protegido contra destruição acidental no Terraform e incluído em snapshots diários pelo AWS Backup.

Credenciais AWS vêm da cadeia padrão do provider AWS CLI/SDK (por exemplo, perfil `AWS_PROFILE` ou role SSO); nenhum account ID ou access key deve ser gravado em `.tfvars`. Região e referências de VPC/subnets são as já configuradas para o ambiente ECS, com IDs de rede resolvidos do Parameter Store.

### Acesso pelo DNS e Swagger no navegador

O DNS público do ALB é `linuxtips-ecs-cluster-ingress-276985081.us-east-2.elb.amazonaws.com`. A regra do ALB aceita tanto o hostname legado `chip.linuxtips.demo` quanto o próprio DNS AWS, permitindo abrir o Swagger diretamente no navegador:

- Swagger UI: http://linuxtips-ecs-cluster-ingress-276985081.us-east-2.elb.amazonaws.com/swagger-ui.html
- OpenAPI JSON: http://linuxtips-ecs-cluster-ingress-276985081.us-east-2.elb.amazonaws.com/v3/api-docs
- Health: http://linuxtips-ecs-cluster-ingress-276985081.us-east-2.elb.amazonaws.com/actuator/health

O ALB continua atendendo HTTP, sem TLS/domínio personalizado. O PostgreSQL não é publicado por esse DNS.

### Coleções Postman e Bruno

Arquivos prontos para importar:

- Postman: `clients/postman/BuggyTrip.postman_collection.json`
- Ambiente Postman: `clients/postman/BuggyTrip.postman_environment.json`
- Bruno: importe a mesma coleção Postman usando **Import → Postman Collection**. O guia de importação e configuração do ambiente está em `clients/bruno/README.md`.

A coleção contém health/OpenAPI/Swagger, cadastro e login do CLIENTE com captura automática do JWT, busca/atualização/desativação da própria conta, listagem de usuários como ADMIN, operações CRUD de avaliações, filtro/paginação e verificações de acesso negado. Para avaliar, configure `bugueiroId` com um usuário BUGUEIRO existente; a rota pública só cadastra CLIENTE. Configure credenciais administrativas próprias antes do login ADMIN; nenhuma conta padrão de produção foi criada.

### Teste automatizado de disponibilidade

Execute a partir da raiz deste repositório:

```bash
bash scripts/test-buggytrip-online.sh
```

O teste verifica HTTP 200 e o campo JSON `"status":"UP"`. Para consultar o DNS atual obtido do Terraform em vez do valor padrão do script:

```bash
cd terraform
API_BASE_URL="http://$(terraform output -raw api_dns_name)" \
API_HOST_HEADER="$(terraform output -raw api_dns_name)" \
bash ../scripts/test-buggytrip-online.sh
```

O DNS do ALB é o endpoint de entrada da API, não o endereço do banco. PostgreSQL permanece privado na VPC e não deve ser testado nem publicado por DNS público.

### Publicar as imagens e aplicar o Terraform

Use uma sessão AWS autenticada na conta de desenvolvimento esperada e confirme a identidade antes de alterar recursos. O segredo `buggytrip/postgres` precisa existir no Secrets Manager em `us-east-2`, com os campos `username` e `password`; a rotina de bootstrap citada anteriormente não existe neste repositório. Este comando verifica apenas os metadados, sem imprimir o valor do segredo:

```bash
aws sts get-caller-identity
aws secretsmanager describe-secret --secret-id buggytrip/postgres --region us-east-2 >/dev/null
```

Na raiz deste repositório, inicialize o backend e crie somente os dois repositórios ECR. Esse apply direcionado não cria serviços ECS:

```bash
terraform -chdir=terraform init -backend-config=environment/dev/backend.tfvars
terraform -chdir=terraform apply -target=module.service.aws_ecr_repository.main -target=aws_ecr_repository.postgres -var-file=environment/dev/terraform.tfvars
```

Gere uma tag inédita para cada publicação e construa/envie as imagens Java 25 e PostgreSQL 17 Alpine. Os repositórios são imutáveis; se uma publicação parcial falhar, use uma nova tag na próxima tentativa:

```bash
JAVA_PROJECT_DIR=/home/dantas/Downloads/AvaliaBugueMicrosservice
IMAGE_TAG="$(git -C "$JAVA_PROJECT_DIR" rev-parse --short=12 HEAD)-$(date -u +%Y%m%d%H%M%S)"
AWS_REGION=us-east-2 bash scripts/publish-aws-images.sh "$JAVA_PROJECT_DIR" "$IMAGE_TAG"
```

Confirme que as duas imagens foram publicadas antes de planejar o ECS:

```bash
aws ecr describe-images --repository-name linuxtips-ecs-cluster/chip --image-ids "imageTag=$IMAGE_TAG" --region us-east-2
aws ecr describe-images --repository-name linuxtips-ecs-cluster/postgres --image-ids "imageTag=$IMAGE_TAG" --region us-east-2
```

Revise o plano completo e, se não houver remoção/substituição inesperada de recursos persistentes, aplique usando a mesma tag para as duas imagens:

```bash
terraform -chdir=terraform plan -var-file=environment/dev/terraform.tfvars -var="image_tag=$IMAGE_TAG" -var="postgres_image_tag=$IMAGE_TAG"
terraform -chdir=terraform apply -var-file=environment/dev/terraform.tfvars -var="image_tag=$IMAGE_TAG" -var="postgres_image_tag=$IMAGE_TAG"
```

O primeiro apply completo provisiona a capacidade ECS/EC2 dedicada ao banco, EBS persistente, serviço privado e serviço Java. As migrations Flyway são executadas quando a aplicação inicia. Cada atualização requer publicar ambas as imagens com uma nova tag e aplicar novamente.

### Operação e limites

- O nome privado do banco é `postgres.buggytrip.internal`; o endpoint não é exposto no ALB nem recebe IP público.
- O `PGDATA` fica em um subdiretório do EBS para que o `lost+found` do filesystem ext4 não bloqueie a inicialização do PostgreSQL.
- Usuário e senha são lidos de `buggytrip/postgres` no Secrets Manager; o state Terraform guarda apenas o ARN.
- O AWS Backup cria snapshots diários às 05:00 UTC e mantém 14 dias. Faça testes de restauração para validar o RPO/RTO.
- O banco é uma única instância em uma AZ. EBS não fornece failover multi-AZ; disponibilidade gerenciada e menor carga operacional exigem Amazon RDS.
- Não execute `terraform destroy` em produção nem remova o guard `prevent_destroy` do volume sem plano de recuperação aprovado.
