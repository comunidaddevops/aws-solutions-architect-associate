variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "project_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "comunidad-devops"
}

variable "aurora_cluster_identifier" {
  type        = string
  description = "The cluster identifier for Aurora"
  default     = "comunidad-devops-aurora-cluster"
}

variable "db_master_username" {
  type        = string
  description = "Master username for Aurora DB"
  default     = "dbadmin"
}

variable "db_master_password" {
  type        = string
  description = "Master password for Aurora DB"
  default     = "YourSegurePassord123!"
  sensitive   = true
}

variable "db_instance_class" {
  type        = string
  description = "Instance class for Aurora primary and read replica"
  default     = "db.t3.medium"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name for the DynamoDB table"
  default     = "MyDynamoDBTable"
}

variable "dax_cluster_name" {
  type        = string
  description = "Name for the DAX Cluster"
  default     = "c-devops-dax"
}

variable "dax_node_type" {
  type        = string
  description = "Compute type for the DAX Cluster nodes"
  default     = "dax.t3.small"
}
