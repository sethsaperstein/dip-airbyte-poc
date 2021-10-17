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

resource "aws_security_group" "airbyte_instance" {
    name = "airbyte-sg"
    description = "Sg for hosting Airbyte"
    vpc_id = var.vpc_id

    ingress = [
        {
            description = "allow whitelisted IP's"
            from_port = 443
            to_port = 443
            protocol = "tcp"
            cidr_blcoks = var.whitelisted_ips
        },
        {
            description = "allow whitelisted IP's"
            from_port = 80
            to_port = 80
            protocol = "tcp"
            cidr_blcoks = var.whitelisted_ips
        }
    ]

    egress = [
        {
            from_port        = 0
            to_port          = 0
            protocol         = "-1"
            cidr_blocks      = ["0.0.0.0/0"]
            ipv6_cidr_blocks = ["::/0"]
        }
    ]
}

resource "aws_instance" "this" {
  ami           = "ami-02e136e904f3da870"
  instance_type = "t2.medium"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.airbyte_instance.id]
}

resource "aws_lb_target_group" "this" {
    name = "airbyte-tg"
    port = 8000
    protocol = "HTTP"
    vpc_id = var.vpc_id
}


resource "aws_security_group" "airbyte_tg" {
    name = "airbyte-tg-sg"
    description = "Sg for Airbyte ALB"
    vpc_id = var.vpc_id

    ingress = [
        {
            description = "allow whitelisted IP's"
            from_port = 443
            to_port = 443
            protocol = "tcp"
            cidr_blcoks = [aws_instance.this.public_ip]
        },
        {
            description = "allow whitelisted IP's"
            from_port = 80
            to_port = 80
            protocol = "tcp"
            cidr_blcoks = [aws_instance.this.public_ip]
        }
    ]

    egress = [
        {
            from_port        = 0
            to_port          = 0
            protocol         = "-1"
            cidr_blocks      = ["0.0.0.0/0"]
            ipv6_cidr_blocks = ["::/0"]
        }
    ]
}

resource "aws_alb" "this" {
    name               = "test-lb-tf"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.airbyte_tg.id]
    subnets            = var.subnets
}

resource "aws_lb_listener" "airbyte" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
