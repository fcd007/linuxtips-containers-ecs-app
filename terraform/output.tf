output "java_ecr_repository_url" {
  description = "ECR repository URL for the Java application."
  value       = module.service.ecr_repository_url
}

output "api_dns_name" {
  description = "DNS name of the existing application load balancer."
  value       = data.aws_lb.application.dns_name
}

output "postgres_ecr_repository_url" {
  description = "ECR repository URL for the PostgreSQL image."
  value       = data.aws_ecr_repository.postgres.repository_url
}

output "postgres_jdbc_url" {
  description = "Private JDBC URL used by the Java ECS service."
  value       = "jdbc:postgresql://${var.database_service_name}.${var.database_private_namespace}:5432/${var.database_name}"
}

output "postgres_data_volume_id" {
  description = "Persistent encrypted EBS volume ID for disaster recovery."
  value       = aws_ebs_volume.postgres_data.id
}