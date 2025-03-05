terraform {
  required_version = "~> 1.10.3"

  backend "s3" {
  }

  required_providers {
    // AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      PROJECT = "BASEPORT_PRD",
    }
  }
}

resource "random_password" "db_password" {
  length           = 16
  lower            = true  # 小文字を文字列に含める
  numeric          = true  # 数値を文字列に含める
  upper            = true  # 大文字を文字列に含める
  special          = true  # 記号を文字列に含める
  override_special = "@_=+-"  # 記号で利用する文字列を指定 (default: !@#$%&*()-_=+[]{}<>:?)
}

#
# RDS
#
resource "aws_security_group" "app_db_sg" {
  name = "${var.app_name}-${var.stage}-db"
  vpc_id = local.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = [ "10.0.0.0/8" ]
  }
  tags = {
    "Name" = "${var.app_name}-${var.stage}-db"
  }
}

/**
 * パラメータグループ
 * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group
 *
 * MySQLのパラメータ
 * aws rds describe-engine-default-parameters --db-parameter-group-family mysql8.0
 */
resource "aws_db_parameter_group" "app_db_pg" {
  name = "${var.app_name}-${var.stage}-db"
  family = "mysql8.0"
  parameter {
    name = "character_set_client"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_connection"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_database"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_filesystem"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_results"
    value = "utf8mb4"
  }
  parameter {
    name = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name = "collation_connection"
    value = "utf8mb4_bin"
  }
  parameter {
    name = "collation_server"
    value = "utf8mb4_bin"
  }
}

resource "aws_db_subnet_group" "app_db_subnet_group" {
  name       = "${var.app_name}-${var.stage}-db"
  subnet_ids = local.private_subnet_ids
}

resource "aws_db_instance" "app_db" {
  identifier = "${var.app_name}-${var.stage}-db"
  storage_encrypted = true
  engine               = "mysql"
  allocated_storage    = 20
  max_allocated_storage = 100
  db_name              = var.app_name
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.app_db_subnet_group.name
  backup_retention_period = 30
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  multi_az = false
  parameter_group_name = aws_db_parameter_group.app_db_pg.name
  port = 3306
  vpc_security_group_ids = [aws_security_group.app_db_sg.id]
  storage_type = "gp3"
  network_type = "IPV4"
  username = local.user_name
  password = random_password.db_password.result
  skip_final_snapshot  = true
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }
}


#
# DBのログイン情報を保持する SecretsManager
#
resource "aws_secretsmanager_secret" "app_db_secret" {
  name = "/${var.app_name}/${var.stage}/db"
  recovery_window_in_days = 0
  force_overwrite_replica_secret = true

}

resource "aws_secretsmanager_secret_version" "app_db_secret_version" {
  secret_id = aws_secretsmanager_secret.app_db_secret.id
  secret_string = jsonencode({
    db_user = local.user_name
    db_password = random_password.db_password.result
    db_host = aws_db_instance.app_db.address
    db_port = tostring(aws_db_instance.app_db.port)
  })
}