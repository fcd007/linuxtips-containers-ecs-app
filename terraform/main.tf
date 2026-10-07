module "service" {
  source = "/home/dantas/Documents/github/Linuxtips/descomplicando-ecs/linuxtips-containers-ecs-service-module"

  region                = var.region
  create_ecr_repository = var.create_ecr_repository

  cluster_name   = var.cluster_name
  service_name   = var.service_name
  service_port   = var.service_port
  service_cpu    = var.service_cpu
  service_memory = var.service_memory


  service_listener            = data.aws_ssm_parameter.listener.value
  service_task_execution_role = aws_iam_role.main.arn
  vpc_id                      = data.aws_ssm_parameter.vpc_id.value

  service_health_check = var.service_health_check

  service_launch_type = var.service_launch_type
  service_task_count  = var.service_task_count

  service_hosts = distinct(concat(var.service_hosts, [data.aws_lb.application.dns_name]))

  environment_variables = concat(var.environment_variables, [
    {
      name  = "DB_URL"
      value = "jdbc:postgresql://${var.database_service_name}.${var.database_private_namespace}:5432/${var.database_name}"
    }
  ])
  secrets   = local.application_database_secrets
  image_tag = var.image_tag

  capabilities = var.capabilities

  private_subnets = [
    data.aws_ssm_parameter.private_subnet_1.value,
    data.aws_ssm_parameter.private_subnet_2.value,
    data.aws_ssm_parameter.private_subnet_3.value,
  ]


  # autoscaling
  scale_type   = var.scale_type
  task_minimum = var.task_minimum
  task_maximum = var.task_maximum

  # autscaling de cpu

  scale_out_cpu_threshold       = var.scale_out_cpu_threshold
  scale_out_adjustment          = var.scale_out_adjustment
  scale_out_comparison_operator = var.scale_out_comparison_operator
  scale_out_statistic           = var.scale_out_statistic
  scale_out_period              = var.scale_out_period
  scale_out_evaluation_period   = var.scale_out_evaluation_period
  scale_out_cooldown            = var.scale_out_cooldown

  scale_in_cpu_threshold       = var.scale_in_cpu_threshold
  scale_in_adjustment          = var.scale_in_adjustment
  scale_in_comparison_operator = var.scale_in_comparison_operator
  scale_in_statistic           = var.scale_in_statistic
  scale_in_period              = var.scale_in_period
  scale_in_evaluation_period   = var.scale_in_evaluation_period
  scale_in_cooldown            = var.scale_in_cooldown

  scale_track_cpu = var.scale_track_cpu

  depends_on = [
    aws_iam_role_policy.database_secret_access
  ]
}

removed {
  from = module.service.aws_ecr_repository.main

  lifecycle {
    destroy = false
  }
}