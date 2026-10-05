locals {
  database_subnet_id = data.aws_ssm_parameter.private_subnet_1.value
  postgres_image     = "${data.aws_ecr_repository.postgres.repository_url}:${var.postgres_image_tag}"
  application_database_secrets = [
    {
      name      = "DB_USERNAME"
      valueFrom = "${data.aws_secretsmanager_secret.database_credentials.arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${data.aws_secretsmanager_secret.database_credentials.arn}:password::"
    }
  ]
  postgres_volume_id = replace(aws_ebs_volume.postgres_data.id, "-", "")
}

data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

data "aws_subnet" "database" {
  id = local.database_subnet_id
}

data "aws_region" "current" {}

data "aws_ecr_repository" "postgres" {
  name = "${var.cluster_name}/postgres"
}

removed {
  from = aws_ecr_repository.postgres

  lifecycle {
    destroy = false
  }
}

resource "aws_security_group" "postgres_host" {
  name_prefix = "${var.database_ecs_cluster_name}-host-"
  description = "Private ECS container instance for PostgreSQL"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  egress {
    description = "Outbound ECS, ECR, Secrets Manager, SSM, and CloudWatch access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.database_ecs_cluster_name}-host"
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "postgres_task" {
  name_prefix = "${var.database_ecs_cluster_name}-task-"
  description = "Private PostgreSQL task, accessible only from the application ECS tasks"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  ingress {
    description     = "PostgreSQL from the application ECS task security group only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.service.security_group_id]
  }

  egress {
    description = "Outbound traffic for PostgreSQL task dependencies"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.database_ecs_cluster_name}-task"
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role" "postgres_ecs_instance" {
  name_prefix = "${var.database_ecs_cluster_name}-host-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "postgres_ecs_instance" {
  role       = aws_iam_role.postgres_ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "postgres_ec2_ssm" {
  role       = aws_iam_role.postgres_ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "postgres_ecs_instance" {
  name_prefix = "${var.database_ecs_cluster_name}-host-"
  role        = aws_iam_role.postgres_ecs_instance.name
}

resource "aws_ecs_cluster" "postgres" {
  name = var.database_ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ebs_volume" "postgres_data" {
  availability_zone = data.aws_subnet.database.availability_zone
  size              = var.database_volume_size_gib
  type              = "gp3"
  encrypted         = true

  tags = {
    Name        = "${var.database_ecs_cluster_name}-postgres-data"
    Backup      = "true"
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_instance" "postgres_ecs_host" {
  ami                         = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type               = var.database_instance_type
  subnet_id                   = local.database_subnet_id
  vpc_security_group_ids      = [aws_security_group.postgres_host.id]
  iam_instance_profile        = aws_iam_instance_profile.postgres_ecs_instance.name
  associate_public_ip_address = false
  user_data = templatefile("${path.module}/templates/postgres-host-user-data.yaml.tftpl", {
    ecs_cluster_name = aws_ecs_cluster.postgres.name
    volume_id        = local.postgres_volume_id
  })

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.database_ecs_cluster_name}-ecs-host"
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.postgres_ecs_instance,
    aws_iam_role_policy_attachment.postgres_ec2_ssm
  ]
}

resource "aws_volume_attachment" "postgres_data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.postgres_data.id
  instance_id = aws_instance.postgres_ecs_host.id
}

resource "aws_iam_role" "postgres_task_execution" {
  name_prefix = "${var.database_ecs_cluster_name}-task-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "postgres_task_execution" {
  role       = aws_iam_role.postgres_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "postgres_secret_access" {
  name_prefix = "${var.database_ecs_cluster_name}-secret-"
  role        = aws_iam_role.postgres_task_execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["secretsmanager:GetSecretValue"]
      Effect   = "Allow"
      Resource = data.aws_secretsmanager_secret.database_credentials.arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/ecs/${var.database_ecs_cluster_name}/postgres"
  retention_in_days = 30

  tags = {
    Application = "BuggyTrip"
    ManagedBy   = "Terraform"
  }
}

resource "aws_service_discovery_private_dns_namespace" "postgres" {
  name = var.database_private_namespace
  vpc  = data.aws_ssm_parameter.vpc_id.value
}

resource "aws_service_discovery_service" "postgres" {
  name = var.database_service_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.postgres.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
}

resource "aws_ecs_task_definition" "postgres" {
  family                   = "${var.database_ecs_cluster_name}-postgres"
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.postgres_task_execution.arn

  volume {
    name      = "postgres-data"
    host_path = "/mnt/buggytrip-postgres"
  }

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = local.postgres_image
      essential = true
      memory    = 1024
      portMappings = [{
        containerPort = 5432
        hostPort      = 5432
        protocol      = "tcp"
      }]
      environment = [{
        name  = "POSTGRES_DB"
        value = var.database_name
        }, {
        name  = "PGDATA"
        value = "/var/lib/postgresql/data/pgdata"
      }]
      secrets = [
        {
          name      = "POSTGRES_USER"
          valueFrom = "${data.aws_secretsmanager_secret.database_credentials.arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${data.aws_secretsmanager_secret.database_credentials.arn}:password::"
        }
      ]
      mountPoints = [{
        sourceVolume  = "postgres-data"
        containerPath = "/var/lib/postgresql/data"
        readOnly      = false
      }]
      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
        interval    = 15
        timeout     = 5
        retries     = 5
        startPeriod = 30
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.postgres.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "postgres"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "postgres" {
  name            = "${var.database_ecs_cluster_name}-postgres"
  cluster         = aws_ecs_cluster.postgres.id
  task_definition = aws_ecs_task_definition.postgres.arn
  desired_count   = 1
  launch_type     = "EC2"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [local.database_subnet_id]
    security_groups  = [aws_security_group.postgres_task.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.postgres.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.postgres_task_execution,
    aws_iam_role_policy.postgres_secret_access,
    aws_volume_attachment.postgres_data
  ]
}

resource "aws_backup_vault" "postgres" {
  name          = "${var.database_ecs_cluster_name}-backups"
  force_destroy = true
}

resource "aws_backup_plan" "postgres" {
  name = "${var.database_ecs_cluster_name}-daily-ebs"

  rule {
    rule_name         = "daily-postgres-data-volume"
    target_vault_name = aws_backup_vault.postgres.name
    schedule          = "cron(0 5 * * ? *)"

    lifecycle {
      delete_after = 14
    }
  }
}

resource "aws_iam_role" "postgres_backup" {
  name_prefix = "${var.database_ecs_cluster_name}-backup-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "postgres_backup" {
  role       = aws_iam_role.postgres_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "postgres" {
  name         = "${var.database_ecs_cluster_name}-postgres-data"
  plan_id      = aws_backup_plan.postgres.id
  iam_role_arn = aws_iam_role.postgres_backup.arn
  resources    = [aws_ebs_volume.postgres_data.arn]
}
