locals {
  account_id           = data.aws_caller_identity.current.account_id
  lambda_function_name = var.lambda_function_name
  lambda_role_name     = var.lambda_role_name
  s3_bucket_name       = var.s3_bucket_name
  dynamodb_table_name  = var.dynamodb_table_name
}

data "aws_iam_policy_document" "lambda_role_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "dynamodb_policy" {
  statement {
    effect = "Allow"

    actions = ["dynamodb:PutItem"]

    resources = ["arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.dynamodb_table_name}"]
  }
}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect = "Allow"

    actions = ["s3:PutObject"]

    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }
}

data "aws_iam_policy_document" "s3_bucket_policy" {
    statement {
        effect = "Deny"
        principals {
            type = "*"
            identifiers = ["*"]
        }
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
        
        condition {
            test     = "StringNotEquals"
            variable = "aws:PrincipalArn"
            values   = ["arn:aws:iam::${local.account_id}:role/${local.lambda_role_name}"]
        }
    }
}

resource "aws_iam_role" "lambda_role" {
  name               = local.lambda_role_name
  assume_role_policy = data.aws_iam_policy_document.lambda_role_assume_role.json
}

resource "aws_iam_role_policy_attachment" "aws_lambda_basic_execution_role" {
    role = aws_iam_role.lambda_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dynamo_db_policy" {
    name = "CustomDynamoDBPut"
    policy = data.aws_iam_policy_document.dynamodb_policy.json
}

resource "aws_iam_policy" "s3_policy" {
    name = "CustomS3Put"
    policy = data.aws_iam_policy_document.s3_policy.json
}


resource "aws_iam_role_policy_attachment" "dynamo_db_policy_attachment" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.dynamo_db_policy.arn
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
    role = aws_iam_role.lambda_role.name
    policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_s3_bucket" "s3_bucket" {
    bucket        = local.s3_bucket_name
    force_destroy = true
}

resource "aws_s3_bucket_policy" "s3_bucket_acl" {
    bucket = aws_s3_bucket.s3_bucket.id
    policy = data.aws_iam_policy_document.s3_bucket_policy.json
}

resource "aws_dynamodb_table" "dynamodb_table" {
    name = local.dynamodb_table_name
    hash_key = "ID"
    read_capacity = 5
    write_capacity = 5
    
    attribute {
        name = "ID"
        type = "S"
    }
}

data "archive_file" "lambda_zip" {
    type = "zip"
    source_file = "${path.module}/src/main.py"
    output_path = "${path.module}/function.zip"
}

resource "aws_lambda_function" "lab_lambda" {
    filename         = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    function_name    = local.lambda_function_name
    role             = aws_iam_role.lambda_role.arn
    handler          = "main.lambda_handler"
    runtime          = "python3.8"

    environment {
        variables = {
            DYNAMODB_TABLE_NAME = local.dynamodb_table_name
            S3_BUCKET_NAME      = local.s3_bucket_name
        }
    }
}

# The data source aws_lambda_invocation invokes the function
# during the plan/apply phase and returns the result.
data "aws_lambda_invocation" "invoke_lambda" {
    function_name = aws_lambda_function.lab_lambda.function_name
    input         = "{}"
}

output "lambda_invoke_result" {
    value = jsondecode(data.aws_lambda_invocation.invoke_lambda.result)
}

