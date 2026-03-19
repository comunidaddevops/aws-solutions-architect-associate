variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "my-serverless-lab-bucket-comunidaddevops-12345"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "LabTable"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "LabLambdaFunction"
}

variable "lambda_role_name" {
  description = "Name of the Lambda role"
  type        = string
  default     = "LabLambdaRole"
}
