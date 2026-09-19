variable "region" {}

variable "cluster_name" {}

variable "service_name" {}

variable "service_port" {}

variable "service_cpu" {}

variable "service_memory" {}

variable "ssm_vpc_id" {}

variable "ssm_listener" {}

variable "ssm_private_subnet_1" {}

variable "ssm_private_subnet_2" {}

variable "ssm_private_subnet_3" {}

variable "environment_variables" {}

variable "capabilities" {}

variable "service_health_check" {}

variable "service_launch_type" {}

variable "service_task_count" {}

variable "service_hosts" {}

variable "scale_type" {}

variable "task_minimum" {}

variable "task_maximum" {}

### autoscaling de cpu out

variable "scale_out_cpu_threshold" {}

variable "scale_out_adjustment" {}

variable "scale_out_comparison_operator" {}

variable "scale_out_statistic" {}

variable "scale_out_period" {}

variable "scale_out_evaluation_period" {}

variable "scale_out_cooldown" {}

### autoscaling de cpu in

variable "scale_in_cpu_threshold" {}

variable "scale_in_adjustment" {}

variable "scale_in_comparison_operator" {}

variable "scale_in_statistic" {}

variable "scale_in_period" {}

variable "scale_in_evaluation_period" {}

variable "scale_in_cooldown" {}