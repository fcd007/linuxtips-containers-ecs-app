module "service" {
  source = "/home/dantas/Documents/github/Linuxtips/descomplicando-ecs/linuxtips-containers-ecs-service-module"

  cluster_name   = var.cluster_name
  service_name   = var.service_name
  service_port   = var.service_port
  service_cpu    = var.service_cpu
  service_memory = var.service_memory


  service_listener = data.aws_ssm_parameter.listener.value
  vpc_id           = data.aws_ssm_parameter.vpc_id.value

  private_subnets = [
    data.aws_ssm_parameter.private_subnet_1.value,
    data.aws_ssm_parameter.private_subnet_2.value,
    data.aws_ssm_parameter.private_subnet_3.value,
  ]
}