# -------------------------------------------------------------------------
# Data Sources -> VPC and Subnets (Dynamically fetched just like bash script)
# -------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# -------------------------------------------------------------------------
# Pre-requisites (Security Group, IAM Role, Subnet Group for DAX)
# -------------------------------------------------------------------------

# Security Group for DAX
resource "aws_security_group" "dax_sg" {
  name        = "${var.project_prefix}-dax-sg"
  description = "Security group for DAX cluster"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8111
    to_port     = 8111
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Trust Policy for DAX
data "aws_iam_policy_document" "dax_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dax.amazonaws.com"]
    }
  }
}

# IAM Role for DAX
resource "aws_iam_role" "dax_role" {
  name               = "ComunidadDevopsDAXServiceRole"
  assume_role_policy = data.aws_iam_policy_document.dax_trust_policy.json
}

# Attach Permissions to IAM Role
resource "aws_iam_role_policy_attachment" "dax_dynamodb_access" {
  role       = aws_iam_role.dax_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Subnet Group for DAX
resource "aws_dax_subnet_group" "dax_subnet_group" {
  name        = "${var.project_prefix}-dax-subnet-group"
  description = "Subnet group for DAX"
  subnet_ids  = data.aws_subnets.default.ids
}

# -------------------------------------------------------------------------
# Step 1: Create the Amazon Aurora Database (Cluster + Primary Instance)
# -------------------------------------------------------------------------

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = var.aurora_cluster_identifier
  engine                  = "aurora-mysql"
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  backup_retention_period = 7
  skip_final_snapshot     = true
}

resource "aws_rds_cluster_instance" "primary_instance" {
  identifier         = "${var.project_prefix}-primary-instance"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version_actual
}

# -------------------------------------------------------------------------
# Step 2: Deploy an Aurora Read Replica
# -------------------------------------------------------------------------

resource "aws_rds_cluster_instance" "replica_instance" {
  identifier         = "${var.project_prefix}-replica-instance"
  cluster_identifier = aws_rds_cluster.aurora_cluster.id
  instance_class     = var.db_instance_class
  engine             = aws_rds_cluster.aurora_cluster.engine
  engine_version     = aws_rds_cluster.aurora_cluster.engine_version_actual
  promotion_tier     = 1
}

# -------------------------------------------------------------------------
# Step 3: Create the Amazon DynamoDB Table
# -------------------------------------------------------------------------

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "ID"

  attribute {
    name = "ID"
    type = "S"
  }
}

# -------------------------------------------------------------------------
# Step 4: Deploy a DynamoDB Accelerator (DAX) Cluster
# -------------------------------------------------------------------------

resource "aws_dax_cluster" "dax_cluster" {
  cluster_name       = var.dax_cluster_name
  iam_role_arn       = aws_iam_role.dax_role.arn
  node_type          = var.dax_node_type
  replication_factor = 3
  security_group_ids = [aws_security_group.dax_sg.id]
  subnet_group_name  = aws_dax_subnet_group.dax_subnet_group.name

  # We force Terraform to wait until the policy is attached to the role before creating DAX.
  # Otherwise, AWS DAX deployment might fail if the role isn't ready.
  depends_on = [
    aws_iam_role_policy_attachment.dax_dynamodb_access
  ]
}
