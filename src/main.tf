terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "seth-saperstein"
    workspaces {
      name = "dip-airbyte-poc"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "vpc" {
  backend = "remote"

  config = {
    organization = "seth-saperstein"
    workspaces = {
      name = "poc-network-tf"
    }
  }
}

data "aws_acm_certificate" "issued" {
  domain   = var.domain
  statuses = ["ISSUED"]
}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  public_subnet_id_1  = data.terraform_remote_state.vpc.outputs.public_subnet_1.id
  private_subnet_id_1 = data.terraform_remote_state.vpc.outputs.private_subnet_1.id
  public_subnet_id_2  = data.terraform_remote_state.vpc.outputs.public_subnet_2.id
  vpc_id              = data.terraform_remote_state.vpc.outputs.vpc.id
}

resource "aws_cloudwatch_log_group" "airbyte" {
  name = "${var.project_name}-airbyte-${var.stack_id}"
}

resource "aws_s3_bucket" "config" {
  bucket = "${var.project_name}-airbyte-conf-${var.env_name}-${var.stack_id}-${local.account_id}"
}

resource "aws_s3_bucket_object" "docker_compose" {
  bucket = aws_s3_bucket.config.id
  key    = "docker-compose.yaml"
  content = templatefile("configs/docker-compose.tpl", {
    REGION    = "us-east-1",
    LOG_GROUP = aws_cloudwatch_log_group.airbyte.name,
  })
}

resource "aws_security_group" "airbyte_instance" {
  name        = "${var.project_name}-airbyte-sg-${var.stack_id}"
  description = "Sg for hosting Airbyte"
  vpc_id      = local.vpc_id

  ingress = [
    {
      description      = "allow alb traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = []
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = [aws_security_group.airbyte_lb.id]
      self             = false
    }
  ]

  egress = [
    {
      description      = "All traffic out"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

resource "aws_network_interface" "airbyte" {
  subnet_id       = local.private_subnet_id_1
  security_groups = [aws_security_group.airbyte_instance.id]

  tags = {
    Name = "${var.project_name}-airbyte-eni-${var.stack_id}"
  }
}

resource "aws_iam_role" "instance" {
  name = "${var.project_name}-airbyte-${var.stack_id}"

  inline_policy {
    name = "${var.project_name}-airbyte-instance-${var.stack_id}"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:GetObject"]
          Effect   = "Allow"
          Resource = ["${aws_s3_bucket.config.arn}/*"]
        },
        {
          Action   = ["cloudwatch:CloudWatchLogsFullAccess"]
          Effect   = "Allow"
          Resource = [aws_cloudwatch_log_group.airbyte.arn]
        }
      ]
    })
  }

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "airbyte" {
  name = "${var.project_name}-airbyte-${var.stack_id}"
  role = aws_iam_role.instance.name
}

resource "aws_instance" "this" {
  ami           = "ami-02e136e904f3da870"
  instance_type = "t2.medium"
  iam_instance_profile = aws_iam_instance_profile.airbyte.id

  network_interface {
    network_interface_id = aws_network_interface.airbyte.id
    device_index         = 0
  }

  user_data = templatefile("scripts/startup.tpl", {
    NGINX_USERNAME   = var.nginx_username,
    NGINX_PASSWORD   = var.nginx_password,
    CONF_BUCKET_NAME = aws_s3_bucket.config.id,
  })
  # TODO: Remove this
  key_name = var.airbyte_key_pair_name
  tags = {
    Name = "${var.project_name}-airbyte-${var.stack_id}"
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.project_name}-airbyte-tg-${var.stack_id}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id
}

resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.this.id
  port             = 80
}

resource "aws_security_group" "airbyte_lb" {
  name        = "${var.project_name}-airbyte-lb-sg-${var.stack_id}"
  description = "Sg for Airbyte ALB"
  vpc_id      = local.vpc_id

  ingress = [
    {
      description      = "allow whitelisted IPs"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = var.whitelisted_ips
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  egress = [
    {
      description      = "All traffic out"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "this" {
  name               = "${var.project_name}-airbyte-${var.stack_id}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.airbyte_lb.id]
  subnets            = [local.public_subnet_id_1, local.public_subnet_id_2]
}

resource "aws_lb_listener" "airbyte" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.issued.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
